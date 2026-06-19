import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'auth_provider.dart';

class Achievement {
  final String id;
  final String key;
  final String name;
  final String description;
  final String iconName;
  final int xpReward;

  Achievement({
    required this.id,
    required this.key,
    required this.name,
    required this.description,
    required this.iconName,
    required this.xpReward,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) {
    return Achievement(
      id: json['id']?.toString() ?? '',
      key: json['key']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      iconName: json['icon']?.toString() ?? 'emoji_events',
      xpReward: json['xp_reward'] ?? json['xpReward'] ?? 50,
    );
  }
}

class AchievementsState {
  final List<Achievement> allAchievements;
  final Set<String> earnedKeys;
  final Map<String, String> earnedDates; // Map of key -> date earned
  final bool isLoading;
  final String? error;

  AchievementsState({
    required this.allAchievements,
    required this.earnedKeys,
    required this.earnedDates,
    required this.isLoading,
    this.error,
  });

  AchievementsState copyWith({
    List<Achievement>? allAchievements,
    Set<String>? earnedKeys,
    Map<String, String>? earnedDates,
    bool? isLoading,
    String? error,
  }) {
    return AchievementsState(
      allAchievements: allAchievements ?? this.allAchievements,
      earnedKeys: earnedKeys ?? this.earnedKeys,
      earnedDates: earnedDates ?? this.earnedDates,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class AchievementsNotifier extends Notifier<AchievementsState> {
  final List<Achievement> _defaultAchievements = [
    Achievement(
      id: '1',
      key: 'perfect_predictor',
      name: 'Perfect Predictor',
      description: 'Score 11/11 pts on a single match prediction',
      iconName: 'emoji_events',
      xpReward: 100,
    ),
    Achievement(
      id: '2',
      key: 'early_bird',
      name: 'Early Bird',
      description: 'Submit prediction 24 hours before match deadline',
      iconName: 'schedule',
      xpReward: 50,
    ),
    Achievement(
      id: '3',
      key: 'night_owl',
      name: 'Night Owl',
      description: 'Submit prediction between 12:00 AM and 5:00 AM',
      iconName: 'dark_mode',
      xpReward: 50,
    ),
    Achievement(
      id: '4',
      key: 'streak_7',
      name: '7-Day Streak',
      description: 'Maintain a 7-day daily login streak',
      iconName: 'local_fire_department',
      xpReward: 100,
    ),
    Achievement(
      id: '5',
      key: 'streak_30',
      name: '30-Day Streak',
      description: 'Maintain a 30-day daily login streak',
      iconName: 'whatshot',
      xpReward: 250,
    ),
    Achievement(
      id: '6',
      key: 'sportle_master',
      name: 'Sportle Master',
      description: 'Get a perfect Flag Quiz round or First Goal prediction',
      iconName: 'stars',
      xpReward: 100,
    ),
  ];

  @override
  AchievementsState build() {
    // Watch Auth Provider to reload achievements when user changes
    ref.listen(authProvider, (previous, next) {
      if (next.value != previous?.value) {
        loadAchievements();
      }
    });

    // Run initial load
    Future.microtask(() => loadAchievements());

    return AchievementsState(
      allAchievements: _defaultAchievements,
      earnedKeys: {},
      earnedDates: {},
      isLoading: true,
    );
  }

  Future<void> loadAchievements() async {
    final user = ref.read(authProvider).value;
    if (user == null) {
      state = state.copyWith(earnedKeys: {}, earnedDates: {}, isLoading: false);
      return;
    }

    state = state.copyWith(isLoading: true);

    try {
      final client = sb.Supabase.instance.client;

      // 1. Load available achievements if database achievements table exists
      List<Achievement> dbAchievements = _defaultAchievements;
      try {
        final achievementsRes = await client.from('achievements').select();
        if (achievementsRes.isNotEmpty) {
          dbAchievements = achievementsRes
              .map<Achievement>((item) => Achievement.fromJson(item))
              .toList();
        }
      } catch (e) {
        debugPrint("Supabase achievements table query failed, using default achievements list: $e");
      }

      // 2. Load user-earned achievements
      final Set<String> earnedKeys = {};
      final Map<String, String> earnedDates = {};
      try {
        final userAchievementsRes = await client
            .from('user_achievements')
            .select('earned_at, achievements(key)')
            .eq('user_id', user.id);

        for (final item in userAchievementsRes) {
          final earnedAt = item['earned_at']?.toString() ?? DateTime.now().toIso8601String();
          final achievementData = item['achievements'];
          if (achievementData != null && achievementData is Map) {
            final key = achievementData['key']?.toString();
            if (key != null) {
              earnedKeys.add(key);
              earnedDates[key] = earnedAt;
            }
          }
        }
      } catch (e) {
        debugPrint("Supabase user_achievements query failed: $e");
        // Fallback local memory values for offline sandbox testing
        if (user.id == 'mock-user-id') {
          earnedKeys.addAll({'early_bird'});
          earnedDates['early_bird'] = DateTime.now().subtract(const Duration(days: 2)).toIso8601String();
        }
      }

      state = state.copyWith(
        allAchievements: dbAchievements,
        earnedKeys: earnedKeys,
        earnedDates: earnedDates,
        isLoading: false,
      );
    } catch (e) {
      debugPrint("Load achievements failed overall: $e");
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> unlockAchievement(String key) async {
    final user = ref.read(authProvider).value;
    if (user == null) return false;

    // Check if already earned
    if (state.earnedKeys.contains(key)) {
      return false;
    }

    final achievement = state.allAchievements.firstWhere(
      (a) => a.key == key,
      orElse: () => Achievement(id: '', key: '', name: '', description: '', iconName: '', xpReward: 0),
    );

    if (achievement.key.isEmpty) {
      debugPrint("Achievement with key $key not found.");
      return false;
    }

    final nowStr = DateTime.now().toIso8601String();
    
    // Update local state immediately
    final updatedKeys = Set<String>.from(state.earnedKeys)..add(key);
    final updatedDates = Map<String, String>.from(state.earnedDates)..[key] = nowStr;
    state = state.copyWith(earnedKeys: updatedKeys, earnedDates: updatedDates);

    // Award XP
    ref.read(authProvider.notifier).awardXp(
      amount: achievement.xpReward,
      action: 'Unlocked Achievement: ${achievement.name}',
    );

    // Save to database
    try {
      final client = sb.Supabase.instance.client;
      // Get DB achievement ID from achievements table first, fallback to mock insert
      String dbId = achievement.id;
      try {
        final dbAchievement = await client
            .from('achievements')
            .select('id')
            .eq('key', key)
            .maybeSingle();
        if (dbAchievement != null) {
          dbId = dbAchievement['id']?.toString() ?? achievement.id;
        }
      } catch (_) {}

      await client.from('user_achievements').insert({
        'user_id': user.id,
        'achievement_id': dbId,
        'earned_at': nowStr,
      });
      return true;
    } catch (e) {
      debugPrint("Failed to persist user achievement in Supabase: $e");
      return true; // proceed locally
    }
  }
}

final achievementsProvider =
    NotifierProvider<AchievementsNotifier, AchievementsState>(() {
  return AchievementsNotifier();
});
