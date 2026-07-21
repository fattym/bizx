import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

const _downloadChannel = MethodChannel('com.example.dehus/download');

Future<void> downloadCsvTemplate(String fileName, String content) async {
  final bytes = Uint8List.fromList(content.codeUnits);

  if (Platform.isAndroid) {
    try {
      await _downloadChannel.invokeMethod<bool>('saveToDownloads', {
        'fileName': fileName,
        'bytes': bytes,
        'mimeType': 'text/csv',
      });
      return;
    } on PlatformException catch (e) {
      debugPrint('DownloadManager failed, falling back to app files: $e');
    }
  }

  final directory = Platform.isIOS
      ? await getApplicationDocumentsDirectory()
      : (await getExternalStorageDirectory()) ?? await getTemporaryDirectory();
  final file = File('${directory.path}/$fileName');
  await file.writeAsString(content);
}
