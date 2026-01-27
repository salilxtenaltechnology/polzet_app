// import 'package:flutter/material.dart';

// import '../../api/services/share/share_service.dart';
// import '../../models/home feed/home_feed_items_model.dart';

// class ShareOptionsBottomSheet extends StatelessWidget {
//   final HomeFeedPost post;

//   const ShareOptionsBottomSheet({Key? key, required this.post})
//     : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.symmetric(vertical: 20),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           const Text(
//             'Share Post',
//             style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//           ),
//           const SizedBox(height: 20),
//           ListTile(
//             leading: const Icon(Icons.share),
//             title: const Text('Share via...'),
//             subtitle: const Text('Open share sheet'),
//             onTap: () {
//               Navigator.pop(context);
//               ShareService.sharePost(post, context: context);
//             },
//           ),
//           ListTile(
//             leading: const Icon(Icons.link),
//             title: const Text('Copy Link'),
//             subtitle: const Text('Copy post link to clipboard'),
//             onTap: () async {
//               Navigator.pop(context);
//               await ShareService.copyLinkToClipboard(post.id);
//               if (context.mounted) {
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   const SnackBar(
//                     content: Text('Link copied to clipboard!'),
//                     duration: Duration(seconds: 2),
//                   ),
//                 );
//               }
//             },
//           ),
//           ListTile(
//             leading: const Icon(Icons.link_outlined),
//             title: const Text('Share Link Only'),
//             subtitle: const Text('Share just the link'),
//             onTap: () {
//               Navigator.pop(context);
//               ShareService.shareLink(post.id, post.description);
//             },
//           ),
//         ],
//       ),
//     );
//   }
// }
