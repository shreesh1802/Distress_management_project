import React, { useState, useEffect, useRef } from "react";
import { useNavigate } from "react-router-dom";
import { Play, Settings, ShieldCheck } from "lucide-react";
import "./SurveyPage.css";

interface LogMessage {
  time: string;
  text: string;
}

export default function SurveyPage() {
  const navigate = useNavigate();
  const loggerEndRef = useRef<HTMLDivElement>(null);

  // Form states
  const [surveyorName, setSurveyorName] = useState("Monitoring Engineer (ME)");
  const [selectedRoute, setSelectedRoute] = useState("NH-48 Mumbai-Pune Expressway");
  const [vehicleId, setVehicleId] = useState("MH-12-RS-9948");

  // Flow states
  const [isInitializing, setIsInitializing] = useState(false);
  const [logs, setLogs] = useState<LogMessage[]>([]);

  // Auto-scroll the logger terminal to bottom
  useEffect(() => {
    if (loggerEndRef.current) {
      loggerEndRef.current.scrollIntoView({ behavior: "smooth" });
    }
  }, [logs]);

  // Log simulation sequence
  const addLog = (text: string) => {
    const timestamp = new Date().toLocaleTimeString();
    setLogs((prev) => [...prev, { time: timestamp, text }]);
  };

  const handleStartSurvey = (e: React.FormEvent) => {
    e.preventDefault();
    if (isInitializing) return;

    setIsInitializing(true);
    setLogs([]);

    // Sequence of simulated initialization steps
    const steps = [
      { text: `[INFO] Initializing inspection survey workspace...`, delay: 100 },
      { text: `[INFO] Surveyor: ${surveyorName} | Vehicle: ${vehicleId}`, delay: 300 },
      { text: `[INFO] Target Route: ${selectedRoute}`, delay: 500 },
      { text: `[OK] Establishing handshake with YOLO AI Object Detection Core...`, delay: 800 },
      { text: `[OK] Calibrating live GPS receivers (Zone: Mumbai Division)...`, delay: 1100 },
      { text: `[OK] Connecting to GIS Server & loading Road Polyline layers...`, delay: 1400 },
      { text: `[OK] Initializing local database cache for offline sync...`, delay: 1700 },
      { text: `[SUCCESS] Systems nominal. Redirecting to Management Dashboard...`, delay: 2000 },
    ];

    steps.forEach((step) => {
      setTimeout(() => {
        addLog(step.text);
      }, step.delay);
    });

    // Final redirection after 2.3 seconds
    setTimeout(() => {
      navigate("/dashboard");
    }, 2400);
  };

  return (
    <div className="survey-page-container">
      <div className="survey-page-overlay" />

      <div className="survey-card">
        <div className="survey-header">
          <div className="survey-brand-tag">
            <ShieldCheck size={14} style={{ marginRight: "4px" }} />
            Control Center Pre-Flight
          </div>
          <h2 className="survey-title">Survey Initialization</h2>
          <p className="survey-subtitle">
            Configure target survey session parameters before launching control dashboard.
          </p>
        </div>

        <form onSubmit={handleStartSurvey} className="survey-form">
          {/* Surveyor Name */}
          <div className="survey-field-group">
            <label htmlFor="surveyor-name" className="survey-label">
              Surveyor / Inspector Name
            </label>
            <input
              id="surveyor-name"
              type="text"
              required
              value={surveyorName}
              onChange={(e) => setSurveyorName(e.target.value)}
              className="survey-input"
              placeholder="Enter inspector full name"
              disabled={isInitializing}
            />
          </div>

          {/* Target Highway Route */}
          <div className="survey-field-group">
            <label htmlFor="target-route" className="survey-label">
              Target Highway Route
            </label>
            <select
              id="target-route"
              value={selectedRoute}
              onChange={(e) => setSelectedRoute(e.target.value)}
              className="survey-select"
              disabled={isInitializing}
            >
              <option value="NH-48 Mumbai-Pune Expressway">
                NH-48 Mumbai-Pune Expressway (MH)
              </option>
              <option value="NH-2 Delhi-Agra Highway">
                NH-2 Delhi-Agra Highway (UP/HR)
              </option>
              <option value="NH-8 Delhi-Jaipur Highway">
                NH-8 Delhi-Jaipur Highway (DL/HR/RJ)
              </option>
              <option value="NH-24 Delhi-Lucknow Expressway">
                NH-24 Delhi-Lucknow Expressway (UP)
              </option>
            </select>
          </div>

          {/* Vehicle ID */}
          <div className="survey-field-group">
            <label htmlFor="vehicle-id" className="survey-label">
              Inspection Vehicle ID
            </label>
            <input
              id="vehicle-id"
              type="text"
              required
              value={vehicleId}
              onChange={(e) => setVehicleId(e.target.value)}
              className="survey-input"
              placeholder="e.g. MH-12-AB-1234"
              disabled={isInitializing}
            />
          </div>

          {/* Initialize Button */}
          <button
            type="submit"
            className="survey-submit-btn"
            disabled={isInitializing}
          >
            {isInitializing ? (
              <>
                <Settings className="animate-spin" size={16} />
                <span>Initializing Workspace...</span>
              </>
            ) : (
              <>
                <Play size={16} />
                <span>Initialize Survey & Open Dashboard</span>
              </>
            )}
          </button>
        </form>

        {/* Tech Console Logs Panel */}
        {(isInitializing || logs.length > 0) && (
          <div className="survey-logger-box" aria-live="polite">
            {logs.map((log, index) => (
              <div key={index} className="survey-logger-line">
                <span className="survey-logger-timestamp">[{log.time}]</span>
                <span className="survey-logger-text">{log.text}</span>
              </div>
            ))}
            <div ref={loggerEndRef} />
          </div>
        )}

        <div className="survey-card-footer">
          Road Distress Management System &bull; Secured Session Workspace
        </div>
      </div>
    </div>
  );
}
