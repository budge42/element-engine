// same rules just adding more isotopes

// lib/judge.dart
//
// Outer "judge" brain:
// - Knows the periodic table.
// - Knows approximate stable isotopes for each Z.
// - Compares inner engine's claims to reality and logs correctness.
//
// Philosophy:
// - For Z where we have explicit stable isotope data, use that.
// - For heavier Z where data is missing, approximate the "valley of stability"
//   using a physically-motivated N/Z ratio curve, but keep a strict ±1 neutron window.

import 'inner_physics.dart';
import 'periodic_table.dart';

class JudgeResult {
  final NucleusState nucleus;
  final bool innerThinksStable;
  final bool realityStable;
  final bool inPeriodicTable;
  final ElementDef? elementDef;
  final int? closestStableNeutrons;
  final bool isCorrect; // innerStable && realityStable && inTable

  const JudgeResult({
    required this.nucleus,
    required this.innerThinksStable,
    required this.realityStable,
    required this.inPeriodicTable,
    required this.elementDef,
    required this.closestStableNeutrons,
    required this.isCorrect,
  });
}

class Judge {
  // Map from Z to list of (stable) neutron counts N = A - Z for which we have
  // explicit data. This is dense for light/medium elements and sparse later.
  final Map<int, List<int>> stableIsotopes;

  // Which atomic numbers we've actually "discovered" in reality-stable sense.
  final Set<int> discoveredZ = {};

  Judge({Map<int, List<int>>? stableIsotopesOverride})
    : stableIsotopes = stableIsotopesOverride ?? _defaultStableIsotopes;

  bool isInTable(int Z) => elementByZ.containsKey(Z);

  /// Physically-motivated approximate N/Z trend ("valley of stability")
  /// used when we don't have explicit isotope data for this Z.
  ///
  /// This is NOT a fudge tolerance – it is a specific line in (Z, N) space.
  /// We still demand |N - N_target| <= 1 to call it stable.
  int _approxStableN(int Z) {
    if (Z <= 0) return 0;

    // Piecewise linear-ish N/Z curve:
    //   - Light:  N/Z ~ 1.0
    //   - Medium: N/Z climbs toward ~1.3
    //   - Heavy:  N/Z climbs further toward ~1.45–1.5
    double ratio;
    if (Z <= 20) {
      ratio = 1.0;
    } else if (Z <= 40) {
      // interpolate from 1.0 → 1.2
      final t = (Z - 20) / 20.0;
      ratio = 1.0 + 0.2 * t;
    } else if (Z <= 60) {
      // 1.2 → 1.32
      final t = (Z - 40) / 20.0;
      ratio = 1.2 + 0.12 * t;
    } else if (Z <= 82) {
      // 1.32 → 1.45
      final t = (Z - 60) / 22.0;
      ratio = 1.32 + 0.13 * t;
    } else {
      // Superheavy region: very neutron-rich if it were stable at all.
      ratio = 1.5;
    }

    int n = (ratio * Z).round();

    // Even-even nuclei are generally more bound, so bias toward even N.
    if (n.isOdd) n += 1;
    return n;
  }

  /// Get the list of "target" neutron counts for this Z that define the
  /// stability tube for the Judge.
  ///
  /// Priority:
  ///   1. Use explicit stableIsotopes[Z] if present.
  ///   2. Otherwise, supply a single approximated N from _approxStableN(Z).
  List<int> _targetsForZ(int Z) {
    final explicit = stableIsotopes[Z];
    if (explicit != null && explicit.isNotEmpty) {
      return explicit;
    }
    final approxN = _approxStableN(Z);
    if (approxN <= 0) return const [];
    return [approxN];
  }

  bool _isRealityStable(int Z, int N) {
    if (!isInTable(Z)) return false;

    final Ns = _targetsForZ(Z);
    if (Ns.isEmpty) return false;

    // Treat exact match or very near matches as "stable enough".
    int bestDiff = 1 << 30;
    for (final stableN in Ns) {
      final diff = (N - stableN).abs();
      if (diff < bestDiff) bestDiff = diff;
    }

    // Keep the window tight: |N - N_target| <= 1.
    return bestDiff <= 1;
  }

  int? _closestStableN(int Z, int N) {
    final Ns = _targetsForZ(Z);
    if (Ns.isEmpty) return null;
    Ns.sort();
    int best = Ns.first;
    int bestDiff = (N - best).abs();
    for (final s in Ns.skip(1)) {
      final d = (N - s).abs();
      if (d < bestDiff) {
        bestDiff = d;
        best = s;
      }
    }
    return best;
  }

  JudgeResult evaluate(NucleusState nucleus, bool innerThinksStable) {
    final Z = nucleus.protons;
    final N = nucleus.neutrons;

    final inTable = isInTable(Z);
    final realityStable = _isRealityStable(Z, N);
    final def = inTable ? elementByZ[Z] : null;
    final closestN = inTable ? _closestStableN(Z, N) : null;

    final isCorrect = innerThinksStable && realityStable && inTable;

    if (realityStable && inTable) {
      discoveredZ.add(Z);
    }

    return JudgeResult(
      nucleus: nucleus,
      innerThinksStable: innerThinksStable,
      realityStable: realityStable,
      inPeriodicTable: inTable,
      elementDef: def,
      closestStableNeutrons: closestN,
      isCorrect: isCorrect,
    );
  }
}

