import 'dart:math';

enum ArcDirection { Left, Right, Auto }

Arrow getArrow(
  double x0,
  double y0,
  double x1,
  double y1, {
  double bow = 0,
  double stretchMin = 0,
  double stretchMax = 420,
  double stretch = 0.5,
  double padStart = 0,
  double padEnd = 0,
  bool flip = false,
  bool straights = true,
  ArcDirection arcDirection = ArcDirection.Auto,
}) {
  final angle = getAngle(x0, y0, x1, y1);
  final dist = getDistance(x0, y0, x1, y1);
  final angles = getAngliness(x0, y0, x1, y1);

  // Step 0 ⤜⤏ Should the arrow be straight?

  if (dist < (padStart + padEnd) * 2 || // Too short
          (bow == 0 && stretch == 0) || // No bow, no stretch
          (straights &&
              [0.0, 1.0, double.infinity].contains(angles)) // 45 degree angle
      ) {
    // ⤜⤏ Arrow is straight! Just pad start and end points.

    // Padding distances
    final ps = max(0.0, min(dist - padStart, padStart));
    final pe = max(0.0, min(dist - ps, padEnd));

    // Move start point toward end point
    var pp0 = projectPoint(x0, y0, angle, ps);
    final px0 = pp0.first;
    final py0 = pp0.last;

    // Move end point toward start point
    final pp1 = projectPoint(x1, y1, angle + pi, pe);
    final px1 = pp1.first;
    final py1 = pp1.last;

    // Get midpoint between new points
    final pb = getPointBetween(px0, py0, px1, py1);
    final mx = pb.first;
    final my = pb.last;

    return Arrow(px0, py0, mx, my, px1, py1);
  }

  final downWards = y0 < y1;

  // ⤜⤏ Arrow is an arc!
  int rot;
  if (arcDirection == ArcDirection.Auto) {
    // Is the arc clockwise or counterclockwise?
    rot = (getSector(angle) % 2 == 0 ? 1 : -1) * (flip ? -1 : 1);
  } else if (arcDirection == ArcDirection.Left) {
    rot = downWards ? -1 : 1;
  } else {
    rot = downWards ? 1 : -1;
  }

  // Calculate how much the line should "bow" away from center
  final arc =
      bow + mod(dist, [stretchMin, stretchMax], [1, 0], clamp: true) * stretch;

  // Step 1 ⤜⤏ Find padded points.

  // Get midpoint.
  final mp = getPointBetween(x0, y0, x1, y1);

  final mx = mp.first;
  final my = mp.last;

  // Get control point.
  final cp = getPointBetween(x0, y0, x1, y1, d: 0.5 - arc);
  var cx = cp.first;
  var cy = cp.last;

  // Rotate control point (clockwise or counterclockwise).
  final rcp = rotatePoint(cx, cy, mx, my, (pi / 2) * rot);
  cx = rcp.first;
  cy = rcp.last;

  // Get padded start point.
  final a0 = getAngle(x0, y0, cx, cy);
  final psp = projectPoint(x0, y0, a0, padStart);
  final px0 = psp.first;
  final py0 = psp.last;

  // Get padded end point.
  final a1 = getAngle(x1, y1, cx, cy);
  final pep = projectPoint(x1, y1, a1, padEnd);
  final px1 = pep.first;
  final py1 = pep.last;

  // Step 3 ⤜⤏ Find control point for padded points.

  // Get midpoint between padded start / end points.
  final pmp = getPointBetween(px0, py0, px1, py1);
  final mx1 = pmp.first;
  final my1 = pmp.last;

  // Get control point for padded start / end points.
  final pcp = getPointBetween(px0, py0, px1, py1, d: 0.5 - arc);
  var cx1 = pcp.first;
  var cy1 = pcp.last;

  // Rotate control point (clockwise or counterclockwise).
  final rpcp = rotatePoint(cx1, cy1, mx1, my1, (pi / 2) * rot);
  cx1 = rpcp.first;
  cy1 = rcp.last;

  // Finally, average the two control points.
  final acp = getPointBetween(cx, cy, cx1, cy1);
  final cx2 = acp.first;
  final cy2 = acp.last;

  return Arrow(px0, py0, cx2, cy2, px1, py1);
}

class Arrow {
  /// The x position of the (padded) starting point.
  final double sx,

      /// The y position of the (padded) starting point.
      sy,

      /// The x position of the (padded) control point.
      cx,

      /// The y position of the (padded) control point.
      cy,

      /// The x position of the (padded) ending point.
      ex,

      /// The y position of the (padded) ending point.
      ey;

  Arrow(
    this.sx,
    this.sy,
    this.cx,
    this.cy,
    this.ex,
    this.ey,
  );
}

/// Modulate a value between two ranges
double mod(double value, List<double> a, List<double> b, {bool clamp = false}) {
  final lh = b[0] < b[1] ? [b[0], b[1]] : [b[1], b[0]];
  final result = b[0] + ((value - a[0]) / (a[1] - b[0])) * (b[1] - b[0]);

  if (clamp) {
    if (result < lh.first) return lh.first;
    if (result > lh.last) return lh.last;
  }

  return result;
}

/// Rotate a point around a center.
List<double> rotatePoint(
    double x, double y, double cx, double cy, double angle) {
  final s = sin(angle);
  final c = cos(angle);
  final px = x - cx;
  final py = y - cy;

  final nx = px * c - py * s;
  final ny = px * s + py * c;

  return [nx + cx, ny + cy];
}

/// Get the distance between two points.
double getDistance(double x0, double y0, double x1, double y1) =>
    sqrt(pow(y1 - y0, 2) + pow(x1 - x0, 2));

/// Get an angle (radians) between two points.
double getAngle(double x0, double y0, double x1, double y1) =>
    atan2(y1 - y0, x1 - x0);

/// Move a point in an angle by a distance.
List<double> projectPoint(
        double x0, double y0, double angle, double distance) =>
    [cos(angle) * distance + x0, sin(angle) * distance + y0];

/// Get a point between two points.
List<double> getPointBetween(
  double x0,
  double y0,
  double x1,
  double y1, {
  double d = 0.5,
}) =>
    [x0 + (x1 - x0) * d, y0 + (y1 - y0) * d];

/// Get the sector of an angle (e.g. quadrant, octant)
int getSector(double angle, {double doubleberOfSectors = 8}) =>
    (doubleberOfSectors * (0.5 + ((angle / (pi * 2)) % doubleberOfSectors)))
        .floor();

/// Get a normal value representing how close two points are from being at a 45 degree angle.
double getAngliness(double x0, double y0, double x1, double y1) =>
    ((x1 - x0) / 2 / ((y1 - y0) / 2)).abs();
