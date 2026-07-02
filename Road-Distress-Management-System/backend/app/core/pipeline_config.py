"""
Global pipeline configuration file for severity thresholds, cost estimations,
rehabilitation recommendation rules, and priority classification parameters.
"""

# Damage area thresholds (as percentage of frame occupied by the bounding box)
AREA_THRESHOLDS = {
    "very_small": 1.5,   # Low severity threshold
    "small": 5.0,        # Medium severity threshold
    "medium": 12.0,      # High severity threshold
    "large": 12.0        # Critical severity threshold
}

# Distress-specific severity adjustments and multipliers
DISTRESS_SEVERITY_CONFIG = {
    "pothole": {
        "area_multiplier": 1.5,       # Potholes occupy more priority and severity
        "base_severity_offset": 1.0,  # Shift severity higher
    },
    "alligator_crack": {
        "area_multiplier": 1.3,
        "base_severity_offset": 0.5,
    },
    "longitudinal_crack": {
        "area_multiplier": 0.8,       # Gradual cracks
        "base_severity_offset": 0.0,
    },
    "transverse_crack": {
        "area_multiplier": 0.8,
        "base_severity_offset": 0.0,
    },
    "default": {
        "area_multiplier": 1.0,
        "base_severity_offset": 0.0,
    }
}

# Standard rehabilitation cost mapping by distress type, severity, and area
REHABILITATION_COST_CONFIG = {
    "pothole": {
        "base": 15000,
        "multiplier_critical": 5.0,
        "multiplier_high": 3.6,
        "multiplier_medium": 2.0,
        "multiplier_low": 1.0,
        "cost_per_percentage_area": 12000
    },
    "alligator_crack": {
        "base": 25000,
        "multiplier_critical": 4.5,
        "multiplier_high": 3.2,
        "multiplier_medium": 1.8,
        "multiplier_low": 1.0,
        "cost_per_percentage_area": 15000
    },
    "longitudinal_crack": {
        "base": 10000,
        "multiplier_critical": 4.0,
        "multiplier_high": 2.8,
        "multiplier_medium": 1.5,
        "multiplier_low": 1.0,
        "cost_per_percentage_area": 8000
    },
    "transverse_crack": {
        "base": 10000,
        "multiplier_critical": 4.0,
        "multiplier_high": 2.8,
        "multiplier_medium": 1.5,
        "multiplier_low": 1.0,
        "cost_per_percentage_area": 8000
    },
    "default": {
        "base": 12000,
        "multiplier_critical": 4.0,
        "multiplier_high": 3.0,
        "multiplier_medium": 1.8,
        "multiplier_low": 1.0,
        "cost_per_percentage_area": 10000
    }
}

# Priority mapping parameters based on severity score index
PRIORITY_MAPPING = {
    "critical": "P1",
    "high": "P2",
    "medium": "P3",
    "low": "P4"
}

# Physical dimensions calibration (Task 3)
# Scale factor representing meters per pixel (e.g., 0.0015 translates 1 pixel to 1.5 mm)
PIXEL_TO_METER_SCALE = 0.0015
