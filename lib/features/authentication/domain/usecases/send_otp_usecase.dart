import '../../../../core/error/result.dart';
import '../repositories/auth_repository.dart';

class SendOtpUseCase {
  final AuthRepository _repository;
  const SendOtpUseCase(this._repository);

  Future<Result<String>> call(String phoneNumber) => _repository.sendOtp(phoneNumber);
}