// ---------------------------------------------------------------------------
// Explicit stable isotope anchors for light & mid elements.
//
// Map from atomic number Z -> list of neutron counts N = A - Z.
// These are **real** (or very close) stable nuclides, not just formula output.
// For heavier Z where this map has no entry, the Judge falls back to the
// approximate valley-of-stability curve above.
// ---------------------------------------------------------------------------
final Map<int, List<int>> _defaultStableIsotopes = {
  // Light elements (H through Ca) — mostly exact major stable isotopes.
  1: [0, 1], // H-1, H-2
  2: [1, 2], // He-3, He-4
  3: [3, 4], // Li-6, Li-7
  4: [5], // Be-9
  5: [5, 6], // B-10, B-11
  6: [6, 7], // C-12, C-13
  7: [7, 8], // N-14, N-15
  8: [8, 9, 10], // O-16,17,18
  9: [10], // F-19
  10: [10, 11, 12], // Ne-20,21,22
  11: [12], // Na-23
  12: [12, 13], // Mg-24,25-ish
  13: [14], // Al-27
  14: [14, 15], // Si-28,29-ish
  15: [16], // P-31
  16: [16, 18], // S-32,34-ish
  17: [18, 20], // Cl-35,37-ish
  18: [22], // Ar-40
  19: [20], // K-39
  20: [20, 21, 22], // Ca-40,41,42-ish
  // Period 4 transition metals and neighbours (Sc → Kr).
  21: [24], // Sc-45
  22: [26], // Ti-48
  23: [28], // V-51
  24: [28], // Cr-52
  25: [30], // Mn-55
  26: [30], // Fe-56
  27: [32], // Co-59
  28: [30, 32], // Ni-58,60
  29: [34], // Cu-63
  30: [34], // Zn-64
  31: [38], // Ga-69
  32: [40, 42], // Ge-72,74-ish
  33: [42], // As-75
  34: [44, 46], // Se-78,80-ish
  35: [46, 48], // Br-81-ish
  36: [48, 50], // Kr-84,86-ish

  // Period 5 (approximate but grounded in real stable isotopes),
  // using one or two anchor N values around the main stable nuclides.
  37: [48, 50], // Rb-85,87 → N~48,50
  38: [50, 52], // Sr-88 etc.
  39: [50], // Y-89
  40: [50, 52], // Zr ~90–92
  41: [52, 54], // Nb ~93
  42: [54, 56], // Mo stable cluster near A~96–100
  43: [], // Tc has no truly stable isotopes → force fallback / unstable
  44: [56, 58], // Ru stable near A~101–104
  45: [58], // Rh-103
  46: [60], // Pd stable near A~106–110
  47: [60, 62], // Ag-107,109
  48: [64, 66], // Cd stable ~114–116
  49: [66, 68], // In-113,115-ish
  50: [68, 70, 72], // Sn many stable isotopes ~116–120
  51: [72], // Sb ~121–123
  52: [74, 76], // Te cluster ~128–130
  53: [74, 76], // I-127,129-ish
  54: [77, 78, 80], // Xe stable ~129–132

  // Period 6 (Cs → Hg) approximate stable anchors.
  55: [78], // Cs-133 → N=78
  56: [80, 82], // Ba stable ~134–138
  57: [82], // La-139 → N=82
  58: [82, 84], // Ce stable ~140–142
  59: [84], // Pr-141
  60: [86], // Nd-142,144-ish
  61: [], // Pm no stable
  62: [88], // Sm cluster ~147–154
  63: [88, 90], // Eu-151,153-ish
  64: [90, 92], // Gd stable ~154–160
  65: [92], // Tb-159-ish
  66: [94], // Dy stable ~160–164
  67: [94, 96], // Ho-165-ish
  68: [96, 98], // Er stable ~166–170
  69: [98], // Tm-169-ish
  70: [100, 102], // Yb stable ~168–176
  71: [104], // Lu-175,176-ish
  72: [106], // Hf stable ~176–180
  73: [108], // Ta-181-ish
  74: [110], // W-182–184-ish
  75: [112], // Re-185,187-ish
  76: [116], // Os stable ~188–192
  77: [118], // Ir stable ~191–193
  78: [118, 120], // Pt stable ~194–198
  79: [118, 120], // Au-197 → N=118, allow a neighbour
  80: [122, 124], // Hg stable ~198–204

  // Period 7 anchors for key "effectively stable" heavy nuclides.
  // Many are technically radioactive but insanely long-lived,
  // so we treat them as "stable enough" for the toy universe.
  81: [124], // Tl ~203,205-ish
  82: [126], // Pb-208 → N=126 (doubly magic)
  83: [126], // Bi-209 (very long-lived)
  84: [], // Po no stable
  85: [], // At
  86: [], // Rn
  87: [], // Fr
  88: [138], // Ra-226-ish (long-lived)
  89: [140], // Ac-227-ish
  90: [142], // Th-232 → N=142
  91: [144], // Pa-231-ish
  92: [146], // U-238 → N=146
  // 93+ (Np, Pu, …) are all pretty radioactive; leave them empty so they
  // fall back to the approximate curve or are treated as unstable, which
  // is physically honest at this level.
};



































