import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/notice_model.dart';

class NoticesScreen extends StatelessWidget {
  const NoticesScreen({super.key});

  Stream<List<NoticeModel>> _noticesStream() {
    return FirebaseFirestore.instance
        .collection('notices')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(NoticeModel.fromFirestore).toList());
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<NoticeModel>>(
      stream: _noticesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('공지사항을 불러오는 중 오류가 발생했습니다.'));
        }
        final notices = snapshot.data ?? [];
        if (notices.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.campaign_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('등록된 공지사항이 없습니다.', style: TextStyle(color: Colors.grey, fontSize: 16)),
              ],
            ),
          );
        }

        final pinned = notices.where((n) => n.isPinned).toList();
        final normal = notices.where((n) => !n.isPinned).toList();
        final all = [...pinned, ...normal];

        return ListView.separated(
          itemCount: all.length,
          separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
          itemBuilder: (context, index) {
            final notice = all[index];
            return _NoticeListTile(notice: notice);
          },
        );
      },
    );
  }
}

class _NoticeListTile extends StatelessWidget {
  final NoticeModel notice;
  const _NoticeListTile({required this.notice});

  @override
  Widget build(BuildContext context) {
    final thumbnail = notice.imageUrls.isNotEmpty ? notice.imageUrls.first : null;

    return InkWell(
      onTap: () => _showDetail(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: thumbnail != null
                  ? Image.network(
                      thumbnail,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(),
                    )
                  : _placeholder(),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (notice.isPinned)
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFB44F4F),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '중요',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  Text(
                    notice.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, height: 1.3),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notice.content,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${notice.authorName}  |  ${DateFormat('yyyy.MM.dd').format(notice.createdAt)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 72,
      height: 72,
      color: notice.isPinned ? const Color(0xFFFFEBEB) : const Color(0xFFE3F2FD),
      child: Icon(
        notice.isPinned ? Icons.priority_high : Icons.campaign_outlined,
        size: 32,
        color: notice.isPinned ? const Color(0xFFB44F4F) : Colors.blue.shade300,
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              if (notice.isPinned)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB44F4F),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('중요', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              Text(
                notice.title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, height: 1.3),
              ),
              const SizedBox(height: 8),
              Text(
                '${notice.authorName}  |  ${DateFormat('yyyy-MM-dd HH:mm').format(notice.createdAt)}',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const Divider(height: 28),
              if (notice.imageUrls.isNotEmpty) ...[
                ...notice.imageUrls.map((url) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: GestureDetector(
                      onTap: () => _showImageFullscreen(context, url),
                      child: Image.network(
                        url,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (_, __, ___) => Container(
                          height: 120,
                          color: Colors.grey.shade200,
                          child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                        ),
                      ),
                    ),
                  ),
                )),
                const SizedBox(height: 8),
              ],
              Text(
                notice.content,
                style: const TextStyle(fontSize: 15, height: 1.7),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _showImageFullscreen(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.network(url, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
