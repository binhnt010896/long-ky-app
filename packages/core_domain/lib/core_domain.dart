/// Pure-Dart domain models for Việt Sử, mirroring `content/era.schema.json`.
///
/// No Flutter dependency: colours are hex strings, not `Color`s, so these models
/// stay testable and reusable. The UI layer (ui_kit) turns hex into the sơn mài
/// palette; the content layer (core_content) parses JSON into these types.
library;

export 'src/asset_ref.dart';
export 'src/character.dart';
export 'src/citation.dart';
export 'src/content_validation/content_formatter.dart';
export 'src/content_validation/content_validator.dart';
export 'src/era.dart';
export 'src/history_event.dart';
export 'src/json_util.dart' show ContentFormatException;
export 'src/localized_text.dart';
export 'src/people.dart';
export 'src/period.dart';
export 'src/quiz/question.dart';
export 'src/quiz/quiz_generator.dart';
export 'src/year.dart';
