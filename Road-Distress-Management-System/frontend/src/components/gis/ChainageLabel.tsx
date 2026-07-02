import { useMemo } from 'react';
import { Marker, Tooltip, FeatureGroup } from 'react-leaflet';
import L from 'leaflet';
import { HIGHWAY_ROUTES } from './routes';

// Helper to interpolate points
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

// Milestone icon definition (small neutral dot)
const milestoneIcon = L.divIcon({
  html: `<div class="milestone-dot-core"></div>`,
  className: 'custom-milestone-marker',
  iconSize: [10, 10],
  iconAnchor: [5, 5],
});

export default function ChainageLabel() {
  // Generate milestones for all routes
  const milestones = useMemo(() => {
    const list: { key: string; coords: [number, number]; label: string }[] = [];

    HIGHWAY_ROUTES.forEach((route) => {
      // Interpolate the highway with high resolution
      const smoothPath = interpolatePath(route.coordinates, 25);
      
      // Select milestone points roughly every 20-25 km
      // In this scale, 25 steps per segment is roughly 50-80 km. Selecting every 8th index represents ~20 km intervals
      const interval = 8;
      for (let i = 0; i < smoothPath.length; i += interval) {
        // Skip the very first/last nodes to avoid overlapping with city badges
        if (i === 0 || i >= smoothPath.length - 2) continue;

        const coords = smoothPath[i];
        // Generate km marker offset
        const baseKM = route.name === 'NH-48' ? 42 : 10;
        const kmVal = baseKM + Math.floor(i * 1.5);
        
        list.push({
          key: `${route.name}-milestone-${i}`,
          coords,
          label: `${route.name} - KM ${kmVal}+000`,
        });
      }
    });

    return list;
  }, []);

  return (
    <FeatureGroup>
      {milestones.map((milestone) => (
        <Marker
          key={milestone.key}
          position={milestone.coords}
          icon={milestoneIcon}
          interactive={true}
        >
          {/* Tooltip appears ONLY on hover */}
          <Tooltip direction="top" offset={[0, -5]} opacity={0.9}>
            <div className="milestone-tooltip">
              <span className="milestone-tooltip__label">{milestone.label}</span>
              <span className="milestone-tooltip__sub">Chainage Reference</span>
            </div>
          </Tooltip>
        </Marker>
      ))}
    </FeatureGroup>
  );
}
