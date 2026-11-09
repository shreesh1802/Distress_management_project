"""
Report sections that show the repair strategy for the distresses found in a video (PDF section and Excel sheet),
plus the one-line recommendation used in the per-detection tables. The rules live in ``repair_strategies``.
"""

from collections import OrderedDict
from typing import Any, Iterable, List, Optional, Tuple
from xml.sax.saxutils import escape

from reportlab.lib import colors
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.platypus import KeepTogether, Paragraph, Spacer

from app.services.repair_strategies import (
    BASIS_NOTE,
    PAVEMENT_LABELS,
    RepairStrategy,
    normalise_pavement,
    strategy_for,
)

_SEVERITY_RANK = {"High": 0, "Medium": 1, "Low": 2}
_SEVERITY_COLOUR = {"High": "#ea580c", "Medium": "#ca8a04", "Low": "#2563eb"}


def strategy_for_distress(distress: Any, pavement: Optional[str]) -> Optional[RepairStrategy]:
    """The strategy for one RoadDistress row (uses its estimated pothole diameter when it has one)."""
    return strategy_for(
        getattr(distress, "distress_type", ""),
        getattr(distress, "severity", ""),
        pavement=normalise_pavement(pavement),
        pothole_diameter_m=getattr(distress, "pothole_diameter", None),
    )


def row_recommendation(distress: Any, stored_recommendation: Optional[str], pavement: Optional[str]) -> str:
    """Text for a per-detection table: the code-based strategy when there is one, else the stored task text."""
    strategy = strategy_for_distress(distress, pavement)
    if strategy is not None:
        return strategy.headline
    return stored_recommendation or "Inspect and formulate patching schedule."


def group_strategies(distresses: Iterable[Any], pavement: Optional[str]) -> List[Tuple[RepairStrategy, int]]:
    """One entry per distinct strategy, with how many detections it covers; most severe first."""
    groups: "OrderedDict[str, List[Any]]" = OrderedDict()
    for d in distresses:
        strategy = strategy_for_distress(d, pavement)
        if strategy is None:
            continue
        entry = groups.setdefault(strategy.title, [strategy, 0])
        entry[1] += 1
    ordered = sorted(groups.values(), key=lambda e: (_SEVERITY_RANK.get(e[0].severity, 3), e[0].distress, e[0].title))
    return [(strategy, count) for strategy, count in ordered]


# --------------------------------------------------------------------------------------------------- PDF
def repair_strategy_flowables(distresses: Iterable[Any], pavement: Optional[str]) -> list:
    """Platypus flowables for the 'Recommended Repair Strategies' section."""
    pavement = normalise_pavement(pavement)
    base = getSampleStyleSheet()["Normal"]
    h1 = ParagraphStyle("RepairH1", parent=base, fontName="Helvetica-Bold", fontSize=13, leading=16,
                        textColor=colors.HexColor("#1e3a8a"), spaceBefore=6, spaceAfter=6)
    body = ParagraphStyle("RepairBody", parent=base, fontSize=8.5, leading=11)
    note = ParagraphStyle("RepairNote", parent=body, fontName="Helvetica-Oblique", textColor=colors.HexColor("#475569"))
    block_title = ParagraphStyle("RepairBlockTitle", parent=body, fontName="Helvetica-Bold", fontSize=10, leading=13,
                                 spaceBefore=8)
    bullet = ParagraphStyle("RepairBullet", parent=body, leftIndent=12, bulletIndent=2)

    flow: list = [
        Paragraph("Recommended Repair Strategies", h1),
        Paragraph(f"<b>Pavement type:</b> {escape(PAVEMENT_LABELS[pavement])}", body),
        Paragraph(escape(BASIS_NOTE), note),
        Spacer(1, 4),
    ]

    groups = group_strategies(distresses, pavement)
    if not groups:
        flow.append(Paragraph("No detected distress has a repair strategy in the IRC codes used.", body))
        flow.append(Spacer(1, 10))
        return flow

    for strategy, count in groups:
        colour = _SEVERITY_COLOUR.get(strategy.severity, "#334155")
        block: list = [
            Paragraph(
                f"<font color='{colour}'>{escape(strategy.title)}</font> "
                f"<font size=8 color='#64748b'>({count} detection{'s' if count != 1 else ''})</font>",
                block_title,
            ),
            Paragraph(f"<b>Recommended:</b> {escape(strategy.headline)}.", body),
            Paragraph("<b>Procedure</b>", body),
        ]
        block.extend(Paragraph(escape(step), bullet, bulletText="•") for step in strategy.steps)
        if strategy.materials:
            block.append(Paragraph("<b>Materials</b>", body))
            block.extend(Paragraph(escape(m), bullet, bulletText="•") for m in strategy.materials)
        if strategy.cautions:
            block.append(Paragraph("<b>Notes</b>", body))
            block.extend(Paragraph(escape(c), bullet, bulletText="•") for c in strategy.cautions)
        block.append(Paragraph(f"<font color='#64748b'>Reference: {escape(strategy.reference)}</font>", body))
        flow.append(KeepTogether(block))
    flow.append(Spacer(1, 10))
    return flow


