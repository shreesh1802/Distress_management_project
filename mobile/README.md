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
│   └── live_detection_api.dart
├── router/
│   └── app_router.dart      # go_router routes, mirrors AppRoutes.tsx
├── screens/
│   ├── login/
│   ├── survey/              # Mission Setup
│   ├── dashboard/           # Shell (sidebar + top navbar) + Overview
│   └── live_detection/      # Live camera detection screen + widgets
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
| GIS Map | Not started | |
| Upload Video | Not started | |
| Live Processing | Not started | |
| Road Distresses | Not started | |
| Video Review | Not started | |
| Maintenance | Not started | |
| Reports | Not started | |
| Analytics | Not started | |
| History | Not started | |
| Notifications | Not started | |
| Settings | Not started | |

Everything above "Live Detection" runs against mock/hardcoded data (no
backend calls). The Live Detection screen is the one exception — it's wired
to the real FastAPI backend described below.

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
