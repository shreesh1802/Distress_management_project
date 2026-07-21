/**
 * LiveCameraPanel - self-contained live USB camera detection panel.
 *
 * Drop into LiveMonitoringDashboard (or any page):
 *    import LiveCameraPanel from '../../components/live/LiveCameraPanel';
 *    ...
 *    <LiveCameraPanel />
 *
 * Talks to: POST /live/start, POST /live/stop, GET /live/stream, WS /live/ws
 * Replaces the timer-based simulation with real backend detection data.
 */
import { useEffect, useRef, useState } from 'react';

const API_BASE = (import.meta as any).env?.VITE_API_URL || 'http://127.0.0.1:8000';
const API_V1 = `${API_BASE}/api/v1`;
const WS_URL = `${API_BASE.replace(/^http/, 'ws')}/api/v1/live/ws`;

interface LiveEvent {
  seq: number;
  time: string;
  class_name: string;
  confidence: number;
  severity: string;
  model_source: string;
  frame: number;
}

interface LiveStatus {
  running: boolean;
  error: string | null;
  frames: number;
  inferences: number;
  detections_total: number;
  detections_road: number;
  detections_sign: number;
  critical_alerts: number;
  persisted: number;
  avg_confidence: number;
  fps: number;
  inference_fps?: number;
}

const SEVERITY_COLORS: Record<string, string> = {
  critical: '#ef4444', high: '#f97316', medium: '#eab308', low: '#22c55e',
};

