import '../../../../core/error/result.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class SignUpWithPhoneUseCase {
  final AuthRepository _repository;
  const SignUpWithPhoneUseCase(this._repository);

  Future<Result<UserEntity>> call({
    required String name,
    required String phone,
    required String password,
    required String verificationId,
    required String smsCode,
  }) {
    return _repository.signUpWithPhoneAndPassword(
      name: name,
      phone: phone,
      password: password,
      verificationId: verificationId,
      smsCode: smsCode,
    );
  }
}
