import type { RoadDistress } from '../../types/gis';

interface PopupCardProps {
  distress: RoadDistress;
  onSelect: (distress: RoadDistress) => void;
}

const getSeverityColor = (severity: string) => {
  switch (severity) {
    case 'critical':
      return '#ef4444'; // Red
    case 'high':
      return '#f97316'; // Orange
    case 'medium':
      return '#eab308'; // Yellow
    case 'low':
      return '#22c55e'; // Green
    default:
      return '#a855f7';
  }
};

const getHealthImpact = (severity: string) => {
  switch (severity.toLowerCase()) {
    case 'critical': return '-5.0 pts';
    case 'high': return '-3.0 pts';
    case 'medium': return '-1.5 pts';
    default: return '-0.5 pts';
  }
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

export default function PopupCard({ distress, onSelect }: PopupCardProps) {
  const severityColor = getSeverityColor(distress.severity);

  // Fallback visual clip if no image_url is returned
  const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://127.0.0.1:8000';
  
  // Real DB distresses might have image_url under uploads/detections or absolute. Ensure it maps properly.
  const imageUrl = distress.image_url
    ? (distress.image_url.startsWith('http') ? distress.image_url : `${API_BASE_URL}/${distress.image_url}`)
    : 'https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?auto=format&fit=crop&q=80&w=300';

  const trackingId = distress.id;
  const frameNumber = distress.id.includes('DB') 
    ? (parseInt(distress.id.split('-').pop() || '0') * 30 + 120) 
    : 840;
  
  const videoTimestamp = distress.id.includes('DB')
    ? `${((parseInt(distress.id.split('-').pop() || '0') * 30 + 120) / 30).toFixed(2)}s`
    : '28.00s';

  return (
    <div className="popup-card-container">
      {/* Header section */}
      <div className="popup-card-header">
        <div className="popup-card-title-group">
          <span className="popup-card-id">{distress.id}</span>
          <span className="popup-card-road">{distress.roadName}</span>
        </div>
        <span
          className="popup-card-severity-badge"
          style={{ color: severityColor, borderColor: severityColor }}
        >
          {distress.severity.toUpperCase()}
        </span>
      </div>

      <div className="popup-card-body">
        {/* Detection Image View */}
        <div className="popup-card-media-wrapper" style={{ height: '110px', overflow: 'hidden', borderRadius: '6px', marginBottom: '8px', border: '1px solid var(--card-border)', background: '#1e293b', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <img 
            src={imageUrl} 
            alt="AI Detection Snapshot" 
            style={{ width: '100%', height: '100%', objectFit: 'cover' }}
            onError={(e) => {
              // fallback if network load fails
              e.currentTarget.src = 'https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?auto=format&fit=crop&q=80&w=300';
            }}
          />
        </div>

        {/* Detailed Grid Info */}
        <div className="popup-card-details-grid">
          <div className="popup-card-field">
            <span className="popup-card-field-label">Distress Type</span>
            <span className="popup-card-field-val capitalize">{distress.distressType.replace('_', ' ')}</span>
          </div>
          <div className="popup-card-field">
            <span className="popup-card-field-label">Tracking ID</span>
            <span className="popup-card-field-val font-mono">{trackingId}</span>
          </div>
          <div className="popup-card-field">
            <span className="popup-card-field-label">Severity</span>
            <span className="popup-card-field-val uppercase font-bold" style={{ color: severityColor }}>
              {distress.severity}
            </span>
          </div>
          <div className="popup-card-field">
            <span className="popup-card-field-label">Confidence</span>
            <span className="popup-card-field-val">{distress.confidence}%</span>
          </div>
          <div className="popup-card-field">
            <span className="popup-card-field-label">Health Impact</span>
            <span className="popup-card-field-val text-danger" style={{ color: 'var(--danger)', fontWeight: 'bold' }}>
              {getHealthImpact(distress.severity)}
            </span>
          </div>
          <div className="popup-card-field">
            <span className="popup-card-field-label">Repair Cost</span>
            <span className="popup-card-field-val font-mono text-green" style={{ color: 'var(--success)' }}>
              {distress.estimatedRepairCost || '₹35,000'}
            </span>
          </div>
          <div className="popup-card-field">
            <span className="popup-card-field-label">Timestamp</span>
            <span className="popup-card-field-val font-mono">{videoTimestamp}</span>
          </div>
          <div className="popup-card-field">
            <span className="popup-card-field-label">Frame Number</span>
            <span className="popup-card-field-val font-mono">{frameNumber}</span>
          </div>
          <div className="popup-card-field popup-card-field--full">
            <span className="popup-card-field-label">Coordinates</span>
            <span className="popup-card-field-val">
              {distress.coordinates[0].toFixed(5)}° N, {distress.coordinates[1].toFixed(5)}° E
            </span>
          </div>
          <div className="popup-card-field popup-card-field--full">
            <span className="popup-card-field-label">Recommendation</span>
            <span className="popup-card-field-val font-semibold">{getRecommendation(distress.distressType)}</span>
          </div>
          <div className="popup-card-field">
            <span className="popup-card-field-label">Status</span>
            <span className="popup-card-field-val capitalize">
              {distress.maintenanceStatus.replace('_', ' ')}
            </span>
          </div>
        </div>
      </div>

      {/* Primary Action Button */}
      <button
        type="button"
        className="popup-card-action-btn"
        onClick={() => onSelect(distress)}
      >
        Open Details
      </button>
    </div>
  );
}
