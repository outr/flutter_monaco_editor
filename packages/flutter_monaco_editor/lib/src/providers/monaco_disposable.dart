/// A handle returned by provider registrations. Call [dispose] to
/// unregister the provider.
abstract interface class MonacoDisposable {
  Future<void> dispose();
}

class MonacoDisposableCallback implements MonacoDisposable {
  MonacoDisposableCallback(this._callback);
  final Future<void> Function() _callback;
  bool _disposed = false;

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _callback();
  }
}
