import 'dart:typed_data';

import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:vector_math/vector_math_64.dart';

import '../../core/models/human_pose.dart';

/// طبقة تشغيل لنموذج TFLite عام يعيد 17 نقطة.
///
/// لأن أوزان النموذج وتنسيق خرجه يختلفان حسب PoseNet/MoveNet/نموذج مخصص،
/// هذه الطبقة لا تفترض شبكة واحدة للصور. تستلم buffer الإدخال الجاهز وتحوّل
/// خرجاً مسطحاً من الشكل 17×3 أو 17×4 إلى HumanPose3D.
class Tflite17PoseAdapter {
  Tflite17PoseAdapter({this.assetPath = 'assets/models/pose_17.tflite'});

  final String assetPath;
  Interpreter? _interpreter;

  Future<void> load() async {
    final options = InterpreterOptions()..threads = 2;
    _interpreter = await Interpreter.fromAsset(assetPath, options: options);
  }

  bool get isLoaded => _interpreter != null;

  List<int> get inputShape {
    _ensureLoaded();
    return List<int>.from(_interpreter!.getInputTensor(0).shape);
  }

  List<int> get outputShape {
    _ensureLoaded();
    return List<int>.from(_interpreter!.getOutputTensor(0).shape);
  }

  /// يشغّل النموذج بعد تجهيز input وفق شكل النموذج نفسه.
  /// `input` يجب أن يحتوي بالضبط على عدد عناصر input tensor الأول.
  List<double> runRaw(Float32List input) {
    _ensureLoaded();
    final inputTensor = _interpreter!.getInputTensor(0);
    final expected = inputTensor.shape.fold<int>(1, (a, b) => a * b);
    if (input.length != expected) {
      throw ArgumentError(
        'حجم الإدخال ${input.length} لا يطابق المتوقع $expected (${inputTensor.shape})',
      );
    }

    final outputTensor = _interpreter!.getOutputTensor(0);
    final inputNested = _reshapeFlat(input, inputTensor.shape);
    final outputNested = _zeroTensor(outputTensor.shape);
    _interpreter!.run(inputNested, outputNested);
    return _flatten(outputNested);
  }

  HumanPose3D decodeToPose3D(
    List<double> output, {
    double depthScale = 1.0,
    double zOffset = -2.4,
  }) {
    if (output.length != 51 && output.length != 68) {
      throw ArgumentError(
        'خرج النموذج يجب أن يكون 51 (17×3) أو 68 (17×4) قيمة، وليس ${output.length}',
      );
    }

    final stride = output.length == 51 ? 3 : 4;
    final points = <PoseKeypoint>[];
    for (var i = 0; i < 17; i++) {
      final base = i * stride;
      final x = output[base];
      final y = output[base + 1];
      final z = output[base + 2] * depthScale + zOffset;
      final confidence = stride == 4 ? output[base + 3].clamp(0, 1) : 1.0;
      points.add(PoseKeypoint(
        position: Vector3(x, y, z),
        confidence: confidence,
      ));
    }
    return HumanPose3D(keypoints: points);
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }

  void _ensureLoaded() {
    if (_interpreter == null) {
      throw StateError('نموذج TFLite غير محمّل؛ نفّذ load() أولاً');
    }
  }
}

  dynamic _reshapeFlat(List<double> values, List<int> shape) {
    var offset = 0;

    dynamic build(int dimension) {
      if (dimension == shape.length - 1) {
        final count = shape[dimension];
        final result = values.sublist(offset, offset + count);
        offset += count;
        return result;
      }
      return List.generate(shape[dimension], (_) => build(dimension + 1));
    }

    return build(0);
  }

  dynamic _zeroTensor(List<int> shape) {
    if (shape.length == 1) return List<double>.filled(shape.first, 0);
    return List.generate(shape.first, (_) => _zeroTensor(shape.sublist(1)));
  }

  List<double> _flatten(dynamic value) {
    if (value is num) return [value.toDouble()];
    if (value is List) {
      return value.expand<double>((item) => _flatten(item)).toList(growable: false);
    }
    throw StateError('خرج TFLite غير قابل للتسطيح');
  }
}
