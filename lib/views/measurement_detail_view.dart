import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/history_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/section_card.dart';

String _fmtTimestamp(String? raw) {
  if (raw == null || raw.isEmpty) return '-';
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  final local = parsed.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} '
      '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
}

String _fmtNum(num value) {
  if (value == value.roundToDouble()) return value.round().toString();
  return value.toStringAsFixed(2);
}

class MeasurementDetailView extends StatefulWidget {
  final int id;

  const MeasurementDetailView({super.key, required this.id});

  @override
  State<MeasurementDetailView> createState() => _MeasurementDetailViewState();
}

class _MeasurementDetailViewState extends State<MeasurementDetailView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HistoryController>().loadDetail(widget.id);
    });
  }

  Future<void> _confirmDelete() async {
    final c = context.read<HistoryController>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete measurement?'),
        content: Text('This will permanently delete measurement #${widget.id}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final ok = await c.delete(widget.id);
    if (!mounted) return;
    if (ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Measurement deleted.')),
      );
      navigator.pop();
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text(c.deleteError ?? 'Unable to delete measurement.')),
      );
    }
  }

  void _openImageFullscreen(String url) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _NetworkImageFullScreen(url: url)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Measurement #${widget.id}'),
        backgroundColor: Colors.transparent,
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final c = context.watch<HistoryController>();
    final errorColor = Theme.of(context).colorScheme.error;

    if (c.isDetailLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (c.detailError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 48, color: errorColor),
              const SizedBox(height: 12),
              Text(c.detailError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => c.loadDetail(widget.id),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    final item = c.detail;
    if (item == null) {
      return const Center(child: Text('Measurement not found.'));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (item.imageUrl != null && item.imageUrl!.isNotEmpty) ...[
          SectionCard(
            icon: Icons.image_outlined,
            title: 'Attached image',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => _openImageFullscreen(item.imageUrl!),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      item.imageUrl!,
                      height: 220,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          height: 220,
                          color: const Color(0xFFF2F4FA),
                          alignment: Alignment.center,
                          child: const CircularProgressIndicator(
                              strokeWidth: 2.5),
                        );
                      },
                      errorBuilder: (context, error, stack) => Container(
                        height: 220,
                        color: const Color(0xFFF2F4FA),
                        alignment: Alignment.center,
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.image_not_supported_outlined,
                                size: 34, color: AppTheme.textSecondary),
                            SizedBox(height: 8),
                            Text(
                              'Image preview unavailable',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.open_in_full_rounded,
                        size: 14, color: AppTheme.textSecondary),
                    SizedBox(width: 6),
                    Text(
                      'Tap to view full screen',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        SectionCard(
          icon: Icons.straighten_rounded,
          title: 'Measurement details',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _kvRow('ID', item.id?.toString() ?? '-'),
              _kvRow('Width', '${_fmtNum(item.width)} in'),
              _kvRow('Height', '${_fmtNum(item.height)} in'),
              _kvRow('Sq.Ft', _fmtNum(item.sqft)),
              _kvRow('Latitude', item.latitude.toStringAsFixed(6)),
              _kvRow('Longitude', item.longitude.toStringAsFixed(6)),
              _kvRow('Accuracy', '${_fmtNum(item.accuracy)} m'),
              _kvRow('Date/Time', _fmtTimestamp(item.timestamp)),
              if (item.createdAt != null && item.createdAt!.isNotEmpty)
                _kvRow('Created', _fmtTimestamp(item.createdAt)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 52,
          child: OutlinedButton.icon(
            onPressed: c.isDeleting ? null : _confirmDelete,
            icon: c.isDeleting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline_rounded, size: 20),
            label: Text(c.isDeleting ? 'Deleting...' : 'Delete measurement'),
            style: OutlinedButton.styleFrom(
              foregroundColor: errorColor,
              side: BorderSide(color: errorColor, width: 1.4),
            ),
          ),
        ),
      ],
    );
  }

  Widget _kvRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _NetworkImageFullScreen extends StatelessWidget {
  final String url;

  const _NetworkImageFullScreen({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F1A),
      body: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              maxScale: 6,
              minScale: 1,
              child: Center(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  },
                  errorBuilder: (context, error, stack) => const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.image_not_supported_outlined,
                            size: 40, color: Colors.white70),
                        SizedBox(height: 10),
                        Text(
                          'Unable to load image',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  child: IconButton(
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.close_rounded,
                        color: AppTheme.textPrimary),
                    tooltip: 'Close',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}