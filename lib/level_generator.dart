import 'dart:math';
import 'difficulty.dart';
import 'gravity_packer.dart';
import 'hand_levels.dart';
import 'models.dart';
import 'rng.dart';

/// Procedural, deterministic, GUARANTEED-solvable level generator.
///
/// Tuned to match the reference game (analysed across 99 levels + 28 daily
/// challenges): board SIZE and arrow DENSITY scale smoothly with the level —
/// that is the real difficulty driver. The tier LABEL (Normal/Hard/Super
/// Hard/Nightmare) is mostly cosmetic and only nudges arrow length/density.
///
/// Arrows are long winding maze paths (the reference's signature look): Normal
/// levels use the longest, windiest arrows; harder tiers pack denser/shorter.
/// Every board fills to ~100% with no isolated stubs where avoidable.
class LevelGenerator {
  int cols = 9, rows = 11;

  // Arrow-shape controls (set per level/tier in [_configure]).
  int _walkMin = 4, _walkMax = 8;
  double _straightBias = 0.6; // higher = straighter; lower = windier

  // Shape mask: if non-null, only cells in this set are valid. Affects all
  // packing, gap-fill, and solvability checks via _inB.
  Set<String>? _shapeMask;

  bool _inB(int x, int y) {
    if (x < 0 || x > cols || y < 0 || y > rows) return false;
    if (_shapeMask != null) return _shapeMask!.contains(cellKey(x, y));
    return true;
  }

  // ── Shape masks ──

  /// Shaped levels cycle every 5-6-7 levels from L16 to L99.
  static const _shapeLevels = <int, String>{
    16: 'circle', 21: 'heart', 27: 'diamond', 34: 'triangle',
    39: 'star', 45: 'cross', 52: 'hexagon', 57: 'pentagon',
    63: 'crescent', 70: 'clover', 75: 'bolt', 81: 'octagon', 88: 'circle',
    93: 'flower', 99: 'peach',
    // L100+ shapes use the gravity packer (see _gravityShapes).
    104: 'shield', 112: 'teardrop', 120: 'kite', 128: 'house',
    136: 'egg', 144: 'dome', 152: 'arrow', 160: 'crown', 168: 'tree',
  };

  /// Shapes generated with [GravityPacker] (100% fill, solvable by
  /// construction, fast generation) instead of RC packing.
  static const _gravityShapes = <String>{
    'shield', 'teardrop', 'kite', 'house', 'egg', 'dome', 'arrow', 'crown',
    'tree',
  };

