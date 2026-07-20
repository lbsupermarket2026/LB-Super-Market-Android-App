import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/employee_remote_datasource.dart';
import '../../domain/entities/staff_member_entity.dart';

final employeeRemoteDataSourceProvider = Provider<EmployeeRemoteDataSource>((ref) {
  return EmployeeRemoteDataSource();
});

final allStaffProvider = FutureProvider.autoDispose<List<StaffMemberEntity>>((ref) {
  return ref.watch(employeeRemoteDataSourceProvider).getAllStaff();
});

class EmployeeMutationState {
  final bool isSubmitting;
  final String? error;
  const EmployeeMutationState({this.isSubmitting = false, this.error});
}

class EmployeeMutationNotifier extends StateNotifier<EmployeeMutationState> {
  final Ref _ref;
  EmployeeMutationNotifier(this._ref) : super(const EmployeeMutationState());

  Future<bool> createEmployee({
    required String name,
    required String email,
    required String phone,
    required String password,
    required StaffRole role,
  }) async {
    state = const EmployeeMutationState(isSubmitting: true);
    try {
      await _ref.read(employeeRemoteDataSourceProvider).createEmployee(
            name: name,
            email: email,
            phone: phone,
            password: password,
            role: role,
          );
      state = const EmployeeMutationState();
      _ref.invalidate(allStaffProvider);
      return true;
    } catch (e) {
      state = EmployeeMutationState(error: e.toString());
      return false;
    }
  }

  Future<bool> updateEmployee({
    required String uid,
    required String name,
    required String phone,
    required StaffRole role,
  }) async {
    state = const EmployeeMutationState(isSubmitting: true);
    try {
      await _ref.read(employeeRemoteDataSourceProvider).updateEmployee(
            uid: uid,
            name: name,
            phone: phone,
            role: role,
          );
      state = const EmployeeMutationState();
      _ref.invalidate(allStaffProvider);
      return true;
    } catch (e) {
      state = EmployeeMutationState(error: e.toString());
      return false;
    }
  }

  Future<bool> removeStaff(String uid) async {
    state = const EmployeeMutationState(isSubmitting: true);
    try {
      await _ref.read(employeeRemoteDataSourceProvider).removeStaffAccess(uid);
      state = const EmployeeMutationState();
      _ref.invalidate(allStaffProvider);
      return true;
    } catch (e) {
      state = EmployeeMutationState(error: e.toString());
      return false;
    }
  }
}

final employeeMutationProvider =
    StateNotifierProvider.autoDispose<EmployeeMutationNotifier, EmployeeMutationState>((ref) {
  return EmployeeMutationNotifier(ref);
});
