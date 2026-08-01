import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Upload profile image
  Future<String?> uploadProfileImage(String userId, File imageFile) async {
    try {
      // Create a reference to the storage location
      final ref = _storage.ref().child('profile_images/$userId.jpg');

      // Upload the file
      final uploadTask = await ref.putFile(imageFile);

      // Get the download URL
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  // Delete profile image
  Future<void> deleteProfileImage(String userId) async {
    try {
      final ref = _storage.ref().child('profile_images/$userId.jpg');
      await ref.delete();
    } catch (e) {
      // Ignore if file doesn't exist
      if (!e.toString().contains('object-not-found')) {
        throw Exception('Failed to delete image: $e');
      }
    }
  }

  // Upload repair report image
  Future<String?> uploadRepairImage(String reportId, File imageFile) async {
    try {
      final ref = _storage.ref().child('repair_images/$reportId.jpg');
      final uploadTask = await ref.putFile(imageFile);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload repair image: $e');
    }
  }

  // Upload repair report media (image or video) with index
  Future<String?> uploadRepairMedia(String reportId, File file, int index) async {
    try {
      final ext = file.path.split('.').last.toLowerCase();
      final ref = _storage.ref().child('repair_media/${reportId}_$index.$ext');
      final uploadTask = await ref.putFile(file);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload repair media: $e');
    }
  }

  // Upload notice image
  Future<String?> uploadNoticeImage(String noticeId, File imageFile) async {
    try {
      final ref = _storage.ref().child('notice_images/$noticeId.jpg');
      final uploadTask = await ref.putFile(imageFile);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload notice image: $e');
    }
  }

  // Upload notice PDF
  Future<String?> uploadNoticePdf(String noticeId, File pdfFile, String fileName) async {
    try {
      final ref = _storage.ref().child('notice_pdfs/$noticeId/$fileName');
      final uploadTask = await ref.putFile(pdfFile);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload notice PDF: $e');
    }
  }

  // Generic image upload with custom path
  Future<String?> uploadImage(File imageFile, String storagePath) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${timestamp}_${imageFile.path.split('/').last}';
      final ref = _storage.ref().child('$storagePath/$fileName');
      final uploadTask = await ref.putFile(imageFile);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }
}
