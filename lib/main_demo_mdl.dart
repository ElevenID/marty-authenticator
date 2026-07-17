/*
  privacyIDEA Authenticator - Demo Main: MDL Only

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

/// Demo main entry point with Mobile Driver License (mDL) only
///
/// Run with:
///   flutter run -t lib/main_demo_mdl.dart -d chrome
///   flutter run -t lib/main_demo_mdl.dart -d macos
///   flutter run -t lib/main_demo_mdl.dart -d android

import 'mains/demo_base.dart';
import 'fixtures/spruce_credentials_fixtures.dart';

void main() async {
  await runDemoApp(
    demoName: 'MDL Only',
    credentialsLoader: (mockServices) async {
      final mdl = MDocFixtures.mobileDriverLicense(
        state: CredentialState.valid,
      );

      await mockServices.platformService.storeCredential(mdl);

      return ['Mobile Driver License (mDL)'];
    },
  );
}
