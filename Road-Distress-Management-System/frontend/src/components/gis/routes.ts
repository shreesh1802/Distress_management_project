export interface HighwayRoute {
  id: string;
  name: string;
  length: string;
  states: string[];
  districts: string[];
  activeVehicle: string;
  activeDistresses: number;
  averageSeverity: 'low' | 'medium' | 'high' | 'critical';
  estimatedRepairCost: string;
  lastSurvey: string;
  coordinates: [number, number][];
  color: string;
}

export const HIGHWAY_ROUTES: HighwayRoute[] = [
  {
    id: 'RD-MH-48',
    name: 'NH-48',
    length: '1,428 km (Corridor)',
    states: ['Maharashtra', 'Karnataka'],
    districts: ['Mumbai', 'Thane', 'Pune', 'Satara', 'Kolhapur', 'Belagavi', 'Dharwad', 'Davanagere', 'Tumakuru', 'Bengaluru'],
    activeVehicle: 'V-102 (Live Tracker)',
    activeDistresses: 12,
    averageSeverity: 'high',
    estimatedRepairCost: '₹3,45,000',
    lastSurvey: '2026-06-25',
    color: '#1d4ed8', // Deep blue
    coordinates: [
      [19.0760, 72.8777], // Mumbai
      [18.9894, 73.1175], // Panvel
      [18.7562, 73.3678], // Khandala
      [18.7481, 73.4072], // Lonavala
      [18.5204, 73.8567], // Pune
      [17.6805, 73.9918], // Satara
      [17.2882, 74.1840], // Karad
      [16.7050, 74.2433], // Kolhapur
      [15.8497, 74.4977], // Belagavi
      [15.3647, 75.1240], // Hubli
      [14.4644, 75.9218], // Davanagere
      [13.3392, 77.1140], // Tumakuru
      [12.9716, 77.5946], // Bengaluru
    ],
  },
  {
    id: 'RD-TN-44',
    name: 'NH-44',
    length: '420 km (Corridor)',
    states: ['Karnataka', 'Tamil Nadu'],
    districts: ['Bengaluru', 'Krishnagiri', 'Dharmapuri', 'Salem', 'Namakkal', 'Karur', 'Dindigul', 'Madurai'],
    activeVehicle: 'Not Assigned',
    activeDistresses: 6,
    averageSeverity: 'medium',
    estimatedRepairCost: '₹1,80,000',
    lastSurvey: '2026-06-20',
    color: '#059669', // Emerald green
    coordinates: [
      [12.9716, 77.5946], // Bengaluru
      [12.7409, 77.8253], // Hosur
      [12.5186, 78.2137], // Krishnagiri
      [12.1211, 78.1582], // Dharmapuri
      [11.6643, 78.1460], // Salem
      [11.2189, 78.1673], // Namakkal
      [10.9601, 78.0766], // Karur
      [10.3673, 77.9803], // Dindigul
      [9.9252, 78.1198], // Madurai
    ],
  },
];
