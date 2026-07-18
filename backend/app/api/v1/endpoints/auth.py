from datetime import timedelta
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from app.api import deps
from app.core import security
from app.core.config import settings
from app.models.faculty import Faculty
from app.schemas.auth import LoginRequest, Token, RefreshRequest
from app.schemas.faculty import FacultyOut

router = APIRouter()

async def authenticate_user(db: AsyncSession, email: str, password: str) -> Faculty:
    """Helper method to find and verify user credentials."""
    query = select(Faculty).where(Faculty.email == email)
    result = await db.execute(query)
    user = result.scalars().first()
    
    if not user or not security.verify_password(password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Incorrect email or password",
        )
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Inactive user profile",
        )
    return user

@router.post("/login", response_model=Token)
async def login_json(
    login_data: LoginRequest,
    db: AsyncSession = Depends(deps.get_db)
) -> Token:
    """
    JSON-based login endpoint. Preferred for mobile apps/Flutter.
    """
    user = await authenticate_user(db, login_data.email, login_data.password)
    
    access_token_expires = timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    refresh_token_expires = timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
    
    return Token(
        access_token=security.create_access_token(user.id, expires_delta=access_token_expires),
        refresh_token=security.create_refresh_token(user.id, expires_delta=refresh_token_expires),
        token_type="bearer"
    )

@router.post("/login/access-token", response_model=Token)
async def login_access_token(
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: AsyncSession = Depends(deps.get_db)
) -> Token:
    """
    OAuth2 compatible form login. Used by FastAPI Swagger documentation.
    """
    user = await authenticate_user(db, form_data.username, form_data.password)
    
    access_token_expires = timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    refresh_token_expires = timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
    
    return Token(
        access_token=security.create_access_token(user.id, expires_delta=access_token_expires),
        refresh_token=security.create_refresh_token(user.id, expires_delta=refresh_token_expires),
        token_type="bearer"
    )

@router.post("/refresh", response_model=Token)
async def refresh_token(
    refresh_data: RefreshRequest,
    db: AsyncSession = Depends(deps.get_db)
) -> Token:
    """
    Refresh endpoint to get a new access token using a valid refresh token.
    """
    payload = security.decode_token(refresh_data.refresh_token)
    if not payload or payload.get("type") != "refresh":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid refresh token",
        )
        
    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token payload",
        )
        
    query = select(Faculty).where(Faculty.id == user_id)
    result = await db.execute(query)
    user = result.scalars().first()
    
    if not user or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found or inactive",
        )
        
    access_token_expires = timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    
    return Token(
        access_token=security.create_access_token(user.id, expires_delta=access_token_expires),
        refresh_token=refresh_data.refresh_token,  # reuse existing refresh token
        token_type="bearer"
    )

@router.post("/logout")
async def logout() -> dict:
    """
    Stateless logout endpoint. Tokens must be cleared on the client side.
    """
    return {"status": "ok", "message": "Successfully logged out"}

@router.get("/me", response_model=FacultyOut)
async def get_me(
    current_user: Faculty = Depends(deps.get_current_user)
) -> FacultyOut:
    """
    Get profile information of the currently authenticated user.
    """
    return current_user