export default function LiveCameraPanel() {
  const [running, setRunning] = useState(false);
  const [starting, setStarting] = useState(false);
  const [cameraIndex, setCameraIndex] = useState(1);
  const [status, setStatus] = useState<LiveStatus | null>(null);
  const [events, setEvents] = useState<LiveEvent[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [streamKey, setStreamKey] = useState(0);
  const wsRef = useRef<WebSocket | null>(null);

  const start = async () => {
    setStarting(true);
    setError(null);
    try {
      // Send real GPS from the browser when available
      let coords: { latitude?: number; longitude?: number } = {};
      try {
        const pos = await new Promise<GeolocationPosition>((res, rej) =>
          navigator.geolocation.getCurrentPosition(res, rej, { timeout: 3000 }));
        coords = { latitude: pos.coords.latitude, longitude: pos.coords.longitude };
      } catch { /* no GPS permission - backend uses its default base */ }

      const res = await fetch(`${API_V1}/live/start`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ camera_index: cameraIndex, ...coords }),
      });
      if (!res.ok) throw new Error((await res.json()).detail || 'Failed to start');
      setRunning(true);
      setStreamKey(k => k + 1); // force <img> to (re)connect to the MJPEG stream
      connectWs();
    } catch (e: any) {
      setError(e.message || 'Failed to start live camera');
    } finally {
      setStarting(false);
    }
  };

  const stop = async () => {
    try { await fetch(`${API_V1}/live/stop`, { method: 'POST' }); } catch { /* noop */ }
    wsRef.current?.close();
    wsRef.current = null;
    setRunning(false);
  };

  const connectWs = () => {
    const ws = new WebSocket(WS_URL);
    wsRef.current = ws;
    ws.onmessage = (msg) => {
      const data = JSON.parse(msg.data);
      if (data.status) setStatus(data.status);
      if (data.events?.length) {
        setEvents(prev => [...data.events.reverse(), ...prev].slice(0, 30));
      }
      if (data.status && !data.status.running) setRunning(false);
      if (data.status?.error) setError(data.status.error);
    };
    ws.onerror = () => setError('WebSocket connection lost');
  };

  useEffect(() => () => { wsRef.current?.close(); }, []);

  return (
    <div style={{ display: 'grid', gridTemplateColumns: '2fr 1fr', gap: 16 }}>
      {/* Video feed */}
      <div style={{ background: 'rgba(0,0,0,0.35)', borderRadius: 12, padding: 12 }}>
        <div style={{ display: 'flex', gap: 8, alignItems: 'center', marginBottom: 10 }}>
          <label style={{ fontSize: 13 }}>Camera index:</label>
          <input
            type="number" min={0} max={4} value={cameraIndex} disabled={running}
            onChange={e => setCameraIndex(Number(e.target.value))}
            style={{ width: 56, padding: 4, borderRadius: 6 }}
          />
          {!running ? (
            <button onClick={start} disabled={starting}
              style={{ padding: '6px 18px', borderRadius: 8, background: '#22c55e', border: 'none', color: '#052e16', fontWeight: 600, cursor: 'pointer' }}>
              {starting ? 'Loading models…' : '▶ Start Live Detection'}
            </button>
          ) : (
            <button onClick={stop}
              style={{ padding: '6px 18px', borderRadius: 8, background: '#ef4444', border: 'none', color: '#fff', fontWeight: 600, cursor: 'pointer' }}>
              ■ Stop
            </button>
          )}
          {status && running && (
            <span style={{ marginLeft: 'auto', fontSize: 12, opacity: 0.8 }}>
              Display: {status.fps} FPS · Inference: {status.inference_fps ?? 0.0} FPS · {status.inferences} inferences
            </span>
          )}
        </div>

        {running ? (
          <img
            key={streamKey}
            src={`${API_V1}/live/stream?k=${streamKey}`}
            alt="Live detection stream"
            style={{ width: '100%', borderRadius: 8, background: '#000' }}
          />
        ) : (
          <div style={{ aspectRatio: '4/3', display: 'flex', alignItems: 'center', justifyContent: 'center', border: '1px dashed rgba(255,255,255,0.25)', borderRadius: 8, opacity: 0.6 }}>
            Camera offline — press Start
          </div>
        )}
        {error && <p style={{ color: '#f87171', fontSize: 13, marginTop: 8 }}>{error}</p>}
      </div>

      {/* Stats + detection feed */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
          <Stat label="Detections" value={status?.detections_total ?? 0} />
          <Stat label="Critical" value={status?.critical_alerts ?? 0} color="#ef4444" />
          <Stat label="Road / Sign" value={`${status?.detections_road ?? 0} / ${status?.detections_sign ?? 0}`} />
          <Stat label="Saved to DB" value={status?.persisted ?? 0} />
        </div>
        <div style={{ background: 'rgba(0,0,0,0.35)', borderRadius: 12, padding: 12, flex: 1, overflowY: 'auto', maxHeight: 420 }}>
          <h4 style={{ margin: '0 0 8px', fontSize: 13, opacity: 0.8 }}>REAL-TIME DETECTION FEED</h4>
          {events.length === 0 && <p style={{ fontSize: 12, opacity: 0.5 }}>No detections yet…</p>}
          {events.map(ev => (
            <div key={ev.seq} style={{ display: 'flex', gap: 8, alignItems: 'center', padding: '6px 0', borderBottom: '1px solid rgba(255,255,255,0.06)', fontSize: 12 }}>
              <span style={{ width: 8, height: 8, borderRadius: '50%', background: SEVERITY_COLORS[ev.severity] || '#94a3b8', flexShrink: 0 }} />
              <span style={{ fontWeight: 600 }}>{ev.class_name}</span>
              <span style={{ opacity: 0.6 }}>{(ev.confidence * 100).toFixed(0)}%</span>
              <span style={{ marginLeft: 'auto', opacity: 0.5, fontSize: 10, textTransform: 'uppercase' }}>
                {ev.model_source} · f{ev.frame}
              </span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

function Stat({ label, value, color }: { label: string; value: number | string; color?: string }) {
  return (
    <div style={{ background: 'rgba(0,0,0,0.35)', borderRadius: 10, padding: '10px 12px' }}>
      <div style={{ fontSize: 11, opacity: 0.6 }}>{label}</div>
      <div style={{ fontSize: 20, fontWeight: 700, color: color || 'inherit' }}>{value}</div>
    </div>
  );
}
