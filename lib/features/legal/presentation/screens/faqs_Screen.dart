import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/states/empty_state.dart';
import '../../../../core/widgets/states/error_state.dart';
import '../providers/legal_providers.dart';

class FaqsScreen extends ConsumerWidget {
  const FaqsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final faqsAsync = ref.watch(faqsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('FAQs')),
      body: faqsAsync.when(
        data: (faqs) => faqs.isEmpty
            ? const EmptyStateWidget(message: 'No FAQs available yet.', icon: Icons.help_outline)
            : ListView.separated(
                itemCount: faqs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final faq = faqs[index];
                  return ExpansionTile(
                    title: Text(faq.question, style: Theme.of(context).textTheme.titleMedium),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    expandedAlignment: Alignment.centerLeft,
                    children: [
                      Text(faq.answer, style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorStateWidget(
          message: 'Could not load FAQs.',
          onRetry: () => ref.invalidate(faqsProvider),
        ),
      ),
    );
  }
}