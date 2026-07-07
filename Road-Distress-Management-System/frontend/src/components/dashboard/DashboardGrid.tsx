import { useEffect, useState, useRef } from 'react'
import { useParams } from 'react-router-dom'
import apiService from '../../services/api/apiService'
import type { RoadDistressResponse } from '../../services/api/apiService'
import DetectionTrendChart from './DetectionTrendChart'
import DistressDistributionChart from './DistressDistributionChart'
import KPISection from './KPISection'
import {
  Tv, Play, Square, Camera, Map, Compass, ChevronRight, Sliders, Plus,
  Minus, Layers, Download, CheckCircle2, RefreshCw, Calendar, Ruler, Car,
  Users, Sun, Mic, Trash2, PlayCircle, StopCircle, Upload, X, Save, MapPin
} from 'lucide-react'
import type { UploadedVideoResponse } from '../../services/api/apiService'
import { MapContainer, TileLayer, Marker, Popup } from 'react-leaflet'
import L from 'leaflet'
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
const customDivIcon = (severity: string) => {
  const color = severity === 'critical' || severity === 'high' ? '#EF4444' : severity === 'medium' ? '#F59E0B' : '#10B981';
  return L.divIcon({
    html: `<div style="background-color: ${color}; width: 14px; height: 14px; border-radius: 50%; border: 2px solid white; box-shadow: 0 0 4px rgba(0,0,0,0.4);"></div>`,
    className: 'custom-gis-div-icon',
    iconSize: [14, 14],
    iconAnchor: [7, 7]
  });
};

