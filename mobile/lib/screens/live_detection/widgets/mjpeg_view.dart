import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Renders an MJPEG (`multipart/x-mixed-replace`) endpoint — what the React
/// source just points a plain `<img src="...">` tag at — since Flutter has
/// no built-in equivalent. Reads the response as a byte stream and scans for
/// JPEG SOI/EOI markers (0xFFD8 / 0xFFD9) frame-by-frame rather than parsing
/// the multipart boundary text, which is simpler and works regardless of
/// the exact boundary format the server uses.
class MjpegView extends StatefulWidget {
  const MjpegView({super.key, required this.url, required this.onError});

  final String url;
  final ValueChanged<String> onError;

  @override
  State<MjpegView> createState() => _MjpegViewState();
}

class _MjpegViewState extends State<MjpegView> {
  Uint8List? _frame;
  http.Client? _client;
  StreamSubscription<List<int>>? _subscription;
  final List<int> _buffer = [];

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void didUpdateWidget(covariant MjpegView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _disconnect();
      _frame = null;
      _connect();
    }
  }

  Future<void> _connect() async {
    final client = http.Client();
    _client = client;
    try {
      final response = await client.send(http.Request('GET', Uri.parse(widget.url)));
      if (response.statusCode != 200) {
        widget.onError('Stream returned ${response.statusCode}');
        return;
      }
      _subscription = response.stream.listen(
        _onChunk,
        onError: (Object _) => widget.onError('Live stream connection lost'),
        cancelOnError: true,
      );
    } catch (_) {
      widget.onError('Could not reach the live video stream');
    }
  }

  void _onChunk(List<int> chunk) {
    _buffer.addAll(chunk);
    while (true) {
      final start = _indexOfMarker(_buffer, 0xFF, 0xD8, 0);
      if (start == -1) {
        // No frame start yet; keep the buffer from growing unbounded while
        // we wait for one.
        if (_buffer.length > 2000000) _buffer.clear();
        return;
      }
      final end = _indexOfMarker(_buffer, 0xFF, 0xD9, start + 2);
      if (end == -1) {
        if (start > 0) _buffer.removeRange(0, start);
        return;
      }
      final frame = Uint8List.fromList(_buffer.sublist(start, end + 2));
      _buffer.removeRange(0, end + 2);
      if (mounted) setState(() => _frame = frame);
    }
  }

  int _indexOfMarker(List<int> data, int b0, int b1, int start) {
    for (var i = start; i < data.length - 1; i++) {
      if (data[i] == b0 && data[i + 1] == b1) return i;
    }
    return -1;
  }

  void _disconnect() {
    _subscription?.cancel();
    _subscription = null;
    _client?.close();
    _client = null;
    _buffer.clear();
  }

  @override
  void dispose() {
    _disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final frame = _frame;
    if (frame == null) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white54,
          ),
        ),
      );
    }
    return ColoredBox(
      color: Colors.black,
      child: Image.memory(frame, gaplessPlayback: true, fit: BoxFit.contain),
    );
  }
}
