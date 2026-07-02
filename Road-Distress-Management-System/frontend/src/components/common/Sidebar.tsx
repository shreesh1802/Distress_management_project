import { useState, type ComponentType } from 'react'
import { NavLink } from 'react-router-dom'
import {
  LayoutDashboard,
  Map,
  Radar,
  BarChart3,
  FileText,
  Wrench,
  Settings,
  Upload,
  ShieldAlert,
  History,
  Bell,
  HardDrive,
  LogOut,
  ChevronLeft,
  ChevronRight,
  Route,
  Activity,
} from 'lucide-react'
import './Sidebar.css'

interface LucideIconProps {
  size?: number | string
  className?: string
}

interface SidebarMenuItem {
  path: string
  label: string
  icon: ComponentType<LucideIconProps>
  badge?: number
}

export default function Sidebar() {
  const [isCollapsed, setIsCollapsed] = useState(false)

  const menuItems: SidebarMenuItem[] = [
    {
      path: '/dashboard',
      label: 'Dashboard',
      icon: LayoutDashboard,
    },
    {
      path: '/live-monitoring',
      label: 'Live Detection',
      icon: Radar,
    },
    {
      path: '/upload-video',
      label: 'Upload Video',
      icon: Upload,
    },
    {
      path: '/live-processing',
      label: 'Live Processing',
      icon: Activity,
    },
    {
      path: '/gis-map',
      label: 'GIS Map',
      icon: Map,
    },
    {
      path: '/road-distresses',
      label: 'Road Distresses',
      icon: ShieldAlert,
    },
    {
      path: '/maintenance',
      label: 'Maintenance',
      icon: Wrench,
    },
    {
      path: '/reports',
      label: 'Reports',
      icon: FileText,
    },
    {
      path: '/analytics',
      label: 'Analytics',
      icon: BarChart3,
    },
    {
      path: '/history',
      label: 'History',
      icon: History,
    },
    {
      path: '/notifications',
      label: 'Notifications',
      icon: Bell,
      badge: 2,
    },
    {
      path: '/settings',
      label: 'Settings',
      icon: Settings,
    },
  ]

  const toggleSidebar = () => {
    setIsCollapsed((prev) => !prev)
  }

  return (
    <aside className={`sidebar-rebuilt ${isCollapsed ? 'sidebar-rebuilt--collapsed' : ''}`}>
      {/* Top Logo */}
      <div className="sidebar-rebuilt__header">
        <div className="sidebar-rebuilt__brand">
          <Route className="sidebar-rebuilt__logo-icon" size={20} style={{ color: '#7C8573' }} />
          {!isCollapsed && (
            <div className="sidebar-rebuilt__brand-text" style={{ display: 'flex', flexDirection: 'column', lineHeight: 1.15, gap: '2px' }}>
              <span className="sidebar-rebuilt__brand-title" style={{ fontSize: '22px', fontWeight: 800, color: 'var(--sidebar-text)', letterSpacing: '-0.03em' }}>
                THAPAR - AKCM
              </span>
              <span className="sidebar-rebuilt__brand-subtitle" style={{ fontSize: '11px', fontWeight: 600, color: '#7C8573', letterSpacing: '2px', textTransform: 'uppercase' }}>
                AI POWERED VENTURE
              </span>
            </div>
          )}
        </div>
        <button
          className="sidebar-rebuilt__toggle-btn"
          onClick={toggleSidebar}
          type="button"
          aria-label={isCollapsed ? 'Expand sidebar' : 'Collapse sidebar'}
        >
          {isCollapsed ? <ChevronRight size={12} /> : <ChevronLeft size={12} />}
        </button>
      </div>

      {/* Nav List */}
      <nav className="sidebar-rebuilt__nav" aria-label="Main Navigation">
        <ul className="sidebar-rebuilt__nav-list">
          {menuItems.map((item) => (
            <li key={item.path} className="sidebar-rebuilt__nav-item">
              <NavLink
                to={item.path}
                className={({ isActive }) =>
                  `sidebar-rebuilt__nav-link ${isActive ? 'sidebar-rebuilt__nav-link--active' : ''}`
                }
                title={isCollapsed ? item.label : undefined}
              >
                <item.icon className="sidebar-rebuilt__nav-icon" size={16} />
                {!isCollapsed && <span className="sidebar-rebuilt__nav-label">{item.label}</span>}
                {!isCollapsed && item.badge && (
                  <span className="sidebar-rebuilt__nav-badge">{item.badge}</span>
                )}
              </NavLink>
            </li>
          ))}
        </ul>
      </nav>

      {/* Storage card styled matching dark theme */}
      {!isCollapsed && (
        <div className="sidebar-rebuilt-storage-card">
          <div className="sidebar-rebuilt-storage-card__header">
            <HardDrive size={13} style={{ color: '#4F8EF7' }} />
            <span>GIS Storage Capacity</span>
          </div>
          <div className="sidebar-rebuilt-storage-card__track">
            <div className="sidebar-rebuilt-storage-card__fill" style={{ width: '78.4%' }}></div>
          </div>
          <div className="sidebar-rebuilt-storage-card__labels">
            <span>78.4 GB occupied</span>
            <span>100 GB</span>
          </div>
        </div>
      )}

      {/* Profile Card & Logout Footer */}
      <div className="sidebar-rebuilt__footer">
        <div className="sidebar-rebuilt__profile">
          <div className="sidebar-rebuilt__profile-avatar">DA</div>
          {!isCollapsed && (
            <div className="sidebar-rebuilt__profile-info">
              <span className="sidebar-rebuilt__profile-name">Daksh Agarwal</span>
              <span className="sidebar-rebuilt__profile-role">Admin Control</span>
            </div>
          )}
          {!isCollapsed && (
            <button
              className="sidebar-rebuilt__logout-btn"
              onClick={() => alert("Logging out of system...")}
              title="Logout session"
              type="button"
            >
              <LogOut size={14} />
            </button>
          )}
        </div>
      </div>
    </aside>
  )
}
