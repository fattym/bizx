import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<void> downloadCsvTemplate(String fileName, String content) async {
  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}/$fileName');
  await file.writeAsString(content);
}
