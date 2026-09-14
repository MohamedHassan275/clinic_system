import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dartz/dartz.dart';
import '../../../core/common/error_handler/failure.dart';

enum StateType { loading, done, successfully, error, loadMore }

enum PaginationMethod { refresh, loadMore }

class BaseCubit<StatesEnum> extends Cubit<BaseState<StatesEnum>> {
  BaseCubit(StatesEnum currentState) : super(BaseState(currentState)) {
    init();
  }

  void init() {}

  final Map<StatesEnum, StateType> _stateMap = {};
  final Map<StatesEnum, String?> _errorMap = {};
  final Map<StatesEnum, Future<void> Function()> _retryMap = {};

  StateType stateOf(StatesEnum state) => _stateMap[state] ?? StateType.done;
  String? errorMessageOf(StatesEnum state) => _errorMap[state];

  void fire(StatesEnum type, [StateType? stateType, String? errorMessage]) {
    if (stateType != null) _stateMap[type] = stateType;
    if (errorMessage != null) {
      _errorMap[type] = errorMessage;
    } else if (stateType != StateType.error) {
      _errorMap[type] = null;
    }
    emit(BaseState(type));
  }

  Future<void> retry(StatesEnum type) async {
    final retryAction = _retryMap[type];
    if (retryAction != null) {
      await retryAction();
    }
  }

  Future<Either<Failure, T>> fastFire<T>({
    required StatesEnum type,
    required Future<Either<Failure, T>> Function() fun,
    Function(Failure r)? onFailure,
    required Function(T l) onSuccess,
  }) async {
    _retryMap[type] = () async {
      await fastFire<T>(
        type: type,
        fun: fun,
        onFailure: onFailure,
        onSuccess: onSuccess,
      );
    };

    fire(type, StateType.loading);
    final res = await fun();
    return res.fold(
      (l) {
        l.printInfo('fastFire<$T>');
        if (onFailure != null) onFailure(l);
        fire(type, StateType.error, l.message);
        return left(l);
      },
      (r) {
        onSuccess(r);
        fire(type, StateType.done);
        return right(r);
      },
    );
  }
}

class BaseState<StatesEnum> {
  final StatesEnum type;
  BaseState(this.type);
}

extension StateTypeEX on StateType {
  bool isLoading() => this == StateType.loading;
  bool isSuccessfully() => this == StateType.successfully;
  bool isDone() => this == StateType.done;
  bool isError() => this == StateType.error;
  bool isPaginationLoadMore() => this == StateType.loadMore;
}
