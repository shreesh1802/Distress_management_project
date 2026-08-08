import { useState, useEffect, useRef } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { Search, Bell, MapPin, Calendar, Sun, Moon, User, Settings, LogOut, ChevronDown } from 'lucide-react'
import './TopNavbar.css'

export default function TopNavbar() {
  const navigate = useNavigate()
  const [search, setSearch] = useState('')
  const [isDark, setIsDark] = useState(false)
  const [dropdownOpen, setDropdownOpen] = useState(false)
  const [currentDate, setCurrentDate] = useState('')
  const dropdownRef = useRef<HTMLDivElement>(null)


  useEffect(() => {
    const formatted = new Date().toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric'
    });
    setCurrentDate(formatted);
  }, []);

  useEffect(() => {
    function handleClickOutside(event: MouseEvent) {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
        setDropdownOpen(false)
      }
    }
    document.addEventListener('mousedown', handleClickOutside)
    return () => document.removeEventListener('mousedown', handleClickOutside)
  }, [])

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault();
    if (search.trim()) {
      alert(`Searching for: "${search}"`);
    }
  };

  const handleToggleTheme = () => {
    setIsDark(!isDark);
    alert("Theme toggle clicked (Mock). Dashboard is optimized for commercial light mode.");
  };

  return (
    <header className="top-navbar" aria-label="Top Navigation Bar">
      {/* Left side: Large rounded search bar */}
      <div className="top-navbar__left">
        <form onSubmit={handleSearch} className="top-navbar__search-form">
          <div className="top-navbar__search-wrapper">
            <Search className="top-navbar__search-icon" size={16} />
            <input
              type="text"
              placeholder="Search roads, videos, locations..."
              className="top-navbar__search-input"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              aria-label="Global Search"
            />
            <span className="search-shortcut">⌘ K</span>
          </div>
        </form>
      </div>


      {/* Right side: Status items and user widget */}
      <div className="top-navbar__right">
        {/* Location Widget */}
        <div className="top-navbar__widget" title="Active Operations Center">
          <MapPin size={15} style={{ color: 'var(--accent-blue)' }} />
          <span className="font-semibold">Mumbai Division</span>
        </div>

        {/* Calendar Widget */}
        <div className="top-navbar__widget">
          <Calendar size={15} />
          <span>{currentDate}</span>
        </div>

        {/* Notifications Tray Bell */}
        <button
          className="top-navbar__btn"
          onClick={() => navigate('/notifications')}
          type="button"
          aria-label="Notifications Center"
          title="Notifications Center"
        >
          <Bell size={18} />
          <span className="top-navbar__badge-dot" />
        </button>

        {/* Theme Toggle Button */}
        <button
          className="top-navbar__btn"
          onClick={handleToggleTheme}
          type="button"
          aria-label="Toggle Dark Mode"
          title="Toggle Dark Mode"
        >
          {isDark ? <Sun size={18} /> : <Moon size={18} />}
        </button>

        {/* Profile Avatar Widget */}
        <div className="top-navbar__profile-dropdown" ref={dropdownRef}>
          <button
            className="top-navbar__profile-btn"
            onClick={() => setDropdownOpen((prev) => !prev)}
            aria-expanded={dropdownOpen}
            aria-haspopup="menu"
            type="button"
          >
            <div className="top-navbar__avatar">DA</div>
            <ChevronDown
              size={12}
              className={`top-navbar__chevron ${dropdownOpen ? 'top-navbar__chevron--open' : ''}`}
            />
          </button>

          {dropdownOpen && (
            <div className="top-navbar__menu" role="menu" aria-label="User actions">
              <div className="top-navbar__menu-header">
                <span className="font-bold">Monitoring Engineer (ME)</span>
                <span className="small-caption">Admin Engineer</span>
              </div>
              <div className="top-navbar__menu-divider" role="separator" />
              <Link
                to="/settings"
                className="top-navbar__menu-item"
                role="menuitem"
                onClick={() => setDropdownOpen(false)}
              >
                <User size={14} className="top-navbar__menu-icon" />
                <span>My Profile</span>
              </Link>
              <Link
                to="/settings"
                className="top-navbar__menu-item"
                role="menuitem"
                onClick={() => setDropdownOpen(false)}
              >
                <Settings size={14} className="top-navbar__menu-icon" />
                <span>Settings</span>
              </Link>
              <div className="top-navbar__menu-divider" role="separator" />
              <button
                className="top-navbar__menu-item top-navbar__menu-item--danger"
                role="menuitem"
                type="button"
                onClick={() => {
                  setDropdownOpen(false)
                  localStorage.removeItem("isAuthenticated")
                  navigate("/login")
                }}
              >
                <LogOut size={14} className="top-navbar__menu-icon" />
                <span>Log Out</span>
              </button>
            </div>
          )}
        </div>
      </div>
    </header>
  )
}

