import 'package:flutter_test/flutter_test.dart';
import 'package:doctor_computer/data/models/pc_part_model.dart';

PcPartModel _part({
  required String name,
  required PcPartCategory category,
  Map<String, String> specs = const {},
  List<String> tags = const [],
}) {
  return PcPartModel(
    id: name,
    name: name,
    category: category,
    brand: 'Test',
    price: 100,
    specs: specs,
    compatibilityTags: tags,
  );
}

void main() {
  test('detects CPU and motherboard socket mismatch from specifications', () {
    final cpu = _part(
      name: 'Intel CPU',
      category: PcPartCategory.cpu,
      specs: const {'Socket': 'LGA 1700'},
    );
    final motherboard = _part(
      name: 'AMD motherboard',
      category: PcPartCategory.motherboard,
      specs: const {'CPU Socket': 'AM5', 'Memory Type': 'DDR5'},
    );

    expect(
      PcPartCompatibility.issues(cpu: cpu, motherboard: motherboard),
      contains('Socket CPU (LGA 1700) tidak cocok dengan motherboard (AM5).'),
    );
  });

  test('detects RAM mismatch using legacy tags', () {
    final motherboard = _part(
      name: 'Motherboard',
      category: PcPartCategory.motherboard,
      tags: const ['intel_lga1700', 'ddr4'],
    );
    final ram = _part(
      name: 'DDR5 memory',
      category: PcPartCategory.ram,
      tags: const ['ddr5'],
    );

    expect(
      PcPartCompatibility.issues(motherboard: motherboard, ram: ram),
      contains('RAM DDR5 tidak cocok dengan motherboard (DDR4).'),
    );
  });

  test('does not warn when socket and RAM types are compatible', () {
    final cpu = _part(
      name: 'Ryzen CPU',
      category: PcPartCategory.cpu,
      specs: const {'Socket': 'AM5'},
    );
    final motherboard = _part(
      name: 'AM5 motherboard',
      category: PcPartCategory.motherboard,
      specs: const {'Socket': 'AM5', 'Memory Type': 'DDR5'},
    );
    final ram = _part(
      name: 'DDR5 memory',
      category: PcPartCategory.ram,
      specs: const {'Type': 'DDR5'},
    );

    expect(
      PcPartCompatibility.issues(cpu: cpu, motherboard: motherboard, ram: ram),
      isEmpty,
    );
    expect(
      PcPartCompatibility.warnings(
        cpu: cpu,
        motherboard: motherboard,
        ram: ram,
      ),
      isEmpty,
    );
  });

  test('warns when compatibility specifications are missing', () {
    final cpu = _part(name: 'CPU', category: PcPartCategory.cpu);
    final motherboard = _part(
      name: 'Motherboard',
      category: PcPartCategory.motherboard,
    );

    expect(
      PcPartCompatibility.warnings(cpu: cpu, motherboard: motherboard),
      contains(
        'Socket CPU atau motherboard belum tercatat; kompatibilitas socket '
        'belum dapat dipastikan.',
      ),
    );
  });

  test('derives compatibility tags from product specifications', () {
    expect(
      PcPartCompatibility.tagsFor(
        specs: const {'Socket': 'LGA-1700', 'Memory Type': 'DDR 5'},
        existingTags: const [],
      ),
      containsAll(['socket_lga 1700', 'ddr5']),
    );
  });
}
