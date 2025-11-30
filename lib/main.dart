// lib/main.dart
//
// Two-brain nucleus universe:
// - InnerPhysicsEngine: wanders in (Z, N) space and flags "stable" configurations.
// - Judge: compares them to the periodic table & stable isotopes.
// - UI layout (cleaned):
//   * Top: nucleus / engine status card.
//   * Middle: periodic table card (big).
//   * Bottom: info row, submissions log, controls.

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'inner_physics.dart';
import 'judge.dart';
import 'periodic_table.dart';

void main() {
  runApp(const NucleusUniverseApp());
}

class NucleusUniverseApp extends StatelessWidget {
  const NucleusUniverseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Two-Brain Nucleus Universe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF050509),
        colorScheme: const ColorScheme.dark(primary: Colors.tealAccent),
        textTheme: ThemeData.dark().textTheme.apply(
          bodyColor: Colors.white.withOpacity(0.9),
          displayColor: Colors.white.withOpacity(0.9),
        ),
      ),
      home: const NucleusUniverseScreen(),
    );
  }
}

class SubmissionRecord {
  final int attempt;
  final JudgeResult result;

  const SubmissionRecord({required this.attempt, required this.result});
}

class NucleusUniverseScreen extends StatefulWidget {
  const NucleusUniverseScreen({super.key});

  @override
  State<NucleusUniverseScreen> createState() => _NucleusUniverseScreenState();
}

class _NucleusUniverseScreenState extends State<NucleusUniverseScreen> {
  late InnerPhysicsEngine _inner;
  late Judge _judge;

  Timer? _timer;
  bool _running = false;
  int _stepCount = 0;
  int _submissionCount = 0;

  // Accuracy stats for the inner engine.
  //int _correctStable = 0;
  //int _falseStable = 0;

  final List<SubmissionRecord> _submissions = [];

  @override
  void initState() {
    super.initState();
    _inner = InnerPhysicsEngine(seed: 42);
    _judge = Judge();
    _inner.reset(maxZ: allElements.length);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _reset() {
    _timer?.cancel();
    _timer = null;
    _running = false;
    _stepCount = 0;
    _submissionCount = 0;
    _submissions.clear();
    _judge.discoveredZ.clear();
    _inner.reset(maxZ: allElements.length);
    setState(() {});
  }

  void _toggleRun() {
    if (_running) {
      _stop();
    } else {
      _start();
    }
  }

  void _start() {
    if (_running) return;
    _running = true;
    _timer = Timer.periodic(const Duration(milliseconds: 60), (_) {
      _step();
    });
    setState(() {});
  }

  void _stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
    setState(() {});
  }

  void _step() {
    setState(() {
      final result = _inner.step(maxZ: allElements.length);
      _stepCount++;

      if (result.innerThinksStable) {
        _submissionCount++;

        final judgeResult = _judge.evaluate(
          result.nucleus,
          result.innerThinksStable,
        );

        // ✅ If the engine AND reality both say "stable", record as solved
        if (judgeResult.isCorrect) {
          _inner.markSolved(judgeResult.nucleus);
        }

        _submissions.insert(
          0,
          SubmissionRecord(attempt: _submissionCount, result: judgeResult),
        );

        if (_submissions.length > 120) {
          _submissions.removeLast();
        }
      }
    });
  }

  void _stepOnce() {
    _step();
  }

