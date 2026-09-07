# Ethix Gold — الدستور البرمجي النهائي الشامل

Use this guide whenever a new feature, screen, or module is requested "using the new method".  
هذا الملف هو المرجع الوحيد والملزم لهيكلية المشروع، أنماط الكود، وبوابة الجودة قبل التسليم.

## 1. Directory Structure
For any new module `{feature}`, the structure MUST be:
```
lib/modules/{feature}/
├── data/
│   ├── cubit/
│   │   ├── {feature}_cubit.dart
│   │   └── {feature}_state.dart
│   ├── model/
│   │   └── {feature}_model.dart
│   └── repo/
│       ├── {feature}_repo.dart
│       └── {feature}_repo_imp.dart
└── view/
    ├── {feature}_screen.dart
    └── {feature}_view_model.dart
```

> **ملاحظة**: ملف `{feature}_state.dart` يحتوي على تعريف الحالة (يفضل باستخدام **Freezed**) ويُفصل تماماً عن منطق الـ Cubit.

## 2. Repository Pattern (Repo & RepoImpl)
- **Interface**: Define abstract methods returning `Future<Either<Failure, Model>>`.
- **Implementation**: 
    - Use `DioHelper` directly (avoiding complex base classes for simplicity).
    - Use `try-catch` with `ErrorHandlerCustom`.
    - Return `Right(model)` on success, `Left(Failure)` on error.

```dart
// Example RepoImpl
class FeatureRepoImp implements FeatureRepo {
  @override
  Future<Either<Failure, MyResponseModel>> getData() async {
    try {
      final response = await DioHelper.getData(uri: ApiConstant.endpoint);
      return Right(MyResponseModel.fromJson(response.data));
    } catch (e) {
      return Left(ErrorHandlerCustom.handle(e).failure);
    }
  }
}
```

## 3. Cubit Pattern (BaseCubit & fastFire)
- Inherit from `BaseCubit<EnumTypes>`.
- Use `fastFire` to handle loading, error, and success states automatically.
- Keep the Cubit focused on calling the Repo and emitting the state.

> **قاعدة صارمة**: الـ Cubit يجب أن يكون **Pure Logic** ومعزول تماماً عن الـ UI. الـ Cubit يطلق الـ States فقط، بينما الـ **ViewModel** هو المسؤول عن الاستماع للحالة وتوجيه الـ UI أو إظهار الـ Toasts. **ممنوع** استخدام `navigatorKey` أو `BuildContext` داخل الـ Cubit.

### 3.1. هيكلية الـ Cubit:
1. يتم تعريف `enum` لكل العمليات داخل الـ Cubit (أو في ملف State منفصل).
2. يتم حقن الـ Repository عبر الـ Constructor أو `sl<FeatureRepo>()`.
3. **ممنوع** إضافة دالة `static get` للوصول للـ Cubit عبر `navigatorKey` أو `BuildContext`.

#### فصل الـ States باستخدام Freezed (ملف مستقل `{feature}_state.dart`):

```dart
// lib/modules/{feature}/data/cubit/{feature}_state.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import '../model/{feature}_model.dart';

part '{feature}_state.freezed.dart';

@freezed
class FeatureState with _$FeatureState {
  const factory FeatureState({
    @Default([]) List<FeatureModel> items,
    @Default(false) bool isSubmitting,
  }) = _FeatureState;
}
```

> بعد إنشاء الملف، شغّل: `dart run build_runner build --delete-conflicting-outputs`

ثم في `{feature}_cubit.dart` استورد الملف المنفصل واربطه بالـ Cubit:

```dart
import '{feature}_state.dart';

class FeatureCubit extends Cubit<FeatureState> {
  FeatureCubit(this._repo) : super(const FeatureState());

  final FeatureRepo _repo;
  // منطق العمليات هنا فقط — بدون أي رفرنس للـ Context
}
```

> عند استخدام `BaseCubit<EnumTypes>` مع `fastFire`، يبقى الـ `enum` لتحديد نوع العملية (loading/error/done)، بينما يحتفظ `FeatureState` (Freezed) ببيانات الحالة بشكل immutable.

#### مثال لـ Cubit شامل (GET + POST — Pure Logic فقط):

```dart
enum FeatureApiType { none, getOrders, addRequestOrder }

class FeatureCubit extends BaseCubit<FeatureApiType> {
  FeatureCubit(this._repo) : super(FeatureApiType.none);

  final FeatureRepo _repo;

  List<OrderModel> orders = [];

  Future<void> getOrders({CancelToken? cancelToken}) async {
    await fastFire(
      type: FeatureApiType.getOrders,
      fun: () => _repo.getOrders(cancelToken: cancelToken),
      onSuccess: (data) => orders = data,
    );
  }

  Future<void> addOrderRequest({required OrderRequestModel request, CancelToken? cancelToken}) async {
    await fastFire(
      type: FeatureApiType.addRequestOrder,
      fun: () => _repo.addOrder(request, cancelToken: cancelToken),
      onSuccess: (_) {},
    );
  }
}
```

> **لأنماط بناء الشاشات الكاملة (GET / POST)** راجع القسم **6 — Standard UI Implementation Patterns**.


