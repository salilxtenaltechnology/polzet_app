// import 'package:flutter/material.dart';

// // ─────────────────────────────────────────────
// // APP COLORS
// // ─────────────────────────────────────────────
// class AppColors {
//   AppColors._();

//   static const Color primaryColor = Color(0xFF9B3046);

//   // Light Mode
//   static const Color lightBackgroundColor = Color(0xFFFDFDFD);
//   static const Color lightPrimaryCardColor = Color(0xFFFFFFFF);
//   static const Color lightHeadingColor = Color(0xFF111111);
//   static const Color lightBodyTextColor = Color(0xFF595959);
//   static const Color lightSubheadingColor = Color(0xFF2C2C2C);
//   static const Color lightSubTextColor = Color(0xFF8E8E8E);
//   static const Color lightDividerColor = Color(0xFFE6E6E6);
//   static const Color lightStrokeColor = Color(0xFFDDDDDD);
//   static const Color lightPlaceholderColor = Color(0xFFB3B3B3);

//   // Dark Mode
//   static const Color darkBackgroundColor = Color(0xFF0F0F10);
//   static const Color darkPrimaryCardColor = Color(0xFF151F25);
//   static const Color darkHeadingColor = Color(0xFFF5F5F5);
//   static const Color darkBodyTextColor = Color(0xFFBFBFBF);
//   static const Color darkSubheadingColor = Color(0xFFE9E9E9);
//   static const Color darkSubTextColor = Color(0xFFF2F2F2);
//   static const Color darkDividerColor = Color(0xFFF8F8F8);
//   static const Color darkStrokeColor = Color(0xFF3C3C3C);
//   static const Color darkPlaceholderColor = Color(0xFFE7E7E7);
// }

// // ─────────────────────────────────────────────
// // APP TEXT STYLES  (Inter, size hierarchy)
// // ─────────────────────────────────────────────
// class AppTextStyles {
//   AppTextStyles._();

//   static TextStyle h1({required Color color}) => TextStyle(
//         fontFamily: 'Inter',
//         fontSize: 22,
//         fontWeight: FontWeight.w700,
//         color: color,
//         height: 1.3,
//       );

//   static TextStyle h2({required Color color}) => TextStyle(
//         fontFamily: 'Inter',
//         fontSize: 18,
//         fontWeight: FontWeight.w600,
//         color: color,
//         height: 1.35,
//       );

//   static TextStyle h3({required Color color}) => TextStyle(
//         fontFamily: 'Inter',
//         fontSize: 16,
//         fontWeight: FontWeight.w600,
//         color: color,
//         height: 1.4,
//       );

//   static TextStyle body({required Color color}) => TextStyle(
//         fontFamily: 'Inter',
//         fontSize: 14,
//         fontWeight: FontWeight.w400,
//         color: color,
//         height: 1.5,
//       );

//   static TextStyle subtext({required Color color}) => TextStyle(
//         fontFamily: 'Inter',
//         fontSize: 12,
//         fontWeight: FontWeight.w400,
//         color: color,
//         height: 1.45,
//       );
// }

// // ─────────────────────────────────────────────
// // SPACING TOKENS
// // ─────────────────────────────────────────────
// class AppSpacing {
//   AppSpacing._();

//   static const double textSpacing = 8;
//   static const double cardPadding = 16;
//   static const double cardGap = 16;
//   static const double sectionSpacing = 24;
//   static const double screenPadding = 16;
// }

// // ─────────────────────────────────────────────
// // ENTRY POINT
// // ─────────────────────────────────────────────
// void main() => runApp(const DesignSystemApp());

// class DesignSystemApp extends StatefulWidget {
//   const DesignSystemApp({super.key});

//   @override
//   State<DesignSystemApp> createState() => _DesignSystemAppState();
// }

// class _DesignSystemAppState extends State<DesignSystemApp> {
//   bool _isDark = false;

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       title: 'Design System Demo',
//       themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
//       theme: ThemeData(
//         brightness: Brightness.light,
//         scaffoldBackgroundColor: AppColors.lightBackgroundColor,
//         fontFamily: 'Inter',
//       ),
//       darkTheme: ThemeData(
//         brightness: Brightness.dark,
//         scaffoldBackgroundColor: AppColors.darkBackgroundColor,
//         fontFamily: 'Inter',
//       ),
//       home: DesignDemoScreen(
//         isDark: _isDark,
//         onToggle: () => setState(() => _isDark = !_isDark),
//       ),
//     );
//   }
// }

