import 'dart:async';
import 'dart:math' as math;

import 'package:carousel_image_editor/data/layer.dart';
import 'package:colorfilter_generator/colorfilter_generator.dart';
import 'package:colorfilter_generator/presets.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:hand_signature/signature.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';
import 'package:carousel_image_editor/colors_picker.dart';
import 'package:carousel_image_editor/data/image_item.dart';
import 'package:carousel_image_editor/layers_viewer.dart';
import 'package:carousel_image_editor/loading_screen.dart';
import 'package:carousel_image_editor/modules/all_emojies.dart';
import 'package:carousel_image_editor/modules/layers_overlay.dart';
import 'package:carousel_image_editor/modules/link.dart';
import 'package:carousel_image_editor/modules/text.dart';
import 'package:carousel_image_editor/options.dart' as o;
import 'package:carousel_image_editor/utils.dart';
import 'package:screenshot/screenshot.dart';

late Size viewportSize;
double viewportRatio = 1;
Map<int, List<Layer>> layers = {}, undoLayers = {}, removedLayers = {};
Map<int, ScreenshotController> screenshotControllers = {};
int currentIndex = 0;
Map<String, String> _translations = {};
List<ImageItem> images = [];

String i18n(String sourceString) =>
    _translations[sourceString.toLowerCase()] ?? sourceString;

/// Single endpoint for MultiImageEditor & ImagesEditor
class ImageEditor extends StatelessWidget {
  final List<Uint8List> images;
  final String? savePath;
  final int outputFormat;
  final IconData doneIcon;

  final o.ImagePickerOption imagePickerOption;
  final o.CropOption? cropOption;
  final o.BlurOption? blurOption;
  final o.BrushOption? brushOption;
  final o.EmojiOption? emojiOption;
  final o.FiltersOption? filtersOption;
  final o.FlipOption? flipOption;
  final o.RotateOption? rotateOption;
  final o.TextOption? textOption;

  const ImageEditor({
    super.key,
    this.images = const [],
    this.savePath,
    this.imagePickerOption = const o.ImagePickerOption(),
    this.outputFormat = o.OutputFormat.jpeg,
    this.doneIcon = Icons.check,
    this.cropOption = const o.CropOption(),
    this.blurOption = const o.BlurOption(),
    this.brushOption = const o.BrushOption(),
    this.emojiOption = const o.EmojiOption(),
    this.filtersOption = const o.FiltersOption(),
    this.flipOption = const o.FlipOption(),
    this.rotateOption = const o.RotateOption(),
    this.textOption = const o.TextOption(),
  });

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty &&
        !imagePickerOption.captureFromCamera &&
        !imagePickerOption.pickFromGallery) {
      throw Exception(
          'No image to work with, provide an image or allow the image picker.');
    }

    return ImagesEditor(
      images: images,
      savePath: savePath,
      imagePickerOption: imagePickerOption,
      outputFormat: outputFormat,
      doneIcon: doneIcon,
      cropOption: cropOption,
      blurOption: blurOption,
      brushOption: brushOption,
      emojiOption: emojiOption,
      filtersOption: filtersOption,
      flipOption: flipOption,
      rotateOption: rotateOption,
      textOption: textOption,
    );
  }

  static i18n(Map<String, String> translations) {
    translations.forEach((key, value) {
      _translations[key.toLowerCase()] = value;
    });
  }

  /// Set custom theme properties default is dark theme with white text
  static ThemeData theme = ThemeData(
    scaffoldBackgroundColor: Colors.black,
    colorScheme: const ColorScheme.dark(
      background: Colors.black,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.black87,
      iconTheme: IconThemeData(color: Colors.white),
      systemOverlayStyle: SystemUiOverlayStyle.light,
      toolbarTextStyle: TextStyle(color: Colors.white),
      titleTextStyle: TextStyle(color: Colors.white),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.black,
    ),
    iconTheme: const IconThemeData(
      color: Colors.white,
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: Colors.white),
    ),
  );
}

/// Image editor with all option available
class ImagesEditor extends StatefulWidget {
  final List<Uint8List> images;
  final String? savePath;
  final int outputFormat;
  final IconData doneIcon;
  final o.ImagePickerOption imagePickerOption;
  final o.CropOption? cropOption;
  final o.BlurOption? blurOption;
  final o.BrushOption? brushOption;
  final o.EmojiOption? emojiOption;
  final o.FiltersOption? filtersOption;
  final o.FlipOption? flipOption;
  final o.RotateOption? rotateOption;
  final o.TextOption? textOption;

