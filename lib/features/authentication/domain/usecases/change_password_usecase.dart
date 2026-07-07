import '../../../../core/error/result.dart';
import '../repositories/auth_repository.dart';

class ChangePasswordUseCase {
  final AuthRepository _repository;
  const ChangePasswordUseCase(this._repository);

  Future<Result<void>> call({required String currentPassword, required String newPassword}) =>
      _repository.changePassword(currentPassword: currentPassword, newPassword: newPassword);
}