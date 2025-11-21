/*
 * privacyIDEA Authenticator
 *
 * Authors: Adam Burdett <adam.burdett@netknights.it>
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

/// Central export for SDK-enhanced SpruceID services
/// Provides easy access to all extended functionality
///
/// This file exports the complete SDK integration layer that leverages
/// the refactored Android and iOS handlers for enhanced functionality

// Extended interfaces
export '../interfaces/spruce_interfaces_extended.dart';

// Extended platform service
export 'spruce_platform_service_extended.dart';

// Extended client
export 'spruce_client_extended.dart';

// Extended managers
export 'spruce_managers_extended.dart';

// Base services for backward compatibility
export 'spruce_platform_service.dart';
export 'spruce_client.dart';
export 'spruce_mdoc_manager.dart';
export 'spruce_sdjwt_manager.dart';
export 'spruce_wallet_manager.dart';

// Interfaces
export '../interfaces/spruce_interfaces.dart';

// Utilities
export '../utils/spruce_channels.dart';
