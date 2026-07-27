import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/order_entity.dart';
import '../providers/order_providers.dart';
import '../../../products/domain/entities/product_entity.dart';
import '../../../products/presentation/providers/product_providers.dart';

const _green = Color(0xFF2E7D32);
const _red = Color(0xFFE53935);

/// Editing an order is only offered (and only actually succeeds — the
/// Firestore rule enforces this independently of this UI check) while
/// status is still 'placed'. Once staff move it to 'confirmed' or
/// later, this dialog isn't shown at all — see the "Edit Order" button
/// wiring on both the customer and admin order detail screens.
class EditOrderDialog extends ConsumerStatefulWidget {
  final OrderEntity order;
  const EditOrderDialog({super.key, required this.order});

  @override
  ConsumerState<EditOrderDialog> createState() => _EditOrderDialogState();
}

class _EditOrderDialogState extends ConsumerState<EditOrderDialog> {
  late List<OrderItemEntity> _items;
  late final TextEditingController _addressController;

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.order.items);
    _addressController = TextEditingController(text: widget.order.deliveryAddress);
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  double get _total => _items.fold(0.0, (sum, i) => sum + i.lineTotal);

  void _addProduct(ProductEntity product) {
    setState(() {
      final existingIndex = _items.indexWhere((i) => i.productId == product.id);
      if (existingIndex >= 0) {
        final existing = _items[existingIndex];
        _items[existingIndex] = OrderItemEntity(
          productId: existing.productId,
          name: existing.name,
          unit: existing.unit,
          imageUrl: existing.imageUrl,
          price: existing.price,
          quantity: existing.quantity + 1,
          categoryId: existing.categoryId,
        );
      } else {
        _items.add(OrderItemEntity(
          productId: product.id,
          name: product.name,
          unit: product.unit,
          imageUrl: product.primaryImage,
          price: product.displayPrice,
          quantity: 1,
          categoryId: product.categoryId,
        ));
      }
    });
  }

  Future<void> _openAddItemSheet() async {
    final product = await showModalBottomSheet<ProductEntity>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddItemSheet(),
    );
    if (product != null) _addProduct(product);
  }

  void _setQuantity(int index, int quantity) {
    setState(() {
      if (quantity <= 0) {
        _items.removeAt(index);
      } else {
        final item = _items[index];
        _items[index] = OrderItemEntity(
          productId: item.productId,
          name: item.name,
          unit: item.unit,
          imageUrl: item.imageUrl,
          price: item.price,
          quantity: quantity,
          categoryId: item.categoryId,
        );
      }
    });
  }

  Future<void> _save() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An order needs at least one item — cancel it instead if you want it removed entirely.')),
      );
      return;
    }
    if (_addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Delivery address can\'t be empty.')));
      return;
    }

    final success = await ref.read(editOrderProvider.notifier).save(
          orderId: widget.order.id,
          items: _items
              .map((i) => {
                    'productId': i.productId,
                    'name': i.name,
                    'unit': i.unit,
                    'imageUrl': i.imageUrl,
                    'price': i.price,
                    'quantity': i.quantity,
                    'categoryId': i.categoryId,
                  })
              .toList(),
          totalAmount: _total,
          deliveryAddress: _addressController.text.trim(),
        );

    if (!mounted) return;
    if (success) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(editOrderProvider);

    return AlertDialog(
      title: const Text('Edit Order'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This order hasn\'t been confirmed yet, so items and address can still change.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(state.error!, style: const TextStyle(color: _red, fontSize: 12)),
                ),
              const SizedBox(height: 12),
              ..._items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            Text('₹${item.price.toStringAsFixed(0)} each', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, size: 20),
                        onPressed: () => _setQuantity(index, item.quantity - 1),
                      ),
                      Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, size: 20),
                        onPressed: () => _setQuantity(index, item.quantity + 1),
                      ),
                    ],
                  ),
                );
              }),
              TextButton.icon(
                onPressed: _openAddItemSheet,
                icon: const Icon(Icons.add),
                label: const Text('Add Item'),
              ),
              const Divider(),
              TextField(
                controller: _addressController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Delivery Address'),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('New Total', style: TextStyle(fontWeight: FontWeight.w700)),
                  Text('₹${_total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800, color: _green, fontSize: 16)),
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
          onPressed: state.isSubmitting ? null : _save,
          child: state.isSubmitting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Save Changes'),
        ),
      ],
    );
  }
}

/// Simple search-to-add sheet — types a query, taps a result, that
/// product gets added (or its quantity bumped, if already present) on
/// the order being edited.
class _AddItemSheet extends ConsumerStatefulWidget {
  const _AddItemSheet();

  @override
  ConsumerState<_AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends ConsumerState<_AddItemSheet> {
  final _controller = TextEditingController();
  List<ProductEntity> _results = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().length < 2) {
      setState(() => _results = []);
      return;
    }
    setState(() => _isSearching = true);
    final result = await ref.read(searchProductsUseCaseProvider).call(query.trim());
    if (!mounted) return;
    setState(() {
      _results = result.match((_) => [], (products) => products);
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _controller,
                autofocus: true,
                onChanged: _search,
                decoration: InputDecoration(
                  hintText: 'Search products to add',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            Expanded(
              child: _isSearching
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty
                      ? Center(
                          child: Text(
                            _controller.text.trim().length < 2 ? 'Type at least 2 characters to search.' : 'No products found.',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _results.length,
                          itemBuilder: (context, index) {
                            final product = _results[index];
                            return ListTile(
                              title: Text(product.name),
                              subtitle: Text('₹${product.displayPrice.toStringAsFixed(0)}${product.unit.isNotEmpty ? ' · ${product.unit}' : ''}'),
                              trailing: const Icon(Icons.add_circle_outline, color: _green),
                              onTap: () => Navigator.pop(context, product),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
