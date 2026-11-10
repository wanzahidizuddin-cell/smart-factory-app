import 'package:flutter_riverpod/flutter_riverpod.dart';

class SyncStatusState {
  const SyncStatusState({
    this.isOffline = false,
    this.pendingRecords = 0,
    this.isSyncing = false,
    this.errorMessage,
  });

  final bool isOffline;
  final int pendingRecords;
  final bool isSyncing;
  final String? errorMessage;

  SyncStatusState copyWith({
    bool? isOffline,
    int? pendingRecords,
    bool? isSyncing,
    String? errorMessage,
    bool clearError = false,
  }) =>
      SyncStatusState(
        isOffline: isOffline ?? this.isOffline,
        pendingRecords: pendingRecords ?? this.pendingRecords,
        isSyncing: isSyncing ?? this.isSyncing,
        errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      );
}

class SyncStatusController extends StateNotifier<SyncStatusState> {
  SyncStatusController() : super(const SyncStatusState());

  bool _networkOffline = false;
  bool _simulateOffline = false;
  Future<void> Function()? _syncHandler;

  void setOffline(bool value) {
    _simulateOffline = value;
    state = state.copyWith(isOffline: _networkOffline || _simulateOffline);
    if (!state.isOffline) {
      _requestSync();
    }
  }

  void setConnectivityOffline(bool value) {
    _networkOffline = value;
    state = state.copyWith(isOffline: _networkOffline || _simulateOffline);
  }

  void setSyncHandler(Future<void> Function() handler) {
    _syncHandler = handler;
  }

  void update({
    int? pendingRecords,
    bool? isSyncing,
    String? errorMessage,
    bool? clearError,
  }) {
    state = state.copyWith(
      pendingRecords: pendingRecords,
      isSyncing: isSyncing,
      errorMessage: errorMessage,
      clearError: clearError ?? false,
    );
  }

  Future<void> sync() async {
    final handler = _syncHandler;
    if (handler == null) {
      throw StateError('The background sync service is not initialized.');
    }
    await handler();
  }

  void _requestSync() {
    final handler = _syncHandler;
    if (handler != null) {
      handler().catchError((Object error) {
        update(errorMessage: error.toString());
      });
    }
  }
}

final syncStatusProvider =
    StateNotifierProvider<SyncStatusController, SyncStatusState>(
  (ref) => SyncStatusController(),
);