// // ─────────────────────────────────────────────
// // DEMO SCREEN
// // ─────────────────────────────────────────────
// class DesignDemoScreen extends StatelessWidget {
//   final bool isDark;
//   final VoidCallback onToggle;

//   const DesignDemoScreen({
//     super.key,
//     required this.isDark,
//     required this.onToggle,
//   });

//   // Resolved tokens based on mode
//   Color get bg =>
//       isDark ? AppColors.darkBackgroundColor : AppColors.lightBackgroundColor;
//   Color get card =>
//       isDark ? AppColors.darkPrimaryCardColor : AppColors.lightPrimaryCardColor;
//   Color get heading =>
//       isDark ? AppColors.darkHeadingColor : AppColors.lightHeadingColor;
//   Color get subheading =>
//       isDark ? AppColors.darkSubheadingColor : AppColors.lightSubheadingColor;
//   Color get bodyText =>
//       isDark ? AppColors.darkBodyTextColor : AppColors.lightBodyTextColor;
//   Color get subText =>
//       isDark ? AppColors.darkSubTextColor : AppColors.lightSubTextColor;
//   Color get divider =>
//       isDark ? AppColors.darkDividerColor : AppColors.lightDividerColor;
//   Color get stroke =>
//       isDark ? AppColors.darkStrokeColor : AppColors.lightStrokeColor;
//   Color get placeholder =>
//       isDark ? AppColors.darkPlaceholderColor : AppColors.lightPlaceholderColor;

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: bg,
//       body: SafeArea(
//         child: SingleChildScrollView(
//           padding: const EdgeInsets.all(AppSpacing.screenPadding),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               // ── Top Bar ──────────────────────────────
//               _TopBar(
//                 isDark: isDark,
//                 onToggle: onToggle,
//                 headingColor: heading,
//                 subTextColor: subText,
//               ),

//               const SizedBox(height: AppSpacing.sectionSpacing),

//               // ── Section: Typography ──────────────────
//               _SectionLabel(label: 'Typography', color: subText),
//               const SizedBox(height: AppSpacing.textSpacing),
//               _TypographyCard(
//                 card: card,
//                 stroke: stroke,
//                 heading: heading,
//                 subheading: subheading,
//                 bodyText: bodyText,
//                 subText: subText,
//               ),

//               const SizedBox(height: AppSpacing.sectionSpacing),

//               // ── Section: Color Palette ───────────────
//               _SectionLabel(label: 'Color Palette', color: subText),
//               const SizedBox(height: AppSpacing.textSpacing),
//               _ColorPaletteCard(
//                 card: card,
//                 stroke: stroke,
//                 subText: subText,
//                 isDark: isDark,
//               ),

//               const SizedBox(height: AppSpacing.sectionSpacing),

//               // ── Section: UI Components ───────────────
//               _SectionLabel(label: 'UI Components', color: subText),
//               const SizedBox(height: AppSpacing.textSpacing),
//               _ButtonsRow(),

//               const SizedBox(height: AppSpacing.cardGap),
//               _InputField(
//                 card: card,
//                 stroke: stroke,
//                 placeholder: placeholder,
//                 bodyText: bodyText,
//               ),

//               const SizedBox(height: AppSpacing.sectionSpacing),

//               // ── Section: Article Cards ───────────────
//               _SectionLabel(label: 'Article Cards', color: subText),
//               const SizedBox(height: AppSpacing.textSpacing),
//               _ArticleCard(
//                 card: card,
//                 stroke: stroke,
//                 heading: heading,
//                 bodyText: bodyText,
//                 subText: subText,
//                 divider: divider,
//               ),
//               const SizedBox(height: AppSpacing.cardGap),
//               _ArticleCard(
//                 card: card,
//                 stroke: stroke,
//                 heading: heading,
//                 bodyText: bodyText,
//                 subText: subText,
//                 divider: divider,
//                 isSecond: true,
//               ),

//               const SizedBox(height: AppSpacing.sectionSpacing),

//               // ── Section: Stat Cards ──────────────────
//               _SectionLabel(label: 'Stat Cards', color: subText),
//               const SizedBox(height: AppSpacing.textSpacing),
//               _StatCardsRow(
//                 card: card,
//                 stroke: stroke,
//                 heading: heading,
//                 bodyText: bodyText,
//                 subText: subText,
//               ),

