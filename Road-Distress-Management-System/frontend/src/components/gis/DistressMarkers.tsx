import { useState, useEffect, useMemo } from 'react';
import { useMap, Marker, Popup, Tooltip, FeatureGroup } from 'react-leaflet';
import L from 'leaflet';
import type { RoadDistress } from '../../types/gis';
import PopupCard from './PopupCard';

interface DistressMarkersProps {
  distresses: RoadDistress[];
  selectedDistress: RoadDistress | null;
  onSelect: (distress: RoadDistress | null) => void;
}

const getMockChainage = (distress: RoadDistress) => {
  const baseKM = Math.floor(distress.coordinates[0] * 5.7) + 12;
  const meters = Math.floor(distress.coordinates[1] * 135) % 1000;
  const paddedMeters = String(meters).padStart(3, '0');
  return `KM ${baseKM}+${paddedMeters}`;
};

const getSeverityColor = (severity: string) => {
  switch (severity) {
    case 'critical':
      return '#ef4444'; // Red
    case 'high':
      return '#f97316'; // Orange
    case 'medium':
      return '#eab308'; // Yellow
    case 'low':
      return '#22c55e'; // Green
    default:
      return '#a855f7';
  }
};

const getDistressSVG = (type: string) => {
  const lowerType = type.toLowerCase();
  if (lowerType.includes('pothole')) {
    return `<svg viewBox="0 0 24 24" width="12" height="12" stroke="white" stroke-width="2.5" fill="rgba(255,255,255,0.4)" style="display: block;"><circle cx="12" cy="12" r="8"/></svg>`;
  } else if (lowerType.includes('longitudinal')) {
    return `<svg viewBox="0 0 24 24" width="12" height="12" stroke="white" stroke-width="2.5" fill="none" style="display: block;"><path d="M12 2v20 M9 8l3 4-3 4"/></svg>`;
  } else if (lowerType.includes('transverse')) {
    return `<svg viewBox="0 0 24 24" width="12" height="12" stroke="white" stroke-width="2.5" fill="none" style="display: block;"><path d="M2 12h20 M8 9l4 3-4 3"/></svg>`;
  } else if (lowerType.includes('alligator') || lowerType.includes('crack')) {
    return `<svg viewBox="0 0 24 24" width="12" height="12" stroke="white" stroke-width="2" fill="none" style="display: block;"><path d="M3 3l18 18 M21 3L3 21 M12 3v18 M3 12h18"/></svg>`;
  }
  return `<svg viewBox="0 0 24 24" width="12" height="12" stroke="white" stroke-width="2.5" fill="none" style="display: block;"><circle cx="12" cy="12" r="3"/></svg>`;
};

const createDistressIcon = (distress: RoadDistress, isSelected: boolean) => {
  const color = getSeverityColor(distress.severity);
  const isCritical = distress.severity === 'critical';
  const isHigh = distress.severity === 'high';

  let pulseClass = '';
  if (isCritical) {
    pulseClass = 'gis-map-container__pulse-ring--critical';
  } else if (isHigh) {
    pulseClass = 'gis-map-container__pulse-ring--high';
  }

  const sizeClass = isSelected ? 'selected' : 'normal';

  return L.divIcon({
    html: `
      <div class="leaflet-distress-marker ${sizeClass}" style="transform: scale(${isSelected ? 1.4 : 1}); transition: transform 0.2s ease;">
        ${isSelected ? `<div class="ping-ring" style="border-color: ${color}; animation: ping 1.5s infinite;"></div>` : ''}
        <div class="pulse-ring ${pulseClass}" style="background-color: ${color}"></div>
        <div class="marker-center" style="background-color: ${color}; color: white; display: flex; align-items: center; justify-content: center; width: 100%; height: 100%; border-radius: 50%; box-shadow: 0 0 8px rgba(0,0,0,0.4);">
          ${getDistressSVG(distress.distressType)}
        </div>
      </div>
    `,
    className: 'custom-distress-icon',
    iconSize: isSelected ? [32, 32] : [24, 24],
    iconAnchor: isSelected ? [16, 16] : [12, 12],
  });
};

const createClusterIcon = (count: number, highestSeverity: string) => {
  const color = getSeverityColor(highestSeverity);
  const pulseClass = `cluster-pulse--${highestSeverity}`;
  return L.divIcon({
    html: `
      <div class="leaflet-marker-cluster ${pulseClass}" style="border-color: ${color}; box-shadow: 0 0 12px ${color}80; color: ${color}; background: rgba(15, 23, 42, 0.95); display: flex; align-items: center; justify-content: center; font-weight: bold; border-radius: 50%;">
        <span class="cluster-count">${count}</span>
      </div>
    `,
    className: 'custom-cluster-icon',
    iconSize: [38, 38],
    iconAnchor: [19, 19],
  });
};