## 4. ViewModel Pattern (BaseViewModel)
- Inherit from `BaseViewModel`.
- Bridge between the UI and Cubit.
- Manage `TextEditingController`s and UI-specific logic.
- Use `sl<Cubit>()` for dependency injection.
- استخدم `cancelToken` (الموروث من `BaseViewModel`) لإلغاء الريكويستات النشطة عند مغادرة الشاشة.
- استمع لحالات الـ Cubit عبر `BlocListener` لعرض Toasts والتنقل — **ليس** من داخل الـ Cubit.

> **تنبيه صارم**: يجب على كل ViewModel إغلاق الـ Cubit يدوياً داخل `dispose()` عبر `_featureCubit.close();` لمنع تسريب الذاكرة (Memory Leak). يجب استدعاء `super.dispose()` في النهاية لإلغاء الـ `CancelToken` تلقائياً (`cancelToken.cancel()`).

```dart
// Example ViewModel
class FeatureViewModel extends BaseViewModel {
  FeatureViewModel(super.reLoad, this._featureCubit);

  final FeatureCubit _featureCubit;
  final TextEditingController controller = TextEditingController();

  void submit() {
    _featureCubit.fetchData(cancelToken: cancelToken);
  }

  /// يُستدعى من BlocListener في الـ Screen عند نجاح العملية
  void onFetchSuccess(BuildContext context) {
    context.pop(); // GoRouter — التنقل من الـ ViewModel فقط
  }

  void onFetchError(Failure failure) {
    failure.showToast(); // Toast من الـ ViewModel — وليس من الـ Cubit
  }

  @override
  void dispose() {
    controller.dispose();
    _featureCubit.close(); // إغلاق الكوبيت يدوياً — إلزامي
    super.dispose();       // يلغي cancelToken.cancel() تلقائياً
  }
}
```

## 5. UI Screen Pattern (القواعد العامة)
- استخدم `const` constructor بدون parameters للشاشات (`Zero parameters constructor`).
- استخدم `AppGradientBackground` كجذر للشاشات ذات التصميم الموحد.
- استخدم `BlockBuilderWidget<Cubit, Type>` لإدارة حالات التحميل والخطأ والنجاح.
- **لا** تستدعِ `setState` إلا عبر `updateRefresh` مع فحص `mounted` — تجنب `setState` العشوائي.
- للأنماط الكاملة لشاشات GET و POST راجع **القسم 6**.

```dart
// Example Screen — هيكل مبسط
class FeatureScreen extends StatefulWidget {
  const FeatureScreen({super.key});

  @override
  State<FeatureScreen> createState() => _FeatureScreenState();
}

class _FeatureScreenState extends State<FeatureScreen> {
  late final FeatureViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = sl<FeatureViewModel>()..updateRefresh(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppGradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: BlockBuilderWidget<FeatureCubit, FeatureApiType>(
          types: const [FeatureApiType.getOrders],
          body: (_) => AuthTextField(controller: _viewModel.controller, label: '', hintText: '', icon: Icons.edit),
        ),
      ),
    );
  }
}
```

## 6. Standard UI Implementation Patterns (أنماط تنفيذ الواجهات القياسية)

هذا القسم هو المرجع الإلزامي عند بناء أي شاشة. يجب على الـ AI والمطورين محاكاته حرفياً مع الالتزام بحماية `mounted` ومنع `setState` العشوائي.

#### ViewModel المرافق (يُستخدم في كلا النمطين GET و POST):

```dart
class FeatureViewModel extends BaseViewModel {
  FeatureViewModel(super.reLoad, this._featureCubit);

  final FeatureCubit _featureCubit;
  FeatureCubit get featureCubit => _featureCubit;

  final TextEditingController controller = TextEditingController();

  void loadInitialData() {
    _featureCubit.getDataList(cancelToken: cancelToken);
  }

  Future<void> refreshData() async {
    await _featureCubit.getDataList(
      cancelToken: cancelToken,
      paginationMethod: PaginationMethod.refresh,
    );
    refresh();
  }

  void submit() {
    _featureCubit.submitData(cancelToken: cancelToken);
  }

  void onSubmitSuccess(BuildContext context) => context.pop();

  void onSubmitError() {
    // عرض Toast من الـ ViewModel — وليس من الـ Cubit
  }

  @override
  void dispose() {
    controller.dispose();
    _featureCubit.close();
    super.dispose();
  }
}
```

### 6.1. نمط استقبال وجلب البيانات (GET Pattern — القياسي)

يُستخدم عند بناء أي شاشة تعرض قوائم أو بيانات قادمة من الـ API (مثل الإعلانات) باستخدام الـ Slivers لأفضل أداء، ودعم الـ Pull to Refresh والـ Pagination، والتعامل مع حالات الـ Cubit عبر الـ ViewModel:

```dart
class FeatureGetScreen extends StatefulWidget {
  const FeatureGetScreen({super.key}); // Zero parameters constructor

  @override
  State<FeatureGetScreen> createState() => _FeatureGetScreenState();
}

class _FeatureGetScreenState extends State<FeatureGetScreen> {
  late final FeatureViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    // ربط الـ ViewModel وتمرير دالة الـ refresh المحلية الآمنة
    _viewModel = sl<FeatureViewModel>()..updateRefresh(() {
      if (mounted) setState(() {});
    });

    _viewModel.loadInitialData();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => _viewModel.refreshData(),
        child: CustomScrollView(
          slivers: [
            const SliverAppBar(title: Text('عرض البيانات القياسي')),

            // الـ BlockBuilder لإدارة الحالات الحتمية (Loading, Error, Success)
            BlockBuilderWidget<FeatureCubit, FeatureApiType>(
              types: const [FeatureApiType.getDataList],
              loading: (_) => const SliverToBoxAdapter(
                child: Center(child: CircularProgressIndicator()), // أو Shimmer
              ),
              error: (error) => SliverToBoxAdapter(
                child: Center(
                  child: ElevatedButton(
                    onPressed: () => _viewModel.refreshData(),
                    child: const Text('إعادة المحاولة'),
                  ),
                ),
              ),
              body: (_) => _buildDataList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataList() {
    final cubit = _viewModel.featureCubit;

    // التحقق من القائمة الفارغة وعرض الـ Empty State
    if (cubit.items.isEmpty) {
      return const SliverToBoxAdapter(
        child: Center(child: Text('لا توجد بيانات حالياً')),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final item = cubit.items[index];
          return ListTile(
            title: Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          );
        },
        childCount: cubit.items.length,
      ),
    );
  }
}
```

### 6.2. نمط إرسال البيانات (POST Pattern — القياسي)

يُستخدم عند بناء شاشات النماذج والإرسال (Login, Register, Create Alert...) مع `BlocListener` للتنقل والـ Toasts من الـ ViewModel:

```dart
class FeaturePostScreen extends StatefulWidget {
  const FeaturePostScreen({super.key}); // Zero parameters constructor

  @override
  State<FeaturePostScreen> createState() => _FeaturePostScreenState();
}

class _FeaturePostScreenState extends State<FeaturePostScreen> {
  late final FeatureViewModel _viewModel;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _viewModel = sl<FeatureViewModel>()..updateRefresh(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppGradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: MultiBlocListener(
          listeners: [
            BlocListener<FeatureCubit, BaseState<FeatureApiType>>(
              listenWhen: (_, state) => state.type == FeatureApiType.submit,
              listener: (context, state) {
                final cubit = context.read<FeatureCubit>();
                if (cubit.stateOf(FeatureApiType.submit).isDone()) {
                  _viewModel.onSubmitSuccess(context);
                }
                if (cubit.stateOf(FeatureApiType.submit).isError()) {
                  _viewModel.onSubmitError();
                }
              },
            ),
          ],
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const AuthHeader(),
                AuthTextField(
                  controller: _viewModel.controller,
                  label: 'الحقل',
                  hintText: 'أدخل البيانات',
                  icon: Icons.edit,
                ),
                BlockBuilderWidget<FeatureCubit, FeatureApiType>(
                  types: const [FeatureApiType.submit],
                  loading: (_) => const Center(child: CircularProgressIndicator()),
                  error: (_) => _buildSubmitButton(),
                  body: (_) => _buildSubmitButton(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: () {
        if (!_formKey.currentState!.validate()) return;
        _viewModel.submit();
      },
      child: const Text('إرسال'),
    );
  }
}
```

### 6.3. قواعد إلزامية لكل شاشة

| القاعدة | التفاصيل |
|---------|----------|
| Zero Params | `const FeatureScreen({super.key})` — لا تمرر Cubit أو ViewModel عبر Constructor |
| mounted | كل `setState` يجب أن يكون داخل `if (mounted)` |
| dispose | `_viewModel.dispose()` في `dispose()` الشاشة — يغلق Cubit ويلغي CancelToken |
| Navigation | GoRouter من الـ ViewModel فقط (`context.pop()`, `context.pushNamed()`) |
| Text | أي نص ديناميكي: `maxLines` + `TextOverflow.ellipsis` |
| Cubit Access | عبر `_viewModel.featureCubit` — **ممنوع** `static get` أو `navigatorKey` |

## 7. Registration in Service Locator
Don't forget to register the new components in `lib/core/di/service_locator.dart`:
```dart
sl.registerLazySingleton<FeatureRepo>(() => FeatureRepoImp());
sl.registerFactory(() => FeatureCubit(sl()));
sl.registerFactory(() => FeatureViewModel(null, sl()));
```

## 8. Core Boilerplate Files (Full Content)

Below is the exact content of the core files to be used for setting up any new project with this architecture.

### 8.1. Base ViewModel (`lib/core/base/base_view_model.dart`)
```dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

abstract class BaseViewModel extends ChangeNotifier {
  void Function()? reLoad;

  BaseViewModel([this.reLoad]);

  /// يُستخدم لإلغاء الريكويستات النشطة عند مغادرة الشاشة
  final CancelToken cancelToken = CancelToken();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  void setLoading(bool value) {
    if (_isLoading == value) return;
    _isLoading = value;
    notifyListeners();
  }

  void refresh() {
    reLoad?.call();
    notifyListeners();
  }

  void updateRefresh(void Function() newRefresh) {
    reLoad = newRefresh;
  }

  @override
  void dispose() {
    cancelToken.cancel();
    super.dispose();
  }
}
```