//               const SizedBox(height: AppSpacing.sectionSpacing),

//               // ── Section: Spacing Tokens ───────────────
//               _SectionLabel(label: 'Spacing Tokens', color: subText),
//               const SizedBox(height: AppSpacing.textSpacing),
//               _SpacingCard(
//                 card: card,
//                 stroke: stroke,
//                 heading: heading,
//                 bodyText: bodyText,
//                 subText: subText,
//                 divider: divider,
//               ),

//               const SizedBox(height: 32),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// // ─────────────────────────────────────────────
// // WIDGETS
// // ─────────────────────────────────────────────

// class _TopBar extends StatelessWidget {
//   final bool isDark;
//   final VoidCallback onToggle;
//   final Color headingColor;
//   final Color subTextColor;

//   const _TopBar({
//     required this.isDark,
//     required this.onToggle,
//     required this.headingColor,
//     required this.subTextColor,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//       children: [
//         Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text('Design System',
//                 style: AppTextStyles.h1(color: headingColor)),
//             const SizedBox(height: 4),
//             Text('Inter · Light & Dark Mode',
//                 style: AppTextStyles.subtext(color: subTextColor)),
//           ],
//         ),
//         GestureDetector(
//           onTap: onToggle,
//           child: Container(
//             padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
//             decoration: BoxDecoration(
//               color: AppColors.primaryColor,
//               borderRadius: BorderRadius.circular(20),
//             ),
//             child: Row(
//               children: [
//                 Icon(
//                   isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
//                   size: 14,
//                   color: Colors.white,
//                 ),
//                 const SizedBox(width: 6),
//                 Text(
//                   isDark ? 'Light' : 'Dark',
//                   style: AppTextStyles.subtext(color: Colors.white)
//                       .copyWith(fontWeight: FontWeight.w600),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// }

// class _SectionLabel extends StatelessWidget {
//   final String label;
//   final Color color;
//   const _SectionLabel({required this.label, required this.color});

//   @override
//   Widget build(BuildContext context) {
//     return Text(
//       label.toUpperCase(),
//       style: TextStyle(
//         fontFamily: 'Inter',
//         fontSize: 11,
//         fontWeight: FontWeight.w600,
//         letterSpacing: 1.2,
//         color: color,
//       ),
//     );
//   }
// }

// // ── Typography Card ──────────────────────────
// class _TypographyCard extends StatelessWidget {
//   final Color card, stroke, heading, subheading, bodyText, subText;
//   const _TypographyCard({
//     required this.card,
//     required this.stroke,
//     required this.heading,
//     required this.subheading,
//     required this.bodyText,
//     required this.subText,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final rows = [
//       ('H1 — 22px Bold', AppTextStyles.h1(color: heading), 'FontWeight.w700'),
//       ('H2 — 18px SemiBold', AppTextStyles.h2(color: subheading),
//           'FontWeight.w600'),
//       ('H3 — 16px SemiBold', AppTextStyles.h3(color: subheading),
//           'FontWeight.w600'),
//       ('Body — 14px Regular', AppTextStyles.body(color: bodyText),
//           'FontWeight.w400'),
//       ('Subtext — 12px Regular', AppTextStyles.subtext(color: subText),
//           'FontWeight.w400'),
//     ];

//     return _BaseCard(
//       card: card,
//       stroke: stroke,
//       child: Column(
//         children: rows.asMap().entries.map((e) {
//           final i = e.key;
//           final (label, style, weight) = e.value;
//           return Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               if (i != 0) const SizedBox(height: 12),
//               Text(label, style: style),
//               const SizedBox(height: 2),
//               Text(weight,
//                   style: AppTextStyles.subtext(
//                       color: AppColors.primaryColor.withOpacity(0.8))
//                     ..copyWith()),
//               if (i != rows.length - 1)
//                 Padding(
//                   padding: const EdgeInsets.only(top: 12),
//                   child: Divider(color: stroke, height: 1),
//                 ),
//             ],
//           );
//         }).toList(),
//       ),
//     );
//   }
// }

