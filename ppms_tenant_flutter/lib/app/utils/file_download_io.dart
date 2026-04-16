import 'dart:io';
import 'dart:typed_data';

Future<String?> saveDownloadImpl({
  required String fileName,
  required Uint8List bytes,
  required String contentType,
}) async {
  final targetDir = await Directory.systemTemp.createTemp('ppms_download_');
  final file = File('${targetDir.path}${Platform.pathSeparator}$fileName');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
