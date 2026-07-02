"""
GIS integration routes for the Road Distress Management System.
"""

from typing import List
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from pydantic import BaseModel
from app.db.session import get_db
from app.crud.distress import get_distresses

router = APIRouter()


class MapMarker(BaseModel):
    """
    Schema representing a geo-tagged distress marker on the GIS map.
    """
    id: int
    latitude: float
    longitude: float
    distress_type: str
    severity: str
    status: str


@router.get("/markers", response_model=List[MapMarker])
def get_map_markers(db: Session = Depends(get_db)) -> List[MapMarker]:
    """
    Retrieve geo-tagged distress logs formatted as map markers for GIS visualization.
    """
    # Fetch distress logs from database (up to 500 for maps)
    distresses = get_distresses(db, limit=500)
    return [
        MapMarker(
            id=d.id,
            latitude=d.latitude,
            longitude=d.longitude,
            distress_type=d.distress_type,
            severity=d.severity,
            status=d.status
        )
        for d in distresses
    ]


from typing import Optional

# GeoJSON Schema definitions (Task 2)
class Geometry(BaseModel):
    type: str = "Point"
    coordinates: List[float]  # [longitude, latitude]


class GeoJSONProperty(BaseModel):
    id: Optional[int] = None
    distress_type: Optional[str] = None
    severity: Optional[str] = None
    status: Optional[str] = None
    marker_color: str
    is_cluster: bool = False
    point_count: int = 1
    highest_severity: Optional[str] = None
    ids: Optional[List[int]] = None


class GeoJSONFeature(BaseModel):
    type: str = "Feature"
    geometry: Geometry
    properties: GeoJSONProperty


class GeoJSONFeatureCollection(BaseModel):
    type: str = "FeatureCollection"
    features: List[GeoJSONFeature]


COLOR_MAP = {
    "critical": "#ef4444",  # Red
    "high": "#f97316",      # Orange
    "medium": "#eab308",    # Yellow
    "low": "#3b82f6"        # Blue
}


@router.get("/geojson", response_model=GeoJSONFeatureCollection)
def get_geojson(db: Session = Depends(get_db)) -> GeoJSONFeatureCollection:
    """
    Retrieve geo-tagged distress logs formatted as standard GeoJSON feature collection.
    Includes severity-based marker colors.
    """
    distresses = get_distresses(db, limit=1000)
    features = []
    
    for d in distresses:
        color = COLOR_MAP.get(d.severity.lower(), "#64748b")
        features.append(
            GeoJSONFeature(
                geometry=Geometry(coordinates=[d.longitude, d.latitude]),
                properties=GeoJSONProperty(
                    id=d.id,
                    distress_type=d.distress_type,
                    severity=d.severity,
                    status=d.status,
                    marker_color=color,
                    is_cluster=False,
                    point_count=1,
                    highest_severity=d.severity
                )
            )
        )
        
    return GeoJSONFeatureCollection(features=features)


@router.get("/geojson/clusters", response_model=GeoJSONFeatureCollection)
def get_geojson_clusters(
    radius: float = 0.02,
    db: Session = Depends(get_db)
) -> GeoJSONFeatureCollection:
    """
    Retrieve geo-tagged distress logs grouped/clustered by proximity using threshold radius.
    Colors matching the highest severity in each cluster.
    """
    distresses = get_distresses(db, limit=1000)
    features = []
    visited = set()
    
    severity_order = {"critical": 4, "high": 3, "medium": 2, "low": 1}
    
    for i, d1 in enumerate(distresses):
        if d1.id in visited:
            continue
            
        cluster_members = [d1]
        visited.add(d1.id)
        
        for j in range(i + 1, len(distresses)):
            d2 = distresses[j]
            if d2.id in visited:
                continue
                
            # Euclidean distance in degrees
            dist = ((d1.latitude - d2.latitude) ** 2 + (d1.longitude - d2.longitude) ** 2) ** 0.5
            if dist <= radius:
                cluster_members.append(d2)
                visited.add(d2.id)
                
        # Calculate cluster centroid coordinates
        avg_lat = sum(m.latitude for m in cluster_members) / len(cluster_members)
        avg_lon = sum(m.longitude for m in cluster_members) / len(cluster_members)
        
        # Determine highest severity contained in this cluster (Task 4)
        highest_sev = "low"
        highest_order = 0
        for m in cluster_members:
            order = severity_order.get(m.severity.lower(), 1)
            if order > highest_order:
                highest_order = order
                highest_sev = m.severity.lower()
                
        color = COLOR_MAP.get(highest_sev, "#64748b")
        
        if len(cluster_members) > 1:
            features.append(
                GeoJSONFeature(
                    geometry=Geometry(coordinates=[avg_lon, avg_lat]),
                    properties=GeoJSONProperty(
                        marker_color=color,
                        is_cluster=True,
                        point_count=len(cluster_members),
                        highest_severity=highest_sev,
                        ids=[m.id for m in cluster_members]
                    )
                )
            )
        else:
            features.append(
                GeoJSONFeature(
                    geometry=Geometry(coordinates=[d1.longitude, d1.latitude]),
                    properties=GeoJSONProperty(
                        id=d1.id,
                        distress_type=d1.distress_type,
                        severity=d1.severity,
                        status=d1.status,
                        marker_color=color,
                        is_cluster=False,
                        point_count=1,
                        highest_severity=d1.severity
                    )
                )
            )
            
    return GeoJSONFeatureCollection(features=features)
