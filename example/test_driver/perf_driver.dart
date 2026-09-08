import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() {
  return integrationDriver(
    responseDataCallback: (Map<String, dynamic>? data) async {
      if (data == null) return;
      final Directory out = Directory('build/perf');
      await out.create(recursive: true);
      for (final MapEntry<String, dynamic> entry in data.entries) {
        final File file = File('${out.path}/${entry.key}.json');
        await file.writeAsString(
          const JsonEncoder.withIndent('  ').convert(entry.value),
        );
      }
    },
  );
}
