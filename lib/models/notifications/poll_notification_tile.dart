// // poll_notification_tile.dart
// // ignore_for_file: deprecated_member_use

// import 'dart:convert';

// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';

// import '../../../models/notifications/notification_model.dart';

// /// A self-contained, expandable poll notification card.
// ///
// /// Drop-in usage inside the Poll tab's ListView.builder:
// /// ```dart
// /// PollNotificationTile(notification: notification)
// /// ```
// class PollNotificationTile extends StatefulWidget {
//   const PollNotificationTile({
//     super.key,
//     required this.notification,
//     this.initiallyExpanded = false,
//     this.onTap,
//   });

//   final NotificationItem notification;
//   final bool initiallyExpanded;

//   /// Called when the collapsed header row is tapped (e.g. navigate to post).
//   final VoidCallback? onTap;

//   @override
//   State<PollNotificationTile> createState() => _PollNotificationTileState();
// }

// class _PollNotificationTileState extends State<PollNotificationTile>
//     with SingleTickerProviderStateMixin {
//   late bool _expanded;
//   late AnimationController _animCtrl;
//   late Animation<double> _expandAnim;

//   // ── tiny image cache (per-widget lifetime) ─────────────────────────────
//   final Map<String, Uint8List> _imgCache = {};

//   @override
//   void initState() {
//     super.initState();
//     _expanded = widget.initiallyExpanded;

//     _animCtrl = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 260),
//     );
//     _expandAnim = CurvedAnimation(
//       parent: _animCtrl,
//       curve: Curves.easeInOut,
//     );

//     if (_expanded) _animCtrl.value = 1.0;
//   }

//   @override
//   void dispose() {
//     _animCtrl.dispose();
//     super.dispose();
//   }

//   // ── helpers ─────────────────────────────────────────────────────────────

//   void _toggle() {
//     setState(() => _expanded = !_expanded);
//     _expanded ? _animCtrl.forward() : _animCtrl.reverse();
//   }

//   Uint8List? _decodeBase64(String? url) {
//     if (url == null || url.isEmpty) return null;
//     if (_imgCache.containsKey(url)) return _imgCache[url];
//     try {
//       final data = url.replaceFirst(RegExp(r'data:image/[^;]+;base64,'), '');
//       final bytes = base64Decode(data);
//       _imgCache[url] = bytes;
//       return bytes;
//     } catch (_) {
//       return null;
//     }
//   }

//   String _initial(String name) =>
//       name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

//   /// Detects whether the poll uses images instead of text options.
//   bool get _isImagePoll {
//     final detail = widget.notification.post?.pollDetails.firstOrNull;
//     if (detail == null) return false;
//     return detail.options.any((o) => o.image != null);
//   }

//   // ── build ────────────────────────────────────────────────────────────────

//   @override
//   Widget build(BuildContext context) {
//     final notification = widget.notification;
//     final post = notification.post;
//     final details = post?.pollDetails ?? [];

//     // total votes across all options of the first question
//     final int totalVotes = details.isEmpty
//         ? 0
//         : details.first.options.fold<int>(
//             0,
//             (sum, o) => sum + (int.tryParse(o.voteCount) ?? 0),
//           );

//     // subtitle: "104 votes • 2 min ago"
//     final String subtitle =
//         '$totalVotes vote${totalVotes == 1 ? '' : 's'} • ${notification.timeAgo}';

//     // post image (thumbnail for the header)
//     final String? postImageUrl = post?.imageUrl;

