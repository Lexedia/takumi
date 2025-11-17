import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'models/font_style.dart';
import 'models/node.dart';
import 'models/options.dart';

import './ffi/takumi.g.dart' hide Renderer;
import './ffi/takumi.g.dart' as takumi show Renderer;

/// A frame in an animation consisting of a [Node] and its display [duration].
typedef Frame = (Node node, Duration duration);

/// A list of frames for an animation.
typedef Frames = List<Frame>;

/// {@template renderer}
/// A high-performance rendering engine for converting styled layout trees into raster images.
///
/// The [Renderer] class provides a Dart wrapper around a native Rust-based renderer that can:
/// - Render single frames both synchronously or asynchronously
/// - Render animations with multiple frames and durations
/// - Load custom fonts from in-memory buffers
/// - Manage a persistent image store for reusable image assets
/// - Cache resources for improved performance
///
///
/// Native resources are automatically freed when the Renderer object is garbage collected,
/// but you can also explicitly call [dispose] to free them immediately.
///
/// Example usage:
/// ```dart
/// final renderer = Renderer();
/// // Resources are automatically freed when renderer goes out of scope
/// final imageBytes = renderer.renderSync(myNode, RenderOptions(width: 800, height: 600));
/// ```
/// {@endtemplate}
class Renderer implements Finalizable {
  static final _finalizer = NativeFinalizer(_takumiRendererFreeAddress);

  static final Pointer<NativeFunction<Void Function(Pointer<Void>)>>
  _takumiRendererFreeAddress = Native.addressOf(takumi_renderer_free_void);

  Pointer<takumi.Renderer> _ptr;

  Renderer._(this._ptr) {
    _finalizer.attach(this, _ptr.cast<Void>(), detach: this);
  }

  /// {@macro renderer}
  /// 
  /// Creates a new instance of [Renderer].
  factory Renderer() {
    final ptr = takumi_renderer_new();
    if (ptr == nullptr) {
      throw Exception('Failed to create Renderer');
    }
    return Renderer._(ptr);
  }

  String _getLastError() => takumi_last_error().cast<Utf8>().toDartString();

  /// Asynchronously renders a [node] with the specified [options].
  ///
  /// This method offloads the rendering work to a background thread, allowing the caller
  /// to await the result without blocking the main isolate. This is ideal for interactive
  /// applications where responsiveness is important.
  ///
  /// This method renders the given [node] with the specified [options]. The
  /// [node] is the root layout node to render and [options] provides rendering
  /// options such as dimensions, format, and quality; it defaults to sensible
  /// values.
  ///
  /// Returns a [Future] that resolves to the rendered image bytes.
  ///
  /// Throws an exception if rendering fails. The error message will include details
  /// from the native renderer.
  ///
  /// Example:
  /// ```dart
  /// final renderer = Renderer();
  /// final imageBytes = await renderer.render(
  ///   myNode,
  ///   RenderOptions(width: 1200, height: 630, format: .webp),
  /// );
  /// ```
  Future<Uint8List> render(
    Node node, [
    RenderOptions options = const .new(),
  ]) async {
    final jsonNode = node.toJson();
    final jsonOptions = options.toJson();
    final nodePtr = jsonNode.toNativeUtf8();
    final optionsPtr = jsonOptions.toNativeUtf8();

    try {
      final taskId = takumi_renderer_render(
        _ptr,
        nodePtr.cast<UnsignedChar>(),
        jsonNode.length,
        optionsPtr.cast<UnsignedChar>(),
        jsonOptions.length,
      );

      if (taskId == 0) {
        final error = _getLastError();
        throw Exception('Failed to start render: $error');
      }

      return _pollRenderTask(taskId);
    } finally {
      malloc.free(nodePtr);
      malloc.free(optionsPtr);
    }
  }

  Future<Uint8List> _pollRenderTask(int taskId) async {
    while (true) {
      final outLen = calloc<UintPtr>();
      final outStatus = calloc<Int>();

      try {
        final bufPtr = takumi_poll_render_task(taskId, outLen, outStatus);
        final status = outStatus.value;

        if (status == 1) {
          final len = outLen.value;
          final result = bufPtr.cast<Uint8>().asTypedList(len).sublist(0);
          takumi_free_buffer(bufPtr.cast());
          takumi_free_render_task(taskId);
          return result;
        } else if (status == 2) {
          final error = _getLastError();
          throw Exception('Render error: $error');
        }

        await Future.delayed(const Duration(milliseconds: 10));
      } finally {
        malloc.free(outLen);
        malloc.free(outStatus);
      }
    }
  }

