import { useEffect, useState, useMemo } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  PieChart,
  Pie,
  Cell,
  ResponsiveContainer,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  Tooltip,
  Legend
} from 'recharts';
import {
  LayoutDashboard,
  Map,
  BarChart3,
  Video,
  FileText,
  Wrench,
  ShieldAlert,
  ChevronRight,
  Activity,
  Calendar
} from 'lucide-react';
import apiService from '../../services/api/apiService';
import type { RoadDistressResponse, UploadedVideoResponse, ReportResponse, MaintenanceTaskResponse } from '../../services/api/apiService';
import './OverviewDashboard.css';

export default function OverviewDashboard() {
  const navigate = useNavigate();

  // API states
  const [distressLogs, setDistressLogs] = useState<RoadDistressResponse[]>([]);
  const [videos, setVideos] = useState<UploadedVideoResponse[]>([]);
  const [reports, setReports] = useState<ReportResponse[]>([]);
  const [maintenanceTasks, setMaintenanceTasks] = useState<MaintenanceTaskResponse[]>([]);
  const [isLoading, setIsLoading] = useState<boolean>(true);
  const [error, setError] = useState<string | null>(null);

  // Fetch all overview statistics
  const fetchOverviewData = async () => {
    setIsLoading(true);
    setError(null);
    try {
      const [dists, vids, reps, tasks] = await Promise.all([
        apiService.getDistressLogs(0, 1000),
        apiService.getVideos(0, 200),
        apiService.getReports(0, 200),
        apiService.getMaintenanceRecommendations()
      ]);
      setDistressLogs(dists);
      setVideos(vids);
      setReports(reps);
      setMaintenanceTasks(tasks);
    } catch (err: any) {
      console.error(err);
      setError('Failed to fetch system overview datasets. Verify backend connection.');
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchOverviewData();
  }, []);

  // Computed KPIs
  const kpis = useMemo(() => {
    const totalVideos = videos.length;
    const totalDistresses = distressLogs.length;

    // Overall Road Health Score logic
    const penalty = distressLogs.reduce((sum, d) => {
      const w = d.severity.toLowerCase() === 'critical' ? 5.0 : d.severity.toLowerCase() === 'high' ? 3.0 : d.severity.toLowerCase() === 'medium' ? 1.5 : 0.5;
      return sum + w;
    }, 0);
    const healthScore = Math.max(0, Math.round(100 - penalty));

    // Total Maintenance Cost
    const totalCost = maintenanceTasks.reduce((sum, t) => sum + (t.estimated_cost || 0), 0);
    const totalCostFormatted = totalCost > 0
      ? `₹${(totalCost / 100000).toFixed(2)}L`
      : '₹0.00';

    const totalReports = reports.length;

    return {
      totalVideos,
      totalDistresses,
      healthScore,
      totalCostFormatted,
      totalReports
    };
  }, [videos, distressLogs, maintenanceTasks, reports]);

  // Video item runs mapping
  const videoRuns = useMemo(() => {
    return videos.map(vid => {
      const vidDists = distressLogs.filter(d => d.video_id === vid.id);
      const penalty = vidDists.reduce((sum, d) => {
        const w = d.severity.toLowerCase() === 'critical' ? 5.0 : d.severity.toLowerCase() === 'high' ? 3.0 : d.severity.toLowerCase() === 'medium' ? 1.5 : 0.5;
        return sum + w;
      }, 0);
      const healthScore = Math.max(0, Math.round(100 - penalty));

      return {
        ...vid,
        totalDistresses: vidDists.length,
        healthScore
      };
    }).sort((a, b) => new Date(b.upload_timestamp).getTime() - new Date(a.upload_timestamp).getTime());
  }, [videos, distressLogs]);

  // Distress Distribution data
  const distressDistributionData = useMemo(() => {
    const counts: Record<string, number> = {};
    distressLogs.forEach(d => {
      const type = d.distress_type.replace('_', ' ').toLowerCase();
      counts[type] = (counts[type] || 0) + 1;
    });
    const data = Object.keys(counts).map(key => ({
      name: key.charAt(0).toUpperCase() + key.slice(1),
      value: counts[key]
    }));
    return data.length > 0 ? data : [{ name: 'No Data', value: 1 }];
  }, [distressLogs]);

  // Severity Chart Data
  const severityChartData = useMemo(() => {
    const counts = { critical: 0, high: 0, medium: 0, low: 0 };
    distressLogs.forEach(d => {
      const sev = d.severity.toLowerCase();
      if (counts[sev] !== undefined) {
        counts[sev]++;
      }
    });
    return [
      { name: 'Critical', value: counts.critical, fill: '#ef4444' },
      { name: 'High', value: counts.high, fill: '#f97316' },
      { name: 'Medium', value: counts.medium, fill: '#eab308' },
      { name: 'Low', value: counts.low, fill: '#10b981' }
    ];
  }, [distressLogs]);

  if (isLoading) {
    return (
      <div className="dashboard-page dashboard-page--loading">
        <div className="dashboard-page__spinner-container">
          <div className="dashboard-page__spinner" />
          <p>Loading System Overview Dashboard...</p>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="dashboard-page dashboard-page--error">
        <div className="dashboard-page__error-container">
          <div className="dashboard-page__error-icon">⚠️</div>
          <h2>System Sync Issue</h2>
          <p>{error}</p>
          <button className="dashboard-page__retry-btn" onClick={fetchOverviewData}>
            Retry Data Sync
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="overview-dashboard animate-fade-in">
      <header className="overview-header">
        <h1 className="overview-title">System Overview Dashboard</h1>
        <p className="overview-subtitle">Global operational metrics, inspect status logs, and spatial distress density.</p>
      </header>

      {/* Row 1: KPI Cards */}
      <div className="overview-kpi-grid">
        <div className="overview-kpi-card">
          <div className="overview-kpi-title" style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <Video size={16} style={{ color: 'var(--primary-btn)' }} />
            <span>Total Videos Processed</span>
          </div>
          <span className="overview-kpi-value">{kpis.totalVideos}</span>
        </div>

        <div className="overview-kpi-card">
          <div className="overview-kpi-title" style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <ShieldAlert size={16} style={{ color: 'var(--danger)' }} />
            <span>Total Distresses Detected</span>
          </div>
          <span className="overview-kpi-value">{kpis.totalDistresses}</span>
        </div>

        <div className="overview-kpi-card">
          <div className="overview-kpi-title" style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <Activity size={16} style={{ color: 'var(--success)' }} />
            <span>Overall Road Health</span>
          </div>
          <span className="overview-kpi-value" style={{ color: kpis.healthScore >= 70 ? 'var(--success)' : 'var(--danger)' }}>
            {kpis.healthScore}%
          </span>
        </div>

        <div className="overview-kpi-card">
          <div className="overview-kpi-title" style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <Wrench size={16} style={{ color: '#f59e0b' }} />
            <span>Estimated Maintenance Cost</span>
          </div>
          <span className="overview-kpi-value">{kpis.totalCostFormatted}</span>
        </div>

        <div className="overview-kpi-card">
          <div className="overview-kpi-title" style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <FileText size={16} style={{ color: '#3b82f6' }} />
            <span>Total Reports Generated</span>
          </div>
          <span className="overview-kpi-value">{kpis.totalReports}</span>
        </div>
      </div>

      {/* Row 2: Charts and Layout Grid */}
      <div className="overview-main-grid">
        {/* Left Column: Recent Inspections & Visual Charts */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
          <div className="overview-section-card">
            <h2 className="overview-section-title">Recent Inspections Log</h2>
            <div className="inspections-list">
              {videoRuns.length === 0 ? (
                <p style={{ textAlign: 'center', color: 'var(--secondary-text)' }}>No videos processed yet. Use the Upload tab to submit surveillance feeds.</p>
              ) : (
                videoRuns.slice(0, 5).map(vid => (
                  <div key={vid.id} className="inspection-item-card">
                    <div className="inspection-name-group">
                      <span className="inspection-name">{vid.filename}</span>
                      <span className="inspection-date">
                        {new Date(vid.upload_timestamp).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })}
                      </span>
                    </div>

                    <div>
                      <span className={`inspection-badge-status inspection-badge-status--${vid.processing_status.toLowerCase()}`}>
                        {vid.processing_status}
                      </span>
                    </div>

                    <div>
                      <span style={{ fontSize: '11px', color: 'var(--secondary-text)' }}>Road Health</span>
                      <div className="inspection-health" style={{ color: vid.healthScore >= 75 ? 'var(--success)' : 'var(--danger)' }}>
                        {vid.healthScore}%
                      </div>
                    </div>

                    <div>
                      <span style={{ fontSize: '11px', color: 'var(--secondary-text)' }}>Distresses</span>
                      <div className="inspection-distresses">
                        {vid.totalDistresses}
                      </div>
                    </div>

                    <div>
                      <button 
                        className="btn-view-inspection" 
                        onClick={() => navigate(`/inspection/${vid.id}`)}
                      >
                        View Inspection
                      </button>
                    </div>
                  </div>
                ))
              )}
            </div>
          </div>

          <div className="overview-charts-grid">
            <div className="overview-section-card">
              <h2 className="overview-section-title">Distress Distribution</h2>
              <div style={{ height: '200px' }}>
                <ResponsiveContainer width="100%" height="100%">
                  <PieChart>
                    <Pie
                      data={distressDistributionData}
                      cx="50%"
                      cy="50%"
                      innerRadius={60}
                      outerRadius={80}
                      paddingAngle={5}
                      dataKey="value"
                    >
                      {distressDistributionData.map((entry, index) => (
                        <Cell key={`cell-${index}`} fill={['#3b82f6', '#8b5cf6', '#ec4899', '#f59e0b', '#06b6d4', '#10b981'][index % 6]} />
                      ))}
                    </Pie>
                    <Tooltip />
                  </PieChart>
                </ResponsiveContainer>
              </div>
            </div>

            <div className="overview-section-card">
              <h2 className="overview-section-title">Severity Level Detections</h2>
              <div style={{ height: '200px' }}>
                <ResponsiveContainer width="100%" height="100%">
                  <BarChart data={severityChartData}>
                    <XAxis dataKey="name" />
                    <YAxis />
                    <Tooltip />
                    <Bar dataKey="value" radius={[4, 4, 0, 0]}>
                      {severityChartData.map((entry, index) => (
                        <Cell key={`cell-${index}`} fill={entry.fill} />
                      ))}
                    </Bar>
                  </BarChart>
                </ResponsiveContainer>
              </div>
            </div>
          </div>
        </div>

        {/* Right Column: GIS projection map & Overall summary info */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
          <div className="overview-section-card">
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
              <Map size={18} style={{ color: 'var(--primary-btn)' }} />
              <h2 className="overview-section-title">Overall Spatial GIS Map</h2>
            </div>
            
            <div className="overview-gis-projection">
              <svg viewBox="0 0 800 450" className="overview-svg-projection">
                {/* Projected grid projection vectors */}
                <rect width="100%" height="100%" fill="#F3F4F6" />
                <path d="M 50,20 L 750,430 M 100,430 L 700,20 M 50,225 L 750,225" stroke="#FFFFFF" strokeWidth="12" strokeLinecap="round" />
                <path d="M 50,20 L 750,430 M 100,430 L 700,20 M 50,225 L 750,225" stroke="#E5E7EB" strokeWidth="2" strokeLinecap="round" />
                
                {/* Dynamically draw database distress points on the projected vector grid */}
                {distressLogs.slice(0, 10).map((d, index) => {
                  const x = 100 + (d.latitude * 15) % 600;
                  const y = 50 + (d.longitude * 12) % 350;
                  const fill = d.severity.toLowerCase() === 'critical' ? 'var(--danger)' : d.severity.toLowerCase() === 'high' ? 'var(--warning)' : 'var(--success)';
                  
                  return (
                    <g key={d.id} transform={`translate(${x}, ${y})`} className="gis-pin-marker">
                      <circle r="10" fill={`${fill}4D`} />
                      <circle r="6" fill={fill} />
                    </g>
                  );
                })}
              </svg>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', fontSize: '12px' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                <span style={{ color: 'var(--secondary-text)' }}>Active GIS Markers:</span>
                <span className="font-mono font-bold" style={{ color: 'var(--primary-text)' }}>{distressLogs.length}</span>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                <span style={{ color: 'var(--secondary-text)' }}>Critical Zones:</span>
                <span className="font-mono font-bold" style={{ color: 'var(--danger)' }}>
                  {distressLogs.filter(d => d.severity.toLowerCase() === 'critical').length}
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
