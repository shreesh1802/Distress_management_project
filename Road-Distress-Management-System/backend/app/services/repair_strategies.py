"""
Repair strategies for the distresses the detector reports, taken from:

  * IRC:82-2015       - Code of practice for maintenance of bituminous road surfaces  (flexible pavements)
  * IRC:SP:83-2018    - Guidelines for maintenance, repairs and rehabilitation of cement concrete pavements

(source summary: "Crack and Pothole Repair Strategies as per IRC 82-2015 and IRC SP 83-2018").

``strategy_for(distress_type, severity, pavement=..., pothole_diameter_m=...)`` returns the strategy to put in a
report, or ``None`` for distresses with no repair strategy in the codes (signage, poles ...).

Important limits, repeated in every report (``BASIS_NOTE``):
  * The codes grade cracks by width (mm) and potholes by depth and width. A camera cannot measure those, so the
    detector's severity (low / medium / high / critical) is used as the stand-in: low / medium / high map to the
    IRC low / medium / high bands and critical is treated as high. A pothole's size class uses the estimated
    diameter when there is one, otherwise the severity.
  * For concrete roads the choice also depends on crack depth against half the slab thickness (D/2), which is not
    visible either, so both branches are given.
  * Repair selection always starts with a site check (cause, structural adequacy, moisture).
"""

from dataclasses import dataclass
from typing import Optional, Tuple

BITUMINOUS = "bituminous"
CONCRETE = "concrete"
PAVEMENT_TYPES = (BITUMINOUS, CONCRETE)

PAVEMENT_LABELS = {
    BITUMINOUS: "Bituminous (flexible) pavement - IRC:82-2015",
    CONCRETE: "Cement concrete (rigid) pavement - IRC:SP:83-2018",
}

BASIS_NOTE = (
    "Severity here is estimated from the video. The IRC codes grade cracks by width (mm) and potholes by depth "
    "and width, which a camera cannot measure, so the detector's low / medium / high (critical is treated as high) "
    "stands in for the IRC bands. Confirm the crack width, pothole depth and the structural condition on site "
    "before ordering the work."
)


@dataclass(frozen=True)
class RepairStrategy:
    distress: str                      # "Longitudinal crack"
    severity: str                      # "Low" | "Medium" | "High"
    pavement: str                      # BITUMINOUS | CONCRETE
    headline: str                      # one line, used in tables and as the maintenance task text
    steps: Tuple[str, ...]
    materials: Tuple[str, ...] = ()
    cautions: Tuple[str, ...] = ()
    reference: str = ""
    size_class: Optional[str] = None   # potholes only

    @property
    def title(self) -> str:
        label = f"{self.distress} - {self.severity} severity"
        return f"{label} ({self.size_class} pothole)" if self.size_class else label


# --------------------------------------------------------------------------------------------- normalisation
def normalise_class(distress_type: str) -> Optional[str]:
    """Maps a detector class name to 'longitudinal' | 'transverse' | 'alligator' | 'pothole', else None."""
    t = (distress_type or "").strip().lower().replace("-", "_").replace(" ", "_")
    if "pothole" in t:
        return "pothole"
    if "alligator" in t or "fatigue" in t:
        return "alligator"
    if "longitudinal" in t:
        return "longitudinal"
    if "transverse" in t:
        return "transverse"
    return None


def severity_tier(severity: str) -> str:
    """low -> low, medium -> medium, high and critical -> high (anything unknown is treated as medium)."""
    s = (severity or "").strip().lower()
    if s == "low":
        return "low"
    if s in ("high", "critical"):
        return "high"
    return "medium"


def pothole_size_class(severity: str, diameter_m: Optional[float] = None) -> str:
    """IRC:82 7.5.3.4: small up to 200 mm wide, medium about 500 mm, large over 500 mm."""
    if diameter_m is not None and diameter_m > 0:
        if diameter_m <= 0.2:
            return "small"
        if diameter_m <= 0.5:
            return "medium"
        return "large"
    return {"low": "small", "medium": "medium", "high": "large"}[severity_tier(severity)]


