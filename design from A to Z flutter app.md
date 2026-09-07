# 📘 design from A to Z flutter app.md — المرجع الموحد النهائي الشامل

هذا الملف هو **الدستور البرمجي والعملي الكامل** لتصميم وبرمجة تطبيقات Flutter من الصفر وحتى تسليم كود نظيف وخالٍ من الأخطاء. يدمج هذا الملف **دورة حياة التصميم (Design Workflow)** و **دليل البنية البرمجية الصارمة (Architecture Guide)** ليكون المرجع الوحيد لكل مشروع.

---

## 0. البنية البرمجية والتقنيات (Quad-Layer Architecture & Tech Stack)

نعتمد بنية **Quad-Layer Architecture** الصارمة لتقسيم الكود:
* **Data Layer** (طبقة البيانات) ← `cubit`, `model`, `repo`
* **View Layer** (طبقة العرض) ← `screen`, `view_model`, `widget`

### جدول التقنيات المعتمدة (Tech Stack)

| Concern              | Package                                |
|----------------------|----------------------------------------|
| State Management     | `flutter_bloc` (Cubit only)            |
| Dependency Injection | `get_it` + `injectable`                |
| Navigation           | `go_router`                            |
| Network              | `dio`                                  |
| Error Handling       | `dartz` → `Either<Failure, T>`         |
| Environment Vars     | `flutter_dotenv`                       |
| Local Storage        | `hive` or `shared_preferences`         |
| Assets / Icons       | `flutter_svg` + `cached_network_image` |
| Localization         | `easy_localization`                    |
| Responsive UI        | `flutter_screenutil`                   |

---

## 1. القواعد الصارمة للكتابة (Strict Clean Code Rules)

### أ. قواعد Clean Code العامة (Clean Code Rules)
- **Guard Clauses (Fail Fast)**: تجنب تداخل جمل الشرط (Nested if/else).
  * ✅ `if (items.isEmpty) return; if (!isValid) return; _process();`
  * ❌ `if (items.isNotEmpty) { if (isValid) { _process(); } }`
- **Arrow `=>` للمصطلحات أحادية التعبير فقط**: لا تستخدم الـ Arrow مع الـ Widgets متعددة الأبناء.
  * ✅ `bool get isEmpty => _items.isEmpty;`
  * ✅ `Widget _label() => Text('OK');`
  * ❌ `Widget _body() => Column(children: [_header(), _content()]);`
- **منع التعبيرات الثلاثية المتداخلة (No Nested Ternaries)**:
  * ✅ `if (isLoading) return _shimmer(); if (hasError) return _error(); return _content();`
  * ❌ `isLoading ? _shimmer() : hasError ? _error() : _content();`
- **تحويل الشروط المعقدة إلى Getters موصوفة**:
  * ✅ `bool get canSubmit => _items.isNotEmpty && _reason.isNotEmpty;`
  * ❌ `if (_items.isNotEmpty && _reason.isNotEmpty) { submit() }`
- **حماية الـ Rebuild**: لا تقم بعمل `notifyListeners` أو تحديث الحالة إلا إذا كانت القيمة الجديدة مختلفة فعلاً.
  * ✅ `void update(int v) { if (_v == v) return; _v = v.clamp(0, max); notifyListeners(); }`
- **التسميات الموصوفة ذاتياً (Self-Documented Code)**: التسميات الممتازة تلغي الحاجة للتعليقات الجانبية. استخدم التعليقات لتوضيح **السبب (Why)** وليس **ماذا يفعل الكود (What)**.
- **تسمية المتغيرات المنطقية**: البولين تبدأ بـ `is/has/can` والأحداث بـ `on` والـ Builders بـ `_build`.

