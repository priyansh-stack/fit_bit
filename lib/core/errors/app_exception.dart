// lib/core/errors/app_exception.dart

/// Typed exception hierarchy for the health dashboard application.
sealed class AppException implements Exception {
  const AppException({required this.message, this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() =>
      '$runtimeType: $message${cause != null ? ' (caused by: $cause)' : ''}';
}

// ---------------------------------------------------------------------------
// Authentication
// ---------------------------------------------------------------------------

class AuthException extends AppException {
  const AuthException({required super.message, super.cause});
}

class NotSignedInException extends AuthException {
  const NotSignedInException()
      : super(message: 'User is not signed in. Please sign in to continue.');
}

class SignInCancelledException extends AuthException {
  const SignInCancelledException() : super(message: 'Sign-in was cancelled.');
}

// ---------------------------------------------------------------------------
// Health Connection / OAuth
// ---------------------------------------------------------------------------

class HealthConnectionException extends AppException {
  const HealthConnectionException({required super.message, super.cause});
}

class OAuthCancelledException extends HealthConnectionException {
  const OAuthCancelledException()
      : super(message: 'Google Health authorization was cancelled.');
}

class OAuthFailedException extends HealthConnectionException {
  const OAuthFailedException({required super.message, super.cause});
}

class TokenExpiredException extends HealthConnectionException {
  const TokenExpiredException(
      [String message =
          'Your Google Health authorization has expired. Please reconnect.'])
      : super(message: message);
}

class TokenRevokedException extends HealthConnectionException {
  const TokenRevokedException(
      {super.message =
          'Your Google Health access has been revoked. Please reconnect your account.'});
}

class ScopeMissingException extends HealthConnectionException {
  const ScopeMissingException(
      {super.message = 'Required Google Health API scopes were not granted.'});
}

class PartialConsentException extends HealthConnectionException {
  PartialConsentException({required List<String> missingScopes})
      : super(
          message:
              'Some permissions were not granted. Missing: ${missingScopes.join(', ')}',
        );
}

class NotConnectedException extends HealthConnectionException {
  const NotConnectedException()
      : super(
            message:
                'No Google Health connection found. Please connect your account.');
}

// ---------------------------------------------------------------------------
// Sync / Google Health API / Data
// ---------------------------------------------------------------------------

class SyncException extends AppException {
  const SyncException({required super.message, super.cause});
}

class GoogleHealthApiException extends SyncException {
  const GoogleHealthApiException({
    required super.message,
    this.statusCode,
    super.cause,
  });
  final int? statusCode;
}

class RateLimitException extends SyncException {
  const RateLimitException({
    super.message =
        'Google Health API rate limit reached. Please try again later.',
    this.retryAfterSeconds,
    super.cause,
  });
  final int? retryAfterSeconds;
}

class DataUnavailableException extends SyncException {
  const DataUnavailableException({required String dataType})
      : super(
            message: 'Data type "$dataType" is not available for this device.');
}

// ---------------------------------------------------------------------------
// Network
// ---------------------------------------------------------------------------

class NetworkException extends AppException {
  const NetworkException({required super.message, super.cause});
}

class TimeoutException extends NetworkException {
  const TimeoutException()
      : super(
            message:
                'The request timed out. Check your internet connection and try again.');
}

class ServerException extends NetworkException {
  const ServerException({required this.statusCode, required super.message});
  final int statusCode;
}

// ---------------------------------------------------------------------------
// Firestore
// ---------------------------------------------------------------------------

class FirestoreException extends AppException {
  const FirestoreException({required super.message, super.cause});
}
