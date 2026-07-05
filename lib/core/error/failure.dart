import 'package:equatable/equatable.dart';

/// Every repository method returns Either<Failure, T> — never throws
/// across the domain boundary. See core/error/result.dart for the alias.
abstract class Failure extends Equatable {
  final String message;
  const Failure(this.message);

  @override
  List<Object?> get props => [message];
}

class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Something went wrong. Please try again.']);
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No internet connection. Please check your network.']);
}

class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Authentication failed.']);
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'The requested item could not be found.']);
}

class PermissionFailure extends Failure {
  const PermissionFailure([super.message = 'You do not have permission to do this.']);
}