### 8.2. Base Cubit (`lib/modules/shared/cubit/bse_cubit.dart`)
```dart
import 'package:bloc/bloc.dart';
import 'package:dartz/dartz.dart';
import 'package:ethix_gold/modules/shared/cubit/responses/base_pagination_response.dart';

import '../../../core/common/error_handler/failure.dart';

enum StateType { loading, done, successfully, error, loadMore }

enum PaginationMethod { refresh, loadMore }

class BaseCubit<StatesEnum> extends Cubit<BaseState<StatesEnum>> {
  BaseCubit(StatesEnum currentState) : super(BaseState(currentState)) {
    init();
  }

  void init() {}

  final Map<StatesEnum, StateType> _stateMap = {};

  StateType stateOf(StatesEnum state) => _stateMap[state] ?? StateType.done;

  void fire(StatesEnum type, [StateType? stateType]) {
    if (stateType != null) _stateMap[type] = stateType;
    emit((BaseState(type)));
  }

  Future<Either<Failure, T>> fastFire<T>({
    required StatesEnum type,
    required Future<Either<Failure, T>> Function() fun,
    Function(Failure r)? onFailure,
    required Function(T l) onSuccess,
  }) async {
    fire(type, StateType.loading);
    var res = await fun();
    return res.fold(
      (l) {
        l.printInfo("fastFire<$T>");
        if (onFailure != null) onFailure(l);
        fire(type, StateType.error);
        return left(l);
      },
      (r) {
        onSuccess(r);
        fire(type, StateType.done);
        return right(r);
      },
    );
  }

  final Map<StatesEnum, BasePaginationResponse> _paginationMap = {};

  BasePaginationResponse paginationOf(StatesEnum state) => _paginationMap[state] ?? BasePaginationResponse();

  Future fastPagination<T>({
    required StatesEnum type,
    required Future<Either<Failure, T>> Function(int page) fun,
    required Function(T r) onRefreshSuccess,
    required Function(T r) onLoadMoreSuccess,
    required BasePaginationResponse? Function(T t) toMeta,
    required PaginationMethod paginationMethod,
    Function(Failure r)? onFailure,
  }) async {
    BasePaginationResponse paginationInfo = paginationOf(type);
    if (paginationMethod == PaginationMethod.loadMore && paginationInfo.currentPage >= paginationInfo.lastPage) return;

    if (paginationMethod == PaginationMethod.refresh) fire(type, StateType.loading);
    if (paginationMethod == PaginationMethod.loadMore) fire(type, StateType.loadMore);

    int nextPage = paginationMethod == PaginationMethod.refresh ? 1 : paginationInfo.currentPage + 1;
    var res = await fun(nextPage);

    return res.fold(
      (l) {
        l.printInfo("fastFire<$T>");
        if (onFailure != null) onFailure(l);
        fire(type, StateType.error);
        return left(l);
      },
      (r) {
        if (toMeta(r) != null) _paginationMap[type] = toMeta(r)!;
        if (paginationMethod == PaginationMethod.refresh) onRefreshSuccess(r);
        if (paginationMethod == PaginationMethod.loadMore) onLoadMoreSuccess(r);
        fire(type, StateType.done);
        return right(r);
      },
    );
  }
}

class BaseState<StatesEnum> {
  StatesEnum type;
  BaseState(this.type);
}

extension StateTypeEX on StateType {
  bool isLoading() => this == StateType.loading;
  bool isSuccessfully() => this == StateType.successfully;
  bool isDone() => this == StateType.done;
  bool isError() => this == StateType.error;
  bool isPaginationLoadMore() => this == StateType.loadMore;
}
```

### 8.3. Failure (`lib/core/common/error_handler/failure.dart`)
```dart
import 'package:ethix_gold/core/common/error_handler/toast_manager/tost_manager.dart';
import 'app_logger.dart';

class Failure {
  int code;
  String message;
  TypeMsg type;

  Failure(this.code, this.message, this.type);

  @override
  String toString() {
    return 'Failure{code: $code, message: $message, type: $type}';
  }

  void printInfo(String from) {
    AppLogger.log('from => $from : Failure{code: $code, message: $message, type: $type}');
  }

  showToast() => ToastManager.handelFailure(this);
}

enum TypeMsg { ok, error, warning }
```

### 8.4. App Logger (`lib/core/common/error_handler/app_logger.dart`)
```dart
import 'package:flutter/foundation.dart';

class AppLogger {
  static void log(String message) {
    if (kDebugMode) {
      debugPrint('💡 [APP_LOG]: $message');
    }
  }

  static void error(String message) {
    if (kDebugMode) {
      debugPrint('🔴 [APP_ERROR]: $message');
    }
  }

  static void info(String message) {
    if (kDebugMode) {
      debugPrint('ℹ️ [APP_INFO]: $message');
    }
  }
}
```

### 8.5. Error Handler (`lib/core/common/error_handler/error_handler.dart`)
```dart
import 'package:dio/dio.dart';
import 'failure.dart';

class ErrorHandlerCustom implements Exception {
  final Failure failure;

  ErrorHandlerCustom.handle(dynamic error) : failure = _getFailure(error);

  static Failure _getFailure(dynamic error) {
    if (error is DioException) {
      return _handleDioError(error);
    } else if (error is FormatException) {
      return Failure(-2, "حدث خطأ في معالجة البيانات من السيرفر", TypeMsg.error);
    } else {
      return Failure(-1, "حدث خطأ غير متوقع، يرجى المحاولة لاحقاً", TypeMsg.error);
    }
  }

  static Failure _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionTimeout:
        return Failure(-3, "يرجى التحقق من اتصالك بالإنترنت", TypeMsg.error);

      case DioExceptionType.badResponse:
        if (error.response?.data != null && error.response?.data is Map) {
          final message = error.response?.data['message'];
          if (message != null && message.toString().isNotEmpty) {
            return Failure(error.response?.statusCode ?? -4, message.toString(), TypeMsg.error);
          }
        }
        return Failure(-4, "نواجه مشكلة في الوصول للمحتوى حالياً", TypeMsg.error);

      case DioExceptionType.cancel:
        return Failure(-5, "تم إلغاء الطلب", TypeMsg.error);

      default:
        return Failure(-1, "عذراً، حدث خطأ ما", TypeMsg.error);
    }
  }
}
```

