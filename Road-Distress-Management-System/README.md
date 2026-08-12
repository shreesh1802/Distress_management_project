# Road Distress Management System

A real-time AI-powered pavement monitoring system that uses dashcam video to detect road distresses such as cracks, potholes, rutting, ravelling, and road signages. The system stores GPS-tagged detections, displays them on a GIS dashboard, and generates maintenance reports for road authorities.

## Project Objective

The goal is to build a simple, scalable Final Year Project that demonstrates an end-to-end road monitoring workflow:

1. Capture dashcam video and GPS information.
2. Detect road distress using AI models such as YOLOv11.
3. Store detected issues with location, severity, image/video evidence, and timestamp.
4. Display detections on a GIS dashboard using map-based visualization.
5. Generate maintenance reports for planning and decision-making.

## Architecture Overview

```text
Dashcam Video + GPS
        |
        v
AI Detection Module
YOLOv11 + OpenCV
        |
        v
Backend API
FastAPI business logic and APIs
        |
        v
Database
PostgreSQL detection records
        |
        v
Frontend Dashboard
React GIS dashboard and reports
```

## Repository Structure

```text
frontend/     React dashboard (legacy) -- superseded by the Flutter app in ../mobile, kept as a design/behavior reference only
backend/      FastAPI APIs for detections, reports, users, and integrations
ai/           YOLO, OpenCV, datasets, training scripts, and inference experiments
database/     PostgreSQL schema, migrations, and database documentation
docs/         Proposal, reports, architecture diagrams, and viva documentation
shared/       API contracts, sample data, common assets, and cross-module resources
.github/      GitHub Actions workflows for automation
```

## Suggested Team Distribution

| Member | Branch | Main Folder | Responsibility |
| --- | --- | --- | --- |
| Member 1 | `frontend-dev` | `frontend/` | React dashboard, GIS map, pages, UI components |
| Member 2 | `backend-dev` | `backend/` | FastAPI routes, services, API logic, backend integration |
| Member 3 | `ai-dev` | `ai/` | YOLOv11 model training, OpenCV inference, datasets |
| Member 4 | `database-dev` | `database/` | PostgreSQL schema, migrations, GPS-tagged detection storage |
| Member 5 | `docs-dev` | `docs/` | Proposal, reports, diagrams, presentation, viva material |
| Member 6 | `main` and feature branches | `shared/`, integration support | API contracts, sample data, testing, integration coordination |

## Suggested Git Branches

- `main` - stable branch for final integrated code
- `frontend-dev` - frontend dashboard work
- `backend-dev` - backend API work
- `ai-dev` - AI, ML, YOLO, and OpenCV work
- `database-dev` - database schema and migrations
- `docs-dev` - documentation, reports, diagrams, and presentation work

## Future Technology Stack

- Frontend: React, TypeScript, Google Maps or another GIS map provider
- Backend: FastAPI, Python
- AI: YOLOv11, OpenCV
- Database: PostgreSQL with GPS-enabled detection records
- DevOps: Docker Compose, GitHub Actions

## Development Notes

This structure is intentionally simple. Each member can work independently in their assigned module while using `shared/api-contracts/` to agree on request and response formats.

Large datasets, trained models, videos, and generated outputs should not be committed to Git. Use cloud storage, release artifacts, or external drives for heavy files.