  /// Builds a shape mask for the current grid, or null for rectangular.
  Set<String>? _buildShapeMask(String shape) {
    final cx = cols / 2.0, cy = rows / 2.0;
    final rx = cols / 2.0, ry = rows / 2.0;
    final mask = <String>{};

    switch (shape) {
      case 'circle':
        for (var y = 0; y <= rows; y++) {
          for (var x = 0; x <= cols; x++) {
            final dx = (x - cx) / rx, dy = (y - cy) / ry;
            if (dx * dx + dy * dy <= 1.05) mask.add(cellKey(x, y));
          }
        }
      case 'heart':
        for (var y = 0; y <= rows; y++) {
          for (var x = 0; x <= cols; x++) {
            final nx = (x - cx) / rx;
            final ny = (y - cy) / ry;
            // Top: two large bumps with gentle notch (the version that worked)
            if (ny < -0.1) {
              final t = (ny + 0.1) / 0.9;
              final lx = nx + 0.50;
              final rx2 = nx - 0.50;
              final r = 0.55;
              final inLeft = lx * lx + t * t * 0.8 <= r * r;
              final inRight = rx2 * rx2 + t * t * 0.8 <= r * r;
              if (inLeft || inRight) mask.add(cellKey(x, y));
            } else {
              // Bottom: sharper point (quadratic narrowing)
              final t = (ny + 0.1) / 1.1;
              final halfW = 1.05 * (1.0 - t * t * 0.4 - t * 0.6);
              if (nx.abs() <= halfW.clamp(0, 1)) mask.add(cellKey(x, y));
            }
          }
        }
      case 'diamond':
        for (var y = 0; y <= rows; y++) {
          for (var x = 0; x <= cols; x++) {
            final dx = (x - cx).abs() / rx, dy = (y - cy).abs() / ry;
            if (dx + dy <= 1.05) mask.add(cellKey(x, y));
          }
        }
      case 'triangle':
        for (var y = 0; y <= rows; y++) {
          for (var x = 0; x <= cols; x++) {
            // Inverted triangle (point at bottom)
            final ny = y / rows; // 0=top, 1=bottom
            final halfW = (1 - ny) * rx;
            if ((x - cx).abs() <= halfW + 0.5) mask.add(cellKey(x, y));
          }
        }
      case 'star':
        for (var y = 0; y <= rows; y++) {
          for (var x = 0; x <= cols; x++) {
            final dx = x - cx, dy = y - cy;
            final angle = atan2(dy, dx);
            final dist = sqrt(dx * dx / (rx * rx) + dy * dy / (ry * ry));
            // 5-pointed star: sharp points with deep inner valleys
            // Alternates between outer radius (1.0) and inner (0.38)
            final a = (angle + pi / 2) % (2 * pi); // rotate so point faces up
            final sector = (a * 5 / (2 * pi)) % 1.0; // 0-1 within each sector
            final t = (sector - 0.5).abs() * 2; // 0 at valley, 1 at point
            final r = 0.52 + 0.48 * t; // inner=0.52, outer=1.0 (fatter star)
            if (dist <= r + 0.08) mask.add(cellKey(x, y));
          }
        }
      case 'peach':
        // Rounded heart/peach: very round body, tiny top dip, gentle bottom
        for (var y = 0; y <= rows; y++) {
          for (var x = 0; x <= cols; x++) {
            final nx = (x - cx) / rx;
            final ny = (y - cy) / ry;
            if (ny < -0.1) {
              final t = (ny + 0.1) / 0.9;
              final lx = nx + 0.38;
              final rx2 = nx - 0.38;
              final r = 0.65;
              final inLeft = lx * lx + t * t * 0.6 <= r * r;
              final inRight = rx2 * rx2 + t * t * 0.6 <= r * r;
              if (inLeft || inRight) mask.add(cellKey(x, y));
            } else if (ny < 0.3) {
              if (nx.abs() <= 1.02) mask.add(cellKey(x, y));
            } else {
              final t = (ny - 0.3) / 0.7;
              final halfW = 1.02 * (1.0 - t * t * 0.55 - t * 0.45);
              if (nx.abs() <= halfW.clamp(0, 1)) mask.add(cellKey(x, y));
            }
          }
        }
      case 'cross':
        final armW = max(2, (cols * 0.22).round());
        final armH = max(2, (rows * 0.22).round());
        for (var y = 0; y <= rows; y++) {
          for (var x = 0; x <= cols; x++) {
            final inHBar = (y - cy).abs() <= armH;
            final inVBar = (x - cx).abs() <= armW;
            if (inHBar || inVBar) mask.add(cellKey(x, y));
          }
        }
      case 'hexagon':
        // Flat-top hexagon: width tapers linearly from full at the
        // vertical center straight to a flat half-width edge at top and
        // bottom — no flat waist band, so it's a true 6-sided hexagon
        // (not 8-sided like a waist+taper octagon).
        for (var y = 0; y <= rows; y++) {
          for (var x = 0; x <= cols; x++) {
            final nx = (x - cx) / rx;
            final ny = (y - cy) / ry;
            final halfW = 1.0 - ny.abs() * 0.5;
            if (nx.abs() <= halfW + 0.05) mask.add(cellKey(x, y));
          }
        }
      case 'octagon':
        // Full-width middle band + linear taper to a flat half-width edge
        // at top and bottom — 8 sides (this is what 'hexagon' originally
        // produced before being corrected to a true 6-sided hexagon).
        for (var y = 0; y <= rows; y++) {
          for (var x = 0; x <= cols; x++) {
            final nx = (x - cx) / rx;
            final ny = (y - cy) / ry;
            final ay = ny.abs();
            double halfW;
            if (ay <= 0.5) {
              halfW = 1.0;
            } else {
              final t = (ay - 0.5) / 0.5;
              halfW = 1.0 - t * 0.5;
            }
            if (nx.abs() <= halfW + 0.05) mask.add(cellKey(x, y));
          }
        }
      case 'pentagon':
        // Regular 5-sided polygon, point facing down (rotated 180° from
        // the initial point-up attempt). Uses the standard "distance to
        // regular polygon edge by angle" formula: radius is the apothem
        // at each edge midpoint, widening to the full circumradius at
        // each vertex.
        const pentN = 5;
        const pentSector = 2 * pi / pentN;
        final pentApothem = cos(pi / pentN);
        for (var y = 0; y <= rows; y++) {
          for (var x = 0; x <= cols; x++) {
            final dx = x - cx, dy = y - cy;
            final dist = sqrt(dx * dx / (rx * rx) + dy * dy / (ry * ry));
            var angle = (atan2(dy, dx) - pi / 2) % (2 * pi);
            if (angle < 0) angle += 2 * pi;
            final a = (angle + pentSector / 2) % pentSector - pentSector / 2;
            final r = pentApothem / cos(a);
            if (dist <= r + 0.08) mask.add(cellKey(x, y));
          }
        }
      case 'shield':
        // Badge/crest shield (matched to reference): top edge with a
        // slight raised peak at the center, near-square corners, straight
        // sides down to ~10% below center, then outward-bulging curves
        // meeting at a bottom point.
        for (var y = 0; y <= rows; y++) {
          for (var x = 0; x <= cols; x++) {
            final nx = (x - cx) / rx;
            final ny = (y - cy) / ry;
            var inside = false;
            if (ny <= 0.1) {
              // Top boundary: peak at center (-1.0), dipping to -0.88 at
              // the corners — the subtle V of the reference crest.
              final topY = -1.0 + 0.12 * nx.abs();
              inside = nx.abs() <= 1.0 && ny >= topY;
              // Small corner rounding.
              if (ny < topY + 0.10 && nx.abs() > 0.85) {
                final ddx = (nx.abs() - 0.85) / 0.15;
                final ddy = (topY + 0.10 - ny) / 0.10;
                inside = ddx * ddx + ddy * ddy <= 1.1;
              }
            } else {
              // Outward-bulging curve into the bottom point.
              final t = (ny - 0.1) / 0.9;
              final halfW = 1.0 - pow(t, 1.8).toDouble();
              inside = nx.abs() <= halfW.clamp(0.0, 1.0) + 0.03;
            }
            if (inside) mask.add(cellKey(x, y));
          }
        }
      case 'teardrop':
        // Teardrop: sharp point at the top widening into a round bottom.
        for (var y = 0; y <= rows; y++) {
          for (var x = 0; x <= cols; x++) {
            final nx = (x - cx) / rx;
            final ny = (y - cy) / ry;
            final halfW = ny <= 0
                ? 0.95 * pow(ny + 1.0, 1.4).toDouble()
                : 0.95 * sqrt(max(0.0, 1.0 - ny * ny));
            if (nx.abs() <= halfW + 0.03) mask.add(cellKey(x, y));
          }
        }
      case 'kite':
        // Kite: tall quadrilateral — short peak on top, widest at 3/8
        // height, long taper to the bottom point.
        for (var y = 0; y <= rows; y++) {
          for (var x = 0; x <= cols; x++) {
            final nx = (x - cx) / rx;
            final ny = (y - cy) / ry;
            final halfW = ny <= -0.25
                ? 0.85 * (ny + 1.0) / 0.75
                : 0.85 * (1.0 - (ny + 0.25) / 1.25);
            if (nx.abs() <= halfW + 0.03) mask.add(cellKey(x, y));
          }
        }
      case 'house':
        // House: triangular roof over a rectangular body, flat bottom.
        for (var y = 0; y <= rows; y++) {
          for (var x = 0; x <= cols; x++) {
            final nx = (x - cx) / rx;
            final ny = (y - cy) / ry;
            final halfW =
                ny <= -0.15 ? (ny + 1.0) / 0.85 : 0.78;
            if (nx.abs() <= halfW + 0.03) mask.add(cellKey(x, y));
          }
        }
      case 'egg':
        // Egg: ellipse, slightly narrower toward the top.
        for (var y = 0; y <= rows; y++) {
          for (var x = 0; x <= cols; x++) {
            final nx = (x - cx) / rx;
            final ny = (y - cy) / ry;
            final halfW = 0.94 *
                sqrt(max(0.0, 1.0 - ny * ny)) *
                (1.0 - 0.18 * max(0.0, -ny));
            if (nx.abs() <= halfW + 0.03) mask.add(cellKey(x, y));
          }
        }
      case 'dome':
        // Dome: half-ellipse spanning the full grid height, flat base at
        // the bottom edge.
        for (var y = 0; y <= rows; y++) {
          for (var x = 0; x <= cols; x++) {
            final nx = (x - cx) / rx;
            final ny = (y - cy) / ry;
            final dy = (ny - 1.0) / 2.0; // 0 at base, -1 at the top
            if (nx * nx + dy * dy <= 1.06) mask.add(cellKey(x, y));
          }
        }
      case 'arrow':
        // Up arrow (the game's own icon): triangular head over a straight
        // shaft — full-width head top 45%, 0.42-wide shaft below.
        for (var y = 0; y <= rows; y++) {
          for (var x = 0; x <= cols; x++) {
            final nx = (x - cx) / rx;
            final ny = (y - cy) / ry;
            final halfW = ny <= -0.1 ? (ny + 1.0) / 0.9 : 0.42;
            if (nx.abs() <= halfW + 0.03) mask.add(cellKey(x, y));
          }
        }
      case 'crown':
        // Crown: solid band below, three triangular spikes on top.
        for (var y = 0; y <= rows; y++) {
          for (var x = 0; x <= cols; x++) {
            final nx = (x - cx) / rx;
            final ny = (y - cy) / ry;
            var inside = false;
            if (ny >= 0.15) {
              inside = nx.abs() <= 0.95;
            } else {
              final spikeHalf = 0.32 * (ny + 1.0) / 1.15;
              for (final p in const [-0.63, 0.0, 0.63]) {
                if ((nx - p).abs() <= spikeHalf + 0.03) inside = true;
              }
            }
            if (inside) mask.add(cellKey(x, y));
          }
        }
      case 'tree':
        // Christmas tree: three stacked, widening triangles + short trunk.
        for (var y = 0; y <= rows; y++) {
          for (var x = 0; x <= cols; x++) {
            final nx = (x - cx) / rx;
            final ny = (y - cy) / ry;
            var inside = false;
            if (ny >= -1.0 && ny <= -0.45) {
              inside = nx.abs() <= 0.52 * (ny + 1.0) / 0.55 + 0.02;
            }
            if (!inside && ny >= -0.6 && ny <= -0.05) {
              inside = nx.abs() <= 0.74 * (ny + 0.6) / 0.55 + 0.02;
            }
            if (!inside && ny >= -0.2 && ny <= 0.55) {
              inside = nx.abs() <= 0.98 * (ny + 0.2) / 0.75 + 0.02;
            }
            if (!inside && ny > 0.55) {
              inside = nx.abs() <= 0.18;
            }
            if (inside) mask.add(cellKey(x, y));
          }
        }
      case 'crescent':
        // Crescent moon: a large circle with a smaller, offset circle
        // subtracted from one side, leaving a curved sliver. Inner circle
        // pushed further toward center (and slightly smaller) so the
        // crescent body reads bolder/thicker, with the inner cut edge
        // landing near the grid's vertical center.
        final outerCx = cx, outerCy = cy;
        const outerR = 1.0;
        final innerCx = cx + rx * 0.65, innerCy = cy;
        const innerR = 0.70;
        for (var y = 0; y <= rows; y++) {
          for (var x = 0; x <= cols; x++) {
            final dxo = (x - outerCx) / (rx * outerR);
            final dyo = (y - outerCy) / (ry * outerR);
            final inOuter = dxo * dxo + dyo * dyo <= 1.05;
            final dxi = (x - innerCx) / (rx * innerR);
            final dyi = (y - innerCy) / (ry * innerR);
            final inInner = dxi * dxi + dyi * dyi <= 1.0;
            if (inOuter && !inInner) mask.add(cellKey(x, y));
          }
        }
      case 'clover':
        // 4-leaf clover rotated 45° — leaves point to the four corners.
        // offN > radN       → + gap at cardinal centres (no circle reaches)
        // 2·radN > offN·√2  → adjacent leaves overlap slightly → connected
        const offN = 0.55;
        const radN = 0.44;
        // Diagonal offset: same Euclidean distance offN·rx from centre,
        // split equally across x and y via ÷√2.
        final dOff = rx * offN * 0.7071;
        // NE, SE, SW, NW
        final lobeCX2 = [cx + dOff, cx + dOff, cx - dOff, cx - dOff];
        final lobeCY2 = [cy - dOff, cy + dOff, cy + dOff, cy - dOff];
        for (var y = 0; y <= rows; y++) {
          for (var x = 0; x <= cols; x++) {
            for (var i = 0; i < 4; i++) {
              final dxl = (x - lobeCX2[i]) / (rx * radN);
              final dyl = (y - lobeCY2[i]) / (ry * radN);
              if (dxl*dxl + dyl*dyl <= 1.0) { mask.add(cellKey(x, y)); break; }
            }
          }
        }
      case 'flower':
        // 5-petal flower 🌸: five circles evenly spaced 72° apart around the
        // centre, one petal pointing straight up (θ = -90° + i·72°).
        //   offN > radN                → hollow hole in the middle (no petal
        //                                reaches the centre)
        //   2·radN > inter-petal dist  → adjacent petals overlap slightly, so
        //                                the ring of petals stays connected
        // Round/plump petals, matching the 4-leaf clover (L70).
        const petalN = 5;
        const offN = 0.60;
        const radN = 0.42;
        final petalCX = <double>[];
        final petalCY = <double>[];
        for (var i = 0; i < petalN; i++) {
          final ang = -pi / 2 + i * 2 * pi / petalN;
          petalCX.add(cx + rx * offN * cos(ang));
          petalCY.add(cy + ry * offN * sin(ang));
        }
        for (var y = 0; y <= rows; y++) {
          for (var x = 0; x <= cols; x++) {
            for (var i = 0; i < petalN; i++) {
              final dxl = (x - petalCX[i]) / (rx * radN);
              final dyl = (y - petalCY[i]) / (ry * radN);
              if (dxl * dxl + dyl * dyl <= 1.0) { mask.add(cellKey(x, y)); break; }
            }
          }
        }
      case 'bolt':
        // Lightning bolt ⚡: a single chunky zigzag band leaning down-left with
        // a sharp point at the bottom. Defined as a normalized polygon (x,y in
        // [0,1], y-down) traced clockwise, filled via ray-casting point-in-
        // polygon. Vertices: top edge → down-left upper arm → step-right notch
        // → down-left to the sharp bottom point → back up the lower arm → step-
        // left notch → up the upper arm's left edge.
        const boltPoly = <List<double>>[
          [0.40, 0.00], // top-left
          [0.70, 0.00], // top-right
          [0.48, 0.46], // upper-arm bottom-right (kink)
          [0.68, 0.46], // step right → notch outer
          [0.46, 0.86], // lower-arm right edge (stays wide/chunky)
          [0.34, 1.00], // sharp bottom point
          [0.26, 0.88], // lower-arm left, near the tip
          [0.42, 0.54], // lower-arm top-left (kink)
          [0.22, 0.54], // step left → notch
        ];
        for (var y = 0; y <= rows; y++) {
          for (var x = 0; x <= cols; x++) {
            final px = x / cols, py = y / rows;
            var inside = false;
            for (var i = 0, j = boltPoly.length - 1;
                i < boltPoly.length; j = i++) {
              final xi = boltPoly[i][0], yi = boltPoly[i][1];
              final xj = boltPoly[j][0], yj = boltPoly[j][1];
              if (((yi > py) != (yj > py)) &&
                  (px < (xj - xi) * (py - yi) / (yj - yi) + xi)) {
                inside = !inside;
              }
            }
            if (inside) mask.add(cellKey(x, y));
          }
        }
      default:
        return null;
    }
    return mask.length >= 20 ? mask : null;
  }

