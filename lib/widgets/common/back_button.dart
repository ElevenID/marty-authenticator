import 'package:flutter/material.dart';

class CustomBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String text;

  const CustomBackButton({super.key, this.onPressed, this.text = 'Back'});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // If we have enough width, show icon + text, otherwise just icon
        final showText = constraints.maxWidth > 60;

        return TextButton(
          onPressed:
              onPressed ??
              () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              },
          style: TextButton.styleFrom(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.all(4.0),
            minimumSize: Size(constraints.maxWidth, 40),
          ),
          child: showText
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.chevron_left,
                      color: Colors.blue,
                      size: 18,
                    ),
                    Text(
                      text,
                      style: const TextStyle(color: Colors.blue, fontSize: 14),
                    ),
                  ],
                )
              : const Icon(Icons.chevron_left, color: Colors.blue, size: 24),
        );
      },
    );
  }
}