### 8.6. Toast Manager Implementation (`lib/core/common/error_handler/toast_manager/normal_toast_imp.dart`)
```dart
import 'package:ethix_gold/core/common/error_handler/toast_manager/toast_repo.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class ToastNormalImp implements ToastRepo {
  final FToast fToast = FToast();

  @override
  void showError(String msg, BuildContext context, {Duration? duration}) {
    _showCustomToast(msg, context, Colors.red, duration);
  }

  @override
  void showSuccess(String msg, BuildContext context, {Duration? duration}) {
    _showCustomToast(msg, context, Colors.green, duration);
  }

  @override
  void showWarning(String msg, BuildContext context, {Duration? duration}) {
    _showCustomToast(msg, context, Colors.orange, duration);
  }

  @override
  void showNormalMsg(String msg, BuildContext context, {Duration? duration}) {
    _showCustomToast(msg, context, Colors.grey, duration);
  }

  void _showCustomToast(String message, BuildContext context, Color backgroundColor, Duration? duration) {
    fToast.init(context);
    fToast.removeCustomToast();

    Widget toast = Container(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25.0),
        color: backgroundColor,
      ),
      child: Text(
        message,
        style: const TextStyle(color: Colors.white),
      ),
    );

    fToast.showToast(
      child: toast,
      gravity: ToastGravity.BOTTOM,
      toastDuration: duration ?? const Duration(seconds: 10),
    );
  }
}
```

### 8.7. Toast Repository (`lib/core/common/error_handler/toast_manager/toast_repo.dart`)
```dart
import 'package:flutter/material.dart';

abstract class ToastRepo {
  void showError(String msg, BuildContext context, {Duration? duration});
  void showWarning(String msg, BuildContext context, {Duration? duration});
  void showSuccess(String msg, BuildContext context, {Duration? duration});
  void showNormalMsg(String msg, BuildContext context, {Duration? duration});
}
```

### 8.8. Toast Manager (`lib/core/common/error_handler/toast_manager/tost_manager.dart`)
```dart
import 'package:ethix_gold/core/common/error_handler/failure.dart';
import 'package:ethix_gold/core/common/error_handler/toast_manager/toast_repo.dart';
import 'package:flutter/material.dart';

class ToastManager {
  ToastManager._();
  static late final ToastRepo _toastRepo;
  static late final GlobalKey<NavigatorState> _navigatorKey;
  static const Duration _fixedDuration = Duration(seconds: 10);

  static void init(ToastRepo toastRepo, GlobalKey<NavigatorState> navigatorKey) {
    _toastRepo = toastRepo;
    _navigatorKey = navigatorKey;
  }

  static void handelFailure(Failure failure) {
    switch (failure.type) {
      case TypeMsg.ok:
        success(failure.message);
        break;
      case TypeMsg.error:
        error(failure.message);
        break;
      case TypeMsg.warning:
        warning(failure.message);
        break;
    }
  }

  static void error(String msg) {
    if (_navigatorKey.currentState != null) {
      _toastRepo.showError(msg, _navigatorKey.currentState!.context, duration: _fixedDuration);
    }
  }

  static void warning(String msg) {
    if (_navigatorKey.currentState != null) {
      _toastRepo.showWarning(msg, _navigatorKey.currentState!.context, duration: _fixedDuration);
    }
  }

  static void success(String msg) {
    if (_navigatorKey.currentState != null) {
      _toastRepo.showSuccess(msg, _navigatorKey.currentState!.context, duration: _fixedDuration);
    }
  }

  static void normal(String msg) {
    if (_navigatorKey.currentState != null) {
      _toastRepo.showNormalMsg(msg, _navigatorKey.currentState!.context, duration: _fixedDuration);
    }
  }
}
```

### 8.9. API Constant (`lib/core/network/api_constant.dart`)
```dart
class ApiConstant {
  static const baseDevUrl = 'https://ethix-dev.fintech-teknoloji.com/api/';
  static const login = 'login';
  static const register = 'register';
  static const logout = 'logout';
  static const forgotPassword = '/forgot-password';
  static const changePassword = '/change_password';
  static const resetPasswordUpdate = '/reset-password';
  static const updateProfile = 'update_profile';
  static const checkOtp = 'verify-token';
}
```

### 8.10. Cache Helper (`lib/core/local/cache_helper.dart`)
```dart
import 'package:shared_preferences/shared_preferences.dart';

class CacheHelper {
  static late SharedPreferences sharedPreferences;

  static init() async {
    sharedPreferences = await SharedPreferences.getInstance();
  }

  static Future<bool> saveData({
    required String key,
    required dynamic value,
  }) async {
    if (value is String) return await sharedPreferences.setString(key, value);
    if (value is int) return await sharedPreferences.setInt(key, value);
    if (value is bool) return await sharedPreferences.setBool(key, value);
    return await sharedPreferences.setDouble(key, value);
  }

  static dynamic getData({required String key}) {
    return sharedPreferences.get(key);
  }

  static Future<bool> removeData({required String key}) async {
    return await sharedPreferences.remove(key);
  }

  static Future<bool> clearData() async {
    return await sharedPreferences.clear();
  }
}
```

