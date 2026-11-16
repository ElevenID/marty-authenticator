Future<T> withBrowserStorageLock<T>(String name, Future<T> Function() action) =>
    Future.error(UnsupportedError('Browser storage requires a secure browser'));
