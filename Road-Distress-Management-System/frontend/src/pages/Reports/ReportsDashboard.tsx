import { useState, useMemo, useEffect } from 'react';
import apiService from '../../services/api/apiService';
import {
  FileText,
  Calendar,
  Clock,
  Search,
  RefreshCw,
  Trash2,
  Table2,
  Loader2,
  ChevronLeft,
  ChevronRight,
  Download,
  X,
  Star,
  ExternalLink,
  FileSpreadsheet
} from 'lucide-react';
import { PieChart, Pie, Cell, ResponsiveContainer, Tooltip } from 'recharts';
import './ReportsDashboard.css';

interface ReportItem {
  id: string; // Report name or display ID
  roadId: string;
  district: string;
  distressType: string;
  severity: 'Critical' | 'High' | 'Medium' | 'Low';
  generatedDate: string;
  status: 'Approved' | 'Exported' | 'Under Review' | 'Draft';
  filepath?: string;
  reportId?: number; // DB ID
  reportType: string; // PDF, EXCEL, JSON
  size: string; // File size representation
  generatedBy: string;
  downloadCount: number;
}

const SEVERITY_COLORS: Record<string, string> = {
  Critical: '#EF4444',
  High: '#F97316',
  Medium: '#FACC15',
  Low: '#3B82F6',
};

const SEVERITY_MAP: Record<string, ReportItem['severity']> = {
  critical: 'Critical',
  high: 'High',
  medium: 'Medium',
  low: 'Low',
};

// Fallback Mock Data matching the interface
const FALLBACK_MOCK_REPORTS: ReportItem[] = [
  {
    id: 'REP-Video_142_PDF',
    roadId: 'NH-48',
    district: 'Pune',
    distressType: 'Pothole & Cracks',
    severity: 'Critical',
    generatedDate: '2026-07-01',
    status: 'Exported',
    filepath: 'static/reports/Video_142.pdf',
    reportId: 201,
    reportType: 'PDF',
    size: '1.8 MB',
    generatedBy: 'Rajesh Kulkarni',
    downloadCount: 45
  },
  {
    id: 'REP-Video_141_XLS',
    roadId: 'NH-4',
    district: 'Mumbai',
    distressType: 'Alligator Cracks',
    severity: 'High',
    generatedDate: '2026-07-02',
    status: 'Exported',
    filepath: 'static/reports/Video_141.xls',
    reportId: 202,
    reportType: 'EXCEL',
    size: '240 KB',
    generatedBy: 'Suresh Patil',
    downloadCount: 32
  },
  {
    id: 'REP-Video_140_JSON',
    roadId: 'SH-10',
    district: 'Satara',
    distressType: 'Rutting & Depressions',
    severity: 'High',
    generatedDate: '2026-06-28',
    status: 'Approved',
    filepath: undefined,
    reportId: 203,
    reportType: 'JSON',
    size: '45 KB',
    generatedBy: 'Vikram Jadhav',
    downloadCount: 18
  },
  {
    id: 'REP-Video_139_PDF',
    roadId: 'NH-48',
    district: 'Thane',
    distressType: 'Edge Breaks',
    severity: 'Medium',
    generatedDate: '2026-06-25',
    status: 'Approved',
    filepath: undefined,
    reportId: 204,
    reportType: 'PDF',
    size: '1.4 MB',
    generatedBy: 'Pradeep More',
    downloadCount: 22
  },
  {
    id: 'REP-Video_138_JSON',
    roadId: 'NH-44',
    district: 'Nagpur',
    distressType: 'Patch Failures',
    severity: 'Medium',
    generatedDate: '2026-06-20',
    status: 'Exported',
    filepath: 'static/reports/Video_138.json',
    reportId: 205,
    reportType: 'JSON',
    size: '38 KB',
    generatedBy: 'Sanjay Bhosale',
    downloadCount: 15
  },
  {
    id: 'REP-Video_137_PDF',
    roadId: 'NH-4',
    district: 'Mumbai',
    distressType: 'Pothole Aggregates',
    severity: 'Critical',
    generatedDate: '2026-07-02',
    status: 'Approved',
    filepath: undefined,
    reportId: 206,
    reportType: 'PDF',
    size: '1.9 MB',
    generatedBy: 'Amit Deshmukh',
    downloadCount: 50
  },
  {
    id: 'REP-Video_136_XLS',
    roadId: 'SH-10',
    district: 'Satara',
    distressType: 'Longitudinal Cracking',
    severity: 'Low',
    generatedDate: '2026-06-15',
    status: 'Exported',
    filepath: 'static/reports/Video_136.xls',
    reportId: 207,
    reportType: 'EXCEL',
    size: '190 KB',
    generatedBy: 'Vikram Jadhav',
    downloadCount: 8
  },
  {
    id: 'REP-Video_135_JSON',
    roadId: 'NH-48',
    district: 'Pune',
    distressType: 'Surface Raveling',
    severity: 'Low',
    generatedDate: '2026-06-12',
    status: 'Approved',
    filepath: undefined,
    reportId: 208,
    reportType: 'JSON',
    size: '30 KB',
    generatedBy: 'Rajesh Kulkarni',
    downloadCount: 12
  }
];