### 8.11. Dio Helper (`lib/core/network/dio_helper.dart`)
```dart
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import '../local/cache_helper.dart';
import 'api_constant.dart';

class DioHelper {
  static Dio? _dio;
  static Dio get dio {
    if (_dio != null) return _dio!;
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstant.baseDevUrl,
        receiveDataWhenStatusError: true,
        validateStatus: (int? status) => true,
        connectTimeout: const Duration(seconds: 360),
        receiveTimeout: const Duration(seconds: 360),
      ),
    );
    _dio!.interceptors.add(PrettyDioLogger(requestHeader: true, requestBody: true, responseBody: true));
    return _dio!;
  }

  static Future<Response> getData({required String uri, dynamic query, Map<String, dynamic>? headers}) async {
    return await dio.get(uri, queryParameters: query, options: Options(headers: _getHeaders(headers ?? {})));
  }

  static Future<Response> postData({required String uri, dynamic data, Map<String, dynamic>? headers, bool isMultipart = false}) async {
    return await dio.post(uri, data: data, options: Options(headers: _getHeaders(headers ?? {}, isMultipart: isMultipart)));
  }

  static Map<String, dynamic> _getHeaders(Map<String, dynamic> more, {bool isMultipart = false}) {
    String? token = CacheHelper.getData(key: 'token');
    Map<String, dynamic> headers = {
      if (!isMultipart) 'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token?.isNotEmpty ?? false) 'Authorization': 'Bearer $token',
    };
    headers.addAll(more);
    return headers;
  }
}
```

### 8.12. Service Locator (`lib/core/di/service_locator.dart`)
```dart
import 'package:get_it/get_it.dart';

final sl = GetIt.instance;

Future<void> initServiceLocator() async {
  // Register Repos, Cubits and ViewModels here
}
```

### 8.13. App Router (`lib/core/router/app_router.dart`)
```dart
import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../local/cache_helper.dart';
import 'app_routes.dart';

class AppRouter {
  const AppRouter._();
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static final GoRouter router = GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: CacheHelper.getData(key: 'token') != null ? '/dashboard' : '/login',
    observers: <NavigatorObserver>[BotToastNavigatorObserver()],
    routes: <RouteBase>[
      // Define your routes here
    ],
  );
}
```

### 8.14. Route Helper Methods (`lib/core/router/route_help_methods.dart`)

<!-- اقتراح (Proposal): استخدام الـ navigatorKey مباشرة وبدون null checks -->

```dart
import 'package:go_router/go_router.dart';
import '../../main.dart'; // استيراد الـ navigatorKey من الملف الرئيسي

void navigateTo(String name, {Object? extra}) {
  navigatorKey.currentContext!.pushNamed(name, extra: extra);
}

void navigateOff(String name, {Object? extra}) {
  navigatorKey.currentContext!.goNamed(name, extra: extra);
}

void navigateBack() {
  navigatorKey.currentContext!.pop();
}
```

### 8.15. Error Source Codes (`lib/core/common/error_handler/res/error_source.dart`)
```dart
import 'string_errors_manager.dart';

class ErrorCodes {
  static const int success = 200;
  static const int defaultError = -1;
  static const int unexpectedCharacter = -7;
  static const int assetNotFound = -8;
  static const int responseIsNull = -9;
  static const int connectTimeOut = -10;
  static const int sendTimeOut = -11;
  static const int receiveTimeOut = -12;
  static const int cancel = -13;
  static const int authError = -14;
}

class ErrorMessages {
  static const String success = StringErrorManager.success;
  static const String unexpectedCharacter = StringErrorManager.parsingJsonErr;
  static const String defaultError = StringErrorManager.defaultError;
  static const String assetNotFound = StringErrorManager.assetNotFound;
  static const String responseIsNull = StringErrorManager.responseIsNull;
  static const String connectTimeOut = StringErrorManager.connectTimeOut;
  static const String sendTimeOut = StringErrorManager.sendTimeOut;
  static const String receiveTimeOut = StringErrorManager.receiveTimeOut;
  static const String cancel = StringErrorManager.cancel;
  static const String authError = StringErrorManager.authError;
}
```

### 8.16. String Error Manager (`lib/core/common/error_handler/res/string_errors_manager.dart`)
```dart
class StringErrorManager {
  static const String success = "success";
  static const String badRequestError = "bad_request_error";
  static const String noContent = "no_content";
  static const String forbiddenError = "forbidden_error";
  static const String unauthorizedError = "unauthorized_error";
  static const String notFoundError = "not_found_error";
  static const String conflictError = "conflict_error";
  static const String internalServerError = "internal_server_error";
  static const String unknownError = "unknown_error";
  static const String timeoutError = "timeout_error";
  static const String defaultError = "default_error";
  static const String cacheError = "cache_error";
  static const String noInternetError = "no_internet_error";
  static const String parsingJsonErr = "when parsing json";
  static const String assetNotFound = "asset not found";
  static const String responseIsNull = "response is null";
  static const String connectTimeOut = "connectTimeOut";
  static const String sendTimeOut = "sendTimeOut";
  static const String receiveTimeOut = "receiveTimeOut";
  static const String cancel = "cancel";
  static const String authError = "E-Mail-Adresse oder Passwort nicht korrekt";
}
```


