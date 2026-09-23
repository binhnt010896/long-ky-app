/// Content loading for Việt Sử.
///
/// Reads `content/eras/*.json` into [core_domain] models through a swappable
/// [ContentSource]: [BundledContentSource] for the shipped app, [OtaContentSource]
/// for the (stubbed) over-the-air seam. [ContentRepository] is the entry point.
library;

export 'src/content_pack.dart';
export 'src/content_repository.dart';
export 'src/content_source.dart';
export 'src/ota_content_source.dart';
