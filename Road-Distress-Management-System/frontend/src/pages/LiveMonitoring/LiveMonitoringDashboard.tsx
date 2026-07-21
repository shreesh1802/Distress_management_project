import { useState, useEffect, useRef } from 'react';
import { 
  Play, 
  Square, 
  Maximize2, 
  Minimize2, 
  Radio, 
  AlertTriangle, 
  History, 
  Activity, 
  Check, 
  Tv, 
  Loader2,
  Cpu
} from 'lucide-react';
import './LiveMonitoringDashboard.css';
import RealTimeDetectionFeed from '../../components/monitoring/RealTimeDetectionFeed';

interface LiveEvent {
  seq: number;
  time: string;
  class_name: string;
  confidence: number;
  severity: string;
  model_source: string;
  frame: number;
  latitude: number;
  longitude: number;
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

const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://127.0.0.1:8000';
const API_V1 = `${API_BASE_URL}/api/v1`;
const WS_URL = `${API_BASE_URL.replace(/^http/, 'ws')}/api/v1/live/ws`;

export default function LiveMonitoringDashboard() {
  const [running, setRunning] = useState(false);
  const [starting, setStarting] = useState(false);
  const [cameraIndex, setCameraIndex] = useState(1);
  const [status, setStatus] = useState<LiveStatus | null>(null);
  const [events, setEvents] = useState<LiveEvent[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [streamKey, setStreamKey] = useState(0);
  const [isFullscreen, setIsFullscreen] = useState(false);
  const wsRef = useRef<WebSocket | null>(null);

  const start = async () => {
    setStarting(true);
    setError(null);
    try {
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
      setStreamKey(k => k + 1);
      connectWs();
    } catch (e: any) {
      setError(e.message || 'Failed to start live camera');
    } finally {
      setStarting(false);
    }
  };

  const stop = async () => {
    try { await fetch(`${API_V1}/live/stop`, { method: 'POST' }); } catch { /* noop */ }
    if (wsRef.current) {
      wsRef.current.close();
      wsRef.current = null;
    }
    setRunning(false);
  };

  const connectWs = () => {
    if (wsRef.current) {
      wsRef.current.close();
    }
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

  useEffect(() => {
    // Probe initial status on mount
    const probeStatus = async () => {
      try {
        const res = await fetch(`${API_V1}/live/status`);
        if (res.ok) {
          const data = await res.json();
          if (data.running) {
            setRunning(true);
            connectWs();
          }
        }
      } catch (e) { /* ignore offline */ }
    };
    probeStatus();

    return () => {
      if (wsRef.current) wsRef.current.close();
    };
  }, []);

  const toggleFullscreen = () => {
    setIsFullscreen(!isFullscreen);
  };

  const handleAcknowledgeAlert = (seq: number) => {
    setEvents(prev => prev.filter(e => e.seq !== seq));
  };

  // Map events to FeedDetection type required by RealTimeDetectionFeed
  const feedDetections = events.map(ev => ({
    id: `DET-${ev.seq}`,
    time: ev.time,
    roadId: ev.model_source === 'road' ? 'RD-PAVEMENT' : 'RD-SIGNAGE',
    distressType: ev.class_name,
    severity: (ev.severity.charAt(0).toUpperCase() + ev.severity.slice(1)) as any,
    confidence: Math.round(ev.confidence * 100),
    coordinates: `${ev.latitude.toFixed(6)}, ${ev.longitude.toFixed(6)}`
  }));

  const activeOverlay = events.length > 0 ? events[0] : null;
  const criticalAlerts = events.filter(e => e.severity.toLowerCase() === 'critical');

  return (
    <div className="live-mon-center-page animate-fade-in">
      <header className="live-mon-header">
        <div className="live-mon-header__title-group">
          <Tv size={28} className="live-mon-header__logo" />
          <div>
            <h1 className="bold-page-title">Live Monitoring Center</h1>
            <p className="light-secondary-text">Real-time road distress detection and AI video stream diagnostics</p>
          </div>
        </div>

        <div className="live-mon-header__toolbar">
          <div className="live-mon-header__status-badge">
            <span className={`status-badge-dot ${running ? 'active' : ''}`} />
            <span>{running ? 'LIVE: ACTIVE' : 'FEED: IDLE'}</span>
          </div>

          <button className="header-action-btn" onClick={toggleFullscreen} title={isFullscreen ? "Exit Fullscreen" : "Fullscreen"}>
            {isFullscreen ? <Minimize2 size={15} /> : <Maximize2 size={15} />}
          </button>
        </div>
      </header>

      <div className="live-mon-main-grid">
        {/* Left Column (70%): Live Camera Feed Viewport */}
        <div className="live-mon-left-column">
          <section className={`live-camera-feed-card premium-card ${isFullscreen ? 'card-fullscreen' : ''}`}>
            <header className="feed-card-header">
              <div className="feed-card-title" style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                <Radio size={16} className={`feed-live-icon ${running ? 'pulsing' : ''}`} />
                <h2 className="medium-section-title">Camera Feed Analysis</h2>
              </div>
              {running && status && (
                <div className="feed-card-telemetry" style={{ display: 'flex', gap: '15px' }}>
                  <span>Display FPS: <strong>{status.fps.toFixed(1)}</strong></span>
                  <span>Inference FPS: <strong>{(status.inference_fps ?? 0).toFixed(1)}</strong></span>
                  <span>Inferences: <strong>{status.inferences}</strong></span>
                </div>
              )}
            </header>

            <div className="feed-viewport-container">
              <div className="live-mon-video-card__viewport">
                {running ? (
                  <img
                    key={streamKey}
                    src={`${API_V1}/live/stream?k=${streamKey}`}
                    alt="Live detection stream"
                    style={{ width: '100%', height: '100%', objectFit: 'contain', background: '#000', borderRadius: 8 }}
                  />
                ) : (
                  <div className="live-mon-video-card__empty-state">
                    <Radio className="live-mon-video-card__empty-icon animate-pulse" size={48} />
                    <h3>Live Video Stream Offline</h3>
                    <p>Select camera index below and start live monitoring to activate YOLO inference scanning.</p>
                  </div>
                )}
              </div>
            </div>

            <footer className="feed-controls-footer" style={{ display: 'flex', alignItems: 'center', gap: 16 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <label className="light-secondary-text" style={{ fontSize: 13 }}>Camera Index:</label>
                <input
                  type="number"
                  min={0}
                  max={4}
                  value={cameraIndex}
                  disabled={running}
                  onChange={e => setCameraIndex(Number(e.target.value))}
                  style={{ width: 60, padding: '6px 8px', borderRadius: 6, background: 'rgba(255,255,255,0.05)', color: '#FFF', border: '1px solid rgba(255,255,255,0.1)' }}
                />
              </div>

              {!running ? (
                <button className="live-mon-btn start-monitoring-btn" onClick={start} disabled={starting}>
                  {starting ? <Loader2 className="animate-spin" size={15} /> : <Play size={15} />}
                  <span>{starting ? 'Initializing Models...' : 'Start Live Detection'}</span>
                </button>
              ) : (
                <button className="live-mon-btn stop-monitoring-btn" onClick={stop}>
                  <Square size={15} />
                  <span>Stop Detection</span>
                </button>
              )}

              {error && <p className="upload-error-tag font-mono" style={{ margin: 0, color: '#f87171' }}>{error}</p>}
            </footer>
          </section>
        </div>

        {/* Right Column (30%): Current Anomaly & Alerts */}
        <aside className="live-mon-sidebar-column">
          {running && activeOverlay && (
            <article className="current-detection-card premium-card">
              <header className="card-header-row">
                <Activity size={16} className="text-purple animate-pulse" />
                <h3 className="medium-section-title" style={{ fontSize: '15px' }}>Current Detection HUD</h3>
              </header>

              <div className="current-detection-body">
                <div className="active-distress-panel">
                  <div className="active-distress-header">
                    <span className="hud-label">Distress Category</span>
                    <h4 className="active-distress-title">{activeOverlay.class_name}</h4>
                  </div>

                  <div className="hud-properties-grid">
                    <div className="hud-prop-item">
                      <span className="prop-lbl">Severity</span>
                      <span className={`severity-badge bg-${activeOverlay.severity.toLowerCase()}`}>
                        {activeOverlay.severity}
                      </span>
                    </div>

                    <div className="hud-prop-item">
                      <span className="prop-lbl">AI Confidence</span>
                      <span className="prop-val font-mono font-bold text-purple">
                        {Math.round(activeOverlay.confidence * 100)}%
                      </span>
                    </div>

                    <div className="hud-prop-item">
                      <span className="prop-lbl">Source Model</span>
                      <span className="prop-val font-mono text-uppercase">
                        {activeOverlay.model_source}
                      </span>
                    </div>

                    <div className="hud-prop-item">
                      <span className="prop-lbl">Frame Number</span>
                      <span className="prop-val font-mono">
                        #{activeOverlay.frame}
                      </span>
                    </div>

                    <div className="hud-prop-item span-full">
                      <span className="prop-lbl">Coordinates</span>
                      <span className="prop-val font-mono text-xs">
                        📍 {activeOverlay.latitude.toFixed(6)}, {activeOverlay.longitude.toFixed(6)}
                      </span>
                    </div>
                  </div>
                </div>
              </div>
            </article>
          )}

          <article className="live-alerts-card premium-card">
            <header className="card-header-row">
              <AlertTriangle size={16} className="text-red animate-pulse" />
              <h3 className="medium-section-title" style={{ fontSize: '15px' }}>Critical Warnings</h3>
            </header>

            <div className="alerts-card-body scrollable-y">
              {criticalAlerts.length === 0 ? (
                <div className="empty-alerts-view">
                  <Check size={28} className="success-icon" />
                  <span>No critical distress alerts active</span>
                </div>
              ) : (
                <div className="alerts-elements-list">
                  {criticalAlerts.map(alert => (
                    <div key={alert.seq} className="alerts-item-card" style={{ borderLeft: '3.5px solid var(--danger)' }}>
                      <div className="alert-item-details">
                        <div className="alert-item-header">
                          <span className="alert-item-id font-mono">DET-{alert.seq}</span>
                          <span className="alert-item-time font-mono">[{alert.time.slice(11, 19)}]</span>
                        </div>
                        <span className="alert-item-title font-semibold">{alert.class_name}</span>
                        <span className="alert-item-location" style={{ fontSize: 11 }}>
                          📍 {alert.latitude.toFixed(5)}, {alert.longitude.toFixed(5)}
                        </span>
                      </div>
                      <button 
                        className="alert-item-acknowledge-btn"
                        onClick={() => handleAcknowledgeAlert(alert.seq)}
                      >
                        Acknowledge
                      </button>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </article>
        </aside>
      </div>

      {/* Real-time Scrolling Detection Row */}
      <section className="live-realtime-feed-row">
        <RealTimeDetectionFeed 
          detections={feedDetections} 
          isMonitoringActive={running} 
        />
      </section>

      {/* Real History Logs Table */}
      <section className="live-detection-history-card premium-card">
        <header className="history-section-header">
          <div className="section-title-group">
            <History size={18} style={{ color: 'var(--accent-blue)' }} />
            <h2 className="medium-section-title">Detection History Logs</h2>
          </div>
        </header>

        <div className="history-table-viewport scrollable-x">
          <table className="history-data-table">
            <thead>
              <tr>
                <th>Detection ID</th>
                <th>Timestamp</th>
                <th>Source Model</th>
                <th>Distress Category</th>
                <th>Severity</th>
                <th>Confidence</th>
                <th>Coordinates</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              {events.length === 0 ? (
                <tr>
                  <td colSpan={8} className="text-center font-mono light-secondary-text" style={{ padding: 24 }}>
                    Waiting for camera detections...
                  </td>
                </tr>
              ) : (
                events.map(row => (
                  <tr key={row.seq} className="table-row-hover">
                    <td className="font-mono font-bold text-primary-text">DET-{row.seq}</td>
                    <td>{row.time.slice(11, 19)}</td>
                    <td className="text-uppercase">{row.model_source}</td>
                    <td>{row.class_name}</td>
                    <td>
                      <span className={`live-mon-badge live-mon-badge--${row.severity.toLowerCase()}`}>
                        {row.severity}
                      </span>
                    </td>
                    <td className="font-mono">{Math.round(row.confidence * 100)}%</td>
                    <td className="font-mono text-xs">{row.latitude.toFixed(6)}, {row.longitude.toFixed(6)}</td>
                    <td>
                      <span className="live-mon-status-badge live-mon-status-badge--active">
                        Active
                      </span>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </section>

      {/* Bottom KPI Telemetry widgets */}
      <footer className="live-analytics-footer-grid">
        <article className="premium-kpi-card premium-card">
          <div className="kpi-header-row">
            <div className="kpi-icon-container" style={{ backgroundColor: 'rgba(59,130,246,0.1)' }}>
              <Activity size={18} style={{ color: '#3B82F6' }} />
            </div>
            <span className="kpi-title-label">Total Detections</span>
          </div>
          <p className="kpi-value-num">{status?.detections_total ?? 0}</p>
          <div className="kpi-card-footer">
            <span className="comparison-lbl">distresses flagged</span>
          </div>
        </article>

        <article className="premium-kpi-card premium-card">
          <div className="kpi-header-row">
            <div className="kpi-icon-container" style={{ backgroundColor: 'rgba(16,185,129,0.1)' }}>
              <Cpu size={18} style={{ color: '#10B981' }} />
            </div>
            <span className="kpi-title-label">Average Accuracy</span>
          </div>
          <p className="kpi-value-num">{status ? `${Math.round(status.avg_confidence * 100)}%` : '0%'}</p>
          <div className="kpi-card-footer">
            <span className="comparison-lbl">confidence rating</span>
          </div>
        </article>

        <article className="premium-kpi-card premium-card">
          <div className="kpi-header-row">
            <div className="kpi-icon-container" style={{ backgroundColor: 'rgba(245,158,11,0.1)' }}>
              <Radio size={18} style={{ color: '#F59E0B' }} />
            </div>
            <span className="kpi-title-label">Display / Inference FPS</span>
          </div>
          <p className="kpi-value-num">{status ? `${status.fps.toFixed(1)} / ${(status.inference_fps ?? 0).toFixed(1)}` : '0.0 / 0.0'} FPS</p>
          <div className="kpi-card-footer">
            <span className="comparison-lbl">stream / inference rates</span>
          </div>
        </article>

        <article className="premium-kpi-card premium-card">
          <div className="kpi-header-row">
            <div className="kpi-icon-container" style={{ backgroundColor: 'rgba(139,92,246,0.1)' }}>
              <Loader2 size={18} style={{ color: '#8B5CF6' }} className={running ? 'animate-spin' : ''} />
            </div>
            <span className="kpi-title-label">Frames Processed</span>
          </div>
          <p className="kpi-value-num">{status?.frames ?? 0}</p>
          <div className="kpi-card-footer">
            <span className="comparison-lbl">total frame count</span>
          </div>
        </article>
      </footer>
    </div>
  );
}
