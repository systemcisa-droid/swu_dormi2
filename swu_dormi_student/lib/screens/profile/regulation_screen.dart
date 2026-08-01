import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../models/regulation_agreement_model.dart';
import '../../utils/regulation_strings.dart';
import '../../utils/regulation_content.dart';

class RegulationScreen extends StatefulWidget {
  const RegulationScreen({super.key});

  @override
  State<RegulationScreen> createState() => _RegulationScreenState();
}

class _RegulationScreenState extends State<RegulationScreen>
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
    final s = RegulationStrings(Provider.of<LocaleProvider>(context).isEnglish);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.title),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.article),
              text: s.tabRegulation,
            ),
            Tab(
              icon: const Icon(Icons.edit),
              text: s.tabSignature,
            ),
            Tab(
              icon: const Icon(Icons.description),
              text: s.tabDocument,
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _RegulationContent(),
          _SignatureTab(
            onNext: () {
              _tabController.animateTo(2); // 서약서내용 탭으로 이동
            },
          ),
          const _AgreementDocumentTab(),
        ],
      ),
    );
  }
}

// 사생수칙 내용 탭
class _RegulationContent extends StatefulWidget {
  @override
  State<_RegulationContent> createState() => _RegulationContentState();
}

class _RegulationContentState extends State<_RegulationContent> {
  final _scrollCtrl = ScrollController();
  final List<GlobalKey> _keys = List.generate(9, (_) => GlobalKey());

  static const _chapterIcons = [
    Icons.gavel, Icons.how_to_reg, Icons.meeting_room, Icons.fact_check,
    Icons.home, Icons.campaign, Icons.medical_services, Icons.warning, Icons.groups,
  ];

  void _scrollTo(int index) {
    final ctx = _keys[index].currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut);
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = Provider.of<LocaleProvider>(context).isEnglish;
    final categoryLabels = isEnglish
        ? RegulationContent.categoryLabelsEn
        : RegulationContent.categoryLabelsKo;

