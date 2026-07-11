import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../order_requests/domain/entities/order_request_entity.dart';
import '../providers/admin_order_providers.dart';

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

    return AlertDialog(
      title: const Text('Confirm Final Order'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter the final priced items after calling the customer.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
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
                          decoration: const InputDecoration(labelText: 'Item', isDense: true),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: row.qty,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Qty', isDense: true),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: row.price,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Price', isDense: true),
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
                  const Text('Total', style: TextStyle(fontWeight: FontWeight.w800)),
                  Text('₹${_total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w800)),
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