  @override
  Widget build(BuildContext context) {
    final nucleus = _inner.state;
    final judgeSnapshot =
        _submissions.isNotEmpty ? _submissions.first.result : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Element Engine'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: const Color(0xFF050509),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ===== TOP + MIDDLE: Engine + Periodic Table laid out by height =====
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final double nucleusHeight = min(
                    260.0,
                    constraints.maxHeight * 0.38,
                  );

                  return Column(
                    children: [
                      // Top: nucleus / engine card
                      SizedBox(
                        height: nucleusHeight,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                          child: _NucleusPanel(
                            nucleus: nucleus,
                            innerThinksStable:
                                judgeSnapshot?.innerThinksStable ?? false,
                            realityStable:
                                judgeSnapshot?.realityStable ?? false,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Middle: periodic table fills remaining vertical space
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                          child: _PeriodicTablePanel(
                            discoveredZ: _judge.discoveredZ,
                            currentZ: nucleus.protons,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // Info row
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 4,
              ),
              child: _buildInfoRow(),
            ),
            const SizedBox(height: 4),

            // Submission log
            _SubmissionLog(submissions: _submissions),

            // Controls
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.05),
                      foregroundColor: Colors.tealAccent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    onPressed: _reset,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Reset'),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: _stepOnce,
                        icon: const Icon(Icons.skip_next),
                        tooltip: 'Step once',
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _running
                                  ? Colors.tealAccent.withOpacity(0.16)
                                  : Colors.tealAccent.withOpacity(0.26),
                          foregroundColor: Colors.tealAccent,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 8,
                          ),
                        ),
                        onPressed: _toggleRun,
                        icon: Icon(_running ? Icons.pause : Icons.play_arrow),
                        label: Text(_running ? 'Pause' : 'Run'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow() {
    final n = _inner.state;
    final currentElement = elementByZ[n.protons];

    // How many submissions were actually correct (inner + reality agree)?
    final int correctCount =
        _submissions.where((s) => s.result.isCorrect).length;

    final double accuracy =
        _submissionCount > 0 ? correctCount / _submissionCount : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Steps: $_stepCount   '
          'Submissions: $_submissionCount   '
          'Correct: $correctCount   '
          'Accuracy: ${(accuracy * 100).toStringAsFixed(1)}%',
          style: const TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 2),
        Text(
          'Current nucleus: Z=${n.protons}, N=${n.neutrons}, A=${n.massNumber}'
          '${currentElement != null ? ' (${currentElement.symbol})' : ''}',
          style: const TextStyle(fontSize: 12),
        ),
        if (currentElement != null)
          Text(
            'Element: ${currentElement.name}',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withOpacity(0.8),
            ),
          )
        else
          Text(
            'Element: (beyond current table)',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
      ],
    );
  }
}

// ---------- Nucleus visual panel ----------

class _NucleusPanel extends StatelessWidget {
  final NucleusState nucleus;
  final bool innerThinksStable;
  final bool realityStable;

  const _NucleusPanel({
    required this.nucleus,
    required this.innerThinksStable,
    required this.realityStable,
  });

