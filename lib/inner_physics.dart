// lib/inner_physics.dart
//
// Inner physics engine ("brain 1"):
// - Only knows about protons (Z) and neutrons (N).
// - Has its own parametric rule for "stability".
// - Randomly explores (Z, N) space with a mix of local moves, valley-seeking
//   moves, and occasional global jumps, so it's not trapped near the start.
// - Remembers nuclei that have been *correctly* judged stable and avoids
//   revisiting them, so it keeps exploring new territory.
//
// Important: we are NOT changing the Judge's criteria.
// We're only making the search dynamics less dumb.

import 'dart:math';

class NucleusState {
  final int protons; // Z
  final int neutrons; // N

  const NucleusState({required this.protons, required this.neutrons});

  int get massNumber => protons + neutrons;

  NucleusState copyWith({int? protons, int? neutrons}) {
    return NucleusState(
      protons: protons ?? this.protons,
      neutrons: neutrons ?? this.neutrons,
    );
  }
}

class InnerStepResult {
  final NucleusState nucleus;
  final bool innerThinksStable;

  const InnerStepResult({
    required this.nucleus,
    required this.innerThinksStable,
  });
}

class InnerPhysicsEngine {
  final Random _rng;

  // States that have been confirmed "correct" by the Judge:
  // i.e. innerThinksStable == true AND realityStable == true.
  // We store them as "Z:N" strings.
  final Set<String> _solvedStates = {};

  // Parameters for the inner "stability rule" (tunable later for learning).
  double targetRatioSmallZ;
  double targetRatioLargeZ;
  int transitionZ;
  double baseTolerance;
  double toleranceSlope;

  // Search dynamics parameters.
  //
  // - localStepMax: max magnitude for local moves in Z and N.
  // - valleyMoveProb: probability of taking a step that tries to move N
  //   toward the engine's own target N(Z).
  // - globalJumpProb: probability of a big "teleport" to a new (Z, N).
  final int localStepMax;
  final double valleyMoveProb;
  final double globalJumpProb;

  NucleusState _state;

  InnerPhysicsEngine({
    int? seed,
    this.targetRatioSmallZ = 1.0,
    this.targetRatioLargeZ = 1.3,
    this.transitionZ = 20,
    this.baseTolerance = 2.0,
    this.toleranceSlope = 0.10,
    int initialZ = 1,
    int initialN = 0,
    this.localStepMax = 2,
    this.valleyMoveProb = 0.15,
    this.globalJumpProb = 0.05,
  }) : _rng = Random(seed),
       _state = NucleusState(protons: initialZ, neutrons: initialN);

  NucleusState get state => _state;

  // --- Solved-state helpers -------------------------------------------------

  String _key(int Z, int N) => '$Z:$N';

  /// Called by the outer world when the Judge confirms a "correct" nucleus.
  void markSolved(NucleusState nucleus) {
    _solvedStates.add(_key(nucleus.protons, nucleus.neutrons));
  }

  /// Optional explicit clear; reset() also clears solved states.
  void clearSolved() {
    _solvedStates.clear();
  }

  void reset({required int maxZ}) {
    _solvedStates.clear();
    final z = 1 + _rng.nextInt(maxZ.clamp(1, 128));
    final n = _rng.nextInt(maxZ * 2);
    _state = NucleusState(protons: z, neutrons: n);
  }

  /// Inner engine's own guess for the N/Z ratio at a given Z.
  /// We approximate the real valley of stability:
  /// - Light nuclei: N ~ Z (ratio ~ 1.0–1.2)
  /// - Mid-Z: ratio slowly rises
  /// - Heavy (around Pb): ratio ~ 1.5–1.6
  double _innerTargetRatio(int Z) {
    if (Z <= 0) return 1.0;

    // 1) Light region: up to Z ≈ 20,
    //    let the ratio rise very slowly from ~1.0 to ~1.2.
    if (Z <= 20) {
      return 1.0 + 0.01 * Z; // Z=0 → 1.0, Z=20 → 1.2
    }

    // 2) Heavy region: Z ≥ 82 (around lead),
    //    clamp to ~1.55.
    if (Z >= 82) {
      return 1.55;
    }

    // 3) Mid region: smoothly interpolate between (Z=20, ratio=1.2)
    //    and (Z=82, ratio=1.55).
    const double r20 = 1.2;
    const double r82 = 1.55;
    final double t = (Z - 20) / (82 - 20); // in [0, 1]
    return r20 + (r82 - r20) * t;
  }

