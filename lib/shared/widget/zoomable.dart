import 'dart:math';

import 'package:e1547/shared/shared.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

const double zoomMin = 1;
const double zoomReach = 6;
const double zoomSnap = 0.08;
const double zoomStep = 2.5;
const double edgeSlack = 0.5;
const double edgeDragDecision = 4;

Rect? containedRect(Size content, Size size) {
  if (content.isEmpty || size.isEmpty) return null;
  final FittedSizes fitted = applyBoxFit(BoxFit.contain, content, size);
  return Alignment.center.inscribe(fitted.destination, Offset.zero & size);
}

class ZoomController extends ChangeNotifier {
  final TransformationController transformation = TransformationController();

  double _scale = zoomMin;

  double get scale => _scale;

  bool get isZoomed => _scale > zoomMin + zoomSnap;

  void _read() {
    final double next = transformation.value.getMaxScaleOnAxis();
    if ((next - _scale).abs() < 0.001) return;
    _scale = next;
    notifyListeners();
  }

  @override
  void dispose() {
    transformation.dispose();
    super.dispose();
  }
}

class Zoomable extends StatefulWidget {
  const Zoomable({
    super.key,
    required this.child,
    required this.controller,
    required this.content,
    this.pan,
    this.onTap,
    this.onSpare,
    this.onSpareEnd,
    this.onSpareCancel,
  });

  final Widget child;
  final ZoomController controller;
  final Size content;
  final GalleryPanController? pan;
  final VoidCallback? onTap;
  final void Function(Offset spare)? onSpare;
  final void Function(Velocity velocity)? onSpareEnd;
  final VoidCallback? onSpareCancel;

  @override
  State<Zoomable> createState() => _ZoomableState();
}

