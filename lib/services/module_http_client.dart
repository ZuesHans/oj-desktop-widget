import 'dart:async';

import 'package:http/http.dart' as http;

/// A module can stop its requests without disposing the shared provider setup.
/// A fresh cancellation signal lets the same client work after re-enabling it.
class ModuleHttpClient extends http.BaseClient {
  ModuleHttpClient(this._inner);

  final http.Client _inner;
  bool _enabled = true;
  final _cancellations = StreamController<void>.broadcast(sync: true);

  void setEnabled(bool enabled) {
    if (enabled == _enabled) return;
    _enabled = enabled;
    if (!enabled) _cancellations.add(null);
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!_enabled) {
      return Future.error(http.RequestAbortedException(request.url));
    }
    final signal = Completer<void>();
    final subscription = _cancellations.stream.listen((_) {
      if (!signal.isCompleted) signal.complete();
    });
    final abort = signal.future;
    final http.BaseRequest outgoing;
    if (request is http.Request) {
      outgoing = http.AbortableRequest(
        request.method,
        request.url,
        abortTrigger: abort,
      )
        ..headers.addAll(request.headers)
        ..bodyBytes = request.bodyBytes
        ..followRedirects = request.followRedirects
        ..maxRedirects = request.maxRedirects
        ..persistentConnection = request.persistentConnection;
    } else {
      outgoing = request;
    }
    try {
      final response = await Future.any([
        _inner.send(outgoing),
        abort.then<http.StreamedResponse>(
          (_) => throw http.RequestAbortedException(request.url),
        ),
      ]);
      return http.StreamedResponse(
        _body(response.stream, subscription),
        response.statusCode,
        headers: response.headers,
        contentLength: response.contentLength,
        request: response.request,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
        reasonPhrase: response.reasonPhrase,
      );
    } catch (_) {
      await subscription.cancel();
      rethrow;
    }
  }

  Stream<List<int>> _body(
      Stream<List<int>> stream, StreamSubscription<void> subscription) async* {
    try {
      yield* stream;
    } finally {
      await subscription.cancel();
    }
  }

  @override
  void close() {
    setEnabled(false);
    _inner.close();
    unawaited(_cancellations.close());
  }
}
