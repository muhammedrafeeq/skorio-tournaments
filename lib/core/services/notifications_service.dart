import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Handling background message: ${message.messageId}");
}

class NotificationsService {
  NotificationsService._privateConstructor();
  static final NotificationsService instance = NotificationsService._privateConstructor();

  bool _isFirebaseInitialized = false;
  String? _fcmToken;

  bool get isFirebaseInitialized => _isFirebaseInitialized;
  String? get fcmToken => _fcmToken;

  Future<void> initFCM() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _isFirebaseInitialized = true;

      final messaging = FirebaseMessaging.instance;

      // Request permission
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('User granted notification permission');
        
        // Get token
        _fcmToken = await messaging.getToken();
        debugPrint('FCM Token: $_fcmToken');

        // Setup background handler
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

        // Setup foreground listening
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          debugPrint('Got a message in the foreground!');
          debugPrint('Message data: ${message.data}');

          if (message.notification != null) {
            debugPrint('Message also contained a notification: ${message.notification?.title}');
          }
        });
      } else {
        debugPrint('User declined or has not accepted notification permission');
      }
    } catch (e) {
      debugPrint('Firebase messaging initialization failed: $e');
      _isFirebaseInitialized = false;
    }
  }

  /// Load notification preferences for a user from Supabase.
  /// If it does not exist, returns default preferences.
  Future<NotificationPrefs> loadPreferences(String userId) async {
    try {
      final client = sb.Supabase.instance.client;
      final response = await client
          .from('notification_preferences')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null) {
        return NotificationPrefs.fromJson(response);
      }
    } catch (e) {
      debugPrint('Failed to load notification preferences: $e');
    }
    return NotificationPrefs();
  }

  /// Save notification preferences to Supabase.
  Future<bool> savePreferences(String userId, NotificationPrefs prefs) async {
    try {
      final client = sb.Supabase.instance.client;
      final data = prefs.toJson();
      data['user_id'] = userId;
      data['updated_at'] = DateTime.now().toIso8601String();

      // If token is available from FCM but not in preferences, add it
      if (_fcmToken != null && data['fcm_token'] == null) {
        data['fcm_token'] = _fcmToken;
      }

      await client.from('notification_preferences').upsert(data);
      return true;
    } catch (e) {
      debugPrint('Failed to save notification preferences: $e');
      return false;
    }
  }

  /// Updates only the FCM token in Supabase.
  Future<void> updateTokenInSupabase(String userId) async {
    if (_fcmToken == null) return;
    try {
      final client = sb.Supabase.instance.client;
      await client.from('notification_preferences').upsert({
        'user_id': userId,
        'fcm_token': _fcmToken,
        'updated_at': DateTime.now().toIso8601String(),
      });
      debugPrint('FCM token updated in Supabase');
    } catch (e) {
      debugPrint('Failed to update FCM token in Supabase: $e');
    }
  }
}

class NotificationPrefs {
  final bool deadlineReminder;
  final bool resultPublished;
  final bool dailySpinReady;
  final bool leaderboardMoved;
  final bool reEngagement;
  final String? fcmToken;

  NotificationPrefs({
    this.deadlineReminder = true,
    this.resultPublished = true,
    this.dailySpinReady = true,
    this.leaderboardMoved = true,
    this.reEngagement = false,
    this.fcmToken,
  });

  factory NotificationPrefs.fromJson(Map<String, dynamic> json) {
    return NotificationPrefs(
      deadlineReminder: json['deadline_reminder'] ?? true,
      resultPublished: json['result_published'] ?? true,
      dailySpinReady: json['daily_spin_ready'] ?? true,
      leaderboardMoved: json['leaderboard_moved'] ?? true,
      reEngagement: json['re_engagement'] ?? false,
      fcmToken: json['fcm_token'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deadline_reminder': deadlineReminder,
      'result_published': resultPublished,
      'daily_spin_ready': dailySpinReady,
      'leaderboard_moved': leaderboardMoved,
      're_engagement': reEngagement,
      'fcm_token': fcmToken,
    };
  }

  NotificationPrefs copyWith({
    bool? deadlineReminder,
    bool? resultPublished,
    bool? dailySpinReady,
    bool? leaderboardMoved,
    bool? reEngagement,
    String? fcmToken,
  }) {
    return NotificationPrefs(
      deadlineReminder: deadlineReminder ?? this.deadlineReminder,
      resultPublished: resultPublished ?? this.resultPublished,
      dailySpinReady: dailySpinReady ?? this.dailySpinReady,
      leaderboardMoved: leaderboardMoved ?? this.leaderboardMoved,
      reEngagement: reEngagement ?? this.reEngagement,
      fcmToken: fcmToken ?? this.fcmToken,
    );
  }
}
