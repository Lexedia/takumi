import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:takumi/src/models/node.dart';
import 'package:takumi/src/models/options.dart';

import './ffi/takumi.g.dart' hide Renderer;
import './ffi/takumi.g.dart' as takumi show Renderer;

/// A frame in an animation consisting of a [Node] and its display [duration].
typedef Frame = (Node node, Duration duration);

/// A list of frames for an animation.
typedef Frames = List<Frame>;

/// The renderer for
class Renderer {
  Pointer<takumi.Renderer> _ptr;

  Renderer._(this._ptr);

  factory Renderer() {
    final ptr = takumi_renderer_new();
    if (ptr == nullptr) {
      throw Exception('Failed to create Renderer');
    }
    return Renderer._(ptr);
  }

  /// Render [node] with [options] asynchronously by delegating the render to a background task.
  Future<Uint8List> render(Node node, [RenderOptions? options]) async {
    options ??= const RenderOptions();
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
        final error = takumi_last_error().cast<Utf8>().toDartString();
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
          final error = takumi_last_error().cast<Utf8>().toDartString();
          throw Exception('Render error: $error');
        }

        await Future.delayed(const Duration(milliseconds: 10));
      } finally {
        malloc.free(outLen);
        malloc.free(outStatus);
      }
    }
  }

  /// Synchronously block the main thread and render [node] with [options] to an image.
  Uint8List renderSync(Node node, [RenderOptions? options]) {
    options ??= const RenderOptions();
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
        final error = takumi_last_error().cast<Utf8>().toDartString();
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

  /// Synchronously render an animation from [frames] with [options].
  Uint8List renderAnimationSync(
    Frames frames,
    [RenderAnimationOptions? options]
  ) {
    options ??= const RenderAnimationOptions();
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
        final error = takumi_last_error().cast<Utf8>().toDartString();
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

  /// Render an animation from [frames] with [options] asynchronously by delegating the render to a background task.
  Future<Uint8List> renderAnimation(
    Frames frames,
    [RenderAnimationOptions? options]
  ) async {
    options ??= const RenderAnimationOptions();
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
        final error = takumi_last_error().cast<Utf8>().toDartString();
        throw Exception('Failed to start animation render: $error');
      }

      return _pollRenderTask(taskId);
    } finally {
      malloc.free(framesPtr);
      malloc.free(optionsPtr);
    }
  }

  /// Frees the underlying native renderer.
  /// After calling this, the Renderer instance should not be used again.
  void dispose() {
    if (_ptr != nullptr) {
      takumi_renderer_free(_ptr);
      _ptr = nullptr;
    }
  }
}
