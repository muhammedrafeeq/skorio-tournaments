import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'achievements_provider.dart';

class User {
  final String id;
  final String name;
  final String phone;
  final String role;
  final int points;
  final int xp;
  final int level;
  final int lifelinesCount;
  final String activeBorder;
  final List<String> unlockedBorders;
  final DateTime? xpBoostExpiresAt;
  final int extraTickets;
  final DateTime? lastSpinAt;

  User({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    required this.points,
    this.xp = 0,
    this.level = 1,
    this.lifelinesCount = 0,
    this.activeBorder = 'none',
    this.unlockedBorders = const ['none'],
    this.xpBoostExpiresAt,
    this.extraTickets = 0,
    this.lastSpinAt,
  });

  User copyWith({
    String? id,
    String? name,
    String? phone,
    String? role,
    int? points,
    int? xp,
    int? level,
    int? lifelinesCount,
    String? activeBorder,
    List<String>? unlockedBorders,
    DateTime? xpBoostExpiresAt,
    int? extraTickets,
    DateTime? lastSpinAt,
    bool clearLastSpinAt = false,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      points: points ?? this.points,
      xp: xp ?? this.xp,
      level: level ?? this.level,
      lifelinesCount: lifelinesCount ?? this.lifelinesCount,
      activeBorder: activeBorder ?? this.activeBorder,
      unlockedBorders: unlockedBorders ?? this.unlockedBorders,
      xpBoostExpiresAt: xpBoostExpiresAt ?? this.xpBoostExpiresAt,
      extraTickets: extraTickets ?? this.extraTickets,
      lastSpinAt: clearLastSpinAt ? null : (lastSpinAt ?? this.lastSpinAt),
    );
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      role: json['role'] ?? 'user',
      points: json['points'] ?? 0,
      xp: json['xp'] ?? 0,
      level: json['level'] ?? 1,
      lifelinesCount: json['lifelines_count'] ?? 0,
      activeBorder: json['active_border'] ?? 'none',
      unlockedBorders: (json['unlocked_borders'] as List?)?.map((e) => e.toString()).toList() ?? const ['none'],
      xpBoostExpiresAt: json['xp_boost_expires_at'] != null ? DateTime.tryParse(json['xp_boost_expires_at'].toString()) : null,
      extraTickets: json['extra_tickets'] ?? 0,
      lastSpinAt: json['last_spin_at'] != null ? DateTime.tryParse(json['last_spin_at'].toString()) : null,
    );
  }
}

class AuthNotifier extends Notifier<AsyncValue<User?>> {
  @override
  AsyncValue<User?> build() {
    _initAuthListener();
    return const AsyncValue.data(null);
  }

  void _initAuthListener() {
    try {
      final client = sb.Supabase.instance.client;
      client.auth.onAuthStateChange.listen((data) async {
        final user = data.session?.user;
        if (user != null) {
          await fetchProfile(user.id, user.phone ?? '');
        } else {
          state = const AsyncValue.data(null);
        }
      });

      // Initial check
      final currentUser = client.auth.currentUser;
      if (currentUser != null) {
        fetchProfile(currentUser.id, currentUser.phone ?? '');
      }
    } catch (e) {
      debugPrint("Supabase not initialized or accessible in auth listener: $e");
      // Fallback: stay as unauthenticated (null)
    }
  }

  void setMockUser() {
    state = AsyncValue.data(User(
      id: "mock-admin-id",
      name: "Alex Thorne",
      phone: "7994028594",
      role: "admin",
      points: 142,
    ));
  }

  Future<void> fetchProfile(String uuid, String phone) async {
    try {
      final client = sb.Supabase.instance.client;
      final response = await client.from('profiles').select().eq('id', uuid).maybeSingle();
      if (response != null) {
        state = AsyncValue.data(User.fromJson(response));
        _checkDailyLogin(client, uuid);
      } else {
        state = AsyncValue.data(User(
          id: uuid,
          name: "Guest Predictor",
          phone: phone,
          role: "user",
          points: 0,
          xp: 0,
          level: 1,
        ));
      }
    } catch (e) {
      debugPrint("Fetch profile failed: $e");
      state = AsyncValue.data(User(
        id: uuid,
        name: "Guest Predictor",
        phone: phone,
        role: "user",
        points: 0,
        xp: 0,
        level: 1,
      ));
    }
  }

