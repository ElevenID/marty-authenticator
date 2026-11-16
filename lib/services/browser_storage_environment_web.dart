import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;
import 'package:flutter_secure_storage_web/flutter_secure_storage_web.dart';
import 'browser_storage_inventory.dart';

bool browserStorageBackendSupported(Object backend) =>
    backend is FlutterSecureStorageWeb;

Future<BrowserStorageInventory> browserStorageInventory(
  Map<String, String> options,
) async {
  if (!web.window.isSecureContext) {
    throw UnsupportedError('Browser storage requires HTTPS or localhost');
  }
  final storage = options['useSessionStorage'] == 'true'
      ? web.window.sessionStorage
      : web.window.localStorage;
  final namespace = options['publicKey']!;
  final prefix = '$namespace.';
  final keys = <String>[];
  for (var index = 0; index < storage.length; index++) {
    final key = storage.key(index);
    if (key != null && key.startsWith(prefix)) {
      if (keys.length >= 1024 ||
          (storage.getItem(key)?.length ?? 0) > 3 * 1024 * 1024) {
        throw StateError('Encrypted browser storage exceeds safety bounds');
      }
      keys.add(key.substring(prefix.length));
    }
  }
  return BrowserStorageInventory(
    keys: keys,
    keyPresent: storage.getItem(namespace) != null,
  );
}

/// Serialize the new application's storage across tabs and workers as well as
/// within one isolate. Older application tabs must be closed before upgrading;
/// they do not participate in this lock protocol.
Future<T> withBrowserStorageLock<T>(
  String name,
  Future<T> Function() action,
) async {
  if (!web.window.isSecureContext) {
    throw UnsupportedError('Browser storage requires HTTPS or localhost');
  }
  late T result;
  Object? failure;
  StackTrace? failureStack;
  var completed = false;
  final abort = web.AbortController();
  final timer = Timer(const Duration(seconds: 30), () => abort.abort());
  Future<JSAny?> invoke() async {
    timer.cancel();
    try {
      result = await action();
    } catch (error, stack) {
      failure = error;
      failureStack = stack;
    }
    completed = true;
    return null;
  }

  try {
    await web.window.navigator.locks
        .request(
          name,
          web.LockOptions(mode: 'exclusive', signal: abort.signal),
          ((web.Lock? lock) => invoke().toJS).toJS,
        )
        .toDart;
  } catch (_) {
    throw StateError('Exclusive browser storage is unavailable');
  } finally {
    timer.cancel();
  }
  if (failure != null) Error.throwWithStackTrace(failure!, failureStack!);
  if (!completed) throw StateError('Exclusive browser storage did not execute');
  return result;
}