  const ImagesEditor({
    super.key,
    this.images = const [],
    this.savePath,
    this.imagePickerOption = const o.ImagePickerOption(),
    this.outputFormat = o.OutputFormat.jpeg,
    this.doneIcon = Icons.check,
    this.cropOption = const o.CropOption(),
    this.blurOption = const o.BlurOption(),
    this.brushOption = const o.BrushOption(),
    this.emojiOption = const o.EmojiOption(),
    this.filtersOption = const o.FiltersOption(),
    this.flipOption = const o.FlipOption(),
    this.rotateOption = const o.RotateOption(),
    this.textOption = const o.TextOption(),
  });

  @override
  ImagesEditorState createState() => ImagesEditorState();
}

class ImagesEditorState extends State<ImagesEditor> {
  PermissionStatus galleryPermission = PermissionStatus.permanentlyDenied,
      cameraPermission = PermissionStatus.permanentlyDenied;

  Future<void> checkPermissions() async {
    if (widget.imagePickerOption.pickFromGallery) {
      galleryPermission = await Permission.photos.status;
    }

    if (widget.imagePickerOption.captureFromCamera) {
      cameraPermission = await Permission.camera.status;
    }

    if (widget.imagePickerOption.pickFromGallery ||
        widget.imagePickerOption.captureFromCamera) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    layers.clear();
    super.dispose();
  }

