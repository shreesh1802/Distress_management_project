import { useState, useRef, useEffect, useMemo } from 'react';
import { Map, Layers, ZoomIn, ZoomOut, Compass, X, ShieldAlert, Maximize, Minimize } from 'lucide-react';
import type { RoadDistress } from '../../types/gis';
import './GISMapContainer.css';
import LeafletMap from './LeafletMap';
import L from 'leaflet';

interface GISMapContainerProps {
  distresses: RoadDistress[];
  selectedDistress: RoadDistress | null;
  onSelect: (distress: RoadDistress | null) => void;
  isLoading?: boolean;
}

export default function GISMapContainer({
  distresses,
  selectedDistress,
  onSelect,
  isLoading = false,
}: GISMapContainerProps) {
  const mapRef = useRef<L.Map | null>(null);
  const [zoomLevel, setZoomLevel] = useState<number>(5);
  const [isFullscreen, setIsFullscreen] = useState<boolean>(false);
  
  // Custom interactive overlay states
  const [searchQuery, setSearchQuery] = useState<string>('');
  const [selectedSeverities, setSelectedSeverities] = useState<string[]>(['critical', 'high', 'medium', 'low']);
  const [selectedTypes, setSelectedTypes] = useState<string[]>(['pothole', 'crack', 'rutting', 'edge_break', 'patch', 'raveling']);
  const [mouseCoords, setMouseCoords] = useState<[number, number] | null>(null);
  const [mapCenter, setMapCenter] = useState<[number, number]>([18.75, 73.40]);

  // Sync center coordinates on map panning
  useEffect(() => {
    const timer = setInterval(() => {
      if (mapRef.current) {
        const center = mapRef.current.getCenter();
        setMapCenter([center.lat, center.lng]);
      }
    }, 1000);
    return () => clearInterval(timer);
  }, []);

  // Filter markers list dynamically on client side
  const displayDistresses = useMemo(() => {
    return distresses.filter((d) => {
      // 1. Severity check
      if (!selectedSeverities.includes(d.severity.toLowerCase())) return false;

      // 2. Type check
      let mappedType = d.distressType.toLowerCase();
      if (mappedType.includes('pothole')) mappedType = 'pothole';
      else if (mappedType.includes('crack')) mappedType = 'crack';
      else if (mappedType.includes('rutting')) mappedType = 'rutting';
      else if (mappedType.includes('edge')) mappedType = 'edge_break';
      else if (mappedType.includes('patch')) mappedType = 'patch';
      
      const matchesType = selectedTypes.some(t => mappedType.includes(t));
      if (!matchesType) return false;

      // 3. Search query match
      if (searchQuery.trim() !== '') {
        const query = searchQuery.toLowerCase().trim();
        const matchesId = d.id.toLowerCase().includes(query);
        const matchesTypeLabel = d.distressType.toLowerCase().includes(query);
        const matchesLat = d.coordinates[0].toString().includes(query);
        const matchesLon = d.coordinates[1].toString().includes(query);
        return matchesId || matchesTypeLabel || matchesLat || matchesLon;
      }

      return true;
    });
  }, [distresses, searchQuery, selectedSeverities, selectedTypes]);

  // Calculate local health score of filtered section
  const localHealthScore = useMemo(() => {
    const penalty = displayDistresses.reduce((sum: number, d: RoadDistress) => {
      const w = d.severity === 'critical' ? 5.0 : d.severity === 'high' ? 3.0 : d.severity === 'medium' ? 1.5 : 0.5;
      return sum + w;
    }, 0);
    return Math.max(0, 100 - penalty);
  }, [displayDistresses]);

  // Sync fullscreen state based on document event
  useEffect(() => {
    const handleFullscreenChange = () => {
      setIsFullscreen(!!document.fullscreenElement);
    };
    document.addEventListener('fullscreenchange', handleFullscreenChange);
    return () => {
      document.removeEventListener('fullscreenchange', handleFullscreenChange);
    };
  }, []);

  const toggleFullscreen = () => {
    const element = document.querySelector('.gis-map-container__canvas-wrapper');
    if (!element) return;
    if (!document.fullscreenElement) {
      element.requestFullscreen().catch(() => {});
    } else {
      document.exitFullscreen().catch(() => {});
    }
  };

  // Zoom controls linking to Leaflet map instance
  const handleZoomIn = () => {
    if (mapRef.current) {
      mapRef.current.zoomIn();
    }
  };

  const handleZoomOut = () => {
    if (mapRef.current) {
      mapRef.current.zoomOut();
    }
  };

  const handleSearchSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (displayDistresses.length > 0) {
      onSelect(displayDistresses[0]);
    }
  };

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

  const formatDistressType = (type: string) => {
    return type.replace('_', ' ').charAt(0).toUpperCase() + type.replace('_', ' ').slice(1);
  };

  // Calculate counts for Active Filter Summary Bar
  const summaryCounts = displayDistresses.reduce(
    (acc: any, d: RoadDistress) => {
      acc.total += 1;
      if (d.severity in acc.severities) {
        acc.severities[d.severity as keyof typeof acc.severities] += 1;
      }
      return acc;
    },
    {
      total: 0,
      severities: {
        critical: 0,
        high: 0,
        medium: 0,
        low: 0,
      },
    }
  );

  return (
    <section className="gis-map-container" aria-labelledby="map-title">
      {/* Header bar */}
      <header className="gis-map-container__header">
        <div className="gis-map-container__title-wrapper">
          <Map className="gis-map-container__icon" size={20} />
          <h2 id="map-title" className="gis-map-container__title">
            Road Distress Map
          </h2>
        </div>
        <div className="gis-map-container__actions">
          <span className="gis-map-container__zoom-level">
            Zoom: {zoomLevel}
          </span>
          <button className="gis-map-container__action-btn" title="Map Layers" type="button">
            <Layers size={16} />
          </button>
          <button
            className="gis-map-container__action-btn"
            title={isFullscreen ? "Exit Fullscreen" : "Fullscreen"}
            type="button"
            onClick={toggleFullscreen}
          >
            {isFullscreen ? <Minimize size={16} /> : <Maximize size={16} />}
          </button>
          <button
            className="gis-map-container__action-btn"
            title="Zoom In"
            type="button"
            onClick={handleZoomIn}
            disabled={zoomLevel >= 18 || isLoading}
          >
            <ZoomIn size={16} />
          </button>
          <button
            className="gis-map-container__action-btn"
            title="Zoom Out"
            type="button"
            onClick={handleZoomOut}
            disabled={zoomLevel <= 3 || isLoading}
          >
            <ZoomOut size={16} />
          </button>
        </div>
      </header>

      {/* KPI Strip */}
      <div className="gis-map-container__kpi-strip">
        <div className="gis-map-container__kpi-card">
          <span className="gis-map-container__kpi-lbl">Vehicles</span>
          <strong className="gis-map-container__kpi-val">1 Active</strong>
        </div>
        <div className="gis-map-container__kpi-card">
          <span className="gis-map-container__kpi-lbl">Active Distresses</span>
          <strong className="gis-map-container__kpi-val">{isLoading ? '...' : distresses.length}</strong>
        </div>
        <div className="gis-map-container__kpi-card gis-map-container__kpi-card--critical">
          <span className="gis-map-container__kpi-lbl">Critical Alerts</span>
          <strong className="gis-map-container__kpi-val">
            {isLoading ? '...' : distresses.filter((d) => d.severity === 'critical').length}
          </strong>
        </div>
        <div className="gis-map-container__kpi-card">
          <span className="gis-map-container__kpi-lbl">Surveyed Today</span>
          <strong className="gis-map-container__kpi-val">412.8 km</strong>
        </div>
        <div className="gis-map-container__kpi-card gis-map-container__kpi-card--accuracy">
          <span className="gis-map-container__kpi-lbl">AI Accuracy</span>
          <strong className="gis-map-container__kpi-val">94.6%</strong>
        </div>
      </div>

      {/* Active Filter Summary Bar */}
      <div className="gis-map-container__filter-summary">
        <div className="gis-map-container__summary-pill">
          <span className="gis-map-container__summary-dot" />
          <span className="gis-map-container__summary-text">
            Total: <strong>{isLoading ? '...' : summaryCounts.total}</strong>
          </span>
        </div>
        <div className="gis-map-container__summary-pill gis-map-container__summary-pill--critical">
          <span className="gis-map-container__summary-dot" />
          <span className="gis-map-container__summary-text">
            Critical: <strong>{isLoading ? '...' : summaryCounts.severities.critical}</strong>
          </span>
        </div>
        <div className="gis-map-container__summary-pill gis-map-container__summary-pill--high">
          <span className="gis-map-container__summary-dot" />
          <span className="gis-map-container__summary-text">
            High: <strong>{isLoading ? '...' : summaryCounts.severities.high}</strong>
          </span>
        </div>
        <div className="gis-map-container__summary-pill gis-map-container__summary-pill--medium">
          <span className="gis-map-container__summary-dot" />
          <span className="gis-map-container__summary-text">
            Medium: <strong>{isLoading ? '...' : summaryCounts.severities.medium}</strong>
          </span>
        </div>
        <div className="gis-map-container__summary-pill gis-map-container__summary-pill--low">
          <span className="gis-map-container__summary-dot" />
          <span className="gis-map-container__summary-text">
            Low: <strong>{isLoading ? '...' : summaryCounts.severities.low}</strong>
          </span>
        </div>
      </div>

      <div className="gis-map-container__canvas-wrapper">
        {/* Shimmer loading skeleton overlay */}
        {isLoading && (
          <div className="gis-map-container__loading-overlay" aria-live="polite">
            <div className="gis-map-container__loading-spinner" />
            <span className="gis-map-container__loading-text shimmer-text">Loading Geospatial Data...</span>
          </div>
        )}

        {/* Floating Search & Filter Toolbox */}
        {!isLoading && (
          <div className="gis-map-container__toolbox" style={{ position: 'absolute', top: '10px', left: '10px', zIndex: 10, background: 'rgba(15, 23, 42, 0.95)', border: '1px solid var(--card-border)', borderRadius: '8px', padding: '12px', width: '280px', display: 'flex', flexDirection: 'column', gap: '10px', color: 'var(--primary-text)', boxShadow: '0 4px 12px rgba(0,0,0,0.5)' }}>
            <form onSubmit={handleSearchSubmit} style={{ display: 'flex', gap: '6px' }}>
              <input 
                type="text" 
                placeholder="Search ID, Type, GPS..." 
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                style={{ flex: 1, padding: '5px 8px', fontSize: '11px', background: 'var(--body-bg)', border: '1px solid var(--card-border)', borderRadius: '4px', color: 'var(--primary-text)' }}
              />
              <button type="submit" style={{ padding: '5px 10px', background: 'var(--primary-text)', color: 'white', border: 'none', borderRadius: '4px', fontSize: '11px', cursor: 'pointer' }}>Go</button>
            </form>

            <div style={{ borderTop: '1px solid var(--card-border)', paddingTop: '8px' }}>
              <h4 style={{ fontSize: '11px', fontWeight: 700, margin: '0 0 6px 0', textTransform: 'uppercase', color: 'var(--secondary-text)' }}>Severity Filter</h4>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '4px 8px' }}>
                {['critical', 'high', 'medium', 'low'].map(sev => (
                  <label key={sev} style={{ display: 'flex', alignItems: 'center', gap: '4px', fontSize: '11px', cursor: 'pointer' }}>
                    <input 
                      type="checkbox" 
                      checked={selectedSeverities.includes(sev)}
                      onChange={() => {
                        setSelectedSeverities(prev => 
                          prev.includes(sev) ? prev.filter(s => s !== sev) : [...prev, sev]
                        );
                      }}
                    />
                    <span style={{ color: getSeverityColor(sev), fontWeight: 'bold' }}>{sev.toUpperCase()}</span>
                  </label>
                ))}
              </div>
            </div>

            <div style={{ borderTop: '1px solid var(--card-border)', paddingTop: '8px' }}>
              <h4 style={{ fontSize: '11px', fontWeight: 700, margin: '0 0 6px 0', textTransform: 'uppercase', color: 'var(--secondary-text)' }}>Distress Type Filter</h4>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr', gap: '4px' }}>
                {['pothole', 'crack', 'rutting', 'edge_break', 'patch'].map(type => (
                  <label key={type} style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '11px', cursor: 'pointer' }}>
                    <input 
                      type="checkbox" 
                      checked={selectedTypes.includes(type)}
                      onChange={() => {
                        setSelectedTypes(prev => 
                          prev.includes(type) ? prev.filter(t => t !== type) : [...prev, type]
                        );
                      }}
                    />
                    <span>{type.replace('_', ' ').charAt(0).toUpperCase() + type.replace('_', ' ').slice(1)}</span>
                  </label>
                ))}
              </div>
            </div>
          </div>
        )}

        {/* GPS Telemetry HUD */}
        {!isLoading && (
          <div className="gis-map-container__gps-card" style={{ position: 'absolute', bottom: '10px', left: '10px', zIndex: 10, background: 'rgba(15, 23, 42, 0.95)', border: '1px solid var(--card-border)', borderRadius: '8px', padding: '10px 12px', width: '220px', display: 'flex', flexDirection: 'column', gap: '4px', color: 'var(--primary-text)', fontSize: '11px', boxShadow: '0 4px 12px rgba(0,0,0,0.5)' }}>
            <h4 style={{ fontSize: '11px', fontWeight: 700, margin: '0 0 6px 0', textTransform: 'uppercase', color: '#10b981', borderBottom: '1px solid var(--card-border)', paddingBottom: '4px' }}>GPS Telemetry HUD</h4>
            <div style={{ display: 'flex', justifyContent: 'space-between' }}>
              <span style={{ color: 'var(--secondary-text)' }}>Center Lat:</span>
              <span className="font-mono">{mapCenter[0].toFixed(5)}°</span>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between' }}>
              <span style={{ color: 'var(--secondary-text)' }}>Center Lon:</span>
              <span className="font-mono">{mapCenter[1].toFixed(5)}°</span>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between' }}>
              <span style={{ color: 'var(--secondary-text)' }}>Total Detections:</span>
              <span className="font-mono font-bold">{distresses.length}</span>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between' }}>
              <span style={{ color: 'var(--secondary-text)' }}>Visible Detections:</span>
              <span className="font-mono font-bold text-blue" style={{ color: 'var(--accent-blue)' }}>{displayDistresses.length}</span>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between' }}>
              <span style={{ color: 'var(--secondary-text)' }}>Section Health:</span>
              <span className="font-mono font-bold text-amber" style={{ color: '#f59e0b' }}>{localHealthScore}%</span>
            </div>
          </div>
        )}

        {/* React Leaflet Map */}
        <LeafletMap
          distresses={displayDistresses}
          selectedDistress={selectedDistress}
          onSelect={onSelect}
          mapRef={mapRef}
          onZoomChange={setZoomLevel}
          onMouseMoveCoords={setMouseCoords}
        />

        {/* Floating Compass */}
        <div className="gis-map-container__compass">
          <Compass size={24} />
        </div>

        {/* Marker Count Badge (Top-Right of Map) */}
        {!isLoading && (
          <div className="gis-map-container__count-badge">
            <span className="gis-map-container__count-badge-val">{displayDistresses.length}</span>
            <span className="gis-map-container__count-badge-lbl">Visible</span>
          </div>
        )}

        {/* Floating Selected Marker Info Card */}
        {!isLoading && selectedDistress && (
          <div className="gis-map-container__floating-card">
            <header className="gis-map-container__floating-card-header">
              <div className="gis-map-container__floating-card-title-group">
                <ShieldAlert
                  size={15}
                  style={{ color: getSeverityColor(selectedDistress.severity) }}
                />
                <span className="gis-map-container__floating-card-title">
                  {selectedDistress.id}
                </span>
              </div>
              <button
                className="gis-map-container__floating-card-close"
                type="button"
                onClick={() => onSelect(null)}
                aria-label="Close detail card"
              >
                <X size={14} />
              </button>
            </header>
            <div className="gis-map-container__floating-card-body">
              <div className="gis-map-container__floating-card-row">
                <span className="gis-map-container__floating-card-lbl">Location:</span>
                <span className="gis-map-container__floating-card-val truncate">
                  {selectedDistress.location}
                </span>
              </div>
              <div className="gis-map-container__floating-card-row">
                <span className="gis-map-container__floating-card-lbl">Type:</span>
                <span className="gis-map-container__floating-card-val">
                  {formatDistressType(selectedDistress.distressType)}
                </span>
              </div>
              <div className="gis-map-container__floating-card-row">
                <span className="gis-map-container__floating-card-lbl">Severity:</span>
                <span
                  className="gis-map-container__floating-card-val font-semibold"
                  style={{ color: getSeverityColor(selectedDistress.severity) }}
                >
                  {selectedDistress.severity.toUpperCase()}
                </span>
              </div>
              <div className="gis-map-container__floating-card-row">
                <span className="gis-map-container__floating-card-lbl">Confidence:</span>
                <span className="gis-map-container__floating-card-val">
                  {selectedDistress.confidence}%
                </span>
              </div>
              <div className="gis-map-container__floating-card-row">
                <span className="gis-map-container__floating-card-lbl">Last Updated:</span>
                <span className="gis-map-container__floating-card-val">
                  {selectedDistress.lastInspectionDate}
                </span>
              </div>
            </div>
          </div>
        )}

        {/* Centered Placeholder Text (Only overlay when map has no items and not loading) */}
        {!isLoading && displayDistresses.length === 0 && (
          <div className="gis-map-container__overlay" aria-hidden="true">
            <p className="gis-map-container__placeholder-text">
              Interactive GIS Map will be displayed here
            </p>
            <span className="gis-map-container__placeholder-subtext">
              No distress data matches the current filters.
            </span>
          </div>
        )}
      </div>

      {/* Footer / Legends */}
      <footer className="gis-map-container__footer" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div className="gis-map-container__legend">
          <span className="gis-map-container__legend-title">Legend:</span>
          <div className="gis-map-container__legend-item">
            <span className="gis-map-container__legend-icon gis-map-container__legend-icon--vehicle" />
            <span>Vehicle</span>
          </div>
          <div className="gis-map-container__legend-item">
            <span className="gis-map-container__legend-dot gis-map-container__legend-dot--critical" />
            <span>Critical</span>
          </div>
          <div className="gis-map-container__legend-item">
            <span className="gis-map-container__legend-dot gis-map-container__legend-dot--high" />
            <span>High</span>
          </div>
          <div className="gis-map-container__legend-item">
            <span className="gis-map-container__legend-dot gis-map-container__legend-dot--medium" />
            <span>Medium</span>
          </div>
          <div className="gis-map-container__legend-item">
            <span className="gis-map-container__legend-dot gis-map-container__legend-dot--low" />
            <span>Low</span>
          </div>
          <div className="gis-map-container__legend-item">
            <span className="gis-map-container__legend-route-line" />
            <span>Highway Routes</span>
          </div>
        </div>
        <div style={{ display: 'flex', gap: '20px', alignItems: 'center' }}>
          <div className="gis-map-container__scale font-mono" style={{ fontSize: '11px', color: 'var(--secondary-text)' }}>
            {mouseCoords ? `Cursor: ${mouseCoords[0].toFixed(5)}° N, ${mouseCoords[1].toFixed(5)}° E` : 'Cursor: --'}
          </div>
          <div className="gis-map-container__scale">Scale 1 : 250,000</div>
        </div>
      </footer>
    </section>
  );
}
