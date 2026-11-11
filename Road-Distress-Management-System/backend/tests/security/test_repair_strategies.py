"""
IRC:82-2015 / IRC:SP:83-2018 repair strategies: rules, report sections and how they reach the maintenance plan.
"""

from io import BytesIO
from types import SimpleNamespace

import pytest
from reportlab.lib.pagesizes import letter
from reportlab.platypus import Paragraph, SimpleDocTemplate

from app.services.maintenance_recommendation import recommend_maintenance
from app.services.repair_report_sections import (
    add_repair_strategy_sheet,
    group_strategies,
    repair_strategy_flowables,
    row_recommendation,
)
from app.services.repair_strategies import (
    BITUMINOUS,
    CONCRETE,
    normalise_class,
    normalise_pavement,
    pothole_size_class,
    severity_tier,
    strategy_for,
)


def d(kind, severity, diameter=None):
    return SimpleNamespace(distress_type=kind, severity=severity, pothole_diameter=diameter)


# ------------------------------------------------------------------------------------------ normalisation
@pytest.mark.parametrize("name,expected", [
    ("longitudinal_crack", "longitudinal"), ("Longitudinal Crack", "longitudinal"),
    ("transverse_crack", "transverse"), ("alligator_crack", "alligator"), ("pothole", "pothole"),
    ("POTHOLE", "pothole"), ("TRAFFIC SIGN", None), ("SIGN BOARD", None), ("POLES", None), ("", None), (None, None),
])
def test_class_names_are_recognised(name, expected):
    assert normalise_class(name) == expected


def test_critical_is_treated_as_high_and_unknown_as_medium():
    assert severity_tier("critical") == "high" and severity_tier("HIGH") == "high"
    assert severity_tier("low") == "low" and severity_tier("medium") == "medium"
    assert severity_tier("weird") == "medium" and severity_tier(None) == "medium"


def test_pavement_names():
    assert normalise_pavement("concrete") == CONCRETE and normalise_pavement("Rigid") == CONCRETE
    assert normalise_pavement(None) == BITUMINOUS and normalise_pavement("anything") == BITUMINOUS


def test_pothole_size_uses_diameter_first_then_severity():
    assert pothole_size_class("high", 0.15) == "small"      # diameter wins over severity
    assert pothole_size_class("low", 0.4) == "medium"
    assert pothole_size_class("low", 0.8) == "large"
    assert [pothole_size_class(s) for s in ("low", "medium", "high", "critical")] == ["small", "medium", "large", "large"]


# ------------------------------------------------------------------------------------------ bituminous rules
def test_longitudinal_cracks_low_and_medium_are_sealed_high_are_replaced():
    for sev in ("low", "medium"):
        assert strategy_for("longitudinal_crack", sev).headline == "Crack sealing, preferably with rubberised bitumen"
    for sev in ("high", "critical"):
        assert strategy_for("longitudinal_crack", sev).headline == "Remove and replace the cracked layer with a fresh overlay"


def test_transverse_cracks_follow_slurry_seal_types_by_width():
    assert "Type II" in strategy_for("transverse_crack", "low").headline
    assert "Type III" in strategy_for("transverse_crack", "medium").headline
    high = strategy_for("transverse_crack", "high")
    assert high.headline == "Crack sealing with rubberised bitumen"
    assert any("only cover cracks up to 6 mm" in s for s in high.steps)


def test_alligator_cracking_starts_with_finding_the_cause():
    for sev in ("low", "medium", "high"):
        s = strategy_for("alligator_crack", sev)
        assert s.steps[0].startswith("First find the cause")
        assert any("designed overlay" in step for step in s.steps)
    assert any("essential" in c for c in strategy_for("alligator_crack", "high").cautions)


def test_pothole_strategy_depends_on_size_and_keeps_the_depth_rule():
    small = strategy_for("pothole", "low")
    large = strategy_for("pothole", "high")
    assert small.size_class == "small" and large.size_class == "large"
    assert small.headline.startswith("Fill with open-graded premix")
    assert "layers" in large.headline
    assert any("75 mm" in step for step in large.steps)
    assert strategy_for("pothole", "low", pothole_diameter_m=0.7).size_class == "large"


def test_signage_has_no_repair_strategy():
    for name in ("TRAFFIC SIGN", "SIGN BOARD", "POLES"):
        assert strategy_for(name, "high") is None


# ------------------------------------------------------------------------------------------ concrete rules
def test_concrete_cracks_give_both_depth_branches():
    s = strategy_for("longitudinal_crack", "low", pavement=CONCRETE)
    text = " ".join(s.steps)
    assert "Depth under D/2" in text and "Depth over D/2" in text and "cross-stitch" in text
    assert "IRC:SP:83" in s.reference


def test_concrete_pothole_follows_table_4_5_by_diameter():
    assert strategy_for("pothole", "low", CONCRETE, pothole_diameter_m=0.07).headline == "Partial-depth repair, about 65 mm deep"
    assert strategy_for("pothole", "low", CONCRETE, pothole_diameter_m=0.2).headline == "Partial-depth repair, 10 mm deeper than the hole"
    assert strategy_for("pothole", "low", CONCRETE, pothole_diameter_m=0.45).headline == "Full-depth repair"
    assert strategy_for("pothole", "high", CONCRETE).headline == "Full-depth repair"


def test_concrete_multiple_cracking_ends_in_reconstruction_when_severe():
    assert "reconstruct the whole slab" in strategy_for("alligator_crack", "high", CONCRETE).headline