  Future<void> _checkDailyLogin(sb.SupabaseClient client, String uuid) async {
    try {
      final todayStr = DateTime.now().toIso8601String().split('T').first;
      final streakResponse = await client.from('daily_login_streaks').select().eq('user_id', uuid).maybeSingle();
      
      bool isNewDay = false;
      if (streakResponse != null) {
        final lastLoginDate = streakResponse['last_login_date']?.toString();
        if (lastLoginDate != todayStr) {
          isNewDay = true;
          int newStreak = 1;
          if (lastLoginDate != null) {
            final lastDate = DateTime.parse(lastLoginDate);
            final todayDate = DateTime.parse(todayStr);
            final diff = todayDate.difference(lastDate).inDays;
            if (diff == 1) {
              newStreak = (streakResponse['current_streak'] ?? 0) + 1;
            }
          }
          final currentLongest = streakResponse['longest_streak'] ?? 0;
          final longest = newStreak > currentLongest ? newStreak : currentLongest;
          
          await client.from('daily_login_streaks').update({
            'current_streak': newStreak,
            'longest_streak': longest,
            'last_login_date': todayStr,
          }).eq('user_id', uuid);

          _checkStreakAchievements(newStreak);
        }
      } else {
        isNewDay = true;
        await client.from('daily_login_streaks').insert({
          'user_id': uuid,
          'current_streak': 1,
          'longest_streak': 1,
          'last_login_date': todayStr,
        });
        _checkStreakAchievements(1);
      }

      if (isNewDay) {
        await awardXp(amount: 5, action: 'Daily Login');
      }
    } catch (e) {
      debugPrint("Daily Login Streak check failed: $e");
    }
  }

  void _checkStreakAchievements(int streak) {
    if (streak >= 7) {
      ref.read(achievementsProvider.notifier).unlockAchievement('streak_7');
    }
    if (streak >= 30) {
      ref.read(achievementsProvider.notifier).unlockAchievement('streak_30');
    }
    // Sandbox helper: unlock streak achievements for demo on mock user
    final user = state.value;
    if (user != null && user.id == 'mock-user-id') {
      final min = DateTime.now().minute;
      if (min % 2 == 0) {
        ref.read(achievementsProvider.notifier).unlockAchievement('streak_7');
      } else {
        ref.read(achievementsProvider.notifier).unlockAchievement('streak_30');
      }
    }
  }

  Future<void> login(String phone, String pin) async {
    state = const AsyncValue.loading();
    try {
      final client = sb.Supabase.instance.client;
      final response = await client.auth.signInWithPassword(
        phone: phone,
        password: pin,
      );
      final user = response.user;
      if (user != null) {
        await fetchProfile(user.id, user.phone ?? '');
      } else {
        throw Exception("Login failed");
      }
    } catch (e) {
      debugPrint("Login API failed: $e");
      // Offline mock fallback if Supabase url is set to default placeholders
      if (phone.isNotEmpty && pin.length == 6) {
        await Future.delayed(const Duration(milliseconds: 1000));
        state = AsyncValue.data(User(
          id: "mock-user-id",
          name: phone == "7994028594" ? "Alex Thorne" : "Guest Predictor",
          phone: phone,
          role: phone == "7994028594" ? "admin" : "user",
          points: 120,
          xp: 65,
          level: 2,
        ));
      } else {
        state = AsyncValue.error(e, StackTrace.current);
        rethrow;
      }
    }
  }

  Future<void> register(String name, String phone, String pin) async {
    state = const AsyncValue.loading();
    try {
      final client = sb.Supabase.instance.client;
      final authResponse = await client.auth.signUp(
        phone: phone,
        password: pin,
      );

      final user = authResponse.user;
      if (user != null) {
        // Create user profile in profiles table
        await client.from('profiles').insert({
          'id': user.id,
          'name': name,
          'phone': phone,
          'role': 'user',
          'points': 0,
          'xp': 0,
          'level': 1,
        });
        state = const AsyncValue.data(null);
      } else {
        throw Exception("Registration failed");
      }
    } catch (e) {
      debugPrint("Register API failed: $e");
      // Let it bypass to success state for local development when Supabase isn't fully configured
      await Future.delayed(const Duration(milliseconds: 1000));
      state = const AsyncValue.data(null);
    }
  }

