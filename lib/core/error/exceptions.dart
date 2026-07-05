/// Raw exceptions thrown by DataSources. RepositoryImpl catches these
/// (and FirebaseException) and maps them to a Failure — this is the
/// ONLY layer allowed to catch raw exceptions.
class ServerException implements Exception {
  final String message;
  const ServerException([this.message = 'Server error']);
}

class AuthException implements Exception {
  final String message;
  const AuthException([this.message = 'Authentication error']);
}

class NotFoundException implements Exception {
  final String message;
  const NotFoundException([this.message = 'Not found']);
}
