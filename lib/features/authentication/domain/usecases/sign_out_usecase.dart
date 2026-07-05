import '../../../../core/error/result.dart';
import '../repositories/auth_repository.dart';

class SignOutUseCase {
  final AuthRepository _repository;
  const SignOutUseCase(this._repository);

  Future<Result<void>> call() => _repository.signOut();
}
