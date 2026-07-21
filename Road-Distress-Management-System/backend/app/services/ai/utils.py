"""
AI processing helper utility functions.
"""

import random
from typing import Optional, Tuple

# Mapping from class ID to distress type
# Signage classes (offset by 10 to prevent collision): the real signage_best.pt
# checkpoint outputs exactly 3 classes (confirmed via head.cls_preds output shape,
# see model_loader.py), not 4. The original training class names/order aren't known
# (no exp config file for this checkpoint is present in this repo), so these are
# honest placeholders rather than a guessed specific taxonomy -- update them once
# the real names are confirmed.
CLASS_MAPPING = {
    0: "longitudinal_crack",
    1: "transverse_crack",
    2: "alligator_crack",
    3: "pothole",
    10: "TRAFFIC SIGN",
    11: "SIGN BOARD",
    12: "POLES"
}

# Base location coordinates from seed data for realistic Indian corridor simulation
BASE_LOCATIONS = [
    (18.7501, 73.4002),  # Lonavala Ghats NH-48
    (18.5912, 73.7123),  # Hinjewadi Phase 3 Road
    (19.0824, 72.9135),  # Ghatkopar Flyover Eastern Express
    (19.2015, 73.0112),  # Thane Toll Plaza Corridor
    (13.1042, 77.3821),  # Nelamangala Highway NH-48
    (12.8915, 77.4812),  # Kengeri Metro Corridor SH-17
    (12.5231, 76.9015),  # Mandya Bypass NH-275
    (15.3614, 75.1213),  # Davangere Highway Corridor
    (28.5612, 77.2145),  # Ring Road AIIMS Underpass
    (28.6315, 77.2212),  # CP Outer Circle G-Block
    (28.5942, 77.1712),  # Dhaula Kuan Flyover Loop
    (12.9214, 80.1215),  # Tambaram-Chengalpattu Flyover
    (13.0712, 80.2014),  # Koyambedu Junction Flyover
    (12.9712, 77.5914)   # MG Road Metro Pillar 110
]


def map_class_id_to_name(class_id: int) -> str:
    """
    Map YOLO class integer ID to human readable distress type.
    """
    return CLASS_MAPPING.get(class_id, "unknown")


def map_confidence_to_severity(confidence: float) -> str:
    """
    Convert confidence score into severity classification.
    """
    if confidence >= 0.8:
        return "critical" if confidence >= 0.9 else "high"
    elif confidence >= 0.5:
        return "medium"
    else:
        return "low"


def generate_gps_coordinates() -> Tuple[float, float]:
    """
    Generates realistic GPS coordinates by picking a base corridor location
    and applying a small random geographical offset.
    """
    base_lat, base_lon = random.choice(BASE_LOCATIONS)
    # Small offset: +/- 0.005 approx 500 meters
    offset_lat = random.uniform(-0.005, 0.005)
    offset_lon = random.uniform(-0.005, 0.005)
    return round(base_lat + offset_lat, 6), round(base_lon + offset_lon, 6)


def calculate_engineering_severity(
    class_name: str,
    box: list,
    frame_width: int,
    frame_height: int,
    confidence: float
) -> Tuple[str, dict]:
    """
    Computes engineering-based severity and damage metrics from bounding box coordinates,
    frame dimensions, distress type, and confidence score.
    """
    x1, y1, x2, y2 = box
    width = x2 - x1
    height = y2 - y1
    area = width * height
    
    total_pixels = frame_width * frame_height
    percentage = (area / total_pixels) * 100.0 if total_pixels > 0 else 0.0
    
    from app.core.pipeline_config import (
        AREA_THRESHOLDS,
        DISTRESS_SEVERITY_CONFIG
    )
    
    cfg = DISTRESS_SEVERITY_CONFIG.get(class_name.lower(), DISTRESS_SEVERITY_CONFIG["default"])
    effective_percentage = percentage * cfg["area_multiplier"]
    
    if effective_percentage < AREA_THRESHOLDS["very_small"]:
        severity_level = "low"
    elif effective_percentage < AREA_THRESHOLDS["small"]:
        severity_level = "medium"
    elif effective_percentage < AREA_THRESHOLDS["medium"]:
        severity_level = "high"
    else:
        severity_level = "critical"
        
    severity_ranks = ["low", "medium", "high", "critical"]
    rank_idx = severity_ranks.index(severity_level)
    offset = cfg.get("base_severity_offset", 0.0)
    if offset > 0:
        rank_idx = min(3, rank_idx + int(offset))
        
    # Secondary factor: confidence level adjustments
    if confidence < 0.40 and rank_idx > 0:
        rank_idx -= 1
    elif confidence >= 0.90 and rank_idx == 0:
        rank_idx = 1
        
    severity = severity_ranks[rank_idx]
    
    metrics = {
        "damage_width_pixels": round(width, 2),
        "damage_height_pixels": round(height, 2),
        "damage_area_pixels": round(area, 2),
        "damage_percentage_of_frame": round(percentage, 4)
    }
    
    return severity, metrics


