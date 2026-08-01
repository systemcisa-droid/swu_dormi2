import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/locale_provider.dart';
import '../../utils/check_in_out_strings.dart';

class CheckInOutScreen extends StatelessWidget {
  const CheckInOutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = CheckInOutStrings(Provider.of<LocaleProvider>(context).isEnglish);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.title),
      ),
      body: const _GuideTab(),
    );
  }
}

class _GuideTab extends StatefulWidget {
  const _GuideTab();

  @override
  State<_GuideTab> createState() => _GuideTabState();
}

class _GuideTabState extends State<_GuideTab> {
  final _scrollCtrl = ScrollController();

  // 0=입사자격, 1=입사절차, 2=정규퇴사, 3=학기중퇴사, 4=강제퇴사, 5=영구퇴사, 6=관비환불
  final List<GlobalKey> _keys = List.generate(7, (_) => GlobalKey());

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
        ? CheckInOutStrings.categoryLabelsEn
        : CheckInOutStrings.categoryLabelsKo;
    final cards = CheckInOutContent.cards;

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
                for (int i = 0; i < cards.length; i++) ...[
                  _buildCard(
                    context,
                    isEnglish ? cards[i].titleEn : cards[i].titleKo,
                    anchorKey: _keys[i],
                    [
                      for (final section in cards[i].sections)
                        _buildSubSection(
                          isEnglish ? section.titleEn : section.titleKo,
                          isEnglish ? section.contentEn : section.contentKo,
                        ),
                      for (int b = 0; b < cards[i].bulletsKo.length; b++)
                        _buildBulletPoint(
                          isEnglish ? cards[i].bulletsEn[b] : cards[i].bulletsKo[b],
                        ),
                    ],
                  ),
                  SizedBox(height: i == 1 ? 32 : 16),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(BuildContext context, String title, List<Widget> children, {Key? anchorKey}) {
    return Card(
      key: anchorKey,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildSubSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 13)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
