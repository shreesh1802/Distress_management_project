import { useMemo } from 'react';
import { Polyline, Marker, Tooltip, FeatureGroup } from 'react-leaflet';
import L from 'leaflet';
import type { HighwayRoute } from './routes';

interface RoutePolylineProps {
  route: HighwayRoute;
  onSelectRoad: (route: HighwayRoute) => void;
  isSelected: boolean;
}

export default function RoutePolyline({ route, onSelectRoad, isSelected }: RoutePolylineProps) {
  // Memoize path positions
  const pathPositions = useMemo(() => route.coordinates, [route.coordinates]);

  // Compute middle point of the polyline path
  const midPosition = useMemo(() => {
    if (pathPositions.length < 2) {
      return [0, 0] as [number, number];
    }
    const midIdx = Math.floor(pathPositions.length / 2);
    const p1 = pathPositions[midIdx];
    const p2 = pathPositions[midIdx + 1] || pathPositions[midIdx - 1];

    const lat = (p1[0] + p2[0]) / 2;
    const lng = (p1[1] + p2[1]) / 2;

    return [lat, lng] as [number, number];
  }, [pathPositions]);

  // Dynamic horizontal shield badge icon matching route style
  const labelIcon = useMemo(() => {
    return L.divIcon({
      html: `
        <div class="highway-shield-badge" style="background-color: ${route.color};">
          <span class="highway-shield-text">${route.name}</span>
        </div>
      `,
      className: 'custom-highway-shield',
      iconSize: [46, 20],
      iconAnchor: [23, 10],
    });
  }, [route.name, route.color]);

  return (
    <FeatureGroup>
      {/* Outer outline layer (Thicker white outline) */}
      <Polyline
        positions={pathPositions}
        color="#ffffff"
        weight={isSelected ? 7.5 : 5.5}
        opacity={1.0}
        eventHandlers={{
          click: () => onSelectRoad(route),
        }}
      />
      {/* Inner primary line (Slightly thinner center line) */}
      <Polyline
        positions={pathPositions}
        color={route.color}
        weight={isSelected ? 4.0 : 2.5}
        opacity={1.0}
        eventHandlers={{
          click: () => onSelectRoad(route),
        }}
      >
        <Tooltip sticky>
          <div className="route-tooltip">
            <strong>{route.name} Corridor</strong>
            <span>Click for survey information</span>
          </div>
        </Tooltip>
      </Polyline>

      {/* Naturally centered horizontal shield badge */}
      <Marker position={midPosition} icon={labelIcon} interactive={false} />
    </FeatureGroup>
  );
}
