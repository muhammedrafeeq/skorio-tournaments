import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

// ─── Pending Operation ────────────────────────────────────────────────────────

enum SyncOpType { insert, update, delete }

class SyncOperation {
  final String id;
  final SyncOpType type;
  final String table;
  final String recordId;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  int retryCount;

  SyncOperation({
    required this.id,
    required this.type,
    required this.table,
    required this.recordId,
    required this.data,
    required this.createdAt,
    this.retryCount = 0,
  });

  factory SyncOperation.fromJson(Map<String, dynamic> json) => SyncOperation(
        id: json['id'],
        type: SyncOpType.values.byName(json['type']),
        table: json['table'],
        recordId: json['record_id'],
        data: Map<String, dynamic>.from(json['data']),
        createdAt: DateTime.parse(json['created_at']),
        retryCount: json['retry_count'] ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'table': table,
        'record_id': recordId,
        'data': data,
        'created_at': createdAt.toIso8601String(),
        'retry_count': retryCount,
      };
}

// ─── State ────────────────────────────────────────────────────────────────────

class SyncState {
  final bool isOnline;
  final bool isSyncing;
  final List<SyncOperation> pendingOps;
  final DateTime? lastSyncAt;
  final String? lastError;

  const SyncState({
    this.isOnline = true,
    this.isSyncing = false,
    this.pendingOps = const [],
    this.lastSyncAt,
    this.lastError,
  });

  int get pendingCount => pendingOps.length;

  SyncState copyWith({
    bool? isOnline,
    bool? isSyncing,
    List<SyncOperation>? pendingOps,
    DateTime? lastSyncAt,
    String? lastError,
  }) => SyncState(
        isOnline: isOnline ?? this.isOnline,
        isSyncing: isSyncing ?? this.isSyncing,
        pendingOps: pendingOps ?? this.pendingOps,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
        lastError: lastError ?? this.lastError,
      );
}

// ─── Service ──────────────────────────────────────────────────────────────────

class OfflineSyncNotifier extends Notifier<SyncState> {
  static const _queueKey = 'skorio_sync_queue';
  StreamSubscription? _connectivitySub;

  @override
  SyncState build() {
    ref.onDispose(() => _connectivitySub?.cancel());
    Future.microtask(_init);
    return const SyncState();
  }

  Future<void> _init() async {
    final ops = await _loadQueue();
    state = state.copyWith(pendingOps: ops);
    _connectivitySub = Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);
    // Check current connectivity
    final result = await Connectivity().checkConnectivity();
    final online = !result.contains(ConnectivityResult.none);
    state = state.copyWith(isOnline: online);
    if (online && ops.isNotEmpty) _syncNow();
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final online = !results.contains(ConnectivityResult.none);
    state = state.copyWith(isOnline: online);
    if (online && state.pendingOps.isNotEmpty) _syncNow();
  }

  // ── Queue an operation (call instead of direct Supabase write when offline) ─

  Future<void> enqueue(SyncOperation op) async {
    final updated = [...state.pendingOps, op];
    state = state.copyWith(pendingOps: updated);
    await _saveQueue(updated);
    if (state.isOnline) _syncNow();
  }

  /// Convenience: queue a tournament upsert
  Future<void> queueTournamentUpdate(Map<String, dynamic> data) async {
    await enqueue(SyncOperation(
      id: 'sync_${DateTime.now().millisecondsSinceEpoch}',
      type: SyncOpType.update,
      table: 'tournaments',
      recordId: data['id']?.toString() ?? '',
      data: data,
      createdAt: DateTime.now(),
    ));
  }

  /// Convenience: queue a match event insert
  Future<void> queueMatchEventInsert(Map<String, dynamic> data) async {
    await enqueue(SyncOperation(
      id: 'sync_evt_${DateTime.now().millisecondsSinceEpoch}',
      type: SyncOpType.insert,
      table: 'match_events',
      recordId: '',
      data: data,
      createdAt: DateTime.now(),
    ));
  }

  // ── Sync ──────────────────────────────────────────────────────────────────

  Future<void> _syncNow() async {
    if (state.isSyncing || state.pendingOps.isEmpty) return;
    state = state.copyWith(isSyncing: true, lastError: null);

    final client = sb.Supabase.instance.client;
    final remaining = <SyncOperation>[];

    for (final op in state.pendingOps) {
      try {
        switch (op.type) {
          case SyncOpType.insert:
            await client.from(op.table).insert(op.data);
          case SyncOpType.update:
            await client.from(op.table).update(op.data).eq('id', op.recordId);
          case SyncOpType.delete:
            await client.from(op.table).delete().eq('id', op.recordId);
        }
      } catch (e) {
        debugPrint('Sync failed for ${op.id}: $e');
        op.retryCount++;
        if (op.retryCount < 5) remaining.add(op); // drop after 5 retries
      }
    }

    state = state.copyWith(
      isSyncing: false,
      pendingOps: remaining,
      lastSyncAt: DateTime.now(),
    );
    await _saveQueue(remaining);
  }

  Future<void> manualSync() => _syncNow();

  // ── Persistence ──────────────────────────────────────────────────────────

  Future<List<SyncOperation>> _loadQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_queueKey);
      if (raw == null) return [];
      final list = jsonDecode(raw) as List;
      return list.map((e) => SyncOperation.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> _saveQueue(List<SyncOperation> ops) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_queueKey, jsonEncode(ops.map((o) => o.toJson()).toList()));
    } catch (e) {
      debugPrint('Failed to persist sync queue: $e');
    }
  }
}

final offlineSyncProvider = NotifierProvider<OfflineSyncNotifier, SyncState>(
  OfflineSyncNotifier.new,
);
