// // ignore_for_file: deprecated_member_use

// import 'package:flutter/material.dart';
// import 'dart:convert';
// import 'package:shared_preferences/shared_preferences.dart';

// import 'api/services/notification/notification_services.dart';
// import 'core/constants/app_colors.dart';
// import 'data/token/shared_preferences.dart';

// class TestNotificationsScreen extends StatefulWidget {
//   const TestNotificationsScreen({super.key});

//   @override
//   State<TestNotificationsScreen> createState() => _NotificationsScreenState();
// }

// class _NotificationsScreenState extends State<TestNotificationsScreen>
//     with WidgetsBindingObserver {
//   final NotificationService _notificationService = NotificationService();
//   final List<NotificationItem> _notifications = [];
//   bool _isWebSocketConnected = false;
//   String? _fcmToken;
//   final ScrollController _scrollController = ScrollController();
//   bool _isLoading = true;
//   final Set<String> _processedNotificationIds =
//       {}; // Track processed notifications

//   static const String _notificationsKey = 'stored_notifications';

//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addObserver(this); // Add lifecycle observer
//     _loadStoredNotifications();
//     _initializeNotifications();
//     _checkConnectionStatus();
//   }

//   @override
//   void dispose() {
//     WidgetsBinding.instance.removeObserver(this);
//     _scrollController.dispose();
//     super.dispose();
//   }

//   // Handle app lifecycle changes
//   @override
//   void didChangeAppLifecycleState(AppLifecycleState state) {
//     super.didChangeAppLifecycleState(state);

//     switch (state) {
//       case AppLifecycleState.resumed:
//         // App came to foreground
//         debugPrint('🟢 App resumed - reconnecting WebSocket');
//         _reconnectWebSocketIfNeeded();
//         break;
//       case AppLifecycleState.paused:
//         // App went to background
//         debugPrint('🔴 App paused - WebSocket will handle in background');
//         break;
//       case AppLifecycleState.inactive:
//       case AppLifecycleState.detached:
//       case AppLifecycleState.hidden:
//         break;
//     }
//   }

//   Future<void> _reconnectWebSocketIfNeeded() async {
//     final accessToken = await SharedPrefService.getAccessToken();
//     if (accessToken != null && accessToken.isNotEmpty) {
//       await _notificationService.connectToWebSocket(accessToken);
//       await Future.delayed(const Duration(milliseconds: 500));
//       _checkConnectionStatus();
//     }
//   }

//   Future<void> _loadStoredNotifications() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final storedData = prefs.getString(_notificationsKey);

//       if (storedData != null) {
//         final List<dynamic> decoded = jsonDecode(storedData);
//         final notifications = decoded
//             .map((item) => NotificationItem.fromJson(item))
//             .toList();

//         setState(() {
//           _notifications.addAll(notifications);
//           _isLoading = false;
//         });

//         // Populate processed IDs to avoid duplicates
//         _processedNotificationIds.addAll(notifications.map((n) => n.id));

//         debugPrint('✅ Loaded ${notifications.length} stored notifications');
//       } else {
//         setState(() {
//           _isLoading = false;
//         });
//         debugPrint('ℹ️ No stored notifications found');
//       }
//     } catch (e) {
//       debugPrint('❌ Error loading notifications: $e');
//       setState(() {
//         _isLoading = false;
//       });
//     }
//   }

//   Future<void> _saveNotifications() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final jsonList = _notifications.map((n) => n.toJson()).toList();
//       await prefs.setString(_notificationsKey, jsonEncode(jsonList));
//       debugPrint('✅ Saved ${_notifications.length} notifications');
//     } catch (e) {
//       debugPrint('❌ Error saving notifications: $e');
//     }
//   }

//   Future<void> _initializeNotifications() async {
//     // Set up callbacks for real-time notifications with deduplication
//     _notificationService.onNotificationReceived = (payload) {
//       // Only process if app is in foreground and WebSocket is connected
//       if (_isWebSocketConnected &&
//           payload.source == NotificationSource.webSocket) {
//         debugPrint('📨 WebSocket notification received (app online)');
//         _handleNewNotification(payload);
//       } else if (!_isWebSocketConnected &&
//           payload.source == NotificationSource.fcm) {
//         debugPrint(
//           '📨 FCM notification received (app offline or WS disconnected)',
//         );
//         _handleNewNotification(payload);
//       } else {
//         debugPrint('⚠️ Ignored duplicate notification from ${payload.source}');
//       }
//     };

