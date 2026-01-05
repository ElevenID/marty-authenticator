import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

/// Configuration for the SSE push service
class SSEPushConfig {
  final String apiBaseUrl;
  final Duration reconnectMinDelay;
  final Duration reconnectMaxDelay;
  final Duration connectionTimeout;

  const SSEPushConfig({
    this.apiBaseUrl = 'http://localhost:8000',
    this.reconnectMinDelay = const Duration(seconds: 1),
    this.reconnectMaxDelay = const Duration(seconds: 30),
    this.connectionTimeout = const Duration(seconds: 30),
  });

  /// Create config from environment variables
  factory SSEPushConfig.fromEnvironment() {
    return SSEPushConfig(
      apiBaseUrl: const String.fromEnvironment(
        'MARTY_API_URL',
        defaultValue: 'http://localhost:8000',
      ),
    );
  }
}

/// A push challenge received via SSE
///
/// This class wraps the raw challenge data for processing.
/// The actual MartyChallenge model should be used for typed access.
class SSEPushChallenge {
  final String challengeId;
  final String title;
  final String question;
  final String nonce;
  final String? credentialId;
  final int ttlSeconds;
  final Map<String, dynamic> data;
  final DateTime receivedAt;

  SSEPushChallenge({
    required this.challengeId,
    required this.title,
    required this.question,
    required this.nonce,
    this.credentialId,
    this.ttlSeconds = 120,
    this.data = const {},
    DateTime? receivedAt,
  }) : receivedAt = receivedAt ?? DateTime.now();

  factory SSEPushChallenge.fromJson(Map<String, dynamic> json) {
    // Support both marty/v1 format and legacy format
    final isMartyFormat =
        json['format']?.toString().startsWith('marty/') ?? false;

    if (isMartyFormat) {
      // Marty/v1 format - data is in the root or nested 'data' field
      final rawData = json['data'] as Map<String, dynamic>? ?? json;

      // Parse ttl_seconds (may be string from FCM or int)
      int ttlSeconds = 120;
      final ttlValue = rawData['ttl_seconds'] ?? json['ttl_seconds'];
      if (ttlValue != null) {
        ttlSeconds = ttlValue is int
            ? ttlValue
            : int.tryParse(ttlValue.toString()) ?? 120;
      }

      return SSEPushChallenge(
        challengeId:
            rawData['challenge_id']?.toString() ??
            json['challenge_id']?.toString() ??
            '',
        title: rawData['title']?.toString() ?? json['title']?.toString() ?? '',
        question:
            rawData['question']?.toString() ??
            json['question']?.toString() ??
            '',
        nonce: rawData['nonce']?.toString() ?? json['nonce']?.toString() ?? '',
        credentialId:
            rawData['credential_id']?.toString() ??
            json['credential_id']?.toString(),
        ttlSeconds: ttlSeconds,
        data: json, // Store full JSON for MartyChallenge parsing
      );
    }

    // Legacy format (nested data field)
    final data = json['data'] as Map<String, dynamic>? ?? {};
    return SSEPushChallenge(
      challengeId:
          data['challenge_id'] as String? ?? json['id'] as String? ?? '',
      title: json['title'] as String? ?? data['title'] as String? ?? '',
      question: data['question'] as String? ?? json['body'] as String? ?? '',
      nonce: data['nonce'] as String? ?? '',
      credentialId: data['credential_id'] as String?,
      ttlSeconds: data['ttl_seconds'] as int? ?? 120,
      data: json, // Store full JSON for MartyChallenge parsing
    );
  }

  bool get isExpired {
    final expiresAt = receivedAt.add(Duration(seconds: ttlSeconds));
    return DateTime.now().isAfter(expiresAt);
  }
}

/// SSE Push Service for real-time push notification delivery
///
/// This service provides an alternative to Firebase Cloud Messaging for
/// web-based development and testing. It connects to the Marty backend
/// via Server-Sent Events and receives push challenges in real-time.
///
/// Features:
/// - Automatic reconnection with exponential backoff
/// - Heartbeat handling to detect stale connections
/// - Challenge stream for reactive handling
class SSEPushService {
  final SSEPushConfig config;
  final Logger _logger = Logger('SSEPushService');

  http.Client? _client;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;

  int _reconnectAttempts = 0;
  bool _isConnecting = false;
  bool _shouldReconnect = true;
  String? _currentDeviceId;

  final StreamController<SSEPushChallenge> _challengeController =
      StreamController<SSEPushChallenge>.broadcast();

  final StreamController<SSEConnectionState> _stateController =
      StreamController<SSEConnectionState>.broadcast();

  SSEConnectionState _connectionState = SSEConnectionState.disconnected;

  SSEPushService({SSEPushConfig? config})
    : config = config ?? SSEPushConfig.fromEnvironment();

  /// Stream of push challenges received via SSE
  Stream<SSEPushChallenge> get challenges => _challengeController.stream;

  /// Stream of connection state changes
  Stream<SSEConnectionState> get connectionState => _stateController.stream;

  /// Current connection state
  SSEConnectionState get currentState => _connectionState;

  /// Whether currently connected
  bool get isConnected => _connectionState == SSEConnectionState.connected;

