# Repair strategies in the reports

Every PDF and Excel report now shows the repair strategy for the distresses found, taken from
*Crack and Pothole Repair Strategies as per IRC 82-2015 and IRC SP 83-2018*.

* PDF: a **Recommended Repair Strategies** section after the severity distributions, one block per distress type and
  severity (procedure, materials, notes, code reference), and the per-detection table's *Action Recommendation* column.
* Excel: a **Repair Strategies** sheet (last tab), and the recommendation column of *Detection Details*,
  *Maintenance Plan* and *Chainage Analysis*.
* Maintenance tasks created from now on carry the same one-line action.

## Choosing the pavement type

The reports follow either code:

| Pavement | Code | When |
|---|---|---|
| Bituminous (default) | IRC:82-2015 | asphalt roads - the detector's crack classes are bituminous-pavement terms |
| Cement concrete | IRC:SP:83-2018 | rigid pavements |

In the app: **Reports > Configure AI Reports Compilation > Pavement type** (also next to the live Session report buttons).
The choice is remembered on the device and applies to every report generated from it. The API takes
`?pavement=bituminous|concrete` on `POST /reports/generate/{video_id}` and `POST /reports/excel/{video_id}`.

## How a detection is matched to a strategy

| Detector class | Bituminous (IRC:82) | Concrete (IRC:SP:83) |
|---|---|---|
| longitudinal_crack | low / medium: crack sealing, preferably rubberised bitumen. high: remove and replace the cracked layer | single longitudinal crack |
| transverse_crack | low: slurry seal Type II, medium: Type III, high: rubberised bitumen sealing | single transverse / diagonal crack |
| alligator_crack | find the cause (pit or core), then seal or mill and recycle; designed overlay if weak | multiple cracking of the slab |
| pothole | small / medium / large premix patch with the code's procedure | Table 4.5: partial-depth (about 65 mm, or 10 mm deeper) or full-depth repair |
| traffic sign, sign board, poles | no strategy in the codes - the previous generic text is kept | same |

Severity: the detector's low / medium / high is used for the IRC bands and **critical is treated as high**.
Pothole size class: the estimated diameter when the detection has one (small up to 200 mm, medium up to 500 mm, large
above), otherwise the severity.

## Limits (also printed in every report)

* The codes grade cracks by **width in mm** and potholes by **depth and width**. A camera cannot measure those, so
  the detector's severity stands in. The strategy is a starting point: confirm width, depth and structural condition
  on site before ordering work.
* For concrete roads the choice also depends on whether the crack depth exceeds half the slab thickness (D/2); that
  is not visible either, so both branches are listed.
* Rates, quantities and costs are not part of the source document and are not changed by this feature.

## Changing the rules

All the content is in `backend/app/services/repair_strategies.py` (rules) and
`backend/app/services/repair_report_sections.py` (how it is laid out in PDF / Excel). Tests:
`backend/tests/security/test_repair_strategies.py`.