### ب. قواعد المعمارية الصارمة (Strict Architecture Rules)
1. **Cubit = Pure Logic**: ممنوع تماماً استخدام `BuildContext` أو `navigatorKey` أو استدعاء UI أو توستات بداخل الـ Cubit.
2. **Screen = UI Only**: الشاشة لا تقوم باستدعاء الـ API مباشرة بل يتم كل شيء عبر الـ ViewModel.
3. **ViewModel = LifeCycle Bridge**: إدارة الـ Controllers، والـ Navigation، والـ Toasts، والـ Upload progress.
4. **Repo = Data Access**: كل ميثود بالـ Repo يجب أن ترجع `Future<Either<Failure, T>>`.
5. **الوراثة من `BaseCubit<EnumType>`**: استخدام `fastFire` (للطلبات الأحادية أو POST) و `fastPagination` (للـ GET المرفق بترقيم الصفحات) مع استخدام الـ `BlockBuilderWidget` لإدارة الحالات.
6. **حقن التبعيات (DI)**: يتم حصراً عبر `sl<>()`. **يمنع تماماً**:
   - استخدام الـ static get في الـ Cubit مثل: `Cubit.get(context)`.
   - إنشاء الـ Repo كمتغير محلي داخل الـ Cubit يدويًا (يجب حقنه بالـ Constructor).
   - إنشاء الـ ViewModel يدويًا داخل الشاشة (يجب جلبه بالـ `sl()`).
7. **منع الـ print()**: استخدم `AppLogger` دائماً.
8. **الشاشات**:
   - **GET (جلب البيانات)**: الـ `BlockBuilderWidget` يغلف **كامل محتوى الشاشة**.
   - **POST (إرسال البيانات/الفورم)**: الـ `BlockBuilderWidget` يغلف **زر الإرسال فقط**، مع استخدام `BlocListener` للاستماع لانتهاء العملية (النجاح/الفشل) وتوجيه المستخدم أو إظهار توست من الـ ViewModel.

---

## 2. دورة حياة التصميم (Design Workflow - Tasks 1-5)

### الخطوة 1: تحليل لقطات الشاشة (Analyze Design Images)
- تحديد عدد الشاشات المطلوبة.
- حصر العناصر المشتركة (Repeated Components).
- تصنيف كل شاشة: **GET** (عرض قائمة/تفاصيل) أو **POST** (فورم/رفع بيانات).

### الخطوة 2: استخراج الرموز التصميمية (Design Tokens)
تعريف الألوان والخطوط والأبعاد في ملفات مستقلة تحت `lib/core/theme/` مع استخدام `flutter_screenutil` للمقاسات المتجاوبة:

```dart
// lib/core/theme/app_colors.dart
class AppColors {
  AppColors._();
  static const primary              = Color(0xFF1E88E5);
  static const colorSecondPrimary   = Color(0xFF43A047);
  static const background           = Color(0xFF0D1833);
  static const surface              = Color(0xFFFFFFFF);
  static const error                = Color(0xFFD32F2F);
  static const black                = Color(0xFF000000);
  static const colorDarkGrey        = Color(0xFF757575);
}

// lib/core/theme/app_text_styles.dart
class AppTextStyles {
  AppTextStyles._();
  static final headline1 = TextStyle(fontSize: 32.sp, fontWeight: FontWeight.w700);
  static final body1     = TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w400);
}
```

### الخطوة 3: تعريف الشاشات (Define Screens List)
صياغة جدول بالشاشات وتحديد نوعها:

| # | Screen Name          | File Name                    | Type | Description                   |
|---|----------------------|------------------------------|------|-------------------------------|
| 1 | SplashScreen         | `splash_screen.dart`         | —    | App launch / branding         |
| 2 | AdvertisementsScreen | `advertisements_screen.dart` | GET  | Paginated messages list       |
| 3 | SpecialQuestionScreen| `special_question_screen.dart`| POST | Ask custom questions + upload |

### الخطوة 4: مسار المستخدم (User Flow)
تحديد مسار التنقل وحراس المصادقة (Auth Guards) وتوجيه GoRouter.

### الخطوة 5: حصر الودجت المشتركة (Shared Widgets)
تجميع الـ Widgets المتكررة كـ: `AppButton`, `AuthTextField`, `AppErrorWidget`, `PullToRefreshWidget`, `showUploadFilesDialog`.

---

## 3. هيكل المجلدات وترتيب البناء (Directory Structure)

يتم ترتيب ملفات أي ميزة جديدة `{feature}` على النحو التالي:

```
lib/
├── core/                          # ملفات الـ Core والـ Boilerplate
├── shared/cubit/                  # BaseCubit + BlockBuilderWidget
└── modules/{feature}/
    ├── data/
    │   ├── cubit/
    │   │   ├── {feature}_cubit.dart
    │   │   └── {feature}_state.dart   # اختياري (sealed class)
    │   ├── model/
    │   │   └── {feature}_model.dart
    │   └── repo/
    │       └── {feature}_repo.dart    # يحتوي على الواجهة والتنفيذ معاً
    ├── view/
    │   ├── {feature}_screen.dart      # شاشة GET أو POST متوافقة مع القواعد
    │   └── {feature}_view_model.dart
    └── widget/
        └── {feature}_list_widget.dart # الودجت الفرعية التابعة للميزة
```

