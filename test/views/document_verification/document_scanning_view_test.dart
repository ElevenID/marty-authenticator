import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marty_authenticator/models/document_verification_config.dart';
import 'package:marty_authenticator/views/document_verification/document_scanning_view.dart';

void main() {
  Widget app(DocumentScanningView view) => MaterialApp(home: view);

  testWidgets('captures a passport front and opens liveness', (tester) async {
    await tester.pumpWidget(
      app(
        DocumentScanningView(
          config: DocumentVerificationConfig.passport,
          cameraPreviewOverride: const ColoredBox(color: Colors.blue),
          processingDelay: Duration.zero,
          cameraReleaseDelay: Duration.zero,
          livenessBuilder: (_) => const Scaffold(body: Text('Fake liveness')),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Scan Front of Document'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.camera_alt));
    await tester.pump();
    expect(find.text('Processing Document...'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Fake liveness'), findsOneWidget);
  });

  testWidgets('captures a license front and opens the back scan', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        DocumentScanningView(
          config: DocumentVerificationConfig.driverLicense,
          cameraPreviewOverride: const ColoredBox(color: Colors.blue),
          processingDelay: Duration.zero,
          cameraReleaseDelay: Duration.zero,
          scanningBuilder: (_, index) =>
              Scaffold(body: Text('Scan step $index')),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byIcon(Icons.camera_alt));
    await tester.pumpAndSettle();
    expect(find.text('Scan step 1'), findsOneWidget);
  });

  testWidgets('renders back instruction and safely handles a final scan', (
    tester,
  ) async {
    const config = DocumentVerificationConfig(
      type: DocumentType.driverLicense,
      steps: [VerificationStep.scanBack],
    );
    await tester.pumpWidget(
      app(
        const DocumentScanningView(
          config: config,
          cameraPreviewOverride: ColoredBox(color: Colors.blue),
          processingDelay: Duration.zero,
          cameraReleaseDelay: Duration.zero,
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Scan Back of Document'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.camera_alt));
    await tester.pumpAndSettle();
    expect(find.text('Scan Document'), findsOneWidget);
  });

  testWidgets('shows progress when no camera is available', (tester) async {
    await tester.pumpWidget(
      app(
        DocumentScanningView(
          config: DocumentVerificationConfig.passport,
          cameraProvider: () async => [],
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('recovers when document processing fails', (tester) async {
    await tester.pumpWidget(
      app(
        DocumentScanningView(
          config: DocumentVerificationConfig.passport,
          cameraPreviewOverride: const ColoredBox(color: Colors.blue),
          delay: (_) async => throw StateError('processing failed'),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byIcon(Icons.camera_alt));
    await tester.pump();
    expect(find.byIcon(Icons.camera_alt), findsOneWidget);
  });

  testWidgets('uses the production liveness route by default', (tester) async {
    await tester.pumpWidget(
      app(
        DocumentScanningView(
          config: DocumentVerificationConfig.passport,
          cameraPreviewOverride: const ColoredBox(color: Colors.blue),
          processingDelay: Duration.zero,
          cameraReleaseDelay: Duration.zero,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byIcon(Icons.camera_alt));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    Navigator.of(
      tester.element(find.byType(CircularProgressIndicator).first),
    ).pop();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Scan Document'), findsOneWidget);
  });
}
