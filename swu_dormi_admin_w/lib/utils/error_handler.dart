import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// 에러 처리 유틸리티 클래스
class ErrorHandler {
  /// Firebase Authentication 에러 메시지 변환
  static String getAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return '잘못된 이메일 형식입니다.';
      case 'user-disabled':
        return '비활성화된 계정입니다.';
      case 'user-not-found':
        return '존재하지 않는 계정입니다.';
      case 'wrong-password':
        return '잘못된 비밀번호입니다.';
      case 'email-already-in-use':
        return '이미 사용 중인 이메일입니다.';
      case 'operation-not-allowed':
        return '허용되지 않은 작업입니다.';
      case 'weak-password':
        return '비밀번호가 너무 약합니다.';
      case 'too-many-requests':
        return '너무 많은 요청이 발생했습니다. 잠시 후 다시 시도해주세요.';
      case 'network-request-failed':
        return '네트워크 연결을 확인해주세요.';
      case 'requires-recent-login':
        return '재로그인이 필요합니다.';
      default:
        return '인증 중 오류가 발생했습니다: ${e.message ?? e.code}';
    }
  }

  /// Firestore 에러 메시지 변환
  static String getFirestoreErrorMessage(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return '접근 권한이 없습니다.';
      case 'not-found':
        return '요청한 데이터를 찾을 수 없습니다.';
      case 'already-exists':
        return '이미 존재하는 데이터입니다.';
      case 'resource-exhausted':
        return '할당량이 초과되었습니다.';
      case 'failed-precondition':
        return '작업을 수행할 수 없는 상태입니다.';
      case 'aborted':
        return '작업이 중단되었습니다.';
      case 'out-of-range':
        return '유효하지 않은 범위입니다.';
      case 'unimplemented':
        return '지원되지 않는 작업입니다.';
      case 'internal':
        return '내부 서버 오류가 발생했습니다.';
      case 'unavailable':
        return '서비스를 일시적으로 사용할 수 없습니다.';
      case 'data-loss':
        return '데이터 손실이 발생했습니다.';
      case 'unauthenticated':
        return '인증이 필요합니다.';
      case 'deadline-exceeded':
        return '요청 시간이 초과되었습니다.';
      default:
        return 'Firestore 오류가 발생했습니다: ${e.message ?? e.code}';
    }
  }

  /// Storage 에러 메시지 변환
  static String getStorageErrorMessage(FirebaseException e) {
    switch (e.code) {
      case 'object-not-found':
        return '파일을 찾을 수 없습니다.';
      case 'bucket-not-found':
        return '저장소를 찾을 수 없습니다.';
      case 'project-not-found':
        return '프로젝트를 찾을 수 없습니다.';
      case 'quota-exceeded':
        return '저장소 할당량이 초과되었습니다.';
      case 'unauthenticated':
        return '인증이 필요합니다.';
      case 'unauthorized':
        return '파일 접근 권한이 없습니다.';
      case 'retry-limit-exceeded':
        return '재시도 횟수가 초과되었습니다.';
      case 'invalid-checksum':
        return '파일이 손상되었습니다.';
      case 'canceled':
        return '업로드가 취소되었습니다.';
      case 'invalid-event-name':
        return '잘못된 이벤트 이름입니다.';
      case 'invalid-url':
        return '잘못된 URL입니다.';
      case 'invalid-argument':
        return '잘못된 인자입니다.';
      case 'no-default-bucket':
        return '기본 저장소가 설정되지 않았습니다.';
      case 'cannot-slice-blob':
        return '파일을 처리할 수 없습니다.';
      case 'server-file-wrong-size':
        return '서버의 파일 크기가 일치하지 않습니다.';
      default:
        return 'Storage 오류가 발생했습니다: ${e.message ?? e.code}';
    }
  }

  /// 일반 에러 메시지 변환
  static String getErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      return getAuthErrorMessage(error);
    } else if (error is FirebaseException) {
      // Storage와 Firestore 모두 FirebaseException을 사용
      if (error.plugin == 'firebase_storage') {
        return getStorageErrorMessage(error);
      } else {
        return getFirestoreErrorMessage(error);
      }
    } else if (error is Exception) {
      return error.toString().replaceFirst('Exception: ', '');
    } else {
      return '알 수 없는 오류가 발생했습니다.';
    }
  }

  /// 에러 로깅
  static void logError(dynamic error, StackTrace? stackTrace, {String? context}) {
    if (kDebugMode) {
      print('=== ERROR ${context != null ? '[$context]' : ''} ===');
      print('Error: $error');
      if (stackTrace != null) {
        print('StackTrace: $stackTrace');
      }
      print('================');
    }
  }

  /// 에러 발생 시 사용자에게 보여줄 메시지와 로깅을 동시에 처리
  static String handleError(dynamic error, StackTrace? stackTrace, {String? context}) {
    logError(error, stackTrace, context: context);
    return getErrorMessage(error);
  }

  /// 네트워크 에러 확인
  static bool isNetworkError(dynamic error) {
    if (error is FirebaseException) {
      return error.code == 'unavailable' ||
             error.code == 'network-request-failed' ||
             error.code == 'deadline-exceeded';
    }
    return false;
  }

  /// 권한 에러 확인
  static bool isPermissionError(dynamic error) {
    if (error is FirebaseException) {
      return error.code == 'permission-denied' ||
             error.code == 'unauthorized' ||
             error.code == 'unauthenticated';
    }
    return false;
  }

  /// 에러 재시도 가능 여부 확인
  static bool isRetryable(dynamic error) {
    if (error is FirebaseException) {
      return error.code == 'unavailable' ||
             error.code == 'deadline-exceeded' ||
             error.code == 'aborted' ||
             error.code == 'internal';
    }
    return false;
  }
}