  /// True if (nx,ny) is orthogonally adjacent to an own-body cell other than
  /// the cell we stepped from — banned so a path never folds beside itself.
  bool _touchesSelf(int nx, int ny, int fromX, int fromY, Set<String> body) {
    const adj = [
      [1, 0],
      [-1, 0],
      [0, 1],
      [0, -1]
    ];
    for (final d in adj) {
      final ax = nx + d[0], ay = ny + d[1];
      if (ax == fromX && ay == fromY) continue;
      if (body.contains(cellKey(ax, ay))) return true;
    }
    return false;
  }

  /// Grows a winding self-avoiding walk from (sx,sy). Prefers to keep going
  /// (longer arrows) and turns based on [_straightBias]. Returns null if it
  /// couldn't reach length >= 2.
  bool _relaxSelf = false; // set by _configure for daily mode

  /// Counts how many open exits a cell (nx,ny) has, excluding [body] and [occ].
  /// Used by the look-ahead walker to avoid dead ends.
  int _openExits(int nx, int ny, Set<String> occ, Set<String> body) {
    var exits = 0;
    for (final d in Direction.values) {
      final ex = nx + d.dx, ey = ny + d.dy;
      if (_inB(ex, ey) &&
          !occ.contains(cellKey(ex, ey)) &&
          !body.contains(cellKey(ex, ey))) {
        exits++;
      }
    }
    return exits;
  }

