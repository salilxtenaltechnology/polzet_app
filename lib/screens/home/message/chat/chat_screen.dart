// ignore_for_file: deprecated_member_use, must_be_immutable

import 'package:feather_icons/feather_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../../core/constants/app_images.dart';
import '../../../../mixin/utility_mixins.dart';
import '../../../../models/message/message_model.dart';
import '../../../../widgets/button/back_button.dart';
import 'chat_details.dart';

class ChatScreen extends StatefulWidget {
  String? memberName;
  ChatScreen({super.key, required this.memberName});

  @override
  State<ChatScreen> createState() => ChatScreenState();
}

class ChatScreenState extends State<ChatScreen> with UtilityMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(
        text: _messageController.text.trim(),
        timestamp: DateTime.now(),
        isSentByMe: true,
      ));
    });

    _messageController.clear();
    
    // Scroll to bottom after sending message
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    // Simulate receiving a reply after 2 seconds (for demo purposes)
    _simulateReceivedMessage();
  }

  void _simulateReceivedMessage() {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
            text: "Thanks for your message! 👍",
            timestamp: DateTime.now(),
            isSentByMe: false,
          ));
        });

        // Scroll to bottom
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });
  }

  String _formatTime(DateTime dateTime) {
    return DateFormat('HH:mm').format(dateTime);
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Align(
      alignment: message.isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4.h, horizontal: 12.w),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        constraints: BoxConstraints(maxWidth: 250.w),
        decoration: BoxDecoration(
          color: message.isSentByMe
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.tertiaryContainer,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(12.r),
            topRight: Radius.circular(12.r),
            bottomLeft: message.isSentByMe ? Radius.circular(12.r) : const Radius.circular(0),
            bottomRight: message.isSentByMe ? const Radius.circular(0) : Radius.circular(12.r),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: message.isSentByMe
                    ? Colors.white
                    : Theme.of(context).colorScheme.onBackground,
                fontSize: 13.sp,
                fontWeight: FontWeight.w400,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              _formatTime(message.timestamp),
              style: TextStyle(
                color: message.isSentByMe
                    ? Colors.white.withOpacity(0.7)
                    : const Color(0XFF8593A8),
                fontSize: 10.sp,
                fontWeight: FontWeight.w300,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: true,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        appBar: AppBar(
          toolbarHeight: 60.h,
          automaticallyImplyLeading: false,
          leadingWidth: double.infinity,
          leading: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(width: 12.w),
              const PrimaryBackButton(),
              CircleAvatar(
                radius: 20.r,
                backgroundColor: const Color(0XFFEEEEEE),
                foregroundColor: const Color(0XFFEEEEEE),
                backgroundImage: const AssetImage(Assets.assetsImagesPeople3),
              ),
              SizedBox(width: 7.w),
              GestureDetector(
                onTap: () {
                  navigationPush(context, ChatDetails(memberName: widget.memberName));
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(widget.memberName!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onBackground,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600)),
                    Text('Online',
                        style: TextStyle(
                            color: Colors.green,
                            fontSize: 11.2.sp,
                            fontWeight: FontWeight.w300))
                  ],
                ),
              )
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.background,
          surfaceTintColor: Theme.of(context).colorScheme.background,
          actions: [
            Icon(FeatherIcons.video, size: 20.sp),
            SizedBox(width: 15.w),
            Icon(FeatherIcons.phone, size: 18.sp),
            SizedBox(width: 15.w),
          ],
        ),
        body: Column(
          children: [
            // Messages List
            Expanded(
              child: _messages.isEmpty
                  ? Center(
                      child: Text(
                        'No messages yet. Start the conversation!',
                        style: TextStyle(
                          color: const Color(0XFF8593A8),
                          fontSize: 13.sp,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.symmetric(vertical: 8.h),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        return _buildMessageBubble(_messages[index]);
                      },
                    ),
            ),
            
            // Message Input Field
            Container(
              height: 37.h,
              width: double.infinity,
              margin: const EdgeInsets.all(12).w,
              padding: EdgeInsets.symmetric(horizontal: 10.w),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Type here...',
                        hintStyle: TextStyle(
                          color: Color(0XFF8593A8),
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      // Handle image picking
                    },
                    child: Icon(
                      FeatherIcons.image,
                      size: 20.spMax,
                      color: const Color(0XFF8593A8),
                    ),
                  ),
                  SizedBox(width: 7.w),
                  GestureDetector(
                    onTap: () {
                      // Handle emoji picker
                    },
                    child: Icon(
                      FeatherIcons.smile,
                      size: 20.spMax,
                      color: const Color(0XFF8593A8),
                    ),
                  ),
                  SizedBox(width: 7.w),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      padding: EdgeInsets.all(6.w),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        FeatherIcons.send,
                        size: 16.spMax,
                        color: Colors.white,
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
}