import { useState, useMemo, useEffect } from 'react';
import type { RoadDistress, GISFiltersState } from '../../types/gis';
import GISFilters from '../../components/gis/GISFilters';
import GISMapContainer from '../../components/gis/GISMapContainer';
import DistressSummary from '../../components/gis/DistressSummary';
import RoadDetailsPanel from '../../components/gis/RoadDetailsPanel';
import apiService from '../../services/api/apiService';
import './GISMap.css';

// Centralized mock database of 15 road distress records
const MOCK_DISTRESS_DB: RoadDistress[] = [
  {
    id: 'DIS-MH-4801',
    roadId: 'RD-MH-48',
    roadName: 'NH-48',
    location: 'KM 42.5 near Lonavala Ghats',
    state: 'Maharashtra',
    district: 'Pune',
    distressType: 'pothole',
    severity: 'critical',
    lastInspectionDate: '2026-06-10',
    maintenanceStatus: 'pending',
    coordinates: [18.75, 73.40],
    reportedDate: '2026-06-08',
    confidence: 94,
    detectionDate: '2026-06-08',
    assignedTeam: 'Not Assigned',
    estimatedRepairCost: '₹75,000',
    estimatedRepairTime: '6 hours',
    priorityScore: 94,
  },
  {
    id: 'DIS-MH-4802',
    roadId: 'RD-MH-48',
    roadName: 'NH-48',
    location: 'KM 122.1 near Hinjewadi Exit',
    state: 'Maharashtra',
    district: 'Pune',
    distressType: 'crack',
    severity: 'high',
    lastInspectionDate: '2026-06-12',
    maintenanceStatus: 'in_progress',
    coordinates: [18.59, 73.71],
    reportedDate: '2026-06-11',
    confidence: 88,
    detectionDate: '2026-06-11',
    assignedTeam: 'Pune Division Crew B',
    estimatedRepairCost: '₹1,20,000',
    estimatedRepairTime: '2 days',
    priorityScore: 85,
  },
  {
    id: 'DIS-MH-0304',
    roadId: 'RD-MH-EE',
    roadName: 'Eastern Express Highway',
    location: 'KM 12.8, Ghatkopar Flyover south ramp',
    state: 'Maharashtra',
    district: 'Mumbai',
    distressType: 'rutting',
    severity: 'medium',
    lastInspectionDate: '2026-05-28',
    maintenanceStatus: 'completed',
    coordinates: [19.08, 72.91],
    reportedDate: '2026-05-25',
    confidence: 76,
    detectionDate: '2026-05-25',
    assignedTeam: 'Mumbai MMRDA Crew A',
    estimatedRepairCost: '₹2,10,000',
    estimatedRepairTime: '3 days',
    priorityScore: 55,
  },
  {
    id: 'DIS-MH-4805',
    roadId: 'RD-MH-48',
    roadName: 'NH-48',
    location: 'KM 85.0 near Talegaon Toll plaza',
    state: 'Maharashtra',
    district: 'Thane',
    distressType: 'edge_break',
    severity: 'high',
    lastInspectionDate: '2026-06-13',
    maintenanceStatus: 'scheduled',
    coordinates: [19.20, 73.01],
    reportedDate: '2026-06-12',
    confidence: 91,
    detectionDate: '2026-06-12',
    assignedTeam: 'Thane Maintenance Squad',
    estimatedRepairCost: '₹95,000',
    estimatedRepairTime: '1.5 days',
    priorityScore: 80,
  },
  {
    id: 'DIS-KA-4801',
    roadId: 'RD-KA-48',
    roadName: 'NH-48',
    location: 'KM 14.5, Nelamangala Highway toll plaza',
    state: 'Karnataka',
    district: 'Bengaluru',
    distressType: 'pothole',
    severity: 'high',
    lastInspectionDate: '2026-06-14',
    maintenanceStatus: 'pending',
    coordinates: [13.10, 77.38],
    reportedDate: '2026-06-13',
    confidence: 92,
    detectionDate: '2026-06-13',
    assignedTeam: 'Not Assigned',
    estimatedRepairCost: '₹45,000',
    estimatedRepairTime: '4 hours',
    priorityScore: 88,
  },
  {
    id: 'DIS-KA-1702',
    roadId: 'RD-KA-17',
    roadName: 'SH-17',
    location: 'KM 18.2 near Kengeri metro pillar 45',
    state: 'Karnataka',
    district: 'Bengaluru',
    distressType: 'patch',
    severity: 'low',
    lastInspectionDate: '2026-06-01',
    maintenanceStatus: 'scheduled',
    coordinates: [12.89, 77.48],
    reportedDate: '2026-05-29',
    confidence: 81,
    detectionDate: '2026-05-29',
    assignedTeam: 'Bengaluru South Crew 1',
    estimatedRepairCost: '₹50,000',
    estimatedRepairTime: '1.5 days',
    priorityScore: 28,
  },
  {
    id: 'DIS-KA-1705',
    roadId: 'RD-KA-17',
    roadName: 'SH-17',
    location: 'KM 98.2 Mandya bypass junction',
    state: 'Karnataka',
    district: 'Mysore',
    distressType: 'patch',
    severity: 'medium',
    lastInspectionDate: '2026-05-15',
    maintenanceStatus: 'completed',
    coordinates: [12.52, 76.90],
    reportedDate: '2026-05-12',
    confidence: 85,
    detectionDate: '2026-05-12',
    assignedTeam: 'Mandya Local Division',
    estimatedRepairCost: '₹60,000',
    estimatedRepairTime: '1 day',
    priorityScore: 50,
  },
  {
    id: 'DIS-KA-4809',
    roadId: 'RD-KA-48',
    roadName: 'NH-48',
    location: 'KM 198.0 Davangere sector highway',
    state: 'Karnataka',
    district: 'Hubli',
    distressType: 'edge_break',
    severity: 'medium',
    lastInspectionDate: '2026-06-05',
    maintenanceStatus: 'in_progress',
    coordinates: [15.36, 75.12],
    reportedDate: '2026-06-04',
    confidence: 78,
    detectionDate: '2026-06-04',
    assignedTeam: 'Hubli Highway Team 3',
    estimatedRepairCost: '₹1,15,000',
    estimatedRepairTime: '2 days',
    priorityScore: 52,
  },
  {
    id: 'DIS-DL-0402',
    roadId: 'RD-DL-04',
    roadName: 'Ring Road',
    location: 'Ring Road, AIIMS flyover underpass',
    state: 'Delhi',
    district: 'South Delhi',
    distressType: 'pothole',
    severity: 'critical',
    lastInspectionDate: '2026-06-16',
    maintenanceStatus: 'pending',
    coordinates: [28.56, 77.21],
    reportedDate: '2026-06-15',
    confidence: 97,
    detectionDate: '2026-06-15',
    assignedTeam: 'Not Assigned',
    estimatedRepairCost: '₹85,000',
    estimatedRepairTime: '8 hours',
    priorityScore: 97,
  },
  {
    id: 'DIS-DL-0406',
    roadId: 'RD-DL-04',
    roadName: 'Ring Road',
    location: 'Connaught Place Outer Circle, Block G road',
    state: 'Delhi',
    district: 'New Delhi',
    distressType: 'rutting',
    severity: 'medium',
    lastInspectionDate: '2026-06-05',
    maintenanceStatus: 'scheduled',
    coordinates: [28.63, 77.22],
    reportedDate: '2026-06-04',
    confidence: 79,
    detectionDate: '2026-06-04',
    assignedTeam: 'New Delhi NDMC Squad',
    estimatedRepairCost: '₹1,10,000',
    estimatedRepairTime: '2 days',
    priorityScore: 52,
  },
  {
    id: 'DIS-DL-0902',
    roadId: 'RD-DL-NH8',
    roadName: 'NH-8',
    location: 'KM 8.2 near Dhaula Kuan flyover',
    state: 'Delhi',
    district: 'New Delhi',
    distressType: 'crack',
    severity: 'high',
    lastInspectionDate: '2026-06-11',
    maintenanceStatus: 'in_progress',
    coordinates: [28.59, 77.17],
    reportedDate: '2026-06-10',
    confidence: 89,
    detectionDate: '2026-06-10',
    assignedTeam: 'NHAI Delhi Division A',
    estimatedRepairCost: '₹1,45,000',
    estimatedRepairTime: '3 days',
    priorityScore: 81,
  },
  {
    id: 'DIS-TN-4501',
    roadId: 'RD-TN-45',
    roadName: 'NH-45',
    location: 'KM 28.5, Tambaram-Chengalpattu flyover approach',
    state: 'Tamil Nadu',
    district: 'Chennai',
    distressType: 'crack',
    severity: 'high',
    lastInspectionDate: '2026-06-09',
    maintenanceStatus: 'in_progress',
    coordinates: [12.92, 80.12],
    reportedDate: '2026-06-07',
    confidence: 90,
    detectionDate: '2026-06-07',
    assignedTeam: 'Chennai Highway Division C',
    estimatedRepairCost: '₹1,40,000',
    estimatedRepairTime: '2.5 days',
    priorityScore: 82,
  },
  {
    id: 'DIS-TN-4508',
    roadId: 'RD-TN-45',
    roadName: 'NH-45',
    location: 'KM 142 near Villupuram bypass tollway',
    state: 'Tamil Nadu',
    district: 'Madurai',
    distressType: 'rutting',
    severity: 'low',
    lastInspectionDate: '2026-05-20',
    maintenanceStatus: 'completed',
    coordinates: [9.92, 78.11],
    reportedDate: '2026-05-18',
    confidence: 83,
    detectionDate: '2026-05-18',
    assignedTeam: 'Villupuram Sector Crew',
    estimatedRepairCost: '₹85,000',
    estimatedRepairTime: '1 day',
    priorityScore: 30,
  },
  {
    id: 'DIS-TN-0204',
    roadId: 'RD-TN-EE',
    roadName: 'Inner Ring Road',
    location: 'Koyambedu junction flyover entry ramp',
    state: 'Tamil Nadu',
    district: 'Chennai',
    distressType: 'pothole',
    severity: 'critical',
    lastInspectionDate: '2026-06-17',
    maintenanceStatus: 'pending',
    coordinates: [13.07, 80.20],
    reportedDate: '2026-06-16',
    confidence: 95,
    detectionDate: '2026-06-16',
    assignedTeam: 'Not Assigned',
    estimatedRepairCost: '₹65,000',
    estimatedRepairTime: '5 hours',
    priorityScore: 95,
  },
  {
    id: 'DIS-TN-4512',
    roadId: 'RD-TN-45',
    roadName: 'NH-45',
    location: 'KM 82.5 near Melmaruvathur toll sector',
    state: 'Tamil Nadu',
    district: 'Chennai',
    distressType: 'edge_break',
    severity: 'medium',
    lastInspectionDate: '2026-06-03',
    maintenanceStatus: 'scheduled',
    coordinates: [12.44, 79.83],
    reportedDate: '2026-06-02',
    confidence: 84,
    detectionDate: '2026-06-02',
    assignedTeam: 'Chengalpattu Maintenance Crew',
    estimatedRepairCost: '₹1,05,000',
    estimatedRepairTime: '1.5 days',
    priorityScore: 53,
  },
];

const DEFAULT_FILTERS: GISFiltersState = {
  state: '',
  district: '',
  distressType: '',
  severity: '',
  startDate: '',
  endDate: '',
};

export default function GISMap() {
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
          };
        });
        setRealDistresses(mapped);
      } catch (err) {
        console.error("Failed to load database distress logs:", err);
      }
    };
    fetchRealDistresses();
  }, []);

  // Merge mock and DB markers
  const distressesList = useMemo(() => {
    return [...MOCK_DISTRESS_DB, ...realDistresses];
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
