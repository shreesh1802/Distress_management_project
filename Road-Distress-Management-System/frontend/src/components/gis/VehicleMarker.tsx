import { useState, useEffect, useMemo, useRef } from 'react';
import { Marker, Popup } from 'react-leaflet';
import L from 'leaflet';
import { HIGHWAY_ROUTES } from './routes';

export interface VehicleData {
  vehicleId: string;
  roadName: string;
  speed: number;
  heading: string;
  chainage: string;
  coordinates: [number, number];
  gpsConnected: boolean;
  status: string;
  lastUpdate: string;
}

interface VehicleMarkerProps {
  onVehicleUpdate: (data: VehicleData) => void;
}

// Geodesic bearing calculation between two coordinates
const getBearingAngle = (p1: [number, number], p2: [number, number]): number => {
  const lat1 = (p1[0] * Math.PI) / 180;
  const lat2 = (p2[0] * Math.PI) / 180;
  const dLon = ((p2[1] - p1[1]) * Math.PI) / 180;

  const y = Math.sin(dLon) * Math.cos(lat2);
  const x =
    Math.cos(lat1) * Math.sin(lat2) -
    Math.sin(lat1) * Math.cos(lat2) * Math.cos(dLon);
  const brng = Math.atan2(y, x) * (180 / Math.PI);
  return (brng + 360) % 360;
};

// Cardinal directions helper
const getHeadingDirection = (degree: number): string => {
  const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
  const index = Math.round(degree / 45) % 8;
  return `${Math.round(degree)}° ${directions[index]}`;
};

// Interpolates points between nodes to create coordinate sequences
const interpolatePath = (path: [number, number][], stepsPerSegment: number): [number, number][] => {
  const interpolated: [number, number][] = [];
  for (let i = 0; i < path.length - 1; i++) {
    const start = path[i];
    const end = path[i + 1];
    for (let step = 0; step < stepsPerSegment; step++) {
      const fraction = step / stepsPerSegment;
      const lat = start[0] + (end[0] - start[0]) * fraction;
      const lng = start[1] + (end[1] - start[1]) * fraction;
      interpolated.push([lat, lng]);
    }
  }
  if (path.length > 0) {
    interpolated.push(path[path.length - 1]);
  }
  return interpolated;
};

