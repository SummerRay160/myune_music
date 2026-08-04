import 'package:flutter/material.dart';

import '../widgets/app_window_title_bar.dart';
import 'main_view.dart';
import '../widgets/playbar.dart';
import '../widgets/playing_queue_drawer.dart';
import '../widgets/toast_overlay.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.transparent,
      endDrawer: PlayingQueueDrawer(),
      body: Stack(
        children: [
          Material(
            color: Colors.transparent,
            child: Column(
              children: [
                AppWindowTitleBar(),
                Expanded(child: MainView()),
                Playbar(),
              ],
            ),
          ),
          ToastOverlay(),
        ],
      ),
    );
  }
}
