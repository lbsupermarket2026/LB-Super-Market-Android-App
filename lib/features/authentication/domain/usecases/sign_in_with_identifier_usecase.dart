import '../../../../core/error/result.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class SignInWithIdentifierUseCase {
  final AuthRepository _repository;
  const SignInWithIdentifierUseCase(this._repository);

  Future<Result<UserEntity>> call({required String identifier, required String password}) {
    return _repository.signInWithIdentifierAndPassword(identifier: identifier, password: password);
  }
}
