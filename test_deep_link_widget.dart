import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';

/// Simple test app to demonstrate deep linking without Firebase
/// This shows how the app_links package works independently
class DeepLinkTestApp extends StatelessWidget {
  const DeepLinkTestApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'Deep Link Test', home: const DeepLinkTestPage());
  }
}

class DeepLinkTestPage extends StatefulWidget {
  const DeepLinkTestPage({Key? key}) : super(key: key);

  @override
  State<DeepLinkTestPage> createState() => _DeepLinkTestPageState();
}

class _DeepLinkTestPageState extends State<DeepLinkTestPage> {
  final AppLinks _appLinks = AppLinks();
  final List<String> _receivedLinks = [];

  @override
  void initState() {
    super.initState();
    _initializeDeepLinking();
  }

  void _initializeDeepLinking() {
    // Listen for initial app launch from deep link
    _appLinks.getInitialLink().then((Uri? uri) {
      if (uri != null) {
        _handleDeepLink(uri, isInitial: true);
      }
    });

    // Listen for deep links while app is running
    _appLinks.uriLinkStream.listen(
      (Uri uri) => _handleDeepLink(uri),
      onError: (err) => print('Deep link error: $err'),
    );
  }

  void _handleDeepLink(Uri uri, {bool isInitial = false}) {
    setState(() {
      _receivedLinks.add(
        '${isInitial ? '[INITIAL]' : '[RUNTIME]'} ${uri.toString()}',
      );
    });
    print('Received deep link: $uri');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deep Link Test'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This app demonstrates deep linking without Firebase.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Supported URL Schemes:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            const Text('• otpauth://'),
            const Text('• otpauth-migration://'),
            const Text('• pia://'),
            const Text('• openid-credential-offer://'),
            const Text('• openid4vp://'),
            const Text('• openid-credential://'),
            const SizedBox(height: 16),
            Text(
              'Received Deep Links (${_receivedLinks.length}):',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _receivedLinks.isEmpty
                  ? const Center(
                      child: Text(
                        'No deep links received yet.\nUse ADB commands to test.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _receivedLinks.length,
                      itemBuilder: (context, index) {
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              _receivedLinks[index],
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _receivedLinks.clear();
                });
              },
              child: const Text('Clear History'),
            ),
          ],
        ),
      ),
    );
  }
}

// Test this by creating a minimal Flutter app:
// flutter create deep_link_test
// Replace lib/main.dart with:
/*
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';

void main() {
  runApp(const DeepLinkTestApp());
}

// ... include the code above ...
*/