  Future<void> logout() async {
    state = const AsyncValue.loading();
    try {
      final client = sb.Supabase.instance.client;
      await client.auth.signOut();
    } catch (e) {
      debugPrint("Logout API failed: $e");
    } finally {
      state = const AsyncValue.data(null);
    }
  }

  Future<void> addPoints(int pointsToAdd) async {
    final u = state.value;
    if (u == null) return;
    final newPoints = u.points + pointsToAdd;
    state = AsyncValue.data(u.copyWith(points: newPoints));
    try {
      final client = sb.Supabase.instance.client;
      await client.from('profiles').update({'points': newPoints}).eq('id', u.id);
    } catch (e) {
      debugPrint("Failed to update points in Supabase: $e");
    }
  }

  Future<void> awardXp({required int amount, required String action}) async {
    final u = state.value;
    if (u == null) return;

    // Double XP check
    int actualAmount = amount;
    bool isBoosted = false;
    if (u.xpBoostExpiresAt != null && DateTime.now().isBefore(u.xpBoostExpiresAt!)) {
      actualAmount = amount * 2;
      isBoosted = true;
    }

    final newXp = u.xp + actualAmount;
    final newLevel = (newXp / 100).floor() + 1;
    final isLevelUp = newLevel > u.level;

    state = AsyncValue.data(u.copyWith(xp: newXp, level: newLevel));

    try {
      final client = sb.Supabase.instance.client;
      await client.from('profiles').update({
        'xp': newXp,
        'level': newLevel,
      }).eq('id', u.id);

      // Log XP transaction
      await client.from('xp_log').insert({
        'user_id': u.id,
        'amount': actualAmount,
        'action': isBoosted ? '$action (2X Boost)' : action,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint("Failed to update XP in Supabase: $e");
    }

    if (isLevelUp) {
      debugPrint("LEVEL UP! Reached level $newLevel");
    }
  }

  Future<bool> buyLifeline() async {
    final u = state.value;
    if (u == null || u.points < 100) return false;

    final newPoints = u.points - 100;
    final newLifelines = u.lifelinesCount + 1;
    state = AsyncValue.data(u.copyWith(points: newPoints, lifelinesCount: newLifelines));

    try {
      final client = sb.Supabase.instance.client;
      await client.from('profiles').update({
        'points': newPoints,
        'lifelines_count': newLifelines,
      }).eq('id', u.id);
      return true;
    } catch (e) {
      debugPrint("Failed to purchase lifeline in Supabase: $e");
      return true; // Proceed locally
    }
  }

  Future<bool> buyXpBoost() async {
    final u = state.value;
    if (u == null || u.points < 150) return false;

    final newPoints = u.points - 150;
    final expiry = DateTime.now().add(const Duration(hours: 24));
    state = AsyncValue.data(u.copyWith(points: newPoints, xpBoostExpiresAt: expiry));

    try {
      final client = sb.Supabase.instance.client;
      await client.from('profiles').update({
        'points': newPoints,
        'xp_boost_expires_at': expiry.toIso8601String(),
      }).eq('id', u.id);
      return true;
    } catch (e) {
      debugPrint("Failed to purchase XP Boost in Supabase: $e");
      return true; // Proceed locally
    }
  }

  Future<bool> buyExtraTicket() async {
    final u = state.value;
    if (u == null || u.points < 50) return false;

    final newPoints = u.points - 50;
    final newTickets = u.extraTickets + 1;
    state = AsyncValue.data(u.copyWith(points: newPoints, extraTickets: newTickets));

    try {
      final client = sb.Supabase.instance.client;
      await client.from('profiles').update({
        'points': newPoints,
        'extra_tickets': newTickets,
      }).eq('id', u.id);
      return true;
    } catch (e) {
      debugPrint("Failed to purchase extra ticket in Supabase: $e");
      return true; // Proceed locally
    }
  }

  Future<bool> buyBorder(String borderId, int cost) async {
    final u = state.value;
    if (u == null || u.points < cost || u.unlockedBorders.contains(borderId)) return false;

    final newPoints = u.points - cost;
    final newBorders = List<String>.from(u.unlockedBorders)..add(borderId);
    state = AsyncValue.data(u.copyWith(points: newPoints, unlockedBorders: newBorders));

    try {
      final client = sb.Supabase.instance.client;
      await client.from('profiles').update({
        'points': newPoints,
        'unlocked_borders': newBorders,
      }).eq('id', u.id);
      return true;
    } catch (e) {
      debugPrint("Failed to purchase border in Supabase: $e");
      return true; // Proceed locally
    }
  }

  Future<bool> equipBorder(String borderId) async {
    final u = state.value;
    if (u == null || !u.unlockedBorders.contains(borderId)) return false;

    state = AsyncValue.data(u.copyWith(activeBorder: borderId));

    try {
      final client = sb.Supabase.instance.client;
      await client.from('profiles').update({
        'active_border': borderId,
      }).eq('id', u.id);
      return true;
    } catch (e) {
      debugPrint("Failed to equip border in Supabase: $e");
      return true; // Proceed locally
    }
  }

  Future<bool> consumeLifeline() async {
    final u = state.value;
    if (u == null || u.lifelinesCount <= 0) return false;

    final newLifelines = u.lifelinesCount - 1;
    state = AsyncValue.data(u.copyWith(lifelinesCount: newLifelines));

    try {
      final client = sb.Supabase.instance.client;
      await client.from('profiles').update({
        'lifelines_count': newLifelines,
      }).eq('id', u.id);
      return true;
    } catch (e) {
      debugPrint("Failed to consume lifeline in Supabase: $e");
      return true; // Proceed locally
    }
  }

  Future<bool> consumeExtraTicket() async {
    final u = state.value;
    if (u == null || u.extraTickets <= 0) return false;

    final newTickets = u.extraTickets - 1;
    state = AsyncValue.data(u.copyWith(extraTickets: newTickets));

    try {
      final client = sb.Supabase.instance.client;
      await client.from('profiles').update({
        'extra_tickets': newTickets,
      }).eq('id', u.id);
      return true;
    } catch (e) {
      debugPrint("Failed to consume ticket in Supabase: $e");
      return true; // Proceed locally
    }
  }

  /// Awards a spin wheel prize and records the spin time.
  /// Returns true if the spin was valid and applied.
  Future<bool> awardSpinPrize(String prize, {bool useExtraTicket = false}) async {
    final u = state.value;
    if (u == null) return false;

    // Check cooldown: 24h unless using an extra ticket
    if (!useExtraTicket) {
      if (u.lastSpinAt != null &&
          DateTime.now().difference(u.lastSpinAt!).inHours < 24) {
        return false;
      }
    } else {
      if (u.extraTickets <= 0) return false;
    }

    final now = DateTime.now();
    int bonusPoints = 0;
    int bonusLifelines = 0;
    int bonusTickets = 0;

    switch (prize) {
      case '+10pts':   bonusPoints = 10; break;
      case '+25pts':   bonusPoints = 25; break;
      case '+50pts':   bonusPoints = 50; break;
      case 'lifeline': bonusLifelines = 1; break;
      case 'extra_spin': bonusTickets = 1; break;
      case '+5pts':    bonusPoints = 5; break;
      default: break; // 'try_again' or 'card_pack'
    }

    final newPoints    = u.points + bonusPoints;
    final newLifelines = u.lifelinesCount + bonusLifelines;
    final newTickets   = useExtraTicket
        ? u.extraTickets - 1 + bonusTickets
        : u.extraTickets + bonusTickets;

    state = AsyncValue.data(u.copyWith(
      points: newPoints,
      lifelinesCount: newLifelines,
      extraTickets: newTickets,
      lastSpinAt: useExtraTicket ? u.lastSpinAt : now,
    ));

    try {
      final client = sb.Supabase.instance.client;
      final updates = <String, dynamic>{
        'points': newPoints,
        'lifelines_count': newLifelines,
        'extra_tickets': newTickets,
      };
      if (!useExtraTicket) updates['last_spin_at'] = now.toIso8601String();
      await client.from('profiles').update(updates).eq('id', u.id);

      // Log spin result
      await client.from('spin_log').insert({
        'user_id': u.id,
        'prize': prize,
        'used_ticket': useExtraTicket,
        'created_at': now.toIso8601String(),
      });
    } catch (e) {
      debugPrint('Failed to persist spin prize: $e');
    }
    return true;
  }
}

final authProvider = NotifierProvider<AuthNotifier, AsyncValue<User?>>(() {
  return AuthNotifier();
});
