// // ignore_for_file: deprecated_member_use

// import 'package:flutter/material.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';

// class PublicProfileSimmer extends StatefulWidget {
//   const PublicProfileSimmer({super.key});

//   @override
//   State<PublicProfileSimmer> createState() => _PublicProfileSimmerState();
// }

// class _PublicProfileSimmerState extends State<PublicProfileSimmer>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _controller;
//   late Animation<double> _animation;

//   @override
//   void initState() {
//     super.initState();
//     _controller = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 1400),
//     )..repeat();
//     _animation = Tween<double>(
//       begin: -1.5,
//       end: 1.5,
//     ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }

//   Widget _box({
//     required double width,
//     required double height,
//     double radius = 6,
//     bool isCircle = false,
//   }) {
//     return AnimatedBuilder(
//       animation: _animation,
//       builder: (context, _) {
//         final isDark = Theme.of(context).brightness == Brightness.dark;
//         final base = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE0E0E0);
//         final highlight = isDark
//             ? const Color(0xFF3A3A3C)
//             : const Color(0xFFF5F5F5);

//         return Container(
//           width: width,
//           height: height,
//           decoration: BoxDecoration(
//             borderRadius: isCircle
//                 ? BorderRadius.circular(height / 2)
//                 : BorderRadius.circular(radius.r),
//             gradient: LinearGradient(
//               begin: Alignment.centerLeft,
//               end: Alignment.centerRight,
//               colors: [base, highlight, base],
//               stops: const [0.0, 0.5, 1.0],
//               transform: _SlidingGradient(_animation.value),
//             ),
//           ),
//         );
//       },
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final isDark = Theme.of(context).brightness == Brightness.dark;
//     final surfaceColor = isDark
//         ? const Color(0xFF1C1C1E)
//         : const Color(0xFFF2F2F7);

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         /*──── Cover + Profile Info ────*/
//         Stack(
//           children: [
//             // Cover image shimmer
//             _box(width: double.infinity, height: 180.h, radius: 0),

//             // Glass card overlay at bottom of cover
//             Positioned(
//               bottom: 10.h,
//               left: 10.w,
//               right: 10.w,
//               child: AnimatedBuilder(
//                 animation: _animation,
//                 builder: (context, _) {
//                   return Container(
//                     padding: EdgeInsets.all(10.w),
//                     decoration: BoxDecoration(
//                       color: Colors.black.withOpacity(0.25),
//                       borderRadius: BorderRadius.circular(12.r),
//                     ),
//                     child: Row(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         // Profile avatar
//                         _box(width: 50.h, height: 50.h, isCircle: true),
//                         SizedBox(width: 10.w),
//                         Expanded(
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               // Username
//                               _box(width: 110.w, height: 11.h, radius: 5),
//                               SizedBox(height: 5.h),
//                               // Bio line 1
//                               _box(
//                                 width: double.infinity,
//                                 height: 8.h,
//                                 radius: 4,
//                               ),
//                               SizedBox(height: 4.h),
//                               // Bio line 2
//                               _box(width: 140.w, height: 8.h, radius: 4),
//                               SizedBox(height: 8.h),
//                               // Buttons row
//                               Row(
//                                 children: [
//                                   _box(width: 100.w, height: 25.h, radius: 8),
//                                   SizedBox(width: 8.w),
//                                   _box(width: 100.w, height: 25.h, radius: 8),
//                                 ],
//                               ),
//                             ],
//                           ),
//                         ),
//                       ],
//                     ),
//                   );
//                 },
//               ),
//             ),

//             // Back arrow placeholder
//             Positioned(
//               top: 16.h,
//               left: 8.w,
//               child: _box(width: 32.w, height: 32.h, isCircle: true),
//             ),
//           ],
//         ),

