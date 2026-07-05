import '../../../../core/error/result.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class SignUpUseCase {
  final AuthRepository _repository;
  const SignUpUseCase(this._repository);

  Future<Result<UserEntity>> call({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) {
    return _repository.signUpWithEmail(name: name, email: email, phone: phone, password: password);
  }
}
