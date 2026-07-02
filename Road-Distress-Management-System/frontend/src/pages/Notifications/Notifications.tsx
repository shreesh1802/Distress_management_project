import { useState, useMemo } from 'react';
import {
  Bell,
  ShieldAlert,
  FileText,
  CheckCircle2,
  Trash2,
  Check,
  RefreshCw,
  Eye,
  UserPlus,
  Filter,
  X,
  ChevronDown,
  ChevronUp,
  MapPin,
  Calendar,
  Activity,
  Camera,
  SlidersHorizontal,
  Layers
} from 'lucide-react';
import {
  ResponsiveContainer,
  LineChart,
  Line,
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
import './Notifications.css';

interface NotificationItem {
  id: string;
  type: 'danger' | 'warning' | 'success' | 'info';
  title: string;
  message: string;
  time: string;
  dateGroup: 'Today' | 'Yesterday' | 'Last 7 Days' | 'Earlier';
  unread: boolean;
  
  // Extended fields for enterprise details and filters
  priority: 'Critical' | 'High' | 'Medium' | 'Information' | 'Success';
  category: 'Detection' | 'Maintenance' | 'Reports' | 'System' | 'GIS' | 'Uploads';
  roadId?: string;
  location?: string;
  district?: string;
  pipeline?: string;
  thumbnailUrl?: string; // stylized SVG or colors representation
  assignedTo?: string;
}

export default function Notifications() {
  const [notifications, setNotifications] = useState<NotificationItem[]>([
    {
      id: 'NT-101',
      type: 'danger',
      title: 'Critical Distress Found',
      message: 'Pothole detected on NH-48 (KM 42.5 near Lonavala Ghats) requires immediate work order scheduling.',
      time: '10 mins ago',
      dateGroup: 'Today',
      unread: true,
      priority: 'Critical',
      category: 'Detection',
      roadId: 'NH-48',
      location: 'KM 42.5, Lonavala Ghats',
      district: 'Pune',
      pipeline: 'YOLOv11-Heavy',
      thumbnailUrl: 'pothole_1'
    },
    {
      id: 'NT-107',
      type: 'danger',
      title: 'Bridge Structural Crack',
      message: 'Severe structural cracking identified on Bridge deck section #4, Western Express Highway.',
      time: '45 mins ago',
      dateGroup: 'Today',
      unread: true,
      priority: 'Critical',
      category: 'Detection',
      roadId: 'WEH-01',
      location: 'Bridge #4, Bandra Flyover',
      district: 'Mumbai',
      pipeline: 'YOLOv11-Heavy',
      thumbnailUrl: 'bridge_crack'
    },
    {
      id: 'NT-102',
      type: 'success',
      title: 'YOLOv11 Inference Complete',
      message: 'Video upload log surveillance_cam_mumbai.mp4 processed successfully. 12 distresses tagged.',
      time: '2 hours ago',
      dateGroup: 'Today',
      unread: true,
      priority: 'Success',
      category: 'Uploads',
      roadId: 'WEH-03',
      location: 'Bandra Reclamation Checkpoint',
      district: 'Mumbai',
      pipeline: 'YOLOv11-Base'
    },
    {
      id: 'NT-103',
      type: 'info',
      title: 'PDF Report Exported',
      message: 'Maintenance team generated and compiled NH-48 quarterly repair estimates document.',
      time: 'Yesterday at 17:30',
      dateGroup: 'Yesterday',
      unread: false,
      priority: 'Information',
      category: 'Reports',
      roadId: 'NH-48',
      location: 'Mumbai-Pune Expressway Section',
      district: 'Thane',
      pipeline: 'System Export'
    },
    {
      id: 'NT-104',
      type: 'warning',
      title: 'Camera CAM-04 Offline',
      message: 'Surveillance feed stream from sector 4 has been interrupted for more than 5 minutes.',
      time: 'Yesterday at 12:15',
      dateGroup: 'Yesterday',
      unread: false,
      priority: 'High',
      category: 'System',
      roadId: 'SH-4',
      location: 'CAM-04 Sector 4 Junction',
      district: 'Nagpur',
      pipeline: 'Hardware Watchdog'
    },
    {
      id: 'NT-109',
      type: 'danger',
      title: 'Severe Alligator Cracking',
      message: 'Widespread fatigue alligator cracking flagged on Pune-Solapur road segment (KM 118).',
      time: 'Yesterday at 09:00',
      dateGroup: 'Yesterday',
      unread: true,
      priority: 'Critical',
      category: 'Detection',
      roadId: 'NH-965',
      location: 'KM 118, Hadapsar Bypass',
      district: 'Pune',
      pipeline: 'YOLOv11-Heavy',
      thumbnailUrl: 'cracks_2'
    },
    {
      id: 'NT-106',
      type: 'warning',
      title: 'Distress Markers Verified',
      message: 'GIS specialist completed verification of 18 crack coordinates on SH-4 corridor.',
      time: '3 days ago',
      dateGroup: 'Last 7 Days',
      unread: false,
      priority: 'Medium',
      category: 'GIS',
      roadId: 'SH-4',
      location: 'Sector 2 verification zone',
      district: 'Nagpur',
      pipeline: 'GIS Linker'
    },
    {
      id: 'NT-108',
      type: 'info',
      title: 'Database Auto-Backup Sync',
      message: 'Core RoadVision system database full backup completed and synchronized with S3 bucket.',
      time: '5 days ago',
      dateGroup: 'Last 7 Days',
      unread: false,
      priority: 'Information',
      category: 'System',
      roadId: 'SYS-SRV',
      location: 'Primary Server Subnet',
      district: 'All',
      pipeline: 'Backup Service'
    },
    {
      id: 'NT-105',
      type: 'success',
      title: 'Work Order Closed',
      message: 'Maharashtra highway repair team completed sealing operations on Eastern Express cracks.',
      time: 'June 25, 2026',
      dateGroup: 'Earlier',
      unread: false,
      priority: 'Success',
      category: 'Maintenance',
      roadId: 'EEH-12',
      location: 'Ghatkopar flyover northbound lane',
      district: 'Mumbai',
      pipeline: 'Workforce Sync',
      assignedTo: 'Crew Bravo'
    }
  ]);

  // UI state hooks
  const [search, setSearch] = useState('');
  const [activeFilters, setActiveFilters] = useState({
    priority: 'All',
    category: 'All',
    status: 'All', // 'All', 'Unread', 'Read'
    district: 'All',
    road: 'All',
    pipeline: 'All'
  });
  
  // Date range filter
  const [dateRange, setDateRange] = useState('All');

  // Collapsible section headers state
  const [collapsedGroups, setCollapsedGroups] = useState<Record<string, boolean>>({
    'Today': false,
    'Yesterday': false,
    'Last 7 Days': false,
    'Earlier': false
  });

  // Selected single notification detail modal/drawer
  const [selectedNotif, setSelectedNotif] = useState<NotificationItem | null>(null);

  // Mark all read handler
  const handleMarkAllAsRead = () => {
    setNotifications(prev => prev.map(n => ({ ...n, unread: false })));
  };

  // Toggle read handler
  const handleToggleRead = (id: string) => {
    setNotifications(prev => prev.map(n => n.id === id ? { ...n, unread: !n.unread } : n));
    if (selectedNotif && selectedNotif.id === id) {
      setSelectedNotif(prev => prev ? { ...prev, unread: !prev.unread } : null);
    }
  };

  // Delete notification handler
  const handleDelete = (id: string) => {
    setNotifications(prev => prev.filter(n => n.id !== id));
    if (selectedNotif && selectedNotif.id === id) {
      setSelectedNotif(null);
    }
  };

  // Simulated assign handler
  const handleAssign = (id: string) => {
    const crewName = prompt("Assign alert to maintenance crew (e.g. Crew Alpha, Crew Bravo):", "Crew Alpha");
    if (crewName) {
      setNotifications(prev => prev.map(n => n.id === id ? { ...n, assignedTo: crewName, priority: 'Medium' } : n));
      alert(`Alert successfully assigned to ${crewName}.`);
    }
  };

  // Unread & critical calculations
  const unreadCount = notifications.filter(n => n.unread).length;
  const criticalCount = notifications.filter(n => n.priority === 'Critical').length;
  const todayCount = notifications.filter(n => n.dateGroup === 'Today').length;
  const resolvedCount = notifications.filter(n => n.priority === 'Success').length;

  const toggleGroupCollapsed = (group: string) => {
    setCollapsedGroups(prev => ({ ...prev, [group]: !prev[group] }));
  };

  // Handle chips search shortcuts
  const handleQuickChipFilter = (chip: string) => {
    if (chip === 'Critical') {
      setActiveFilters(prev => ({ ...prev, priority: prev.priority === 'Critical' ? 'All' : 'Critical' }));
    } else if (chip === 'Unread') {
      setActiveFilters(prev => ({ ...prev, status: prev.status === 'Unread' ? 'All' : 'Unread' }));
    } else if (chip === 'AI') {
      setActiveFilters(prev => ({ ...prev, category: prev.category === 'Detection' ? 'All' : 'Detection' }));
    } else if (chip === 'Maintenance') {
      setActiveFilters(prev => ({ ...prev, category: prev.category === 'Maintenance' ? 'All' : 'Maintenance' }));
    } else if (chip === 'Reports') {
      setActiveFilters(prev => ({ ...prev, category: prev.category === 'Reports' ? 'All' : 'Reports' }));
    } else if (chip === 'System') {
      setActiveFilters(prev => ({ ...prev, category: prev.category === 'System' ? 'All' : 'System' }));
    }
  };

  // Filtered list construction
  const filteredNotifications = useMemo(() => {
    return notifications.filter(notif => {
      // Search matches
      const matchesSearch = 
        notif.title.toLowerCase().includes(search.toLowerCase()) ||
        notif.message.toLowerCase().includes(search.toLowerCase()) ||
        (notif.roadId && notif.roadId.toLowerCase().includes(search.toLowerCase())) ||
        (notif.location && notif.location.toLowerCase().includes(search.toLowerCase()));

      if (!matchesSearch) return false;

      // Priority matches
      if (activeFilters.priority !== 'All' && notif.priority !== activeFilters.priority) {
        return false;
      }

      // Category matches
      if (activeFilters.category !== 'All' && notif.category !== activeFilters.category) {
        return false;
      }

      // Status read/unread matches
      if (activeFilters.status === 'Unread' && !notif.unread) return false;
      if (activeFilters.status === 'Read' && notif.unread) return false;

      // District matches
      if (activeFilters.district !== 'All' && notif.district !== activeFilters.district) {
        return false;
      }

      // Road matches
      if (activeFilters.road !== 'All' && notif.roadId !== activeFilters.road) {
        return false;
      }

      // Pipeline matches
      if (activeFilters.pipeline !== 'All' && notif.pipeline !== activeFilters.pipeline) {
        return false;
      }

      // Date range filter (Today/Yesterday)
      if (dateRange !== 'All' && notif.dateGroup !== dateRange) {
        return false;
      }

      return true;
    });
  }, [notifications, search, activeFilters, dateRange]);

  // Sidebar metrics mapping
  const sidebarMetrics = useMemo(() => {
    return {
      critical: filteredNotifications.filter(n => n.priority === 'Critical').length,
      unread: filteredNotifications.filter(n => n.unread).length,
      maintenance: filteredNotifications.filter(n => n.category === 'Maintenance').length,
      reports: filteredNotifications.filter(n => n.category === 'Reports').length,
      aiJobs: filteredNotifications.filter(n => n.category === 'Detection').length
    };
  }, [filteredNotifications]);

  // Donut/Category distribution data
  const categoryChartData = useMemo(() => {
    const counts: Record<string, number> = {
      Detection: 0,
      Maintenance: 0,
      Reports: 0,
      System: 0,
      GIS: 0,
      Uploads: 0
    };
    
    filteredNotifications.forEach(n => {
      if (counts[n.category] !== undefined) {
        counts[n.category]++;
      }
    });

    return Object.keys(counts).map(key => ({
      name: key,
      value: counts[key]
    })).filter(c => c.value > 0);
  }, [filteredNotifications]);

  // Resolution speed chart (synthetic data per category)
  const resolutionTimeData = [
    { name: 'Detection', hours: 1.5 },
    { name: 'Maintenance', hours: 4.2 },
    { name: 'Reports', hours: 0.1 },
    { name: 'System', hours: 0.5 },
    { name: 'GIS', hours: 2.8 },
    { name: 'Uploads', hours: 0.8 }
  ];

  // Notification Trend over past epochs (simulated trend)
  const trendChartData = [
    { name: '08:00', Alerts: 2, Detections: 4 },
    { name: '10:00', Alerts: 5, Detections: 8 },
    { name: '12:00', Alerts: 3, Detections: 6 },
    { name: '14:00', Alerts: 7, Detections: 12 },
    { name: '16:00', Alerts: 4, Detections: 9 },
    { name: '18:00', Alerts: 8, Detections: 15 },
    { name: '20:00', Alerts: todayCount, Detections: todayCount * 2 }
  ];

  const getPriorityColor = (priority: NotificationItem['priority']) => {
    switch (priority) {
      case 'Critical': return '#EF4444';
      case 'High': return '#F97316';
      case 'Medium': return '#F59E0B';
      case 'Information': return '#3B82F6';
      case 'Success': return '#10B981';
      default: return '#6B7280';
    }
  };

  const getCategoryIcon = (category: NotificationItem['category']) => {
    switch (category) {
      case 'Detection': return <ShieldAlert size={18} />;
      case 'Maintenance': return <Activity size={18} />;
      case 'Reports': return <FileText size={18} />;
      case 'System': return <SlidersHorizontal size={18} />;
      case 'GIS': return <MapPin size={18} />;
      case 'Uploads': return <CheckCircle2 size={18} />;
      default: return <Bell size={18} />;
    }
  };

  // Render collapsible sections
  const renderCollapsibleSection = (groupName: 'Today' | 'Yesterday' | 'Last 7 Days' | 'Earlier') => {
    const items = filteredNotifications.filter(n => n.dateGroup === groupName);
    if (items.length === 0) return null;

    const isCollapsed = collapsedGroups[groupName];

    return (
      <div className={`notif-collapsible-group ${isCollapsed ? 'collapsed' : ''}`}>
        <header className="group-header" onClick={() => toggleGroupCollapsed(groupName)}>
          <div className="group-header-left">
            {isCollapsed ? <ChevronDown size={18} /> : <ChevronUp size={18} />}
            <h3 className="group-title font-sans">{groupName}</h3>
            <span className="group-count">{items.length} events</span>
          </div>
          <div className="group-header-divider" />
        </header>

        {!isCollapsed && (
          <div className="group-cards-list">
            {items.map((item) => {
              const borderCol = getPriorityColor(item.priority);
              
              return (
                <div
                  key={item.id}
                  className={`notif-card-item hover-lift ${item.unread ? 'notif-card-item--unread' : ''}`}
                  style={{ borderLeft: `4px solid ${borderCol}` }}
                >
                  <div className="notif-card-body">
                    {/* Left Icon */}
                    <div
                      className="notif-card-icon-container"
                      style={{ color: borderCol, backgroundColor: `${borderCol}10` }}
                    >
                      {getCategoryIcon(item.category)}
                    </div>

                    {/* Middle details */}
                    <div className="notif-card-middle">
                      <div className="notif-card-title-row">
                        <h4 className="notif-title">{item.title}</h4>
                        <span className="notif-id font-mono">{item.id}</span>
                        {item.unread && <span className="unread-ping" />}
                      </div>

                      <p className="notif-message-text">{item.message}</p>

                      {/* Meta Tags Row */}
                      <div className="notif-card-tags">
                        {item.roadId && (
                          <span className="meta-tag font-mono">
                            🛣️ {item.roadId}
                          </span>
                        )}
                        {item.location && (
                          <span className="meta-tag">
                            📍 {item.location}
                          </span>
                        )}
                        {item.pipeline && (
                          <span className="meta-tag font-mono">
                            🤖 {item.pipeline}
                          </span>
                        )}
                        <span className="meta-tag">
                          ⏱️ {item.time}
                        </span>
                        {item.assignedTo && (
                          <span className="meta-tag crew-tag">
                            👷 {item.assignedTo}
                          </span>
                        )}
                      </div>
                    </div>

                    {/* Right action and priority column */}
                    <div className="notif-card-right">
                      <span
                        className="notif-priority-badge"
                        style={{ color: borderCol, borderColor: `${borderCol}30`, backgroundColor: `${borderCol}10` }}
                      >
                        {item.priority}
                      </span>

                      {/* Display thumbnail mock if pothole image */}
                      {item.thumbnailUrl && (
                        <div className="notif-thumbnail-mock" title="Anomalous Frame preview">
                          <div className="camera-grid-line" />
                          <ShieldAlert size={12} className="thumbnail-anomaly-icon" />
                        </div>
                      )}
                    </div>
                  </div>

                  {/* Actions footer bar */}
                  <div className="notif-card-action-bar">
                    <button className="card-action-btn" onClick={() => setSelectedNotif(item)}>
                      <Eye size={12} /> View Details
                    </button>
                    <button className="card-action-btn" onClick={() => handleAssign(item.id)}>
                      <UserPlus size={12} /> Assign
                    </button>
                    <button className="card-action-btn" onClick={() => handleToggleRead(item.id)}>
                      <Check size={12} /> {item.unread ? 'Mark Read' : 'Mark Unread'}
                    </button>
                    <button className="card-action-btn delete-btn" onClick={() => handleDelete(item.id)}>
                      <Trash2 size={12} /> Delete
                    </button>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>
    );
  };

  const PIE_COLORS = ['#C45C45', '#C87B35', '#D6A23A', '#6B88C7', '#7B8260', '#8FA06A'];

  return (
    <div className="operations-alert-center animate-fade-in">
      {/* 1. Page Header */}
      <header className="ops-header-panel">
        <div className="ops-header-title">
          <div className="ops-logo-icon animate-pulse">
            <Bell size={28} />
          </div>
          <div>
            <h1 className="bold-page-title">Notification Center</h1>
            <p className="light-secondary-text">
              Real-time AI alerts, operational events, maintenance updates, and system notifications.
            </p>
          </div>
        </div>

        <div className="ops-toolbar">
          <div className="ops-search-field">
            <input
              type="text"
              placeholder="Search notifications..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
          </div>

          <div className="ops-select-field">
            <Calendar size={15} />
            <select value={dateRange} onChange={(e) => setDateRange(e.target.value)}>
              <option value="All">All Time</option>
              <option value="Today">Today</option>
              <option value="Yesterday">Yesterday</option>
              <option value="Last 7 Days">Last 7 Days</option>
              <option value="Earlier">Earlier</option>
            </select>
          </div>

          <button className="ops-btn ops-btn--primary" onClick={handleMarkAllAsRead} disabled={unreadCount === 0}>
            <CheckCircle2 size={15} /> Mark All Read
          </button>

          <button className="ops-btn ops-btn--secondary" onClick={() => alert("Syncing operations feed... (Simulated)")}>
            <RefreshCw size={15} /> Refresh
          </button>
        </div>
      </header>

      {/* 2. KPI Summary Row */}
      <section className="ops-kpis-grid">
        <article className="premium-kpi-card premium-card">
          <div className="kpi-header-row">
            <div className="kpi-icon-container kpi-icon-container--criticaldistresses" style={{ backgroundColor: 'rgba(239, 68, 68, 0.1)' }}>
              <Bell size={18} style={{ color: '#EF4444' }} />
            </div>
            <span className="kpi-title-label">Unread Alerts</span>
          </div>
          <p className="kpi-value-num">{unreadCount}</p>
          <div className="kpi-card-footer">
            <div className="kpi-trend-group">
              <span className="trend-icon-arrow text-danger">↑</span>
              <span className="trend-badge-text text-danger font-semibold">{unreadCount > 0 ? '+4' : '0'}</span>
              <span className="comparison-lbl">active alerts</span>
            </div>
            <div className="kpi-sparkline">
              <svg width="60" height="24">
                <polyline fill="none" stroke="var(--danger)" strokeWidth="1.8" points="0,5 10,20 20,8 30,18 40,12 50,5 60,10" />
              </svg>
            </div>
          </div>
        </article>

        <article className="premium-kpi-card premium-card">
          <div className="kpi-header-row">
            <div className="kpi-icon-container" style={{ backgroundColor: 'rgba(239,68,68,0.1)' }}>
              <ShieldAlert size={18} style={{ color: '#EF4444' }} />
            </div>
            <span className="kpi-title-label">Critical Alerts</span>
          </div>
          <p className="kpi-value-num">{criticalCount}</p>
          <div className="kpi-card-footer">
            <div className="kpi-trend-group">
              <span className="trend-icon-arrow text-danger">↑</span>
              <span className="trend-badge-text text-danger font-semibold">Critical</span>
              <span className="comparison-lbl">immediate attention</span>
            </div>
            <div className="kpi-sparkline">
              <svg width="60" height="24">
                <polyline fill="none" stroke="#EF4444" strokeWidth="1.8" points="0,2 10,8 20,12 30,5 40,18 50,15 60,2" />
              </svg>
            </div>
          </div>
        </article>

        <article className="premium-kpi-card premium-card">
          <div className="kpi-header-row">
            <div className="kpi-icon-container" style={{ backgroundColor: 'rgba(59, 130, 246, 0.1)' }}>
              <Activity size={18} style={{ color: '#3B82F6' }} />
            </div>
            <span className="kpi-title-label">Today's Notifications</span>
          </div>
          <p className="kpi-value-num">{todayCount}</p>
          <div className="kpi-card-footer">
            <div className="kpi-trend-group">
              <span className="trend-icon-arrow text-success">↑</span>
              <span className="trend-badge-text text-success font-semibold">12%</span>
              <span className="comparison-lbl">vs yesterday</span>
            </div>
            <div className="kpi-sparkline">
              <svg width="60" height="24">
                <polyline fill="none" stroke="var(--accent-blue)" strokeWidth="1.8" points="0,20 10,12 20,18 30,10 40,15 50,3 60,6" />
              </svg>
            </div>
          </div>
        </article>

        <article className="premium-kpi-card premium-card">
          <div className="kpi-header-row">
            <div className="kpi-icon-container" style={{ backgroundColor: 'rgba(16, 185, 129, 0.1)' }}>
              <CheckCircle2 size={18} style={{ color: '#10B981' }} />
            </div>
            <span className="kpi-title-label">Resolved Events</span>
          </div>
          <p className="kpi-value-num">{resolvedCount}</p>
          <div className="kpi-card-footer">
            <div className="kpi-trend-group">
              <span className="trend-icon-arrow text-success">↑</span>
              <span className="trend-badge-text text-success font-semibold">100%</span>
              <span className="comparison-lbl">resolved status</span>
            </div>
            <div className="kpi-sparkline">
              <svg width="60" height="24">
                <polyline fill="none" stroke="var(--success)" strokeWidth="1.8" points="0,18 10,15 20,20 30,12 40,8 50,5 60,2" />
              </svg>
            </div>
          </div>
        </article>
      </section>

      {/* 3. Sticky Filter & Chips Bar */}
      <nav className="ops-filters-bar sticky-filter">
        <div className="filters-label">
          <Filter size={14} />
          <span>Filter Incident Streams</span>
        </div>

        <div className="filters-selectors">
          <select
            value={activeFilters.priority}
            onChange={(e) => setActiveFilters(prev => ({ ...prev, priority: e.target.value }))}
          >
            <option value="All">Priority: All</option>
            <option value="Critical">Critical</option>
            <option value="High">High</option>
            <option value="Medium">Medium</option>
            <option value="Information">Information</option>
            <option value="Success">Success</option>
          </select>

          <select
            value={activeFilters.category}
            onChange={(e) => setActiveFilters(prev => ({ ...prev, category: e.target.value }))}
          >
            <option value="All">Category: All</option>
            <option value="Detection">Detection</option>
            <option value="Maintenance">Maintenance</option>
            <option value="Reports">Reports</option>
            <option value="System">System</option>
            <option value="GIS">GIS</option>
            <option value="Uploads">Uploads</option>
          </select>

          <select
            value={activeFilters.status}
            onChange={(e) => setActiveFilters(prev => ({ ...prev, status: e.target.value }))}
          >
            <option value="All">Status: All</option>
            <option value="Unread">Unread</option>
            <option value="Read">Read</option>
          </select>

          <select
            value={activeFilters.district}
            onChange={(e) => setActiveFilters(prev => ({ ...prev, district: e.target.value }))}
          >
            <option value="All">District: All</option>
            <option value="Mumbai">Mumbai</option>
            <option value="Pune">Pune</option>
            <option value="Nagpur">Nagpur</option>
            <option value="Thane">Thane</option>
          </select>

          <select
            value={activeFilters.road}
            onChange={(e) => setActiveFilters(prev => ({ ...prev, road: e.target.value }))}
          >
            <option value="All">Road: All</option>
            <option value="NH-48">NH-48</option>
            <option value="SH-4">SH-4</option>
            <option value="WEH-01">WEH-01</option>
          </select>

          <select
            value={activeFilters.pipeline}
            onChange={(e) => setActiveFilters(prev => ({ ...prev, pipeline: e.target.value }))}
          >
            <option value="All">Pipeline: All</option>
            <option value="YOLOv11-Heavy">YOLOv11-Heavy</option>
            <option value="YOLOv11-Base">YOLOv11-Base</option>
          </select>
        </div>

        {/* Quick Chips Row */}
        <div className="filters-chips">
          <button
            className={`chip-btn ${activeFilters.priority === 'Critical' ? 'active' : ''}`}
            onClick={() => handleQuickChipFilter('Critical')}
          >
            🚨 Critical Alerts
          </button>
          <button
            className={`chip-btn ${activeFilters.status === 'Unread' ? 'active' : ''}`}
            onClick={() => handleQuickChipFilter('Unread')}
          >
            📬 Unread Tray
          </button>
          <button
            className={`chip-btn ${activeFilters.category === 'Detection' ? 'active' : ''}`}
            onClick={() => handleQuickChipFilter('AI')}
          >
            🤖 AI Tagged Detections
          </button>
          <button
            className={`chip-btn ${activeFilters.category === 'Maintenance' ? 'active' : ''}`}
            onClick={() => handleQuickChipFilter('Maintenance')}
          >
            👷 Workforce Updates
          </button>
          <button
            className={`chip-btn ${activeFilters.category === 'Reports' ? 'active' : ''}`}
            onClick={() => handleQuickChipFilter('Reports')}
          >
            📄 PDF Summary Logs
          </button>
          <button
            className={`chip-btn ${activeFilters.category === 'System' ? 'active' : ''}`}
            onClick={() => handleQuickChipFilter('System')}
          >
            ⚙️ Hardware/Backup
          </button>

          <button
            className="chip-btn chip-btn--clear"
            onClick={() => {
              setActiveFilters({
                priority: 'All',
                category: 'All',
                status: 'All',
                district: 'All',
                road: 'All',
                pipeline: 'All'
              });
              setSearch('');
              setDateRange('All');
            }}
          >
            Clear Filters
          </button>
        </div>
      </nav>

      {/* 4. Split 70/30 Content Area */}
      <div className="ops-split-grid">
        {/* Left Column (70%): Notification Feed */}
        <section className="ops-feed-container premium-card">
          <div className="section-header">
            <div className="section-title-group">
              <Bell size={18} style={{ color: 'var(--accent-blue)' }} />
              <h2 className="medium-section-title">Incident Alert Feed</h2>
            </div>
            <span className="logs-count-badge">
              {filteredNotifications.length} of {notifications.length} alerts visible
            </span>
          </div>

          {filteredNotifications.length === 0 ? (
            <div className="feed-empty-tray">
              <Bell size={40} style={{ opacity: 0.3 }} />
              <p>No operational incidents match your filters.</p>
            </div>
          ) : (
            <div className="feed-chronological-sections">
              {renderCollapsibleSection('Today')}
              {renderCollapsibleSection('Yesterday')}
              {renderCollapsibleSection('Last 7 Days')}
              {renderCollapsibleSection('Earlier')}
            </div>
          )}
        </section>

        {/* Right Column (30%): Incident Widgets */}
        <aside className="ops-sidebar-column">
          {/* Quick Summary Panel */}
          <article className="ops-sidebar-widget premium-card">
            <h3 className="widget-title">Quick Incident Summary</h3>
            <div className="incident-summary-list">
              <div className="summary-row">
                <span className="summary-lbl">⚠️ Critical Incidents</span>
                <span className="summary-val text-bold font-mono" style={{ color: '#EF4444' }}>{sidebarMetrics.critical}</span>
              </div>
              <div className="summary-row">
                <span className="summary-lbl">📬 Unread Messages</span>
                <span className="summary-val text-bold font-mono" style={{ color: 'var(--accent-blue)' }}>{sidebarMetrics.unread}</span>
              </div>
              <div className="summary-row">
                <span className="summary-lbl">🔧 Maintenance Tasks</span>
                <span className="summary-val text-bold font-mono">{sidebarMetrics.maintenance}</span>
              </div>
              <div className="summary-row">
                <span className="summary-lbl">📄 PDF & Excel Reports</span>
                <span className="summary-val text-bold font-mono">{sidebarMetrics.reports}</span>
              </div>
              <div className="summary-row">
                <span className="summary-lbl">🤖 Active AI Pipelines</span>
                <span className="summary-val text-bold font-mono">{sidebarMetrics.aiJobs}</span>
              </div>
            </div>
          </article>

          {/* Donut Chart Category Distribution */}
          <article className="ops-sidebar-widget premium-card">
            <h3 className="widget-title">Alert Categories</h3>
            {categoryChartData.length === 0 ? (
              <div className="chart-empty-state">No category matches.</div>
            ) : (
              <div className="widget-chart-wrapper" style={{ height: '170px' }}>
                <ResponsiveContainer width="100%" height="100%">
                  <PieChart>
                    <Pie
                      data={categoryChartData}
                      cx="50%"
                      cy="50%"
                      innerRadius={45}
                      outerRadius={65}
                      paddingAngle={3}
                      dataKey="value"
                    >
                      {categoryChartData.map((_, index) => (
                        <Cell key={`cell-${index}`} fill={PIE_COLORS[index % PIE_COLORS.length]} />
                      ))}
                    </Pie>
                    <Tooltip contentStyle={{ background: '#FFFFFF', border: '1px solid var(--card-border)', borderRadius: '8px' }} />
                  </PieChart>
                </ResponsiveContainer>
              </div>
            )}
            <div className="chart-legend-grid">
              {categoryChartData.map((item, idx) => (
                <div key={idx} className="legend-chip-item">
                  <span className="legend-dot" style={{ backgroundColor: PIE_COLORS[idx % PIE_COLORS.length] }} />
                  <span className="legend-label">
                    {item.name}: <strong>{item.value}</strong>
                  </span>
                </div>
              ))}
            </div>
          </article>

          {/* Recent Operations Activity (5 events) */}
          <article className="ops-sidebar-widget premium-card">
            <h3 className="widget-title">Recent Event Log</h3>
            <div className="recent-log-activities">
              {notifications.slice(0, 5).map((notif, idx) => (
                <div key={idx} className="recent-log-strip">
                  <div className="strip-indicator" style={{ backgroundColor: getPriorityColor(notif.priority) }} />
                  <div className="strip-info">
                    <span className="strip-title">{notif.title}</span>
                    <span className="strip-time">{notif.time}</span>
                  </div>
                </div>
              ))}
            </div>
          </article>
        </aside>
      </div>

      {/* 5. Detailed Notification Drawer / Modal Overlay */}
      {selectedNotif && (
        <div className="ops-detail-modal-overlay animate-fade-in" onClick={() => setSelectedNotif(null)}>
          <div className="ops-detail-modal-container premium-card" onClick={(e) => e.stopPropagation()}>
            <header className="modal-header">
              <div className="modal-title-group">
                <div className="modal-icon-badge" style={{ backgroundColor: `${getPriorityColor(selectedNotif.priority)}15`, color: getPriorityColor(selectedNotif.priority) }}>
                  {getCategoryIcon(selectedNotif.category)}
                </div>
                <div>
                  <h3 className="modal-title">{selectedNotif.title}</h3>
                  <span className="modal-subtitle font-mono">{selectedNotif.id} &bull; Category: {selectedNotif.category}</span>
                </div>
              </div>
              <button className="modal-close-btn" onClick={() => setSelectedNotif(null)}>
                <X size={18} />
              </button>
            </header>

            <div className="modal-body-content">
              {/* Highlight bar */}
              <div className="modal-alert-message-box" style={{ borderLeft: `4px solid ${getPriorityColor(selectedNotif.priority)}` }}>
                <p className="modal-message-text">{selectedNotif.message}</p>
              </div>

              {/* Styled camera image simulation if detection */}
              {selectedNotif.thumbnailUrl && (
                <div className="modal-frame-simulation">
                  <div className="overlay-camera-stamp">
                    <span>CAM-04 FEED</span>
                    <span>1080P @ 30FPS</span>
                  </div>
                  <div className="simulation-distress-marker animate-ping" />
                  <div className="simulation-bounding-box">
                    <span className="tag-box font-mono">POTHOLE 92.4%</span>
                  </div>
                </div>
              )}

              {/* Metadata details table */}
              <div className="modal-metadata-grid">
                <div className="meta-box">
                  <span className="lbl">Priority Class</span>
                  <span className="val text-bold" style={{ color: getPriorityColor(selectedNotif.priority) }}>
                    {selectedNotif.priority}
                  </span>
                </div>
                <div className="meta-box">
                  <span className="lbl">District / Jurisdiction</span>
                  <span className="val">{selectedNotif.district || 'Not Stated'}</span>
                </div>
                <div className="meta-box">
                  <span className="lbl">Road Corridor ID</span>
                  <span className="val font-mono">{selectedNotif.roadId || 'N/A'}</span>
                </div>
                <div className="meta-box">
                  <span className="lbl">Precision GPS Coordinates</span>
                  <span className="val">{selectedNotif.location || 'N/A'}</span>
                </div>
                <div className="meta-box">
                  <span className="lbl">Inference Pipeline Source</span>
                  <span className="val font-mono">{selectedNotif.pipeline || 'N/A'}</span>
                </div>
                <div className="meta-box">
                  <span className="lbl">Alert Trigger Timestamp</span>
                  <span className="val">{selectedNotif.time}</span>
                </div>
              </div>
            </div>

            <footer className="modal-footer-actions">
              <button
                className="modal-btn modal-btn--secondary"
                onClick={() => {
                  handleToggleRead(selectedNotif.id);
                }}
              >
                {selectedNotif.unread ? 'Dismiss & Mark Read' : 'Mark Unread'}
              </button>

              <button
                className="modal-btn modal-btn--secondary"
                onClick={() => {
                  handleAssign(selectedNotif.id);
                  setSelectedNotif(null);
                }}
              >
                👷 Dispatch Crew
              </button>

              <button
                className="modal-btn modal-btn--danger"
                onClick={() => {
                  handleDelete(selectedNotif.id);
                  setSelectedNotif(null);
                }}
              >
                <Trash2 size={13} /> Purge Record
              </button>

              <button className="modal-btn modal-btn--close" onClick={() => setSelectedNotif(null)}>
                Close
              </button>
            </footer>
          </div>
        </div>
      )}

      {/* 6. Activity Timeline Section */}
      <section className="ops-activity-timeline-section premium-card">
        <div className="section-header">
          <div className="section-title-group">
            <Activity size={18} style={{ color: 'var(--accent-blue)' }} />
            <h2 className="medium-section-title">Incident Mitigation Timeline</h2>
          </div>
          <span className="logs-count-badge">Active operations sequence</span>
        </div>

        <div className="timeline-flow-box">
          <div className="timeline-vertical-line" />
          {[
            { title: 'Pothole Distress Flagged', desc: 'AI engine detected high-severity distress index #101 on NH-48.', time: '10m ago', icon: <ShieldAlert size={14} />, color: '#EF4444' },
            { title: 'Inference Run Finished', desc: 'surveillance_cam_mumbai.mp4 parsed; catalogued coordinates into GIS dashboard.', time: '2h ago', icon: <Layers size={14} />, color: '#3B82F6' },
            { title: 'PDF Summary Generated', desc: 'System automatically compiled quarterly estimates report file for review.', time: 'Yesterday', icon: <FileText size={14} />, color: '#8B5CF6' },
            { title: 'Camera CAM-04 Recovery Scheduled', desc: 'Hardware monitoring pinged technician; dispatch in sector 4 requested.', time: 'Yesterday', icon: <Camera size={14} />, color: '#F97316' },
            { title: 'Patching Repair Completed', desc: 'Crew Alpha closed maintenance order #4582 on Eastern Express Highway.', time: '5 days ago', icon: <CheckCircle2 size={14} />, color: '#10B981' }
          ].map((op, idx) => (
            <div key={idx} className="timeline-flow-node">
              <div className="node-icon-wrapper" style={{ backgroundColor: op.color }}>
                {op.icon}
              </div>
              <div className="node-details">
                <span className="node-title font-semibold">{op.title}</span>
                <span className="node-desc">{op.desc}</span>
              </div>
              <span className="node-time font-mono">{op.time}</span>
            </div>
          ))}
        </div>
      </section>

      {/* 7. Bottom Analytics Section */}
      <footer className="ops-analytics-footer-grid">
        <article className="ops-analytics-chart-card premium-card">
          <h3 className="widget-title">Alert Rate Trend</h3>
          <p className="widget-subtitle">Line graph of hourly logged incident alerts</p>
          <div className="chart-container-box">
            <ResponsiveContainer width="100%" height="100%">
              <LineChart data={trendChartData} margin={{ top: 10, right: 10, left: -25, bottom: 0 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="#F1F5F9" />
                <XAxis dataKey="name" stroke="#94A3B8" fontSize={11} />
                <YAxis stroke="#94A3B8" fontSize={11} allowDecimals={false} />
                <Tooltip contentStyle={{ background: '#FFFFFF', border: '1px solid var(--card-border)', borderRadius: '8px' }} />
                <Line type="monotone" dataKey="Alerts" stroke="#EF4444" strokeWidth={2} activeDot={{ r: 6 }} />
                <Line type="monotone" dataKey="Detections" stroke="#3B82F6" strokeWidth={2} />
              </LineChart>
            </ResponsiveContainer>
          </div>
        </article>

        <article className="ops-analytics-chart-card premium-card">
          <h3 className="widget-title">Distribution Ratio</h3>
          <p className="widget-subtitle">Relative classification of operations events</p>
          <div className="chart-container-box flex-center">
            <div style={{ width: '100%', height: '150px' }}>
              <ResponsiveContainer width="100%" height="100%">
                <PieChart>
                  <Pie
                    data={categoryChartData}
                    cx="50%"
                    cy="50%"
                    innerRadius={45}
                    outerRadius={60}
                    paddingAngle={3}
                    dataKey="value"
                  >
                    {categoryChartData.map((_, index) => (
                      <Cell key={`cell-${index}`} fill={PIE_COLORS[index % PIE_COLORS.length]} />
                    ))}
                  </Pie>
                  <Tooltip contentStyle={{ background: '#FFFFFF', border: '1px solid var(--card-border)', borderRadius: '8px' }} />
                </PieChart>
              </ResponsiveContainer>
            </div>
            <div className="donut-legend-list">
              {categoryChartData.slice(0, 3).map((item, idx) => (
                <div key={idx} className="legend-chip-item">
                  <span className="legend-dot" style={{ backgroundColor: PIE_COLORS[idx % PIE_COLORS.length] }} />
                  <span className="legend-label">
                    {item.name}: <strong>{item.value}</strong>
                  </span>
                </div>
              ))}
            </div>
          </div>
        </article>

        <article className="ops-analytics-chart-card premium-card">
          <h3 className="widget-title">Average Mitigation Time</h3>
          <p className="widget-subtitle">Standard resolution time (in hours) per category</p>
          <div className="chart-container-box">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={resolutionTimeData} margin={{ top: 10, right: 10, left: -25, bottom: 0 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="#F1F5F9" vertical={false} />
                <XAxis dataKey="name" stroke="#94A3B8" fontSize={9} interval={0} tickLine={false} />
                <YAxis stroke="#94A3B8" fontSize={11} unit="h" />
                <Tooltip contentStyle={{ background: '#FFFFFF', border: '1px solid var(--card-border)', borderRadius: '8px' }} />
                <Bar dataKey="hours" fill="#10B981" radius={[4, 4, 0, 0]} barSize={14} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </article>
      </footer>
    </div>
  );
}
