// This file is conditionally imported for Flutter Web only.
// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

import 'package:cross_file/cross_file.dart';

Future<XFile?> pickProductImage() async {
  final input = html.FileUploadInputElement()
    ..accept = 'image/jpeg,image/png,image/webp'
    ..multiple = false;

  final completer = Completer<XFile?>();
  input.onChange.first
      .then((_) async {
        final file = input.files?.firstOrNull;
        if (file == null) {
          completer.complete(null);
          return;
        }

        final reader = html.FileReader()..readAsDataUrl(file);
        await reader.onLoad.first;
        final result = reader.result;
        if (result is! String) {
          completer.completeError(
            const FormatException('Browser tidak dapat membaca file gambar.'),
          );
          return;
        }
        final separator = result.indexOf(',');
        if (separator < 0) {
          completer.completeError(
            const FormatException(
              'Format data gambar dari browser tidak valid.',
            ),
          );
          return;
        }
        final bytes = base64.decode(result.substring(separator + 1));

        completer.complete(
          XFile.fromData(bytes, name: file.name, mimeType: file.type),
        );
      })
      .catchError((Object error) {
        if (!completer.isCompleted) completer.completeError(error);
      });

  input.click();
  return completer.future;
}
