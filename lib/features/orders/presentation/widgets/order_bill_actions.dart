import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../business_info/presentation/providers/business_info_providers.dart';
import '../../../admin/delivery_settings/presentation/providers/delivery_settings_providers.dart';
import '../../../categories/domain/entities/category_entity.dart';
import '../../../categories/presentation/providers/category_providers.dart';
import '../../domain/entities/order_entity.dart';
import '../../domain/utils/order_bill_generator.dart';

/// Looks up just the customerCode for a given order's customer — used
/// on the bill rather than the full user profile, since admin viewing
/// someone else's order needs THAT customer's code, not their own.
Future<String> _getCustomerCode(String userId) async {
  final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
  return (doc.data()?['customerCode'] as String?) ?? userId.substring(0, userId.length.clamp(0, 8));
}

/// Shared by both the customer's and admin's Order Detail screens —
/// gathers everything the bill needs, builds it, then opens the
/// system share/print sheet. Shows its own loading/error feedback via
/// SnackBars rather than needing the caller to manage state for it.
Future<void> generateAndShareOrderBill(BuildContext context, WidgetRef ref, OrderEntity order) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(const SnackBar(content: Text('Preparing bill…'), duration: Duration(seconds: 2)));

  try {
    final businessInfo = await ref.read(businessInfoProvider.future);
    final deliverySettings = await ref.read(deliverySettingsProvider.future);
    final categories = await ref.read(topLevelCategoriesProvider.future);
    final customerCode = await _getCustomerCode(order.userId);

    final categoriesById = <String, CategoryEntity>{for (final c in categories) c.id: c};

    final bytes = await OrderBillGenerator.build(
      order: order,
      customerCode: customerCode,
      businessInfo: businessInfo,
      deliverySettings: deliverySettings,
      categoriesById: categoriesById,
    );

    await Printing.sharePdf(bytes: bytes, filename: '${order.orderNumber ?? order.id}.pdf');
  } catch (e) {
    if (context.mounted) {
      messenger.showSnackBar(SnackBar(content: Text('Could not generate bill: $e')));
    }
  }
}
