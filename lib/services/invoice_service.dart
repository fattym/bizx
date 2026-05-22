import 'dart:io';

import 'package:path_provider/path_provider.dart';

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
    final file = File('${invoiceDir.path}/invoice_$safeNumber.txt');
    await file.writeAsString(_buildInvoiceText(order, items));
    return file.path;
  }

  String _buildInvoiceText(OrderModel order, List<OrderItemModel> items) {
    final buffer = StringBuffer();
    buffer.writeln('DEHUS INVOICE');
    buffer.writeln('Order Number: ${order.orderNumber}');
    buffer.writeln('School: ${order.schoolName}');
    buffer.writeln('Phone: ${order.schoolPhone ?? 'N/A'}');
    buffer.writeln('Payment Method: ${_paymentLabel(order.paymentMethod)}');
    buffer.writeln('Payment Reference: ${order.paymentReference ?? 'N/A'}');
    buffer.writeln('Status: ${order.status.toUpperCase()}');
    buffer.writeln(
      'Submitted At: ${order.submittedAt?.toIso8601String() ?? 'N/A'}',
    );
    buffer.writeln('');
    buffer.writeln('ITEMS');
    buffer.writeln('----------------------------------------');

    for (final item in items) {
      buffer.writeln(
        '${item.productName} | ${item.quantity} x ${item.unitPrice.toStringAsFixed(2)} = ${item.lineTotal.toStringAsFixed(2)}',
      );
      if ((item.category ?? '').isNotEmpty || (item.sku ?? '').isNotEmpty) {
        buffer.writeln(
          '  ${item.category ?? 'Item'}${item.sku != null ? ' • ${item.sku}' : ''}',
        );
      }
    }

    buffer.writeln('----------------------------------------');
    buffer.writeln('Total: KES ${order.checkoutAmount.toStringAsFixed(2)}');
    if ((order.notes ?? '').isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('Notes: ${order.notes}');
    }
    return buffer.toString();
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
