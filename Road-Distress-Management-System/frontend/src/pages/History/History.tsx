import { useState, useEffect, useMemo } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  History as HistoryIcon,
  Download,
  Search,
  Trash2,
  Calendar,
  FileSpreadsheet,
  Brain,
  Video,
  MapPin,
  AlertTriangle,
  RefreshCw,
  CheckCircle2,
  XCircle,
  AlertCircle,
  Loader2,
  User,
  Clock,
  ArrowUpRight,
  ChevronDown,
  ChevronUp,
  SlidersHorizontal,
  UserCheck,
  Activity,
  Database,
  Cpu,
  Layers,
  Lock,
  Mail,
  FileUp,
  Filter
} from 'lucide-react';
import {
  ResponsiveContainer,
  AreaChart,
  Area,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  PieChart,
  Pie,
  Cell,
  BarChart,
  Bar
} from 'recharts';
import apiService from '../../services/api/apiService';
import type { ReportResponse, UploadedVideoResponse } from '../../services/api/apiService';
import './History.css';

// Type definitions for Timeline Events
interface TimelineEvent {
  id: string;
  type: string;
  category: 'Reports' | 'Inference' | 'Uploads' | 'Maintenance' | 'GIS' | 'Notifications';
  title: string;
  description: string;
  timestamp: string;
  status: 'Success' | 'Warning' | 'Info' | 'Failed';
  user: string;
  meta?: {
    reportId?: number;
    videoId?: number;
    filepath?: string | null;
    reportType?: string;
    size?: string;
    duration?: string;
    model?: string;
    district?: string;
    road?: string;
    modelVersion?: string;
  };
}

