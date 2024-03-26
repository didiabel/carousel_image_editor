import 'package:carousel_image_editor/custom_image_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MaterialApp(home: ImageEditorExample()));
}

class ImageEditorExample extends StatefulWidget {
  const ImageEditorExample({
    super.key,
  });

  @override
  createState() => _ImageEditorExampleState();
}

class _ImageEditorExampleState extends State<ImageEditorExample> {
  List<Uint8List> imageListData = [];

  @override
  void initState() {
    super.initState();
    loadAsset("image.jpg");
  }

  void loadAsset(String name) async {
    var data = await rootBundle.load('assets/$name');
    setState(() =>
        imageListData = [data.buffer.asUint8List(), data.buffer.asUint8List()]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("ImageEditor Example"),
        centerTitle: true,
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (imageListData.isNotEmpty) Image.memory(imageListData[0]),
          const SizedBox(height: 16),
          ElevatedButton(
            child: const Text("Multiple image editor"),
            onPressed: () async {
              if (imageListData.isNotEmpty) {
                final List<Uint8List> editedImage = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ImagesEditor(
                      images: [imageListData[0], imageListData[0]],
                    ),
                  ),
                );

                // replace with edited image

                setState(() {
                  imageListData = editedImage;
                });
              }
            },
          ),
        ],
      ),
    );
  }
}
