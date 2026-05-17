from datetime import datetime
from pydantic import EmailStr, Field
from ninja import Schema


class SignupIn(Schema):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)


class LoginIn(Schema):
    email: EmailStr
    password: str


class RefreshIn(Schema):
    refresh: str


class UserOut(Schema):
    id: str
    email: EmailStr
    full_name: str | None = None
    default_savings_ratio: float
    date_joined: datetime


class TokenPairOut(Schema):
    access: str
    refresh: str


class AuthResultOut(Schema):
    user: UserOut
    access: str
    refresh: str


class PasswordResetRequestIn(Schema):
    email: EmailStr


class PasswordResetConfirmIn(Schema):
    token: str
    new_password: str = Field(min_length=8, max_length=128)
