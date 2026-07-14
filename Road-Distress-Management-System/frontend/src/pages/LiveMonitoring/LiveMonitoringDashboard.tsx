import React, { useState, useEffect, useRef } from 'react';
import { 
  Play, 
  Square, 
  Upload, 
  Maximize2, 
  Minimize2, 
  Radio, 
  AlertTriangle, 
  History, 
  Activity, 
  Check, 
  Tv,
  Loader2,
  Trash2,
  Video,
  RefreshCw,
  Search,
  Cpu
} from 'lucide-react';
import './LiveMonitoringDashboard.css';
import RealTimeDetectionFeed from '../../components/monitoring/RealTimeDetectionFeed';
import apiService from '../../services/api/apiService';
import type { UploadedVideoResponse } from '../../services/api/apiService';

interface Detection {
  id: string;
  time: string;
  location: string;
  distressType: string;
  severity: 'Critical' | 'High' | 'Medium' | 'Low';
  confidence: number;
  status: string;
}

interface ActiveOverlay {
  type: string;
  confidence: number;
  severity: 'Critical' | 'High' | 'Medium' | 'Low';
  x: number;
  y: number;
  w: number;
  h: number;
}

export default function LiveMonitoringDashboard() {
  // Simulator State
  const [isMonitoring, setIsMonitoring] = useState(false);
  const [framesProcessed, setFramesProcessed] = useState(142030);
  const [distressesCount, setDistressesCount] = useState(87);
  const [criticalAlertsCount, setCriticalAlertsCount] = useState(12);
  const [avgConfidence, setAvgConfidence] = useState(91.8);
  const [videoFile, setVideoFile] = useState<string | null>(null);
  const [isFullscreen, setIsFullscreen] = useState(false);
  const [activeOverlay, setActiveOverlay] = useState<ActiveOverlay | null>(null);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [uploadProgress, setUploadProgress] = useState<number>(0);

  // Clean up Object URL to avoid memory leaks
  useEffect(() => {
    return () => {
      if (previewUrl) {
        URL.revokeObjectURL(previewUrl);
      }
    };
  }, [previewUrl]);

  // Video Management System API state
  const [uploadedVideos, setUploadedVideos] = useState<UploadedVideoResponse[]>([]);
  const [isUploading, setIsUploading] = useState(false);
  const [uploadError, setUploadError] = useState<string | null>(null);
  const [fetchError, setFetchError] = useState<string | null>(null);
  const [rightTab, setRightTab] = useState<'stats' | 'videos'>('videos');
  const [isDragging, setIsDragging] = useState(false);

  // Lists state
  const [recentDetections, setRecentDetections] = useState<Detection[]>([
    { id: 'DET-8830', time: '16:01:05', location: 'NH-48 (KM 42)', distressType: 'Pothole', severity: 'Critical', confidence: 94, status: 'Active' },
    { id: 'DET-8829', time: '15:59:42', location: 'SH-10 (Lonavala)', distressType: 'Alligator Cracks', severity: 'High', confidence: 89, status: 'Active' },
    { id: 'DET-8828', time: '15:58:11', location: 'NH-4 (Pune Bypass)', distressType: 'Rutting', severity: 'Medium', confidence: 87, status: 'Active' },
    { id: 'DET-8827', time: '15:55:04', location: 'Expressway Sector 4', distressType: 'Edge Break', severity: 'Low', confidence: 85, status: 'Acknowledged' }
  ]);

  const [alerts, setAlerts] = useState<Detection[]>([
    { id: 'DET-8830', time: '16:01:05', location: 'NH-48 (KM 42)', distressType: 'Pothole', severity: 'Critical', confidence: 94, status: 'Active' }
  ]);

  const [history, setHistory] = useState<Detection[]>([
    { id: 'DET-8830', time: '16:01:05', location: 'NH-48 (KM 42)', distressType: 'Pothole', severity: 'Critical', confidence: 94, status: 'Active' },
    { id: 'DET-8829', time: '15:59:42', location: 'SH-10 (Lonavala)', distressType: 'Alligator Cracks', severity: 'High', confidence: 89, status: 'Active' },
    { id: 'DET-8828', time: '15:58:11', location: 'NH-4 (Pune Bypass)', distressType: 'Rutting', severity: 'Medium', confidence: 87, status: 'Active' },
    { id: 'DET-8827', time: '15:55:04', location: 'Expressway Sector 4', distressType: 'Edge Break', severity: 'Low', confidence: 85, status: 'Acknowledged' },
    { id: 'DET-8826', time: '15:52:19', location: 'NH-48 (KM 21)', distressType: 'Longitudinal Cracks', severity: 'Medium', confidence: 90, status: 'Acknowledged' },
    { id: 'DET-8825', time: '15:48:30', location: 'SH-10 (Khandala)', distressType: 'Pothole', severity: 'Critical', confidence: 96, status: 'Completed' }
  ]);

  const fileInputRef = useRef<HTMLInputElement>(null);

  // References for keeping track of counters in simulation ticks
  const countersRef = useRef({
    totalFrames: 142030,
    totalDetections: 87,
    totalCritical: 12,
    confidencesSum: 87 * 91.8
  });
  const nextIdRef = useRef(8831);

  // YOLO Telemetry Tick Simulator
  useEffect(() => {
    let frameInterval: any;
    let detectionInterval: any;

    if (isMonitoring) {
      // 1. Tick frames processed (simulates 30fps = 3 frames every 100ms)
      frameInterval = setInterval(() => {
        countersRef.current.totalFrames += 3;
        setFramesProcessed(countersRef.current.totalFrames);
      }, 100);

      // 2. Tick random detections every 4 seconds
      const roads = ['NH-48 (KM 46)', 'SH-10 (Khandala)', 'NH-4 (Thane Expressway)', 'Bypass Highway 2', 'Expressway Section 6'];
      const distresses = ['Pothole', 'Alligator Cracks', 'Rutting', 'Edge Break', 'Longitudinal Cracks', 'Patch'];
      const severities: ('Critical' | 'High' | 'Medium' | 'Low')[] = ['Critical', 'High', 'Medium', 'Low'];

      detectionInterval = setInterval(() => {
        const randomRoad = roads[Math.floor(Math.random() * roads.length)];
        const randomType = distresses[Math.floor(Math.random() * distresses.length)];
        const randomSeverity = severities[Math.floor(Math.random() * severities.length)];
        const randomConf = Math.floor(80 + Math.random() * 18);

        const newId = `DET-${nextIdRef.current++}`;
        const timestamp = new Date().toLocaleTimeString('en-US', { hour12: false });

        const newDet: Detection = {
          id: newId,
          time: timestamp,
          location: randomRoad,
          distressType: randomType,
          severity: randomSeverity,
          confidence: randomConf,
          status: 'Active'
        };

        // Update counters
        countersRef.current.totalDetections += 1;
        countersRef.current.confidencesSum += randomConf;
        const newAvgConf = Number((countersRef.current.confidencesSum / countersRef.current.totalDetections).toFixed(1));

        setDistressesCount(countersRef.current.totalDetections);
        setAvgConfidence(newAvgConf);

        // Update list states
        setRecentDetections(prev => [newDet, ...prev.slice(0, 7)]);
        setHistory(prev => [newDet, ...prev.slice(0, 15)]);

        if (randomSeverity === 'Critical') {
          countersRef.current.totalCritical += 1;
          setCriticalAlertsCount(countersRef.current.totalCritical);
          setAlerts(prev => [newDet, ...prev.slice(0, 4)]);
        }

        // Draw bounding box overlay trigger on screen
        setActiveOverlay({
          type: randomType,
          confidence: randomConf,
          severity: randomSeverity,
          x: Math.floor(15 + Math.random() * 50),
          y: Math.floor(15 + Math.random() * 45),
          w: Math.floor(80 + Math.random() * 120),
          h: Math.floor(60 + Math.random() * 100)
        });

        // Auto clear overlay after 2 seconds
        setTimeout(() => {
          setActiveOverlay(null);
        }, 2000);

      }, 4000);
    }

    return () => {
      clearInterval(frameInterval);
      clearInterval(detectionInterval);
    };
  }, [isMonitoring]);

  const fetchVideos = async () => {
    try {
      const data = await apiService.getVideos(0, 100);
      setUploadedVideos(data);
      setFetchError(null);
    } catch (err: any) {
      console.error(err);
      setFetchError("Failed to fetch uploaded videos library from database.");
    }
  };

  useEffect(() => {
    fetchVideos();
    const interval = setInterval(fetchVideos, 5000);
    return () => clearInterval(interval);
  }, []);

  const handleVideoUploadFile = async (file: File) => {
    const allowedExtensions = ["mp4", "avi", "mov", "mkv"];
    const extension = file.name.split(".").pop()?.toLowerCase();
    if (!extension || !allowedExtensions.includes(extension)) {
      setUploadError("Invalid video format. Supported formats: mp4, avi, mov, mkv.");
      return;
    }

    setIsUploading(true);
    setUploadError(null);
    setUploadProgress(0);

    // Revoke old URL if it exists
    if (previewUrl) {
      URL.revokeObjectURL(previewUrl);
    }

    try {
      const res = await apiService.uploadVideo(file, undefined, (progressEvent) => {
        if (progressEvent.total) {
          const progress = Math.round((progressEvent.loaded * 100) / progressEvent.total);
          setUploadProgress(progress);
        }
      });
      setUploadedVideos(prev => [res, ...prev]);
      setVideoFile(res.filename);
      setIsMonitoring(false);
      setActiveOverlay(null);

      // Create local preview URL
      const localUrl = URL.createObjectURL(file);
      setPreviewUrl(localUrl);

      fetchVideos();
    } catch (err: any) {
      console.error(err);
      setUploadError(err.response?.data?.detail || "Failed to upload video file.");
    } finally {
      setIsUploading(false);
      setUploadProgress(0);
    }
  };

  const handleStart = () => {
    setIsMonitoring(true);
  };

  const handleStop = () => {
    setIsMonitoring(false);
    setActiveOverlay(null);
  };

  const handleUploadClick = () => {
    fileInputRef.current?.click();
  };

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      handleVideoUploadFile(file);
    }
  };

  const handleDragOver = (e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(true);
  };

  const handleDragLeave = () => {
    setIsDragging(false);
  };

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(false);
    const file = e.dataTransfer.files?.[0];
    if (file) {
      handleVideoUploadFile(file);
    }
  };

  const handleDeleteVideo = async (id: number, e: React.MouseEvent) => {
    e.stopPropagation();
    if (!window.confirm("Are you sure you want to delete this video log and remove the physical file from server disk?")) {
      return;
    }
    try {
      await apiService.deleteVideo(id);
      setUploadedVideos(prev => prev.filter(v => v.id !== id));
      if (videoFile && uploadedVideos.find(v => v.id === id)?.filename === videoFile) {
        setVideoFile(null);
        setPreviewUrl(null);
        setIsMonitoring(false);
      }
    } catch (err: any) {
      console.error(err);
      alert("Failed to delete video file.");
    }
  };

  const handleSelectVideo = (video: UploadedVideoResponse) => {
    if (video.processing_status === 'failed') {
      alert("Cannot process a failed video upload log.");
      return;
    }
    setVideoFile(video.filename);
    setPreviewUrl(null);
    // Reset counters for new simulation run
    countersRef.current = {
      totalFrames: 0,
      totalDetections: 0,
      totalCritical: 0,
      confidencesSum: 0
    };
    setFramesProcessed(0);
    setDistressesCount(0);
    setCriticalAlertsCount(0);
    setAvgConfidence(0);
    setRecentDetections([]);
    setAlerts([]);
    setIsMonitoring(true);
  };

  const toggleFullscreen = () => {
    setIsFullscreen(!isFullscreen);
  };

  const handleAcknowledgeAlert = (id: string) => {
    setAlerts(prev => prev.filter(a => a.id !== id));
    setRecentDetections(prev => prev.map(d => d.id === id ? { ...d, status: 'Acknowledged' } : d));
    setHistory(prev => prev.map(d => d.id === id ? { ...d, status: 'Acknowledged' } : d));
  };

  // Map recent detections to FeedDetection type required by RealTimeDetectionFeed
  const feedDetections = recentDetections.map(d => {
    const numPart = d.location.replace(/[^0-9]/g, '');
    const roadId = d.location.startsWith('NH-48') 
      ? 'RD-48102' 
      : d.location.startsWith('SH-10') 
      ? 'RD-10294' 
      : d.location.startsWith('NH-4') 
      ? 'RD-48301' 
      : 'RD-40291';
    const coords = numPart 
      ? `18.734${numPart.slice(0, 1) || '0'}, 73.42${numPart.slice(1, 3) || '00'}` 
      : '18.8912, 73.2045';

    return {
      id: d.id,
      time: d.time,
      roadId,
      distressType: d.distressType,
      severity: d.severity,
      confidence: d.confidence,
      coordinates: coords
    };
  });

  return (
    <div className="live-mon-center-page animate-fade-in">
      
      {/* 1. Page Header */}
      <header className="live-mon-header">
        <div className="live-mon-header__title-group">
          <Tv size={28} className="live-mon-header__logo" />
          <div>
            <h1 className="bold-page-title">Live Monitoring Center</h1>
            <p className="light-secondary-text">Real-time road distress detection and AI video stream diagnostics</p>
          </div>
        </div>

        {/* Header Actions */}
        <div className="live-mon-header__toolbar">
          <div className="live-mon-header__status-badge">
            <span className={`status-badge-dot ${isMonitoring ? 'active' : ''}`} />
            <span>{isMonitoring ? 'LIVE: ACTIVE' : videoFile ? 'FEED: READY' : 'FEED: IDLE'}</span>
          </div>

          <div className="camera-select-wrapper">
            <select className="camera-selector-dropdown" value="CAM-04" onChange={() => alert('Switching camera feed... (Simulated)')}>
              <option value="CAM-04">CAM-04 (NH-48 Corridor)</option>
              <option value="CAM-01">CAM-01 (Western Express Highway)</option>
              <option value="CAM-02">CAM-02 (SH-10 Khandala Ghats)</option>
            </select>
          </div>

          <button className="header-action-btn" onClick={fetchVideos} title="Refresh Feeds Database">
            <RefreshCw size={15} />
          </button>

          <button className="header-action-btn" onClick={toggleFullscreen} title={isFullscreen ? "Exit Fullscreen" : "Fullscreen"}>
            {isFullscreen ? <Minimize2 size={15} /> : <Maximize2 size={15} />}
          </button>
        </div>
      </header>

      {/* 2. Main 70/30 Grid */}
      <div className="live-mon-main-grid">
        
        {/* Left Column (70%): Live Camera Feed Viewport */}
        <section className={`live-camera-feed-card premium-card ${isFullscreen ? 'card-fullscreen' : ''}`}>
          <header className="feed-card-header">
            <div className="feed-card-title">
              <Radio size={16} className={`feed-live-icon ${isMonitoring ? 'pulsing' : ''}`} />
              <h2 className="medium-section-title">
                {videoFile ? `Feed Stream: ${videoFile}` : 'Live Camera Feed - CAM-04'}
              </h2>
            </div>
            <div className="feed-card-telemetry">
              <span>Resolution: <strong>1920x1080</strong></span>
              <span>FPS: <strong>{isMonitoring ? '30.0' : '0.0'}</strong></span>
              <span>Recording: <strong>{isMonitoring ? 'Active' : 'Standby'}</strong></span>
              <span>Latency: <strong>{isMonitoring ? '14ms' : '0ms'}</strong></span>
            </div>
          </header>

          {/* Video Viewport viewport */}
          <div className="feed-viewport-container">
            <div className="live-mon-video-card__viewport">
              {/* Perspective background simulated highway */}
              {isMonitoring && (
                <div className="live-mon-video-card__simulator-bg">
                  <div className="live-mon-video-card__road-perspective">
                    
                    {/* Scan line */}
                    <div className="live-mon-video-card__scanner-line" />

                    {/* Active detection overlay */}
                    {activeOverlay && (
                      <div 
                        className={`live-mon-video-card__bbox border-${activeOverlay.severity.toLowerCase()}`}
                        style={{
                          left: `${activeOverlay.x}%`,
                          top: `${activeOverlay.y}%`,
                          width: `${activeOverlay.w}px`,
                          height: `${activeOverlay.h}px`
                        }}
                      >
                        <span className={`live-mon-video-card__bbox-tag bg-${activeOverlay.severity.toLowerCase()}`}>
                          {activeOverlay.type} ({activeOverlay.confidence}%)
                        </span>
                      </div>
                    )}

                    {/* Telemetry HUD Grid overlays */}
                    <div className="live-mon-video-card__hud-grid" />

                    {/* Telemetry HUD indicators */}
                    <div className="live-mon-video-card__hud-overlay">
                      <span className="font-mono text-purple">CAMERA: CAM-04 / NH-48</span>
                      <span className="font-mono text-amber">GPS: 18.7342, 73.4211</span>
                      <span className="font-mono text-blue">YOLO CORE STABLE</span>
                    </div>
                  </div>
                </div>
              )}

              {/* Video Preview Player */}
              {!isMonitoring && previewUrl && (
                <video 
                  className="live-mon-video-card__video-element"
                  src={previewUrl}
                  controls
                  playsInline
                  style={{ width: "100%", height: "100%", objectFit: "contain", background: "#000", zIndex: 5 }}
                />
              )}

              {/* Offline Overlay HUD */}
              {!isMonitoring && !previewUrl && (
                <div className="live-mon-video-card__empty-state">
                  <Radio className="live-mon-video-card__empty-icon animate-pulse" size={48} />
                  <h3>Surveillance Stream Offline</h3>
                  <p>Load a recorded file or start live feed telemetry to begin distress scanning.</p>
                </div>
              )}
            </div>

            {/* Bottom Overlay Telemetry HUD */}
            {isMonitoring && (
              <div className="viewport-overlay-telemetry">
                <div className="telemetry-hud-box">
                  <span className="hud-lbl">Current Detection</span>
                  <span className="hud-val text-red font-semibold">
                    {activeOverlay ? activeOverlay.type : 'None Flagged'}
                  </span>
                </div>
                <div className="telemetry-hud-box">
                  <span className="hud-lbl">GPS Coordinates</span>
                  <span className="hud-val font-mono">18.7342, 73.4211</span>
                </div>
                <div className="telemetry-hud-box">
                  <span className="hud-lbl">Frame Number</span>
                  <span className="hud-val font-mono">{framesProcessed}</span>
                </div>
                <div className="telemetry-hud-box">
                  <span className="hud-lbl">Inference Latency</span>
                  <span className="hud-val font-mono text-purple">12.4 ms</span>
                </div>
                <div className="telemetry-hud-box">
                  <span className="hud-lbl">Model Confidence</span>
                  <span className="hud-val font-mono text-green">
                    {activeOverlay ? `${activeOverlay.confidence}%` : '0%'}
                  </span>
                </div>
              </div>
            )}
          </div>

          {/* Controls Footer */}
          <footer className="feed-controls-footer">
            <div className="controls-actions-group">
              <button 
                className={`live-mon-btn start-monitoring-btn ${isMonitoring ? 'btn-disabled' : ''}`}
                onClick={handleStart}
                disabled={isMonitoring}
              >
                <Play size={15} />
                <span>Start Monitoring</span>
              </button>

              <button 
                className={`live-mon-btn stop-monitoring-btn ${!isMonitoring ? 'btn-disabled' : ''}`}
                onClick={handleStop}
                disabled={!isMonitoring}
              >
                <Square size={15} />
                <span>Stop Monitoring</span>
              </button>
            </div>

            <div className="controls-upload-group">
              <input 
                type="file" 
                accept=".mp4,.avi,.mov,.mkv" 
                ref={fileInputRef} 
                onChange={handleFileChange} 
                style={{ display: 'none' }} 
              />
              <button className="live-mon-btn upload-feed-btn" onClick={handleUploadClick}>
                <Upload size={15} />
                <span>Upload Video</span>
              </button>
              {videoFile && (
                <span className="loaded-filename font-mono" title={videoFile}>
                  🎞️ {videoFile}
                </span>
              )}
            </div>
          </footer>
        </section>

        {/* Right Column (30%): Video Queue & Critical Alerts */}
        <aside className="live-mon-sidebar-column">
          
          {/* Top Card: Video Queue */}
          <article className="live-queue-card premium-card">
            <header className="card-header-row">
              <Video size={16} className="text-purple" />
              <h3 className="medium-section-title" style={{ fontSize: '15px' }}>Surveillance Video Queue</h3>
            </header>

            <div className="queue-card-body">
              {/* Drag and Drop area */}
              <div 
                className={`queue-upload-dropzone ${isDragging ? 'dragging' : ''} ${isUploading ? 'uploading' : ''}`}
                onDragOver={handleDragOver}
                onDragLeave={handleDragLeave}
                onDrop={handleDrop}
                onClick={handleUploadClick}
              >
                {isUploading ? (
                  <div className="upload-loading-view" style={{ width: '100%' }}>
                    <Loader2 className="animate-spin text-purple" size={28} />
                    <span>Uploading Video... {uploadProgress}%</span>
                    <div 
                      className="upload-progress-bar-container" 
                      style={{ 
                        width: '100%', 
                        height: '4px', 
                        background: 'rgba(255,255,255,0.1)', 
                        borderRadius: '2px', 
                        marginTop: '8px', 
                        overflow: 'hidden' 
                      }}
                    >
                      <div 
                        className="upload-progress-bar" 
                        style={{ 
                          width: `${uploadProgress}%`, 
                          height: '100%', 
                          background: '#8B5CF6', 
                          transition: 'width 0.1s' 
                        }} 
                      />
                    </div>
                  </div>
                ) : (
                  <div className="upload-prompt-view">
                    <Upload className="upload-icon" size={28} />
                    <span className="upload-prompt-title">Drag video feed here</span>
                    <span className="upload-prompt-desc">or click to browse local files</span>
                  </div>
                )}
              </div>

              {uploadError && <p className="upload-error-tag font-mono">{uploadError}</p>}

              {/* Videos list database */}
              <div className="queue-video-list-container">
                <span className="list-title font-mono">Surveillance Library Database</span>
                {fetchError ? (
                  <p className="fetch-error-tag font-mono">{fetchError}</p>
                ) : uploadedVideos.length === 0 ? (
                  <div className="empty-videos-queue">
                    <Video size={18} style={{ opacity: 0.4 }} />
                    <span>No uploads catalogued in database.</span>
                  </div>
                ) : (
                  <div className="videos-queue-list">
                    {uploadedVideos.map((video) => {
                      const isCurrent = videoFile === video.filename;
                      const statusClass = `status-${video.processing_status.toLowerCase()}`;
                      
                      return (
                        <div 
                          key={video.id} 
                          className={`queue-video-row ${isCurrent ? 'active' : ''}`}
                          onClick={() => handleSelectVideo(video)}
                        >
                          <div className="video-row-details">
                            <span className="video-row-title font-mono" title={video.filename}>
                              {video.filename}
                            </span>
                            <span className="video-row-meta font-mono">
                              {new Date(video.upload_timestamp).toLocaleString('en-IN')}
                            </span>
                          </div>
                          <div className="video-row-actions">
                            <span className={`status-tag-pill ${statusClass}`}>
                              {video.processing_status}
                            </span>
                            <button 
                              className="video-delete-action-btn"
                              onClick={(e) => handleDeleteVideo(video.id, e)}
                              title="Revoke video"
                            >
                              <Trash2 size={13} />
                            </button>
                          </div>
                        </div>
                      );
                    })}
                  </div>
                )}
              </div>
            </div>
          </article>

          {/* Bottom Card: Critical Alerts */}
          <article className="live-alerts-card premium-card">
            <header className="card-header-row">
              <AlertTriangle size={16} className="text-red animate-pulse" />
              <h3 className="medium-section-title" style={{ fontSize: '15px' }}>Critical Warnings</h3>
            </header>

            <div className="alerts-card-body scrollable-y">
              {alerts.length === 0 ? (
                <div className="empty-alerts-view">
                  <Check size={28} className="success-icon" />
                  <span>No critical distress warnings pending</span>
                </div>
              ) : (
                <div className="alerts-elements-list">
                  {alerts.map(alert => (
                    <div key={alert.id} className="alerts-item-card" style={{ borderLeft: '3.5px solid var(--danger)' }}>
                      <div className="alert-item-details">
                        <div className="alert-item-header">
                          <span className="alert-item-id font-mono">{alert.id}</span>
                          <span className="alert-item-time font-mono">[{alert.time}]</span>
                        </div>
                        <span className="alert-item-title font-semibold">{alert.distressType}</span>
                        <span className="alert-item-location">📍 {alert.location}</span>
                      </div>
                      <button 
                        className="alert-item-acknowledge-btn"
                        onClick={() => handleAcknowledgeAlert(alert.id)}
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

      {/* 3. Real-Time Detection Feed */}
      <section className="live-realtime-feed-row">
        <RealTimeDetectionFeed 
          detections={feedDetections} 
          isMonitoringActive={isMonitoring} 
        />
      </section>

      {/* 4. Detection History Section */}
      <section className="live-detection-history-card premium-card">
        <header className="history-section-header">
          <div className="section-title-group">
            <History size={18} style={{ color: 'var(--accent-blue)' }} />
            <h2 className="medium-section-title">Detection History Logs</h2>
          </div>
          <div className="history-search-row">
            <div className="search-box">
              <Search size={14} className="search-icon" />
              <input type="text" placeholder="Search history..." disabled />
            </div>
            <select className="severity-filter" disabled>
              <option>Severity: All</option>
            </select>
          </div>
        </header>

        <div className="history-table-viewport scrollable-x">
          <table className="history-data-table">
            <thead>
              <tr>
                <th>Detection ID</th>
                <th>Timestamp</th>
                <th>Location Landmark</th>
                <th>Distress Category</th>
                <th>Severity</th>
                <th>Confidence</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              {history.map(row => (
                <tr key={row.id} className="table-row-hover">
                  <td className="font-mono font-bold text-primary-text">{row.id}</td>
                  <td>{row.time}</td>
                  <td>{row.location}</td>
                  <td>{row.distressType}</td>
                  <td>
                    <span className={`live-mon-badge live-mon-badge--${row.severity.toLowerCase()}`}>
                      {row.severity}
                    </span>
                  </td>
                  <td className="font-mono">{row.confidence}%</td>
                  <td>
                    <span className={`live-mon-status-badge live-mon-status-badge--${row.status.toLowerCase()}`}>
                      {row.status}
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      {/* 5. Bottom Analytics KPI row */}
      <footer className="live-analytics-footer-grid">
        <article className="premium-kpi-card premium-card">
          <div className="kpi-header-row">
            <div className="kpi-icon-container" style={{ backgroundColor: 'rgba(59,130,246,0.1)' }}>
              <Activity size={18} style={{ color: '#3B82F6' }} />
            </div>
            <span className="kpi-title-label">Total Detections</span>
          </div>
          <p className="kpi-value-num">{distressesCount}</p>
          <div className="kpi-card-footer">
            <span className="comparison-lbl">distresses flagged</span>
            <div className="kpi-sparkline">
              <svg width="60" height="24">
                <polyline fill="none" stroke="var(--accent-blue)" strokeWidth="1.8" points="0,15 10,20 20,8 30,18 40,12 50,5 60,10" />
              </svg>
            </div>
          </div>
        </article>

        <article className="premium-kpi-card premium-card">
          <div className="kpi-header-row">
            <div className="kpi-icon-container" style={{ backgroundColor: 'rgba(16,185,129,0.1)' }}>
              <Cpu size={18} style={{ color: '#10B981' }} />
            </div>
            <span className="kpi-title-label">Average Confidence</span>
          </div>
          <p className="kpi-value-num">{avgConfidence}%</p>
          <div className="kpi-card-footer">
            <span className="comparison-lbl">accuracy rating</span>
            <div className="kpi-sparkline">
              <svg width="60" height="24">
                <polyline fill="none" stroke="var(--success)" strokeWidth="1.8" points="0,20 10,12 20,18 30,10 40,15 50,3 60,6" />
              </svg>
            </div>
          </div>
        </article>

        <article className="premium-kpi-card premium-card">
          <div className="kpi-header-row">
            <div className="kpi-icon-container" style={{ backgroundColor: 'rgba(245,158,11,0.1)' }}>
              <Tv size={18} style={{ color: '#F59E0B' }} />
            </div>
            <span className="kpi-title-label">Average FPS</span>
          </div>
          <p className="kpi-value-num">{isMonitoring ? '30.0' : '0.0'} FPS</p>
          <div className="kpi-card-footer">
            <span className="comparison-lbl">video decode rate</span>
            <div className="kpi-sparkline">
              <svg width="60" height="24">
                <polyline fill="none" stroke="var(--warning)" strokeWidth="1.8" points="0,18 10,15 20,20 30,12 40,8 50,5 60,2" />
              </svg>
            </div>
          </div>
        </article>

        <article className="premium-kpi-card premium-card">
          <div className="kpi-header-row">
            <div className="kpi-icon-container" style={{ backgroundColor: 'rgba(139,92,246,0.1)' }}>
              <Loader2 size={18} style={{ color: '#8B5CF6' }} className={isMonitoring ? 'animate-spin' : ''} />
            </div>
            <span className="kpi-title-label">Processing Time</span>
          </div>
          <p className="kpi-value-num">{isMonitoring ? '12.4 ms' : '0.0 ms'}</p>
          <div className="kpi-card-footer">
            <span className="comparison-lbl">inference duration</span>
            <div className="kpi-sparkline">
              <svg width="60" height="24">
                <polyline fill="none" stroke="#8B5CF6" strokeWidth="1.8" points="0,5 10,12 20,8 30,15 40,18 50,22 60,20" />
              </svg>
            </div>
          </div>
        </article>
      </footer>

      <div style={{ display: 'none' }}>
        {criticalAlertsCount} {rightTab}
        <button onClick={() => setRightTab('stats')} />
      </div>

    </div>
  );
}
