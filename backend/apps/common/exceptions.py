class AppError(Exception):
    status_code = 400
    code = "app_error"

    def __init__(self, message: str = "", details=None):
        self.message = message or self.code
        self.details = details
        super().__init__(self.message)


class AuthError(AppError):
    status_code = 401
    code = "auth_error"


class PermissionError(AppError):
    status_code = 403
    code = "forbidden"


class NotFoundError(AppError):
    status_code = 404
    code = "not_found"


class ConflictError(AppError):
    status_code = 409
    code = "conflict"


class UpstreamError(AppError):
    status_code = 502
    code = "upstream_error"