  _Walk? _grow(SeededRandom rng, Set<String> occ, int sx, int sy,
      {int? capLen, bool relaxAdj = false}) {
    if (occ.contains(cellKey(sx, sy))) return null;
    var target = _walkMin + rng.nextInt(_walkMax - _walkMin + 1);
    if (capLen != null) target = min(target, capLen);
    final pts = <Point<int>>[Point(sx, sy)];
    final body = <String>{cellKey(sx, sy)};
    var cx = sx, cy = sy;
    var dir = Direction.values[rng.nextInt(4)];
    var headDir = dir;
    for (var step = 0; step < target; step++) {
      final cur = dir;
      final rev = Direction.values.firstWhere(
          (d) => d.dx == -cur.dx && d.dy == -cur.dy);

      // Collect all valid candidate moves with their scores.
      final candidates = <(Direction, int)>[];
      for (final d in Direction.values) {
        final nx = cx + d.dx, ny = cy + d.dy;
        final k = cellKey(nx, ny);
        if (!_inB(nx, ny) || occ.contains(k) || body.contains(k)) continue;
        if (!relaxAdj && !_relaxSelf && _touchesSelf(nx, ny, cx, cy, body)) {
          continue;
        }
        // Score: higher = preferred. Look-ahead avoids dead ends.
        var score = _openExits(nx, ny, occ, body) * 10;
        // Corridor bonus: prefer cells adjacent to occupied cells (maze look)
        if (_relaxSelf) {
          for (final a in Direction.values) {
            if (occ.contains(cellKey(nx + a.dx, ny + a.dy))) score += 3;
          }
        }
        // Direction preference
        if (d == cur) {
          score += rng.next() < _straightBias ? 8 : 2;
        } else if (d == rev) {
          score += 1; // U-turn: last resort but allowed
        } else {
          score += rng.next() < _straightBias ? 3 : 6; // perp = turn
        }
        // Small random jitter to avoid deterministic patterns
        score += rng.nextInt(4);
        candidates.add((d, score));
      }
      if (candidates.isEmpty) break;

      // Sort by score descending, pick the best — but AVOID dead ends:
      // if the best candidate has 0 open exits (dead end), skip it if
      // there's a candidate with 1+ exits, unless we're near the end.
      candidates.sort((a, b) => b.$2.compareTo(a.$2));
      var chosen = candidates.first;
      if (step < target - 2) {
        // Not near the end — avoid dead ends
        for (final c in candidates) {
          final nx = cx + c.$1.dx, ny = cy + c.$1.dy;
          if (_openExits(nx, ny, occ, body) >= 1) {
            chosen = c;
            break;
          }
        }
      }

      final d = chosen.$1;
      cx = cx + d.dx;
      cy = cy + d.dy;
      pts.add(Point(cx, cy));
      body.add(cellKey(cx, cy));
      dir = d;
      headDir = d;
    }
    if (pts.length < 2) return null;
    return _Walk(pts, body, headDir, cx, cy);
  }

  /// When true, [_exitClear] must walk all the way to the full grid
  /// rectangle edge instead of stopping as soon as it leaves the shape mask.
  /// Needed for multi-lobe/concave shapes (clover) where a corridor can exit
  /// one lobe's mask and re-enter a DIFFERENT lobe further along the same
  /// straight line — [greedySolvable]'s real corridor check (which the game
  /// actually uses to verify removability) only stops at the rectangle edge,
  /// not the mask, so exiting the mask early is not a true guarantee there.
  bool _strictRectExit = false;

  /// True if the exit corridor (head → edge) is clear of [occ]. Used by the
  /// reverse-construction packer to guarantee solvability.
  bool _exitClear(_Walk w, Set<String> occ) {
    var fx = w.hx, fy = w.hy;
    while (true) {
      fx += w.headDir.dx;
      fy += w.headDir.dy;
      if (fx < 0 || fx > cols || fy < 0 || fy > rows) return true;
      if (!_strictRectExit && !_inB(fx, fy)) return true;
      final k = cellKey(fx, fy);
      if (occ.contains(k) || w.body.contains(k)) return false;
    }
  }