  /// Synchronously renders a [node] with the specified [options].
  ///
  /// This method blocks the caller until rendering is complete. Use this when you need
  /// the result immediately or when rendering is not performance-critical. For better
  /// responsiveness, consider using [render] for asynchronous rendering.
  ///
  /// This synchronous method renders the given [node] using the provided
  /// [options]. The [node] is the root layout node to render and [options]
  /// controls dimensions, format and other encoding details; it defaults to
  /// sensible values.
  ///
  /// Returns the rendered image bytes.
  ///
  /// Throws an exception if rendering fails. The error message will include details
  /// from the native renderer.
  ///
  /// Example:
  /// ```dart
  /// final renderer = Renderer();
  /// final imageBytes = renderer.renderSync(
  ///  myNode,
  ///  RenderOptions(width: 800, height: 600, format: .png),
  /// );
  /// ```
  Uint8List renderSync(Node node, [RenderOptions options = const .new()]) {
    final jsonNode = node.toJson();
    final jsonOptions = options.toJson();
    final nodePtr = jsonNode.toNativeUtf8();
    final optionsPtr = jsonOptions.toNativeUtf8();
    final outLen = calloc<UintPtr>();

    try {
      final bufPtr = takumi_renderer_render_sync(
        _ptr,
        nodePtr.cast<UnsignedChar>(),
        jsonNode.length,
        optionsPtr.cast<UnsignedChar>(),
        jsonOptions.length,
        outLen,
      );

      if (bufPtr == nullptr) {
        final error = _getLastError();
        throw Exception('Rendering failed: $error');
      }

      final len = outLen.value;
      final buffer = bufPtr.cast<Uint8>().asTypedList(len).sublist(0);
      takumi_free_buffer(bufPtr.cast<Void>());
      return buffer;
    } finally {
      malloc.free(nodePtr);
      malloc.free(optionsPtr);
      malloc.free(outLen);
    }
  }

  /// Synchronously renders an animation from a sequence of [frames] with the specified [options].
  ///
  /// This method blocks until the entire animation is rendered and encoded. Each frame
  /// consists of a [Node] and a [Duration] specifying how long that frame should display.
  ///
  /// The renderer automatically encodes the frames into the specified format (WebP or APNG).
  /// Frame durations are converted to milliseconds for the native renderer.
  ///
  /// Returns the encoded animation bytes (WebP, APNG, etc. depending on format).
  ///
  /// Throws an exception if rendering fails. The error message will include details
  /// from the native renderer.
  ///
  /// Example:
  /// ```dart
  /// final renderer = Renderer();
  /// final frames = [
  ///   (node1, Duration(milliseconds: 100)),
  ///   (node2, Duration(milliseconds: 100)),
  ///   (node3, Duration(milliseconds: 100)),
  /// ];
  /// final animationBytes = renderer.renderAnimationSync(
  ///   frames,
  ///   RenderAnimationOptions(width: 800, height: 600, format: .webp),
  /// );
  /// ```
  Uint8List renderAnimationSync(
    Frames frames, [
    RenderAnimationOptions options = const .new(),
  ]) {
    final framesMap = frames
        .map(
          (frame) => {
            'node': frame.$1.toMap(),
            'duration_ms': frame.$2.inMilliseconds,
          },
        )
        .toList();
    final jsonFrames = json.encode(framesMap);

    final jsonOptions = options.toJson();

    final framesPtr = jsonFrames.toNativeUtf8();
    final optionsPtr = jsonOptions.toNativeUtf8();
    final outLen = calloc<UintPtr>();

    try {
      final bufPtr = takumi_render_animation_sync(
        _ptr,
        framesPtr.cast<UnsignedChar>(),
        jsonFrames.length,
        optionsPtr.cast<UnsignedChar>(),
        jsonOptions.length,
        outLen,
      );

      if (bufPtr == nullptr) {
        final error = _getLastError();
        throw Exception('Rendering animation failed: $error');
      }

      final len = outLen.value;
      final buffer = bufPtr.cast<Uint8>().asTypedList(len).sublist(0);
      takumi_free_buffer(bufPtr.cast<Void>());
      return buffer;
    } finally {
      malloc.free(framesPtr);
      malloc.free(optionsPtr);
      malloc.free(outLen);
    }
  }

