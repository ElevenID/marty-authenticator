/*
 * privacyIDEA Authenticator
 *
 * Authors: Adam Burdett <adam.burdett@netknights.it>
 *          Frank Merkel <frank.merkel@netknights.it>
 *
 * Copyright (c) 2025 NetKnights GmbH
 *
 * Licensed under the Apache License, Version 2.0 (the 'License');
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an 'AS IS' BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../widgets/status_bar.dart';
import 'main_view_widgets/credentials_list.dart';
import 'main_view_widgets/main_view_tokens_list.dart';
import 'main_view_widgets/main_view_background_image.dart';

export 'credential_first_main_view.dart';

/// Provider for the current view mode (credentials or tokens)
final viewModeProvider = StateProvider<ViewMode>((ref) => ViewMode.credentials);

enum ViewMode { credentials, tokens }

/// New credential-first main view
class CredentialFirstMainView extends ConsumerStatefulWidget {
  static const routeName = '/credentialFirstMainView';

  final Widget appbarIcon;
  final Widget? backgroundImage;
  final String appName;
  final bool disablePatchNotes;

  const CredentialFirstMainView({
    required this.backgroundImage,
    required this.appbarIcon,
    required this.appName,
    required this.disablePatchNotes,
    super.key,
  });

  @override
  ConsumerState<CredentialFirstMainView> createState() =>
      _CredentialFirstMainViewState();
}

class _CredentialFirstMainViewState
    extends ConsumerState<CredentialFirstMainView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Set initial tab based on provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentMode = ref.read(viewModeProvider);
      _tabController.index = currentMode.index;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewMode = ref.watch(viewModeProvider);

    return Container(
      color: theme.navigationBarTheme.backgroundColor,
      child: SafeArea(
        top: false,
        child: Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: Column(
            children: [
              // Custom app bar with tab functionality
              Container(
                decoration: BoxDecoration(
                  color: theme.appBarTheme.backgroundColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      // App bar row
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          children: [
                            widget.appbarIcon,
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                widget.appName,
                                style:
                                    theme.appBarTheme.titleTextStyle?.copyWith(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ) ??
                                    theme.textTheme.titleLarge,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Settings button
                            IconButton(
                              icon: const Icon(Icons.settings),
                              onPressed: () => _showSettings(),
                            ),
                          ],
                        ),
                      ),

                      // Tab bar
                      Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          onTap: (index) {
                            ref.read(viewModeProvider.notifier).state =
                                ViewMode.values[index];
                          },
                          tabs: const [
                            Tab(
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.credit_card, size: 18),
                                    SizedBox(width: 8),
                                    Text('Credentials'),
                                  ],
                                ),
                              ),
                            ),
                            Tab(
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.security, size: 18),
                                    SizedBox(width: 8),
                                    Text('Tokens'),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          indicator: BoxDecoration(
                            borderRadius: BorderRadius.circular(25),
                            color: theme.colorScheme.primary,
                          ),
                          labelColor: Colors.white,
                          unselectedLabelColor: theme.colorScheme.onSurface
                              .withOpacity(0.7),
                          dividerColor: Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Content area
              Expanded(
                child: StatusBar(
                  child: Stack(
                    children: [
                      // Background image
                      if (widget.backgroundImage != null)
                        MainViewBackgroundImage(
                          appImage: widget.backgroundImage!,
                        ),

                      // Tab view
                      TabBarView(
                        controller: _tabController,
                        children: [
                          // Credentials view (primary)
                          const CredentialsList(),

                          // Tokens view (secondary)
                          MainViewTokensList(
                            nestedScrollViewKey:
                                GlobalKey<NestedScrollViewState>(),
                          ),
                        ],
                      ),

                      // Floating action button
                      _buildFAB(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFAB() {
    final viewMode = ref.watch(viewModeProvider);

    return Positioned(
      right: 16,
      bottom: 24,
      child: FloatingActionButton.extended(
        onPressed: () => _addItem(viewMode),
        label: Text(
          viewMode == ViewMode.credentials ? 'Add Credential' : 'Add Token',
        ),
        icon: Icon(
          viewMode == ViewMode.credentials
              ? Icons.add_card
              : Icons.qr_code_scanner,
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  void _addItem(ViewMode mode) {
    if (mode == ViewMode.credentials) {
      // TODO: Navigate to add credential flow
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add credential flow coming soon...'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      // TODO: Navigate to existing add token flow
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Opening QR scanner...'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showSettings() {
    // TODO: Navigate to settings
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Opening settings...'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