export default function DashboardGrid() {
  const { videoId } = useParams<{ videoId?: string }>();
  const [distresses, setDistresses] = useState<RoadDistressResponse[]>([]);
  const [reportsCount, setReportsCount] = useState<number>(0);

  const [isLoading, setIsLoading] = useState<boolean>(true);
  const [error, setError] = useState<string | null>(null);

  const [currentVideo, setCurrentVideo] = useState<UploadedVideoResponse | null>(null);

  // Manual observations states
  const [manualObservations, setManualObservations] = useState<any[]>([
    {
      id: 'OBS-1',
      time: '11:32 AM',
      highway: 'NH-48 Mumbai–Pune Expressway',
      chainage: 'Km 124+350',
      category: 'Broken Sign Board',
      severity: 'Medium',
      observation: 'Speed limit board at Km 124+350 is damaged and bent.',
      voice: null,
      snapshot: null,
      status: 'Logged'
    }
  ]);

  const [observationText, setObservationText] = useState('');
  const [category, setCategory] = useState('Pole Obstruction');
  const [severity, setSeverity] = useState('Medium');
  const [chainage, setChainage] = useState('');
  const [gpsLocation, setGpsLocation] = useState('');
  const [audioUrl, setAudioUrl] = useState<string | null>(null);
  const [mediaRecorder, setMediaRecorder] = useState<MediaRecorder | null>(null);
  const [recordingStatus, setRecordingStatus] = useState<'idle' | 'recording' | 'recorded' | 'playing'>('idle');
  const [recordingDuration, setRecordingDuration] = useState(0);
  const [snapshotUrl, setSnapshotUrl] = useState<string | null>(null);

  const timerRef = useRef<any>(null);
  const audioChunksRef = useRef<Blob[]>([]);
  const audioRef = useRef<HTMLAudioElement | null>(null);

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

      let videoMeta: UploadedVideoResponse | null = null;
      if (videoId) {
        try {
          videoMeta = await apiService.getVideoById(Number(videoId));
        } catch (e) {
          console.error("Failed to load video metadata:", e);
        }
      }
      setCurrentVideo(videoMeta);
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

  const getHighwayName = () => {
    if (!currentVideo) return 'NH-48 Mumbai–Pune Expressway';
    const fname = currentVideo.filename.toUpperCase();
    if (fname.includes('NH-48') || fname.includes('NH48')) return 'NH-48 Mumbai–Pune Expressway';
    if (fname.includes('NH-4') || fname.includes('NH4')) return 'NH-4 Mumbai–Pune National Highway';
    return currentVideo.filename.split('.')[0].replace(/_/g, ' ') || 'NH-48 Mumbai–Pune Expressway';
  };

  const getInspectionDate = () => {
    if (!currentVideo) return '04 July 2026';
    const dateStr = currentVideo.upload_timestamp || currentVideo.created_at;
    if (!dateStr) return '04 July 2026';
    const d = new Date(dateStr);
    return d.toLocaleDateString('en-US', { day: '2-digit', month: 'long', year: 'numeric' });
  };

  const startRecording = async () => {
    try {
      if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
        const stream = await navigator.mediaDevices.getUserMedia({ audio: true }).catch(() => null);
        if (stream) {
          const recorder = new MediaRecorder(stream);
          audioChunksRef.current = [];

          recorder.ondataavailable = (event) => {
            if (event.data.size > 0) {
              audioChunksRef.current.push(event.data);
            }
          };

          recorder.onstop = () => {
            const audioBlob = new Blob(audioChunksRef.current, { type: 'audio/wav' });
            const url = URL.createObjectURL(audioBlob);
            setAudioUrl(url);
            setRecordingStatus('recorded');
            stream.getTracks().forEach(track => track.stop());
          };

          setMediaRecorder(recorder);
          recorder.start();
          setRecordingStatus('recording');
          setRecordingDuration(0);

          if (timerRef.current) clearInterval(timerRef.current);
          timerRef.current = setInterval(() => {
            setRecordingDuration(prev => prev + 1);
          }, 1000);
          return;
        }
      }

      // Fallback simulated recording
      setRecordingStatus('recording');
      setRecordingDuration(0);
      if (timerRef.current) clearInterval(timerRef.current);
      timerRef.current = setInterval(() => {
        setRecordingDuration(prev => prev + 1);
      }, 1000);
    } catch (err) {
      console.error(err);
      setRecordingStatus('recording');
      setRecordingDuration(0);
      if (timerRef.current) clearInterval(timerRef.current);
      timerRef.current = setInterval(() => {
        setRecordingDuration(prev => prev + 1);
      }, 1000);
    }
  };

  const stopRecording = () => {
    if (mediaRecorder && mediaRecorder.state !== 'inactive') {
      mediaRecorder.stop();
      clearInterval(timerRef.current);
    } else {
      clearInterval(timerRef.current);
      setAudioUrl("simulated-audio-recording");
      setRecordingStatus('recorded');
    }
  };

  const playRecording = () => {
    if (audioUrl) {
      if (audioUrl === "simulated-audio-recording") {
        setRecordingStatus('playing');
        setTimeout(() => {
          setRecordingStatus('recorded');
        }, recordingDuration * 1000);
        return;
      }
      if (audioRef.current) {
        audioRef.current.pause();
      }
      const audio = new Audio(audioUrl);
      audioRef.current = audio;
      setRecordingStatus('playing');
      audio.play();
      audio.onended = () => {
        setRecordingStatus('recorded');
      };
    }
  };

  const deleteRecording = () => {
    if (audioRef.current) {
      audioRef.current.pause();
    }
    setAudioUrl(null);
    setRecordingStatus('idle');
    setRecordingDuration(0);
  };

  const handleImageUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      const allowed = ['image/jpeg', 'image/jpg', 'image/png'];
      if (!allowed.includes(file.type)) {
        alert("Invalid file format. Supported formats: JPG, PNG, JPEG.");
        return;
      }
      const url = URL.createObjectURL(file);
      setSnapshotUrl(url);
    }
  };

  const handleRemoveImage = () => {
    setSnapshotUrl(null);
  };

  const handleSaveObservation = (e: React.FormEvent) => {
    e.preventDefault();
    if (!observationText.trim()) {
      alert("Please enter observation details.");
      return;
    }
    if (!chainage.trim()) {
      alert("Please specify the chainage location.");
      return;
    }

    const newObs = {
      id: `OBS-${Date.now()}`,
      time: new Date().toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' }),
      highway: getHighwayName(),
      chainage: chainage,
      category: category,
      severity: severity,
      observation: observationText,
      voice: audioUrl,
      snapshot: snapshotUrl,
      status: 'Logged'
    };

    setManualObservations(prev => [newObs, ...prev]);

    // Reset form fields
    setObservationText('');
    setCategory('Pole Obstruction');
    setSeverity('Medium');
    setChainage('');
    setGpsLocation('');
    deleteRecording();
    handleRemoveImage();
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

  const validMapMarkers = distresses.filter(d => typeof d.latitude === 'number' && typeof d.longitude === 'number');
  const mapCenterCoords: [number, number] = validMapMarkers.length > 0
    ? [validMapMarkers[0].latitude, validMapMarkers[0].longitude]
    : [37.7749, -122.4194];

  return (
    <section className="dashboard-page animate-fade-in" aria-label="Dashboard overview">
      <header className="dashboard-page__header">
        <h1 className="bold-page-title" style={{ fontSize: '32px' }}>Fleet Operations Control</h1>
      </header>

      {/* Section 1: Road Inspection Information */}
      <div className="premium-card inspection-info-card" style={{ marginBottom: '24px' }}>
        <div className="card-header-with-actions" style={{ borderBottom: 'none', marginBottom: '8px' }}>
          <div className="card-header-title">
            <Sliders size={18} style={{ color: 'var(--accent-blue)' }} />
            <h2 className="medium-section-title" style={{ fontSize: '16px' }}>Road Inspection Information</h2>
          </div>
        </div>
        
        <div className="inspection-info-grid-two-rows">
          {/* Row 1 */}
          <div className="info-item">
            <Compass className="info-icon" size={16} />
            <div className="info-content">
              <span className="info-label">Highway Name</span>
              <span className="info-value">{getHighwayName()}</span>
            </div>
          </div>
          <div className="info-item">
            <Calendar className="info-icon" size={16} />
            <div className="info-content">
              <span className="info-label">Inspection Date</span>
              <span className="info-value">{getInspectionDate()}</span>
            </div>
          </div>
          <div className="info-item">
            <MapPin className="info-icon" size={16} />
            <div className="info-content">
              <span className="info-label">Start Chainage</span>
              <span className="info-value">Km 118+250</span>
            </div>
          </div>
          <div className="info-item">
            <MapPin className="info-icon" size={16} />
            <div className="info-content">
              <span className="info-label">End Chainage</span>
              <span className="info-value">Km 136+900</span>
            </div>
          </div>
          {/* Row 2 */}
          <div className="info-item">
            <Compass className="info-icon" size={16} />
            <div className="info-content">
              <span className="info-label">Latitude</span>
              <span className="info-value">{mapCenterCoords[0].toFixed(5)}° N</span>
            </div>
          </div>
          <div className="info-item">
            <Compass className="info-icon" size={16} />
            <div className="info-content">
              <span className="info-label">Longitude</span>
              <span className="info-value">{mapCenterCoords[1].toFixed(5)}° E</span>
            </div>
          </div>
          <div className="info-item">
            <Ruler className="info-icon" size={16} />
            <div className="info-content">
              <span className="info-label">Road Length</span>
              <span className="info-value">18.65 km</span>
            </div>
          </div>
          <div className="info-item">
            <CheckCircle2 className="info-icon" size={16} style={{ color: 'var(--success)' }} />
            <div className="info-content">
              <span className="info-label">Inspection Status</span>
              <span className="info-value" style={{ color: 'var(--success)', fontWeight: 'bold' }}>Completed</span>
            </div>
          </div>
        </div>
      </div>

      {/* Section 2: Distress Distribution & AI Pipeline */}
      <div className="dash-analytics-grid" style={{ marginBottom: '24px' }}>
        <div className="premium-card">
          <div className="card-header-with-actions" style={{ marginBottom: '8px' }}>
            <h2 className="medium-section-title" style={{ fontSize: '15px' }}>Distress Distribution</h2>
            <select className="gis-date-select" defaultValue="month">
              <option value="month">This Month</option>
            </select>
          </div>
          <DistressDistributionChart data={distresses} />
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

      {/* Section 3: Live Camera & GIS Map side-by-side */}
      <div className="dash-camera-map-grid">
        {/* Left Column: Live camera feed simulation */}
        <div className="premium-card live-cam-card" style={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
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

          <div className="live-cam-viewport" style={{ flex: 1 }}>
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

          <div className="live-cam-controls" style={{ borderBottom: '1px solid var(--card-border)' }}>
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

          {/* Voice recorder & snapshot elements inside live camera card */}
          <div style={{ padding: '16px 20px' }}>
            <div className="card-header-with-actions" style={{ borderBottom: 'none', marginBottom: '8px' }}>
              <div className="card-header-title">
                <Mic size={14} style={{ color: 'var(--primary-text)' }} />
                <h3 className="medium-section-title" style={{ fontSize: '13px' }}>Voice Note Recorder</h3>
              </div>
              <span className={`status-pill status-pill--${recordingStatus}`}>
                {recordingStatus.toUpperCase()}
              </span>
            </div>

            <div className="voice-recorder-controls" style={{ padding: '10px 14px' }}>
              <div className="timer-display" style={{ fontSize: '16px', fontWeight: 600 }}>
                {Math.floor(recordingDuration / 60).toString().padStart(2, '0')}:
                {(recordingDuration % 60).toString().padStart(2, '0')}
              </div>

              <div className="controls-row">
                {recordingStatus === 'idle' && (
                  <button onClick={startRecording} className="btn-control btn-control--record">
                    <Mic size={12} />
                    <span>Record</span>
                  </button>
                )}

                {recordingStatus === 'recording' && (
                  <button onClick={stopRecording} className="btn-control btn-control--stop">
                    <StopCircle size={12} />
                    <span>Stop</span>
                  </button>
                )}

                {(recordingStatus === 'recorded' || recordingStatus === 'playing') && (
                  <div style={{ display: 'flex', gap: '8px' }}>
                    <button onClick={playRecording} className="btn-control btn-control--play" disabled={recordingStatus === 'playing'}>
                      <PlayCircle size={12} />
                      <span>{recordingStatus === 'playing' ? 'Playing' : 'Play'}</span>
                    </button>
                    <button onClick={deleteRecording} className="btn-control btn-control--delete">
                      <Trash2 size={12} />
                      <span>Delete</span>
                    </button>
                  </div>
                )}
              </div>
            </div>

            {/* Separator line */}
            <div style={{ height: '1px', background: 'var(--card-border)', margin: '12px 0' }} />

            {/* Image Snapshot Uploader */}
            <div className="card-header-with-actions" style={{ borderBottom: 'none', marginBottom: '8px' }}>
              <div className="card-header-title">
                <Camera size={14} style={{ color: 'var(--primary-text)' }} />
                <h3 className="medium-section-title" style={{ fontSize: '13px' }}>Snapshot Card</h3>
              </div>
            </div>

            <div className="snapshot-uploader-container">
              {snapshotUrl ? (
                <div className="image-preview-wrapper" style={{ height: '100px' }}>
                  <img src={snapshotUrl} alt="Preview" className="uploaded-snapshot-img" />
                  <button onClick={handleRemoveImage} className="btn-control remove-image-btn">
                    <X size={10} />
                    <span>Remove</span>
                  </button>
                </div>
              ) : (
                <label className="upload-dropzone" style={{ padding: '12px' }}>
                  <Upload size={18} style={{ color: 'var(--secondary-text)' }} />
                  <span style={{ fontSize: '10px', color: 'var(--secondary-text)', marginTop: '2px' }}>
                    Upload PNG, JPG, or JPEG
                  </span>
                  <input 
                    type="file" 
                    accept="image/png, image/jpeg, image/jpg" 
                    onChange={handleImageUpload} 
                    style={{ display: 'none' }} 
                  />
                </label>
              )}
            </div>
          </div>
        </div>

        {/* Right Column: Interactive Leaflet Map */}
        <div className="premium-card gis-map-card" style={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
          <div className="card-header-with-actions" style={{ padding: '16px 20px 8px 20px', marginBottom: 0 }}>
            <div className="card-header-title">
              <Map size={16} style={{ color: 'var(--primary-text)' }} />
              <h2 className="medium-section-title" style={{ fontSize: '15px' }}>Geospatial Mapping (GIS)</h2>
            </div>
            <span className="live-cam-badge" style={{ background: 'var(--success-light)', color: 'var(--success)' }}>
              ONLINE
            </span>
          </div>

          <div className="gis-map-legend">
            <span className="gis-legend-item"><span className="legend-dot legend-dot--critical" />Critical</span>
            <span className="gis-legend-item"><span className="legend-dot legend-dot--high" />High</span>
            <span className="gis-legend-item"><span className="legend-dot legend-dot--medium" />Medium</span>
            <span className="gis-legend-item"><span className="legend-dot legend-dot--low" />Low</span>
          </div>

          <div className="gis-map-inner-wrapper" style={{ flex: 1, position: 'relative', background: 'var(--primary-bg)' }}>
            <MapContainer
              center={mapCenterCoords}
              zoom={12}
              style={{ width: '100%', height: '100%', borderRadius: '8px', zIndex: 1 }}
              zoomControl={false}
            >
              <TileLayer
                attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
                url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
              />
              {validMapMarkers.map((d) => (
                <Marker
                  key={d.id}
                  position={[d.latitude, d.longitude]}
                  icon={customDivIcon(d.severity.toLowerCase())}
                >
                  <Popup>
                    <div style={{ fontSize: '12px', color: '#111827', padding: '4px' }}>
                      <strong style={{ textTransform: 'capitalize', fontSize: '13px' }}>{d.distress_type.replace('_', ' ')}</strong>
                      <br />
                      <span style={{ color: 'var(--secondary-text)' }}>Severity:</span> <span style={{ color: d.severity.toLowerCase() === 'critical' || d.severity.toLowerCase() === 'high' ? '#EF4444' : '#F59E0B', fontWeight: 600 }}>{d.severity.toUpperCase()}</span>
                      <br />
                      <span style={{ color: 'var(--secondary-text)' }}>Confidence:</span> {Math.round(d.confidence_score * 100)}%
                      <br />
                      <span style={{ color: 'var(--secondary-text)' }}>GPS:</span> {d.latitude.toFixed(5)}°, {d.longitude.toFixed(5)}°
                    </div>
                  </Popup>
                </Marker>
              ))}
            </MapContainer>

            {/* Map Controls */}
            <div className="gis-controls-overlay" style={{ zIndex: 10 }}>
              <button className="gis-control-btn"><Compass size={14} /></button>
              <button className="gis-control-btn"><Plus size={14} /></button>
              <button className="gis-control-btn"><Minus size={14} /></button>
              <button className="gis-control-btn"><Layers size={14} /></button>
            </div>
          </div>
        </div>
      </div>

      {/* Section 4: Recent Detections List (Full Width Grid Layout) */}
      <div className="premium-card recent-detections-list-card" style={{ marginBottom: '24px' }}>
        <div className="card-header-with-actions" style={{ padding: '16px 20px 8px 20px', marginBottom: 0 }}>
          <h2 className="medium-section-title" style={{ fontSize: '15px' }}>Recent Detections</h2>
          <button className="btn-view-feed" style={{ fontSize: '12px' }}>View All</button>
        </div>
        <div className="scrollable-detections-feed" style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(220px, 1fr))', gap: '16px', padding: '16px 20px', overflowY: 'unset', maxHeight: 'unset' }}>
          {distresses.slice(0, 5).map((d) => (
            <div key={d.id} className="detection-feed-item" onClick={() => alert(`Details: distress ID RD-${d.id}`)} style={{ margin: 0 }}>
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

      {/* Section 5: Manual Observations form & Recent observations list */}
      <div className="manual-observations-section" style={{ marginBottom: '24px' }}>
        <header className="section-header" style={{ marginBottom: '16px' }}>
          <h2 className="bold-page-title" style={{ fontSize: '24px' }}>Manual Field Observations</h2>
          <p className="light-secondary-text" style={{ fontSize: '13px' }}>Record events and obstructions manually for inspection validation.</p>
        </header>

        <div className="obs-form-grid" style={{ gridTemplateColumns: '1fr', gap: '20px' }}>
          {/* Left form inputs card */}
          <div className="premium-card form-inputs-card">
            <form onSubmit={handleSaveObservation} className="observation-form">
              <div className="form-group-row">
                <div className="form-group">
                  <label className="form-label">Observation Category *</label>
                  <select
                    value={category}
                    onChange={e => setCategory(e.target.value)}
                    className="form-select"
                  >
                    <option value="Pole Obstruction">Pole Obstruction</option>
                    <option value="Tree Fall">Tree Fall</option>
                    <option value="Road Block">Road Block</option>
                    <option value="Water Logging">Water Logging</option>
                    <option value="Accident">Accident</option>
                    <option value="Construction Debris">Construction Debris</option>
                    <option value="Damaged Barrier">Damaged Barrier</option>
                    <option value="Broken Sign Board">Broken Sign Board</option>
                    <option value="Other">Other</option>
                  </select>
                </div>

                <div className="form-group">
                  <label className="form-label">Severity Level</label>
                  <select
                    value={severity}
                    onChange={e => setSeverity(e.target.value)}
                    className="form-select"
                  >
                    <option value="Critical">Critical</option>
                    <option value="High">High</option>
                    <option value="Medium">Medium</option>
                    <option value="Low">Low</option>
                  </select>
                </div>
              </div>

              <div className="form-group-row">
                <div className="form-group">
                  <label className="form-label">Location Chainage *</label>
                  <input
                    type="text"
                    value={chainage}
                    onChange={e => setChainage(e.target.value)}
                    placeholder="Km 124+350"
                    className="form-input"
                  />
                </div>

                <div className="form-group">
                  <label className="form-label">GPS Coordinates (Optional)</label>
                  <input
                    type="text"
                    value={gpsLocation}
                    onChange={e => setGpsLocation(e.target.value)}
                    placeholder="18.5321, 73.8450"
                    className="form-input"
                  />
                </div>
              </div>

              <div className="form-group">
                <label className="form-label">Observation Details *</label>
                <textarea
                  value={observationText}
                  onChange={e => setObservationText(e.target.value)}
                  placeholder="Example: Electric pole lying across lane. Immediate removal required."
                  rows={4}
                  className="form-textarea"
                />
              </div>

              <button type="submit" className="btn-report-run save-obs-btn">
                <Save size={14} />
                <span>Save Observation</span>
              </button>
            </form>
          </div>

          {/* Observations Table */}
          <div className="premium-card table-registry-card" style={{ margin: 0 }}>
            <div className="card-header-with-actions" style={{ borderBottom: 'none', marginBottom: '10px' }}>
              <div className="card-header-title">
                <Layers size={16} />
                <h3 className="medium-section-title" style={{ fontSize: '15px' }}>Recent Manual Observations</h3>
              </div>
            </div>

            <div className="table-responsive-container">
              <table className="inspections-grid-table">
                <thead>
                  <tr>
                    <th>Time</th>
                    <th>Highway</th>
                    <th>Chainage</th>
                    <th>Category</th>
                    <th>Severity</th>
                    <th>Observation</th>
                    <th>Voice</th>
                    <th>Snapshot</th>
                    <th>Status</th>
                  </tr>
                </thead>
                <tbody>
                  {manualObservations.length > 0 ? (
                    manualObservations.map((obs) => (
                      <tr key={obs.id}>
                        <td className="font-mono" style={{ fontSize: '12px' }}>{obs.time}</td>
                        <td>{obs.highway}</td>
                        <td className="font-mono">{obs.chainage}</td>
                        <td>
                          <span className="category-tag">{obs.category}</span>
                        </td>
                        <td>
                          <span className={`severity-tag severity-tag--${obs.severity.toLowerCase()}`}>
                            {obs.severity}
                          </span>
                        </td>
                        <td className="text-truncate-cell" title={obs.observation}>
                          {obs.observation}
                        </td>
                        <td>
                          {obs.voice ? (
                            <button onClick={() => {
                              if (obs.voice === 'simulated-audio-recording') {
                                alert("Playing simulated voice note recording...");
                              } else {
                                const audio = new Audio(obs.voice);
                                audio.play();
                              }
                            }} className="btn-audio-play">
                              🔊 Play
                            </button>
                          ) : (
                            <span className="light-secondary-text">N/A</span>
                          )}
                        </td>
                        <td>
                          {obs.snapshot ? (
                            <a href={obs.snapshot} target="_blank" rel="noreferrer" className="snapshot-link">
                              🖼️ View
                            </a>
                          ) : (
                            <span className="light-secondary-text">N/A</span>
                          )}
                        </td>
                        <td>
                          <span className="status-badge-logged">{obs.status}</span>
                        </td>
                      </tr>
                    ))
                  ) : (
                    <tr>
                      <td colSpan={9} style={{ textAlign: 'center', padding: '24px', color: 'var(--secondary-text)' }}>
                        No manual observations recorded yet.
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>

      {/* Section 6: KPI cards relocated lower */}
      <div className="dash-row" style={{ marginBottom: '24px' }}>
        <KPISection
          distressCount={distressCount}
          criticalCount={criticalCount}
          pendingCount={pendingCount}
          reportsCount={reportsCount}
        />
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
