import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories_impl/auth_repository_impl.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/sign_in_usecase.dart';
import '../../domain/usecases/sign_up_usecase.dart';
import '../../domain/usecases/sign_out_usecase.dart';
import '../../domain/usecases/reset_password_usecase.dart';

// ---- DI wiring ----

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSource();
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(ref.watch(authRemoteDataSourceProvider));
});

final signInUseCaseProvider = Provider<SignInUseCase>((ref) {
  return SignInUseCase(ref.watch(authRepositoryProvider));
});

final signUpUseCaseProvider = Provider<SignUpUseCase>((ref) {
  return SignUpUseCase(ref.watch(authRepositoryProvider));
});

final signOutUseCaseProvider = Provider<SignOutUseCase>((ref) {
  return SignOutUseCase(ref.watch(authRepositoryProvider));
});

final resetPasswordUseCaseProvider = Provider<ResetPasswordUseCase>((ref) {
  return ResetPasswordUseCase(ref.watch(authRepositoryProvider));
});

// ---- Auth state stream (drives router redirects + app-wide "who is logged in") ----

final authStateChangesProvider = StreamProvider<UserEntity?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

/// Convenience sync accessor for the current user, used in widgets that
/// just need to read the value without handling loading/error states
/// (the router guard, for instance, treats loading as "not yet decided").
final currentUserProvider = Provider<UserEntity?>((ref) {
  return ref.watch(authStateChangesProvider).valueOrNull;
});

// ---- Sign-in view model ----

class SignInState {
  final bool isLoading;
  final String? errorMessage;
  const SignInState({this.isLoading = false, this.errorMessage});

  SignInState copyWith({bool? isLoading, String? errorMessage}) => SignInState(
        isLoading: isLoading ?? this.isLoading,
        errorMessage: errorMessage,
      );
}

class SignInNotifier extends Notifier<SignInState> {
  @override
  SignInState build() => const SignInState();

  Future<bool> signIn({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final result = await ref.read(signInUseCaseProvider).call(email: email, password: password);
    return result.match(
      (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return false;
      },
      (_) {
        state = state.copyWith(isLoading: false, errorMessage: null);
        return true;
      },
    );
  }
}

final signInNotifierProvider = NotifierProvider<SignInNotifier, SignInState>(SignInNotifier.new);

// ---- Sign-up view model ----

class SignUpState {
  final bool isLoading;
  final String? errorMessage;
  const SignUpState({this.isLoading = false, this.errorMessage});

  SignUpState copyWith({bool? isLoading, String? errorMessage}) => SignUpState(
        isLoading: isLoading ?? this.isLoading,
        errorMessage: errorMessage,
      );
}

class SignUpNotifier extends Notifier<SignUpState> {
  @override
  SignUpState build() => const SignUpState();

  Future<bool> signUp({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final result = await ref.read(signUpUseCaseProvider).call(name: name, email: email, phone: phone, password: password);
    return result.match(
      (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return false;
      },
      (_) {
        state = state.copyWith(isLoading: false, errorMessage: null);
        return true;
      },
    );
  }
}

final signUpNotifierProvider = NotifierProvider<SignUpNotifier, SignUpState>(SignUpNotifier.new);

// ---- Forgot password view model ----

class ForgotPasswordNotifier extends Notifier<SignInState> {
  @override
  SignInState build() => const SignInState();

  Future<bool> sendResetEmail(String email) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final result = await ref.read(resetPasswordUseCaseProvider).call(email);
    return result.match(
      (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return false;
      },
      (_) {
        state = state.copyWith(isLoading: false, errorMessage: null);
        return true;
      },
    );
  }
}

final forgotPasswordNotifierProvider = NotifierProvider<ForgotPasswordNotifier, SignInState>(ForgotPasswordNotifier.new);
