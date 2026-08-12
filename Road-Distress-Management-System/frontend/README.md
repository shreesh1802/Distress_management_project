# Road Distress Management — React Frontend (Legacy / Reference Only)

**This is no longer the active frontend.** The production app is now the
Flutter port at [`mobile/`](../../mobile), which has fully replaced this
React/TypeScript/Vite dashboard — see
[`mobile/README.md`](../../mobile/README.md) for the current app's setup,
architecture, and a full screen-by-screen breakdown of what's real vs. mock
data.

This directory is kept in the repo purely as the **design/behavior
reference** each Flutter screen was ported against — when a Flutter screen's
intended layout or logic is unclear, the equivalent `.tsx` file here is the
source of truth for "what should this look/behave like." It is not deployed
anywhere and does not receive new feature work.

## Running it (if you need to compare against the original)

```bash
cd Road-Distress-Management-System/frontend
npm install
npm run dev
```

Standard Vite dev server — opens at `http://localhost:5173` by default.
`npm run build` produces a static production build; `npm run lint` runs
ESLint. Points at the same FastAPI backend as the Flutter app
(`Road-Distress-Management-System/backend`) for any screens with real API
calls — see the root [`README.md`](../../README.md) for backend setup.

## Stack

React + TypeScript + Vite, with `react-leaflet` for the GIS map (ported to
`flutter_map` in the Flutter app) and `apiService` as the API client layer
(ported to the per-screen `*_api.dart` files in `mobile/lib/data/`).
