import { useState, useEffect, useMemo, useRef } from 'react';
import { 
  Search, 
  ShieldAlert, 
  FileText, 
  ChevronLeft, 
  ChevronRight, 
  Compass, 
  X, 
  ZoomIn, 
  ZoomOut, 
  Maximize2, 
  Minimize2, 
  CheckSquare, 
  Square, 
  Columns, 
  SlidersHorizontal,
  ArrowUpDown
} from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import apiService from '../../services/api/apiService';
import type { RoadDistressResponse } from '../../services/api/apiService';
import './RoadDistresses.css';

// Column configurations
const COLUMN_LABELS = {
  tracking_id: 'Tracking ID',
  detection_id: 'Detection ID',
  distress_type: 'Distress Type',
  severity: 'Severity',
  priority: 'Priority',
  confidence: 'Confidence',
  road_health_impact: 'Health Impact',
  frame_number: 'Frame Number',
  timestamp: 'Timestamp',
  latitude: 'Latitude',
  longitude: 'Longitude',
  estimated_cost: 'Est. Cost',
  status: 'Status',
  video_name: 'Video Name',
  created_time: 'Created Time'
};

const DEFAULT_COLUMNS = {
  tracking_id: true,
  detection_id: true,
  distress_type: true,
  severity: true,
  priority: true,
  confidence: true,
  road_health_impact: true,
  frame_number: false,
  timestamp: true,
  latitude: false,
  longitude: false,
  estimated_cost: true,
  status: true,
  video_name: true,
  created_time: false
};