  /// Connect to the SSE endpoint for the given device
  void connect(String deviceId) {
    if (_isConnecting) {
      _logger.warning('Already connecting, ignoring duplicate connect call');
      return;
    }

    _currentDeviceId = deviceId;
    _shouldReconnect = true;
    _reconnectAttempts = 0;

    _doConnect(deviceId);
  }

  /// Disconnect from the SSE endpoint
  void disconnect() {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _subscription?.cancel();
    _subscription = null;
    _client?.close();
    _client = null;
    _currentDeviceId = null;

    _updateState(SSEConnectionState.disconnected);
    _logger.info('SSE disconnected');
  }

  void _doConnect(String deviceId) async {
    if (_isConnecting) return;
    _isConnecting = true;

    _updateState(SSEConnectionState.connecting);
    _logger.info('Connecting to SSE for device: $deviceId');

    try {
      _client = http.Client();

      final uri = Uri.parse(
        '${config.apiBaseUrl}/api/events/push',
      ).replace(queryParameters: {'device_id': deviceId});

      final request = http.Request('GET', uri);
      request.headers['Accept'] = 'text/event-stream';
      request.headers['Cache-Control'] = 'no-cache';

      final response = await _client!
          .send(request)
          .timeout(
            config.connectionTimeout,
            onTimeout: () {
              throw TimeoutException('Connection timeout');
            },
          );

      if (response.statusCode != 200) {
        throw Exception('SSE connection failed: ${response.statusCode}');
      }

      _isConnecting = false;
      _reconnectAttempts = 0;
      _updateState(SSEConnectionState.connected);
      _logger.info('SSE connected successfully');

      _subscription = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            _handleLine,
            onError: _handleError,
            onDone: _handleDone,
            cancelOnError: false,
          );
    } catch (e) {
      _isConnecting = false;
      _logger.warning('SSE connection error: $e');
      _handleError(e);
    }
  }

  String _currentEventType = '';
  final StringBuffer _currentData = StringBuffer();

  void _handleLine(String line) {
    if (line.startsWith('event: ')) {
      _currentEventType = line.substring(7).trim();
    } else if (line.startsWith('data: ')) {
      _currentData.write(line.substring(6));
    } else if (line.isEmpty && _currentData.isNotEmpty) {
      // End of event
      _processEvent(_currentEventType, _currentData.toString());
      _currentEventType = '';
      _currentData.clear();
    } else if (line.startsWith(': heartbeat') || line.startsWith(':')) {
      // Heartbeat or comment - connection is alive
      _logger.fine('Heartbeat received');
    }
  }

  void _processEvent(String eventType, String data) {
    _logger.fine('SSE event received: $eventType');

    if (eventType == 'push_challenge' || eventType.isEmpty) {
      try {
        final json = jsonDecode(data) as Map<String, dynamic>;
        final challenge = SSEPushChallenge.fromJson(json);

        if (!challenge.isExpired) {
          _challengeController.add(challenge);
          _logger.info('Push challenge received: ${challenge.challengeId}');
        } else {
          _logger.warning(
            'Ignoring expired challenge: ${challenge.challengeId}',
          );
        }
      } catch (e) {
        _logger.warning('Failed to parse SSE event: $e');
      }
    }
  }

  void _handleError(dynamic error) {
    _logger.warning('SSE error: $error');
    _updateState(SSEConnectionState.error);

    _subscription?.cancel();
    _subscription = null;
    _client?.close();
    _client = null;

    _scheduleReconnect();
  }

  void _handleDone() {
    _logger.info('SSE stream ended');
    _updateState(SSEConnectionState.disconnected);

    _subscription = null;
    _client?.close();
    _client = null;

    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (!_shouldReconnect || _currentDeviceId == null) {
      return;
    }

    _reconnectTimer?.cancel();

    // Exponential backoff with jitter
    final delay = _calculateBackoff();
    _logger.info(
      'Scheduling reconnect in ${delay.inMilliseconds}ms (attempt ${_reconnectAttempts + 1})',
    );

    _reconnectTimer = Timer(delay, () {
      _reconnectAttempts++;
      if (_currentDeviceId != null && _shouldReconnect) {
        _doConnect(_currentDeviceId!);
      }
    });
  }

  Duration _calculateBackoff() {
    // Exponential backoff: 2^attempt * minDelay, capped at maxDelay
    final exponentialDelay =
        config.reconnectMinDelay.inMilliseconds *
        pow(2, _reconnectAttempts).toInt();

    final cappedDelay = min(
      exponentialDelay,
      config.reconnectMaxDelay.inMilliseconds,
    );

    // Add jitter (±25%)
    final jitter = (cappedDelay * 0.25 * (Random().nextDouble() * 2 - 1))
        .toInt();

    return Duration(milliseconds: cappedDelay + jitter);
  }

  void _updateState(SSEConnectionState state) {
    if (_connectionState != state) {
      _connectionState = state;
      _stateController.add(state);
    }
  }

  /// Dispose of the service and clean up resources
  void dispose() {
    disconnect();
    _challengeController.close();
    _stateController.close();
  }
}

/// Connection state for SSE
enum SSEConnectionState { disconnected, connecting, connected, error }
