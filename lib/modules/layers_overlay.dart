import 'package:flutter/material.dart';
import 'package:reorderables/reorderables.dart';
import 'package:carousel_image_editor/custom_image_editor.dart';
import 'package:carousel_image_editor/data/layer.dart';
import 'package:carousel_image_editor/modules/emoji_layer_overlay.dart';
import 'package:carousel_image_editor/modules/image_layer_overlay.dart';
import 'package:carousel_image_editor/modules/text_layer_overlay.dart';

class ManageLayersOverlay extends StatefulWidget {
  final List<Layer> layers;
  final Function onUpdate;

  const ManageLayersOverlay({
    super.key,
    required this.layers,
    required this.onUpdate,
  });

  @override
  createState() => _ManageLayersOverlayState();
}

class _ManageLayersOverlayState extends State<ManageLayersOverlay> {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 450,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(10),
          topLeft: Radius.circular(10),
        ),
      ),
      child: ReorderableColumn(
        onReorder: (oldIndex, newIndex) {
          var oi = layers[currentIndex]!.length - 1 - oldIndex,
              ni = layers[currentIndex]!.length - 1 - newIndex;

          if (oi == 0 || ni == 0) {
            return;
          }

          layers[currentIndex]!.insert(ni, layers[currentIndex]!.removeAt(oi));
          setState(() {});
        },
        draggedItemBuilder: (context, index) {
          var layer = layers[layers[currentIndex]!.length - 1 - index];

          return Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xff111111),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              SizedBox(
                width: 64,
                height: 64,
                child: Center(
                  child: layer is TextLayerData || layer is EmojiLayerData
                      ? Text(
                          layer is TextLayerData
                              ? 'T'
                              : (layer as EmojiLayerData).text,
                          style: const TextStyle(
                            fontSize: 32,
                            color: Colors.white,
                            fontWeight: FontWeight.w100,
                          ),
                        )
                      : (layer is ImageLayerData
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                (layer as ImageLayerData).image.bytes,
                                fit: BoxFit.cover,
                                width: 40,
                                height: 40,
                              ))
                          : (layer is BackgroundLayerData
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(
                                    (layer as BackgroundLayerData).image.bytes,
                                    fit: BoxFit.cover,
                                    width: 40,
                                    height: 40,
                                  ))
                              : const Text(
                                  '',
                                  style: TextStyle(
                                    color: Colors.white,
                                  ),
                                ))),
                ),
              ),
              SizedBox(
                width: MediaQuery.of(context).size.width - 92 - 64,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (layer is TextLayerData)
                      Text(
                        (layer as TextLayerData).text,
                        style: const TextStyle(
                          color: Colors.white,
                        ),
                      )
                    else
                      Text(
                        layer.runtimeType.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
              if (layer is! BackgroundLayerData)
                IconButton(
                  onPressed: () {
                    layers[currentIndex]!.remove(layer);
                    setState(() {});
                  },
                  icon: const Icon(Icons.delete, size: 22, color: Colors.red),
                )
            ]),
          );
        },
        children: [
          for (var layer in layers[currentIndex]!.reversed)
            // ReorderableWidget(
            //   reorderable: true,
            //   child:
            GestureDetector(
              key: Key(
                  '${layers[currentIndex]!.indexOf(layer)}:${layer.runtimeType}'),
              onTap: () {
                if (layer is BackgroundLayerData) return;

                showModalBottomSheet(
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(10),
                      topLeft: Radius.circular(10),
                    ),
                  ),
                  context: context,
                  backgroundColor: Colors.transparent,
                  builder: (context) {
                    if (layer is EmojiLayerData) {
                      return EmojiLayerOverlay(
                        index: layers[currentIndex]!.indexOf(layer),
                        layer: layer,
                        onUpdate: () {
                          setState(() {});
                        },
                      );
                    }

                    if (layer is ImageLayerData) {
                      return ImageLayerOverlay(
                        index: layers[currentIndex]!.indexOf(layer),
                        layerData: layer,
                        onUpdate: () {
                          setState(() {});
                        },
                      );
                    }

                    if (layer is TextLayerData) {
                      return TextLayerOverlay(
                        index: layers[currentIndex]!.indexOf(layer),
                        layer: layer,
                        onUpdate: () {
                          setState(() {});
                        },
                      );
                    }

                    return Container();
                  },
                );
              },
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(children: [
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: Center(
                      child: layer is LinkLayerData
                          ? const Icon(Icons.link,
                              size: 32, color: Colors.white)
                          : (layer is TextLayerData || layer is EmojiLayerData
                              ? Text(
                                  layer is TextLayerData
                                      ? 'T'
                                      : (layer as EmojiLayerData).text,
                                  style: const TextStyle(
                                    fontSize: 32,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w100,
                                  ),
                                )
                              : (layer is ImageLayerData
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.memory(
                                        layer.image.bytes,
                                        fit: BoxFit.cover,
                                        width: 40,
                                        height: 40,
                                      ))
                                  : (layer is BackgroundLayerData
                                      ? ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: Image.memory(
                                            layer.image.bytes,
                                            fit: BoxFit.cover,
                                            width: 40,
                                            height: 40,
                                          ))
                                      : const Text(
                                          '',
                                          style: TextStyle(
                                            color: Colors.white,
                                          ),
                                        )))),
                    ),
                  ),
                  SizedBox(
                    width: MediaQuery.of(context).size.width - 92 - 64,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (layer is LinkLayerData)
                          Text(
                            layer.text,
                            style: const TextStyle(
                              color: Colors.white,
                            ),
                          )
                        else if (layer is TextLayerData)
                          Text(
                            layer.text,
                            style: const TextStyle(
                              color: Colors.white,
                            ),
                          )
                        else
                          Text(
                            layer.runtimeType.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (layer is! BackgroundLayerData)
                    IconButton(
                      onPressed: () {
                        layers[currentIndex]!.remove(layer);
                        setState(() {});
                      },
                      icon:
                          const Icon(Icons.delete, size: 22, color: Colors.red),
                    )
                ]),
              ),
              // ),
            )
        ],
      ),
    );
  }
}