### ⚡ ترتيب إنشاء ملفات الميزة (Feature Build Order):
1. **Repo**: واجهة البيانات واستدعاءات الـ API.
2. **Cubit**: منطق العمل وتحديث الـ States.
3. **ViewModel**: ربط الـ Controllers والـ Callbacks.
4. **Screen**: بناء الواجهة الرسومية (GET أو POST).
5. **Widgets**: كتابة المكونات الفرعية.
6. **DI**: تسجيل المكونات في الـ Service Locator.

---

## 4. نموذج التطبيق البرمجي (Implementation Guide)

### 4.1. الـ Repository (Repo Pattern)
يجب إرجاع `Future<Either<Failure, T>>` واستخدام الـ `handleResponse` أو الـ `try-catch` مع `ErrorHandlerCustom`:

```dart
// lib/modules/special_question/data/repo/special_question_repo.dart
abstract class SpecialQuestionRepo {
  Future<Either<Failure, DefaultResponse>> addSpecialQuestion({
    required AddAppointmentByPatientModel addAppointmentByPatientModel,
    void Function(int sent, int total)? onSendProgress,
  });
}

class SpecialQuestionImp implements SpecialQuestionRepo {
  @override
  Future<Either<Failure, DefaultResponse>> addSpecialQuestion({
    required AddAppointmentByPatientModel addAppointmentByPatientModel,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    return await handleResponse(
      endPoint: ApiConstant.addSpecialQuestion,
      data: addAppointmentByPatientModel.toJson(),
      asObject: (e) => DefaultResponse.fromJson(e),
      method: DioMethod.post,
      onSendProgress: onSendProgress,
    );
  }
}
```

### 4.2. الـ Cubit (استخدام `fastFire` و `fastPagination`)
- يجب أن يرث من `BaseCubit<EnumType>`.
- **ممنوع تماماً** إنشاء الـ Repo يدويًا بالداخل؛ بل يتم حقنه عبر الـ Constructor.
- **ممنوع تماماً** استخدام الـ static `get()` أو الـ `BuildContext`.

```dart
// lib/modules/special_question/data/cubit/special_question_cubit.dart
enum SpecialQuestionApiType { none, addSpecialQuestion }

@injectable
class SpecialQuestionCubit extends BaseCubit<SpecialQuestionApiType> {
  SpecialQuestionCubit(this._repo) : super(SpecialQuestionApiType.none);

  final SpecialQuestionRepo _repo;

  Future<Either<Failure, DefaultResponse>> addSpecialQuestion({
    required AddAppointmentByPatientModel addAppointmentByPatientModel,
    required dynamic Function(DefaultResponse) onSuccess,
    void Function(int, int)? onSendProgress,
  }) async {
    return await fastFire(
      type: SpecialQuestionApiType.addSpecialQuestion,
      fun: () => _repo.addSpecialQuestion(
          addAppointmentByPatientModel: addAppointmentByPatientModel, 
          onSendProgress: onSendProgress,
      ),
      onSuccess: onSuccess,
      onFailure: (failure) => AppLogger.error('addSpecialQuestion Failure: ${failure.toString()}'),
    );
  }
}
```

### 4.3. الـ ViewModel (BaseViewModel)
يدير الـ Controllers، شريط تقدم الرفع، وإغلاق الـ Cubit والـ CancelToken:

