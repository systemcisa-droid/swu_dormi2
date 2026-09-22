import 'package:cloud_firestore/cloud_firestore.dart';

/// cloud_firestore 6.x의 QueryDocumentSnapshot.data()는 내부에서 `data()!`를 쓰기 때문에,
/// 필드가 하나도 없는 문서를 만나면 null을 돌려주는 대신 "Null check operator" 예외를 던진다.
/// 조건 없이 컬렉션 전체를 읽는 곳에서는 이 확장으로 그런 문서를 안전하게 건너뛴다.
extension SafeQueryDocumentData on QueryDocumentSnapshot<Map<String, dynamic>> {
  Map<String, dynamic>? dataOrNull() {
    try {
      return data();
    } catch (_) {
      return null;
    }
  }
}
