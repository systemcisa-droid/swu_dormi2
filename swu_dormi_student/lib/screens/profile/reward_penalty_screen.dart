import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../models/point_history_model.dart';
import '../../services/database_service.dart';
import '../../utils/reward_penalty_strings.dart';

class RewardPenaltyScreen extends StatefulWidget {
  final int initialTab;
  const RewardPenaltyScreen({super.key, this.initialTab = 0});

  @override
  State<RewardPenaltyScreen> createState() => _RewardPenaltyScreenState();
}

class _RewardPenaltyScreenState extends State<RewardPenaltyScreen> {
  late int _selectedTab; // 0: 기준표, 1: 이력

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = Provider.of<LocaleProvider>(context).isEnglish;
    final s = RewardPenaltyStrings(isEnglish);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.title),
      ),
      body: Column(
        children: [
          // 탭 버튼
          Container(
            color: Theme.of(context).colorScheme.surface,
            child: Row(
              children: [
                _buildTabButton(0, s.tabCriteria),
                _buildTabButton(1, s.tabHistory),
              ],
            ),
          ),
          const Divider(height: 1),
          // 탭 콘텐츠
          Expanded(
            child: _selectedTab == 0 ? _buildCriteriaTab(s, isEnglish) : _buildHistoryTab(s, isEnglish),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String label) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey.shade600,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }

  // ===== 기준표 탭 =====

  Widget _buildCriteriaTab(RewardPenaltyStrings s, bool isEnglish) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(s.penaltyCriteriaTitle, Icons.warning_amber, Colors.red),
          const SizedBox(height: 16),
          for (int i = 0; i < RewardPenaltyContent.penaltyCards.length; i++) ...[
            _buildCriteriaCard(RewardPenaltyContent.penaltyCards[i], isEnglish, isPenalty: true),
            const SizedBox(height: 12),
          ],
          _buildInfoBox(isEnglish ? RewardPenaltyContent.penaltyInfoEn : RewardPenaltyContent.penaltyInfoKo),
          const SizedBox(height: 32),
          _buildSectionTitle(s.rewardCriteriaTitle, Icons.star, Colors.blue),
          const SizedBox(height: 16),
          for (int i = 0; i < RewardPenaltyContent.rewardCards.length; i++) ...[
            _buildCriteriaCard(RewardPenaltyContent.rewardCards[i], isEnglish, isPenalty: false),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  // ===== 이력 탭 =====

  Widget _buildHistoryTab(RewardPenaltyStrings s, bool isEnglish) {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null) {
      return Center(child: Text(s.userDataUnavailable));
    }

    return StreamBuilder<List<PointHistoryModel>>(
      stream: DatabaseService().getPointHistory(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(s.genericError(snapshot.error!)));
        }

        final history = snapshot.data ?? [];

        // 합계 계산
        final total = history.fold<int>(0, (sum, e) => sum + (e.isReward ? e.points : -e.points));

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 현재 합계 카드
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: total < 0
                      ? Colors.red.shade50
                      : Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.star_rounded,
                      size: 32,
                      color: total < 0 ? Colors.red.shade600 : Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.currentTotalLabel,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          '${total > 0 ? '+' : ''}${s.points(total)}',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: total < 0
                                ? Colors.red.shade600
                                : Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                s.historyCount(history.length),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              if (history.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Column(
                      children: [
                        Icon(Icons.history, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          s.noHistory,
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...history.map((entry) => _buildHistoryItem(entry, s)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistoryItem(PointHistoryModel entry, RewardPenaltyStrings s) {
    final isReward = entry.isReward;
    final pointValue = isReward ? entry.points : -entry.points;
    final color = isReward ? Colors.blue.shade600 : Colors.red.shade600;
    final bgColor = isReward ? Colors.blue.shade50 : Colors.red.shade50;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isReward ? Icons.arrow_upward : Icons.arrow_downward,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.reason,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(entry.createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${pointValue > 0 ? '+' : ''}${s.points(pointValue)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  // ===== 기준표 위젯들 =====

  Widget _buildSectionTitle(String title, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCriteriaCard(CriteriaCard card, bool isEnglish, {required bool isPenalty}) {
    final title = isEnglish ? card.titleEn : card.titleKo;
    final itemWidgets = card.items.map((item) {
      if (item is SubTitle) {
        return _buildSubTitle(isEnglish ? item.en : item.ko);
      } else if (item is WarningEntry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildWarningBox(isEnglish ? item.en : item.ko, isHighlight: item.isHighlight),
        );
      } else if (item is CriteriaItem) {
        return _buildItem(
          isEnglish ? item.descriptionEn : item.descriptionKo,
          isEnglish ? item.pointsEn : item.pointsKo,
        );
      }
      return const SizedBox.shrink();
    }).toList();

    if (isPenalty) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        card.number ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...itemWidgets,
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.star, color: Colors.blue, size: 24),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...itemWidgets,
          ],
        ),
      ),
    );
  }

  Widget _buildItem(String description, String points) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 13)),
          Expanded(
            child: Text(
              description,
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            points,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildWarningBox(String text, {bool isHighlight = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isHighlight ? Colors.red.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isHighlight ? Colors.red : Colors.orange,
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: isHighlight ? Colors.red.shade900 : Colors.orange.shade900,
          fontWeight: FontWeight.w500,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildInfoBox(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey.shade800,
          height: 1.5,
        ),
      ),
    );
  }
}
