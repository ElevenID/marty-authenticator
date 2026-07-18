import 'package:flutter_test/flutter_test.dart';
import 'package:marty_authenticator/utils/logger.dart';

void main() {
  test('logger accepts every level and redacts credential-shaped errors', () {
    Logger.setVerboseLogging(true);
    Logger.info('secret=abc123', name: 'auth');
    Logger.warning('new_fb_token: token-value', error: 'secret=unsafe');
    Logger.debug('fbtoken bearer-value', verbose: true);
    Logger.error(
      null,
      error: 'secret=unsafe',
      stackTrace: StackTrace.fromString('trace'),
      name: 'wallet',
    );
    Logger.error('failure', stackTrace: 'string trace');
    Logger.error(null);
    Logger.setVerboseLogging(false);
  });
}
