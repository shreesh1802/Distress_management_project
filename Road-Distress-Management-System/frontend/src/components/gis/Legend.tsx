import { useState } from 'react';
import { ChevronDown, ChevronUp, Map } from 'lucide-react';

export default function Legend() {
  const [isOpen, setIsOpen] = useState(true);

  return (
    <div className="floating-legend">
      <header className="floating-legend__header" onClick={() => setIsOpen(!isOpen)}>
        <div className="floating-legend__title-group">
          <Map size={14} className="floating-legend__icon" />
          <span className="floating-legend__title">Map Legend</span>
        </div>
        <button type="button" className="floating-legend__toggle">
          {isOpen ? <ChevronDown size={14} /> : <ChevronUp size={14} />}
        </button>
      </header>

      {isOpen && (
        <div className="floating-legend__body animate-fade-in">
          {/* Vehicle Indicator */}
          <div className="floating-legend__item">
            <span className="legend-vehicle-bullet" />
            <span>Surveying Vehicle</span>
          </div>

          {/* Distress Severities */}
          <div className="floating-legend__item">
            <span className="legend-dot-bullet legend-dot-bullet--critical" />
            <span>Critical Severity (Red)</span>
          </div>
          <div className="floating-legend__item">
            <span className="legend-dot-bullet legend-dot-bullet--high" />
            <span>High Severity (Orange)</span>
          </div>
          <div className="floating-legend__item">
            <span className="legend-dot-bullet legend-dot-bullet--medium" />
            <span>Medium Severity (Yellow)</span>
          </div>
          <div className="floating-legend__item">
            <span className="legend-dot-bullet legend-dot-bullet--low" />
            <span>Low Severity (Green)</span>
          </div>

          {/* Highway Route */}
          <div className="floating-legend__item">
            <span className="legend-route-bullet" />
            <span>Highway Routes (NH-48/NH-44)</span>
          </div>

          {/* Chainage Milestones */}
          <div className="floating-legend__item">
            <span className="legend-milestone-bullet" />
            <span>Chainage Milestones (20km spacing)</span>
          </div>
        </div>
      )}
    </div>
  );
}