# --------------------------------------------------------------------------------------------- shared text
_SEAL_STEPS = (
    "Check the pavement is structurally sound first; the treatment depends on whether it is sound or distorted.",
    "Clean the cracks: remove loose material with brooms and, if needed, compressed-air jetting.",
    "Fill with a low-viscosity binder - cut-back, emulsion or rubberised bitumen (ASTM D 5078). For wider cracks use "
    "slurry seal or sand-bituminous premix; for fine cracks over large areas, broom in a fog seal.",
    "Pour the binder from a can and work it in with a hand squeegee.",
    "Blind with a light sanding so traffic does not pick up the binder.",
)

_POTHOLE_STEPS = (
    "Cut the deteriorated pavement around the pothole (square or rectangular) and remove loose particles.",
    "Clean with a stiff wire brush. The pothole need not be dry, but remove excess water.",
    "Apply a prime coat on the WMM or granular surface at the bottom for bond.",
    "Depth up to 75 mm: fill and compact in one layer. Over 75 mm: compact in layers of 25-75 mm (the pothole may "
    "first be filled with Crusher Run Macadam).",
    "Compact the edge first with a hand rammer, then work inwards. Wet the rammer or lay plastic-lined bags on the "
    "mix to stop pick-up.",
    "Leave the compacted patch about 10 mm above the road surface with a hand rammer, or about 3 mm with a small "
    "roller (use a roller where many patches are close together).",
    "Sprinkle clean sand before opening to traffic.",
)

_POTHOLE_MATERIALS = (
    "Open-graded or dense-graded premix, cold or hot: mix for immediate use, storable cold mix (cut-back to IRC:116 "
    "or emulsion to IRC:100), readymade mix, or cold mix from patching machines.",
    "Immediate-use mix: MS, SS-2 or tailor-made emulsion at 7-8% by weight of aggregate (4.5-5.5% residual bitumen).",
    "Readymade cold mix (4.5-5.5% residual bitumen) can be stored up to 6 months and used in wet weather.",
)

_POTHOLE_EQUIPMENT = (
    "Equipment: pavement cutter with air compressor, vibratory plate or roller, spot-mix equipment and traffic "
    "control devices. Mechanised options: machine-mixed cold-mix patching, mobile maintenance units, jet-patching "
    "(velocity spray injection) and infrared patching.",
)


