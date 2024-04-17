import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:carousel_image_editor/custom_image_editor.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class ImageItem {
  int width = 300;
  int height = 300;
  Uint8List bytes = Uint8List.fromList([]);
  Completer loader = Completer();

  ImageItem([dynamic img]) {
    if (img != null) {
      load(img);
    }
  }
  Future<ImageItem> load(dynamic imageFile) async {
    loader = Completer();

    if (imageFile is ImageItem) {
      height = imageFile.height;
      width = imageFile.width;

      bytes = imageFile.bytes;
      loader.complete(true);
    } else {
      bytes = imageFile;
      var decodedImage = await decodeImageFromList(bytes);

      double maxWidth = viewportSize.width;
      double maxHeight = 400;

      double aspectRatio = decodedImage.width / decodedImage.height;

      if (decodedImage.width > maxWidth || decodedImage.height > maxHeight) {
        if (decodedImage.height > maxHeight) {
          maxHeight = decodedImage.height.toDouble() - maxWidth;
        }
        if (aspectRatio > 1) {
          width = maxWidth.toInt();
          height = width ~/ aspectRatio;
        } else {
          height = maxHeight.toInt();
          width = (height * aspectRatio).toInt();
        }
      } else {
        width = decodedImage.width;
        height = decodedImage.height;
      }

      loader.complete(decodedImage);
    }

    return this;
  }

  Future rotateImage(int rotationVal) async {
    try {
      final fixedImageBytes = await FlutterImageCompress.compressWithList(
        bytes,
        rotate: rotationVal,
        quality: 100,
        keepExif: false,
        autoCorrectionAngle: true,
        format: CompressFormat.jpeg,
      );

      // invert height and width
      int oldHeight = height;
      height = width;
      width = oldHeight;

      bytes = fixedImageBytes;
    } catch (e) {
      debugPrint("failed to rotate: ${e.toString()}");
    }
  }

  static ImageItem fromJson(Map json) {
    var image = ImageItem(json['image']);

    image.width = json['width'];
    image.height = json['height'];

    return image;
  }

  Map toJson() {
    return {
      'height': height,
      'width': width,
      'bytes': bytes,
    };
  }
}
