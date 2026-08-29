import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_compress/video_compress.dart';

/// 단톡방 첨부 파일 선택 + 압축 + 업로드.
///
/// 사진은 image_picker 단계에서 1280x720 / 품질 70으로 줄이고,
/// 영상은 VideoCompress 로 LowQuality 재인코딩한 뒤 업로드한다.
class ChatUpload {
  ChatUpload._();

  /// 영상 최대 길이 - 지나치게 큰 파일이 올라가지 않도록 제한한다.
  static const Duration maxVideoDuration = Duration(minutes: 1);

  /// 업로드 허용 최대 크기 (압축 후 기준)
  static const int maxUploadBytes = 20 * 1024 * 1024;

  static final ImagePicker _picker = ImagePicker();

  /// 사진 선택 (선택 단계에서 이미 축소·압축된다)
  static Future<File?> pickImage(ImageSource source) async {
    final file = await _picker.pickImage(
      source: source,
      maxWidth: 1280,
      maxHeight: 720,
      imageQuality: 70,
    );
    return file == null ? null : File(file.path);
  }

  /// 영상 선택
  static Future<File?> pickVideo(ImageSource source) async {
    final file = await _picker.pickVideo(
      source: source,
      maxDuration: maxVideoDuration,
    );
    return file == null ? null : File(file.path);
  }

  /// 영상 압축. 실패하면 원본을 그대로 쓴다.
  static Future<File> compressVideo(File original) async {
    try {
      final info = await VideoCompress.compressVideo(
        original.path,
        quality: VideoQuality.LowQuality,
        deleteOrigin: false,
        includeAudio: true,
      );
      final compressed = info?.file;
      if (compressed == null) return original;
      // 압축 결과가 오히려 크면 원본을 쓴다.
      if (await compressed.length() >= await original.length()) return original;
      return compressed;
    } catch (e) {
      debugPrint('영상 압축 실패: $e');
      return original;
    }
  }

  /// Storage 업로드 후 다운로드 URL 반환.
  static Future<String> upload({
    required File file,
    required String roomId,
    required bool isVideo,
  }) async {
    final ext = isVideo ? 'mp4' : 'jpg';
    final name = '${DateTime.now().millisecondsSinceEpoch}.$ext';
    final ref = FirebaseStorage.instance
        .ref()
        .child('floor_chats')
        .child(roomId)
        .child(name);

    final task = await ref.putFile(
      file,
      SettableMetadata(contentType: isVideo ? 'video/mp4' : 'image/jpeg'),
    );
    return task.ref.getDownloadURL();
  }

  static void cancelCompression() {
    VideoCompress.cancelCompression();
  }
}
