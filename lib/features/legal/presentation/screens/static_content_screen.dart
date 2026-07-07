import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/states/error_state.dart';

class StaticContentScreen extends ConsumerWidget {
  final String title;
  final FutureProvider<String> provider;

  const StaticContentScreen({super.key, required this.title, required this.provider});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentAsync = ref.watch(provider);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: contentAsync.when(
        data: (content) => SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(content, style: Theme.of(context).textTheme.bodyMedium),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorStateWidget(
          message: 'Could not load $title.',
          onRetry: () => ref.invalidate(provider),
        ),
      ),
    );
  }
}