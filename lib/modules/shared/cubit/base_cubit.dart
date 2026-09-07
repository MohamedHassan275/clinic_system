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

  StateType stateOf(StatesEnum state) => _stateMap[state] ?? StateType.done;

  void fire(StatesEnum type, [StateType? stateType]) {
    if (stateType != null) _stateMap[type] = stateType;
    emit(BaseState(type));
  }

  Future<Either<Failure, T>> fastFire<T>({
    required StatesEnum type,
    required Future<Either<Failure, T>> Function() fun,
    Function(Failure r)? onFailure,
    required Function(T l) onSuccess,
  }) async {
    fire(type, StateType.loading);
    final res = await fun();
    return res.fold(
      (l) {
        l.printInfo('fastFire<$T>');
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