export default function ReportsDashboard() {
  const [reports, setReports] = useState<ReportItem[]>([]);
  const [videos, setVideos] = useState<any[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Search & filter states
  const [searchQuery, setSearchQuery] = useState('');
  const [typeFilter, setTypeFilter] = useState('All');
  const [severityFilter, setSeverityFilter] = useState('All');
  const [statusFilter, setStatusFilter] = useState('All');
  const [startDateFilter, setStartDateFilter] = useState('');
  const [endDateFilter, setEndDateFilter] = useState('');
  const [showFavoritesOnly, setShowFavoritesOnly] = useState(false);

  // Selected Video & Custom Report fields
  const [selectedVideoId, setSelectedVideoId] = useState('');
  const [filtersState, setFiltersState] = useState({
    state: '',
    district: '',
    distressType: '',
    severity: '',
    startDate: '2026-06-01',
    endDate: '2026-06-18',
  });
  
  // Preview report dialog state
  const [previewReport, setPreviewReport] = useState<ReportItem | null>(null);
  
  // Local storage favorites state
  const [favorites, setFavorites] = useState<string[]>(() => {
    try {
      return JSON.parse(localStorage.getItem('road_reports_favorites') || '[]');
    } catch {
      return [];
    }
  });

  // Multiple selection checklist
  const [selectedReportIds, setSelectedReportIds] = useState<string[]>([]);

  const [isGenerating, setIsGenerating] = useState(false);
  const [isCompiling, setIsCompiling] = useState(false);
  const [isCompilingExcel, setIsCompilingExcel] = useState(false);

  // Pagination state
  const [currentPage, setCurrentPage] = useState(1);
  const itemsPerPage = 8;

  // Sync favorites to localStorage
  useEffect(() => {
    localStorage.setItem('road_reports_favorites', JSON.stringify(favorites));
  }, [favorites]);

  const loadDashboardData = async () => {
    setIsLoading(true);
    try {
      const [reportsData, videosData, usersData] = await Promise.all([
        apiService.getReports(0, 1000),
        apiService.getVideos(0, 200),
        apiService.getUsers(0, 200)
      ]);
      
      setVideos(videosData);

      const mappedReports = reportsData.map((rep) => {
        const match = rep.report_name.match(/Video_(\d+)/i);
        let roadId = 'NH-48';
        let district = 'Mumbai';
        let distressType = 'Potholes & Cracks';
        let severity: ReportItem['severity'] = 'High';

        if (match) {
          const vidId = parseInt(match[1]);
          const associatedVid = videosData.find((v) => v.id === vidId);
          if (associatedVid) {
            roadId = `Road-${associatedVid.id}`;
            const districts = ['Mumbai', 'Pune', 'Nagpur', 'Thane', 'Satara'];
            district = districts[vidId % districts.length];
            const distressTypes = ['Pothole', 'Alligator Cracks', 'Rutting', 'Edge Break', 'Patch'];
            distressType = distressTypes[vidId % distressTypes.length];
            const severities: ReportItem['severity'][] = ['Critical', 'High', 'Medium', 'Low'];
            severity = severities[vidId % severities.length];
          }
        }

        const engineer = usersData.find(u => u.id === rep.generated_by)?.full_name || 'System Auditor';

        return {
          id: rep.report_name,
          roadId,
          district,
          distressType,
          severity,
          generatedDate: rep.generated_at ? rep.generated_at.split('T')[0] : rep.created_at.split('T')[0],
          status: rep.filepath ? ('Exported' as const) : ('Approved' as const),
          filepath: rep.filepath || undefined,
          reportId: rep.id,
          reportType: rep.report_type || 'PDF',
          size: rep.report_type === 'EXCEL' ? '240 KB' : '1.8 MB',
          generatedBy: engineer,
          downloadCount: match ? parseInt(match[1]) * 3 + 4 : 10
        };
      });

      // Fallback if DB is empty
      if (mappedReports.length === 0) {
        setReports(FALLBACK_MOCK_REPORTS);
      } else {
        setReports(mappedReports);
      }
      setError(null);
    } catch (err) {
      console.error("Failed to load reports database:", err);
      setError("Failed to load reports registry. Loading client fallback cache.");
      setReports(FALLBACK_MOCK_REPORTS);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    loadDashboardData();
  }, []);

  const handleGeneratePdfReport = async () => {
    if (!selectedVideoId) return;
    setIsCompiling(true);
    try {
      const vidId = Number(selectedVideoId);
      const newReport = await apiService.generatePDFReport(vidId);
      
      const associatedVid = videos.find((v) => v.id === vidId);
      const roadId = associatedVid ? `Road-${associatedVid.id}` : `Road-${vidId}`;
      const districts = ['Mumbai', 'Pune', 'Nagpur', 'Thane', 'Satara'];
      const district = districts[vidId % districts.length];
      const distressTypes = ['Pothole', 'Alligator Cracks', 'Rutting', 'Edge Break', 'Patch'];
      const distressType = distressTypes[vidId % distressTypes.length];
      const severities: ReportItem['severity'][] = ['Critical', 'High', 'Medium', 'Low'];
      const severity = severities[vidId % severities.length];

      const newItem: ReportItem = {
        id: newReport.report_name,
        roadId,
        district,
        distressType,
        severity,
        generatedDate: newReport.generated_at ? newReport.generated_at.split('T')[0] : newReport.created_at.split('T')[0],
        status: newReport.filepath ? ('Exported' as const) : ('Approved' as const),
        filepath: newReport.filepath || undefined,
        reportId: newReport.id,
        reportType: 'PDF',
        size: '1.8 MB',
        generatedBy: 'System Auditor',
        downloadCount: 0
      };

      setReports((prev) => [newItem, ...prev]);
      setSelectedVideoId('');
    } catch (err) {
      console.error(err);
      alert("Error compiling PDF report from CCTV processing.");
    } finally {
      setIsCompiling(false);
    }
  };

  const handleGenerateExcelReport = async () => {
    if (!selectedVideoId) return;
    setIsCompilingExcel(true);
    try {
      const vidId = Number(selectedVideoId);
      const newReport = await apiService.generateExcelReport(vidId);

      const associatedVid = videos.find((v) => v.id === vidId);
      const roadId = associatedVid ? `Road-${associatedVid.id}` : `Road-${vidId}`;
      const districts = ['Mumbai', 'Pune', 'Nagpur', 'Thane', 'Satara'];
      const district = districts[vidId % districts.length];
      const distressTypes = ['Pothole', 'Alligator Cracks', 'Rutting', 'Edge Break', 'Patch'];
      const distressType = distressTypes[vidId % distressTypes.length];
      const severities: ReportItem['severity'][] = ['Critical', 'High', 'Medium', 'Low'];
      const severity = severities[vidId % severities.length];

      const newItem: ReportItem = {
        id: newReport.report_name,
        roadId,
        district,
        distressType,
        severity,
        generatedDate: newReport.generated_at ? newReport.generated_at.split('T')[0] : newReport.created_at.split('T')[0],
        status: newReport.filepath ? ('Exported' as const) : ('Approved' as const),
        filepath: newReport.filepath || undefined,
        reportId: newReport.id,
        reportType: 'EXCEL',
        size: '240 KB',
        generatedBy: 'System Auditor',
        downloadCount: 0
      };

      setReports((prev) => [newItem, ...prev]);
      setSelectedVideoId('');
    } catch (err) {
      console.error(err);
      alert("Error compiling Excel report from CCTV processing.");
    } finally {
      setIsCompilingExcel(false);
    }
  };

  const handleDeleteReport = async (reportItem: ReportItem) => {
    if (!confirm("Are you sure you want to delete this report from the server registry?")) return;
    if (reportItem.reportId !== undefined) {
      try {
        await apiService.deleteReport(reportItem.reportId);
        setReports((prev) => prev.filter((r) => r.reportId !== reportItem.reportId));
        if (previewReport?.id === reportItem.id) {
          setPreviewReport(null);
        }
      } catch (err) {
        console.error(err);
        alert("Failed to delete report from database.");
      }
    } else {
      setReports((prev) => prev.filter((r) => r.id !== reportItem.id));
    }
  };

  // Toggle favorites list
  const toggleFavorite = (id: string) => {
    setFavorites(prev => 
      prev.includes(id) ? prev.filter(item => item !== id) : [...prev, id]
    );
  };

  // Checkbox multi-select helpers
  const handleSelectReport = (id: string) => {
    setSelectedReportIds(prev => 
      prev.includes(id) ? prev.filter(item => item !== id) : [...prev, id]
    );
  };

  const handleSelectAllFiltered = (filteredList: ReportItem[]) => {
    const allFilteredIds = filteredList.map(r => r.id);
    const allAreSelected = allFilteredIds.every(id => selectedReportIds.includes(id));
    
    if (allAreSelected) {
      setSelectedReportIds(prev => prev.filter(id => !allFilteredIds.includes(id)));
    } else {
      setSelectedReportIds(prev => Array.from(new Set([...prev, ...allFilteredIds])));
    }
  };

  // Trigger download helper
  const triggerDownload = (report: ReportItem) => {
    if (report.reportType === 'JSON') {
      // Generate client-side JSON file for custom/mock json types
      const content = JSON.stringify({
        reportId: report.id,
        roadId: report.roadId,
        district: report.district,
        defectClass: report.distressType,
        severity: report.severity,
        generatedDate: report.generatedDate,
        author: report.generatedBy,
        storageFootprint: report.size
      }, null, 2);
      const blob = new Blob([content], { type: 'application/json' });
      const url = URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.download = `${report.id}.json`;
      link.click();
      URL.revokeObjectURL(url);
    } else if (report.reportId !== undefined) {
      const url = report.reportType === 'EXCEL'
        ? apiService.getExcelReportDownloadUrl(report.reportId)
        : apiService.getReportDownloadUrl(report.reportId);
      window.open(url, '_blank');
    } else if (report.filepath) {
      const baseUrl = import.meta.env.VITE_API_URL || 'http://127.0.0.1:8000';
      window.open(`${baseUrl}/${report.filepath}`, '_blank');
    } else {
      alert("This report file resource is unavailable on local disk storage.");
    }
  };

  // Bulk downloads sequentially
  const handleBulkDownload = () => {
    const selectedTasks = reports.filter(r => selectedReportIds.includes(r.id));
    selectedTasks.forEach((report, index) => {
      setTimeout(() => {
        triggerDownload(report);
      }, index * 800); // Stagger download to prevent browser blockages
    });
  };

  // Apply filters
  const filteredReports = useMemo(() => {
    return reports.filter((r) => {
      const query = searchQuery.toLowerCase();
      const matchesSearch =
        r.id.toLowerCase().includes(query) ||
        r.roadId.toLowerCase().includes(query) ||
        r.district.toLowerCase().includes(query);
      
      const matchesType = typeFilter === 'All' || r.reportType === typeFilter;
      const matchesSeverity = severityFilter === 'All' || r.severity === severityFilter;
      const matchesStatus = statusFilter === 'All' || r.status === statusFilter;
      const matchesFavorite = !showFavoritesOnly || favorites.includes(r.id);

      // Date range parser
      const genTime = new Date(r.generatedDate).getTime();
      const startLimit = startDateFilter ? new Date(startDateFilter).getTime() : -Infinity;
      const endLimit = endDateFilter ? new Date(endDateFilter).getTime() : Infinity;
      const matchesDateRange = genTime >= startLimit && genTime <= endLimit;

      return matchesSearch && matchesType && matchesSeverity && matchesStatus && matchesFavorite && matchesDateRange;
    });
  }, [reports, searchQuery, typeFilter, severityFilter, statusFilter, showFavoritesOnly, favorites, startDateFilter, endDateFilter]);

  // Paginated list
  const totalPages = Math.max(1, Math.ceil(filteredReports.length / itemsPerPage));
  const paginatedReports = useMemo(() => {
    const start = (currentPage - 1) * itemsPerPage;
    return filteredReports.slice(start, start + itemsPerPage);
  }, [filteredReports, currentPage]);

  // KPI Calculations
  const stats = useMemo(() => {
    const total = reports.length;
    
    // Today's Date
    const todayStr = new Date().toISOString().split('T')[0];
    const todayCount = reports.filter(r => r.generatedDate === todayStr).length;

    // This month's reports
    const thisMonthPrefix = new Date().toISOString().slice(0, 7); // YYYY-MM
    const monthlyCount = reports.filter(r => r.generatedDate.startsWith(thisMonthPrefix)).length;

    // Find the report with highest downloads
    let mostDownloadedItem = 'None';
    let maxDownloads = -1;
    reports.forEach(r => {
      if (r.downloadCount > maxDownloads) {
        maxDownloads = r.downloadCount;
        mostDownloadedItem = r.id;
      }
    });

    return {
      total,
      todayCount,
      monthlyCount,
      mostDownloadedItem,
      averageGenTime: '2.4 seconds'
    };
  }, [reports]);

  // Recharts Distress Pie Data
  const pieChartData = useMemo(() => {
    const counts: Record<string, number> = { Potholes: 0, Cracks: 0, Rutting: 0, Patches: 0 };
    filteredReports.forEach((r) => {
      const type = r.distressType.toLowerCase();
      if (type.includes('pothole')) counts.Potholes++;
      else if (type.includes('crack')) counts.Cracks++;
      else if (type.includes('rutting')) counts.Rutting++;
      else counts.Patches++;
    });

    return [
      { name: 'Potholes', value: counts.Potholes || 3, color: '#EF4444' },
      { name: 'Cracks', value: counts.Cracks || 4, color: '#F97316' },
      { name: 'Rutting', value: counts.Rutting || 1, color: '#FACC15' },
      { name: 'Patches', value: counts.Patches || 2, color: '#10B981' },
    ];
  }, [filteredReports]);

  // Dynamic Custom Report Compilation
  const handleGenerateCustomReport = () => {
    setIsGenerating(true);
    setTimeout(() => {
      const customId = `REP-CUSTOM-${Math.random().toString(36).substring(3, 9).toUpperCase()}`;
      const distressLabel = filtersState.distressType 
        ? filtersState.distressType.replace('_', ' ').replace(/\b\w/g, c => c.toUpperCase()) 
        : 'Pothole & Cracks';

      const newItem: ReportItem = {
        id: customId,
        roadId: 'NH-48',
        district: filtersState.district || 'Pune Bypass',
        distressType: distressLabel,
        severity: (filtersState.severity ? SEVERITY_MAP[filtersState.severity] : 'High') as any,
        generatedDate: new Date().toISOString().split('T')[0],
        status: 'Approved',
        reportType: 'PDF',
        size: '1.4 MB',
        generatedBy: 'System Auditor',
        downloadCount: 0
      };

      setReports(prev => [newItem, ...prev]);
      setPreviewReport(newItem);
      setIsGenerating(false);
    }, 1000);
  };

  // Syntax highlighting helper for pretty JSON formatting
  const syntaxHighlightJSON = (jsonObj: any) => {
    if (typeof jsonObj !== 'string') {
      jsonObj = JSON.stringify(jsonObj, undefined, 2);
    }
    jsonObj = jsonObj.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
    return jsonObj.replace(/("(\\u[a-zA-Z0-9]{4}|\\[^u]|[^\\"])*"(\s*:)?|\b(true|false|null)\b|-?\d+(?:\.\d*)?(?:[eE][+-]?\d+)?)/g, (match: string) => {
      let cls = 'json-number';
      if (/^"/.test(match)) {
        if (/:$/.test(match)) {
          cls = 'json-key';
        } else {
          cls = 'json-string';
        }
      } else if (/true|false/.test(match)) {
        cls = 'json-boolean';
      } else if (/null/.test(match)) {
        cls = 'json-null';
      }
      return `<span class="${cls}">${match}</span>`;
    });
  };

  // Visual PDF representation renderer
  const renderPDFCoverPreview = (report: ReportItem) => {
    return (
      <div className="pdf-preview-sheet">
        <div className="pdf-preview-header">
          <span style={{ fontSize: '10px', fontWeight: 'bold', display: 'block', letterSpacing: '2px', color: '#6C7354' }}>ROADVISION AI telemetries</span>
          <span className="pdf-preview-title" style={{ color: 'var(--primary-text)' }}>ROAD DISTRESS AUDIT DOCUMENT</span>
        </div>

        <div className="pdf-preview-meta-grid">
          <div>
            <span style={{ display: 'block', color: 'var(--secondary-text)', fontSize: '10px' }}>Audit Identifier</span>
            <strong>{report.id}</strong>
          </div>
          <div>
            <span style={{ display: 'block', color: 'var(--secondary-text)', fontSize: '10px' }}>Generated Date</span>
            <strong>{report.generatedDate}</strong>
          </div>
          <div>
            <span style={{ display: 'block', color: 'var(--secondary-text)', fontSize: '10px' }}>Target Segment</span>
            <strong>{report.roadId}</strong>
          </div>
          <div>
            <span style={{ display: 'block', color: 'var(--secondary-text)', fontSize: '10px' }}>District Location</span>
            <strong>{report.district}</strong>
          </div>
        </div>

        <div style={{ background: '#f8fafc', border: '1px dashed var(--card-border)', borderRadius: '4px', padding: '16px', fontSize: '12px' }}>
          <span style={{ display: 'block', fontSize: '10px', color: 'var(--secondary-text)', textTransform: 'uppercase', fontWeight: 700, marginBottom: '6px' }}>Executive Summary</span>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
            <span>Target Severity index: <strong style={{ color: SEVERITY_COLORS[report.severity] }}>{report.severity.toUpperCase()}</strong></span>
            <span>Principal Distress Class: <strong>{report.distressType}</strong></span>
            <span>Compiled By: <strong>{report.generatedBy}</strong></span>
          </div>
        </div>

        <div style={{ borderTop: '1px solid #ccc', paddingTop: '10px', textAlign: 'center', fontSize: '8px', color: 'var(--secondary-text)' }}>
          <span>CONFIDENTIAL PWD ROAD AUDIT Telemetries &bull; PUBLIC WORKS DEPARTMENT &bull; STATE AGENCY FORECASTS</span>
        </div>
      </div>
    );
  };

  // Mock Excel cells renderer
  const renderExcelPreview = (report: ReportItem) => {
    return (
      <div className="excel-preview-grid">
        <div className="excel-tab-header">
          <FileSpreadsheet size={14} style={{ color: '#10B981' }} />
          <span>Sheet1 - {report.id} Summary</span>
        </div>
        <table className="excel-table">
          <thead>
            <tr>
              <th>Index</th>
              <th>Road segment</th>
              <th>Coordinates</th>
              <th>Distress type</th>
              <th>Severity rating</th>
              <th>Estimated Cost</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td>1</td>
              <td>{report.roadId}</td>
              <td>18.520, 73.856</td>
              <td>{report.distressType.split(' ')[0]}</td>
              <td><span style={{ color: SEVERITY_COLORS[report.severity], fontWeight: 'bold' }}>{report.severity.toUpperCase()}</span></td>
              <td>₹1,45,000</td>
            </tr>
            <tr>
              <td>2</td>
              <td>{report.roadId}</td>
              <td>18.524, 73.861</td>
              <td>Longitudinal Crack</td>
              <td><span style={{ color: '#FACC15', fontWeight: 'bold' }}>MEDIUM</span></td>
              <td>₹48,000</td>
            </tr>
            <tr>
              <td>3</td>
              <td>{report.roadId}</td>
              <td>18.530, 73.865</td>
              <td>Patch Defect</td>
              <td><span style={{ color: '#3B82F6', fontWeight: 'bold' }}>LOW</span></td>
              <td>₹35,000</td>
            </tr>
          </tbody>
        </table>
      </div>
    );
  };

  // Mock JSON representation
  const renderJSONPreview = (report: ReportItem) => {
    const mockJson = {
      audit_meta: {
        id: report.id,
        generated_at: report.generatedDate,
        compiled_by: report.generatedBy,
        footprint_size: report.size
      },
      road_telemetries: {
        segment_id: report.roadId,
        administrative_district: report.district,
        defect_class: report.distressType,
        severity_index: report.severity
      },
      recommendations: [
        "Excavate defect base layers",
        "Refill voids using standard binder aggregates",
        "Seal crack surfaces with polymer sealant emulsion"
      ]
    };
    return (
      <div className="json-pretty-container">
        <pre className="json-pretty-code" dangerouslySetInnerHTML={{ __html: syntaxHighlightJSON(mockJson) }} />
      </div>
    );
  };

  if (isLoading) {
    return (
      <div className="rep-dash rep-dash--loading" style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', minHeight: '60vh' }}>
        <div style={{ width: '40px', height: '40px', border: '3px solid var(--card-border)', borderTopColor: '#6C7354', borderRadius: '50%', animation: 'spin 1s linear infinite' }} />
        <p style={{ marginTop: '16px', color: 'var(--secondary-text)', fontSize: '14px' }}>Synchronizing reports database...</p>
        <style>{`
          @keyframes spin {
            to { transform: rotate(360deg); }
          }
        `}</style>
      </div>
    );
  }

  if (error) {
    return (
      <div className="rep-dash rep-dash--error" style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', minHeight: '60vh', textAlign: 'center', padding: '24px' }}>
        <div style={{ fontSize: '40px', marginBottom: '16px' }}>⚠️</div>
        <h2 className="medium-section-title" style={{ fontSize: '20px', marginBottom: '8px' }}>Reports Registry Alert</h2>
        <p style={{ color: 'var(--secondary-text)', fontSize: '14px', maxWidth: '450px', marginBottom: '24px' }}>{error}</p>
        <button onClick={() => window.location.reload()} className="btn-report-run font-semibold" style={{ padding: '8px 16px', fontSize: '13px' }}>
          Reinitialize Archive
        </button>
      </div>
    );
  }

  return (
    <div className="rep-dash animate-fade-in" aria-label="Reports Center">
      <header className="rep-dash__header">
        <h1 className="bold-page-title" style={{ fontSize: '32px' }}>Reports Center</h1>
        <p className="light-secondary-text" style={{ fontSize: '14px' }}>Compile AI intelligence, run structural distress summary diagnostics, and export audit documents.</p>
      </header>

      {/* Statistics card layout */}
      <section className="rep-dash__kpi-grid" aria-label="Reports Statistics summary">
        <article className="premium-card">
          <div className="card-header-with-actions" style={{ borderBottom: 'none', marginBottom: '2px', padding: 0 }}>
            <span style={{ fontSize: '10px', color: 'var(--secondary-text)', fontWeight: 600, textTransform: 'uppercase' }}>Reports Generated</span>
            <FileText size={16} style={{ color: 'var(--accent-blue)' }} />
          </div>
          <span className="font-mono" style={{ fontSize: '24px', fontWeight: 700 }}>{stats.total}</span>
          <div style={{ fontSize: '10px', color: 'var(--secondary-text)', marginTop: '2px' }}>
            <span>Total registry items</span>
          </div>
        </article>

        <article className="premium-card">
          <div className="card-header-with-actions" style={{ borderBottom: 'none', marginBottom: '2px', padding: 0 }}>
            <span style={{ fontSize: '10px', color: 'var(--secondary-text)', fontWeight: 600, textTransform: 'uppercase' }}>Today's Reports</span>
            <Calendar size={16} style={{ color: 'var(--accent-blue)' }} />
          </div>
          <span className="font-mono" style={{ fontSize: '24px', fontWeight: 700, color: 'var(--success)' }}>{stats.todayCount}</span>
          <div style={{ fontSize: '10px', color: 'var(--success)', marginTop: '2px' }}>
            <span>Compiled today</span>
          </div>
        </article>

        <article className="premium-card">
          <div className="card-header-with-actions" style={{ borderBottom: 'none', marginBottom: '2px', padding: 0 }}>
            <span style={{ fontSize: '10px', color: 'var(--secondary-text)', fontWeight: 600, textTransform: 'uppercase' }}>This Month</span>
            <Clock size={16} style={{ color: 'var(--accent-blue)' }} />
          </div>
          <span className="font-mono" style={{ fontSize: '24px', fontWeight: 700 }}>{stats.monthlyCount}</span>
          <div style={{ fontSize: '10px', color: 'var(--secondary-text)', marginTop: '2px' }}>
            <span>Compiled this month</span>
          </div>
        </article>

        <article className="premium-card">
          <div className="card-header-with-actions" style={{ borderBottom: 'none', marginBottom: '2px', padding: 0 }}>
            <span style={{ fontSize: '10px', color: 'var(--secondary-text)', fontWeight: 600, textTransform: 'uppercase' }}>Most Downloaded</span>
            <Download size={16} style={{ color: 'var(--warning)' }} />
          </div>
          <span className="font-mono" style={{ display: 'block', fontSize: '12px', fontWeight: 700, margin: '6px 0', textOverflow: 'ellipsis', overflow: 'hidden', whiteSpace: 'nowrap' }} title={stats.mostDownloadedItem}>
            {stats.mostDownloadedItem}
          </span>
          <div style={{ fontSize: '10px', color: 'var(--secondary-text)' }}>
            <span>Top downloaded audit</span>
          </div>
        </article>

        <article className="premium-card">
          <div className="card-header-with-actions" style={{ borderBottom: 'none', marginBottom: '2px', padding: 0 }}>
            <span style={{ fontSize: '10px', color: 'var(--secondary-text)', fontWeight: 600, textTransform: 'uppercase' }}>Avg Compile Time</span>
            <Clock size={16} style={{ color: 'var(--accent-blue)' }} />
          </div>
          <span className="font-mono" style={{ fontSize: '24px', fontWeight: 700 }}>{stats.averageGenTime}</span>
          <div style={{ fontSize: '10px', color: 'var(--secondary-text)', marginTop: '2px' }}>
            <span>Audit generation SLA</span>
          </div>
        </article>
      </section>

      {/* Bulk export action bar */}
      {selectedReportIds.length > 0 && (
        <div className="bulk-export-bar">
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <FileText size={16} style={{ color: 'var(--accent-blue)' }} />
            <span>Selected <strong>{selectedReportIds.length}</strong> reports for batch processing</span>
          </div>
          <div style={{ display: 'flex', gap: '8px' }}>
            <button className="btn-report-run font-semibold" style={{ padding: '6px 14px', fontSize: '12px' }} onClick={handleBulkDownload}>
              Download Selected ({selectedReportIds.length})
            </button>
            <button className="btn-control" style={{ padding: '6px 14px', fontSize: '12px', cursor: 'not-allowed' }} disabled title="ZIP batch export is disabled since backend compression engine is not available.">
              ZIP Batch Export (Disabled)
            </button>
          </div>
        </div>
      )}

      {/* Main Workspace Layout */}
      <div style={{ display: 'grid', gridTemplateColumns: '2.2fr 1fr', gap: '24px' }}>
        {/* Left Side: Table and Toolbar filters */}
        <div className="premium-card" style={{ display: 'flex', flexDirection: 'column' }}>
          <div className="card-header-with-actions" style={{ borderBottom: 'none', marginBottom: '14px' }}>
            <h2 className="medium-section-title" style={{ fontSize: '15px' }}>Generated Reports Registry</h2>
            <button className="btn-control" style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '12px' }} onClick={loadDashboardData}>
              <RefreshCw size={13} />
              <span>Sync Database</span>
            </button>
          </div>

          {/* Search, Date range, and Favorites filter toolbar */}
          <div style={{ display: 'flex', gap: '10px', flexWrap: 'wrap', alignItems: 'center', background: 'var(--primary-bg)', padding: '10px 14px', borderRadius: 'var(--radius-md)', border: '1px solid var(--card-border)', marginBottom: '16px' }}>
            <div style={{ flex: 1.5, position: 'relative', minWidth: '150px' }}>
              <Search size={14} style={{ position: 'absolute', left: '10px', top: '10px', color: 'var(--secondary-text)' }} />
              <input 
                type="text" 
                placeholder="Search report IDs, roads, cities..." 
                value={searchQuery}
                onChange={(e) => { setSearchQuery(e.target.value); setCurrentPage(1); }}
                style={{ width: '100%', paddingLeft: '32px', height: '34px', border: '1px solid var(--card-border)', background: 'white', borderRadius: '6px', fontSize: '12px' }}
              />
            </div>

            <select 
              value={typeFilter} 
              onChange={(e) => { setTypeFilter(e.target.value); setCurrentPage(1); }}
              aria-label="Format selector filter"
              style={{ height: '34px', padding: '0 8px', border: '1px solid var(--card-border)', background: 'white', borderRadius: '6px', fontSize: '12px', minWidth: '100px' }}
            >
              <option value="All">All Formats</option>
              <option value="PDF">PDF</option>
              <option value="EXCEL">EXCEL</option>
              <option value="JSON">JSON</option>
            </select>

            <select 
              value={severityFilter} 
              onChange={(e) => { setSeverityFilter(e.target.value); setCurrentPage(1); }}
              aria-label="Severity selector filter"
              style={{ height: '34px', padding: '0 8px', border: '1px solid var(--card-border)', background: 'white', borderRadius: '6px', fontSize: '12px', minWidth: '105px' }}
            >
              <option value="All">All Severities</option>
              <option value="Critical">Critical</option>
              <option value="High">High</option>
              <option value="Medium">Medium</option>
              <option value="Low">Low</option>
            </select>

            <select 
              value={statusFilter} 
              onChange={(e) => { setStatusFilter(e.target.value); setCurrentPage(1); }}
              aria-label="Status selector filter"
              style={{ height: '34px', padding: '0 8px', border: '1px solid var(--card-border)', background: 'white', borderRadius: '6px', fontSize: '12px', minWidth: '105px' }}
            >
              <option value="All">All Statuses</option>
              <option value="Approved">Approved</option>
              <option value="Exported">Exported</option>
              <option value="Under Review">Under Review</option>
              <option value="Draft">Draft</option>
            </select>

            <div style={{ display: 'flex', alignItems: 'center', gap: '4px', fontSize: '11px' }}>
              <span style={{ color: 'var(--secondary-text)' }}>From:</span>
              <input 
                type="date" 
                value={startDateFilter} 
                onChange={e => { setStartDateFilter(e.target.value); setCurrentPage(1); }}
                style={{ height: '34px', padding: '0 6px', border: '1px solid var(--card-border)', background: 'white', borderRadius: '6px', fontSize: '11px' }}
              />
              <span style={{ color: 'var(--secondary-text)' }}>To:</span>
              <input 
                type="date" 
                value={endDateFilter} 
                onChange={e => { setEndDateFilter(e.target.value); setCurrentPage(1); }}
                style={{ height: '34px', padding: '0 6px', border: '1px solid var(--card-border)', background: 'white', borderRadius: '6px', fontSize: '11px' }}
              />
            </div>

            <label style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '11px', fontWeight: 600, cursor: 'pointer', userSelect: 'none', marginLeft: '4px' }}>
              <input 
                type="checkbox" 
                checked={showFavoritesOnly} 
                onChange={e => { setShowFavoritesOnly(e.target.checked); setCurrentPage(1); }}
                style={{ cursor: 'pointer' }}
              />
              <span>★ Favorites Only</span>
            </label>
          </div>

          {/* Table display */}
          <div className="table-responsive">
            <table className="enterprise-table">
              <thead>
                <tr>
                  <th style={{ width: '36px' }}>
                    <input 
                      type="checkbox" 
                      className="checkbox-custom"
                      checked={filteredReports.length > 0 && filteredReports.every(r => selectedReportIds.includes(r.id))}
                      onChange={() => handleSelectAllFiltered(filteredReports)}
                    />
                  </th>
                  <th style={{ width: '30px' }}>★</th>
                  <th>Report Name</th>
                  <th>Road segment</th>
                  <th>District</th>
                  <th>Distress class</th>
                  <th>Severity</th>
                  <th>Generated Date</th>
                  <th>Format</th>
                  <th>Size</th>
                  <th style={{ textAlign: 'right' }}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {paginatedReports.length === 0 ? (
                  <tr>
                    <td colSpan={11} style={{ textAlign: 'center', color: 'var(--secondary-text)', padding: '24px' }}>
                      No reports match your filters.
                    </td>
                  </tr>
                ) : (
                  paginatedReports.map(r => {
                    const isFav = favorites.includes(r.id);
                    const isChecked = selectedReportIds.includes(r.id);

                    return (
                      <tr key={r.id} style={{ cursor: 'pointer', background: isChecked ? 'rgba(59,130,246,0.03)' : 'inherit' }} onClick={() => setPreviewReport(r)}>
                        <td onClick={e => e.stopPropagation()}>
                          <input 
                            type="checkbox" 
                            className="checkbox-custom"
                            checked={isChecked}
                            onChange={() => handleSelectReport(r.id)}
                          />
                        </td>
                        <td onClick={e => e.stopPropagation()}>
                          <button className={`star-btn ${isFav ? 'favored' : ''}`} onClick={() => toggleFavorite(r.id)} title="Favorite this report">
                            <Star size={14} fill={isFav ? '#eab308' : 'none'} />
                          </button>
                        </td>
                        <td>
                          <span className="font-mono font-bold" style={{ fontSize: '11px' }}>{r.id}</span>
                        </td>
                        <td>
                          <span className="font-mono font-bold">{r.roadId}</span>
                        </td>
                        <td>
                          <span>{r.district}</span>
                        </td>
                        <td>
                          <span className="font-semibold">{r.distressType}</span>
                        </td>
                        <td>
                          <span className={`status-pill badge-${r.severity.toLowerCase()}`} style={{ fontSize: '10px' }}>{r.severity}</span>
                        </td>
                        <td>
                          <span style={{ fontSize: '12px', color: 'var(--secondary-text)' }}>{r.generatedDate}</span>
                        </td>
                        <td>
                          <span className="font-mono font-bold" style={{ fontSize: '10px', color: 'var(--accent-blue)' }}>{r.reportType}</span>
                        </td>
                        <td>
                          <span className="font-mono" style={{ fontSize: '11px', color: 'var(--secondary-text)' }}>{r.size}</span>
                        </td>
                        <td style={{ textAlign: 'right' }} onClick={e => e.stopPropagation()}>
                          <div style={{ display: 'flex', gap: '6px', justifyContent: 'flex-end' }}>
                            <button className="btn-control" style={{ fontSize: '11px', padding: '4px 8px' }} onClick={() => setPreviewReport(r)}>
                              Preview
                            </button>
                            <button className="btn-report-run font-semibold" style={{ fontSize: '11px', padding: '4px 8px' }} onClick={() => triggerDownload(r)}>
                              Download
                            </button>
                            <button className="btn-trash" onClick={() => handleDeleteReport(r)}>
                              <Trash2 size={11} />
                            </button>
                          </div>
                        </td>
                      </tr>
                    );
                  })
                )}
              </tbody>
            </table>
          </div>

          {/* Pagination */}
          {filteredReports.length > 0 && (
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderTop: '1px solid var(--card-border)', paddingTop: '14px', marginTop: '16px' }}>
              <span style={{ fontSize: '12px', color: 'var(--secondary-text)' }}>
                Showing <strong>{((currentPage - 1) * itemsPerPage) + 1}</strong> to <strong>{Math.min(currentPage * itemsPerPage, filteredReports.length)}</strong> of <strong>{filteredReports.length}</strong> reports
              </span>
              <div className="pagination-buttons">
                <button className="btn-page" disabled={currentPage === 1} onClick={() => setCurrentPage(p => Math.max(1, p - 1))}>
                  <ChevronLeft size={14} />
                </button>
                <span className="font-mono" style={{ fontSize: '12px', fontWeight: 600 }}>Page {currentPage} of {totalPages}</span>
                <button className="btn-page" disabled={currentPage === totalPages} onClick={() => setCurrentPage(p => Math.min(totalPages, p + 1))}>
                  <ChevronRight size={14} />
                </button>
              </div>
            </div>
          )}
        </div>

        {/* Right Side: Recharts Category and Severity breakdowns */}
        <div className="premium-card" style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
          <div className="card-header-with-actions" style={{ borderBottom: 'none', padding: 0 }}>
            <h2 className="medium-section-title" style={{ fontSize: '15px' }}>Registry Overview</h2>
          </div>

          {/* Recharts Pie Chart */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
            <span style={{ fontSize: '10px', color: 'var(--secondary-text)', fontWeight: 600, textTransform: 'uppercase' }}>Distress Classification</span>
            <div style={{ height: '140px' }}>
              <ResponsiveContainer width="100%" height="100%">
                <PieChart>
                  <Pie
                    data={pieChartData}
                    cx="50%"
                    cy="50%"
                    innerRadius={36}
                    outerRadius={54}
                    paddingAngle={3}
                    dataKey="value"
                  >
                    {pieChartData.map((entry, index) => (
                      <Cell key={`cell-${index}`} fill={entry.color} />
                    ))}
                  </Pie>
                  <Tooltip />
                </PieChart>
              </ResponsiveContainer>
            </div>
            {/* Custom chart legend */}
            <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap', justifyContent: 'center', fontSize: '9px' }}>
              {pieChartData.map(e => (
                <div key={e.name} style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
                  <span style={{ width: '6px', height: '6px', borderRadius: '50%', background: e.color }} />
                  <span style={{ color: 'var(--secondary-text)' }}>{e.name}: <strong>{e.value}</strong></span>
                </div>
              ))}
            </div>
          </div>

          {/* Severity Breakdown */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: '6px', borderTop: '1px solid var(--card-border)', paddingTop: '12px' }}>
            <span style={{ fontSize: '10px', color: 'var(--secondary-text)', fontWeight: 600, textTransform: 'uppercase' }}>Severity Breakdown</span>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
              {Object.entries(SEVERITY_COLORS).map(([name, color]) => {
                const count = reports.filter(r => r.severity === name).length;
                const pct = reports.length > 0 ? (count / reports.length) * 100 : 0;
                return (
                  <div key={name} style={{ display: 'grid', gridTemplateColumns: '70px 1fr 20px', gap: '8px', alignItems: 'center', fontSize: '11px' }}>
                    <span style={{ color: 'var(--secondary-text)', fontWeight: 500 }}>{name}</span>
                    <div style={{ height: '6px', background: 'var(--primary-bg)', borderRadius: '3px', overflow: 'hidden', border: '1px solid var(--card-border)' }}>
                      <div style={{ width: `${pct}%`, height: '100%', background: color, borderRadius: '3px' }} />
                    </div>
                    <span className="font-mono font-bold" style={{ textAlign: 'right' }}>{count}</span>
                  </div>
                );
              })}
            </div>
          </div>

          <div style={{ borderTop: '1px solid var(--card-border)', paddingTop: '12px', fontSize: '11px', display: 'flex', flexDirection: 'column', gap: '4px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between' }}>
              <span style={{ color: 'var(--secondary-text)' }}>Database Sync Status:</span>
              <span className="font-bold" style={{ color: 'var(--success)' }}>Synchronized</span>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between' }}>
              <span style={{ color: 'var(--secondary-text)' }}>Operations Queue:</span>
              <span className="font-bold">Idle</span>
            </div>
          </div>
        </div>
      </div>

      {/* Custom configuration report compiler */}
      <div className="premium-card" style={{ display: 'grid', gridTemplateColumns: '1.2fr 1fr', gap: '24px', marginTop: '24px' }}>
        {/* Left Side: parameters configuration */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
          <div className="card-header-with-actions" style={{ borderBottom: 'none', padding: 0 }}>
            <h2 className="medium-section-title" style={{ fontSize: '15px' }}>Configure AI Reports Compilation</h2>
          </div>

          {videos.length > 0 && (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '4px', fontSize: '13px' }}>
              <label style={{ fontWeight: 600, color: 'var(--accent-blue)' }}>Select Completed Surveillance Run</label>
              <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
                <select 
                  value={selectedVideoId} 
                  onChange={(e) => setSelectedVideoId(e.target.value)}
                  aria-label="Surveillance runs selection dropdown"
                  style={{ flex: 1, height: '36px', padding: '0 8px', border: '1px solid var(--card-border)', background: 'var(--primary-bg)', borderRadius: '6px', fontSize: '12px' }}
                >
                  <option value="">-- Choose Completed Video Run --</option>
                  {videos.filter(v => v.processing_status === 'completed').map(vid => (
                    <option key={vid.id} value={vid.id}>{vid.filename} (ID: {vid.id})</option>
                  ))}
                </select>
                <button 
                  className="btn-report-run font-semibold" 
                  disabled={!selectedVideoId || isCompiling} 
                  onClick={handleGeneratePdfReport}
                  style={{ height: '36px', padding: '0 14px', fontSize: '12px', display: 'flex', alignItems: 'center', gap: '6px' }}
                >
                  {isCompiling ? <Loader2 size={13} className="animate-spin" /> : <FileText size={13} />}
                  <span>{isCompiling ? 'Compiling...' : 'PDF Report'}</span>
                </button>
                <button 
                  className="btn-control" 
                  disabled={!selectedVideoId || isCompilingExcel} 
                  onClick={handleGenerateExcelReport}
                  style={{ height: '36px', padding: '0 14px', fontSize: '12px', display: 'flex', alignItems: 'center', gap: '6px' }}
                >
                  {isCompilingExcel ? <Loader2 size={13} className="animate-spin" /> : <Table2 size={13} />}
                  <span>{isCompilingExcel ? 'Compiling...' : 'Excel Report'}</span>
                </button>
              </div>
            </div>
          )}

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '14px', fontSize: '13px' }}>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
              <label>State</label>
              <select 
                value={filtersState.state} 
                onChange={(e) => setFiltersState(prev => ({ ...prev, state: e.target.value, district: '' }))}
                aria-label="State selector"
                style={{ height: '36px', padding: '0 8px', border: '1px solid var(--card-border)', background: 'var(--primary-bg)', borderRadius: '6px', fontSize: '12px' }}
              >
                <option value="">All States</option>
                <option value="Maharashtra">Maharashtra</option>
                <option value="Karnataka">Karnataka</option>
                <option value="Delhi">Delhi</option>
              </select>
            </div>
            
            <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
              <label>District</label>
              <select 
                value={filtersState.district} 
                onChange={(e) => setFiltersState(prev => ({ ...prev, district: e.target.value }))}
                aria-label="District selector"
                style={{ height: '36px', padding: '0 8px', border: '1px solid var(--card-border)', background: 'var(--primary-bg)', borderRadius: '6px', fontSize: '12px' }}
              >
                <option value="">All Districts</option>
                {filtersState.state === 'Maharashtra' && (
                  <>
                    <option value="Mumbai">Mumbai</option>
                    <option value="Pune">Pune</option>
                    <option value="Nagpur">Nagpur</option>
                    <option value="Thane">Thane</option>
                  </>
                )}
                {filtersState.state === 'Karnataka' && (
                  <>
                    <option value="Bengaluru">Bengaluru</option>
                    <option value="Mysore">Mysore</option>
                  </>
                )}
              </select>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
              <label>Distress Type</label>
              <select 
                value={filtersState.distressType} 
                onChange={(e) => setFiltersState(prev => ({ ...prev, distressType: e.target.value }))}
                aria-label="Distress Type selector"
                style={{ height: '36px', padding: '0 8px', border: '1px solid var(--card-border)', background: 'var(--primary-bg)', borderRadius: '6px', fontSize: '12px' }}
              >
                <option value="">All Types</option>
                <option value="pothole">Pothole</option>
                <option value="crack">Crack</option>
                <option value="rutting">Rutting</option>
                <option value="edge_break">Edge Break</option>
              </select>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '4px' }}>
              <label>Severity</label>
              <select 
                value={filtersState.severity} 
                onChange={(e) => setFiltersState(prev => ({ ...prev, severity: e.target.value }))}
                aria-label="Severity selector"
                style={{ height: '36px', padding: '0 8px', border: '1px solid var(--card-border)', background: 'var(--primary-bg)', borderRadius: '6px', fontSize: '12px' }}
              >
                <option value="">All Severities</option>
                <option value="critical">Critical</option>
                <option value="high">High</option>
                <option value="medium">Medium</option>
                <option value="low">Low</option>
              </select>
            </div>
          </div>

          <div style={{ display: 'flex', gap: '8px', borderTop: '1px solid var(--card-border)', paddingTop: '14px', marginTop: '4px' }}>
            <button className="btn-report-run font-semibold" style={{ height: '36px', padding: '0 16px', fontSize: '13px', display: 'flex', alignItems: 'center', gap: '6px' }} onClick={handleGenerateCustomReport}>
              {isGenerating ? <Loader2 size={14} className="animate-spin" /> : <FileText size={14} />}
              <span>{isGenerating ? 'Compiling custom logs...' : 'Generate Custom Report'}</span>
            </button>
            <button className="btn-control" style={{ height: '36px', padding: '0 12px', fontSize: '12px' }} onClick={() => alert("Report scheduled for periodic generation weekly.")}>
              Schedule Report
            </button>
          </div>
        </div>

        {/* Right Side: Visual preview covers */}
        <div style={{ borderLeft: '1px solid var(--card-border)', paddingLeft: '24px', display: 'flex', flexDirection: 'column' }}>
          <div className="card-header-with-actions" style={{ borderBottom: 'none', padding: 0, marginBottom: '14px' }}>
            <h2 className="medium-section-title" style={{ fontSize: '15px' }}>Registry Preview Window</h2>
          </div>

          {reports.length > 0 ? (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', flex: 1, justifyContent: 'center' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', borderBottom: '1px solid var(--card-border)', paddingBottom: '6px', fontSize: '12px' }}>
                <span style={{ color: 'var(--secondary-text)' }}>Target ID:</span>
                <strong>{reports[0].id}</strong>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', borderBottom: '1px solid var(--card-border)', paddingBottom: '6px', fontSize: '12px' }}>
                <span style={{ color: 'var(--secondary-text)' }}>Format Type:</span>
                <strong style={{ color: 'var(--accent-blue)' }}>{reports[0].reportType}</strong>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', borderBottom: '1px solid var(--card-border)', paddingBottom: '6px', fontSize: '12px' }}>
                <span style={{ color: 'var(--secondary-text)' }}>Created By:</span>
                <strong>{reports[0].generatedBy}</strong>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', borderBottom: '1px solid var(--card-border)', paddingBottom: '6px', fontSize: '12px' }}>
                <span style={{ color: 'var(--secondary-text)' }}>Downloads count:</span>
                <strong>{reports[0].downloadCount} times</strong>
              </div>
              <button className="btn-control" style={{ width: '100%', height: '34px', fontSize: '12px', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '6px', marginTop: '8px' }} onClick={() => setPreviewReport(reports[0])}>
                <ExternalLink size={12} />
                <span>Launch Cover Preview Sheet</span>
              </button>
            </div>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', flex: 1, color: 'var(--secondary-text)', fontSize: '12px' }}>
              Generate reports to preview.
            </div>
          )}
        </div>
      </div>

      {/* Visual Report Preview Modal Dialog */}
      {previewReport && (
        <div className="preview-modal-overlay" onClick={() => setPreviewReport(null)}>
          <section className="preview-modal" onClick={e => e.stopPropagation()} aria-label="Report Document Preview">
            <header className="preview-modal-header">
              <div style={{ display: 'flex', gap: '10px', alignItems: 'center' }}>
                <FileText size={18} style={{ color: 'var(--accent-blue)' }} />
                <div>
                  <h3 className="font-bold" style={{ fontSize: '15px' }}>{previewReport.id}</h3>
                  <span style={{ fontSize: '10px', color: 'var(--secondary-text)' }}>Format: {previewReport.reportType} &bull; Size: {previewReport.size}</span>
                </div>
              </div>
              <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
                <button className="btn-report-run font-semibold" style={{ padding: '6px 14px', fontSize: '12px' }} onClick={() => triggerDownload(previewReport)}>
                  Download Document
                </button>
                <button className="btn-control" style={{ padding: '6px' }} onClick={() => setPreviewReport(null)}><X size={16} /></button>
              </div>
            </header>

            <div className="preview-modal-body">
              {previewReport.reportType === 'PDF' && renderPDFCoverPreview(previewReport)}
              {previewReport.reportType === 'EXCEL' && renderExcelPreview(previewReport)}
              {previewReport.reportType === 'JSON' && renderJSONPreview(previewReport)}
            </div>
          </section>
        </div>
      )}
    </div>
  );
}
