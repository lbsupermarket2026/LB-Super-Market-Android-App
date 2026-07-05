import '../../../../core/error/result.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class SignInUseCase {
  final AuthRepository _repository;
  const SignInUseCase(this._repository);

  Future<Result<UserEntity>> call({required String email, required String password}) {
    return _repository.signInWithEmail(email: email, password: password);
  }
}
