import 'package:get_it/get_it.dart';
import '../../modules/auth/data/cubit/auth_cubit.dart';
import '../../modules/auth/data/repo/auth_repo.dart';
import '../../modules/auth/view/login_view_model.dart';
import '../../modules/clinic/data/cubit/clinic_cubit.dart';
import '../../modules/clinic/data/repo/clinic_repository.dart';
import '../../modules/clinic/data/repo/local_clinic_repository.dart';
import '../../modules/clinic/view/clinic_view_model.dart';
import '../../modules/main_shell/view/main_shell_view_model.dart';
import '../../modules/shift/data/cubit/shift_cubit.dart';
import '../../modules/shift/data/repo/shift_repo.dart';
import '../../modules/shift/view/shift_view_model.dart';
import '../../modules/splash/view/splash_view_model.dart';

final sl = GetIt.instance;

Future<void> initServiceLocator() async {
  // Repositories
  sl.registerLazySingleton<AuthRepo>(() => AuthRepoImpl());
  sl.registerLazySingleton<ShiftRepo>(() => ShiftRepoImpl());
  sl.registerLazySingleton<ClinicRepository>(() => LocalClinicRepository());

  // Cubits (Factory & Singleton)
  sl.registerFactory(() => AuthCubit(sl()));
  sl.registerFactory(() => ShiftCubit(sl()));
  sl.registerLazySingleton(() => ClinicCubit(sl()));

  // ViewModels (Factory)
  sl.registerFactory(() => SplashViewModel(null));
  sl.registerFactory(() => LoginViewModel(null, sl()));
  sl.registerFactory(() => ShiftViewModel(null, sl()));
  sl.registerFactory(() => MainShellViewModel(null));
  sl.registerFactory(() => ClinicViewModel(null, sl()));
}
