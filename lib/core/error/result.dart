import 'package:fpdart/fpdart.dart';
import 'failure.dart';
import 'exceptions.dart';

/// Standard return type for every repository/usecase method in the app.
/// Left = Failure, Right = success value.
typedef Result<T> = Either<Failure, T>;

/// Convenience wrapper: runs [action], catching FirebaseException/generic
/// exceptions and mapping them into a [Failure] instead of letting them
/// escape the data layer. Use this inside every DataSource/RepositoryImpl
/// method rather than hand-writing try/catch everywhere.
Future<Result<T>> guard<T>(Future<T> Function() action) async {
  try {
    final value = await action();
    return Right(value);
  } on Failure catch (f) {
    return Left(f);
  } on AuthException catch (e) {
    return Left(AuthFailure(e.message));
  } on NotFoundException catch (e) {
    return Left(NotFoundFailure(e.message));
  } on ServerException catch (e) {
    return Left(ServerFailure(e.message));
  } catch (e) {
    return Left(ServerFailure(e.toString()));
  }
}
