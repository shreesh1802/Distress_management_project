import { useEffect, useState, useRef } from 'react'
import { useParams } from 'react-router-dom'
import apiService from '../../services/api/apiService'
import type { RoadDistressResponse } from '../../services/api/apiService'
import DetectionTrendChart from './DetectionTrendChart'
import DistressDistributionChart from './DistressDistributionChart'
import KPISection from './KPISection'
import { Tv, Play, Square, Camera, Map, Compass, ChevronRight, Sliders, Plus, Minus, Layers, Download, CheckCircle2, RefreshCw } from 'lucide-react'
import './DashboardGrid.css'

interface ActiveOverlay {
  type: string;
  confidence: number;
  severity: string;
  x: number;
  y: number;
  w: number;
  h: number;
}

export default function DashboardGrid() {
  const { videoId } = useParams<{ videoId?: string }>();
  const [distresses, setDistresses] = useState<RoadDistressResponse[]>([]);
  const [reportsCount, setReportsCount] = useState<number>(0);
  
  const [isLoading, setIsLoading] = useState<boolean>(true);
  const [error, setError] = useState<string | null>(null);

  // Simulated Live Camera State (exact numbers from reference)
  const [isCameraActive, setIsCameraActive] = useState(true);
  const [fps, setFps] = useState(24);
  const [elapsedSeconds, setElapsedSeconds] = useState(765); // 00:12:45
  const [frameCount, setFrameCount] = useState(14532);

  const [overlays] = useState<ActiveOverlay[]>([
    { type: 'Pothole', confidence: 97, severity: 'critical', x: 20, y: 55, w: 100, h: 60 },
    { type: 'Crack', confidence: 92, severity: 'high', x: 60, y: 50, w: 120, h: 70 }
  ]);


  const frameIntervalRef = useRef<any>(null);

  const fetchDashboardData = async () => {
    setIsLoading(true);
    setError(null);
    try {
      const [distressLogs, reportsList] = await Promise.all([
        videoId
          ? apiService.getVideoDetections(Number(videoId))
          : apiService.getDistressLogs(0, 200),
        apiService.getReports(0, 200)
      ]);
      setDistresses(distressLogs);
      setReportsCount(reportsList.length);
    } catch (err: any) {
      console.error(err);
      setError('Failed to fetch dashboard data. Verify that the backend server is running.');
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchDashboardData();
  }, [videoId]);

  // Camera telemetries simulator
  useEffect(() => {
    if (isCameraActive) {
      frameIntervalRef.current = setInterval(() => {
        setFrameCount(prev => prev + 1);
        setElapsedSeconds(prev => prev + 1);
        setFps(Math.floor(23 + Math.random() * 2));
      }, 1000 / 24);
    } else {
      clearInterval(frameIntervalRef.current);
    }

    return () => {
      clearInterval(frameIntervalRef.current);
    };
  }, [isCameraActive]);

  const handleCapture = () => {
    alert("Live frame captured & saved to system disk directory uploads/screenshots.");
  };

  const handleReplay = () => {
    setFrameCount(14532);
    setElapsedSeconds(765);
    setIsCameraActive(true);
  };

  const handleGenerateReport = async (distressId: number) => {
    try {
      await apiService.generatePDFReport(distressId);
      alert(`Report generated successfully for Road Distress #${distressId}.`);
    } catch (err) {
      alert("Failed to export PDF report.");
    }
  };

  if (isLoading) {
    return (
      <section className="dashboard-page dashboard-page--loading" aria-label="Loading dashboard">
        <div className="dashboard-page__spinner-container">
          <div className="dashboard-page__spinner" />
          <p>Connecting to backend API services...</p>
        </div>
      </section>
    );
  }

  if (error) {
    return (
      <section className="dashboard-page dashboard-page--error" aria-label="Dashboard connection error">
        <div className="dashboard-page__error-container">
          <div className="dashboard-page__error-icon">⚠️</div>
          <h2>Service Connection Failure</h2>
          <p>{error}</p>
          <button className="dashboard-page__retry-btn" onClick={fetchDashboardData}>
            Retry Connection
          </button>
        </div>
      </section>
    );
  }

  const distressCount = distresses.length;
  const criticalCount = distresses.filter(
    (d) => d.severity.toLowerCase() === 'high' || d.severity.toLowerCase() === 'critical'
  ).length;
  const pendingCount = distresses.filter(
    (d) => d.status.toLowerCase() === 'detected' || d.status.toLowerCase() === 'scheduled' || d.status.toLowerCase() === 'pending'
  ).length;

  // Format elapsed time as HH:MM:SS
  const formatTime = (secs: number) => {
    const h = Math.floor(secs / 3600).toString().padStart(2, '0');
    const m = Math.floor((secs % 3600) / 60).toString().padStart(2, '0');
    const s = (secs % 60).toString().padStart(2, '0');
    return `${h}:${m}:${s}`;
  };

  return (
    <section className="dashboard-page animate-fade-in" aria-label="Dashboard overview">
      <header className="dashboard-page__header">
        <h1 className="bold-page-title" style={{ fontSize: '32px' }}>Fleet Operations Control</h1>
        <p className="light-secondary-text" style={{ fontSize: '14px' }}>Commercial SaaS admin interface monitoring road conditions, defects, and maintenance schedules.</p>
      </header>

      {/* Row 1: 8 KPI cards */}
      <div className="dash-row">
        <KPISection 
          distressCount={distressCount}
          criticalCount={criticalCount}
          pendingCount={pendingCount}
          reportsCount={reportsCount}
        />
      </div>

      {/* Row 2: Live camera feed, GIS map, Recent feed */}
      <div className="dash-layout-grid">
        {/* Left Column: Live camera feed simulation */}
        <div className="premium-card live-cam-card">
          <div className="card-header-with-actions">
            <div className="card-header-title">
              <Tv size={16} style={{ color: 'var(--primary-text)' }} />
              <h2 className="medium-section-title" style={{ fontSize: '15px' }}>Live Camera Feed</h2>
            </div>
            <span className="live-cam-badge">
              <span className="live-dot" />
              LIVE
            </span>
          </div>

          <div className="live-cam-viewport">
            <div className="live-cam-simulation-scene">
              {/* Telemetries overlay */}
              <div className="hud-telemetry">
                <span>GPS: 37.7749, -122.4194</span>
                <span>Camera ID: CAM-04</span>
              </div>

              {/* Bounding box display (Pothole and Crack) */}
              {isCameraActive && overlays.map((box, index) => (
                <div 
                  key={index}
                  className={`live-cam-bbox`}
                  style={{
                    left: `${box.x}%`,
                    top: `${box.y}%`,
                    width: `${box.w}px`,
                    height: `${box.h}px`,
                    borderColor: box.severity === 'critical' ? 'var(--danger)' : 'var(--warning)',
                    borderWidth: '2px',
                    borderStyle: 'solid',
                    position: 'absolute'
                  }}
                >
                  <span className={`live-cam-bbox-tag`} style={{ background: box.severity === 'critical' ? 'var(--danger)' : 'var(--warning)', color: '#FFF' }}>
                    {box.type} {box.type === 'Pothole' ? '0.97' : '0.92'}
                  </span>
                </div>
              ))}

              <div className="hud-grid-lines" />
            </div>
          </div>

          {/* HUD Parameter labels row */}
          <div className="hud-params-grid">
            <div className="hud-param-block">
              <span className="hud-param-lbl">FPS</span>
              <span className="hud-param-val">{fps}</span>
            </div>
            <div className="hud-param-block">
              <span className="hud-param-lbl">Resolution</span>
              <span className="hud-param-val">1280x720</span>
            </div>
            <div className="hud-param-block">
              <span className="hud-param-lbl">Frame</span>
              <span className="hud-param-val">{frameCount.toLocaleString()}</span>
            </div>
            <div className="hud-param-block">
              <span className="hud-param-lbl">Time</span>
              <span className="hud-param-val">{formatTime(elapsedSeconds)}</span>
            </div>
          </div>

          <div className="live-cam-controls">
            <div className="controls-group">
              {isCameraActive ? (
                <button className="btn-control btn-control--stop" onClick={() => setIsCameraActive(false)}>
                  <Square size={12} />
                  <span>Pause</span>
                </button>
              ) : (
                <button className="btn-control btn-control--start" onClick={() => setIsCameraActive(true)}>
                  <Play size={12} />
                  <span>Resume</span>
                </button>
              )}
              <button className="btn-control" onClick={handleReplay}>
                <RefreshCw size={12} />
                <span>Replay</span>
              </button>
            </div>
            <button className="btn-control btn-control--capture" onClick={handleCapture}>
              <Camera size={12} />
            </button>
          </div>
        </div>

        {/* Center Column: Live Road Map */}
        <div className="premium-card gis-map-card">
          <div className="card-header-with-actions">
            <div className="card-header-title">
              <Map size={16} />
              <h2 className="medium-section-title" style={{ fontSize: '15px' }}>Live Road Map</h2>
            </div>
            <div style={{ display: 'flex', gap: '8px' }}>
              <select className="gis-date-select" defaultValue="all">
                <option value="all">All Distresses</option>
              </select>
              <select className="gis-date-select" defaultValue="today">
                <option value="today">Today</option>
              </select>
              <button className="btn-control" style={{ padding: '4px 8px', borderRadius: '6px' }}>
                <Sliders size={12} />
              </button>
            </div>
          </div>

          <div className="gis-map-legend">
            <span className="gis-legend-item"><span className="legend-dot legend-dot--critical" />Critical</span>
            <span className="gis-legend-item"><span className="legend-dot legend-dot--high" />High</span>
            <span className="gis-legend-item"><span className="legend-dot legend-dot--medium" />Medium</span>
            <span className="gis-legend-item"><span className="legend-dot legend-dot--low" />Low</span>
            <span className="gis-legend-item"><span className="legend-dot legend-dot--info" />Info</span>
          </div>

          <div className="gis-map-inner-wrapper">
            <svg viewBox="0 0 800 450" className="gis-svg-projection">
              {/* Map base streets vector layout */}
              <rect width="100%" height="100%" fill="#F3F4F6" />
              <path d="M 50,20 L 750,430 M 100,430 L 700,20 M 50,225 L 750,225" stroke="#FFFFFF" strokeWidth="12" strokeLinecap="round" />
              <path d="M 50,20 L 750,430 M 100,430 L 700,20 M 50,225 L 750,225" stroke="#E5E7EB" strokeWidth="2" strokeLinecap="round" />
              
              <rect x="180" y="40" width="160" height="80" fill="#E8F5E9" rx="8" />
              <text x="260" y="80" fontSize="13" fontWeight="600" fill="#2E7D32" textAnchor="middle">Presidio of SF</text>

              <rect x="80" y="280" width="200" height="80" fill="#E8F5E9" rx="8" />
              <text x="180" y="325" fontSize="13" fontWeight="600" fill="#2E7D32" textAnchor="middle">Golden Gate Park</text>

              <text x="560" y="220" fontSize="12" fill="#9CA3AF" fontWeight="600">Mission District</text>
              <text x="540" y="100" fontSize="12" fill="#9CA3AF" fontWeight="600">Sunset District</text>

              {/* Map Pins from Image */}
              <g transform="translate(230, 160)">
                <circle r="16" fill="var(--danger-light)" />
                <circle r="12" fill="var(--danger)" />
                <text y="4" fontSize="11" fontWeight="bold" fill="white" textAnchor="middle">12</text>
              </g>
              <g transform="translate(380, 240)">
                <circle r="16" fill="var(--warning-light)" />
                <circle r="12" fill="var(--warning)" />
                <text y="4" fontSize="11" fontWeight="bold" fill="white" textAnchor="middle">8</text>
              </g>
              <g transform="translate(560, 140)">
                <circle r="16" fill="var(--danger-light)" />
                <circle r="12" fill="var(--danger)" />
                <text y="4" fontSize="11" fontWeight="bold" fill="white" textAnchor="middle">9</text>
              </g>
              <g transform="translate(560, 320)">
                <circle r="16" fill="var(--danger-light)" />
                <circle r="12" fill="var(--danger)" />
                <text y="4" fontSize="11" fontWeight="bold" fill="white" textAnchor="middle">9</text>
              </g>
              <g transform="translate(420, 90)">
                <circle r="16" fill="var(--success-light)" />
                <circle r="12" fill="var(--success)" />
                <text y="4" fontSize="11" fontWeight="bold" fill="white" textAnchor="middle">5</text>
              </g>
              <g transform="translate(380, 360)">
                <circle r="16" fill="var(--success-light)" />
                <circle r="12" fill="var(--success)" />
                <text y="4" fontSize="11" fontWeight="bold" fill="white" textAnchor="middle">6</text>
              </g>
              <g transform="translate(520, 380)">
                <circle r="16" fill="var(--success-light)" />
                <circle r="12" fill="var(--success)" />
                <text y="4" fontSize="11" fontWeight="bold" fill="white" textAnchor="middle">4</text>
              </g>
              <g transform="translate(240, 360)">
                <circle r="16" fill="var(--warning-light)" />
                <circle r="12" fill="var(--warning)" />
                <text y="4" fontSize="11" fontWeight="bold" fill="white" textAnchor="middle">7</text>
              </g>
            </svg>

            {/* Map Controls */}
            <div className="gis-controls-overlay">
              <button className="gis-control-btn"><Compass size={14} /></button>
              <button className="gis-control-btn"><Plus size={14} /></button>
              <button className="gis-control-btn"><Minus size={14} /></button>
              <button className="gis-control-btn"><Layers size={14} /></button>
            </div>
          </div>
        </div>

        {/* Right Column: Recent Detections List */}
        <div className="premium-card recent-detections-list-card">
          <div className="card-header-with-actions" style={{ padding: '16px 20px 8px 20px', marginBottom: 0 }}>
            <h2 className="medium-section-title" style={{ fontSize: '15px' }}>Recent Detections</h2>
            <button className="btn-view-feed" style={{ fontSize: '12px' }}>View All</button>
          </div>
          <div className="scrollable-detections-feed">
            {distresses.slice(0, 5).map((d) => (
              <div key={d.id} className="detection-feed-item" onClick={() => alert(`Details: distress ID RD-${d.id}`)}>
                <div className="feed-item-thumbnail-wrapper">
                  {d.image_url ? (
                    <img src={`http://localhost:8000/static/${d.image_url.split('static/')[1] || d.image_url}`} alt="thumbnail" className="feed-item-thumbnail" onError={(e) => {
                      e.currentTarget.src = 'https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?auto=format&fit=crop&q=80&w=80';
                    }} />
                  ) : (
                    <div className="feed-item-thumbnail-placeholder">N/A</div>
                  )}
                </div>
                <div className="feed-item-details">
                  <div className="feed-item-row-top">
                    <span className="feed-item-time" style={{ fontSize: '11px', color: 'var(--secondary-text)' }}>
                      {new Date(d.detected_at).toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', hour12: true })}
                    </span>
                    <span className={`severity-tag severity-tag--${d.severity.toLowerCase()}`}>
                      {d.severity}
                    </span>
                  </div>
                  <div className="feed-item-row-middle">
                    <span className="feed-item-type" style={{ fontSize: '12px', fontWeight: 600 }}>{d.distress_type.replace('_', ' ')}</span>
                  </div>
                  <div className="feed-item-row-bottom">
                    <span className="feed-item-road-id" style={{ fontSize: '11px', color: 'var(--secondary-text)' }}>Road ID: {d.id}</span>
                    <span className="feed-item-conf font-mono">Confidence: {Math.round(d.confidence_score * 100 || 88)}%</span>
                  </div>
                </div>
                <ChevronRight size={14} className="feed-item-arrow" />
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Row 3: Circular analytics pipelines & standard charts */}
      <div className="dash-analytics-grid">
        <div className="premium-card">
          <div className="card-header-with-actions" style={{ marginBottom: '8px' }}>
            <h2 className="medium-section-title" style={{ fontSize: '15px' }}>Distress Distribution</h2>
            <select className="gis-date-select" defaultValue="month">
              <option value="month">This Month</option>
            </select>
          </div>
          <DistressDistributionChart data={distresses} />
        </div>

        <div className="premium-card">
          <div className="card-header-with-actions" style={{ marginBottom: '8px' }}>
            <h2 className="medium-section-title" style={{ fontSize: '15px' }}>Weekly Detection Trend</h2>
            <select className="gis-date-select" defaultValue="week">
              <option value="week">This Week</option>
            </select>
          </div>
          <DetectionTrendChart data={distresses} />
        </div>

        {/* Circular progress indicators & checklist */}
        <div className="premium-card circular-pipelines-card">
          <h2 className="medium-section-title" style={{ fontSize: '15px', marginBottom: '14px' }}>AI Processing Pipeline</h2>
          <div className="pipeline-flex-layout">
            <div className="pipeline-left-circle">
              <div className="circle-svg-wrapper-large">
                <svg width="90" height="90" viewBox="0 0 36 36">
                  <path className="circle-bg" d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831" fill="none" stroke="#F3F4F6" strokeWidth="2.5" />
                  <path className="circle-fill" strokeDasharray="75, 100" stroke="#1F2937" d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831" fill="none" strokeWidth="2.5" />
                </svg>
                <div className="circle-text-large font-mono font-bold" style={{ fontSize: '16px' }}>75%</div>
              </div>
              <span className="circle-label-large" style={{ fontSize: '11px', fontWeight: 600 }}>Processing...</span>
              <span className="circle-label-sub" style={{ fontSize: '10px', color: 'var(--secondary-text)' }}>Est. 00:25 left</span>
            </div>
            
            <div className="pipeline-checklist">
              <div className="pipeline-checklist-item">
                <CheckCircle2 size={14} className="text-success" style={{ color: 'var(--success)' }} />
                <span className="checklist-label">Video Uploaded</span>
                <span className="vms-status-badge vms-status-badge--completed" style={{ marginLeft: 'auto', fontSize: '9px' }}>Completed</span>
              </div>
              <div className="pipeline-checklist-item">
                <CheckCircle2 size={14} className="text-success" style={{ color: 'var(--success)' }} />
                <span className="checklist-label">Frames Extracted</span>
                <span className="vms-status-badge vms-status-badge--completed" style={{ marginLeft: 'auto', fontSize: '9px' }}>Completed</span>
              </div>
              <div className="pipeline-checklist-item">
                <CheckCircle2 size={14} className="text-success" style={{ color: 'var(--success)' }} />
                <span className="checklist-label">AI Detection (YOLOv11)</span>
                <span className="vms-status-badge vms-status-badge--completed" style={{ marginLeft: 'auto', fontSize: '9px' }}>Completed</span>
              </div>
              <div className="pipeline-checklist-item">
                <div className="status-indicator status-indicator--running" />
                <span className="checklist-label">Generating Reports</span>
                <span className="vms-status-badge vms-status-badge--processing" style={{ marginLeft: 'auto', fontSize: '9px' }}>In Progress</span>
              </div>
              <div className="pipeline-checklist-item">
                <div className="status-indicator status-indicator--pending" />
                <span className="checklist-label">Uploading to Storage</span>
                <span className="vms-status-badge vms-status-badge--pending" style={{ marginLeft: 'auto', fontSize: '9px', background: '#F3F4F6', color: 'var(--secondary-text)' }}>Pending</span>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Row 4: Single Highlight Card for AI Maintenance Recommendation */}
      <div className="premium-card highlight-recommendation-card">
        <div className="card-header-with-actions" style={{ paddingBottom: '12px' }}>
          <h2 className="medium-section-title" style={{ fontSize: '15px' }}>AI Maintenance Recommendation</h2>
          <div style={{ display: 'flex', gap: '8px' }}>
            <button className="btn-control" style={{ fontSize: '12px' }} onClick={() => alert("Redirecting to maintenance board...")}>
              View All
            </button>
            <button className="btn-control btn-control--capture" style={{ fontSize: '12px', background: 'var(--primary-text)', color: '#FFF' }}>
              <Download size={12} />
              <span>Generate PDF</span>
            </button>
          </div>
        </div>

        {distresses.slice(0, 1).map((d) => (
          <div key={d.id} className="highlight-recommendation-body">
            <div className="highlight-recommendation-col highlight-recommendation-col--thumb">
              {d.image_url ? (
                <img src={`http://localhost:8000/static/${d.image_url.split('static/')[1] || d.image_url}`} alt="visual" className="highlight-thumbnail" onError={(e) => {
                  e.currentTarget.src = 'https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?auto=format&fit=crop&q=80&w=80';
                }} />
              ) : (
                <div className="highlight-thumbnail highlight-thumbnail--empty">No image</div>
              )}
            </div>

            <div className="highlight-recommendation-col">
              <span className="highlight-lbl">Distress Type</span>
              <span className="highlight-val text-capitalize">{d.distress_type.replace('_', ' ')}</span>
            </div>

            <div className="highlight-recommendation-col">
              <span className="highlight-lbl">Severity</span>
              <span className={`status-pill badge-${d.severity.toLowerCase()}`} style={{ width: 'max-content', marginTop: '2px' }}>
                {d.severity.toUpperCase()}
              </span>
            </div>

            <div className="highlight-recommendation-col">
              <span className="highlight-lbl">Road ID</span>
              <span className="highlight-val font-mono font-bold">RD-{d.id}</span>
            </div>

            <div className="highlight-recommendation-col">
              <span className="highlight-lbl">Location</span>
              <span className="highlight-val">San Francisco, CA</span>
              <span className="highlight-sub font-mono">{d.latitude.toFixed(4)}° N, {d.longitude.toFixed(4)}° W</span>
            </div>

            <div className="highlight-recommendation-col" style={{ flex: 1.2 }}>
              <span className="highlight-lbl">Recommended Action</span>
              <span className="highlight-val">{d.distress_type === 'pothole' ? 'Cold Mix Asphalt Repair' : 'Polyurethane Crack Injection'}</span>
              <span className="highlight-sub text-danger" style={{ color: 'var(--danger)', fontWeight: 600 }}>Priority: Immediate</span>
            </div>

            <div className="highlight-recommendation-col">
              <span className="highlight-lbl">Estimated Cost</span>
              <span className="highlight-val font-semibold">$120 - $180</span>
            </div>

            <div className="highlight-recommendation-col">
              <span className="highlight-lbl">Estimated Time</span>
              <span className="highlight-val">3 - 4 Hours</span>
            </div>

            <div className="highlight-recommendation-col highlight-recommendation-col--action">
              <button 
                className="btn-report-run font-semibold"
                onClick={() => handleGenerateReport(d.id)}
                style={{ display: 'flex', alignItems: 'center', gap: '6px' }}
              >
                <Download size={14} />
                <span>Generate PDF</span>
              </button>
            </div>
          </div>
        ))}
      </div>
    </section>
  );
}
