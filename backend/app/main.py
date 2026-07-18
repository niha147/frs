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

async def seed_default_admin() -> None:
    """Seeds a default system admin account if none exists in the database."""
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
                default_admin = Faculty(
                    id=uuid.uuid4(),
                    name="System Admin",
                    email="admin@smartattend.com",
                    phone="0000000000",
                    department="IT & Support",
                    password_hash=get_password_hash("admin123"),
                    role="admin",
                    is_active=True
                )
                session.add(default_admin)
                await session.commit()
                logger.info("Default admin seeded: admin@smartattend.com / admin123")
            else:
                logger.info("Admin accounts already exist. Skipping seeding.")
        except Exception as e:
            logger.warning(
                f"Could not connect to database to verify/seed default admin user (Database might be offline): {str(e)}"
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
    allow_credentials=True,
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