  List<Widget> filterActions(int index) {
    final imageLayers = layers[index];
    final imageUndoLayers = undoLayers[index];
    final imageRemovedLayers = removedLayers[index];
    return [
      const BackButton(),
      SizedBox(
        width: MediaQuery.of(context).size.width - 48,
        child: SingleChildScrollView(
          reverse: true,
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            IconButton(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              icon: Icon(Icons.undo,
                  color: layers.length > 1 ||
                          (imageRemovedLayers?.isNotEmpty ?? true)
                      ? Colors.white
                      : Colors.grey),
              onPressed: () {
                if (imageRemovedLayers != null && removedLayers.isNotEmpty) {
                  addLayer(imageRemovedLayers.removeLast());
                  layers[currentIndex]?.add(imageRemovedLayers.removeLast());
                  setState(() {});
                  return;
                }

                if (layers.isEmpty || layers.length <= 1) {
                  return;
                }

                if (imageUndoLayers != null && imageLayers != null) {
                  imageUndoLayers.add(imageLayers.removeLast());
                } else {
                  if (imageLayers != null) {
                    undoLayers.addAll({
                      currentIndex: [imageLayers.removeLast()]
                    });
                  } else {
                    undoLayers.addAll({currentIndex: []});
                  }
                }

                setState(() {});
              },
            ),
            IconButton(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              icon: Icon(Icons.redo,
                  color: imageUndoLayers?.isNotEmpty ?? true
                      ? Colors.white
                      : Colors.grey),
              onPressed: () {
                if (imageUndoLayers == null || imageUndoLayers.isEmpty) {
                  return;
                }
                if (imageLayers == null) {
                  layers.addAll({
                    index: [imageUndoLayers.removeLast()]
                  });
                } else {
                  imageLayers.add(imageUndoLayers.removeLast());
                }

                setState(() {});
              },
            ),
            IconButton(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              icon: Icon(widget.doneIcon),
              onPressed: () async {
                resetTransformation();
                setState(() {});

                loadingScreen.show();

                if ((widget.outputFormat & 0x1) == o.OutputFormat.json &&
                    imageLayers != null) {
                  List<List<Map<dynamic, dynamic>>> jsonList = [];
                  for (var i = 0; i < images.length; i++) {
                    var json = layers[i]!.map((e) => e.toJson()).toList();
                    jsonList.add(json);
                  }

                  if ((widget.outputFormat & 0xFE) > 0) {
                    List<Uint8List> editedImageBytesList = [];

                    for (var i = 0; i < images.length; i++) {
                      var editedImageBytes = await getMergedImage(
                        format: widget.outputFormat & 0xFE,
                        index: currentIndex,
                      );
                      if (editedImageBytes != null) {
                        editedImageBytesList.add(editedImageBytes);
                      }
                    }

                    jsonList.insert(0, [
                      {
                        'type': 'MergedLayer',
                        'image': editedImageBytesList,
                      }
                    ]);
                  }

                  loadingScreen.hide();

                  if (mounted) {
                    Navigator.pop(context, jsonList);
                  }
                } else {
                  List<Uint8List> editedImageBytesList = [];

                  for (var i = 0; i < images.length; i++) {
                    var editedImageBytes = await getMergedImage(
                      format: widget.outputFormat & 0xFE,
                      index: i,
                    );
                    if (editedImageBytes != null) {
                      editedImageBytesList.add(editedImageBytes);
                    }
                  }

                  loadingScreen.hide();

                  if (mounted) {
                    Navigator.pop(context, editedImageBytesList);
                  }
                }
              },
            ),
          ]),
        ),
      ),
    ];
  }

  @override
  void initState() {
    if (widget.images.isNotEmpty) {
      loadImages(widget.images);
    }

    checkPermissions();

    super.initState();
  }

  double flipValue = 0;

  double x = 0;
  double y = 0;
  double z = 0;

  double lastScaleFactor = 1, scaleFactor = 1;
  double widthRatio = 1, heightRatio = 1, pixelRatio = 1;

  void resetTransformation() {
    scaleFactor = 1;
    x = 0;
    y = 0;
    setState(() {});
  }

  /// obtain image Uint8List by merging layers
  Future<Uint8List?> getMergedImage({
    int format = o.OutputFormat.png,
    required int index,
  }) async {
    final imageLayers = layers[index];

    Uint8List? image;

    if (imageLayers?.length == 1 && imageLayers?.first is BackgroundLayerData) {
      image = (imageLayers?.first as BackgroundLayerData).image.bytes;
    } else if (imageLayers?.length == 1 &&
        imageLayers?.first is ImageLayerData) {
      image = (imageLayers?.first as ImageLayerData).image.bytes;
    } else {
      final controller = screenshotControllers[index];
      image = await controller!.capture(pixelRatio: pixelRatio);
    }

    // conversion for non-png
    if (image != null &&
        (format == o.OutputFormat.heic ||
            format == o.OutputFormat.jpeg ||
            format == o.OutputFormat.webp)) {
      var formats = {
        o.OutputFormat.heic: 'heic',
        o.OutputFormat.jpeg: 'jpeg',
        o.OutputFormat.webp: 'webp'
      };

      image = await ImageUtils.convert(image, format: formats[format]!);
    }

    return image;
  }

  void addLayer(Layer layer) {
    if (layers[currentIndex] != null) {
      layers[currentIndex]?.add(layer);
    } else {
      layers.addAll({
        currentIndex: [layer]
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    viewportSize = MediaQuery.of(context).size;
    pixelRatio = MediaQuery.of(context).devicePixelRatio;

    if (images.isEmpty) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    return Theme(
      data: ImageEditor.theme,
      child: Scaffold(
        body: Stack(children: [
          GestureDetector(
            onScaleUpdate: (details) {
              if (details.pointerCount == 2) {
                if (details.horizontalScale != 1) {
                  scaleFactor = lastScaleFactor *
                      math.min(details.horizontalScale, details.verticalScale);
                  setState(() {});
                }
              }
            },
            onScaleEnd: (details) {
              lastScaleFactor = scaleFactor;
            },
            child: Center(
              child: PageView.builder(
                  onPageChanged: (value) {
                    currentIndex = value;
                  },
                  itemCount: images.length,
                  itemBuilder: (context, index) {
                    return Container(
                      color: Colors.transparent,
                      child: Container(
                        child: LayersViewer(
                          index: index,
                          layers: layers[index] ?? [],
                          onUpdate: () {
                            setState(() {});
                          },
                          editable: true,
                        ),
                      ),
                    );
                  }),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.25),
              ),
              child: SafeArea(
                child: Row(
                  children: filterActions(currentIndex),
                ),
              ),
            ),
          ),
          if (layers.length > 1)
            Positioned(
              bottom: 64,
              left: 0,
              child: SafeArea(
                child: Container(
                  height: 48,
                  width: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(100),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(19),
                      bottomRight: Radius.circular(19),
                    ),
                  ),
                  child: IconButton(
                    iconSize: 20,
                    padding: const EdgeInsets.all(0),
                    onPressed: () {
                      showModalBottomSheet(
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(
                            topRight: Radius.circular(10),
                            topLeft: Radius.circular(10),
                          ),
                        ),
                        context: context,
                        backgroundColor: Colors.transparent,
                        builder: (context) => SafeArea(
                          child: ManageLayersOverlay(
                            layers: layers[currentIndex] ?? [],
                            onUpdate: () => setState(() {}),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.layers),
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 64,
            right: 0,
            child: SafeArea(
              child: Container(
                height: 48,
                width: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(100),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(19),
                    bottomLeft: Radius.circular(19),
                  ),
                ),
                child: IconButton(
                  iconSize: 20,
                  padding: const EdgeInsets.all(0),
                  onPressed: () {
                    resetTransformation();
                  },
                  icon: Icon(
                    scaleFactor > 1 ? Icons.zoom_in_map : Icons.zoom_out_map,
                  ),
                ),
              ),
            ),
          ),
        ]),
        bottomNavigationBar: Container(
          alignment: Alignment.bottomCenter,
          height: 86 + MediaQuery.of(context).padding.bottom,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: const BoxDecoration(
            color: Colors.black87,
            shape: BoxShape.rectangle,
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  if (widget.cropOption != null)
                    BottomButton(
                      icon: Icons.crop,
                      text: i18n('Crop'),
                      onTap: () async {
                        resetTransformation();
                        LoadingScreen(scaffoldGlobalKey).show();
                        final mergedImage =
                            await getMergedImage(index: currentIndex);
                        LoadingScreen(scaffoldGlobalKey).hide();

                        if (!mounted || mergedImage == null) {
                          return;
                        }

                        Uint8List? croppedImage = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ImageCropper(
                              image: mergedImage,
                              availableRatios: widget.cropOption!.ratios,
                            ),
                          ),
                        );

                        if (croppedImage == null) {
                          return;
                        }

                        flipValue = 0;

                        await images[currentIndex].load(croppedImage);
                        setState(() {});
                      },
                    ),
                  if (widget.brushOption != null)
                    BottomButton(
                      icon: Icons.edit,
                      text: i18n('Brush'),
                      onTap: () async {
                        if (widget.brushOption!.translatable) {
                          var drawing = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ImageEditorDrawing(
                                image: images[currentIndex],
                                options: widget.brushOption!,
                              ),
                            ),
                          );

                          if (drawing != null) {
                            undoLayers.clear();
                            removedLayers.clear();

                            addLayer(
                              ImageLayerData(
                                image: ImageItem(drawing),
                                offset: Offset(
                                  -images[currentIndex].width / 4,
                                  -images[currentIndex].height / 4,
                                ),
                              ),
                            );

                            setState(() {});
                          }
                        } else {
                          resetTransformation();
                          LoadingScreen(scaffoldGlobalKey).show();
                          var mergedImage =
                              await getMergedImage(index: currentIndex);
                          LoadingScreen(scaffoldGlobalKey).hide();

                          if (!mounted || mergedImage == null) {
                            return;
                          }

                          var drawing = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ImageEditorDrawing(
                                image: ImageItem(mergedImage),
                                options: widget.brushOption!,
                              ),
                            ),
                          );

                          if (drawing != null) {
                            images[currentIndex].load(drawing);

                            setState(() {});
                          }
                        }
                      },
                    ),
                  if (widget.textOption != null)
                    BottomButton(
                      icon: Icons.text_fields,
                      text: i18n('Text'),
                      onTap: () async {
                        TextLayerData? layer = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const TextEditorImage(),
                          ),
                        );

                        if (layer == null) return;

                        undoLayers.clear();
                        removedLayers.clear();

                        addLayer(layer);

                        setState(() {});
                      },
                    ),
                  if (widget.textOption != null)
                    BottomButton(
                      icon: Icons.link,
                      text: i18n('Link'),
                      onTap: () async {
                        LinkLayerData? layer = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LinkEditorImage(),
                          ),
                        );

                        if (layer == null) return;

                        undoLayers.clear();
                        removedLayers.clear();
                        addLayer(layer);

                        setState(() {});
                      },
                    ),
                  if (widget.flipOption != null)
                    BottomButton(
                      icon: Icons.flip,
                      text: i18n('Flip'),
                      onTap: () {
                        setState(() {
                          flipValue = flipValue == 0 ? math.pi : 0;
                        });
                      },
                    ),
                  if (widget.rotateOption != null)
                    BottomButton(
                      icon: Icons.rotate_90_degrees_cw,
                      text: i18n('Rotate image'),
                      onTap: () async {
                        await images[currentIndex].rotateImage(90);

                        setState(() {});
                      },
                    ),
                  if (widget.blurOption != null)
                    BottomButton(
                      icon: Icons.blur_on,
                      text: i18n('Blur'),
                      onTap: () {
                        var blurLayer = BackgroundBlurLayerData(
                          color: Colors.transparent,
                          radius: 0.0,
                          opacity: 0.0,
                        );

                        undoLayers.clear();
                        removedLayers.clear();
                        addLayer(blurLayer);
                        setState(() {});

                        showModalBottomSheet(
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.only(
                                topRight: Radius.circular(10),
                                topLeft: Radius.circular(10)),
                          ),
                          context: context,
                          backgroundColor: Colors.transparent,
                          builder: (context) {
                            return StatefulBuilder(
                              builder: (context, setS) {
                                return SingleChildScrollView(
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.black87,
                                      borderRadius: BorderRadius.only(
                                          topRight: Radius.circular(10),
                                          topLeft: Radius.circular(10)),
                                    ),
                                    padding: const EdgeInsets.all(20),
                                    height: 400,
                                    child: Column(
                                      children: [
                                        Center(
                                            child: Text(
                                          i18n('Slider Filter Color')
                                              .toUpperCase(),
                                          style: const TextStyle(
                                              color: Colors.white),
                                        )),
                                        const SizedBox(height: 20.0),
                                        Text(
                                          i18n('Slider Color'),
                                          style: const TextStyle(
                                              color: Colors.white),
                                        ),
                                        const SizedBox(height: 10),
                                        Row(children: [
                                          Expanded(
                                            child: BarColorPicker(
                                              width: 300,
                                              thumbColor: Colors.white,
                                              cornerRadius: 10,
                                              pickMode: PickMode.color,
                                              colorListener: (int value) {
                                                setS(() {
                                                  setState(() {
                                                    blurLayer.color =
                                                        Color(value);
                                                  });
                                                });
                                              },
                                            ),
                                          ),
                                          TextButton(
                                            child: Text(
                                              i18n('Reset'),
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                setS(() {
                                                  blurLayer.color =
                                                      Colors.transparent;
                                                });
                                              });
                                            },
                                          )
                                        ]),
                                        const SizedBox(height: 5.0),
                                        Text(
                                          i18n('Blur Radius'),
                                          style: const TextStyle(
                                              color: Colors.white),
                                        ),
                                        const SizedBox(height: 10.0),
                                        Row(children: [
                                          Expanded(
                                            child: Slider(
                                              activeColor: Colors.white,
                                              inactiveColor: Colors.grey,
                                              value: blurLayer.radius,
                                              min: 0.0,
                                              max: 10.0,
                                              onChanged: (v) {
                                                setS(() {
                                                  setState(() {
                                                    blurLayer.radius = v;
                                                  });
                                                });
                                              },
                                            ),
                                          ),
                                          TextButton(
                                            child: Text(
                                              i18n('Reset'),
                                            ),
                                            onPressed: () {
                                              setS(() {
                                                setState(() {
                                                  blurLayer.color =
                                                      Colors.white;
                                                });
                                              });
                                            },
                                          )
                                        ]),
                                        const SizedBox(height: 5.0),
                                        Text(
                                          i18n('Color Opacity'),
                                          style: const TextStyle(
                                              color: Colors.white),
                                        ),
                                        const SizedBox(height: 10.0),
                                        Row(children: [
                                          Expanded(
                                            child: Slider(
                                              activeColor: Colors.white,
                                              inactiveColor: Colors.grey,
                                              value: blurLayer.opacity,
                                              min: 0.00,
                                              max: 1.0,
                                              onChanged: (v) {
                                                setS(() {
                                                  setState(() {
                                                    blurLayer.opacity = v;
                                                  });
                                                });
                                              },
                                            ),
                                          ),
                                          TextButton(
                                            child: Text(
                                              i18n('Reset'),
                                            ),
                                            onPressed: () {
                                              setS(() {
                                                setState(() {
                                                  blurLayer.opacity = 0.0;
                                                });
                                              });
                                            },
                                          )
                                        ]),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  if (widget.filtersOption != null)
                    BottomButton(
                      icon: Icons.color_lens,
                      text: i18n('Filter'),
                      onTap: () async {
                        resetTransformation();

                        LoadingScreen(scaffoldGlobalKey).show();
                        var mergedImage =
                            await getMergedImage(index: currentIndex);
                        LoadingScreen(scaffoldGlobalKey).hide();

                        if (!mounted) return;

                        Uint8List? filterAppliedImage = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ImageFilters(
                              image: mergedImage!,
                              options: widget.filtersOption,
                            ),
                          ),
                        );

                        if (filterAppliedImage == null) return;

                        removedLayers.clear();
                        undoLayers.clear();

                        var layer = BackgroundLayerData(
                          image: ImageItem(filterAppliedImage),
                        );

                        /// Use case, if you don't want your filter to effect your
                        /// other elements such as emoji and text. Use insert
                        /// instead of add like in line 888
                        addLayer(layer);

                        await layer.image.loader.future;

                        setState(() {});
                      },
                    ),
                  if (widget.emojiOption != null)
                    BottomButton(
                      icon: Icons.emoji_emotions,
                      text: i18n('Emoji'),
                      onTap: () async {
                        EmojiLayerData? layer = await showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.black,
                          builder: (BuildContext context) {
                            return const Emojies();
                          },
                        );

                        if (layer == null) return;

                        undoLayers.clear();
                        removedLayers.clear();
                        addLayer(layer);

                        setState(() {});
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // final picker = ImagePicker();

  Future<void> loadImages(List<Uint8List> imageFiles) async {
    images.clear();
    for (var i = 0; i < imageFiles.length; i++) {
      ImageItem image = ImageItem();
      final imageLoaded = await image.load(imageFiles[i]);
      images.add(imageLoaded);
      screenshotControllers.addAll({i: ScreenshotController()});
      layers.addAll({
        i: [BackgroundLayerData(image: imageLoaded)]
      });

      undoLayers.addAll({currentIndex: []});
      removedLayers.addAll({currentIndex: []});
      setState(() {});
    }

    setState(() {});
  }
}

/// Button used in bottomNavigationBar in ImageEditor
class BottomButton extends StatelessWidget {
  final VoidCallback? onTap, onLongPress;
  final IconData icon;
  final String text;

  const BottomButton({
    super.key,
    this.onTap,
    this.onLongPress,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          children: [
            Icon(
              icon,
              color: Colors.white,
            ),
            const SizedBox(height: 8),
            Text(
              i18n(text),
            ),
          ],
        ),
      ),
    );
  }
}

/// Crop given image with various aspect ratios
class ImageCropper extends StatefulWidget {
  final Uint8List image;
  final List<o.AspectRatio> availableRatios;

  const ImageCropper({
    super.key,
    required this.image,
    this.availableRatios = const [
      o.AspectRatio(title: 'Freeform'),
      o.AspectRatio(title: '1:1', ratio: 1),
      o.AspectRatio(title: '4:3', ratio: 4 / 3),
      o.AspectRatio(title: '5:4', ratio: 5 / 4),
      o.AspectRatio(title: '7:5', ratio: 7 / 5),
      o.AspectRatio(title: '16:9', ratio: 16 / 9),
    ],
  });

  @override
  createState() => _ImageCropperState();
}

class _ImageCropperState extends State<ImageCropper> {
  final GlobalKey<ExtendedImageEditorState> _controller =
      GlobalKey<ExtendedImageEditorState>();

  double? currentRatio;
  bool isLandscape = true;
  int rotateAngle = 0;

  double? get aspectRatio => currentRatio == null
      ? null
      : isLandscape
          ? currentRatio!
          : (1 / currentRatio!);

  @override
  void initState() {
    if (widget.availableRatios.isNotEmpty) {
      currentRatio = widget.availableRatios.first.ratio;
    }
    _controller.currentState?.rotate(right: true);

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ImageEditor.theme,
      child: Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              icon: const Icon(Icons.check),
              onPressed: () async {
                var state = _controller.currentState;

                if (state == null || state.getCropRect() == null) {
                  Navigator.pop(context);
                }

                var data = await cropImageWithThread(
                  imageBytes: state!.rawImageData,
                  rect: state.getCropRect()!,
                );

                if (mounted) Navigator.pop(context, data);
              },
            ),
          ],
        ),
        body: Container(
          color: Colors.black,
          child: ExtendedImage.memory(
            widget.image,
            cacheRawData: true,
            fit: BoxFit.contain,
            extendedImageEditorKey: _controller,
            mode: ExtendedImageMode.editor,
            initEditorConfigHandler: (state) {
              return EditorConfig(
                cropAspectRatio: aspectRatio,
              );
            },
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: SizedBox(
            height: 80,
            child: Column(
              children: [
                Container(
                  height: 80,
                  decoration: const BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black,
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        if (currentRatio != null && currentRatio != 1)
                          IconButton(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            icon: Icon(
                              Icons.portrait,
                              color: isLandscape ? Colors.grey : Colors.white,
                            ),
                            onPressed: () {
                              isLandscape = false;

                              setState(() {});
                            },
                          ),
                        if (currentRatio != null && currentRatio != 1)
                          IconButton(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            icon: Icon(
                              Icons.landscape,
                              color: isLandscape ? Colors.white : Colors.grey,
                            ),
                            onPressed: () {
                              isLandscape = true;

                              setState(() {});
                            },
                          ),
                        for (var ratio in widget.availableRatios)
                          TextButton(
                            onPressed: () {
                              currentRatio = ratio.ratio;

                              setState(() {});
                            },
                            child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                child: Text(
                                  i18n(ratio.title),
                                  style: TextStyle(
                                    color: currentRatio == ratio.ratio
                                        ? Colors.white
                                        : Colors.grey,
                                  ),
                                )),
                          )
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<Uint8List?> cropImageWithThread({
    required Uint8List imageBytes,
    required Rect rect,
  }) async {
    img.Command cropTask = img.Command();
    cropTask.decodeImage(imageBytes);

    cropTask.copyCrop(
      x: rect.topLeft.dx.ceil(),
      y: rect.topLeft.dy.ceil(),
      height: rect.height.ceil(),
      width: rect.width.ceil(),
    );

    img.Command encodeTask = img.Command();
    encodeTask.subCommand = cropTask;
    encodeTask.encodeJpg();

    return encodeTask.getBytesThread();
  }
}

/// Return filter applied Uint8List image
class ImageFilters extends StatefulWidget {
  final Uint8List image;

  /// apply each filter to given image in background and cache it to improve UX
  final bool useCache;
  final o.FiltersOption? options;

  const ImageFilters({
    super.key,
    required this.image,
    this.useCache = true,
    this.options,
  });

  @override
  createState() => _ImageFiltersState();
}

class _ImageFiltersState extends State<ImageFilters> {
  late img.Image decodedImage;
  ColorFilterGenerator selectedFilter = PresetFilters.none;
  Uint8List resizedImage = Uint8List.fromList([]);
  double filterOpacity = 1;
  Uint8List? filterAppliedImage;
  ScreenshotController screenshotController = ScreenshotController();
  late List<ColorFilterGenerator> filters;

  @override
  void initState() {
    filters = [
      PresetFilters.none,
      ...(widget.options?.filters ?? presetFiltersList.sublist(1))
    ];

    // decodedImage = img.decodeImage(widget.image)!;
    // resizedImage = img.copyResize(decodedImage, height: 64).getBytes();

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ImageEditor.theme,
      child: Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              icon: const Icon(Icons.check),
              onPressed: () async {
                loadingScreen.show();
                var data = await screenshotController.capture();
                loadingScreen.hide();

                if (mounted) Navigator.pop(context, data);
              },
            ),
          ],
        ),
        body: Center(
          child: Screenshot(
            controller: screenshotController,
            child: Stack(
              children: [
                Image.memory(
                  widget.image,
                  fit: BoxFit.cover,
                ),
                FilterAppliedImage(
                  key: Key('selectedFilter:${selectedFilter.name}'),
                  image: widget.image,
                  filter: selectedFilter,
                  fit: BoxFit.cover,
                  opacity: filterOpacity,
                  // onProcess: (img) {
                  //   print('processing done');
                  //   filterAppliedImage = img;
                  // },
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: SizedBox(
            height: 160,
            child: Column(children: [
              SizedBox(
                height: 40,
                child: selectedFilter == PresetFilters.none
                    ? Container()
                    : selectedFilter.build(
                        Slider(
                          min: 0,
                          max: 1,
                          divisions: 100,
                          value: filterOpacity,
                          onChanged: (value) {
                            filterOpacity = value;
                            setState(() {});
                          },
                        ),
                      ),
              ),
              SizedBox(
                height: 120,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (var filter in filters)
                      GestureDetector(
                        onTap: () {
                          selectedFilter = filter;
                          setState(() {});
                        },
                        child: Column(children: [
                          Container(
                            height: 64,
                            width: 64,
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(48),
                              border: Border.all(
                                color: selectedFilter == filter
                                    ? Colors.white
                                    : Colors.black,
                                width: 2,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(48),
                              child: FilterAppliedImage(
                                key: Key('filterPreviewButton:${filter.name}'),
                                image: widget.image,
                                filter: filter,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Text(
                            i18n(filter.name),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ]),
                      ),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class FilterAppliedImage extends StatefulWidget {
  final Uint8List image;
  final ColorFilterGenerator filter;
  final BoxFit? fit;
  final Function(Uint8List)? onProcess;
  final double opacity;

  const FilterAppliedImage({
    super.key,
    required this.image,
    required this.filter,
    this.fit,
    this.onProcess,
    this.opacity = 1,
  });

  @override
  State<FilterAppliedImage> createState() => _FilterAppliedImageState();
}

class _FilterAppliedImageState extends State<FilterAppliedImage> {
  @override
  initState() {
    super.initState();

    // process filter in background
    if (widget.onProcess != null) {
      // no filter supplied
      if (widget.filter.filters.isEmpty) {
        widget.onProcess!(widget.image);
        return;
      }

      var filterTask = img.Command();
      filterTask.decodeImage(widget.image);

      var matrix = widget.filter.matrix;

      filterTask.filter((image) {
        for (final pixel in image) {
          pixel.r = matrix[0] * pixel.r +
              matrix[1] * pixel.g +
              matrix[2] * pixel.b +
              matrix[3] * pixel.a +
              matrix[4];

          pixel.g = matrix[5] * pixel.r +
              matrix[6] * pixel.g +
              matrix[7] * pixel.b +
              matrix[8] * pixel.a +
              matrix[9];

          pixel.b = matrix[10] * pixel.r +
              matrix[11] * pixel.g +
              matrix[12] * pixel.b +
              matrix[13] * pixel.a +
              matrix[14];

          pixel.a = matrix[15] * pixel.r +
              matrix[16] * pixel.g +
              matrix[17] * pixel.b +
              matrix[18] * pixel.a +
              matrix[19];
        }

        return image;
      });

      filterTask.getBytesThread().then((result) {
        if (widget.onProcess != null && result != null) {
          widget.onProcess!(result);
        }
      }).catchError((err, stack) {
        // print(err);
        // print(stack);
      });

      // final image_editor.ImageEditorOption option =
      //     image_editor.ImageEditorOption();

      // option.addOption(image_editor.ColorOption(matrix: filter.matrix));

      // image_editor.ImageEditor.editImage(
      //   image: image,
      //   imageEditorOption: option,
      // ).then((result) {
      //   if (result != null) {
      //     onProcess!(result);
      //   }
      // }).catchError((err, stack) {
      //   // print(err);
      //   // print(stack);
      // });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.filter.filters.isEmpty) {
      return Image.memory(
        widget.image,
        fit: widget.fit,
      );
    }

    return Opacity(
      opacity: widget.opacity,
      child: widget.filter.build(
        Image.memory(
          widget.image,
          fit: widget.fit,
        ),
      ),
    );
  }
}

/// Show image drawing surface over image
class ImageEditorDrawing extends StatefulWidget {
  final ImageItem image;
  final o.BrushOption options;

  const ImageEditorDrawing({
    super.key,
    required this.image,
    this.options = const o.BrushOption(
      showBackground: true,
      translatable: true,
    ),
  });

  @override
  State<ImageEditorDrawing> createState() => _ImageEditorDrawingState();
}

class _ImageEditorDrawingState extends State<ImageEditorDrawing> {
  Color pickerColor = Colors.white,
      currentColor = Colors.white,
      currentBackgroundColor = Colors.black;
  var screenshotController = ScreenshotController();

  final control = HandSignatureControl(
    threshold: 3.0,
    smoothRatio: 0.65,
    velocityRange: 2.0,
  );

  List<CubicPath> undoList = [];
  bool skipNextEvent = false;

  void changeColor(o.BrushColor color) {
    currentColor = color.color;
    currentBackgroundColor = color.background;

    setState(() {});
  }

  @override
  void initState() {
    control.addListener(() {
      if (control.hasActivePath) return;

      if (skipNextEvent) {
        skipNextEvent = false;
        return;
      }

      undoList = [];
      setState(() {});
    });

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ImageEditor.theme,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              icon: const Icon(Icons.clear),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            const Spacer(),
            IconButton(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              icon: Icon(
                Icons.undo,
                color: control.paths.isNotEmpty
                    ? Colors.white
                    : Colors.white.withAlpha(80),
              ),
              onPressed: () {
                if (control.paths.isEmpty) return;
                skipNextEvent = true;
                undoList.add(control.paths.last);
                control.stepBack();
                setState(() {});
              },
            ),
            IconButton(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              icon: Icon(
                Icons.redo,
                color: undoList.isNotEmpty
                    ? Colors.white
                    : Colors.white.withAlpha(80),
              ),
              onPressed: () {
                if (undoList.isEmpty) return;

                control.paths.add(undoList.removeLast());
                setState(() {});
              },
            ),
            IconButton(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              icon: const Icon(Icons.check),
              onPressed: () async {
                if (control.paths.isEmpty) return Navigator.pop(context);

                if (widget.options.translatable) {
                  var data = await control.toImage(
                    color: currentColor,
                    height: widget.image.height,
                    width: widget.image.width,
                  );

                  if (!mounted) return;

                  return Navigator.pop(context, data!.buffer.asUint8List());
                }

                loadingScreen.show();
                var image = await screenshotController.capture();
                loadingScreen.hide();

                if (!mounted) return;

                return Navigator.pop(context, image);
              },
            ),
          ],
        ),
        body: Screenshot(
          controller: screenshotController,
          child: Container(
            height: MediaQuery.of(context).size.height,
            width: MediaQuery.of(context).size.width,
            decoration: BoxDecoration(
              color:
                  widget.options.showBackground ? null : currentBackgroundColor,
              image: widget.options.showBackground
                  ? DecorationImage(
                      image: Image.memory(widget.image.bytes).image,
                      fit: BoxFit.contain,
                    )
                  : null,
            ),
            child: HandSignature(
              control: control,
              color: currentColor,
              width: 1.0,
              maxWidth: 7.0,
              type: SignatureDrawType.shape,
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            height: 80,
            decoration: const BoxDecoration(
              boxShadow: [
                BoxShadow(blurRadius: 2),
              ],
            ),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: <Widget>[
                ColorButton(
                  color: Colors.yellow,
                  onTap: (color) {
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
                        return Container(
                          color: Colors.black87,
                          padding: const EdgeInsets.all(20),
                          child: SingleChildScrollView(
                            child: Container(
                              padding: const EdgeInsets.only(top: 16),
                              child: HueRingPicker(
                                pickerColor: pickerColor,
                                onColorChanged: (color) {
                                  currentColor = color;
                                  setState(() {});
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
                for (var color in widget.options.colors)
                  ColorButton(
                    color: color.color,
                    onTap: (color) {
                      currentColor = color;
                      setState(() {});
                    },
                    isSelected: color.color == currentColor,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Button used in bottomNavigationBar in ImageEditorDrawing
class ColorButton extends StatelessWidget {
  final Color color;
  final Function(Color) onTap;
  final bool isSelected;

  const ColorButton({
    super.key,
    required this.color,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        onTap(color);
      },
      child: Container(
        height: 34,
        width: 34,
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 23),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white54,
            width: isSelected ? 3 : 1,
          ),
        ),
      ),
    );
  }
}
