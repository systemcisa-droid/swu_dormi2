import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../models/regulation_agreement_model.dart';
import '../../utils/move_out_inspection_strings.dart';

class MoveOutInspectionScreen extends StatefulWidget {
  const MoveOutInspectionScreen({super.key});

  @override
  State<MoveOutInspectionScreen> createState() => _MoveOutInspectionScreenState();
}

class _MoveOutInspectionScreenState extends State<MoveOutInspectionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = MoveOutInspectionStrings(Provider.of<LocaleProvider>(context).isEnglish);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.title),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: const Icon(Icons.article), text: s.tabGuide),
            Tab(icon: const Icon(Icons.edit), text: s.tabSignature),
            Tab(icon: const Icon(Icons.description), text: s.tabDocument),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const _MoveOutGuideContent(),
          _MoveOutSignatureTab(
            onNext: () => _tabController.animateTo(2),
          ),
          const _MoveOutAgreementDocumentTab(),
        ],
      ),
    );
  }
}

// ── 퇴사 안내 탭 ──
class _MoveOutGuideContent extends StatelessWidget {
  const _MoveOutGuideContent();

  @override
  Widget build(BuildContext context) {
    final s = MoveOutInspectionStrings(Provider.of<LocaleProvider>(context).isEnglish);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSection(
          context,
          icon: Icons.meeting_room,
          title: s.whatIsTitle,
          color: Theme.of(context).primaryColor,
          items: s.whatIsItems,
        ),
        const SizedBox(height: 16),
        _buildSection(
          context,
          icon: Icons.checklist,
          title: s.itemsTitle,
          color: Colors.blue,
          items: s.inspectionItems,
        ),
        const SizedBox(height: 16),
        _buildSection(
          context,
          icon: Icons.warning_amber,
          title: s.noticeTitle,
          color: Colors.orange,
          items: s.noticeItems,
        ),
        const SizedBox(height: 16),
        _buildSection(
          context,
          icon: Icons.assignment_turned_in,
          title: s.procedureTitle,
          color: Colors.green,
          items: s.procedureItems,
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color color,
    required List<String> items,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 26),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(item, style: const TextStyle(fontSize: 14, height: 1.6)),
                )),
          ],
        ),
      ),
    );
  }
}

// ── 동의 및 서명 탭 ──
class _MoveOutSignatureTab extends StatefulWidget {
  final VoidCallback onNext;

  const _MoveOutSignatureTab({required this.onNext});

  @override
  State<_MoveOutSignatureTab> createState() => _MoveOutSignatureTabState();
}

