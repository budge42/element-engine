// lib/periodic_table.dart
//
// Full periodic table 1–118, squeezed into a 9x18 grid.
// Periods 1–7 = normal rows.
// Period 8 = lanthanides (57–71), shifted starting at group 3.
// Period 9 = actinides  (89–103), shifted starting at group 3.

class ElementDef {
  final int Z;
  final String symbol;
  final String name;
  final int period; // row index used by our grid (1..9)
  final int group; // column (1..18)

  const ElementDef({
    required this.Z,
    required this.symbol,
    required this.name,
    required this.period,
    required this.group,
  });
}

const List<ElementDef> allElements = [
  // ----- Period 1 -----
  ElementDef(Z: 1, symbol: 'H', name: 'Hydrogen', period: 1, group: 1),
  ElementDef(Z: 2, symbol: 'He', name: 'Helium', period: 1, group: 18),

  // ----- Period 2 -----
  ElementDef(Z: 3, symbol: 'Li', name: 'Lithium', period: 2, group: 1),
  ElementDef(Z: 4, symbol: 'Be', name: 'Beryllium', period: 2, group: 2),
  ElementDef(Z: 5, symbol: 'B', name: 'Boron', period: 2, group: 13),
  ElementDef(Z: 6, symbol: 'C', name: 'Carbon', period: 2, group: 14),
  ElementDef(Z: 7, symbol: 'N', name: 'Nitrogen', period: 2, group: 15),
  ElementDef(Z: 8, symbol: 'O', name: 'Oxygen', period: 2, group: 16),
  ElementDef(Z: 9, symbol: 'F', name: 'Fluorine', period: 2, group: 17),
  ElementDef(Z: 10, symbol: 'Ne', name: 'Neon', period: 2, group: 18),

  // ----- Period 3 -----
  ElementDef(Z: 11, symbol: 'Na', name: 'Sodium', period: 3, group: 1),
  ElementDef(Z: 12, symbol: 'Mg', name: 'Magnesium', period: 3, group: 2),
  ElementDef(Z: 13, symbol: 'Al', name: 'Aluminium', period: 3, group: 13),
  ElementDef(Z: 14, symbol: 'Si', name: 'Silicon', period: 3, group: 14),
  ElementDef(Z: 15, symbol: 'P', name: 'Phosphorus', period: 3, group: 15),
  ElementDef(Z: 16, symbol: 'S', name: 'Sulfur', period: 3, group: 16),
  ElementDef(Z: 17, symbol: 'Cl', name: 'Chlorine', period: 3, group: 17),
  ElementDef(Z: 18, symbol: 'Ar', name: 'Argon', period: 3, group: 18),

  // ----- Period 4 -----
  ElementDef(Z: 19, symbol: 'K', name: 'Potassium', period: 4, group: 1),
  ElementDef(Z: 20, symbol: 'Ca', name: 'Calcium', period: 4, group: 2),
  ElementDef(Z: 21, symbol: 'Sc', name: 'Scandium', period: 4, group: 3),
  ElementDef(Z: 22, symbol: 'Ti', name: 'Titanium', period: 4, group: 4),
  ElementDef(Z: 23, symbol: 'V', name: 'Vanadium', period: 4, group: 5),
  ElementDef(Z: 24, symbol: 'Cr', name: 'Chromium', period: 4, group: 6),
  ElementDef(Z: 25, symbol: 'Mn', name: 'Manganese', period: 4, group: 7),
  ElementDef(Z: 26, symbol: 'Fe', name: 'Iron', period: 4, group: 8),
  ElementDef(Z: 27, symbol: 'Co', name: 'Cobalt', period: 4, group: 9),
  ElementDef(Z: 28, symbol: 'Ni', name: 'Nickel', period: 4, group: 10),
  ElementDef(Z: 29, symbol: 'Cu', name: 'Copper', period: 4, group: 11),
  ElementDef(Z: 30, symbol: 'Zn', name: 'Zinc', period: 4, group: 12),
  ElementDef(Z: 31, symbol: 'Ga', name: 'Gallium', period: 4, group: 13),
  ElementDef(Z: 32, symbol: 'Ge', name: 'Germanium', period: 4, group: 14),
  ElementDef(Z: 33, symbol: 'As', name: 'Arsenic', period: 4, group: 15),
  ElementDef(Z: 34, symbol: 'Se', name: 'Selenium', period: 4, group: 16),
  ElementDef(Z: 35, symbol: 'Br', name: 'Bromine', period: 4, group: 17),
  ElementDef(Z: 36, symbol: 'Kr', name: 'Krypton', period: 4, group: 18),

  // ----- Period 5 -----
  ElementDef(Z: 37, symbol: 'Rb', name: 'Rubidium', period: 5, group: 1),
  ElementDef(Z: 38, symbol: 'Sr', name: 'Strontium', period: 5, group: 2),
  ElementDef(Z: 39, symbol: 'Y', name: 'Yttrium', period: 5, group: 3),
  ElementDef(Z: 40, symbol: 'Zr', name: 'Zirconium', period: 5, group: 4),
  ElementDef(Z: 41, symbol: 'Nb', name: 'Niobium', period: 5, group: 5),
  ElementDef(Z: 42, symbol: 'Mo', name: 'Molybdenum', period: 5, group: 6),
  ElementDef(Z: 43, symbol: 'Tc', name: 'Technetium', period: 5, group: 7),
  ElementDef(Z: 44, symbol: 'Ru', name: 'Ruthenium', period: 5, group: 8),
  ElementDef(Z: 45, symbol: 'Rh', name: 'Rhodium', period: 5, group: 9),
  ElementDef(Z: 46, symbol: 'Pd', name: 'Palladium', period: 5, group: 10),
  ElementDef(Z: 47, symbol: 'Ag', name: 'Silver', period: 5, group: 11),
  ElementDef(Z: 48, symbol: 'Cd', name: 'Cadmium', period: 5, group: 12),
  ElementDef(Z: 49, symbol: 'In', name: 'Indium', period: 5, group: 13),
  ElementDef(Z: 50, symbol: 'Sn', name: 'Tin', period: 5, group: 14),
  ElementDef(Z: 51, symbol: 'Sb', name: 'Antimony', period: 5, group: 15),
  ElementDef(Z: 52, symbol: 'Te', name: 'Tellurium', period: 5, group: 16),
  ElementDef(Z: 53, symbol: 'I', name: 'Iodine', period: 5, group: 17),
  ElementDef(Z: 54, symbol: 'Xe', name: 'Xenon', period: 5, group: 18),

  // ----- Period 6 main row (no lanthanides here) -----
  ElementDef(Z: 55, symbol: 'Cs', name: 'Caesium', period: 6, group: 1),
  ElementDef(Z: 56, symbol: 'Ba', name: 'Barium', period: 6, group: 2),

  // group 3 of period 6 is "occupied" by lanthanides row (period 8)
  ElementDef(Z: 72, symbol: 'Hf', name: 'Hafnium', period: 6, group: 4),
  ElementDef(Z: 73, symbol: 'Ta', name: 'Tantalum', period: 6, group: 5),
  ElementDef(Z: 74, symbol: 'W', name: 'Tungsten', period: 6, group: 6),
  ElementDef(Z: 75, symbol: 'Re', name: 'Rhenium', period: 6, group: 7),
  ElementDef(Z: 76, symbol: 'Os', name: 'Osmium', period: 6, group: 8),
  ElementDef(Z: 77, symbol: 'Ir', name: 'Iridium', period: 6, group: 9),
  ElementDef(Z: 78, symbol: 'Pt', name: 'Platinum', period: 6, group: 10),
  ElementDef(Z: 79, symbol: 'Au', name: 'Gold', period: 6, group: 11),
  ElementDef(Z: 80, symbol: 'Hg', name: 'Mercury', period: 6, group: 12),
  ElementDef(Z: 81, symbol: 'Tl', name: 'Thallium', period: 6, group: 13),
  ElementDef(Z: 82, symbol: 'Pb', name: 'Lead', period: 6, group: 14),
  ElementDef(Z: 83, symbol: 'Bi', name: 'Bismuth', period: 6, group: 15),
  ElementDef(Z: 84, symbol: 'Po', name: 'Polonium', period: 6, group: 16),
  ElementDef(Z: 85, symbol: 'At', name: 'Astatine', period: 6, group: 17),
  ElementDef(Z: 86, symbol: 'Rn', name: 'Radon', period: 6, group: 18),

  // ----- Period 7 main row (no actinides here) -----
  ElementDef(Z: 87, symbol: 'Fr', name: 'Francium', period: 7, group: 1),
  ElementDef(Z: 88, symbol: 'Ra', name: 'Radium', period: 7, group: 2),

  // group 3 of period 7 is "occupied" by actinides row (period 9)
  ElementDef(Z: 104, symbol: 'Rf', name: 'Rutherfordium', period: 7, group: 4),
  ElementDef(Z: 105, symbol: 'Db', name: 'Dubnium', period: 7, group: 5),
  ElementDef(Z: 106, symbol: 'Sg', name: 'Seaborgium', period: 7, group: 6),
  ElementDef(Z: 107, symbol: 'Bh', name: 'Bohrium', period: 7, group: 7),
  ElementDef(Z: 108, symbol: 'Hs', name: 'Hassium', period: 7, group: 8),
  ElementDef(Z: 109, symbol: 'Mt', name: 'Meitnerium', period: 7, group: 9),
  ElementDef(Z: 110, symbol: 'Ds', name: 'Darmstadtium', period: 7, group: 10),
  ElementDef(Z: 111, symbol: 'Rg', name: 'Roentgenium', period: 7, group: 11),
  ElementDef(Z: 112, symbol: 'Cn', name: 'Copernicium', period: 7, group: 12),
  ElementDef(Z: 113, symbol: 'Nh', name: 'Nihonium', period: 7, group: 13),
  ElementDef(Z: 114, symbol: 'Fl', name: 'Flerovium', period: 7, group: 14),
  ElementDef(Z: 115, symbol: 'Mc', name: 'Moscovium', period: 7, group: 15),
  ElementDef(Z: 116, symbol: 'Lv', name: 'Livermorium', period: 7, group: 16),
  ElementDef(Z: 117, symbol: 'Ts', name: 'Tennessine', period: 7, group: 17),
  ElementDef(Z: 118, symbol: 'Og', name: 'Oganesson', period: 7, group: 18),

  // ----- Period 8 (lanthanides, visually separate row) -----
  ElementDef(Z: 57, symbol: 'La', name: 'Lanthanum', period: 8, group: 3),
  ElementDef(Z: 58, symbol: 'Ce', name: 'Cerium', period: 8, group: 4),
  ElementDef(Z: 59, symbol: 'Pr', name: 'Praseodymium', period: 8, group: 5),
  ElementDef(Z: 60, symbol: 'Nd', name: 'Neodymium', period: 8, group: 6),
  ElementDef(Z: 61, symbol: 'Pm', name: 'Promethium', period: 8, group: 7),
  ElementDef(Z: 62, symbol: 'Sm', name: 'Samarium', period: 8, group: 8),
  ElementDef(Z: 63, symbol: 'Eu', name: 'Europium', period: 8, group: 9),
  ElementDef(Z: 64, symbol: 'Gd', name: 'Gadolinium', period: 8, group: 10),
  ElementDef(Z: 65, symbol: 'Tb', name: 'Terbium', period: 8, group: 11),
  ElementDef(Z: 66, symbol: 'Dy', name: 'Dysprosium', period: 8, group: 12),
  ElementDef(Z: 67, symbol: 'Ho', name: 'Holmium', period: 8, group: 13),
  ElementDef(Z: 68, symbol: 'Er', name: 'Erbium', period: 8, group: 14),
  ElementDef(Z: 69, symbol: 'Tm', name: 'Thulium', period: 8, group: 15),
  ElementDef(Z: 70, symbol: 'Yb', name: 'Ytterbium', period: 8, group: 16),
  ElementDef(Z: 71, symbol: 'Lu', name: 'Lutetium', period: 8, group: 17),

  // ----- Period 9 (actinides, visually separate row) -----
  ElementDef(Z: 89, symbol: 'Ac', name: 'Actinium', period: 9, group: 3),
  ElementDef(Z: 90, symbol: 'Th', name: 'Thorium', period: 9, group: 4),
  ElementDef(Z: 91, symbol: 'Pa', name: 'Protactinium', period: 9, group: 5),
  ElementDef(Z: 92, symbol: 'U', name: 'Uranium', period: 9, group: 6),
  ElementDef(Z: 93, symbol: 'Np', name: 'Neptunium', period: 9, group: 7),
  ElementDef(Z: 94, symbol: 'Pu', name: 'Plutonium', period: 9, group: 8),
  ElementDef(Z: 95, symbol: 'Am', name: 'Americium', period: 9, group: 9),
  ElementDef(Z: 96, symbol: 'Cm', name: 'Curium', period: 9, group: 10),
  ElementDef(Z: 97, symbol: 'Bk', name: 'Berkelium', period: 9, group: 11),
  ElementDef(Z: 98, symbol: 'Cf', name: 'Californium', period: 9, group: 12),
  ElementDef(Z: 99, symbol: 'Es', name: 'Einsteinium', period: 9, group: 13),
  ElementDef(Z: 100, symbol: 'Fm', name: 'Fermium', period: 9, group: 14),
  ElementDef(Z: 101, symbol: 'Md', name: 'Mendelevium', period: 9, group: 15),
  ElementDef(Z: 102, symbol: 'No', name: 'Nobelium', period: 9, group: 16),
  ElementDef(Z: 103, symbol: 'Lr', name: 'Lawrencium', period: 9, group: 17),
];

final Map<int, ElementDef> elementByZ = {for (final e in allElements) e.Z: e};
