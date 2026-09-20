import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/history_controller.dart';
import '../controllers/report_controller.dart';
import '../services/image_service.dart';
import '../theme/app_theme.dart';
import 'capture_view.dart';
import 'history_view.dart';
import 'home_view.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  bool _historyLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recoverLostCapture());
  }

  /// On Android, MainActivity can be destroyed while the system camera or
  /// gallery is open. When the app relaunches we recover the lost photo so it
  /// is not silently dropped, and re-enter the capture step instead of Home.
  Future<void> _recoverLostCapture() async {
    try {
      final lost = await ImageService().recoverLostCapture();
      if (lost == null || !mounted) return;

      final compressed = await ImageService().compressAndValidate(lost);
      if (!mounted) return;
      context.read<ReportController>().setImage(compressed);
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CaptureView()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not restore the captured photo: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          const HomeView(),
          _historyLoaded
              ? const HistoryView()
              : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.appBarBorder)),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (value) {
            if (value == 1) {
              _historyLoaded = true;
              context.read<HistoryController>().load();
            }
            setState(() => _index = value);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history_rounded),
              label: 'History',
            ),
          ],
        ),
      ),
    );
  }
}