import 'browser_storage_inventory.dart';

bool browserStorageBackendSupported(Object backend) => false;

Future<T> withBrowserStorageLock<T>(String name, Future<T> Function() action) =>
    Future.error(UnsupportedError('Browser storage requires a secure browser'));

Future<BrowserStorageInventory> browserStorageInventory(
  Map<String, String> options,
) =>
    Future.error(UnsupportedError('Browser storage requires a secure browser'));