//     _notificationService.onFCMMessageTap = (payload) {
//       _handleNotificationTap(payload);
//     };

//     // Get FCM token
//     _fcmToken = await _notificationService.getFCMToken();

//     setState(() {});
//   }

//   void _checkConnectionStatus() {
//     setState(() {
//       _isWebSocketConnected = _notificationService.isWebSocketConnected;
//     });
//   }

//   void _handleNewNotification(NotificationPayload payload) {
//     if (!mounted) return;

//     // Check for duplicate notifications
//     if (_processedNotificationIds.contains(payload.id)) {
//       debugPrint('⚠️ Duplicate notification ignored: ${payload.id}');
//       return;
//     }

//     final notification = NotificationItem(
//       id: payload.id,
//       title: payload.title,
//       message: payload.body,
//       timestamp: payload.timestamp,
//       source: payload.source == NotificationSource.webSocket
//           ? 'WebSocket'
//           : 'FCM',
//       type: payload.type,
//       data: payload.data,
//       isRead: false,
//     );

//     setState(() {
//       _notifications.insert(0, notification);
//       _processedNotificationIds.add(payload.id);
//     });

//     _saveNotifications();

//     debugPrint(
//       '✅ Added notification: ${payload.id} from ${notification.source}',
//     );

//     if (_scrollController.hasClients) {
//       _scrollController.animateTo(
//         0,
//         duration: const Duration(milliseconds: 300),
//         curve: Curves.easeOut,
//       );
//     }
//   }

//   void _handleNotificationTap(NotificationPayload payload) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text(payload.title),
//         content: SingleChildScrollView(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Text(payload.body),
//               const SizedBox(height: 16),
//               const Divider(),
//               const SizedBox(height: 8),
//               _buildDetailRow('Type', payload.type),
//               _buildDetailRow('Source', payload.source.toString()),
//               _buildDetailRow('Time', _formatTimestamp(payload.timestamp)),
//               if (payload.data.isNotEmpty) ...[
//                 const SizedBox(height: 8),
//                 const Text(
//                   'Data:',
//                   style: TextStyle(fontWeight: FontWeight.bold),
//                 ),
//                 const SizedBox(height: 4),
//                 Container(
//                   padding: const EdgeInsets.all(8),
//                   decoration: BoxDecoration(
//                     color: Colors.grey[100],
//                     borderRadius: BorderRadius.circular(4),
//                   ),
//                   child: Text(
//                     jsonEncode(payload.data),
//                     style: const TextStyle(fontSize: 12),
//                   ),
//                 ),
//               ],
//             ],
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: const Text('Close'),
//           ),
//         ],
//       ),
//     );
//   }

//   Future<void> _connectWebSocket() async {
//     final accessToken = await SharedPrefService.getAccessToken();

//     if (accessToken == null || accessToken.isEmpty) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('Please login first to connect WebSocket'),
//             backgroundColor: Colors.orange,
//           ),
//         );
//       }
//       return;
//     }

//     await _notificationService.connectToWebSocket(accessToken);
//     await Future.delayed(const Duration(milliseconds: 500));
//     _checkConnectionStatus();

//     if (mounted && _notificationService.isWebSocketConnected) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('WebSocket connected successfully'),
//           backgroundColor: Colors.green,
//         ),
//       );
//     }
//   }

//   void _disconnectWebSocket() {
//     _notificationService.disconnectWebSocket();
//     _checkConnectionStatus();

//     if (mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('WebSocket disconnected'),
//           backgroundColor: Colors.orange,
//         ),
//       );
//     }
//   }

//   Future<void> _clearNotifications() async {
//     final confirm = await showDialog<bool>(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Clear All Notifications'),
//         content: Text(
//           'Are you sure you want to delete all ${_notifications.length} notifications?',
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context, false),
//             child: const Text('Cancel'),
//           ),
//           TextButton(
//             onPressed: () => Navigator.pop(context, true),
//             style: TextButton.styleFrom(foregroundColor: Colors.red),
//             child: const Text('Clear All'),
//           ),
//         ],
//       ),
//     );