// // ── Color Palette Card ────────────────────────
// class _ColorPaletteCard extends StatelessWidget {
//   final Color card, stroke, subText;
//   final bool isDark;
//   const _ColorPaletteCard({
//     required this.card,
//     required this.stroke,
//     required this.subText,
//     required this.isDark,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final swatches = isDark
//         ? [
//             ('Background', AppColors.darkBackgroundColor),
//             ('Card', AppColors.darkPrimaryCardColor),
//             ('Heading', AppColors.darkHeadingColor),
//             ('Body Text', AppColors.darkBodyTextColor),
//             ('Subheading', AppColors.darkSubheadingColor),
//             ('Subtext', AppColors.darkSubTextColor),
//             ('Stroke', AppColors.darkStrokeColor),
//             ('Placeholder', AppColors.darkPlaceholderColor),
//           ]
//         : [
//             ('Background', AppColors.lightBackgroundColor),
//             ('Card', AppColors.lightPrimaryCardColor),
//             ('Heading', AppColors.lightHeadingColor),
//             ('Body Text', AppColors.lightBodyTextColor),
//             ('Subheading', AppColors.lightSubheadingColor),
//             ('Subtext', AppColors.lightSubTextColor),
//             ('Stroke', AppColors.lightStrokeColor),
//             ('Placeholder', AppColors.lightPlaceholderColor),
//           ];

//     // Always show primary
//     return _BaseCard(
//       card: card,
//       stroke: stroke,
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Primary
//           Row(
//             children: [
//               Container(
//                 width: 40,
//                 height: 40,
//                 decoration: BoxDecoration(
//                   color: AppColors.primaryColor,
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//               ),
//               const SizedBox(width: 12),
//               Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text('Primary',
//                       style: AppTextStyles.body(color: subText)
//                           .copyWith(fontWeight: FontWeight.w600)),
//                   Text('#9B3046',
//                       style: AppTextStyles.subtext(color: subText)),
//                 ],
//               ),
//               const Spacer(),
//               Container(
//                 padding:
//                     const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                 decoration: BoxDecoration(
//                   color: AppColors.primaryColor.withOpacity(0.12),
//                   borderRadius: BorderRadius.circular(4),
//                 ),
//                 child: Text('Brand',
//                     style: AppTextStyles.subtext(
//                         color: AppColors.primaryColor)),
//               ),
//             ],
//           ),
//           const SizedBox(height: 16),
//           Divider(color: stroke, height: 1),
//           const SizedBox(height: 16),
//           // Grid
//           Wrap(
//             spacing: 10,
//             runSpacing: 10,
//             children: swatches.map((s) {
//               final (name, color) = s;
//               final hexStr =
//                   '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
//               final isLight = ThemeData.estimateBrightnessForColor(color) ==
//                   Brightness.light;
//               final onColor = isLight ? Colors.black87 : Colors.white;
//               return Container(
//                 width: (MediaQuery.of(context).size.width - 32 - 16 - 10) / 2,
//                 padding: const EdgeInsets.all(10),
//                 decoration: BoxDecoration(
//                   color: color,
//                   borderRadius: BorderRadius.circular(8),
//                   border: Border.all(color: stroke, width: 0.5),
//                 ),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(name,
//                         style: TextStyle(
//                           fontFamily: 'Inter',
//                           fontSize: 11,
//                           fontWeight: FontWeight.w600,
//                           color: onColor.withOpacity(0.75),
//                         )),
//                     const SizedBox(height: 2),
//                     Text(hexStr,
//                         style: TextStyle(
//                           fontFamily: 'Inter',
//                           fontSize: 10,
//                           color: onColor.withOpacity(0.5),
//                         )),
//                   ],
//                 ),
//               );
//             }).toList(),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // ── Buttons ───────────────────────────────────
// class _ButtonsRow extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       children: [
//         Expanded(
//           child: ElevatedButton(
//             style: ElevatedButton.styleFrom(
//               backgroundColor: AppColors.primaryColor,
//               foregroundColor: Colors.white,
//               padding: const EdgeInsets.symmetric(vertical: 14),
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(10),
//               ),
//               elevation: 0,
//             ),
//             onPressed: () {},
//             child: Text('Primary',
//                 style: AppTextStyles.body(color: Colors.white)
//                     .copyWith(fontWeight: FontWeight.w600)),
//           ),
//         ),
//         const SizedBox(width: AppSpacing.cardGap),
//         Expanded(
//           child: OutlinedButton(
//             style: OutlinedButton.styleFrom(
//               foregroundColor: AppColors.primaryColor,
//               side: const BorderSide(color: AppColors.primaryColor),
//               padding: const EdgeInsets.symmetric(vertical: 14),
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(10),
//               ),
//             ),
//             onPressed: () {},
//             child: Text('Outline',
//                 style: AppTextStyles.body(color: AppColors.primaryColor)
//                     .copyWith(fontWeight: FontWeight.w600)),
//           ),
//         ),
//       ],
//     );
//   }
// }