//     return Container(
//       margin: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
//       decoration: BoxDecoration(
//         color: Theme.of(context).colorScheme.surface,
//         borderRadius: BorderRadius.circular(14.r),
//         border: Border.all(
//           color: _expanded
//               ? Theme.of(context).colorScheme.primary.withOpacity(0.6)
//               : Theme.of(context).colorScheme.outline.withOpacity(0.18),
//           width: _expanded ? 1.2 : 1,
//         ),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.04),
//             blurRadius: 8,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: ClipRRect(
//         borderRadius: BorderRadius.circular(14.r),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             // ── Collapsed header ──────────────────────────────────────────
//             InkWell(
//               onTap: _toggle,
//               borderRadius: BorderRadius.circular(14.r),
//               child: Padding(
//                 padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
//                 child: Row(
//                   children: [
//                     // post thumbnail
//                     if (postImageUrl != null && postImageUrl.isNotEmpty)
//                       ClipRRect(
//                         borderRadius: BorderRadius.circular(8.r),
//                         child: Image.network(
//                           postImageUrl,
//                           width: 42.w,
//                           height: 42.w,
//                           fit: BoxFit.cover,
//                           errorBuilder: (_, __, ___) =>
//                               _fallbackAvatar(notification),
//                         ),
//                       )
//                     else
//                       _fallbackAvatar(notification),
//                     SizedBox(width: 10.w),

//                     // title + subtitle
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             notification.title.isNotEmpty
//                                 ? notification.title
//                                 : 'Your poll gets votes',
//                             style: TextStyle(
//                               fontSize: 14.sp,
//                               fontWeight: FontWeight.w600,
//                               color:
//                                   Theme.of(context).colorScheme.onBackground,
//                             ),
//                           ),
//                           SizedBox(height: 2.h),
//                           Text(
//                             subtitle,
//                             style: TextStyle(
//                               fontSize: 12.sp,
//                               color: Theme.of(context)
//                                   .colorScheme
//                                   .onBackground
//                                   .withOpacity(0.5),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),

//                     // chevron
//                     AnimatedRotation(
//                       turns: _expanded ? 0 : 0.5,
//                       duration: const Duration(milliseconds: 260),
//                       child: Icon(
//                         Icons.keyboard_arrow_up_rounded,
//                         color: Theme.of(context)
//                             .colorScheme
//                             .onBackground
//                             .withOpacity(0.45),
//                         size: 22.sp,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),

