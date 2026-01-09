// lib/screens/notification_screen.dart
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'api/services/notification/notification_services.dart';

class TestNotifications extends StatefulWidget {
  const TestNotifications({super.key});

  @override
  State<TestNotifications> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<TestNotifications> {
  String? _fcmToken;
  bool _isLoading = false;
  bool _notificationsEnabled = false;
  final _topicController = TextEditingController();
  final List<String> _subscribedTopics = [];
  @override
  void initState() {
    super.initState();
    _initializeNotificationSettings();
  }

  Future<void> _initializeNotificationSettings() async {
    setState(() => _isLoading = true);
    try {
      final token = await NotificationService().getToken();
      final enabled = await NotificationService().areNotificationsEnabled();

      setState(() {
        _fcmToken = token;
        _notificationsEnabled = enabled;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error loading notification settings: $e', isError: true);
    }
  }

  void _copyToken() {
    if (_fcmToken != null) {
      Clipboard.setData(ClipboardData(text: _fcmToken!));
      _showSnackBar('Token copied to clipboard!');
    }
  }

  Future<void> _requestPermission() async {
    setState(() => _isLoading = true);
    try {
      final granted = await NotificationService().requestPermission();
      setState(() {
        _notificationsEnabled = granted;
        _isLoading = false;
      });

      if (granted) {
        _showSnackBar('Notification permission granted!');
        await _initializeNotificationSettings();
      } else {
        _showSnackBar('Notification permission denied', isError: true);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error requesting permission: $e', isError: true);
    }
  }

  Future<void> _subscribeToTopic() async {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) {
      _showSnackBar('Please enter a topic name', isError: true);
      return;
    }

    try {
      await NotificationService().subscribeToTopic(topic);
      setState(() {
        if (!_subscribedTopics.contains(topic)) {
          _subscribedTopics.add(topic);
        }
      });
      _topicController.clear();
      _showSnackBar('Subscribed to $topic');
    } catch (e) {
      _showSnackBar('Error subscribing: $e', isError: true);
    }
  }

  Future<void> _unsubscribeFromTopic(String topic) async {
    try {
      await NotificationService().unsubscribeFromTopic(topic);
      setState(() {
        _subscribedTopics.remove(topic);
      });
      _showSnackBar('Unsubscribed from $topic');
    } catch (e) {
      _showSnackBar('Error unsubscribing: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Push Notifications'),
        centerTitle: true,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _initializeNotificationSettings,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildNotificationStatusCard(),
                    SizedBox(height: 16.h),
                    _buildFCMTokenCard(),
                    SizedBox(height: 16.h),
                    _buildTopicSubscriptionCard(),
                    SizedBox(height: 16.h),
                    _buildSubscribedTopicsList(),
                    SizedBox(height: 16.h),
                    _buildInstructionsCard(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildNotificationStatusCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _notificationsEnabled
                      ? Icons.notifications_active
                      : Icons.notifications_off,
                  color: _notificationsEnabled ? Colors.green : Colors.red,
                  size: 24.sp,
                ),
                SizedBox(width: 12.w),
                Text(
                  'Notification Status',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _notificationsEnabled ? 'Enabled' : 'Disabled',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: _notificationsEnabled ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (!_notificationsEnabled)
                  ElevatedButton.icon(
                    onPressed: _requestPermission,
                    icon: const Icon(Icons.notification_add),
                    label: const Text('Enable'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFCMTokenCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.vpn_key,
                  color: Theme.of(context).primaryColor,
                  size: 24.sp,
                ),
                SizedBox(width: 12.w),
                Text(
                  'FCM Device Token',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
              ),
              child: SelectableText(
                _fcmToken ?? 'Loading token...',
                style: TextStyle(
                  fontSize: 11.sp,
                  fontFamily: 'monospace',
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
                maxLines: 4,
              ),
            ),
            SizedBox(height: 12.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _fcmToken != null ? _copyToken : null,
                icon: const Icon(Icons.copy),
                label: const Text('Copy Token'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopicSubscriptionCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.topic, color: Colors.orange, size: 24.sp),
                SizedBox(width: 12.w),
                Text(
                  'Subscribe to Topic',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            TextField(
              controller: _topicController,
              decoration: InputDecoration(
                hintText: 'e.g., news, updates, promotions',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
                prefixIcon: const Icon(Icons.label_outline),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16.w,
                  vertical: 12.h,
                ),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _subscribeToTopic(),
            ),
            SizedBox(height: 12.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _subscribeToTopic,
                icon: const Icon(Icons.add),
                label: const Text('Subscribe'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscribedTopicsList() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.list_alt, color: Colors.purple, size: 24.sp),
                SizedBox(width: 12.w),
                Text(
                  'Subscribed Topics',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text(
                    '${_subscribedTopics.length}',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            _subscribedTopics.isEmpty
                ? Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      child: Column(
                        children: [
                          Icon(Icons.inbox, size: 48.sp, color: Colors.grey),
                          SizedBox(height: 8.h),
                          Text(
                            'No topics subscribed yet',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 14.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _subscribedTopics.length,
                    separatorBuilder: (context, index) => SizedBox(height: 8.h),
                    itemBuilder: (context, index) {
                      final topic = _subscribedTopics[index];
                      return Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.3),
                          ),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.purple.withOpacity(0.1),
                            child: Icon(
                              Icons.label,
                              color: Colors.purple,
                              size: 20.sp,
                            ),
                          ),
                          title: Text(
                            topic,
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          trailing: IconButton(
                            icon: Icon(
                              Icons.remove_circle,
                              color: Colors.red,
                              size: 20.sp,
                            ),
                            onPressed: () => _unsubscribeFromTopic(topic),
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 24.sp),
                SizedBox(width: 12.w),
                Text(
                  'How to Test Notifications',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            _buildStep('1', 'Copy your FCM token above'),
            _buildStep('2', 'Open Firebase Console > Cloud Messaging'),
            _buildStep('3', 'Click "Send your first message"'),
            _buildStep('4', 'Paste your token and send notification'),
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: Colors.blue,
                    size: 20.sp,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'Notifications work in all states: foreground, background, and terminated!',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.blue[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12.r,
            backgroundColor: Colors.blue,
            child: Text(
              number,
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 14.sp)),
          ),
        ],
      ),
    );
  }
}
