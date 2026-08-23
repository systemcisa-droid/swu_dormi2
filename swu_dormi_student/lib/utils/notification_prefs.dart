import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 알림 종류별 수신 설정을 관리한다.
///
/// 설정은 Firestore(`users/{uid}.notificationSettings`)에 저장해
/// 알림을 만드는 쪽(관리 프로그램)이 꺼둔 학생을 건너뛸 수 있게 한다.
/// 화면이 즉시 반응하도록 로컬(SharedPreferences)에도 같은 값을 캐시한다.
class NotificationPrefs {
  static final _firestore = FirebaseFirestore.instance;

  /// 알림 type → 설정 키 (Firestore 필드명 겸 로컬 키)
  static const Map<String, String> keyByType = {
    'notice': 'notice_notifications',
    'facility_report': 'facility_notifications',
    'meal': 'meal_notifications',
    'check_in_out': 'check_in_out_notifications',
    'message': 'admin_message_notifications',
    'board_comment': 'board_comment_notifications',
  };

  /// 기본 꺼짐인 설정(그 외는 기본 켜짐)
  static const Set<String> defaultOffKeys = {'meal_notifications'};

  static bool defaultOf(String key) => !defaultOffKeys.contains(key);

  /// 설정 저장: Firestore에 기록하고 로컬 캐시도 갱신한다.
  static Future<void> save(String userId, Map<String, bool> settings) async {
    final prefs = await SharedPreferences.getInstance();
    for (final e in settings.entries) {
      await prefs.setBool(e.key, e.value);
    }
    try {
      await _firestore.collection('users').doc(userId).set(
        {'notificationSettings': settings},
        SetOptions(merge: true),
      );
    } catch (_) {
      // 오프라인 등으로 실패해도 로컬 설정은 유지된다.
    }
  }

  /// 설정 불러오기: Firestore 값을 우선하고, 없으면 로컬 캐시를 쓴다.
  static Future<Map<String, bool>> load(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic>? remote;
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      remote = doc.data()?['notificationSettings'] as Map<String, dynamic>?;
    } catch (_) {}

    final result = <String, bool>{};
    final allKey = 'all_notifications';
    result[allKey] = (remote?[allKey] as bool?) ?? prefs.getBool(allKey) ?? true;
    for (final key in keyByType.values) {
      result[key] =
          (remote?[key] as bool?) ?? prefs.getBool(key) ?? defaultOf(key);
    }

    // 원격 값을 로컬에도 반영해 다음 조회를 빠르게 한다.
    for (final e in result.entries) {
      await prefs.setBool(e.key, e.value);
    }
    return result;
  }

  /// Firestore에 설정이 아직 없으면 기본값으로 한 번 기록한다.
  /// (알림을 만드는 쪽이 '설정 없음'과 '꺼둠'을 구분할 수 없어 생기는 공백을 없앤다)
  static Future<void> ensureInitialized(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.data()?['notificationSettings'] != null) return;

      final defaults = <String, bool>{'all_notifications': true};
      for (final key in keyByType.values) {
        defaults[key] = defaultOf(key);
      }
      await save(userId, defaults);
    } catch (_) {
      // 실패해도 다음 실행에서 다시 시도한다.
    }
  }

  /// 현재 꺼져 있는 알림 type 집합 (로컬 캐시 기준 — 화면 표시에 사용)
  static Future<Set<String>> disabledTypes() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('all_notifications') ?? true)) {
      return keyByType.keys.toSet();
    }
    final disabled = <String>{};
    keyByType.forEach((type, key) {
      if (!(prefs.getBool(key) ?? defaultOf(key))) disabled.add(type);
    });
    return disabled;
  }

  /// 해당 종류의 알림을 받을지 여부. 매핑에 없는 종류는 항상 수신한다.
  static Future<bool> isEnabled(String? type) async {
    if (type == null || !keyByType.containsKey(type)) return true;
    final disabled = await disabledTypes();
    return !disabled.contains(type);
  }
}