# --------------------------------------------------------------------------------------------- bituminous (IRC:82)
def _bituminous(kind: str, tier: str, severity_label: str, diameter_m: Optional[float], severity: str) -> RepairStrategy:
    if kind == "longitudinal":
        if tier in ("low", "medium"):
            width = "1-3 mm" if tier == "low" else "3-6 mm"
            return RepairStrategy(
                "Longitudinal crack", severity_label, BITUMINOUS,
                "Crack sealing, preferably with rubberised bitumen",
                _SEAL_STEPS,
                ("Rubberised bitumen (preferred), cut-back or emulsion", "Sand for blinding"),
                (f"IRC:82 band for this severity: crack width {width}.",),
                "IRC:82-2015 Sec. 7.3 (crack types) and 7.3.7.5 (crack sealing), Sec. 10.3",
            )
        return RepairStrategy(
            "Longitudinal crack", severity_label, BITUMINOUS,
            "Remove and replace the cracked layer with a fresh overlay",
            (
                "High-severity longitudinal cracking (over 6 mm and frequent) is beyond sealing.",
                "Check the layers below are sound before relaying.",
                "Remove the cracked layer and replace it with a fresh overlay.",
            ),
            (),
            ("IRC:82 band for this severity: crack width over 6 mm and frequent.",),
            "IRC:82-2015 Sec. 7.3 (crack types), Sec. 10.3",
        )

    if kind == "transverse":
        if tier == "low":
            head = "Slurry seal Type II (cracks 1-3 mm), or crack sealing with rubberised bitumen"
        elif tier == "medium":
            head = "Slurry seal Type III (cracks 3-6 mm), or crack sealing with rubberised bitumen"
        else:
            head = "Crack sealing with rubberised bitumen"
        steps = (
            "Slurry seal (SS-2 emulsion, laid 3-6 mm thick): Type I for cracks under 1 mm, Type II for 1-3 mm, "
            "Type III for 3-6 mm. It adds no structural strength, so repair any weak pavement first."
            if tier != "high" else
            "Slurry seal types only cover cracks up to 6 mm, so use crack sealing with rubberised bitumen.",
            *_SEAL_STEPS,
        )
        return RepairStrategy(
            "Transverse crack", severity_label, BITUMINOUS, head, steps,
            ("Rubberised bitumen", "SS-2 emulsion and graded aggregate for slurry seal"),
            ("IRC:82 band for this severity: crack width "
             + {"low": "1-3 mm.", "medium": "3-6 mm.", "high": "over 6 mm and frequent."}[tier],),
            "IRC:82-2015 Sec. 7.3 (crack types), 7.3.7.5 and Sec. 10.3 (slurry seal, crack sealing)",
        )

    if kind == "alligator":
        head = ("Find the cause (pit or core), then seal with emulsion or rubberised bitumen, or mill and recycle the "
                "surface; designed overlay if structurally weak")
        steps = (
            "First find the cause: dig a pit or take a core to check structural adequacy and sub-surface moisture.",
            "If the pavement is structurally adequate: crack sealing with bitumen emulsion, crack sealing with "
            "rubberised or modified bitumen, or milling and surface recycling.",
            "If the pavement is structurally weak: provide a properly designed overlay based on the evaluation.",
            "Where sealing is used, follow the general crack-sealing procedure: clean the cracks, fill with a "
            "low-viscosity binder, work it in with a squeegee and blind with sand.",
        )
        cautions = ("IRC:82 band for this severity: crack width "
                    + {"low": "1-3 mm.", "medium": "3-6 mm.", "high": "over 6 mm."}[tier],)
        if tier == "high":
            cautions += ("At high severity the structural evaluation is essential before choosing sealing.",)
        return RepairStrategy(
            "Alligator (fatigue) cracking", severity_label, BITUMINOUS, head, steps,
            ("Bitumen emulsion, or rubberised / modified bitumen", "Overlay mix as designed from the evaluation"),
            cautions,
            "IRC:82-2015 Sec. 7.3 (alligator / map cracking) and Sec. 10.3",
        )

    # pothole
    size = pothole_size_class(severity, diameter_m)
    size_text = {
        "small": "small (up to 25 mm deep and 200 mm wide)",
        "medium": "medium (25-50 mm deep, about 500 mm wide)",
        "large": "large (over 50 mm deep and over 500 mm wide)",
    }[size]
    head = {
        "small": "Fill with open-graded premix and finish with a seal coat",
        "medium": "Cut square, fill with premix (cold or hot), compact and finish with a seal coat",
        "large": "Cut square and fill with premix compacted in layers (Crusher Run Macadam first if deep); consider "
                 "mechanised patching",
    }[size]
    return RepairStrategy(
        "Pothole", severity_label, BITUMINOUS, head,
        (f"Size class used: {size_text}.", *_POTHOLE_STEPS),
        _POTHOLE_MATERIALS,
        _POTHOLE_EQUIPMENT,
        "IRC:82-2015 Sec. 7.5.3 (potholes), 10.3.7 (premix patching), 10.3.8 (maintenance mixes), Sec. 11",
        size_class=size,
    )


# --------------------------------------------------------------------------------------------- concrete (SP:83)
_CONCRETE_RULES = (
    "Depth test: a crack is non-structural when its depth is under half the slab thickness (D/2) and gets preventive "
    "repair; if deeper than D/2 it is structural and needs corrective repair. Depth is not visible in the video, so "
    "both branches are shown.",
    "Do full-depth repairs, dowel retrofit and cross-stitching before diamond grinding, grooving and joint resealing.",
    "Use repair materials that give at least 6-8 years of service.",
)

_PARTIAL_DEPTH_STEPS = (
    "Mark the boundary: sound the concrete and mark the cut at least 50 mm into sound concrete, square or "
    "rectangular, at least 100 mm x 250 mm.",
    "Remove the affected concrete by sawing and chipping (50 mm deep, not beyond a third of the slab) or cold "
    "milling; chip about 10 mm further into sound concrete. If damage goes beyond half the slab depth, switch to "
    "full-depth repair.",
    "Clean the pit: sandblast, air-blast, high-pressure water jet and dry air. Protect adjacent joints with a bond "
    "breaker.",
    "Apply the bonding agent or primer - the code calls this the most critical step.",
    "Place the repair material, slightly overfill, vibrate and finish from the centre outward. Cementitious repair "
    "material or epoxy mortar for about 65 mm depth, elastomeric concrete for about 40 mm, M40 concrete with 10 mm "
    "down aggregate for depths over 80 mm.",
    "Wet-cure with gunny bag for the first 24 hours, reseal the joints, then open to traffic once the repair has "
    "gained strength.",
)


