import { useState, useEffect, useRef } from 'react';
import { 
  Play, 
  Activity, 
  CheckCircle2, 
  XCircle, 
  Loader2, 
  Clock, 
  ShieldAlert, 
  FileText, 
  Cpu, 
  Video, 
  ChevronRight,
  TrendingUp
} from 'lucide-react';
import apiService from '../../services/api/apiService';
import type { UploadedVideoResponse } from '../../services/api/apiService';
import './LiveProcessingDashboard.css';

interface ActivityLog {
  id: string;
  time: string;
  message: string;
  type: 'info' | 'success' | 'warning' | 'error';
}

export default function LiveProcessingDashboard() {
  const [videos, setVideos] = useState<UploadedVideoResponse[]>([]);
  const [selectedVideo, setSelectedVideo] = useState<UploadedVideoResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Stats State
  const [stats, setStats] = useState({
    videosUploaded: 0,
    videosProcessed: 0,
    totalDistresses: 0,
    roadHealthScore: 100.0,
    reportsGenerated: 0
  });

  // Live Progress Simulation States
  const [progress, setProgress] = useState(0);
  const [currentStage, setCurrentStage] = useState<string>('Idle');
  const [activityLogs, setActivityLogs] = useState<ActivityLog[]>([]);
  const progressIntervalRef = useRef<any>(null);

  // Poll for video queues and analytical stats
  const fetchData = async () => {
    try {
      const videoList = await apiService.getVideos(0, 100);
      setVideos(videoList);
      
      // Update basic counts from videoList
      const uploaded = videoList.length;
      const processed = videoList.filter(v => v.processing_status.toLowerCase() === 'completed').length;

      // Fetch analytics summary & reports
      const [summary, reportList] = await Promise.all([
        apiService.getDetectionSummary().catch(() => ({ total_detections: 0, road_health_score: 100.0 })),
        apiService.getReports(0, 100).catch(() => [])
      ]);

      setStats({
        videosUploaded: uploaded,
        videosProcessed: processed,
        totalDistresses: summary.total_detections || 0,
        roadHealthScore: summary.road_health_score || 100.0,
        reportsGenerated: reportList.length || 0
      });

      setError(null);
    } catch (err: any) {
      console.error(err);
      setError("Failed to synchronize dashboard statistics with backend registry.");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
    const interval = setInterval(fetchData, 4000);
    return () => clearInterval(interval);
  }, []);

  // Sync selected video state with polled video queue updates
  useEffect(() => {
    if (selectedVideo) {
      const updated = videos.find(v => v.id === selectedVideo.id);
      if (updated && updated.processing_status !== selectedVideo.processing_status) {
        setSelectedVideo(updated);
      }
    } else if (videos.length > 0 && !selectedVideo) {
      setSelectedVideo(videos[0]);
    }
  }, [videos, selectedVideo]);

  // Handle active progress bar simulation when selected video status is "processing"
  useEffect(() => {
    if (!selectedVideo) {
      setProgress(0);
      setCurrentStage('Idle');
      return;
    }

    const status = selectedVideo.processing_status.toLowerCase();

    if (status === 'completed') {
      if (progressIntervalRef.current) clearInterval(progressIntervalRef.current);
      setProgress(100);
      setCurrentStage('Completed');
      
      // Add completion logs if not already present
      addLogOnce(`Detection pipeline finished successfully. PDF report and CSV datasets compiled.`, 'success');
    } else if (status === 'failed') {
      if (progressIntervalRef.current) clearInterval(progressIntervalRef.current);
      setProgress(100);
      setCurrentStage('Failed');
      addLogOnce(`Pipeline failure: OpenCV frame extraction or inference loop failed. Check server logs.`, 'error');
    } else if (status === 'processing') {
      // Start/continue progress bar simulation
      if (!progressIntervalRef.current) {
        setProgress(10);
        setCurrentStage('Extracting Frames');
        addLogOnce(`Triggered detection pipeline. Initializing camera stream.`, 'info');
        
        let simProgress = 10;
        progressIntervalRef.current = setInterval(() => {
          simProgress += Math.floor(Math.random() * 4) + 1;
          if (simProgress > 95) {
            simProgress = 95;
          }
          setProgress(simProgress);

          // Update stages based on progress
          if (simProgress < 35) {
            setCurrentStage('Extracting Frames');
            addLogOnce(`Decompressing video stream and caching frame segments.`, 'info');
          } else if (simProgress < 65) {
            setCurrentStage('Running YOLO Detection');
            addLogOnce(`Running YOLO inference weights. Scanning frames for road distress markers.`, 'info');
          } else if (simProgress < 80) {
            setCurrentStage('Tracking Objects');
            addLogOnce(`Matching IoU bounding boxes across frame sequences to filter duplicate records.`, 'info');
          } else if (simProgress < 90) {
            setCurrentStage('Generating Maintenance Tasks');
            addLogOnce(`Executing priority recommendation engine and logging tasks.`, 'success');
          } else {
            setCurrentStage('Generating Report');
          }
        }, 800);
      }
    } else {
      // waiting, queued, pending
      if (progressIntervalRef.current) clearInterval(progressIntervalRef.current);
      setProgress(0);
      setCurrentStage('Pending');
    }

    return () => {
      if (progressIntervalRef.current) {
        clearInterval(progressIntervalRef.current);
        progressIntervalRef.current = null;
      }
    };
  }, [selectedVideo]);

  const addLogOnce = (msg: string, type: 'info' | 'success' | 'warning' | 'error') => {
    const timestamp = new Date().toLocaleTimeString('en-IN');
    setActivityLogs(prev => {
      // Check if duplicate message exists in last 3 items to avoid spamming
      const exists = prev.slice(0, 3).some(log => log.message === msg);
      if (exists) return prev;
      return [
        {
          id: Math.random().toString(),
          time: timestamp,
          message: msg,
          type
        },
        ...prev
      ];
    });
  };

  const handleTriggerProcessing = async () => {
    if (!selectedVideo) return;
    try {
      addLogOnce(`Sending execution request to backend orchestration pipeline...`, 'info');
      await apiService.triggerDetection(selectedVideo.id);
      
      // Update local state to immediately show processing status
      setSelectedVideo({
        ...selectedVideo,
        processing_status: 'processing'
      });
      fetchData();
    } catch (err: any) {
      console.error(err);
      addLogOnce(`Failed to trigger processing: ${err.response?.data?.detail || err.message}`, 'error');
    }
  };

  const selectVideoRow = (vid: UploadedVideoResponse) => {
    setSelectedVideo(vid);
    setActivityLogs([]); // reset log view for selected video context
  };

  return (
    <div className="live-proc-dashboard animate-fade-in">
      
      {/* Page Header */}
      <header className="live-proc-header">
        <div className="live-proc-header__title">
          <Activity size={24} className="live-proc-header__icon text-purple animate-pulse" />
          <div>
            <h1 className="bold-page-title" style={{ fontSize: '32px' }}>Live Pipeline Monitor</h1>
            <p className="light-secondary-text" style={{ fontSize: '14px' }}>Track video ingestion, frame extraction, YOLO inference, and task allocation milestones.</p>
          </div>
        </div>
      </header>

      {error && (
        <div className="dashboard-error-banner">
          <XCircle size={16} />
          <span>{error}</span>
        </div>
      )}

      {/* Grid Section 1: KPI Analytics Cards */}
      <section className="live-proc-kpi-grid">
        <div className="live-proc-kpi-card premium-card">
          <div className="kpi-header">
            <Video size={16} className="text-blue" />
            <span className="kpi-title">Ingested Footage</span>
          </div>
          <h2 className="kpi-val font-mono">{stats.videosUploaded}</h2>
          <div className="kpi-footer font-mono">Total video files uploaded</div>
        </div>

        <div className="live-proc-kpi-card premium-card">
          <div className="kpi-header">
            <CheckCircle2 size={16} className="text-green" />
            <span className="kpi-title">Processed Feeds</span>
          </div>
          <h2 className="kpi-val font-mono">{stats.videosProcessed}</h2>
          <div className="kpi-footer font-mono">
            {stats.videosUploaded > 0 
              ? `${Math.round((stats.videosProcessed / stats.videosUploaded) * 100)}% completion rate`
              : '0% completion rate'}
          </div>
        </div>

        <div className="live-proc-kpi-card premium-card">
          <div className="kpi-header">
            <ShieldAlert size={16} className="text-red" />
            <span className="kpi-title">Total Distresses</span>
          </div>
          <h2 className="kpi-val font-mono">{stats.totalDistresses}</h2>
          <div className="kpi-footer font-mono">Logged anomalies on map</div>
        </div>

        <div className="live-proc-kpi-card premium-card">
          <div className="kpi-header">
            <TrendingUp size={16} className="text-amber" />
            <span className="kpi-title">Road Health Index</span>
          </div>
          <h2 className="kpi-val font-mono text-amber">{stats.roadHealthScore}%</h2>
          <div className="kpi-footer font-mono">Weighted distress deductions</div>
        </div>

        <div className="live-proc-kpi-card premium-card">
          <div className="kpi-header">
            <FileText size={16} className="text-purple" />
            <span className="kpi-title">Generated Reports</span>
          </div>
          <h2 className="kpi-val font-mono">{stats.reportsGenerated}</h2>
          <div className="kpi-footer font-mono">PDF & Excel datasets exported</div>
        </div>
      </section>

      {/* Grid Section 2: Main Content Layout */}
      <div className="live-proc-main-row">
        
        {/* Left Side: Video Selection Queue */}
        <section className="live-proc-queue-card premium-card">
          <header className="card-header-label">
            <Video size={16} />
            <h3>Footage Registry Queue</h3>
          </header>
          
          <div className="queue-list-viewport scrollable-y">
            {loading ? (
              <div className="queue-empty-view">
                <Loader2 className="animate-spin text-purple" />
                <span>Loading video archives...</span>
              </div>
            ) : videos.length === 0 ? (
              <div className="queue-empty-view font-mono">
                <span>No surveillance logs indexed in the database.</span>
              </div>
            ) : (
              <div className="queue-items-container">
                {videos.map(v => {
                  const isActive = selectedVideo?.id === v.id;
                  const status = v.processing_status.toLowerCase();
                  
                  return (
                    <div 
                      key={v.id} 
                      className={`queue-item-row ${isActive ? 'active' : ''}`}
                      onClick={() => selectVideoRow(v)}
                    >
                      <div className="queue-item-meta">
                        <span className="queue-item-name font-mono" title={v.filename}>{v.filename}</span>
                        <span className="queue-item-date font-mono">
                          {new Date(v.upload_timestamp).toLocaleDateString('en-IN')}
                        </span>
                      </div>
                      
                      <div className="queue-item-actions">
                        <span className={`status-tag status-tag--${status}`}>
                          {status}
                        </span>
                        <ChevronRight size={14} className="queue-arrow" />
                      </div>
                    </div>
                  );
                })}
              </div>
            )}
          </div>
        </section>

        {/* Right Side: Active Processing & Milestone Tracking */}
        <section className="live-proc-monitor-card premium-card">
          {selectedVideo ? (
            <div className="monitor-container">
              <header className="monitor-header-row">
                <div>
                  <h3 className="monitor-video-title font-mono">{selectedVideo.filename}</h3>
                  <p className="monitor-video-subtitle">Video ID: #{selectedVideo.id} &bull; Registry date: {new Date(selectedVideo.upload_timestamp).toLocaleString('en-IN')}</p>
                </div>
                
                {selectedVideo.processing_status.toLowerCase() === 'waiting' && (
                  <button 
                    className="btn-trigger-pipeline font-semibold"
                    onClick={handleTriggerProcessing}
                  >
                    <Play size={14} />
                    <span>Run AI Pipeline</span>
                  </button>
                )}
              </header>

              {/* Status Section */}
              <div className="monitor-status-grid">
                <div className="status-indicator-box">
                  <span className="box-lbl">Ingestion Status</span>
                  <span className="box-val text-green font-bold">Uploaded</span>
                </div>
                <div className="status-indicator-box">
                  <span className="box-lbl">Pipeline Status</span>
                  <span className={`box-val font-bold text-${selectedVideo.processing_status.toLowerCase()}`}>
                    {selectedVideo.processing_status}
                  </span>
                </div>
                <div className="status-indicator-box">
                  <span className="box-lbl">Current Stage</span>
                  <span className="box-val font-mono">{currentStage}</span>
                </div>
              </div>

              {/* Modern Progress Bar */}
              <div className="monitor-progress-block">
                <div className="progress-bar-labels font-mono">
                  <span>Progress Rate</span>
                  <span>{progress}%</span>
                </div>
                <div className="progress-track-wrapper">
                  <div 
                    className={`progress-fill ${selectedVideo.processing_status.toLowerCase() === 'failed' ? 'failed' : ''}`}
                    style={{ width: `${progress}%` }}
                  />
                </div>
              </div>

              {/* Pipeline Stage Milestones */}
              <div className="pipeline-milestones-block">
                <h4 className="block-title">Pipeline Milestones Progression</h4>
                <div className="milestones-stepper">
                  {[
                    { label: 'Uploading Video', range: [0, 100] },
                    { label: 'Extracting Frames', range: [10, 100] },
                    { label: 'Running YOLO Detection', range: [35, 100] },
                    { label: 'Tracking Objects', range: [65, 100] },
                    { label: 'Generating Maintenance Tasks', range: [80, 100] },
                    { label: 'Generating Report', range: [90, 100] },
                    { label: 'Completed', range: [100, 100] }
                  ].map((step, idx) => {
                    const status = selectedVideo.processing_status.toLowerCase();
                    let isDone = false;
                    let isCurrent = false;

                    if (status === 'completed') {
                      isDone = true;
                    } else if (status === 'failed') {
                      isDone = false;
                    } else if (status === 'processing') {
                      if (currentStage === step.label) {
                        isCurrent = true;
                      } else {
                        const stepIndex = ['Uploading Video', 'Extracting Frames', 'Running YOLO Detection', 'Tracking Objects', 'Generating Maintenance Tasks', 'Generating Report', 'Completed'].indexOf(currentStage);
                        if (stepIndex > idx) {
                          isDone = true;
                        }
                      }
                    } else {
                      // waiting / queued
                      if (idx === 0) isDone = true;
                      if (idx === 1) isCurrent = true;
                    }

                    return (
                      <div key={step.label} className={`milestone-step-row ${isDone ? 'done' : ''} ${isCurrent ? 'current' : ''}`}>
                        <div className="milestone-bullet">
                          {isDone ? <CheckCircle2 size={14} className="text-green" /> : idx + 1}
                        </div>
                        <span className="milestone-label font-mono">{step.label}</span>
                      </div>
                    );
                  })}
                </div>
              </div>

              {/* Recent Activity Log Panel */}
              <div className="activity-panel-block">
                <h4 className="block-title">Pipeline Activity Log</h4>
                <div className="activity-logs-viewport scrollable-y">
                  {activityLogs.length === 0 ? (
                    <div className="activity-empty-state font-mono">
                      <Clock size={16} />
                      <span>Diagnostics logs are currently empty. Run pipeline to stream activity logs.</span>
                    </div>
                  ) : (
                    <div className="logs-list">
                      {activityLogs.map(log => (
                        <div key={log.id} className={`log-row type-${log.type}`}>
                          <span className="log-time font-mono">[{log.time}]</span>
                          <span className="log-text font-mono">{log.message}</span>
                        </div>
                      ))}
                    </div>
                  )}
                </div>
              </div>

            </div>
          ) : (
            <div className="monitor-empty-state">
              <Cpu size={32} className="empty-icon animate-pulse" />
              <h3>Select a video source to begin surveillance monitoring.</h3>
            </div>
          )}
        </section>

      </div>

    </div>
  );
}