/// Names only; ciphertext and encryption-key bytes never leave the backend.
class BrowserStorageInventory {
  const BrowserStorageInventory({required this.keys, required this.keyPresent});
  final List<String> keys;
  final bool keyPresent;
}
