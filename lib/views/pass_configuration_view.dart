import 'package:flutter/material.dart';
import '../widgets/common/back_button.dart' as common;

class PassConfigurationView extends StatefulWidget {
  const PassConfigurationView({super.key});

  @override
  State<PassConfigurationView> createState() => _PassConfigurationViewState();
}

class _PassConfigurationViewState extends State<PassConfigurationView> {
  bool automaticUpdates = true;
  bool allowNotifications = true;
  bool suggestOnLockScreen = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: common.CustomBackButton(
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.blue),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 30),
              _buildSwitchTile(
                'Automatic Updates',
                automaticUpdates,
                (val) => setState(() => automaticUpdates = val),
              ),
              const Divider(color: Colors.grey),
              _buildSwitchTile(
                'Allow Notifications',
                allowNotifications,
                (val) => setState(() => allowNotifications = val),
              ),
              const Divider(color: Colors.grey),
              _buildSwitchTile(
                'Suggest on Lock Screen',
                suggestOnLockScreen,
                (val) => setState(() => suggestOnLockScreen = val),
              ),
              const SizedBox(height: 10),
              const Text(
                'Show based on time or location.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 30),
              const Text(
                'Email',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              const Text(
                'holder@example.com',
                style: TextStyle(color: Colors.blue, fontSize: 16),
              ),
              const SizedBox(height: 20),
              const Text(
                'ADDRESS',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              const Text(
                'Example Event\n100 Example Avenue\nDenver, CO 80202',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Center(
      child: Column(
        children: [
          Container(
            width: 100,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.indigo,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.event, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 10),
          const Text(
            'Spanish Fork October Mon-Thurs Pumpkin Fest',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text('Updated 12/4/24', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildSwitchTile(String title, bool value, Function(bool) onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: Colors.green,
        ),
      ],
    );
  }
}
