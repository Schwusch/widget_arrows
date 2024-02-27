library widget_arrows;

import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'arrows.dart';

class ArrowContainer extends StatefulWidget {
  final Widget child;

  /// [listenables] could be [ScrollController] and alike, in order for
  /// the arrows to repaint when moving in a scrollable widget.
  final List<Listenable> listenables;

  const ArrowContainer({
    Key? key,
    required this.child,
    this.listenables = const [],
  }) : super(key: key);

  @override
  ArrowContainerState createState() => ArrowContainerState();
}

abstract class StatePatched<T extends StatefulWidget> extends State<T> {
  void disposePatched() {
    super.dispose();
  }
}

class ArrowContainerState extends StatePatched<ArrowContainer>
    with ChangeNotifier {
  final _elements = <String, ArrowElementState>{};

  @override
  void dispose() {
    super.dispose();
    disposePatched();
  }

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          widget.child,
          IgnorePointer(
            child: CustomPaint(
              foregroundPainter: _ArrowPainter(
                _elements,
                Directionality.of(context),
                [this, ...widget.listenables],
              ),
              child: Container(),
            ),
          ),
        ],
      );

  void addArrow(ArrowElementState arrow) {
    _elements[arrow.widget.id] = arrow;
    notifyListeners();
  }

  void removeArrow(ArrowElementState arrow) {
    if (_elements[arrow.widget.id] == arrow) {
      _elements.remove(arrow.widget.id);
    }

    if (mounted) {
      notifyListeners();
    }
  }
}

class _ArrowPainter extends CustomPainter {
  final Map<String, ArrowElementState> _elements;
  final TextDirection _direction;

  _ArrowPainter(this._elements, this._direction, List<Listenable> repaint)
      : super(repaint: Listenable.merge(repaint));

  @override
  void paint(Canvas canvas, Size size) {
    for (final elem in _elements.values) {
      final widget = elem.widget;

      if (!widget.show) continue; // don't show/paint
      if (widget.targetId == null && widget.targetIds == null) {
        continue; // No target for arrow
      }

      List<String> targets;
      if (widget.targetIds == null) {
        targets = [widget.targetId!];
      } else {
        targets = widget.targetIds!;
      }

      for (final targetId in targets) {
        if (_elements[targetId] == null) {
          continue;
        }

        if (!elem.mounted || _elements[targetId]?.mounted != true) continue;

        final start = elem.context.findRenderObject() as RenderBox;
        final end =
            _elements[targetId]?.context.findRenderObject() as RenderBox;

        if (!start.attached || !end.attached) {
          continue; // Unable to draw
        }

        final containerRenderObject =
            elem._container?.context.findRenderObject();

        final startGlobalOffset = start.localToGlobal(
          Offset.zero,
          ancestor: containerRenderObject,
        );
        final endGlobalOffset = end.localToGlobal(
          Offset.zero,
          ancestor: containerRenderObject,
        );

        final startPosition = widget.sourceAnchor
            .resolve(_direction)
            .withinRect(Rect.fromLTWH(startGlobalOffset.dx,
                startGlobalOffset.dy, start.size.width, start.size.height));
        final endPosition = widget.targetAnchor.resolve(_direction).withinRect(
            Rect.fromLTWH(endGlobalOffset.dx, endGlobalOffset.dy,
                end.size.width, end.size.height));

        final arrow = getArrow(
          startPosition.dx,
          startPosition.dy,
          endPosition.dx,
          endPosition.dy,
          bow: widget.bow,
          stretch: widget.stretch,
          stretchMin: widget.stretchMin,
          stretchMax: widget.stretchMax,
          padStart: widget.padStart,
          padEnd: widget.padEnd,
          straights: widget.straights,
          flip: widget.flip,
          arcDirection: widget.arcDirection,
        );

        final path = _createPath(arrow, widget);
        // if (path == null) return;

        if (path != null) {
          final paint = Paint()
            ..color = widget.colors[targetId] ?? widget.color
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..strokeWidth = widget.width;

          canvas.drawPath(path, paint);
        }
      }
    }
  }

