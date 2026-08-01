import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/database_service.dart';
import '../../services/storage_service.dart';
import '../../models/point_history_model.dart';
import '../../utils/app_strings.dart';
import '../../utils/profile_strings.dart';
import 'reward_penalty_screen.dart';
import 'notification_settings_screen.dart';
import 'change_password_screen.dart';
import 'privacy_policy_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploadingImage = false;

  Future<void> _pickAndUploadImage(ImageSource source) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    if (user == null) return;

    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 70,
      );
      if (picked == null) return;

      setState(() => _isUploadingImage = true);

      final url = await StorageService()
          .uploadProfileImage(user.uid, File(picked.path));
      if (url != null) {
        await DatabaseService().updateProfileImageUrl(user.uid, url);
        await authProvider.refreshUserData();
      }
    } catch (e) {
      if (mounted) {
        final s = ProfileStrings(Provider.of<LocaleProvider>(context, listen: false).isEnglish);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${s.imageUploadError}: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  void _showImageSourceDialog() {
    final s = ProfileStrings(Provider.of<LocaleProvider>(context, listen: false).isEnglish);
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(s.takePhoto),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(s.chooseFromGallery),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;
    final isEnglish = Provider.of<LocaleProvider>(context).isEnglish;
    final s = ProfileStrings(isEnglish);
    final a = AppStrings(isEnglish);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.title),
      ),
      body: user == null
          ? Center(child: Text(s.userDataUnavailable))
          : SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32.0),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                    ),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _isUploadingImage ? null : _showImageSourceDialog,
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 60,
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                child: user.profileImageUrl != null
                                    ? ClipOval(
                                        child: Image.network(
                                          user.profileImageUrl!,
                                          width: 120,
                                          height: 120,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) =>
                                              const Icon(
                                            Icons.person,
                                            size: 60,
                                            color: Colors.white,
                                          ),
                                        ),
                                      )
                                    : const Icon(
                                        Icons.person,
                                        size: 60,
                                        color: Colors.white,
                                      ),
                              ),
                              if (_isUploadingImage)
                                const Positioned.fill(
                                  child: CircleAvatar(
                                    radius: 60,
                                    backgroundColor: Colors.black45,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  child: const Icon(
                                    Icons.camera_alt,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                user.name,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                            if (user.nickname != null && user.nickname!.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  '(${user.nickname})',
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        color: Colors.grey.shade700,
                                      ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.studentId,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 12),
                        StreamBuilder<List<PointHistoryModel>>(
                          stream: DatabaseService().getPointHistory(user.uid),
                          builder: (context, snapshot) {
                            int totalPoints = user.points;
                            if (snapshot.hasData) {
                              totalPoints = snapshot.data!.fold<int>(
                                0,
                                (sum, e) => sum + (e.isReward ? e.points : -e.points),
                              );
                            }
                            return Column(
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const RewardPenaltyScreen(initialTab: 1),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.85),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.star_rounded,
                                          size: 20,
                                          color: totalPoints >= 0 ? Colors.amber.shade700 : Colors.red.shade600,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          s.rewardPenalty,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${totalPoints > 0 ? '+' : ''}$totalPoints점',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: totalPoints < 0 ? Colors.red.shade600 : Colors.grey.shade800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  s.pointNotice,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoCard(
                    context,
                    title: s.personalInfo,
                    items: [
                      _buildInfoTile(
                        icon: Icons.email,
                        label: s.email,
                        value: user.email,
                      ),
                      _buildInfoTile(
                        icon: Icons.phone,
                        label: s.phoneNumber,
                        value: _formatPhone(user.phoneNumber),
                      ),
                      if (user.department != null)
                        _buildInfoTile(
                          icon: Icons.class_,
                          label: s.department,
                          value: user.department!,
                        ),
                      if (user.dormBuilding != null)
                        _buildInfoTile(
                          icon: Icons.apartment,
                          label: s.dormBuilding,
                          value: user.dormBuilding!,
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoTile(
                              icon: Icons.meeting_room,
                              label: s.room,
                              value: user.roomCapacity.isNotEmpty ? '${user.roomNumber} (${user.roomCapacity})' : user.roomNumber,
                            ),
                          ),
                          if (user.seatNumber != null && user.seatNumber!.isNotEmpty)
                            Expanded(
                              child: _buildInfoTile(
                                icon: Icons.chair,
                                label: s.seatNumber,
                                value: user.seatNumber!,
                              ),
                            ),
                        ],
                      ),

                      _buildInfoTile(
                        icon: Icons.calendar_today,
                        label: s.joinDate,
                        value: s.joinDateFormatted(user.createdAt),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSettingsCard(context, s),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: ElevatedButton(
                      onPressed: () => _showLogoutDialog(context, s, a),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: Text(a.logout),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  String _formatPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 11) {
      return '${digits.substring(0, 3)}-${digits.substring(3, 7)}-${digits.substring(7)}';
    } 
    return phone;
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required String title,
    required List<Widget> items,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const Divider(height: 24),
            ...items,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Icon(icon, size: 24, color: Colors.grey.shade600),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(BuildContext context, ProfileStrings s) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.notifications),
            title: Text(s.notificationSettings),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationSettingsScreen(),
                ),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.lock),
            title: Text(s.changePassword),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ChangePasswordScreen(),
                ),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: Text(s.privacyPolicyAndWithdrawal),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PrivacyPolicyScreen(),
                ),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.info),
            title: Text(s.appInfo),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              _showAboutDialog(context, s, AppStrings(s.isEnglish));
            },
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, ProfileStrings s, AppStrings a) {
    final rootContext = context;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(s.logoutTitle),
        content: Text(s.logoutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(a.cancel),
          ),
          TextButton(
            onPressed: () async {
              final authProvider =
                  Provider.of<AuthProvider>(rootContext, listen: false);
              Navigator.pop(dialogContext);
              await authProvider.signOut();
              if (rootContext.mounted) {
                Navigator.of(rootContext).popUntil((route) => route.isFirst);
              }
            },
            child: Text(
              a.logout,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context, ProfileStrings s, AppStrings a) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.appInfoTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.appVersion),
            const SizedBox(height: 8),
            Text(s.appInfoSubtitle),
            const SizedBox(height: 16),
            Text(
              s.appInfoDescription,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(a.confirm),
          ),
        ],
      ),
    );
  }
}