class _MoveOutSignatureTabState extends State<_MoveOutSignatureTab> {
  final _nameController = TextEditingController();
  final _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  Future<void> _submitSignature() async {
    final s = MoveOutInspectionStrings(
        Provider.of<LocaleProvider>(context, listen: false).isEnglish);
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.nameRequired), backgroundColor: Colors.orange),
      );
      return;
    }
    if (_signatureController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.signatureRequired), backgroundColor: Colors.orange),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.userNotFound), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final signatureBytes = await _signatureController.toPngBytes();
      if (signatureBytes == null) throw Exception(s.signatureGenerationFailed);

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('move_out_agreements')
          .child('${user.uid}_${DateTime.now().millisecondsSinceEpoch}.png');

      final uploadTask = await storageRef.putData(
        signatureBytes,
        SettableMetadata(contentType: 'image/png'),
      );
      final signatureUrl = await uploadTask.ref.getDownloadURL();

      final agreement = RegulationAgreementModel(
        id: user.uid,
        userId: user.uid,
        userName: _nameController.text.trim(),
        roomNumber: user.roomNumber,
        dormBuilding: user.dormBuilding,
        signatureUrl: signatureUrl,
        agreedAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('move_out_agreements')
          .doc(user.uid)
          .set(agreement.toMap());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.agreementSubmitted), backgroundColor: Colors.green),
        );
        _nameController.clear();
        _signatureController.clear();
        widget.onNext();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.genericError(e)), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;
    final s = MoveOutInspectionStrings(Provider.of<LocaleProvider>(context).isEnglish);
    final now = DateTime.now();
    final dateFormat = DateFormat(s.isEnglish ? 'MMM d, yyyy HH:mm' : 'yyyy년 MM월 dd일 HH:mm', s.isEnglish ? null : 'ko');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 3,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Column(
                      children: [
                        Text(
                          s.formTitle,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          s.formSubtitle,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Text(
                      s.isEnglish ? s.pledgeBodyEn : s.pledgeBodyKo,
                      style: const TextStyle(fontSize: 14, height: 1.8, letterSpacing: 0.3),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Divider(thickness: 2),
                  const SizedBox(height: 24),
                  Text(
                    s.signHint,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const SizedBox(width: 40),
                      Text(s.writtenAtLabel, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 12),
                      Text(dateFormat.format(now), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (user != null) ...[
                    if (user.dormBuilding != null && user.dormBuilding!.isNotEmpty)
                      Row(
                        children: [
                          const SizedBox(width: 40),
                          Text(s.buildingLabel, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 12),
                          Text(user.dormBuilding!, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    if (user.dormBuilding != null && user.dormBuilding!.isNotEmpty)
                      const SizedBox(height: 20),
                    Row(
                      children: [
                        const SizedBox(width: 40),
                        Text(s.roomLabel, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 12),
                        Text(user.roomNumber, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                  Row(
                    children: [
                      const SizedBox(width: 40),
                      Text(s.nameLabel, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            hintText: s.nameHint,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: const OutlineInputBorder(),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey[400]!),
                            ),
                          ),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ),
                      const Expanded(flex: 1, child: SizedBox()),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(width: 40),
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(s.signatureLabel, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 150,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[400]!, width: 1.5),
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.grey[50],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(7),
                                child: Signature(
                                  controller: _signatureController,
                                  backgroundColor: Colors.grey[50]!,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () => _signatureController.clear(),
                                icon: const Icon(Icons.refresh, size: 18),
                                label: Text(s.redo),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(s.agreeStatement,
                          style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.black54)),
                      const SizedBox(width: 40),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(s.dormLabel, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                      const SizedBox(width: 40),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isLoading ? null : _submitSignature,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20, width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(s.submitAgreement, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.privacyNotice,
                    style: TextStyle(fontSize: 13, color: Colors.blue.shade900),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 서약서 내용 탭 ──
class _MoveOutAgreementDocumentTab extends StatefulWidget {
  const _MoveOutAgreementDocumentTab();

  @override
  State<_MoveOutAgreementDocumentTab> createState() => _MoveOutAgreementDocumentTabState();
}

class _MoveOutAgreementDocumentTabState extends State<_MoveOutAgreementDocumentTab> {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;
    final s = MoveOutInspectionStrings(Provider.of<LocaleProvider>(context).isEnglish);

    if (user == null) {
      return Center(child: Text(s.userDataUnavailable));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('move_out_agreements')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return _buildNoAgreementView(s);
        }
        final agreement = RegulationAgreementModel.fromFirestore(snapshot.data!);
        return _buildAgreementView(agreement, s);
      },
    );
  }

  Widget _buildNoAgreementView(MoveOutInspectionStrings s) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 100),
          Icon(Icons.assignment_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 24),
          Text(s.noAgreementYet,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[700])),
          const SizedBox(height: 12),
          Text(s.noAgreementHint,
              style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildAgreementView(RegulationAgreementModel agreement, MoveOutInspectionStrings s) {
    final dateFormat = DateFormat(s.isEnglish ? 'MMM d, yyyy' : 'yyyy년 MM월 dd일', s.isEnglish ? null : 'ko');
    final timeFormat = DateFormat('HH:mm');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            elevation: 4,
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!, width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.assignment_turned_in, size: 48, color: Theme.of(context).primaryColor),
                        const SizedBox(height: 16),
                        Text(
                          s.formTitle,
                          style: TextStyle(
                            fontSize: 26, fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor, letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(s.formSubtitle,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!, width: 1.5),
                    ),
                    child: Text(
                      s.isEnglish ? s.documentPledgeEn : s.documentPledgeKo,
                      style: const TextStyle(fontSize: 15, height: 1.9, letterSpacing: 0.4, color: Colors.black87),
                    ),
                  ),
                  const SizedBox(height: 48),
                  Divider(thickness: 2.5, color: Colors.grey[400]),
                  const SizedBox(height: 32),
                  _buildDocumentRow(s.writtenDateLabel, dateFormat.format(agreement.agreedAt)),
                  const SizedBox(height: 16),
                  _buildDocumentRow(s.writtenTimeLabel, timeFormat.format(agreement.agreedAt)),
                  const SizedBox(height: 16),
                  if (agreement.dormBuilding != null && agreement.dormBuilding!.isNotEmpty)
                    _buildDocumentRow(s.building, agreement.dormBuilding!),
                  if (agreement.dormBuilding != null && agreement.dormBuilding!.isNotEmpty)
                    const SizedBox(height: 16),
                  _buildDocumentRow(s.room, agreement.roomNumber),
                  const SizedBox(height: 16),
                  _buildDocumentRow(s.name, agreement.userName),
                  const SizedBox(height: 32),
                  Text(s.signature,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 12),
                  Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[400]!, width: 2),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: agreement.signatureUrl.isNotEmpty
                          ? Image.network(
                              agreement.signatureUrl,
                              fit: BoxFit.contain,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) => Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                                    const SizedBox(height: 8),
                                    Text(s.signatureLoadError,
                                        style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                                  ],
                                ),
                              ),
                            )
                          : Center(
                              child: Text(s.noSignature,
                                  style: TextStyle(fontSize: 16, color: Colors.grey[500]))),
                    ),
                  ),
                  const SizedBox(height: 48),
                  const Divider(thickness: 1),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      s.finalStatement,
                      style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic,
                          color: Colors.black54, fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(dateFormat.format(agreement.agreedAt),
                              style: TextStyle(fontSize: 14, color: Colors.grey[700], fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(s.dormLabel,
                              style: TextStyle(fontSize: 15, color: Colors.grey[800], fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200, width: 1.5),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade700, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.agreementCompleted,
                          style: TextStyle(fontSize: 15, color: Colors.green.shade900, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        s.writtenAt(dateFormat.format(agreement.agreedAt), timeFormat.format(agreement.agreedAt)),
                        style: TextStyle(fontSize: 13, color: Colors.green.shade800),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey[400]!, width: 1.5)),
            ),
            child: Text(value,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black87)),
          ),
        ),
      ],
    );
  }
}
