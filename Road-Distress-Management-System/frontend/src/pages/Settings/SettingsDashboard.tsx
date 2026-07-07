import React, { useState } from "react";
import {
  User,
  Info,
  Bell,
  Lock,
  Sliders,
  Palette,
  Save,
  CheckCircle,
  Key,
  Database,
  Server,
  AlertTriangle,
  Search,
  Download,
  RotateCcw,
  Smartphone,
  ShieldCheck,
  Settings as SettingsIcon,
  UserCheck,
  Moon,
  ToggleLeft,
  Plus,
  Trash2
} from "lucide-react";
import './SettingsDashboard.css';

// ----------------------------------------------------
// Strict Type Definitions
// ----------------------------------------------------
interface ProfileSettings {
  name: string;
  email: string;
  role: string;
  department: string;
  phoneNumber: string;
}

interface AccountInfo {
  userId: string;
  createdDate: string;
  lastLogin: string;
  accessLevel: string;
  sessionStatus: string;
  verificationStatus: string;
}

interface NotificationSettings {
  emailNotifications: boolean;
  criticalAlerts: boolean;
  maintenanceUpdates: boolean;
  weeklyReports: boolean;
}

interface SecuritySettings {
  twoFactorAuth: boolean;
  activeSessions: number;
}

interface SystemPreferences {
  defaultView: 'Overview' | 'Live Feed' | 'GIS Map' | 'Analytics';
  defaultMapZoom: number;
  preferredReportFormat: 'PDF' | 'CSV' | 'JSON';
  language: string;
}

interface AppearanceSettings {
  darkTheme: boolean;
  compactMode: boolean;
  fontSize: 'small' | 'medium' | 'large';
}

interface SystemInfo {
  version: string;
  buildDate: string;
  yoloModel: string;
  databaseStatus: 'Online' | 'Offline';
  backendStatus: 'Online' | 'Offline';
}

