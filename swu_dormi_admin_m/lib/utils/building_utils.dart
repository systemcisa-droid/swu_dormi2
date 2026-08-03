import 'package:flutter/material.dart';

Color buildingColor(String floorOrBuilding) {
  if (floorOrBuilding.startsWith('샬롬하우스')) return const Color(0xFF2196F3);
  if (floorOrBuilding.startsWith('국제생활관')) return const Color(0xFF4CAF50);
  if (floorOrBuilding.startsWith('바롬인성교육관')) return const Color(0xFFFF9800);
  return const Color(0xFF9E9E9E);
}

const Map<int, int> kShalomRoomCapacities = {
  1: 2, 2: 4, 3: 2, 4: 2, 5: 4, 6: 2, 7: 1, 8: 2, 9: 1, 10: 2,
  11: 1, 12: 1, 13: 4, 14: 4, 15: 4, 16: 4, 17: 4, 18: 4, 19: 4, 20: 4,
  21: 2, 22: 4, 23: 2, 24: 2, 25: 4, 26: 2, 27: 2, 28: 2, 29: 1, 30: 4,
  31: 4, 32: 4, 33: 4, 34: 4, 35: 4,
};

int shalomRoomCapacity(String roomNumber) {
  final n = int.tryParse(roomNumber);
  if (n == null) return 4;
  return kShalomRoomCapacities[n % 100] ?? 4;
}
