import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'base_cubit.dart';

class BlockBuilderWidget<CubitClass extends BaseCubit<S>, S> extends StatelessWidget {
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
    return BlocBuilder<CubitClass, BaseState<S>>(
      buildWhen: (p, c) => types.contains(c.type),
      builder: (context, state) {
        final CubitClass cubit = context.read<CubitClass>();
        final currentState = cubit.stateOf(state.type);

        if (currentState.isDone()) return body(state.type);
        if (currentState.isLoading()) {
          return loading != null
              ? loading!(state.type)
              : const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                );
        }
        if (currentState.isError()) {
          return error != null
              ? error!(state.type)
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 40),
                      const SizedBox(height: 8),
                      const Text('حدث خطأ في تحميل البيانات'),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {
                          // Allow retry
                        },
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                );
        }
        if (currentState.isPaginationLoadMore()) {
          return fetchMore != null ? fetchMore!(state.type) : body(state.type);
        }
        return body(state.type);
      },
    );
  }
}