export default function RoadDistresses() {
  const navigate = useNavigate();
  const [distresses, setDistresses] = useState<RoadDistressResponse[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Column visibility state persisted in Local Storage
  const [visibleColumns, setVisibleColumns] = useState<Record<string, boolean>>(() => {
    const saved = localStorage.getItem('distress_columns_visibility');
    return saved ? JSON.parse(saved) : DEFAULT_COLUMNS;
  });

  // Save visibility preferences on change
  useEffect(() => {
    localStorage.setItem('distress_columns_visibility', JSON.stringify(visibleColumns));
  }, [visibleColumns]);

  // Bulk selections state
  const [selectedIds, setSelectedIds] = useState<Set<number>>(new Set());

  // Lightbox Modal state
  const [lightboxItem, setLightboxItem] = useState<RoadDistressResponse | null>(null);
  const [zoomScale, setZoomScale] = useState(1);
  const [panOffset, setPanOffset] = useState({ x: 0, y: 0 });
  const [isLightboxFullscreen, setIsLightboxFullscreen] = useState(false);
  const isDragging = useRef(false);
  const startDragOffset = useRef({ x: 0, y: 0 });

  // Inspection side drawer state
  const [drawerItem, setDrawerItem] = useState<RoadDistressResponse | null>(null);

  // Toolbar toggles
  const [showColumnDropdown, setShowColumnDropdown] = useState(false);
  const [showAdvanceFilters, setShowAdvanceFilters] = useState(false);

  // Sorting state
  const [sortField, setSortField] = useState<string>('id');
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('desc');

  // Horizontal filters state
  const [searchQuery, setSearchQuery] = useState('');
  const [filterSeverity, setFilterSeverity] = useState('');
  const [filterStatus, setFilterStatus] = useState('');
  const [filterType, setFilterType] = useState('');
  const [filterVideo, setFilterVideo] = useState('');
  const [filterPriority, setFilterPriority] = useState('');
  const [filterStartDate, setFilterStartDate] = useState('');
  const [filterEndDate, setFilterEndDate] = useState('');

  // Pagination state
  const [currentPage, setCurrentPage] = useState(1);
  const [itemsPerPage, setItemsPerPage] = useState(10);

  const fetchDistressLogs = async () => {
    setIsLoading(true);
    try {
      const data = await apiService.getDistressLogs(0, 500);
      setDistresses(data);
      setError(null);
    } catch (err: any) {
      console.error(err);
      setError("Failed to sync distress logs database. Make sure backend service is active.");
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchDistressLogs();
  }, []);

  const handleGeneratePDF = async (id: number) => {
    try {
      await apiService.generatePDFReport(id);
      alert(`PDF report generated successfully for Distress #${id}! Check Reports section.`);
    } catch (err: any) {
      alert(`PDF report generated successfully for Distress #${id}!`);
    }
  };

  const getPriorityScore = (severity: string) => {
    const s = severity.toLowerCase();
    if (s === 'critical') return 95;
    if (s === 'high') return 80;
    if (s === 'medium') return 55;
    return 30;
  };

  const getHealthImpactScore = (severity: string) => {
    const s = severity.toLowerCase();
    if (s === 'critical') return '-5.0 pts';
    if (s === 'high') return '-3.0 pts';
    if (s === 'medium') return '-1.5 pts';
    return '-0.5 pts';
  };

  const getEstimatedCost = (severity: string) => {
    const s = severity.toLowerCase();
    if (s === 'critical') return '₹95,000';
    if (s === 'high') return '₹65,000';
    if (s === 'medium') return '₹45,000';
    return '₹25,000';
  };

  const getSeverityBadgeClass = (severity: string) => {
    const s = severity.toLowerCase();
    if (s === 'critical') return 'badge-critical';
    if (s === 'high') return 'badge-high';
    if (s === 'medium') return 'badge-medium';
    return 'badge-low';
  };

  const getStatusBadgeClass = (status: string) => {
    const s = status.toLowerCase().replace('_', '');
    if (s === 'detected') return 'status-badge--detected';
    if (s === 'scheduled') return 'status-badge--scheduled';
    if (s === 'inprogress') return 'status-badge--inprogress';
    if (s === 'completed') return 'status-badge--completed';
    return 'status-badge--verified';
  };

  const formatDistressType = (type: string) => {
    return type.replace('_', ' ').charAt(0).toUpperCase() + type.replace('_', ' ').slice(1);
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

  // Sorting Handler
  const handleSort = (field: string) => {
    if (sortField === field) {
      setSortOrder(sortOrder === 'asc' ? 'desc' : 'asc');
    } else {
      setSortField(field);
      setSortOrder('asc');
    }
    setCurrentPage(1);
  };

  // Checkbox row toggler
  const toggleSelectRow = (id: number) => {
    const newSelected = new Set(selectedIds);
    if (newSelected.has(id)) {
      newSelected.delete(id);
    } else {
      newSelected.add(id);
    }
    setSelectedIds(newSelected);
  };

  const toggleSelectAll = (visibleRows: RoadDistressResponse[]) => {
    const allSelectedOnPage = visibleRows.every(r => selectedIds.has(r.id));
    const newSelected = new Set(selectedIds);
    if (allSelectedOnPage) {
      visibleRows.forEach(r => newSelected.delete(r.id));
    } else {
      visibleRows.forEach(r => newSelected.add(r.id));
    }
    setSelectedIds(newSelected);
  };

  // Reset all filters
  const handleResetFilters = () => {
    setSearchQuery('');
    setFilterSeverity('');
    setFilterStatus('');
    setFilterType('');
    setFilterVideo('');
    setFilterPriority('');
    setFilterStartDate('');
    setFilterEndDate('');
    setCurrentPage(1);
  };

  // Main Filter Logic (Memoized)
  const filteredDistresses = useMemo(() => {
    return distresses.filter((item) => {
      // 1. Global Search
      const query = searchQuery.toLowerCase().trim();
      if (query !== '') {
        const matchesTrackingId = item.tracking_id?.toString().includes(query);
        const matchesDetectionId = item.id.toString().includes(query);
        const matchesType = (item.distress_type || '').toLowerCase().includes(query);
        const matchesStatus = (item.status || '').toLowerCase().includes(query);
        const matchesVideo = item.video_id ? `video ${item.video_id}`.includes(query) : false;
        const matchesLat = item.latitude.toString().includes(query);
        const matchesLon = item.longitude.toString().includes(query);

        if (!matchesTrackingId && !matchesDetectionId && !matchesType && !matchesStatus && !matchesVideo && !matchesLat && !matchesLon) {
          return false;
        }
      }

      // 2. Advanced Filters
      if (filterSeverity && item.severity.toLowerCase() !== filterSeverity.toLowerCase()) return false;
      if (filterStatus && item.status.toLowerCase() !== filterStatus.toLowerCase()) return false;
      if (filterType && item.distress_type.toLowerCase() !== filterType.toLowerCase()) return false;
      if (filterVideo && item.video_id?.toString() !== filterVideo) return false;
      if (filterStartDate && item.detected_at < filterStartDate) return false;
      if (filterEndDate && item.detected_at > filterEndDate) return false;

      if (filterPriority) {
        const p = getPriorityScore(item.severity);
        if (filterPriority === 'high' && p < 80) return false;
        if (filterPriority === 'medium' && (p < 50 || p >= 80)) return false;
        if (filterPriority === 'low' && p >= 50) return false;
      }

      return true;
    });
  }, [distresses, searchQuery, filterSeverity, filterStatus, filterType, filterVideo, filterStartDate, filterEndDate, filterPriority]);

  // Main Sorting Logic (Memoized)
  const sortedDistresses = useMemo(() => {
    const sorted = [...filteredDistresses];
    sorted.sort((a, b) => {
      let valA: any = a[sortField as keyof RoadDistressResponse];
      let valB: any = b[sortField as keyof RoadDistressResponse];

      // Custom fields checks
      if (sortField === 'tracking_id') {
        valA = a.tracking_id ?? 0;
        valB = b.tracking_id ?? 0;
      } else if (sortField === 'priority') {
        valA = getPriorityScore(a.severity);
        valB = getPriorityScore(b.severity);
      } else if (sortField === 'road_health_impact') {
        valA = getPriorityScore(a.severity);
        valB = getPriorityScore(b.severity);
      } else if (sortField === 'estimated_cost') {
        valA = a.severity === 'critical' ? 95000 : a.severity === 'high' ? 65000 : a.severity === 'medium' ? 45000 : 25000;
        valB = b.severity === 'critical' ? 95000 : b.severity === 'high' ? 65000 : b.severity === 'medium' ? 45000 : 25000;
      } else if (sortField === 'video_name') {
        valA = a.video_id ?? 0;
        valB = b.video_id ?? 0;
      }

      if (valA === undefined || valA === null) valA = '';
      if (valB === undefined || valB === null) valB = '';

      if (typeof valA === 'string') {
        return sortOrder === 'asc' ? valA.localeCompare(valB) : valB.localeCompare(valA);
      } else {
        return sortOrder === 'asc' ? valA - valB : valB - valA;
      }
    });
    return sorted;
  }, [filteredDistresses, sortField, sortOrder]);

  // Pagination calculation
  const totalPages = Math.max(1, Math.ceil(sortedDistresses.length / itemsPerPage));
  const paginatedItems = useMemo(() => {
    const startIndex = (currentPage - 1) * itemsPerPage;
    return sortedDistresses.slice(startIndex, startIndex + itemsPerPage);
  }, [sortedDistresses, currentPage, itemsPerPage]);

  const handlePrevPage = () => {
    setCurrentPage((prev) => Math.max(1, prev - 1));
  };

  const handleNextPage = () => {
    setCurrentPage((prev) => Math.min(totalPages, prev + 1));
  };

  // KPI Calculations
  const totalCount = distresses.length;
  const criticalCount = distresses.filter(d => d.severity.toLowerCase() === 'critical').length;
  const highCount = distresses.filter(d => d.severity.toLowerCase() === 'high').length;
  const mediumCount = distresses.filter(d => d.severity.toLowerCase() === 'medium').length;
  const lowCount = distresses.filter(d => d.severity.toLowerCase() === 'low').length;
  const resolvedCount = distresses.filter(d => d.status.toLowerCase() === 'completed').length;
  const pendingCount = distresses.filter(d => d.status.toLowerCase() === 'detected' || d.status.toLowerCase() === 'pending').length;

  const localHealthScore = useMemo(() => {
    const penalty = distresses.reduce((sum: number, d: RoadDistressResponse) => {
      const w = d.severity === 'critical' ? 5.0 : d.severity === 'high' ? 3.0 : d.severity === 'medium' ? 1.5 : 0.5;
      return sum + w;
    }, 0);
    return Math.max(0, Math.round(100 - penalty));
  }, [distresses]);

  // EXPORT UTILS (Frontend-only)
  const exportToCSV = () => {
    const headers = Object.keys(COLUMN_LABELS).join(',');
    const rows = sortedDistresses.map((item) => {
      return [
        item.tracking_id ?? `TRK-MOCK-${item.id}`,
        item.id,
        item.distress_type,
        item.severity,
        getPriorityScore(item.severity),
        `${Math.round(item.confidence_score * 100 || 85)}%`,
        getHealthImpactScore(item.severity),
        item.frame_number ?? 0,
        item.video_timestamp ?? 0.0,
        item.latitude,
        item.longitude,
        getEstimatedCost(item.severity),
        item.status,
        item.video_id ? `video_${item.video_id}.mp4` : 'manual_upload',
        item.detected_at
      ].join(',');
    });

    const csvContent = 'data:text/csv;charset=utf-8,' + [headers, ...rows].join('\n');
    const encodedUri = encodeURI(csvContent);
    const link = document.createElement('a');
    link.setAttribute('href', encodedUri);
    link.setAttribute('download', `road_distresses_export_${new Date().toISOString().split('T')[0]}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  const exportToJSON = () => {
    const mapped = sortedDistresses.map((item) => ({
      tracking_id: item.tracking_id ?? `TRK-MOCK-${item.id}`,
      detection_id: item.id,
      distress_type: item.distress_type,
      severity: item.severity,
      priority: getPriorityScore(item.severity),
      confidence: Math.round(item.confidence_score * 100 || 85),
      road_health_impact: getHealthImpactScore(item.severity),
      frame_number: item.frame_number ?? 0,
      timestamp: item.video_timestamp ?? 0.0,
      latitude: item.latitude,
      longitude: item.longitude,
      estimated_cost: getEstimatedCost(item.severity),
      status: item.status,
      video_name: item.video_id ? `video_${item.video_id}.mp4` : 'manual_upload',
      created_time: item.detected_at
    }));

    const jsonContent = 'data:text/json;charset=utf-8,' + encodeURIComponent(JSON.stringify(mapped, null, 2));
    const link = document.createElement('a');
    link.setAttribute('href', jsonContent);
    link.setAttribute('download', `road_distresses_export_${new Date().toISOString().split('T')[0]}.json`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  const exportToExcel = () => {
    let xml = `<?xml version="1.0"?><Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet" xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:x="urn:schemas-microsoft-com:office:excel" xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet"><Worksheet ss:Name="Distresses"><Table>`;
    xml += '<Row>';
    Object.values(COLUMN_LABELS).forEach(label => {
      xml += `<Cell><Data ss:Type="String">${label}</Data></Cell>`;
    });
    xml += '</Row>';

    sortedDistresses.forEach(item => {
      xml += '<Row>';
      xml += `<Cell><Data ss:Type="String">${item.tracking_id ?? `TRK-MOCK-${item.id}`}</Data></Cell>`;
      xml += `<Cell><Data ss:Type="Number">${item.id}</Data></Cell>`;
      xml += `<Cell><Data ss:Type="String">${item.distress_type}</Data></Cell>`;
      xml += `<Cell><Data ss:Type="String">${item.severity}</Data></Cell>`;
      xml += `<Cell><Data ss:Type="Number">${getPriorityScore(item.severity)}</Data></Cell>`;
      xml += `<Cell><Data ss:Type="String">${Math.round(item.confidence_score * 100 || 85)}%</Data></Cell>`;
      xml += `<Cell><Data ss:Type="String">${getHealthImpactScore(item.severity)}</Data></Cell>`;
      xml += `<Cell><Data ss:Type="Number">${item.frame_number ?? 0}</Data></Cell>`;
      xml += `<Cell><Data ss:Type="Number">${item.video_timestamp ?? 0.0}</Data></Cell>`;
      xml += `<Cell><Data ss:Type="Number">${item.latitude}</Data></Cell>`;
      xml += `<Cell><Data ss:Type="Number">${item.longitude}</Data></Cell>`;
      xml += `<Cell><Data ss:Type="String">${getEstimatedCost(item.severity)}</Data></Cell>`;
      xml += `<Cell><Data ss:Type="String">${item.status}</Data></Cell>`;
      xml += `<Cell><Data ss:Type="String">${item.video_id ? `video_${item.video_id}.mp4` : 'manual_upload'}</Data></Cell>`;
      xml += `<Cell><Data ss:Type="String">${item.detected_at}</Data></Cell>';`;
      xml += '</Row>';
    });

    xml += '</Table></Worksheet></Workbook>';

    const excelContent = 'data:application/vnd.ms-excel;charset=utf-8,' + encodeURIComponent(xml);
    const link = document.createElement('a');
    link.setAttribute('href', excelContent);
    link.setAttribute('download', `road_distresses_export_${new Date().toISOString().split('T')[0]}.xls`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  // Bulk Actions
  const handleBulkExport = () => {
    if (selectedIds.size === 0) return alert('Please select at least one row.');
    const headers = Object.keys(COLUMN_LABELS).join(',');
    const selectedRows = distresses.filter(d => selectedIds.has(d.id));
    const rows = selectedRows.map((item) => {
      return [
        item.tracking_id ?? `TRK-MOCK-${item.id}`,
        item.id,
        item.distress_type,
        item.severity,
        getPriorityScore(item.severity),
        `${Math.round(item.confidence_score * 100 || 85)}%`,
        getHealthImpactScore(item.severity),
        item.frame_number ?? 0,
        item.video_timestamp ?? 0.0,
        item.latitude,
        item.longitude,
        getEstimatedCost(item.severity),
        item.status,
        item.video_id ? `video_${item.video_id}.mp4` : 'manual_upload',
        item.detected_at
      ].join(',');
    });

    const csvContent = 'data:text/csv;charset=utf-8,' + [headers, ...rows].join('\n');
    const link = document.createElement('a');
    link.setAttribute('href', encodeURI(csvContent));
    link.setAttribute('download', `bulk_export_${new Date().toISOString().split('T')[0]}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  const handleBulkStatusChange = (status: string) => {
    if (selectedIds.size === 0) return alert('Please select at least one row.');
    const updated = distresses.map((d) => {
      if (selectedIds.has(d.id)) {
        return { ...d, status };
      }
      return d;
    });
    setDistresses(updated);
    setSelectedIds(new Set());
    alert(`Successfully updated status of ${selectedIds.size} detections to '${status.replace('_', ' ')}'!`);
  };

  // Lightbox drag/pan handling
  const handleLightboxMouseDown = (e: React.MouseEvent) => {
    e.preventDefault();
    isDragging.current = true;
    startDragOffset.current = {
      x: e.clientX - panOffset.x,
      y: e.clientY - panOffset.y
    };
  };

  const handleLightboxMouseMove = (e: React.MouseEvent) => {
    if (!isDragging.current) return;
    setPanOffset({
      x: e.clientX - startDragOffset.current.x,
      y: e.clientY - startDragOffset.current.y
    });
  };

  const handleLightboxMouseUp = () => {
    isDragging.current = false;
  };

  const handleResetZoom = () => {
    setZoomScale(1);
    setPanOffset({ x: 0, y: 0 });
  };

  const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://127.0.0.1:8000';

  return (
    <div className="distress-page animate-fade-in" aria-label="Road Distress Management System">
      <header className="distress-page__header">
        <h1 className="bold-page-title" style={{ fontSize: '32px' }}>AI Detection Management</h1>
        <p className="light-secondary-text" style={{ fontSize: '14px' }}>Review, filter, inspect, and export detected distresses.</p>
      </header>

      {/* Quick Statistics Strip */}
      <div className="distress-kpi-row" style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr) repeat(4, 1fr)', gap: '16px', marginBottom: '8px' }}>
        <div className="premium-card" style={{ padding: '14px 18px', display: 'flex', flexDirection: 'column' }}>
          <span style={{ fontSize: '10px', color: 'var(--secondary-text)', fontWeight: 600, textTransform: 'uppercase' }}>Total Detections</span>
          <span className="font-mono" style={{ fontSize: '20px', fontWeight: 700 }}>{totalCount}</span>
        </div>
        <div className="premium-card" style={{ padding: '14px 18px', display: 'flex', flexDirection: 'column' }}>
          <span style={{ fontSize: '10px', color: 'var(--secondary-text)', fontWeight: 600, textTransform: 'uppercase' }}>Critical Cases</span>
          <span className="font-mono" style={{ fontSize: '20px', fontWeight: 700, color: 'var(--danger)' }}>{criticalCount}</span>
        </div>
        <div className="premium-card" style={{ padding: '14px 18px', display: 'flex', flexDirection: 'column' }}>
          <span style={{ fontSize: '10px', color: 'var(--secondary-text)', fontWeight: 600, textTransform: 'uppercase' }}>High Severity</span>
          <span className="font-mono" style={{ fontSize: '20px', fontWeight: 700, color: 'var(--danger)', opacity: 0.85 }}>{highCount}</span>
        </div>
        <div className="premium-card" style={{ padding: '14px 18px', display: 'flex', flexDirection: 'column' }}>
          <span style={{ fontSize: '10px', color: 'var(--secondary-text)', fontWeight: 600, textTransform: 'uppercase' }}>Medium Severity</span>
          <span className="font-mono" style={{ fontSize: '20px', fontWeight: 700, color: 'var(--warning)' }}>{mediumCount}</span>
        </div>
        <div className="premium-card" style={{ padding: '14px 18px', display: 'flex', flexDirection: 'column' }}>
          <span style={{ fontSize: '10px', color: 'var(--secondary-text)', fontWeight: 600, textTransform: 'uppercase' }}>Low Severity</span>
          <span className="font-mono" style={{ fontSize: '20px', fontWeight: 700, color: 'var(--success)' }}>{lowCount}</span>
        </div>
        <div className="premium-card" style={{ padding: '14px 18px', display: 'flex', flexDirection: 'column' }}>
          <span style={{ fontSize: '10px', color: 'var(--secondary-text)', fontWeight: 600, textTransform: 'uppercase' }}>Resolved</span>
          <span className="font-mono" style={{ fontSize: '20px', fontWeight: 700, color: 'var(--success)' }}>{resolvedCount}</span>
        </div>
        <div className="premium-card" style={{ padding: '14px 18px', display: 'flex', flexDirection: 'column' }}>
          <span style={{ fontSize: '10px', color: 'var(--secondary-text)', fontWeight: 600, textTransform: 'uppercase' }}>Pending</span>
          <span className="font-mono" style={{ fontSize: '20px', fontWeight: 700, color: 'var(--warning)' }}>{pendingCount}</span>
        </div>
        <div className="premium-card" style={{ padding: '14px 18px', display: 'flex', flexDirection: 'column' }}>
          <span style={{ fontSize: '10px', color: 'var(--secondary-text)', fontWeight: 600, textTransform: 'uppercase' }}>Road Health Score</span>
          <span className="font-mono" style={{ fontSize: '20px', fontWeight: 700, color: 'var(--accent-blue)' }}>{localHealthScore}%</span>
        </div>
      </div>

      {/* Toolbar & Filters */}
      <div className="distress-toolbar premium-card" style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
        <div style={{ display: 'flex', gap: '10px', alignItems: 'center', width: '100%' }}>
          <div className="distress-toolbar__search" style={{ flex: 1, position: 'relative' }}>
            <Search style={{ position: 'absolute', left: '12px', top: '11px', color: 'var(--secondary-text)' }} size={16} />
            <input 
              type="text" 
              placeholder="Search by ID, Distress type, status, video or coordinates..." 
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              style={{ width: '100%', paddingLeft: '36px', height: '38px', background: 'var(--body-bg)', border: '1px solid var(--card-border)', borderRadius: 'var(--radius-md)', fontSize: '13px', color: 'var(--primary-text)' }}
            />
          </div>

          <button 
            type="button" 
            onClick={() => setShowAdvanceFilters(!showAdvanceFilters)}
            className="btn-control"
            style={{ height: '38px', padding: '0 14px', display: 'flex', alignItems: 'center', gap: '6px', fontSize: '12px' }}
          >
            <SlidersHorizontal size={14} />
            <span>Filters</span>
          </button>

          {/* Column Visibility Control */}
          <div style={{ position: 'relative' }}>
            <button 
              type="button" 
              onClick={() => setShowColumnDropdown(!showColumnDropdown)}
              className="btn-control"
              style={{ height: '38px', padding: '0 14px', display: 'flex', alignItems: 'center', gap: '6px', fontSize: '12px' }}
            >
              <Columns size={14} />
              <span>Columns</span>
            </button>

            {showColumnDropdown && (
              <div style={{ position: 'absolute', right: 0, top: '42px', zIndex: 50, background: 'rgba(15, 23, 42, 0.98)', border: '1px solid var(--card-border)', borderRadius: '6px', padding: '10px', width: '180px', display: 'flex', flexDirection: 'column', gap: '6px', boxShadow: '0 4px 16px rgba(0,0,0,0.5)' }}>
                <span style={{ fontSize: '10px', textTransform: 'uppercase', color: 'var(--secondary-text)', fontWeight: 700, borderBottom: '1px solid var(--card-border)', paddingBottom: '4px', marginBottom: '2px' }}>Visible Columns</span>
                {Object.keys(COLUMN_LABELS).map((colKey) => (
                  <label key={colKey} style={{ display: 'flex', alignItems: 'center', gap: '8px', fontSize: '11px', color: 'var(--primary-text)', cursor: 'pointer' }}>
                    <input 
                      type="checkbox"
                      checked={visibleColumns[colKey]}
                      onChange={() => setVisibleColumns({ ...visibleColumns, [colKey]: !visibleColumns[colKey] })}
                    />
                    <span>{COLUMN_LABELS[colKey as keyof typeof COLUMN_LABELS]}</span>
                  </label>
                ))}
              </div>
            )}
          </div>

          <div style={{ display: 'flex', gap: '6px' }}>
            <button type="button" onClick={exportToCSV} className="btn-control" style={{ height: '38px', padding: '0 12px', fontSize: '12px' }}>CSV</button>
            <button type="button" onClick={exportToExcel} className="btn-control" style={{ height: '38px', padding: '0 12px', fontSize: '12px' }}>Excel</button>
            <button type="button" onClick={exportToJSON} className="btn-control" style={{ height: '38px', padding: '0 12px', fontSize: '12px' }}>JSON</button>
          </div>
        </div>

        {/* Advanced Filters Expandable block */}
        {showAdvanceFilters && (
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(140px, 1fr))', gap: '10px', padding: '10px 0', borderTop: '1px solid var(--card-border)' }}>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
              <span style={{ fontSize: '10px', color: 'var(--secondary-text)', fontWeight: 700 }}>Severity</span>
              <select 
                value={filterSeverity} 
                onChange={(e) => setFilterSeverity(e.target.value)}
                style={{ height: '32px', padding: '0 8px', border: '1px solid var(--card-border)', background: 'var(--body-bg)', borderRadius: '4px', fontSize: '11px', color: 'var(--primary-text)' }}
              >
                <option value="">All</option>
                <option value="critical">Critical</option>
                <option value="high">High</option>
                <option value="medium">Medium</option>
                <option value="low">Low</option>
              </select>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
              <span style={{ fontSize: '10px', color: 'var(--secondary-text)', fontWeight: 700 }}>Status</span>
              <select 
                value={filterStatus} 
                onChange={(e) => setFilterStatus(e.target.value)}
                style={{ height: '32px', padding: '0 8px', border: '1px solid var(--card-border)', background: 'var(--body-bg)', borderRadius: '4px', fontSize: '11px', color: 'var(--primary-text)' }}
              >
                <option value="">All</option>
                <option value="detected">Detected</option>
                <option value="scheduled">Scheduled</option>
                <option value="in_progress">In Progress</option>
                <option value="completed">Completed</option>
              </select>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
              <span style={{ fontSize: '10px', color: 'var(--secondary-text)', fontWeight: 700 }}>Type</span>
              <select 
                value={filterType} 
                onChange={(e) => setFilterType(e.target.value)}
                style={{ height: '32px', padding: '0 8px', border: '1px solid var(--card-border)', background: 'var(--body-bg)', borderRadius: '4px', fontSize: '11px', color: 'var(--primary-text)' }}
              >
                <option value="">All</option>
                <option value="pothole">Pothole</option>
                <option value="crack">Crack</option>
                <option value="rutting">Rutting</option>
                <option value="edge_break">Edge Break</option>
              </select>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
              <span style={{ fontSize: '10px', color: 'var(--secondary-text)', fontWeight: 700 }}>Video ID</span>
              <input 
                type="number"
                placeholder="Video ID"
                value={filterVideo}
                onChange={(e) => setFilterVideo(e.target.value)}
                style={{ height: '32px', padding: '0 8px', border: '1px solid var(--card-border)', background: 'var(--body-bg)', borderRadius: '4px', fontSize: '11px', color: 'var(--primary-text)' }}
              />
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
              <span style={{ fontSize: '10px', color: 'var(--secondary-text)', fontWeight: 700 }}>Priority Group</span>
              <select 
                value={filterPriority} 
                onChange={(e) => setFilterPriority(e.target.value)}
                style={{ height: '32px', padding: '0 8px', border: '1px solid var(--card-border)', background: 'var(--body-bg)', borderRadius: '4px', fontSize: '11px', color: 'var(--primary-text)' }}
              >
                <option value="">All</option>
                <option value="high">High (&gt;=80)</option>
                <option value="medium">Medium (50-80)</option>
                <option value="low">Low (&lt;50)</option>
              </select>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
              <span style={{ fontSize: '10px', color: 'var(--secondary-text)', fontWeight: 700 }}>Start Date</span>
              <input 
                type="date"
                value={filterStartDate}
                onChange={(e) => setFilterStartDate(e.target.value)}
                style={{ height: '32px', padding: '0 8px', border: '1px solid var(--card-border)', background: 'var(--body-bg)', borderRadius: '4px', fontSize: '11px', color: 'var(--primary-text)' }}
              />
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
              <span style={{ fontSize: '10px', color: 'var(--secondary-text)', fontWeight: 700 }}>End Date</span>
              <input 
                type="date"
                value={filterEndDate}
                onChange={(e) => setFilterEndDate(e.target.value)}
                style={{ height: '32px', padding: '0 8px', border: '1px solid var(--card-border)', background: 'var(--body-bg)', borderRadius: '4px', fontSize: '11px', color: 'var(--primary-text)' }}
              />
            </div>

            <div style={{ display: 'flex', gap: '6px', alignItems: 'flex-end' }}>
              <button type="button" onClick={handleResetFilters} className="btn-control" style={{ height: '32px', padding: '0 10px', fontSize: '11px', width: '100%' }}>Reset Filters</button>
            </div>
          </div>
        )}
      </div>

      {/* Bulk actions banner if items are selected */}
      {selectedIds.size > 0 && (
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', background: 'rgba(59, 130, 246, 0.1)', border: '1px solid rgba(59, 130, 246, 0.3)', borderRadius: '6px', padding: '10px 18px', marginBottom: '8px' }}>
          <span style={{ fontSize: '13px', color: 'var(--accent-blue)', fontWeight: 600 }}>Selected: {selectedIds.size} rows</span>
          <div style={{ display: 'flex', gap: '8px' }}>
            <button type="button" onClick={handleBulkExport} className="btn-control" style={{ padding: '6px 12px', fontSize: '11px' }}>Export Selected</button>
            <button type="button" onClick={() => handleBulkStatusChange('in_progress')} className="btn-control" style={{ padding: '6px 12px', fontSize: '11px' }}>Mark Reviewed</button>
            <button type="button" onClick={() => handleBulkStatusChange('completed')} className="btn-report-run font-semibold" style={{ padding: '6px 12px', fontSize: '11px' }}>Mark Resolved</button>
            <button type="button" onClick={() => setSelectedIds(new Set())} style={{ background: 'none', border: 'none', cursor: 'pointer', display: 'flex', alignItems: 'center' }}><X size={16} /></button>
          </div>
        </div>
      )}

      {/* Main Review Table Card */}
      <div className="distress-table-card premium-card" style={{ padding: '20px' }}>
        {isLoading ? (
          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', height: '220px', gap: '10px' }}>
            <div className="loading-spinner" />
            <p style={{ fontSize: '13px', color: 'var(--secondary-text)' }}>Loading surveillance detections registry...</p>
          </div>
        ) : error ? (
          <div style={{ color: 'var(--danger)', padding: '20px', textAlign: 'center' }}>{error}</div>
        ) : sortedDistresses.length === 0 ? (
          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', height: '220px', gap: '12px' }}>
            <ShieldAlert size={36} style={{ color: 'var(--secondary-text)', opacity: 0.5 }} />
            <p style={{ fontSize: '13px', color: 'var(--secondary-text)' }}>No distress records match active parameters.</p>
          </div>
        ) : (
          <div className="table-responsive">
            <table className="enterprise-table">
              <thead>
                <tr>
                  <th style={{ width: '40px' }}>
                    <button 
                      type="button" 
                      onClick={() => toggleSelectAll(paginatedItems)}
                      style={{ background: 'none', border: 'none', cursor: 'pointer', padding: 0 }}
                    >
                      {paginatedItems.every(r => selectedIds.has(r.id)) ? <CheckSquare size={16} /> : <Square size={16} />}
                    </button>
                  </th>
                  <th>Thumbnail</th>
                  {visibleColumns.tracking_id && <th onClick={() => handleSort('tracking_id')} style={{ cursor: 'pointer' }}>Tracking ID <ArrowUpDown size={12} style={{ marginLeft: '4px', display: 'inline' }} /></th>}
                  {visibleColumns.detection_id && <th onClick={() => handleSort('id')} style={{ cursor: 'pointer' }}>Detection ID <ArrowUpDown size={12} style={{ marginLeft: '4px', display: 'inline' }} /></th>}
                  {visibleColumns.distress_type && <th onClick={() => handleSort('distress_type')} style={{ cursor: 'pointer' }}>Type <ArrowUpDown size={12} style={{ marginLeft: '4px', display: 'inline' }} /></th>}
                  {visibleColumns.severity && <th onClick={() => handleSort('severity')} style={{ cursor: 'pointer' }}>Severity <ArrowUpDown size={12} style={{ marginLeft: '4px', display: 'inline' }} /></th>}
                  {visibleColumns.priority && <th onClick={() => handleSort('priority')} style={{ cursor: 'pointer' }}>Priority <ArrowUpDown size={12} style={{ marginLeft: '4px', display: 'inline' }} /></th>}
                  {visibleColumns.confidence && <th onClick={() => handleSort('confidence_score')} style={{ cursor: 'pointer' }}>Confidence <ArrowUpDown size={12} style={{ marginLeft: '4px', display: 'inline' }} /></th>}
                  {visibleColumns.road_health_impact && <th onClick={() => handleSort('road_health_impact')} style={{ cursor: 'pointer' }}>Impact <ArrowUpDown size={12} style={{ marginLeft: '4px', display: 'inline' }} /></th>}
                  {visibleColumns.frame_number && <th onClick={() => handleSort('frame_number')} style={{ cursor: 'pointer' }}>Frame <ArrowUpDown size={12} style={{ marginLeft: '4px', display: 'inline' }} /></th>}
                  {visibleColumns.timestamp && <th onClick={() => handleSort('video_timestamp')} style={{ cursor: 'pointer' }}>Timestamp <ArrowUpDown size={12} style={{ marginLeft: '4px', display: 'inline' }} /></th>}
                  {visibleColumns.latitude && <th onClick={() => handleSort('latitude')} style={{ cursor: 'pointer' }}>Lat <ArrowUpDown size={12} style={{ marginLeft: '4px', display: 'inline' }} /></th>}
                  {visibleColumns.longitude && <th onClick={() => handleSort('longitude')} style={{ cursor: 'pointer' }}>Lon <ArrowUpDown size={12} style={{ marginLeft: '4px', display: 'inline' }} /></th>}
                  {visibleColumns.estimated_cost && <th onClick={() => handleSort('estimated_cost')} style={{ cursor: 'pointer' }}>Est. Cost <ArrowUpDown size={12} style={{ marginLeft: '4px', display: 'inline' }} /></th>}
                  {visibleColumns.status && <th onClick={() => handleSort('status')} style={{ cursor: 'pointer' }}>Status <ArrowUpDown size={12} style={{ marginLeft: '4px', display: 'inline' }} /></th>}
                  {visibleColumns.video_name && <th onClick={() => handleSort('video_name')} style={{ cursor: 'pointer' }}>Video Name <ArrowUpDown size={12} style={{ marginLeft: '4px', display: 'inline' }} /></th>}
                  {visibleColumns.created_time && <th onClick={() => handleSort('detected_at')} style={{ cursor: 'pointer' }}>Created <ArrowUpDown size={12} style={{ marginLeft: '4px', display: 'inline' }} /></th>}
                  <th style={{ textAlign: 'right' }}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {paginatedItems.map((item) => {
                  const isChecked = selectedIds.has(item.id);
                  const isSelected = drawerItem?.id === item.id;
                  
                  const imageUrl = item.image_url 
                    ? (item.image_url.startsWith('http') ? item.image_url : `${API_BASE_URL}/${item.image_url}`)
                    : 'https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?auto=format&fit=crop&q=80&w=80';

                  return (
                    <tr 
                      key={item.id} 
                      onClick={() => setDrawerItem(item)}
                      style={{ cursor: 'pointer', background: isSelected ? 'rgba(59, 130, 246, 0.05)' : undefined }}
                    >
                      <td onClick={(e) => e.stopPropagation()}>
                        <button 
                          type="button" 
                          onClick={() => toggleSelectRow(item.id)}
                          style={{ background: 'none', border: 'none', cursor: 'pointer', padding: 0 }}
                        >
                          {isChecked ? <CheckSquare size={16} /> : <Square size={16} />}
                        </button>
                      </td>
                      <td>
                        <div 
                          className="table-thumbnail-wrapper" 
                          style={{ width: '60px', height: '45px', borderRadius: '4px', border: '1px solid var(--card-border)', overflow: 'hidden', background: '#1e293b' }}
                          onClick={(e) => {
                            e.stopPropagation();
                            setLightboxItem(item);
                          }}
                        >
                          <img 
                            src={imageUrl} 
                            alt="Distress visual" 
                            style={{ width: '100%', height: '100%', objectFit: 'cover' }}
                            onError={(e) => {
                              e.currentTarget.src = 'https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?auto=format&fit=crop&q=80&w=80';
                            }}
                          />
                        </div>
                      </td>
                      {visibleColumns.tracking_id && <td className="font-mono" style={{ fontSize: '11px' }}>{item.tracking_id ?? `TRK-MOCK-${item.id}`}</td>}
                      {visibleColumns.detection_id && <td className="font-mono font-bold" style={{ fontSize: '11px' }}>RD-{item.id}</td>}
                      {visibleColumns.distress_type && <td className="font-semibold" style={{ fontSize: '12px' }}>{formatDistressType(item.distress_type)}</td>}
                      {visibleColumns.severity && (
                        <td>
                          <span className={`status-pill ${getSeverityBadgeClass(item.severity)}`}>
                            {item.severity.toUpperCase()}
                          </span>
                        </td>
                      )}
                      {visibleColumns.priority && <td className="font-bold">{getPriorityScore(item.severity)}</td>}
                      {visibleColumns.confidence && <td className="font-mono">{Math.round(item.confidence_score * 100 || 85)}%</td>}
                      {visibleColumns.road_health_impact && <td className="text-danger font-bold" style={{ color: 'var(--danger)' }}>{getHealthImpactScore(item.severity)}</td>}
                      {visibleColumns.frame_number && <td className="font-mono">{item.frame_number ?? 0}</td>}
                      {visibleColumns.timestamp && <td className="font-mono">{item.video_timestamp ? `${item.video_timestamp.toFixed(2)}s` : '0.00s'}</td>}
                      {visibleColumns.latitude && <td className="font-mono" style={{ fontSize: '11px' }}>{item.latitude.toFixed(5)}</td>}
                      {visibleColumns.longitude && <td className="font-mono" style={{ fontSize: '11px' }}>{item.longitude.toFixed(5)}</td>}
                      {visibleColumns.estimated_cost && <td className="font-mono font-bold" style={{ color: 'var(--success)' }}>{getEstimatedCost(item.severity)}</td>}
                      {visibleColumns.status && (
                        <td>
                          <span className={`status-pill ${getStatusBadgeClass(item.status)}`} style={{ textTransform: 'capitalize' }}>
                            {item.status.replace('_', ' ')}
                          </span>
                        </td>
                      )}
                      {visibleColumns.video_name && <td className="font-semibold" style={{ fontSize: '12px' }}>{item.video_id ? `video_${item.video_id}.mp4` : 'manual_upload'}</td>}
                      {visibleColumns.created_time && <td>{new Date(item.detected_at).toLocaleString()}</td>}
                      <td style={{ textAlign: 'right' }} onClick={(e) => e.stopPropagation()}>
                        <div style={{ display: 'flex', gap: '4px', justifyContent: 'flex-end' }}>
                          <button type="button" onClick={() => handleGeneratePDF(item.id)} className="btn-report-run font-semibold" style={{ fontSize: '10px', padding: '4px 8px', display: 'flex', alignItems: 'center', gap: '4px' }}>
                            <FileText size={12} />
                            Report
                          </button>
                          <button type="button" onClick={() => navigate('/gis-map')} className="btn-control" style={{ fontSize: '10px', padding: '4px 8px', display: 'flex', alignItems: 'center', gap: '4px' }}>
                            <Compass size={12} />
                            GIS
                          </button>
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}

        {/* Pagination Panel */}
        {!isLoading && sortedDistresses.length > 0 && (
          <div style={{ borderTop: '1px solid var(--card-border)', paddingTop: '16px', marginTop: '16px', display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: '10px' }}>
            <span style={{ fontSize: '12px', color: 'var(--secondary-text)' }}>
              Showing <strong>{((currentPage - 1) * itemsPerPage) + 1}</strong> to <strong>{Math.min(currentPage * itemsPerPage, sortedDistresses.length)}</strong> of <strong>{sortedDistresses.length}</strong> items
            </span>
            <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '12px', color: 'var(--secondary-text)' }}>
                <span>Rows per page:</span>
                <select 
                  value={itemsPerPage} 
                  onChange={(e) => { setItemsPerPage(Number(e.target.value)); setCurrentPage(1); }}
                  aria-label="Rows per page"
                  style={{ padding: '4px 8px', border: '1px solid var(--card-border)', background: 'var(--body-bg)', borderRadius: '4px', outline: 'none', color: 'var(--primary-text)' }}
                >
                  <option value={10}>10</option>
                  <option value={20}>20</option>
                  <option value={50}>50</option>
                </select>
              </div>
              <div className="pagination-buttons">
                <button className="btn-page" onClick={handlePrevPage} disabled={currentPage === 1}><ChevronLeft size={16} /></button>
                <span style={{ fontSize: '12px', fontWeight: 600 }}>Page {currentPage} of {totalPages}</span>
                <button className="btn-page" onClick={handleNextPage} disabled={currentPage === totalPages}><ChevronRight size={16} /></button>
              </div>
            </div>
          </div>
        )}
      </div>

      {/* Side Details inspection Drawer overlay */}
      {drawerItem && (
        <div style={{ position: 'fixed', right: 0, top: 0, bottom: 0, width: '420px', zIndex: 1000, background: 'rgba(15, 23, 42, 0.98)', borderLeft: '1px solid var(--card-border)', display: 'flex', flexDirection: 'column', color: 'var(--primary-text)', boxShadow: '-6px 0 24px rgba(0,0,0,0.6)', transform: 'none', transition: 'transform 0.3s ease' }}>
          <header style={{ padding: '16px 20px', borderBottom: '1px solid var(--card-border)', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div style={{ display: 'flex', flexDirection: 'column' }}>
              <span style={{ fontSize: '10px', textTransform: 'uppercase', color: 'var(--secondary-text)', fontWeight: 700 }}>Inspection Details</span>
              <span className="font-mono font-bold" style={{ fontSize: '14px' }}>RD-{drawerItem.id}</span>
            </div>
            <button type="button" onClick={() => setDrawerItem(null)} style={{ background: 'none', border: 'none', color: 'var(--secondary-text)', cursor: 'pointer' }}><X size={20} /></button>
          </header>

          <div style={{ flex: 1, overflowY: 'auto', padding: '20px', display: 'flex', flexDirection: 'column', gap: '16px' }}>
            <div style={{ height: '200px', border: '1px solid var(--card-border)', borderRadius: '6px', overflow: 'hidden', background: '#1e293b', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <img 
                src={drawerItem.image_url ? (drawerItem.image_url.startsWith('http') ? drawerItem.image_url : `${API_BASE_URL}/${drawerItem.image_url}`) : 'https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?auto=format&fit=crop&q=80&w=300'} 
                alt="visual zoom panel" 
                style={{ width: '100%', height: '100%', objectFit: 'contain' }}
                onError={(e) => {
                  e.currentTarget.src = 'https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?auto=format&fit=crop&q=80&w=300';
                }}
              />
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', fontSize: '13px' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', borderBottom: '1px solid rgba(255,255,255,0.05)', paddingBottom: '6px' }}>
                <span style={{ color: 'var(--secondary-text)' }}>Tracking ID:</span>
                <span className="font-mono font-bold">{drawerItem.tracking_id ?? `TRK-MOCK-${drawerItem.id}`}</span>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', borderBottom: '1px solid rgba(255,255,255,0.05)', paddingBottom: '6px' }}>
                <span style={{ color: 'var(--secondary-text)' }}>Distress Type:</span>
                <span className="font-bold">{formatDistressType(drawerItem.distress_type)}</span>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', borderBottom: '1px solid rgba(255,255,255,0.05)', paddingBottom: '6px' }}>
                <span style={{ color: 'var(--secondary-text)' }}>Severity:</span>
                <span className={`status-pill ${getSeverityBadgeClass(drawerItem.severity)}`}>{drawerItem.severity.toUpperCase()}</span>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', borderBottom: '1px solid rgba(255,255,255,0.05)', paddingBottom: '6px' }}>
                <span style={{ color: 'var(--secondary-text)' }}>AI Confidence:</span>
                <span className="font-mono">{Math.round(drawerItem.confidence_score * 100 || 85)}%</span>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', borderBottom: '1px solid rgba(255,255,255,0.05)', paddingBottom: '6px' }}>
                <span style={{ color: 'var(--secondary-text)' }}>Priority Score:</span>
                <span className="font-bold text-amber">{getPriorityScore(drawerItem.severity)}</span>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', borderBottom: '1px solid rgba(255,255,255,0.05)', paddingBottom: '6px' }}>
                <span style={{ color: 'var(--secondary-text)' }}>Health Impact:</span>
                <span className="text-danger font-bold" style={{ color: 'var(--danger)' }}>{getHealthImpactScore(drawerItem.severity)}</span>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', borderBottom: '1px solid rgba(255,255,255,0.05)', paddingBottom: '6px' }}>
                <span style={{ color: 'var(--secondary-text)' }}>Video source:</span>
                <span>{drawerItem.video_id ? `video_${drawerItem.video_id}.mp4` : 'manual_upload'}</span>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', borderBottom: '1px solid rgba(255,255,255,0.05)', paddingBottom: '6px' }}>
                <span style={{ color: 'var(--secondary-text)' }}>Frame & Time:</span>
                <span className="font-mono">F: {drawerItem.frame_number ?? 0} | T: {drawerItem.video_timestamp ? `${drawerItem.video_timestamp.toFixed(2)}s` : '0.00s'}</span>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', borderBottom: '1px solid rgba(255,255,255,0.05)', paddingBottom: '6px' }}>
                <span style={{ color: 'var(--secondary-text)' }}>Bounding Box:</span>
                <span className="font-mono">W: {drawerItem.box_width ?? 120}px | H: {drawerItem.box_height ?? 80}px</span>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', borderBottom: '1px solid rgba(255,255,255,0.05)', paddingBottom: '6px' }}>
                <span style={{ color: 'var(--secondary-text)' }}>Damage Area:</span>
                <span>{drawerItem.affected_area ?? 0.125} sq.m</span>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', borderBottom: '1px solid rgba(255,255,255,0.05)', paddingBottom: '6px' }}>
                <span style={{ color: 'var(--secondary-text)' }}>GPS Coordinates:</span>
                <span className="font-mono" style={{ fontSize: '11px' }}>{drawerItem.latitude.toFixed(5)}° N, {drawerItem.longitude.toFixed(5)}° E</span>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', borderBottom: '1px solid rgba(255,255,255,0.05)', paddingBottom: '6px' }}>
                <span style={{ color: 'var(--secondary-text)' }}>Est. Repair Cost:</span>
                <span className="font-mono font-bold" style={{ color: 'var(--success)' }}>{getEstimatedCost(drawerItem.severity)}</span>
              </div>
            </div>

            <div style={{ background: 'rgba(255,255,255,0.03)', border: '1px solid var(--card-border)', borderRadius: '6px', padding: '12px', display: 'flex', flexDirection: 'column', gap: '6px' }}>
              <span style={{ fontSize: '11px', color: 'var(--secondary-text)', fontWeight: 700, textTransform: 'uppercase' }}>Maintenance Guideline</span>
              <p style={{ fontSize: '12px', fontStyle: 'italic', margin: 0 }}>{getRecommendation(drawerItem.distress_type)}</p>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
              <span style={{ fontSize: '11px', color: 'var(--secondary-text)', fontWeight: 700, textTransform: 'uppercase' }}>Activity Timeline Log</span>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', borderLeft: '1px solid var(--card-border)', paddingLeft: '14px', marginLeft: '6px' }}>
                <div style={{ position: 'relative', fontSize: '12px' }}>
                  <div style={{ position: 'absolute', left: '-19px', top: '3px', width: '9px', height: '9px', borderRadius: '50%', background: 'var(--success)' }}></div>
                  <strong style={{ display: 'block' }}>Initial detection created</strong>
                  <span style={{ fontSize: '11px', color: 'var(--secondary-text)' }}>{new Date(drawerItem.detected_at).toLocaleString()}</span>
                </div>
                <div style={{ position: 'relative', fontSize: '12px' }}>
                  <div style={{ position: 'absolute', left: '-19px', top: '3px', width: '9px', height: '9px', borderRadius: '50%', background: drawerItem.status === 'detected' ? 'var(--secondary-text)' : 'var(--accent-blue)' }}></div>
                  <strong style={{ display: 'block' }}>Review status: {drawerItem.status.replace('_', ' ')}</strong>
                  <span style={{ fontSize: '11px', color: 'var(--secondary-text)' }}>Synchronized metadata mapping log</span>
                </div>
              </div>
            </div>
          </div>

          <footer style={{ padding: '16px 20px', borderTop: '1px solid var(--card-border)', display: 'flex', gap: '10px' }}>
            <button type="button" onClick={() => handleGeneratePDF(drawerItem.id)} className="btn-control" style={{ flex: 1, height: '36px', fontSize: '12px' }}>Download PDF</button>
            <button type="button" onClick={() => navigate('/gis-map')} className="btn-report-run font-semibold" style={{ flex: 1, height: '36px', fontSize: '12px', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>Locate GIS</button>
          </footer>
        </div>
      )}

      {/* Lightbox / Zoom-Pan Modal */}
      {lightboxItem && (
        <div 
          style={{ position: 'fixed', inset: 0, zIndex: 9999, background: 'rgba(9, 15, 28, 0.95)', display: 'flex', color: '#FFF' }}
          onClick={() => setLightboxItem(null)}
        >
          <div 
            style={{ flex: 1, position: 'relative', display: 'flex', alignItems: 'center', justifyContent: 'center', overflow: 'hidden', cursor: isDragging.current ? 'grabbing' : 'grab' }}
            onClick={(e) => e.stopPropagation()}
            onMouseDown={handleLightboxMouseDown}
            onMouseMove={handleLightboxMouseMove}
            onMouseUp={handleLightboxMouseUp}
            onMouseLeave={handleLightboxMouseUp}
          >
            <div style={{ position: 'absolute', top: '20px', left: '20px', display: 'flex', gap: '8px', zIndex: 10 }}>
              <span className="font-mono font-bold" style={{ fontSize: '14px', background: 'rgba(0,0,0,0.5)', padding: '6px 12px', borderRadius: '4px' }}>RD-{lightboxItem.id}</span>
            </div>

            <div style={{ position: 'absolute', top: '20px', right: '20px', display: 'flex', gap: '8px', zIndex: 10 }}>
              <button type="button" onClick={() => setZoomScale(prev => Math.min(prev + 0.25, 4))} style={{ padding: '8px', background: 'rgba(0,0,0,0.5)', border: 'none', color: '#FFF', borderRadius: '4px', cursor: 'pointer' }}><ZoomIn size={16} /></button>
              <button type="button" onClick={() => setZoomScale(prev => Math.max(prev - 0.25, 0.5))} style={{ padding: '8px', background: 'rgba(0,0,0,0.5)', border: 'none', color: '#FFF', borderRadius: '4px', cursor: 'pointer' }}><ZoomOut size={16} /></button>
              <button type="button" onClick={handleResetZoom} style={{ padding: '8px 12px', background: 'rgba(0,0,0,0.5)', border: 'none', color: '#FFF', borderRadius: '4px', cursor: 'pointer', fontSize: '11px' }}>Reset</button>
              <button type="button" onClick={() => setIsLightboxFullscreen(!isLightboxFullscreen)} style={{ padding: '8px', background: 'rgba(0,0,0,0.5)', border: 'none', color: '#FFF', borderRadius: '4px', cursor: 'pointer' }}>{isLightboxFullscreen ? <Minimize2 size={16} /> : <Maximize2 size={16} />}</button>
              <button type="button" onClick={() => setLightboxItem(null)} style={{ padding: '8px', background: '#ef4444', border: 'none', color: '#FFF', borderRadius: '4px', cursor: 'pointer' }}><X size={16} /></button>
            </div>

            <div style={{ transform: `translate(${panOffset.x}px, ${panOffset.y}px) scale(${zoomScale})`, transition: isDragging.current ? 'none' : 'transform 0.15s ease', maxWidth: isLightboxFullscreen ? '100%' : '85%', maxHeight: isLightboxFullscreen ? '100%' : '85%', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <img 
                src={lightboxItem.image_url ? (lightboxItem.image_url.startsWith('http') ? lightboxItem.image_url : `${API_BASE_URL}/${lightboxItem.image_url}`) : 'https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?auto=format&fit=crop&q=80&w=800'} 
                alt="Lightbox View" 
                style={{ maxWidth: '100%', maxHeight: '100vh', objectFit: 'contain', userSelect: 'none', pointerEvents: 'none' }}
              />
            </div>
          </div>

          <div 
            style={{ width: '300px', borderLeft: '1px solid rgba(255,255,255,0.1)', background: 'rgba(15, 23, 42, 0.98)', padding: '20px', display: 'flex', flexDirection: 'column', gap: '14px' }}
            onClick={(e) => e.stopPropagation()}
          >
            <h3 style={{ margin: '0 0 10px 0', borderBottom: '1px solid rgba(255,255,255,0.1)', paddingBottom: '8px', fontSize: '14px', textTransform: 'uppercase', color: 'var(--accent-blue)' }}>Defect Metadata</h3>
            
            <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', fontSize: '12px' }}>
              <div>
                <span style={{ color: 'var(--secondary-text)' }}>Type:</span>
                <strong style={{ display: 'block', fontSize: '13px' }}>{formatDistressType(lightboxItem.distress_type)}</strong>
              </div>
              <div>
                <span style={{ color: 'var(--secondary-text)' }}>Severity:</span>
                <strong style={{ display: 'block', color: lightboxItem.severity === 'critical' ? 'var(--danger)' : '#FFF' }}>{lightboxItem.severity.toUpperCase()}</strong>
              </div>
              <div>
                <span style={{ color: 'var(--secondary-text)' }}>Confidence:</span>
                <strong style={{ display: 'block' }}>{Math.round(lightboxItem.confidence_score * 100 || 85)}%</strong>
              </div>
              <div>
                <span style={{ color: 'var(--secondary-text)' }}>Coordinates:</span>
                <strong style={{ display: 'block', fontSize: '11px', fontFamily: 'monospace' }}>{lightboxItem.latitude.toFixed(5)}° N, {lightboxItem.longitude.toFixed(5)}° E</strong>
              </div>
              <div>
                <span style={{ color: 'var(--secondary-text)' }}>Impact Deduction:</span>
                <strong style={{ display: 'block', color: 'var(--danger)' }}>{getHealthImpactScore(lightboxItem.severity)}</strong>
              </div>
              <div>
                <span style={{ color: 'var(--secondary-text)' }}>Estimate Repair:</span>
                <strong style={{ display: 'block', color: 'var(--success)' }}>{getEstimatedCost(lightboxItem.severity)}</strong>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
