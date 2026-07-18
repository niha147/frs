import os
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env", 
        env_file_encoding="utf-8", 
        case_sensitive=True, 
        extra="ignore"
    )
    
    PROJECT_NAME: str = "SmartAttend AI"
    API_V1_STR: str = "/api/v1"
    
    # Database
    DATABASE_URL: str
    
    # Security
    JWT_SECRET: str
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7
    
    # Face Recognition Thresholds
    FACE_SIMILARITY_THRESHOLD: float = 0.60
    FACE_DUPLICATE_THRESHOLD: float = 0.93
    
    # Local Storage Paths
    STORAGE_PATH: str = "storage"
    FACES_STORAGE_DIR: str = "storage/faces"
    REPORTS_STORAGE_DIR: str = "storage/reports"

settings = Settings()
