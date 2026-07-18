from typing import List, Optional
import uuid
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from app.models.notification import Notification

class NotificationRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def list_for_recipient(
        self,
        recipient_id: uuid.UUID,
        skip: int = 0,
        limit: int = 100
    ) -> List[Notification]:
        """Fetch all notifications for a given recipient (sorted by newest first)."""
        query = select(Notification).where(
            Notification.recipient_id == recipient_id
        ).order_by(Notification.created_at.desc()).offset(skip).limit(limit)
        
        result = await self.db.execute(query)
        return list(result.scalars().all())

    async def mark_as_read(self, notification_id: int) -> Optional[Notification]:
        """Mark a specific notification as read."""
        query = select(Notification).where(Notification.id == notification_id)
        result = await self.db.execute(query)
        notification = result.scalars().first()
        
        if notification:
            notification.is_read = True
            self.db.add(notification)
            await self.db.flush()
            
        return notification
