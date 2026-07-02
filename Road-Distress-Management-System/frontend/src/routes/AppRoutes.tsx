import { BrowserRouter, Route, Routes } from "react-router-dom";

import DashboardLayout from "../layouts/DashboardLayout";

import Analytics from "../pages/Analytics/Analytics";
import Dashboard from "../pages/Dashboard/Dashboard";
import GISMap from "../pages/GISMap/GISMap";
import LiveMonitoring from "../pages/LiveMonitoring/LiveMonitoring";
import Maintenance from "../pages/Maintenance/Maintenance";
import Reports from "../pages/Reports/Reports";
import Settings from "../pages/Settings/Settings";

// New Redesigned Pages
import UploadVideo from "../pages/UploadVideo/UploadVideo";
import RoadDistresses from "../pages/RoadDistresses/RoadDistresses";
import History from "../pages/History/History";
import Notifications from "../pages/Notifications/Notifications";
import LiveProcessingDashboard from "../pages/LiveProcessing/LiveProcessingDashboard";
import VideoReview from "../pages/VideoReview/VideoReview";

export default function AppRoutes() {
  return (
    <BrowserRouter>
      <Routes>
        <Route element={<DashboardLayout />}>
          <Route path="/" element={<Dashboard />} />
          <Route path="/dashboard" element={<Dashboard />} />
          <Route path="/live-monitoring" element={<LiveMonitoring />} />
          <Route path="/live-processing" element={<LiveProcessingDashboard />} />
          <Route path="/upload-video" element={<UploadVideo />} />
          <Route path="/gis-map" element={<GISMap />} />
          <Route path="/road-distresses" element={<RoadDistresses />} />
          <Route path="/video-review" element={<VideoReview />} />
          <Route path="/video-review/:id" element={<VideoReview />} />
          <Route path="/maintenance" element={<Maintenance />} />
          <Route path="/reports" element={<Reports />} />
          <Route path="/analytics" element={<Analytics />} />
          <Route path="/history" element={<History />} />
          <Route path="/notifications" element={<Notifications />} />
          <Route path="/settings" element={<Settings />} />
        </Route>
      </Routes>
    </BrowserRouter>
  );
}