    // 데이터의 9개 장(9장 벌칙 제외 8개 + 벌칙 1개)을 순서대로 앵커에 매핑
    // chapters 리스트는 벌칙(9장)을 제외한 8개 장을 담고 있으므로, 인덱스 7(8번째) 다음에 벌칙을 삽입
    return Column(
      children: [
        // 카테고리 인덱스 바
        Container(
          height: 46,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              children: categoryLabels.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ActionChip(
                  label: Text(e.value, style: const TextStyle(fontSize: 12)),
                  onPressed: () => _scrollTo(e.key),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: Theme.of(context)
                      .colorScheme.primaryContainer.withValues(alpha: 0.5),
                ),
              )).toList(),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollCtrl,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < 7; i++) ...[
                  _buildChapter(context, anchorKey: _keys[i], icon: _chapterIcons[i],
                      chapter: RegulationContent.chapters[i], isEnglish: isEnglish),
                  const SizedBox(height: 16),
                ],
                _buildPenaltyChapter(context, anchorKey: _keys[7], isEnglish: isEnglish),
                const SizedBox(height: 16),
                _buildChapter(context, anchorKey: _keys[8], icon: _chapterIcons[8],
                    chapter: RegulationContent.chapters[7], isEnglish: isEnglish),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChapter(
    BuildContext context, {
    Key? anchorKey,
    required IconData icon,
    required RegulationChapter chapter,
    required bool isEnglish,
  }) {
    return Card(
      key: anchorKey,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 장 제목
            Row(
              children: [
                Icon(icon, color: Theme.of(context).primaryColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEnglish ? chapter.numberEn : chapter.numberKo,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        isEnglish ? chapter.titleEn : chapter.titleKo,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),

            // 조항들
            ...chapter.articles.map((article) {
              final title = isEnglish ? article.titleEn : article.titleKo;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEnglish ? article.numberEn : article.numberKo,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        if (title != null) ...[
                          const SizedBox(width: 4),
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isEnglish ? article.contentEn : article.contentKo,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildPenaltyChapter(BuildContext context, {Key? anchorKey, required bool isEnglish}) {
    String t(String ko, String en) => isEnglish ? en : ko;
    return Card(
      key: anchorKey,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 장 제목
            Row(
              children: [
                Icon(Icons.warning, color: Colors.red.shade700, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t(RegulationContent.penaltyChapterNumberKo, RegulationContent.penaltyChapterNumberEn),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        t(RegulationContent.penaltyChapterTitleKo, RegulationContent.penaltyChapterTitleEn),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),

            // 제40조
            Text(
              t(RegulationContent.article40NumberKo, RegulationContent.article40NumberEn),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              t(RegulationContent.article40IntroKo, RegulationContent.article40IntroEn),
              style: const TextStyle(fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 12),

            // 처분 종류
            _buildPenaltyItem(t(RegulationContent.warningKo, RegulationContent.warningEn)),
            _buildPenaltyItem(t(RegulationContent.penaltyPointKo, RegulationContent.penaltyPointEn)),
            _buildPenaltyItem(
              t(RegulationContent.forcedMoveOutKo, RegulationContent.forcedMoveOutEn),
              isEnglish ? RegulationContent.forcedMoveOutSubItemsEn : RegulationContent.forcedMoveOutSubItemsKo,
            ),
            _buildPenaltyItem(
              t(RegulationContent.permanentMoveOutKo, RegulationContent.permanentMoveOutEn),
              isEnglish ? RegulationContent.permanentMoveOutSubItemsEn : RegulationContent.permanentMoveOutSubItemsKo,
            ),
            const SizedBox(height: 12),

            // 반입 가능/불가 물품
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t(RegulationContent.itemsTitleKo, RegulationContent.itemsTitleEn),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t(RegulationContent.allowedItemsKo, RegulationContent.allowedItemsEn),
                    style: const TextStyle(fontSize: 13, height: 1.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t(RegulationContent.prohibitedLabelKo, RegulationContent.prohibitedLabelEn),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t(RegulationContent.prohibitedElectricKo, RegulationContent.prohibitedElectricEn),
                    style: const TextStyle(fontSize: 13, height: 1.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t(RegulationContent.prohibitedFireKo, RegulationContent.prohibitedFireEn),
                    style: const TextStyle(fontSize: 13, height: 1.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t(RegulationContent.prohibitedAlcoholKo, RegulationContent.prohibitedAlcoholEn),
                    style: const TextStyle(fontSize: 13, height: 1.5),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      t(RegulationContent.prohibitedPenaltyNoticeKo, RegulationContent.prohibitedPenaltyNoticeEn),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 제41조
            Text(
              t(RegulationContent.article41NumberKo, RegulationContent.article41NumberEn),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              t(RegulationContent.article41Item1Ko, RegulationContent.article41Item1En),
              style: const TextStyle(fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 6),
            Text(
              t(RegulationContent.article41Item2Ko, RegulationContent.article41Item2En),
              style: const TextStyle(fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 6),
            Text(
              t(RegulationContent.article41Item3Ko, RegulationContent.article41Item3En),
              style: const TextStyle(fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 16),

            // 제42조
            Text(
              t(RegulationContent.article42NumberKo, RegulationContent.article42NumberEn),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              t(RegulationContent.article42Item1Ko, RegulationContent.article42Item1En),
              style: const TextStyle(fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 6),
            Text(
              t(RegulationContent.article42Item2Ko, RegulationContent.article42Item2En),
              style: const TextStyle(fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 16),

            // 제43조
            Text(
              t(RegulationContent.article43NumberKo, RegulationContent.article43NumberEn),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              t(RegulationContent.article43ContentKo, RegulationContent.article43ContentEn),
              style: const TextStyle(fontSize: 14, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPenaltyItem(String title, [List<String>? subItems]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              height: 1.6,
            ),
          ),
          if (subItems != null) ...[
            const SizedBox(height: 4),
            ...subItems.map((item) => Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 4),
                  child: Text(
                    item,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.6,
                    ),
                  ),
                )),
          ],
        ],
      ),
    );
  }
}

// 동의 및 서명 탭
class _SignatureTab extends StatefulWidget {
  final VoidCallback onNext;

  const _SignatureTab({required this.onNext});

  @override
  State<_SignatureTab> createState() => _SignatureTabState();
}

class _SignatureTabState extends State<_SignatureTab> {
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
    final s = RegulationStrings(
        Provider.of<LocaleProvider>(context, listen: false).isEnglish);
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.nameRequired),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_signatureController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.signatureRequired),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.userNotFound),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. 서명을 PNG 이미지로 변환
      final signatureBytes = await _signatureController.toPngBytes();
      if (signatureBytes == null) {
        throw Exception(s.signatureGenerationFailed);
      }

      // 2. Firebase Storage에 서명 이미지 업로드
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('regulation_agreements')
          .child('${user.uid}_${DateTime.now().millisecondsSinceEpoch}.png');

      final uploadTask = await storageRef.putData(
        signatureBytes,
        SettableMetadata(contentType: 'image/png'),
      );

      final signatureUrl = await uploadTask.ref.getDownloadURL();

      // 3. Firestore에 서약서 정보 저장
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
          .collection('regulation_agreements')
          .doc(user.uid)
          .set(agreement.toMap());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.agreementSubmitted),
            backgroundColor: Colors.green,
          ),
        );

        // 서명 초기화
        _nameController.clear();
        _signatureController.clear();

        // 서약서내용 탭으로 이동
        widget.onNext();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.genericError(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;
    final s = RegulationStrings(Provider.of<LocaleProvider>(context).isEnglish);
    final now = DateTime.now();
    final dateFormat = DateFormat(s.isEnglish ? 'MMM d, yyyy HH:mm' : 'yyyy년 MM월 dd일 HH:mm', s.isEnglish ? null : 'ko');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 문서 형식의 동의서
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
                  // 제목
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
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 본문
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Text(
                      s.isEnglish ? s.pledgeBodyEn : s.pledgeBodyKo,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.8,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 구분선
                  const Divider(thickness: 2),
                  const SizedBox(height: 24),

                  // 서명란 안내
                  Text(
                    s.signHint,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 날짜 및 시간
                  Row(
                    children: [
                      const SizedBox(width: 40),
                      Text(
                        s.writtenAtLabel,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        dateFormat.format(now),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 사생 정보
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
                        Text(
                          s.roomLabel,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          user.roomNumber,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],

                  // 이름 입력란
                  Row(
                    children: [
                      const SizedBox(width: 40),
                      Text(
                        s.nameLabel,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            hintText: s.nameHint,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            border: const OutlineInputBorder(),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey[400]!),
                            ),
                          ),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const Expanded(flex: 1, child: SizedBox()),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 서명란
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(width: 40),
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          s.signatureLabel,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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
                                onPressed: () {
                                  _signatureController.clear();
                                },
                                icon: const Icon(Icons.refresh, size: 18),
                                label: Text(s.redo),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
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

                  // 하단 서명 라인
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        s.agreeStatement,
                        style: const TextStyle(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        s.dormLabel,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 제출 버튼
          ElevatedButton(
            onPressed: _isLoading ? null : _submitSignature,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    s.submitAgreement,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
          const SizedBox(height: 16),

          // 안내 문구
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
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// 서약서내용 탭 (완성된 서약서 문서)
class _AgreementDocumentTab extends StatefulWidget {
  const _AgreementDocumentTab();

  @override
  State<_AgreementDocumentTab> createState() => _AgreementDocumentTabState();
}

class _AgreementDocumentTabState extends State<_AgreementDocumentTab> {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;
    final s = RegulationStrings(Provider.of<LocaleProvider>(context).isEnglish);

    if (user == null) {
      return Center(
        child: Text(s.userDataUnavailable),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('regulation_agreements')
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

  Widget _buildNoAgreementView(RegulationStrings s) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 100),
          Icon(
            Icons.assignment_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 24),
          Text(
            s.noAgreementYet,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            s.noAgreementHint,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgreementView(RegulationAgreementModel agreement, RegulationStrings s) {
    final dateFormat = DateFormat(s.isEnglish ? 'MMM d, yyyy' : 'yyyy년 MM월 dd일', s.isEnglish ? null : 'ko');
    final timeFormat = DateFormat('HH:mm');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 완성된 서약서 문서
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
                  // 문서 제목
                  Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.assignment_turned_in,
                          size: 48,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          s.formTitle,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          s.formSubtitle,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // 서약 내용
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!, width: 1.5),
                    ),
                    child: Text(
                      s.isEnglish ? s.documentPledgeEn : s.documentPledgeKo,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.9,
                        letterSpacing: 0.4,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),

                  // 구분선
                  Divider(
                    thickness: 2.5,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 32),

                  // 작성 정보
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

                  // 서명란
                  Text(
                    s.signature,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
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
                              errorBuilder: (context, error, stackTrace) {
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.error_outline,
                                        size: 48,
                                        color: Colors.red[300],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        s.signatureLoadError,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            )
                          : Center(
                              child: Text(
                                s.noSignature,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 48),

                  // 하단 문구
                  const Divider(thickness: 1),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      s.finalStatement,
                      style: const TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            dateFormat.format(agreement.agreedAt),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            s.dormLabel,
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey[800],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 완료 안내 문구
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
                      Text(
                        s.agreementCompleted,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.green.shade900,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        s.writtenAt(dateFormat.format(agreement.agreedAt), timeFormat.format(agreement.agreedAt)),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.green.shade800,
                        ),
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
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey[400]!, width: 1.5),
              ),
            ),
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
