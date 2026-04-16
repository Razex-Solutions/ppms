import 'dart:typed_data';

import 'file_download_stub.dart'
    if (dart.library.html) 'file_download_web.dart'
    if (dart.library.io) 'file_download_io.dart';

Future<String?> saveDownload({
  required String fileName,
  required Uint8List bytes,
  required String contentType,
}) {
  return saveDownloadImpl(
    fileName: fileName,
    bytes: bytes,
    contentType: contentType,
  );
}
