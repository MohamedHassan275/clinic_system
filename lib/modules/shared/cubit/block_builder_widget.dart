import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'base_cubit.dart';

class BlockBuilderWidget<CubitClass extends BaseCubit<S>, S> extends StatelessWidget {
  final List<S> types;
  final Widget Function(S currentApi) body;
  final Widget Function(S currentApi)? loading;
  final Widget Function(S currentApi)? error;
  final Widget Function(S currentApi)? fetchMore;
  final VoidCallback? onRetry;

  const BlockBuilderWidget({
    super.key,
    required this.body,
    this.loading,
    this.error,
    required this.types,
    this.fetchMore,
    this.onRetry,
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
          final errorMsg = cubit.errorMessageOf(activeType) ?? 'حدث خطأ في تحميل البيانات';
          return error != null
              ? error!(activeType)
              : Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 44),
                        const SizedBox(height: 10),
                        Text(
                          errorMsg,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          onPressed: () async {
                            if (onRetry != null) {
                              onRetry!();
                            } else {
                              for (var t in types) {
                                if (cubit.stateOf(t).isError()) {
                                  await cubit.retry(t);
                                }
                              }
                            }
                          },
                          label: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
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
