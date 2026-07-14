import React, { useState, useEffect, useRef, useMemo } from "react";
import { useNavigate } from "react-router-dom";
import {
  FileText,
  Navigation,
  MapPin,
  Users,
  CloudSun,
  Play,
  Save,
  ArrowLeft,
  Calendar,
  Clock,
  Car,
  Lock,
  Sliders,
  Cpu,
  Wrench,
  Check,
  User,
} from "lucide-react";
import "./SurveyInitialization.css";

interface LogEntry {
  timestamp: string;
  text: string;
}

export default function SurveyInitialization() {
  const navigate = useNavigate();
  const consoleEndRef = useRef<HTMLDivElement>(null);

  // Auto-generate Inspection ID once
  const inspectionId = useMemo(() => {
    const randomNum = Math.floor(100000 + Math.random() * 900000);
    return `RIMS-2026-${randomNum}`;
  }, []);

  // Form Field States
  const [highwayName, setHighwayName] = useState("NH-48 Delhi–Jaipur Expressway");
  const [highwayNumber, setHighwayNumber] = useState("NH-48");
  const [inspectionDate, setInspectionDate] = useState(() => {
    return new Date().toISOString().substring(0, 10);
  });
  const [inspectionTime, setInspectionTime] = useState(() => {
    const now = new Date();
    return `${String(now.getHours()).padStart(2, "0")}:${String(
      now.getMinutes()
    ).padStart(2, "0")}`;
  });
  const [surveyType, setSurveyType] = useState("Routine Inspection");

  // Chainage
  const [startingChainage, setStartingChainage] = useState("Km 118+250");
  const [endingChainage, setEndingChainage] = useState("Km 136+900");

  // Location
  const [latitude, setLatitude] = useState("28.4595");
  const [longitude, setLongitude] = useState("77.0266");
  const [state, setState] = useState("Haryana");
  const [district, setDistrict] = useState("Gurugram");
  const [roadDirection, setRoadDirection] = useState("Northbound");

  // Team
  const [inspectorName, setInspectorName] = useState("Daksh Agarwal");
  const [department, setDepartment] = useState("NHAI Operations");
  const [organization, setOrganization] = useState("AKCM Infrastructure");
  const [vehicleNumber, setVehicleNumber] = useState("HR-26-CP-4812");
  const [surveyTeam, setSurveyTeam] = useState("AKCM Survey Unit-01");

  // Conditions
  const [weather, setWeather] = useState("Sunny");
  const [trafficDensity, setTrafficDensity] = useState("Medium");
  const [roadSurface, setRoadSurface] = useState("Bituminous");
  const [inspectionNotes, setInspectionNotes] = useState("");

  // Default values from requested Equipment card which was removed
  const camera = "RunCam 4K Orange";

  // Validation Error States
  const [errors, setErrors] = useState<Record<string, string>>({});

  // Loading Simulation States
  const [isInitializing, setIsInitializing] = useState(false);
  const [pipelineLogs, setPipelineLogs] = useState<LogEntry[]>([]);

  // Parse chainage strings in formats like "Km 118+250"
  const parsedStart = useMemo(() => {
    return parseChainage(startingChainage);
  }, [startingChainage]);

  const parsedEnd = useMemo(() => {
    return parseChainage(endingChainage);
  }, [endingChainage]);

  // Compute survey length dynamically
  const surveyLength = useMemo(() => {
    if (parsedStart !== null && parsedEnd !== null) {
      const length = parsedEnd - parsedStart;
      return length > 0 ? length : 0;
    }
    return 0;
  }, [parsedStart, parsedEnd]);

  // Check completeness for live readiness checklist
  const isHighwayOk = useMemo(() => !!highwayName.trim(), [highwayName]);
  const isChainageOk = useMemo(() => {
    return (
      !!startingChainage.trim() &&
      !!endingChainage.trim() &&
      parsedStart !== null &&
      parsedEnd !== null &&
      parsedEnd > parsedStart
    );
  }, [startingChainage, endingChainage, parsedStart, parsedEnd]);
  const isInspectorOk = useMemo(() => !!inspectorName.trim(), [inspectorName]);
  const isVehicleOk = useMemo(() => !!vehicleNumber.trim(), [vehicleNumber]);
  const isWeatherOk = useMemo(() => !!weather, [weather]);

  const isFormComplete = useMemo(() => {
    return isHighwayOk && isChainageOk && isInspectorOk && isVehicleOk && isWeatherOk;
  }, [isHighwayOk, isChainageOk, isInspectorOk, isVehicleOk, isWeatherOk]);

  // Auto scroll loading console logs
  useEffect(() => {
    if (consoleEndRef.current) {
      consoleEndRef.current.scrollIntoView({ behavior: "smooth" });
    }
  }, [pipelineLogs]);

  function parseChainage(val: string): number | null {
    const cleaned = val.toLowerCase().replace(/[^0-9+.]/g, "");
    if (cleaned.includes("+")) {
      const parts = cleaned.split("+");
      const km = parseFloat(parts[0]);
      const m = parseFloat(parts[1]);
      if (!isNaN(km) && !isNaN(m)) {
        return km + m / 1000;
      }
    }
    const direct = parseFloat(cleaned);
    return isNaN(direct) ? null : direct;
  }

  const validateForm = (): boolean => {
    const newErrors: Record<string, string> = {};

    if (!highwayName.trim()) {
      newErrors.highwayName = "Highway Name is required.";
    }

    if (!startingChainage.trim()) {
      newErrors.startingChainage = "Starting Chainage is required.";
    } else if (parsedStart === null) {
      newErrors.startingChainage = "Invalid format. E.g., Km 118+250 or 118.25";
    }

    if (!endingChainage.trim()) {
      newErrors.endingChainage = "Ending Chainage is required.";
    } else if (parsedEnd === null) {
      newErrors.endingChainage = "Invalid format. E.g., Km 136+900 or 136.90";
    }

    if (parsedStart !== null && parsedEnd !== null && parsedEnd <= parsedStart) {
      newErrors.endingChainage = "Ending chainage must be greater than starting chainage.";
    }

    if (!inspectorName.trim()) {
      newErrors.inspectorName = "Inspector Name is required.";
    }

    if (!vehicleNumber.trim()) {
      newErrors.vehicleNumber = "Vehicle Number is required.";
    }

    if (!weather) {
      newErrors.weather = "Weather selection is required.";
    }

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleStartInspection = (e: React.FormEvent) => {
    e.preventDefault();

    if (!validateForm()) {
      // Find first error and scroll to it
      const firstErrorKey = Object.keys(errors)[0];
      const element = document.getElementById(`field-${firstErrorKey}`);
      if (element) {
        element.scrollIntoView({ behavior: "smooth", block: "center" });
      }
      return;
    }

    setIsInitializing(true);
    setPipelineLogs([]);

    // Step-by-step terminal logs simulation (target 1s duration)
    const logsSequence = [
      { text: "Initializing AI Inspection Environment...", delay: 100 },
      { text: `Target Highway: ${highwayName} | Range: ${startingChainage} to ${endingChainage}`, delay: 250 },
      { text: "Verifying active session credentials for inspector Daksh Agarwal...", delay: 400 },
      { text: "Loading YOLOv11 Road Distress Model weights (CUDA active)...", delay: 550 },
      { text: `Allocating GPU buffers for stream feed capture (${camera})...`, delay: 700 },
      { text: "Calibrating GPS positioning coordinates and GIS link layer...", delay: 850 },
      { text: "Systems nominal. Redirecting to Inspection Dashboard...", delay: 950 },
    ];

    logsSequence.forEach((log) => {
      setTimeout(() => {
        const time = new Date().toLocaleTimeString();
        setPipelineLogs((prev) => [...prev, { timestamp: time, text: log.text }]);
      }, log.delay);
    });

    // Final redirection after 1 second
    setTimeout(() => {
      setIsInitializing(false);
      navigate("/dashboard");
    }, 1000);
  };

  const handleSaveDraft = () => {
    alert("Inspection configuration draft saved successfully locally.");
  };

  const handleCancel = () => {
    if (confirm("Are you sure you want to cancel? Any unsaved setup details will be lost.")) {
      localStorage.removeItem("isAuthenticated");
      navigate("/login");
    }
  };

  return (
    <div className="survey-init-container">
      {/* Background overlay matching Login */}
      <div className="survey-init-overlay" />

      {/* Simulated setup calibration overlay dialog */}
      {isInitializing && (
        <div className="survey-loading-overlay" role="dialog" aria-modal="true">
          <div className="survey-loading-box">
            <div className="survey-pipeline-spinner" />
            <h3 className="survey-pipeline-title">Initializing AI Inspection Environment...</h3>
            <div className="survey-pipeline-log-box">
              {pipelineLogs.map((log, idx) => (
                <div key={idx} style={{ marginBottom: "2px" }}>
                  <span style={{ color: "#64748B" }}>[{log.timestamp}]</span> {log.text}
                </div>
              ))}
              <div ref={consoleEndRef} />
            </div>
          </div>
        </div>
      )}

      {/* Page Header Split Row */}
      <header className="survey-init-header-row">
        <div className="survey-init-title-group">
          <p className="survey-subtitle">Inspection Mission Setup</p>
          <h1>Road Inspection Control Center</h1>
          <p className="survey-description">
            Configure and verify survey details before launching the AI-powered Road Distress Monitoring System.
          </p>
        </div>

        {/* Top Right compact User info card */}
        <div className="survey-user-card" aria-label="User Info Profile">
          <div className="survey-user-avatar">
            <User size={16} />
          </div>
          <div className="survey-user-info">
            <span className="survey-user-name">{inspectorName}</span>
            <span className="survey-user-team">{surveyTeam}</span>
          </div>
        </div>
      </header>

      {/* Center centeed Horizontal Progress workflow timeline */}
      <div className="survey-horizontal-timeline" aria-label="Horizontal Mission Timeline">
        <div className="survey-horizontal-step survey-horizontal-step--completed">
          <div className="survey-horizontal-icon-circle">
            <Lock size={14} />
          </div>
          <span className="survey-horizontal-step-number">Step 1</span>
          <span className="survey-horizontal-step-title">Secure Login</span>
          <span className="survey-horizontal-step-status">Completed</span>
        </div>

        <div className="survey-horizontal-step survey-horizontal-step--active">
          <div className="survey-horizontal-icon-circle">
            <Sliders size={14} />
          </div>
          <span className="survey-horizontal-step-number">Step 2</span>
          <span className="survey-horizontal-step-title">Inspection Mission Setup</span>
          <span className="survey-horizontal-step-status">Current Step</span>
        </div>

        <div className="survey-horizontal-step">
          <div className="survey-horizontal-icon-circle">
            <Play size={14} />
          </div>
          <span className="survey-horizontal-step-number">Step 3</span>
          <span className="survey-horizontal-step-title">Live Road Inspection</span>
          <span className="survey-horizontal-step-status">Upcoming</span>
        </div>

        <div className="survey-horizontal-step">
          <div className="survey-horizontal-icon-circle">
            <Cpu size={14} />
          </div>
          <span className="survey-horizontal-step-number">Step 4</span>
          <span className="survey-horizontal-step-title">AI Distress Detection</span>
          <span className="survey-horizontal-step-status">Upcoming</span>
        </div>

        <div className="survey-horizontal-step">
          <div className="survey-horizontal-icon-circle">
            <MapPin size={14} />
          </div>
          <span className="survey-horizontal-step-number">Step 5</span>
          <span className="survey-horizontal-step-title">GIS Mapping</span>
          <span className="survey-horizontal-step-status">Upcoming</span>
        </div>

        <div className="survey-horizontal-step">
          <div className="survey-horizontal-icon-circle">
            <Wrench size={14} />
          </div>
          <span className="survey-horizontal-step-number">Step 6</span>
          <span className="survey-horizontal-step-title">Maintenance Recommendation</span>
          <span className="survey-horizontal-step-status">Upcoming</span>
        </div>

        <div className="survey-horizontal-step">
          <div className="survey-horizontal-icon-circle">
            <FileText size={14} />
          </div>
          <span className="survey-horizontal-step-number">Step 7</span>
          <span className="survey-horizontal-step-title">Report Generation</span>
          <span className="survey-horizontal-step-status">Upcoming</span>
        </div>
      </div>

      {/* Main workspace containing form rows */}
      <main className="survey-init-workspace">
        {/* Row 1: 4 columns */}
        <div className="survey-grid-row-1">
          {/* Card 1: Inspection Details */}
          <div className="glass-survey-card" id="field-highwayName">
            <div className="glass-survey-card-header">
              <div className="glass-survey-card-icon-wrapper">
                <FileText size={18} />
              </div>
              <h2 className="glass-survey-card-title">Inspection Details</h2>
            </div>
            <div className="glass-survey-inputs-grid">
              <div className="glass-survey-form-field">
                <label className="glass-survey-label">Inspection ID</label>
                <input
                  type="text"
                  className="glass-survey-input"
                  value={inspectionId}
                  disabled
                />
              </div>

              <div className="glass-survey-form-field">
                <label className="glass-survey-label">
                  Highway Name <span className="glass-survey-required-dot">*</span>
                </label>
                <input
                  type="text"
                  className={`glass-survey-input ${
                    errors.highwayName ? "glass-survey-input--invalid" : ""
                  }`}
                  value={highwayName}
                  onChange={(e) => setHighwayName(e.target.value)}
                  placeholder="e.g. NH-48 Delhi–Jaipur Expressway"
                />
                {errors.highwayName && (
                  <span className="glass-survey-error-msg">{errors.highwayName}</span>
                )}
              </div>

              <div className="glass-survey-form-field">
                <label className="glass-survey-label">Highway Number</label>
                <input
                  type="text"
                  className="glass-survey-input"
                  value={highwayNumber}
                  onChange={(e) => setHighwayNumber(e.target.value)}
                  placeholder="e.g. NH-48"
                />
              </div>

              <div className="glass-survey-form-field">
                <label className="glass-survey-label">Inspection Date</label>
                <div className="glass-survey-input-wrapper">
                  <input
                    type="date"
                    className="glass-survey-input glass-survey-input--icon"
                    value={inspectionDate}
                    onChange={(e) => setInspectionDate(e.target.value)}
                  />
                  <Calendar className="glass-survey-input-icon" size={16} />
                </div>
              </div>

              <div className="glass-survey-form-field">
                <label className="glass-survey-label">Inspection Time</label>
                <div className="glass-survey-input-wrapper">
                  <input
                    type="time"
                    className="glass-survey-input glass-survey-input--icon"
                    value={inspectionTime}
                    onChange={(e) => setInspectionTime(e.target.value)}
                  />
                  <Clock className="glass-survey-input-icon" size={16} />
                </div>
              </div>

              <div className="glass-survey-form-field">
                <label className="glass-survey-label">Survey Type</label>
                <select
                  className="glass-survey-input"
                  value={surveyType}
                  onChange={(e) => setSurveyType(e.target.value)}
                >
                  <option value="Routine Inspection">Routine Inspection</option>
                  <option value="Emergency Inspection">Emergency Inspection</option>
                  <option value="Post Construction">Post Construction</option>
                  <option value="Complaint Based">Complaint Based</option>
                </select>
              </div>
            </div>
          </div>

          {/* Card 2: Road Chainage */}
          <div className="glass-survey-card" id="field-startingChainage">
            <div className="glass-survey-card-header">
              <div className="glass-survey-card-icon-wrapper">
                <Navigation size={18} />
              </div>
              <h2 className="glass-survey-card-title">Road Chainage</h2>
            </div>
            <div className="glass-survey-inputs-grid">
              <div className="glass-survey-form-field">
                <label className="glass-survey-label">
                  Starting Chainage <span className="glass-survey-required-dot">*</span>
                </label>
                <input
                  type="text"
                  className={`glass-survey-input ${
                    errors.startingChainage ? "glass-survey-input--invalid" : ""
                  }`}
                  value={startingChainage}
                  onChange={(e) => setStartingChainage(e.target.value)}
                  placeholder="e.g. Km 118+250"
                />
                {errors.startingChainage && (
                  <span className="glass-survey-error-msg">{errors.startingChainage}</span>
                )}
              </div>

              <div className="glass-survey-form-field" id="field-endingChainage">
                <label className="glass-survey-label">
                  Ending Chainage <span className="glass-survey-required-dot">*</span>
                </label>
                <input
                  type="text"
                  className={`glass-survey-input ${
                    errors.endingChainage ? "glass-survey-input--invalid" : ""
                  }`}
                  value={endingChainage}
                  onChange={(e) => setEndingChainage(e.target.value)}
                  placeholder="e.g. Km 136+900"
                />
                {errors.endingChainage && (
                  <span className="glass-survey-error-msg">{errors.endingChainage}</span>
                )}
              </div>

              <div className="glass-survey-form-field">
                <label className="glass-survey-label">Total Survey Length</label>
                <div className="glass-survey-calculated-badge">
                  {surveyLength > 0 ? `${surveyLength.toFixed(2)} km` : "0.00 km"}
                </div>
              </div>
            </div>
          </div>

          {/* Card 3: Location Details */}
          <div className="glass-survey-card">
            <div className="glass-survey-card-header">
              <div className="glass-survey-card-icon-wrapper">
                <MapPin size={18} />
              </div>
              <h2 className="glass-survey-card-title">Location</h2>
            </div>
            <div className="glass-survey-inputs-grid">
              <div className="glass-survey-form-field">
                <label className="glass-survey-label">Latitude</label>
                <input
                  type="text"
                  className="glass-survey-input"
                  value={latitude}
                  onChange={(e) => setLatitude(e.target.value)}
                  placeholder="e.g. 28.5355"
                />
              </div>

              <div className="glass-survey-form-field">
                <label className="glass-survey-label">Longitude</label>
                <input
                  type="text"
                  className="glass-survey-input"
                  value={longitude}
                  onChange={(e) => setLongitude(e.target.value)}
                  placeholder="e.g. 77.3910"
                />
              </div>

              <div className="glass-survey-form-field">
                <label className="glass-survey-label">State</label>
                <input
                  type="text"
                  className="glass-survey-input"
                  value={state}
                  onChange={(e) => setState(e.target.value)}
                  placeholder="State"
                />
              </div>

              <div className="glass-survey-form-field">
                <label className="glass-survey-label">District</label>
                <input
                  type="text"
                  className="glass-survey-input"
                  value={district}
                  onChange={(e) => setDistrict(e.target.value)}
                  placeholder="District"
                />
              </div>

              <div className="glass-survey-form-field">
                <label className="glass-survey-label">Road Direction</label>
                <select
                  className="glass-survey-input"
                  value={roadDirection}
                  onChange={(e) => setRoadDirection(e.target.value)}
                >
                  <option value="Northbound">Northbound</option>
                  <option value="Southbound">Southbound</option>
                  <option value="Eastbound">Eastbound</option>
                  <option value="Westbound">Westbound</option>
                </select>
              </div>
            </div>
          </div>

          {/* Card 4: Inspection Team */}
          <div className="glass-survey-card" id="field-inspectorName">
            <div className="glass-survey-card-header">
              <div className="glass-survey-card-icon-wrapper">
                <Users size={18} />
              </div>
              <h2 className="glass-survey-card-title">Inspection Team</h2>
            </div>
            <div className="glass-survey-inputs-grid">
              <div className="glass-survey-form-field">
                <label className="glass-survey-label">
                  Inspector Name <span className="glass-survey-required-dot">*</span>
                </label>
                <input
                  type="text"
                  className={`glass-survey-input ${
                    errors.inspectorName ? "glass-survey-input--invalid" : ""
                  }`}
                  value={inspectorName}
                  onChange={(e) => setInspectorName(e.target.value)}
                  placeholder="Inspector Name"
                />
                {errors.inspectorName && (
                  <span className="glass-survey-error-msg">{errors.inspectorName}</span>
                )}
              </div>

              <div className="glass-survey-form-field">
                <label className="glass-survey-label">Department</label>
                <input
                  type="text"
                  className="glass-survey-input"
                  value={department}
                  onChange={(e) => setDepartment(e.target.value)}
                  placeholder="Department"
                />
              </div>

              <div className="glass-survey-form-field">
                <label className="glass-survey-label">Organization</label>
                <input
                  type="text"
                  className="glass-survey-input"
                  value={organization}
                  onChange={(e) => setOrganization(e.target.value)}
                  placeholder="Organization"
                />
              </div>

              <div className="glass-survey-form-field" id="field-vehicleNumber">
                <label className="glass-survey-label">
                  Vehicle Registration <span className="glass-survey-required-dot">*</span>
                </label>
                <div className="glass-survey-input-wrapper">
                  <input
                    type="text"
                    className={`glass-survey-input glass-survey-input--icon ${
                      errors.vehicleNumber ? "glass-survey-input--invalid" : ""
                    }`}
                    value={vehicleNumber}
                    onChange={(e) => setVehicleNumber(e.target.value)}
                    placeholder="Vehicle Number"
                  />
                  <Car className="glass-survey-input-icon" size={16} />
                </div>
                {errors.vehicleNumber && (
                  <span className="glass-survey-error-msg">{errors.vehicleNumber}</span>
                )}
              </div>

              <div className="glass-survey-form-field">
                <label className="glass-survey-label">Survey Team</label>
                <input
                  type="text"
                  className="glass-survey-input"
                  value={surveyTeam}
                  onChange={(e) => setSurveyTeam(e.target.value)}
                  placeholder="e.g. AKCM Survey Unit-01"
                />
              </div>
            </div>
          </div>
        </div>

        {/* Row 2: 3 columns */}
        <div className="survey-grid-row-2">
          {/* Card 5: Road Conditions */}
          <div className="glass-survey-card" id="field-weather">
            <div className="glass-survey-card-header">
              <div className="glass-survey-card-icon-wrapper">
                <CloudSun size={18} />
              </div>
              <h2 className="glass-survey-card-title">Road Conditions</h2>
            </div>
            <div className="glass-survey-inputs-grid">
              <div className="glass-survey-form-field">
                <label className="glass-survey-label">
                  Weather <span className="glass-survey-required-dot">*</span>
                </label>
                <select
                  className={`glass-survey-input ${
                    errors.weather ? "glass-survey-input--invalid" : ""
                  }`}
                  value={weather}
                  onChange={(e) => setWeather(e.target.value)}
                >
                  <option value="Sunny">Sunny</option>
                  <option value="Cloudy">Cloudy</option>
                  <option value="Rainy">Rainy</option>
                  <option value="Fog">Fog</option>
                  <option value="Night">Night</option>
                </select>
                {errors.weather && (
                  <span className="glass-survey-error-msg">{errors.weather}</span>
                )}
              </div>

              <div className="glass-survey-form-field">
                <label className="glass-survey-label">Traffic Density</label>
                <select
                  className="glass-survey-input"
                  value={trafficDensity}
                  onChange={(e) => setTrafficDensity(e.target.value)}
                >
                  <option value="Low">Low</option>
                  <option value="Medium">Medium</option>
                  <option value="High">High</option>
                </select>
              </div>

              <div className="glass-survey-form-field">
                <label className="glass-survey-label">Road Surface</label>
                <select
                  className="glass-survey-input"
                  value={roadSurface}
                  onChange={(e) => setRoadSurface(e.target.value)}
                >
                  <option value="Bituminous">Bituminous</option>
                  <option value="Concrete">Concrete</option>
                  <option value="Composite">Composite</option>
                </select>
              </div>

              <div className="glass-survey-form-field survey-form-field--fullwidth">
                <label className="glass-survey-label">Inspection Notes</label>
                <textarea
                  className="glass-survey-input"
                  style={{ minHeight: "80px", resize: "vertical" }}
                  value={inspectionNotes}
                  onChange={(e) => setInspectionNotes(e.target.value)}
                  placeholder="Enter any observations before beginning inspection..."
                />
              </div>
            </div>
          </div>

          {/* Card 6: Mission Summary */}
          <div className="glass-survey-card">
            <div className="glass-survey-card-header">
              <div className="glass-survey-card-icon-wrapper">
                <FileText size={18} />
              </div>
              <h2 className="glass-survey-card-title">Mission Summary</h2>
            </div>
            <div className="summary-two-column-grid">
              <div className="summary-grid-item">
                <span className="summary-item-lbl">Highway</span>
                <span className="summary-item-val" title={highwayName}>
                  {highwayName || "--"}
                </span>
              </div>

              <div className="summary-grid-item">
                <span className="summary-item-lbl">Chainage</span>
                <span className="summary-item-val">
                  {startingChainage || "--"} to {endingChainage || "--"}
                </span>
              </div>

              <div className="summary-grid-item">
                <span className="summary-item-lbl">Survey Length</span>
                <span className="summary-item-val summary-item-val--highlight">
                  {surveyLength > 0 ? `${surveyLength.toFixed(2)} km` : "0.00 km"}
                </span>
              </div>

              <div className="summary-grid-item">
                <span className="summary-item-lbl">Inspector</span>
                <span className="summary-item-val" title={inspectorName}>
                  {inspectorName || "--"}
                </span>
              </div>

              <div className="summary-grid-item">
                <span className="summary-item-lbl">Vehicle</span>
                <span className="summary-item-val" title={vehicleNumber}>
                  {vehicleNumber || "--"}
                </span>
              </div>

              <div className="summary-grid-item">
                <span className="summary-item-lbl">Weather</span>
                <span className="summary-item-val">
                  {weather || "--"}
                </span>
              </div>

              <div className="summary-grid-item">
                <span className="summary-item-lbl">Date</span>
                <span className="summary-item-val">
                  {inspectionDate || "--"}
                </span>
              </div>

              <div className="summary-grid-item">
                <span className="summary-item-lbl">Time</span>
                <span className="summary-item-val">
                  {inspectionTime || "--"}
                </span>
              </div>

              <div className="summary-grid-item">
                <span className="summary-item-lbl">Road Surface</span>
                <span className="summary-item-val">
                  {roadSurface || "--"}
                </span>
              </div>

              <div className="summary-grid-item">
                <span className="summary-item-lbl">Direction</span>
                <span className="summary-item-val">
                  {roadDirection || "--"}
                </span>
              </div>
            </div>
          </div>

          {/* Card 7: Inspection Readiness Checklist */}
          <div className="glass-survey-card">
            <div className="glass-survey-card-header">
              <div className="glass-survey-card-icon-wrapper">
                <Sliders size={18} />
              </div>
              <h2 className="glass-survey-card-title">Inspection Readiness Checklist</h2>
            </div>
            <div className="checklist-card-grid">
              <div className="checklist-item checklist-item--checked">
                <span className="checklist-item-icon checklist-item-icon--checked">
                  <Check size={14} />
                </span>
                <span>✓ Login Verified</span>
              </div>

              <div className={`checklist-item ${isHighwayOk ? "checklist-item--checked" : ""}`}>
                {isHighwayOk ? (
                  <span className="checklist-item-icon checklist-item-icon--checked">
                    <Check size={14} />
                  </span>
                ) : (
                  <span className="checklist-item-icon checklist-item-icon--unchecked" />
                )}
                <span>✓ Highway Selected</span>
              </div>

              <div className={`checklist-item ${isChainageOk ? "checklist-item--checked" : ""}`}>
                {isChainageOk ? (
                  <span className="checklist-item-icon checklist-item-icon--checked">
                    <Check size={14} />
                  </span>
                ) : (
                  <span className="checklist-item-icon checklist-item-icon--unchecked" />
                )}
                <span>✓ Chainage Configured</span>
              </div>

              <div className={`checklist-item ${isInspectorOk ? "checklist-item--checked" : ""}`}>
                {isInspectorOk ? (
                  <span className="checklist-item-icon checklist-item-icon--checked">
                    <Check size={14} />
                  </span>
                ) : (
                  <span className="checklist-item-icon checklist-item-icon--unchecked" />
                )}
                <span>✓ Inspector Assigned</span>
              </div>

              <div className={`checklist-item ${isVehicleOk ? "checklist-item--checked" : ""}`}>
                {isVehicleOk ? (
                  <span className="checklist-item-icon checklist-item-icon--checked">
                    <Check size={14} />
                  </span>
                ) : (
                  <span className="checklist-item-icon checklist-item-icon--unchecked" />
                )}
                <span>✓ Vehicle Registered</span>
              </div>

              <div className={`checklist-item ${isWeatherOk ? "checklist-item--checked" : ""}`}>
                {isWeatherOk ? (
                  <span className="checklist-item-icon checklist-item-icon--checked">
                    <Check size={14} />
                  </span>
                ) : (
                  <span className="checklist-item-icon checklist-item-icon--unchecked" />
                )}
                <span>✓ Road Conditions Selected</span>
              </div>

              <div className={`checklist-item ${isFormComplete ? "checklist-item--checked" : ""}`}>
                {isFormComplete ? (
                  <span className="checklist-item-icon checklist-item-icon--checked">
                    <Check size={14} />
                  </span>
                ) : (
                  <span className="checklist-item-icon checklist-item-icon--unchecked" />
                )}
                <span>✓ Survey Information Complete</span>
              </div>

              {/* Status Display row */}
              <div className="checklist-status-divider" />
              <div className="checklist-status-row">
                <span className="checklist-status-lbl">Inspection Status</span>
                {isFormComplete ? (
                  <span className="checklist-status-badge checklist-status-badge--ready">
                    🟢 READY TO START
                  </span>
                ) : (
                  <span className="checklist-status-badge checklist-status-badge--awaiting">
                    🟠 Awaiting Configuration
                  </span>
                )}
              </div>
            </div>
          </div>
        </div>
      </main>

      {/* Bottom Fixed Actions Bar */}
      <div className="survey-action-bar-fixed">
        <div className="survey-action-bar-content">
          <button
            type="button"
            className="survey-btn survey-btn--text"
            onClick={handleCancel}
          >
            <ArrowLeft size={16} />
            Cancel Setup
          </button>
          <button
            type="button"
            className="survey-btn survey-btn--secondary"
            onClick={handleSaveDraft}
          >
            <Save size={16} />
            Save Draft
          </button>
          <button
            type="button"
            className="survey-btn survey-btn--primary"
            onClick={handleStartInspection}
          >
            <Play size={16} />
            Start Inspection
          </button>
        </div>
      </div>
    </div>
  );
}
