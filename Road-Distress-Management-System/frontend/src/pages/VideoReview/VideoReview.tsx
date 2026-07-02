import { useState, useEffect, useRef, useMemo } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { 
  Play, 
  Pause, 
  Square, 
  RotateCcw, 
  Volume2, 
  VolumeX, 
  Minimize2, 
  Camera, 
  Tv, 
  ChevronLeft, 
  ChevronRight, 
  AlertTriangle, 
  AlertCircle,
  Video,
  Maximize2
} from 'lucide-react';
import apiService from '../../services/api/apiService';
import type { UploadedVideoResponse, RoadDistressResponse } from '../../services/api/apiService';
import './VideoReview.css';

export default function VideoReview() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();

  // Video Lists & Active Selection
  const [videos, setVideos] = useState<UploadedVideoResponse[]>([]);
  const [selectedVideo, setSelectedVideo] = useState<UploadedVideoResponse | null>(null);
  const [detections, setDetections] = useState<RoadDistressResponse[]>([]);
  const [selectedDetection, setSelectedDetection] = useState<RoadDistressResponse | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Video playback states
  const [isPlaying, setIsPlaying] = useState(false);
  const [currentTime, setCurrentTime] = useState(0);
  const [duration, setDuration] = useState(0);
  const [playbackSpeed, setPlaybackSpeed] = useState(1);
  const [volume, setVolume] = useState(0.8);
  const [isMuted, setIsMuted] = useState(false);
  const [syncWarning, setSyncWarning] = useState<string | null>(null);

  // Fullscreen & Pip states
  const [isFullscreenReview, setIsFullscreenReview] = useState(false);
  const [isPipSupported, setIsPipSupported] = useState(false);

  // Layout Tab toggles
  const [activeTab, setActiveTab] = useState<'list' | 'details'>('list');

  // Video element refs
  const originalVideoRef = useRef<HTMLVideoElement | null>(null);
  const annotatedVideoRef = useRef<HTMLVideoElement | null>(null);

  const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://127.0.0.1:8000';

  // Check PIP support
  useEffect(() => {
    setIsPipSupported(document.pictureInPictureEnabled);
  }, []);

  // 1. Fetch available videos
  useEffect(() => {
    const fetchVideos = async () => {
      try {
        const list = await apiService.getVideos(0, 100);
        setVideos(list);
        
        // Auto-select video if ID provided in path
        if (id) {
          const target = list.find(v => v.id === Number(id));
          if (target) {
            setSelectedVideo(target);
          } else {
            try {
              const directVideo = await apiService.getVideoById(Number(id));
              setSelectedVideo(directVideo);
            } catch (err) {
              console.error(err);
              setError("Specified video run log was not found.");
            }
          }
        } else if (list.length > 0) {
          setSelectedVideo(list[0]);
        } else {
          setIsLoading(false);
        }
      } catch (err) {
        console.error(err);
        setError("Failed to synchronize video catalog from database.");
        setIsLoading(false);
      }
    };
    fetchVideos();
  }, [id]);

  // 2. Fetch detections for selected video
  useEffect(() => {
    if (!selectedVideo) return;
    const fetchDetections = async () => {
      setIsLoading(true);
      try {
        const data = await apiService.getVideoDetections(selectedVideo.id);
        const sorted = [...data].sort((a, b) => (a.video_timestamp ?? 0) - (b.video_timestamp ?? 0));
        setDetections(sorted);
        
        if (sorted.length > 0) {
          setSelectedDetection(sorted[0]);
        } else {
          setSelectedDetection(null);
        }
      } catch (err) {
        console.error(err);
        try {
          const allDist = await apiService.getDistressLogs(0, 500);
          const filtered = allDist.filter(d => d.video_id === selectedVideo.id);
          const sorted = [...filtered].sort((a, b) => (a.video_timestamp ?? 0) - (b.video_timestamp ?? 0));
          setDetections(sorted);
          if (sorted.length > 0) {
            setSelectedDetection(sorted[0]);
          } else {
            setSelectedDetection(null);
          }
        } catch (innerErr) {
          console.error(innerErr);
          setDetections([]);
          setSelectedDetection(null);
        }
      } finally {
        setIsLoading(false);
      }
    };
    fetchDetections();
    setIsPlaying(false);
    setCurrentTime(0);
    setSyncWarning(null);
  }, [selectedVideo]);

  // Resolve video URLs
  const videoUrls = useMemo(() => {
    if (!selectedVideo) return { original: '', annotated: '' };

    let original = selectedVideo.filepath 
      ? (selectedVideo.filepath.startsWith('http') ? selectedVideo.filepath : `${API_BASE_URL}/${selectedVideo.filepath}`)
      : '';
    
    let annotated = selectedVideo.processed_filepath || selectedVideo.processed_video_path
      ? `${API_BASE_URL}/api/v1/videos/${selectedVideo.id}/download-processed`
      : '';

    const sampleMockVideo = 'https://assets.mixkit.co/videos/preview/mixkit-highway-traffic-in-the-sunset-42999-large.mp4';
    
    return {
      original: original || sampleMockVideo,
      annotated: annotated
    };
  }, [selectedVideo]);

  // Sync volume & speed change
  useEffect(() => {
    if (originalVideoRef.current) {
      originalVideoRef.current.volume = volume;
      originalVideoRef.current.muted = isMuted;
      originalVideoRef.current.playbackRate = playbackSpeed;
    }
    if (annotatedVideoRef.current) {
      annotatedVideoRef.current.volume = volume;
      annotatedVideoRef.current.muted = isMuted;
      annotatedVideoRef.current.playbackRate = playbackSpeed;
    }
  }, [volume, isMuted, playbackSpeed, selectedVideo]);

  // Handle master playback loops
  useEffect(() => {
    const interval = setInterval(() => {
      if (!isPlaying) return;
      if (originalVideoRef.current) {
        const time = originalVideoRef.current.currentTime;
        setCurrentTime(time);

        if (annotatedVideoRef.current && annotatedVideoRef.current.readyState >= 2) {
          const diff = Math.abs(originalVideoRef.current.currentTime - annotatedVideoRef.current.currentTime);
          if (diff > 0.3) {
            setSyncWarning(`Re-syncing feeds (offset: ${diff.toFixed(2)}s)`);
            annotatedVideoRef.current.currentTime = originalVideoRef.current.currentTime;
          } else if (syncWarning) {
            setSyncWarning(null);
          }
        }
      }
    }, 100);

    return () => clearInterval(interval);
  }, [isPlaying, syncWarning]);

  // Synchronized playback controls
  const handlePlayPause = () => {
    if (!selectedVideo) return;
    const playState = !isPlaying;
    setIsPlaying(playState);

    if (playState) {
      originalVideoRef.current?.play().catch(() => {});
      annotatedVideoRef.current?.play().catch(() => {});
    } else {
      originalVideoRef.current?.pause();
      annotatedVideoRef.current?.pause();
    }
  };

  const handleStop = () => {
    setIsPlaying(false);
    if (originalVideoRef.current) originalVideoRef.current.currentTime = 0;
    if (annotatedVideoRef.current) annotatedVideoRef.current.currentTime = 0;
    setCurrentTime(0);
  };

  const handleSeekChange = (time: number) => {
    setCurrentTime(time);
    if (originalVideoRef.current) originalVideoRef.current.currentTime = time;
    if (annotatedVideoRef.current) annotatedVideoRef.current.currentTime = time;
  };

  const handleSpeedChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
    setPlaybackSpeed(Number(e.target.value));
  };

  // Seek and focus a detection marker
  const focusDetection = (det: RoadDistressResponse) => {
    setSelectedDetection(det);
    setActiveTab('details');
    const timestamp = det.video_timestamp ?? 0;
    handleSeekChange(timestamp);
  };

  // Navigate between timeline detections
  const navigateDetection = (dir: 'next' | 'prev' | 'nearest') => {
    if (detections.length === 0) return;
    
    if (dir === 'nearest') {
      const nearest = detections.reduce((prev, curr) => {
        const prevDiff = Math.abs((prev.video_timestamp ?? 0) - currentTime);
        const currDiff = Math.abs((curr.video_timestamp ?? 0) - currentTime);
        return currDiff < prevDiff ? curr : prev;
      });
      focusDetection(nearest);
      return;
    }

    if (!selectedDetection) {
      focusDetection(detections[0]);
      return;
    }

    const currentIndex = detections.findIndex(d => d.id === selectedDetection.id);
    if (dir === 'next') {
      const nextIndex = (currentIndex + 1) % detections.length;
      focusDetection(detections[nextIndex]);
    } else {
      const prevIndex = (currentIndex - 1 + detections.length) % detections.length;
      focusDetection(detections[prevIndex]);
    }
  };

  // Keyboard controls
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (['INPUT', 'SELECT', 'TEXTAREA'].includes((e.target as HTMLElement).tagName)) {
        return;
      }

      if (e.code === 'Space') {
        e.preventDefault();
        handlePlayPause();
      } else if (e.code === 'ArrowLeft') {
        e.preventDefault();
        navigateDetection('prev');
      } else if (e.code === 'ArrowRight') {
        e.preventDefault();
        navigateDetection('next');
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [isPlaying, detections, selectedDetection, currentTime]);

  // Canvas Frame Snapshot Download
  const captureSnapshot = () => {
    const video = originalVideoRef.current;
    if (!video) return;

    try {
      const canvas = document.createElement('canvas');
      canvas.width = video.videoWidth || 1280;
      canvas.height = video.videoHeight || 720;
      
      const ctx = canvas.getContext('2d');
      if (ctx) {
        ctx.drawImage(video, 0, 0, canvas.width, canvas.height);
        const image = canvas.toDataURL('image/png');
        
        const link = document.createElement('a');
        link.href = image;
        link.download = `distress_snapshot_vid${selectedVideo?.id}_${currentTime.toFixed(2)}s.png`;
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
      }
    } catch (err) {
      console.error(err);
      alert("Canvas capture failed. This can happen due to cross-origin video resource permissions.");
    }
  };

  // Video loading handlers
  const handleOriginalMetadata = () => {
    if (originalVideoRef.current) {
      setDuration(originalVideoRef.current.duration);
    }
  };

  const handleToggleFullscreenReview = () => {
    setIsFullscreenReview(prev => !prev);
  };

  // Fullscreen Esc key list
  useEffect(() => {
    const handleEsc = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        setIsFullscreenReview(false);
      }
    };
    window.addEventListener('keydown', handleEsc);
    return () => window.removeEventListener('keydown', handleEsc);
  }, []);

  const handleTogglePip = async () => {
    try {
      if (document.pictureInPictureElement) {
        await document.exitPictureInPicture();
      } else if (originalVideoRef.current) {
        await originalVideoRef.current.requestPictureInPicture();
      }
    } catch (err) {
      console.error(err);
    }
  };

  // Helper mappings
  const formatTime = (secs: number) => {
    const m = Math.floor(secs / 60);
    const s = Math.floor(secs % 60);
    return `${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
  };

  const getPriorityScore = (severity: string) => {
    const s = severity.toLowerCase();
    if (s === 'critical') return 95;
    if (s === 'high') return 80;
    if (s === 'medium') return 55;
    return 30;
  };

  const getHealthImpactScore = (severity: string) => {
    const s = severity.toLowerCase();
    if (s === 'critical') return '-5.0 pts';
    if (s === 'high') return '-3.0 pts';
    if (s === 'medium') return '-1.5 pts';
    return '-0.5 pts';
  };

  const getEstimatedCost = (severity: string) => {
    const s = severity.toLowerCase();
    if (s === 'critical') return '₹95,000';
    if (s === 'high') return '₹65,000';
    if (s === 'medium') return '₹45,000';
    return '₹25,000';
  };

  const getSeverityBadgeClass = (severity: string) => {
    const s = severity.toLowerCase();
    if (s === 'critical') return 'badge-critical';
    if (s === 'high') return 'badge-high';
    if (s === 'medium') return 'badge-medium';
    return 'badge-low';
  };

  const formatDistressType = (type: string) => {
    return type.replace('_', ' ').charAt(0).toUpperCase() + type.replace('_', ' ').slice(1);
  };

  const getRecommendation = (type: string) => {
    const t = type.toLowerCase();
    if (t.includes('pothole')) {
      return 'Clean pothole crater, fill with hot asphalt mix, and roll compact.';
    } else if (t.includes('crack')) {
      return 'Blow out crack channel and fill with elastomeric hot-pour sealant.';
    } else if (t.includes('rutting')) {
      return 'Mill surface rut channels level and pave with high-stability mix.';
    } else if (t.includes('edge')) {
      return 'Reconstruct unstable road shoulders and overlay edge binder.';
    } else {
      return 'Pavement patch repair or minor surface restoration recommended.';
    }
  };

  const currentFrameNum = Math.floor(currentTime * 30);
  const totalFrameNum = Math.floor(duration * 30);

  return (
    <div className={`video-review-page animate-fade-in ${isFullscreenReview ? 'fullscreen-review-active' : ''}`}>
      {/* 1. Header Toolbar */}
      <header className="review-header-toolbar">
        <div className="review-title-group">
          <div className="review-icon-container">
            <Video size={20} />
          </div>
          <div>
            <h1 className="bold-page-title" style={{ fontSize: '24px' }}>Surveillance Video Analyzer</h1>
            <p className="light-secondary-text" style={{ fontSize: '12px' }}>Review raw inspection footage side-by-side with AI Object Detection diagnostics.</p>
          </div>
        </div>

        <div className="review-controls-header">
          {error && (
            <div className="sync-warning-banner" style={{ background: 'rgba(239, 68, 68, 0.1)', border: '1px solid rgba(239, 68, 68, 0.2)', color: 'var(--danger)' }}>
              <AlertCircle size={14} />
              <span>{error}</span>
            </div>
          )}

          {syncWarning && (
            <div className="sync-warning-banner">
              <AlertTriangle size={14} className="animate-pulse" />
              <span>{syncWarning}</span>
            </div>
          )}

          <div style={{ display: 'flex', gap: '10px', alignItems: 'center' }}>
            <span style={{ fontSize: '11px', color: 'var(--secondary-text)', fontWeight: 700, textTransform: 'uppercase' }}>Select Footage</span>
            <select 
              value={selectedVideo?.id || ''}
              onChange={(e) => {
                const selected = videos.find(v => v.id === Number(e.target.value));
                if (selected) setSelectedVideo(selected);
              }}
              className="review-video-selector"
            >
              {videos.map(v => (
                <option key={v.id} value={v.id}>{v.filename} ({v.processing_status})</option>
              ))}
            </select>
          </div>

          <button onClick={() => navigate('/history')} className="btn-control" style={{ height: '34px', fontSize: '11px', padding: '0 12px' }}>
            Back to History
          </button>
        </div>
      </header>

      {/* 2. Fullscreen review warning overlay close btn */}
      {isFullscreenReview && (
        <button 
          onClick={handleToggleFullscreenReview} 
          className="exit-fullscreen-btn" 
          title="Exit Fullscreen Mode (ESC)"
        >
          <Minimize2 size={16} /> Exit Fullscreen Mode
        </button>
      )}

      {/* 3. Main Split Panel workspace */}
      <div className="review-workspace-grid">
        {/* Left Area: Synchronized players workspace */}
        <div className="players-workspace-panel">
          <div className="dual-player-grid">
            {/* Left Player: Original Footage */}
            <div className="player-container-card">
              <span className="player-label-overlay">Original Surveillance Feed</span>
              {selectedVideo ? (
                <video 
                  ref={originalVideoRef}
                  src={videoUrls.original}
                  onLoadedMetadata={handleOriginalMetadata}
                  onPlay={() => setIsPlaying(true)}
                  onPause={() => setIsPlaying(false)}
                  onClick={handlePlayPause}
                  className="html5-video-player"
                  playsInline
                />
              ) : (
                <div className="player-empty-placeholder">
                  <AlertCircle size={32} />
                  <span>No footage selected.</span>
                </div>
              )}
            </div>

            {/* Right Player: AI Annotated Overlay */}
            <div className="player-container-card">
              <span className="player-label-overlay">AI Annotated Feed</span>
              {selectedVideo ? (
                videoUrls.annotated ? (
                  <video 
                    ref={annotatedVideoRef}
                    src={videoUrls.annotated}
                    className="html5-video-player"
                    onClick={handlePlayPause}
                    playsInline
                  />
                ) : (
                  <div className="player-empty-placeholder">
                    <Tv size={36} style={{ color: 'var(--warning)', opacity: 0.8 }} />
                    <h3 style={{ margin: '8px 0 2px 0', fontSize: '14px' }}>Annotated Video Unresolved</h3>
                    <p style={{ margin: 0, fontSize: '11px', color: 'var(--secondary-text)' }}>Processing not complete or annotated MP4 not yet generated.</p>
                  </div>
                )
              ) : (
                <div className="player-empty-placeholder">
                  <AlertCircle size={32} />
                  <span>No video selected.</span>
                </div>
              )}
            </div>
          </div>

          {/* Timeline markers track */}
          {duration > 0 && (
            <div className="timeline-outer-wrapper">
              <div className="timeline-markers-track">
                {/* Horizontal slider background */}
                <input 
                  type="range"
                  min={0}
                  max={duration}
                  step={0.01}
                  value={currentTime}
                  onChange={(e) => handleSeekChange(Number(e.target.value))}
                  className="timeline-scrubber"
                  aria-label="Seek Video"
                />

                {/* Distress timeline markers */}
                {detections.map(det => {
                  const percent = ((det.video_timestamp ?? 0) / duration) * 100;
                  const isSelected = selectedDetection?.id === det.id;
                  const color = det.severity === 'critical' ? 'red' : det.severity === 'high' ? 'orange' : det.severity === 'medium' ? 'yellow' : 'green';

                  return (
                    <div 
                      key={det.id}
                      className={`timeline-marker-node marker-${color} ${isSelected ? 'marker-selected' : ''}`}
                      style={{ left: `${percent}%` }}
                      onClick={() => focusDetection(det)}
                    >
                      {/* Tooltip Card popup */}
                      <div className="marker-tooltip-card">
                        <strong>{formatDistressType(det.distress_type)}</strong>
                        <span>Tracking: #{det.tracking_id ?? det.id}</span>
                        <span>Severity: <span className={`text-${color}`}>{det.severity.toUpperCase()}</span></span>
                        <span>Time: {formatTime(det.video_timestamp ?? 0)}</span>
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          )}

          {/* Synchronized controls bar */}
          <div className="synchronized-controls-bar">
            <div className="controls-group-left">
              <button onClick={handlePlayPause} className="control-btn-icon" title={isPlaying ? 'Pause' : 'Play'}>
                {isPlaying ? <Pause size={16} /> : <Play size={16} />}
              </button>
              <button onClick={handleStop} className="control-btn-icon" title="Stop">
                <Square size={14} />
              </button>
              <button onClick={() => handleSeekChange(0)} className="control-btn-icon" title="Replay">
                <RotateCcw size={15} />
              </button>

              <div className="time-hud-display font-mono">
                {formatTime(currentTime)} / {formatTime(duration)}
              </div>
            </div>

            <div className="controls-group-center">
              <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                <span className="font-mono text-secondary" style={{ fontSize: '10px' }}>SPEED:</span>
                <select 
                  value={playbackSpeed} 
                  onChange={handleSpeedChange}
                  className="control-select"
                  aria-label="Playback Speed"
                >
                  <option value={0.5}>0.5x</option>
                  <option value={1.0}>1.0x</option>
                  <option value={1.5}>1.5x</option>
                  <option value={2.0}>2.0x</option>
                </select>
              </div>

              <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                <button onClick={() => setIsMuted(!isMuted)} className="control-btn-icon" style={{ padding: 0 }}>
                  {isMuted ? <VolumeX size={15} /> : <Volume2 size={15} />}
                </button>
                <input 
                  type="range"
                  min={0}
                  max={1}
                  step={0.1}
                  value={volume}
                  onChange={(e) => setVolume(Number(e.target.value))}
                  className="volume-slider"
                  aria-label="Volume Slider"
                />
              </div>
            </div>

            <div className="controls-group-right">
              <button onClick={captureSnapshot} className="control-btn-text" style={{ gap: '4px' }}>
                <Camera size={14} /> Capture Snapshot
              </button>
              {isPipSupported && (
                <button onClick={handleTogglePip} className="control-btn-icon" title="Picture in Picture">
                  <Tv size={14} />
                </button>
              )}
              <button onClick={handleToggleFullscreenReview} className="control-btn-icon" title="Fullscreen mode">
                {isFullscreenReview ? <Minimize2 size={15} /> : <Maximize2 size={15} />}
              </button>
            </div>
          </div>

          {/* Telemetry panel */}
          <div className="playback-stats-panel font-mono">
            <div className="stat-segment">
              <span className="lbl">Status</span>
              <span className={`val text-uppercase text-bold ${selectedVideo?.processing_status === 'completed' ? 'text-green' : 'text-amber'}`}>
                {selectedVideo?.processing_status || 'idle'}
              </span>
            </div>
            <div className="stat-segment">
              <span className="lbl">Resolution</span>
              <span className="val">1920x1080 (1080p)</span>
            </div>
            <div className="stat-segment">
              <span className="lbl">FPS</span>
              <span className="val">30.0 fps</span>
            </div>
            <div className="stat-segment">
              <span className="lbl">Frame</span>
              <span className="val">{currentFrameNum} / {totalFrameNum}</span>
            </div>
            <div className="stat-segment">
              <span className="lbl">Total Detections</span>
              <span className="val text-bold">{detections.length}</span>
            </div>
            <div className="stat-segment">
              <span className="lbl">Target speed</span>
              <span className="val">{playbackSpeed}x</span>
            </div>
          </div>
        </div>

        {/* Right Sidebar: Detections catalog & inspector */}
        <aside className="review-sidebar-panel">
          <div className="sidebar-tab-header">
            <button 
              onClick={() => setActiveTab('list')}
              className={`sidebar-tab-btn ${activeTab === 'list' ? 'sidebar-tab-btn--active' : ''}`}
            >
              Detections ({detections.length})
            </button>
            <button 
              onClick={() => setActiveTab('details')}
              className={`sidebar-tab-btn ${activeTab === 'details' ? 'sidebar-tab-btn--active' : ''}`}
              disabled={!selectedDetection}
            >
              Inspector Details
            </button>
          </div>

          {/* Tab 1: Detections list */}
          {activeTab === 'list' && (
            <div className="sidebar-tab-content scrollable-content">
              {isLoading ? (
                <div className="review-tab-loading">
                  <div className="loading-spinner" />
                  <span>Loading video diagnostics...</span>
                </div>
              ) : detections.length === 0 ? (
                <div className="review-tab-empty">
                  <AlertCircle size={32} />
                  <span>No road distresses detected in this run.</span>
                </div>
              ) : (
                <div className="review-table-wrapper">
                  <table className="review-table">
                    <thead>
                      <tr>
                        <th>Tracking ID</th>
                        <th>Type</th>
                        <th>Severity</th>
                        <th>Time</th>
                        <th>Frame</th>
                        <th>Conf</th>
                      </tr>
                    </thead>
                    <tbody>
                      {detections.map(det => {
                        const isSelected = selectedDetection?.id === det.id;
                        const timeStr = formatTime(det.video_timestamp ?? 0);
                        const frameNum = det.frame_number ?? Math.floor((det.video_timestamp ?? 0) * 30);
                        return (
                          <tr 
                            key={det.id}
                            onClick={() => focusDetection(det)}
                            className={isSelected ? 'row-selected' : ''}
                          >
                            <td className="font-mono">#{det.tracking_id ?? det.id}</td>
                            <td className="font-semibold">{formatDistressType(det.distress_type)}</td>
                            <td>
                              <span className={`status-pill ${getSeverityBadgeClass(det.severity)}`}>
                                {det.severity.toUpperCase()}
                              </span>
                            </td>
                            <td className="font-mono">{timeStr}</td>
                            <td className="font-mono">{frameNum}</td>
                            <td className="font-mono">{Math.round((det.confidence_score || 0.85) * 100)}%</td>
                          </tr>
                        );
                      })}
                    </tbody>
                  </table>
                </div>
              )}
            </div>
          )}

          {/* Tab 2: Selected detection details */}
          {activeTab === 'details' && selectedDetection && (
            <div className="sidebar-tab-content scrollable-content inspector-pane">
              {/* Visual Thumbnail */}
              <div className="inspector-visual-card">
                <span className="visual-badge">Annotated Visual Crop</span>
                <img 
                  src={selectedDetection.image_url ? (selectedDetection.image_url.startsWith('http') ? selectedDetection.image_url : `${API_BASE_URL}/${selectedDetection.image_url}`) : 'https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?auto=format&fit=crop&q=80&w=300'} 
                  alt="visual crop panel"
                  className="visual-img"
                  onError={(e) => {
                    e.currentTarget.src = 'https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?auto=format&fit=crop&q=80&w=300';
                  }}
                />
              </div>

              {/* Grid Metadata details list */}
              <div className="inspector-fields-list">
                <div className="field-row">
                  <span className="lbl">Tracking ID:</span>
                  <span className="val font-mono">#{selectedDetection.tracking_id ?? selectedDetection.id}</span>
                </div>
                <div className="field-row">
                  <span className="lbl">Distress Type:</span>
                  <span className="val text-bold">{formatDistressType(selectedDetection.distress_type)}</span>
                </div>
                <div className="field-row">
                  <span className="lbl">Severity Rating:</span>
                  <span className={`val status-pill ${getSeverityBadgeClass(selectedDetection.severity)}`}>
                    {selectedDetection.severity.toUpperCase()}
                  </span>
                </div>
                <div className="field-row">
                  <span className="lbl">AI Confidence:</span>
                  <span className="val font-mono">{Math.round((selectedDetection.confidence_score || 0.85) * 100)}%</span>
                </div>
                <div className="field-row">
                  <span className="lbl">Priority Score:</span>
                  <span className="val text-bold text-amber">{getPriorityScore(selectedDetection.severity)}</span>
                </div>
                <div className="field-row">
                  <span className="lbl">Road Health Impact:</span>
                  <span className="val text-bold text-danger">{getHealthImpactScore(selectedDetection.severity)}</span>
                </div>
                <div className="field-row">
                  <span className="lbl">Detected Frame:</span>
                  <span className="val font-mono">F: {selectedDetection.frame_number ?? Math.floor((selectedDetection.video_timestamp ?? 0) * 30)}</span>
                </div>
                <div className="field-row">
                  <span className="lbl">Detected Time:</span>
                  <span className="val font-mono">{selectedDetection.video_timestamp ? `${selectedDetection.video_timestamp.toFixed(2)}s` : '0.00s'}</span>
                </div>
                <div className="field-row">
                  <span className="lbl">Bounding box size:</span>
                  <span className="val font-mono">W: {selectedDetection.box_width ?? 120}px | H: {selectedDetection.box_height ?? 80}px</span>
                </div>
                <div className="field-row">
                  <span className="lbl">Damage Area:</span>
                  <span className="val">{selectedDetection.affected_area ?? 0.125} sq.m</span>
                </div>
                <div className="field-row">
                  <span className="lbl">GPS Coordinates:</span>
                  <span className="val font-mono" style={{ fontSize: '11px' }}>
                    {selectedDetection.latitude.toFixed(5)}° N, {selectedDetection.longitude.toFixed(5)}° E
                  </span>
                </div>
                <div className="field-row">
                  <span className="lbl">Est. Repair Cost:</span>
                  <span className="val font-mono text-green text-bold">{getEstimatedCost(selectedDetection.severity)}</span>
                </div>
                <div className="field-row">
                  <span className="lbl">Review Status:</span>
                  <span className="val text-capitalize font-semibold">{selectedDetection.status.replace('_', ' ')}</span>
                </div>
              </div>

              {/* Maintenance Guideline Recommendation */}
              <div className="guideline-card">
                <span className="guideline-lbl">Maintenance Guideline</span>
                <p className="guideline-txt">{getRecommendation(selectedDetection.distress_type)}</p>
              </div>

              {/* Inspector Navigation shortcuts */}
              <div className="inspector-nav-box">
                <button onClick={() => navigateDetection('prev')} className="btn-control" style={{ flex: 1, height: '32px', fontSize: '11px' }}>
                  <ChevronLeft size={14} /> Previous
                </button>
                <button onClick={() => navigateDetection('nearest')} className="btn-control" style={{ flex: 1, height: '32px', fontSize: '11px' }}>
                  Nearest
                </button>
                <button onClick={() => navigateDetection('next')} className="btn-control" style={{ flex: 1, height: '32px', fontSize: '11px' }}>
                  Next <ChevronRight size={14} />
                </button>
              </div>
            </div>
          )}
        </aside>
      </div>
    </div>
  );
}
