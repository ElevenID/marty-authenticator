import 'package:flutter/material.dart';

class PreviousCardsDialog {
  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog.fullscreen(
          backgroundColor: const Color(0xFF1C1C1E),
          child: Scaffold(
            backgroundColor: const Color(0xFF1C1C1E),
            appBar: AppBar(
              backgroundColor: const Color(0xFF1C1C1E),
              elevation: 0,
              automaticallyImplyLeading: false,
              leading: TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Return to main add wallet dialog
                },
                icon: const Icon(
                  Icons.chevron_left,
                  color: Colors.blue,
                  size: 20,
                ),
                label: const Text(
                  'Back',
                  style: TextStyle(color: Colors.blue, fontSize: 16),
                ),
                style: TextButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 8.0),
                ),
              ),
              leadingWidth: 80,
            ),
            body: const SingleChildScrollView(
              padding: EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Previous Cards',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Add cards you\'ve used before.',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  SizedBox(height: 32),
                  Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.credit_card_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No Previous Cards',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Cards you\'ve added before will appear here.',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