/*
// lib/judge.dart
//
// Outer "judge" brain:
// - Knows the periodic table.
// - Knows approximate stable isotopes for each Z.
// - Compares inner engine's claims to reality and logs correctness.

import 'inner_physics.dart';
import 'periodic_table.dart';

class JudgeResult {
  final NucleusState nucleus;
  final bool innerThinksStable;
  final bool realityStable;
  final bool inPeriodicTable;
  final ElementDef? elementDef;
  final int? closestStableNeutrons;
  final bool isCorrect; // innerStable && realityStable && inTable

  const JudgeResult({
    required this.nucleus,
    required this.innerThinksStable,
    required this.realityStable,
    required this.inPeriodicTable,
    required this.elementDef,
    required this.closestStableNeutrons,
    required this.isCorrect,
  });
}

class Judge {
  // Map from Z to list of (stable) neutron counts N = A - Z.
  // These are approximate but good enough for the toy.
  final Map<int, List<int>> stableIsotopes;

  // Which atomic numbers we've actually "discovered" in reality-stable sense.
  final Set<int> discoveredZ = {};

  Judge({Map<int, List<int>>? stableIsotopesOverride})
    : stableIsotopes = stableIsotopesOverride ?? _defaultStableIsotopes;

  bool isInTable(int Z) => elementByZ.containsKey(Z);

  bool _isRealityStable(int Z, int N) {
    if (!isInTable(Z)) return false;
    final Ns = stableIsotopes[Z];
    if (Ns == null || Ns.isEmpty) return false;

    // Treat exact match or very near matches as "stable enough".
    int bestDiff = 1 << 30;
    for (final stableN in Ns) {
      final diff = (N - stableN).abs();
      if (diff < bestDiff) bestDiff = diff;
    }
    // If within 1 neutron of a known stable isotope, call it stable-ish.
    return bestDiff <= 1;
  }

  int? _closestStableN(int Z, int N) {
    final Ns = stableIsotopes[Z];
    if (Ns == null || Ns.isEmpty) return null;
    Ns.sort();
    int best = Ns.first;
    int bestDiff = (N - best).abs();
    for (final s in Ns.skip(1)) {
      final d = (N - s).abs();
      if (d < bestDiff) {
        bestDiff = d;
        best = s;
      }
    }
    return best;
  }

  JudgeResult evaluate(NucleusState nucleus, bool innerThinksStable) {
    final Z = nucleus.protons;
    final N = nucleus.neutrons;

    final inTable = isInTable(Z);
    final realityStable = _isRealityStable(Z, N);
    final def = inTable ? elementByZ[Z] : null;
    final closestN = inTable ? _closestStableN(Z, N) : null;

    final isCorrect = innerThinksStable && realityStable && inTable;

    if (realityStable && inTable) {
      discoveredZ.add(Z);
    }

    return JudgeResult(
      nucleus: nucleus,
      innerThinksStable: innerThinksStable,
      realityStable: realityStable,
      inPeriodicTable: inTable,
      elementDef: def,
      closestStableNeutrons: closestN,
      isCorrect: isCorrect,
    );
  }
}

// Rough stable isotope list (Z -> list of N = A - Z).
// This is not complete or perfect, but it captures the valley of stability shape.
final Map<int, List<int>> _defaultStableIsotopes = {
  1: [0, 1], // H-1, H-2
  2: [1, 2], // He-3, He-4
  3: [3, 4], // Li-6, Li-7
  4: [5], // Be-9
  5: [5, 6], // B-10, B-11
  6: [6, 7], // C-12, C-13
  7: [7, 8], // N-14, N-15
  8: [8, 9, 10], // O-16,17,18
  9: [10], // F-19
  10: [10, 11, 12], // Ne-20,21,22
  11: [12], // Na-23
  12: [12], // Mg-24
  13: [14], // Al-27
  14: [14], // Si-28
  15: [16], // P-31
  16: [16], // S-32
  17: [18], // Cl-35
  18: [22], // Ar-40
  19: [20], // K-39
  20: [20], // Ca-40
  21: [24], // Sc-45
  22: [26], // Ti-48
  23: [28], // V-51
  24: [28], // Cr-52
  25: [30], // Mn-55
  26: [30], // Fe-56
  27: [32], // Co-59
  28: [30, 32], // Ni-58,60
  29: [34], // Cu-63
  30: [34], // Zn-64
  31: [38], // Ga-69
  32: [40], // Ge-72
  33: [42], // As-75
  34: [44], // Se-78-ish
  35: [46], // Br-81-ish
  36: [48], // Kr-84-ish
};
*/