import 'package:flutter/material.dart';
import 'package:carousel_image_editor/data/layer.dart';

/// Main layer
class BackgroundLayer extends StatefulWidget {
  final BackgroundLayerData layerData;
  final VoidCallback? onUpdate;
  final bool editable;

  const BackgroundLayer({
    super.key,
    required this.layerData,
    this.onUpdate,
    this.editable = false,
  });

  @override
  State<BackgroundLayer> createState() => _BackgroundLayerState();
}

class _BackgroundLayerState extends State<BackgroundLayer> {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.blue,
      width: MediaQuery.of(context).size.width,
      height: widget.layerData.image.height.toDouble(),
      padding: EdgeInsets.zero,
      child: FittedBox(
        fit: BoxFit.fitWidth,
        child: Image.memory(
          widget.layerData.image.bytes,
          width: MediaQuery.of(context).size.width,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
