import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'empty_state.dart';

/// Renders an AsyncValue with consistent loading / error / data states.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({super.key, required this.value, required this.data, this.onRetry, this.loading});
  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;

  /// Optional loading placeholder. List screens pass a [SkeletonList] so the
  /// page keeps its shape; defaults to a centered spinner for detail screens.
  final Widget? loading;

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => loading ?? const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline,
        title: 'Something went wrong',
        message: e.toString(),
        actionLabel: onRetry != null ? 'Retry' : null,
        onAction: onRetry,
      ),
      data: data,
    );
  }
}
