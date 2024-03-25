import 'package:flutter/material.dart';
import 'package:carousel_image_editor/custom_image_editor.dart';
import 'package:carousel_image_editor/data/layer.dart';

class TextEditorImage extends StatefulWidget {
  const TextEditorImage({super.key});

  @override
  createState() => _TextEditorImageState();
}

class _TextEditorImageState extends State<TextEditorImage> {
  TextEditingController name = TextEditingController();
  Color currentColor = Colors.white;
  double slider = 32.0;
  TextAlign align = TextAlign.left;

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;

    return Theme(
      data: ThemeData.dark(),
      child: Scaffold(
        appBar: AppBar(
          actions: <Widget>[
            IconButton(
              icon: Icon(Icons.abc, //TODO: change
                  color: align == TextAlign.left
                      ? Colors.white
                      : Colors.white.withAlpha(80)),
              onPressed: () {
                setState(() {
                  align = TextAlign.left;
                });
              },
            ),
            IconButton(
              icon: Icon(Icons.center_focus_strong, // TODO: change
                  color: align == TextAlign.center
                      ? Colors.white
                      : Colors.white.withAlpha(80)),
              onPressed: () {
                setState(() {
                  align = TextAlign.center;
                });
              },
            ),
            IconButton(
              icon: Icon(Icons.fork_right, // TODO: change
                  color: align == TextAlign.right
                      ? Colors.white
                      : Colors.white.withAlpha(80)),
              onPressed: () {
                setState(() {
                  align = TextAlign.right;
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: () {
                Navigator.pop(
                  context,
                  TextLayerData(
                    background: Colors.transparent,
                    text: name.text,
                    color: currentColor,
                    size: slider.toDouble(),
                    align: align,
                  ),
                );
              },
              color: Colors.white,
              padding: const EdgeInsets.all(15),
            )
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(children: [
              SizedBox(
                height: size.height / 2.2,
                child: TextField(
                  controller: name,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(10),
                    hintText: i18n('Insert Your Message'),
                    hintStyle: const TextStyle(color: Colors.white),
                    alignLabelWithHint: true,
                  ),
                  scrollPadding: const EdgeInsets.all(20.0),
                  keyboardType: TextInputType.multiline,
                  minLines: 5,
                  maxLines: 99999,
                  style: TextStyle(
                    color: currentColor,
                  ),
                  autofocus: true,
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