  @override
  Widget build(BuildContext context) {
    final label =
        innerThinksStable
            ? (realityStable ? 'ENGINE: STABLE ✅' : 'ENGINE: STABLE ❌')
            : 'ENGINE: UNSTABLE';

    final labelColor =
        innerThinksStable
            ? (realityStable ? Colors.tealAccent : Colors.redAccent)
            : Colors.white.withOpacity(0.7);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.16)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF050509), Color(0xFF131628)],
        ),
      ),
      child: Stack(
        children: [
          CustomPaint(
            painter: _NucleusPainter(
              nucleus: nucleus,
              isRealityStable: realityStable,
            ),
            child: const SizedBox.expand(),
          ),
          Positioned(
            left: 12,
            top: 10,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.2,
                color: labelColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NucleusPainter extends CustomPainter {
  final NucleusState nucleus;
  final bool isRealityStable;

  _NucleusPainter({required this.nucleus, required this.isRealityStable});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = min(size.width, size.height) * 0.32;

    // Background halo
    final haloPaint =
        Paint()
          ..shader = RadialGradient(
            colors: [
              (isRealityStable ? Colors.tealAccent : Colors.redAccent)
                  .withOpacity(0.24),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(center: center, radius: maxRadius * 1.5),
          );
    canvas.drawCircle(center, maxRadius * 1.5, haloPaint);

    // Main sphere
    final corePaint =
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.2, -0.3),
            radius: 1.0,
            colors:
                isRealityStable
                    ? [
                      const Color(0xFF00FFC3),
                      const Color(0xFF0070FF),
                      const Color(0xFF050509),
                    ]
                    : [
                      const Color(0xFFFF3B8D),
                      const Color(0xFF5A144A),
                      const Color(0xFF050509),
                    ],
          ).createShader(Rect.fromCircle(center: center, radius: maxRadius));
    canvas.drawCircle(center, maxRadius, corePaint);

    // Nucleons on shells
    final total = nucleus.massNumber.clamp(1, 120);
    final protonCount = nucleus.protons.clamp(0, total);
    //final neutronCount = (total - protonCount).clamp(0, total);

    final shells = (sqrt(total / 4)).ceil().clamp(1, 5);
    final rngSeed = nucleus.massNumber * 7919 + nucleus.protons * 13;
    final random = Random(rngSeed);

    int placed = 0;
    for (int s = 0; s < shells; s++) {
      final shellRadius = maxRadius * (0.3 + 0.6 * (s + 1) / shells);
      final countOnShell = (total / shells).ceil();
      for (int i = 0; i < countOnShell && placed < total; i++) {
        final angle = 2 * pi * (i / countOnShell) + random.nextDouble() * 0.3;
        final pos = Offset(
          center.dx + shellRadius * cos(angle),
          center.dy + shellRadius * sin(angle),
        );

        final isProton = placed < protonCount;
        final nucleonPaint =
            Paint()
              ..color =
                  isProton
                      ? Colors.pinkAccent.withOpacity(0.95)
                      : Colors.indigoAccent.withOpacity(0.95);

        final r = maxRadius * 0.06;
        canvas.drawCircle(pos, r, nucleonPaint);
        placed++;
      }
    }

    // Electron orbit
    final orbitPaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = Colors.white.withOpacity(0.2);
    final orbitR = maxRadius * 1.2;
    canvas.drawOval(
      Rect.fromCircle(center: center, radius: orbitR),
      orbitPaint,
    );

    // Electrons
    final electronsToShow = 4;
    for (int i = 0; i < electronsToShow; i++) {
      final angle =
          2 * pi * (i / electronsToShow) +
          (nucleus.protons * 0.1 + nucleus.neutrons * 0.07);
      final pos = Offset(
        center.dx + orbitR * cos(angle),
        center.dy + orbitR * sin(angle),
      );
      final ePaint = Paint()..color = Colors.tealAccent.withOpacity(0.9);
      canvas.drawCircle(pos, maxRadius * 0.035, ePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _NucleusPainter oldDelegate) {
    return oldDelegate.nucleus.protons != nucleus.protons ||
        oldDelegate.nucleus.neutrons != nucleus.neutrons ||
        oldDelegate.isRealityStable != isRealityStable;
  }
}

// ---------- Periodic table panel ----------

class _PeriodicTablePanel extends StatelessWidget {
  final Set<int> discoveredZ;
  final int currentZ;

  const _PeriodicTablePanel({
    required this.discoveredZ,
    required this.currentZ,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.16)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF050509), Color(0xFF151A2A)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: _PeriodicTableGrid(discoveredZ: discoveredZ, currentZ: currentZ),
      ),
    );
  }
}

class _PeriodicTableGrid extends StatelessWidget {
  final Set<int> discoveredZ;
  final int currentZ;

  const _PeriodicTableGrid({required this.discoveredZ, required this.currentZ});

  @override
  Widget build(BuildContext context) {
    const rows = 9; // was 7
    const cols = 18;

    final Map<String, ElementDef> byPos = {
      for (final e in allElements) '${e.period}-${e.group}': e,
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth = constraints.maxWidth / cols;
        final cellHeight = constraints.maxHeight / rows;

        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _PeriodicTablePainter(
            rows: rows,
            cols: cols,
            byPos: byPos,
            discoveredZ: discoveredZ,
            currentZ: currentZ,
            cellWidth: cellWidth,
            cellHeight: cellHeight,
          ),
        );
      },
    );
  }
}

class _PeriodicTablePainter extends CustomPainter {
  final int rows;
  final int cols;
  final Map<String, ElementDef> byPos;
  final Set<int> discoveredZ;
  final int currentZ;
  final double cellWidth;
  final double cellHeight;

