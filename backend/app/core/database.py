import uuid
from typing import AsyncGenerator
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from app.core.config import settings

def _unique_stmt_name(*args, **kwargs) -> str:
    return f"__asyncpg_stmt_{uuid.uuid4().hex}__"

connect_args = {}
if "postgresql" in settings.DATABASE_URL or "asyncpg" in settings.DATABASE_URL:
    connect_args["statement_cache_size"] = 0
    connect_args["prepared_statement_cache_size"] = 0
    connect_args["prepared_statement_name_func"] = _unique_stmt_name

# Create async database engine
engine = create_async_engine(
    settings.DATABASE_URL,
    echo=False,
    future=True,
    connect_args=connect_args,
    execution_options={"compiled_cache": None},
    pool_pre_ping=True,
    pool_recycle=300
)

# Create session maker with expire_on_commit=False for async safety
AsyncSessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autoflush=False,
    autocommit=False
)

async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """Dependency injection wrapper to yield db session in endpoints, rollback on error."""
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()
