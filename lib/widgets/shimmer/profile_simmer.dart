// // ignore_for_file: deprecated_member_use

// import 'package:flutter/material.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';
// import 'package:shimmer/shimmer.dart';

// class ProfileSimmer extends StatelessWidget {
//   const ProfileSimmer({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Shimmer.fromColors(
//       baseColor: Colors.grey[300]!,
//       highlightColor: Colors.grey[100]!,
//       child: ListView(
//         children: [
//           Padding(
//             padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 SizedBox(
//                   height: 195.h,
//                   child: Stack(
//                     children: [
//                       Align(
//                         alignment: Alignment.topCenter,
//                         child: Container(
//                           height: 140.h,
//                           width: double.infinity,
//                           decoration: BoxDecoration(
//                             color: Theme.of(context).colorScheme.background,
//                             borderRadius: BorderRadius.circular(7.r),
//                           ),
//                         ),
//                       ),
//                       Align(
//                         alignment: Alignment.bottomCenter,
//                         child: Container(
//                           height: 100.h,
//                           width: 110.w,
//                           margin: EdgeInsets.only(bottom: 10.h),
//                           padding: const EdgeInsets.all(2).w,
//                           decoration: BoxDecoration(
//                             color: Theme.of(context).colorScheme.background,
//                             shape: BoxShape.circle,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 SizedBox(height: 20.h),
//                 Container(
//                   height: 250.h,
//                   width: double.infinity,
//                   decoration: BoxDecoration(
//                     color: Theme.of(context).colorScheme.secondaryContainer,
//                     borderRadius: BorderRadius.circular(15.r),
//                   ),
//                 ),
//                 SizedBox(height: 15.h),
//                 Container(
//                   height: 250.h,
//                   width: double.infinity,
//                   decoration: BoxDecoration(
//                     color: Theme.of(context).colorScheme.secondaryContainer,
//                     borderRadius: BorderRadius.circular(15.r),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
