/*
 * privacyIDEA Authenticator
 *
 * Copyright (c) 2025 NetKnights GmbH
 *
 * Licensed under the Apache License, Version 2.0 (the 'License');
 */

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'qr_scanner_integration_demo.dart';

void main() {
  runApp(const ProviderScope(child: QrScannerIntegrationDemoApp()));
}

class QrScannerIntegrationDemoApp extends StatelessWidget {
  const QrScannerIntegrationDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'QR Scanner Integration Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const QrScannerIntegrationDemo(),
    );
  }
}
