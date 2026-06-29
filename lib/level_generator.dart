import 'dart:math';
import 'difficulty.dart';
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
    39: 'star', 45: 'cross', 52: 'circle', 57: 'heart',
    63: 'diamond', 70: 'triangle', 75: 'star', 81: 'cross',
    88: 'circle', 93: 'heart', 99: 'diamond',
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
            // 5-pointed star: inner radius modulated by angle
            final r = 0.5 + 0.5 * cos(5 * angle).abs();
            if (dist <= r * 1.1 + 0.15) mask.add(cellKey(x, y));
          }
        }
      case 'cross':
        final armW = max(2, (cols * 0.3).round());
        final armH = max(2, (rows * 0.3).round());
        for (var y = 0; y <= rows; y++) {
          for (var x = 0; x <= cols; x++) {
            final inHBar = (y - cy).abs() <= armH;
            final inVBar = (x - cx).abs() <= armW;
            if (inHBar || inVBar) mask.add(cellKey(x, y));
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

  /// True if the exit corridor (head → edge) is clear of [occ]. Used by the
  /// reverse-construction packer to guarantee solvability.
  bool _exitClear(_Walk w, Set<String> occ) {
    var fx = w.hx, fy = w.hy;
    while (true) {
      fx += w.headDir.dx;
      fy += w.headDir.dy;
      if (!_inB(fx, fy)) return true;
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
  List<Arrow> _packRC(int seed) {
    final rng = SeededRandom(seed);
    final occ = <String>{};
    final arrows = <Arrow>[];
    for (final (x, y) in _shuffledCells(rng)) {
      if (occ.contains(cellKey(x, y))) continue;
      _Walk? chosen;
      for (var r = 0; r < 6; r++) {
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
  void _applyGapFill(List<Arrow> arrows) {
    final occ = <String>{};
    for (final a in arrows) {
      occ.addAll(a.cells);
    }

    bool free(int x, int y) => _inB(x, y) && !occ.contains(cellKey(x, y));

    bool tryPlace(List<Point<int>> pts, Direction dir) {
      final cells = {for (final p in pts) cellKey(p.x, p.y)};
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
      return out;
    }

    var placed = true;
    while (placed) {
      placed = false;
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
      // Daily challenges are bigger than main levels at the same tier.
      switch (tier) {
        case Tier.normal:
          // Shouldn't happen for daily, but fallback
          cols = 15;
          rows = 20;
        case Tier.hard:
          // avg 18×25, range 15×24 → 29×25
          cols = (15 + lv * 0.05).clamp(15, 29).round();
          rows = (24 + lv * 0.02).clamp(24, 27).round();
        case Tier.superHard:
          // avg ~868 dots — tall rectangle
          cols = (20 + lv * 0.08).clamp(20, 30).round();
          rows = (25 + lv * 0.10).clamp(25, 37).round();
        case Tier.nightmare:
          cols = (28 + lv * 0.08).clamp(28, 40).round();
          rows = (35 + lv * 0.08).clamp(35, 45).round();
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
      } else if (shapeName == 'diamond') {
        cols = max(cols, 26);
        rows = max(cols, 30);
      } else {
        cols = (cols * 1.3).round();
        rows = (rows * 1.3).round();
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

    if (_shapeMask != null) {
      // Shaped levels: RC-only (guaranteed solvable by construction).
      for (var att = 0; att < 10; att++) {
        final arr = _packRC((seed + att * 7919) & 0xFFFFFFFF);
        if (arr.isEmpty) continue;
        final sc = score(arr);
        if (sc > bestScore) {
          bestScore = sc;
          best = arr;
        }
        if (bestScore > area * 0.55) break;
      }
    } else if (daily) {
      // Daily: _packFill FIRST — produces the signature long winding maze
      // arrows. RC's exit-corridor constraint forces short arrows, so we only
      // use it as a fallback if _packFill fails solvability.
      for (var att = 0; att < 12; att++) {
        final arr = _packFill((seed + att * 7919) & 0xFFFFFFFF);
        if (arr.isEmpty) continue;
        final sc = score(arr);
        if (sc <= bestScore) continue;
        if (!greedySolvable(arr)) continue;
        bestScore = sc;
        best = arr;
        if (bestScore > area * 0.60) break;
      }
      // Fallback: RC if no solvable _packFill found
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
    _applyGapFill(best);
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