export default function VehicleMarker({ onVehicleUpdate }: VehicleMarkerProps) {
  // Use NH-48 coordinate path
  const nh48Route = useMemo(() => {
    const route = HIGHWAY_ROUTES.find((r) => r.name === 'NH-48');
    return route ? route.coordinates : [];
  }, []);

  // Generate path segments
  const fullPath = useMemo(() => {
    return interpolatePath(nh48Route, 30);
  }, [nh48Route]);

  const [currentCoords, setCurrentCoords] = useState<[number, number]>([19.0760, 72.8777]);
  const [bearing, setBearing] = useState<number>(0);
  const [pathIdx, setPathIdx] = useState<number>(0);

  const onVehicleUpdateRef = useRef(onVehicleUpdate);

  // Sync ref to prevent loop resets
  useEffect(() => {
    onVehicleUpdateRef.current = onVehicleUpdate;
  }, [onVehicleUpdate]);

  // Butter-smooth requestAnimationFrame position loop
  useEffect(() => {
    if (fullPath.length < 2) return;

    let animationFrameId: number;
    const durationPerSegment = 1500; // ms per segment step
    const startTime = performance.now();

    const animate = (time: number) => {
      const elapsed = time - startTime;
      const totalSegments = fullPath.length - 1;
      const totalDuration = totalSegments * durationPerSegment;

      const loopTime = elapsed % totalDuration;
      const currentSegmentIdx = Math.floor(loopTime / durationPerSegment);
      const segmentProgress = (loopTime % durationPerSegment) / durationPerSegment;

      const p1 = fullPath[currentSegmentIdx];
      const p2 = fullPath[currentSegmentIdx + 1] || p1;

      if (p1 && p2) {
        const lat = p1[0] + (p2[0] - p1[0]) * segmentProgress;
        const lng = p1[1] + (p2[1] - p1[1]) * segmentProgress;

        setCurrentCoords([lat, lng]);
        setPathIdx(currentSegmentIdx);

        const angle = getBearingAngle(p1, p2);
        setBearing(angle);
      }

      animationFrameId = requestAnimationFrame(animate);
    };

    animationFrameId = requestAnimationFrame(animate);
    return () => cancelAnimationFrame(animationFrameId);
  }, [fullPath]);

  const headingStr = useMemo(() => {
    return getHeadingDirection(bearing);
  }, [bearing]);

  // Create speed variance
  const speed = useMemo(() => {
    const base = 74;
    const offset = Math.floor(Math.sin(pathIdx / 5) * 3);
    return base + offset;
  }, [pathIdx]);

  // Generate simulated chainage advancing along index
  const chainageStr = useMemo(() => {
    const baseKM = 42;
    const kmOffset = Math.floor(pathIdx * 1.8);
    const mOffset = (pathIdx * 70) % 1000;
    const paddedM = String(mOffset).padStart(3, '0');
    return `KM ${baseKM + kmOffset}+${paddedM}`;
  }, [pathIdx]);

  const vehicleData: VehicleData = useMemo(() => {
    return {
      vehicleId: 'V-102',
      roadName: 'NH-48 Corridor',
      speed,
      heading: headingStr,
      chainage: chainageStr,
      coordinates: currentCoords,
      gpsConnected: true,
      status: 'Active Surveying',
      lastUpdate: new Date().toLocaleTimeString(),
    };
  }, [speed, headingStr, chainageStr, currentCoords]);

  // Trigger parent updates
  useEffect(() => {
    onVehicleUpdateRef.current(vehicleData);
  }, [vehicleData]);

  // Create rotated navigation icon
  const rotatedIcon = useMemo(() => {
    return L.divIcon({
      html: `
        <div class="navigation-vehicle-icon" style="transform: rotate(${bearing}deg);">
          <svg xmlns="http://www.w3.org/2000/svg" width="22" height="22" viewBox="0 0 24 24" fill="#3b82f6" stroke="white" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" class="lucide lucide-navigation-2"><polygon points="12 2 22 22 12 17 2 22 12 2"/></svg>
        </div>
      `,
      className: 'custom-navigation-vehicle',
      iconSize: [36, 36],
      iconAnchor: [18, 18],
    });
  }, [bearing]);

  return (
    <Marker position={currentCoords} icon={rotatedIcon}>
      <Popup>
        <div className="map-popup-card">
          <div className="map-popup-card__header">
            <span className="map-popup-card__id">{vehicleData.vehicleId}</span>
            <span
              className="map-popup-card__severity"
              style={{
                color: '#3b82f6',
                borderColor: '#3b82f6',
              }}
            >
              GPS CONNECTED
            </span>
          </div>
          <div className="map-popup-card__divider" />
          <div className="map-popup-card__grid">
            <div className="map-popup-card__item">
              <span className="map-popup-card__label">Active Route</span>
              <span className="map-popup-card__value">{vehicleData.roadName}</span>
            </div>
            <div className="map-popup-card__item">
              <span className="map-popup-card__label">Current Chainage</span>
              <span className="map-popup-card__value">{vehicleData.chainage}</span>
            </div>
            <div className="map-popup-card__item">
              <span className="map-popup-card__label">Speed</span>
              <span className="map-popup-card__value">{vehicleData.speed} km/h</span>
            </div>
            <div className="map-popup-card__item">
              <span className="map-popup-card__label">Heading</span>
              <span className="map-popup-card__value">{vehicleData.heading}</span>
            </div>
            <div className="map-popup-card__item map-popup-card__item--full">
              <span className="map-popup-card__label">Coordinates</span>
              <span className="map-popup-card__value">
                {currentCoords[0].toFixed(5)}° N, {currentCoords[1].toFixed(5)}° E
              </span>
            </div>
          </div>
        </div>
      </Popup>
    </Marker>
  );
}
