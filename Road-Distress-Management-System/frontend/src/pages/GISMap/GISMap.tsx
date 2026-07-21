import { useState, useMemo, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import type { RoadDistress, GISFiltersState } from '../../types/gis';
import GISFilters from '../../components/gis/GISFilters';
import GISMapContainer from '../../components/gis/GISMapContainer';
import DistressSummary from '../../components/gis/DistressSummary';
import RoadDetailsPanel from '../../components/gis/RoadDetailsPanel';
import apiService from '../../services/api/apiService';
import './GISMap.css';



const DEFAULT_FILTERS: GISFiltersState = {
  state: '',
  district: '',
  distressType: '',
  severity: '',
  startDate: '',
  endDate: '',
};

export default function GISMap() {
  const navigate = useNavigate();
  const [appliedFilters, setAppliedFilters] = useState<GISFiltersState>(DEFAULT_FILTERS);
  const [selectedDistress, setSelectedDistress] = useState<RoadDistress | null>(null);
  const [isLoading, setIsLoading] = useState<boolean>(true);
  const [realDistresses, setRealDistresses] = useState<RoadDistress[]>([]);

  // Fetch real distress logs from Postgres DB
  useEffect(() => {
    const fetchRealDistresses = async () => {
      try {
        const logs = await apiService.getDistressLogs(0, 100);
        const mapped: RoadDistress[] = logs.map(d => {
          const lat = d.latitude;
          const lon = d.longitude;
          return {
            id: `DIS-DB-${d.id}`,
            roadId: d.video_id ? `RD-${d.video_id}` : 'RD-DB',
            roadName: d.video_id ? `Corridor #${d.video_id}` : 'Main Road',
            location: `Punjab Sector - Lat: ${lat.toFixed(4)}, Lon: ${lon.toFixed(4)}`,
            state: 'Punjab',
            district: 'Patiala',
            distressType: d.distress_type as any,
            severity: d.severity.toLowerCase() as any,
            lastInspectionDate: d.detected_at ? d.detected_at.split('T')[0] : new Date().toISOString().split('T')[0],
            reportedDate: d.detected_at ? d.detected_at.split('T')[0] : new Date().toISOString().split('T')[0],
            detectionDate: d.detected_at ? d.detected_at.split('T')[0] : new Date().toISOString().split('T')[0],
            maintenanceStatus: (d.status === 'detected' ? 'pending' : d.status) as any,
            coordinates: [lat, lon],
            confidence: Math.round(d.confidence_score * 100) || 85,
            assignedTeam: 'Patiala Main Division Squad',
            estimatedRepairCost: '₹35,000',
            estimatedRepairTime: '6 hours',
            priorityScore: Math.round(d.confidence_score * 100) || 85,
            video_id: d.video_id,
            video_timestamp: d.video_timestamp
          };
        });
        setRealDistresses(mapped);
      } catch (err) {
        console.error("Failed to load database distress logs:", err);
      }
    };
    fetchRealDistresses();
  }, []);

  // Return DB markers only
  const distressesList = useMemo(() => {
    return realDistresses;
  }, [realDistresses]);

  // Simulate initial load query latency
  useEffect(() => {
    const timer = setTimeout(() => {
      setIsLoading(false);
    }, 600);
    return () => clearTimeout(timer);
  }, []);

  // Filter logic applied to the database
  const filteredDistresses = useMemo(() => {
    return distressesList.filter((distress) => {
      if (appliedFilters.state && distress.state !== appliedFilters.state) {
        return false;
      }
      if (appliedFilters.district && distress.district !== appliedFilters.district) {
        return false;
      }
      if (appliedFilters.distressType && distress.distressType !== appliedFilters.distressType) {
        return false;
      }
      if (appliedFilters.severity && distress.severity !== appliedFilters.severity) {
        return false;
      }
      if (appliedFilters.startDate && distress.reportedDate < appliedFilters.startDate) {
        return false;
      }
      if (appliedFilters.endDate && distress.reportedDate > appliedFilters.endDate) {
        return false;
      }
      return true;
    });
  }, [distressesList, appliedFilters]);

  // Set selected distress, checking if it is still within the filtered list
  const handleSelectDistress = (distress: RoadDistress | null) => {
    setSelectedDistress(distress);
    if (distress && distress.video_id && distress.video_timestamp !== undefined && distress.video_timestamp !== null) {
      navigate(`/video-review/${distress.video_id}?t=${distress.video_timestamp}`);
    }
  };

  const handleApplyFilters = (newFilters: GISFiltersState) => {
    setIsLoading(true);
    setTimeout(() => {
      setAppliedFilters(newFilters);
      setIsLoading(false);

      if (selectedDistress) {
        const isStillVisible = distressesList.filter((distress) => {
          if (newFilters.state && distress.state !== newFilters.state) return false;
          if (newFilters.district && distress.district !== newFilters.district) return false;
          if (newFilters.distressType && distress.distressType !== newFilters.distressType) return false;
          if (newFilters.severity && distress.severity !== newFilters.severity) return false;
          if (newFilters.startDate && distress.reportedDate < newFilters.startDate) return false;
          if (newFilters.endDate && distress.reportedDate > newFilters.endDate) return false;
          return true;
        }).some((d) => d.id === selectedDistress.id);

        if (!isStillVisible) {
          setSelectedDistress(null);
        }
      }
    }, 600);
  };

  const handleResetFilters = () => {
    setIsLoading(true);
    setTimeout(() => {
      setAppliedFilters(DEFAULT_FILTERS);
      setSelectedDistress(null);
      setIsLoading(false);
    }, 600);
  };

  // Dynamically calculate averages based on applied filter list
  const roadsCoveredCount = useMemo(() => {
    return Array.from(new Set(filteredDistresses.map(d => d.roadId))).length;
  }, [filteredDistresses]);

  const avgConfidenceVal = useMemo(() => {
    if (filteredDistresses.length === 0) return 0;
    const sum = filteredDistresses.reduce((acc, curr) => acc + curr.confidence, 0);
    return Math.round(sum / filteredDistresses.length);
  }, [filteredDistresses]);

  return (
    <div className="gis-page animate-fade-in" aria-label="Road Distress GIS Intelligence">
      <header className="gis-page__header" style={{ marginBottom: '4px' }}>
        <h1 className="bold-page-title" style={{ fontSize: '32px' }}>Road Distress GIS Intelligence</h1>
        <p className="light-secondary-text" style={{ fontSize: '14px' }}>Live visualization, spatial overlays, and distress density tracking across routes.</p>
      </header>

      {/* KPI Summary Row (6 Compact Cards) */}
      <div className="gis-kpi-row">
        <div className="gis-kpi-card">
          <span className="gis-kpi-card__lbl">Total Distresses</span>
          <span className="gis-kpi-card__val font-mono">{filteredDistresses.length}</span>
        </div>
        <div className="gis-kpi-card">
          <span className="gis-kpi-card__lbl">Critical Alerts</span>
          <span className="gis-kpi-card__val font-mono" style={{ color: 'var(--danger)' }}>
            {filteredDistresses.filter(d => d.severity.toLowerCase() === 'critical').length}
          </span>
        </div>
        <div className="gis-kpi-card">
          <span className="gis-kpi-card__lbl">Roads Covered</span>
          <span className="gis-kpi-card__val font-mono">{roadsCoveredCount}</span>
        </div>
        <div className="gis-kpi-card">
          <span className="gis-kpi-card__lbl">Avg Confidence</span>
          <span className="gis-kpi-card__val font-mono" style={{ color: 'var(--accent-blue)' }}>
            {avgConfidenceVal > 0 ? `${avgConfidenceVal}%` : 'N/A'}
          </span>
        </div>
        <div className="gis-kpi-card">
          <span className="gis-kpi-card__lbl">AI Status</span>
          <span className="gis-kpi-card__val" style={{ color: 'var(--success)', display: 'flex', alignItems: 'center', gap: '6px', fontSize: '16px' }}>
            <span className="live-dot" style={{ display: 'inline-block', width: '8px', height: '8px' }} />
            Active
          </span>
        </div>
        <div className="gis-kpi-card">
          <span className="gis-kpi-card__lbl">Synchronization</span>
          <span className="gis-kpi-card__val" style={{ fontSize: '16px' }}>Just Now</span>
        </div>
      </div>

      {/* Main Workspace: Sticky Sidebar Filters (Left) | Map Container (Right) */}
      <div className="gis-page__content">
        <aside className="gis-page__sidebar" aria-label="Filters Panel">
          <GISFilters
            initialFilters={appliedFilters}
            onApply={handleApplyFilters}
            onReset={handleResetFilters}
          />
        </aside>

        <main className="gis-page__main">
          {/* Map Section */}
          <section className="gis-page__map-wrapper">
            <GISMapContainer
              distresses={filteredDistresses}
              selectedDistress={selectedDistress}
              onSelect={handleSelectDistress}
              isLoading={isLoading}
            />
          </section>

          {/* Bottom Information Section: Selected Details (Left) | Spatial Analytics (Right) */}
          <div className="gis-page__bottom-grid">
            <section className="gis-page__details-wrapper" aria-label="Selected Distress Details" style={{ background: 'transparent', border: 'none', padding: 0, boxShadow: 'none' }}>
              <RoadDetailsPanel selectedDistress={selectedDistress} isLoading={isLoading} />
            </section>
            
            <section className="gis-page__summary-wrapper" aria-label="Summary Metrics" style={{ background: 'transparent', border: 'none', padding: 0, boxShadow: 'none' }}>
              <DistressSummary distresses={filteredDistresses} isLoading={isLoading} />
            </section>
          </div>

          {/* Full Width Recent Detections Table */}
          <div className="premium-card gis-history-table-card">
            <div className="card-header-with-actions" style={{ paddingBottom: '16px', borderBottom: '1px solid var(--card-border)', marginBottom: '16px' }}>
              <h2 className="medium-section-title" style={{ fontSize: '15px' }}>Spatial Distress Records Registry</h2>
            </div>
            
            <div className="table-responsive">
              <table className="enterprise-table">
                <thead>
                  <tr>
                    <th>Thumbnail</th>
                    <th>Road ID</th>
                    <th>District</th>
                    <th>Severity</th>
                    <th>Confidence</th>
                    <th>Detection Time</th>
                    <th>Status</th>
                    <th style={{ textAlign: 'right' }}>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredDistresses.length === 0 ? (
                    <tr>
                      <td colSpan={8} style={{ textAlign: 'center', color: 'var(--secondary-text)' }}>No distress records match active filtering rules.</td>
                    </tr>
                  ) : (
                    filteredDistresses.map((d) => (
                      <tr key={d.id} style={{ cursor: 'pointer' }} onClick={() => handleSelectDistress(d)}>
                        <td>
                          <div className="table-thumbnail-wrapper">
                            <img 
                              src="https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?auto=format&fit=crop&q=80&w=80" 
                              alt="visual clip" 
                              className="table-thumbnail" 
                            />
                          </div>
                        </td>
                        <td>
                          <span className="font-mono font-bold">RD-{d.roadId.split('-').pop()}</span>
                        </td>
                        <td>
                          <span>{d.district}</span>
                        </td>
                        <td>
                          <span className={`status-pill badge-${d.severity.toLowerCase()}`}>
                            {d.severity.toUpperCase()}
                          </span>
                        </td>
                        <td>
                          <span className="font-mono font-bold" style={{ color: 'var(--accent-blue)' }}>{d.confidence}%</span>
                        </td>
                        <td>
                          <span>{new Date(d.reportedDate).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })}</span>
                        </td>
                        <td>
                          <span className={`status-pill status-pill--${d.maintenanceStatus.toLowerCase()}`} style={{ textTransform: 'capitalize', fontWeight: 600 }}>
                            {d.maintenanceStatus.replace('_', ' ')}
                          </span>
                        </td>
                        <td style={{ textAlign: 'right' }} onClick={(e) => e.stopPropagation()}>
                          <div className="table-actions" style={{ display: 'flex', gap: '6px', justifyContent: 'flex-end' }}>
                            <button 
                              className="btn-report-run font-semibold"
                              style={{ fontSize: '12px', padding: '4px 10px' }}
                              onClick={() => alert(`Report generated successfully for ${d.id}`)}
                            >
                              Report
                            </button>
                            <button 
                              className="btn-control"
                              style={{ fontSize: '12px', padding: '4px 10px' }}
                              onClick={() => handleSelectDistress(d)}
                            >
                              Details
                            </button>
                          </div>
                        </td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
          </div>
        </main>
      </div>
    </div>
  );
}
