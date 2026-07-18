import os
import shutil
from abc import ABC, abstractmethod
from app.core.config import settings
from app.core.logging import logger

class StorageService(ABC):
    """Abstract storage interface to decouple app logic from direct disk storage."""
    
    @abstractmethod
    async def save_file(self, content: bytes, filename: str, folder_type: str) -> str:
        """Saves a file and returns its access path/URL."""
        pass

    @abstractmethod
    async def delete_file(self, file_path: str) -> None:
        """Deletes a file from the storage system."""
        pass


class LocalStorageService(StorageService):
    """Local filesystem implementation of the StorageService."""
    
    def __init__(self):
        # Ensure root storage directories exist
        os.makedirs(settings.FACES_STORAGE_DIR, exist_ok=True)
        os.makedirs(settings.REPORTS_STORAGE_DIR, exist_ok=True)

    async def save_file(self, content: bytes, filename: str, folder_type: str) -> str:
        """Saves file contents locally under the selected directory."""
        if folder_type == "faces":
            target_dir = settings.FACES_STORAGE_DIR
        elif folder_type == "reports":
            target_dir = settings.REPORTS_STORAGE_DIR
        else:
            target_dir = settings.STORAGE_PATH

        os.makedirs(target_dir, exist_ok=True)
        
        file_path = os.path.join(target_dir, filename)
        # Convert path separators to forward slashes for cross-platform stability
        normalized_path = file_path.replace("\\", "/")
        
        try:
            with open(normalized_path, "wb") as f:
                f.write(content)
            logger.info(f"File saved successfully to local disk: {normalized_path}")
            return normalized_path
        except Exception as e:
            logger.error(f"Failed to write file to local disk: {str(e)}", exc_info=True)
            raise e

    async def delete_file(self, file_path: str) -> None:
        """Deletes a file locally from disk if it exists."""
        normalized_path = file_path.replace("\\", "/")
        try:
            if os.path.exists(normalized_path):
                os.remove(normalized_path)
                logger.info(f"File deleted successfully from local disk: {normalized_path}")
            else:
                logger.warning(f"Attempted to delete non-existent file: {normalized_path}")
        except Exception as e:
            logger.error(f"Failed to delete file from local disk: {str(e)}", exc_info=True)
            raise e
