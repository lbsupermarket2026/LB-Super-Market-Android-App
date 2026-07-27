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
class OrderBillGenerator {
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
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text('LB SUPER MARKET', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              if (businessInfo.physicalAddress?.isNotEmpty == true)
                pw.Text(businessInfo.physicalAddress!, style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.center),
              if (businessInfo.contactPhone?.isNotEmpty == true)
                pw.Text('Ph: ${businessInfo.contactPhone}', style: const pw.TextStyle(fontSize: 9)),
              if (deliverySettings.gstNumber.isNotEmpty)
                pw.Text('GST: ${deliverySettings.gstNumber}', style: const pw.TextStyle(fontSize: 9)),
              pw.SizedBox(height: 8),
              pw.Text('********** TAX INVOICE **********', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Divider(),

              // Order/Customer identity — the piece the physical receipt
              // doesn't have, since walk-in sales have no app account.
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Order ID: ${order.orderNumber ?? order.id}', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('Customer ID: $customerCode', style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Date: ${_formatDate(order.createdAt)}', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('Payment: ${order.paymentMethod.label}', style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Divider(),

              // Item table
              pw.Table(
                border: null,
                columnWidths: const {
                  0: pw.FlexColumnWidth(3.2),
                  1: pw.FlexColumnWidth(1),
                  2: pw.FlexColumnWidth(0.7),
                  3: pw.FlexColumnWidth(0.8),
                  4: pw.FlexColumnWidth(1.1),
                },
                children: [
                  pw.TableRow(children: [
                    _cell('Item', bold: true),
                    _cell('Rate', bold: true, align: pw.TextAlign.right),
                    _cell('Qty', bold: true, align: pw.TextAlign.center),
                    _cell('GST%', bold: true, align: pw.TextAlign.center),
                    _cell('Amount', bold: true, align: pw.TextAlign.right),
                  ]),
                  ...order.items.map((item) {
                    final category = item.categoryId != null ? categoriesById[item.categoryId] : null;
                    final gstPercent = category?.gstPercent ?? 0;
                    return pw.TableRow(children: [
                      _cell('${item.name}${item.unit.isNotEmpty ? ' (${item.unit})' : ''}'),
                      _cell(item.price.toStringAsFixed(2), align: pw.TextAlign.right),
                      _cell('${item.quantity}', align: pw.TextAlign.center),
                      _cell(gstPercent.toStringAsFixed(0), align: pw.TextAlign.center),
                      _cell(item.lineTotal.toStringAsFixed(2), align: pw.TextAlign.right),
                    ]);
                  }),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Divider(),

              // Totals
              _summaryRow('Basic Amount', basicTotal.toStringAsFixed(2)),
              _summaryRow('CGST', cgst.toStringAsFixed(2)),
              _summaryRow('SGST', sgst.toStringAsFixed(2)),
              pw.Divider(),
              _summaryRow('Total Amount', order.totalAmount.toStringAsFixed(2), bold: true),
              pw.SizedBox(height: 16),

              pw.Divider(),
              pw.SizedBox(height: 6),
              pw.Text('YOUR BEST BUDGET STORE', style: const pw.TextStyle(fontSize: 9)),
              pw.Text('THANK YOU, VISIT AGAIN', style: const pw.TextStyle(fontSize: 9)),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  static pw.Widget _cell(String text, {bool bold = false, pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(fontSize: 9, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal),
      ),
    );
  }

  static pw.Widget _summaryRow(String label, String value, {bool bold = false}) {
    final style = pw.TextStyle(fontSize: bold ? 11 : 10, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal);
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
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
