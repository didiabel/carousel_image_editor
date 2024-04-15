import 'package:carousel_image_editor/custom_image_editor.dart';
import 'package:carousel_image_editor/data/layer.dart';
import 'package:carousel_image_editor/layers/background_blur_layer.dart';
import 'package:carousel_image_editor/layers/background_layer.dart';
import 'package:carousel_image_editor/layers/emoji_layer.dart';
import 'package:carousel_image_editor/layers/image_layer.dart';
import 'package:carousel_image_editor/layers/link_layer.dart';
import 'package:carousel_image_editor/layers/text_layer.dart';
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';

/// View stacked layers (unbounded height, width)
class LayersViewer extends StatelessWidget {
  final List<Layer> layers;
  final int index;
  final Function()? onUpdate;
  final bool editable;

  const LayersViewer({
    super.key,
    required this.layers,
    required this.index,
    required this.editable,
    this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: layers.map((layerItem) {
        // Background layer
        if (layerItem is BackgroundLayerData) {
          return Screenshot(
            controller: screenshotControllers[index]!,
            child: BackgroundLayer(
              onUpdate: onUpdate,
              layerData: layerItem,
              editable: editable,
            ),
          );
        }

        // Image layer
        if (layerItem is ImageLayerData) {
          return ImageLayer(
            layerData: layerItem,
            onUpdate: onUpdate,
            editable: editable,
          );
        }

        // Background blur layer
        if (layerItem is BackgroundBlurLayerData && layerItem.radius > 0) {
          return BackgroundBlurLayer(
            layerData: layerItem,
            onUpdate: onUpdate,
            editable: editable,
          );
        }

        // Emoji layer
        if (layerItem is EmojiLayerData) {
          return EmojiLayer(
            layerData: layerItem,
            onUpdate: onUpdate,
            editable: editable,
          );
        }

        // Text layer
        if (layerItem is TextLayerData) {
          return TextLayer(
            layerData: layerItem,
            onUpdate: onUpdate,
            editable: editable,
          );
        }

        // Link layer
        if (layerItem is LinkLayerData) {
          return LinkLayer(
            layerData: layerItem,
            onUpdate: onUpdate,
            editable: editable,
          );
        }

        // Blank layer
        return Container();
      }).toList(),
    );
  }
}
