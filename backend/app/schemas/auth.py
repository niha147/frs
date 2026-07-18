from typing import Optional
from pydantic import BaseModel, EmailStr, Field

class LoginRequest(BaseModel):
    """Pydantic model validating email and password for login."""
    email: EmailStr = Field(..., description="Faculty/Admin login email")
    password: str = Field(..., min_length=6, description="Login password")

class Token(BaseModel):
    """Token response model containing access and refresh tokens."""
    access_token: str
    refresh_token: str
    token_type: str = "bearer"

class TokenPayload(BaseModel):
    """Payload decoded from a valid JWT token."""
    sub: Optional[str] = None
    exp: Optional[int] = None
    type: Optional[str] = None

class RefreshRequest(BaseModel):
    """Request model containing the refresh token to renew access."""
    refresh_token: str

