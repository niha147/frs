from fastapi import APIRouter
from app.api.v1.endpoints import auth, students, faculty, subjects, classes, faces, attendance, analytics, notifications, reports, student_auth

api_router = APIRouter()
api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(students.router, prefix="/students", tags=["students"])
api_router.include_router(faculty.router, prefix="/faculty", tags=["faculty"])
api_router.include_router(subjects.router, prefix="/subjects", tags=["subjects"])
api_router.include_router(classes.router, prefix="/classes", tags=["classes"])
api_router.include_router(faces.router, tags=["faces"])
api_router.include_router(attendance.router, prefix="/attendance", tags=["attendance"])
api_router.include_router(analytics.router, prefix="/analytics", tags=["analytics"])
api_router.include_router(notifications.router, prefix="/notifications", tags=["notifications"])
api_router.include_router(reports.router, prefix="/reports", tags=["reports"])
api_router.include_router(student_auth.router, prefix="/student-auth", tags=["student-portal"])
