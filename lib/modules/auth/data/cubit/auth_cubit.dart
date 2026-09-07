import 'package:dartz/dartz.dart';
import '../../../../core/common/error_handler/failure.dart';
import '../../../shared/cubit/base_cubit.dart';
import '../repo/auth_repo.dart';

enum AuthApiType { none, login }

class AuthCubit extends BaseCubit<AuthApiType> {
  final AuthRepo _authRepo;

  AuthCubit(this._authRepo) : super(AuthApiType.none);

  Map<String, dynamic>? authenticatedUser;

  Future<Either<Failure, Map<String, dynamic>>> login({
    required String username,
    required String password,
  }) async {
    return await fastFire(
      type: AuthApiType.login,
      fun: () => _authRepo.login(username: username, password: password),
      onSuccess: (user) {
        authenticatedUser = user;
      },
    );
  }
}
