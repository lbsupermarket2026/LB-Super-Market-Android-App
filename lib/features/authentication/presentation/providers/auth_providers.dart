import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories_impl/auth_repository_impl.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/sign_in_usecase.dart';
import '../../domain/usecases/sign_up_usecase.dart';
import '../../domain/usecases/sign_out_usecase.dart';
import '../../domain/usecases/reset_password_usecase.dart';
import '../../domain/usecases/send_otp_usecase.dart';
import '../../domain/usecases/verify_otp_usecase.dart';
import '../../domain/usecases/update_profile_usecase.dart';
import '../../domain/usecases/upload_profile_photo_usecase.dart';
import '../../domain/usecases/change_password_usecase.dart';
import '../../domain/usecases/sign_in_with_identifier_usecase.dart';
import '../../domain/usecases/sign_up_with_phone_usecase.dart';



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

final signInWithIdentifierUseCaseProvider = Provider<SignInWithIdentifierUseCase>((ref) {
  return SignInWithIdentifierUseCase(ref.watch(authRepositoryProvider));
});

final signUpWithPhoneUseCaseProvider = Provider<SignUpWithPhoneUseCase>((ref) {
  return SignUpWithPhoneUseCase(ref.watch(authRepositoryProvider));
});

final signUpUseCaseProvider = Provider<SignUpUseCase>((ref) {
  return SignUpUseCase(ref.watch(authRepositoryProvider));
});

final updateProfileUseCaseProvider = Provider<UpdateProfileUseCase>((ref) {
  return UpdateProfileUseCase(ref.watch(authRepositoryProvider));
});

final uploadProfilePhotoUseCaseProvider = Provider<UploadProfilePhotoUseCase>((ref) {
  return UploadProfilePhotoUseCase(ref.watch(authRepositoryProvider));
});

final changePasswordUseCaseProvider =
    Provider<ChangePasswordUseCase>((ref) {
  return ChangePasswordUseCase(
    ref.watch(authRepositoryProvider),
  );
});

final signOutUseCaseProvider =
    Provider<SignOutUseCase>((ref) {
  return SignOutUseCase(
    ref.watch(authRepositoryProvider),
  );
});

final resetPasswordUseCaseProvider =
    Provider<ResetPasswordUseCase>((ref) {
  return ResetPasswordUseCase(
    ref.watch(authRepositoryProvider),
  );
});

final firebaseAuthUserProvider =
    StreamProvider<fb.User?>((ref) {
  return fb.FirebaseAuth.instance.authStateChanges();
});

final authStateChangesProvider =
    StreamProvider<UserEntity?>((ref) {
  final repository = ref.watch(authRepositoryProvider);

  return repository.authStateChanges().distinct(
    (previous, next) => previous?.uid == next?.uid,
  );
});


final currentUserProvider = Provider<UserEntity?>((ref) {
  final authState = ref.watch(authStateChangesProvider);

  return authState.when(
    loading: () => null,
    error: (error, stack) {
      // Do NOT sign the user out because profile loading failed.
      print('[AUTH ERROR] $error');
      return null;
    },
    data: (user) => user,
  );
});

final profileRefreshTriggerProvider =
    StateProvider<int>((ref) => 0);

