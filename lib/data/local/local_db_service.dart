import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class SyncQueueEntry {
  const SyncQueueEntry({
    required this.id,
    required this.actionType,
    required this.payload,
    required this.status,
    required this.attemptCount,
  });

  final String id;
  final String actionType;
  final Map<String, dynamic> payload;
  final String status;
  final int attemptCount;
}

class LocalDbService {
  LocalDbService._(this._database);

  static Future<LocalDbService>? _instanceFuture;
  static final _random = Random.secure();

  final _LocalDatabase _database;

  static Future<LocalDbService> open() async {
    final existing = _instanceFuture;
    if (existing != null) return existing;

    final opening = _create();
    _instanceFuture = opening;
    try {
      return await opening;
    } catch (_) {
      _instanceFuture = null;
      rethrow;
    }
  }

  static Future<LocalDbService> _create() async {
    final directory = await getApplicationSupportDirectory();
    final file = File(p.join(directory.path, 'smart_factory_qc.sqlite'));
    return LocalDbService._(_LocalDatabase(file));
  }

  Future<String> enqueueAction({
    required String actionType,
    required Map<String, dynamic> payload,
  }) async {
    final id =
        '${DateTime.now().toUtc().microsecondsSinceEpoch}-${_random.nextInt(1 << 32)}';
    await _database.customStatement(
      'INSERT INTO sync_queue '
      '(id, action_type, payload, status, created_at) '
      'VALUES (?, ?, ?, ?, ?)',
      [
        id,
        actionType,
        jsonEncode(payload),
        'queued',
        DateTime.now().toUtc().toIso8601String(),
      ],
    );
    return id;
  }

  Future<List<SyncQueueEntry>> pendingActions() async {
    final rows = await _database
        .customSelect(
          "SELECT id, action_type, payload, status, attempt_count "
          "FROM sync_queue WHERE status IN ('queued', 'failed') "
          'ORDER BY created_at ASC',
        )
        .get();
    return rows.map((row) {
      final values = row.data;
      return SyncQueueEntry(
        id: values['id'] as String,
        actionType: values['action_type'] as String,
        payload:
            jsonDecode(values['payload'] as String) as Map<String, dynamic>,
        status: values['status'] as String,
        attemptCount: values['attempt_count'] as int,
      );
    }).toList(growable: false);
  }

  Future<int> pendingActionCount() async {
    final row = await _database
        .customSelect(
          "SELECT COUNT(*) AS count FROM sync_queue "
          "WHERE status IN ('queued', 'failed', 'syncing')",
        )
        .getSingle();
    return row.data['count'] as int;
  }

  Future<void> markSyncing(String id) async {
    await _database.customStatement(
      "UPDATE sync_queue SET status = 'syncing', attempt_count = attempt_count + 1, "
      'last_error = NULL WHERE id = ?',
      [id],
    );
  }

  Future<void> markFailed(String id, Object error) async {
    await _database.customStatement(
      "UPDATE sync_queue SET status = 'failed', last_error = ? WHERE id = ?",
      [error.toString(), id],
    );
  }

  Future<void> removeAction(String id) async {
    await _database
        .customStatement('DELETE FROM sync_queue WHERE id = ?', [id]);
  }

  Future<void> recoverInterruptedActions() async {
    await _database.customStatement(
      "UPDATE sync_queue SET status = 'queued' WHERE status = 'syncing'",
    );
  }

  Future<void> saveCache(String key, Object payload) async {
    await _database.customStatement(
      'INSERT INTO data_cache (cache_key, payload, updated_at) VALUES (?, ?, ?) '
      'ON CONFLICT(cache_key) DO UPDATE SET '
      'payload = excluded.payload, updated_at = excluded.updated_at',
      [
        key,
        jsonEncode(payload),
        DateTime.now().toUtc().toIso8601String(),
      ],
    );
  }

  Future<Object?> readCache(String key) async {
    final row = await _database.customSelect(
      'SELECT payload FROM data_cache WHERE cache_key = ?',
      variables: [Variable.withString(key)],
    ).getSingleOrNull();
    if (row == null) return null;
    return jsonDecode(row.data['payload'] as String);
  }
}

class _LocalDatabase extends GeneratedDatabase {
  _LocalDatabase(File file) : super(NativeDatabase.createInBackground(file));

  @override
  int get schemaVersion => 1;

  @override
  Iterable<TableInfo> get allTables => const [];

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (migrator) async {
          await customStatement('''
            CREATE TABLE sync_queue (
              id TEXT PRIMARY KEY NOT NULL,
              action_type TEXT NOT NULL,
              payload TEXT NOT NULL,
              status TEXT NOT NULL CHECK (status IN ('queued', 'syncing', 'failed')),
              created_at TEXT NOT NULL,
              attempt_count INTEGER NOT NULL DEFAULT 0,
              last_error TEXT
            )
          ''');
          await customStatement('''
            CREATE INDEX sync_queue_status_created_at_idx
            ON sync_queue (status, created_at)
          ''');
          await customStatement('''
            CREATE TABLE data_cache (
              cache_key TEXT PRIMARY KEY NOT NULL,
              payload TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
        },
      );
}