//         /*──── Stats + Chase/Rechase ────*/
//         Container(
//           color: surfaceColor,
//           child: Row(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               // Left stat boxes
//               SizedBox(
//                 width: 100.w,
//                 child: Column(
//                   children: [
//                     Container(
//                       width: 80.w,
//                       height: 80.h,
//                       margin: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 0),
//                       decoration: BoxDecoration(
//                         borderRadius: BorderRadius.circular(20.r),
//                       ),
//                       child: _box(width: 80.w, height: 80.h, radius: 20),
//                     ),
//                     Container(
//                       width: 80.w,
//                       height: 80.h,
//                       margin: EdgeInsets.fromLTRB(10.w, 5.h, 10.w, 0),
//                       child: _box(width: 80.w, height: 80.h, radius: 20),
//                     ),
//                   ],
//                 ),
//               ),

//               // Right: Vibe + Revibe sections
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     SizedBox(height: 12.h),

//                     // "Vibe" label + "See all"
//                     _shimmerRow(),
//                     SizedBox(height: 6.h),
//                     _avatarRow(),

//                     SizedBox(height: 12.h),

//                     // "Revibe" label + "See all"
//                     _shimmerRow(),
//                     SizedBox(height: 6.h),
//                     _avatarRow(),

//                     SizedBox(height: 12.h),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),

//         SizedBox(height: 10.h),

//         /*──── Posts Count Bar ────*/
//         Container(
//           margin: EdgeInsets.symmetric(horizontal: 10.w),
//           child: _box(width: double.infinity, height: 38.h, radius: 10),
//         ),

//         SizedBox(height: 14.h),

//         /*──── Poll Section Header ────*/
//         Padding(
//           padding: EdgeInsets.symmetric(horizontal: 10.w),
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               _box(width: 40.w, height: 11.h, radius: 5),
//               _box(width: 50.w, height: 10.h, radius: 5),
//             ],
//           ),
//         ),

//         SizedBox(height: 10.h),

//         /*──── Poll Grid (2x2) ────*/
//         Padding(
//           padding: EdgeInsets.symmetric(horizontal: 10.w),
//           child: GridView.builder(
//             shrinkWrap: true,
//             physics: const NeverScrollableScrollPhysics(),
//             itemCount: 4,
//             gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//               crossAxisCount: 2,
//               crossAxisSpacing: 8,
//               mainAxisSpacing: 8,
//               childAspectRatio: 1.3,
//             ),
//             itemBuilder: (_, __) => _box(
//               width: double.infinity,
//               height: double.infinity,
//               radius: 10,
//             ),
//           ),
//         ),

//         SizedBox(height: 16.h),

//         /*──── Things Section Header ────*/
//         Padding(
//           padding: EdgeInsets.symmetric(horizontal: 10.w),
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               _box(width: 50.w, height: 11.h, radius: 5),
//               _box(width: 50.w, height: 10.h, radius: 5),
//             ],
//           ),
//         ),

//         SizedBox(height: 10.h),

//         /*──── Things Cards (3 items) ────*/
//         ...List.generate(
//           3,
//           (_) => Container(
//             margin: EdgeInsets.fromLTRB(12.w, 0, 12.w, 10.h),
//             child: _box(width: double.infinity, height: 90.h, radius: 12),
//           ),
//         ),

//         SizedBox(height: 20.h),
//       ],
//     );
//   }

//   /// Label line + "See all" placeholder
//   Widget _shimmerRow() {
//     return Padding(
//       padding: EdgeInsets.only(right: 10.w),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           _box(width: 50.w, height: 10.h, radius: 5),
//           _box(width: 45.w, height: 9.h, radius: 5),
//         ],
//       ),
//     );
//   }

//   /// Row of 4 circular avatar placeholders
//   Widget _avatarRow() {
//     return SizedBox(
//       height: 55.h,
//       child: ListView.builder(
//         scrollDirection: Axis.horizontal,
//         physics: const NeverScrollableScrollPhysics(),
//         itemCount: 4,
//         itemBuilder: (_, __) => Container(
//           margin: EdgeInsets.only(right: 8.w),
//           child: _box(width: 55.w, height: 55.h, isCircle: true),
//         ),
//       ),
//     );
//   }
// }

// class _SlidingGradient extends GradientTransform {
//   final double slidePercent;
//   const _SlidingGradient(this.slidePercent);

//   @override
//   Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
//     return Matrix4.translationValues(bounds.width * slidePercent, 0, 0);
//   }
// }