```dart
// lib/modules/special_question/view/special_question_view_model.dart
@injectable
class SpecialQuestionViewModel extends BaseViewModel {
  SpecialQuestionViewModel(super.reLoad, this.specialQuestionCubit);

  final SpecialQuestionCubit specialQuestionCubit;
  
  // شريط تقدم الرفع
  final UploadProgressController mainUploadProgress = UploadProgressController();
  
  // التحقق من وجود ملفات محلية للرفع
  bool get hasLocalUploads => /* منطق التحقق من الملفات */;
  AddAppointmentByPatientModel? addAppointmentByPatientModel;
  String? appointmentId;

  void resetAllUploadControllers() => mainUploadProgress.reset();
  void completeAllUploadControllers() => mainUploadProgress.complete();
  void dispatchUploadProgress(int sent, int total) => mainUploadProgress.update(sent, total);

  Future<void> onTapAddOrEditAppointment(
    BuildContext context, {
    required bool isCompleteScreenStatement,
    String? appointmentId,
    void Function(int, int)? onSendProgress,
  }) async {
    if (addAppointmentByPatientModel == null) return;
    
    await specialQuestionCubit.addSpecialQuestion(
      addAppointmentByPatientModel: addAppointmentByPatientModel!,
      onSendProgress: onSendProgress,
      onSuccess: (response) {
        // إدارة النجاح عبر الـ ViewModel وتوجيه الـ UI
        context.pop(); 
      },
    );
  }

  @override
  void dispose() {
    specialQuestionCubit.close();
    super.dispose();
  }
}
```

---

## 5. نماذج الشاشات القياسية (Standard UI Screens)

### 5.1. نمط شاشة جلب البيانات (GET Pattern - Paginated Fetch)
* الـ `BlockBuilderWidget` يغلف **كامل مساحة المحتوى**.
* استخدام `PullToRefreshWidget` لتفعيل التحديث والسحب للأسفل وجلب المزيد.

```dart
class FeatureGetScreen extends StatefulWidget {
  const FeatureGetScreen({super.key});

  @override
  State<FeatureGetScreen> createState() => _FeatureGetScreenState();
}

class _FeatureGetScreenState extends State<FeatureGetScreen> {
  late final FeatureViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    // جلب الـ ViewModel بالـ sl مع ربط الـ refresh وحماية الـ mounted
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
      appBar: AppDefaultAppBar(title: AppStrings.featureTitle),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(AppDimens.paddingMD.w),
          child: BlockBuilderWidget<FeatureCubit, FeatureApiType>(
            types: const [FeatureApiType.getList],
            loading: (_) => ShimmerHelper().listViewVerticalShimmer(height: 100.h),
            error: (_) => AppErrorWidget(
              onRetry: () {
                _viewModel.featureCubit.listModel = null;
                _viewModel.refreshData();
              },
            ),
            body: (_) => PullToRefreshWidget(
              onChangeRefresh: () => _viewModel.refreshData(),
              onChangeLoadingMore: () => _viewModel.loadMore(),
              widgetChild: _buildList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    final items = _viewModel.featureCubit.listModel?.data;
    if (items == null || items.isEmpty) {
      return const AppEmptyWidget();
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const BouncingScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, __) => SizedBox(height: AppDimens.paddingSM.h),
      itemBuilder: (_, index) => FeatureListItemWidget(item: items[index]),
    );
  }
}
```

### 5.2. نمط شاشات الإرسال (POST Pattern - Form Submit & Progress dialog)
* الـ `BlockBuilderWidget` يغلف **زر الإرسال فقط** لكي لا يُعاد رسم كامل الشاشة أثناء التحميل.
* استخدام `MultiBlocListener` أو `BlocListener` للاستماع لانتهاء العملية وإظهار التوست أو التنقل.
* فحص الإنترنت عن طريق `NetworkCheckerCubit` قبل بدء الـ Action.
* معالجة تقدم الرفع (Progress Dialog) بداخل بلوك `try-finally` لضمان إغلاق الدايلوج دائماً حتى عند حدوث أخطاء.

