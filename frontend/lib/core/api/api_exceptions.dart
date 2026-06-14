sealed class ApiException implements Exception {
  final String code;
  final String message;
  final Object? details;
  const ApiException(this.code, this.message, [this.details]);
  @override
  String toString() => 'ApiException($code): $message';
}

class ApiValidationException extends ApiException {
  const ApiValidationException(String m, [Object? d])
    : super('validation_error', m, d);
}

class ApiAuthException extends ApiException {
  const ApiAuthException(String m, [Object? d]) : super('auth_error', m, d);
}

class ApiForbiddenException extends ApiException {
  const ApiForbiddenException(String m, [Object? d]) : super('forbidden', m, d);
}

class ApiNotFoundException extends ApiException {
  const ApiNotFoundException(String m, [Object? d]) : super('not_found', m, d);
}

class ApiConflictException extends ApiException {
  const ApiConflictException(String m, [Object? d]) : super('conflict', m, d);
}

class ApiUpstreamException extends ApiException {
  const ApiUpstreamException(String m, [Object? d])
    : super('upstream_error', m, d);
}

class ApiNetworkException extends ApiException {
  const ApiNetworkException(String m) : super('network', m);
}

class ApiServerException extends ApiException {
  const ApiServerException(String m, [Object? d]) : super('server_error', m, d);
}
