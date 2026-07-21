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


class SupabaseStorageService(StorageService):
    """
    Supabase Storage (persistent, remote) implementation of StorageService.

    IMPORTANT: use this instead of LocalStorageService when deploying anywhere
    with an ephemeral filesystem (Render, Railway, Fly.io, most free-tier hosts).
    Local disk writes are wiped on every restart/redeploy on those platforms,
    which would silently delete every registered student's face data.
    """

    def __init__(self):
        import httpx  # local import keeps this optional if unused
        self._httpx = httpx
        self.base_url = settings.SUPABASE_URL.rstrip("/")
        self.service_key = settings.SUPABASE_SERVICE_KEY
        if not self.base_url or not self.service_key:
            raise RuntimeError(
                "SUPABASE_URL and SUPABASE_SERVICE_KEY must be set in .env to use SupabaseStorageService."
            )

    def _bucket_for(self, folder_type: str) -> str:
        if folder_type == "faces":
            return "faces"
        elif folder_type == "reports":
            return "reports"
        return "faces"

    def _headers(self, content_type: str = "application/octet-stream") -> dict:
        return {
            "Authorization": f"Bearer {self.service_key}",
            "apikey": self.service_key,
            "Content-Type": content_type,
            "x-upsert": "true",
        }

    async def save_file(self, content: bytes, filename: str, folder_type: str) -> str:
        bucket = self._bucket_for(folder_type)
        url = f"{self.base_url}/storage/v1/object/{bucket}/{filename}"
        async with self._httpx.AsyncClient(timeout=30) as client:
            resp = await client.post(url, headers=self._headers(), content=content)
            if resp.status_code not in (200, 201):
                logger.error(f"Supabase Storage upload failed ({resp.status_code}): {resp.text}")
                raise Exception(f"Failed to upload file to Supabase Storage: {resp.text}")
        logger.info(f"File uploaded to Supabase Storage: {bucket}/{filename}")
        # Store as "bucket/path" — since buckets are private, generate signed URLs when reading, not public URLs
        return f"{bucket}/{filename}"

    async def delete_file(self, file_path: str) -> None:
        # file_path format: "bucket/filename"
        url = f"{self.base_url}/storage/v1/object/{file_path}"
        async with self._httpx.AsyncClient(timeout=30) as client:
            resp = await client.delete(url, headers=self._headers())
            if resp.status_code not in (200, 204):
                logger.warning(f"Failed to delete file from Supabase Storage ({resp.status_code}): {resp.text}")

    async def get_signed_url(self, file_path: str, expires_in: int = 3600) -> str:
        """Generates a temporary signed URL to view a private file (e.g. for displaying a student's face photo)."""
        bucket, _, object_path = file_path.partition("/")
        url = f"{self.base_url}/storage/v1/object/sign/{bucket}/{object_path}"
        async with self._httpx.AsyncClient(timeout=15) as client:
            resp = await client.post(
                url,
                headers=self._headers("application/json"),
                json={"expiresIn": expires_in},
            )
            if resp.status_code != 200:
                logger.error(f"Failed to sign Supabase Storage URL ({resp.status_code}): {resp.text}")
                raise Exception("Failed to generate signed URL.")
            signed_path = resp.json().get("signedURL", "")
            return f"{self.base_url}/storage/v1{signed_path}"
