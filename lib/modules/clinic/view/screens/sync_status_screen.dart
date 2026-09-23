import 'package:flutter/material.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../../core/theme/app_colors.dart';

class SyncStatusScreen extends StatefulWidget {
  const SyncStatusScreen({super.key});

  @override
  State<SyncStatusScreen> createState() => _SyncStatusScreenState();
}

class _SyncStatusScreenState extends State<SyncStatusScreen> {
  bool _isLoading = true;
  bool _isSyncing = false;
  bool _isRetrying = false;

  int _pendingCount = 0;
  int _failedCount = 0;
  int _successCount = 0;
  List<Map<String, dynamic>> _logs = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final pending = await DatabaseHelper.instance.getPendingSyncQueueCount();
      final failed = await DatabaseHelper.instance.getFailedSyncQueueCount();
      final success = await DatabaseHelper.instance.getSuccessfulSyncLogsCount();
      final logs = await DatabaseHelper.instance.getRecentSyncLogs(limit: 50);

      if (!mounted) return;
      setState(() {
        _pendingCount = pending;
        _failedCount = failed;
        _successCount = success;
        _logs = logs;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _syncNow() async {
    if (_isSyncing || _isRetrying) return;
    setState(() => _isSyncing = true);

    try {
      await SyncService.instance.syncAll();
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
        await _loadData();
      }
    }
  }

  Future<void> _retryFailed() async {
    if (_isSyncing || _isRetrying) return;
    setState(() => _isRetrying = true);

    try {
      await DatabaseHelper.instance.retryFailedSyncQueueItems();
      await SyncService.instance.syncAll();
    } finally {
      if (mounted) {
        setState(() => _isRetrying = false);
        await _loadData();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('حالة المزامنة السحابية (Cloud Sync Monitor)'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث البيانات',
            onPressed: _isLoading ? null : _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBreadcrumbs(),
                  const SizedBox(height: 16),
                  _buildKpiCards(context),
                  const SizedBox(height: 20),
                  _buildActionButtons(),
                  const SizedBox(height: 24),
                  _buildLogsSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildBreadcrumbs() {
    return Row(
      children: [
        const Icon(Icons.home_outlined, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        const Text(
          'الرئيسية',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Text('/', style: TextStyle(color: AppColors.textLight)),
        ),
        const Text(
          'حالة المزامنة',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCards(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    final cards = [
      _buildStatusCard(),
      _buildKpiCard(
        title: 'في الانتظار (Pending)',
        value: '$_pendingCount',
        icon: Icons.hourglass_top_rounded,
        color: Colors.orange.shade700,
      ),
      _buildKpiCard(
        title: 'الفاشلة (Failed)',
        value: '$_failedCount',
        icon: Icons.warning_amber_rounded,
        color: AppColors.error,
      ),
      _buildKpiCard(
        title: 'العمليات الناجحة',
        value: '$_successCount',
        icon: Icons.check_circle_outline_rounded,
        color: AppColors.success,
      ),
    ];

    if (isDesktop) {
      return Row(
        children: cards
            .map((card) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: card,
                  ),
                ))
            .toList(),
      );
    }

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: cards,
    );
  }

  Widget _buildStatusCard() {
    return ValueListenableBuilder<SyncStatus>(
      valueListenable: SyncService.instance.statusNotifier,
      builder: (context, status, _) {
        String statusText;
        Color color;
        IconData icon;

        switch (status) {
          case SyncStatus.connected:
            statusText = 'متصل ومنتظم';
            color = AppColors.success;
            icon = Icons.cloud_done_rounded;
            break;
          case SyncStatus.syncing:
            statusText = 'جاري المزامنة...';
            color = Colors.amber.shade800;
            icon = Icons.cloud_sync_rounded;
            break;
          case SyncStatus.offline:
            statusText = 'غير متصل (Offline)';
            color = Colors.grey.shade600;
            icon = Icons.cloud_off_rounded;
            break;
          case SyncStatus.error:
            statusText = 'خطأ في المزامنة';
            color = AppColors.error;
            icon = Icons.cloud_off_rounded;
            break;
        }

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'حالة الاتصال السحابي',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        ElevatedButton.icon(
          onPressed: (_isSyncing || _isRetrying) ? null : _syncNow,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          icon: _isSyncing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.sync_rounded, size: 20),
          label: Text(_isSyncing ? 'جاري المزامنة...' : 'مزامنة الآن'),
        ),
        OutlinedButton.icon(
          onPressed: (_isSyncing || _isRetrying || _failedCount == 0) ? null : _retryFailed,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.error,
            side: const BorderSide(color: AppColors.error),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          icon: _isRetrying
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.error,
                  ),
                )
              : const Icon(Icons.replay_rounded, size: 20),
          label: Text(_isRetrying ? 'جاري إعادة المحاولة...' : 'إعادة المحاولة للفاشلة'),
        ),
      ],
    );
  }

  Widget _buildLogsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'سجلات المزامنة الأخيرة (Recent Sync Logs)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'عرض آخر ${_logs.length} سجل',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: _logs.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(
                    child: Text(
                      'لا توجد سجلات مزامنة حالياً',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 24,
                    headingRowHeight: 44,
                    dataRowMinHeight: 40,
                    dataRowMaxHeight: 52,
                    columns: const [
                      DataColumn(label: Text('الوقت', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('الجدول', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('العملية', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('الحالة', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('التفاصيل', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: _logs.map((log) {
                      final status = log['status'] as String? ?? '';
                      final isSuccess = status == 'success';
                      final timeStr = log['sync_time'] as String? ?? '';
                      final formattedTime = timeStr.contains('T')
                          ? timeStr.split('T').last.split('.').first
                          : timeStr;

                      return DataRow(cells: [
                        DataCell(Text(formattedTime, style: const TextStyle(fontSize: 12))),
                        DataCell(Text(log['table_name'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              log['operation'] ?? '',
                              style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: (isSuccess ? AppColors.success : AppColors.error).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isSuccess ? 'نجاح' : 'فشل',
                              style: TextStyle(
                                fontSize: 11,
                                color: isSuccess ? AppColors.success : AppColors.error,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            log['details'] ?? '',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ]);
                    }).toList(),
                  ),
                ),
        ),
      ],
    );
  }
}
