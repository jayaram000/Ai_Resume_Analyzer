import 'dart:io';
import 'package:file_picker/file_picker.dart';

Future<void> downloadFileBytes(List<int> bytes, String fileName) async {
  String? outputFile = await FilePicker.platform.saveFile(
    dialogTitle: 'Save PDF Report',
    fileName: fileName,
    type: FileType.custom,
    allowedExtensions: ['pdf'],
  );
  if (outputFile != null) {
    final file = File(outputFile);
    await file.writeAsBytes(bytes);
  }
}
