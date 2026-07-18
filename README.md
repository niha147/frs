# SmartAttend AI

SmartAttend AI is a modern Android attendance management system that uses face recognition and liveness detection to eliminate proxy attendance, detect bunking, and track in-classroom presence.

## Features

- **Anti-Proxy Face Verification**: Guided liveness checks (blink detection, smile verification, head-pose yaw tracking) using MediaPipe Face Mesh.
- **Classroom Bulk Scan**: One-click multi-face recognition using InsightFace (`buffalo_l` model) and OpenCV.
- **Bunk Detection**: Surprise checks comparing classroom presence at the start vs. later in the class period.
- **Defaulter Analytics**: Predicts students falling below the 75% attendance threshold using dynamic risk scoring.
- **Automated Reports & Notifications**: Exports reports in PDF, Excel, and CSV, and dispatches reminders/warnings.

## Project Structure

```text
smart_frs/
├── backend/            # FastAPI application (Python 3.11+)
│   ├── app/
│   │   ├── api/        # Routers / Endpoints
│   │   ├── core/       # Configurations, logging, security
│   │   ├── models/     # SQLAlchemy ORM Models
│   │   ├── schemas/    # Pydantic Schemas
│   │   ├── services/   # Business logic (rules, bunking engine)
│   │   ├── ai/         # InsightFace, MediaPipe, OpenCV wrappers
│   │   └── repositories/# Database access layer
│   └── docker-compose.yml
├── mobile/             # Flutter frontend application (Android target)
│   ├── lib/
│   │   ├── core/       # Constants, clients, theming
│   │   ├── data/       # Repositories & Data Sources
│   │   ├── domain/     # Entities & Interfaces
│   │   └── presentation/# Widgets, Screens, Providers (Riverpod)
└── docs/               # Architecture, API & Database documentation
```

## Tech Stack

- **Mobile**: Flutter (Material Design 3, Riverpod)
- **Backend**: FastAPI, Python 3.11+
- **Database**: PostgreSQL 15+ with `pgvector`
- **AI/ML**: InsightFace (`buffalo_l`), MediaPipe Face Mesh, OpenCV
- **Authentication**: JWT (Access + Refresh tokens)
- **Background Jobs**: APScheduler
- **Reports**: ReportLab (PDF), OpenPyXL (Excel)