//     if (confirm == true) {
//       setState(() {
//         _notifications.clear();
//         _processedNotificationIds.clear();
//       });
//       await _saveNotifications();

//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('All notifications cleared'),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//     }
//   }

//   void _markAsRead(NotificationItem notification) {
//     final index = _notifications.indexWhere((n) => n.id == notification.id);
//     if (index != -1) {
//       setState(() {
//         _notifications[index] = notification.copyWith(isRead: true);
//       });
//       _saveNotifications();
//     }
//   }

//   Future<void> _markAllAsRead() async {
//     setState(() {
//       for (int i = 0; i < _notifications.length; i++) {
//         _notifications[i] = _notifications[i].copyWith(isRead: true);
//       }
//     });
//     await _saveNotifications();

//     if (mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('All notifications marked as read'),
//           backgroundColor: Colors.blue,
//         ),
//       );
//     }
//   }

//   Color _getNotificationColor(String type) {
//     final normalizedType = type.toLowerCase();
//     switch (normalizedType) {
//       case 'like':
//         return Colors.pink;
//       case 'comment':
//         return Colors.blue;
//       case 'follow':
//         return Colors.purple;
//       case 'post':
//         return Colors.orange;
//       case 'chat':
//       case 'new_message':
//         return Colors.green;
//       case 'mention':
//         return Colors.teal;
//       default:
//         return Colors.grey;
//     }
//   }

//   IconData _getNotificationIcon(String type) {
//     final normalizedType = type.toLowerCase();
//     switch (normalizedType) {
//       case 'like':
//         return Icons.favorite;
//       case 'comment':
//         return Icons.comment;
//       case 'follow':
//         return Icons.person_add;
//       case 'mention':
//         return Icons.alternate_email;
//       case 'post':
//         return Icons.article;
//       case 'chat':
//       case 'new_message':
//         return Icons.message;
//       default:
//         return Icons.notifications;
//     }
//   }

//   int get _unreadCount => _notifications.where((n) => !n.isRead).length;

//   @override
//   Widget build(BuildContext context) {
//     if (_isLoading) {
//       return Scaffold(
//         appBar: AppBar(title: const Text('Notifications Test')),
//         body: const Center(child: CircularProgressIndicator()),
//       );
//     }