  /// High-fill packer: scans cells in shuffled order and grows long winding
  /// arrows. After placing each arrow, tries to start the NEXT arrow from an
  /// open neighbor of the one just placed — this fills connected regions
  /// contiguously, leaving fewer isolated pockets (= fewer short gap-fill
  /// stubs). NOT guaranteed solvable (verified by the caller).
  List<Arrow> _packFill(int seed) {
    final rng = SeededRandom(seed);
    final occ = <String>{};
    final arrows = <Arrow>[];
    final pending = _shuffledCells(rng);
    var idx = 0;
    while (idx < pending.length) {
      final (sx, sy) = pending[idx++];
      if (occ.contains(cellKey(sx, sy))) continue;
      var cx = sx, cy = sy;
      // Grow arrows in a chain: after placing one, start the next from a
      // neighbor of the head — fills regions contiguously.
      for (var chain = 0; chain < 40; chain++) {
        final w = _grow(rng, occ, cx, cy);
        if (w == null) break;
        occ.addAll(w.body);
        arrows.add(Arrow(
            id: arrows.length, pts: w.pts, dir: w.headDir, cells: w.body));
        // Find an open neighbor of any cell in this arrow to continue from.
        (int, int)? next;
        for (final p in w.pts) {
          for (final d in Direction.values) {
            final nx = p.x + d.dx, ny = p.y + d.dy;
            if (_inB(nx, ny) && !occ.contains(cellKey(nx, ny))) {
              next = (nx, ny);
              break;
            }
          }
          if (next != null) break;
        }
        if (next == null) break;
        cx = next.$1;
        cy = next.$2;
      }
    }
    return arrows;
  }

  /// Reverse-construction packer: each arrow's exit corridor must be clear of
  /// already-placed arrows ⇒ removing in reverse order always works ⇒
  /// GUARANTEED solvable. Fills less tightly than [_packFill]; gap-fill cleans up.
  int _rcRetries = 6;

  List<Arrow> _packRC(int seed) {
    final rng = SeededRandom(seed);
    final occ = <String>{};
    final arrows = <Arrow>[];
    for (final (x, y) in _shuffledCells(rng)) {
      if (occ.contains(cellKey(x, y))) continue;
      _Walk? chosen;
      for (var r = 0; r < _rcRetries; r++) {
        final w = _grow(rng, occ, x, y);
        if (w == null) continue;
        if (_exitClear(w, occ)) {
          chosen = w;
          break;
        }
      }
      if (chosen == null) continue;
      occ.addAll(chosen.body);
      arrows.add(Arrow(
          id: arrows.length,
          pts: chosen.pts,
          dir: chosen.headDir,
          cells: chosen.body));
    }
    return arrows;
  }

  /// All grid points (0..cols, 0..rows) in a deterministic shuffled order.
  List<(int, int)> _shuffledCells(SeededRandom rng) {
    final cells = <(int, int)>[];
    for (var y = 0; y <= rows; y++) {
      for (var x = 0; x <= cols; x++) {
        cells.add((x, y));
      }
    }
    for (var i = cells.length - 1; i > 0; i--) {
      final j = rng.nextInt(i + 1);
      final t = cells[i];
      cells[i] = cells[j];
      cells[j] = t;
    }
    return cells;
  }

  /// Fills remaining gaps with the longest winding arrow that fits and keeps
  /// the board solvable. Prefers 3+ cell L-shapes/straights; 2-cell only as a
  /// last resort. Each candidate is solvability-checked individually.
  bool _allow2CellGapFill = false;

  void _applyGapFill(List<Arrow> arrows) {
    final occ = <String>{};
    for (final a in arrows) {
      occ.addAll(a.cells);
    }

    bool free(int x, int y) => _inB(x, y) && !occ.contains(cellKey(x, y));

    bool exitClearFor(Point<int> head, Direction dir, Set<String> body) {
      var fx = head.x, fy = head.y;
      while (true) {
        fx += dir.dx;
        fy += dir.dy;
        if (fx < 0 || fx > cols || fy < 0 || fy > rows) return true;
        if (!_strictRectExit && !_inB(fx, fy)) return true;
        final k = cellKey(fx, fy);
        if (occ.contains(k) || body.contains(k)) return false;
      }
    }

    bool tryPlace(List<Point<int>> pts, Direction dir) {
      final cells = {for (final p in pts) cellKey(p.x, p.y)};
      // Two-phase acceptance for clover: first the cheap exit-corridor test
      // (accept immediately if the arrow has a guaranteed clear flight path),
      // otherwise fall back to the full greedySolvable check — which is LESS
      // restrictive than exit-clear (an arrow may be blocked as long as its
      // blockers can clear first), so it packs many more arrows into the
      // lobes while still guaranteeing the whole board stays solvable.
      if (_allow2CellGapFill) {
        if (exitClearFor(pts.last, dir, cells)) {
          occ.addAll(cells);
          arrows.add(Arrow(id: arrows.length, pts: pts, dir: dir, cells: cells));
          return true;
        }
        arrows.add(Arrow(id: arrows.length, pts: pts, dir: dir, cells: cells));
        if (greedySolvable(arrows)) {
          occ.addAll(cells);
          return true;
        }
        arrows.removeLast();
        return false;
      }
      arrows.add(Arrow(id: arrows.length, pts: pts, dir: dir, cells: cells));
      if (greedySolvable(arrows)) {
        occ.addAll(cells);
        return true;
      }
      arrows.removeLast();
      return false;
    }

    // Candidate arrows from (x,y), longest/windiest first. Gaps are usually
    // small, so we cap at 4-cell straights, 3-cell straights/L-shapes, then
    // 2-cell — enough to fill holes without an explosion of solve checks.
    List<(List<Point<int>>, Direction)> candidates(int x, int y) {
      final out = <(List<Point<int>>, Direction)>[];
      // 4-cell straight
      for (final d in Direction.values) {
        final a = Point(x + d.dx, y + d.dy);
        final b = Point(x + d.dx * 2, y + d.dy * 2);
        final c = Point(x + d.dx * 3, y + d.dy * 3);
        if (free(a.x, a.y) && free(b.x, b.y) && free(c.x, c.y)) {
          out.add(([Point(x, y), a, b, c], d));
        }
      }
      // 3-cell straights and L-shapes
      for (final d in Direction.values) {
        final a = Point(x + d.dx, y + d.dy);
        if (!free(a.x, a.y)) continue;
        final b = Point(x + d.dx * 2, y + d.dy * 2);
        if (free(b.x, b.y)) out.add(([Point(x, y), a, b], d));
        for (final t in Direction.values) {
          if (t == d || (t.dx == -d.dx && t.dy == -d.dy)) continue;
          final e = Point(a.x + t.dx, a.y + t.dy);
          if (free(e.x, e.y) && !(e.x == x && e.y == y)) {
            out.add(([Point(x, y), a, e], t));
          }
        }
      }
      // No 2-cell stubs — minimum 3 cells. Isolated single cells left unfilled.
      if (_allow2CellGapFill) {
        for (final d in Direction.values) {
          final a = Point(x + d.dx, y + d.dy);
          if (free(a.x, a.y)) out.add(([Point(x, y), a], d));
        }
      }
      return out;
    }

    int freeNeighborCount(int x, int y) {
      var n = 0;
      for (final d in Direction.values) {
        if (free(x + d.dx, y + d.dy)) n++;
      }
      return n;
    }

    var placed = true;
    while (placed) {
      placed = false;
      if (_allow2CellGapFill) {
        // Most-constrained-cell-first: cells in tight corners/pockets have
        // fewer valid candidate directions, so filling them before open
        // cells unlocks more of the board overall than a fixed raster scan.
        final freeCells = <(int, int)>[];
        for (var y = 0; y <= rows; y++) {
          for (var x = 0; x <= cols; x++) {
            if (free(x, y)) freeCells.add((x, y));
          }
        }
        freeCells.sort((a, b) =>
            freeNeighborCount(a.$1, a.$2).compareTo(freeNeighborCount(b.$1, b.$2)));
        for (final (x, y) in freeCells) {
          if (occ.contains(cellKey(x, y))) continue;
          for (final (pts, dir) in candidates(x, y)) {
            if (tryPlace(pts, dir)) {
              placed = true;
              break;
            }
          }
        }
      } else {
        for (var y = 0; y <= rows; y++) {
          for (var x = 0; x <= cols; x++) {
            if (occ.contains(cellKey(x, y))) continue;
            for (final (pts, dir) in candidates(x, y)) {
              if (tryPlace(pts, dir)) {
                placed = true;
                break;
              }
            }
          }
        }
      }
    }
  }

