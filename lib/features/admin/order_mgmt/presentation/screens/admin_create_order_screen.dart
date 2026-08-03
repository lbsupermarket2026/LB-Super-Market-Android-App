import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../order_requests/presentation/screens/type_list_screen.dart' show kListUnits;
import '../providers/admin_order_providers.dart';
import '../../../../../core/theme/app_semantic_colors.dart';

const _green = Color(0xFF2E7D32);

class _LineControllers {
  final name = TextEditingController();
  final price = TextEditingController();
  final qty = TextEditingController(text: '1');
  String unit = kListUnits.first;
}

/// For orders admin enters directly — e.g. a customer who called or
/// messaged on WhatsApp instead of ordering through the app. Same
/// item/qty/unit/price pattern as Type My List and Convert to Order,
/// for consistency across every place someone manually enters items.
class AdminCreateOrderScreen extends ConsumerStatefulWidget {
  const AdminCreateOrderScreen({super.key});

  @override
  ConsumerState<AdminCreateOrderScreen> createState() => _AdminCreateOrderScreenState();
}

class _AdminCreateOrderScreenState extends ConsumerState<AdminCreateOrderScreen> {
  final _customerName = TextEditingController();
  final _customerPhone = TextEditingController();
  final _address = TextEditingController();
  final List<_LineControllers> _lines = [_LineControllers()];

  @override
  void dispose() {
    _customerName.dispose();
    _customerPhone.dispose();
    _address.dispose();
    for (final l in _lines) {
      l.name.dispose();
      l.price.dispose();
      l.qty.dispose();
    }
    super.dispose();
  }

  double get _total {
    return _lines.fold<double>(0, (sum, l) {
      final price = double.tryParse(l.price.text) ?? 0;
      final qty = int.tryParse(l.qty.text) ?? 0;
      return sum + (price * qty);
    });
  }

  Future<void> _submit() async {
    if (_customerName.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter the customer\'s name.')));
      return;
    }
    if (_address.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a delivery/pickup address.')));
      return;
    }
    final items = _lines
        .where((l) => l.name.text.trim().isNotEmpty)
        .map((l) => {
              'productId': '',
              'name': l.name.text.trim(),
              'unit': l.unit,
              'imageUrl': '',
              'price': double.tryParse(l.price.text) ?? 0,
              'quantity': int.tryParse(l.qty.text) ?? 1,
            })
        .toList();
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add at least one item.')));
      return;
    }

    final success = await ref.read(adminOrderMutationProvider.notifier).createManualOrder(
          items: items,
          totalAmount: _total,
          deliveryAddress: _address.text.trim(),
          customerName: _customerName.text.trim(),
          customerPhone: _customerPhone.text.trim().isEmpty ? null : _customerPhone.text.trim(),
        );

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order created.')));
      Navigator.pop(context);
    } else {
      final error = ref.read(adminOrderMutationProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not create order: ${error ?? 'unknown error'}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminOrderMutationProvider);

    // FIXED: these fields had no explicit text color/fill, so they
    // relied entirely on theme inheritance for contrast. Now explicit
    // via context.appColors so "Name" (and the others) is guaranteed
    // readable regardless of any theme edge case — dark fill + light
    // text in dark mode, light fill + dark text in light mode.
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(title: const Text('Create Order')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text('Customer', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: colors.ink)),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _customerName,
            style: TextStyle(color: colors.ink),
            decoration: InputDecoration(labelText: 'Name', fillColor: colors.card, labelStyle: TextStyle(color: colors.muted)),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _customerPhone,
            keyboardType: TextInputType.phone,
            style: TextStyle(color: colors.ink),
            decoration: InputDecoration(labelText: 'Phone (optional)', fillColor: colors.card, labelStyle: TextStyle(color: colors.muted)),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _address,
            maxLines: 2,
            style: TextStyle(color: colors.ink),
            decoration: InputDecoration(labelText: 'Delivery / Pickup Address', fillColor: colors.card, labelStyle: TextStyle(color: colors.muted)),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text('Items', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: AppSpacing.sm),
          ..._lines.asMap().entries.map((entry) {
            final index = entry.key;
            final row = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: row.name,
                          decoration: InputDecoration(labelText: 'Item ${index + 1}', isDense: true),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      if (_lines.length > 1)
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => setState(() => _lines.removeAt(index)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: row.qty,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$'))],
                          decoration: const InputDecoration(labelText: 'Qty', isDense: true),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          value: row.unit,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Unit', isDense: true),
                          items: kListUnits.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                          onChanged: (v) => setState(() => row.unit = v ?? row.unit),
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
                ],
              ),
            );
          }),
          OutlinedButton.icon(
            onPressed: () => setState(() => _lines.add(_LineControllers())),
            icon: const Icon(Icons.add),
            label: const Text('Add Item'),
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: _green.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total', style: TextStyle(fontWeight: FontWeight.w700)),
                Text('₹${_total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: _green)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: state.isSubmitting ? null : _submit,
              child: state.isSubmitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Create Order'),
            ),
          ),
        ],
      ),
    );
  }
}