//     return Scaffold(
//       appBar: AppBar(
//         title: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text('Notifications Test'),
//             if (_unreadCount > 0)
//               Text(
//                 '$_unreadCount unread',
//                 style: const TextStyle(fontSize: 12, color: Colors.white70),
//               ),
//           ],
//         ),
//         elevation: 2,
//         actions: [
//           if (_notifications.isNotEmpty && _unreadCount > 0)
//             IconButton(
//               icon: const Icon(Icons.done_all),
//               tooltip: 'Mark all as read',
//               onPressed: _markAllAsRead,
//             ),
//           if (_notifications.isNotEmpty)
//             IconButton(
//               icon: const Icon(Icons.clear_all),
//               tooltip: 'Clear all',
//               onPressed: _clearNotifications,
//             ),
//           IconButton(
//             icon: const Icon(Icons.refresh),
//             tooltip: 'Refresh status',
//             onPressed: _checkConnectionStatus,
//           ),
//         ],
//       ),
//       body: Column(
//         children: [
//           // Status Panel
//           Container(
//             width: double.infinity,
//             padding: const EdgeInsets.all(16),
//             decoration: BoxDecoration(
//               color: Colors.grey[100],
//               border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
//             ),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Row(
//                   children: [
//                     Icon(
//                       Icons.wifi,
//                       color: _isWebSocketConnected ? Colors.green : Colors.red,
//                       size: 20,
//                     ),
//                     const SizedBox(width: 8),
//                     Text(
//                       'WebSocket: ${_isWebSocketConnected ? "Connected" : "Disconnected"}',
//                       style: TextStyle(
//                         fontWeight: FontWeight.bold,
//                         color: _isWebSocketConnected
//                             ? Colors.green
//                             : Colors.red,
//                       ),
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 8),
//                 Row(
//                   children: [
//                     Icon(
//                       Icons.notifications_active,
//                       color: _fcmToken != null ? Colors.green : Colors.orange,
//                       size: 20,
//                     ),
//                     const SizedBox(width: 8),
//                     Text(
//                       'FCM: ${_fcmToken != null ? "Ready" : "Not Ready"}',
//                       style: TextStyle(
//                         fontWeight: FontWeight.bold,
//                         color: _fcmToken != null ? Colors.green : Colors.orange,
//                       ),
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 8),
//                 Container(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 8,
//                     vertical: 4,
//                   ),
//                   decoration: BoxDecoration(
//                     color: _isWebSocketConnected
//                         ? Colors.green[50]
//                         : Colors.orange[50],
//                     borderRadius: BorderRadius.circular(4),
//                     border: Border.all(
//                       color: _isWebSocketConnected
//                           ? Colors.green
//                           : Colors.orange,
//                     ),
//                   ),
//                   child: Text(
//                     _isWebSocketConnected
//                         ? '📡 Receiving via WebSocket'
//                         : '📱 Receiving via FCM',
//                     style: TextStyle(
//                       fontSize: 12,
//                       fontWeight: FontWeight.bold,
//                       color: _isWebSocketConnected
//                           ? Colors.green[900]
//                           : Colors.orange[900],
//                     ),
//                   ),
//                 ),
//                 if (_fcmToken != null) ...[
//                   const SizedBox(height: 8),
//                   Text(
//                     'Token: ${_fcmToken!.substring(0, 30)}...',
//                     style: TextStyle(fontSize: 12, color: Colors.grey[600]),
//                   ),
//                 ],
//                 if (_notifications.isNotEmpty) ...[
//                   const SizedBox(height: 8),
//                   Text(
//                     'Total: ${_notifications.length} notifications',
//                     style: TextStyle(
//                       fontSize: 12,
//                       color: Colors.grey[700],
//                       fontWeight: FontWeight.w500,
//                     ),
//                   ),
//                 ],
//               ],
//             ),
//           ),

//           // Control Buttons
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//             child: Wrap(
//               spacing: 8,
//               runSpacing: 8,
//               children: [
//                 ElevatedButton.icon(
//                   onPressed: _isWebSocketConnected ? null : _connectWebSocket,
//                   icon: const Icon(Icons.link, size: 18),
//                   label: const Text('Connect WS'),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.blue,
//                     foregroundColor: Colors.white,
//                     disabledBackgroundColor: Colors.grey,
//                   ),
//                 ),
//                 ElevatedButton.icon(
//                   onPressed: _isWebSocketConnected
//                       ? _disconnectWebSocket
//                       : null,
//                   icon: const Icon(Icons.link_off, size: 18),
//                   label: const Text('Disconnect WS'),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.red,
//                     foregroundColor: Colors.white,
//                     disabledBackgroundColor: Colors.grey,
//                   ),
//                 ),
//               ],
//             ),
//           ),

//           const Divider(height: 1),

//           // Notifications List
//           Expanded(
//             child: _notifications.isEmpty
//                 ? Center(
//                     child: Column(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         Icon(
//                           Icons.notifications_none,
//                           size: 80,
//                           color: Colors.grey[400],
//                         ),
//                         const SizedBox(height: 16),
//                         Text(
//                           'No notifications yet',
//                           style: TextStyle(
//                             fontSize: 18,
//                             color: Colors.grey[600],
//                             fontWeight: FontWeight.w500,
//                           ),
//                         ),
//                         const SizedBox(height: 8),
//                         Text(
//                           'Notifications will appear here',
//                           style: TextStyle(
//                             fontSize: 14,
//                             color: Colors.grey[500],
//                           ),
//                         ),
//                       ],
//                     ),
//                   )
//                 : ListView.builder(
//                     controller: _scrollController,
//                     itemCount: _notifications.length,
//                     itemBuilder: (context, index) {
//                       final notification = _notifications[index];
//                       return _buildNotificationCard(notification);
//                     },
//                   ),
//           ),
//         ],
//       ),
//     );
//   }

//   Future<void> _deleteNotification(NotificationItem notification) async {
//     final index = _notifications.indexWhere((n) => n.id == notification.id);
//     if (index == -1) return;

