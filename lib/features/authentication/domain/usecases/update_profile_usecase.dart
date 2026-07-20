import '../../../../core/error/result.dart';
import '../repositories/auth_repository.dart';

class UpdateProfileUseCase {
  final AuthRepository _repository;
  const UpdateProfileUseCase(this._repository);

  Future<Result<void>> call({required String name, required String phone, String? photoUrl}) =>
      _repository.updateProfile(name: name, phone: phone, photoUrl: photoUrl);
}
