import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/proximity_service.dart';
import '../../services/proximity/proximity_transport.dart';

class MdlPresentationView extends ConsumerStatefulWidget {
  const MdlPresentationView({super.key});

  @override
  ConsumerState<MdlPresentationView> createState() =>
      _MdlPresentationViewState();
}

class _MdlPresentationViewState extends ConsumerState<MdlPresentationView> {
  String _status = 'Initializing...';
  List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _startPresentation();
  }

  Future<void> _startPresentation() async {
    final service = ref.read(proximityServiceProvider);

    // Listen to events manually for logging (in addition to service handling)
    // Note: In a real app, the service would expose a state stream.
    // For this debug view, we'll just rely on the service's internal logging
    // or we could expose the stream from the service.
    // Let's just update status based on what we expect.

    setState(() {
      _status = 'Advertising mDL Service...';
      _logs.add('Started advertising UUID: 000018013-...');
    });

    try {
      await service.startPresentation();
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
        _logs.add('Error starting presentation: $e');
      });
    }
  }

  @override
  void dispose() {
    ref.read(proximityServiceProvider).stopPresentation();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Present ID'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Icon(Icons.wifi_tethering, size: 80, color: Colors.blue),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                _status,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 40),
            const Text(
              'Activity Log:',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey[800]!),
                ),
                child: ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Text(
                        '> ${_logs[index]}',
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontFamily: 'Courier',
                          fontSize: 12,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: const Text(
                  'Stop Presentation',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
