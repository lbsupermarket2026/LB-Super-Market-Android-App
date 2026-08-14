import '../../../../core/error/result.dart';
import '../repositories/auth_repository.dart';

class SendOtpUseCase {
  final AuthRepository _repository;
  const SendOtpUseCase(this._repository);

  Future<Result<(String verificationId, int? resendToken)>> call(String phoneNumber, {int? forceResendingToken}) =>
      _repository.sendOtp(phoneNumber, forceResendingToken: forceResendingToken);
}