@pytest.mark.parametrize("pavement", [BITUMINOUS, CONCRETE])
@pytest.mark.parametrize("kind", ["longitudinal_crack", "transverse_crack", "alligator_crack", "pothole"])
@pytest.mark.parametrize("sev", ["low", "medium", "high", "critical"])
def test_every_combination_has_a_complete_strategy(pavement, kind, sev):
    s = strategy_for(kind, sev, pavement)
    assert s is not None and s.headline and len(s.steps) >= 2 and s.reference
    assert s.pavement == pavement
    assert s.severity in ("Low", "Medium", "High")


# ------------------------------------------------------------------------------------------ report sections
def test_groups_are_counted_and_ordered_most_severe_first():
    items = [d("pothole", "low"), d("pothole", "low"), d("alligator_crack", "high"), d("longitudinal_crack", "medium"),
             d("TRAFFIC SIGN", "low")]
    groups = group_strategies(items, BITUMINOUS)
    assert [(s.severity, c) for s, c in groups] == [("High", 1), ("Medium", 1), ("Low", 2)]


def test_row_recommendation_prefers_the_code_and_falls_back_for_signage():
    assert row_recommendation(d("pothole", "low"), "old generic text", BITUMINOUS).startswith("Fill with open-graded premix")
    assert row_recommendation(d("TRAFFIC SIGN", "low"), "Clean and straighten the sign", BITUMINOUS) == "Clean and straighten the sign"
    assert row_recommendation(d("TRAFFIC SIGN", "low"), None, BITUMINOUS) == "Inspect and formulate patching schedule."


def _plain(flowables):
    return "\n".join(f.getPlainText() for f in flowables if isinstance(f, Paragraph) or hasattr(f, "getPlainText")) + "\n".join(
        inner.getPlainText() for f in flowables if hasattr(f, "_content") for inner in f._content if hasattr(inner, "getPlainText"))


def test_pdf_section_builds_and_names_the_codes_and_strategies():
    flow = repair_strategy_flowables([d("pothole", "high"), d("longitudinal_crack", "low")], BITUMINOUS)
    text = _plain(flow)  # read before building: build() consumes the list
    buf = BytesIO()
    SimpleDocTemplate(buf, pagesize=letter).build(list(flow))
    assert buf.getvalue().startswith(b"%PDF")
    assert "Recommended Repair Strategies" in text and "IRC:82-2015" in text
    assert "Crack sealing, preferably with rubberised bitumen" in text
    assert "Pothole - High severity (large pothole)" in text


def test_pdf_section_with_no_repairable_distress_says_so():
    flow = repair_strategy_flowables([d("TRAFFIC SIGN", "low")], BITUMINOUS)
    assert "No detected distress has a repair strategy" in _plain(flow)
    flow_empty = repair_strategy_flowables([], CONCRETE)
    assert "IRC:SP:83-2018" in _plain(flow_empty)


def test_excel_sheet_lists_each_strategy_with_counts():
    import openpyxl
    wb = openpyxl.Workbook()
    add_repair_strategy_sheet(wb, [d("pothole", "low"), d("pothole", "low"), d("transverse_crack", "high")], BITUMINOUS)
    ws = wb["Repair Strategies"]
    assert ws["A1"].value == "RECOMMENDED REPAIR STRATEGIES"
    assert "IRC:82-2015" in ws["A2"].value
    rows = [[c.value for c in row] for row in ws.iter_rows(min_row=6, max_row=7)]
    assert rows[0][0] == "Transverse crack" and rows[0][1] == "High" and rows[0][2] == 1
    assert rows[1][0] == "Pothole (small)" and rows[1][2] == 2
    assert "1. " in rows[1][4] and "IRC:82-2015" in rows[1][7]


# ------------------------------------------------------------------------------------------ maintenance plan + route
def test_maintenance_recommendation_uses_the_code_strategy_for_cracks_and_potholes():
    rec = recommend_maintenance("pothole", "low", 0.9, damage_percentage=1.0)
    assert rec["recommended_action"] == "Fill with open-graded premix and finish with a seal coat"
    rec = recommend_maintenance("longitudinal_crack", "high", 0.9, damage_percentage=6.0)
    assert rec["recommended_action"] == "Remove and replace the cracked layer with a fresh overlay"
    # priority, category and cost logic are untouched
    assert rec["priority"] in ("P1", "P2", "P3", "P4") and rec["estimated_cost"] > 0


def test_maintenance_recommendation_keeps_escalation_text_and_non_code_distresses():
    rec = recommend_maintenance("pothole", "low", 0.9, frequency=3, damage_percentage=1.0)
    assert rec["recommended_action"].endswith("(Escalated due to high recurrence frequency)")
    other = recommend_maintenance("rutting", "low", 0.9, damage_percentage=1.0)
    assert "Micro-Surfacing" in other["recommended_action"]


def test_maintenance_recommendation_can_target_concrete():
    rec = recommend_maintenance("pothole", "high", 0.9, damage_percentage=8.0, pavement=CONCRETE)
    assert rec["recommended_action"] == "Full-depth repair"


def test_report_routes_reject_an_unknown_pavement_type(client, admin):
    _uid, _email, headers = admin
    for path in ("/api/v1/reports/generate/999999", "/api/v1/reports/excel/999999"):
        assert client.post(path + "?pavement=gravel", headers=headers).status_code == 422
        assert client.post(path + "?pavement=concrete", headers=headers).status_code == 404  # valid type, no such video