  /*
  /// Inner engine's own guess for the "valley" at a given Z.
  /// This is separate from the Judge's model; it's what the engine *believes*.
  double _innerTargetRatio(int Z) {
    if (Z <= 0) return 1.0;
    if (Z < transitionZ) {
      return targetRatioSmallZ; // ~1.0 for light nuclei
    } else {
      return targetRatioLargeZ; // ~1.3 for heavier ones
    }
  }
*/
  int _innerTargetN(int Z) {
    final ratio = _innerTargetRatio(Z);
    int n = (ratio * Z).round();
    if (n < 0) n = 0;
    return n;
  }

  /// One random "tick" in (Z, N) space.
  /// We mix three behaviours:
  ///   - Local random walk (most of the time)
  ///   - Valley-seeking step (sometimes)
  ///   - Global random jump (rarely)
  InnerStepResult step({required int maxZ}) {
    final double r = _rng.nextDouble();

    if (r < globalJumpProb) {
      // --- Rare global jump: explore a totally new region ---
      _doGlobalJump(maxZ: maxZ);
    } else if (r < globalJumpProb + valleyMoveProb) {
      // --- Valley-seeking move: adjust N toward inner target ---
      _doValleyMove(maxZ: maxZ);
    } else {
      // --- Default: small local random move ---
      _doLocalMove(maxZ: maxZ);
    }

    final stable = _innerStabilityRule(_state.protons, _state.neutrons);
    return InnerStepResult(nucleus: _state, innerThinksStable: stable);
  }

  void _doLocalMove({required int maxZ}) {
    // Allow a bit larger range than ±1, but still "local".
    int dZ = _rng.nextInt(2 * localStepMax + 1) - localStepMax;
    int dN = _rng.nextInt(2 * localStepMax + 1) - localStepMax;

    // Avoid the "no move" case.
    if (dZ == 0 && dN == 0) {
      dZ = 1;
    }

    int newZ = _state.protons + dZ;
    int newN = _state.neutrons + dN;

    if (newZ < 1) newZ = 1;
    if (newZ > maxZ + 10) newZ = maxZ + 10; // allow some beyond-known

    if (newN < 0) newN = 0;
    if (newN > (maxZ + 10) * 3) {
      newN = (maxZ + 10) * 3;
    }

    // If this exact (Z, N) has already been correctly solved,
    // nudge away a bit so we don't waste time there.
    int tries = 0;
    while (tries < 5 && _solvedStates.contains(_key(newZ, newN))) {
      newZ += _rng.nextBool() ? 1 : -1;
      newN += _rng.nextInt(3) - 1;

      if (newZ < 1) newZ = 1;
      if (newZ > maxZ + 10) newZ = maxZ + 10;
      if (newN < 0) newN = 0;
      if (newN > (maxZ + 10) * 3) {
        newN = (maxZ + 10) * 3;
      }

      tries++;
    }

    _state = NucleusState(protons: newZ, neutrons: newN);
  }

