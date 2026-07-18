from datetime import date
from typing import Optional
import uuid
from fastapi import APIRouter, Depends, Query, Response, status
from fastapi.responses import StreamingResponse
import io
from sqlalchemy.ext.asyncio import AsyncSession

from app.api import deps
from app.models.faculty import Faculty
from app.services.report import (
    query_attendance_report_data,
    generate_csv_report,
    generate_excel_report,
    generate_pdf_report,
    query_overall_attendance,
    generate_overall_csv_report,
    generate_overall_excel_report,
    generate_overall_pdf_report,
)

router = APIRouter()

@router.get("/attendance/csv")
async def get_attendance_csv_report(
    class_id: Optional[int] = Query(None, description="Filter by class ID"),
    subject_id: Optional[int] = Query(None, description="Filter by subject ID"),
    student_id: Optional[uuid.UUID] = Query(None, description="Filter by student ID"),
    department: Optional[str] = Query(None, description="Filter by department"),
    year: Optional[int] = Query(None, ge=1, le=5, description="Filter by year"),
    section: Optional[str] = Query(None, description="Filter by section"),
    start_date: Optional[date] = Query(None, description="Start date (YYYY-MM-DD)"),
    end_date: Optional[date] = Query(None, description="End date (YYYY-MM-DD)"),
    db: AsyncSession = Depends(deps.get_db),
    current_user: Faculty = Depends(deps.RoleChecker(["admin", "faculty"]))
):
    """Streams the requested attendance logs as a raw CSV spreadsheet file."""
    data = await query_attendance_report_data(
        db=db,
        class_id=class_id,
        subject_id=subject_id,
        student_id=student_id,
        department=department,
        year=year,
        section=section,
        start_date=start_date,
        end_date=end_date
    )
    
    csv_string = generate_csv_report(data)
    
    return StreamingResponse(
        io.StringIO(csv_string),
        media_type="text/csv",
        headers={"Content-Disposition": "attachment; filename=attendance_report.csv"}
    )

@router.get("/attendance/excel")
async def get_attendance_excel_report(
    class_id: Optional[int] = Query(None, description="Filter by class ID"),
    subject_id: Optional[int] = Query(None, description="Filter by subject ID"),
    student_id: Optional[uuid.UUID] = Query(None, description="Filter by student ID"),
    department: Optional[str] = Query(None, description="Filter by department"),
    year: Optional[int] = Query(None, ge=1, le=5, description="Filter by year"),
    section: Optional[str] = Query(None, description="Filter by section"),
    start_date: Optional[date] = Query(None, description="Start date (YYYY-MM-DD)"),
    end_date: Optional[date] = Query(None, description="End date (YYYY-MM-DD)"),
    db: AsyncSession = Depends(deps.get_db),
    current_user: Faculty = Depends(deps.RoleChecker(["admin", "faculty"]))
):
    """Compiles the filtered attendance records into a styled OpenPyXL Excel spreadsheet."""
    data = await query_attendance_report_data(
        db=db,
        class_id=class_id,
        subject_id=subject_id,
        student_id=student_id,
        department=department,
        year=year,
        section=section,
        start_date=start_date,
        end_date=end_date
    )
    
    excel_bytes = generate_excel_report(data)
    
    return Response(
        content=excel_bytes,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": "attachment; filename=attendance_report.xlsx"}
    )

@router.get("/attendance/pdf")
async def get_attendance_pdf_report(
    class_id: Optional[int] = Query(None, description="Filter by class ID"),
    subject_id: Optional[int] = Query(None, description="Filter by subject ID"),
    student_id: Optional[uuid.UUID] = Query(None, description="Filter by student ID"),
    department: Optional[str] = Query(None, description="Filter by department"),
    year: Optional[int] = Query(None, ge=1, le=5, description="Filter by year"),
    section: Optional[str] = Query(None, description="Filter by section"),
    start_date: Optional[date] = Query(None, description="Start date (YYYY-MM-DD)"),
    end_date: Optional[date] = Query(None, description="End date (YYYY-MM-DD)"),
    db: AsyncSession = Depends(deps.get_db),
    current_user: Faculty = Depends(deps.RoleChecker(["admin", "faculty"]))
):
    """Compiles the filtered attendance logs into a styled PDF document using ReportLab flowables."""
    data = await query_attendance_report_data(
        db=db,
        class_id=class_id,
        subject_id=subject_id,
        student_id=student_id,
        department=department,
        year=year,
        section=section,
        start_date=start_date,
        end_date=end_date
    )
    
    pdf_bytes = generate_pdf_report(data)
    
    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={"Content-Disposition": "attachment; filename=attendance_report.pdf"}
    )


@router.get("/overall-attendance")
async def get_overall_attendance_report(
    department: Optional[str] = Query(None, description="Filter by department"),
    year: Optional[int] = Query(None, ge=1, le=5, description="Filter by year"),
    section: Optional[str] = Query(None, description="Filter by section"),
    subject_id: Optional[int] = Query(None, description="Filter by subject ID"),
    start_date: Optional[date] = Query(None, description="Start date (YYYY-MM-DD)"),
    end_date: Optional[date] = Query(None, description="End date (YYYY-MM-DD)"),
    format: str = Query("json", description="Export format (json, pdf, excel, csv)"),
    db: AsyncSession = Depends(deps.get_db),
    current_user: Faculty = Depends(deps.RoleChecker(["admin", "faculty"]))
):
    """
    Retrieves overall attendance metrics across all students matching filters.
    Supports formats: json, csv, excel, pdf.
    """
    data = await query_overall_attendance(
        db=db,
        department=department,
        year=year,
        section=section,
        subject_id=subject_id,
        start_date=start_date,
        end_date=end_date
    )
    
    if format == "csv":
        csv_string = generate_overall_csv_report(data)
        return StreamingResponse(
            io.StringIO(csv_string),
            media_type="text/csv",
            headers={"Content-Disposition": "attachment; filename=overall_attendance.csv"}
        )
    elif format == "excel":
        excel_bytes = generate_overall_excel_report(data)
        return Response(
            content=excel_bytes,
            media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            headers={"Content-Disposition": "attachment; filename=overall_attendance.xlsx"}
        )
    elif format == "pdf":
        pdf_bytes = generate_overall_pdf_report(data)
        return Response(
            content=pdf_bytes,
            media_type="application/pdf",
            headers={"Content-Disposition": "attachment; filename=overall_attendance.pdf"}
        )
    else:
        return data
