library widget_arrows;

import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:widget_arrows/arrows.dart';

class ArrowContainer extends StatefulWidget {
  final Widget child;

  const ArrowContainer({Key key, this.child}) : super(key: key);

  @override
  _ArrowContainerState createState() => _ArrowContainerState();
}

class _ArrowContainerState extends State<ArrowContainer> {
  final _elements = <String, ArrowNotification>{};
  ValueNotifier<Map<String, ArrowNotification>> _notifier;

  _ArrowContainerState() {
    _notifier = ValueNotifier(_elements);
  }

  @override
  void dispose() {
    _notifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ArrowDisposeNotification>(
        onNotification: (disposeMe) {
          _notifier.value = Map.from(_elements..remove(disposeMe.id));
          return true;
        },
        child: NotificationListener<ArrowNotification>(
          onNotification: (notification) {
            _notifier.value =
                Map.from(_elements..[notification.id] = notification);
            return true;
          },
          child: Stack(
            children: [
              widget.child,
              IgnorePointer(
                child: ValueListenableBuilder<Map<String, ArrowNotification>>(
                  valueListenable: _notifier,
                  builder: (_, elements, __) => CustomPaint(
                    painter: ArrowPainter(elements, Directionality.of(context)),
                    child: Container(),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class ArrowPainter extends CustomPainter {
  final Map<String, ArrowNotification> _elements;
  final TextDirection _direction;

  ArrowPainter(this._elements, this._direction);

  @override
  void paint(Canvas canvas, Size size) => _elements.values.forEach((elem) {
        if (!elem.show) return; // don't show/paint
        if (elem.targetId == null &&
            elem.id == null &&
            _elements[elem.targetId] == null) {
          return; // Unable to draw
        }

        final start = elem.key.currentContext?.findRenderObject() as RenderBox;
        final end = _elements[elem.targetId]
            ?.key
            ?.currentContext
            ?.findRenderObject() as RenderBox;

        if (start == null || end == null) return; // Unable to draw

        final startGlobalOffset = start.localToGlobal(Offset.zero);
        final endGlobalOffset = end.localToGlobal(Offset.zero);

        final startPosition = elem.sourceAnchor.resolve(_direction).withinRect(
            Rect.fromLTWH(startGlobalOffset.dx, startGlobalOffset.dy,
                start.size.width, start.size.height));
        final endPosition = elem.targetAnchor.resolve(_direction).withinRect(
            Rect.fromLTWH(endGlobalOffset.dx, endGlobalOffset.dy,
                end.size.width, end.size.height));

        final paint = Paint()
          ..color = elem.color
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = elem.width;

        final arrow = getArrow(
          startPosition.dx,
          startPosition.dy,
          endPosition.dx,
          endPosition.dy,
          bow: elem.bow,
          stretch: elem.stretch,
          stretchMin: elem.stretchMin,
          stretchMax: elem.stretchMax,
          padStart: elem.padStart,
          padEnd: elem.padEnd,
          straights: elem.straights,
          flip: elem.flip,
        );
        final path = Path()
          ..moveTo(arrow.sx, arrow.sy)
          ..quadraticBezierTo(arrow.cx, arrow.cy, arrow.ex, arrow.ey);

        makeArrowTip(
          path: path,
          isDoubleSided: elem.isDoubleSided,
        );

        canvas.drawPath(path, paint);
      });

  static void makeArrowTip({
    @required Path path,
    double tipLength = 15,
    double tipAngleStart = pi * 0.2,
    bool isDoubleSided = false,
    bool isAdjusted = true,
  }) {
    PathMetric lastPathMetric;
    PathMetric firstPathMetric;
    Offset tipVector;
    Tangent tan;
    var adjustmentAngle = 0.0;

    final angleStart = pi - tipAngleStart;
    lastPathMetric = path.computeMetrics().last;
    if (isDoubleSided) {
      firstPathMetric = path.computeMetrics().first;
    }

    tan = lastPathMetric.getTangentForOffset(lastPathMetric.length);

    final originalPosition = tan.position;

    if (isAdjusted && lastPathMetric.length > 10) {
      final tanBefore =
          lastPathMetric.getTangentForOffset(lastPathMetric.length - 5);
      adjustmentAngle = _getAngleBetweenVectors(tan.vector, tanBefore.vector);
    }

    tipVector =
        _rotateVector(tan.vector, angleStart - adjustmentAngle) * tipLength;
    path.moveTo(tan.position.dx, tan.position.dy);
    path.relativeLineTo(tipVector.dx, tipVector.dy);

    tipVector =
        _rotateVector(tan.vector, -angleStart - adjustmentAngle) * tipLength;
    path.moveTo(tan.position.dx, tan.position.dy);
    path.relativeLineTo(tipVector.dx, tipVector.dy);

    if (isDoubleSided) {
      tan = firstPathMetric.getTangentForOffset(0);
      if (isAdjusted && firstPathMetric.length > 10) {
        final tanBefore = firstPathMetric.getTangentForOffset(5);
        adjustmentAngle = _getAngleBetweenVectors(tan.vector, tanBefore.vector);
      }

      tipVector =
          _rotateVector(-tan.vector, angleStart - adjustmentAngle) * tipLength;
      path.moveTo(tan.position.dx, tan.position.dy);
      path.relativeLineTo(tipVector.dx, tipVector.dy);

      tipVector =
          _rotateVector(-tan.vector, -angleStart - adjustmentAngle) * tipLength;
      path.moveTo(tan.position.dx, tan.position.dy);
      path.relativeLineTo(tipVector.dx, tipVector.dy);
    }

    path.moveTo(originalPosition.dx, originalPosition.dy);
  }

  static Offset _rotateVector(Offset vector, double angle) => Offset(
        cos(angle) * vector.dx - sin(angle) * vector.dy,
        sin(angle) * vector.dx + cos(angle) * vector.dy,
      );

  static double _getVectorsDotProduct(Offset vector1, Offset vector2) =>
      vector1.dx * vector2.dx + vector1.dy * vector2.dy;

  // Clamp to avoid rounding issues when the 2 vectors are equal.
  static double _getAngleBetweenVectors(Offset vector1, Offset vector2) =>
      acos((_getVectorsDotProduct(vector1, vector2) /
              (vector1.distance * vector2.distance))
          .clamp(-1.0, 1.0));

  @override
  bool shouldRepaint(ArrowPainter oldDelegate) =>
      !mapEquals(oldDelegate._elements, _elements) ||
      _direction != oldDelegate._direction;
}

class ArrowElement extends StatefulWidget {
  /// Whether to show the arrow
  final bool show;

  /// ID for being targeted by other [ArrowElement]s
  final String id;

  /// The ID of the [ArrowElement] that will be drawn to
  final String targetId;

  /// Where on the source Widget the arrow should start
  final AlignmentGeometry sourceAnchor;

  /// Where on the target Widget the arrow should end
  final AlignmentGeometry targetAnchor;

  /// A [Widget] to be drawn to or from
  final Widget child;

  /// Whether the arrow should be pointed both ways
  final bool doubleSided;

  /// Arrow color
  final Color color;

  /// Arrow width
  final double width;

  /// A value representing the natural bow of the arrow.
  /// At 0, all lines will be straight.
  final double bow;

  /// The length of the arrow where the line should be most stretched. Shorter
  /// distances than 0 will have no additional effect on the bow of the arrow.
  final double stretchMin;

  /// The length of the arrow at which the stretch should have no effect.
  final double stretchMax;

  /// The effect that the arrow's length will have, relative to its minStretch
  /// and maxStretch, on the bow of the arrow. At 0, the stretch will have no effect.
  final double stretch;

  /// How far the arrow's starting point should be from the provided start point.
  final double padStart;

  /// How far the arrow's ending point should be from the provided end point.
  final double padEnd;

  /// Whether to reflect the arrow's bow angle.
  final bool flip;

  /// Whether to use straight lines at 45 degree angles.
  final bool straights;

  const ArrowElement({
    Key key,
    @required this.id,
    @required this.child,
    this.targetId,
    this.show = true,
    this.sourceAnchor = Alignment.centerLeft,
    this.targetAnchor = Alignment.centerLeft,
    this.doubleSided = false,
    this.color = Colors.blue,
    this.width = 3,
    this.bow = 0.2,
    this.stretchMin = 0,
    this.stretchMax = 420,
    this.stretch = 0.5,
    this.padStart = 0,
    this.padEnd = 0,
    this.flip = false,
    this.straights = true,
  }) : super(key: key);

  @override
  _ArrowElementState createState() => _ArrowElementState(id);
}

class _ArrowElementState extends State<ArrowElement> {
  final GlobalObjectKey _key;

  _ArrowElementState(String id) : _key = GlobalObjectKey(id);

  @override
  Widget build(BuildContext context) {
    ArrowNotification(
      show: widget.show,
      id: widget.id,
      targetId: widget.targetId,
      sourceAnchor: widget.sourceAnchor,
      targetAnchor: widget.targetAnchor,
      key: _key,
      isDoubleSided: widget.doubleSided,
      color: widget.color,
      width: widget.width,
      bow: widget.bow,
      stretchMin: widget.stretchMin,
      stretchMax: widget.stretchMax,
      stretch: widget.stretch,
      padStart: widget.padStart,
      padEnd: widget.padEnd,
      flip: widget.flip,
      straights: widget.straights,
    )..dispatch(context);
    return Container(
      key: _key,
      child: widget.child,
    );
  }
}

class ArrowDisposeNotification extends Notification {
  final String id;

  ArrowDisposeNotification(this.id);
}

class ArrowNotification extends Notification {
  final bool show;
  final GlobalKey key;
  final String id;
  final String targetId;
  final AlignmentGeometry sourceAnchor;
  final AlignmentGeometry targetAnchor;
  final bool isDoubleSided;
  final Color color;
  final double width;
  final double bow;
  final double stretchMin;
  final double stretchMax;
  final double stretch;
  final double padStart;
  final double padEnd;
  final bool flip;
  final bool straights;

  const ArrowNotification({
    this.show,
    this.key,
    this.id,
    this.targetId,
    this.sourceAnchor,
    this.targetAnchor,
    this.isDoubleSided,
    this.color,
    this.width,
    this.bow,
    this.stretchMin,
    this.stretchMax,
    this.stretch,
    this.padStart,
    this.padEnd,
    this.flip,
    this.straights,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ArrowNotification &&
          show == other.show &&
          runtimeType == other.runtimeType &&
          key == other.key &&
          id == other.id &&
          targetId == other.targetId &&
          sourceAnchor == other.sourceAnchor &&
          targetAnchor == other.targetAnchor &&
          isDoubleSided == other.isDoubleSided &&
          color == other.color &&
          width == other.width &&
          bow == other.bow &&
          stretchMin == other.stretchMin &&
          stretchMax == other.stretchMax &&
          stretch == other.stretch &&
          padStart == other.padStart &&
          padEnd == other.padEnd &&
          flip == other.flip &&
          straights == other.straights;

  @override
  int get hashCode =>
      show.hashCode ^
      key.hashCode ^
      id.hashCode ^
      targetId.hashCode ^
      sourceAnchor.hashCode ^
      targetAnchor.hashCode ^
      isDoubleSided.hashCode ^
      color.hashCode ^
      width.hashCode ^
      bow.hashCode ^
      stretchMin.hashCode ^
      stretchMax.hashCode ^
      stretch.hashCode ^
      padStart.hashCode ^
      padEnd.hashCode ^
      flip.hashCode ^
      straights.hashCode;
}