### 8.17. Main Entry Point (`lib/main.dart`)

> **ملاحظة**: جميع الـ Imports يجب أن تبدأ بـ `package:ethix_gold/` — ممنوع استخدام مسارات مشاريع قديمة (مثل `doctor_gtc`).

```dart
import 'package:bloc/bloc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:ethix_gold/core/di/app.dart';
import 'package:ethix_gold/core/di/get_it.dart';
import 'package:ethix_gold/core/providers/network_provider.dart';
import 'package:ethix_gold/core/services/fcm_service.dart';
import 'package:ethix_gold/core/translation_app/codegen_loader.g.dart';
import 'package:ethix_gold/modules/shared/cubit/bloc_observer.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

GlobalKey<NavigatorState> navigatorKey = GlobalKey();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  try {
    // 1. تهيئة HydratedStorage
    HydratedBloc.storage = await HydratedStorage.build(
      storageDirectory: kIsWeb
          ? HydratedStorage.webStorageDirectory
          : await getApplicationDocumentsDirectory(),
    );

    // 2. تهيئة Firebase
    await Firebase.initializeApp();

    // 3. تهيئة SharedPreferences
    await SharedPreferences.getInstance();
  } catch (e) {
    debugPrint("Initialization Error: $e");
  }

  // 4. تهيئة Dependency Injection (Service Locator)
  await initAppModule();

  // 5. تهيئة FCM بعد جاهزية الـ DI
  await FcmService.instance.init();

  // 6. إعداد Bloc Observer وتنسيق شريط النظام
  Bloc.observer = MyBlocObserver();
  _setupSystemUI();

  // 7. تثبيت اتجاه الشاشة طوليًا فقط
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NetworkProvider()),
      ],
      child: ScreenUtilInit(
        designSize: const Size(360, 730),
        useInheritedMediaQuery: true,
        child: EasyLocalization(
          assetLoader: const CodegenLoader(),
          supportedLocales: const [Locale('en'), Locale('ar'), Locale('fr')],
          path: 'assets/translations',
          startLocale: const Locale('ar'),
          fallbackLocale: const Locale('ar'),
          child: const MyApp(),
        ),
      ),
    ),
  );
}

void _setupSystemUI() {
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF040B18),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
}
```

### 8.18. Base Pagination Response (`lib/modules/shared/cubit/responses/base_pagination_response.dart`)
```dart
class BasePaginationResponse {
  late int currentPage;
  late int from;
  late int lastPage;
  late int perPage;
  late int to;
  late int total;

  BasePaginationResponse({this.currentPage = 0, this.from = 0, this.lastPage = 1, this.perPage = 0, this.to = 0, this.total = 0});

  int _parseIntOrZero(dynamic obj) => int.tryParse(obj.toString()) ?? 0;

  BasePaginationResponse.fromJson(Map<String, dynamic> json) {
    currentPage = _parseIntOrZero(json['current_page']);
    from = _parseIntOrZero(json['from']);
    lastPage = _parseIntOrZero(json['last_page']);
    perPage = _parseIntOrZero(json['per_page']);
    to = _parseIntOrZero(json['to']);
    total = _parseIntOrZero(json['total']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['current_page'] = currentPage;
    data['from'] = from;
    data['last_page'] = lastPage;
    data['per_page'] = perPage;
    data['to'] = to;
    data['total'] = total;
    return data;
  }
}
```

### 8.19. Block Builder Widget (`lib/modules/shared/cubit/block_builder_widget.dart`)
```dart
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'bse_cubit.dart';

class BlockBuilderWidget<Cubit extends BaseCubit<S>, S> extends StatelessWidget {
  final List<S> types;
  final Widget Function(S currentApi) body;
  final Widget Function(S currentApi)? loading;
  final Widget Function(S currentApi)? error;
  final Widget Function(S currentApi)? fetchMore;

  const BlockBuilderWidget({super.key, required this.body, this.loading, this.error, required this.types, this.fetchMore});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<Cubit, BaseState>(
      buildWhen: (p, c) => types.contains(c.type),
      builder: (context, state) {
        BaseCubit cubit = context.read<Cubit>();
        var currentState = cubit.stateOf(state.type);
        if (currentState.isDone()) return body(state.type);
        if (currentState.isLoading()) return loading != null ? loading!(state.type) : const Center(child: CircularProgressIndicator());
        if (currentState.isError()) return error != null ? error!(state.type) : const SizedBox();
        if (currentState.isPaginationLoadMore()) return fetchMore != null ? fetchMore!(state.type) : body(state.type);
        return const SizedBox();
      },
    );
  }
}
```

### 8.20. App Gradient Background (`lib/core/widgets/app_gradient_background.dart`)
```dart
import 'package:flutter/material.dart';

class AppGradientBackground extends StatelessWidget {
  const AppGradientBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFF0D1833), // Deep Navy
      ),
      child: child,
    );
  }
}
```

### 8.21. Auth Header (`lib/modules/auth/widgets/auth_header.dart`)
```dart
import 'package:flutter/material.dart';

class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Logo and Title implementation as per design
        const Icon(Icons.currency_exchange_rounded, color: Colors.amber, size: 64),
        const SizedBox(height: 24),
        const Text('Ethix Gold', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 8),
        Text('PREMIUM INVESTMENT', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), letterSpacing: 2.0)),
      ],
    );
  }
}
```