  /// Greedy solver — true iff every arrow can be cleared. Removing an arrow
  /// only frees cells (monotone), so a greedy clear order is a valid test.
  ///
  /// Topological implementation: each arrow is "blocked" by the count of cells
  /// in its exit corridor owned by OTHER arrows. Clearable arrows (0 blockers)
  /// cascade as they leave. O(total corridor length) instead of O(n²).
  bool greedySolvable(List<Arrow> arrows) {
    final n = arrows.length;
    if (n == 0) return true;
    final w = cols + 1, h = rows + 1;
    final stride = w;
    // Flat int grid (no string hashing): cell index = y*stride + x, value =
    // owning arrow index or -1.
    final owner = List<int>.filled(w * h, -1);
    for (var i = 0; i < n; i++) {
      for (final p in arrows[i].pts) {
        owner[p.y * stride + p.x] = i;
      }
    }
    final blockerCount = List<int>.filled(n, 0);
    final waiters = <int, List<int>>{}; // cell index -> waiting arrow indices
    for (var i = 0; i < n; i++) {
      final a = arrows[i];
      var x = a.head.x, y = a.head.y;
      final dx = a.dir.dx, dy = a.dir.dy;
      while (true) {
        x += dx;
        y += dy;
        if (x < 0 || x >= w || y < 0 || y >= h) break;
        final idx = y * stride + x;
        final o = owner[idx];
        if (o != -1 && o != i) {
          blockerCount[i]++;
          (waiters[idx] ??= <int>[]).add(i);
        }
      }
    }
    final queue = <int>[];
    for (var i = 0; i < n; i++) {
      if (blockerCount[i] == 0) queue.add(i);
    }
    var cleared = 0;
    while (queue.isNotEmpty) {
      final i = queue.removeLast();
      cleared++;
      for (final p in arrows[i].pts) {
        final ws = waiters[p.y * stride + p.x];
        if (ws == null) continue;
        for (final wi in ws) {
          if (--blockerCount[wi] == 0) queue.add(wi);
        }
        ws.clear();
      }
    }
    return cleared == n;
  }

  /// Sets grid size and arrow-shape params for a level (and daily mode).
  ///
  /// Reference grid sizes (measured from all 155 reference screenshots):
  ///   Normal:     avg 11×13 (151 dots), range 4×6 → 14×20
  ///   Hard:       avg 15×17 (264 dots), range 10×14 → 26×20
  ///   Super Hard: avg 23×25 (569 dots), range 17×21 → 35×26
  ///   Nightmare:  31×31 (961 dots)
  ///   Daily Hard:       avg 18×25 (444 dots)
  ///   Daily Super Hard: avg 28×31 (868 dots)
  ///   Daily Nightmare:  avg 33×34 (1146 dots), up to 35×35
  void _configure(int level, Tier tier, bool daily) {
    final lv = level.toDouble();

    // ── Grid size ──
    if (daily) {
      // Daily challenges are big reference-scale boards, ~25-30% larger than
      // regular levels at the same tier. Daily level numbers span 40-99
      // (dailyLevelFor), so growth is keyed on (lv - 40): floor at 40,
      // reaching the cap near 99.
      final d = (lv - 40).clamp(0, 59);
      switch (tier) {
        case Tier.normal:
          // Shouldn't happen for daily, but fallback.
          cols = 24;
          rows = 34;
        case Tier.hard:
          cols = (24 + d * 0.17).clamp(24, 34).round();
          rows = (34 + d * 0.14).clamp(34, 42).round();
        case Tier.superHard:
          cols = (30 + d * 0.17).clamp(30, 40).round();
          rows = (40 + d * 0.14).clamp(40, 48).round();
        case Tier.nightmare:
          cols = (36 + d * 0.14).clamp(36, 44).round();
          rows = (46 + d * 0.17).clamp(46, 56).round();
      }
    } else {
      switch (tier) {
        case Tier.normal:
          // Range 4×6 (L4) → 14×19 (L9) → 22×29 (L47) → 14×20 (L98)
          // Fast growth early, slower later. Reference Normal varies a lot
          // but trends upward. Cap at 26×20 (max seen in reference).
          cols = (7 + lv * 0.20).clamp(7, 26).round();
          rows = (10 + lv * 0.18).clamp(10, 26).round();
        case Tier.hard:
          cols = (10 + lv * 0.12).clamp(10, 26).round();
          rows = (20 + lv * 0.08).clamp(20, 26).round();
        case Tier.superHard:
          cols = (15 + lv * 0.08).clamp(15, 28).round();
          rows = (25 + lv * 0.08).clamp(25, 35).round();
        case Tier.nightmare:
          cols = (25 + lv * 0.05).clamp(25, 35).round();
          rows = (30 + lv * 0.06).clamp(30, 40).round();
      }
    }

    // ── Arrow shape: look-ahead walker avoids dead ends → much longer arrows ──
    if (daily || tier == Tier.superHard || tier == Tier.nightmare) {
      _relaxSelf = true;
      _walkMin = 8;
      _walkMax = 40;
      _straightBias = 0.38;
    } else {
      _relaxSelf = false;
      switch (tier) {
        case Tier.normal:
          _walkMin = 5;
          _walkMax = 20;
          _straightBias = 0.45;
        case Tier.hard:
          _walkMin = 6;
          _walkMax = 25;
          _straightBias = 0.42;
        default:
          break;
      }
    }
  }

