from typing import List
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api import deps
from app.models.faculty import Faculty
from app.schemas.notification import NotificationOut
from app.repositories.notification import NotificationRepository

router = APIRouter()

@router.get("/", response_model=List[NotificationOut])
async def list_notifications(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    db: AsyncSession = Depends(deps.get_db),
    current_user: Faculty = Depends(deps.get_current_user)
) -> List[NotificationOut]:
    """Retrieve warning and shortage notifications for the currently logged-in user."""
    repo = NotificationRepository(db)
    # Both students and faculty receive alerts. Faculty recipient matches faculty ID.
    return await repo.list_for_recipient(current_user.id, skip=skip, limit=limit)

@router.post("/mark-read/{notification_id}", response_model=NotificationOut)
async def mark_notification_as_read(
    notification_id: int,
    db: AsyncSession = Depends(deps.get_db),
    current_user: Faculty = Depends(deps.get_current_user)
) -> NotificationOut:
    """Marks a specific notification alert as read."""
    repo = NotificationRepository(db)
    notification = await repo.mark_as_read(notification_id)
    if not notification:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Notification not found."
        )
    # Ensure recipient matches logged-in user before returning
    if notification.recipient_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have permission to mark this notification as read."
        )
    return notification