  void _doValleyMove({required int maxZ}) {
    int Z = _state.protons;
    int N = _state.neutrons;

    if (Z < 1) Z = 1;
    if (Z > maxZ + 10) Z = maxZ + 10;

    final targetN = _innerTargetN(Z);

    // Move N one step toward the engine's own target N(Z).
    int dN = 0;
    if (N < targetN) {
      dN = 1;
    } else if (N > targetN) {
      dN = -1;
    } else {
      // Already on the valley for this Z; nudge Z a bit to slide along it.
      final dir = _rng.nextBool() ? 1 : -1;
      Z += dir;
    }

    int newZ = Z;
    int newN = N + dN;

    if (newZ < 1) newZ = 1;
    if (newZ > maxZ + 10) newZ = maxZ + 10;
    if (newN < 0) newN = 0;
    if (newN > (maxZ + 10) * 3) {
      newN = (maxZ + 10) * 3;
    }

    // Avoid exact revisits to already-solved nuclei.
    int tries = 0;
    while (tries < 5 && _solvedStates.contains(_key(newZ, newN))) {
      // Slide along the valley or shift Z slightly.
      newZ += _rng.nextBool() ? 1 : -1;
      newN += _rng.nextInt(3) - 1;

      if (newZ < 1) newZ = 1;
      if (newZ > maxZ + 10) newZ = maxZ + 10;
      if (newN < 0) newN = 0;
      if (newN > (maxZ + 10) * 3) {
        newN = (maxZ + 10) * 3;
      }

      tries++;
    }

    _state = NucleusState(protons: newZ, neutrons: newN);
  }

  void _doGlobalJump({required int maxZ}) {
    // Pick a new Z anywhere in (1 .. maxZ+something).
    int newZ = 1 + _rng.nextInt(((maxZ + 10).clamp(2, 140)).toInt());
    // Choose N near the engine's own valley guess for that Z, with some noise.
    final targetN = _innerTargetN(newZ);
    int newN = targetN + (_rng.nextInt(9) - 4); // ±4
    if (newN < 0) newN = 0;

    // Try a few times to avoid landing exactly on a solved state.
    int tries = 0;
    while (tries < 5 && _solvedStates.contains(_key(newZ, newN))) {
      newZ = 1 + _rng.nextInt(((maxZ + 10).clamp(2, 140)).toInt());
      final tN = _innerTargetN(newZ);
      newN = tN + (_rng.nextInt(9) - 4);
      if (newN < 0) newN = 0;
      tries++;
    }

    _state = NucleusState(protons: newZ, neutrons: newN);
  }

  /// The inner engine's private idea of "stability",
  /// which can later be learned/tuned.
  bool _innerStabilityRule(int Z, int N) {
    if (Z <= 0 || N <= 0) return false;

    // Use the smooth, Z-dependent ratio curve.
    final ratio = _innerTargetRatio(Z);
    final targetN = ratio * Z;

    // Let the allowed deviation grow with Z so mid/heavy nuclei
    // can still be considered "close" to the valley.
    final tol = baseTolerance + toleranceSlope * Z;
    final diff = (N - targetN).abs();

    return diff <= tol;
  }
}




















