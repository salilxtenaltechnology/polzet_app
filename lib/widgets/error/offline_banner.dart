// // lib/widgets/offline_banner.dart
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';

// import '../../provider/connection_provider.dart';

// class OfflineBanner extends StatefulWidget {
//   const OfflineBanner({super.key});

//   @override
//   State<OfflineBanner> createState() => _OfflineBannerState();
// }

// class _OfflineBannerState extends State<OfflineBanner> {
//   bool _wasOffline = false;
//   bool _showBackOnline = false;

//   @override
//   Widget build(BuildContext context) {
//     return Consumer<ConnectivityProvider>(
//       builder: (context, connectivity, _) {
//         final isOffline = !connectivity.isOnline && connectivity.isInitialized;

//         if (_wasOffline && !isOffline && connectivity.isInitialized) {
//           _wasOffline = false;
//           // Show "back online" briefly
//           WidgetsBinding.instance.addPostFrameCallback((_) {
//             if (!mounted) return;
//             setState(() => _showBackOnline = true);
//             Future.delayed(const Duration(seconds: 3), () {
//               if (mounted) setState(() => _showBackOnline = false);
//             });
//           });
//         } else if (isOffline) {
//           _wasOffline = true;
//         }

//         if (isOffline) {
//           return _buildBanner(
//             color: Colors.red.shade700,
//             icon: Icons.wifi_off_rounded,
//             message: 'No internet connection',
//             showRetry: true,
//             onRetry: connectivity.retryNow,
//           );
//         }

//         if (_showBackOnline) {
//           return _buildBanner(
//             color: Colors.green.shade600,
//             icon: Icons.wifi_rounded,
//             message: 'Back online',
//             showRetry: false,
//           );
//         }

//         return const SizedBox.shrink();
//       },
//     );
//   }

//   Widget _buildBanner({
//     required Color color,
//     required IconData icon,
//     required String message,
//     required bool showRetry,
//     VoidCallback? onRetry,
//   }) {
//     return AnimatedContainer(
//       duration: const Duration(milliseconds: 300),
//       width: double.infinity,
//       color: color,
//       padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 14),
//       child: Row(
//         children: [
//           Icon(icon, color: Colors.white, size: 16),
//           const SizedBox(width: 8),
//           Expanded(
//             child: Text(
//               message,
//               style: const TextStyle(
//                 color: Colors.white,
//                 fontSize: 13,
//                 fontWeight: FontWeight.w500,
//               ),
//             ),
//           ),
//           if (showRetry && onRetry != null)
//             GestureDetector(
//               onTap: onRetry,
//               child: const Text(
//                 'Retry',
//                 style: TextStyle(
//                   color: Colors.white,
//                   fontSize: 13,
//                   fontWeight: FontWeight.bold,
//                   decoration: TextDecoration.underline,
//                   decorationColor: Colors.white,
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
// }