  /// Arrow-length density profile for a tier: harder tiers pack busier
  /// (more, shorter) arrows, easier tiers fewer/longer ones.
  ArrowProfile _profileForTier(Tier tier) {
    switch (tier) {
      case Tier.normal:
      case Tier.hard:
        return ArrowProfile.flowing;
      case Tier.superHard:
        return ArrowProfile.mixed;
      case Tier.nightmare:
        return ArrowProfile.busy;
    }
  }

  /// Runs the gravity packer over several seeds and keeps the best board:
  /// prefers a hole-free, greedy-verified result; otherwise the solvable
  /// one with the fewest 1-cell holes. Always applies the direction-mixing
  /// flip pass. The result is guaranteed solvable (every kept board passes
  /// [greedySolvable]).
  List<Arrow> _gravityBest(int seed, ArrowProfile profile) {
    final packer = GravityPacker(
        cols: cols,
        rows: rows,
        inMask: _inB,
        solvable: greedySolvable,
        profile: profile);
    List<Arrow>? best;
    var bestHoles = 1 << 30;
    for (var att = 0; att < 12; att++) {
      final arr = packer.pack((seed + att * 7919) & 0xFFFFFFFF);
      if (!greedySolvable(arr)) continue;
      if (packer.holes < bestHoles) {
        bestHoles = packer.holes;
        best = arr;
      }
      if (bestHoles == 0) break;
    }
    // Guaranteed non-null: attempt 0 with no risky merges is solvable by
    // construction, so at least one attempt always passes the gate.
    best ??= packer.pack(seed);
    packer.mixByFlipping(SeededRandom(seed ^ 0x51F1), best);
    return best;
  }