  Path? _createPath(Arrow arrow, ArrowElement widget) {
    final path = Path()
      ..moveTo(arrow.sx, arrow.sy)
      ..quadraticBezierTo(arrow.cx, arrow.cy, arrow.ex, arrow.ey);

    final metrics = path.computeMetrics().toList();
    // if (metrics.isEmpty) return null;

    if (metrics.isNotEmpty) {
      final lastPathMetric = metrics.last;
      final firstPathMetric = metrics.first;

      var tan = lastPathMetric.getTangentForOffset(lastPathMetric.length)!;
      var adjustmentAngle = 0.0;

      final tipLength = widget.tipLength;
      final tipAngleStart = widget.tipAngleOutwards;

      final angleStart = pi - tipAngleStart;
      final originalPosition = tan.position;

      if (lastPathMetric.length > 10) {
        final tanBefore =
            lastPathMetric.getTangentForOffset(lastPathMetric.length - 5)!;
        adjustmentAngle = _getAngleBetweenVectors(tan.vector, tanBefore.vector);
      }

      Offset tipVector;

      tipVector =
          _rotateVector(tan.vector, angleStart - adjustmentAngle) * tipLength;
      path.moveTo(tan.position.dx, tan.position.dy);
      path.relativeLineTo(tipVector.dx, tipVector.dy);

      tipVector =
          _rotateVector(tan.vector, -angleStart - adjustmentAngle) * tipLength;
      path.moveTo(tan.position.dx, tan.position.dy);
      path.relativeLineTo(tipVector.dx, tipVector.dy);

      if (widget.doubleSided) {
        tan = firstPathMetric.getTangentForOffset(0)!;
        if (firstPathMetric.length > 10) {
          final tanBefore = firstPathMetric.getTangentForOffset(5)!;
          adjustmentAngle =
              _getAngleBetweenVectors(tan.vector, tanBefore.vector);
        }

        tipVector = _rotateVector(-tan.vector, angleStart - adjustmentAngle) *
            tipLength;
        path.moveTo(tan.position.dx, tan.position.dy);
        path.relativeLineTo(tipVector.dx, tipVector.dy);

        tipVector = _rotateVector(-tan.vector, -angleStart - adjustmentAngle) *
            tipLength;
        path.moveTo(tan.position.dx, tan.position.dy);
        path.relativeLineTo(tipVector.dx, tipVector.dy);
      }

      path.moveTo(originalPosition.dx, originalPosition.dy);
      return path;
    }

    return null;
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
  bool shouldRepaint(_ArrowPainter oldDelegate) =>
      !mapEquals(oldDelegate._elements, _elements) ||
      _direction != oldDelegate._direction;
}

class ArrowElement extends StatefulWidget {
  /// Whether to show the arrow
  final bool show;

  /// ID for being targeted by other [ArrowElement]s
  final String id;

  /// The ID of the [ArrowElement] that will be drawn to
  final String? targetId;

  /// A List of IDs of [ArrowElement] that will be drawn to
  final List<String>? targetIds;

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

  /// Arrow color
  final Map<String, Color> colors;

  /// Arrow width
  final double width;

  /// Length of arrow tip
  final double tipLength;

  /// Outwards angle of arrow tip, in radians
  final double tipAngleOutwards;

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
  /// Only used if [arcRotation] is [ArcDirection.Auto]
  final bool flip;

  /// Whether to use straight lines at 45 degree angles.
  final bool straights;

  /// If arrow is not straight, which direction the arc should follow
  final ArcDirection arcDirection;

  const ArrowElement({
    Key? key,
    required this.id,
    required this.child,
    this.targetId,
    this.targetIds,
    this.show = true,
    this.sourceAnchor = Alignment.centerLeft,
    this.targetAnchor = Alignment.centerLeft,
    this.doubleSided = false,
    this.color = Colors.blue,
    this.colors = const {},
    this.width = 3,
    this.tipLength = 15,
    this.tipAngleOutwards = pi * 0.2,
    this.bow = 0.2,
    this.stretchMin = 0,
    this.stretchMax = 420,
    this.stretch = 0.5,
    this.padStart = 0,
    this.padEnd = 0,
    this.flip = false,
    this.straights = true,
    this.arcDirection = ArcDirection.Auto,
  })  : assert(targetId == null || targetIds == null),
        super(key: key);

  @override
  ArrowElementState createState() => ArrowElementState();
}

class ArrowElementState extends State<ArrowElement> {
  ArrowContainerState? _container;

  @override
  void initState() {
    super.initState();
    findContainerAndAddOneself();
  }

  @override
  void didUpdateWidget(ArrowElement oldWidget) {
    super.didUpdateWidget(oldWidget);
    findContainerAndAddOneself();
  }

  void findContainerAndAddOneself() {
    _container = context.findAncestorStateOfType<ArrowContainerState>()
      ?..addArrow(this);
  }

  @override
  void deactivate() {
    _container?.removeArrow(this);
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