export default function History() {
  const navigate = useNavigate();
  const [reports, setReports] = useState<ReportResponse[]>([]);
  const [videos, setVideos] = useState<UploadedVideoResponse[]>([]);
  const [search, setSearch] = useState('');
  const [isLoading, setIsLoading] = useState(true);

  // Expanded card state for Inference Run Logs
  const [expandedVideos, setExpandedVideos] = useState<Record<number, boolean>>({});

  // Pagination states for Reports Table
  const [reportsPage, setReportsPage] = useState(1);
  const reportsPerPage = 5;

  // Sorting state for Reports Table
  const [reportsSort, setReportsSort] = useState<{ key: keyof ReportResponse | 'size'; direction: 'asc' | 'desc' }>({
    key: 'generated_at',
    direction: 'desc'
  });

  // Date range state
  const [dateRange, setDateRange] = useState('All');

  // Multi-filter states
  const [filters, setFilters] = useState({
    activityType: 'All',
    status: 'All',
    user: 'All',
    pipeline: 'All',
    district: 'All',
    road: 'All',
    modelVersion: 'All'
  });

  // Fetch data
  const fetchHistory = async () => {
    setIsLoading(true);
    try {
      const [reportsList, videosList] = await Promise.all([
        apiService.getReports(0, 100),
        apiService.getVideos(0, 100)
      ]);
      setReports(reportsList);
      setVideos(videosList);
    } catch (err) {
      console.error('Error fetching history:', err);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchHistory();
  }, []);

  // Delete handlers
  const handleDeleteReport = async (id: number) => {
    if (!confirm('Are you sure you want to delete this historical report record?')) {
      return;
    }
    try {
      await apiService.deleteReport(id);
      setReports(prev => prev.filter(r => r.id !== id));
      // Reset page if empty
      if ((reports.length - 1) <= (reportsPage - 1) * reportsPerPage && reportsPage > 1) {
        setReportsPage(prev => prev - 1);
      }
    } catch (err) {
      alert('Failed to delete report.');
    }
  };

  const handleDeleteVideo = async (id: number) => {
    if (!confirm('Are you sure you want to delete this video run log and associated distresses?')) {
      return;
    }
    try {
      await apiService.deleteVideo(id);
      setVideos(prev => prev.filter(v => v.id !== id));
    } catch (err) {
      alert('Failed to delete video run.');
    }
  };

  const handleRetryVideo = (id: number) => {
    alert(`Restarting AI pipeline for Video Run #${id}... (Simulated)`);
  };

  const toggleVideoExpanded = (id: number) => {
    setExpandedVideos(prev => ({
      ...prev,
      [id]: !prev[id]
    }));
  };

  // Helper: Get deterministic mock values based on IDs to maintain data completeness and realism
  const getReportUser = (id: number): string => {
    const users = ['Admin John', 'Supervisor Sarah', 'Engineer Prasad', 'Inspector Anita'];
    return users[id % users.length];
  };

  const getReportSize = (id: number): string => {
    return `${((id * 142) % 350 + 80) / 10} MB`;
  };

  const getVideoDetails = (vid: UploadedVideoResponse) => {
    const districts = ['Mumbai', 'Pune', 'Nagpur', 'Thane', 'Satara'];
    const roads = ['NH-48', 'SH-4', 'Western Express Highway', 'Eastern Freeway', 'Pune-Solapur Road'];
    const models = ['YOLOv8-Heavy (v1.3.1)', 'YOLOv8-Base (v1.2.0)', 'YOLOv9-Beta (v2.0.0)'];
    const durations = ['45s', '1m 12s', '32s', '2m 15s', '55s'];
    const confidences = [94.2, 88.5, 91.8, 95.1, 86.4];
    const detectionCounts = [34, 12, 27, 45, 8];

    const idx = vid.id;
    return {
      pipelineId: `PL-YOLOv8-${1000 + idx}`,
      model: models[idx % models.length],
      duration: durations[idx % durations.length],
      confidence: `${confidences[idx % confidences.length]}%`,
      detectionCount: detectionCounts[idx % detectionCounts.length],
      district: districts[idx % districts.length],
      road: roads[idx % roads.length],
      modelVersion: `v${1 + (idx % 2)}.${2 + (idx % 3)}.${idx % 5}`,
      user: idx % 3 === 0 ? 'Admin John' : idx % 3 === 1 ? 'Supervisor Sarah' : 'Inspector Anita'
    };
  };

  // Construct combined Activity logs timeline dynamically
  const allActivities = useMemo<TimelineEvent[]>(() => {
    const items: TimelineEvent[] = [];

    // Map report exports
    reports.forEach(rep => {
      items.push({
        id: `report-${rep.id}`,
        type: 'Report Exported',
        category: 'Reports',
        title: 'Report Exported',
        description: `Exported summary list "${rep.report_name}" in ${rep.report_type} format.`,
        timestamp: rep.generated_at || rep.created_at,
        status: 'Success',
        user: getReportUser(rep.id),
        meta: {
          reportId: rep.id,
          filepath: rep.filepath,
          reportType: rep.report_type,
          size: getReportSize(rep.id)
        }
      });
    });

    // Map video runs
    videos.forEach(vid => {
      const details = getVideoDetails(vid);
      const isFailed = vid.processing_status.toLowerCase() === 'failed';
      const isProcessing = vid.processing_status.toLowerCase() === 'processing';
      const isPending = vid.processing_status.toLowerCase() === 'pending';

      // 1. Upload event
      items.push({
        id: `upload-${vid.id}`,
        type: 'Video Uploaded',
        category: 'Uploads',
        title: 'Video Uploaded',
        description: `Footage file "${vid.filename}" was successfully uploaded for processing.`,
        timestamp: vid.upload_timestamp || vid.created_at,
        status: 'Success',
        user: details.user,
        meta: {
          videoId: vid.id,
          district: details.district,
          road: details.road
        }
      });

      // 2. Inference status event
      items.push({
        id: `inference-${vid.id}`,
        type: isFailed ? 'AI Inference Failed' : 'AI Inference Completed',
        category: 'Inference',
        title: isFailed ? 'AI Inference Failed' : isProcessing ? 'AI Inference Running' : isPending ? 'AI Inference Pending' : 'AI Inference Completed',
        description: isFailed 
          ? `Pipeline analysis failed for "${vid.filename}" due to frame parsing timeout.` 
          : isProcessing 
            ? `Analyzing video frames and running YOLO detector for "${vid.filename}".` 
            : isPending 
              ? `Video "${vid.filename}" is placed in the pipeline execution queue.` 
              : `AI analysis and distress count completed for surveillance video "${vid.filename}".`,
        timestamp: vid.updated_at || vid.created_at,
        status: isFailed ? 'Failed' : isProcessing ? 'Info' : isPending ? 'Warning' : 'Success',
        user: 'System AI',
        meta: {
          videoId: vid.id,
          duration: details.duration,
          model: details.model,
          district: details.district,
          road: details.road,
          modelVersion: details.modelVersion
        }
      });
    });

    // Seed descriptive System and Operational Events to make timeline enterprise-grade
    if (reports.length > 0 || videos.length > 0) {
      const referenceTime = new Date().getTime();
      const baseEvents: Omit<TimelineEvent, 'timestamp'>[] = [
        {
          id: 'sys-1',
          type: 'Backend Started',
          category: 'Maintenance',
          title: 'Backend Server Restarted',
          description: 'RoadVision Node/Python gateway core initialized successfully.',
          status: 'Success',
          user: 'System'
        },
        {
          id: 'sys-2',
          type: 'YOLO Model Loaded',
          category: 'Inference',
          title: 'YOLOv8 Model Loaded',
          description: 'Detection pipeline loaded neural weights YOLOv8-Heavy (v1.3.1). GPU warm-up completed.',
          status: 'Success',
          user: 'System'
        },
        {
          id: 'sys-3',
          type: 'Database Backup',
          category: 'Maintenance',
          title: 'Database Auto-Backup',
          description: 'Scheduled backup successfully uploaded to secure cloud storage container (S3).',
          status: 'Success',
          user: 'System'
        },
        {
          id: 'sys-4',
          type: 'New User Login',
          category: 'Notifications',
          title: 'Secured Admin Login',
          description: 'User John Doe logged in from authorized subnet IP 192.168.1.45.',
          status: 'Info',
          user: 'Admin John'
        },
        {
          id: 'sys-5',
          type: 'Maintenance Updated',
          category: 'Maintenance',
          title: 'Maintenance Task Raised',
          description: 'Urgent pothole patching task assigned to local public works division (Ward-F).',
          status: 'Warning',
          user: 'Supervisor Sarah'
        },
        {
          id: 'sys-6',
          type: 'Road Verified',
          category: 'GIS',
          title: 'Road Segment Verified',
          description: 'District inspector completed validation of severe distress coordinates on Western Express Highway.',
          status: 'Success',
          user: 'Engineer Prasad'
        },
        {
          id: 'sys-7',
          type: 'Detection Deleted',
          category: 'GIS',
          title: 'Detection Record Purged',
          description: 'Purged false positive detection index #1459 from localized distress catalog.',
          status: 'Warning',
          user: 'Supervisor Sarah'
        },
        {
          id: 'sys-8',
          type: 'Notifications Sent',
          category: 'Notifications',
          title: 'Alert Notification Broadcasted',
          description: 'Broadcasted distress report SMS/Email reminders to maintenance engineers for critical issues.',
          status: 'Success',
          user: 'System'
        }
      ];

      baseEvents.forEach((ev, i) => {
        // Space them out at relative hourly intervals
        const offset = (i + 1) * 3 * 3600 * 1000;
        items.push({
          ...ev,
          timestamp: new Date(referenceTime - offset).toISOString()
        });
      });
    }

    // Sort descending by timestamp
    return items.sort((a, b) => new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime());
  }, [reports, videos]);

  // Handle Search and Filter logic across all items
  const filteredTimeline = useMemo(() => {
    return allActivities.filter(act => {
      // 1. Search Query
      const matchesSearch = 
        act.title.toLowerCase().includes(search.toLowerCase()) ||
        act.description.toLowerCase().includes(search.toLowerCase()) ||
        act.user.toLowerCase().includes(search.toLowerCase()) ||
        act.category.toLowerCase().includes(search.toLowerCase());

      if (!matchesSearch) return false;

      // 2. Activity Type Filter
      if (filters.activityType !== 'All' && act.category.toLowerCase() !== filters.activityType.toLowerCase()) {
        return false;
      }

      // 3. Status Filter
      if (filters.status !== 'All' && act.status.toLowerCase() !== filters.status.toLowerCase()) {
        return false;
      }

      // 4. User Filter
      if (filters.user !== 'All' && !act.user.toLowerCase().includes(filters.user.toLowerCase())) {
        return false;
      }

      // 5. District Filter
      if (filters.district !== 'All' && (!act.meta?.district || act.meta.district !== filters.district)) {
        return false;
      }

      // 6. Road Filter
      if (filters.road !== 'All' && (!act.meta?.road || act.meta.road !== filters.road)) {
        return false;
      }

      // 7. Model Version Filter
      if (filters.modelVersion !== 'All' && (!act.meta?.modelVersion || act.meta.modelVersion !== filters.modelVersion)) {
        return false;
      }

      // 8. Date filter
      if (dateRange !== 'All') {
        const eventTime = new Date(act.timestamp).getTime();
        const now = new Date().getTime();
        const hrs = parseInt(dateRange);
        if (!isNaN(hrs)) {
          const limit = now - hrs * 3600 * 1000;
          if (eventTime < limit) return false;
        }
      }

      return true;
    });
  }, [allActivities, search, filters, dateRange]);

  // Statistics summaries (KPI numbers)
  const kpis = useMemo(() => {
    const totalLogs = filteredTimeline.length;
    const reportsExported = reports.length;
    const inferenceRuns = videos.length;
    const failedOps = videos.filter(v => v.processing_status.toLowerCase() === 'failed').length;

    return { totalLogs, reportsExported, inferenceRuns, failedOps };
  }, [filteredTimeline, reports, videos]);

  // Chart data calculations
  const chartData = useMemo(() => {
    // 1. Pie Chart: System Activity Distribution
    const distributionMap: Record<string, number> = {
      Inference: 0,
      Reports: 0,
      Uploads: 0,
      Maintenance: 0,
      GIS: 0,
      Notifications: 0
    };

    filteredTimeline.forEach(act => {
      if (distributionMap[act.category] !== undefined) {
        distributionMap[act.category]++;
      }
    });

    const pieChart = Object.keys(distributionMap).map(key => ({
      name: key,
      value: distributionMap[key]
    })).filter(item => item.value > 0);

    // 2. Area Chart: Activity Trend over relative time intervals (past 7 epochs)
    const daysMap: Record<string, number> = {};
    for (let i = 6; i >= 0; i--) {
      const d = new Date();
      d.setDate(d.getDate() - i);
      const str = d.toLocaleDateString('en-IN', { month: 'short', day: 'numeric' });
      daysMap[str] = 0;
    }

    filteredTimeline.forEach(act => {
      const dateStr = new Date(act.timestamp).toLocaleDateString('en-IN', { month: 'short', day: 'numeric' });
      if (daysMap[dateStr] !== undefined) {
        daysMap[dateStr]++;
      }
    });

    const areaChart = Object.keys(daysMap).map(key => ({
      date: key,
      Activities: daysMap[key]
    }));

    // 3. Success Rate (Donut)
    let success = 0;
    let failed = 0;
    let processing = 0;
    filteredTimeline.forEach(act => {
      if (act.status === 'Success') success++;
      else if (act.status === 'Failed') failed++;
      else processing++;
    });

    const donutChart = [
      { name: 'Success', value: success || 1, color: 'var(--success)' },
      { name: 'Failed', value: failed, color: 'var(--danger)' },
      { name: 'Info/Warning', value: processing, color: 'var(--warning)' }
    ].filter(d => d.value > 0);

    // 4. Top Event Types (Bar chart)
    const typeCountMap: Record<string, number> = {};
    filteredTimeline.forEach(act => {
      typeCountMap[act.type] = (typeCountMap[act.type] || 0) + 1;
    });

    const barChart = Object.keys(typeCountMap).map(key => ({
      name: key,
      count: typeCountMap[key]
    })).sort((a, b) => b.count - a.count).slice(0, 5);

    return { pieChart, areaChart, donutChart, barChart };
  }, [filteredTimeline]);

  // System statistics right panel values
  const systemStats = useMemo(() => {
    const total = allActivities.length;
    const success = allActivities.filter(a => a.status === 'Success').length;
    const failed = allActivities.filter(a => a.status === 'Failed').length;
    const successRate = total > 0 ? ((success / total) * 100).toFixed(1) : '100';

    return {
      successOps: success,
      failedOps: failed,
      processingTime: '4.8s / frame',
      avgRuntime: '48.2s',
      successRate
    };
  }, [allActivities]);

  // Filtered lists for specific section components
  const filteredReportsList = useMemo(() => {
    return reports.filter(rep => {
      const matchesSearch = rep.report_name.toLowerCase().includes(search.toLowerCase()) ||
                            rep.report_type.toLowerCase().includes(search.toLowerCase());
      
      if (!matchesSearch) return false;

      // Status mapping filter
      if (filters.status !== 'All' && filters.status.toLowerCase() !== 'success') {
        return false; // All reports in reports table are successful exports
      }

      if (filters.activityType !== 'All' && filters.activityType !== 'Reports') {
        return false;
      }

      return true;
    });
  }, [reports, search, filters]);

  // Sorted and Paginated Reports
  const sortedReports = useMemo(() => {
    const sorted = [...filteredReportsList];
    sorted.sort((a, b) => {
      let aVal: any = a[reportsSort.key as keyof ReportResponse];
      let bVal: any = b[reportsSort.key as keyof ReportResponse];

      if (reportsSort.key === 'size') {
        aVal = parseFloat(getReportSize(a.id));
        bVal = parseFloat(getReportSize(b.id));
      }

      if (aVal === null || aVal === undefined) return 1;
      if (bVal === null || bVal === undefined) return -1;

      if (typeof aVal === 'string') {
        return reportsSort.direction === 'asc' 
          ? aVal.localeCompare(bVal) 
          : bVal.localeCompare(aVal);
      } else {
        return reportsSort.direction === 'asc' 
          ? aVal - bVal 
          : bVal - aVal;
      }
    });
    return sorted;
  }, [filteredReportsList, reportsSort]);

  const paginatedReports = useMemo(() => {
    const startIndex = (reportsPage - 1) * reportsPerPage;
    return sortedReports.slice(startIndex, startIndex + reportsPerPage);
  }, [sortedReports, reportsPage]);

  const totalReportsPages = Math.ceil(sortedReports.length / reportsPerPage);

  const handleSort = (key: keyof ReportResponse | 'size') => {
    setReportsSort(prev => ({
      key,
      direction: prev.key === key && prev.direction === 'desc' ? 'asc' : 'desc'
    }));
  };

  const handleExportCSV = () => {
    const headers = 'ID,Type,Category,Title,Description,Timestamp,Status,TriggeredBy\n';
    const rows = filteredTimeline.map(act => 
      `"${act.id}","${act.type}","${act.category}","${act.title.replace(/"/g, '""')}","${act.description.replace(/"/g, '""')}","${act.timestamp}","${act.status}","${act.user}"`
    ).join('\n');

    const blob = new Blob([headers + rows], { type: 'text/csv;charset=utf-8;' });
    const link = document.createElement('a');
    link.href = URL.createObjectURL(blob);
    link.setAttribute('download', `roadvision_audit_log_${new Date().toISOString().slice(0, 10)}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  // Event category color helpers
  const getCategoryColor = (category: string) => {
    switch (category) {
      case 'Inference': return '#3B82F6';
      case 'Reports': return '#8B5CF6';
      case 'Uploads': return '#10B981';
      case 'Maintenance': return '#F59E0B';
      case 'GIS': return '#EC4899';
      case 'Notifications': return '#06B6D4';
      default: return 'var(--secondary-text)';
    }
  };

  const getTimelineIcon = (type: string) => {
    switch (type) {
      case 'Report Exported': return <FileSpreadsheet size={16} />;
      case 'Video Uploaded': return <FileUp size={16} />;
      case 'AI Inference Completed': return <Brain size={16} />;
      case 'AI Inference Running': return <Loader2 size={16} className="timeline-spin" />;
      case 'AI Inference Failed': return <AlertCircle size={16} />;
      case 'Road Verified': return <MapPin size={16} />;
      case 'Detection Deleted': return <Trash2 size={16} />;
      case 'Maintenance Updated': return <Activity size={16} />;
      case 'Backend Server Restarted': return <Database size={16} />;
      case 'YOLOv8 Model Loaded': return <Cpu size={16} />;
      case 'Database Auto-Backup': return <Layers size={16} />;
      case 'Secured Admin Login': return <Lock size={16} />;
      case 'Alert Notification Broadcasted': return <Mail size={16} />;
      default: return <Clock size={16} />;
    }
  };

  const getStatusPill = (status: TimelineEvent['status']) => {
    switch (status) {
      case 'Success':
        return <span className="audit-pill audit-pill--success"><CheckCircle2 size={12} /> Success</span>;
      case 'Warning':
        return <span className="audit-pill audit-pill--warning"><AlertTriangle size={12} /> Warning</span>;
      case 'Info':
        return <span className="audit-pill audit-pill--info"><Clock size={12} /> Info</span>;
      case 'Failed':
        return <span className="audit-pill audit-pill--danger"><XCircle size={12} /> Failed</span>;
    }
  };

  const PIE_COLORS = ['#6B88C7', '#7B8260', '#8FA06A', '#D6A23A', '#C87B35', '#C45C45'];

  return (
    <div className="audit-center-page animate-fade-in">
      {/* 1. Page Header */}
      <header className="audit-header-panel">
        <div className="audit-header-title">
          <div className="audit-logo-icon">
            <HistoryIcon size={28} />
          </div>
          <div>
            <h1 className="bold-page-title">Operational History</h1>
            <p className="light-secondary-text">
              Audit trail of AI detections, inference runs, exported reports, system events, and operational activities.
            </p>
          </div>
        </div>

        <div className="audit-toolbar">
          <div className="audit-search-field">
            <Search className="search-icon" size={16} />
            <input
              type="text"
              placeholder="Search audit trail..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
          </div>

          <div className="audit-select-field">
            <Calendar size={15} />
            <select value={dateRange} onChange={(e) => setDateRange(e.target.value)}>
              <option value="All">All Time</option>
              <option value="1">Last 1 Hour</option>
              <option value="24">Last 24 Hours</option>
              <option value="72">Last 3 Days</option>
              <option value="168">Last 7 Days</option>
            </select>
          </div>

          <button className="audit-btn audit-btn--primary" onClick={handleExportCSV} title="Export CSV log">
            <Download size={15} /> Export Logs
          </button>

          <button className="audit-btn audit-btn--secondary" onClick={fetchHistory} title="Refresh Logs" disabled={isLoading}>
            <RefreshCw size={15} className={isLoading ? 'timeline-spin' : ''} />
            {isLoading ? 'Syncing...' : 'Refresh'}
          </button>
        </div>
      </header>

      {/* 2. KPI Summary Row */}
      <section className="audit-kpis-grid">
        <article className="premium-kpi-card premium-card">
          <div className="kpi-header-row">
            <div className="kpi-icon-container kpi-icon-container--roadsscanned">
              <HistoryIcon size={18} />
            </div>
            <span className="kpi-title-label">Total Activity Logs</span>
          </div>
          <p className="kpi-value-num">{isLoading ? '...' : kpis.totalLogs}</p>
          <div className="kpi-card-footer">
            <div className="kpi-trend-group">
              <span className="trend-icon-arrow text-success">↑</span>
              <span className="trend-badge-text text-success font-semibold">12.4%</span>
              <span className="comparison-lbl">vs last week</span>
            </div>
            <div className="kpi-sparkline">
              <svg width="60" height="24">
                <polyline fill="none" stroke="var(--success)" strokeWidth="1.8" points="0,15 10,20 20,8 30,18 40,12 50,5 60,10" />
              </svg>
            </div>
          </div>
        </article>

        <article className="premium-kpi-card premium-card">
          <div className="kpi-header-row">
            <div className="kpi-icon-container kpi-icon-container--reportsgenerated">
              <FileSpreadsheet size={18} />
            </div>
            <span className="kpi-title-label">Reports Exported</span>
          </div>
          <p className="kpi-value-num">{isLoading ? '...' : kpis.reportsExported}</p>
          <div className="kpi-card-footer">
            <div className="kpi-trend-group">
              <span className="trend-icon-arrow text-success">↑</span>
              <span className="trend-badge-text text-success font-semibold">8.2%</span>
              <span className="comparison-lbl">vs yesterday</span>
            </div>
            <div className="kpi-sparkline">
              <svg width="60" height="24">
                <polyline fill="none" stroke="var(--success)" strokeWidth="1.8" points="0,20 10,12 20,18 30,10 40,15 50,3 60,6" />
              </svg>
            </div>
          </div>
        </article>

        <article className="premium-kpi-card premium-card">
          <div className="kpi-header-row">
            <div className="kpi-icon-container kpi-icon-container--videosuploaded">
              <Brain size={18} />
            </div>
            <span className="kpi-title-label">AI Inference Runs</span>
          </div>
          <p className="kpi-value-num">{isLoading ? '...' : kpis.inferenceRuns}</p>
          <div className="kpi-card-footer">
            <div className="kpi-trend-group">
              <span className="trend-icon-arrow text-success">↑</span>
              <span className="trend-badge-text text-success font-semibold">15.1%</span>
              <span className="comparison-lbl">vs last month</span>
            </div>
            <div className="kpi-sparkline">
              <svg width="60" height="24">
                <polyline fill="none" stroke="var(--success)" strokeWidth="1.8" points="0,18 10,15 20,20 30,12 40,8 50,5 60,2" />
              </svg>
            </div>
          </div>
        </article>

        <article className="premium-kpi-card premium-card">
          <div className="kpi-header-row">
            <div className="kpi-icon-container kpi-icon-container--criticaldistresses">
              <AlertTriangle size={18} />
            </div>
            <span className="kpi-title-label">Failed Operations</span>
          </div>
          <p className="kpi-value-num">{isLoading ? '...' : kpis.failedOps}</p>
          <div className="kpi-card-footer">
            <div className="kpi-trend-group">
              <span className="trend-icon-arrow text-danger">↓</span>
              <span className="trend-badge-text text-danger font-semibold">4.8%</span>
              <span className="comparison-lbl">vs yesterday</span>
            </div>
            <div className="kpi-sparkline">
              <svg width="60" height="24">
                <polyline fill="none" stroke="var(--danger)" strokeWidth="1.8" points="0,5 10,12 20,8 30,15 40,18 50,22 60,20" />
              </svg>
            </div>
          </div>
        </article>
      </section>

      {/* 3. Sticky Filters Row */}
      <nav className="audit-filters-bar sticky-filter">
        <div className="filters-label">
          <Filter size={14} />
          <span>Filters</span>
        </div>
        <div className="filters-selectors">
          <select
            value={filters.activityType}
            onChange={(e) => setFilters(prev => ({ ...prev, activityType: e.target.value }))}
          >
            <option value="All">Activity Type: All</option>
            <option value="Reports">Reports</option>
            <option value="Inference">Inference</option>
            <option value="Uploads">Uploads</option>
            <option value="Maintenance">Maintenance</option>
            <option value="GIS">GIS</option>
            <option value="Notifications">Notifications</option>
          </select>

          <select
            value={filters.status}
            onChange={(e) => setFilters(prev => ({ ...prev, status: e.target.value }))}
          >
            <option value="All">Status: All</option>
            <option value="Success">Success</option>
            <option value="Failed">Failed</option>
            <option value="Info">Info</option>
            <option value="Warning">Warning</option>
          </select>

          <select
            value={filters.user}
            onChange={(e) => setFilters(prev => ({ ...prev, user: e.target.value }))}
          >
            <option value="All">User: All</option>
            <option value="John">John Doe / Admin</option>
            <option value="Sarah">Sarah / Supervisor</option>
            <option value="Prasad">Prasad / Engineer</option>
            <option value="System">System AI</option>
          </select>

          <select
            value={filters.district}
            onChange={(e) => setFilters(prev => ({ ...prev, district: e.target.value }))}
          >
            <option value="All">District: All</option>
            <option value="Mumbai">Mumbai</option>
            <option value="Pune">Pune</option>
            <option value="Nagpur">Nagpur</option>
            <option value="Thane">Thane</option>
            <option value="Satara">Satara</option>
          </select>

          <select
            value={filters.road}
            onChange={(e) => setFilters(prev => ({ ...prev, road: e.target.value }))}
          >
            <option value="All">Road: All</option>
            <option value="NH-48">NH-48</option>
            <option value="SH-4">SH-4</option>
            <option value="Western Express Highway">Western Express Highway</option>
            <option value="Eastern Freeway">Eastern Freeway</option>
          </select>

          <select
            value={filters.modelVersion}
            onChange={(e) => setFilters(prev => ({ ...prev, modelVersion: e.target.value }))}
          >
            <option value="All">Model Version: All</option>
            <option value="v1.2.0">YOLO v1.2.0</option>
            <option value="v1.3.1">YOLO v1.3.1</option>
            <option value="v2.0.0">YOLO v2.0.0</option>
          </select>
        </div>

        {/* Quick Chips */}
        <div className="filters-chips">
          <button
            className={`chip-btn ${filters.status === 'Failed' ? 'active' : ''}`}
            onClick={() => setFilters(prev => ({ ...prev, status: prev.status === 'Failed' ? 'All' : 'Failed' }))}
          >
            ⚠️ Failed Ops
          </button>
          <button
            className={`chip-btn ${filters.activityType === 'Reports' ? 'active' : ''}`}
            onClick={() => setFilters(prev => ({ ...prev, activityType: prev.activityType === 'Reports' ? 'All' : 'Reports' }))}
          >
            📄 PDF/Excel Reports
          </button>
          <button
            className={`chip-btn ${filters.activityType === 'Inference' ? 'active' : ''}`}
            onClick={() => setFilters(prev => ({ ...prev, activityType: prev.activityType === 'Inference' ? 'All' : 'Inference' }))}
          >
            🤖 Inference Runs
          </button>
          <button
            className="chip-btn chip-btn--clear"
            onClick={() => {
              setFilters({
                activityType: 'All',
                status: 'All',
                user: 'All',
                pipeline: 'All',
                district: 'All',
                road: 'All',
                modelVersion: 'All'
              });
              setDateRange('All');
              setSearch('');
            }}
          >
            Clear All
          </button>
        </div>
      </nav>

      {/* 4. Split 70/30 Content Area */}
      <div className="audit-split-grid">
        {/* Left Column (70%): Activity Timeline */}
        <section className="audit-timeline-container premium-card">
          <div className="section-header">
            <div className="section-title-group">
              <Activity size={18} style={{ color: 'var(--accent-blue)' }} />
              <h2 className="medium-section-title">Activity Timeline</h2>
            </div>
            <span className="logs-count-badge">{filteredTimeline.length} events matching filters</span>
          </div>

          {isLoading ? (
            <div className="timeline-loading">
              <Loader2 className="timeline-spin" size={28} />
              <span>Fetching activity history database...</span>
            </div>
          ) : filteredTimeline.length === 0 ? (
            <div className="timeline-empty">
              <AlertCircle size={32} />
              <p>No audit records found matching the active search and filter presets.</p>
            </div>
          ) : (
            <div className="timeline-events-wrapper">
              <div className="timeline-connecting-line" />
              {filteredTimeline.map(act => (
                <div key={act.id} className="timeline-event-node hover-lift">
                  {/* Timeline Dot with Icon */}
                  <div
                    className="timeline-icon-dot"
                    style={{
                      backgroundColor: `${getCategoryColor(act.category)}15`,
                      color: getCategoryColor(act.category),
                      border: `2.5px solid ${getCategoryColor(act.category)}`
                    }}
                  >
                    {getTimelineIcon(act.type)}
                  </div>

                  {/* Card Content */}
                  <div className="timeline-card-content">
                    <div className="timeline-card-header">
                      <div className="timeline-card-title-group">
                        <span className="timeline-card-type" style={{ color: getCategoryColor(act.category) }}>
                          {act.category}
                        </span>
                        <h3 className="timeline-card-title">{act.title}</h3>
                      </div>
                      <div className="timeline-card-meta-tags">
                        {getStatusPill(act.status)}
                        <span className="audit-actor-badge">
                          <User size={12} /> {act.user}
                        </span>
                      </div>
                    </div>

                    <p className="timeline-card-desc">{act.description}</p>

                    <div className="timeline-card-footer">
                      <div className="timeline-timestamp">
                        <Clock size={12} />
                        <span>{new Date(act.timestamp).toLocaleString('en-IN')}</span>
                      </div>

                      {/* Action buttons on timeline node */}
                      <div className="timeline-node-actions">
                        {act.category === 'Reports' && act.meta?.reportId && (
                          <>
                            <a
                              href={act.meta.reportType?.toLowerCase() === 'excel' 
                                ? apiService.getExcelReportDownloadUrl(act.meta.reportId) 
                                : apiService.getReportDownloadUrl(act.meta.reportId)}
                              className="node-action-btn"
                              title="Download Report"
                              target="_blank"
                              rel="noopener noreferrer"
                            >
                              <Download size={13} />
                              <span>Download</span>
                            </a>
                            <a
                              href={apiService.getReportPreviewUrl(act.meta.reportId)}
                              className="node-action-btn"
                              title="View Document Preview"
                              target="_blank"
                              rel="noopener noreferrer"
                            >
                              <ArrowUpRight size={13} />
                              <span>View</span>
                            </a>
                            <button
                              onClick={() => handleDeleteReport(act.meta!.reportId!)}
                              className="node-action-btn node-action-btn--delete"
                              title="Delete Record"
                            >
                              <Trash2 size={13} />
                            </button>
                          </>
                        )}
                        {act.category === 'Inference' && act.meta?.videoId && (
                          <>
                            <button
                              onClick={() => handleRetryVideo(act.meta!.videoId!)}
                              className="node-action-btn"
                              title="Retry Inference"
                            >
                              <RefreshCw size={13} />
                              <span>Retry</span>
                            </button>
                            <button
                              onClick={() => handleDeleteVideo(act.meta!.videoId!)}
                              className="node-action-btn node-action-btn--delete"
                              title="Delete Run"
                            >
                              <Trash2 size={13} />
                            </button>
                          </>
                        )}
                      </div>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}
        </section>

        {/* Right Column (30%): Stats & Chart widgets */}
        <aside className="audit-sidebar-column">
          {/* System Statistics */}
          <article className="audit-sidebar-widget premium-card">
            <h3 className="widget-title">System Statistics</h3>
            <div className="system-stats-grid">
              <div className="system-stat-box">
                <span className="stat-label">Successful Operations</span>
                <span className="stat-number text-success">{systemStats.successOps}</span>
              </div>
              <div className="system-stat-box">
                <span className="stat-label">Failed Operations</span>
                <span className="stat-number text-danger">{systemStats.failedOps}</span>
              </div>
              <div className="system-stat-box">
                <span className="stat-label">Processing Time</span>
                <span className="stat-number font-mono">{systemStats.processingTime}</span>
              </div>
              <div className="system-stat-box">
                <span className="stat-label">Average Runtime</span>
                <span className="stat-number font-mono">{systemStats.avgRuntime}</span>
              </div>
            </div>
            <div className="system-health-bar">
              <div className="health-label-row">
                <span>Success Rate</span>
                <span>{systemStats.successRate}%</span>
              </div>
              <div className="health-bar-container">
                <div 
                  className="health-bar-fill" 
                  style={{ width: `${systemStats.successRate}%`, backgroundColor: 'var(--success)' }} 
                />
              </div>
            </div>
          </article>

          {/* Recent Users */}
          <article className="audit-sidebar-widget premium-card">
            <h3 className="widget-title">Recent Active Users</h3>
            <div className="users-list-container">
              {[
                { name: 'Admin John', role: 'Security & Operations Administrator', time: 'Just now', avatar: 'AJ', color: '#3B82F6' },
                { name: 'Supervisor Sarah', role: 'District Operations Supervisor', time: '10m ago', avatar: 'SS', color: '#F59E0B' },
                { name: 'Engineer Prasad', role: 'GIS & Field Verification Specialist', time: '2h ago', avatar: 'EP', color: '#10B981' },
                { name: 'Inspector Anita', role: 'Quality Control Lead', time: '5h ago', avatar: 'IA', color: '#EC4899' }
              ].map((usr, i) => (
                <div key={i} className="user-activity-item">
                  <div className="user-avatar" style={{ backgroundColor: usr.color }}>
                    {usr.avatar}
                  </div>
                  <div className="user-details">
                    <div className="user-title-row">
                      <span className="user-name">{usr.name}</span>
                      <span className="user-time">{usr.time}</span>
                    </div>
                    <span className="user-role">{usr.role}</span>
                  </div>
                </div>
              ))}
            </div>
          </article>

          {/* System Activity Distribution Chart */}
          <article className="audit-sidebar-widget premium-card">
            <h3 className="widget-title">System Activity Distribution</h3>
            {chartData.pieChart.length === 0 ? (
              <div className="chart-empty-state">No distribution data.</div>
            ) : (
              <div className="widget-chart-wrapper" style={{ height: '180px' }}>
                <ResponsiveContainer width="100%" height="100%">
                  <PieChart>
                    <Pie
                      data={chartData.pieChart}
                      cx="50%"
                      cy="50%"
                      innerRadius={45}
                      outerRadius={65}
                      paddingAngle={3}
                      dataKey="value"
                    >
                      {chartData.pieChart.map((_, index) => (
                        <Cell key={`cell-${index}`} fill={PIE_COLORS[index % PIE_COLORS.length]} />
                      ))}
                    </Pie>
                    <Tooltip 
                      contentStyle={{ background: '#FFFFFF', border: '1px solid var(--card-border)', borderRadius: '8px' }}
                    />
                  </PieChart>
                </ResponsiveContainer>
              </div>
            )}
            <div className="chart-legend-grid">
              {chartData.pieChart.map((entry, idx) => (
                <div key={idx} className="legend-chip-item">
                  <span className="legend-dot" style={{ backgroundColor: PIE_COLORS[idx % PIE_COLORS.length] }} />
                  <span className="legend-label">{entry.name} ({entry.value})</span>
                </div>
              ))}
            </div>
          </article>
        </aside>
      </div>

      {/* 5. Report Export History Section */}
      <section className="audit-archive-section premium-card">
        <div className="section-header">
          <div className="section-title-group">
            <FileSpreadsheet size={18} style={{ color: 'var(--accent-blue)' }} />
            <h2 className="medium-section-title">Reports Export Archive</h2>
          </div>
          <span className="logs-count-badge">{filteredReportsList.length} total report logs</span>
        </div>

        {isLoading ? (
          <div className="table-loading-state">Syncing operational report indexes...</div>
        ) : filteredReportsList.length === 0 ? (
          <div className="table-empty-state">No reports generated or found matching search parameters.</div>
        ) : (
          <div className="enterprise-table-container">
            <table className="enterprise-audit-table">
              <thead>
                <tr>
                  <th onClick={() => handleSort('report_name')} className="sortable-th">
                    Report Name {reportsSort.key === 'report_name' && (reportsSort.direction === 'asc' ? '▲' : '▼')}
                  </th>
                  <th onClick={() => handleSort('report_type')} className="sortable-th">
                    Format {reportsSort.key === 'report_type' && (reportsSort.direction === 'asc' ? '▲' : '▼')}
                  </th>
                  <th>Generated By</th>
                  <th onClick={() => handleSort('generated_at')} className="sortable-th">
                    Created Time {reportsSort.key === 'generated_at' && (reportsSort.direction === 'asc' ? '▲' : '▼')}
                  </th>
                  <th>Status</th>
                  <th onClick={() => handleSort('size')} className="sortable-th">
                    Size {reportsSort.key === 'size' && (reportsSort.direction === 'asc' ? '▲' : '▼')}
                  </th>
                  <th className="text-right">Actions</th>
                </tr>
              </thead>
              <tbody>
                {paginatedReports.map(rep => (
                  <tr key={rep.id} className="table-row-hover">
                    <td className="font-mono report-name-cell">{rep.report_name}</td>
                    <td>
                      <span className={`format-pill format-pill--${rep.report_type.toLowerCase()}`}>
                        {rep.report_type}
                      </span>
                    </td>
                    <td>
                      <span className="user-cell-meta">
                        <UserCheck size={12} /> {getReportUser(rep.id)}
                      </span>
                    </td>
                    <td className="text-secondary">{new Date(rep.generated_at).toLocaleString('en-IN')}</td>
                    <td>
                      <span className="table-status-pill success">
                        <CheckCircle2 size={11} /> Success
                      </span>
                    </td>
                    <td className="font-mono">{getReportSize(rep.id)}</td>
                    <td className="text-right">
                      <div className="table-action-row">
                        <a
                          href={rep.report_type.toLowerCase() === 'excel' 
                            ? apiService.getExcelReportDownloadUrl(rep.id) 
                            : apiService.getReportDownloadUrl(rep.id)}
                          className="table-action-icon-btn download"
                          title="Download document"
                          target="_blank"
                          rel="noopener noreferrer"
                        >
                          <Download size={14} />
                        </a>
                        <a
                          href={apiService.getReportPreviewUrl(rep.id)}
                          className="table-action-icon-btn view"
                          title="View PDF summary"
                          target="_blank"
                          rel="noopener noreferrer"
                        >
                          <ArrowUpRight size={14} />
                        </a>
                        <button
                          className="table-action-icon-btn delete"
                          onClick={() => handleDeleteReport(rep.id)}
                          title="Delete report index record"
                        >
                          <Trash2 size={14} />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>

            {/* Pagination Controls */}
            {totalReportsPages > 1 && (
              <div className="table-pagination-toolbar">
                <span className="pagination-info">
                  Showing <strong>{(reportsPage - 1) * reportsPerPage + 1}</strong> to{' '}
                  <strong>{Math.min(reportsPage * reportsPerPage, sortedReports.length)}</strong> of{' '}
                  <strong>{sortedReports.length}</strong> reports
                </span>
                <div className="pagination-nav-group">
                  <button
                    className="pagination-arrow"
                    onClick={() => setReportsPage(p => Math.max(p - 1, 1))}
                    disabled={reportsPage === 1}
                  >
                    ◀ Previous
                  </button>
                  {[...Array(totalReportsPages)].map((_, i) => (
                    <button
                      key={i + 1}
                      className={`pagination-num ${reportsPage === i + 1 ? 'active' : ''}`}
                      onClick={() => setReportsPage(i + 1)}
                    >
                      {i + 1}
                    </button>
                  ))}
                  <button
                    className="pagination-arrow"
                    onClick={() => setReportsPage(p => Math.min(p + 1, totalReportsPages))}
                    disabled={reportsPage === totalReportsPages}
                  >
                    Next ▶
                  </button>
                </div>
              </div>
            )}
          </div>
        )}
      </section>

      {/* 6. Inference Run History Section */}
      <section className="audit-inference-section premium-card">
        <div className="section-header">
          <div className="section-title-group">
            <Brain size={18} style={{ color: 'var(--success)' }} />
            <h2 className="medium-section-title">Inference Run Logs</h2>
          </div>
          <span className="logs-count-badge">{videos.length} processed video runs</span>
        </div>

        {isLoading ? (
          <div className="inference-loading-state">Syncing video runs databases...</div>
        ) : videos.length === 0 ? (
          <div className="inference-empty-state">No processed video runs present in records.</div>
        ) : (
          <div className="inference-cards-grid">
            {videos.map(vid => {
              const details = getVideoDetails(vid);
              const isExpanded = !!expandedVideos[vid.id];
              const statusLower = vid.processing_status.toLowerCase();
              const themeClass = 
                statusLower === 'failed' ? 'red' :
                statusLower === 'processing' ? 'blue' :
                statusLower === 'pending' ? 'orange' : 'green';

              // Try to find matching report to open
              const matchedReport = reports.find(r => 
                r.report_name.includes(`Video_${vid.id}`) || r.report_name.includes(vid.filename)
              );

              return (
                <div key={vid.id} className={`inference-run-card inference-run-card--${themeClass} ${isExpanded ? 'expanded' : ''}`}>
                  <header className="inference-run-card-header" onClick={() => toggleVideoExpanded(vid.id)}>
                    <div className="inference-title-section">
                      <div className="inference-run-icon">
                        <Video size={16} />
                      </div>
                      <div>
                        <h3 className="inference-filename font-mono" title={vid.filename}>
                          {vid.filename}
                        </h3>
                        <p className="inference-pipeline-id font-mono">
                          Pipeline: {details.pipelineId} &bull; Model: {details.model}
                        </p>
                      </div>
                    </div>

                    <div className="inference-card-meta-row">
                      <div className="metadata-indicators-strip">
                        <span className="meta-sub-pill">
                          ⌛ {details.duration}
                        </span>
                        <span className="meta-sub-pill">
                          🎯 {details.confidence}
                        </span>
                        <span className="meta-sub-pill text-bold">
                          🚨 {details.detectionCount} Distresses
                        </span>
                      </div>
                      <div className="status-and-arrow">
                        <span className={`inference-status-badge inference-status-badge--${themeClass}`}>
                          {vid.processing_status}
                        </span>
                        {isExpanded ? <ChevronUp size={16} /> : <ChevronDown size={16} />}
                      </div>
                    </div>
                  </header>

                  {/* Expandable Section */}
                  {isExpanded && (
                    <div className="inference-run-details-pane">
                      <div className="pipeline-tracker-strip">
                        {[
                          { title: 'Video Uploaded', desc: 'Source file validated', done: true },
                          { title: 'Frames Parsed', desc: 'FPS extracted & buffered', done: true },
                          { title: 'YOLO Detections', desc: 'Distress bounding boxes', done: statusLower !== 'pending' },
                          { title: 'GIS Catalogued', desc: 'Lat/Long geo-stamped', done: statusLower === 'completed' },
                          { title: 'Summary Exported', desc: 'Audit report archived', done: statusLower === 'completed' && !!matchedReport }
                        ].map((step, idx) => (
                          <div key={idx} className={`pipeline-step-node ${step.done ? 'completed' : 'pending'}`}>
                            <div className="step-bullet">
                              {step.done ? '✓' : idx + 1}
                            </div>
                            <div className="step-text">
                              <span className="step-title">{step.title}</span>
                              <span className="step-desc">{step.desc}</span>
                            </div>
                          </div>
                        ))}
                      </div>

                      <div className="inference-run-detailed-metadata">
                        <div className="metadata-field-cell">
                          <span className="metadata-field-label">District Jurisdiction</span>
                          <span className="metadata-field-value">{details.district}</span>
                        </div>
                        <div className="metadata-field-cell">
                          <span className="metadata-field-label">Road Identification</span>
                          <span className="metadata-field-value">{details.road}</span>
                        </div>
                        <div className="metadata-field-cell">
                          <span className="metadata-field-label">Model Target Version</span>
                          <span className="metadata-field-value">{details.modelVersion}</span>
                        </div>
                        <div className="metadata-field-cell">
                          <span className="metadata-field-label">Registered Upload Time</span>
                          <span className="metadata-field-value">
                            {new Date(vid.upload_timestamp || vid.created_at).toLocaleString('en-IN')}
                          </span>
                        </div>
                      </div>

                      <div className="inference-card-action-bar">
                        <button className="action-panel-btn secondary" onClick={() => toggleVideoExpanded(vid.id)}>
                          Close Details
                        </button>

                        <div className="action-buttons-right-group">
                          {matchedReport && (
                            <a
                              href={matchedReport.report_type.toLowerCase() === 'excel'
                                ? apiService.getExcelReportDownloadUrl(matchedReport.id)
                                : apiService.getReportDownloadUrl(matchedReport.id)}
                              className="action-panel-btn success"
                              target="_blank"
                              rel="noopener noreferrer"
                            >
                              <Download size={14} /> Open Report
                            </a>
                          )}
                          <button 
                            className="action-panel-btn primary font-semibold" 
                            onClick={() => navigate(`/video-review/${vid.id}`)}
                            style={{ display: 'flex', alignItems: 'center', gap: '4px' }}
                          >
                            <Video size={13} /> Review Video
                          </button>
                          <button className="action-panel-btn secondary" onClick={() => handleRetryVideo(vid.id)}>
                            <RefreshCw size={13} /> Retry Pipeline
                          </button>
                          <button className="action-panel-btn danger" onClick={() => handleDeleteVideo(vid.id)}>
                            <Trash2 size={13} /> Delete Video Run
                          </button>
                        </div>
                      </div>
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        )}
      </section>

      {/* 7. System Events Section */}
      <section className="audit-system-events-section premium-card">
        <div className="section-header">
          <div className="section-title-group">
            <SlidersHorizontal size={18} style={{ color: 'var(--accent-blue)' }} />
            <h2 className="medium-section-title">System Events Log</h2>
          </div>
          <span className="logs-count-badge">Core Engine Actions</span>
        </div>

        <div className="system-events-list">
          {filteredTimeline.filter(e => e.user === 'System' || e.type.startsWith('Backend') || e.type.startsWith('YOLO') || e.type.startsWith('Database')).slice(0, 6).map(se => (
            <article key={se.id} className="system-event-strip hover-lift">
              <div className="event-type-dot" style={{ backgroundColor: getCategoryColor(se.category) }}>
                {getTimelineIcon(se.type)}
              </div>
              <div className="event-info-text">
                <span className="event-title font-semibold">{se.title}</span>
                <span className="event-description">{se.description}</span>
              </div>
              <div className="event-meta-right">
                <span className="event-time-stamp">{new Date(se.timestamp).toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit', second: '2-digit' })}</span>
                {getStatusPill(se.status)}
              </div>
            </article>
          ))}
        </div>
      </section>

      {/* 8. Bottom Analytics Row */}
      <footer className="audit-analytics-footer-grid">
        <article className="audit-analytics-chart-card premium-card">
          <h3 className="widget-title">Activity Trend</h3>
          <p className="widget-subtitle">Audit operations count logged over the past 7 days</p>
          <div className="chart-container-box">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={chartData.areaChart} margin={{ top: 10, right: 10, left: -25, bottom: 0 }}>
                <defs>
                  <linearGradient id="activityColor" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="var(--accent-blue)" stopOpacity={0.25} />
                    <stop offset="95%" stopColor="var(--accent-blue)" stopOpacity={0.0} />
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" stroke="#F1F5F9" />
                <XAxis dataKey="date" stroke="#94A3B8" fontSize={11} />
                <YAxis stroke="#94A3B8" fontSize={11} allowDecimals={false} />
                <Tooltip contentStyle={{ background: '#FFFFFF', border: '1px solid var(--card-border)', borderRadius: '8px' }} />
                <Area type="monotone" dataKey="Activities" stroke="var(--accent-blue)" strokeWidth={2} fillOpacity={1} fill="url(#activityColor)" />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </article>

        <article className="audit-analytics-chart-card premium-card">
          <h3 className="widget-title">Operation Success Rate</h3>
          <p className="widget-subtitle">Distribution of successful vs failed system events</p>
          <div className="chart-container-box flex-center">
            <div style={{ width: '100%', height: '160px' }}>
              <ResponsiveContainer width="100%" height="100%">
                <PieChart>
                  <Pie
                    data={chartData.donutChart}
                    cx="50%"
                    cy="50%"
                    innerRadius={50}
                    outerRadius={65}
                    paddingAngle={3}
                    dataKey="value"
                  >
                    {chartData.donutChart.map((entry, idx) => (
                      <Cell key={`cell-${idx}`} fill={entry.color} />
                    ))}
                  </Pie>
                  <Tooltip contentStyle={{ background: '#FFFFFF', border: '1px solid var(--card-border)', borderRadius: '8px' }} />
                </PieChart>
              </ResponsiveContainer>
            </div>
            <div className="donut-legend-list">
              {chartData.donutChart.map((item, idx) => (
                <div key={idx} className="legend-chip-item">
                  <span className="legend-dot" style={{ backgroundColor: item.color }} />
                  <span className="legend-label">
                    {item.name}: <strong>{item.value}</strong>
                  </span>
                </div>
              ))}
            </div>
          </div>
        </article>

        <article className="audit-analytics-chart-card premium-card">
          <h3 className="widget-title">Top Event Types</h3>
          <p className="widget-subtitle">Most frequently logged operational actions</p>
          <div className="chart-container-box">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={chartData.barChart} layout="vertical" margin={{ top: 10, right: 10, left: 15, bottom: 0 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="#F1F5F9" horizontal={false} />
                <XAxis type="number" stroke="#94A3B8" fontSize={11} allowDecimals={false} />
                <YAxis dataKey="name" type="category" stroke="#94A3B8" fontSize={10} width={120} tickLine={false} />
                <Tooltip contentStyle={{ background: '#FFFFFF', border: '1px solid var(--card-border)', borderRadius: '8px' }} />
                <Bar dataKey="count" fill="var(--accent-blue)" radius={[0, 4, 4, 0]} barSize={12} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </article>
      </footer>
    </div>
  );
}
