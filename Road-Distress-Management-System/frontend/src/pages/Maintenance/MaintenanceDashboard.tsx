import { useState, useEffect, useMemo } from 'react';
import {
  ClipboardList,
  Wrench,
  CheckCircle2,
  IndianRupee,
  Clock,
  Search,
  Download,
  ChevronLeft,
  ChevronRight,
  AlertTriangle,
  X,
  MapPin,
  ExternalLink,
  Calendar,
  ArrowRight
} from 'lucide-react';
import { ResponsiveContainer, Tooltip, PieChart, Pie, Cell } from 'recharts';
import apiService from '../../services/api/apiService';
import type { MaintenanceTaskResponse, RoadDistressResponse, UserResponse } from '../../services/api/apiService';
import './MaintenanceDashboard.css';

// Combined task model interface
interface CombinedTask {
  id: string; // TASK-{id}
  taskId: number;
  distressId: number;
  trackingId: string;
  distressType: string;
  priority: string;
  severity: string;
  estimatedCost: number;
  roadHealthImpact: string;
  assignedEngineer: string;
  dueDate: string;
  detectionImage: string | null;
  annotatedImage: string | null;
  damageArea: string;
  gps: string;
  recommendation: string;
  status: string; // Pending, Assigned, In Progress, Completed, Closed
  rawTask?: MaintenanceTaskResponse;
  rawDistress?: RoadDistressResponse;
}

const STATUS_COLORS: Record<string, string> = {
  Pending: '#6B88C7',
  Assigned: '#3b82f6',
  'In Progress': '#D6A23A',
  Completed: '#8FA06A',
  Closed: '#94a3b8',
};

const PRIORITY_COLORS: Record<string, string> = {
  Critical: '#C45C45',
  High: '#C87B35',
  Medium: '#D6A23A',
  Low: '#6B88C7',
};

function formatCost(amount: number): string {
  if (amount >= 10000000) {
    return `₹${(amount / 10000000).toFixed(1)}Cr`;
  }
  if (amount >= 100000) {
    return `₹${(amount / 100000).toFixed(1)}L`;
  }
  return `₹${amount.toLocaleString('en-IN')}`;
}

// Fallback Mock Data matching the interface
const FALLBACK_MOCK_TASKS: CombinedTask[] = [
  {
    id: 'TASK-1',
    taskId: 1,
    distressId: 101,
    trackingId: 'RD-TRK-142',
    distressType: 'Pothole',
    priority: 'Critical',
    severity: 'Critical',
    estimatedCost: 185000,
    roadHealthImpact: 'Penalty: -5.0 pts',
    assignedEngineer: 'Rajesh Kulkarni',
    dueDate: '2026-07-10',
    detectionImage: null,
    annotatedImage: null,
    damageArea: '1.25 sq m',
    gps: '18.520430, 73.856743',
    recommendation: 'Excavate distress zone, compact sub-base, lay 50mm hot asphalt mix.',
    status: 'In Progress'
  },
  {
    id: 'TASK-2',
    taskId: 2,
    distressId: 102,
    trackingId: 'RD-TRK-141',
    distressType: 'Alligator Cracks',
    priority: 'High',
    severity: 'High',
    estimatedCost: 320000,
    roadHealthImpact: 'Penalty: -3.0 pts',
    assignedEngineer: 'Suresh Patil',
    dueDate: '2026-07-12',
    detectionImage: null,
    annotatedImage: null,
    damageArea: '4.80 sq m',
    gps: '19.076090, 72.877793',
    recommendation: 'Apply localized crack sealant, perform micro-surfacing overlay.',
    status: 'Assigned'
  },
  {
    id: 'TASK-3',
    taskId: 3,
    distressId: 103,
    trackingId: 'RD-TRK-140',
    distressType: 'Rutting',
    priority: 'High',
    severity: 'High',
    estimatedCost: 275000,
    roadHealthImpact: 'Penalty: -3.0 pts',
    assignedEngineer: 'Vikram Jadhav',
    dueDate: '2026-07-08',
    detectionImage: null,
    annotatedImage: null,
    damageArea: '3.10 sq m',
    gps: '17.983300, 73.883300',
    recommendation: 'Mill down rutted deformation crests, lay dense bituminous macadam overlay.',
    status: 'In Progress'
  },
  {
    id: 'TASK-4',
    taskId: 4,
    distressId: 104,
    trackingId: 'RD-TRK-139',
    distressType: 'Longitudinal Cracks',
    priority: 'Medium',
    severity: 'Medium',
    estimatedCost: 95000,
    roadHealthImpact: 'Penalty: -1.5 pts',
    assignedEngineer: 'Pradeep More',
    dueDate: '2026-07-15',
    detectionImage: null,
    annotatedImage: null,
    damageArea: '0.95 sq m',
    gps: '19.200000, 72.970000',
    recommendation: 'Clean crack using compressed air, inject rubberized asphalt sealant.',
    status: 'Pending'
  },
  {
    id: 'TASK-5',
    taskId: 5,
    distressId: 105,
    trackingId: 'RD-TRK-138',
    distressType: 'Transverse Cracks',
    priority: 'Medium',
    severity: 'Medium',
    estimatedCost: 142000,
    roadHealthImpact: 'Penalty: -1.5 pts',
    assignedEngineer: 'Sanjay Bhosale',
    dueDate: '2026-07-18',
    detectionImage: null,
    annotatedImage: null,
    damageArea: '1.45 sq m',
    gps: '21.145800, 79.088200',
    recommendation: 'Inject polymer-modified sealant and seal edges to prevent moisture entry.',
    status: 'Assigned'
  },
  {
    id: 'TASK-6',
    taskId: 6,
    distressId: 106,
    trackingId: 'RD-TRK-137',
    distressType: 'Pothole',
    priority: 'Critical',
    severity: 'Critical',
    estimatedCost: 210000,
    roadHealthImpact: 'Penalty: -5.0 pts',
    assignedEngineer: 'Amit Deshmukh',
    dueDate: '2026-07-06',
    detectionImage: null,
    annotatedImage: null,
    damageArea: '2.10 sq m',
    gps: '18.966700, 72.825800',
    recommendation: 'Cut rectangular distress zone, compact sub-base, refill and vibrate.',
    status: 'Completed'
  },
  {
    id: 'TASK-7',
    taskId: 7,
    distressId: 107,
    trackingId: 'RD-TRK-136',
    distressType: 'Raveling',
    priority: 'Low',
    severity: 'Low',
    estimatedCost: 68000,
    roadHealthImpact: 'Penalty: -0.5 pts',
    assignedEngineer: 'Vikram Jadhav',
    dueDate: '2026-07-04',
    detectionImage: null,
    annotatedImage: null,
    damageArea: '5.20 sq m',
    gps: '17.900000, 73.800000',
    recommendation: 'Apply thin emulsion slurry seal coat over loose surface aggregate area.',
    status: 'Completed'
  },
  {
    id: 'TASK-8',
    taskId: 8,
    distressId: 108,
    trackingId: 'RD-TRK-135',
    distressType: 'Alligator Cracks',
    priority: 'High',
    severity: 'High',
    estimatedCost: 310000,
    roadHealthImpact: 'Penalty: -3.0 pts',
    assignedEngineer: 'Unassigned',
    dueDate: '2026-07-22',
    detectionImage: null,
    annotatedImage: null,
    damageArea: '8.40 sq m',
    gps: '18.550000, 73.900000',
    recommendation: 'Full depth patch rehabilitation to replace degraded structural layers.',
    status: 'Pending'
  },
  {
    id: 'TASK-9',
    taskId: 9,
    distressId: 109,
    trackingId: 'RD-TRK-134',
    distressType: 'Pothole',
    priority: 'Critical',
    severity: 'Critical',
    estimatedCost: 195000,
    roadHealthImpact: 'Penalty: -5.0 pts',
    assignedEngineer: 'Rajesh Kulkarni',
    dueDate: '2026-07-05',
    detectionImage: null,
    annotatedImage: null,
    damageArea: '1.80 sq m',
    gps: '18.590000, 73.780000',
    recommendation: 'Excavate and clean pothole void, apply tack coat, pack hot aggregate mix.',
    status: 'Closed'
  },
  {
    id: 'TASK-10',
    taskId: 10,
    distressId: 110,
    trackingId: 'RD-TRK-133',
    distressType: 'Rutting',
    priority: 'Medium',
    severity: 'Medium',
    estimatedCost: 165000,
    roadHealthImpact: 'Penalty: -1.5 pts',
    assignedEngineer: 'Suresh Patil',
    dueDate: '2026-07-25',
    detectionImage: null,
    annotatedImage: null,
    damageArea: '2.50 sq m',
    gps: '18.460000, 73.830000',
    recommendation: 'Overlay with thin friction course or mill deformation bumps.',
    status: 'Closed'
  }
];