class _ZoomableState extends State<Zoomable>
    with SingleTickerProviderStateMixin {
  late final AnimationController animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );
  Animation<Matrix4>? _flight;
  TapDownDetails? _lastTap;

  TransformationController get transformation =>
      widget.controller.transformation;

  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    transformation.addListener(_clamp);
    transformation.addListener(widget.controller._read);
    widget.controller.addListener(_onZoom);
    animation.addListener(_onFlight);
  }

  @override
  void dispose() {
    transformation.removeListener(_clamp);
    transformation.removeListener(widget.controller._read);
    widget.controller.removeListener(_onZoom);
    animation
      ..removeListener(_onFlight)
      ..dispose();
    super.dispose();
  }

  void _onZoom() {
    final bool zoomed = widget.controller.isZoomed;
    if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
  }

  void _onFlight() {
    if (_flight case final Animation<Matrix4> value) {
      transformation.value = value.value;
    }
  }

  void _settle() {
    if (widget.controller.isZoomed) return;
    if (transformation.value == Matrix4.identity()) return;
    _fly(Matrix4.identity());
  }

  void _fly(Matrix4 target) {
    _flight = Matrix4Tween(
      begin: transformation.value,
      end: target,
    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
    animation.forward(from: 0);
  }

  Size get _viewport {
    final RenderObject? box = context.findRenderObject();
    return box is RenderBox && box.hasSize ? box.size : Size.zero;
  }

  Rect _contentIn(Size viewport) =>
      containedRect(widget.content, viewport) ?? Rect.zero;

  double _coverIn(Size viewport) {
    final Rect content = _contentIn(viewport);
    if (content.isEmpty) return zoomMin;
    return max(
      viewport.width / content.width,
      viewport.height / content.height,
    );
  }

  Matrix4 _clamped(Matrix4 matrix, Size viewport) {
    final Rect content = _contentIn(viewport);
    if (content.isEmpty) return matrix;
    final double scale = matrix.getMaxScaleOnAxis();
    final Offset shift = MatrixUtils.transformPoint(matrix, Offset.zero);
    double axis(double shift, double begin, double end, double extent) {
      if ((end - begin) * scale <= extent) {
        return extent / 2 - (begin + end) / 2 * scale;
      }
      return shift.clamp(extent - end * scale, -begin * scale);
    }

    final Offset next = Offset(
      axis(shift.dx, content.left, content.right, viewport.width),
      axis(shift.dy, content.top, content.bottom, viewport.height),
    );
    if ((next - shift).distance < 0.01) return matrix;
    return matrix.clone()..setTranslationRaw(next.dx, next.dy, 0);
  }

  void _clamp() {
    final Matrix4 clamped = _clamped(transformation.value, _viewport);
    if (!identical(clamped, transformation.value)) {
      transformation.value = clamped;
    }
  }

  void _cycle() {
    if (widget.controller.isZoomed) return _fly(Matrix4.identity());
    final Size viewport = _viewport;
    final Rect content = _contentIn(viewport);
    final double cover = _coverIn(viewport);
    final double next = max(cover, zoomStep).clamp(zoomMin, cover * zoomReach);
    Offset focus = _lastTap?.localPosition ?? viewport.center(Offset.zero);
    if (!content.contains(focus)) focus = content.center;
    final Offset shift = focus * (1 - next);
    _fly(
      Matrix4.identity()
        ..translateByDouble(shift.dx, shift.dy, 0, 1)
        ..scaleByDouble(next, next, 1, 1),
    );
  }

  Offset get _shift =>
      MatrixUtils.transformPoint(transformation.value, Offset.zero);

  Offset? _panned;
  bool _fromTop = false;
  bool _fromBottom = false;

  bool _pinned(Axis axis, {required bool leading}) {
    final Size viewport = _viewport;
    final Rect content = _contentIn(viewport);
    final double scale = widget.controller.scale;
    final (
      double shift,
      double begin,
      double end,
      double extent,
    ) = switch (axis) {
      Axis.horizontal => (
        _shift.dx,
        content.left,
        content.right,
        viewport.width,
      ),
      Axis.vertical => (
        _shift.dy,
        content.top,
        content.bottom,
        viewport.height,
      ),
    };
    if (leading) return shift >= -scale * begin - edgeSlack;
    return shift <= extent - scale * end + edgeSlack;
  }

  bool _outward(double dx) => _pinned(Axis.horizontal, leading: dx > 0);

  void _onStart(ScaleStartDetails details) {
    _panned = _shift;
    _fromTop = _pinned(Axis.vertical, leading: true);
    _fromBottom = _pinned(Axis.vertical, leading: false);
  }

  void _onUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount != 1 || details.scale != 1) {
      _panned = null;
      return;
    }
    final Offset moved = _shift;
    if (widget.controller.isZoomed) {
      _panned = moved;
      return;
    }
    if (_panned case final Offset last) {
      final Offset spare = details.focalPointDelta - (moved - last);
      final bool allowed = spare.dy > 0
          ? _fromTop
          : spare.dy < 0 && _fromBottom;
      if (allowed) widget.onSpare?.call(spare);
    }
    _panned = moved;
  }

  void _onEnd(ScaleEndDetails details) {
    _panned = null;
    _settle();
    if (details.pointerCount > 0) {
      widget.onSpareCancel?.call();
    } else {
      widget.onSpareEnd?.call(details.velocity);
    }
  }

  @override
  Widget build(BuildContext context) {
    final GalleryPanController? pan = widget.pan;
    return GestureDetector(
      onTap: widget.onTap,
      onDoubleTapDown: (details) => _lastTap = details,
      onDoubleTap: _cycle,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final Size viewport = constraints.biggest;
          return InteractiveViewer(
            transformationController: transformation,
            onInteractionStart: _onStart,
            onInteractionUpdate: _onUpdate,
            onInteractionEnd: _onEnd,
            boundaryMargin: const EdgeInsets.all(double.infinity),
            minScale: zoomMin,
            maxScale: _coverIn(viewport) * zoomReach,
            clipBehavior: Clip.none,
            child: RawGestureDetector(
              behavior: HitTestBehavior.opaque,
              gestures: {
                if (pan != null && _zoomed)
                  EdgeDragGestureRecognizer:
                      GestureRecognizerFactoryWithHandlers<
                        EdgeDragGestureRecognizer
                      >(
                        () => EdgeDragGestureRecognizer(
                          outward: _outward,
                          onUpdate: pan.push,
                          onEnd: pan.release,
                        ),
                        (recognizer) {},
                      ),
              },
              child: widget.child,
            ),
          );
        },
      ),
    );
  }
}

class EdgeDragGestureRecognizer extends OneSequenceGestureRecognizer {
  EdgeDragGestureRecognizer({
    required this.outward,
    required this.onUpdate,
    required this.onEnd,
  });

  final bool Function(double dx) outward;
  final ValueChanged<double> onUpdate;
  final ValueChanged<double> onEnd;

  Offset _travel = Offset.zero;
  bool _accepted = false;
  VelocityTracker? _velocity;
  int? _pointer;

  @override
  String get debugDescription => 'edge drag';

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (_pointer != null) return;
    _pointer = event.pointer;
    super.addAllowedPointer(event);
    _travel = Offset.zero;
    _accepted = false;
    _velocity = VelocityTracker.withKind(event.kind)
      ..addPosition(event.timeStamp, event.position);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent) {
      _velocity?.addPosition(event.timeStamp, event.position);
      if (_accepted) {
        onUpdate(event.delta.dx);
        return;
      }
      _travel += event.delta;
      if (_travel.distance < edgeDragDecision) return;
      final bool sideways = _travel.dx.abs() > _travel.dy.abs();
      resolve(
        sideways && outward(_travel.dx)
            ? GestureDisposition.accepted
            : GestureDisposition.rejected,
      );
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      if (_accepted) {
        onEnd(_velocity?.getVelocity().pixelsPerSecond.dx ?? 0);
      } else {
        resolve(GestureDisposition.rejected);
      }
      _pointer = null;
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  void acceptGesture(int pointer) {
    _accepted = true;
    onUpdate(_travel.dx);
  }

  @override
  void rejectGesture(int pointer) {
    _pointer = null;
    stopTrackingPointer(pointer);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}
}
