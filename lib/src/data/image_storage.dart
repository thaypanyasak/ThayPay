import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

class ImageStorage {
  const ImageStorage();

  Future<String> saveCompressedExpenseImage({
    required String sourcePath,
    required String fileNameBase,
  }) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/expense_images');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final targetPath = '${dir.path}/$fileNameBase.jpg';

    final result = await FlutterImageCompress.compressAndGetFile(
      sourcePath,
      targetPath,
      quality: 80,
      format: CompressFormat.jpeg,
    );

    if (result == null) {
      // Fallback: copy original if compression failed.
      final copied = await File(sourcePath).copy(targetPath);
      return copied.path;
    }

    return result.path;
  }
}
