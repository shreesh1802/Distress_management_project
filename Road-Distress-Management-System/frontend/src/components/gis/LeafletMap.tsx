import { useState, useEffect, useMemo } from 'react';
import { MapContainer, TileLayer, LayersControl, ZoomControl, useMap, Polyline } from 'react-leaflet';
import 'leaflet/dist/leaflet.css';
import L from 'leaflet';
import type { RoadDistress } from '../../types/gis';
import RoutePolyline from './RoutePolyline';
import VehicleMarker, { type VehicleData } from './VehicleMarker';
import DistressMarkers from './DistressMarkers';
import ChainageLabel from './ChainageLabel';
import RoadInfoPanel from './RoadInfoPanel';
import Legend from './Legend';
import VehicleStatus from './VehicleStatus';
import MapFilters, { type MapFilterState } from './MapFilters';
import { HIGHWAY_ROUTES, type HighwayRoute } from './routes';

interface LeafletMapProps {
  distresses: RoadDistress[];
  selectedDistress: RoadDistress | null;
  onSelect: (distress: RoadDistress | null) => void;
  mapRef: React.MutableRefObject<L.Map | null>;
  onZoomChange: (zoom: number) => void;
  onMouseMoveCoords?: (coords: [number, number] | null) => void;
}

function MouseMoveTracker({ onCoordsChange }: { onCoordsChange: (coords: [number, number] | null) => void }) {
  const map = useMap();
  useEffect(() => {
    const handleMouseMove = (e: L.LeafletMouseEvent) => {
      onCoordsChange([e.latlng.lat, e.latlng.lng]);
    };
    const handleMouseOut = () => {
      onCoordsChange(null);
    };
    map.on('mousemove', handleMouseMove);
    map.on('mouseout', handleMouseOut);
    return () => {
      map.off('mousemove', handleMouseMove);
      map.off('mouseout', handleMouseOut);
    };
  }, [map, onCoordsChange]);
  return null;
}

interface MapUpdaterProps {
  center: [number, number];
  zoom: number;
  mapRef: React.MutableRefObject<L.Map | null>;
  onZoomChange: (zoom: number) => void;
  fitBoundsCoords: [number, number][] | null;
}

// Subcomponent to handle leaflet map viewport updates
function MapUpdater({ center, zoom, mapRef, onZoomChange, fitBoundsCoords }: MapUpdaterProps) {
  const map = useMap();

  // Store map instance
  useEffect(() => {
    mapRef.current = map;
    return () => {
      mapRef.current = null;
    };
  }, [map, mapRef]);

  // Handle standard zoom end tracking
  useEffect(() => {
    const handleZoom = () => {
      onZoomChange(map.getZoom());
    };
    map.on('zoomend', handleZoom);
    onZoomChange(map.getZoom());
    return () => {
      map.off('zoomend', handleZoom);
    };
  }, [map, onZoomChange]);

  // Handle smart bounds fitting or center re-focus
  useEffect(() => {
    if (fitBoundsCoords && fitBoundsCoords.length > 0) {
      const bounds = L.latLngBounds(fitBoundsCoords);
      map.fitBounds(bounds, { padding: [50, 50], maxZoom: 12 });
    } else {
      map.setView(center, zoom);
    }
  }, [map, fitBoundsCoords, center, zoom]);

  return null;
}

