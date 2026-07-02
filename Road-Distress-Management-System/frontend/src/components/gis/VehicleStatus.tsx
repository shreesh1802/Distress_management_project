import { Compass, Radio, Zap } from 'lucide-react';
import type { VehicleData } from './VehicleMarker';

interface VehicleStatusProps {
  data: VehicleData | null;
}

export default function VehicleStatus({ data }: VehicleStatusProps) {
  if (!data) {
    return (
      <div className="vehicle-status-widget">
        <div className="vehicle-status-widget__loading">
          <span className="status-indicatorstatus-indicator--inactive" />
          <span>Vehicle Offline</span>
        </div>
      </div>
    );
  }

  return (
    <div className="vehicle-status-widget animate-slide-in">
      <header className="vehicle-status-widget__header">
        <div className="vehicle-status-widget__title-group">
          <Radio size={14} className="vehicle-status-widget__live-icon" />
          <span className="vehicle-status-widget__title">Live Vehicle: {data.vehicleId}</span>
        </div>
        <div className="vehicle-status-widget__gps">
          <span className="gps-indicator gps-indicator--active" />
          <span className="gps-label">GPS CONNECTED</span>
        </div>
      </header>

      <div className="vehicle-status-widget__body">
        {/* Main Stats Row */}
        <div className="vehicle-status-widget__row">
          <div className="vehicle-status-widget__item">
            <span className="vehicle-status-widget__label">Speed</span>
            <div className="vehicle-status-widget__value-group">
              <Zap size={13} className="text-warning" />
              <strong className="vehicle-status-widget__value font-mono">{data.speed} km/h</strong>
            </div>
          </div>
          <div className="vehicle-status-widget__item">
            <span className="vehicle-status-widget__label">Heading</span>
            <div className="vehicle-status-widget__value-group">
              <Compass size={13} className="text-info" />
              <strong className="vehicle-status-widget__value">{data.heading}</strong>
            </div>
          </div>
        </div>

        {/* Info Rows */}
        <div className="vehicle-status-widget__info-list">
          <div className="vehicle-status-widget__info-row">
            <span>Location:</span>
            <strong>{data.roadName}</strong>
          </div>
          <div className="vehicle-status-widget__info-row">
            <span>Chainage:</span>
            <strong className="font-mono text-accent-blue">{data.chainage}</strong>
          </div>
          <div className="vehicle-status-widget__info-row">
            <span>State:</span>
            <strong className="text-success">{data.status}</strong>
          </div>
          <div className="vehicle-status-widget__info-row">
            <span>Last GPS Ping:</span>
            <strong className="font-mono">{data.lastUpdate}</strong>
          </div>
        </div>
      </div>
    </div>
  );
}
