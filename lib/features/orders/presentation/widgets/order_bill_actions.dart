import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
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

Future<Uint8List> _buildBillBytes(WidgetRef ref, OrderEntity order) async {
  final businessInfo = await ref.read(businessInfoProvider.future);
  final deliverySettings = await ref.read(deliverySettingsProvider.future);
  final categories = await ref.read(topLevelCategoriesProvider.future);
  final customerCode = await _getCustomerCode(order.userId);

  final categoriesById = <String, CategoryEntity>{for (final c in categories) c.id: c};

  return OrderBillGenerator.build(
    order: order,
    customerCode: customerCode,
    businessInfo: businessInfo,
    deliverySettings: deliverySettings,
    categoriesById: categoriesById,
  );
}

/// Presents View / Share / Print / Download as a bottom sheet.
Future<void> generateAndShareOrderBill(BuildContext context, WidgetRef ref, OrderEntity order) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.visibility_outlined),
            title: const Text('View'),
            subtitle: const Text('Open in the app'),
            onTap: () => Navigator.pop(sheetContext, 'view'),
          ),
          ListTile(
            leading: const Icon(Icons.print_outlined),
            title: const Text('Print'),
            subtitle: const Text('Formatted for an 80mm receipt roll'),
            onTap: () => Navigator.pop(sheetContext, 'print'),
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Download'),
            subtitle: const Text('Save a copy on this device'),
            onTap: () => Navigator.pop(sheetContext, 'download'),
          ),
          ListTile(
            leading: const Icon(Icons.share_outlined),
            title: const Text('Share'),
            onTap: () => Navigator.pop(sheetContext, 'share'),
          ),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(const SnackBar(content: Text('Preparing bill…'), duration: Duration(seconds: 2)));

  try {
    final bytes = await _buildBillBytes(ref, order);
    final filename = '${order.orderNumber ?? order.id}.pdf';

    switch (choice) {
      case 'view':
        if (context.mounted) {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => _BillPreviewScreen(bytes: bytes, filename: filename)));
        }
        break;
      case 'print':
        await Printing.layoutPdf(onLayout: (_) async => bytes, name: filename);
        break;
      case 'download':
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$filename');
        await file.writeAsBytes(bytes);
        if (context.mounted) {
          messenger.showSnackBar(SnackBar(content: Text('Saved as $filename')));
        }
        break;
      case 'share':
      default:
        await Printing.sharePdf(bytes: bytes, filename: filename);
        break;
    }
  } catch (e) {
    if (context.mounted) {
      messenger.showSnackBar(SnackBar(content: Text('Could not generate bill: $e')));
    }
  }
}

/// Full-screen in-app preview — PdfPreview (from the printing package,
/// already a dependency) also has its own built-in print/share buttons,
/// so this doubles as a fallback route to those even without going
/// through the bottom sheet again.
class _BillPreviewScreen extends StatelessWidget {
  final Uint8List bytes;
  final String filename;
  const _BillPreviewScreen({required this.bytes, required this.filename});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bill')),
      body: PdfPreview(
        build: (format) async => bytes,
        allowPrinting: true,
        allowSharing: true,
        canChangeOrientation: false,
        canChangePageFormat: false,
        pdfFileName: filename,
      ),
    );
  }
}