export default function MaintenanceDashboard() {
  // Navigation & View Mode states
  const [viewMode, setViewMode] = useState<'kanban' | 'table' | 'calendar'>('kanban');
  const [tasks, setTasks] = useState<CombinedTask[]>([]);
  const [engineers, setEngineers] = useState<UserResponse[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Search & Filter Toolbar States
  const [searchQuery, setSearchQuery] = useState('');
  const [priorityFilter, setPriorityFilter] = useState('All');
  const [severityFilter, setSeverityFilter] = useState('All');
  const [statusFilter, setStatusFilter] = useState('All');
  const [engineerFilter, setEngineerFilter] = useState('All');
  const [dateFilter, setDateFilter] = useState('All'); // Matches YYYY-MM prefix

  // Selected Task Drawer State
  const [selectedTask, setSelectedTask] = useState<CombinedTask | null>(null);

  // Calendar View month state
  const [currentYear, setCurrentYear] = useState(2026);
  const [currentMonth, setCurrentMonth] = useState(6); // 0-indexed: July = 6

  // Table pagination state
  const [currentPage, setCurrentPage] = useState(1);
  const itemsPerPage = 8;

  // 1. Fetch & Join API Data
  useEffect(() => {
    const fetchMaintenanceData = async () => {
      setIsLoading(true);
      try {
        const [recommendations, distresses, users] = await Promise.all([
          apiService.getMaintenanceRecommendations(),
          apiService.getDistressLogs(0, 1000),
          apiService.getUsers(0, 200)
        ]);

        setEngineers(users);

        let combined: CombinedTask[] = recommendations.map(task => {
          const distress = distresses.find(d => d.id === task.distress_id);
          const engineer = users.find(u => u.id === task.assigned_to)?.full_name || 'Unassigned';
          const severity = distress?.severity || 'Medium';
          const distressType = distress?.distress_type || 'Pothole';
          const gps = distress ? `${distress.latitude.toFixed(6)}, ${distress.longitude.toFixed(6)}` : '18.520430, 73.856743';
          const damageArea = distress?.affected_area ? `${distress.affected_area.toFixed(2)} sq m` : '0.50 sq m';

          return {
            id: `TASK-${task.id}`,
            taskId: task.id,
            distressId: task.distress_id,
            trackingId: distress?.tracking_id ? `RD-TRK-${distress.tracking_id}` : `RD-TRK-${task.distress_id}`,
            distressType: distressType.replace('_', ' ').replace(/\b\w/g, c => c.toUpperCase()),
            priority: task.priority ? task.priority.charAt(0).toUpperCase() + task.priority.slice(1).toLowerCase() : 'Medium',
            severity: severity.charAt(0).toUpperCase() + severity.slice(1).toLowerCase(),
            estimatedCost: task.estimated_cost || 120000,
            roadHealthImpact: `Penalty: -${severity.toLowerCase() === 'critical' ? '5.0' : severity.toLowerCase() === 'high' ? '3.0' : severity.toLowerCase() === 'medium' ? '1.5' : '0.5'} pts`,
            assignedEngineer: engineer,
            dueDate: task.due_date || new Date(Date.now() + 5 * 24 * 60 * 60 * 1000).toISOString().split('T')[0],
            detectionImage: distress?.detection_image_path || distress?.image_url || null,
            annotatedImage: distress?.image_url || null,
            damageArea,
            gps,
            recommendation: task.recommendation || 'Standard rehabilitation procedure required.',
            status: task.status ? task.status.replace('_', ' ').replace(/\b\w/g, c => c.toUpperCase()) : 'Pending',
          };
        });

        // Fallback to mock data if backend has no active tasks
        if (combined.length === 0) {
          combined = FALLBACK_MOCK_TASKS.map((t, idx) => {
            let engineer = t.assignedEngineer;
            if (engineer === 'Unassigned' && users.length > 0) {
              const u = users[idx % users.length];
              engineer = u.full_name || u.email;
            }
            return { ...t, assignedEngineer: engineer };
          });
        }

        setTasks(combined);
        setError(null);
      } catch (err) {
        console.error(err);
        setError("Failed to fetch backend maintenance data. Running in cache fallback mode.");
        setTasks(FALLBACK_MOCK_TASKS);
      } finally {
        setIsLoading(false);
      }
    };

    fetchMaintenanceData();
  }, []);

  // Sync drawer task if changes were made
  const drawerTask = useMemo(() => {
    if (!selectedTask) return null;
    return tasks.find(t => t.taskId === selectedTask.taskId) || selectedTask;
  }, [tasks, selectedTask]);

  // Unique lists for Filters
  const uniqueEngineers = useMemo(() => {
    const list = new Set<string>();
    tasks.forEach(t => {
      if (t.assignedEngineer && t.assignedEngineer !== 'Unassigned') {
        list.add(t.assignedEngineer);
      }
    });
    return Array.from(list);
  }, [tasks]);

  const uniqueMonths = useMemo(() => {
    const list = new Set<string>();
    tasks.forEach(t => {
      if (t.dueDate) {
        list.add(t.dueDate.slice(0, 7)); // YYYY-MM
      }
    });
    return Array.from(list).sort();
  }, [tasks]);

  // Statistics Calculations
  const stats = useMemo(() => {
    const pending = tasks.filter(t => t.status === 'Pending').length;
    const completed = tasks.filter(t => t.status === 'Completed' || t.status === 'Closed').length;
    const critical = tasks.filter(t => t.priority === 'Critical').length;
    const totalCost = tasks.reduce((sum, t) => sum + t.estimatedCost, 0);
    const avgCost = tasks.length > 0 ? Math.round(totalCost / tasks.length) : 0;
    
    return {
      pending,
      completed,
      critical,
      totalCost,
      avgCost,
      avgCompletionTime: '1.8 Days' // Operations KPI metric benchmark
    };
  }, [tasks]);

  // Filter Tasks list
  const filteredTasks = useMemo(() => {
    return tasks.filter(t => {
      const query = searchQuery.toLowerCase();
      const matchesSearch =
        t.trackingId.toLowerCase().includes(query) ||
        t.assignedEngineer.toLowerCase().includes(query) ||
        t.priority.toLowerCase().includes(query) ||
        t.status.toLowerCase().includes(query) ||
        t.distressType.toLowerCase().includes(query);

      const matchesPriority = priorityFilter === 'All' || t.priority === priorityFilter;
      const matchesSeverity = severityFilter === 'All' || t.severity === severityFilter;
      const matchesStatus = statusFilter === 'All' || t.status === statusFilter;
      const matchesEngineer = engineerFilter === 'All' || t.assignedEngineer === engineerFilter;
      const matchesDate = dateFilter === 'All' || t.dueDate.startsWith(dateFilter);

      return matchesSearch && matchesPriority && matchesSeverity && matchesStatus && matchesEngineer && matchesDate;
    });
  }, [tasks, searchQuery, priorityFilter, severityFilter, statusFilter, engineerFilter, dateFilter]);

  // Table Pagination
  const totalPages = Math.max(1, Math.ceil(filteredTasks.length / itemsPerPage));
  const paginatedTasks = useMemo(() => {
    const start = (currentPage - 1) * itemsPerPage;
    return filteredTasks.slice(start, start + itemsPerPage);
  }, [filteredTasks, currentPage]);

  // Reset filter bar
  const handleResetFilters = () => {
    setSearchQuery('');
    setPriorityFilter('All');
    setSeverityFilter('All');
    setStatusFilter('All');
    setEngineerFilter('All');
    setDateFilter('All');
    setCurrentPage(1);
  };

  // Recharts Summary Data
  const rechartsStatusData = useMemo(() => {
    const counts: Record<string, number> = { Pending: 0, Assigned: 0, 'In Progress': 0, Completed: 0, Closed: 0 };
    filteredTasks.forEach(t => {
      if (counts[t.status] !== undefined) counts[t.status]++;
    });
    return Object.entries(counts).map(([name, value]) => ({
      name,
      value,
      color: STATUS_COLORS[name] || '#ccc'
    })).filter(item => item.value > 0);
  }, [filteredTasks]);

  const rechartsPriorityData = useMemo(() => {
    const counts: Record<string, number> = { Critical: 0, High: 0, Medium: 0, Low: 0 };
    filteredTasks.forEach(t => {
      if (counts[t.priority] !== undefined) counts[t.priority]++;
    });
    return Object.entries(counts).map(([name, value]) => ({
      name,
      value,
      color: PRIORITY_COLORS[name] || '#ccc'
    }));
  }, [filteredTasks]);

  // Calendar cells builder
  const calendarCells = useMemo(() => {
    const firstDayOfWeek = new Date(currentYear, currentMonth, 1).getDay();
    const daysInMonth = new Date(currentYear, currentMonth + 1, 0).getDate();
    const daysInPrevMonth = new Date(currentYear, currentMonth, 0).getDate();

    const cells: Array<{ day: number; isCurrentMonth: boolean; dateString: string }> = [];

    // Prev month days padding
    for (let i = firstDayOfWeek - 1; i >= 0; i--) {
      const prevDay = daysInPrevMonth - i;
      const prevMonth = currentMonth === 0 ? 11 : currentMonth - 1;
      const prevYear = currentMonth === 0 ? currentYear - 1 : currentYear;
      const dateString = `${prevYear}-${String(prevMonth + 1).padStart(2, '0')}-${String(prevDay).padStart(2, '0')}`;
      cells.push({ day: prevDay, isCurrentMonth: false, dateString });
    }

    // Current month days
    for (let i = 1; i <= daysInMonth; i++) {
      const dateString = `${currentYear}-${String(currentMonth + 1).padStart(2, '0')}-${String(i).padStart(2, '0')}`;
      cells.push({ day: i, isCurrentMonth: true, dateString });
    }

    // Next month days padding
    const remaining = 42 - cells.length; // Max 6 rows = 42 cells
    for (let i = 1; i <= remaining; i++) {
      const nextMonth = currentMonth === 11 ? 0 : currentMonth + 1;
      const nextYear = currentMonth === 11 ? currentYear + 1 : currentYear;
      const dateString = `${nextYear}-${String(nextMonth + 1).padStart(2, '0')}-${String(i).padStart(2, '0')}`;
      cells.push({ day: i, isCurrentMonth: false, dateString });
    }

    return cells;
  }, [currentYear, currentMonth]);

  const monthNames = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];

  // Navigation Calendar
  const handlePrevMonth = () => {
    if (currentMonth === 0) {
      setCurrentMonth(11);
      setCurrentYear(currentYear - 1);
    } else {
      setCurrentMonth(currentMonth - 1);
    }
  };

  const handleNextMonth = () => {
    if (currentMonth === 11) {
      setCurrentMonth(0);
      setCurrentYear(currentYear + 1);
    } else {
      setCurrentMonth(currentMonth + 1);
    }
  };

  // Local Task Updates
  const updateTaskField = (taskId: number, field: keyof CombinedTask, value: any) => {
    setTasks(prev => prev.map(t => {
      if (t.taskId === taskId) {
        let updated = { ...t, [field]: value };
        // Auto adjust status if assigning engineer
        if (field === 'assignedEngineer') {
          if (value !== 'Unassigned' && t.status === 'Pending') {
            updated.status = 'Assigned';
          } else if (value === 'Unassigned') {
            updated.status = 'Pending';
          }
        }
        return updated;
      }
      return t;
    }));
  };

  // CSV Export
  const exportCSV = () => {
    const headers = ['Task ID', 'Tracking ID', 'Distress Type', 'Severity', 'Priority', 'Status', 'Estimated Cost', 'Road Health Impact', 'Assigned Engineer', 'Due Date', 'GPS'];
    const rows = filteredTasks.map(t => [
      t.id,
      t.trackingId,
      t.distressType,
      t.severity,
      t.priority,
      t.status,
      t.estimatedCost,
      t.roadHealthImpact,
      t.assignedEngineer,
      t.dueDate,
      t.gps
    ]);
    const content = [headers.join(','), ...rows.map(r => r.map(val => `"${val}"`).join(','))].join('\n');
    const blob = new Blob([content], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `maintenance_tasks_registry_${new Date().toISOString().split('T')[0]}.csv`;
    link.click();
    URL.revokeObjectURL(url);
  };

  // Excel Export
  const exportExcel = () => {
    const headers = ['Task ID', 'Tracking ID', 'Distress Type', 'Severity', 'Priority', 'Status', 'Estimated Cost', 'Road Health Impact', 'Assigned Engineer', 'Due Date', 'GPS'];
    const rows = filteredTasks.map(t => [
      t.id,
      t.trackingId,
      t.distressType,
      t.severity,
      t.priority,
      t.status,
      t.estimatedCost,
      t.roadHealthImpact,
      t.assignedEngineer,
      t.dueDate,
      t.gps
    ]);
    let content = headers.join('\t') + '\n';
    rows.forEach(r => {
      content += r.join('\t') + '\n';
    });
    const blob = new Blob([content], { type: 'application/vnd.ms-excel;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `maintenance_tasks_registry_${new Date().toISOString().split('T')[0]}.xls`;
    link.click();
    URL.revokeObjectURL(url);
  };

  // PDF Export
  const exportPDF = () => {
    window.print();
  };

  const getAbsoluteImageUrl = (path: string | null) => {
    if (!path) return null;
    if (path.startsWith('http')) return path;
    const baseUrl = import.meta.env.VITE_API_URL || 'http://127.0.0.1:8000';
    const cleanPath = path.startsWith('/') ? path.slice(1) : path;
    return `${baseUrl}/${cleanPath}`;
  };

  const getTasksForDate = (dateString: string): CombinedTask[] => {
    return tasks.filter(t => t.dueDate === dateString);
  };

  if (isLoading) {
    return (
      <div className="mnt-dash mnt-dash--loading" style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', minHeight: '60vh' }}>
        <div style={{ width: '40px', height: '40px', border: '3px solid var(--card-border)', borderTopColor: '#6C7354', borderRadius: '50%', animation: 'spin 1s linear infinite' }} />
        <p style={{ marginTop: '16px', color: 'var(--secondary-text)', fontSize: '14px' }}>Synchronizing maintenance operations registry...</p>
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
      <div className="mnt-dash mnt-dash--error" style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', minHeight: '60vh', textAlign: 'center', padding: '24px' }}>
        <div style={{ fontSize: '40px', marginBottom: '16px' }}>⚠️</div>
        <h2 className="medium-section-title" style={{ fontSize: '20px', marginBottom: '8px' }}>Operations Database Alert</h2>
        <p style={{ color: 'var(--secondary-text)', fontSize: '14px', maxWidth: '450px', marginBottom: '24px' }}>{error}</p>
        <button onClick={() => window.location.reload()} className="btn-report-run font-semibold" style={{ padding: '8px 16px', fontSize: '13px' }}>
          Reload Registry Cache
        </button>
      </div>
    );
  }

  return (
    <div className="mnt-dash animate-fade-in" aria-label="Maintenance Operations Center">
      <header className="mnt-dash__header">
        <h1 className="bold-page-title" style={{ fontSize: '32px' }}>Maintenance Operations Center</h1>
        <p className="light-secondary-text" style={{ fontSize: '14px' }}>Analyze, allocate, and schedule road repair workflows, operations budgets, and crew dispatches.</p>
      </header>

      {/* 6 Column Statistics Cards Grid */}
      <section className="mnt-dash__kpi-grid" aria-label="Operations Overview Metrics">
        <article className="premium-card">
          <div className="card-header-with-actions" style={{ borderBottom: 'none', marginBottom: '2px', padding: 0 }}>
            <span style={{ fontSize: '10px', color: 'var(--secondary-text)', fontWeight: 600, textTransform: 'uppercase' }}>Pending Tasks</span>
            <ClipboardList size={16} style={{ color: 'var(--accent-blue)' }} />
          </div>
          <span className="font-mono" style={{ fontSize: '24px', fontWeight: 700 }}>{stats.pending}</span>
          <div style={{ display: 'flex', gap: '4px', fontSize: '10px', color: 'var(--secondary-text)', marginTop: '2px' }}>
            <span>Awaiting allocation</span>
          </div>
        </article>

        <article className="premium-card">
          <div className="card-header-with-actions" style={{ borderBottom: 'none', marginBottom: '2px', padding: 0 }}>
            <span style={{ fontSize: '10px', color: 'var(--secondary-text)', fontWeight: 600, textTransform: 'uppercase' }}>Completed Tasks</span>
            <CheckCircle2 size={16} style={{ color: 'var(--success)' }} />
          </div>
          <span className="font-mono" style={{ fontSize: '24px', fontWeight: 700, color: 'var(--success)' }}>{stats.completed}</span>
          <div style={{ display: 'flex', gap: '4px', fontSize: '10px', color: 'var(--success)', marginTop: '2px' }}>
            <span>Resolved work orders</span>
          </div>
        </article>

        <article className="premium-card">
          <div className="card-header-with-actions" style={{ borderBottom: 'none', marginBottom: '2px', padding: 0 }}>
            <span style={{ fontSize: '10px', color: 'var(--secondary-text)', fontWeight: 600, textTransform: 'uppercase' }}>Critical Repairs</span>
            <AlertTriangle size={16} style={{ color: 'var(--danger)' }} />
          </div>
          <span className="font-mono" style={{ fontSize: '24px', fontWeight: 700, color: 'var(--danger)' }}>{stats.critical}</span>
          <div style={{ display: 'flex', gap: '4px', fontSize: '10px', color: 'var(--danger)', marginTop: '2px' }}>
            <span>P1 critical priority</span>
          </div>
        </article>

        <article className="premium-card">
          <div className="card-header-with-actions" style={{ borderBottom: 'none', marginBottom: '2px', padding: 0 }}>
            <span style={{ fontSize: '10px', color: 'var(--secondary-text)', fontWeight: 600, textTransform: 'uppercase' }}>Estimated Budget</span>
            <IndianRupee size={16} style={{ color: 'var(--accent-blue)' }} />
          </div>
          <span className="font-mono" style={{ fontSize: '24px', fontWeight: 700 }}>{formatCost(stats.totalCost)}</span>
          <div style={{ display: 'flex', gap: '4px', fontSize: '10px', color: 'var(--secondary-text)', marginTop: '2px' }}>
            <span>Total estimated cost</span>
          </div>
        </article>

        <article className="premium-card">
          <div className="card-header-with-actions" style={{ borderBottom: 'none', marginBottom: '2px', padding: 0 }}>
            <span style={{ fontSize: '10px', color: 'var(--secondary-text)', fontWeight: 600, textTransform: 'uppercase' }}>Average Repair Cost</span>
            <IndianRupee size={16} style={{ color: 'var(--accent-blue)' }} />
          </div>
          <span className="font-mono" style={{ fontSize: '24px', fontWeight: 700 }}>{formatCost(stats.avgCost)}</span>
          <div style={{ display: 'flex', gap: '4px', fontSize: '10px', color: 'var(--secondary-text)', marginTop: '2px' }}>
            <span>Average per ticket</span>
          </div>
        </article>

        <article className="premium-card">
          <div className="card-header-with-actions" style={{ borderBottom: 'none', marginBottom: '2px', padding: 0 }}>
            <span style={{ fontSize: '10px', color: 'var(--secondary-text)', fontWeight: 600, textTransform: 'uppercase' }}>Avg Completion Time</span>
            <Clock size={16} style={{ color: 'var(--accent-blue)' }} />
          </div>
          <span className="font-mono" style={{ fontSize: '24px', fontWeight: 700 }}>{stats.avgCompletionTime}</span>
          <div style={{ display: 'flex', gap: '4px', fontSize: '10px', color: 'var(--secondary-text)', marginTop: '2px' }}>
            <span>Operations SLA benchmark</span>
          </div>
        </article>
      </section>

      {/* Toolbar View Mode Switcher + Client Side Exports */}
      <div className="view-selector-bar">
        <div className="view-tabs">
          <button onClick={() => setViewMode('kanban')} className={`view-tab-btn ${viewMode === 'kanban' ? 'active' : ''}`} aria-label="Switch to Kanban Board View">
            <Wrench size={14} />
            <span>Kanban Board</span>
          </button>
          <button onClick={() => setViewMode('table')} className={`view-tab-btn ${viewMode === 'table' ? 'active' : ''}`} aria-label="Switch to Table Registry View">
            <ClipboardList size={14} />
            <span>Table Registry</span>
          </button>
          <button onClick={() => setViewMode('calendar')} className={`view-tab-btn ${viewMode === 'calendar' ? 'active' : ''}`} aria-label="Switch to Calendar Schedule View">
            <Calendar size={14} />
            <span>Calendar Schedule</span>
          </button>
        </div>

        <div style={{ display: 'flex', gap: '8px' }}>
          <button className="btn-control" style={{ fontSize: '12px', display: 'flex', alignItems: 'center', gap: '6px' }} onClick={exportCSV} title="Export CSV file">
            <Download size={13} />
            <span>CSV</span>
          </button>
          <button className="btn-control" style={{ fontSize: '12px', display: 'flex', alignItems: 'center', gap: '6px' }} onClick={exportExcel} title="Export Excel sheet">
            <Download size={13} />
            <span>Excel</span>
          </button>
          <button className="btn-control" style={{ fontSize: '12px', display: 'flex', alignItems: 'center', gap: '6px' }} onClick={exportPDF} title="Print and save to PDF">
            <Download size={13} />
            <span>PDF Print</span>
          </button>
        </div>
      </div>

      {/* Search and Filters panel */}
      <section style={{ display: 'flex', gap: '10px', flexWrap: 'wrap', alignItems: 'center', background: 'var(--primary-bg)', padding: '10px 14px', borderRadius: 'var(--radius-md)', border: '1px solid var(--card-border)' }} aria-label="Filters Panel">
        <div style={{ flex: 1.5, position: 'relative', minWidth: '160px' }}>
          <Search size={14} style={{ position: 'absolute', left: '10px', top: '10px', color: 'var(--secondary-text)' }} />
          <input 
            type="text" 
            placeholder="Search tasks, types, engineers..." 
            value={searchQuery}
            onChange={(e) => { setSearchQuery(e.target.value); setCurrentPage(1); }}
            style={{ width: '100%', paddingLeft: '32px', height: '34px', border: '1px solid var(--card-border)', background: 'white', borderRadius: '6px', fontSize: '12px' }}
          />
        </div>

        <select 
          value={statusFilter} 
          onChange={(e) => { setStatusFilter(e.target.value); setCurrentPage(1); }}
          aria-label="Filter status dropdown"
          style={{ height: '34px', padding: '0 8px', border: '1px solid var(--card-border)', background: 'white', borderRadius: '6px', fontSize: '12px', minWidth: '100px' }}
        >
          <option value="All">All Statuses</option>
          <option value="Pending">Pending</option>
          <option value="Assigned">Assigned</option>
          <option value="In Progress">In Progress</option>
          <option value="Completed">Completed</option>
          <option value="Closed">Closed</option>
        </select>

        <select 
          value={priorityFilter} 
          onChange={(e) => { setPriorityFilter(e.target.value); setCurrentPage(1); }}
          aria-label="Filter priority dropdown"
          style={{ height: '34px', padding: '0 8px', border: '1px solid var(--card-border)', background: 'white', borderRadius: '6px', fontSize: '12px', minWidth: '100px' }}
        >
          <option value="All">All Priorities</option>
          <option value="Critical">Critical</option>
          <option value="High">High</option>
          <option value="Medium">Medium</option>
          <option value="Low">Low</option>
        </select>

        <select 
          value={severityFilter} 
          onChange={(e) => { setSeverityFilter(e.target.value); setCurrentPage(1); }}
          aria-label="Filter severity dropdown"
          style={{ height: '34px', padding: '0 8px', border: '1px solid var(--card-border)', background: 'white', borderRadius: '6px', fontSize: '12px', minWidth: '100px' }}
        >
          <option value="All">All Severities</option>
          <option value="Critical">Critical</option>
          <option value="High">High</option>
          <option value="Medium">Medium</option>
          <option value="Low">Low</option>
        </select>

        <select 
          value={engineerFilter} 
          onChange={(e) => { setEngineerFilter(e.target.value); setCurrentPage(1); }}
          aria-label="Filter assigned engineer dropdown"
          style={{ height: '34px', padding: '0 8px', border: '1px solid var(--card-border)', background: 'white', borderRadius: '6px', fontSize: '12px', minWidth: '120px' }}
        >
          <option value="All">All Engineers</option>
          <option value="Unassigned">Unassigned Only</option>
          {uniqueEngineers.map(e => (
            <option key={e} value={e}>{e}</option>
          ))}
        </select>

        <select 
          value={dateFilter} 
          onChange={(e) => { setDateFilter(e.target.value); setCurrentPage(1); }}
          aria-label="Filter due dates dropdown"
          style={{ height: '34px', padding: '0 8px', border: '1px solid var(--card-border)', background: 'white', borderRadius: '6px', fontSize: '12px', minWidth: '110px' }}
        >
          <option value="All">All Months</option>
          {uniqueMonths.map(m => {
            const [y, mon] = m.split('-');
            return <option key={m} value={m}>{monthNames[Number(mon) - 1]} {y}</option>;
          })}
        </select>

        <button className="btn-control" style={{ height: '34px', padding: '0 12px', fontSize: '12px' }} onClick={handleResetFilters}>
          Reset
        </button>
      </section>

      {/* Main Workspace Layout */}
      {viewMode === 'kanban' && (
        <div className="kanban-board">
          {['Pending', 'Assigned', 'In Progress', 'Completed', 'Closed'].map(columnStatus => {
            const columnTasks = filteredTasks.filter(t => t.status === columnStatus);
            return (
              <div key={columnStatus} className="kanban-column">
                <div className="kanban-column-header">
                  <div className="kanban-column-title">
                    <span style={{ width: '8px', height: '8px', borderRadius: '50%', background: STATUS_COLORS[columnStatus] || '#ccc' }} />
                    <span>{columnStatus}</span>
                  </div>
                  <span className="kanban-column-badge">{columnTasks.length}</span>
                </div>

                <div className="kanban-cards-container">
                  {columnTasks.length === 0 ? (
                    <div style={{ textAlign: 'center', color: 'var(--secondary-text)', fontSize: '11px', padding: '24px 0', border: '2px dashed var(--card-border)', borderRadius: '6px' }}>
                      No tasks in this stage
                    </div>
                  ) : (
                    columnTasks.map(task => (
                      <div key={task.id} className="kanban-card" onClick={() => setSelectedTask(task)}>
                        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                          <span className="kanban-card-id">{task.trackingId}</span>
                          <span className={`status-pill badge-${task.priority.toLowerCase()}`} style={{ fontSize: '9px' }}>{task.priority}</span>
                        </div>

                        <span className="kanban-card-title">{task.distressType}</span>

                        <div className="kanban-card-row">
                          <span className="kanban-card-meta">Severity:</span>
                          <span className={`font-semibold`} style={{ color: PRIORITY_COLORS[task.severity] || 'inherit' }}>{task.severity}</span>
                        </div>

                        <div className="kanban-card-row">
                          <span className="kanban-card-meta">Impact:</span>
                          <span className="font-semibold">{task.roadHealthImpact}</span>
                        </div>

                        <div className="kanban-card-row">
                          <span className="kanban-card-meta">Due Date:</span>
                          <span className="font-mono">{task.dueDate}</span>
                        </div>

                        <div className="kanban-card-footer">
                          <div className="kanban-card-engineer">
                            <div className="kanban-card-avatar">
                              {task.assignedEngineer.split(' ').map(n => n[0]).join('').slice(0, 2)}
                            </div>
                            <span style={{ fontSize: '10px' }} title={task.assignedEngineer}>{task.assignedEngineer.split(' ')[0]}</span>
                          </div>
                          <span className="font-mono font-bold" style={{ fontSize: '11px' }}>{formatCost(task.estimatedCost)}</span>
                        </div>

                        {/* Quick Action Navigation buttons inside card */}
                        <div style={{ display: 'flex', gap: '4px', marginTop: '6px', borderTop: '1px solid var(--card-border)', paddingTop: '6px', justifyContent: 'flex-end' }} onClick={e => e.stopPropagation()}>
                          {columnStatus === 'Pending' && (
                            <button className="btn-control" style={{ fontSize: '9px', padding: '2px 6px', height: '18px' }} onClick={() => updateTaskField(task.taskId, 'status', 'Assigned')}>
                              Assign <ArrowRight size={10} style={{ marginLeft: '2px', display: 'inline' }} />
                            </button>
                          )}
                          {columnStatus === 'Assigned' && (
                            <button className="btn-control" style={{ fontSize: '9px', padding: '2px 6px', height: '18px' }} onClick={() => updateTaskField(task.taskId, 'status', 'In Progress')}>
                              Start <ArrowRight size={10} style={{ marginLeft: '2px', display: 'inline' }} />
                            </button>
                          )}
                          {columnStatus === 'In Progress' && (
                            <button className="btn-control" style={{ fontSize: '9px', padding: '2px 6px', height: '18px', background: 'rgba(16, 185, 129, 0.1)', color: 'var(--success)' }} onClick={() => updateTaskField(task.taskId, 'status', 'Completed')}>
                              Complete <ArrowRight size={10} style={{ marginLeft: '2px', display: 'inline' }} />
                            </button>
                          )}
                          {columnStatus === 'Completed' && (
                            <button className="btn-control" style={{ fontSize: '9px', padding: '2px 6px', height: '18px', background: 'rgba(148, 163, 184, 0.1)' }} onClick={() => updateTaskField(task.taskId, 'status', 'Closed')}>
                              Close
                            </button>
                          )}
                        </div>
                      </div>
                    ))
                  )}
                </div>
              </div>
            );
          })}
        </div>
      )}

      {viewMode === 'table' && (
        <div className="premium-card" style={{ display: 'flex', flexDirection: 'column' }}>
          <div className="table-responsive">
            <table className="enterprise-table">
              <thead>
                <tr>
                  <th>Tracking ID</th>
                  <th>Distress Type</th>
                  <th>Severity</th>
                  <th>Priority</th>
                  <th>Road Health Impact</th>
                  <th>Assigned Engineer</th>
                  <th>Status</th>
                  <th>Estimated Cost</th>
                  <th>Due Date</th>
                </tr>
              </thead>
              <tbody>
                {paginatedTasks.length === 0 ? (
                  <tr>
                    <td colSpan={9} style={{ textAlign: 'center', color: 'var(--secondary-text)', padding: '24px' }}>
                      No tasks found matching current filters.
                    </td>
                  </tr>
                ) : (
                  paginatedTasks.map(t => (
                    <tr key={t.id} style={{ cursor: 'pointer' }} onClick={() => setSelectedTask(t)}>
                      <td>
                        <span className="font-mono font-bold">{t.trackingId}</span>
                      </td>
                      <td>
                        <span className="font-semibold">{t.distressType}</span>
                      </td>
                      <td>
                        <span className={`status-pill badge-${t.severity.toLowerCase()}`} style={{ fontSize: '10px' }}>{t.severity}</span>
                      </td>
                      <td>
                        <span className={`status-pill badge-${t.priority.toLowerCase()}`} style={{ fontSize: '10px' }}>{t.priority}</span>
                      </td>
                      <td>
                        <span className="font-semibold">{t.roadHealthImpact}</span>
                      </td>
                      <td>
                        <span className="font-semibold">{t.assignedEngineer}</span>
                      </td>
                      <td>
                        <span className={`status-pill status-pill--${t.status.toLowerCase().replace(/\s/g, '')}`} style={{ textTransform: 'capitalize', fontWeight: 600 }}>
                          {t.status}
                        </span>
                      </td>
                      <td>
                        <span className="font-mono font-bold">{formatCost(t.estimatedCost)}</span>
                      </td>
                      <td>
                        <span className="font-mono">{t.dueDate}</span>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>

          {filteredTasks.length > 0 && (
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderTop: '1px solid var(--card-border)', paddingTop: '14px', marginTop: '16px' }}>
              <span style={{ fontSize: '12px', color: 'var(--secondary-text)' }}>
                Showing <strong>{((currentPage - 1) * itemsPerPage) + 1}</strong> to <strong>{Math.min(currentPage * itemsPerPage, filteredTasks.length)}</strong> of <strong>{filteredTasks.length}</strong> tasks
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
      )}

      {viewMode === 'calendar' && (
        <div className="calendar-view-container">
          <div className="calendar-header">
            <span className="calendar-month-title">{monthNames[currentMonth]} {currentYear}</span>
            <div className="calendar-nav-buttons">
              <button className="btn-control" style={{ padding: '6px' }} onClick={handlePrevMonth}><ChevronLeft size={16} /></button>
              <button className="btn-control" style={{ padding: '6px 12px', fontSize: '12px' }} onClick={() => { setCurrentMonth(new Date().getMonth()); setCurrentYear(new Date().getFullYear()); }}>Today</button>
              <button className="btn-control" style={{ padding: '6px' }} onClick={handleNextMonth}><ChevronRight size={16} /></button>
            </div>
          </div>

          <div className="calendar-grid">
            {['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].map(d => (
              <div key={d} className="calendar-day-header">{d}</div>
            ))}

            {calendarCells.map((cell, idx) => {
              const dayTasks = getTasksForDate(cell.dateString);
              const isToday = cell.dateString === new Date().toISOString().split('T')[0];

              return (
                <div key={idx} className={`calendar-day-cell ${cell.isCurrentMonth ? '' : 'other-month'} ${isToday ? 'today' : ''}`}>
                  <span className="calendar-day-num">{cell.day}</span>
                  
                  <div className="calendar-events-container">
                    {dayTasks.slice(0, 3).map(task => (
                      <div 
                        key={task.id} 
                        className="calendar-event-badge" 
                        style={{ background: STATUS_COLORS[task.status] || '#76B900' }}
                        onClick={() => setSelectedTask(task)}
                        title={`${task.trackingId}: ${task.distressType}`}
                      >
                        {task.trackingId} - {task.distressType}
                      </div>
                    ))}
                    {dayTasks.length > 3 && (
                      <div style={{ fontSize: '9px', fontWeight: 'bold', color: 'var(--secondary-text)', paddingLeft: '4px' }}>
                        +{dayTasks.length - 3} more
                      </div>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      )}

      {/* Recharts Analytics breakdown displayed beneath the workspace */}
      <div style={{ display: 'grid', gridTemplateColumns: '1.2fr 1fr', gap: '24px' }}>
        {/* Left: Priority breakdown bar chart */}
        <div className="premium-card">
          <h2 className="medium-section-title" style={{ fontSize: '15px', marginBottom: '14px' }}>Priority Workload Distribution</h2>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
            {rechartsPriorityData.map((item) => {
              const max = Math.max(...rechartsPriorityData.map((d) => d.value), 1);
              const pct = (item.value / max) * 100;
              return (
                <div key={item.name} style={{ display: 'grid', gridTemplateColumns: '100px 1fr 30px', gap: '12px', alignItems: 'center', fontSize: '12px' }}>
                  <span style={{ color: 'var(--secondary-text)', fontWeight: 600 }}>{item.name}</span>
                  <div style={{ height: '8px', background: 'var(--primary-bg)', borderRadius: '4px', overflow: 'hidden', border: '1px solid var(--card-border)' }}>
                    <div style={{ width: `${pct}%`, height: '100%', background: item.color, borderRadius: '4px' }} />
                  </div>
                  <strong className="font-mono" style={{ textAlign: 'right' }}>{item.value}</strong>
                </div>
              );
            })}
          </div>
        </div>

        {/* Right: Pie Chart / Status Distribution */}
        <div className="premium-card" style={{ display: 'flex', flexDirection: 'column' }}>
          <h2 className="medium-section-title" style={{ fontSize: '15px', marginBottom: '10px' }}>Operations Stage Allocation</h2>
          <div style={{ display: 'flex', flex: 1, alignItems: 'center', justifyContent: 'center', gap: '20px' }}>
            <div style={{ width: '130px', height: '130px' }}>
              {rechartsStatusData.length > 0 ? (
                <ResponsiveContainer width="100%" height="100%">
                  <PieChart>
                    <Pie
                      data={rechartsStatusData}
                      cx="50%"
                      cy="50%"
                      innerRadius={36}
                      outerRadius={54}
                      paddingAngle={3}
                      dataKey="value"
                    >
                      {rechartsStatusData.map((entry) => (
                        <Cell key={entry.name} fill={entry.color} />
                      ))}
                    </Pie>
                    <Tooltip />
                  </PieChart>
                </ResponsiveContainer>
              ) : (
                <div style={{ display: 'flex', height: '100%', alignItems: 'center', justifyContent: 'center', fontSize: '11px', color: 'var(--secondary-text)' }}>No Data</div>
              )}
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '6px', fontSize: '11px' }}>
              {rechartsStatusData.map(e => (
                <div key={e.name} style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                  <span style={{ width: '8px', height: '8px', borderRadius: '50%', background: e.color }} />
                  <span style={{ color: 'var(--secondary-text)' }}>{e.name}: <strong>{e.value}</strong></span>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>

      {/* Slide-out Maintenance Details Drawer */}
      {drawerTask && (
        <div className="details-drawer-overlay" onClick={() => setSelectedTask(null)}>
          <section className="details-drawer" onClick={e => e.stopPropagation()} aria-label="Maintenance Task Details">
            <header className="details-drawer-header">
              <div style={{ display: 'flex', flexDirection: 'column' }}>
                <span style={{ fontSize: '11px', color: 'var(--secondary-text)', fontWeight: 600, textTransform: 'uppercase' }}>Work Order Details</span>
                <h3 className="font-bold" style={{ fontSize: '18px', color: 'var(--primary-text)' }}>{drawerTask.trackingId}</h3>
              </div>
              <button className="btn-control" style={{ padding: '6px' }} onClick={() => setSelectedTask(null)}><X size={16} /></button>
            </header>

            <div className="details-drawer-body">
              {/* Image previews */}
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                <div style={{ background: 'var(--primary-bg)', height: '150px', border: '1px solid var(--card-border)', borderRadius: '6px', overflow: 'hidden', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', position: 'relative' }}>
                  {drawerTask.detectionImage ? (
                    <img src={getAbsoluteImageUrl(drawerTask.detectionImage) || undefined} alt="Detection CCTV Capture" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                  ) : (
                    <span style={{ fontSize: '11px', color: 'var(--secondary-text)', textAlign: 'center', padding: '10px' }}>Detection Frame <br/>[CCTV Source]</span>
                  )}
                  <span style={{ position: 'absolute', bottom: '4px', left: '4px', background: 'rgba(0,0,0,0.6)', color: 'white', fontSize: '8px', padding: '2px 4px', borderRadius: '3px' }}>RAW CAMERA</span>
                </div>

                <div style={{ background: 'var(--primary-bg)', height: '150px', border: '1px solid var(--card-border)', borderRadius: '6px', overflow: 'hidden', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', position: 'relative' }}>
                  {drawerTask.annotatedImage ? (
                    <img src={getAbsoluteImageUrl(drawerTask.annotatedImage) || undefined} alt="YOLO Annotated Capture" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                  ) : (
                    <span style={{ fontSize: '11px', color: 'var(--secondary-text)', textAlign: 'center', padding: '10px' }}>YOLO Annotated Frame <br/>[Analytics Source]</span>
                  )}
                  <span style={{ position: 'absolute', bottom: '4px', left: '4px', background: 'rgba(0,0,0,0.6)', color: 'white', fontSize: '8px', padding: '2px 4px', borderRadius: '3px' }}>AI ANNOTATION</span>
                </div>
              </div>

              {/* Status and Allocation Modifiers */}
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px', background: 'var(--primary-bg)', padding: '14px', borderRadius: '6px', border: '1px solid var(--card-border)' }}>
                <div>
                  <label style={{ fontSize: '10px', color: 'var(--secondary-text)', textTransform: 'uppercase', fontWeight: 700, display: 'block', marginBottom: '4px' }}>Stage Status</label>
                  <select 
                    value={drawerTask.status} 
                    onChange={e => updateTaskField(drawerTask.taskId, 'status', e.target.value)}
                    style={{ width: '100%', height: '34px', border: '1px solid var(--card-border)', background: 'white', borderRadius: '6px', fontSize: '12px', fontWeight: 600 }}
                  >
                    <option value="Pending">Pending</option>
                    <option value="Assigned">Assigned</option>
                    <option value="In Progress">In Progress</option>
                    <option value="Completed">Completed</option>
                    <option value="Closed">Closed</option>
                  </select>
                </div>

                <div>
                  <label style={{ fontSize: '10px', color: 'var(--secondary-text)', textTransform: 'uppercase', fontWeight: 700, display: 'block', marginBottom: '4px' }}>Assign Engineer</label>
                  <select 
                    value={drawerTask.assignedEngineer} 
                    onChange={e => updateTaskField(drawerTask.taskId, 'assignedEngineer', e.target.value)}
                    style={{ width: '100%', height: '34px', border: '1px solid var(--card-border)', background: 'white', borderRadius: '6px', fontSize: '12px', fontWeight: 600 }}
                  >
                    <option value="Unassigned">Unassigned</option>
                    {engineers.map(e => {
                      const name = e.full_name || e.email;
                      return <option key={e.id} value={name}>{name}</option>;
                    })}
                    {/* Add fallback names if engineers array is empty */}
                    {engineers.length === 0 && (
                      <>
                        <option value="Rajesh Kulkarni">Rajesh Kulkarni</option>
                        <option value="Suresh Patil">Suresh Patil</option>
                        <option value="Vikram Jadhav">Vikram Jadhav</option>
                        <option value="Pradeep More">Pradeep More</option>
                        <option value="Sanjay Bhosale">Sanjay Bhosale</option>
                        <option value="Amit Deshmukh">Amit Deshmukh</option>
                      </>
                    )}
                  </select>
                </div>
              </div>

              {/* Task specifications */}
              <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', borderBottom: '1px solid var(--card-border)', paddingBottom: '8px' }}>
                  <span style={{ color: 'var(--secondary-text)', fontSize: '12px' }}>Distress Classification:</span>
                  <strong>{drawerTask.distressType}</strong>
                </div>

                <div style={{ display: 'flex', justifyContent: 'space-between', borderBottom: '1px solid var(--card-border)', paddingBottom: '8px' }}>
                  <span style={{ color: 'var(--secondary-text)', fontSize: '12px' }}>Severity:</span>
                  <span className={`status-pill badge-${drawerTask.severity.toLowerCase()}`} style={{ fontSize: '11px' }}>{drawerTask.severity}</span>
                </div>

                <div style={{ display: 'flex', justifyContent: 'space-between', borderBottom: '1px solid var(--card-border)', paddingBottom: '8px' }}>
                  <span style={{ color: 'var(--secondary-text)', fontSize: '12px' }}>Priority level:</span>
                  <span className={`status-pill badge-${drawerTask.priority.toLowerCase()}`} style={{ fontSize: '11px' }}>{drawerTask.priority}</span>
                </div>

                <div style={{ display: 'flex', justifyContent: 'space-between', borderBottom: '1px solid var(--card-border)', paddingBottom: '8px' }}>
                  <span style={{ color: 'var(--secondary-text)', fontSize: '12px' }}>Damage Area (m²):</span>
                  <strong>{drawerTask.damageArea}</strong>
                </div>

                <div style={{ display: 'flex', justifyContent: 'space-between', borderBottom: '1px solid var(--card-border)', paddingBottom: '8px' }}>
                  <span style={{ color: 'var(--secondary-text)', fontSize: '12px' }}>Estimated Cost:</span>
                  <strong className="font-mono">{formatCost(drawerTask.estimatedCost)}</strong>
                </div>

                <div style={{ display: 'flex', justifyContent: 'space-between', borderBottom: '1px solid var(--card-border)', paddingBottom: '8px' }}>
                  <span style={{ color: 'var(--secondary-text)', fontSize: '12px' }}>Road Health Impact:</span>
                  <strong style={{ color: PRIORITY_COLORS[drawerTask.severity] }}>{drawerTask.roadHealthImpact}</strong>
                </div>

                {/* Editable Due Date */}
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderBottom: '1px solid var(--card-border)', paddingBottom: '8px' }}>
                  <span style={{ color: 'var(--secondary-text)', fontSize: '12px' }}>Due Date:</span>
                  <input 
                    type="date" 
                    value={drawerTask.dueDate} 
                    onChange={e => updateTaskField(drawerTask.taskId, 'dueDate', e.target.value)}
                    style={{ border: '1px solid var(--card-border)', padding: '4px 8px', borderRadius: '4px', fontSize: '12px', background: 'white' }}
                  />
                </div>

                {/* GPS mapping location */}
                <div style={{ display: 'flex', justifyContent: 'space-between', borderBottom: '1px solid var(--card-border)', paddingBottom: '8px', alignItems: 'center' }}>
                  <span style={{ color: 'var(--secondary-text)', fontSize: '12px' }}>GPS Coordinates:</span>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                    <MapPin size={12} style={{ color: 'var(--accent-blue)' }} />
                    <strong className="font-mono" style={{ fontSize: '12px' }}>{drawerTask.gps}</strong>
                    <a 
                      href={`https://www.google.com/maps/search/?api=1&query=${drawerTask.gps}`}
                      target="_blank" 
                      rel="noopener noreferrer"
                      className="btn-control" 
                      style={{ padding: '3px 6px', fontSize: '10px', height: '22px', display: 'flex', alignItems: 'center' }}
                      title="Open locations inside Google Maps"
                    >
                      <ExternalLink size={10} />
                    </a>
                  </div>
                </div>

                {/* Operations Recommendation */}
                <div style={{ display: 'flex', flexDirection: 'column', gap: '4px', background: 'var(--primary-bg)', padding: '12px 14px', borderRadius: '6px', border: '1px solid var(--card-border)', marginTop: '8px' }}>
                  <span style={{ fontSize: '10px', color: 'var(--secondary-text)', textTransform: 'uppercase', fontWeight: 700 }}>AI Telemetry Recommendation</span>
                  <p style={{ fontSize: '12px', lineHeight: 1.5, margin: 0 }}>{drawerTask.recommendation}</p>
                </div>
              </div>
            </div>
          </section>
        </div>
      )}
    </div>
  );
}