/* good but now we are going to let it kow wehen it gets correct answers and no to retry
// lib/inner_physics.dart
//
// Inner physics engine ("brain 1"):
// - Only knows about protons (Z) and neutrons (N).
// - Has its own parametric rule for "stability".
// - Randomly explores (Z, N) space with a mix of local moves, valley-seeking
//   moves, and occasional global jumps, so it's not trapped near the start.
//
// Important: we are NOT changing the Judge's criteria.
// We're only making the search dynamics less dumb.

import 'dart:math';

class NucleusState {
  final int protons; // Z
  final int neutrons; // N

  const NucleusState({required this.protons, required this.neutrons});

  int get massNumber => protons + neutrons;

  NucleusState copyWith({int? protons, int? neutrons}) {
    return NucleusState(
      protons: protons ?? this.protons,
      neutrons: neutrons ?? this.neutrons,
    );
  }
}

class InnerStepResult {
  final NucleusState nucleus;
  final bool innerThinksStable;

  const InnerStepResult({
    required this.nucleus,
    required this.innerThinksStable,
  });
}

class InnerPhysicsEngine {
  final Random _rng;

  // Parameters for the inner "stability rule" (tunable later for learning).
  double targetRatioSmallZ;
  double targetRatioLargeZ;
  int transitionZ;
  double baseTolerance;
  double toleranceSlope;

  // Search dynamics parameters.
  //
  // - localStepMax: max magnitude for local moves in Z and N.
  // - valleyMoveProb: probability of taking a step that tries to move N
  //   toward the engine's own target N(Z).
  // - globalJumpProb: probability of a big "teleport" to a new (Z, N).
  final int localStepMax;
  final double valleyMoveProb;
  final double globalJumpProb;

  NucleusState _state;

  InnerPhysicsEngine({
    int? seed,
    this.targetRatioSmallZ = 1.0,
    this.targetRatioLargeZ = 1.3,
    this.transitionZ = 20,
    this.baseTolerance = 2.0,
    this.toleranceSlope = 0.05,
    int initialZ = 1,
    int initialN = 0,
    this.localStepMax = 2,
    this.valleyMoveProb = 0.15,
    this.globalJumpProb = 0.05,
  }) : _rng = Random(seed),
       _state = NucleusState(protons: initialZ, neutrons: initialN);

  NucleusState get state => _state;

  void reset({required int maxZ}) {
    final z = 1 + _rng.nextInt(maxZ.clamp(1, 128));
    final n = _rng.nextInt(maxZ * 2);
    _state = NucleusState(protons: z, neutrons: n);
  }

  /// Inner engine's own guess for the "valley" at a given Z.
  /// This is separate from the Judge's model; it's what the engine *believes*.
  double _innerTargetRatio(int Z) {
    if (Z <= 0) return 1.0;
    if (Z < transitionZ) {
      return targetRatioSmallZ; // ~1.0 for light nuclei
    } else {
      return targetRatioLargeZ; // ~1.3 for heavier ones
    }
  }

  int _innerTargetN(int Z) {
    final ratio = _innerTargetRatio(Z);
    int n = (ratio * Z).round();
    if (n < 0) n = 0;
    return n;
  }

  /// One random "tick" in (Z, N) space.
  /// We mix three behaviours:
  ///   - Local random walk (most of the time)
  ///   - Valley-seeking step (sometimes)
  ///   - Global random jump (rarely)
  InnerStepResult step({required int maxZ}) {
    final double r = _rng.nextDouble();

    if (r < globalJumpProb) {
      // --- Rare global jump: explore a totally new region ---
      _doGlobalJump(maxZ: maxZ);
    } else if (r < globalJumpProb + valleyMoveProb) {
      // --- Valley-seeking move: adjust N toward inner target ---
      _doValleyMove(maxZ: maxZ);
    } else {
      // --- Default: small local random move ---
      _doLocalMove(maxZ: maxZ);
    }

    final stable = _innerStabilityRule(_state.protons, _state.neutrons);
    return InnerStepResult(nucleus: _state, innerThinksStable: stable);
  }

  void _doLocalMove({required int maxZ}) {
    // Allow a bit larger range than ±1, but still "local".
    int dZ = _rng.nextInt(2 * localStepMax + 1) - localStepMax;
    int dN = _rng.nextInt(2 * localStepMax + 1) - localStepMax;

    // Avoid the "no move" case.
    if (dZ == 0 && dN == 0) {
      dZ = 1;
    }

    int newZ = _state.protons + dZ;
    int newN = _state.neutrons + dN;

    if (newZ < 1) newZ = 1;
    if (newZ > maxZ + 10) newZ = maxZ + 10; // allow some beyond-known

    if (newN < 0) newN = 0;
    if (newN > (maxZ + 10) * 3) {
      newN = (maxZ + 10) * 3;
    }

    _state = NucleusState(protons: newZ, neutrons: newN);
  }

  void _doValleyMove({required int maxZ}) {
    int Z = _state.protons;
    int N = _state.neutrons;

    if (Z < 1) Z = 1;
    if (Z > maxZ + 10) Z = maxZ + 10;

    final targetN = _innerTargetN(Z);

    // Move N one step toward the engine's own target N(Z).
    int dN = 0;
    if (N < targetN) {
      dN = 1;
    } else if (N > targetN) {
      dN = -1;
    } else {
      // Already on the valley for this Z; nudge Z a bit to slide along it.
      final dir = _rng.nextBool() ? 1 : -1;
      Z += dir;
    }

    int newZ = Z;
    int newN = N + dN;

    if (newZ < 1) newZ = 1;
    if (newZ > maxZ + 10) newZ = maxZ + 10;
    if (newN < 0) newN = 0;
    if (newN > (maxZ + 10) * 3) {
      newN = (maxZ + 10) * 3;
    }

    _state = NucleusState(protons: newZ, neutrons: newN);
  }

  void _doGlobalJump({required int maxZ}) {
    // Pick a new Z anywhere in (1 .. maxZ+something).
    final newZ = 1 + _rng.nextInt((maxZ + 10).clamp(2, 140));
    // Choose N near the engine's own valley guess for that Z, with some noise.
    final targetN = _innerTargetN(newZ);
    final noise = _rng.nextInt(9) - 4; // ±4
    int newN = targetN + noise;
    if (newN < 0) newN = 0;

    _state = NucleusState(protons: newZ, neutrons: newN);
  }

  /// The inner engine's private idea of "stability",
  /// which can later be learned/tuned.
  bool _innerStabilityRule(int Z, int N) {
    if (Z <= 0 || N <= 0) return false;

    final ratio = Z < transitionZ ? targetRatioSmallZ : targetRatioLargeZ;
    final targetN = ratio * Z;
    final tol = baseTolerance + toleranceSlope * Z;
    final diff = (N - targetN).abs();

    return diff <= tol;
  }
}
*/



























