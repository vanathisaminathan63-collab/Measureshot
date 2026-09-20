import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_editor_plus/image_editor_plus.dart';
import 'package:provider/provider.dart';

import '../controllers/report_controller.dart';
import '../services/image_service.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';
import '../widgets/step_progress_header.dart';
import 'image_preview_view.dart';
import 'measurement_view.dart';

enum _EditAction { edit, view, retake, gallery, remove }

class CaptureView extends StatefulWidget {
  const CaptureView({super.key});

  @override
  State<CaptureView> createState() => _CaptureViewState();
}

class _CaptureViewState extends State<CaptureView>
    with WidgetsBindingObserver {
  final ImageService _imageService = ImageService();
  bool _busy = false;
  bool _cameraPickActive = false;
  bool _recovering = false;

  @override
  void initState() {
    super.initState();
    debugPrint('[Capture] CaptureView created');
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _runRecovery());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('[Capture] lifecycle: $state '
        '(busy=$_busy cameraActive=$_cameraPickActive)');
    if (state == AppLifecycleState.resumed) _recoverOnResume();
  }

  /// After returning from the camera intent the MainActivity may have been
  /// destroyed and recreated by the OS. ImagePicker parks the picked result
  /// in its lost-data cache, so poll it until the result appears.
  Future<void> _recoverOnResume() async {
    if (!_cameraPickActive) {
      if (!_busy) await _runRecovery();
      return;
    }
    // Camera intent was in the foreground when we paused. The MainActivity
    // may have been destroyed, so poll ImagePicker's lost-data cache until
    // the result (or nothing) arrives.
    await _runRecovery(poll: true);
  }

  /// Runs a recovery pass. The loading card is driven by [_recoverLost] itself
  /// (raised only while an actual recovered photo is being processed), so a
  /// normal screen entry without lost data never flashes the indicator.
  Future<void> _runRecovery({bool poll = false}) async {
    if (_recovering) return;
    if (_busy && !_cameraPickActive) return;
    if (await _recoverLost()) return;
    if (poll) {
      for (var attempt = 0; attempt < 5 && _cameraPickActive; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        if (!mounted) return;
        if (await _recoverLost()) return;
      }
      debugPrint('[Capture] recovery polling exhausted (no lost data found)');
    }
  }

  /// Queries ImagePicker's lost-data cache and, when a photo survives, stores
  /// it. Returns true when the recovered photo was applied to the preview.
  /// While the recovered photo is being re-encoded the preview loading card is
  /// shown so the blank state never flashes during recovery.
  Future<bool> _recoverLost() async {
    debugPrint('[Capture] recoverLost: querying lost-data cache');
    final recovered = await _imageService.recoverLostCapture();
    if (recovered == null || !mounted) {
      debugPrint('[Capture] recoverLost: no lost data to restore');
      return false;
    }
    if (!_recovering) setState(() => _recovering = true);
    try {
      final compressed = await _imageService.compressAndValidate(recovered);
      if (!mounted) return false;
      context.read<ReportController>().setImage(compressed);
      if (_cameraPickActive || _busy) {
        _cameraPickActive = false;
        setState(() => _busy = false);
      }
      debugPrint('[Capture] recoverLost: preview updated with '
          '${compressed.path}');
      _snack('Recovered photo from interrupted capture.');
      return true;
    } catch (e) {
      debugPrint('[Capture] recoverLost: compress failed: $e');
      return false;
    } finally {
      if (mounted) setState(() => _recovering = false);
    }
  }

  Future<void> _pick(bool camera) async {
    if (_busy) return;
    final source = camera ? 'camera' : 'gallery';
    try {
      setState(() => _busy = true);
      debugPrint('[Capture] source=$source starting');
      File? raw;
      if (camera) {
        _cameraPickActive = true;
        raw = await _imageService.recoverLostCapture() ??
            await _imageService.pickFromCamera();
        if (raw == null && _cameraPickActive) {
          debugPrint('[Capture] camera returned null; polling lost data');
          for (var i = 0; i < 4 && raw == null && _cameraPickActive; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 400));
            if (!mounted) return;
            if (await _recoverLost()) return;
            raw = await _imageService.recoverLostCapture();
          }
        }
      } else {
        raw = await _imageService.pickFromGallery();
      }
      _cameraPickActive = false;
      if (raw == null) {
        debugPrint('[Capture] $source returned null');
        return;
      }
      debugPrint('[Capture] raw path=${raw.path} '
          'exists=${await raw.exists()} bytes=${await raw.length()}');
      if (!mounted) return;

      final compressed = await _imageService.compressAndValidate(raw);
      if (!mounted) return;
      context.read<ReportController>().setImage(compressed);
      debugPrint('[Capture] $source preview updated');
    } catch (e) {
      debugPrint('[Capture] $source failed: $e');
      if (mounted) _snack(e.toString());
    } finally {
      _cameraPickActive = false;
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openFullscreen() async {
    final image = context.read<ReportController>().report.image;
    if (image == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ImagePreviewView(image: image)),
    );
  }

  Future<void> _openEditor() async {
    final file = context.read<ReportController>().report.image;
    if (file == null) return;

    setState(() => _busy = true);
    try {
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() => _busy = false);

      final edited = await Navigator.push<Uint8List>(
        context,
        MaterialPageRoute(
          builder: (_) => ImageEditor(
            image: bytes,
          ),
        ),
      );
      if (edited == null || !mounted) return;

      setState(() => _busy = true);
      final saved = await _imageService.saveEdits(edited);
      if (!mounted) return;
      setState(() => _busy = false);
      context.read<ReportController>().setImage(saved);
      _snack('Edited image saved.');
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _snack(e.toString());
      }
    }
  }

  Future<void> _showEditSheet() async {
    final action = await showModalBottomSheet<_EditAction>(
      context: context,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _EditImageSheet(),
    );
    if (action == null || !mounted) return;

    switch (action) {
      case _EditAction.edit:
        await _openEditor();
        break;
      case _EditAction.view:
        await _openFullscreen();
        break;
      case _EditAction.retake:
        await _pick(true);
        break;
      case _EditAction.gallery:
        await _pick(false);
        break;
      case _EditAction.remove:
        context.read<ReportController>().removeImage();
        break;
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final report = context.watch<ReportController>().report;
    final hasImage = report.image != null;

    return Scaffold(
      body: Column(
        children: [
          const StepProgressHeader(
            step: 1,
            total: 5,
            title: 'Capture',
            subtitle: 'Add a clear, well-lit photo of the surface.',
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              children: [
                // Preview card
                Container(
                  height: 300,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.outline),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: hasImage
                      ? GestureDetector(
                          onTap: _openFullscreen,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.file(
                                report.image!,
                                fit: BoxFit.cover,
                              ),
                              Positioned(
                                top: 12,
                                left: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color:
                                        Colors.black.withValues(alpha: 0.55),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check_circle_rounded,
                                          size: 14, color: Colors.white),
                                      SizedBox(width: 5),
                                      Text('Captured',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 12,
                                left: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color:
                                        Colors.black.withValues(alpha: 0.45),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.zoom_in_rounded,
                                          size: 14, color: Colors.white),
                                      SizedBox(width: 5),
                                      Text('Tap to preview',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 12,
                                right: 12,
                                child: Material(
                                  color: Colors.white,
                                  elevation: 3,
                                  shape: const CircleBorder(),
                                  child: IconButton(
                                    onPressed: _showEditSheet,
                                    icon: const Icon(Icons.edit_rounded,
                                        color: AppTheme.primary, size: 22),
                                    tooltip: 'Edit image',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ((_busy || _recovering)
                          ? const _CaptureLoading()
                          : const _EmptyPreview()),
                ),
                if (_busy && hasImage) ...[
                  const SizedBox(height: 10),
                  const LinearProgressIndicator(minHeight: 4),
                ],
                const SizedBox(height: 20),

                // Pick buttons
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: FilledButton.tonalIcon(
                          onPressed: _busy ? null : () => _pick(true),
                          icon:
                              const Icon(Icons.camera_alt_outlined, size: 20),
                          label: const Text('Camera'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : () => _pick(false),
                          icon: const Icon(Icons.photo_library_rounded,
                              size: 20),
                          label: const Text('Gallery'),
                        ),
                      ),
                    ),
                  ],
                ),

                // Action row when image present
                if (hasImage) ...[
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                context.read<ReportController>().removeImage(),
                            icon: const Icon(Icons.delete_outline_rounded,
                                color: Color(0xFFE5484D), size: 20),
                            label: const Text(
                              'Delete',
                              style: TextStyle(color: Color(0xFFE5484D)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: PrimaryButton(
                          label: 'Next',
                          icon: Icons.arrow_forward_rounded,
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const MeasurementView()),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EditImageSheet extends StatelessWidget {
  const _EditImageSheet();

  @override
  Widget build(BuildContext context) {
    void choose(_EditAction action) =>
        Navigator.of(context).pop(action);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.outline,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Text(
              'Edit image',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              'Review, replace or remove the photo.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ),
          ListTile(
            leading:
                const Icon(Icons.edit_rounded, color: AppTheme.primary),
            title: const Text('Edit & annotate'),
            subtitle: const Text('Draw, text, crop, rotate'),
            onTap: () => choose(_EditAction.edit),
          ),
          // const Divider(height: 8, indent: 20, endIndent: 20),
          // ListTile(
          //   leading: const Icon(Icons.visibility_outlined,
          //       color: AppTheme.primary),
          //   title: const Text('View full screen'),
          //   onTap: () => choose(_EditAction.view),
          // ),
          // ListTile(
          //   leading: const Icon(Icons.camera_alt_outlined,
          //       color: AppTheme.primary),
          //   title: const Text('Retake photo'),
          //   onTap: () => choose(_EditAction.retake),
          // ),
          // ListTile(
          //   leading: const Icon(Icons.photo_library_outlined,
          //       color: AppTheme.primary),
          //   title: const Text('Choose from gallery'),
          //   onTap: () => choose(_EditAction.gallery),
          // ),
          const Divider(height: 8, indent: 20, endIndent: 20),
          ListTile(
            leading:
                const Icon(Icons.delete_outline_rounded, color: Color(0xFFE5484D)),
            title: const Text(
              'Remove image',
              style: TextStyle(color: Color(0xFFE5484D)),
            ),
            onTap: () => choose(_EditAction.remove),
          ),
        ],
      ),
    );
  }
}

class _CaptureLoading extends StatelessWidget {
  const _CaptureLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          SizedBox(height: 16),
          Text(
            'Loading…',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPreview extends StatelessWidget {
  const _EmptyPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.image_outlined,
                size: 32, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          const Text(
            'No image captured yet',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Use the camera or gallery below.',
            style: TextStyle(
              color: AppTheme.textSecondary.withValues(alpha: 0.85),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}