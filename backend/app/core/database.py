import uuid
import logging
from typing import AsyncGenerator
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from sqlalchemy.engine import make_url
from app.core.config import settings

logger = logging.getLogger("smart_attend.database")

def _unique_stmt_name(*args, **kwargs) -> str:
    return f"__asyncpg_stmt_{uuid.uuid4().hex}__"

connect_args = {}
if "postgresql" in settings.DATABASE_URL or "asyncpg" in settings.DATABASE_URL:
    connect_args["statement_cache_size"] = 0
    connect_args["prepared_statement_cache_size"] = 0
    connect_args["prepared_statement_name_func"] = _unique_stmt_name

# Startup diagnostics logging
try:
    url_obj = make_url(settings.DATABASE_URL)
    driver_prefix = f"{url_obj.drivername}://"
except Exception:
    driver_prefix = settings.DATABASE_URL.split("://")[0] + "://" if "://" in settings.DATABASE_URL else settings.DATABASE_URL

stmt_cache_active = connect_args.get("statement_cache_size") == 0
prep_stmt_cache_active = connect_args.get("prepared_statement_cache_size") == 0
name_func_attached = "prepared_statement_name_func" in connect_args

log_banner = (
    "==================================================\n"
    "CUSTOM PREPARED STATEMENT PATCH ACTIVE\n"
    "Logging immediately before Application engine creation:\n"
    f"  - Full SQLAlchemy URL driver prefix: {driver_prefix}\n"
    f"  - statement_cache_size=0 active: {stmt_cache_active}\n"
    f"  - prepared_statement_cache_size=0 active: {prep_stmt_cache_active}\n"
    f"  - prepared_statement_name_func attached: {name_func_attached}\n"
    f"  - Exact connect_args passed into create_async_engine(): {connect_args}\n"
    "=================================================="
)
print(log_banner, flush=True)
logger.info(log_banner)

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
