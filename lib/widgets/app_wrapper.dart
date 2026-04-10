import 'dart:ui';

import 'package:easy_dynamic_theme/easy_dynamic_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/logger.dart';
import '../utils/riverpod/riverpod_providers/generated_providers/deeplink_notifier.dart';
import '../utils/riverpod/riverpod_providers/generated_providers/token_notifier.dart';
import '../utils/riverpod/state_listeners/navigation_deep_link_listener.dart';
import 'app_wrappers/single_touch_recognizer.dart';
import 'app_wrappers/state_observer.dart';

class AppWrapper extends StatelessWidget {
  final Widget child;
  final List<Override> overrides;

  const AppWrapper({required this.child, this.overrides = const [], super.key});

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: overrides,
    child: _AppWrapper(key: key, child: child),
  );
}

class _AppWrapper extends ConsumerStatefulWidget {
  final Widget child;
  const _AppWrapper({required this.child, super.key});

  @override
  ConsumerState<_AppWrapper> createState() => _AppWrapperState();
}

class _AppWrapperState extends ConsumerState<_AppWrapper> {
  late final AppLifecycleListener _listener;

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(
      onResume: () async {
        await ref.read(tokenProvider.notifier).loadStateFromRepo();
        Logger.info('Refreshed tokens on resume');
      },
      onHide: () async {
        if (await ref.read(tokenProvider.notifier).onMinimizeApp() == false) {
          Logger.error('Failed to save tokens on Hide');
        }
        Logger.info('Saved tokens on Hide');
      },
      onExitRequested: () async {
        Logger.info('Exit requested');
        return AppExitResponse.exit;
      },
    );
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleTouchRecognizer(
      child: widget
          .child, // Temporarily disabled StateObserver due to compilation issues
    );
  }
}
