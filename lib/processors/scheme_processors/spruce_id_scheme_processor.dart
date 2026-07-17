import 'package:privacyidea_authenticator/utils/object_validator.dart';
import 'package:privacyidea_authenticator/utils/riverpod/providers/credentials_provider.dart';
import '../../../model/processor_result.dart';
import '../../../utils/logger.dart';
import 'scheme_processor_interface.dart';

class SpruceIdSchemeProcessor extends SchemeProcessor {
  static ObjectValidator<CredentialsNotifier> get resultHandlerType =>
      const ObjectValidator<CredentialsNotifier>();

  const SpruceIdSchemeProcessor();

  @override
  Set<String> get supportedSchemes => {
    'openid-credential-offer',
    'openid4vp',
    'openid-credential',
  };

  @override
  Future<List<ProcessorResult<dynamic>>?> processUri(
    Uri uri, {
    bool fromInit = false,
  }) async {
    if (!supportedSchemes.contains(uri.scheme)) return null;

    Logger.info('Processing SpruceID URI: ${uri.scheme}');

    return [ProcessorResult.success(uri, resultHandlerType: resultHandlerType)];
  }
}