```dart
class SpecialQuestionScreen extends StatefulWidget {
  const SpecialQuestionScreen({super.key, required this.appointmentDataViewModel});
  final SpecialQuestionViewModel appointmentDataViewModel;

  @override
  State<SpecialQuestionScreen> createState() => _SpecialQuestionScreenState();
}

class _SpecialQuestionScreenState extends State<SpecialQuestionScreen> {
  final formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppDefaultAppBar(title: "إرسال سؤال طبي خاص"),
      body: BlocListener<SpecialQuestionCubit, BaseState<SpecialQuestionApiType>>(
        listenWhen: (_, state) => state.type == SpecialQuestionApiType.addSpecialQuestion,
        listener: (context, state) {
          final cubit = context.read<SpecialQuestionCubit>();
          final currentState = cubit.stateOf(SpecialQuestionApiType.addSpecialQuestion);
          
          if (currentState.isDone()) {
            ToastManager.success("تم إرسال سؤالك بنجاح");
          }
          if (currentState.isError()) {
            ToastManager.error("عذراً، فشل إرسال السؤال");
          }
        },
        child: Form(
          key: formKey,
          child: Padding(
            padding: EdgeInsets.all(AppDimens.paddingMD.w),
            child: Column(
              children: [
                // حقول البيانات المدخلة هنا
                const Spacer(),
                BlockBuilderWidget<SpecialQuestionCubit, SpecialQuestionApiType>(
                  types: const [SpecialQuestionApiType.addSpecialQuestion],
                  body: (currentApi) => buildAddQuestionButton(),
                  error: (currentApi) => buildAddQuestionButton(),
                  loading: (loading) => const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildAddQuestionButton() {
    return CustomButton(
      AppStringsLanguage.send.trans(), 
      clr: AppColors.colorSecondPrimary, 
      onTap: () {
        AppLogger.log('AppString.initialIndexQuestionMain ${AppString.initialIndexQuestionMain}');
        
        // 1. التحقق من اتصال الإنترنت أولاً
        NetworkCheckerCubit.get(context).checkInternetConnectionAction(
          context: context,
          onActionWithInterNet: () async {
            // 2. التحقق من صحة المدخلات (Form Validation)
            if (formKey.currentState!.validate()) {
              final vm = widget.appointmentDataViewModel;
              
              // 3. التحقق من وجود ملفات أو مرفقات لرفعها
              final bool showProgress = vm.hasLocalUploads || 
                  (vm.addAppointmentByPatientModel?.attachmentSpecialQuestion != null);

              if (showProgress) {
                vm.resetAllUploadControllers();
                showUploadFilesDialog(context: context, controller: vm.mainUploadProgress);
              }

              try {
                // 4. تنفيذ الطلب الفعلي من الـ API
                await vm.onTapAddOrEditAppointment(
                  context,
                  isCompleteScreenStatement: true,
                  appointmentId: vm.appointmentId,
                  onSendProgress: showProgress ? vm.dispatchUploadProgress : null,
                );
                if (showProgress) vm.completeAllUploadControllers();
              } finally {
                // 5. ضمان إغلاق شاشة الرفع مهما كانت النتيجة
                if (showProgress) {
                  closeUploadFilesDialog(context);
                }
                if (mounted) setState(() {});
              }
            }
          },
        );
      },
    );
  }
}
```

---

## 6. ملفات الـ Core والـ Boilerplate البرمجية بالكامل

انسخ هذه الملفات مباشرة لتأسيس أي مشروع جديد بالبنية الصحيحة:

