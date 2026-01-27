// import 'dart:async';
// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:web_socket_channel/web_socket_channel.dart';
// import 'package:web_socket_channel/status.dart' as status;

// import '../../../data/token/shared_preferences.dart';

// class WebSocketNotificationService {
//   static final WebSocketNotificationService _instance = WebSocketNotificationService._internal();
//   factory WebSocketNotificationService() => _instance;
//   WebSocketNotificationService._internal();

//   WebSocketChannel? _channel;
//   StreamSubscription? _streamSubscription;
//   Timer? _reconnectTimer;
//   bool _isConnecting = false;
//   bool _shouldStayConnected = true;
//   int _reconnectAttempts = 0;
//   static const int _maxReconnectAttempts = 5;
//   static const Duration _initialReconnectDelay = Duration(seconds: 2);

//   // Callback for handling notifications
//   Function(dynamic)? onNotificationReceived;

//   Future<void> initialize() async {
//     // This can be called from main.dart after Firebase initialization
//     debugPrint('NotificationService initialized');
//   }

//   /// Connect to WebSocket notifications automatically
//   Future<void> connectToNotifications() async {
//     if (_isConnecting || _channel != null) {
//       debugPrint('Already connected or connecting to WebSocket');
//       return;
//     }

//     try {
//       _isConnecting = true;
//       _shouldStayConnected = true;

//       // Get the access token from SharedPreferences
//       final accessToken = await SharedPrefService.getAccessToken();

//       if (accessToken == null || accessToken.isEmpty) {
//         debugPrint('No access token found - skipping WebSocket connection');
//         _isConnecting = false;
//         return;
//       }

//       // Create WebSocket connection with token
//       final wsUrl = 'wss://testbackend.polzet.in/ws/notifications/?token=$accessToken';
//       _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

//       // Listen to messages
//       _streamSubscription = _channel!.stream.listen(
//         (message) {
//           debugPrint('Received notification: $message');
//           _handleNotification(message);
//           _reconnectAttempts = 0; // Reset attempts on successful message
//         },
//         onError: (error) {
//           debugPrint('WebSocket error: $error');
//           _handleDisconnection();
//         },
//         onDone: () {
//           debugPrint('WebSocket connection closed');
//           _handleDisconnection();
//         },
//         cancelOnError: false,
//       );

//       debugPrint('WebSocket connected successfully');
//       _isConnecting = false;
//       _reconnectAttempts = 0;
//     } catch (e) {
//       debugPrint('Failed to connect to WebSocket: $e');
//       _isConnecting = false;
//       _handleDisconnection();
//     }
//   }

//   void _handleNotification(dynamic message) {
//     try {
//       // Try to parse as JSON
//       final data = jsonDecode(message);
      
//       // Call the callback if set
//       if (onNotificationReceived != null) {
//         onNotificationReceived!(data);
//       }
      
//       // Handle different notification types here
//       // Example:
//       // if (data['type'] == 'like') { ... }
//       // if (data['type'] == 'comment') { ... }
      
//     } catch (e) {
//       debugPrint('Error parsing notification: $e');
//       // If not JSON, handle as plain text
//       if (onNotificationReceived != null) {
//         onNotificationReceived!(message);
//       }
//     }
//   }

//   void _handleDisconnection() {
//     _cleanup();
    
//     if (_shouldStayConnected && _reconnectAttempts < _maxReconnectAttempts) {
//       _scheduleReconnect();
//     } else if (_reconnectAttempts >= _maxReconnectAttempts) {
//       debugPrint('Max reconnection attempts reached. Stopping reconnection.');
//     }
//   }

//   void _scheduleReconnect() {
//     _reconnectTimer?.cancel();
    
//     // Exponential backoff: 2s, 4s, 8s, 16s, 32s
//     final delay = _initialReconnectDelay * (1 << _reconnectAttempts);
    
//     _reconnectAttempts++;
//     debugPrint('Scheduling reconnection attempt $_reconnectAttempts in ${delay.inSeconds}s');
    
//     _reconnectTimer = Timer(delay, () {
//       if (_shouldStayConnected) {
//         connectToNotifications();
//       }
//     });
//   }

//   void _cleanup() {
//     _streamSubscription?.cancel();
//     _streamSubscription = null;
//     _channel = null;
//     _isConnecting = false;
//   }

//   /// Send a message through WebSocket
//   void sendMessage(String message) {
//     if (_channel != null) {
//       try {
//         _channel!.sink.add(message);
//         debugPrint('Message sent: $message');
//       } catch (e) {
//         debugPrint('Error sending message: $e');
//       }
//     } else {
//       debugPrint('Cannot send message: WebSocket not connected');
//     }
//   }

//   /// Disconnect from WebSocket
//   void disconnect() {
//     _shouldStayConnected = false;
//     _reconnectTimer?.cancel();
//     _reconnectTimer = null;
    
//     try {
//       _channel?.sink.close(status.goingAway);
//     } catch (e) {
//       debugPrint('Error closing WebSocket: $e');
//     }
    
//     _cleanup();
//     debugPrint('WebSocket disconnected');
//   }

//   /// Check if WebSocket is connected
//   bool get isConnected => _channel != null;

//   /// Reset reconnection attempts (useful after successful login)
//   void resetReconnectionAttempts() {
//     _reconnectAttempts = 0;
//   }

//   /// Dispose of resources
//   void dispose() {
//     disconnect();
//   }
// }