export type DistressSeverity = 'low' | 'medium' | 'high' | 'critical';

export type DistressType = 'pothole' | 'crack' | 'rutting' | 'edge_break' | 'patch' | 'raveling' | 'shoving' | 'bleeding';

export type MaintenanceStatus = 'pending' | 'in_progress' | 'completed' | 'scheduled';

export interface RoadDistress {
  id: string;
  roadId: string;
  roadName: string;
  location: string;
  state: string;
  district: string;
  distressType: DistressType;
  severity: DistressSeverity;
  lastInspectionDate: string;
  maintenanceStatus: MaintenanceStatus;
  coordinates: [number, number]; // [latitude, longitude]
  reportedDate: string;
  confidence: number; // confidence percentage (0-100)
  detectionDate: string;
  assignedTeam: string;
  estimatedRepairCost: string;
  estimatedRepairTime: string;
  priorityScore: number;
  image_url?: string | null;
}

export interface GISFiltersState {
  state: string;
  district: string;
  distressType: string;
  severity: string;
  startDate: string;
  endDate: string;
}

export interface GISSummary {
  totalDistresses: number;
  highSeverityCount: number;
  roadsMonitored: number;
  maintenancePending: number;
}
