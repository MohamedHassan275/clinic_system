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
        final S activeType = types.contains(state.type) ? state.type : types.first;

        final isLoading = types.any((t) => cubit.stateOf(t).isLoading());
        final isError = !isLoading && types.any((t) => cubit.stateOf(t).isError());
        final isLoadMore = !isLoading && !isError && types.any((t) => cubit.stateOf(t).isPaginationLoadMore());

        if (isLoading) {
          return loading != null
              ? loading!(activeType)
              : const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                );
        }
        if (isError) {
          return error != null
              ? error!(activeType)
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
        if (isLoadMore) {
          return fetchMore != null ? fetchMore!(activeType) : body(activeType);
        }
        return body(activeType);
      },
    );
  }
}
