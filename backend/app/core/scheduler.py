from datetime import datetime, date, timedelta
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from sqlalchemy.future import select
from app.core.database import AsyncSessionLocal
from app.core.logging import logger

# Models imports
from app.models.student import Student
from app.models.subject import Subject
from app.models.class_session import ClassSession
from app.models.attendance import Attendance
from app.models.analytics import AttendanceAnalytics
from app.models.bunk_flag import BunkFlag
from app.models.notification import Notification

scheduler = AsyncIOScheduler()

async def run_attendance_rollup() -> None:
    """
    Background job triggered nightly or manually.
    Loops through active students, calculates subject attendance totals,
    generates risk scores, and dispatches warnings.
    """
    logger.info("Starting background attendance analytics rollup job...")
    async with AsyncSessionLocal() as db:
        try:
            # Query active students
            students_query = select(Student).where(Student.is_active == True)
            students_result = await db.execute(students_query)
            students = students_result.scalars().all()
            
            for student in students:
                # Find subjects corresponding to this student's year/section/department
                subjects_query = select(Subject).where(
                    (Subject.department == student.department) &
                    (Subject.year == student.year) &
                    (Subject.section == student.section)
                )
                subjects_result = await db.execute(subjects_query)
                subjects = subjects_result.scalars().all()
                
                for subject in subjects:
                    # Find all class sessions for this subject
                    classes_query = select(ClassSession).where(ClassSession.subject_id == subject.id)
                    classes_result = await db.execute(classes_query)
                    classes = classes_result.scalars().all()
                    
                    if not classes:
                        continue
                        
                    class_ids = [c.id for c in classes]
                    now = datetime.now()
                    
                    # Count total classes held (scheduled start <= now)
                    held_classes = [c for c in classes if c.scheduled_start <= now]
                    classes_held = len(held_classes)
                    if classes_held == 0:
                        continue
                        
                    held_class_ids = [c.id for c in held_classes]
                    
                    # Count classes attended by the student
                    attended_query = select(Attendance).where(
                        (Attendance.student_id == student.id) &
                        (Attendance.class_id.in_(held_class_ids)) &
                        (Attendance.status.in_(["present", "late"]))
                    )
                    attended_result = await db.execute(attended_query)
                    classes_attended = len(attended_result.scalars().all())
                    
                    # Compute percentage
                    attendance_percentage = float((classes_attended / classes_held) * 100.0)
                    
                    # Count unresolved bunk flags
                    bunk_query = select(BunkFlag).where(
                        (BunkFlag.student_id == student.id) &
                        (BunkFlag.class_id.in_(held_class_ids)) &
                        (BunkFlag.resolved == False)
                    )
                    bunk_result = await db.execute(bunk_query)
                    bunk_count = len(bunk_result.scalars().all())
                    
                    # Compute recent trend (absence count in last 5 classes)
                    last_5_held = sorted(held_classes, key=lambda x: x.scheduled_start, reverse=True)[:5]
                    last_5_ids = [c.id for c in last_5_held]
                    
                    last_5_att_query = select(Attendance).where(
                        (Attendance.student_id == student.id) &
                        (Attendance.class_id.in_(last_5_ids))
                    )
                    last_5_att_result = await db.execute(last_5_att_query)
                    last_5_att = last_5_att_result.scalars().all()
                    
                    absent_count = 0
                    for c_id in last_5_ids:
                        att_rec = next((a for a in last_5_att if a.class_id == c_id), None)
                        if not att_rec or att_rec.status == "absent":
                            absent_count += 1
                            
                    # Calculate risk score: w1=1.5, w2=6.0 (recent absences), w3=8.0 (bunk flags)
                    pct_deficit = max(0.0, 75.0 - attendance_percentage)
                    risk_score = (pct_deficit * 1.5) + (bunk_count * 8.0) + (absent_count * 6.0)
                    risk_score = min(100.0, max(0.0, risk_score))
                    
                    # Save record in DB
                    analytics_query = select(AttendanceAnalytics).where(
                        (AttendanceAnalytics.student_id == student.id) &
                        (AttendanceAnalytics.subject_id == subject.id)
                    )
                    analytics_result = await db.execute(analytics_query)
                    analytics_rec = analytics_result.scalars().first()
                    
                    if not analytics_rec:
                        analytics_rec = AttendanceAnalytics(
                            student_id=student.id,
                            subject_id=subject.id,
                            period_type="daily",
                            period_start=date.today() - timedelta(days=30),
                            period_end=date.today()
                        )
                        
                    analytics_rec.classes_held = classes_held
                    analytics_rec.classes_attended = classes_attended
                    analytics_rec.attendance_percentage = attendance_percentage
                    analytics_rec.risk_score = risk_score
                    analytics_rec.computed_at = datetime.now()
                    
                    db.add(analytics_rec)
                    await db.flush()
                    
                    # --- NOTIFICATION ALERTS DISPATCH ---
                    if risk_score > 60.0 or attendance_percentage < 75.0:
                        # Avoid spamming: Check if notification sent in last 7 days
                        notif_query = select(Notification).where(
                            (Notification.recipient_id == student.id) &
                            (Notification.type == "defaulter_warning") &
                            (Notification.created_at >= datetime.now() - timedelta(days=7))
                        )
                        notif_result = await db.execute(notif_query)
                        recent_notif = notif_result.scalars().first()
                        
                        if not recent_notif:
                            # Alert Student
                            student_notif = Notification(
                                recipient_type="student",
                                recipient_id=student.id,
                                type="defaulter_warning",
                                title="Attendance Defaulter Shortage Warning",
                                message=f"Your attendance in {subject.name} ({subject.code}) is {attendance_percentage:.1f}%, below the 75% threshold. Defaulter risk score: {risk_score:.1f}.",
                                is_read=False
                            )
                            db.add(student_notif)
                            
                            # Alert Faculty
                            if subject.faculty_id:
                                faculty_notif = Notification(
                                    recipient_type="faculty",
                                    recipient_id=subject.faculty_id,
                                    type="defaulter_warning",
                                    title="Shortage Alert: " + student.name,
                                    message=f"Student {student.name} ({student.roll_number}) has fallen to {attendance_percentage:.1f}% in subject {subject.name}. Calculated risk score: {risk_score:.1f}.",
                                    is_read=False
                                )
                                db.add(faculty_notif)
                                
            await db.commit()
            logger.info("Background attendance rollup analytics completed successfully.")
        except Exception as e:
            logger.error(f"Error executing background rollup analytics: {str(e)}", exc_info=True)
            await db.rollback()

def start_scheduler() -> None:
    """Starts the background task manager and registers the nightly job."""
    # Run rollup analytics every night at 1:00 AM
    scheduler.add_job(run_attendance_rollup, 'cron', hour=1, minute=0, id='nightly_rollup')
    scheduler.start()
    logger.info("APScheduler background tasks engine started successfully.")

def shutdown_scheduler() -> None:
    """Shuts down the background scheduler."""
    scheduler.shutdown()
    logger.info("APScheduler background tasks engine stopped successfully.")
