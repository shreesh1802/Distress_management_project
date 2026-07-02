import { X, Activity, DollarSign, Calendar, MapPin, Navigation, Info } from 'lucide-react';
import type { HighwayRoute } from './routes';

interface RoadInfoPanelProps {
  route: HighwayRoute | null;
  onClose: () => void;
}

export default function RoadInfoPanel({ route, onClose }: RoadInfoPanelProps) {
  if (!route) return null;

  return (
    <div className="road-info-panel animate-slide-in">
      <header className="road-info-panel__header">
        <div className="road-info-panel__title-group">
          <Info size={16} className="road-info-panel__info-icon" />
          <h3 className="road-info-panel__title">Corridor Details</h3>
        </div>
        <button
          type="button"
          onClick={onClose}
          className="road-info-panel__close-btn"
          aria-label="Close road details panel"
        >
          <X size={15} />
        </button>
      </header>

      <div className="road-info-panel__body">
        {/* Road Identifier */}
        <div className="road-info-panel__hero">
          <h4 className="road-info-panel__road-name">{route.name}</h4>
          <span className="road-info-panel__road-len">{route.length}</span>
        </div>

        {/* Detailed Stats list */}
        <div className="road-info-panel__stats">
          <div className="road-info-panel__stat-row">
            <div className="road-info-panel__stat-lbl">
              <MapPin size={13} />
              <span>States</span>
            </div>
            <strong className="road-info-panel__stat-val">{route.states.join(', ')}</strong>
          </div>

          <div className="road-info-panel__stat-row">
            <div className="road-info-panel__stat-lbl">
              <MapPin size={13} />
              <span>Districts</span>
            </div>
            <strong className="road-info-panel__stat-val truncate-2-lines" title={route.districts.join(', ')}>
              {route.districts.join(', ')}
            </strong>
          </div>

          <div className="road-info-panel__stat-row">
            <div className="road-info-panel__stat-lbl">
              <Navigation size={13} />
              <span>Assigned Vehicle</span>
            </div>
            <strong className="road-info-panel__stat-val">{route.activeVehicle}</strong>
          </div>

          <div className="road-info-panel__stat-row">
            <div className="road-info-panel__stat-lbl">
              <Activity size={13} />
              <span>Active Detections</span>
            </div>
            <strong className="road-info-panel__stat-val font-mono">{route.activeDistresses}</strong>
          </div>

          <div className="road-info-panel__stat-row">
            <div className="road-info-panel__stat-lbl">
              <Activity size={13} />
              <span>Average Severity</span>
            </div>
            <strong
              className="road-info-panel__stat-val uppercase font-bold"
              style={{
                color:
                  route.averageSeverity === 'critical'
                    ? '#ef4444'
                    : route.averageSeverity === 'high'
                    ? '#f97316'
                    : route.averageSeverity === 'medium'
                    ? '#eab308'
                    : '#22c55e',
              }}
            >
              {route.averageSeverity}
            </strong>
          </div>

          <div className="road-info-panel__stat-row">
            <div className="road-info-panel__stat-lbl">
              <DollarSign size={13} />
              <span>Est. Repair Cost</span>
            </div>
            <strong className="road-info-panel__stat-val text-accent-blue">{route.estimatedRepairCost}</strong>
          </div>

          <div className="road-info-panel__stat-row">
            <div className="road-info-panel__stat-lbl">
              <Calendar size={13} />
              <span>Last Survey Date</span>
            </div>
            <strong className="road-info-panel__stat-val font-mono">{route.lastSurvey}</strong>
          </div>
        </div>
      </div>
    </div>
  );
}
