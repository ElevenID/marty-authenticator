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

/// Marty Rust Bridge - FFI bindings to marty-verification
///
/// This library provides Dart bindings to the Marty Rust layer for:
/// - Credential parsing (VC, mDoc, SD-JWT)
/// - Trust chain verification (IACA for mDL)
/// - Credential grouping and selection
///
/// Initialize the Rust library before use:
/// ```dart
/// await RustLib.init();
/// ```
library marty_bridge;

// Re-export generated types and API
export 'marty_bridge.dart/frb_generated.dart' show RustLib;
export 'marty_bridge.dart/api.dart';
export 'marty_bridge.dart/credential.dart';