export default function SettingsDashboard() {
  // 1. Profile Settings State
  const [profile, setProfile] = useState<ProfileSettings>({
    name: 'Daksh Agarwal',
    email: 'daksh.agarwal@example.com',
    role: 'Lead System Administrator',
    department: 'Urban Infrastructure Operations',
    phoneNumber: '+1 (555) 019-2834'
  });

  // 2. Account Information (Mock Static Data)
  const accountInfo: AccountInfo = {
    userId: 'USR-2026-9812A',
    createdDate: '2024-11-15',
    lastLogin: '2026-06-30 10:45:08 (IST)',
    accessLevel: 'Level 5 (Super Admin)',
    sessionStatus: 'Active Session',
    verificationStatus: 'Verified Enterprise Account'
  };

  // 3. Notification Settings State
  const [notifications, setNotifications] = useState<NotificationSettings>({
    emailNotifications: true,
    criticalAlerts: true,
    maintenanceUpdates: false,
    weeklyReports: true
  });

  // Extra Notification channels state
  const [extraNotifications, setExtraNotifications] = useState({
    pushNotifications: true,
    smsAlerts: false,
    desktopNotifications: true
  });

  // 4. Security Settings State
  const [security, setSecurity] = useState<SecuritySettings>({
    twoFactorAuth: true,
    activeSessions: 3
  });

  // Password Update Form State
  const [showPasswordChange, setShowPasswordChange] = useState(false);
  const [currentPassword, setCurrentPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [passwordError, setPasswordError] = useState('');

  // Mock API Keys
  const [apiKeys, setApiKeys] = useState<Array<{ name: string; key: string; created: string }>>([
    { name: 'Production YOLO Streamer', key: 'sk_live_2026_roadvision_a8b9c10d', created: '2025-01-20' },
    { name: 'Local Test Gateway', key: 'sk_test_2026_roadvision_f2e4d5c6', created: '2026-02-14' }
  ]);
  const [newApiKeyName, setNewApiKeyName] = useState('');

  // 5. System Preferences State
  const [preferences, setPreferences] = useState<SystemPreferences>({
    defaultView: 'GIS Map',
    defaultMapZoom: 14,
    preferredReportFormat: 'PDF',
    language: 'English (US)'
  });

  const [extraPreferences, setExtraPreferences] = useState({
    timeZone: 'UTC+05:30 (India Standard Time)',
    distanceUnit: 'Kilometers (km)',
    measurementSystem: 'Metric (SI)',
    autosaveInterval: '5 minutes'
  });

  // 6. Appearance & Theme State
  const [appearance, setAppearance] = useState<AppearanceSettings>({
    darkTheme: true,
    compactMode: false,
    fontSize: 'medium'
  });

  const [extraAppearance, setExtraAppearance] = useState({
    primaryAccent: '#3B82F6',
    cardRadius: '20px',
    animations: true,
    density: 'Default'
  });

  // 7. About System (Mock Static Data)
  const systemInfo: SystemInfo = {
    version: 'v3.2.0-stable',
    buildDate: '2026-06-15 08:30:12 UTC',
    yoloModel: 'YOLOv11x-RoadDistress-v4.6.2',
    databaseStatus: 'Online',
    backendStatus: 'Online'
  };

  // Sidebar navigation active state
  const [activeSection, setActiveSection] = useState('profile');

  // Search filter for settings fields
  const [searchQuery, setSearchQuery] = useState('');

  // Toast / Feedback message states
  const [toastMessage, setToastMessage] = useState<string | null>(null);
  const [toastType, setToastType] = useState<'success' | 'error'>('success');

  const triggerToast = (message: string, type: 'success' | 'error' = 'success') => {
    setToastMessage(message);
    setToastType(type);
    setTimeout(() => {
      setToastMessage(null);
    }, 4500);
  };

  // ----------------------------------------------------
  // Handlers
  // ----------------------------------------------------
  const handleProfileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const { name, value } = e.target;
    setProfile(prev => ({
      ...prev,
      [name]: value
    }));
  };

  const handleProfileSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!profile.name || !profile.email) {
      triggerToast('Name and Email fields are required.', 'error');
      return;
    }
    triggerToast('Profile settings saved successfully.');
  };

  const handleNotificationToggle = (field: keyof NotificationSettings) => {
    setNotifications(prev => ({
      ...prev,
      [field]: !prev[field]
    }));
    triggerToast('Notification preferences updated.');
  };

  const handleExtraNotificationToggle = (field: 'pushNotifications' | 'smsAlerts' | 'desktopNotifications') => {
    setExtraNotifications(prev => ({
      ...prev,
      [field]: !prev[field]
    }));
    triggerToast('Notification preferences updated.');
  };

  const handle2FAToggle = () => {
    setSecurity(prev => ({
      ...prev,
      twoFactorAuth: !prev.twoFactorAuth
    }));
    triggerToast(`Two-Factor Authentication ${!security.twoFactorAuth ? 'enabled' : 'disabled'}.`);
  };

  const handleRevokeSessions = () => {
    setSecurity(prev => ({
      ...prev,
      activeSessions: 1
    }));
    triggerToast('All other active sessions revoked.');
  };

  const handlePasswordSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setPasswordError('');

    if (!currentPassword || !newPassword || !confirmPassword) {
      setPasswordError('All password fields are required.');
      return;
    }

    if (newPassword !== confirmPassword) {
      setPasswordError('New password and confirmation do not match.');
      return;
    }

    if (newPassword.length < 8) {
      setPasswordError('New password must be at least 8 characters long.');
      return;
    }

    // Success flow
    triggerToast('Password updated successfully.');
    setCurrentPassword('');
    setNewPassword('');
    setConfirmPassword('');
    setShowPasswordChange(false);
  };

  const handlePreferenceChange = (
    field: keyof SystemPreferences,
    value: string | number
  ) => {
    setPreferences(prev => ({
      ...prev,
      [field]: value
    }));
    triggerToast('System preference updated.');
  };

  const handleExtraPreferenceChange = (field: string, value: string) => {
    setExtraPreferences(prev => ({
      ...prev,
      [field]: value
    }));
    triggerToast('System preference updated.');
  };

  const handleAppearanceToggle = (field: 'darkTheme' | 'compactMode') => {
    setAppearance(prev => ({
      ...prev,
      [field]: !prev[field]
    }));
    triggerToast(`${field === 'darkTheme' ? 'Dark Theme' : 'Compact Mode'} toggled.`);
  };

  const handleExtraAppearanceChange = (field: string, value: string | boolean) => {
    setExtraAppearance(prev => ({
      ...prev,
      [field]: value
    }));
    triggerToast('Appearance settings updated.');
  };

  const handleFontSizeChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
    const size = e.target.value as 'small' | 'medium' | 'large';
    setAppearance(prev => ({
      ...prev,
      fontSize: size
    }));
    triggerToast(`Font size set to ${size}.`);
  };

  // Add API Key
  const handleCreateApiKey = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newApiKeyName) {
      alert('Please enter a descriptive name for the API key.');
      return;
    }
    const generated = 'sk_live_' + Math.random().toString(36).substring(2, 10) + Math.random().toString(36).substring(2, 10);
    setApiKeys(prev => [
      ...prev,
      { name: newApiKeyName, key: generated, created: new Date().toISOString().split('T')[0] }
    ]);
    setNewApiKeyName('');
    triggerToast('New API key generated successfully.');
  };

  // Delete API Key
  const handleDeleteApiKey = (keyToDelete: string) => {
    if (confirm('Are you sure you want to revoke this API key? Services using it will fail.')) {
      setApiKeys(prev => prev.filter(k => k.key !== keyToDelete));
      triggerToast('API Key revoked.');
    }
  };

  // Global actions
  const handleSaveChanges = () => {
    triggerToast('All platform preferences and configuration modules saved successfully.');
  };

  const handleResetSettings = () => {
    if (confirm('Are you sure you want to reset current modifications back to session defaults?')) {
      setProfile({
        name: 'Daksh Agarwal',
        email: 'daksh.agarwal@example.com',
        role: 'Lead System Administrator',
        department: 'Urban Infrastructure Operations',
        phoneNumber: '+1 (555) 019-2834'
      });
      setNotifications({
        emailNotifications: true,
        criticalAlerts: true,
        maintenanceUpdates: false,
        weeklyReports: true
      });
      setExtraNotifications({
        pushNotifications: true,
        smsAlerts: false,
        desktopNotifications: true
      });
      setPreferences({
        defaultView: 'GIS Map',
        defaultMapZoom: 14,
        preferredReportFormat: 'PDF',
        language: 'English (US)'
      });
      setAppearance({
        darkTheme: true,
        compactMode: false,
        fontSize: 'medium'
      });
      setExtraAppearance({
        primaryAccent: '#3B82F6',
        cardRadius: '20px',
        animations: true,
        density: 'Default'
      });
      triggerToast('Configuration settings reset successfully.');
    }
  };

  const handleExportConfig = () => {
    const backupObj = {
      exportedAt: new Date().toISOString(),
      profile,
      notifications,
      extraNotifications,
      security,
      preferences,
      extraPreferences,
      appearance,
      extraAppearance,
      systemInfo
    };
    const blob = new Blob([JSON.stringify(backupObj, null, 2)], { type: 'application/json' });
    const link = document.createElement('a');
    link.href = URL.createObjectURL(blob);
    link.setAttribute('download', `roadvision_settings_export_${new Date().toISOString().slice(0, 10)}.json`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    triggerToast('Configuration JSON exported successfully.');
  };

  const handleRestoreDefaults = () => {
    if (confirm('CAUTION: Restore ALL configurations to factory defaults? This will erase custom layouts.')) {
      setProfile({
        name: 'Guest Operator',
        email: 'operator@roadvision.ai',
        role: 'System Operator',
        department: 'General Operations',
        phoneNumber: ''
      });
      setNotifications({
        emailNotifications: false,
        criticalAlerts: true,
        maintenanceUpdates: false,
        weeklyReports: false
      });
      setPreferences({
        defaultView: 'Overview',
        defaultMapZoom: 12,
        preferredReportFormat: 'PDF',
        language: 'English (US)'
      });
      setAppearance({
        darkTheme: false,
        compactMode: false,
        fontSize: 'medium'
      });
      triggerToast('Factory default configurations restored.');
    }
  };

  // Navigation click
  const scrollToSection = (id: string) => {
    setActiveSection(id);
    const element = document.getElementById(id);
    if (element) {
      element.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }
  };

  // Mock Devices List
  const activeDevices = [
    { name: 'Chrome Browser / Windows 11', ip: '192.168.1.45', time: 'Active Session', isCurrent: true },
    { name: 'Safari App / iPhone 15 Pro', ip: '10.0.8.212', time: '2 hours ago', isCurrent: false },
    { name: 'Firefox Browser / macOS Sonoma', ip: '172.16.42.98', time: '3 days ago', isCurrent: false }
  ];

  return (
    <div className={`settings-dashboard-page animate-fade-in ${appearance.compactMode ? 'settings-compact' : ''}`}>

      {/* 1. Page Header */}
      <header className="settings-header-panel">
        <div className="settings-header-title">
          <div className="settings-logo-icon">
            <SettingsIcon size={28} />
          </div>
          <div>
            <h1 className="bold-page-title">Settings</h1>
            <p className="light-secondary-text">
              Manage your account, application preferences, security, notifications, and system configuration.
            </p>
          </div>
        </div>

        {/* Header Toolbar */}
        <div className="settings-toolbar">
          <div className="settings-search-field">
            <Search className="search-icon" size={16} />
            <input
              type="text"
              placeholder="Search settings..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
            />
          </div>

          <button className="settings-btn settings-btn--secondary" onClick={handleExportConfig} title="Export Configuration JSON">
            <Download size={15} /> Export Config
          </button>

          <button className="settings-btn settings-btn--secondary" onClick={handleRestoreDefaults} title="Restore Factory Defaults">
            <RotateCcw size={15} /> Restore Defaults
          </button>

          <button className="settings-btn settings-btn--primary" onClick={handleSaveChanges}>
            <Save size={15} /> Save Changes
          </button>
        </div>

        {/* Status Toast Notifications */}
        {toastMessage && (
          <div className={`settings-save-toast ${toastType === 'error' ? 'settings-toast-error' : 'settings-toast-success'}`}>
            {toastType === 'error' ? <AlertTriangle size={15} /> : <CheckCircle size={15} />}
            <span>{toastMessage}</span>
          </div>
        )}
      </header>

      {/* 2. Summary KPI Cards Row */}
      <section className="settings-kpis-grid">
        <article className="premium-kpi-card premium-card">
          <div className="kpi-header-row">
            <div className="kpi-icon-container kpi-icon-container--roadsscanned" style={{ backgroundColor: 'rgba(59,130,246,0.1)' }}>
              <User size={18} style={{ color: '#3B82F6' }} />
            </div>
            <span className="kpi-title-label">User Profile</span>
          </div>
          <p className="kpi-value-num" style={{ fontSize: '18px', marginTop: '14px', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
            {profile.name}
          </p>
          <div className="kpi-card-footer">
            <span className="comparison-lbl">{profile.email}</span>
          </div>
        </article>

        <article className="premium-kpi-card premium-card">
          <div className="kpi-header-row">
            <div className="kpi-icon-container" style={{ backgroundColor: 'rgba(139,92,246,0.1)' }}>
              <UserCheck size={18} style={{ color: '#8B5CF6' }} />
            </div>
            <span className="kpi-title-label">Platform Role</span>
          </div>
          <p className="kpi-value-num" style={{ fontSize: '18px', marginTop: '14px', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
            {profile.role}
          </p>
          <div className="kpi-card-footer">
            <span className="comparison-lbl">{profile.department}</span>
          </div>
        </article>

        <article className="premium-kpi-card premium-card">
          <div className="kpi-header-row">
            <div className="kpi-icon-container" style={{ backgroundColor: 'rgba(16,185,129,0.1)' }}>
              <Bell size={18} style={{ color: '#10B981' }} />
            </div>
            <span className="kpi-title-label">Notifications</span>
          </div>
          <p className="kpi-value-num" style={{ fontSize: '24px', marginTop: '10px' }}>
            {((notifications.emailNotifications ? 1 : 0) +
              (notifications.criticalAlerts ? 1 : 0) +
              (notifications.maintenanceUpdates ? 1 : 0) +
              (notifications.weeklyReports ? 1 : 0) +
              (extraNotifications.pushNotifications ? 1 : 0) +
              (extraNotifications.desktopNotifications ? 1 : 0))
            } Channels
          </p>
          <div className="kpi-card-footer">
            <span className="comparison-lbl">Active event alerts configured</span>
          </div>
        </article>

        <article className="premium-kpi-card premium-card">
          <div className="kpi-header-row">
            <div className="kpi-icon-container" style={{ backgroundColor: security.twoFactorAuth ? 'rgba(16,185,129,0.1)' : 'rgba(245,158,11,0.1)' }}>
              <ShieldCheck size={18} style={{ color: security.twoFactorAuth ? '#10B981' : '#F59E0B' }} />
            </div>
            <span className="kpi-title-label">Security Shield</span>
          </div>
          <p className="kpi-value-num" style={{ fontSize: '24px', marginTop: '10px' }}>
            {security.twoFactorAuth ? '2FA Enabled' : '2FA Inactive'}
          </p>
          <div className="kpi-card-footer">
            <span className="comparison-lbl">{security.activeSessions} logged-in sessions</span>
          </div>
        </article>
      </section>

      {/* 3. 25/75 Main Layout Panel */}
      <div className="settings-main-split">

        {/* Left Sidebar Navigation (25%) */}
        <aside className="settings-sidebar-nav">
          <div className="sidebar-sticky-box">
            <span className="sidebar-section-title">Dashboard Sections</span>
            {[
              { id: 'profile', title: 'Profile Settings', icon: <User size={16} /> },
              { id: 'account', title: 'Account Information', icon: <Info size={16} /> },
              { id: 'notifications', title: 'Notifications Channels', icon: <Bell size={16} /> },
              { id: 'security', title: 'Security Control', icon: <Lock size={16} /> },
              { id: 'preferences', title: 'System Preferences', icon: <Sliders size={16} /> },
              { id: 'appearance', title: 'Theme & Appearance', icon: <Palette size={16} /> },
              { id: 'status', title: 'System Engine Health', icon: <Server size={16} /> }
            ].map(sec => (
              <button
                key={sec.id}
                className={`sidebar-nav-btn ${activeSection === sec.id ? 'active' : ''}`}
                onClick={() => scrollToSection(sec.id)}
              >
                {sec.icon}
                <span>{sec.title}</span>
              </button>
            ))}
          </div>
        </aside>

        {/* Right Settings Content Section (75%) */}
        <main className="settings-content-cards-flow">

          {/* SECTION 1: PROFILE SETTINGS */}
          <section id="profile" className="settings-card premium-card">
            <header className="settings-card__header">
              <span className="settings-card__icon" style={{ backgroundColor: 'rgba(59,130,246,0.1)', color: '#3B82F6' }}>
                <User size={18} />
              </span>
              <h2 className="medium-section-title">Profile Settings</h2>
            </header>

            <div className="settings-card__body">
              {/* Profile Avatar Section */}
              <div className="profile-avatar-row">
                <div className="profile-avatar-large">
                  <span>{profile.name.split(' ').map(n => n[0]).join('')}</span>
                  <div className="avatar-upload-overlay">
                    <Smartphone size={16} />
                  </div>
                </div>
                <div className="profile-avatar-actions">
                  <span className="avatar-title font-sans">Profile Display Picture</span>
                  <p className="avatar-description">Upload a high-resolution PNG or JPG photo. Max size: 2MB.</p>
                  <div className="avatar-btn-row">
                    <button className="settings-btn settings-btn--secondary" onClick={() => alert('Photo upload trigger (Simulated)')}>
                      Upload Photo
                    </button>
                    <button className="settings-btn settings-btn--danger-text" onClick={() => alert('Photo removed.')}>
                      Remove Picture
                    </button>
                  </div>
                </div>
              </div>

              {/* Profile Fields Form */}
              <form onSubmit={handleProfileSubmit} className="settings-form-grid">
                <div className="form-group-cell">
                  <label htmlFor="profile-name" className="form-label">Full Name</label>
                  <input
                    type="text"
                    id="profile-name"
                    name="name"
                    value={profile.name}
                    onChange={handleProfileChange}
                    className="form-input"
                  />
                </div>

                <div className="form-group-cell">
                  <label htmlFor="profile-email" className="form-label">Email Address</label>
                  <input
                    type="email"
                    id="profile-email"
                    name="email"
                    value={profile.email}
                    onChange={handleProfileChange}
                    className="form-input"
                  />
                </div>

                <div className="form-group-cell">
                  <label htmlFor="profile-role" className="form-label">Role</label>
                  <input
                    type="text"
                    id="profile-role"
                    name="role"
                    value={profile.role}
                    onChange={handleProfileChange}
                    className="form-input"
                  />
                </div>

                <div className="form-group-cell">
                  <label htmlFor="profile-dept" className="form-label">Department</label>
                  <input
                    type="text"
                    id="profile-dept"
                    name="department"
                    value={profile.department}
                    onChange={handleProfileChange}
                    className="form-input"
                  />
                </div>

                <div className="form-group-cell form-group-cell--full">
                  <label htmlFor="profile-phone" className="form-label">Phone Number</label>
                  <input
                    type="text"
                    id="profile-phone"
                    name="phoneNumber"
                    value={profile.phoneNumber}
                    onChange={handleProfileChange}
                    className="form-input"
                  />
                </div>

                <div className="form-submit-row">
                  <button type="submit" className="settings-btn settings-btn--primary">
                    <Save size={16} /> Save Changes
                  </button>
                </div>
              </form>
            </div>
          </section>

          {/* SECTION 2: ACCOUNT INFORMATION */}
          <section id="account" className="settings-card premium-card">
            <header className="settings-card__header">
              <span className="settings-card__icon" style={{ backgroundColor: 'rgba(139,92,246,0.1)', color: '#8B5CF6' }}>
                <Info size={18} />
              </span>
              <h2 className="medium-section-title">Account Information</h2>
            </header>

            <div className="settings-card__body">
              <div className="settings-meta-grid" style={{ gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: '20px' }}>
                <div className="settings-meta-item">
                  <span className="settings-meta-lbl">System User ID</span>
                  <span className="settings-meta-val font-mono text-bold">{accountInfo.userId}</span>
                </div>
                <div className="settings-meta-item">
                  <span className="settings-meta-lbl">Access Credentials</span>
                  <span className="settings-meta-val">{accountInfo.accessLevel}</span>
                </div>
                <div className="settings-meta-item">
                  <span className="settings-meta-lbl">Registration Date</span>
                  <span className="settings-meta-val">{accountInfo.createdDate}</span>
                </div>
                <div className="settings-meta-item">
                  <span className="settings-meta-lbl">Last Active Session</span>
                  <span className="settings-meta-val font-mono">{accountInfo.lastLogin}</span>
                </div>
                <div className="settings-meta-item">
                  <span className="settings-meta-lbl">Verification Status</span>
                  <span className="settings-meta-val">
                    <span className="account-badge-status verification-active">
                      ✓ {accountInfo.verificationStatus}
                    </span>
                  </span>
                </div>
                <div className="settings-meta-item">
                  <span className="settings-meta-lbl">Session Lifecycle</span>
                  <span className="settings-meta-val">
                    <span className="account-badge-status session-active">
                      ● {accountInfo.sessionStatus}
                    </span>
                  </span>
                </div>
              </div>
            </div>
          </section>

          {/* SECTION 3: NOTIFICATION SETTINGS */}
          <section id="notifications" className="settings-card premium-card">
            <header className="settings-card__header">
              <span className="settings-card__icon" style={{ backgroundColor: 'rgba(16,185,129,0.1)', color: '#10B981' }}>
                <Bell size={18} />
              </span>
              <h2 className="medium-section-title">Notification Channels</h2>
            </header>

            <div className="settings-card__body">
              <p className="section-description-text">Configure when and where RoadVision sends alert incidents and updates.</p>

              <div className="settings-toggle-group">
                {/* Switch 1: Email Notifications */}
                <div className="settings-toggle-item">
                  <div className="settings-toggle-details">
                    <span className="settings-toggle-title">Email Incident Notifications</span>
                    <span className="settings-toggle-desc">Daily summary list of AI detections on jurisdictions.</span>
                  </div>
                  <label className="enterprise-switch">
                    <input
                      type="checkbox"
                      checked={notifications.emailNotifications}
                      onChange={() => handleNotificationToggle('emailNotifications')}
                    />
                    <span className="switch-slider" />
                  </label>
                </div>

                {/* Switch 2: Critical Alerts */}
                <div className="settings-toggle-item">
                  <div className="settings-toggle-details">
                    <span className="settings-toggle-title">Critical Pothole/Failure Alerts</span>
                    <span className="settings-toggle-desc">Instant alerts for severe structural road failures.</span>
                  </div>
                  <label className="enterprise-switch">
                    <input
                      type="checkbox"
                      checked={notifications.criticalAlerts}
                      onChange={() => handleNotificationToggle('criticalAlerts')}
                    />
                    <span className="switch-slider" />
                  </label>
                </div>

                {/* Switch 3: Maintenance Updates */}
                <div className="settings-toggle-item">
                  <div className="settings-toggle-details">
                    <span className="settings-toggle-title">Workforce Maintenance Updates</span>
                    <span className="settings-toggle-desc">Receive notifications when repair crews close work tickets.</span>
                  </div>
                  <label className="enterprise-switch">
                    <input
                      type="checkbox"
                      checked={notifications.maintenanceUpdates}
                      onChange={() => handleNotificationToggle('maintenanceUpdates')}
                    />
                    <span className="switch-slider" />
                  </label>
                </div>

                {/* Switch 4: Weekly Summary Reports */}
                <div className="settings-toggle-item">
                  <div className="settings-toggle-details">
                    <span className="settings-toggle-title">Weekly Analytical Summaries</span>
                    <span className="settings-toggle-desc">Exported PDF and Excel report attachments on Sundays.</span>
                  </div>
                  <label className="enterprise-switch">
                    <input
                      type="checkbox"
                      checked={notifications.weeklyReports}
                      onChange={() => handleNotificationToggle('weeklyReports')}
                    />
                    <span className="switch-slider" />
                  </label>
                </div>

                {/* Switch 5: Push Notifications */}
                <div className="settings-toggle-item">
                  <div className="settings-toggle-details">
                    <span className="settings-toggle-title">Push Alert Streams</span>
                    <span className="settings-toggle-desc">Receive push alarms directly in your web browser interface.</span>
                  </div>
                  <label className="enterprise-switch">
                    <input
                      type="checkbox"
                      checked={extraNotifications.pushNotifications}
                      onChange={() => handleExtraNotificationToggle('pushNotifications')}
                    />
                    <span className="switch-slider" />
                  </label>
                </div>

                {/* Switch 6: SMS Alerts */}
                <div className="settings-toggle-item">
                  <div className="settings-toggle-details">
                    <span className="settings-toggle-title">SMS Operations Alerts</span>
                    <span className="settings-toggle-desc">Text message alerts containing precision distress GPS coordinates.</span>
                  </div>
                  <label className="enterprise-switch">
                    <input
                      type="checkbox"
                      checked={extraNotifications.smsAlerts}
                      onChange={() => handleExtraNotificationToggle('smsAlerts')}
                    />
                    <span className="switch-slider" />
                  </label>
                </div>

                {/* Switch 7: Desktop Banner Notifications */}
                <div className="settings-toggle-item">
                  <div className="settings-toggle-details">
                    <span className="settings-toggle-title">System Tray Desktop Notifications</span>
                    <span className="settings-toggle-desc">Popup windows on OS status logs.</span>
                  </div>
                  <label className="enterprise-switch">
                    <input
                      type="checkbox"
                      checked={extraNotifications.desktopNotifications}
                      onChange={() => handleExtraNotificationToggle('desktopNotifications')}
                    />
                    <span className="switch-slider" />
                  </label>
                </div>
              </div>
            </div>
          </section>

          {/* SECTION 4: SECURITY SETTINGS */}
          <section id="security" className="settings-card premium-card">
            <header className="settings-card__header">
              <span className="settings-card__icon" style={{ backgroundColor: 'rgba(239,68,68,0.1)', color: '#EF4444' }}>
                <Lock size={18} />
              </span>
              <h2 className="medium-section-title">Security Dashboard</h2>
            </header>

            <div className="settings-card__body">
              <div className="security-sub-sections-grid">

                {/* 2FA block */}
                <div className="security-sub-card">
                  <span className="sub-title font-semibold">Two-Factor Authentication</span>
                  <p className="sub-desc">Reinforce account shielding via Google/Microsoft authenticator OTP tokens.</p>
                  <div className="sub-action-row">
                    <span className={`status-label-pill ${security.twoFactorAuth ? 'green' : 'gold'}`}>
                      {security.twoFactorAuth ? 'Shield Active' : 'Shield Disabled'}
                    </span>
                    <label className="enterprise-switch">
                      <input
                        type="checkbox"
                        checked={security.twoFactorAuth}
                        onChange={handle2FAToggle}
                      />
                      <span className="switch-slider" />
                    </label>
                  </div>
                </div>

                {/* Active sessions block */}
                <div className="security-sub-card">
                  <span className="sub-title font-semibold">Authorized Session Nodes</span>
                  <p className="sub-desc">Review browser logs active on your credential signature.</p>

                  <div className="session-nodes-list">
                    {activeDevices.map((dev, idx) => (
                      <div key={idx} className="device-node-item">
                        <Smartphone size={16} style={{ color: dev.isCurrent ? '#10B981' : 'var(--secondary-text)' }} />
                        <div className="device-details">
                          <span className="device-name">{dev.name} {dev.isCurrent && ' (Current)'}</span>
                          <span className="device-ip font-mono">{dev.ip} &bull; {dev.time}</span>
                        </div>
                      </div>
                    ))}
                  </div>

                  <div className="sub-action-row">
                    <button className="settings-btn settings-btn--danger-text" onClick={handleRevokeSessions}>
                      Revoke Other Sessions
                    </button>
                  </div>
                </div>

                {/* API Keys block */}
                <div className="security-sub-card">
                  <span className="sub-title font-semibold">Integrator API Keys</span>
                  <p className="sub-desc">Authenticate AI surveillance cameras and script hooks.</p>

                  <div className="api-keys-list">
                    {apiKeys.map((keyObj, idx) => (
                      <div key={idx} className="api-key-item">
                        <div className="key-info">
                          <span className="key-name font-semibold">{keyObj.name}</span>
                          <span className="key-code font-mono">{keyObj.key.slice(0, 12)}...{keyObj.key.slice(-8)}</span>
                        </div>
                        <button className="revoke-key-btn" onClick={() => handleDeleteApiKey(keyObj.key)} title="Revoke API Key">
                          <Trash2 size={13} />
                        </button>
                      </div>
                    ))}
                  </div>

                  {/* Add API key form */}
                  <form onSubmit={handleCreateApiKey} className="add-api-key-form">
                    <input
                      type="text"
                      placeholder="Key purpose (e.g. Sector-4 CAM)"
                      value={newApiKeyName}
                      onChange={(e) => setNewApiKeyName(e.target.value)}
                      className="form-input"
                    />
                    <button type="submit" className="add-key-btn">
                      <Plus size={14} /> Generate
                    </button>
                  </form>
                </div>

                {/* Password block */}
                <div className="security-sub-card">
                  <span className="sub-title font-semibold">Password Management</span>
                  <p className="sub-desc">Update your secure platform login key. Choose a strong unique pass.</p>

                  <div className="sub-action-row">
                    <button
                      className="settings-btn settings-btn--secondary"
                      onClick={() => setShowPasswordChange(!showPasswordChange)}
                    >
                      <Key size={14} /> {showPasswordChange ? 'Cancel Update' : 'Change Password'}
                    </button>
                  </div>

                  {showPasswordChange && (
                    <form onSubmit={handlePasswordSubmit} className="password-form-panel animate-fade-in">
                      {passwordError && (
                        <div className="password-error-message">
                          {passwordError}
                        </div>
                      )}
                      <div className="form-group-cell">
                        <label htmlFor="curr-pwd" className="form-label">Current Password</label>
                        <input
                          type="password"
                          id="curr-pwd"
                          value={currentPassword}
                          onChange={(e) => setCurrentPassword(e.target.value)}
                          className="form-input"
                        />
                      </div>
                      <div className="form-group-cell">
                        <label htmlFor="new-pwd" className="form-label">New Password</label>
                        <input
                          type="password"
                          id="new-pwd"
                          value={newPassword}
                          onChange={(e) => setNewPassword(e.target.value)}
                          className="form-input"
                        />
                      </div>
                      <div className="form-group-cell">
                        <label htmlFor="conf-pwd" className="form-label">Confirm New Password</label>
                        <input
                          type="password"
                          id="conf-pwd"
                          value={confirmPassword}
                          onChange={(e) => setConfirmPassword(e.target.value)}
                          className="form-input"
                        />
                      </div>
                      <button type="submit" className="settings-btn settings-btn--primary">
                        Update Password
                      </button>
                    </form>
                  )}
                </div>
              </div>
            </div>
          </section>

          {/* SECTION 5: SYSTEM PREFERENCES */}
          <section id="preferences" className="settings-card premium-card">
            <header className="settings-card__header">
              <span className="settings-card__icon" style={{ backgroundColor: 'rgba(245,158,11,0.1)', color: '#F59E0B' }}>
                <Sliders size={18} />
              </span>
              <h2 className="medium-section-title">System Preferences</h2>
            </header>

            <div className="settings-card__body">
              <div className="preferences-grid">

                {/* 1. Default View */}
                <div className="form-group-cell">
                  <label className="form-label">Default Landing View</label>
                  <select
                    value={preferences.defaultView}
                    onChange={(e) => handlePreferenceChange('defaultView', e.target.value as any)}
                    className="form-select"
                  >
                    <option value="Overview">Overview Dashboard</option>
                    <option value="Live Feed">Live Detection Feed</option>
                    <option value="GIS Map">GIS distress map</option>
                    <option value="Analytics">Analytics Hub</option>
                  </select>
                </div>

                {/* 2. Map Zoom */}
                <div className="form-group-cell">
                  <label className="form-label">Default Map Zoom</label>
                  <select
                    value={preferences.defaultMapZoom}
                    onChange={(e) => handlePreferenceChange('defaultMapZoom', parseInt(e.target.value))}
                    className="form-select"
                  >
                    <option value="10">City Scale (10x)</option>
                    <option value="12">District Scale (12x)</option>
                    <option value="14">Sector Scale (14x)</option>
                    <option value="16">Street Detail (16x)</option>
                  </select>
                </div>

                {/* 3. Preferred Report format */}
                <div className="form-group-cell">
                  <label className="form-label">Default Report Format</label>
                  <select
                    value={preferences.preferredReportFormat}
                    onChange={(e) => handlePreferenceChange('preferredReportFormat', e.target.value as any)}
                    className="form-select"
                  >
                    <option value="PDF">PDF Document Summary</option>
                    <option value="CSV">Excel Spreadsheet (CSV)</option>
                    <option value="JSON">Developer Feed (JSON)</option>
                  </select>
                </div>

                {/* 4. Language */}
                <div className="form-group-cell">
                  <label className="form-label">System Locale Language</label>
                  <select
                    value={preferences.language}
                    onChange={(e) => handlePreferenceChange('language', e.target.value)}
                    className="form-select"
                  >
                    <option value="English (US)">English (US)</option>
                    <option value="Spanish">Español (ES)</option>
                    <option value="French">Français (FR)</option>
                    <option value="German">Deutsch (DE)</option>
                    <option value="Hindi">हिन्दी (IN)</option>
                  </select>
                </div>

                {/* 5. Time Zone */}
                <div className="form-group-cell">
                  <label className="form-label">Time Zone Scope</label>
                  <select
                    value={extraPreferences.timeZone}
                    onChange={(e) => handleExtraPreferenceChange('timeZone', e.target.value)}
                    className="form-select"
                  >
                    <option value="UTC+05:30 (India Standard Time)">Asia/Kolkata (IST)</option>
                    <option value="UTC+00:00 (Greenwich Mean Time)">GMT / UTC Zone</option>
                    <option value="UTC-05:00 (Eastern Standard Time)">US/Eastern (EST)</option>
                    <option value="UTC+09:00 (Japan Standard Time)">Asia/Tokyo (JST)</option>
                  </select>
                </div>

                {/* 6. Distance Unit */}
                <div className="form-group-cell">
                  <label className="form-label">Distance Units</label>
                  <select
                    value={extraPreferences.distanceUnit}
                    onChange={(e) => handleExtraPreferenceChange('distanceUnit', e.target.value)}
                    className="form-select"
                  >
                    <option value="Kilometers (km)">Kilometers (km)</option>
                    <option value="Miles (mi)">Miles (mi)</option>
                    <option value="Meters (m)">Meters (m)</option>
                  </select>
                </div>

                {/* 7. Measurement system */}
                <div className="form-group-cell">
                  <label className="form-label">Measurement Standard</label>
                  <select
                    value={extraPreferences.measurementSystem}
                    onChange={(e) => handleExtraPreferenceChange('measurementSystem', e.target.value)}
                    className="form-select"
                  >
                    <option value="Metric (SI)">Metric System (SI)</option>
                    <option value="Imperial">Imperial Standard</option>
                  </select>
                </div>

                {/* 8. Autosave Interval */}
                <div className="form-group-cell">
                  <label className="form-label">Autosave Interval</label>
                  <select
                    value={extraPreferences.autosaveInterval}
                    onChange={(e) => handleExtraPreferenceChange('autosaveInterval', e.target.value)}
                    className="form-select"
                  >
                    <option value="5 minutes">Every 5 Mins</option>
                    <option value="15 minutes">Every 15 Mins</option>
                    <option value="30 minutes">Every 30 Mins</option>
                    <option value="Never">Disabled / Manual</option>
                  </select>
                </div>
              </div>
            </div>
          </section>

          {/* SECTION 6: APPEARANCE */}
          <section id="appearance" className="settings-card premium-card">
            <header className="settings-card__header">
              <span className="settings-card__icon" style={{ backgroundColor: 'rgba(59,130,246,0.1)', color: '#3B82F6' }}>
                <Palette size={18} />
              </span>
              <h2 className="medium-section-title">Theme & Appearance</h2>
            </header>

            <div className="settings-card__body">
              <div className="appearance-details-layout">
                {/* Theme presets selector */}
                <div className="theme-selectors-row">
                  <span className="form-label" style={{ gridColumn: '1 / -1' }}>Theme Mode Selection</span>

                  <button
                    className={`theme-selector-btn ${appearance.darkTheme ? 'active' : ''}`}
                    onClick={() => handleAppearanceToggle('darkTheme')}
                  >
                    <Moon size={16} />
                    <span>Dark Theme</span>
                  </button>

                  <button
                    className={`theme-selector-btn ${!appearance.darkTheme ? 'active' : ''}`}
                    onClick={() => handleAppearanceToggle('darkTheme')}
                  >
                    <ToggleLeft size={16} />
                    <span>Light Theme</span>
                  </button>
                </div>

                {/* Accent and radius grids */}
                <div className="appearance-tweaks-grid">
                  <div className="form-group-cell">
                    <label className="form-label">Primary Color Accent</label>
                    <select
                      value={extraAppearance.primaryAccent}
                      onChange={(e) => handleExtraAppearanceChange('primaryAccent', e.target.value)}
                      className="form-select"
                    >
                      <option value="#3B82F6">Royal Indigo (#3B82F6)</option>
                      <option value="#10B981">Forest Emerald (#10B981)</option>
                      <option value="#F59E0B">Amber Gold (#F59E0B)</option>
                      <option value="#EF4444">Scarlet Crimson (#EF4444)</option>
                      <option value="#8B5CF6">Deep Purple (#8B5CF6)</option>
                    </select>
                  </div>

                  <div className="form-group-cell">
                    <label className="form-label">Interface Card Corner Radius</label>
                    <select
                      value={extraAppearance.cardRadius}
                      onChange={(e) => handleExtraAppearanceChange('cardRadius', e.target.value)}
                      className="form-select"
                    >
                      <option value="20px">Rounded Enterprise (20px)</option>
                      <option value="14px">Medium Classic (14px)</option>
                      <option value="8px">Sharp Technical (8px)</option>
                      <option value="0px">Flat Flat (0px)</option>
                    </select>
                  </div>

                  <div className="form-group-cell">
                    <label className="form-label">Font Scale Density</label>
                    <select
                      value={appearance.fontSize}
                      onChange={handleFontSizeChange}
                      className="form-select"
                    >
                      <option value="small">Compact (14px)</option>
                      <option value="medium">Standard (16px)</option>
                      <option value="large">Spacious (18px)</option>
                    </select>
                  </div>

                  <div className="form-group-cell">
                    <label className="form-label">Micro-Animations</label>
                    <select
                      value={extraAppearance.animations ? 'true' : 'false'}
                      onChange={(e) => handleExtraAppearanceChange('animations', e.target.value === 'true')}
                      className="form-select"
                    >
                      <option value="true">Enabled (Smooth transitions)</option>
                      <option value="false">Disabled (Reduce CPU power)</option>
                    </select>
                  </div>
                </div>

                {/* Appearance Live preview card */}
                <div className="appearance-preview-card" style={{ borderRadius: extraAppearance.cardRadius }}>
                  <div className="preview-top-accent" style={{ backgroundColor: extraAppearance.primaryAccent }} />
                  <span className="font-semibold">Live System Theme Mockup</span>
                  <p>Settings card border-radius is synced to visual radius preset.</p>
                </div>
              </div>
            </div>
          </section>

          {/* SECTION 7: SYSTEM STATUS */}
          <section id="status" className="settings-card premium-card">
            <header className="settings-card__header">
              <span className="settings-card__icon" style={{ backgroundColor: 'rgba(16,185,129,0.1)', color: '#10B981' }}>
                <Server size={18} />
              </span>
              <h2 className="medium-section-title">System Engine Health</h2>
            </header>

            <div className="settings-card__body">
              <div className="system-health-grid">
                {[
                  { name: 'Core Backend API', status: systemInfo.backendStatus, desc: 'FastAPI Operations gateway layer', icon: <Server size={16} /> },
                  { name: 'Platform Database', status: systemInfo.databaseStatus, desc: 'PostgreSQL Relational distress catalog', icon: <Database size={16} /> },
                  { name: 'YOLOv11 Detection Core', status: 'Online', desc: 'Neural network distress tagging GPU stream', icon: <Cpu size={16} /> },
                  { name: 'File Storage Service', status: 'Online', desc: 'AWS S3 surveillance video vault', icon: <Info size={16} /> },
                  { name: 'NVIDIA CUDA GPU Node', status: 'Online', desc: 'NVIDIA TensorRT execution hardware', icon: <Cpu size={16} /> },
                  { name: 'Inference Queue Gateway', status: 'Warning', desc: 'Pipeline jobs dispatcher queue thread', icon: <AlertTriangle size={16} />, warn: true }
                ].map((srv, idx) => (
                  <div key={idx} className="health-node-card">
                    <div className="health-node-header">
                      <div className="health-node-logo">
                        {srv.icon}
                      </div>
                      <span className={`health-status-badge ${srv.warn ? 'warning' : srv.status.toLowerCase() === 'online' ? 'online' : 'offline'}`}>
                        {srv.warn ? 'Warning' : srv.status}
                      </span>
                    </div>
                    <span className="health-node-name font-semibold">{srv.name}</span>
                    <span className="health-node-desc">{srv.desc}</span>
                  </div>
                ))}
              </div>
            </div>
          </section>



        </main>
      </div>

      {/* 4. Sticky Bottom Action Bar */}
      <footer className="settings-sticky-bottom-bar">
        <div className="bottom-bar-left">
          <span className="bottom-bar-title font-semibold">Platform Configuration</span>
          <p className="bottom-bar-subtitle">Save or export settings parameters globally.</p>
        </div>
        <div className="bottom-bar-actions">
          <button className="settings-btn settings-btn--danger-text" onClick={handleResetSettings}>
            Reset Changes
          </button>
          <button className="settings-btn settings-btn--secondary" onClick={handleExportConfig}>
            Export Configuration
          </button>
          <button className="settings-btn settings-btn--secondary" onClick={() => alert('Changes cancelled.')}>
            Cancel
          </button>
          <button className="settings-btn settings-btn--primary" onClick={handleSaveChanges}>
            Save Changes
          </button>
        </div>
      </footer>

    </div>
  );
}
