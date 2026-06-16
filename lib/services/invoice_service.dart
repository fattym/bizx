import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

import '../models/order_item_model.dart';
import '../models/order_model.dart';

class InvoiceService {
  Future<String> generateInvoiceFile({
    required OrderModel order,
    required List<OrderItemModel> items,
  }) async {
    final directory = await getApplicationDocumentsDirectory();
    final invoiceDir = Directory('${directory.path}/invoices');
    if (!await invoiceDir.exists()) {
      await invoiceDir.create(recursive: true);
    }

    final safeNumber = order.orderNumber.replaceAll(
      RegExp(r'[^A-Za-z0-9_-]'),
      '_',
    );
    final file = File('${invoiceDir.path}/invoice_$safeNumber.pdf');
    final pdfBytes = await _buildInvoicePdf(order, items);
    await file.writeAsBytes(pdfBytes, flush: true);
    return file.path;
  }

  /// Generates the invoice PDF and opens the native share dialog.
  /// This allows users to send the PDF via WhatsApp, Email, etc.
  Future<void> shareInvoice({
    required OrderModel order,
    required List<OrderItemModel> items,
  }) async {
    final pdfBytes = await _buildInvoicePdf(order, items);

    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'invoice_${order.orderNumber}.pdf',
    );
  }

  Future<Uint8List> generateInvoiceBytes({
    required OrderModel order,
    required List<OrderItemModel> items,
  }) {
    return _buildInvoicePdf(order, items);
  }

  Future<Uint8List> _buildInvoicePdf(
    OrderModel order,
    List<OrderItemModel> items,
  ) async {
    final pdf = pw.Document();
    final logo = await _loadLogo();
    final issuedAt = order.submittedAt ?? DateTime.now();

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          theme: pw.ThemeData.withFont(
            base: pw.Font.helvetica(),
            bold: pw.Font.helveticaBold(),
          ),
        ),
        build: (context) {
          return [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Row(
                  children: [
                    if (logo != null)
                      pw.Container(
                        width: 64,
                        height: 64,
                        margin: const pw.EdgeInsets.only(right: 14),
                        child: pw.Image(logo, fit: pw.BoxFit.contain),
                      ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Longhorn Publishers PLC',
                          style: pw.TextStyle(
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromInt(0xFF80AC4A),
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Sales Invoice',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text('Order fulfillment and payment record'),
                      ],
                    ),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFFEAF2E0),
                    borderRadius: pw.BorderRadius.circular(10),
                  ),
                  child: pw.Text(
                    order.status.toUpperCase(),
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromInt(0xFF5A7C32),
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 24),
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F8FCF9'),
                borderRadius: pw.BorderRadius.circular(12),
                border: pw.Border.all(color: PdfColor.fromHex('#D4DAD0')),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: _detailColumn(
                      title: 'Customer',
                      rows: [
                        _detailRow('School', order.schoolName),
                        _detailRow('Phone', order.schoolPhone ?? 'N/A'),
                        _detailRow('School ID', order.schoolId ?? 'N/A'),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 24),
                  pw.Expanded(
                    child: _detailColumn(
                      title: 'Invoice',
                      rows: [
                        _detailRow('Order No.', order.orderNumber),
                        _detailRow(
                          'Payment Method',
                          _paymentLabel(order.paymentMethod),
                        ),
                        _detailRow(
                          'Payment Reference',
                          order.paymentReference ?? 'N/A',
                        ),
                        _detailRow('Issued At', _formatDateTime(issuedAt)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'Order Items',
              style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            pw.TableHelper.fromTextArray(
              headerDecoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#EAF2E0'),
              ),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#2C3325'),
              ),
              cellStyle: const pw.TextStyle(fontSize: 10),
              cellAlignment: pw.Alignment.centerLeft,
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1.2),
                2: const pw.FlexColumnWidth(1.3),
                3: const pw.FlexColumnWidth(1.2),
              },
              headers: const ['Item', 'Qty', 'Unit Price', 'Line Total'],
              data:
                  items.map((item) {
                    return [
                      item.productName,
                      item.quantity.toString(),
                      'KES ${item.unitPrice.toStringAsFixed(2)}',
                      'KES ${item.lineTotal.toStringAsFixed(2)}',
                    ];
                  }).toList(),
            ),
            pw.SizedBox(height: 18),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Container(
                width: 220,
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F8FCF9'),
                  borderRadius: pw.BorderRadius.circular(12),
                  border: pw.Border.all(color: PdfColor.fromHex('#D4DAD0')),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _summaryRow('Items', items.length.toString()),
                    pw.SizedBox(height: 6),
                    _summaryRow(
                      'Total',
                      'KES ${order.checkoutAmount.toStringAsFixed(2)}',
                      isTotal: true,
                    ),
                  ],
                ),
              ),
            ),
            if ((order.notes ?? '').trim().isNotEmpty) ...[
              pw.SizedBox(height: 20),
              pw.Text(
                'Notes',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                order.notes!.trim(),
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
            pw.SizedBox(height: 20),
            pw.Text(
              'Thank you for your business.',
              style: pw.TextStyle(
                fontSize: 11,
                fontStyle: pw.FontStyle.italic,
                color: PdfColors.grey700,
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _detailColumn({
    required String title,
    required List<pw.Widget> rows,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        ...rows,
      ],
    );
  }

  pw.Widget _detailRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 98,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
          ),
        ],
      ),
    );
  }

  pw.Widget _summaryRow(String label, String value, {bool isTotal = false}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: isTotal ? 12 : 10,
            fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: isTotal ? 12 : 10,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Future<pw.ImageProvider?> _loadLogo() async {
    try {
      final bytes = await rootBundle.load('assets/images/icons/logo.png');
      return pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (_) {
      try {
        final bytes = await rootBundle.load(
          'assets/images/icons/download-removebg-preview.png',
        );
        return pw.MemoryImage(bytes.buffer.asUint8List());
      } catch (_) {
        return null;
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year;
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }

  String _paymentLabel(String method) {
    switch (method) {
      case 'cash':
        return 'Cash';
      case 'mpesa':
        return 'M-Pesa';
      case 'bank':
        return 'Bank Transfer';
      default:
        return method;
    }
  }
}
