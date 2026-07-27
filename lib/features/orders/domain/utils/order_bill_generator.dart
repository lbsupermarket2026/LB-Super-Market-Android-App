import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../categories/domain/entities/category_entity.dart';
import '../../../admin/delivery_settings/domain/entities/delivery_settings_entity.dart';
import '../../../business_info/domain/entities/business_info_entity.dart';
import '../entities/order_entity.dart';

/// Builds a tax-invoice-style PDF for a single order — modeled on the
/// store's existing physical till receipt, with Order ID and Customer
/// ID added (the physical receipt has neither, since it's for walk-in
/// customers rather than app orders).
///
/// Sized for an 80mm thermal receipt roll (the common width for POS
/// receipt printers) rather than A4 — width is fixed, height grows
/// with content, same as an actual till receipt spooling out.
class OrderBillGenerator {
  static const _rollWidth = 80.0 * PdfPageFormat.mm;

  static Future<Uint8List> build({
    required OrderEntity order,
    required String customerCode,
    required BusinessInfoEntity businessInfo,
    required DeliverySettingsEntity deliverySettings,
    required Map<String, CategoryEntity> categoriesById,
  }) async {
    final doc = pw.Document();

    // Each item's GST comes from its own category, same logic as the
    // checkout calculator — a bill with items from two different GST
    // rates shows each at its own rate, not one blended figure.
    double totalGst = 0;
    for (final item in order.items) {
      final category = item.categoryId != null ? categoriesById[item.categoryId] : null;
      final gstPercent = category?.gstPercent ?? 0;
      totalGst += item.lineTotal * gstPercent / 100;
    }
    final basicTotal = order.items.fold(0.0, (sum, i) => sum + i.lineTotal) - totalGst;
    // Standard Indian intra-state GST display — CGST and SGST are each
    // half the total rate.
    final cgst = totalGst / 2;
    final sgst = totalGst / 2;

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(_rollWidth, double.infinity, marginAll: 8 * PdfPageFormat.mm),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Center(child: pw.Text('LB SUPER MARKET', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold))),
              if (businessInfo.physicalAddress?.isNotEmpty == true)
                pw.Center(
                  child: pw.Text(businessInfo.physicalAddress!, style: const pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.center),
                ),
              if (businessInfo.contactPhone?.isNotEmpty == true)
                pw.Center(child: pw.Text('Ph: ${businessInfo.contactPhone}', style: const pw.TextStyle(fontSize: 7))),
              if (deliverySettings.gstNumber.isNotEmpty)
                pw.Center(child: pw.Text('GST: ${deliverySettings.gstNumber}', style: const pw.TextStyle(fontSize: 7))),
              pw.SizedBox(height: 4),
              pw.Center(child: pw.Text('-- TAX INVOICE --', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
              pw.SizedBox(height: 4),
              _dashedDivider(),

              pw.Text('Order ID: ${order.orderNumber ?? order.id}', style: const pw.TextStyle(fontSize: 7)),
              pw.Text('Customer ID: $customerCode', style: const pw.TextStyle(fontSize: 7)),
              pw.Text('Date: ${_formatDate(order.createdAt)}', style: const pw.TextStyle(fontSize: 7)),
              pw.Text('Payment: ${order.paymentMethod.label}', style: const pw.TextStyle(fontSize: 7)),
              pw.SizedBox(height: 4),
              _dashedDivider(),

              // Each item gets two compact lines rather than a wide
              // table — a 5-column table doesn't fit legibly on an
              // 80mm roll the way it does on A4.
              ...order.items.expand((item) {
                final category = item.categoryId != null ? categoriesById[item.categoryId] : null;
                final gstPercent = category?.gstPercent ?? 0;
                return [
                  pw.Text(item.name, style: const pw.TextStyle(fontSize: 8)),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        '${item.quantity} x ${item.price.toStringAsFixed(2)} (GST ${gstPercent.toStringAsFixed(0)}%)',
                        style: const pw.TextStyle(fontSize: 7),
                      ),
                      pw.Text(item.lineTotal.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                  pw.SizedBox(height: 2),
                ];
              }),
              _dashedDivider(),

              _summaryRow('Basic Amount', basicTotal.toStringAsFixed(2)),
              _summaryRow('CGST', cgst.toStringAsFixed(2)),
              _summaryRow('SGST', sgst.toStringAsFixed(2)),
              _dashedDivider(),
              _summaryRow('TOTAL', order.totalAmount.toStringAsFixed(2), bold: true),
              pw.SizedBox(height: 8),

              _dashedDivider(),
              pw.SizedBox(height: 4),
              pw.Center(child: pw.Text('YOUR BEST BUDGET STORE', style: const pw.TextStyle(fontSize: 7))),
              pw.Center(child: pw.Text('THANK YOU, VISIT AGAIN', style: const pw.TextStyle(fontSize: 7))),
              pw.SizedBox(height: 8),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  static pw.Widget _dashedDivider() {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Text('--------------------------------', style: const pw.TextStyle(fontSize: 7)),
    );
  }

  static pw.Widget _summaryRow(String label, String value, {bool bold = false}) {
    final style = pw.TextStyle(fontSize: bold ? 10 : 8, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal);
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [pw.Text(label, style: style), pw.Text('Rs. $value', style: style)],
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}-${months[dt.month - 1]}-${dt.year} $hour12:$minute $ampm';
  }
}
