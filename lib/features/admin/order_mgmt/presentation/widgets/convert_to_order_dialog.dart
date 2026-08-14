import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../order_requests/domain/entities/order_request_entity.dart';
import '../providers/admin_order_providers.dart';
import '../../../../../core/theme/app_semantic_colors.dart';

const _green = Color(0xFF2E7D32);

class _LineControllers {
  final name = TextEditingController();
  final price = TextEditingController();
  final qty = TextEditingController(text: '1');
}

class ConvertToOrderDialog extends ConsumerStatefulWidget {
  final OrderRequestEntity request;
  const ConvertToOrderDialog({super.key, required this.request});

  @override
  ConsumerState<ConvertToOrderDialog> createState() => _ConvertToOrderDialogState();
}

class _ConvertToOrderDialogState extends ConsumerState<ConvertToOrderDialog> {
  final List<_LineControllers> _lines = [];

  @override
  void initState() {
    super.initState();
    if (widget.request.itemLines.isNotEmpty) {
      for (final line in widget.request.itemLines) {
        final row = _LineControllers();
        final parts = line.split(' - ');
        row.name.text = parts.isNotEmpty ? parts[0] : line;
        _lines.add(row);
      }
    } else {
      _lines.add(_LineControllers());
    }
  }

  double get _total => _lines.fold(0.0, (sum, l) {
        final price = double.tryParse(l.price.text) ?? 0;
        final qty = int.tryParse(l.qty.text) ?? 1;
        return sum + (price * qty);
      });

  Future<void> _submit() async {
    final items = _lines
        .where((l) => l.name.text.trim().isNotEmpty)
        .map((l) => {
              'productId': '',
              'name': l.name.text.trim(),
              'unit': '',
              'imageUrl': '',
              'price': double.tryParse(l.price.text) ?? 0,
              'quantity': int.tryParse(l.qty.text) ?? 1,
            })
        .toList();

    if (items.isEmpty) return;

    final orderId = await ref.read(adminOrderMutationProvider.notifier).convertRequestToOrder(
          request: widget.request,
          items: items,
          totalAmount: _total,
        );

    if (!mounted) return;
    if (orderId != null) Navigator.pop(context, orderId);
  }

  @override
  Widget build(BuildContext context) {
    final mutation = ref.watch(adminOrderMutationProvider);
    final colors = context.appColors;

    // FIXED: same bug as the Place Order dialog — no explicit
    // backgroundColor plus several Text widgets with no color at all,
    // meaning the pre-filled item text (the customer's original typed
    // list, before admin edits it) was going invisible in dark mode.
    return AlertDialog(
      backgroundColor: colors.card,
      title: Text('Confirm Final Order', style: TextStyle(color: colors.ink)),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter the final priced items after calling the customer.',
                style: TextStyle(fontSize: 12, color: colors.muted),
              ),
              if (mutation.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(mutation.error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                ),
              const SizedBox(height: 12),
              ..._lines.asMap().entries.map((entry) {
                final row = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: row.name,
                          style: TextStyle(color: colors.ink),
                          decoration: InputDecoration(labelText: 'Item', labelStyle: TextStyle(color: colors.muted), isDense: true),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: row.qty,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: colors.ink),
                          decoration: InputDecoration(labelText: 'Qty', labelStyle: TextStyle(color: colors.muted), isDense: true),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: row.price,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: colors.ink),
                          decoration: InputDecoration(labelText: 'Price', labelStyle: TextStyle(color: colors.muted), isDense: true),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              TextButton.icon(
                onPressed: () => setState(() => _lines.add(_LineControllers())),
                icon: const Icon(Icons.add),
                label: const Text('Add Item'),
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total', style: TextStyle(fontWeight: FontWeight.w800, color: colors.ink)),
                  Text('₹${_total.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.w800, color: colors.ink)),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: _green, foregroundColor: Colors.white),
          onPressed: mutation.isSubmitting ? null : _submit,
          child: mutation.isSubmitting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Create Order'),
        ),
      ],
    );
  }
}
