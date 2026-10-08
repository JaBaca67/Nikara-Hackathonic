import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nikara_app/shared/widgets/local_image.dart';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAEklEQVR4nGPMLjBmYGBgYgADAA0KARLg6RHzAAAAAElFTkSuQmCC',
);

class _Client extends Fake implements HttpClient {
  int requests = 0;
  int failures = 0;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async =>
      _Request(++requests <= failures);

  @override
  bool autoUncompress = true;
}

class _Headers extends Fake implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
}

class _Request extends Fake implements HttpClientRequest {
  _Request(this.fail);
  final bool fail;
  @override
  HttpHeaders get headers => _Headers();
  @override
  Future<HttpClientResponse> close() async => _Response(fail);
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  _Response(this.fail);
  final bool fail;
  @override
  int get statusCode => fail ? 503 : 200;
  @override
  int get contentLength => _png.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.value(_png).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Overrides extends HttpOverrides {
  _Overrides(this.client);
  final _Client client;
  @override
  HttpClient createHttpClient(SecurityContext? context) => client;
}

Widget _image(String? url) => MaterialApp(
  home: Center(
    child: SizedBox.square(dimension: 80, child: LocalImage(path: url)),
  ),
);

Future<void> _decode(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 40)),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final client = _Client();
  HttpOverrides? previous;
  setUp(() {
    previous = HttpOverrides.current;
    HttpOverrides.global = _Overrides(client);
    client.requests = 0;
    client.failures = 0;
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });
  tearDown(() => HttpOverrides.global = previous);

  testWidgets('recupera una descarga fallida sin dejar la foto vacía', (
    tester,
  ) async {
    client.failures = 1;
    await tester.pumpWidget(_image('https://images.example/transient.png'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await _decode(tester);
    expect(client.requests, 2);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byTooltip('Reintentar foto'), findsNothing);
    final rendered = tester.widget<RawImage>(find.byType(RawImage));
    expect(rendered.image, isNotNull);
  });

  testWidgets('limita los reintentos y permite recuperar la foto manualmente', (
    tester,
  ) async {
    client.failures = 3;
    await tester.pumpWidget(_image('https://images.example/manual.png'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(client.requests, 3);
    expect(find.byTooltip('Reintentar foto'), findsOneWidget);
    await tester.pump(const Duration(seconds: 10));
    expect(client.requests, 3);
    await tester.tap(find.byTooltip('Reintentar foto'));
    await tester.pump();
    await _decode(tester);
    expect(client.requests, 4);
    expect(find.byTooltip('Reintentar foto'), findsNothing);
    expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
  });

  testWidgets(
    'cancela la recuperación al cambiar de foto o cerrar la pantalla',
    (tester) async {
      client.failures = 20;
      await tester.pumpWidget(_image('https://images.example/old.png'));
      await tester.pump();
      expect(client.requests, 1);
      await tester.pumpWidget(_image(null));
      await tester.pump(const Duration(seconds: 5));
      expect(client.requests, 1);
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
      await tester.pumpWidget(_image('https://images.example/disposed.png'));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
      expect(client.requests, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('al volver a la app recupera fotos que fallaron sin conexión', (
    tester,
  ) async {
    client.failures = 3;
    await tester.pumpWidget(_image('https://images.example/resume.png'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.byTooltip('Reintentar foto'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _decode(tester);
    expect(client.requests, 4);
    expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
  });
}