//             // ── Expanded body ─────────────────────────────────────────────
//             SizeTransition(
//               sizeFactor: _expandAnim,
//               axisAlignment: -1,
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Divider(
//                     height: 1,
//                     thickness: 1,
//                     color: Theme.of(context)
//                         .colorScheme
//                         .outline
//                         .withOpacity(0.12),
//                   ),
//                   if (details.isNotEmpty)
//                     _isImagePoll
//                         ? _buildImagePollBody(details.first, notification)
//                         : _buildTextPollBody(details.first),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   // ── Text poll body ────────────────────────────────────────────────────────

//   Widget _buildTextPollBody(NotificationPollDetail detail) {
//     return Padding(
//       padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 14.h),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // question
//           Text(
//             detail.question,
//             style: TextStyle(
//               fontSize: 15.sp,
//               fontWeight: FontWeight.w700,
//               color: Theme.of(context).colorScheme.onBackground,
//             ),
//           ),
//           SizedBox(height: 12.h),

//           // options
//           ...detail.options.map((option) => _buildTextOption(option, detail)),
//         ],
//       ),
//     );
//   }

//   Widget _buildTextOption(
//       NotificationPollOption option, NotificationPollDetail detail) {
//     final int votes = int.tryParse(option.voteCount) ?? 0;
//     final double pct = option.percentage.clamp(0, 100);
//     final bool isLeading = detail.options
//         .every((o) => option.percentage >= o.percentage);

//     return Padding(
//       padding: EdgeInsets.only(bottom: 10.h),
//       child: Row(
//         children: [
//           // option text + bar
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     Text(
//                       option.text ?? '',
//                       style: TextStyle(
//                         fontSize: 14.sp,
//                         fontWeight: FontWeight.w500,
//                         color: Theme.of(context).colorScheme.onBackground,
//                       ),
//                     ),
//                     Text(
//                       '${pct.toStringAsFixed(pct % 1 == 0 ? 0 : 1)}%',
//                       style: TextStyle(
//                         fontSize: 14.sp,
//                         fontWeight: FontWeight.w700,
//                         color: Theme.of(context).colorScheme.onBackground,
//                       ),
//                     ),
//                   ],
//                 ),
//                 SizedBox(height: 5.h),
//                 ClipRRect(
//                   borderRadius: BorderRadius.circular(20.r),
//                   child: LinearProgressIndicator(
//                     value: pct / 100,
//                     minHeight: 7.h,
//                     backgroundColor: Theme.of(context)
//                         .colorScheme
//                         .outline
//                         .withOpacity(0.18),
//                     valueColor: AlwaysStoppedAnimation<Color>(
//                       isLeading
//                           ? Theme.of(context).colorScheme.primary
//                           : Theme.of(context)
//                               .colorScheme
//                               .outline
//                               .withOpacity(0.35),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           SizedBox(width: 10.w),
//           // vote count
//           SizedBox(
//             width: 58.w,
//             child: Text(
//               '$votes vote${votes == 1 ? '' : 's'}',
//               textAlign: TextAlign.right,
//               style: TextStyle(
//                 fontSize: 11.sp,
//                 color: Theme.of(context)
//                     .colorScheme
//                     .onBackground
//                     .withOpacity(0.45),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // ── Image poll body ───────────────────────────────────────────────────────

//   Widget _buildImagePollBody(
//       NotificationPollDetail detail, NotificationItem notification) {
//     final options = detail.options;
//     final int totalVotes = options.fold<int>(
//         0, (s, o) => s + (int.tryParse(o.voteCount) ?? 0));

//     // Collect unique voters across all options
//     final Map<int, NotificationPollVoter> voterMap = {};
//     for (final o in options) {
//       for (final v in o.voters) {
//         voterMap[v.id] = v;
//       }
//     }
//     final voters = voterMap.values.toList();

//     // Build image grid: first image large (left), rest stacked (right)
//     const int maxRight = 2;
//     final int extraCount =
//         options.length > 3 ? options.length - 3 : 0;

//     return Padding(
//       padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 14.h),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // image grid
//           SizedBox(
//             height: 200.h,
//             child: Row(
//               children: [
//                 // left: big first image
//                 if (options.isNotEmpty)
//                   Expanded(
//                     flex: 3,
//                     child: _pollImageCard(
//                       options[0].image?.url,
//                       radius: const BorderRadius.only(
//                         topLeft: Radius.circular(10),
//                         bottomLeft: Radius.circular(10),
//                       ),
//                     ),
//                   ),
//                 SizedBox(width: 4.w),

//                 // right: up to 2 stacked + overflow badge
//                 if (options.length > 1)
//                   Expanded(
//                     flex: 2,
//                     child: Column(
//                       children: [
//                         // top-right image
//                         Expanded(
//                           child: _pollImageCard(
//                             options.length > 1 ? options[1].image?.url : null,
//                             radius: const BorderRadius.only(
//                               topRight: Radius.circular(10),
//                             ),
//                           ),
//                         ),
//                         SizedBox(height: 4.h),
//                         // bottom-right image (may show "+N more" overlay)
//                         Expanded(
//                           child: Stack(
//                             fit: StackFit.expand,
//                             children: [
//                               _pollImageCard(
//                                 options.length > 2
//                                     ? options[2].image?.url
//                                     : null,
//                                 radius: const BorderRadius.only(
//                                   bottomRight: Radius.circular(10),
//                                 ),
//                               ),
//                               if (extraCount > 0)
//                                 ClipRRect(
//                                   borderRadius: const BorderRadius.only(
//                                     bottomRight: Radius.circular(10),
//                                   ),
//                                   child: Container(
//                                     color: Colors.black.withOpacity(0.55),
//                                     alignment: Alignment.center,
//                                     child: Text(
//                                       '+$extraCount more',
//                                       style: TextStyle(
//                                         color: Colors.white,
//                                         fontWeight: FontWeight.w700,
//                                         fontSize: 13.sp,
//                                       ),
//                                     ),
//                                   ),
//                                 ),
//                             ],
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//               ],
//             ),
//           ),
//           SizedBox(height: 10.h),

//           // voter avatars + total votes row
//           Row(
//             children: [
//               _buildVoterAvatarStack(voters),
//               SizedBox(width: 6.w),
//               if (voters.length > 3)
//                 Text(
//                   '+${voters.length - 3}',
//                   style: TextStyle(
//                     fontSize: 13.sp,
//                     fontWeight: FontWeight.w600,
//                     color: Theme.of(context).colorScheme.onBackground,
//                   ),
//                 ),
//               const Spacer(),
//               Text(
//                 '$totalVotes vote${totalVotes == 1 ? '' : 's'}',
//                 style: TextStyle(
//                   fontSize: 13.sp,
//                   fontWeight: FontWeight.w500,
//                   color: Theme.of(context)
//                       .colorScheme
//                       .onBackground
//                       .withOpacity(0.6),
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _pollImageCard(String? url, {BorderRadius? radius}) {
//     final Widget placeholder = Container(
//       decoration: BoxDecoration(
//         color: Theme.of(context).colorScheme.outline.withOpacity(0.12),
//         borderRadius: radius,
//       ),
//     );

//     if (url == null || url.isEmpty) return placeholder;

//     // Build full URL if relative
//     final String fullUrl = url.startsWith('http')
//         ? url
//         : 'http://testbackend.polzet.in$url';

//     return ClipRRect(
//       borderRadius: radius ?? BorderRadius.zero,
//       child: Image.network(
//         fullUrl,
//         fit: BoxFit.cover,
//         width: double.infinity,
//         height: double.infinity,
//         errorBuilder: (_, __, ___) => placeholder,
//         loadingBuilder: (_, child, loading) =>
//             loading == null ? child : placeholder,
//       ),
//     );
//   }

//   Widget _buildVoterAvatarStack(List<NotificationPollVoter> voters) {
//     const int maxShow = 3;
//     final show = voters.take(maxShow).toList();

//     return SizedBox(
//       width: (show.length * 22 + 8).toDouble().w,
//       height: 28.w,
//       child: Stack(
//         children: List.generate(show.length, (i) {
//           final voter = show[i];
//           final bytes = _decodeBase64(voter.profilePictureUrl);
//           return Positioned(
//             left: (i * 18).toDouble().w,
//             child: Container(
//               decoration: BoxDecoration(
//                 shape: BoxShape.circle,
//                 border: Border.all(
//                   color: Theme.of(context).colorScheme.surface,
//                   width: 2,
//                 ),
//               ),
//               child: CircleAvatar(
//                 radius: 12.w,
//                 backgroundImage:
//                     bytes != null ? MemoryImage(bytes) : null,
//                 backgroundColor: Theme.of(context)
//                     .colorScheme
//                     .primary
//                     .withOpacity(0.15),
//                 child: bytes == null
//                     ? Text(
//                         _initial(voter.firstName),
//                         style: TextStyle(
//                           fontSize: 9.sp,
//                           fontWeight: FontWeight.w600,
//                           color: Theme.of(context).colorScheme.primary,
//                         ),
//                       )
//                     : null,
//               ),
//             ),
//           );
//         }),
//       ),
//     );
//   }

//   Widget _fallbackAvatar(NotificationItem n) {
//     return CircleAvatar(
//       radius: 21.w,
//       backgroundColor:
//           Theme.of(context).colorScheme.primary.withOpacity(0.12),
//       child: Text(
//         _initial(n.actor.name),
//         style: TextStyle(
//           fontSize: 14.sp,
//           fontWeight: FontWeight.w600,
//           color: Theme.of(context).colorScheme.primary,
//         ),
//       ),
//     );
//   }
// }