/* good but need to change the only +- 1
// lib/inner_physics.dart
//
// Inner physics engine ("brain 1"):
// - Only knows about protons (Z) and neutrons (N).
// - Has a more physics-flavoured rule for "stability":
//     * prefers certain N/Z ratios,
//     * bonus for even-even nuclei (pairing),
//     * bonus near magic numbers,
//     * loose tolerance that grows with Z.
// - Moves in (Z, N) space using rough nuclear reactions:
//     * random jitter,
//     * beta- / beta+ decay,
//     * neutron capture,
//     * alpha decay.

import 'dart:math';

class NucleusState {
  final int protons; // Z
  final int neutrons; // N

  const NucleusState({required this.protons, required this.neutrons});

  int get massNumber => protons + neutrons;

  NucleusState copyWith({int? protons, int? neutrons}) {
    return NucleusState(
      protons: protons ?? this.protons,
      neutrons: neutrons ?? this.neutrons,
    );
  }
}

class InnerStepResult {
  final NucleusState nucleus;
  final bool innerThinksStable;

  const InnerStepResult({
    required this.nucleus,
    required this.innerThinksStable,
  });
}

/// Parameters that define "this universe's" stability landscape.
/// You could later let the user tweak these for alternate universes.
class PhysicsParams {
  double targetRatioSmallZ;
  double targetRatioLargeZ;
  int transitionZ;
  double baseTolerance;
  double toleranceSlope;

  double pairingBonus; // extra stability for even-even
  double magicStrength; // how strong magic numbers are
  double baseStableThreshold; // lower = stricter stability

  PhysicsParams({
    this.targetRatioSmallZ = 1.0,
    this.targetRatioLargeZ = 1.5,
    this.transitionZ = 20,
    this.baseTolerance = 2.0,
    this.toleranceSlope = 0.25,
    this.pairingBonus = 0.6,
    this.magicStrength = 0.9,
    this.baseStableThreshold = 1.0,
  });

  PhysicsParams clone() {
    return PhysicsParams(
      targetRatioSmallZ: targetRatioSmallZ,
      targetRatioLargeZ: targetRatioLargeZ,
      transitionZ: transitionZ,
      baseTolerance: baseTolerance,
      toleranceSlope: toleranceSlope,
      pairingBonus: pairingBonus,
      magicStrength: magicStrength,
      baseStableThreshold: baseStableThreshold,
    );
  }
}

class InnerPhysicsEngine {
  final Random _rng;

  PhysicsParams params;

  NucleusState _state;

  InnerPhysicsEngine({
    int? seed,
    PhysicsParams? params,
    int initialZ = 1,
    int initialN = 0,
  }) : _rng = Random(seed),
       params = params ?? PhysicsParams(),
       _state = NucleusState(protons: initialZ, neutrons: initialN);

  NucleusState get state => _state;

  /// Choose a "preset universe". You can call this later from the UI if you
  /// want to expose multiple universes.
  void setPreset(String presetName) {
    // Start from a default and then tweak.
    final p = PhysicsParams();

    switch (presetName) {
      case 'neutronRich':
        p.targetRatioSmallZ = 1.2;
        p.targetRatioLargeZ = 1.8;
        p.baseTolerance = 3.0;
        p.toleranceSlope = 0.35;
        p.pairingBonus = 0.5;
        p.magicStrength = 0.7;
        p.baseStableThreshold = 1.1;
        break;
      case 'magicHeavy':
        p.targetRatioSmallZ = 1.0;
        p.targetRatioLargeZ = 1.4;
        p.baseTolerance = 1.8;
        p.toleranceSlope = 0.20;
        p.pairingBonus = 0.4;
        p.magicStrength = 1.4; // really loves magic numbers
        p.baseStableThreshold = 1.0;
        break;
      case 'standard':
      default:
        // already default
        break;
    }

    params = p;
  }

  void reset({required int maxZ}) {
    // Start from a light-ish random nucleus.
    final z = 1 + _rng.nextInt(maxZ.clamp(1, 64));
    final n = max(0, z + _rng.nextInt(2 * z) - z); // around N~Z
    _state = NucleusState(protons: z, neutrons: n);
  }

  /// One random "tick" in (Z, N) space using crude reaction rules.
  InnerStepResult step({required int maxZ}) {
    _state = _proposeReaction(_state, maxZ: maxZ);
    final stable = _innerStabilityRule(_state.protons, _state.neutrons);
    return InnerStepResult(nucleus: _state, innerThinksStable: stable);
  }

  // ---------------- Internal helpers ----------------

  NucleusState _proposeReaction(NucleusState current, {required int maxZ}) {
    int Z = current.protons;
    int N = current.neutrons;

    double r = _rng.nextDouble();

    if (r < 0.40) {
      // 40%: small random jitter in Z,N (diffusion).
      final dZ = _rng.nextInt(3) - 1; // -1,0,+1
      final dN = _rng.nextInt(3) - 1;
      Z += dZ;
      N += dN;
    } else if (r < 0.60) {
      // 20%: beta- decay: n -> p + e-  (Z+1, N-1)
      Z += 1;
      N -= 1;
    } else if (r < 0.80) {
      // 20%: beta+ / electron capture: p -> n  (Z-1, N+1)
      Z -= 1;
      N += 1;
    } else if (r < 0.95) {
      // 15%: neutron capture (e.g. in stellar environments): (Z, N+1)
      N += 1;
    } else {
      // 5%: alpha decay: (Z-2, N-2)
      Z -= 2;
      N -= 2;
    }

    // Clamp to "universe box" + allow a little beyond maxZ to explore.
    if (Z < 1) Z = 1;
    if (Z > maxZ + 10) Z = maxZ + 10;

    if (N < 0) N = 0;
    if (N > (maxZ + 10) * 3) {
      N = (maxZ + 10) * 3;
    }

    return NucleusState(protons: Z, neutrons: N);
  }

  /// Inner engine's private view of stability.
  /// We treat it like a "score": lower is better, below threshold = stable.
  bool _innerStabilityRule(int Z, int N) {
    if (Z <= 0 || N <= 0) return false;

    final p = params;

    // 1) Valley of stability via N/Z ratio.
    final ratio =
        (Z < p.transitionZ) ? p.targetRatioSmallZ : p.targetRatioLargeZ;
    final targetN = ratio * Z;
    final tol = p.baseTolerance + p.toleranceSlope * Z;
    final diff = (N - targetN).abs();

    // Normalised penalty: 0 when exactly on target, ~1 when at edge of tol.
    double score = diff / max(tol, 1e-3);

    // 2) Pairing term: even-even nuclei are extra stable, odd-odd are worse.
    final bool evenZ = (Z % 2 == 0);
    final bool evenN = (N % 2 == 0);
    if (evenZ && evenN) {
      score -= p.pairingBonus;
    } else if (!evenZ && !evenN) {
      score += p.pairingBonus * 0.5;
    }

    // 3) Magic numbers: extra stability when Z or N near magic numbers.
    const magic = [2, 8, 20, 28, 50, 82, 126];
    double bestMagicDist = 9999.0;
    for (final m in magic) {
      bestMagicDist = min(bestMagicDist, (Z - m).abs().toDouble());
      bestMagicDist = min(bestMagicDist, (N - m).abs().toDouble());
    }
    // Convert distance to a bonus in [0, magicStrength].
    // Within ~3 units: strong bonus. Past ~10: basically none.
    final magicFactor =
        bestMagicDist >= 10.0 ? 0.0 : (1.0 - bestMagicDist / 10.0);
    score -= p.magicStrength * magicFactor;

    // (You could add surface/volume terms in A here if you want more detail.)

    return score <= p.baseStableThreshold;
  }
}
*/










































