import React, { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import {
  Mail,
  Lock,
  Eye,
  EyeOff,
  AlertTriangle,
  Map,
  Wrench,
  FileText,
  BarChart3,
  ShieldCheck,
} from "lucide-react";
import "./LoginPage.css";

export default function LoginPage() {
  const navigate = useNavigate();

  // Form states
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [rememberMe, setRememberMe] = useState(false);
  const [showPassword, setShowPassword] = useState(false);

  // Status states
  const [errors, setErrors] = useState<string[]>([]);
  const [isLoading, setIsLoading] = useState(false);

  // Pre-load stored email if rememberMe was previously set
  useEffect(() => {
    const savedEmail = localStorage.getItem("rememberedEmail");
    if (savedEmail) {
      setEmail(savedEmail);
      setRememberMe(true);
    }
  }, []);

  // Validate form submission
  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    const newErrors: string[] = [];

    // Reset error list
    setErrors([]);

    // 1. Check for empty fields
    if (!email.trim() && !password.trim()) {
      newErrors.push("Please enter both email address and password.");
    } else {
      if (!email.trim()) {
        newErrors.push("Email address is required.");
      }
      if (!password.trim()) {
        newErrors.push("Password is required.");
      }
    }

    // 2. Validate email format (only if not empty)
    if (email.trim() && !/\S+@\S+\.\S+/.test(email)) {
      newErrors.push("Please enter a valid email address (e.g., user@example.com).");
    }

    if (newErrors.length > 0) {
      setErrors(newErrors);
      return;
    }

    // 3. Authenticate with hardcoded credentials
    if (email === "admin@akcm.com" && password === "Admin@123") {
      setIsLoading(true);

      // Handle remember me logic
      if (rememberMe) {
        localStorage.setItem("rememberedEmail", email);
      } else {
        localStorage.removeItem("rememberedEmail");
      }

      // Simulate the 1-second initialization experience
      setTimeout(() => {
        localStorage.setItem("isAuthenticated", "true");
        setIsLoading(false);
        navigate("/survey");
      }, 1000);
    } else {
      setErrors(["Invalid credentials. Please verify your email and password."]);
    }
  };

  return (
    <div className="login-page-container">
      {/* Background dark overlay */}
      <div className="login-page-overlay" />

      {/* Loading Overlay */}
      {isLoading && (
        <div className="login-loading-overlay" role="alert" aria-busy="true">
          <div className="login-loading-spinner" />
          <span className="login-loading-text">
            Initializing Road Inspection Control Center...
          </span>
        </div>
      )}

      {/* Primary Layout Container */}
      <div className="login-page-content">
        {/* Left Column: Branding Section & Features */}
        <section className="login-left-section">
          <div className="login-brand-header">
            <div className="login-brand-tag">
              <span className="login-brand-tag-dot" />
              Infrastructure Portal
            </div>
            <h1 className="login-main-title">Road Inspection Control Center</h1>
            <p className="login-subtitle">Authorized Personnel Access Only</p>
          </div>

          <p className="login-description">
            AI-Powered Road Distress Detection, GIS Mapping and Intelligent
            Maintenance Platform for Highway Infrastructure Monitoring. Developed to Ensure Safety, Track Performance, and Automate Asset Lifecycles.
          </p>

          {/* Custom Animated Road Divider */}
          <div className="login-road-divider-container" aria-hidden="true">
            <div className="login-road-divider-line" />
          </div>

          {/* Feature Grid */}
          <div className="login-features-grid">
            <div className="login-feature-card">
              <div className="login-feature-icon-wrapper">
                <Map size={20} />
              </div>
              <div className="login-feature-text">
                <span className="login-feature-title">Live GIS Monitoring</span>
                <span className="login-feature-desc">Geospatial logging and location-tagged vehicle feeds.</span>
              </div>
            </div>

            <div className="login-feature-card">
              <div className="login-feature-icon-wrapper">
                <Wrench size={20} />
              </div>
              <div className="login-feature-text">
                <span className="login-feature-title">AI Maintenance Recommendations</span>
                <span className="login-feature-desc">Automated maintenance job priorities and budgets.</span>
              </div>
            </div>

            <div className="login-feature-card">
              <div className="login-feature-icon-wrapper">
                <FileText size={20} />
              </div>
              <div className="login-feature-text">
                <span className="login-feature-title">Automated PDF & Excel Reports</span>
                <span className="login-feature-desc">Downloadable structured inspection summaries.</span>
              </div>
            </div>

            <div className="login-feature-card">
              <div className="login-feature-icon-wrapper">
                <BarChart3 size={20} />
              </div>
              <div className="login-feature-text">
                <span className="login-feature-title">Road Health Analytics</span>
                <span className="login-feature-desc">Aggregated severity distribution indexes.</span>
              </div>
            </div>
          </div>
        </section>

        {/* Right Column: Glassmorphism Login Card */}
        <section className="login-right-section">
          <div className="glass-login-card">
            <div className="login-card-header">
              <div className="login-card-logo-wrapper">
                <ShieldCheck size={28} />
              </div>
              <h2 className="login-card-title">Administrator Access</h2>
              <p className="login-card-subtitle">Please sign in to continue.</p>
            </div>

            {/* Error alerts list */}
            {errors.length > 0 && (
              <div className="login-error-container" role="alert">
                <AlertTriangle size={18} className="login-error-icon" />
                <div>
                  <strong>Access Denied:</strong>
                  {errors.length === 1 ? (
                    <p style={{ margin: "4px 0 0 0" }}>{errors[0]}</p>
                  ) : (
                    <ul className="login-error-list">
                      {errors.map((err, idx) => (
                        <li key={idx}>{err}</li>
                      ))}
                    </ul>
                  )}
                </div>
              </div>
            )}

            <form onSubmit={handleSubmit} className="login-form">
              {/* Email field */}
              <div className="login-input-group">
                <label htmlFor="login-email" className="login-label">
                  Email Address
                </label>
                <div className="login-input-wrapper">
                  <input
                    id="login-email"
                    type="text"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    placeholder="name@domain.com"
                    className="login-input"
                    aria-required="true"
                    disabled={isLoading}
                  />
                  <Mail className="login-field-icon" size={16} />
                </div>
              </div>

              {/* Password field */}
              <div className="login-input-group">
                <label htmlFor="login-password" className="login-label">
                  Password
                </label>
                <div className="login-input-wrapper">
                  <input
                    id="login-password"
                    type={showPassword ? "text" : "password"}
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    placeholder="••••••••"
                    className="login-input"
                    aria-required="true"
                    disabled={isLoading}
                  />
                  <Lock className="login-field-icon" size={16} />
                  <button
                    type="button"
                    className="login-forgot-link"
                    style={{
                      position: "absolute",
                      right: "12px",
                      background: "none",
                      border: "none",
                      color: "#A0AEC0",
                      cursor: "pointer",
                      display: "flex",
                      alignItems: "center",
                      justifyContent: "center",
                    }}
                    onClick={() => setShowPassword(!showPassword)}
                    title={showPassword ? "Hide password" : "Show password"}
                    aria-label={showPassword ? "Hide password" : "Show password"}
                    disabled={isLoading}
                  >
                    {showPassword ? <EyeOff size={16} /> : <Eye size={16} />}
                  </button>
                </div>
              </div>

              {/* Extra row: Remember me & Forgot Password */}
              <div className="login-options-row">
                <label className="login-checkbox-label">
                  <input
                    type="checkbox"
                    checked={rememberMe}
                    onChange={(e) => setRememberMe(e.target.checked)}
                    className="login-checkbox"
                    disabled={isLoading}
                  />
                  <span>Remember Me</span>
                </label>
                <button
                  type="button"
                  className="login-forgot-link"
                  onClick={() =>
                    setErrors([
                      "Password reset is restricted. Contact network administrator for security keys.",
                    ])
                  }
                  disabled={isLoading}
                >
                  Forgot Password?
                </button>
              </div>

              {/* Submit button */}
              <button
                type="submit"
                className="login-submit-button"
                disabled={isLoading}
              >
                <span>Secure Login</span>
              </button>
            </form>

            {/* Footer */}
            <div className="login-card-footer">
              <div className="login-card-footer-divider" />
              <div>Road Distress Management System &bull; Version 1.0</div>
              <div className="login-partner-logos">
                POWERED BY THAPAR &times; AKCM
              </div>
            </div>
          </div>
        </section>
      </div>
    </div>
  );
}