  _PeriodicTablePainter({
    required this.rows,
    required this.cols,
    required this.byPos,
    required this.discoveredZ,
    required this.currentZ,
    required this.cellWidth,
    required this.cellHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5
          ..color = Colors.white.withOpacity(0.14);

    final fillPaint = Paint()..style = PaintingStyle.fill;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final rect = Rect.fromLTWH(
          c * cellWidth,
          r * cellHeight,
          cellWidth,
          cellHeight,
        );
        final key = '${r + 1}-${c + 1}';
        final element = byPos[key];

        if (element != null) {
          final isDiscovered = discoveredZ.contains(element.Z);
          final isCurrent = element.Z == currentZ;

          Color baseColor;
          if (isCurrent && isDiscovered) {
            baseColor = Colors.tealAccent;
          } else if (isCurrent && !isDiscovered) {
            baseColor = Colors.amberAccent.withOpacity(0.9);
          } else if (isDiscovered) {
            baseColor = Colors.tealAccent.withOpacity(0.35);
          } else {
            baseColor = Colors.white.withOpacity(0.06);
          }

          fillPaint.color = baseColor;
          canvas.drawRect(rect.deflate(3.0), fillPaint);
          canvas.drawRect(rect.deflate(3.0), borderPaint);

          final symbolPainter = TextPainter(
            text: TextSpan(
              text: element.symbol,
              style: TextStyle(
                fontSize: cellHeight * 0.26, // slightly smaller for spacing
                fontWeight: FontWeight.w600,
                color:
                    (isCurrent && isDiscovered)
                        ? Colors.black
                        : Colors.white.withOpacity(
                          isDiscovered || isCurrent ? 0.9 : 0.7,
                        ),
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: rect.width - 4);

          final ZPainter = TextPainter(
            text: TextSpan(
              text: '${element.Z}',
              style: TextStyle(
                fontSize: cellHeight * 0.16,
                color:
                    (isCurrent && isDiscovered)
                        ? Colors.black.withOpacity(0.8)
                        : Colors.white.withOpacity(0.7),
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: rect.width - 4);

          symbolPainter.paint(
            canvas,
            Offset(
              rect.left + (rect.width - symbolPainter.width) / 2,
              rect.top + rect.height * 0.30 - symbolPainter.height / 2,
            ),
          );

          ZPainter.paint(canvas, Offset(rect.left + 4, rect.top + 3));
        } else {
          canvas.drawRect(rect.deflate(4.0), borderPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PeriodicTablePainter oldDelegate) {
    return oldDelegate.currentZ != currentZ ||
        oldDelegate.discoveredZ.length != discoveredZ.length;
  }
}

// ---------- Submission log ----------

class _SubmissionLog extends StatelessWidget {
  final List<SubmissionRecord> submissions;

  const _SubmissionLog({required this.submissions});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              alignment: Alignment.centerLeft,
              child: Text(
                'Submissions (inner vs reality)',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.8),
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const Divider(height: 1, color: Colors.white24),
            Expanded(
              child:
                  submissions.isEmpty
                      ? Center(
                        child: Text(
                          'No submissions yet. When the inner engine thinks it '
                          'found a stable nucleus, it will appear here.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.6),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                      : ListView.builder(
                        itemCount: submissions.length,
                        itemBuilder: (context, index) {
                          final sub = submissions[index];
                          return _SubmissionRow(record: sub);
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubmissionRow extends StatelessWidget {
  final SubmissionRecord record;

  const _SubmissionRow({required this.record});

  @override
  Widget build(BuildContext context) {
    final r = record.result;
    final Z = r.nucleus.protons;
    final N = r.nucleus.neutrons;
    final A = r.nucleus.massNumber;

    final emoji =
        r.isCorrect
            ? '✅'
            : (r.innerThinksStable && !r.realityStable ? '❌' : '•');

    final elementLabel = r.elementDef != null ? r.elementDef!.symbol : '–';

    final realityLabel =
        r.realityStable
            ? 'stable ($elementLabel)'
            : (r.inPeriodicTable ? 'unstable here' : 'not in table');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              '#${record.attempt}',
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ),
          SizedBox(
            width: 86,
            child: Text('Z=$Z N=$N A=$A', style: const TextStyle(fontSize: 11)),
          ),
          SizedBox(
            width: 86,
            child: Text(
              r.innerThinksStable ? 'engine: stable' : 'engine: unstable',
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withOpacity(0.75),
              ),
            ),
          ),
          Expanded(
            child: Text(
              'reality: $realityLabel  $emoji',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color:
                    r.isCorrect
                        ? Colors.tealAccent
                        : (r.innerThinksStable && !r.realityStable
                            ? Colors.redAccent
                            : Colors.white.withOpacity(0.7)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}














































/*
// lib/main.dart
//
// Two-brain nucleus universe:
// - InnerPhysicsEngine: wanders in (Z, N) space and flags "stable" configurations.
// - Judge: compares them to the periodic table & stable isotopes.
// - UI:
//   * Left: nucleus visualization.
//   * Right: periodic table with discovered elements.
//   * Bottom: log of submissions (inner vs reality).

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'inner_physics.dart';
import 'judge.dart';
import 'periodic_table.dart';

void main() {
  runApp(const NucleusUniverseApp());
}

class NucleusUniverseApp extends StatelessWidget {
  const NucleusUniverseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Two-Brain Nucleus Universe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF050509),
        colorScheme: const ColorScheme.dark(primary: Colors.tealAccent),
        textTheme: ThemeData.dark().textTheme.apply(
          bodyColor: Colors.white.withOpacity(0.9),
          displayColor: Colors.white.withOpacity(0.9),
        ),
      ),
      home: const NucleusUniverseScreen(),
    );
  }
}

class SubmissionRecord {
  final int attempt;
  final JudgeResult result;

  const SubmissionRecord({required this.attempt, required this.result});
}

class NucleusUniverseScreen extends StatefulWidget {
  const NucleusUniverseScreen({super.key});

  @override
  State<NucleusUniverseScreen> createState() => _NucleusUniverseScreenState();
}

class _NucleusUniverseScreenState extends State<NucleusUniverseScreen> {
  late InnerPhysicsEngine _inner;
  late Judge _judge;

  Timer? _timer;
  bool _running = false;
  int _stepCount = 0;
  int _submissionCount = 0;

  final List<SubmissionRecord> _submissions = [];

  @override
  void initState() {
    super.initState();
    _inner = InnerPhysicsEngine(seed: 42);
    _judge = Judge();
    _inner.reset(maxZ: allElements.length);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _reset() {
    _timer?.cancel();
    _timer = null;
    _running = false;
    _stepCount = 0;
    _submissionCount = 0;
    _submissions.clear();
    _judge.discoveredZ.clear();
    _inner.reset(maxZ: allElements.length);
    setState(() {});
  }

  void _toggleRun() {
    if (_running) {
      _stop();
    } else {
      _start();
    }
  }

  void _start() {
    if (_running) return;
    _running = true;
    _timer = Timer.periodic(const Duration(milliseconds: 60), (_) {
      _step();
    });
    setState(() {});
  }

  void _stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
    setState(() {});
  }

  void _step() {
    setState(() {
      final result = _inner.step(maxZ: allElements.length);
      _stepCount++;

      if (result.innerThinksStable) {
        _submissionCount++;
        final judgeResult = _judge.evaluate(
          result.nucleus,
          result.innerThinksStable,
        );
        _submissions.insert(
          0,
          SubmissionRecord(attempt: _submissionCount, result: judgeResult),
        );
        // Keep log from blowing up
        if (_submissions.length > 120) {
          _submissions.removeLast();
        }
      }
    });
  }

  void _stepOnce() {
    _step();
  }

  @override
  Widget build(BuildContext context) {
    final nucleus = _inner.state;
    final judgeSnapshot =
        _submissions.isNotEmpty ? _submissions.first.result : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Two-Brain Nucleus Universe'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: const Color(0xFF050509),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Main visuals row: nucleus + periodic table
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: _NucleusPanel(
                        nucleus: nucleus,
                        innerThinksStable:
                            judgeSnapshot?.innerThinksStable ?? false,
                        realityStable: judgeSnapshot?.realityStable ?? false,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: _PeriodicTablePanel(
                        discoveredZ: _judge.discoveredZ,
                        currentZ: nucleus.protons,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Info & submission log
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 4,
              ),
              child: _buildInfoRow(),
            ),
            const SizedBox(height: 4),
            _SubmissionLog(submissions: _submissions),

            // Controls
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.05),
                      foregroundColor: Colors.tealAccent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    onPressed: _reset,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Reset'),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: _stepOnce,
                        icon: const Icon(Icons.skip_next),
                        tooltip: 'Step once',
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _running
                                  ? Colors.tealAccent.withOpacity(0.16)
                                  : Colors.tealAccent.withOpacity(0.26),
                          foregroundColor: Colors.tealAccent,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 8,
                          ),
                        ),
                        onPressed: _toggleRun,
                        icon: Icon(_running ? Icons.pause : Icons.play_arrow),
                        label: Text(_running ? 'Pause' : 'Run'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow() {
    final n = _inner.state;
    final currentElement = elementByZ[n.protons];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Steps: $_stepCount   '
          'Submissions: $_submissionCount   '
          'Discovered: ${_judge.discoveredZ.length}/${allElements.length}',
          style: const TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 2),
        Text(
          'Current nucleus: Z=${n.protons}, N=${n.neutrons}, A=${n.massNumber}'
          '${currentElement != null ? ' (${currentElement.symbol})' : ''}',
          style: const TextStyle(fontSize: 12),
        ),
        if (currentElement != null)
          Text(
            'Element: ${currentElement.name}',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withOpacity(0.8),
            ),
          )
        else
          Text(
            'Element: (beyond current table)',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
      ],
    );
  }
}

// ---------- Nucleus visual panel ----------

class _NucleusPanel extends StatelessWidget {
  final NucleusState nucleus;
  final bool innerThinksStable;
  final bool realityStable;

  const _NucleusPanel({
    required this.nucleus,
    required this.innerThinksStable,
    required this.realityStable,
  });

  @override
  Widget build(BuildContext context) {
    final label =
        innerThinksStable
            ? (realityStable ? 'ENGINE: STABLE ✅' : 'ENGINE: STABLE ❌')
            : 'ENGINE: UNSTABLE';

    final labelColor =
        innerThinksStable
            ? (realityStable ? Colors.tealAccent : Colors.redAccent)
            : Colors.white.withOpacity(0.7);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.16)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF050509), Color(0xFF131628)],
        ),
      ),
      child: Stack(
        children: [
          CustomPaint(
            painter: _NucleusPainter(
              nucleus: nucleus,
              isRealityStable: realityStable,
            ),
            child: const SizedBox.expand(),
          ),
          Positioned(
            left: 12,
            top: 10,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.2,
                color: labelColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NucleusPainter extends CustomPainter {
  final NucleusState nucleus;
  final bool isRealityStable;

  _NucleusPainter({required this.nucleus, required this.isRealityStable});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = min(size.width, size.height) * 0.32;

    // Background halo
    final haloPaint =
        Paint()
          ..shader = RadialGradient(
            colors: [
              (isRealityStable ? Colors.tealAccent : Colors.redAccent)
                  .withOpacity(0.24),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(center: center, radius: maxRadius * 1.5),
          );
    canvas.drawCircle(center, maxRadius * 1.5, haloPaint);

    // Main sphere
    final corePaint =
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.2, -0.3),
            radius: 1.0,
            colors:
                isRealityStable
                    ? [
                      const Color(0xFF00FFC3),
                      const Color(0xFF0070FF),
                      const Color(0xFF050509),
                    ]
                    : [
                      const Color(0xFFFF3B8D),
                      const Color(0xFF5A144A),
                      const Color(0xFF050509),
                    ],
          ).createShader(Rect.fromCircle(center: center, radius: maxRadius));
    canvas.drawCircle(center, maxRadius, corePaint);

    // Nucleons on shells
    final total = nucleus.massNumber.clamp(1, 120);
    final protonCount = nucleus.protons.clamp(0, total);
    final neutronCount = (total - protonCount).clamp(0, total);

    final shells = (sqrt(total / 4)).ceil().clamp(1, 5);
    final rngSeed = nucleus.massNumber * 7919 + nucleus.protons * 13;
    final random = Random(rngSeed);

    int placed = 0;
    for (int s = 0; s < shells; s++) {
      final shellRadius = maxRadius * (0.3 + 0.6 * (s + 1) / shells);
      final countOnShell = (total / shells).ceil();
      for (int i = 0; i < countOnShell && placed < total; i++) {
        final angle = 2 * pi * (i / countOnShell) + random.nextDouble() * 0.3;
        final pos = Offset(
          center.dx + shellRadius * cos(angle),
          center.dy + shellRadius * sin(angle),
        );

        final isProton = placed < protonCount;
        final nucleonPaint =
            Paint()
              ..color =
                  isProton
                      ? Colors.pinkAccent.withOpacity(0.95)
                      : Colors.indigoAccent.withOpacity(0.95);

        final r = maxRadius * 0.06;
        canvas.drawCircle(pos, r, nucleonPaint);
        placed++;
      }
    }

    // Electron orbit
    final orbitPaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = Colors.white.withOpacity(0.2);
    final orbitR = maxRadius * 1.2;
    canvas.drawOval(
      Rect.fromCircle(center: center, radius: orbitR),
      orbitPaint,
    );

    // Electrons
    final electronsToShow = 4;
    for (int i = 0; i < electronsToShow; i++) {
      final angle =
          2 * pi * (i / electronsToShow) +
          (nucleus.protons * 0.1 + nucleus.neutrons * 0.07);
      final pos = Offset(
        center.dx + orbitR * cos(angle),
        center.dy + orbitR * sin(angle),
      );
      final ePaint = Paint()..color = Colors.tealAccent.withOpacity(0.9);
      canvas.drawCircle(pos, maxRadius * 0.035, ePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _NucleusPainter oldDelegate) {
    return oldDelegate.nucleus.protons != nucleus.protons ||
        oldDelegate.nucleus.neutrons != nucleus.neutrons ||
        oldDelegate.isRealityStable != isRealityStable;
  }
}

// ---------- Periodic table panel ----------

class _PeriodicTablePanel extends StatelessWidget {
  final Set<int> discoveredZ;
  final int currentZ;

  const _PeriodicTablePanel({
    required this.discoveredZ,
    required this.currentZ,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.16)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF050509), Color(0xFF151A2A)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: _PeriodicTableGrid(discoveredZ: discoveredZ, currentZ: currentZ),
      ),
    );
  }
}

class _PeriodicTableGrid extends StatelessWidget {
  final Set<int> discoveredZ;
  final int currentZ;

  const _PeriodicTableGrid({required this.discoveredZ, required this.currentZ});

  @override
  Widget build(BuildContext context) {
    const rows = 7;
    const cols = 18;

    final Map<String, ElementDef> byPos = {
      for (final e in allElements) '${e.period}-${e.group}': e,
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth = constraints.maxWidth / cols;
        final cellHeight = constraints.maxHeight / rows;

        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _PeriodicTablePainter(
            rows: rows,
            cols: cols,
            byPos: byPos,
            discoveredZ: discoveredZ,
            currentZ: currentZ,
            cellWidth: cellWidth,
            cellHeight: cellHeight,
          ),
        );
      },
    );
  }
}

class _PeriodicTablePainter extends CustomPainter {
  final int rows;
  final int cols;
  final Map<String, ElementDef> byPos;
  final Set<int> discoveredZ;
  final int currentZ;
  final double cellWidth;
  final double cellHeight;

  _PeriodicTablePainter({
    required this.rows,
    required this.cols,
    required this.byPos,
    required this.discoveredZ,
    required this.currentZ,
    required this.cellWidth,
    required this.cellHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5
          ..color = Colors.white.withOpacity(0.14);

    final fillPaint = Paint()..style = PaintingStyle.fill;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final rect = Rect.fromLTWH(
          c * cellWidth,
          r * cellHeight,
          cellWidth,
          cellHeight,
        );
        final key = '${r + 1}-${c + 1}';
        final element = byPos[key];

        if (element != null) {
          final isDiscovered = discoveredZ.contains(element.Z);
          final isCurrent = element.Z == currentZ;

          Color baseColor;
          if (isCurrent && isDiscovered) {
            baseColor = Colors.tealAccent;
          } else if (isCurrent && !isDiscovered) {
            baseColor = Colors.amberAccent.withOpacity(0.9);
          } else if (isDiscovered) {
            baseColor = Colors.tealAccent.withOpacity(0.35);
          } else {
            baseColor = Colors.white.withOpacity(0.06);
          }

          fillPaint.color = baseColor;
          canvas.drawRect(rect.deflate(2.0), fillPaint);
          canvas.drawRect(rect.deflate(2.0), borderPaint);

          final symbolPainter = TextPainter(
            text: TextSpan(
              text: element.symbol,
              style: TextStyle(
                fontSize: cellHeight * 0.32,
                fontWeight: FontWeight.w600,
                color:
                    (isCurrent && isDiscovered)
                        ? Colors.black
                        : Colors.white.withOpacity(
                          isDiscovered || isCurrent ? 0.9 : 0.7,
                        ),
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: rect.width - 4);

          final ZPainter = TextPainter(
            text: TextSpan(
              text: '${element.Z}',
              style: TextStyle(
                fontSize: cellHeight * 0.18,
                color:
                    (isCurrent && isDiscovered)
                        ? Colors.black.withOpacity(0.8)
                        : Colors.white.withOpacity(0.7),
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: rect.width - 4);

          symbolPainter.paint(
            canvas,
            Offset(
              rect.left + (rect.width - symbolPainter.width) / 2,
              rect.top + rect.height * 0.30 - symbolPainter.height / 2,
            ),
          );

          ZPainter.paint(canvas, Offset(rect.left + 4, rect.top + 3));
        } else {
          // Empty cell frame
          canvas.drawRect(rect.deflate(4.0), borderPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PeriodicTablePainter oldDelegate) {
    return oldDelegate.currentZ != currentZ ||
        oldDelegate.discoveredZ.length != discoveredZ.length;
  }
}

// ---------- Submission log ----------

class _SubmissionLog extends StatelessWidget {
  final List<SubmissionRecord> submissions;

  const _SubmissionLog({required this.submissions});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Row(
                children: [
                  Text(
                    'Submissions (inner vs reality)',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.8),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.white24),
            Expanded(
              child:
                  submissions.isEmpty
                      ? Center(
                        child: Text(
                          'No submissions yet. When the inner engine thinks it found a stable nucleus, it will appear here.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.6),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                      : ListView.builder(
                        reverse: false,
                        itemCount: submissions.length,
                        itemBuilder: (context, index) {
                          final sub = submissions[index];
                          return _SubmissionRow(record: sub);
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubmissionRow extends StatelessWidget {
  final SubmissionRecord record;

  const _SubmissionRow({required this.record});

  @override
  Widget build(BuildContext context) {
    final r = record.result;
    final Z = r.nucleus.protons;
    final N = r.nucleus.neutrons;
    final A = r.nucleus.massNumber;

    final emoji =
        r.isCorrect
            ? '✅'
            : (r.innerThinksStable && !r.realityStable ? '❌' : '•');

    final elementLabel = r.elementDef != null ? r.elementDef!.symbol : '–';

    final realityLabel =
        r.realityStable
            ? 'stable (${elementLabel})'
            : (r.inPeriodicTable ? 'unstable here' : 'not in table');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 38,
            child: Text(
              '#${record.attempt}',
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ),
          SizedBox(
            width: 78,
            child: Text('Z=$Z N=$N A=$A', style: const TextStyle(fontSize: 11)),
          ),
          SizedBox(
            width: 70,
            child: Text(
              r.innerThinksStable ? 'engine: stable' : 'engine: unstable',
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withOpacity(0.75),
              ),
            ),
          ),
          Expanded(
            child: Text(
              'reality: $realityLabel  $emoji',
              style: TextStyle(
                fontSize: 10,
                color:
                    r.isCorrect
                        ? Colors.tealAccent
                        : (r.innerThinksStable && !r.realityStable
                            ? Colors.redAccent
                            : Colors.white.withOpacity(0.7)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
*/