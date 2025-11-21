/*
 * privacyIDEA Authenticator
 *
 * Authors: Adam Burdett <adam.burdett@netknights.it>
 *
 * Copyright (c) 2025 NetKnights GmbH
 *
 * Licensed under the Apache License, Version 2.0 (the 'License');
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an 'AS IS' BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/// Sync status dashboard widget for monitoring background synchronization
///
/// This widget provides:
/// - Real-time sync status visualization
/// - Credential-specific sync information
/// - Performance metrics and history
/// - Interactive sync management controls
/// - Battery and network usage insights

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/background_sync_service.dart';
import '../utils/logger.dart';

/// Sync status dashboard widget
class SyncStatusDashboard extends ConsumerStatefulWidget {
  final bool showDetailedView;
  final bool enableInteractiveControls;

  const SyncStatusDashboard({
    super.key,
    this.showDetailedView = false,
    this.enableInteractiveControls = true,
  });

  @override
  ConsumerState<SyncStatusDashboard> createState() =>
      _SyncStatusDashboardState();
}

class _SyncStatusDashboardState extends ConsumerState<SyncStatusDashboard>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _syncAnimationController;
  late AnimationController _fadeController;
  late Animation<double> _syncRotation;
  late Animation<double> _fadeAnimation;

  // Stream subscriptions
  StreamSubscription<CredentialSyncInfo>? _syncStatusSubscription;
  StreamSubscription<SyncResult>? _syncResultSubscription;

  // Local state
  Map<String, CredentialSyncInfo> _syncStatusMap = {};
  List<SyncResult> _syncHistory = [];
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _subscribeToSyncUpdates();
  }

  void _initializeAnimations() {
    _syncAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _syncRotation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _syncAnimationController, curve: Curves.linear),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
  }

  void _subscribeToSyncUpdates() {
    final syncService = ref.read(backgroundSyncServiceProvider);

    _syncStatusSubscription = syncService.syncStatusStream.listen((syncInfo) {
      setState(() {
        _syncStatusMap[syncInfo.credentialId] = syncInfo;
      });
    });

    _syncResultSubscription = syncService.syncResultStream.listen((result) {
      setState(() {
        _syncHistory.insert(0, result);
        if (_syncHistory.length > 10) {
          _syncHistory.removeLast();
        }
      });
    });

    // Load initial state
    _loadInitialState();
  }

  Future<void> _loadInitialState() async {
    final syncService = ref.read(backgroundSyncServiceProvider);
    setState(() {
      _syncStatusMap = Map.from(syncService.syncStatus);
      _syncHistory = List.from(syncService.syncHistory.take(10));
    });
  }

  @override
  void dispose() {
    _syncAnimationController.dispose();
    _fadeController.dispose();
    _syncStatusSubscription?.cancel();
    _syncResultSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final syncService = ref.watch(backgroundSyncServiceProvider);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Card(
        margin: const EdgeInsets.all(16),
        child: widget.showDetailedView
            ? _buildDetailedView(syncService)
            : _buildCompactView(syncService),
      ),
    );
  }

  Widget _buildCompactView(BackgroundSyncService syncService) {
    final isActive = syncService.isSyncActive;
    final upToDateCount = _getUpToDateCount();
    final totalCredentials = _syncStatusMap.length;
    final lastSyncTime = _getLastSyncTime();

    if (isActive) {
      _syncAnimationController.repeat();
    } else {
      _syncAnimationController.stop();
    }

    return ListTile(
      leading: AnimatedBuilder(
        animation: _syncRotation,
        builder: (context, child) {
          return Transform.rotate(
            angle: isActive ? _syncRotation.value * 2 * 3.14159 : 0,
            child: Icon(
              isActive ? Icons.sync : Icons.sync_alt,
              color: _getSyncStatusColor(),
              size: 28,
            ),
          );
        },
      ),
      title: Text(
        isActive ? 'Syncing...' : 'Background Sync',
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$upToDateCount of $totalCredentials credentials up-to-date',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (lastSyncTime != null)
            Text(
              'Last sync: ${_formatRelativeTime(lastSyncTime)}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
        ],
      ),
      trailing: widget.enableInteractiveControls
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSyncButton(syncService),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                  ),
                  onPressed: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                ),
              ],
            )
          : null,
    );
  }

  Widget _buildDetailedView(BackgroundSyncService syncService) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(syncService),
          const SizedBox(height: 16),
          _buildSyncOverview(),
          const SizedBox(height: 16),
          _buildCredentialsList(),
          if (_syncHistory.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildSyncHistory(),
          ],
          if (widget.enableInteractiveControls) ...[
            const SizedBox(height: 16),
            _buildControls(syncService),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(BackgroundSyncService syncService) {
    final isActive = syncService.isSyncActive;

    return Row(
      children: [
        AnimatedBuilder(
          animation: _syncRotation,
          builder: (context, child) {
            return Transform.rotate(
              angle: isActive ? _syncRotation.value * 2 * 3.14159 : 0,
              child: Icon(Icons.sync, color: _getSyncStatusColor(), size: 32),
            );
          },
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Background Synchronization',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                isActive ? 'Sync in progress...' : 'Monitoring credentials',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: _getSyncStatusColor()),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSyncOverview() {
    final statusCounts = _getStatusCounts();
    final totalCredentials = _syncStatusMap.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sync Overview',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                '$totalCredentials total',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatusIndicator(
                  'Up-to-date',
                  statusCounts[CredentialSyncStatus.upToDate] ?? 0,
                  Colors.green,
                  Icons.check_circle,
                ),
              ),
              Expanded(
                child: _buildStatusIndicator(
                  'Updating',
                  statusCounts[CredentialSyncStatus.updating] ?? 0,
                  Colors.blue,
                  Icons.sync,
                ),
              ),
              Expanded(
                child: _buildStatusIndicator(
                  'Needs Update',
                  statusCounts[CredentialSyncStatus.needsUpdate] ?? 0,
                  Colors.orange,
                  Icons.warning,
                ),
              ),
              Expanded(
                child: _buildStatusIndicator(
                  'Revoked',
                  statusCounts[CredentialSyncStatus.revoked] ?? 0,
                  Colors.red,
                  Icons.block,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(
    String label,
    int count,
    Color color,
    IconData icon,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildCredentialsList() {
    if (_syncStatusMap.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No credentials to sync',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    final sortedEntries = _syncStatusMap.entries.toList()
      ..sort(
        (a, b) => b.value.lastSyncAttempt.compareTo(a.value.lastSyncAttempt),
      );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Credential Status',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(maxHeight: 300),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: sortedEntries.length,
            itemBuilder: (context, index) {
              final entry = sortedEntries[index];
              return _buildCredentialSyncTile(entry.key, entry.value);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCredentialSyncTile(
    String credentialId,
    CredentialSyncInfo syncInfo,
  ) {
    return ListTile(
      dense: true,
      leading: Icon(
        _getStatusIcon(syncInfo.status),
        color: _getStatusColor(syncInfo.status),
        size: 20,
      ),
      title: Text(
        'Credential ${credentialId.substring(0, 8)}...',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _getStatusDescription(syncInfo.status),
            style: TextStyle(
              fontSize: 12,
              color: _getStatusColor(syncInfo.status),
            ),
          ),
          if (syncInfo.lastError != null)
            Text(
              'Error: ${syncInfo.lastError}',
              style: const TextStyle(fontSize: 11, color: Colors.red),
            ),
        ],
      ),
      trailing: Text(
        _formatRelativeTime(syncInfo.lastSyncAttempt),
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }

  Widget _buildSyncHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Sync Activity',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(maxHeight: 200),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _syncHistory.length,
            itemBuilder: (context, index) {
              final result = _syncHistory[index];
              return _buildSyncHistoryTile(result);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSyncHistoryTile(SyncResult result) {
    return ListTile(
      dense: true,
      leading: Icon(
        result.success ? Icons.check_circle : Icons.error,
        color: result.success ? Colors.green : Colors.red,
        size: 16,
      ),
      title: Text(
        result.success
            ? '${result.credentialsUpdated} credentials updated'
            : 'Sync failed',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      subtitle: result.revocationsDetected > 0
          ? Text(
              '${result.revocationsDetected} revocations detected',
              style: const TextStyle(fontSize: 11, color: Colors.red),
            )
          : null,
      trailing: Text(
        _formatRelativeTime(result.timestamp),
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }

  Widget _buildControls(BackgroundSyncService syncService) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: syncService.isSyncActive
                ? null
                : () => _performManualSync(syncService),
            icon: const Icon(Icons.sync),
            label: const Text('Sync Now'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _showSyncSettings(syncService),
            icon: const Icon(Icons.settings),
            label: const Text('Settings'),
          ),
        ),
      ],
    );
  }

  Widget _buildSyncButton(BackgroundSyncService syncService) {
    if (syncService.isSyncActive) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return IconButton(
      icon: const Icon(Icons.sync, size: 20),
      onPressed: () => _performManualSync(syncService),
      tooltip: 'Manual sync',
    );
  }

  Future<void> _performManualSync(BackgroundSyncService syncService) async {
    try {
      Logger.info('Performing manual sync', name: 'SyncStatusDashboard');
      await syncService.performSync(priority: SyncPriority.high);
    } catch (e) {
      Logger.error('Manual sync failed', error: e, name: 'SyncStatusDashboard');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showSyncSettings(BackgroundSyncService syncService) async {
    // Show sync configuration dialog
    showDialog(
      context: context,
      builder: (context) => _buildSyncSettingsDialog(syncService),
    );
  }

  Widget _buildSyncSettingsDialog(BackgroundSyncService syncService) {
    return AlertDialog(
      title: const Text('Sync Settings'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('Sync Strategy'),
            subtitle: Text(syncService.configuration.strategy.name),
            trailing: const Icon(Icons.arrow_forward_ios),
          ),
          ListTile(
            title: const Text('Auto Sync'),
            subtitle: Text(
              syncService.configuration.enableBackgroundSync
                  ? 'Enabled'
                  : 'Disabled',
            ),
            trailing: Switch(
              value: syncService.configuration.enableBackgroundSync,
              onChanged: (value) {
                // Update configuration
              },
            ),
          ),
          ListTile(
            title: const Text('WiFi Only'),
            subtitle: Text(
              syncService.configuration.wifiOnlySync ? 'Enabled' : 'Disabled',
            ),
            trailing: Switch(
              value: syncService.configuration.wifiOnlySync,
              onChanged: (value) {
                // Update configuration
              },
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  // Helper methods

  int _getUpToDateCount() {
    return _syncStatusMap.values
        .where((info) => info.status == CredentialSyncStatus.upToDate)
        .length;
  }

  DateTime? _getLastSyncTime() {
    if (_syncHistory.isEmpty) return null;
    return _syncHistory.first.timestamp;
  }

  Map<CredentialSyncStatus, int> _getStatusCounts() {
    final counts = <CredentialSyncStatus, int>{};
    for (final info in _syncStatusMap.values) {
      counts[info.status] = (counts[info.status] ?? 0) + 1;
    }
    return counts;
  }

  Color _getSyncStatusColor() {
    final syncService = ref.read(backgroundSyncServiceProvider);
    if (syncService.isSyncActive) return Colors.blue;

    final hasErrors = _syncStatusMap.values.any(
      (info) => info.failureCount > 0,
    );
    if (hasErrors) return Colors.orange;

    return Colors.green;
  }

  IconData _getStatusIcon(CredentialSyncStatus status) {
    switch (status) {
      case CredentialSyncStatus.upToDate:
        return Icons.check_circle;
      case CredentialSyncStatus.updating:
        return Icons.sync;
      case CredentialSyncStatus.needsUpdate:
        return Icons.warning;
      case CredentialSyncStatus.revoked:
        return Icons.block;
      case CredentialSyncStatus.expired:
        return Icons.schedule;
      case CredentialSyncStatus.invalid:
        return Icons.error;
      default:
        return Icons.help;
    }
  }

  Color _getStatusColor(CredentialSyncStatus status) {
    switch (status) {
      case CredentialSyncStatus.upToDate:
        return Colors.green;
      case CredentialSyncStatus.updating:
        return Colors.blue;
      case CredentialSyncStatus.needsUpdate:
        return Colors.orange;
      case CredentialSyncStatus.revoked:
        return Colors.red;
      case CredentialSyncStatus.expired:
        return Colors.red;
      case CredentialSyncStatus.invalid:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusDescription(CredentialSyncStatus status) {
    switch (status) {
      case CredentialSyncStatus.upToDate:
        return 'Up-to-date';
      case CredentialSyncStatus.updating:
        return 'Syncing...';
      case CredentialSyncStatus.needsUpdate:
        return 'Needs update';
      case CredentialSyncStatus.revoked:
        return 'Revoked';
      case CredentialSyncStatus.expired:
        return 'Expired';
      case CredentialSyncStatus.invalid:
        return 'Invalid';
      default:
        return 'Unknown';
    }
  }

  String _formatRelativeTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}
