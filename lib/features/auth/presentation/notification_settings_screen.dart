import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/notifications_service.dart';
import '../../../core/theme/color_scheme.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/pitch_background.dart';
import '../providers/auth_provider.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends ConsumerState<NotificationSettingsScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  late NotificationPrefs _prefs;
  String? _fcmToken;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final user = ref.read(authProvider).value;
    if (user == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final loadedPrefs = await NotificationsService.instance.loadPreferences(user.id);
      final token = NotificationsService.instance.fcmToken;
      if (mounted) {
        setState(() {
          _prefs = loadedPrefs;
          _fcmToken = token;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Failed to load notification preferences: $e");
      if (mounted) {
        setState(() {
          _prefs = NotificationPrefs();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _savePreferences() async {
    final user = ref.read(authProvider).value;
    if (user == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final success = await NotificationsService.instance.savePreferences(user.id, _prefs);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? "Preferences saved successfully!" : "Failed to save preferences.",
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: success ? SkorioColors.onSecondaryContainer : SkorioColors.errorContainer,
          ),
        );
      }
    } catch (e) {
      debugPrint("Failed to save preferences: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("An error occurred while saving."),
            backgroundColor: SkorioColors.errorContainer,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).value;

    if (user == null) {
      return Scaffold(
        backgroundColor: SkorioColors.baseBg,
        body: Stack(
          children: [
            const PitchBackground(child: SizedBox.expand()),
            SafeArea(
              child: Column(
                children: [
                  _buildHeader(context),
                  const Expanded(
                    child: Center(
                      child: Text(
                        "Please login to manage notification settings.",
                        style: TextStyle(color: Colors.white70),
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

    return Scaffold(
      backgroundColor: SkorioColors.baseBg,
      body: Stack(
        children: [
          const PitchBackground(child: SizedBox.expand()),

          // Ambient glowing backdrops
          Positioned(
            top: 40,
            right: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: SkorioColors.primary.withValues(alpha: 0.04),
              ),
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
                child: Container(color: SkorioColors.primary.withValues(alpha: 0.04)),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: SkorioColors.primary,
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(16.0),
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Control which updates you receive. Stay informed about matching times, score updates, and exclusive shop items.",
                                style: SkorioTextStyles.bodyMd.copyWith(
                                  color: SkorioColors.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 24),

                              GlassCard(
                                padding: const EdgeInsets.all(20.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildPreferenceToggle(
                                      title: "Deadline Reminders",
                                      subtitle: "Receive alerts 30 minutes before World Cup match kick-offs.",
                                      value: _prefs.deadlineReminder,
                                      onChanged: (val) {
                                        setState(() {
                                          _prefs = _prefs.copyWith(deadlineReminder: val);
                                        });
                                      },
                                    ),
                                    _buildPreferenceToggle(
                                      title: "Result Published",
                                      subtitle: "Get notified as soon as prediction scores and points are updated.",
                                      value: _prefs.resultPublished,
                                      onChanged: (val) {
                                        setState(() {
                                          _prefs = _prefs.copyWith(resultPublished: val);
                                        });
                                      },
                                    ),
                                    _buildPreferenceToggle(
                                      title: "Daily Spin Ready",
                                      subtitle: "Get reminded when your free daily wheel spin becomes available.",
                                      value: _prefs.dailySpinReady,
                                      onChanged: (val) {
                                        setState(() {
                                          _prefs = _prefs.copyWith(dailySpinReady: val);
                                        });
                                      },
                                    ),
                                    _buildPreferenceToggle(
                                      title: "Leaderboard Movement",
                                      subtitle: "Alerts when you enter or drop out of the top 3 leaderboard ranks.",
                                      value: _prefs.leaderboardMoved,
                                      onChanged: (val) {
                                        setState(() {
                                          _prefs = _prefs.copyWith(leaderboardMoved: val);
                                        });
                                      },
                                    ),
                                    _buildPreferenceToggle(
                                      title: "Cold Re-engagement",
                                      subtitle: "Gentle reminders if you haven't checked the app in over 3 days.",
                                      value: _prefs.reEngagement,
                                      onChanged: (val) {
                                        setState(() {
                                          _prefs = _prefs.copyWith(reEngagement: val);
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 8),
                                    const Divider(color: Colors.white10, height: 1),
                                    const SizedBox(height: 16),
                                    _buildTokenDisplay(_fcmToken),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 24),

                              // Save Button
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: SkorioColors.primaryContainer,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 2,
                                  ),
                                  onPressed: _isSaving ? null : _savePreferences,
                                  child: _isSaving
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Text(
                                          "SAVE PREFERENCES",
                                          style: SkorioTextStyles.labelMd.copyWith(
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.1,
                                            color: SkorioColors.onPrimaryContainer,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 32),
                            ],
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

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          InkWell(
            onTap: () => context.pop(),
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back, color: Colors.white70, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Back',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          Text(
            'NOTIFICATION SETTINGS',
            style: SkorioTextStyles.labelMd.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 14,
              letterSpacing: 1.2,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 48), // Balancing spacer matching back button width
        ],
      ),
    );
  }

  Widget _buildPreferenceToggle({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.04),
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: SkorioTextStyles.labelMd.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: SkorioTextStyles.labelSm.copyWith(
                    color: SkorioColors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: SkorioColors.secondary,
            activeTrackColor: SkorioColors.secondary.withValues(alpha: 0.3),
            inactiveThumbColor: Colors.grey,
            inactiveTrackColor: Colors.white10,
          ),
        ],
      ),
    );
  }

  Widget _buildTokenDisplay(String? token) {
    final hasToken = token != null && token.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.04),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.key_outlined, color: SkorioColors.primary, size: 16),
              const SizedBox(width: 8),
              Text(
                "FCM Device Token",
                style: SkorioTextStyles.labelMd.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              if (hasToken)
                IconButton(
                  icon: const Icon(Icons.copy_rounded, color: SkorioColors.primary, size: 18),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: token));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("FCM token copied to clipboard!"),
                        backgroundColor: SkorioColors.onPrimaryContainer,
                      ),
                    );
                  },
                  tooltip: "Copy Token",
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hasToken ? token : "FCM Token not available (Offline / Simulator Mode)",
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: SkorioTextStyles.labelSm.copyWith(
              color: hasToken ? SkorioColors.onSurfaceVariant : Colors.white24,
              fontFamily: 'monospace',
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