export default function DistressMarkers({
  distresses,
  selectedDistress,
  onSelect,
}: DistressMarkersProps) {
  const map = useMap();
  const [zoom, setZoom] = useState(map.getZoom());

  // Fly to and zoom in on selected distress markers
  useEffect(() => {
    if (selectedDistress) {
      map.flyTo(selectedDistress.coordinates, 13, {
        animate: true,
        duration: 1.2
      });
    }
  }, [selectedDistress, map]);

  // Listen to map zoom to recalculate clusters dynamically
  useEffect(() => {
    const handleZoomEnd = () => {
      setZoom(map.getZoom());
    };
    map.on('zoomend', handleZoomEnd);
    return () => {
      map.off('zoomend', handleZoomEnd);
    };
  }, [map]);

  // Compute dynamic clusters
  const clusters = useMemo(() => {
    // If zoom is high, do not group markers (expand to full detail)
    if (zoom >= 11) {
      return distresses.map((d) => ({
        type: 'marker' as const,
        distress: d,
        key: d.id,
      }));
    }

    const gridSize = zoom <= 5 ? 1.4 : zoom <= 7 ? 0.6 : zoom <= 9 ? 0.25 : 0.08;
    const groups: { [key: string]: RoadDistress[] } = {};

    distresses.forEach((d) => {
      const latGrid = Math.round(d.coordinates[0] / gridSize) * gridSize;
      const lngGrid = Math.round(d.coordinates[1] / gridSize) * gridSize;
      const key = `${latGrid.toFixed(4)},${lngGrid.toFixed(4)}`;
      if (!groups[key]) {
        groups[key] = [];
      }
      groups[key].push(d);
    });

    return Object.entries(groups).map(([key, items]) => {
      if (items.length === 1) {
        return {
          type: 'marker' as const,
          distress: items[0],
          key: items[0].id,
        };
      }

      // Calculate centroid of coordinates
      const lat = items.reduce((sum, d) => sum + d.coordinates[0], 0) / items.length;
      const lng = items.reduce((sum, d) => sum + d.coordinates[1], 0) / items.length;

      // Determine highest severity in cluster to color the border
      const severityOrder = { critical: 3, high: 2, medium: 1, low: 0 };
      let highestSeverity: 'low' | 'medium' | 'high' | 'critical' = 'low';
      items.forEach((item) => {
        if (severityOrder[item.severity] > severityOrder[highestSeverity]) {
          highestSeverity = item.severity;
        }
      });

      return {
        type: 'cluster' as const,
        key,
        coordinates: [lat, lng] as [number, number],
        items,
        highestSeverity,
      };
    });
  }, [distresses, zoom]);

  return (
    <FeatureGroup>
      {clusters.map((cluster) => {
        if (cluster.type === 'marker') {
          const { distress } = cluster;
          const isSelected = selectedDistress?.id === distress.id;
          return (
            <Marker
              key={cluster.key}
              position={distress.coordinates}
              icon={createDistressIcon(distress, isSelected)}
              eventHandlers={{
                click: () => onSelect(distress),
              }}
            >
              {/* Show chainage only on hover */}
              <Tooltip direction="top" offset={[0, -10]} opacity={0.95}>
                <div className="hover-chainage-tooltip">
                  <strong>{getMockChainage(distress)}</strong>
                  <span>{distress.id}</span>
                </div>
              </Tooltip>
              {/* Lazy render popup content */}
              <Popup>
                <PopupCard distress={distress} onSelect={onSelect} />
              </Popup>
            </Marker>
          );
        } else {
          // Cluster rendering
          return (
            <Marker
              key={cluster.key}
              position={cluster.coordinates}
              icon={createClusterIcon(cluster.items.length, cluster.highestSeverity)}
              eventHandlers={{
                click: () => {
                  // Zoom-focus the cluster upon click
                  map.setView(cluster.coordinates, zoom + 2);
                },
              }}
            >
              <Tooltip direction="top" offset={[0, -10]} opacity={0.9}>
                <div style={{ fontSize: '10px', padding: '2px 4px' }}>
                  <strong>Cluster ({cluster.items.length} Detections)</strong>
                </div>
              </Tooltip>
            </Marker>
          );
        }
      })}
    </FeatureGroup>
  );
}
