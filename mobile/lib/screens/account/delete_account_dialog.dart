import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/auth_provider.dart';
import '../../router/app_router.dart';
import '../../theme/app_colors.dart';

/// Account deletion (a Google Play requirement for apps with accounts). Asks the user to type their own
/// e-mail address, deletes the account on the server (POST /auth/delete-account) and returns to the login
/// screen. What is removed and what stays (anonymised) is explained in the privacy policy.
Future<void> confirmAndDeleteAccount(BuildContext context, WidgetRef ref) async {
  final email = ref.read(authProvider).user?.email;
  if (email == null) return;
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);

  final deleted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => _DeleteAccountDialog(email: email, ref: ref),
  );

  if (deleted == true) {
    router.go(AppRoutes.login);
    messenger.showSnackBar(const SnackBar(content: Text('Your account has been deleted.')));
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog({required this.email, required this.ref});

  final String email;
  final WidgetRef ref;

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  bool get _matches => _controller.text.trim().toLowerCase() == widget.email.trim().toLowerCase();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await widget.ref.read(authProvider.notifier).deleteAccount(_controller.text.trim());
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete your account?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This permanently deletes your account and signs you out everywhere. '
              'Surveys, audits and documents you added to shared projects stay available to the other '
              'members, with your name removed. This cannot be undone.',
            ),
            const SizedBox(height: 16),
            Text('Type ${widget.email} to confirm:', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              enabled: !_busy,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Your e-mail address'),
              onChanged: (_) => setState(() => _error = null),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: (_matches && !_busy) ? _delete : null,
          child: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Delete account'),
        ),
      ],
    );
  }
}
