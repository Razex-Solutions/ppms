import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';

Future<String> writeBytesToLocalDocumentFile(
  String fileName,
  List<int> bytes, {
  bool promptForLocation = true,
}) async {
  final suggestedPath = await _resolveSavePath(
    fileName,
    promptForLocation: promptForLocation,
  );
  final file = File(suggestedPath);
  final directory = file.parent;
  if (!directory.existsSync()) {
    directory.createSync(recursive: true);
  }
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

Future<String> writeTextToLocalDocumentFile(
  String fileName,
  String text, {
  bool promptForLocation = true,
}) async {
  return writeBytesToLocalDocumentFile(
    fileName,
    utf8.encode(text),
    promptForLocation: promptForLocation,
  );
}

Future<OpenResult> openSavedDocument(String path) {
  return OpenFilex.open(path);
}

Future<String> _resolveSavePath(
  String fileName, {
  required bool promptForLocation,
}) async {
  if (!promptForLocation) {
    return _fallbackTempPath(fileName);
  }
  if (kIsWeb) {
    return _fallbackTempPath(fileName);
  }

  try {
    final extension = _normalizedExtension(fileName);
    final location = await getSaveLocation(
      suggestedName: fileName,
      acceptedTypeGroups: [
        XTypeGroup(
          label: extension.isEmpty ? 'Document' : extension.toUpperCase(),
          extensions: extension.isEmpty ? null : [extension],
        ),
      ],
    );
    if (location == null) {
      return _fallbackTempPath(fileName);
    }
    return location.path;
  } catch (_) {
    return _fallbackTempPath(fileName);
  }
}

String _fallbackTempPath(String fileName) {
  final directory = Directory('${Directory.systemTemp.path}\\ppms_documents');
  if (!directory.existsSync()) {
    directory.createSync(recursive: true);
  }
  return '${directory.path}\\$fileName';
}

String _normalizedExtension(String fileName) {
  final dotIndex = fileName.lastIndexOf('.');
  if (dotIndex == -1 || dotIndex == fileName.length - 1) {
    return '';
  }
  return fileName.substring(dotIndex + 1).toLowerCase();
}