/* TOY VERSION, works well, N ≈ c·Z with a fuzzy window
// lib/inner_physics.dart
//
// Inner physics engine ("brain 1"):
// - Only knows about protons (Z) and neutrons (N).
// - Has its own parametric rule for "stability".
// - Randomly wanders around (Z, N) space and occasionally says "this is stable".

import 'dart:math';

class NucleusState {
  final int protons; // Z
  final int neutrons; // N

  const NucleusState({required this.protons, required this.neutrons});

  int get massNumber => protons + neutrons;

  NucleusState copyWith({int? protons, int? neutrons}) {
    return NucleusState(
      protons: protons ?? this.protons,
      neutrons: neutrons ?? this.neutrons,
    );
  }
}

class InnerStepResult {
  final NucleusState nucleus;
  final bool innerThinksStable;

  const InnerStepResult({
    required this.nucleus,
    required this.innerThinksStable,
  });
}

class InnerPhysicsEngine {
  final Random _rng;

  // Parameters for the inner "stability rule" (tunable later for learning).
  double targetRatioSmallZ;
  double targetRatioLargeZ;
  int transitionZ;
  double baseTolerance;
  double toleranceSlope;

  NucleusState _state;

  InnerPhysicsEngine({
    int? seed,
    this.targetRatioSmallZ = 1.0,
    this.targetRatioLargeZ = 1.3,
    this.transitionZ = 20,
    this.baseTolerance = 2.0,
    this.toleranceSlope = 0.05,
    int initialZ = 1,
    int initialN = 0,
  }) : _rng = Random(seed),
       _state = NucleusState(protons: initialZ, neutrons: initialN);

  NucleusState get state => _state;

  void reset({required int maxZ}) {
    final z = 1 + _rng.nextInt(maxZ.clamp(1, 128));
    final n = _rng.nextInt(maxZ * 2);
    _state = NucleusState(protons: z, neutrons: n);
  }

  /// One random "tick" in (Z, N) space.
  InnerStepResult step({required int maxZ}) {
    // Propose small random changes.
    final dZ = _rng.nextInt(3) - 1; // -1, 0, +1
    final dN = _rng.nextInt(3) - 1;

    int newZ = _state.protons + dZ;
    int newN = _state.neutrons + dN;

    if (newZ < 1) newZ = 1;
    if (newZ > maxZ + 10) newZ = maxZ + 10; // allow some beyond-known

    if (newN < 0) newN = 0;
    if (newN > (maxZ + 10) * 3) {
      newN = (maxZ + 10) * 3;
    }

    _state = NucleusState(protons: newZ, neutrons: newN);

    final stable = _innerStabilityRule(newZ, newN);

    return InnerStepResult(nucleus: _state, innerThinksStable: stable);
  }

  /// The inner engine's private idea of "stability",
  /// which can later be learned/tuned.
  bool _innerStabilityRule(int Z, int N) {
    if (Z <= 0 || N <= 0) return false;

    final ratio = Z < transitionZ ? targetRatioSmallZ : targetRatioLargeZ;

    final targetN = ratio * Z;
    final tol = baseTolerance + toleranceSlope * Z;
    final diff = (N - targetN).abs();

    return diff <= tol;
  }
}
*/