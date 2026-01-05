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

/// Services implementing MMF interfaces using SpruceID platform services.
///
/// These implementations wrap SpruceID platform channels and provide
/// concrete implementations of the MMF interfaces.
///
/// Note: Key management is handled directly by native SpruceID SDK KeyManager.
/// The Dart layer only needs ISecureStorage and ICredentialTransport.
library;

export 'flutter_secure_storage_adapter.dart';
export 'spruce_credential_transport.dart';
