from typing import List
import uuid
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api import deps
from app.models.faculty import Faculty
from app.repositories.analytics import AnalyticsRepository
from app.schemas.analytics import (
    AnalyticsOut,
    DefaulterOut,
    DepartmentStats,
    DailyTrend,
    MonthlyTrend,
)
from app.core.scheduler import run_attendance_rollup

router = APIRouter()

@router.post("/rollup", status_code=status.HTTP_200_OK)
async def trigger_analytics_rollup(
    db: AsyncSession = Depends(deps.get_db),
    current_user: Faculty = Depends(deps.RoleChecker(["admin"]))
) -> dict:
    """
    Manually triggers the precomputations of student analytics and risk scores (Admin Only).
    Useful to bypass the midnight scheduler and update stats instantly in development.
    """
    await run_attendance_rollup()
    return {"status": "ok", "message": "Rollup calculations finished successfully."}

@router.get("/defaulters", response_model=List[DefaulterOut])
async def list_defaulter_predictions(
    limit: int = 100,
    db: AsyncSession = Depends(deps.get_db),
    current_user: Faculty = Depends(deps.RoleChecker(["admin", "faculty"]))
) -> List[DefaulterOut]:
    """Retrieve risk-ranked list of students falling below 75% attendance or with high risk scores."""
    repo = AnalyticsRepository(db)
    return await repo.list_defaulters(limit=limit)

@router.get("/student/{student_id}", response_model=List[AnalyticsOut])
async def get_student_subject_analytics(
    student_id: uuid.UUID,
    db: AsyncSession = Depends(deps.get_db),
    current_user: Faculty = Depends(deps.RoleChecker(["admin", "faculty"]))
) -> List[AnalyticsOut]:
    """Retrieve subject-wise precomputed attendance ratios and risk scores for a student."""
    repo = AnalyticsRepository(db)
    return await repo.get_student_subject_analytics(student_id)

@router.get("/daily", response_model=List[DailyTrend])
async def get_daily_trends(
    db: AsyncSession = Depends(deps.get_db),
    current_user: Faculty = Depends(deps.RoleChecker(["admin", "faculty"]))
) -> List[DailyTrend]:
    """Retrieve daily aggregate attendance percentage trend over the last 30 active days."""
    repo = AnalyticsRepository(db)
    return await repo.get_daily_trend()

@router.get("/monthly", response_model=List[MonthlyTrend])
async def get_monthly_trends(
    db: AsyncSession = Depends(deps.get_db),
    current_user: Faculty = Depends(deps.RoleChecker(["admin", "faculty"]))
) -> List[MonthlyTrend]:
    """Retrieve monthly aggregate attendance percentage trend over the last 12 active months."""
    repo = AnalyticsRepository(db)
    return await repo.get_monthly_trend()

@router.get("/department/{department}", response_model=DepartmentStats)
async def get_department_analytics(
    department: str,
    db: AsyncSession = Depends(deps.get_db),
    current_user: Faculty = Depends(deps.RoleChecker(["admin", "faculty"]))
) -> DepartmentStats:
    """Retrieve overall averages and shortage logs comparison for a specific department."""
    repo = AnalyticsRepository(db)
    all_stats = await repo.get_department_stats()
    dept_stat = next((s for s in all_stats if s.department.lower() == department.lower()), None)
    if not dept_stat:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Department '{department}' statistics not found."
        )
    return dept_stat
