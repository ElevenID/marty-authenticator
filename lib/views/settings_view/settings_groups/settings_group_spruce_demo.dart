import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../spruce_demo_view/spruce_demo_view.dart';
import '../../separated_spruce_demo_view/separated_spruce_demo_view.dart';
import '../settings_view_widgets/settings_group.dart';
import '../settings_view_widgets/settings_list_tile_button.dart';

class SettingsGroupSpruceDemo extends ConsumerWidget {
  const SettingsGroupSpruceDemo({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsGroup(
      title: 'SpruceID Demo',
      children: [
        SettingsListTileButton(
          onPressed: () {
            Navigator.of(context).pushNamed(SpruceIdDemoView.routeName);
          },
          title: const Text(
            'Original SpruceID Demo',
            overflow: TextOverflow.fade,
            softWrap: false,
          ),
        ),
        SettingsListTileButton(
          onPressed: () {
            Navigator.of(
              context,
            ).pushNamed(SeparatedSpruceIdDemoView.routeName);
          },
          title: const Text(
            'Separated Tech Demo (Recommended)',
            overflow: TextOverflow.fade,
            softWrap: false,
          ),
        ),
      ],
    );
  }
}
