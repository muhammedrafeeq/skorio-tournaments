import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

// ─── Model ────────────────────────────────────────────────────────────────────

enum MatchEventType { goal, yellowCard, redCard, substitution, kickoff, fullTime }

extension MatchEventTypeX on MatchEventType {
  String get label {
    switch (this) {
      case MatchEventType.goal:         return 'Goal';
      case MatchEventType.yellowCard:   return 'Yellow Card';
      case MatchEventType.redCard:      return 'Red Card';
      case MatchEventType.substitution: return 'Substitution';
      case MatchEventType.kickoff:      return 'Kick Off';
      case MatchEventType.fullTime:     return 'Full Time';
    }
  }

  String get emoji {
    switch (this) {
      case MatchEventType.goal:         return '⚽';
      case MatchEventType.yellowCard:   return '🟨';
      case MatchEventType.redCard:      return '🟥';
      case MatchEventType.substitution: return '🔄';
      case MatchEventType.kickoff:      return '🏁';
      case MatchEventType.fullTime:     return '🔔';
    }
  }

  String get value {
    switch (this) {
      case MatchEventType.goal:         return 'goal';
      case MatchEventType.yellowCard:   return 'yellow_card';
      case MatchEventType.redCard:      return 'red_card';
      case MatchEventType.substitution: return 'substitution';
      case MatchEventType.kickoff:      return 'kickoff';
      case MatchEventType.fullTime:     return 'full_time';
    }
  }

  static MatchEventType fromValue(String v) {
    switch (v) {
      case 'goal':         return MatchEventType.goal;
      case 'yellow_card':  return MatchEventType.yellowCard;
      case 'red_card':     return MatchEventType.redCard;
      case 'substitution': return MatchEventType.substitution;
      case 'kickoff':      return MatchEventType.kickoff;
      case 'full_time':    return MatchEventType.fullTime;
      default:             return MatchEventType.goal;
    }
  }
}

class MatchEvent {
  final String id;
  final String matchId;
  final String tournamentId;
  final MatchEventType type;
  final int minute;
  final String playerName;
  final String teamId;
  final String? assistPlayerName;
  final String? subOutPlayerName;
  final DateTime createdAt;

  const MatchEvent({
    required this.id,
    required this.matchId,
    required this.tournamentId,
    required this.type,
    required this.minute,
    required this.playerName,
    required this.teamId,
    this.assistPlayerName,
    this.subOutPlayerName,
    required this.createdAt,
  });

  factory MatchEvent.fromJson(Map<String, dynamic> json) {
    return MatchEvent(
      id: json['id']?.toString() ?? '',
      matchId: json['match_id']?.toString() ?? '',
      tournamentId: json['tournament_id']?.toString() ?? '',
      type: MatchEventTypeX.fromValue(json['event_type'] ?? 'goal'),
      minute: json['minute'] ?? 0,
      playerName: json['player_name'] ?? '',
      teamId: json['team_id']?.toString() ?? '',
      assistPlayerName: json['assist_player_name'],
      subOutPlayerName: json['sub_out_player_name'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'match_id': matchId,
      'tournament_id': tournamentId,
      'event_type': type.value,
      'minute': minute,
      'player_name': playerName,
      'team_id': teamId,
      if (assistPlayerName != null) 'assist_player_name': assistPlayerName,
      if (subOutPlayerName != null) 'sub_out_player_name': subOutPlayerName,
    };
  }
}

// ─── State ────────────────────────────────────────────────────────────────────

class MatchEventsState {
  final List<MatchEvent> events;
  final bool isLoading;
  final String? error;
  final String? watchingMatchId;

  const MatchEventsState({
    this.events = const [],
    this.isLoading = false,
    this.error,
    this.watchingMatchId,
  });

  MatchEventsState copyWith({
    List<MatchEvent>? events,
    bool? isLoading,
    String? error,
    String? watchingMatchId,
  }) {
    return MatchEventsState(
      events: events ?? this.events,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      watchingMatchId: watchingMatchId ?? this.watchingMatchId,
    );
  }
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class MatchEventsNotifier extends Notifier<MatchEventsState> {
  sb.RealtimeChannel? _channel;

  @override
  MatchEventsState build() => const MatchEventsState();

  Future<void> watchMatch(String matchId) async {
    // Unsubscribe from previous match if switching
    await _channel?.unsubscribe();
    _channel = null;

    state = MatchEventsState(isLoading: true, watchingMatchId: matchId);
    await _loadEvents(matchId);
    _subscribeRealtime(matchId);
  }

  Future<void> _loadEvents(String matchId) async {
    try {
      final client = sb.Supabase.instance.client;
      final response = await client
          .from('match_events')
          .select()
          .eq('match_id', matchId)
          .order('minute', ascending: true);

      final events = (response as List).map((e) => MatchEvent.fromJson(e)).toList();
      state = state.copyWith(events: events, isLoading: false);
    } catch (e) {
      debugPrint('Failed to load match events: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  void _subscribeRealtime(String matchId) {
    final client = sb.Supabase.instance.client;
    _channel = client
        .channel('match_events:$matchId')
        .onPostgresChanges(
          event: sb.PostgresChangeEvent.insert,
          schema: 'public',
          table: 'match_events',
          filter: sb.PostgresChangeFilter(
            type: sb.PostgresChangeFilterType.eq,
            column: 'match_id',
            value: matchId,
          ),
          callback: (payload) {
            final newEvent = MatchEvent.fromJson(payload.newRecord);
            state = state.copyWith(events: [...state.events, newEvent]);
          },
        )
        .subscribe();
  }

  Future<bool> addEvent(MatchEvent event) async {
    try {
      final client = sb.Supabase.instance.client;
      await client.from('match_events').insert(event.toJson());
      return true;
    } catch (e) {
      debugPrint('Failed to add match event: $e');
      // Optimistic local insert
      final localEvent = MatchEvent(
        id: 'local_${DateTime.now().millisecondsSinceEpoch}',
        matchId: event.matchId,
        tournamentId: event.tournamentId,
        type: event.type,
        minute: event.minute,
        playerName: event.playerName,
        teamId: event.teamId,
        assistPlayerName: event.assistPlayerName,
        subOutPlayerName: event.subOutPlayerName,
        createdAt: DateTime.now(),
      );
      state = state.copyWith(events: [...state.events, localEvent]);
      return true;
    }
  }

  Future<void> stopWatching() async {
    await _channel?.unsubscribe();
    _channel = null;
    state = const MatchEventsState();
  }
}

final matchEventsProvider =
    NotifierProvider<MatchEventsNotifier, MatchEventsState>(
  MatchEventsNotifier.new,
);