# --------------------------------------------------------------------------------------------------- Excel
def add_repair_strategy_sheet(wb: Any, distresses: Iterable[Any], pavement: Optional[str]) -> Any:
    """Adds the 'Repair Strategies' worksheet to an openpyxl workbook and returns it."""
    from openpyxl.styles import Alignment, Border, Font, PatternFill, Side

    pavement = normalise_pavement(pavement)
    ws = wb.create_sheet(title="Repair Strategies")
    font = "Segoe UI"
    side = Side(border_style="thin", color="D3D3D3")
    border = Border(left=side, right=side, top=side, bottom=side)
    headers = ["Distress", "Severity", "Detections", "Recommended strategy", "Procedure", "Materials",
               "Notes", "Reference"]
    widths = [26, 11, 11, 44, 80, 48, 52, 38]

    ws.merge_cells(start_row=1, start_column=1, end_row=1, end_column=len(headers))
    title = ws.cell(row=1, column=1, value="RECOMMENDED REPAIR STRATEGIES")
    title.font = Font(name=font, size=14, bold=True, color="FFFFFF")
    title.alignment = Alignment(horizontal="center", vertical="center")
    for c in range(1, len(headers) + 1):
        ws.cell(row=1, column=c).fill = PatternFill(start_color="1F4E78", end_color="1F4E78", fill_type="solid")
    ws.row_dimensions[1].height = 28

    ws.cell(row=2, column=1, value=f"Pavement type: {PAVEMENT_LABELS[pavement]}").font = Font(name=font, size=11, bold=True)
    ws.merge_cells(start_row=3, start_column=1, end_row=3, end_column=len(headers))
    basis = ws.cell(row=3, column=1, value=BASIS_NOTE)
    basis.font = Font(name=font, size=9, italic=True, color="595959")
    basis.alignment = Alignment(wrap_text=True, vertical="top")
    ws.row_dimensions[3].height = 40

    for col, text in enumerate(headers, start=1):
        cell = ws.cell(row=5, column=col, value=text)
        cell.font = Font(name=font, size=11, bold=True, color="FFFFFF")
        cell.fill = PatternFill(start_color="1F4E78", end_color="1F4E78", fill_type="solid")
        cell.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
        cell.border = border
    for col, width in enumerate(widths, start=1):
        ws.column_dimensions[ws.cell(row=5, column=col).column_letter].width = width

    sev_colour = {"High": "EF6C00", "Medium": "D6A23A", "Low": "3B82F6"}
    row = 6
    groups = group_strategies(distresses, pavement)
    for strategy, count in groups:
        values = [
            strategy.distress + (f" ({strategy.size_class})" if strategy.size_class else ""),
            strategy.severity,
            count,
            strategy.headline,
            "\n".join(f"{i}. {step}" for i, step in enumerate(strategy.steps, start=1)),
            "\n".join(f"- {m}" for m in strategy.materials),
            "\n".join(f"- {c}" for c in strategy.cautions),
            strategy.reference,
        ]
        longest = max(len(values[4]) / 78, len(values[5]) / 46, len(values[6]) / 50, len(values[3]) / 42, 1)
        ws.row_dimensions[row].height = min(409, 15 * (int(longest) + 1))
        for col, value in enumerate(values, start=1):
            cell = ws.cell(row=row, column=col, value=value)
            cell.font = Font(name=font, size=10, bold=(col == 2),
                             color=sev_colour.get(strategy.severity, "000000") if col == 2 else "000000")
            cell.alignment = Alignment(wrap_text=True, vertical="top",
                                       horizontal="center" if col in (2, 3) else "left")
            cell.border = border
        row += 1

    if not groups:
        ws.cell(row=6, column=1, value="No detected distress has a repair strategy in the IRC codes used.").font = Font(
            name=font, size=10, italic=True)
    ws.freeze_panes = "A6"
    return ws
