import 'package:flutter/material.dart';

const List<Map<String, dynamic>> kBoardCategories = [
  {'value': 'lost&found', 'label': 'Lost&Found', 'color': Colors.green},
  {'value': '배달팟',   'label': '배달팟',   'color': Colors.red},
  {'value': '물품 나눔',   'label': '물품 나눔(당근)',   'color': Colors.orange},
  {'value': '정보 알림',   'label': '정보 알림',   'color': Colors.blue},
  {'value': '세탁실톡',    'label': '세탁실톡',    'color': Colors.purple},
];

Color boardCategoryColor(String category) {
  switch (category) {
    case 'lost&found': return Colors.green;
    case '배달팟':   return Colors.red;
    case '물품 나눔(당근)':   return Colors.orange;
    case '정보 알림':   return Colors.blue;
    case '세탁실톡':    return Colors.purple;
    default:            return Colors.grey;
  }
}

// Firestore에 저장된 category(value)로 한국어 표시 라벨(label)을 조회
String boardCategoryKoLabel(String categoryValue) {
  for (final cat in kBoardCategories) {
    if (cat['value'] == categoryValue) return cat['label'] as String;
  }
  return categoryValue;
}
