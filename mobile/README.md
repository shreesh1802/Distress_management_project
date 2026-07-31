# Road Distress Management — Flutter Web Dashboard

A screen-by-screen Flutter Web port of the React dashboard in
[`Road-Distress-Management-System/frontend`](../Road-Distress-Management-System/frontend).
This is now the active frontend for the project; the React app remains in
the repo as the design/behavior reference each screen is ported against.

## Getting Started

Requires the Flutter SDK (Dart ^3.12.2) with web support enabled.

```bash
cd mobile
flutter pub get
flutter run -d chrome        # dev mode
```

For a release build (recommended if `flutter run -d chrome` has issues with
your browser's remote-debugging policy):

```bash
flutter build web --release
cd build/web
python3 -m http.server 8000  # or: py -m http.server 8000 on Windows
```

Then open `http://localhost:8000` and log in with:

- **Email**: `admin@akcm.com`
- **Password**: `Admin@123`

(See `lib/data/auth_provider.dart` — this is a hardcoded mock check, there's
no real auth backend yet.)

## Project Structure

```text
lib/
├── data/                    # API clients and state (Riverpod providers)
│   ├── auth_provider.dart
│   ├── live_detection_api.dart
│   ├── gis_api.dart
│   ├── video_api.dart       # shared by Upload Video, Live Processing, Dashboard
│   ├── road_distress_api.dart
│   └── maintenance_api.dart
├── router/
│   └── app_router.dart      # go_router routes, mirrors AppRoutes.tsx
├── screens/
│   ├── login/
│   ├── survey/              # Mission Setup
│   ├── dashboard/           # Shell (sidebar + top navbar) + Overview
│   ├── dashboard_grid/      # Dashboard screen (per-run inspection view) + widgets
│   ├── live_detection/      # Live camera detection screen + widgets
│   ├── gis_map/             # GIS Map screen + widgets
│   ├── upload_video/        # Upload Video screen
│   ├── live_processing/     # Live Processing screen
│   ├── road_distresses/     # Road Distresses screen + widgets
│   └── maintenance/         # Maintenance screen + widgets
└── theme/                   # Colors, text styles, ThemeData
```

## Screen Status

| Screen | Status | Notes |
| --- | --- | --- |
| Login | Done | Mock credential check, no real backend auth |
| Survey / Mission Setup | Done | Full port of `SurveyInitialization.tsx` |
| Dashboard shell (sidebar/navbar) | Done | |
| Overview Dashboard | Done | Mock data shaped like `apiService`'s responses |
| Live Detection | Done | **Real backend wiring** — see below |
| GIS Map | Done | **Real backend data** + a real interactive map — see below |
| Upload Video | Done | **Real backend wiring** — see below |
| Live Processing | Done | **Real backend wiring** — see below |
| Road Distresses | Done | **Real backend data** — see below |
| Dashboard (per-run inspection view) | Done | **Real backend data** — see below. Distinct from Overview — `/dashboard` vs. `/overview` in the React source |
| Maintenance | Done | **Real backend data** — see below |
| Reports | Done | **Real backend data** — see below |
| Analytics | Done | **Real backend data** + a real interactive map — see below |
| History | Done | **Real backend data** — see below |
| Video Review | Not started | |
| Notifications | Not started | |
| Settings | Not started | |

Everything above "Live Detection" runs against mock/hardcoded data (no
backend calls). Live Detection and GIS Map are the two exceptions — both are
wired to the real FastAPI backend, described below.

## Live Detection: running it against a real backend

Unlike the other screens, Live Detection (`lib/screens/live_detection/`,
`lib/data/live_detection_api.dart`) talks to the actual backend:

- `POST /api/v1/live/start`, `POST /api/v1/live/stop`, `GET /api/v1/live/status`
- `GET /api/v1/live/stream` — MJPEG video, rendered via a custom
  `MjpegView` widget (Flutter has no built-in `multipart/x-mixed-replace`
  viewer, so this reads the stream manually and scans for JPEG SOI/EOI markers)
- `WS /api/v1/live/ws` — live telemetry/detection events

The base URL is hardcoded to `http://127.0.0.1:8000` (see `kApiBaseUrl` in
`live_detection_api.dart`), matching the React source's default and the fact
that this backend isn't deployed anywhere — it only ever runs locally, next
to whichever machine has the USB camera attached. There's no env-based
override; if you need to point at a different host, edit that constant.

To actually see live video and detections:

1. Run the backend locally (see
   [`Road-Distress-Management-System/backend/README.md`](../Road-Distress-Management-System/backend/README.md#live-camera-detection)
   for setup, including the model files it needs).
2. Have a USB camera attached to that same machine.
3. Open this Flutter app, navigate to **Live Detection**, set the camera
   index, and hit **Start Live Detection**.

Without a backend running, the screen still renders correctly — it shows a
"Live Video Stream Offline" empty state, and hitting Start surfaces a clean
"Failed to start live camera" error instead of crashing (exercises the same
error path the React source's `catch (e) { setError(e.message || ...) }`
does).

## GIS Map: real data, real interactive map

`lib/screens/gis_map/` and `lib/data/gis_api.dart` call the actual
`GET /api/v1/distress/` endpoint (same as the React source's
`apiService.getDistressLogs`, and the same PostgreSQL-backed route as the
backend's `distress.py`) and map the response into marker data the same way
`GISMap.tsx`'s `fetchRealDistresses` does. No auth is required for this
endpoint, so it works standalone without the Live Detection screen's mock
login being anything more than local gating.

The map itself uses [`flutter_map`](https://pub.dev/packages/flutter_map)
(the closest Flutter equivalent to the React source's `react-leaflet`) with
a real OpenStreetMap tile layer — pannable, zoomable, with real
severity-colored markers you can tap to select.

Deliberately trimmed vs. the ~2,900-line React source, since these are all
decorative/simulated and not tied to real backend data:

- No multi-basemap layer switcher (OSM only, no ESRI/Topo/CartoDB options)
- No marker clustering (all markers render individually at every zoom level)
- No simulated survey-vehicle marker, its route animation, hardcoded highway
  route polylines, or chainage milestone labels
- No anchored per-marker popup card (Leaflet's `Popup`) — tapping a marker
  shows the same detail in the floating card overlay + the Road Details
  Panel below the map instead, without pulling in an extra popup package

Everything else — KPI row, filters (state/district/type/severity/date
range, applied the same way as `GISMap.tsx`), the map's KPI strip and
GPS/telemetry HUD, the Distress Summary Analytics panel, and the full
history table — is a direct port.

Note: the map tiles require real internet access to
`tile.openstreetmap.org`; they won't load in a fully offline/sandboxed
environment (same category of limitation as Live Detection needing a real
backend + camera), but work normally anywhere with a live connection.

## Upload Video: real backend wiring

`lib/screens/upload_video/upload_video_screen.dart` and
`lib/data/video_api.dart` call the real `/api/v1/videos/*` and
`/api/v1/reports/generate/*` endpoints — upload (`POST /videos/upload`,
multipart), list (`GET /videos/`, polled every 8s like the React source),
delete (`DELETE /videos/{id}`), and PDF report generation. File selection
uses `file_picker` (click to browse) and `desktop_drop` (drag-and-drop),
both of which work on Flutter Web.

The upload progress bar is a simulated timer incrementing to 85% while the
request is in flight, then jumping to 100% on success — this matches the
React source exactly; `UploadVideo.tsx` never actually wires axios's real
upload-progress event to its progress bar either, so there was no real
progress signal to preserve.

Without a backend running, the screen still renders correctly: the upload
registry fetch fails with a visible "Failed to fetch upload registry."
banner, and the Pipeline Overview / Processing Queue cards fall back to the
same static placeholder numbers the React source shows when its `videos`
array is empty.

## Live Processing: real backend wiring

`lib/screens/live_processing/live_processing_screen.dart` polls
`GET /api/v1/videos/` (every 4s, matching the React source), `GET
/api/v1/detection/summary`, and `GET /api/v1/reports/` for the KPI row, and
calls `POST /api/v1/detection/video/{id}` to trigger the AI pipeline on the
selected "waiting" video — reusing `VideoApi` from `video_api.dart`
(extended with `fetchDetectionSummary`, `fetchReportsCount`, and
`triggerDetection`) rather than duplicating a client.

The frame-extraction → YOLO detection → object tracking → maintenance-task
→ report-generation progress bar and milestone stepper are a client-side
timer simulation in the React source too (there's no backend push channel
for pipeline progress), so that simulation — including its exact stage
thresholds and log messages — is ported as-is rather than replaced with
something real that doesn't exist server-side.

Without a backend running, the screen still renders correctly: the KPI
row shows zeros, the Footage Registry Queue shows its empty state, and the
monitor panel prompts "Select a video source to begin surveillance
monitoring." until a video is loaded.

## Road Distresses: real backend data

`lib/screens/road_distresses/` ports `RoadDistresses.tsx` against the real
`GET /api/v1/distress/` endpoint (same one GIS Map uses, but working with
the raw API record directly rather than GIS Map's synthetic
state/district/roadName mapping). Search, the advanced filter panel
(severity/status/type/video ID/priority group/date range), column-sort,
pagination, configurable column visibility (persisted via
`SharedPreferences`, the Flutter equivalent of the React source's
`localStorage` use), row selection with bulk "Mark Reviewed"/"Mark
Resolved" actions, the inspection side drawer, and per-row "Report"/"GIS"
actions are all direct ports.

Two things were deliberately trimmed vs. the ~1,100-line React source:

- **No CSV/Excel/JSON export buttons, and no "Export Selected" bulk
  action.** These are pure frontend blob-download conveniences in the
  React source (they build a data URI and click a hidden `<a>` tag) rather
  than anything backend-driven, so they were left out to keep this
  screen's scope on the real, data-driven parts.
- **The image lightbox uses Flutter's built-in `InteractiveViewer`**
  (pinch/drag/double-tap zoom) instead of manually re-implementing the
  React source's mouse-drag-to-pan + zoom-button transform math — same
  real capability, idiomatic Flutter widget.

One quirk ported faithfully rather than "fixed": `handleGeneratePDF`'s
catch branch in the React source shows the *same* success message as the
happy path, so the user always sees "PDF report generated successfully"
regardless of whether the API call actually succeeded. That's preserved
here rather than silently made more "correct," since the goal is matching
the reference app's actual behavior, warts and all. Similarly, the bulk
"Mark Reviewed"/"Mark Resolved" actions only mutate local state in the
React source (no real API call) — that's also preserved as-is.

## Dashboard (per-run inspection view): real backend data

`lib/screens/dashboard_grid/` ports `Dashboard.tsx`/`DashboardGrid.tsx` —
the screen at `/dashboard`, distinct from `/overview`'s `OverviewDashboard`
(the one Overview Dashboard above refers to). Fetches real data via
`GET /api/v1/distress/` and `GET /api/v1/reports/`, reusing
`RoadDistressApi` and `VideoApi` rather than adding a third client for the
same endpoints. Includes a real interactive GIS map (flutter_map, same
approach as the GIS Map screen), the distress distribution donut chart,
the recent detections feed, a manual field-observations form + registry
table (local-state-only, matching the source), the KPI row, and the AI
maintenance recommendation highlight.

Trimmed vs. the ~1,035-line React source:

- **The "Live Camera Feed" card** — entirely simulated in the source
  (random bounding-box overlays, a fake FPS/frame-count ticker, hardcoded
  GPS text), with zero backend tie, and redundant with the real Live
  Detection screen already built elsewhere in this app.
- **The voice-note recorder** (real mic capture via `getUserMedia`/
  `MediaRecorder`) and **the snapshot image uploader** — both real browser
  features in the source, but neither is backend-persisted (recordings and
  images only live in local blob URLs and vanish on reload), so they were
  left out rather than pulling in mic-permission and image-picker plumbing
  for something that doesn't survive a page refresh either way.

One quirk kept faithfully: the KPI row's "Videos Uploaded" card is
hardcoded to `42` in the React source regardless of any real data — it's
ported as the same hardcoded `42` here, not wired to a real count.

## Maintenance: real backend data

`lib/screens/maintenance/` ports `MaintenanceDashboard.tsx`: real data from
`GET /api/v1/maintenance/recommendations`, `GET /api/v1/distress/`, and
`GET /api/v1/users/`, joined client-side into `CombinedTask`s exactly as
the React source does (there's no backend endpoint that returns this
joined shape directly). The `components/maintenance/*.tsx` files in the
React source are dead code — never imported by any page or route — so
nothing there needed porting.

All three view modes are direct ports: **Kanban Board** (5 status columns
with quick-advance buttons), **Table Registry** (sortable/paginated), and
**Calendar Schedule** (a real month grid with task badges per day). Also
ported: the KPI row, the full filter bar (search/status/priority/
severity/engineer/month), the task details drawer (editable status/
engineer/due-date — local-state-only, matching the source, since it has
no update endpoint wired up either), and both analytics charts (priority
workload bar chart, operations stage pie chart).

Trimmed: the CSV/Excel export buttons and the "PDF Print" button
(`window.print()`) — pure frontend conveniences with no backend tie, same
reasoning as the export buttons trimmed from GIS Map and Road Distresses.

This screen's widgets (Kanban cards, table, calendar, drawer) render very
differently with real task data than with none, so a small widget test
(`test/maintenance_smoke_test.dart`) pumps each one with sample tasks —
it caught and fixed three real text-overflow bugs that were invisible
when testing against this sandbox's empty/error states alone.

## Reports: real backend data

`lib/screens/reports/` ports `ReportsDashboard.tsx`: real data from
`GET /api/v1/reports/`, `GET /api/v1/videos/`, and `GET /api/v1/users/`,
joined client-side into `ReportItem`s exactly as the React source's
`loadDashboardData` does — `roadId`/`district`/`distressType`/`severity`
are faithfully-preserved fake-but-deterministic values derived from
`videoId % <lookup array>.length` (there's no real per-report geo/distress
data on the backend to join against, and the source doesn't have any
either). The `components/reports/*.tsx` files in the React source
(`ReportGeneratorPanel.tsx`, `ReportsTable.tsx`) are dead code — never
imported by any page or route — so nothing there needed porting.

Ported as real functionality: the reports registry table (search/format/
severity/status/date-range/favorites filters, bulk selection, pagination),
favorites persisted via `SharedPreferences` (mirrors the source's
`localStorage['road_reports_favorites']`), real PDF/Excel report
generation from a completed video run (`POST /api/v1/reports/generate/{id}`
/ `POST /api/v1/reports/excel/{id}`), real deletion
(`DELETE /api/v1/reports/{id}`), real downloads (opening the backend's
download URLs in a new tab), staggered bulk download, the "Registry
Overview" card (distress-classification pie chart — including the
source's own hardcoded non-zero fallback minimums, so no slice ever shows
a true zero — plus the severity breakdown bars, which the source computes
from *all* reports rather than the filtered list, faithfully preserved
here too), and the document preview modal with its two decorative-but-real
document mockups (PDF audit cover, mock Excel spreadsheet).

The permanently-disabled "ZIP Batch Export" button is ported as-is
(disabled, with the source's own tooltip explaining why) — the source
itself ships it disabled, so there was nothing to trim there.

Trimmed: the "Generate Custom Report" button, its 4 decorative State/
District/DistressType/Severity filter dropdowns, and the "Schedule
Report" button. All three are 100% fake — the custom report is fabricated
client-side behind a `setTimeout` with no backend call at all, and
"Schedule Report" is just a bare `alert()` — so unlike the PDF/Excel
preview renderers (which are decorative but preview *real* generated
reports), these had no real functionality worth preserving. Trimming them
also means every `ReportItem` in this port always has a real `reportId`,
which makes the source's dead JSON-preview/JSON-download branches
(`reportType === 'JSON'` is never actually produced by any real code
path, custom-report generator included) unreachable, so those weren't
ported either — see the doc comment on `ReportItem` in
`lib/data/reports_api.dart` for the full reasoning.

A widget test (`test/reports_smoke_test.dart`) pumps the registry table,
overview card, and both preview-modal renderers with sample report data,
following the same rationale as the Maintenance smoke test — this
sandbox's backend-less error state alone can't exercise how these widgets
render with real data.

## Analytics: real backend data + a real interactive map

`lib/screens/analytics/` ports `AnalyticsDashboard.tsx` (~1,486 lines, the
largest single screen in the source): real data from
`GET /api/v1/detection/summary`, `GET /api/v1/distress/`,
`GET /api/v1/videos/`, `GET /api/v1/reports/`, and
`GET /api/v1/maintenance/recommendations`, combined client-side into 11
charts, a road-health gauge, a real interactive GIS map, an inspections
registry table, and several executive summary cards — all computed exactly
as the source's `useMemo` blocks do (severity-weighted road health scoring,
per-video-run stacked severity counts, priority buckets, cost-per-defect-
class breakdowns, daily/weekly/monthly detection timelines, damage-area-vs-
health-impact scatter data, and lat/lng-rounded marker clustering).
`components/dashboard/MaintenanceAnalytics.tsx` in the React source is dead
code — never imported by any page or route — so nothing there needed
porting.

Ported as real, direct functionality: the 8-card KPI row (with same-day
trend badges), the animated circular Road Health Gauge, the "Geographic
Mapping Summary" map (via `flutter_map`, clustering same-coordinate
detections exactly like the source's `clusteredMarkers`, with tap-to-reveal
info cards standing in for Leaflet's anchored `Popup`), the donut/stacked-
bar/priority-bar/cost-bar/timeline-line/scatter charts, the severity legend
click-to-hide toggle, the surveillance run inspections table, the
Maintenance Tasks Queue and Exported Documents Archive summary cards, and
the Executive Summary Insights list.

Three computations in the source are themselves dead code, discovered
while reading it rather than a scope decision: `processingPerformanceData`,
`availablePerformanceMetrics`, and `confidenceHistogramData` all feed a
`fullscreenChartId === 'performance'`/`'histogram'` branch of the
fullscreen chart modal, but no button anywhere in the source ever sets
`fullscreenChartId` to either value — there's no card for either chart in
the main layout, so they're unreachable. None of it was ported. Similarly,
the AI Model Performance card reads `model_name`/`yolo_version`/
`model_size`/`inference_device`/`inference_speed` off the detection-summary
response, but the backend's `get_detection_analytics` never actually
returns any of those keys, so all five always fall back to the source's
own hardcoded defaults in practice — they're hardcoded in this port too
(see `widgets/summary_section.dart`), rather than modeled as fetched data
that never arrives.

Trimmed: the PNG-export button on every chart card (client-side SVG-to-
canvas-to-PNG with no backend tie) and the "expand to fullscreen" modal for
each chart (a pure view convenience — every chart's data is already fully
visible at its normal card size), for the same reasoning as the CSV/export
trims on earlier screens. The "Analyze" button in the inspections table
navigates to `/dashboard` rather than the source's `/inspection/:videoId`,
since the existing `DashboardGridScreen` doesn't support deep-linking to a
specific run and extending an already-shipped screen was out of scope here.

A widget test (`test/analytics_smoke_test.dart`) pumps every chart/table/
card widget with sample data — it caught and fixed two real bugs invisible
against this sandbox's empty/error states: a `BoxDecoration` assertion
failure in the KPI grid (a `Border` with per-side colors can't be combined
with `borderRadius` in one decoration; fixed by drawing the colored top
accent as a `Container` strip inside a `ClipRRect` instead of a border
side) and a text overflow in the Maintenance/Reports summary cards' footer
row (fixed the same way as Maintenance's earlier overflow fixes — wrapping
the value text in `Flexible` with `TextOverflow.ellipsis`).

## History: real backend data

`lib/screens/history/` ports `History.tsx` (~1,535 lines): real data from
`GET /api/v1/reports/` and `GET /api/v1/videos/`, combined client-side into
an activity timeline exactly as the source's `allActivities` does (report-
exported events plus video-uploaded/inference-status events, each with
deterministic-fake-but-DB-id-derived engineer/district/road/model metadata,
matching Reports.tsx's own district/severity derivation precedent), a
sortable/paginated reports archive table, expandable per-video inference
run cards with a real pipeline-stage tracker, and three real analytics
charts (category distribution, 7-day activity trend, top event types).

This is the one screen whose source has **no error state at all** --
`fetchHistory`'s catch block only does `console.error`, there's no
`setError` anywhere in the file. This port matches that faithfully: a fetch
failure just leaves `reports`/`videos` empty and every section shows its
ordinary empty-state copy, rather than the dedicated error banner every
other screen has. The screenshot below is exactly that empty-but-not-error
state, since this sandbox has no live backend.

Trimmed: the 8 hardcoded "system events" the source seeds into the
timeline (Backend Server Restarted, YOLOv8 Model Loaded, Database
Auto-Backup, Secured Admin Login, Maintenance Task Raised, Road Segment
Verified, Detection Record Purged, Alert Notification Broadcasted) — 100%
fabricated strings with no backend tie, seeded (per the source's own code
comment) just "to make timeline enterprise-grade". Dropping them also
removes the source's "System Events Log" section (which filters
specifically for those seeded events, so it would render permanently empty
otherwise) and the `Maintenance`/`GIS`/`Notifications` timeline categories
(so the activity-type filter dropdown drops those options too — see
`timeline_event.dart` and `widgets/history_filters_bar.dart`). Also
trimmed: the "Recent Active Users" widget (a fully static array of 4
fabricated names/roles/timestamps), the fake per-KPI-card trend badges and
SVG sparklines (arbitrary uncomputed percentages, unlike a single static
fallback label elsewhere), and the "Export Logs" CSV button (client-side
Blob+`<a>`+click, no backend tie — same reasoning as the CSV/Excel export
trims on GIS Map, Road Distresses, and Maintenance).

"Retry Pipeline" is ported as a simulated confirmation dialog, mirroring
the source's own `alert('Restarting AI pipeline... (Simulated)')` — it's
simulated in the source too, so unlike fully-fake peripheral buttons
trimmed elsewhere (e.g. Reports' "Schedule Report"), this one is a primary
action on an otherwise-real card and was kept. "Review Video" shows a
"not wired up yet" snackbar, since Video Review doesn't exist in this port
yet (same convention the sidebar already uses for unbuilt destinations).

A widget test (`test/history_smoke_test.dart`) pumps every major widget
with sample data — it caught and fixed a real `BoxConstraints forces an
infinite height` crash in the Inference Run Logs cards (a `Row` with
`CrossAxisAlignment.stretch` doesn't work for a colored side-accent bar
when the card's height is intrinsic/unbounded; fixed by using a
`Positioned` strip in a `Stack` instead, the same underlying fix as
Analytics' KPI-grid accent bug but adapted for an unbounded-height
container).

**Also discovered while building this screen (pre-existing, not
introduced here): a real bug affecting every screen with a `DropdownButton`
filter.** Setting `style:` directly on a `DropdownButton` (instead of on
each `DropdownMenuItem`'s own `Text`) makes the button's displayed
selected-item text render invisibly on Flutter Web/CanvasKit, even though
the text is present in the widget tree (a widget test with `find.text`
finds it fine — it just doesn't paint). This screen's filter dropdowns hit
it first and are now fixed (style moved onto each item's `Text`), but the
same pattern exists in at least `road_distresses_screen.dart`'s filter
dropdowns (confirmed via screenshot: the Severity/Status/Type/Priority
Group filters render with empty-looking boxes) and likely other screens'
`DropdownButton`s built the same way. It went unnoticed until now because
every other real-backend screen's Playwright verification only ever
reached the top-level loading/error state before a backend was available —
History is the first screen whose failure path still renders the "loaded"
UI (see above), which is what exposed it. Not fixed elsewhere in this
change since it touches already-shipped screens outside History's scope —
worth a follow-up pass across the app.

## A couple of Flutter-specific gotchas hit while porting

If you're porting another screen and something silently breaks (wrong
scroll extent, blank page, or a debug-only "Cannot hit test a render box
that has never been laid out" assertion), check for these first:

- **`IntrinsicHeight` around `GridView`/`ListView`/`fl_chart` charts.**
  Viewport- and `CustomPaint`-based widgets don't implement intrinsic-size
  computation. Use a plain `Row`/`Column` instead.
- **Nesting a `Scaffold` inside another screen's `Scaffold`.** Every screen
  passed as `DashboardShell`'s `child` must return plain content (a
  `Column`), not its own `Scaffold`/`SingleChildScrollView` — `DashboardShell`
  already provides those.

## Testing

```bash
flutter analyze
flutter test
```

UI changes should also be checked visually: `flutter build web --release`,
serve `build/web` with a static server, and click through the affected
screens (or drive it headlessly with Playwright against the same static
build — debug mode via `flutter run -d chrome` can behave differently
across environments).