### 8.22. Auth Text Field (`lib/modules/auth/widgets/auth_text_field.dart`)
```dart
import 'package:flutter/material.dart';

class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.label,
    required this.hintText,
    required this.icon,
    this.isPassword = false,
    this.controller,
  });

  final String label;
  final String hintText;
  final IconData icon;
  final bool isPassword;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: const TextStyle(color: Colors.grey, fontSize: 11)),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          obscureText: isPassword,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: Icon(icon, color: Colors.white54),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}
```

## 9. Usage Guide & Master Prompts

Use these prompts to ensure any AI (Cursor, Claude, or myself) follows this architecture and directory structure perfectly.

### 9.1. Master Prompt for New Projects (Arabic)
> **"ابدأ مشروع جديد باستخدام الهيكلية المحددة في ملف `docs/architecture_guide.md`.**
> 
> **الخطوات المطلوبة:**
> 1. **تجهيز الـ Core**: قم بإنشاء هيكل مجلدات `lib/core/` بالكامل (base, common, network, local, router, theme, widgets, di).
> 2. **نسخ ملفات الـ Core**: قم بكتابة الكود الكامل لملفات الـ Boilerplate الموجودة في **القسم 8** من الدليل في مساراتها الصحيحة.
> 3. **تجهيز الموديول الأول**: ابدأ بإنشاء موديول [اسم الميزة] باستخدام تقسيم المجلدات (data/repo, data/cubit, data/model, view/screen, view/view_model) مع فصل `{feature}_state.dart`.
> 4. **اتباع الأنماط**: التزم بنمط `fastFire` في الـ Cubit، ونمط `ViewModel-Cubit` في الربط مع الواجهات، وأنماط **القسم 6** (GET/POST) عند بناء الشاشات. الـ Cubit Pure Logic فقط — التنقل والـ Toasts من الـ ViewModel."

### 9.2. Master Prompt for New Projects (English - Recommended)
> **"Start a new project strictly following the architecture in `docs/architecture_guide.md`.**
> 
> **Instructions:**
> 1. **Core Setup**: Create the full `lib/core/` directory structure (base, common, network, local, router, theme, widgets, di).
> 2. **Core Boilerplate**: Implement ALL files from **Section 8** of the guide exactly as written in their respective paths.
> 3. **First Module**: Initialize the [Feature Name] module with the mandatory structure: `data/(repo, cubit, model)` and `view/(screen, view_model)`, including a separate `{feature}_state.dart`.
> 4. **Pattern Adherence**: Use the `fastFire` pattern for Cubit APIs, the `ViewModel-Cubit` pattern for UI binding, and **Section 6** standard UI patterns (GET/POST) for screens. Cubit must be Pure Logic — navigation and toasts belong to ViewModel only."

### 9.3. Screen Implementation Prompt (Arabic)
> **"قم بتنفيذ التصميم الموضح في الصور المرفقة لموديول [اسم الميزة]، مع الالتزام بملف `docs/architecture_guide.md`.**
> 
> **المطلوب:**
> 1. إنشاء ملفات الـ `Repo`, `Cubit`, `{feature}_state`, `ViewModel`, و `Screen` لهذا الموديول.
> 2. استخدام ويدجت `AuthHeader`, `AuthTextField`, و `AppGradientBackground` من **القسم 8**.
> 3. تطبيق أنماط **القسم 6** (GET أو POST حسب نوع الشاشة) مع `fastFire` في الـ Cubit.
> 4. إغلاق الـ Cubit وإلغاء `CancelToken` في `dispose()` الخاص بالـ ViewModel."

### 9.4. Mandatory Directory Structure Reference
Remember, the directory structure MUST always follow this pattern:
- `lib/core/`: (base, common, network, local, router, theme, widgets, di)
- `lib/modules/{feature}/data/`: (cubit, model, repo)
- `lib/modules/{feature}/data/cubit/`: ({feature}_cubit.dart, {feature}_state.dart)
- `lib/modules/{feature}/view/`: ({feature}_screen.dart, {feature}_view_model.dart)

---

## 10. Pre-Delivery Checklist (بوابة الجودة)

قبل رفع الكود (Push / PR)، يجب على المطور التأكد من الالتزام بالبنود التالية:

- [ ] تم فصل الـ States في ملف مستقل `{feature}_state.dart`.
- [ ] الكوبيت لا يحتوي على أي رفرنس للـ Context أو الـ `navigatorKey`.
- [ ] يتم عمل cancel للـ `CancelToken` وإغلاق الـ Cubit داخل الـ `dispose()` في الـ ViewModel.
- [ ] كل الـ Imports في ملف الـ `main.dart` تم تنظيفها وتوحيدها باسم `ethix_gold`.
- [ ] أي Text ديناميكي محمي بـ `maxLines` و `TextOverflow.ellipsis`.
- [ ] التنقل يتم بـ GoRouter من الـ ViewModel فقط وبـ Primitive types.
- [ ] شاشات GET تتبع نمط **القسم 6.1** (Slivers + RefreshIndicator + BlockBuilder).
- [ ] شاشات POST تتبع نمط **القسم 6.2** (BlocListener + Form + BlockBuilder على الزر).
- [ ] كل `setState` محمي بـ `if (mounted)` عبر `updateRefresh` فقط.
- [ ] الشاشة تستخدم `Zero parameters constructor` (`const Screen({super.key})`).
