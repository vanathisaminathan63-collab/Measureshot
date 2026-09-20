import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/history_controller.dart';
import '../models/measurement_response.dart';
import '../theme/app_theme.dart';
import 'measurement_detail_view.dart';

String _fmtTimestamp(String? raw) {
  if (raw == null || raw.isEmpty) return '-';
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  final local = parsed.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}

String _fmtNum(num value) {
  if (value == value.roundToDouble()) return value.round().toString();
  return value.toStringAsFixed(2);
}

class HistoryView extends StatefulWidget {
  const HistoryView({super.key});

  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> {
  Future<void> _openDetail(MeasurementItem item) async {
    if (item.id == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MeasurementDetailView(id: item.id!),
      ),
    );
    if (mounted) context.read<HistoryController>().load();
  }

  Future<bool> _confirmDelete(MeasurementItem item) async {
    final controller = context.read<HistoryController>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete measurement?'),
        content:
            Text('This will permanently delete measurement #${item.id}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return false;

    final deleted = await controller.delete(item.id!);
    if (!mounted) return false;
    if (deleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Measurement deleted.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            controller.deleteError ?? 'Unable to delete measurement.',
          ),
        ),
      );
    }
    return deleted;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          IconButton(
            onPressed: () => context.read<HistoryController>().load(),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final c = context.watch<HistoryController>();

    if (c.isLoading && c.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (c.error != null && c.items.isEmpty) {
      return _ErrorState(message: c.error!, onRetry: () => c.load());
    }

    if (c.items.isEmpty) {
      return const _EmptyState();
    }

    final totalSqft =
        c.items.fold<double>(0, (sum, item) => sum + item.sqft);

    return RefreshIndicator(
      onRefresh: c.load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _SummaryStrip(count: c.items.length, totalSqft: totalSqft),
          const SizedBox(height: 16),
          Text(
            '${c.items.length} ${c.items.length == 1 ? 'report' : 'reports'}',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < c.items.length; i++) ...[
            Dismissible(
              key: ValueKey(c.items[i].id),
              direction: DismissDirection.endToStart,
              confirmDismiss: (_) => _confirmDelete(c.items[i]),
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 22),
                decoration: BoxDecoration(
                  color: AppTheme.error,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.delete_outline_rounded,
                        color: Colors.white, size: 22),
                    SizedBox(width: 6),
                    Text(
                      'Delete',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              child: _MeasurementCard(
                item: c.items[i],
                onTap: () => _openDetail(c.items[i]),
              ),
            ),
            if (i < c.items.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  final int count;
  final double totalSqft;

  const _SummaryStrip({required this.count, required this.totalSqft});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Row(
          children: [
            Expanded(
              child: _StatBlock(
                icon: Icons.description_outlined,
                value: '$count',
                label: count == 1 ? 'Report' : 'Reports',
              ),
            ),
            const SizedBox(
              height: 34,
              child: VerticalDivider(
                width: 1,
                thickness: 1,
                color: AppTheme.divider,
              ),
            ),
            Expanded(
              child: _StatBlock(
                icon: Icons.square_foot_rounded,
                value: _fmtNum(totalSqft),
                label: 'Total sq. ft',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatBlock({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppTheme.primary),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _MeasurementCard extends StatelessWidget {
  final MeasurementItem item;
  final VoidCallback onTap;

  const _MeasurementCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final id = item.id?.toString() ?? '-';

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primarySoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '#$id',
                      style: const TextStyle(
                        color: AppTheme.primaryDark,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_fmtNum(item.sqft)} sq.ft',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(color: AppTheme.divider),
              const SizedBox(height: 10),
              _row(Icons.straighten_rounded,
                  '${_fmtNum(item.width)} × ${_fmtNum(item.height)} in'),
              const SizedBox(height: 8),
              _row(Icons.schedule_rounded, _fmtTimestamp(item.timestamp)),
              const SizedBox(height: 8),
              _row(
                Icons.place_outlined,
                '${item.latitude.toStringAsFixed(4)}, '
                    '${item.longitude.toStringAsFixed(4)}',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(IconData icon, String text) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: AppTheme.textSecondary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 13.5)),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppTheme.primarySoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.history_rounded,
                size: 42,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No measurements yet',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Submit a report from the Home tab and it will\n'
              'appear here.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cloud_off_outlined,
                size: 36,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}