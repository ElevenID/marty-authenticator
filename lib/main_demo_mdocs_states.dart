/*
  privacyIDEA Authenticator - Demo Main: mDocs in Various States

  Authors: Adam Burdett <adam.burdett@netknights.it>

  Copyright (c) 2017-2025 NetKnights GmbH

  Licensed under the Apache License, Version 2.0 (the 'License');
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an 'AS IS' BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
*/

/// Demo main entry point with mDoc credentials in different states
/// Includes: Valid, Near Expiry, and Expired credentials
/// Useful for testing UI handling of different credential states
///
/// Run with:
///   flutter run -t lib/main_demo_mdocs_states.dart -d chrome
///   flutter run -t lib/main_demo_mdocs_states.dart -d macos
///   flutter run -t lib/main_demo_mdocs_states.dart -d android

import 'mains/demo_base.dart';
import 'fixtures/spruce_credentials_fixtures.dart';

void main() async {
  await runDemoApp(
    demoName: 'mDocs - Multiple States',
    credentialsLoader: (mockServices) async {
      // Valid credentials
      final mdlValid = MDocFixtures.mobileDriverLicense(
        state: CredentialState.valid,
      );
      final passportValid = MDocFixtures.mobilePassport(
        state: CredentialState.valid,
      );

      // Near expiry
      final mdlNearExpiry = MDocFixtures.mobileDriverLicense(
        state: CredentialState.nearExpiry,
      );
      final midNearExpiry = MDocFixtures.mobileId(
        state: CredentialState.nearExpiry,
      );

      // Expired
      final passportExpired = MDocFixtures.mobilePassport(
        state: CredentialState.expiredRecently,
      );

      await mockServices.platformService.storeCredential(mdlValid);
      await mockServices.platformService.storeCredential(passportValid);
      await mockServices.platformService.storeCredential(mdlNearExpiry);
      await mockServices.platformService.storeCredential(midNearExpiry);
      await mockServices.platformService.storeCredential(passportExpired);

      return [
        'MDL (Valid)',
        'Passport (Valid)',
        'MDL (Near Expiry)',
        'Mobile ID (Near Expiry)',
        'Passport (Expired)',
      ];
    },
  );
}