### 6.1. Base ViewModel (`lib/core/base/base_view_model.dart`)
```dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

abstract class BaseViewModel extends ChangeNotifier {
  void Function()? reLoad;

  BaseViewModel([this.reLoad]);

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

### 6.2. Base Cubit (`lib/modules/shared/cubit/bse_cubit.dart`)
```dart
import 'package:bloc/bloc.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import '../../../core/common/error_handler/failure.dart';
import 'responses/base_pagination_response.dart';

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

  BasePaginationResponse paginationOf(StatesEnum state) => 
      _paginationMap[state] ?? BasePaginationResponse();

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
    if (paginationMethod == PaginationMethod.loadMore && 
        paginationInfo.currentPage >= paginationInfo.lastPage) return;

    if (paginationMethod == PaginationMethod.refresh) fire(type, StateType.loading);
    if (paginationMethod == PaginationMethod.loadMore) fire(type, StateType.loadMore);

    int nextPage = paginationMethod == PaginationMethod.refresh ? 1 : paginationInfo.currentPage + 1;
    var res = await fun(nextPage);

    return res.fold(
      (l) {
        l.printInfo("fastPagination<$T>");
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

### 6.3. Block Builder Widget (`lib/modules/shared/cubit/block_builder_widget.dart`)
```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'bse_cubit.dart';

class BlockBuilderWidget<Cubit extends BaseCubit<S>, S> extends StatelessWidget {
  final List<S> types;
  final Widget Function(S currentApi) body;
  final Widget Function(S currentApi)? loading;
  final Widget Function(S currentApi)? error;
  final Widget Function(S currentApi)? fetchMore;

  const BlockBuilderWidget({
    super.key, 
    required this.body, 
    this.loading, 
    this.error, 
    required this.types, 
    this.fetchMore,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<Cubit, BaseState>(
      buildWhen: (p, c) => types.contains(c.type),
      builder: (context, state) {
        BaseCubit cubit = context.read<Cubit>();
        var currentState = cubit.stateOf(state.type);
        if (currentState.isDone()) return body(state.type);
        if (currentState.isLoading()) {
          return loading != null ? loading!(state.type) : const Center(child: CircularProgressIndicator());
        }
        if (currentState.isError()) return error != null ? error!(state.type) : const SizedBox();
        if (currentState.isPaginationLoadMore()) {
          return fetchMore != null ? fetchMore!(state.type) : body(state.type);
        }
        return const SizedBox();
      },
    );
  }
}
```

### 6.4. Failure & error handler (`lib/core/common/error_handler/failure.dart`)
```dart
import 'app_logger.dart';

class Failure {
  int code;
  String message;
  TypeMsg type;

  Failure(this.code, this.message, this.type);

  @override
  String toString() => 'Failure{code: $code, message: $message, type: $type}';

  void printInfo(String from) {
    AppLogger.log('from => $from : Failure{code: $code, message: $message, type: $type}');
  }
}

enum TypeMsg { ok, error, warning }
```

### 6.5. App Logger (`lib/core/common/error_handler/app_logger.dart`)
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
}
```

### 6.6. Base Pagination Response (`lib/modules/shared/cubit/responses/base_pagination_response.dart`)
```dart
class BasePaginationResponse {
  late int currentPage;
  late int from;
  late int lastPage;
  late int perPage;
  late int to;
  late int total;

  BasePaginationResponse({
    this.currentPage = 0, 
    this.from = 0, 
    this.lastPage = 1, 
    this.perPage = 0, 
    this.to = 0, 
    this.total = 0,
  });

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

---

## 7. تسجيل التبعيات (Service Locator DI)

يتم استخدام `GetIt` لتسجيل الكلاسات كالتالي:
```dart
// lib/core/di/service_locator.dart
import 'package:get_it/get_it.dart';

final sl = GetIt.instance;

Future<void> initServiceLocator() async {
  // 1. Repositories
  sl.registerLazySingleton<SpecialQuestionRepo>(() => SpecialQuestionImp());

  // 2. Cubits (Factory)
  sl.registerFactory(() => SpecialQuestionCubit(sl()));

  // 3. ViewModels (Factory)
  sl.registerFactory(() => SpecialQuestionViewModel(null, sl()));
}
```

---

## 8. بوابة الجودة وقائمة التحقق قبل التسليم (Pre-Delivery Quality Checklist)

- [ ] الـ Cubit يرث من `BaseCubit<FeatureApiType>` مع استخدام Enum واحد لكل عملية API.
- [ ] خلو الـ Cubit تماماً من `BuildContext` أو `navigatorKey` أو دوال static `get()`.
- [ ] حقن الـ Repository داخل الـ Cubit عبر الـ Constructor (ممنوع إنشاؤه يدوياً).
- [ ] ميثود الـ `dispose` بالـ ViewModel تقوم بإغلاق الـ Cubit واستدعاء `super.dispose()` لإلغاء الـ `CancelToken`.
- [ ] شاشات الـ GET: استخدام الـ `fastPagination` وتغليف الشاشة بالكامل بـ `BlockBuilderWidget`.
- [ ] شاشات الـ POST: تغليف **زر الإرسال فقط** بالـ `BlockBuilderWidget` واستخدام `BlocListener` للـ Navigation والتوستات.
- [ ] شاشات الـ POST التي تحتوي على رفع ملفات: إظهار دايلوج تقدم الرفع وتمرير `onSendProgress` وإغلاقه دائماً بداخل بلوك `finally`.
- [ ] استخدام الـ `NetworkCheckerCubit` قبل أي عملية إرسال بيانات (POST) للتحقق من سلامة الاتصال.
- [ ] الـ `setState` لا يتم استدعاؤها إلا بعد التحقق من أن الشاشة ما زالت موجودة `if (mounted)`.
- [ ] الكونسراكتور للشاشات بدون باراميترز معرف بـ `const Screen({super.key})`.
- [ ] تجنب القيم المعرفة مباشرة (Hardcoded): استخدام كلاسات `AppStrings` و `AppColors` و `AppDimens` حصراً.
