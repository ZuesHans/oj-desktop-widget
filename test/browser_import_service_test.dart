import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:oj_float/main.dart';

void main() {
  test('browser import accepts authenticated payload', () async {
    final server = BrowserImportServer(port: 0);
    addTearDown(server.stop);
    BrowserProblemImport? imported;
    await server.start(
      token: 'secret-token',
      importer: (problem) async {
        imported = problem;
        return const BrowserProblemImportResult(
          created: true,
          problemId: 'p1',
        );
      },
    );

    final response = await http.post(
      _endpoint(server),
      headers: {
        HttpHeaders.authorizationHeader: 'Bearer secret-token',
        HttpHeaders.contentTypeHeader: 'application/json',
      },
      body: jsonEncode({
        'url': 'https://codeforces.com/contest/1/problem/A',
        'title': 'A. Test',
        'platform': 'cf',
        'externalId': '1:A',
        'tags': ['math', 'math'],
        'difficulty': '800',
      }),
    );

    expect(response.statusCode, HttpStatus.ok);
    expect(jsonDecode(response.body), {
      'status': 'created',
      'problemId': 'p1',
    });
    expect(imported?.tags, ['math']);
  });

  test('browser import rejects missing or wrong tokens', () async {
    final server = BrowserImportServer(port: 0);
    addTearDown(server.stop);
    await server.start(
      token: 'secret-token',
      importer: (_) async => const BrowserProblemImportResult(
        created: false,
        problemId: 'p1',
      ),
    );

    final missing = await http.post(_endpoint(server), body: '{}');
    final wrong = await http.post(
      _endpoint(server),
      headers: {HttpHeaders.authorizationHeader: 'Bearer wrong'},
      body: '{}',
    );

    expect(missing.statusCode, HttpStatus.unauthorized);
    expect(wrong.statusCode, HttpStatus.unauthorized);
  });

  test('browser import validates payload and request size', () async {
    final server = BrowserImportServer(port: 0, maxRequestBytes: 32);
    addTearDown(server.stop);
    await server.start(
      token: 'token',
      importer: (_) async => const BrowserProblemImportResult(
        created: true,
        problemId: 'p1',
      ),
    );
    final headers = {
      HttpHeaders.authorizationHeader: 'Bearer token',
      HttpHeaders.contentTypeHeader: 'application/json',
    };

    final invalid = await http.post(
      _endpoint(server),
      headers: headers,
      body: '{"title":"missing url"}',
    );
    final tooLarge = await http.post(
      _endpoint(server),
      headers: headers,
      body: jsonEncode({'url': 'https://example.com/${'x' * 100}'}),
    );

    expect(invalid.statusCode, HttpStatus.badRequest);
    expect(tooLarge.statusCode, HttpStatus.requestEntityTooLarge);
  });

  test('browser import supports CORS preflight', () async {
    final server = BrowserImportServer(port: 0);
    addTearDown(server.stop);
    await server.start(
      token: 'token',
      importer: (_) async => const BrowserProblemImportResult(
        created: true,
        problemId: 'p1',
      ),
    );

    final request = http.Request('OPTIONS', _endpoint(server));
    final response = await request.send();

    expect(response.statusCode, HttpStatus.noContent);
    expect(response.headers['access-control-allow-origin'], '*');
  });

  test('browser import reports port occupation', () async {
    final occupied = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(occupied.close);
    final server = BrowserImportServer(port: occupied.port);
    addTearDown(server.stop);

    expect(
      () => server.start(
        token: 'token',
        importer: (_) async => const BrowserProblemImportResult(
          created: true,
          problemId: 'p1',
        ),
      ),
      throwsA(isA<SocketException>()),
    );
  });

  test('browser import client reports when desktop service is not running',
      () async {
    final reservation =
        await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = reservation.port;
    await reservation.close();

    expect(
      () => http.post(
        Uri.parse('http://127.0.0.1:$port/v1/problems/import'),
      ),
      throwsA(anyOf(isA<http.ClientException>(), isA<SocketException>())),
    );
  });

  test('memory pairing token is stable until rotation', () async {
    final store = MemoryBrowserImportTokenStore();

    final first = await store.getOrCreateToken();
    final second = await store.getOrCreateToken();
    final rotated = await store.rotateToken();

    expect(first, second);
    expect(first, isNot(rotated));
    expect(first.length, greaterThanOrEqualTo(40));
  });
}

Uri _endpoint(BrowserImportServer server) {
  return Uri.parse(
    'http://127.0.0.1:${server.boundPort}/v1/problems/import',
  );
}