// // ── Input Field ───────────────────────────────
// class _InputField extends StatelessWidget {
//   final Color card, stroke, placeholder, bodyText;
//   const _InputField({
//     required this.card,
//     required this.stroke,
//     required this.placeholder,
//     required this.bodyText,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
//       decoration: BoxDecoration(
//         color: card,
//         borderRadius: BorderRadius.circular(10),
//         border: Border.all(color: stroke),
//       ),
//       child: Row(
//         children: [
//           Icon(Icons.search_rounded, size: 18, color: placeholder),
//           const SizedBox(width: 10),
//           Text('Search anything…',
//               style: AppTextStyles.body(color: placeholder)),
//         ],
//       ),
//     );
//   }
// }

// // ── Article Card ──────────────────────────────
// class _ArticleCard extends StatelessWidget {
//   final Color card, stroke, heading, bodyText, subText, divider;
//   final bool isSecond;
//   const _ArticleCard({
//     required this.card,
//     required this.stroke,
//     required this.heading,
//     required this.bodyText,
//     required this.subText,
//     required this.divider,
//     this.isSecond = false,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return _BaseCard(
//       card: card,
//       stroke: stroke,
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Container(
//             width: 72,
//             height: 72,
//             decoration: BoxDecoration(
//               color: isSecond
//                   ? AppColors.primaryColor.withOpacity(0.12)
//                   : AppColors.primaryColor.withOpacity(0.18),
//               borderRadius: BorderRadius.circular(8),
//             ),
//             child: Icon(
//               isSecond
//                   ? Icons.bar_chart_rounded
//                   : Icons.auto_stories_rounded,
//               color: AppColors.primaryColor,
//               size: 28,
//             ),
//           ),
//           const SizedBox(width: AppSpacing.cardPadding),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Row(
//                   children: [
//                     Expanded(
//                       child: Text(
//                         isSecond
//                             ? 'Market Analysis Report'
//                             : 'Getting Started with Design Systems',
//                         style: AppTextStyles.h3(color: heading),
//                         maxLines: 2,
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: AppSpacing.textSpacing),
//                 Text(
//                   isSecond
//                       ? 'Deep dive into Q3 metrics and how design consistency drives growth.'
//                       : 'Learn how to build scalable and consistent UI components from scratch.',
//                   style: AppTextStyles.body(color: bodyText),
//                   maxLines: 2,
//                   overflow: TextOverflow.ellipsis,
//                 ),
//                 const SizedBox(height: AppSpacing.textSpacing),
//                 Row(
//                   children: [
//                     Text(
//                       isSecond ? '5 min read' : '8 min read',
//                       style: AppTextStyles.subtext(color: subText),
//                     ),
//                     const SizedBox(width: 8),
//                     Container(
//                         width: 3,
//                         height: 3,
//                         decoration: BoxDecoration(
//                           color: subText,
//                           shape: BoxShape.circle,
//                         )),
//                     const SizedBox(width: 8),
//                     Text(
//                       isSecond ? 'Apr 10, 2025' : 'Apr 14, 2025',
//                       style: AppTextStyles.subtext(color: subText),
//                     ),
//                     const Spacer(),
//                     Container(
//                       padding: const EdgeInsets.symmetric(
//                           horizontal: 8, vertical: 3),
//                       decoration: BoxDecoration(
//                         color: AppColors.primaryColor.withOpacity(0.1),
//                         borderRadius: BorderRadius.circular(4),
//                       ),
//                       child: Text(
//                         isSecond ? 'Finance' : 'Design',
//                         style: AppTextStyles.subtext(
//                             color: AppColors.primaryColor),
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // ── Stat Cards Row ────────────────────────────
// class _StatCardsRow extends StatelessWidget {
//   final Color card, stroke, heading, bodyText, subText;
//   const _StatCardsRow({
//     required this.card,
//     required this.stroke,
//     required this.heading,
//     required this.bodyText,
//     required this.subText,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final stats = [
//       (Icons.people_alt_rounded, '12.4K', 'Total Users', '+8.2%'),
//       (Icons.trending_up_rounded, '\$4.8K', 'Revenue', '+14.5%'),
//       (Icons.star_rounded, '4.9', 'Rating', '+0.3'),
//     ];
//     return Row(
//       children: stats.asMap().entries.map((e) {
//         final i = e.key;
//         final (icon, value, label, change) = e.value;
//         return Expanded(
//           child: Padding(
//             padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
//             child: Container(
//               padding: const EdgeInsets.all(AppSpacing.cardPadding),
//               decoration: BoxDecoration(
//                 color: card,
//                 borderRadius: BorderRadius.circular(12),
//                 border: Border.all(color: stroke),
//               ),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Container(
//                     width: 36,
//                     height: 36,
//                     decoration: BoxDecoration(
//                       color: AppColors.primaryColor.withOpacity(0.1),
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                     child: Icon(icon,
//                         size: 18, color: AppColors.primaryColor),
//                   ),
//                   const SizedBox(height: 12),
//                   Text(value, style: AppTextStyles.h2(color: heading)),
//                   const SizedBox(height: 2),
//                   Text(label,
//                       style: AppTextStyles.subtext(color: subText)),
//                   const SizedBox(height: 6),
//                   Row(
//                     children: [
//                       const Icon(Icons.arrow_upward_rounded,
//                           size: 11, color: Color(0xFF2A9D5C)),
//                       const SizedBox(width: 2),
//                       Text(change,
//                           style: AppTextStyles.subtext(
//                               color: const Color(0xFF2A9D5C))),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         );
//       }).toList(),
//     );
//   }
// }

// // ── Spacing Tokens Card ───────────────────────
// class _SpacingCard extends StatelessWidget {
//   final Color card, stroke, heading, bodyText, subText, divider;
//   const _SpacingCard({
//     required this.card,
//     required this.stroke,
//     required this.heading,
//     required this.bodyText,
//     required this.subText,
//     required this.divider,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final tokens = [
//       ('Text Spacing', '8px', AppSpacing.textSpacing),
//       ('Card Padding', '16px', AppSpacing.cardPadding),
//       ('Card Gap', '16px', AppSpacing.cardGap),
//       ('Section Spacing', '24px', AppSpacing.sectionSpacing),
//       ('Screen Padding', '16px', AppSpacing.screenPadding),
//     ];

//     return _BaseCard(
//       card: card,
//       stroke: stroke,
//       child: Column(
//         children: tokens.asMap().entries.map((e) {
//           final i = e.key;
//           final (name, value, size) = e.value;
//           return Column(
//             children: [
//               if (i != 0) Padding(
//                 padding: const EdgeInsets.symmetric(vertical: 10),
//                 child: Divider(color: divider, height: 1),
//               ),
//               if (i == 0) const SizedBox(height: 0),
//               Row(
//                 children: [
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(name,
//                             style: AppTextStyles.body(color: heading)
//                                 .copyWith(fontWeight: FontWeight.w500)),
//                         Text(value,
//                             style: AppTextStyles.subtext(color: subText)),
//                       ],
//                     ),
//                   ),
//                   Container(
//                     height: 10,
//                     width: size * 2.5,
//                     decoration: BoxDecoration(
//                       color: AppColors.primaryColor.withOpacity(0.2),
//                       borderRadius: BorderRadius.circular(2),
//                     ),
//                     child: Align(
//                       alignment: Alignment.centerLeft,
//                       child: Container(
//                         height: 10,
//                         width: size,
//                         decoration: BoxDecoration(
//                           color: AppColors.primaryColor,
//                           borderRadius: BorderRadius.circular(2),
//                         ),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//               if (i == tokens.length - 1) const SizedBox(height: 0),
//             ],
//           );
//         }).toList(),
//       ),
//     );
//   }
// }

// // ── Base Card ─────────────────────────────────
// class _BaseCard extends StatelessWidget {
//   final Color card, stroke;
//   final Widget child;
//   const _BaseCard({
//     required this.card,
//     required this.stroke,
//     required this.child,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: double.infinity,
//       padding: const EdgeInsets.all(AppSpacing.cardPadding),
//       decoration: BoxDecoration(
//         color: card,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: stroke),
//       ),
//       child: child,
//     );
//   }
// }