  /// Asynchronously renders an animation from a sequence of [frames] with the specified [options].
  ///
  /// This method offloads animation rendering to a background thread. Each frame consists
  /// of a [Node] and a [Duration] specifying how long that frame should display.
  ///
  /// Animation encoding (WebP, APNG, etc.) happens on the background thread, so the caller
  /// can await the result without blocking the main isolate.
  ///
  /// This method renders the provided animation [frames] using the supplied
  /// [options]. Each entry in [frames] is a tuple of a [Node] and a [Duration]
  /// (the frame display time). The [options] control encoding format and size
  /// and default to sensible values.
  ///
  /// Returns a [Future] that resolves to the encoded animation bytes.
  ///
  /// Throws an exception if rendering fails. The error message will include details
  /// from the native renderer.
  ///
  /// Example:
  /// ```dart
  /// final renderer = Renderer();
  /// final frames = [
  ///   (node1, Duration(milliseconds: 100)),
  ///   (node2, Duration(milliseconds: 100)),
  /// ];
  /// final animationBytes = await renderer.renderAnimation(
  ///   frames,
  ///   RenderAnimationOptions(width: 1200, height: 630, format: .webp),
  /// );
  /// ```
  Future<Uint8List> renderAnimation(
    Frames frames, [
    RenderAnimationOptions options = const .new(),
  ]) async {
    final framesMap = frames
        .map(
          (frame) => {
            'node': frame.$1.toMap(),
            'duration_ms': frame.$2.inMilliseconds,
          },
        )
        .toList();
    final jsonFrames = json.encode(framesMap);

    final jsonOptions = options.toJson();

    final framesPtr = jsonFrames.toNativeUtf8();
    final optionsPtr = jsonOptions.toNativeUtf8();

    try {
      final taskId = takumi_render_animation(
        _ptr,
        framesPtr.cast<UnsignedChar>(),
        jsonFrames.length,
        optionsPtr.cast<UnsignedChar>(),
        jsonOptions.length,
      );

      if (taskId == 0) {
        final error = _getLastError();
        throw Exception('Failed to start animation render: $error');
      }

      return _pollRenderTask(taskId);
    } finally {
      malloc.free(framesPtr);
      malloc.free(optionsPtr);
    }
  }

  /// Stores an image in the renderer's persistent image store under a given key.
  ///
  /// The persistent image store allows you to register images by key so they can be
  /// referenced in layout nodes without being re-loaded or re-encoded on every render.
  /// This is useful for logos, icons, or other static images used across multiple renders.
  ///
  /// Image data is copied into the renderer, so the original bytes can be discarded
  /// after calling this method.
  ///
  /// Throws an exception if the operation fails.
  ///
  /// Example:
  /// ```dart
  /// final renderer = Renderer();
  /// final logoBytes = await File('logo.png').readAsBytes();
  /// renderer.putPersistentImage('logo.png', logoBytes);
  /// final imageNode = ImageNode(src: 'logo.png');
  /// // This node will render the image with the logo.
  /// ```
  void putPersistentImage(String src, Uint8List data) {
    final srcPtr = src.toNativeUtf8();
    final dataPtr = malloc<Uint8>(data.length);

    try {
      if (data.isNotEmpty) {
        final nativeList = dataPtr.asTypedList(data.length);
        nativeList.setAll(0, data);
      }

      final res = takumi_renderer_put_persistent_image(
        _ptr,
        srcPtr.cast<Char>(),
        dataPtr.cast<UnsignedChar>(),
        data.length,
      );

      if (res != 0) {
        final error = _getLastError();
        throw Exception('Failed to put persistent image: $error');
      }
    } finally {
      malloc.free(srcPtr);
      malloc.free(dataPtr);
    }
  }

