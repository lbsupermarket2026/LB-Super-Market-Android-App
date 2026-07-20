import 'dart:io';
import '../../../../core/error/result.dart';
import '../repositories/auth_repository.dart';

class UploadProfilePhotoUseCase {
  final AuthRepository _repository;
  const UploadProfilePhotoUseCase(this._repository);

  Future<Result<String>> call(File file) => _repository.uploadProfilePhoto(file);
}
