from datetime import datetime, date
from typing import List
import uuid
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import func, and_, or_
from app.models.analytics import AttendanceAnalytics
from app.models.student import Student
from app.models.subject import Subject
from app.models.bunk_flag import BunkFlag
from app.models.attendance import Attendance
from app.schemas.analytics import DefaulterOut, DepartmentStats, DailyTrend, MonthlyTrend

class AnalyticsRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def list_defaulters(self, limit: int = 100) -> List[DefaulterOut]:
        """
        Lists students below the 75% threshold or with high risk scores,
        ranking them by risk score descending.
        """
        # Count unresolved bunk flags per student
        bunk_subquery = select(
            BunkFlag.student_id,
            func.count(BunkFlag.id).label("bunks_count")
        ).where(BunkFlag.resolved == False).group_by(BunkFlag.student_id).subquery()

        # Query and aggregate analytics at student level
        query = select(
            Student.id.label("student_id"),
            Student.name,
            Student.roll_number,
            Student.department,
            Student.year,
            Student.section,
            func.avg(AttendanceAnalytics.attendance_percentage).label("avg_attendance"),
            func.max(AttendanceAnalytics.risk_score).label("max_risk"),
            func.coalesce(bunk_subquery.c.bunks_count, 0).label("bunk_flags_count")
        ).join(
            AttendanceAnalytics, Student.id == AttendanceAnalytics.student_id
        ).outerjoin(
            bunk_subquery, Student.id == bunk_subquery.c.student_id
        ).where(
            Student.is_active == True
        ).group_by(
            Student.id, Student.name, Student.roll_number, Student.department, Student.year, Student.section, bunk_subquery.c.bunks_count
        ).having(
            or_(
                func.avg(AttendanceAnalytics.attendance_percentage) < 75.0,
                func.max(AttendanceAnalytics.risk_score) > 50.0
            )
        ).order_by(
            func.max(AttendanceAnalytics.risk_score).desc()
        ).limit(limit)

        result = await self.db.execute(query)
        defaulters = []
        for row in result.all():
            defaulters.append(DefaulterOut(
                student_id=row.student_id,
                name=row.name,
                roll_number=row.roll_number,
                department=row.department,
                year=row.year,
                section=row.section,
                attendance_percentage=float(row.avg_attendance),
                risk_score=float(row.max_risk),
                bunk_flags_count=int(row.bunk_flags_count)
            ))
        return defaulters

    async def get_student_subject_analytics(self, student_id: uuid.UUID) -> List[AttendanceAnalytics]:
        """Fetch subject-wise analytics records for a student."""
        query = select(AttendanceAnalytics).where(
            AttendanceAnalytics.student_id == student_id
        ).order_by(AttendanceAnalytics.attendance_percentage.asc())
        result = await self.db.execute(query)
        return list(result.scalars().all())

    async def get_department_stats(self) -> List[DepartmentStats]:
        """Computes student count, overall average, and count of defaulters per department."""
        # Query total students per department
        total_query = select(
            Student.department,
            func.count(Student.id).label("total_stud")
        ).where(Student.is_active == True).group_by(Student.department).subquery()

        # Query average attendance per department
        avg_query = select(
            Student.department,
            func.avg(AttendanceAnalytics.attendance_percentage).label("avg_att")
        ).join(
            AttendanceAnalytics, Student.id == AttendanceAnalytics.student_id
        ).group_by(Student.department).subquery()

        # Query count of defaulters (students with average attendance < 75% in a department)
        student_avg_sub = select(
            Student.id.label("sid"),
            Student.department,
            func.avg(AttendanceAnalytics.attendance_percentage).label("student_avg")
        ).join(
            AttendanceAnalytics, Student.id == AttendanceAnalytics.student_id
        ).group_by(Student.id, Student.department).subquery()

        defaulter_query = select(
            student_avg_sub.c.department,
            func.count(student_avg_sub.c.sid).label("def_count")
        ).where(student_avg_sub.c.student_avg < 75.0).group_by(student_avg_sub.c.department).subquery()

        # Combine
        query = select(
            total_query.c.department,
            func.coalesce(avg_query.c.avg_att, 100.0).label("overall_pct"),
            total_query.c.total_stud,
            func.coalesce(defaulter_query.c.def_count, 0).label("def_count")
        ).outerjoin(
            avg_query, total_query.c.department == avg_query.c.department
        ).outerjoin(
            defaulter_query, total_query.c.department == defaulter_query.c.department
        )

        result = await self.db.execute(query)
        stats = []
        for row in result.all():
            stats.append(DepartmentStats(
                department=row.department,
                overall_attendance_percentage=float(row.overall_pct),
                total_students=int(row.total_stud),
                defaulters_count=int(row.def_count)
            ))
        return stats

    async def get_daily_trend(self) -> List[DailyTrend]:
        """Calculates daily attendance trends across all subjects."""
        query = select(
            func.to_char(Attendance.marked_at, 'YYYY-MM-DD').label("date_label"),
            func.sum(func.case((Attendance.status == 'present', 1), (Attendance.status == 'late', 1), else_=0)).label("present_count"),
            func.count(Attendance.id).label("total_count")
        ).group_by(
            func.to_char(Attendance.marked_at, 'YYYY-MM-DD')
        ).order_by(
            func.to_char(Attendance.marked_at, 'YYYY-MM-DD').asc()
        ).limit(30) # last 30 active days
        
        result = await self.db.execute(query)
        trends = []
        for row in result.all():
            total = row.total_count or 1
            trends.append(DailyTrend(
                date_str=row.date_label,
                attendance_percentage=float((row.present_count / total) * 100.0)
            ))
        return trends

    async def get_monthly_trend(self) -> List[MonthlyTrend]:
        """Calculates monthly attendance trends across all subjects."""
        query = select(
            func.to_char(Attendance.marked_at, 'YYYY-MM').label("month_label"),
            func.sum(func.case((Attendance.status == 'present', 1), (Attendance.status == 'late', 1), else_=0)).label("present_count"),
            func.count(Attendance.id).label("total_count")
        ).group_by(
            func.to_char(Attendance.marked_at, 'YYYY-MM')
        ).order_by(
            func.to_char(Attendance.marked_at, 'YYYY-MM').asc()
        ).limit(12) # last 12 active months
        
        result = await self.db.execute(query)
        trends = []
        for row in result.all():
            total = row.total_count or 1
            trends.append(MonthlyTrend(
                month_str=row.month_label,
                attendance_percentage=float((row.present_count / total) * 100.0)
            ))
        return trends
