import os
from pydantic import field_validator
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

    @field_validator("DATABASE_URL", mode="after")
    @classmethod
    def sanitize_database_url(cls, v: str) -> str:
        if isinstance(v, str):
            if v.startswith("postgres://"):
                v = v.replace("postgres://", "postgresql+asyncpg://", 1)
            elif v.startswith("postgresql://") and "+asyncpg" not in v:
                v = v.replace("postgresql://", "postgresql+asyncpg://", 1)

            if "postgresql" in v or "asyncpg" in v:
                params_to_add = []
                if "prepared_statement_cache_size" not in v:
                    params_to_add.append("prepared_statement_cache_size=0")
                if "statement_cache_size" not in v:
                    params_to_add.append("statement_cache_size=0")
                if params_to_add:
                    delimiter = "&" if "?" in v else "?"
                    v = f"{v}{delimiter}{'&'.join(params_to_add)}"
        return v
    
    # Security
    JWT_SECRET: str
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7
    
    # Face Recognition Thresholds
    FACE_SIMILARITY_THRESHOLD: float = 0.60
    FACE_DUPLICATE_THRESHOLD: float = 0.93
    
    # Local Storage Paths (fallback only — not persistent on most cloud hosts)
    STORAGE_PATH: str = "storage"
    FACES_STORAGE_DIR: str = "storage/faces"
    REPORTS_STORAGE_DIR: str = "storage/reports"

    # Supabase Storage (persistent — use this in deployed environments)
    SUPABASE_URL: str = ""
    SUPABASE_SERVICE_KEY: str = ""

settings = Settings()