export default function LeafletMap({
  distresses,
  selectedDistress,
  onSelect,
  mapRef,
  onZoomChange,
  onMouseMoveCoords
}: LeafletMapProps) {
  // Map floating filters state
  const [mapFilters, setMapFilters] = useState<MapFilterState>({
    road: 'all',
    severity: 'all',
    district: 'all',
    status: 'all',
  });

  // Selected road metadata panel state
  const [selectedRoad, setSelectedRoad] = useState<HighwayRoute | null>(null);

  // Live Vehicle status telemetry state
  const [vehicleData, setVehicleData] = useState<VehicleData | null>(null);

  // Calculate distinct districts from distresses to feed the filter dropdown list
  const allDistricts = useMemo(() => {
    const set = new Set(distresses.map((d) => d.district).filter(Boolean));
    return Array.from(set).sort();
  }, [distresses]);

  // Memoize filtered distress markers list
  const filteredDistresses = useMemo(() => {
    return distresses.filter((d) => {
      if (mapFilters.road !== 'all' && d.roadName !== mapFilters.road) return false;
      if (mapFilters.severity !== 'all' && d.severity !== mapFilters.severity) return false;
      if (mapFilters.district !== 'all' && d.district !== mapFilters.district) return false;
      if (mapFilters.status !== 'all' && d.maintenanceStatus !== mapFilters.status) return false;
      return true;
    });
  }, [distresses, mapFilters]);

  // Connect chronological detections to form the vehicle route polyline
  const vehicleRouteCoords = useMemo(() => {
    if (filteredDistresses.length === 0) return [];
    const sorted = [...filteredDistresses].sort(
      (a, b) => new Date(a.detectionDate || a.reportedDate).getTime() - new Date(b.detectionDate || b.reportedDate).getTime()
    );
    return sorted.map((d) => d.coordinates);
  }, [filteredDistresses]);

  // Compute map center using the average coordinates of filtered markers
  const getCenterAndZoom = () => {
    if (filteredDistresses.length === 0) {
      return { center: [20.5937, 78.9629] as [number, number], zoom: 5 };
    }
    const sumLat = filteredDistresses.reduce((sum, d) => sum + d.coordinates[0], 0);
    const sumLng = filteredDistresses.reduce((sum, d) => sum + d.coordinates[1], 0);
    const avgLat = sumLat / filteredDistresses.length;
    const avgLng = sumLng / filteredDistresses.length;
    return { center: [avgLat, avgLng] as [number, number], zoom: 5 };
  };

  const { center, zoom } = getCenterAndZoom();

  // Smart zoom calculation coordinates
  const fitBoundsCoords = useMemo(() => {
    // If a specific road info panel is selected, zoom to that route
    if (selectedRoad) {
      return selectedRoad.coordinates;
    }
    // If a specific road corridor is active in filter, zoom to that route
    if (mapFilters.road !== 'all') {
      const activeRoute = HIGHWAY_ROUTES.find((r) => r.name === mapFilters.road);
      if (activeRoute) return activeRoute.coordinates;
    }
    // Startup view: Combined coordinates of all highway routes to fit monitored network
    return HIGHWAY_ROUTES.flatMap((r) => r.coordinates);
  }, [selectedRoad, mapFilters.road]);

  return (
    <div className="leaflet-map-wrapper">
      <MapContainer
        center={center}
        zoom={zoom}
        zoomControl={false}
        style={{ height: '100%', width: '100%', zIndex: 1 }}
      >
        <MapUpdater
          center={center}
          zoom={zoom}
          mapRef={mapRef}
          onZoomChange={onZoomChange}
          fitBoundsCoords={fitBoundsCoords}
        />
        <ZoomControl position="bottomright" />
        {onMouseMoveCoords && <MouseMoveTracker onCoordsChange={onMouseMoveCoords} />}

        <LayersControl position="topright">
          <LayersControl.BaseLayer checked name="OpenStreetMap (Street)">
            <TileLayer
              url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
              attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
            />
          </LayersControl.BaseLayer>

          <LayersControl.BaseLayer name="ESRI Satellite">
            <TileLayer
              url="https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}"
              attribution='Tiles &copy; Esri &mdash; Source: Esri, i-cubed, USDA, USGS, AEX, GeoEye, Getmapping, Aerogrid, IGN, IGP, UPR-EGP, and the GIS User Community'
            />
          </LayersControl.BaseLayer>

          <LayersControl.BaseLayer name="Topo Terrain">
            <TileLayer
              url="https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png"
              attribution='&copy; <a href="https://opentopomap.org">OpenTopoMap</a>'
            />
          </LayersControl.BaseLayer>

          <LayersControl.BaseLayer name="CartoDB Dark Theme">
            <TileLayer
              url="https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png"
              attribution='&copy; <a href="https://carto.com/attributions">CARTO</a>'
            />
          </LayersControl.BaseLayer>

          {/* Render High Fidelity Highway Route Polylines */}
          <LayersControl.Overlay checked name="Road Overlay">
            <>
              {HIGHWAY_ROUTES.map((route) => (
                <RoutePolyline
                  key={route.id}
                  route={route}
                  onSelectRoad={setSelectedRoad}
                  isSelected={selectedRoad?.id === route.id}
                />
              ))}
            </>
          </LayersControl.Overlay>

          {/* Chronological Vehicle Route Connect Polyline */}
          <LayersControl.Overlay checked name="Vehicle Route Traversal">
            <>
              {vehicleRouteCoords.length > 1 && (
                <Polyline
                  positions={vehicleRouteCoords}
                  color="#d946ef"
                  dashArray="5, 10"
                  weight={3.5}
                />
              )}
            </>
          </LayersControl.Overlay>

          {/* Render spacing milestone markers */}
          <LayersControl.Overlay checked name="Road Milestones">
            <ChainageLabel />
          </LayersControl.Overlay>

          {/* Render custom clustered distress markers */}
          <LayersControl.Overlay checked name="Distress Layer">
            <DistressMarkers
              distresses={filteredDistresses}
              selectedDistress={selectedDistress}
              onSelect={onSelect}
            />
          </LayersControl.Overlay>
        </LayersControl>

        {/* Live simulated survey vehicle */}
        <VehicleMarker onVehicleUpdate={setVehicleData} />
      </MapContainer>

      {/* Floating Filters Overlay */}
      <MapFilters
        filters={mapFilters}
        onFilterChange={setMapFilters}
        allDistricts={allDistricts}
      />

      {/* Floating live status card overlay */}
      <VehicleStatus data={vehicleData} />

      {/* Collapsible legend overlay */}
      <Legend />

      {/* Sliding road details sidebar */}
      <RoadInfoPanel route={selectedRoad} onClose={() => setSelectedRoad(null)} />
    </div>
  );
}
