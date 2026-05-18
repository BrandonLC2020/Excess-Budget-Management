from django.core.signing import TimestampSigner, BadSignature, SignatureExpired

_SIGNER = TimestampSigner(salt="password-reset")
_MAX_AGE_SECONDS = 3600  # 1 hour


def make_reset_token(user_id: str) -> str:
    return _SIGNER.sign(str(user_id))


def parse_reset_token(token: str) -> str:
    try:
        return _SIGNER.unsign(token, max_age=_MAX_AGE_SECONDS)
    except (BadSignature, SignatureExpired) as e:
        raise ValueError("Invalid or expired token") from e