//     setState(() {
//       _notifications.removeAt(index);
//       _processedNotificationIds.remove(notification.id);
//     });

//     await _saveNotifications();

//     if (mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: const Text('Notification deleted'),
//           backgroundColor: Colors.red,
//           duration: const Duration(seconds: 3),
//           action: SnackBarAction(
//             label: 'Undo',
//             textColor: Colors.white,
//             onPressed: () {
//               setState(() {
//                 _notifications.insert(index, notification);
//                 _processedNotificationIds.add(notification.id);
//               });
//               _saveNotifications();
//             },
//           ),
//         ),
//       );
//     }
//   }

//   Widget _buildNotificationCard(NotificationItem notification) {
//     final color = _getNotificationColor(notification.type);
//     final icon = _getNotificationIcon(notification.type);
//     final notificationData = notification.data;

//     final postDescription = notificationData['post_description'] ?? '';
//     final body = notificationData['body'] ?? notification.message;

//     return Dismissible(
//       key: Key(notification.id),
//       direction: DismissDirection.endToStart,
//       background: Container(
//         alignment: Alignment.centerRight,
//         padding: const EdgeInsets.only(right: 20),
//         margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//         decoration: BoxDecoration(
//           color: Colors.transparent,
//           borderRadius: BorderRadius.circular(4),
//         ),
//         child: const Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(Icons.delete, color: AppColors.primaryColor, size: 28),
//             SizedBox(height: 4),
//             Text(
//               'Delete',
//               style: TextStyle(
//                 color: AppColors.primaryColor,
//                 fontWeight: FontWeight.bold,
//                 fontSize: 12,
//               ),
//             ),
//           ],
//         ),
//       ),
//       // confirmDismiss: (direction) async {
//       //   return await showDialog<bool>(
//       //     context: context,
//       //     builder: (context) => AlertDialog(
//       //       title: const Text('Delete Notification'),
//       //       content: const Text(
//       //         'Are you sure you want to delete this notification?',
//       //       ),
//       //       actions: [
//       //         TextButton(
//       //           onPressed: () => Navigator.pop(context, false),
//       //           child: const Text('Cancel'),
//       //         ),
//       //         TextButton(
//       //           onPressed: () => Navigator.pop(context, true),
//       //           style: TextButton.styleFrom(foregroundColor: Colors.red),
//       //           child: const Text('Delete'),
//       //         ),
//       //       ],
//       //     ),
//       //   );
//       // },
//       onDismissed: (direction) {
//         _deleteNotification(notification);
//       },
//       child: Card(
//         margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//         elevation: 2,
//         color: notification.isRead ? Colors.white : Colors.blue[50],
//         child: InkWell(
//           onTap: () {
//             _markAsRead(notification);
//           },
//           borderRadius: BorderRadius.circular(4),
//           child: Padding(
//             padding: const EdgeInsets.all(12),
//             child: Row(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 // Icon
//                 const SizedBox(width: 12),
//                 // Content
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Row(
//                         children: [
//                           Expanded(
//                             child: Text(
//                               body,
//                               style: TextStyle(
//                                 fontSize: 16,
//                                 fontWeight: notification.isRead
//                                     ? FontWeight.normal
//                                     : FontWeight.bold,
//                                 color: Colors.black87,
//                               ),
//                             ),
//                           ),
//                           if (!notification.isRead)
//                             Container(
//                               width: 8,
//                               height: 8,
//                               margin: const EdgeInsets.only(left: 8),
//                               decoration: const BoxDecoration(
//                                 color: Colors.blue,
//                                 shape: BoxShape.circle,
//                               ),
//                             ),
//                           Container(
//                             margin: const EdgeInsets.only(left: 8),
//                             padding: const EdgeInsets.symmetric(
//                               horizontal: 8,
//                               vertical: 4,
//                             ),
//                             decoration: BoxDecoration(
//                               color: notification.source == 'WebSocket'
//                                   ? Colors.blue[100]
//                                   : Colors.green[100],
//                               borderRadius: BorderRadius.circular(12),
//                             ),
//                             child: Text(
//                               notification.source == 'WebSocket' ? 'WS' : 'FCM',
//                               style: TextStyle(
//                                 fontSize: 9,
//                                 fontWeight: FontWeight.bold,
//                                 color: notification.source == 'WebSocket'
//                                     ? Colors.blue[900]
//                                     : Colors.green[900],
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                       if (postDescription.isNotEmpty) ...[
//                         const SizedBox(height: 4),
//                         Text(
//                           postDescription,
//                           style: TextStyle(
//                             fontSize: 14,
//                             color: Colors.grey[600],
//                           ),
//                           maxLines: 2,
//                           overflow: TextOverflow.ellipsis,
//                         ),
//                       ],
//                       const SizedBox(height: 8),
//                       Row(
//                         children: [
//                           Icon(
//                             Icons.access_time,
//                             size: 14,
//                             color: Colors.grey[500],
//                           ),
//                           const SizedBox(width: 4),
//                           Text(
//                             _formatTimestamp(notification.timestamp),
//                             style: TextStyle(
//                               fontSize: 12,
//                               color: Colors.grey[600],
//                             ),
//                           ),
//                           const SizedBox(width: 12),
//                           Container(
//                             padding: const EdgeInsets.symmetric(
//                               horizontal: 6,
//                               vertical: 2,
//                             ),
//                             decoration: BoxDecoration(
//                               color: color.withOpacity(0.2),
//                               borderRadius: BorderRadius.circular(8),
//                             ),
//                             child: Text(
//                               notification.type.toUpperCase(),
//                               style: TextStyle(
//                                 fontSize: 10,
//                                 fontWeight: FontWeight.bold,
//                                 color: color,
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildDetailRow(String label, String value) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 4),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           SizedBox(
//             width: 60,
//             child: Text(
//               '$label:',
//               style: TextStyle(
//                 fontWeight: FontWeight.bold,
//                 color: Colors.grey[700],
//               ),
//             ),
//           ),
//           Expanded(child: Text(value)),
//         ],
//       ),
//     );
//   }

//   String _formatTimestamp(DateTime timestamp) {
//     final now = DateTime.now();
//     final difference = now.difference(timestamp);

//     if (difference.inSeconds < 60) {
//       return 'Just now';
//     } else if (difference.inMinutes < 60) {
//       return '${difference.inMinutes}m ago';
//     } else if (difference.inHours < 24) {
//       return '${difference.inHours}h ago';
//     } else {
//       return '${timestamp.day}/${timestamp.month} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
//     }
//   }
// }

// // Enhanced Notification Item Model with JSON serialization
// class NotificationItem {
//   final String id;
//   final String title;
//   final String message;
//   final DateTime timestamp;
//   final String source;
//   final String type;
//   final Map<String, dynamic> data;
//   final bool isRead;

//   NotificationItem({
//     required this.id,
//     required this.title,
//     required this.message,
//     required this.timestamp,
//     required this.source,
//     required this.type,
//     required this.data,
//     this.isRead = false,
//   });

//   Map<String, dynamic> toJson() {
//     return {
//       'id': id,
//       'title': title,
//       'message': message,
//       'timestamp': timestamp.toIso8601String(),
//       'source': source,
//       'type': type,
//       'data': data,
//       'isRead': isRead,
//     };
//   }

//   factory NotificationItem.fromJson(Map<String, dynamic> json) {
//     return NotificationItem(
//       id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
//       title: json['title'] ?? 'Notification',
//       message: json['message'] ?? '',
//       timestamp: DateTime.parse(json['timestamp']),
//       source: json['source'] ?? 'Unknown',
//       type: json['type'] ?? 'general',
//       data: Map<String, dynamic>.from(json['data'] ?? {}),
//       isRead: json['isRead'] ?? false,
//     );
//   }

//   NotificationItem copyWith({
//     String? id,
//     String? title,
//     String? message,
//     DateTime? timestamp,
//     String? source,
//     String? type,
//     Map<String, dynamic>? data,
//     bool? isRead,
//   }) {
//     return NotificationItem(
//       id: id ?? this.id,
//       title: title ?? this.title,
//       message: message ?? this.message,
//       timestamp: timestamp ?? this.timestamp,
//       source: source ?? this.source,
//       type: type ?? this.type,
//       data: data ?? this.data,
//       isRead: isRead ?? this.isRead,
//     );
//   }
// }
