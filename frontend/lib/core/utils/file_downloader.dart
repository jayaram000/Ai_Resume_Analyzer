import 'package:flutter/foundation.dart';
import 'file_downloader_io.dart' if (dart.library.html) 'file_downloader_web.dart';

class FileDownloader {
  static Future<bool> download(List<int> bytes, String fileName) async {
    try {
      await downloadFileBytes(bytes, fileName);
      return true;
    } catch (e) {
      debugPrint("File download error: $e");
      return false;
    }
  }
}
