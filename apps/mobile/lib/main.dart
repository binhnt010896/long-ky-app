import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'theme/content_assets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ContentMedia.load();
  runApp(const ProviderScope(child: VietSuApp()));
}
