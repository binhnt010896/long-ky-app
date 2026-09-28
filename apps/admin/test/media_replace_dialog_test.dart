import 'dart:typed_data';

import 'package:admin/api/api_providers.dart';
import 'package:admin/api/cms_api_client.dart';
import 'package:admin/util/media_urls.dart';
import 'package:admin/widgets/media_replace_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  // "Download original" (Cycle L) must fetch the untouched file from
  // long-ky-sources via GET /media — never the recompressed CDN copy the
  // rest of the dialog previews — and hand it to the platform save hook
  // rather than doing anything browser-specific itself (so this test needs
  // no real browser).
  testWidgets('Download original fetches the source bytes and saves them', (tester) async {
    // The dialog is a fixed 900×700 — the default test surface is smaller
    // and overflows the "Background:" chip row, which is unrelated to what
    // this test checks.
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Uri? requestedUri;
    final originalBytes = Uint8List.fromList(List.generate(64, (i) => i));

    final client = CmsApiClient(
      baseUrl: 'https://example.invalid',
      idTokenProvider: () async => 'test-token',
      client: MockClient((req) async {
        requestedUri = req.url;
        return http.Response.bytes(originalBytes, 200);
      }),
    );

    Uint8List? savedBytes;
    String? savedFilename;
    String? savedMimeType;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [cmsApiClientProvider.overrideWithValue(client)],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => MediaReplaceDialog(
                    path: 'eras/nha-trieu/cover.png',
                    manifest: MediaManifest.fromJson('{"files":{}}'),
                    saveFile: (bytes, filename, {mimeType}) {
                      savedBytes = bytes;
                      savedFilename = filename;
                      savedMimeType = mimeType;
                    },
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Download original'));
    await tester.pumpAndSettle();

    expect(requestedUri?.queryParameters['path'], 'eras/nha-trieu/cover.png');
    expect(savedBytes, originalBytes);
    expect(savedFilename, 'cover.png');
    expect(savedMimeType, 'image/png');
    expect(find.textContaining('Downloaded original: 0.0 MB'), findsOneWidget);
  });

  testWidgets('a failed download shows an error instead of throwing', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final client = CmsApiClient(
      baseUrl: 'https://example.invalid',
      idTokenProvider: () async => 'test-token',
      client: MockClient((req) async => http.Response('not found', 404)),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [cmsApiClientProvider.overrideWithValue(client)],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => MediaReplaceDialog(
                    path: 'eras/nha-trieu/cover.png',
                    manifest: MediaManifest.fromJson('{"files":{}}'),
                    saveFile: (bytes, filename, {mimeType}) {},
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Download original'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Download failed'), findsOneWidget);
  });
}
