import { useState, useMemo } from 'react';
import {
  ClipboardList,
  Wrench,
  CheckCircle2,
  IndianRupee,
  Users,
  Clock,
  Search,
  Plus,
  Download,
  ChevronLeft,
  ChevronRight,
  AlertTriangle
} from 'lucide-react';
import { ResponsiveContainer, BarChart, Bar, XAxis, Tooltip, PieChart, Pie, Cell } from 'recharts';
import {
  MOCK_WORK_ORDERS,
  MOCK_TEAMS,
  MOCK_UPCOMING_REPAIRS,
  MOCK_REPAIR_PROGRESS,
} from '../../data/maintenanceMockData';
import './MaintenanceDashboard.css';

const STATUS_COLORS: Record<string, string> = {
  Pending: '#6B88C7',
  Assigned: '#6B88C7',
  'In Progress': '#D6A23A',
  Completed: '#8FA06A',
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

export default function MaintenanceDashboard() {
  // Table search & filter states
  const [searchQuery, setSearchQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState('All');
  const [priorityFilter, setPriorityFilter] = useState('All');
  const [teamFilter, setTeamFilter] = useState('All');
  const [currentPage, setCurrentPage] = useState(1);
  const itemsPerPage = 5;

  // KPI Calculations
  const kpis = useMemo(() => {
    const activeWorkOrders = MOCK_WORK_ORDERS.filter((o) => o.status !== 'Completed').length;
    const repairsInProgress = MOCK_WORK_ORDERS.filter((o) => o.status === 'In Progress').length;
    const completedRepairs = MOCK_WORK_ORDERS.filter((o) => o.status === 'Completed').length;
    const totalMaintenanceCost = MOCK_WORK_ORDERS.reduce((sum, o) => sum + o.estimatedCost, 0);
    const availableTeams = MOCK_TEAMS.filter(t => t.status.toLowerCase() === 'available').length;

    return {
      activeWorkOrders,
      repairsInProgress,
      completedRepairs,
      totalMaintenanceCost,
      availableTeams,
      averageRepairTime: '1.8 days',
    };
  }, []);

  // Filter Table List
  const filteredOrders = useMemo(() => {
    return MOCK_WORK_ORDERS.filter((order) => {
      const query = searchQuery.toLowerCase();
      const matchesSearch =
        order.orderId.toLowerCase().includes(query) ||
        order.roadId.toLowerCase().includes(query) ||
        order.location.toLowerCase().includes(query) ||
        order.assignedTeam.toLowerCase().includes(query);
      const matchesStatus = statusFilter === 'All' || order.status === statusFilter;
      const matchesPriority = priorityFilter === 'All' || order.priority === priorityFilter;
      const matchesTeam = teamFilter === 'All' || order.assignedTeam === teamFilter;
      return matchesSearch && matchesStatus && matchesPriority && matchesTeam;
    });
  }, [searchQuery, statusFilter, priorityFilter, teamFilter]);

  // Paginated Table items
  const totalPages = Math.max(1, Math.ceil(filteredOrders.length / itemsPerPage));
  const paginatedOrders = useMemo(() => {
    const start = (currentPage - 1) * itemsPerPage;
    return filteredOrders.slice(start, start + itemsPerPage);
  }, [filteredOrders, currentPage]);

  const handleResetFilters = () => {
    setSearchQuery('');
    setStatusFilter('All');
    setPriorityFilter('All');
    setTeamFilter('All');
    setCurrentPage(1);
  };

  // Recharts donut chart calculation
  const statusChartData = useMemo(() => {
    const counts: Record<string, number> = { Pending: 0, Assigned: 0, 'In Progress': 0, Completed: 0 };
    MOCK_WORK_ORDERS.forEach((o) => {
      counts[o.status] = (counts[o.status] ?? 0) + 1;
    });
    return Object.entries(counts).map(([name, value]) => ({
      name,
      value,
      color: STATUS_COLORS[name] ?? '#94a3b8',
    }));
  }, []);

  const priorityBreakdown = useMemo(() => {
    const counts: Record<string, number> = { Critical: 0, High: 0, Medium: 0, Low: 0 };
    MOCK_WORK_ORDERS.forEach((o) => {
      counts[o.priority] = (counts[o.priority] ?? 0) + 1;
    });
    return Object.entries(counts).map(([name, value]) => ({
      name,
      value,
      color: PRIORITY_COLORS[name] ?? '#94a3b8',
    }));
  }, []);

  const monthlyCompletedData = useMemo(() => {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
    const base = [18, 24, 31, 38, 45, kpis.completedRepairs + 40];
    return months.map((month, i) => ({
      month,
      completed: base[i],
    }));
  }, [kpis.completedRepairs]);

  return (
    <div className="mnt-dash animate-fade-in" aria-label="Maintenance Operations Center">
      <header className="mnt-dash__header" style={{ marginBottom: '4px' }}>
        <h1 className="bold-page-title" style={{ fontSize: '32px' }}>Maintenance Operations Center</h1>
        <p className="light-secondary-text" style={{ fontSize: '14px' }}>Manage repair workflows, maintenance teams, schedules and repair progress.</p>
      </header>

      {/* KPI Summary Row (6 columns) */}
      <section className="mnt-dash__kpi-grid" aria-label="Maintenance Statistics Overview">
        <div className="premium-card">
          <div className="card-header-with-actions" style={{ borderBottom: 'none', marginBottom: '4px', padding: 0 }}>
            <span style={{ fontSize: '11px', color: 'var(--secondary-text)', fontWeight: 600, textTransform: 'uppercase' }}>Active Work Orders</span>
            <ClipboardList size={16} style={{ color: 'var(--accent-blue)' }} />
          </div>
          <span className="font-mono" style={{ fontSize: '24px', fontWeight: 700 }}>{kpis.activeWorkOrders}</span>
        </div>

        <div className="premium-card">
          <div className="card-header-with-actions" style={{ borderBottom: 'none', marginBottom: '4px', padding: 0 }}>
            <span style={{ fontSize: '11px', color: 'var(--secondary-text)', fontWeight: 600, textTransform: 'uppercase' }}>Repairs In Progress</span>
            <Wrench size={16} style={{ color: 'var(--warning)' }} />
          </div>
          <span className="font-mono" style={{ fontSize: '24px', fontWeight: 700, color: 'var(--warning)' }}>{kpis.repairsInProgress}</span>
        </div>

        <div className="premium-card">
          <div className="card-header-with-actions" style={{ borderBottom: 'none', marginBottom: '4px', padding: 0 }}>
            <span style={{ fontSize: '11px', color: 'var(--secondary-text)', fontWeight: 600, textTransform: 'uppercase' }}>Completed Repairs</span>
            <CheckCircle2 size={16} style={{ color: 'var(--success)' }} />
          </div>
          <span className="font-mono" style={{ fontSize: '24px', fontWeight: 700, color: 'var(--success)' }}>{kpis.completedRepairs}</span>
        </div>

        <div className="premium-card">
          <div className="card-header-with-actions" style={{ borderBottom: 'none', marginBottom: '4px', padding: 0 }}>
            <span style={{ fontSize: '11px', color: 'var(--secondary-text)', fontWeight: 600, textTransform: 'uppercase' }}>Total Maintenance Cost</span>
            <IndianRupee size={16} style={{ color: 'var(--accent-blue)' }} />
          </div>
          <span className="font-mono" style={{ fontSize: '24px', fontWeight: 700 }}>{formatCost(kpis.totalMaintenanceCost)}</span>
        </div>

        <div className="premium-card">
          <div className="card-header-with-actions" style={{ borderBottom: 'none', marginBottom: '4px', padding: 0 }}>
            <span style={{ fontSize: '11px', color: 'var(--secondary-text)', fontWeight: 600, textTransform: 'uppercase' }}>Available Teams</span>
            <Users size={16} style={{ color: 'var(--success)' }} />
          </div>
          <span className="font-mono" style={{ fontSize: '24px', fontWeight: 700, color: 'var(--success)' }}>{kpis.availableTeams}</span>
        </div>

        <div className="premium-card">
          <div className="card-header-with-actions" style={{ borderBottom: 'none', marginBottom: '4px', padding: 0 }}>
            <span style={{ fontSize: '11px', color: 'var(--secondary-text)', fontWeight: 600, textTransform: 'uppercase' }}>Average Repair Time</span>
            <Clock size={16} style={{ color: 'var(--accent-blue)' }} />
          </div>
          <span className="font-mono" style={{ fontSize: '24px', fontWeight: 700 }}>{kpis.averageRepairTime}</span>
        </div>
      </section>

      {/* Main Workspace: Left (70%) Table | Right (30%) Statistics */}
      <div className="mnt-dash__grid-row mnt-dash__grid-row--70-30">
        {/* Left Side: Work Orders table */}
        <div className="premium-card" style={{ display: 'flex', flexDirection: 'column' }}>
          <div className="card-header-with-actions" style={{ borderBottom: 'none', marginBottom: '14px' }}>
            <h2 className="medium-section-title" style={{ fontSize: '15px' }}>Active Work Orders Registry</h2>
            <div style={{ display: 'flex', gap: '8px' }}>
              <button className="btn-control" style={{ fontSize: '12px', display: 'flex', alignItems: 'center', gap: '6px' }} onClick={() => alert("Work orders export triggered successfully.")}>
                <Download size={13} />
                <span>Export</span>
              </button>
              <button className="btn-report-run font-semibold" style={{ fontSize: '12px', display: 'flex', alignItems: 'center', gap: '6px' }} onClick={() => alert("New Work order request wizard launched.")}>
                <Plus size={13} />
                <span>New Work Order</span>
              </button>
            </div>
          </div>

          {/* Search and Filters Toolbar */}
          <div style={{ display: 'flex', gap: '10px', flexWrap: 'wrap', marginBottom: '16px', alignItems: 'center', background: 'var(--primary-bg)', padding: '10px 14px', borderRadius: 'var(--radius-md)', border: '1px solid var(--card-border)' }}>
            <div style={{ flex: 1.5, position: 'relative', minWidth: '150px' }}>
              <Search size={14} style={{ position: 'absolute', left: '10px', top: '10px', color: 'var(--secondary-text)' }} />
              <input 
                type="text" 
                placeholder="Search Orders, Roads..." 
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                style={{ width: '100%', paddingLeft: '32px', height: '34px', border: '1px solid var(--card-border)', background: 'white', borderRadius: '6px', fontSize: '12px' }}
              />
            </div>
            
            <select 
              value={statusFilter} 
              onChange={(e) => setStatusFilter(e.target.value)}
              aria-label="Filter status dropdown"
              style={{ height: '34px', padding: '0 8px', border: '1px solid var(--card-border)', background: 'white', borderRadius: '6px', fontSize: '12px', minWidth: '100px' }}
            >
              <option value="All">All Statuses</option>
              <option value="Pending">Pending</option>
              <option value="Assigned">Assigned</option>
              <option value="In Progress">In Progress</option>
              <option value="Completed">Completed</option>
            </select>

            <select 
              value={priorityFilter} 
              onChange={(e) => setPriorityFilter(e.target.value)}
              aria-label="Filter priority dropdown"
              style={{ height: '34px', padding: '0 8px', border: '1px solid var(--card-border)', background: 'white', borderRadius: '6px', fontSize: '12px', minWidth: '100px' }}
            >
              <option value="All">All Priorities</option>
              <option value="Critical">Critical</option>
              <option value="High">High</option>
              <option value="Medium">Medium</option>
              <option value="Low">Low</option>
            </select>

            <button className="btn-control" style={{ height: '34px', padding: '0 12px', fontSize: '12px' }} onClick={handleResetFilters}>
              Reset
            </button>
          </div>

          {/* Table list */}
          <div className="table-responsive" style={{ height: 'auto', overflowY: 'visible' }}>
            <table className="enterprise-table">
              <thead>
                <tr>
                  <th>Order ID</th>
                  <th>Road</th>
                  <th>Location</th>
                  <th>Distress Type</th>
                  <th>Priority</th>
                  <th>Assigned Team</th>
                  <th>Status</th>
                  <th>Due Date</th>
                </tr>
              </thead>
              <tbody>
                {paginatedOrders.length === 0 ? (
                  <tr>
                    <td colSpan={8} style={{ textAlign: 'center', color: 'var(--secondary-text)', padding: '24px' }}>No active work orders match your search criteria.</td>
                  </tr>
                ) : (
                  paginatedOrders.map((order) => (
                    <tr key={order.orderId}>
                      <td>
                        <span className="font-mono font-bold" style={{ fontSize: '12px' }}>{order.orderId}</span>
                      </td>
                      <td>
                        <span className="font-mono font-bold">{order.roadId}</span>
                      </td>
                      <td>
                        <span style={{ fontSize: '12px', color: 'var(--secondary-text)' }} title={order.location}>{order.location}</span>
                      </td>
                      <td>
                        <span className="font-semibold">{order.distressType}</span>
                      </td>
                      <td>
                        <span className={`status-pill badge-${order.priority.toLowerCase()}`}>{order.priority.toUpperCase()}</span>
                      </td>
                      <td>
                        <span className="font-semibold" style={{ fontSize: '12px' }}>{order.assignedTeam}</span>
                      </td>
                      <td>
                        <span className={`status-pill status-pill--${order.status.toLowerCase().replace(/\s/g, '')}`} style={{ textTransform: 'capitalize', fontWeight: 600 }}>
                          {order.status}
                        </span>
                      </td>
                      <td>
                        <span className="font-mono" style={{ fontSize: '12px', color: 'var(--secondary-text)' }}>{order.dueDate}</span>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>

          {/* Paginator */}
          {filteredOrders.length > 0 && (
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderTop: '1px solid var(--card-border)', paddingTop: '14px', marginTop: 'auto' }}>
              <span style={{ fontSize: '12px', color: 'var(--secondary-text)' }}>
                Showing <strong>{((currentPage - 1) * itemsPerPage) + 1}</strong> to <strong>{Math.min(currentPage * itemsPerPage, filteredOrders.length)}</strong> of <strong>{filteredOrders.length}</strong> entries
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

        {/* Right Side: Maintenance Statistics card */}
        <div className="premium-card" style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
          <div className="card-header-with-actions" style={{ borderBottom: 'none', padding: 0 }}>
            <h2 className="medium-section-title" style={{ fontSize: '15px' }}>Maintenance Statistics</h2>
          </div>

          {/* Pie Chart / Donut Distribution */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
            <span style={{ fontSize: '10px', color: 'var(--secondary-text)', fontWeight: 600, textTransform: 'uppercase' }}>Status Distribution</span>
            <div style={{ height: '140px' }}>
              <ResponsiveContainer width="100%" height="100%">
                <PieChart>
                  <Pie
                    data={statusChartData}
                    cx="50%"
                    cy="50%"
                    innerRadius={36}
                    outerRadius={54}
                    paddingAngle={3}
                    dataKey="value"
                  >
                    {statusChartData.map((entry) => (
                      <Cell key={entry.name} fill={entry.color} />
                    ))}
                  </Pie>
                  <Tooltip />
                </PieChart>
              </ResponsiveContainer>
            </div>
            {/* Custom chart legend */}
            <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap', justifyContent: 'center', fontSize: '10px' }}>
              {statusChartData.map(e => (
                <div key={e.name} style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
                  <span style={{ width: '6px', height: '6px', borderRadius: '50%', background: e.color }} />
                  <span style={{ color: 'var(--secondary-text)' }}>{e.name}: <strong>{e.value}</strong></span>
                </div>
              ))}
            </div>
          </div>

          {/* Priority Breakdown bars */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: '6px', borderTop: '1px solid var(--card-border)', paddingTop: '12px' }}>
            <span style={{ fontSize: '10px', color: 'var(--secondary-text)', fontWeight: 600, textTransform: 'uppercase' }}>Priority Breakdown</span>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
              {priorityBreakdown.map((item) => {
                const max = Math.max(...priorityBreakdown.map((d) => d.value), 1);
                const width = (item.value / max) * 100;
                return (
                  <div key={item.name} style={{ display: 'grid', gridTemplateColumns: '80px 1fr 20px', gap: '8px', alignItems: 'center', fontSize: '11px' }}>
                    <span style={{ color: 'var(--secondary-text)', fontWeight: 500 }}>{item.name}</span>
                    <div style={{ height: '6px', background: '#E5E7EB', borderRadius: '3px', overflow: 'hidden' }}>
                      <div style={{ width: `${width}%`, height: '100%', background: item.color, borderRadius: '3px' }} />
                    </div>
                    <span className="font-mono font-bold" style={{ textAlign: 'right' }}>{item.value}</span>
                  </div>
                );
              })}
            </div>
          </div>

          {/* Repairs Completed (Monthly) bar chart */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: '6px', borderTop: '1px solid var(--card-border)', paddingTop: '12px' }}>
            <span style={{ fontSize: '10px', color: 'var(--secondary-text)', fontWeight: 600, textTransform: 'uppercase' }}>Repairs Completed (Monthly)</span>
            <div style={{ height: '100px' }}>
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={monthlyCompletedData} margin={{ top: 5, right: 5, left: -20, bottom: 0 }}>
                  <XAxis dataKey="month" stroke="#9CA3AF" fontSize={9} tickLine={false} axisLine={false} />
                  <Tooltip />
                  <Bar dataKey="completed" fill="var(--primary-text)" radius={[3, 3, 0, 0]} maxBarSize={20} />
                </BarChart>
              </ResponsiveContainer>
            </div>
          </div>
        </div>
      </div>

      {/* Row 3: Team Board + Schedule Schedule */}
      <div className="mnt-dash__grid-row mnt-dash__grid-row--equal">
        {/* Left: Team Assignment Board */}
        <div className="premium-card">
          <div className="card-header-with-actions" style={{ borderBottom: 'none', marginBottom: '14px' }}>
            <h2 className="medium-section-title" style={{ fontSize: '15px' }}>Team Assignment Board</h2>
          </div>
          
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: '16px' }}>
            {MOCK_TEAMS.map((t) => {
              const capacityPct = (t.activeOrders / t.capacity) * 100;
              const isAvailable = t.status.toLowerCase() === 'available';
              
              return (
                <div key={t.id} style={{ border: '1px solid var(--card-border)', borderRadius: 'var(--radius-md)', padding: '12px 14px', display: 'flex', flexDirection: 'column', gap: '8px', background: 'var(--primary-bg)' }}>
                  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: '8px' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '8px', flex: 1 }}>
                      <div className="table-thumbnail-wrapper" style={{ width: '32px', height: '32px', borderRadius: '50%', background: 'var(--card-border)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 'bold', fontSize: '12px' }}>
                        {t.leader.split(' ').map(n => n[0]).join('')}
                      </div>
                      <div style={{ display: 'flex', flexDirection: 'column' }}>
                        <span className="font-bold" style={{ fontSize: '13px' }}>{t.name}</span>
                        <span style={{ fontSize: '10px', color: 'var(--secondary-text)' }}>Lead: {t.leader} &bull; Crew: {t.members}</span>
                      </div>
                    </div>
                    <span className={`status-pill ${isAvailable ? 'badge-low' : 'badge-warning'}`} style={{ fontSize: '9px', textTransform: 'uppercase' }}>
                      {t.status}
                    </span>
                  </div>

                  <div style={{ display: 'flex', flexDirection: 'column', gap: '3px', fontSize: '11px', marginTop: '4px' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                      <span style={{ color: 'var(--secondary-text)' }}>Active Jobs / Capacity</span>
                      <span className="font-bold">{t.activeOrders} / {t.capacity}</span>
                    </div>
                    <div style={{ height: '6px', background: '#E5E7EB', borderRadius: '3px', overflow: 'hidden' }}>
                      <div style={{ width: `${capacityPct}%`, height: '100%', background: 'var(--primary-text)', borderRadius: '3px' }} />
                    </div>
                  </div>

                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderTop: '1px solid var(--card-border)', paddingTop: '8px', marginTop: '4px', fontSize: '11px' }}>
                    <span style={{ color: 'var(--secondary-text)' }} title={t.specialization}>Specs: {t.specialization}</span>
                    <button className="btn-control" style={{ fontSize: '10px', padding: '3px 8px' }} onClick={() => alert(`Assigned work order ${t.currentAssignment} to crew.`)}>
                      Assign
                    </button>
                  </div>
                </div>
              );
            })}
          </div>
        </div>

        {/* Right: Upcoming Repair Schedule (timeline) */}
        <div className="premium-card">
          <div className="card-header-with-actions" style={{ borderBottom: 'none', marginBottom: '14px' }}>
            <h2 className="medium-section-title" style={{ fontSize: '15px' }}>Upcoming Repair Schedule</h2>
          </div>

          {/* Timeline flow */}
          <div style={{ display: 'flex', flexDirection: 'column', gap: '14px', paddingLeft: '10px', borderLeft: '2px solid var(--card-border)', marginLeft: '12px' }}>
            {MOCK_UPCOMING_REPAIRS.map((item) => (
              <div key={item.id} style={{ position: 'relative', display: 'flex', flexDirection: 'column', gap: '4px', fontSize: '13px' }}>
                {/* timeline node */}
                <div style={{ position: 'absolute', left: '-17px', top: '4px', width: '10px', height: '10px', borderRadius: '50%', background: 'var(--primary-text)', border: '2px solid white' }} />
                
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
                    <span className="font-mono font-bold" style={{ color: 'var(--accent-blue)' }}>{item.scheduledTime}</span>
                    <span style={{ fontSize: '11px', color: 'var(--secondary-text)' }}>({item.scheduledDate})</span>
                  </div>
                  <span className={`status-pill badge-${item.priority.toLowerCase()}`} style={{ fontSize: '9px' }}>{item.priority}</span>
                </div>

                <div>
                  <span className="font-bold" style={{ fontSize: '13px' }}>RD-{item.roadId} &bull; {item.distressType}</span>
                  <span style={{ fontSize: '11px', color: 'var(--secondary-text)', display: 'block' }}>Location: {item.location}</span>
                </div>

                <div style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '11px', color: 'var(--secondary-text)' }}>
                  <Users size={11} />
                  <span>Crew: {item.team}</span>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Row 4: Repair Progress Tracker */}
      <div className="premium-card" style={{ marginTop: '24px' }}>
        <div className="card-header-with-actions" style={{ borderBottom: 'none', marginBottom: '14px' }}>
          <h2 className="medium-section-title" style={{ fontSize: '15px' }}>Active Repair Progress Tracker</h2>
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(5, 1fr)', gap: '16px' }}>
          {MOCK_REPAIR_PROGRESS.map((item) => {
            const isDelayed = item.progress < 20 && item.orderId === 'WO-2026-0138';
            
            return (
              <div key={item.orderId} style={{ border: '1px solid var(--card-border)', borderRadius: 'var(--radius-md)', padding: '12px 14px', background: 'var(--primary-bg)', display: 'flex', flexDirection: 'column', gap: '8px' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <span className="font-mono font-bold">{item.orderId}</span>
                  <span className={`status-pill status-pill--${item.status.toLowerCase().replace(/\s/g, '')}`} style={{ fontSize: '9px' }}>{item.status}</span>
                </div>

                <div style={{ fontSize: '12px' }}>
                  <span className="font-bold" style={{ display: 'block' }}>RD-{item.roadId} &bull; {item.distressType}</span>
                  <span style={{ fontSize: '10px', color: 'var(--secondary-text)' }}>Team: {item.team}</span>
                </div>

                {/* Progress bar */}
                <div style={{ display: 'flex', flexDirection: 'column', gap: '3px', fontSize: '11px', marginTop: '4px' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                    <span>Completion</span>
                    <span className="font-mono font-bold" style={{ color: isDelayed ? 'var(--danger)' : 'var(--primary-text)' }}>{item.progress}%</span>
                  </div>
                  <div style={{ height: '6px', background: '#E5E7EB', borderRadius: '3px', overflow: 'hidden' }}>
                    <div style={{ width: `${item.progress}%`, height: '100%', background: isDelayed ? 'var(--danger)' : 'var(--primary-text)', borderRadius: '3px' }} />
                  </div>
                </div>

                {/* Delay warnings */}
                {isDelayed && (
                  <div style={{ display: 'flex', gap: '4px', alignItems: 'center', fontSize: '10px', color: 'var(--danger)', background: '#FEE2E2', padding: '4px 8px', borderRadius: '4px' }}>
                    <AlertTriangle size={11} />
                    <span>Potential Crew Delay</span>
                  </div>
                )}

                <div style={{ fontSize: '10px', color: 'var(--secondary-text)', borderTop: '1px solid var(--card-border)', paddingTop: '6px', marginTop: '2px' }}>
                  <span>Est: {item.estimatedCompletion.split(' ')[0]}</span>
                </div>
              </div>
            );
          })}
        </div>
      </div>

      {/* Row 5: Bottom Analytics Row */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '24px', marginTop: '24px' }}>
        {/* Crew Performance */}
        <div className="premium-card" style={{ padding: '16px 20px' }}>
          <span style={{ fontSize: '10px', color: 'var(--secondary-text)', fontWeight: 600, textTransform: 'uppercase', display: 'block', marginBottom: '8px' }}>Crew Performance</span>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', fontSize: '12px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', borderBottom: '1px solid var(--card-border)', paddingBottom: '4px' }}>
              <span>Pune Rapid Response</span>
              <span className="font-bold" style={{ color: 'var(--success)' }}>96% eff.</span>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', borderBottom: '1px solid var(--card-border)', paddingBottom: '4px' }}>
              <span>Mumbai Metro Crew A</span>
              <span className="font-bold" style={{ color: 'var(--success)' }}>92% eff.</span>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', borderBottom: '1px solid var(--card-border)', paddingBottom: '4px' }}>
              <span>Satara Highway Team</span>
              <span className="font-bold" style={{ color: 'var(--success)' }}>88% eff.</span>
            </div>
          </div>
        </div>

        {/* Equipment Utilization */}
        <div className="premium-card" style={{ padding: '16px 20px' }}>
          <span style={{ fontSize: '10px', color: 'var(--secondary-text)', fontWeight: 600, textTransform: 'uppercase', display: 'block', marginBottom: '8px' }}>Equipment Utilization</span>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', fontSize: '12px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', borderBottom: '1px solid var(--card-border)', paddingBottom: '4px' }}>
              <span>Asphalt Paver</span>
              <span className="font-bold">82% active</span>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', borderBottom: '1px solid var(--card-border)', paddingBottom: '4px' }}>
              <span>Steam Roller</span>
              <span className="font-bold">75% active</span>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', borderBottom: '1px solid var(--card-border)', paddingBottom: '4px' }}>
              <span>Concrete Mixer</span>
              <span className="font-bold">45% active</span>
            </div>
          </div>
        </div>

        {/* Material Consumption */}
        <div className="premium-card" style={{ padding: '16px 20px' }}>
          <span style={{ fontSize: '10px', color: 'var(--secondary-text)', fontWeight: 600, textTransform: 'uppercase', display: 'block', marginBottom: '8px' }}>Material Consumption</span>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', fontSize: '12px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', borderBottom: '1px solid var(--card-border)', paddingBottom: '4px' }}>
              <span>Cold Mix Asphalt</span>
              <span className="font-mono font-bold">12.4 tons</span>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', borderBottom: '1px solid var(--card-border)', paddingBottom: '4px' }}>
              <span>Crack Sealant</span>
              <span className="font-mono font-bold">420 kg</span>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', borderBottom: '1px solid var(--card-border)', paddingBottom: '4px' }}>
              <span>Concrete Casing</span>
              <span className="font-mono font-bold">18 units</span>
            </div>
          </div>
        </div>

        {/* Recent Completed Repairs */}
        <div className="premium-card" style={{ padding: '16px 20px' }}>
          <span style={{ fontSize: '10px', color: 'var(--secondary-text)', fontWeight: 600, textTransform: 'uppercase', display: 'block', marginBottom: '8px' }}>Recent Completed Repairs</span>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', fontSize: '12px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', borderBottom: '1px solid var(--card-border)', paddingBottom: '4px' }}>
              <span>WO-2026-0136</span>
              <span style={{ color: 'var(--secondary-text)' }}>2 hrs ago</span>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', borderBottom: '1px solid var(--card-border)', paddingBottom: '4px' }}>
              <span>WO-2026-0135</span>
              <span style={{ color: 'var(--secondary-text)' }}>1 day ago</span>
            </div>
            <div style={{ display: 'flex', justifyContent: 'space-between', borderBottom: '1px solid var(--card-border)', paddingBottom: '4px' }}>
              <span>WO-2026-0132</span>
              <span style={{ color: 'var(--secondary-text)' }}>3 days ago</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