  GeneratedLevel genLevel(int level, {bool daily = false}) {
    // Hand-authored onboarding levels (1–5) for the main progression only.
    if (!daily) {
      final hand = handLevel(level);
      if (hand != null && greedySolvable(hand.arrows)) {
        cols = hand.cols;
        rows = hand.rows;
        return GeneratedLevel(hand.arrows, hand.cols, hand.rows);
      }
    }

    final tier = daily ? dailyTier(level) : tierForLevel(level);
    _configure(level, tier, daily);

    // Shape mask: shaped levels only in main progression, not daily.
    // Shaped boards lose ~30% of cells to the mask, so bump the grid
    // larger to compensate — keeps arrow count visually dense.
    final shapeName = daily ? null : _shapeLevels[level];
    if (shapeName != null) {
      // Shape-specific grid sizing. Heart needs to be wide (34×25 ref).
      if (shapeName == 'heart') {
        cols = max(cols, 29);
        rows = max(rows, 25);
      } else if (shapeName == 'peach') {
        cols = max(cols, 33);
        rows = max(rows, 37);
      } else if (shapeName == 'diamond') {
        cols = max(cols, 26);
        rows = max(cols, 30);
      } else if (shapeName == 'triangle') {
        cols = max(cols, 26);
        rows = max(rows, 30);
      } else if (shapeName == 'star') {
        cols = max(cols, 32);
        rows = max(rows, 36);
      } else if (shapeName == 'cross') {
        cols = max(cols, 29);
        rows = max(rows, 34);
      } else if (shapeName == 'hexagon') {
        cols = max(cols, 30);
        rows = max(rows, 28);
      } else if (shapeName == 'octagon') {
        cols = max(cols, 33);
        rows = max(rows, 33);
      } else if (shapeName == 'pentagon') {
        cols = max(cols, 32);
        rows = max(rows, 34);
      } else if (shapeName == 'crescent') {
        cols = max(cols, 32);
        rows = max(rows, 32);
      // L100+ gravity shapes: sized to match the reference game's late-game
      // boards (~26×44 rendered, 200-270 arrows). The mask trims some width,
      // so design grids run a little larger than the rendered target.
      } else if (shapeName == 'shield') {
        cols = max(cols, 34);
        rows = max(rows, 44);
      } else if (shapeName == 'teardrop' || shapeName == 'egg') {
        cols = max(cols, 34);
        rows = max(rows, 46);
      } else if (shapeName == 'kite') {
        cols = max(cols, 34);
        rows = max(rows, 46);
      } else if (shapeName == 'arrow') {
        cols = max(cols, 32);
        rows = max(rows, 46);
      } else if (shapeName == 'house') {
        cols = max(cols, 34);
        rows = max(rows, 42);
      } else if (shapeName == 'dome') {
        cols = max(cols, 44);
        // Clamp height: a dome must stay wider than tall.
        rows = max(rows, 28).clamp(28, 30);
      } else if (shapeName == 'crown') {
        cols = max(cols, 40);
        // Clamp height too: a crown taller than wide reads wrong.
        rows = max(rows, 32).clamp(32, 34);
      } else if (shapeName == 'tree') {
        cols = max(cols, 34);
        rows = max(rows, 48);
      } else if (shapeName == 'clover' || shapeName == 'flower') {
        cols = max(cols, 40);
        rows = max(rows, 40);
      } else if (shapeName == 'bolt') {
        // Bolt polygon spans ~0.48 of the width, so a 62-wide design grid
        // trims to a ~30-wide rendered board (wider/chunkier than 44→20).
        cols = max(cols, 62);
        rows = max(rows, 50);
      } else {
        cols = (cols * 1.4).round();
        rows = (rows * 1.4).round();
      }
    }
    _shapeMask = shapeName != null ? _buildShapeMask(shapeName) : null;

    final seed = (0x9E37 + level * 2654435761 + (daily ? 0x5151 : 0)) & 0xFFFFFFFF;

    int score(List<Arrow> arr) {
      var cells = 0;
      for (final a in arr) {
        cells += a.cells.length;
      }
      return cells; // total coverage — favours fuller boards
    }

    final area = _shapeMask?.length ?? (cols + 1) * (rows + 1);
    List<Arrow>? best;
    var bestScore = -1;
    var usedGravity = false;

    if (_shapeMask != null && _gravityShapes.contains(shapeName)) {
      // Shaped L100+ levels: gravity packer with the balanced profile (the
      // look these shapes were tuned/approved with).
      best = _gravityBest(seed, ArrowProfile.balanced);
      bestScore = score(best);
      usedGravity = true;
    } else if (_shapeMask != null) {
      // Shaped levels: RC-only (guaranteed solvable by construction).
      // Pentagon (L57) and crescent (L63) are thin/irregular shapes with
      // a higher sparse-fill risk than the others, so they each get their
      // own (independently tunable) extra attempts + fill target.
      int shapeAttempts = 10;
      double shapeFillTarget = 0.55;
      if (shapeName == 'pentagon' ||
          shapeName == 'crescent' ||
          shapeName == 'clover' ||
          shapeName == 'flower' ||
          shapeName == 'bolt' ||
          shapeName == 'octagon') {
        shapeAttempts = 12;
        shapeFillTarget = 0.70;
      }
      // Fast dense pipeline: shorten walk length for RC packing (the default
      // Hard-tier 6-25 walk is too long for curved/irregular masks — arrows
      // can't find a clear exit corridor and get skipped, leaving cells for
      // gap-fill). Short arrows pack RC's guaranteed-solvable corridors much
      // more densely, and the two-phase gap-fill (see _applyGapFill) finishes
      // the fill fast. _strictRectExit makes the exit check walk to the full
      // grid rectangle edge (not the mask edge) so an arrow flying across a
      // hole/gap into another lobe is correctly accounted for — needed for the
      // concave/hollow shapes; a harmless no-op for the convex pentagon (no
      // arrows exist outside a convex mask to re-enter). Saved/restored so
      // nothing else changes.
      final densePipeline = shapeName == 'pentagon' ||
          shapeName == 'crescent' ||
          shapeName == 'clover' ||
          shapeName == 'flower' ||
          shapeName == 'bolt' ||
          shapeName == 'octagon';
      final savedMin = _walkMin, savedMax = _walkMax, savedBias = _straightBias;
      final savedRetries = _rcRetries;
      if (densePipeline) {
        _walkMin = 2; _walkMax = 6; _straightBias = 0.50;
        _rcRetries = 6;
        _strictRectExit = true;
      }
      for (var att = 0; att < shapeAttempts; att++) {
        final arr = _packRC((seed + att * 7919) & 0xFFFFFFFF);
        if (arr.isEmpty) continue;
        final sc = score(arr);
        if (sc > bestScore) { bestScore = sc; best = arr; }
        if (bestScore > area * shapeFillTarget) break;
      }
      if (densePipeline) {
        _walkMin = savedMin; _walkMax = savedMax; _straightBias = savedBias;
        _rcRetries = savedRetries;
        _strictRectExit = false;
      }
    } else if (daily) {
      // Daily challenges: gravity packer on the full rectangle — big
      // reference-scale board, 100% fill (rarely a stray cell), solvable by
      // construction, U-turn/tri-modal path variety, arrow density set by
      // the daily tier's profile.
      best = _gravityBest(seed, _profileForTier(tier));
      bestScore = score(best);
      usedGravity = true;
    } else if (tier == Tier.superHard || tier == Tier.nightmare) {
      // Super Hard / Nightmare: _packFill first for long winding maze arrows,
      // same strategy as daily.
      for (var att = 0; att < 10; att++) {
        final arr = _packFill((seed + att * 7919) & 0xFFFFFFFF);
        if (arr.isEmpty) continue;
        final sc = score(arr);
        if (sc <= bestScore) continue;
        if (!greedySolvable(arr)) continue;
        bestScore = sc;
        best = arr;
        if (bestScore > area * 0.60) break;
      }
      if (best == null) {
        for (var att = 0; att < 6; att++) {
          final arr = _packRC((seed + 313 + att * 7919) & 0xFFFFFFFF);
          if (arr.isEmpty) continue;
          final sc = score(arr);
          if (sc > bestScore) {
            bestScore = sc;
            best = arr;
          }
          if (bestScore > area * 0.55) break;
        }
      }
    } else {
      // Normal / Hard: RC first (fast, guaranteed solvable), then try a few
      // _packFill attempts for nicer long arrows if they beat it.
      for (var att = 0; att < 6; att++) {
        final arr = _packRC((seed + att * 7919) & 0xFFFFFFFF);
        if (arr.isEmpty) continue;
        final sc = score(arr);
        if (sc > bestScore) {
          bestScore = sc;
          best = arr;
        }
        if (bestScore > area * 0.60) break;
      }
      for (var att = 0; att < 5; att++) {
        final arr = _packFill((seed + 313 + att * 7919) & 0xFFFFFFFF);
        if (arr.isEmpty) continue;
        final sc = score(arr);
        if (sc <= bestScore) continue;
        if (!greedySolvable(arr)) continue;
        bestScore = sc;
        best = arr;
        if (bestScore > area * 0.66) break;
      }
    }

    best ??= <Arrow>[];
    if (shapeName == 'pentagon' ||
        shapeName == 'crescent' ||
        shapeName == 'clover' ||
        shapeName == 'flower' ||
        shapeName == 'bolt' ||
        shapeName == 'octagon') {
      _allow2CellGapFill = true;
      _strictRectExit = true;
    }
    // Gravity levels are already ~100% filled; gap-fill would only touch the
    // rare orphan holes and its arrows pick arbitrary directions, breaking
    // the region direction pattern, so it is skipped for them.
    if (!usedGravity) {
      _applyGapFill(best);
    }
    _allow2CellGapFill = false;
    _strictRectExit = false;
    final result = _trimToFit(best);
    _shapeMask = null;
    return result;
  }

  /// Shrinks the grid to the bounding box of the placed arrows so there's no
  /// dead space around the puzzle. Shifts all arrow coordinates to start at 0.
  GeneratedLevel _trimToFit(List<Arrow> arrows) {
    if (arrows.isEmpty) return GeneratedLevel(arrows, cols, rows);
    var minX = cols, maxX = 0, minY = rows, maxY = 0;
    for (final a in arrows) {
      for (final p in a.pts) {
        if (p.x < minX) minX = p.x;
        if (p.x > maxX) maxX = p.x;
        if (p.y < minY) minY = p.y;
        if (p.y > maxY) maxY = p.y;
      }
    }
    if (minX == 0 && minY == 0 && maxX == cols && maxY == rows) {
      return GeneratedLevel(arrows, cols, rows);
    }
    final shifted = <Arrow>[];
    for (final a in arrows) {
      final pts = a.pts.map((p) => Point(p.x - minX, p.y - minY)).toList();
      final cells = <String>{for (final p in pts) cellKey(p.x, p.y)};
      shifted.add(Arrow(id: a.id, pts: pts, dir: a.dir, cells: cells));
    }
    return GeneratedLevel(shifted, maxX - minX, maxY - minY);
  }
}

class _Walk {
  final List<Point<int>> pts;
  final Set<String> body;
  final Direction headDir;
  final int hx, hy;
  _Walk(this.pts, this.body, this.headDir, this.hx, this.hy);
}