def estimate_damage_metrics(severity: str, distress_type: str) -> dict:
    """
    Reconstructs approximate damage metrics for a given severity and distress type.
    Used to support backward compatibility in analytics and reports.
    """
    from app.core.pipeline_config import (
        AREA_THRESHOLDS,
        DISTRESS_SEVERITY_CONFIG
    )
    
    sev = severity.lower()
    if sev == "critical":
        pct = AREA_THRESHOLDS["medium"] + 3.0
    elif sev == "high":
        pct = (AREA_THRESHOLDS["small"] + AREA_THRESHOLDS["medium"]) / 2.0
    elif sev == "medium":
        pct = (AREA_THRESHOLDS["very_small"] + AREA_THRESHOLDS["small"]) / 2.0
    else:
        pct = AREA_THRESHOLDS["very_small"] / 2.0
        
    cfg = DISTRESS_SEVERITY_CONFIG.get(distress_type.lower(), DISTRESS_SEVERITY_CONFIG["default"])
    pct = pct / cfg["area_multiplier"]
    
    total_pixels = 307200
    area_pixels = (pct / 100.0) * total_pixels
    width = (area_pixels * 1.33) ** 0.5
    height = area_pixels / width
    
    return {
        "damage_percentage_of_frame": round(pct, 4),
        "damage_area_pixels": round(area_pixels, 2),
        "damage_width_pixels": round(width, 2),
        "damage_height_pixels": round(height, 2)
    }


def calculate_road_health_score(distresses: list) -> float:
    """
    Calculates overall Road Health Score (0 to 100) based on distress density and severity.
    """
    if not distresses:
        return 100.0
        
    penalty = 0.0
    for d in distresses:
        sev = d.severity.lower()
        if sev == "critical":
            weight = 5.0
        elif sev == "high":
            weight = 3.0
        elif sev == "medium":
            weight = 1.5
        else:
            weight = 0.5
            
        pct = getattr(d, "damage_percentage_of_frame", None)
        if pct is None:
            metrics = estimate_damage_metrics(d.severity, d.distress_type)
            pct = metrics["damage_percentage_of_frame"]
        
        penalty += weight * (1.0 + pct * 0.1)
        
    score = 100.0 - penalty
    return max(0.0, round(score, 2))


def format_seconds_to_hhmmss_mmm(seconds: float) -> str:
    """
    Converts seconds (float) into HH:MM:SS.mmm string format.
    Examples:
      0.0 -> 00:00:00.000
      5.37 -> 00:00:05.370
      65.42 -> 00:01:05.420
      3723.11 -> 01:02:03.110
    """
    if seconds is None:
        return "00:00:00.000"
    
    hours = int(seconds // 3600)
    minutes = int((seconds % 3600) // 60)
    secs = int(seconds % 60)
    milliseconds = int(round((seconds - int(seconds)) * 1000))
    
    # Handle rollover of milliseconds
    if milliseconds >= 1000:
        secs += milliseconds // 1000
        milliseconds = milliseconds % 1000
        if secs >= 60:
            minutes += secs // 60
            secs = secs % 60
            if minutes >= 60:
                hours += minutes // 60
                minutes = minutes % 60
                
    return f"{hours:02d}:{minutes:02d}:{secs:02d}.{milliseconds:03d}"


def generate_gps_coordinates_for_video(
    video_id: Optional[int],
    frame_number: Optional[int],
    timestamp: Optional[float]
) -> Tuple[float, float]:
    """
    Generates realistic GPS coordinates along a continuous trajectory for a given video
    to simulate a vehicle traversing a road corridor. Prevents random jumps.
    """
    import random
    import math
    
    # We must explicitly type check inside since SQLAlchemy or types might be None
    v_id = video_id if isinstance(video_id, int) else None
    f_num = frame_number if isinstance(frame_number, int) else None
    ts = timestamp if isinstance(timestamp, (int, float)) else None
    
    if v_id is None:
        # Fallback to random pick for manual/imaginary source types
        base_lat, base_lon = random.choice(BASE_LOCATIONS)
        offset_lat = random.uniform(-0.005, 0.005)
        offset_lon = random.uniform(-0.005, 0.005)
        return round(base_lat + offset_lat, 6), round(base_lon + offset_lon, 6)
        
    base_idx = v_id % len(BASE_LOCATIONS)
    base_lat, base_lon = BASE_LOCATIONS[base_idx]
    
    # Generate deterministic heading/angle using video_id as seed
    local_rng = random.Random(v_id)
    angle = local_rng.uniform(0, 2 * math.pi)
    
    # speed is approx 0.0001 degrees of lat/lon per second (approx 40 km/h)
    speed = 0.0001
    speed_lat = speed * math.sin(angle)
    speed_lon = speed * math.cos(angle)
    
    # Use timestamp if available, otherwise estimate from frame number (assuming 30 fps)
    t = 0.0
    if ts is not None:
        t = ts
    elif f_num is not None:
        t = f_num / 30.0
        
    lat = base_lat + t * speed_lat
    lon = base_lon + t * speed_lon
    
    # Add a tiny noise perpendicular to the direction to simulate slight lane deviations
    # range: +/- 0.00001 degrees (approx +/- 1 meter)
    perp_angle = angle + (math.pi / 2)
    noise = local_rng.uniform(-0.00001, 0.00001)
    lat += noise * math.sin(perp_angle)
    lon += noise * math.cos(perp_angle)
    
    return round(lat, 6), round(lon, 6)

