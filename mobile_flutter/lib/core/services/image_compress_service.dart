import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

/// Compresses uploaded photos to WebP (max 1080px, 72% quality)
/// so ads upload and load rapidly even on slow 3G/ADSL connections in Syria.
class ImageCompressService {
  static Future<File> compressToWebp(File file) async {
    final dir = await getTemporaryDirectory();
    final targetPath =
        '${dir.path}/baladna_${DateTime.now().millisecondsSinceEpoch}.webp';

    final XFile? result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 72,
      minWidth: 1080,
      minHeight: 1080,
      format: CompressFormat.webp,
    );

    if (result == null) return file;
    return File(result.path);
  }
}
