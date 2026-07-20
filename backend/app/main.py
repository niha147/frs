import uuid
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request, status
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError
from starlette.exceptions import HTTPException as StarletteHTTPException
from sqlalchemy.future import select

from app.api.v1.api import api_router
from app.core.config import settings
from app.core.database import AsyncSessionLocal
from app.core.logging import LoggingMiddleware, logger
from app.core.security import get_password_hash
from app.models.faculty import Faculty
from app.core.scheduler import start_scheduler, shutdown_scheduler

from sqlalchemy import text

from datetime import datetime, timedelta
from app.models.student import Student
from app.models.subject import Subject
from app.models.class_session import ClassSession

async def seed_default_admin() -> None:
    """Seeds default admin, faculty, students, subject, and active class session if none exist."""
    async with AsyncSessionLocal() as session:
        try:
            # Ensure composite index on attendance is created
            await session.execute(text("CREATE INDEX IF NOT EXISTS idx_attendance_student_status ON attendance (student_id, status)"))
            await session.commit()
            
            # Query if any admin exists
            query = select(Faculty).where(Faculty.role == "admin")
            result = await session.execute(query)
            admin_user = result.scalars().first()
            
            if not admin_user:
                logger.info("No admin user found. Seeding default administrator account...")
                admin_user = Faculty(
                    id=uuid.uuid4(),
                    name="System Admin",
                    email="admin@smartattend.com",
                    phone="0000000000",
                    department="IT & Support",
                    password_hash=get_password_hash("admin123"),
                    role="admin",
                    is_active=True
                )
                session.add(admin_user)
                await session.commit()
                logger.info("Default admin seeded: admin@smartattend.com / admin123")

            # Query if faculty exists
            fac_query = select(Faculty).where(Faculty.email == "faculty@smartattend.com")
            fac_res = await session.execute(fac_query)
            faculty_user = fac_res.scalars().first()
            if not faculty_user:
                faculty_user = Faculty(
                    id=uuid.uuid4(),
                    name="Prof. Alan Turing",
                    email="faculty@smartattend.com",
                    phone="9876543210",
                    department="Computer Science",
                    password_hash=get_password_hash("faculty123"),
                    role="faculty",
                    is_active=True
                )
                session.add(faculty_user)
                await session.commit()
                logger.info("Default faculty seeded: faculty@smartattend.com / faculty123")

            # Seed default students
            s1_query = select(Student).where(Student.roll_number == "S1001")
            s1_res = await session.execute(s1_query)
            if not s1_res.scalars().first():
                s1 = Student(
                    id=uuid.uuid4(),
                    roll_number="S1001",
                    name="John Doe",
                    department="Computer Science",
                    year=1,
                    section="A",
                    email="john.doe@student.edu",
                    password_hash=get_password_hash("student123"),
                    is_active=True
                )
                s2 = Student(
                    id=uuid.uuid4(),
                    roll_number="S1002",
                    name="Alice Smith",
                    department="Computer Science",
                    year=1,
                    section="A",
                    email="alice.smith@student.edu",
                    password_hash=get_password_hash("student123"),
                    is_active=True
                )
                session.add_all([s1, s2])
                await session.commit()
                logger.info("Default students seeded: S1001 / student123 and S1002 / student123")

            # Seed default subject
            subj_query = select(Subject).where(Subject.code == "CS101")
            subj_res = await session.execute(subj_query)
            subj = subj_res.scalars().first()
            if not subj:
                subj = Subject(
                    name="Computer Science Fundamentals",
                    code="CS101",
                    department="Computer Science",
                    year=1,
                    section="A",
                    credits=4,
                    faculty_id=faculty_user.id
                )
                session.add(subj)
                await session.commit()
                logger.info("Default subject CS101 seeded.")

            # Seed active class session for today if none active
            now = datetime.now()
            start_time = now - timedelta(hours=2)
            end_time = now + timedelta(hours=6)
            cls_query = select(ClassSession).where(ClassSession.subject_id == subj.id)
            cls_res = await session.execute(cls_query)
            if not cls_res.scalars().first():
                cls_session = ClassSession(
                    subject_id=subj.id,
                    faculty_id=faculty_user.id,
                    department="Computer Science",
                    year=1,
                    section="A",
                    scheduled_start=start_time,
                    scheduled_end=end_time,
                    classroom="Lab 301"
                )
                session.add(cls_session)
                await session.commit()
                logger.info(f"Default active class session seeded (ID: {cls_session.id}).")

        except Exception as e:
            logger.warning(
                f"Could not connect to database to verify/seed default data: {str(e)}"
            )

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup actions
    await seed_default_admin()
    start_scheduler()
    yield
    # Shutdown actions
    shutdown_scheduler()

app = FastAPI(
    title=settings.PROJECT_NAME,
    openapi_url=f"{settings.API_V1_STR}/openapi.json",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan
)

# Add custom HTTP request logging middleware
app.add_middleware(LoggingMiddleware)

# Include main router aggregator
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_router, prefix=settings.API_V1_STR)

@app.exception_handler(StarletteHTTPException)
async def http_exception_handler(request: Request, exc: StarletteHTTPException) -> JSONResponse:
    logger.warning(f"HTTP exception at {request.url.path}: {exc.detail} (Status: {exc.status_code})")
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "error": {
                "code": f"HTTP_{exc.status_code}",
                "message": exc.detail,
                "details": {}
            }
        }
    )

@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError) -> JSONResponse:
    logger.warning(f"Validation error at {request.url.path}: {exc.errors()}")
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content={
            "error": {
                "code": "VALIDATION_ERROR",
                "message": "Request validation failed.",
                "details": exc.errors()
            }
        }
    )

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    logger.error(f"Unhandled exception at {request.url.path}: {str(exc)}", exc_info=True)
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "error": {
                "code": "INTERNAL_SERVER_ERROR",
                "message": "An unexpected error occurred on the server.",
                "details": {}
            }
        }
    )

@app.get("/")
async def root() -> dict:
    return {
        "status": "ok",
        "project": settings.PROJECT_NAME,
        "docs": "/docs"
    }

@app.get("/api/v1/health")
async def health() -> dict:
    return {
        "status": "healthy",
        "service": settings.PROJECT_NAME
    }
