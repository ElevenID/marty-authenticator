/*
 * Marty WASM Conditional Export
 *
 * Exports the web implementation on web, stub on other platforms.
 * Import this file to get the correct implementation automatically.
 *
 * Authors: Adam Burdett
 * Copyright (c) 2024-2025 Marty Trust Services
 */

export 'marty_wasm_stub.dart' if (dart.library.html) 'marty_wasm_interop.dart';
