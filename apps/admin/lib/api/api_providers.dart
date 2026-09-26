import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import 'cms_api_client.dart';

/// The one Worker this CMS ever talks to — see services/cms_api. No env
/// split: the Worker's own CORS config is what gates who can call it, and
/// there is only ever one deployed instance.
const cmsApiBaseUrl = 'https://long-ky-cms-api.binhnt-010896.workers.dev';

final cmsApiClientProvider = Provider<CmsApiClient>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return CmsApiClient(
    baseUrl: cmsApiBaseUrl,
    idTokenProvider: () => currentIdToken(auth),
  );
});