def _concrete(kind: str, tier: str, severity_label: str, diameter_m: Optional[float], severity: str) -> RepairStrategy:
    ref = "IRC:SP:83-2018 Sec. 4.5 (Table 4.5), 5.3-5.4, Chapters 6-9"

    if kind == "longitudinal":
        both = {
            "low": ("Seal the crack (stitch if longer than 1 m); if deeper than D/2, seal then cross-stitch or staple",
                    "crack width under 3 mm (severity 1-2)"),
            "medium": ("Seal and staple; if deeper than D/2, partial-depth repair with or without dowel bar retrofit",
                       "crack width 3-6 mm (severity 3)"),
            "high": ("Partial-depth repair (6-12 mm cracks) or full-depth repair (over 12 mm with spalling or "
                     "rocking) - deeper than D/2",
                     "crack width over 6 mm (severity 4-5)"),
        }[tier]
        return RepairStrategy(
            "Longitudinal crack", severity_label, CONCRETE, both[0],
            (
                "Depth under D/2 (non-structural): "
                + {"low": "seal the crack, and stitch if the length is over 1 m.",
                   "medium": "seal and staple.",
                   "high": "not applicable at this width (the crack is structural)."}[tier],
                "Depth over D/2 (structural): "
                + {"low": "seal, then cross-stitch or staple.",
                   "medium": "partial-depth repair, with or without dowel bar retrofit.",
                   "high": "partial-depth repair, with or without dowel bar retrofit (6-12 mm); full-depth repair "
                           "for over 12 mm with spalling or rocking."}[tier],
                "Cross-stitching: for full-depth longitudinal cracks narrower than 3 mm and longer than 1 m, with no "
                "spalling - drill 12-20 mm holes at 30-40 degrees, 500-750 mm apart, fill with epoxy and insert "
                "12-16 mm epoxy-coated deformed bars; then reseal the adjacent joint.",
            ),
            ("Low-viscosity epoxy (about 300 cP at 20 C) for cracks 0.5-5 mm", "12-16 mm epoxy-coated deformed bars"),
            (f"IRC:SP:83 band for this severity: {both[1]}.", *_CONCRETE_RULES),
            ref,
        )

    if kind == "transverse":
        both = {
            "low": "Route and seal; if deeper than D/2, seal then cross-stitch or staple",
            "medium": "Seal (stitch if longer than 1 m); if deeper than D/2, full-depth repair",
            "high": "Staple or dowel bar retrofit (structural, over 3 mm)",
        }[tier]
        return RepairStrategy(
            "Transverse / diagonal crack", severity_label, CONCRETE, both,
            (
                "Depth under D/2: " + {"low": "route and seal.",
                                       "medium": "seal, and stitch if the length is over 1 m.",
                                       "high": "not applicable at this width."}[tier],
                "Depth over D/2: " + {"low": "seal, then cross-stitch or staple.",
                                      "medium": "full-depth repair.",
                                      "high": "staple or dowel bar retrofit."}[tier],
                "Do not stitch a full-depth transverse crack that acts as a joint: use dowel bar retrofit or "
                "full-depth repair instead.",
                "Full-depth repair: saw and remove the slab portion, repair the DLC and subbase if damaged, drill and "
                "epoxy dowel or tie bars, place and vibrate the concrete (minimum patch 1.5 m, at least 32 MPa before "
                "opening to traffic), texture and cure.",
            ),
            ("Low-viscosity epoxy", "16-20 mm epoxy-coated U-bars for stapling"),
            (f"IRC:SP:83 band for this severity: crack width "
             + {"low": "under 0.2 mm (severity 1).", "medium": "0.5-3 mm (severity 3).",
                "high": "over 3 mm (severity 4-5)."}[tier], *_CONCRETE_RULES),
            ref,
        )

    if kind == "alligator":
        both = {
            "low": "Seal and stitch if longer than 1 m; if deeper than D/2, dismantle and reconstruct the whole slab",
            "medium": "Full-depth repair; if deeper than D/2, dismantle and reconstruct the whole slab",
            "high": "Full-depth repair, or reinstate the subbase and reconstruct the whole slab",
        }[tier]
        return RepairStrategy(
            "Multiple cracking (slab)", severity_label, CONCRETE, both,
            (
                "Depth under D/2: " + {"low": "seal, and stitch if the length is over 1 m.",
                                       "medium": "full-depth repair.",
                                       "high": "full-depth repair."}[tier],
                "Depth over D/2: " + {"low": "dismantle and reconstruct the whole slab.",
                                      "medium": "dismantle and reconstruct the whole slab.",
                                      "high": "reinstate the subbase and reconstruct the whole slab."}[tier],
                "A slab with more than two full-width cracks should be considered for complete reconstruction.",
            ),
            ("Cement concrete as per full-depth repair specification (at least 32 MPa before opening to traffic)",),
            ("Multiple cracking has no single width band in IRC:SP:83; the severity here follows how badly the panel "
             "is broken up.", *_CONCRETE_RULES),
            ref,
        )

    # pothole / popout in concrete (Table 4.5)
    if diameter_m is not None and diameter_m > 0:
        d_mm = diameter_m * 1000
        band = "small" if d_mm < 100 else ("medium" if d_mm <= 300 else "large")
    else:
        band = {"low": "small", "medium": "medium", "high": "large"}[tier]
    head = {
        "small": "Partial-depth repair, about 65 mm deep",
        "medium": "Partial-depth repair, 10 mm deeper than the hole",
        "large": "Full-depth repair",
    }[band]
    size_text = {
        "small": "popout of 50-100 mm diameter",
        "medium": "pothole of 100-300 mm diameter",
        "large": "pothole over 300 mm diameter and over 100 mm deep",
    }[band]
    steps = (f"Size class used: {size_text}.",)
    if band == "large":
        steps += (
            "Full-depth repair: sound and mark a rectangle at least 50 mm beyond unsound concrete, make buffer cuts "
            "then full-depth cuts, repair the DLC and subbase if damaged, drill and epoxy dowel or tie bars, place, "
            "vibrate and finish the concrete, texture and cure.",
        )
    else:
        steps += _PARTIAL_DEPTH_STEPS
        steps += ("Without saw-cutting (popouts and small potholes): chisel from the middle outward at about 45 degrees "
                  "to a rectangle in sound concrete, drill and epoxy-grout studs, prime with low-viscosity epoxy and "
                  "fill with 1:3 epoxy mortar.",)
    return RepairStrategy(
        "Pothole / popout", severity_label, CONCRETE, head, steps,
        ("Cementitious repair material or epoxy mortar; add at least 5% polysulphide polymer to epoxy mortar for UV "
         "resistance",),
        ("Adjacent patches closer than 300 mm should be combined into one. Partial-depth repairs are generally "
         "susceptible to failure over time.",),
        "IRC:SP:83-2018 Sec. 4.5 (Table 4.5), 8.3 (partial-depth repair), 8.4 (no saw-cutting), Chapter 9",
        size_class={"small": "small", "medium": "medium", "large": "large"}[band],
    )


# --------------------------------------------------------------------------------------------- public API
def strategy_for(
    distress_type: str,
    severity: str,
    pavement: str = BITUMINOUS,
    pothole_diameter_m: Optional[float] = None,
) -> Optional[RepairStrategy]:
    """The repair strategy for one detected distress, or None when the codes give none (signage, poles ...)."""
    kind = normalise_class(distress_type)
    if kind is None:
        return None
    tier = severity_tier(severity)
    label = tier.capitalize()
    builder = _concrete if (pavement or "").lower() == CONCRETE else _bituminous
    return builder(kind, tier, label, pothole_diameter_m, severity)


def normalise_pavement(value: Optional[str]) -> str:
    """'concrete' / 'rigid' / 'cc' -> CONCRETE; everything else (including None) -> BITUMINOUS."""
    v = (value or "").strip().lower()
    return CONCRETE if v in ("concrete", "rigid", "cc", "pqc") else BITUMINOUS
