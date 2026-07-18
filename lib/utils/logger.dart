import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart' as printer;

/// Application logging with credential-value redaction.
class Logger {
  Logger._();

  static final printer.Logger _printer = printer.Logger(
    printer: printer.PrettyPrinter(methodCount: 0, printEmojis: true),
  );

  static bool _verboseLogging = false;

  static void setVerboseLogging(bool value) => _verboseLogging = value;

  static void info(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? name,
    bool verbose = false,
  }) {
    if (!kDebugMode && !_verboseLogging && !verbose) return;
    _printer.i(
      _format(message, name),
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void warning(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? name,
    bool verbose = false,
  }) {
    if (!kDebugMode && !_verboseLogging && !verbose) return;
    _printer.w(
      _format(message, name),
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void debug(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? name,
    bool verbose = false,
  }) {
    if (!kDebugMode && !_verboseLogging && !verbose) return;
    _printer.d(
      _format(message, name),
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void error(
    String? message, {
    Object? error,
    Object? stackTrace,
    String? name,
  }) {
    final trace = switch (stackTrace) {
      StackTrace value => value,
      String value => StackTrace.fromString(value),
      _ => null,
    };
    _printer.e(
      _format(message ?? error?.toString() ?? 'Unknown error', name),
      error: error,
      stackTrace: trace,
    );
  }

  static String _format(String message, String? name) {
    final prefix = name == null ? '' : '[$name] ';
    return _redact('$prefix$message');
  }

  static String _redact(String text) {
    for (final key in filterParameterKeys) {
      final value = RegExp(
        r'(?<=' + key + r'[^A-Z0-9+/=,]*)[A-Z0-9+/=,:_-]+',
        caseSensitive: false,
      );
      text = text.replaceAll(value, '******');
    }
    return text;
  }
}

const filterParameterKeys = ['fbtoken', 'new_fb_token', 'secret'];
