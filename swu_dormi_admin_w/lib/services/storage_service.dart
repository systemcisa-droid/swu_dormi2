import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image/image.dart' as img;

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 공지사항 PDF 업로드
  Future<String> uploadNoticePdf(File file, String fileName) async {
    try {
      print('===== PDF 업로드 시작 =====');
      print('현재 사용자: ${_auth.currentUser?.uid}');
      print('현재 사용자 이메일: ${_auth.currentUser?.email}');
      print('업로드 경로: notices/pdfs/$fileName');
      print('파일 존재 여부: ${await file.exists()}');

      final ref = _storage.ref().child('notices/pdfs/$fileName');
      print('Reference 생성 완료');

      await ref.putFile(file, SettableMetadata(contentType: 'application/pdf'));
      print('파일 업로드 완료');

      final downloadUrl = await ref.getDownloadURL();
      print('다운로드 URL 획득: $downloadUrl');
      print('===== PDF 업로드 완료 =====');

      return downloadUrl;
    } catch (e) {
      print('===== PDF 업로드 오류 =====');
      print('오류 상세: $e');
      throw Exception('PDF 업로드 중 오류가 발생했습니다: $e');
    }
  }

  // 공지사항 이미지 업로드
  Future<String> uploadNoticeImage(File file, String fileName) async {
    try {
      print('===== 이미지 업로드 시작 =====');
      print('현재 사용자: ${_auth.currentUser?.uid}');
      print('현재 사용자 이메일: ${_auth.currentUser?.email}');
      print('업로드 경로: notices/images/$fileName');
      print('파일 존재 여부: ${await file.exists()}');

      final ref = _storage.ref().child('notices/images/$fileName');
      print('Reference 생성 완료');

      await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
      print('파일 업로드 완료');

      final downloadUrl = await ref.getDownloadURL();
      print('다운로드 URL 획득: $downloadUrl');
      print('===== 이미지 업로드 완료 =====');

      return downloadUrl;
    } catch (e) {
      print('===== 이미지 업로드 오류 =====');
      print('오류 상세: $e');
      throw Exception('이미지 업로드 중 오류가 발생했습니다: $e');
    }
  }

  // 시설 신고 이미지 업로드
  Future<String> uploadFacilityImage(File file, String fileName) async {
    try {
      final ref = _storage.ref().child('facilities/images/$fileName');
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      throw Exception('이미지 업로드 중 오류가 발생했습니다: $e');
    }
  }

  // 이미지 압축 (최대 1920px, JPEG 75%)
  Future<Uint8List> _compressImage(File file) async {
    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;
    final resized = decoded.width > 1920
        ? img.copyResize(decoded, width: 1920)
        : decoded;
    return Uint8List.fromList(img.encodeJpg(resized, quality: 75));
  }

  // 식단표 이미지 업로드 (압축 적용)
  Future<String> uploadMealImage(File file, String fileName) async {
    try {
      final compressed = await _compressImage(file);
      final ref = _storage.ref().child('meals/images/$fileName');
      await ref.putData(compressed, SettableMetadata(contentType: 'image/jpeg'));
      return await ref.getDownloadURL();
    } catch (e) {
      throw Exception('식단표 이미지 업로드 중 오류가 발생했습니다: $e');
    }
  }

  // 프로필 이미지 업로드
  Future<String> uploadProfileImage(File file, String userId) async {
    try {
      final ref = _storage.ref().child('profiles/$userId.jpg');
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      throw Exception('프로필 이미지 업로드 중 오류가 발생했습니다: $e');
    }
  }

  // 홈 배너 이미지 업로드
  Future<String> uploadHomeBanner(File file) async {
    try {
      final ref = _storage.ref().child('settings/home_banner.jpg');
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      throw Exception('배너 이미지 업로드 중 오류가 발생했습니다: $e');
    }
  }

  // 사생 기본 정보 엑셀 업로드
  Future<String> uploadStudentInfoExcel(File file) async {
    try {
      final ref = _storage.ref().child('settings/student_info.xlsx');
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      throw Exception('사생 기본 정보 엑셀 업로드 중 오류가 발생했습니다: $e');
    }
  }

  // 파일 삭제
  Future<void> deleteFile(String fileUrl) async {
    try {
      final ref = _storage.refFromURL(fileUrl);
      await ref.delete();
    } catch (e) {
      throw Exception('파일 삭제 중 오류가 발생했습니다: $e');
    }
  }
}