  /// Clears all entries from the renderer's persistent image store.
  ///
  /// After calling this method, all previously stored images (registered via [putPersistentImage])
  /// will be removed. Subsequent renders that reference those images by key will fail unless
  /// the images are re-registered.
  ///
  /// This is useful for freeing memory when you no longer need previously stored images.
  ///
  /// Example:
  /// ```dart
  /// renderer.clearImageStore();
  /// ```
  void clearImageStore() {
    takumi_renderer_clear_image_store(_ptr);
  }

  /// Clears the in-memory resource cache used by this renderer instance.
  ///
  /// The renderer maintains an internal LRU cache of recently fetched resources (images, fonts, etc.)
  /// to improve performance. Calling this method empties that cache, forcing subsequent renders
  /// to re-fetch and re-process resources.
  ///
  /// This is useful for:
  /// - Freeing memory when resources are no longer needed
  /// - Forcing a refresh of resource data (e.g., if external files have been updated)
  /// - Testing or debugging resource-loading behaviour
  ///
  /// This method is thread-safe and can be called from any thread.
  ///
  /// Example:
  /// ```dart
  /// renderer.purgeResourceCache();
  /// ```
  void purgeResourceCache() {
    takumi_renderer_purge_resource_cache(_ptr);
  }

  /// Frees all native resources associated with this renderer.
  ///
  /// After calling [dispose], this renderer instance should no longer be used.
  /// Any attempt to render or access resources after disposal will result in an error.
  ///
  /// It is safe to call [dispose] multiple times; subsequent calls are no-ops.
  /// However, it is best practice to call it exactly once when you're done with the renderer.
  ///
  /// Calling [dispose] prevents the finalizer from running when the object is garbage collected,
  /// allowing for immediate resource cleanup instead of waiting for the GC cycle.
  /// 
  /// Example:
  /// ```dart
  /// final renderer = Renderer();
  /// try {
  ///   // Use renderer...
  /// } finally {
  ///   renderer.dispose();
  /// }
  /// ```
  void dispose() {
    if (_ptr != nullptr) {
      _finalizer.detach(this);
      takumi_renderer_free(_ptr);
      _ptr = nullptr;
    }
  }

  /// Loads a font from in-memory bytes into the renderer's font context.
  ///
  /// This allows you to register custom fonts (WOFF2, TTF, etc.) with the renderer
  /// so they can be used in layout nodes via the `fontFamily` style property.
  ///
  /// Font data is copied into the renderer, so the original bytes can be discarded
  /// after calling this method.
  ///
  /// The [data] parameter is the raw font bytes (WOFF2, TTF, OTF, etc.). The
  /// optional [name] tells the renderer what family name to register the font
  /// under — if omitted the font's internal name will be used. The optional
  /// [weight] and [style] parameters let you override the font's intrinsic
  /// weight and style; if omitted the font's own metadata is used.
  ///
  /// Throws an exception if the font data is invalid or loading fails.
  ///
  /// Example:
  /// ```dart
  /// final renderer = Renderer();
  /// final fontBytes = await File('myfont.woff2').readAsBytes();
  /// renderer.loadFont(
  ///   fontBytes,
  ///   name: 'My Custom Font',
  ///   weight: .normal,
  /// );
  /// // Now use in nodes: Style(fontFamily: .of('My Custom Font'))
  /// ```
  void loadFont(
    Uint8List data, {
    String? name,
    FontWeight? weight,
    FontStyle? style,
  }) {
    double rawWeight = weight?.weight ?? -1.0;
    int rawStyle = style?.index ?? 255;

    Pointer<Uint8> dataPtr = nullptr;
    Pointer<Utf8>? namePtr;
    final dataLen = data.length;

    try {
      if (dataLen > 0) {
        dataPtr = malloc<Uint8>(dataLen);
        final nativeList = dataPtr.asTypedList(dataLen);
        nativeList.setAll(0, data);
      }

      if (name != null) {
        namePtr = name.toNativeUtf8();
      }

      final res = takumi_renderer_load_font(
        _ptr,
        dataPtr.cast<UnsignedChar>(),
        dataLen,
        namePtr?.cast<Char>() ?? nullptr.cast<Char>(),
        rawWeight,
        rawStyle,
      );

      if (res != 0) {
        final error = _getLastError();
        throw Exception('Failed to load font: $error');
      }
    } finally {
      if (dataPtr != nullptr) {
        malloc.free(dataPtr);
      }
      if (namePtr != null) {
        malloc.free(namePtr);
      }
    }
  }
}