final currentUserProfileProvider = FutureProvider<UserEntity?>((ref) async {
  ref.watch(profileRefreshTriggerProvider);

  final uid = ref.watch(currentUserProvider)?.uid;
  if (uid == null) return null;
  final model = await ref.read(authRemoteDataSourceProvider).resolveUserProfile(uid);
  return model.toEntity();
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

  Future<bool> signIn({required String identifier, required String password}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final result = await ref.read(signInWithIdentifierUseCaseProvider).call(identifier: identifier, password: password);
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


class EditProfileNotifier extends Notifier<SignInState> {
  @override
  SignInState build() => const SignInState();

  Future<bool> save({required String name, required String phone, File? photoFile}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    String? photoUrl;
    if (photoFile != null) {
      final uploadResult = await ref.read(uploadProfilePhotoUseCaseProvider).call(photoFile);
      final failure = uploadResult.match((f) => f, (_) => null);
      if (failure != null) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return false;
      }
      photoUrl = uploadResult.match((f) => null, (url) => url);
    }

    final result = await ref.read(updateProfileUseCaseProvider).call(name: name, phone: phone, photoUrl: photoUrl);
    return result.match(
      (failure) {
        state = state.copyWith(isLoading: false, errorMessage: failure.message);
        return false;
      },
      (_) {
        state = state.copyWith(isLoading: false, errorMessage: null);
        ref.read(profileRefreshTriggerProvider.notifier).state++;
        return true;
      },
    );
  }
}

final editProfileNotifierProvider = NotifierProvider<EditProfileNotifier, SignInState>(EditProfileNotifier.new);


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


class ChangePasswordNotifier extends Notifier<SignInState> {
  @override
  SignInState build() => const SignInState();

  Future<bool> changePassword({required String currentPassword, required String newPassword}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final result = await ref
        .read(changePasswordUseCaseProvider)
        .call(currentPassword: currentPassword, newPassword: newPassword);
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

final changePasswordNotifierProvider = NotifierProvider<ChangePasswordNotifier, SignInState>(ChangePasswordNotifier.new);

final sendOtpUseCaseProvider = Provider<SendOtpUseCase>((ref) {
  return SendOtpUseCase(ref.watch(authRepositoryProvider));
});

final verifyOtpUseCaseProvider = Provider<VerifyOtpUseCase>((ref) {
  return VerifyOtpUseCase(ref.watch(authRepositoryProvider));
});

class PhoneAuthState {
  final bool isSendingCode;
  final bool isVerifying;
  final String? verificationId;
  final String? errorMessage;
  // NEW: Firebase's own token for a genuine resend — without passing
  // this back in on the next sendCode() call, Firebase can silently
  // reject a resend for the same number as a duplicate. See sendCode
  // below for how it's threaded through.
  final int? resendToken;
  const PhoneAuthState({this.isSendingCode = false, this.isVerifying = false, this.verificationId, this.errorMessage, this.resendToken});

  PhoneAuthState copyWith({bool? isSendingCode, bool? isVerifying, String? verificationId, String? errorMessage, int? resendToken}) => PhoneAuthState(
        isSendingCode: isSendingCode ?? this.isSendingCode,
        isVerifying: isVerifying ?? this.isVerifying,
        verificationId: verificationId ?? this.verificationId,
        errorMessage: errorMessage,
        resendToken: resendToken ?? this.resendToken,
      );
}

class PhoneAuthNotifier extends Notifier<PhoneAuthState> {
  @override
  PhoneAuthState build() => const PhoneAuthState();

  Future<bool> sendCode(String phoneNumber) async {
    state = state.copyWith(isSendingCode: true, errorMessage: null);
    try {
      final result = await ref
          .read(sendOtpUseCaseProvider)
          .call(phoneNumber, forceResendingToken: state.resendToken)
          .timeout(const Duration(seconds: 30));
      return result.match(
        (failure) {
          state = state.copyWith(isSendingCode: false, errorMessage: failure.message);
          return false;
        },
        (data) {
          state = state.copyWith(isSendingCode: false, verificationId: data.$1, resendToken: data.$2, errorMessage: null);
          return true;
        },
      );
    } on TimeoutException {
      state = state.copyWith(isSendingCode: false, errorMessage: 'Taking too long — check your connection and try again.');
      return false;
    }
  }

  Future<bool> verifyCode(String smsCode) async {
    final verificationId = state.verificationId;
    if (verificationId == null) {
      state = state.copyWith(errorMessage: 'Something went wrong — please request a new code.');
      return false;
    }
    state = state.copyWith(isVerifying: true, errorMessage: null);
    try {
      final result = await ref
          .read(verifyOtpUseCaseProvider)
          .call(verificationId: verificationId, smsCode: smsCode)
          .timeout(const Duration(seconds: 25));
      return result.match(
        (failure) {
          state = state.copyWith(isVerifying: false, errorMessage: failure.message);
          return false;
        },
        (_) {
          state = state.copyWith(isVerifying: false, errorMessage: null);
          return true;
        },
      );
    } on TimeoutException {
      // A slow/dropped connection can leave Firebase's own call hanging
      // rather than erroring out — without this, the button just spins
      // forever with no way to know anything went wrong.
      state = state.copyWith(isVerifying: false, errorMessage: 'Taking too long — check your connection and try again.');
      return false;
    }
  }

  void reset() => state = const PhoneAuthState();
}

final phoneAuthProvider = NotifierProvider<PhoneAuthNotifier, PhoneAuthState>(PhoneAuthNotifier.new);

// ---- Phone signup: send OTP, then complete with name + password ----

class PhoneSignUpState {
  final bool isSendingCode;
  final bool isCompleting;
  final String? verificationId;
  final String? errorMessage;
  // NEW: same reasoning as PhoneAuthState.resendToken above.
  final int? resendToken;
  const PhoneSignUpState({this.isSendingCode = false, this.isCompleting = false, this.verificationId, this.errorMessage, this.resendToken});

  PhoneSignUpState copyWith({bool? isSendingCode, bool? isCompleting, String? verificationId, String? errorMessage, int? resendToken}) =>
      PhoneSignUpState(
        isSendingCode: isSendingCode ?? this.isSendingCode,
        isCompleting: isCompleting ?? this.isCompleting,
        verificationId: verificationId ?? this.verificationId,
        errorMessage: errorMessage,
        resendToken: resendToken ?? this.resendToken,
      );
}

class PhoneSignUpNotifier extends Notifier<PhoneSignUpState> {
  @override
  PhoneSignUpState build() => const PhoneSignUpState();

  // FIXED: same "resend silently does nothing" bug as PhoneAuthNotifier
  // above — now passes state.resendToken back in automatically.
  Future<bool> sendCode({
    required String phoneNumber,
    required String email,
  }) async {
    state = state.copyWith(
      isSendingCode: true,
      errorMessage: null,
    );

    final repository = ref.read(authRepositoryProvider);

    // --------------------------------------------------
    // 1. Check EMAIL
    // --------------------------------------------------

    final emailResult =
        await repository.checkEmailRegistered(email.trim());

    final emailExists = emailResult.match(
      (failure) {
        state = state.copyWith(
          isSendingCode: false,
          errorMessage: failure.message,
        );
        return true;
      },
      (registered) => registered,
    );

    if (emailExists) {
      state = state.copyWith(
        isSendingCode: false,
        errorMessage:
            'An account already exists with this email. Please login.',
      );
      return false;
    }

    // --------------------------------------------------
    // 2. Check PHONE
    // --------------------------------------------------

    final phoneResult =
        await repository.checkPhoneRegistered(phoneNumber);

    final phoneExists = phoneResult.match(
      (failure) {
        state = state.copyWith(
          isSendingCode: false,
          errorMessage: failure.message,
        );
        return true;
      },
      (registered) => registered,
    );

    if (phoneExists) {
      state = state.copyWith(
        isSendingCode: false,
        errorMessage:
            'An account already exists with this phone number. Please login.',
      );
      return false;
    }

    // --------------------------------------------------
    // 3. BOTH ARE NEW → send phone OTP
    // --------------------------------------------------

    try {
      final result = await ref
          .read(sendOtpUseCaseProvider)
          .call(
            phoneNumber,
            forceResendingToken: state.resendToken,
          )
          .timeout(const Duration(seconds: 30));

      return result.match(
        (failure) {
          state = state.copyWith(
            isSendingCode: false,
            errorMessage: failure.message,
          );
          return false;
        },
        (data) {
          state = state.copyWith(
            isSendingCode: false,
            verificationId: data.$1,
            resendToken: data.$2,
            errorMessage: null,
          );
          return true;
        },
      );
    } on TimeoutException {
      state = state.copyWith(
        isSendingCode: false,
        errorMessage:
            'Taking too long — check your connection and try again.',
      );
      return false;
    }
  }

  /// Verifies the code and, in the same step, sets the password this
  /// account will use for every future login — no OTP needed again
  /// after this.
  Future<bool> completeSignUp({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String smsCode,
  }) async {
    final verificationId = state.verificationId;
    if (verificationId == null) {
      state = state.copyWith(errorMessage: 'Something went wrong — please request a new code.');
      return false;
    }
    state = state.copyWith(isCompleting: true, errorMessage: null);
    try {
      final result = await ref
          .read(signUpWithPhoneUseCaseProvider)
          .call(name: name, email: email, phone: phone, password: password, verificationId: verificationId, smsCode: smsCode)
          .timeout(const Duration(seconds: 25));
      return result.match(
        (failure) {
          state = state.copyWith(isCompleting: false, errorMessage: failure.message);
          return false;
        },
        (_) {
          state = state.copyWith(isCompleting: false, errorMessage: null);
          return true;
        },
      );
    } on TimeoutException {
      state = state.copyWith(isCompleting: false, errorMessage: 'Taking too long — check your connection and try again.');
      return false;
    }
  }

  void reset() => state = const PhoneSignUpState();
}

final phoneSignUpProvider = NotifierProvider<PhoneSignUpNotifier, PhoneSignUpState>(PhoneSignUpNotifier.new);

// ---- Forgot password via phone: send OTP, then set new password ----

class PhonePasswordResetState {
  final bool isSendingCode;
  final bool isResetting;
  final String? verificationId;
  final String? errorMessage;
  // NEW: same reasoning as PhoneAuthState.resendToken.
  final int? resendToken;
  const PhonePasswordResetState({this.isSendingCode = false, this.isResetting = false, this.verificationId, this.errorMessage, this.resendToken});

  PhonePasswordResetState copyWith({bool? isSendingCode, bool? isResetting, String? verificationId, String? errorMessage, int? resendToken}) =>
      PhonePasswordResetState(
        isSendingCode: isSendingCode ?? this.isSendingCode,
        isResetting: isResetting ?? this.isResetting,
        verificationId: verificationId ?? this.verificationId,
        errorMessage: errorMessage,
        resendToken: resendToken ?? this.resendToken,
      );
}

class PhonePasswordResetNotifier extends Notifier<PhonePasswordResetState> {
  @override
  PhonePasswordResetState build() => const PhonePasswordResetState();

  // FIXED: same resend bug as the other two phone notifiers.
  Future<bool> sendCode(String phoneNumber) async {
    state = state.copyWith(isSendingCode: true, errorMessage: null);

    final checkResult = await ref.read(authRepositoryProvider).checkPhoneRegistered(phoneNumber);
    final isRegistered = checkResult.match((failure) {
      state = state.copyWith(isSendingCode: false, errorMessage: failure.message);
      return false;
    }, (registered) => registered);

    if (!isRegistered) {
      if (checkResult.match((_) => false, (registered) => !registered)) {
        state = state.copyWith(isSendingCode: false, errorMessage: 'No account found with this phone number.');
      }
      return false;
    }

    try {
      final result = await ref
          .read(sendOtpUseCaseProvider)
          .call(phoneNumber, forceResendingToken: state.resendToken)
          .timeout(const Duration(seconds: 30));
      return result.match(
        (failure) {
          state = state.copyWith(isSendingCode: false, errorMessage: failure.message);
          return false;
        },
        (data) {
          state = state.copyWith(isSendingCode: false, verificationId: data.$1, resendToken: data.$2, errorMessage: null);
          return true;
        },
      );
    } on TimeoutException {
      state = state.copyWith(isSendingCode: false, errorMessage: 'Taking too long — check your connection and try again.');
      return false;
    }
  }

  /// The OTP here proves phone ownership; the password is set in the
  /// very same call, which is what makes this a genuine reset — there
  /// is no code path that signs someone in via OTP alone without also
  /// requiring a new password right here.
  Future<bool> resetPassword({required String smsCode, required String newPassword}) async {
    final verificationId = state.verificationId;
    if (verificationId == null) {
      state = state.copyWith(errorMessage: 'Something went wrong — please request a new code.');
      return false;
    }
    state = state.copyWith(isResetting: true, errorMessage: null);
    final result = await ref.read(authRepositoryProvider).resetPasswordWithPhoneOtp(
          verificationId: verificationId,
          smsCode: smsCode,
          newPassword: newPassword,
        );
    return result.match(
      (failure) {
        state = state.copyWith(isResetting: false, errorMessage: failure.message);
        return false;
      },
      (_) {
        state = state.copyWith(isResetting: false, errorMessage: null);
        return true;
      },
    );
  }

  void reset() => state = const PhonePasswordResetState();
}

final phonePasswordResetProvider = NotifierProvider<PhonePasswordResetNotifier, PhonePasswordResetState>(PhonePasswordResetNotifier.new);

// ---- Email OTP signup: send code, then complete with name + phone + password ----

class EmailOtpSignUpState {
  final bool isSendingCode;
  final bool isCompleting;
  final bool codeSent;
  final String? errorMessage;

  const EmailOtpSignUpState({
    this.isSendingCode = false,
    this.isCompleting = false,
    this.codeSent = false,
    this.errorMessage,
  });

  EmailOtpSignUpState copyWith({
    bool? isSendingCode,
    bool? isCompleting,
    bool? codeSent,
    String? errorMessage,
  }) {
    return EmailOtpSignUpState(
      isSendingCode: isSendingCode ?? this.isSendingCode,
      isCompleting: isCompleting ?? this.isCompleting,
      codeSent: codeSent ?? this.codeSent,
      errorMessage: errorMessage,
    );
  }
}



class EmailOtpSignUpNotifier extends Notifier<EmailOtpSignUpState> {
  @override
  EmailOtpSignUpState build() => const EmailOtpSignUpState();

    Future<bool> sendCode({
    required String email,
    required String phone,
  }) async {
    state = state.copyWith(
      isSendingCode: true,
      errorMessage: null,
    );

    final repository = ref.read(authRepositoryProvider);

    // Check email
    final emailResult = await repository.checkEmailRegistered(email);

    final emailExists = emailResult.match(
      (failure) {
        state = state.copyWith(
          isSendingCode: false,
          errorMessage: failure.message,
        );
        return true;
      },
      (registered) => registered,
    );

    if (emailExists) {
      state = state.copyWith(
        isSendingCode: false,
        errorMessage:
            'An account already exists with this email. Please login.',
      );
      return false;
    }

    // Check phone
    final phoneResult = await repository.checkPhoneRegistered(phone);

    final phoneExists = phoneResult.match(
      (failure) {
        state = state.copyWith(
          isSendingCode: false,
          errorMessage: failure.message,
        );
        return true;
      },
      (registered) => registered,
    );

    if (phoneExists) {
      state = state.copyWith(
        isSendingCode: false,
        errorMessage:
            'An account already exists with this phone number. Please login.',
      );
      return false;
    }

    // Only send OTP if BOTH email and phone are new
    final result = await repository.sendEmailOtp(email);

    return result.match(
      (failure) {
        state = state.copyWith(
          isSendingCode: false,
          errorMessage: failure.message,
        );
        return false;
      },
      (_) {
        state = state.copyWith(
          isSendingCode: false,
          codeSent: true,
          errorMessage: null,
        );
        return true;
      },
    );
  }

  Future<bool> completeSignUp({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String code,
  }) async {
    state = state.copyWith(isCompleting: true, errorMessage: null);

    final verifyResult = await ref.read(authRepositoryProvider).verifyEmailOtp(email: email, code: code);
    final isValid = verifyResult.match((failure) {
      state = state.copyWith(isCompleting: false, errorMessage: failure.message);
      return false;
    }, (valid) => valid);

    if (!isValid) {
      if (verifyResult.match((_) => false, (valid) => !valid)) {
        state = state.copyWith(isCompleting: false, errorMessage: 'Incorrect or expired code.');
      }
      return false;
    }

    final signUpResult = await ref.read(authRepositoryProvider).signUpWithEmailOtp(
          name: name,
          email: email,
          phone: phone,
          password: password,
        );
    return signUpResult.match(
      (failure) {
        state = state.copyWith(isCompleting: false, errorMessage: failure.message);
        return false;
      },
      (_) {
        state = state.copyWith(isCompleting: false, errorMessage: null);
        return true;
      },
    );
  }

  void reset() => state = const EmailOtpSignUpState();
}

final emailOtpSignUpProvider = NotifierProvider<EmailOtpSignUpNotifier, EmailOtpSignUpState>(EmailOtpSignUpNotifier.new);
