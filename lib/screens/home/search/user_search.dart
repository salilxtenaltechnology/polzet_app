// // ignore_for_file: prefer_final_fields, deprecated_member_use, unused_element, unused_field
// part of 'user_search_import.dart';

// class UserSearch extends StatefulWidget {
//   const UserSearch({super.key});

//   @override
//   State<StatefulWidget> createState() {
//     return UserSearchState();
//   }
// }

// // Add this model class for history items
// class SearchHistoryItem {
//   final String text;
//   final String type; // 'search' or 'profile'
//   final String? userId; // Only for profile visits
//   final DateTime timestamp;

//   SearchHistoryItem({
//     required this.text,
//     required this.type,
//     this.userId,
//     required this.timestamp,
//   });

//   Map<String, dynamic> toJson() {
//     return {
//       'text': text,
//       'type': type,
//       'userId': userId,
//       'timestamp': timestamp.millisecondsSinceEpoch,
//     };
//   }

//   static SearchHistoryItem fromJson(Map<String, dynamic> json) {
//     return SearchHistoryItem(
//       text: json['text'],
//       type: json['type'],
//       userId: json['userId'],
//       timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
//     );
//   }
// }

// class UserSearchState extends State<UserSearch>
//     with UtilityMixin, SingleTickerProviderStateMixin {
//   final TextEditingController _searchController = TextEditingController();
//   final ApiService _apiService = ApiService();

//   bool _isUsers = false;
//   bool _isUser = false;
//   bool _isLoading = false;
//   bool _isShowCategory = true;
//   final bool _isShowTab = true;
//   bool _hasSearched = false;
//   bool _showSearchHistory = false;

//   List<SearchUserModel> _users = [];
//   List<SearchHistoryItem> _searchHistory = [];
//   EnhancedTrendingHashtagsModel? _hashtagsData;
//   bool _isHashtagsLoading = false;

//   final Set<int> _chasedUserIds = {};

//   Timer? _debounce;

//   @override
//   void initState() {
//     super.initState();
//     _tabController = TabController(length: 5, vsync: this);
//     _searchController.addListener(_onSearchChanged);
//     _loadSearchHistory();
//     _fetchHashtags();
//   }

//   Future<void> _fetchHashtags() async {
//     setState(() => _isHashtagsLoading = true);
//     try {
//       final data = await _apiService.fetchEnhancedTrendingHashtags();
//       if (mounted) setState(() => _hashtagsData = data);
//     } catch (e) {
//       if (mounted) {
//         showToast(message: e.toString().replaceFirst('Exception: ', ''));
//       }
//     } finally {
//       if (mounted) setState(() => _isHashtagsLoading = false);
//     }
//   }

//   void _loadSearchHistory() async {
//     final prefs = await SharedPreferences.getInstance();
//     final historyJson = prefs.getStringList('user_search_history') ?? [];

//     setState(() {
//       _searchHistory = historyJson.map((jsonStr) {
//         try {
//           final json = jsonDecode(jsonStr);
//           return SearchHistoryItem.fromJson(json);
//         } catch (e) {
//           // Handle old format (plain strings) - convert to search type
//           return SearchHistoryItem(
//             text: jsonStr,
//             type: 'search',
//             timestamp: DateTime.now(),
//           );
//         }
//       }).toList();

//       // Sort by timestamp (newest first)
//       _searchHistory.sort((a, b) => b.timestamp.compareTo(a.timestamp));
//     });
//   }

//   void _saveSearchHistory() async {
//     final prefs = await SharedPreferences.getInstance();
//     final historyJson = _searchHistory
//         .map((item) => jsonEncode(item.toJson()))
//         .toList();
//     await prefs.setStringList('user_search_history', historyJson);
//   }

//   void _addToSearchHistory(String query) {
//     if (query.trim().isEmpty) return;

//     // Remove existing search query to avoid duplicates
//     _searchHistory.removeWhere(
//       (item) => item.text == query && item.type == 'search',
//     );

//     // Add new search to the beginning
//     _searchHistory.insert(
//       0,
//       SearchHistoryItem(text: query, type: 'search', timestamp: DateTime.now()),
//     );

//     // Keep only the last 20 items
//     if (_searchHistory.length > 20) {
//       _searchHistory = _searchHistory.take(20).toList();
//     }
//     _saveSearchHistory();
//   }

//   void _addProfileToHistory(String username, String userId) {
//     if (username.trim().isEmpty) return;

//     // Remove existing profile to avoid duplicates
//     _searchHistory.removeWhere(
//       (item) => item.userId == userId && item.type == 'profile',
//     );

//     // Add new profile visit to the beginning
//     _searchHistory.insert(
//       0,
//       SearchHistoryItem(
//         text: username,
//         type: 'profile',
//         userId: userId,
//         timestamp: DateTime.now(),
//       ),
//     );

//     // Keep only the last 20 items
//     if (_searchHistory.length > 20) {
//       _searchHistory = _searchHistory.take(20).toList();
//     }
//     _saveSearchHistory();
//   }

//   void _removeFromSearchHistory(SearchHistoryItem item) {
//     setState(() {
//       _searchHistory.remove(item);
//     });
//     _saveSearchHistory();
//   }

//   void _clearSearchHistory() {
//     setState(() {
//       _searchHistory.clear();
//     });
//     _saveSearchHistory();
//   }

//   void _onSearchChanged() {
//     if (_debounce?.isActive ?? false) _debounce!.cancel();

//     final query = _searchController.text.trim();

//     // Show/hide search history based on input
//     setState(() {
//       _showSearchHistory = query.isEmpty && !_hasSearched;
//     });

//     _debounce = Timer(const Duration(milliseconds: 400), () {
//       if (query.isNotEmpty) {
//         _search(query);
//       } else {
//         setState(() {
//           _users = [];
//           _hasSearched = false;
//           _showSearchHistory = true;
//         });
//       }
//     });
//   }

//   void _search(String query) async {
//     setState(() {
//       _isLoading = true;
//       _hasSearched = true;
//       _showSearchHistory = false;
//     });

//     try {
//       final results = await _apiService.searchUsers(query);
//       setState(() => _users = results);
//       // Add successful search to history
//       _addToSearchHistory(query);
//     } catch (e) {
//       // Handle 400 error specifically
//       final errorMsg = e.toString();
//       if (query.length < 2) {
//         showToast(message: 'Please enter at least 2 characters');
//         setState(() => _isLoading = false);
//         return;
//       } else {
//         showToast(message: errorMsg.replaceFirst('Exception: ', ''));
//       }
//     }
//     setState(() => _isLoading = false);
//   }

//   Widget _buildSearchHistory() {
//     return Padding(
//       padding: EdgeInsets.symmetric(horizontal: 5.w),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           if (_searchHistory.isNotEmpty) ...[
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Text(
//                   AppLocalizations.of(context)!.recentsearches,
//                   style: TextStyle(
//                     fontSize: 12.5.sp,
//                     fontWeight: FontWeight.w600,
//                     color: Theme.of(context).colorScheme.onBackground,
//                   ),
//                 ),
//                 GestureDetector(
//                   onTap: () {
//                     searchHistoryDiolog(context, () {
//                       _clearSearchHistory();
//                       Navigator.pop(context);
//                     });
//                   },
//                   child: Text(
//                     AppLocalizations.of(context)!.clearall,
//                     style: TextStyle(fontSize: 12.sp, color: Colors.red),
//                   ),
//                 ),
//               ],
//             ),
//             SizedBox(height: 8.h),
//             ..._searchHistory.map((item) => _buildSearchHistoryItem(item)),
//           ] else ...[
//             // Show "No history" when empty
//             Container(
//               width: double.infinity,
//               padding: EdgeInsets.symmetric(vertical: 50.h),
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Icon(
//                     Icons.history,
//                     size: 48.sp,
//                     color: Theme.of(
//                       context,
//                     ).colorScheme.onBackground.withOpacity(0.3),
//                   ),
//                   SizedBox(height: 16.h),
//                   Text(
//                     AppLocalizations.of(context)!.nohistory,
//                     style: TextStyle(
//                       fontSize: 16.sp,
//                       fontWeight: FontWeight.w500,
//                       color: Theme.of(
//                         context,
//                       ).colorScheme.onBackground.withOpacity(0.6),
//                     ),
//                   ),
//                   SizedBox(height: 8.h),
//                   Text(
//                     AppLocalizations.of(context)!.yoursearchhistory,
//                     textAlign: TextAlign.center,
//                     style: TextStyle(
//                       fontSize: 12.sp,
//                       color: Theme.of(
//                         context,
//                       ).colorScheme.onBackground.withOpacity(0.4),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ],
//       ),
//     );
//   }

//   Widget _buildSearchHistoryItem(SearchHistoryItem item) {
//     return Container(
//       margin: EdgeInsets.only(bottom: 8.h),
//       child: InkWell(
//         onTap: () {
//           if (item.type == 'search') {
//             _searchController.text = item.text;
//             _search(item.text);
//           } else if (item.type == 'profile' && item.userId != null) {
//             // For profile items, navigate directly to profile

//             // navigationPush(
//             //     context, PublicProfile(userId: int.parse(item.userId!)));
//           }
//         },
//         child: CustomCard(
//           widget: Row(
//             children: [
//               // Profile picture or search icon
//               if (item.type == 'profile') ...[
//                 // For profile items, try to get the profile picture from the search results
//                 // or show a default user icon
//                 FutureBuilder<SearchUserModel?>(
//                   future: _getUserFromSearchResults(item.text),
//                   builder: (context, snapshot) {
//                     final user = snapshot.data;
//                     final userProvider = Provider.of<UserProvider>(
//                       context,
//                       listen: false,
//                     );

//                     return CircleAvatar(
//                       radius: 16.r,
//                       backgroundImage: user?.profilePicture != null
//                           ? MemoryImage(
//                               userProvider.getProfileImage(
//                                 user!.profilePicture,
//                               )!,
//                             )
//                           : null,
//                       child: user?.profilePicture == null
//                           ? Image.asset(
//                               Assets.assetsImagesIcUser,
//                               height: 20.h,
//                               width: 20.w,
//                             )
//                           : null,
//                     );
//                   },
//                 ),
//               ] else ...[
//                 // For search items, show history icon
//                 Icon(
//                   Icons.history,
//                   size: 16.sp,
//                   color: Theme.of(
//                     context,
//                   ).colorScheme.onBackground.withOpacity(0.6),
//                 ),
//               ],

//               SizedBox(width: 12.w),

//               // Username/search text
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       item.text,
//                       style: TextStyle(
//                         fontSize: 12.sp,
//                         fontWeight: item.type == 'profile'
//                             ? FontWeight.w500
//                             : FontWeight.w400,
//                         color: Theme.of(context).colorScheme.onBackground,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),

//               // Timestamp
//               Text(
//                 _formatTimestamp(item.timestamp),
//                 style: TextStyle(
//                   fontSize: 10.sp,
//                   color: Theme.of(
//                     context,
//                   ).colorScheme.onBackground.withOpacity(0.4),
//                 ),
//               ),

//               SizedBox(width: 8.w),

//               // Remove button
//               IconButton(
//                 onPressed: () => _removeFromSearchHistory(item),
//                 icon: Icon(
//                   Icons.close,
//                   size: 16.sp,
//                   color: Theme.of(
//                     context,
//                   ).colorScheme.onBackground.withOpacity(0.4),
//                 ),
//                 constraints: const BoxConstraints(),
//                 padding: EdgeInsets.zero,
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   // Helper method to get user data from search results or cache
//   Future<SearchUserModel?> _getUserFromSearchResults(String username) async {
//     // First, check if the user is in the current search results
//     final userInResults = _users.firstWhere(
//       (user) => user.username == username,
//       orElse: () => SearchUserModel(
//         id: 0,
//         username: username,
//         firstName: '',
//         lastName: '',
//         profilePicture: null,
//         isFriend: false,
//         followStatus: '',
//       ),
//     );

//     if (userInResults.id != 0) {
//       return userInResults;
//     }

//     // If not in current results, you could optionally make an API call
//     // to get the user's current profile picture, but for simplicity,
//     // we'll return null to show the default avatar
//     return null;
//   }

//   String _formatTimestamp(DateTime timestamp) {
//     final now = DateTime.now();
//     final difference = now.difference(timestamp);

//     if (difference.inMinutes < 1) {
//       return 'Now';
//     } else if (difference.inMinutes < 60) {
//       return '${difference.inMinutes}m';
//     } else if (difference.inHours < 24) {
//       return '${difference.inHours}h';
//     } else if (difference.inDays < 7) {
//       return '${difference.inDays}d';
//     } else {
//       return '${timestamp.day}/${timestamp.month}';
//     }
//   }

//   late TabController _tabController;

//   @override
//   void dispose() {
//     _tabController.dispose();
//     _searchController.removeListener(_onSearchChanged);
//     _debounce?.cancel();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Theme.of(context).colorScheme.background,
//       appBar: AppBar(
//         backgroundColor: Theme.of(context).colorScheme.background,
//         automaticallyImplyLeading: false,
//         toolbarHeight: 50.h,
//         leadingWidth: double.infinity,
//         leading: Padding(
//           padding: EdgeInsets.only(bottom: 5.h, right: 10.w),
//           child: Row(
//             crossAxisAlignment: CrossAxisAlignment.center,
//             children: [
//               SizedBox(width: 7.w),
//               const Expanded(child: PrimaryBackButton()),
//               Expanded(
//                 flex: 10,
//                 child: Container(
//                   height: 34.7.h,
//                   width: double.infinity,
//                   decoration: BoxDecoration(
//                     color: Theme.of(context).colorScheme.background,
//                     borderRadius: BorderRadius.circular(15.r),
//                     boxShadow: const [
//                       BoxShadow(
//                         color: Colors.black12,
//                         blurRadius: 5,
//                         spreadRadius: 1,
//                       ),
//                     ],
//                   ),
//                   child: TextField(
//                     controller: _searchController,
//                     decoration: InputDecoration(
//                       contentPadding: EdgeInsets.only(
//                         right: 12.w,
//                         left: 12.w,
//                         top: 10.h,
//                       ),
//                       hintText: AppLocalizations.of(context)!.searchusers,
//                       hintStyle: CustomTextStyles.lblPrimaryHintText(context),
//                       border: InputBorder.none,
//                       suffixIcon: _searchController.text.isNotEmpty
//                           ? Row(
//                               mainAxisSize: MainAxisSize.min,
//                               children: [
//                                 GestureDetector(
//                                   onTap: () {
//                                     _searchController.clear();
//                                     setState(() {
//                                       _users = [];
//                                       _hasSearched = false;
//                                       _showSearchHistory = true;
//                                       _isShowCategory = false;
//                                     });
//                                   },
//                                   child: Icon(
//                                     Icons.clear,
//                                     size: 17.spMax,
//                                     color: Theme.of(
//                                       context,
//                                     ).colorScheme.onBackground,
//                                   ),
//                                 ),
//                                 SizedBox(width: 8.w),
//                                 GestureDetector(
//                                   onTap: () =>
//                                       _search(_searchController.text.trim()),
//                                   child: Icon(
//                                     FeatherIcons.search,
//                                     size: 17.spMax,
//                                     color: Theme.of(
//                                       context,
//                                     ).colorScheme.onBackground,
//                                   ),
//                                 ),
//                                 SizedBox(width: 8.w),
//                               ],
//                             )
//                           : GestureDetector(
//                               onTap: () =>
//                                   _search(_searchController.text.trim()),
//                               child: Icon(
//                                 FeatherIcons.search,
//                                 size: 17.spMax,
//                                 color: Theme.of(
//                                   context,
//                                 ).colorScheme.onBackground,
//                               ),
//                             ),
//                       enabledBorder: OutlineInputBorder(
//                         borderSide: BorderSide(
//                           color: Theme.of(
//                             context,
//                           ).colorScheme.onBackground.withOpacity(0.1),
//                         ),
//                         borderRadius: BorderRadius.circular(15.r),
//                       ),
//                       focusedBorder: OutlineInputBorder(
//                         borderSide: const BorderSide(
//                           color: AppColors.primaryColor,
//                           width: 0.7,
//                         ),
//                         borderRadius: BorderRadius.circular(15.r),
//                       ),
//                     ),
//                     style: TextStyle(
//                       color: Theme.of(context).colorScheme.onBackground,
//                       fontSize: 13.sp,
//                       fontWeight: FontWeight.w400,
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//       body: Column(
//         mainAxisAlignment: MainAxisAlignment.start,
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Padding(
//             padding: EdgeInsets.symmetric(horizontal: 5.w),
//             child: TabBar(
//               overlayColor: const WidgetStatePropertyAll(Colors.transparent),
//               tabAlignment: TabAlignment.fill,
//               indicator: FadeUnderlineTabIndicator(),
//               controller: _tabController,
//               labelPadding: EdgeInsets.symmetric(horizontal: 5.w),
//               indicatorSize: TabBarIndicatorSize.tab,
//               labelColor: Theme.of(context).colorScheme.primary,
//               labelStyle: TextStyle(
//                 color: Theme.of(context).colorScheme.onBackground,
//                 fontSize: 11.2.sp,
//                 fontWeight: FontWeight.w500,
//               ),
//               dividerColor: Colors.transparent,
//               unselectedLabelColor: Theme.of(context).colorScheme.onBackground,
//               tabs: const [
//                 Tab(text: 'Top'),
//                 Tab(text: 'Accounts'),
//                 Tab(text: 'Photos'),
//                 Tab(text: 'Tags'),
//                 Tab(text: 'Places'),
//               ],
//             ),
//           ),
//           Expanded(
//             child: TabBarView(
//               controller: _tabController,
//               children: [
//                 Column(
//                   children: [
//                     // Search History
//                     if (_showSearchHistory)
//                       Expanded(
//                         child: SingleChildScrollView(
//                           child: _buildSearchHistory(),
//                         ),
//                       ),
//                     // Search Results
//                     SizedBox(height: 10.h),
//                     Visibility(
//                       visible: _isShowTab && !_showSearchHistory,
//                       child: _isLoading
//                           ? const SearchUserSimmer()
//                           : !_hasSearched
//                           ? Center(
//                               child: Text(
//                                 '',
//                                 style: CustomTextStyles.lblPrimaryText(context),
//                               ),
//                             )
//                           : _users.isEmpty
//                           ? Expanded(
//                               child: Center(
//                                 child: Text(
//                                   AppLocalizations.of(context)!.usernotfound,
//                                   style: TextStyle(
//                                     fontSize: 11.sp,
//                                     color: const Color(0XFF999999),
//                                     fontWeight: FontWeight.w500,
//                                   ),
//                                 ),
//                               ),
//                             )
//                           : Expanded(
//                               child: ListView.builder(
//                                 itemCount: _users.length,
//                                 itemBuilder: (context, index) {
//                                   final user = _users[index];
//                                   final userProvider =
//                                       Provider.of<UserProvider>(context);
//                                   return Padding(
//                                     padding: EdgeInsets.only(
//                                       bottom: 10.h,
//                                       right: 10.w,
//                                       left: 10.w,
//                                     ),
//                                     child: CustomCard(
//                                       widget: Row(
//                                         children: [
//                                           GestureDetector(
//                                             onTap: () {
//                                               // Add to profile history when visiting - Fixed: Convert id to String
//                                               _addProfileToHistory(
//                                                 user.username,
//                                                 user.id.toString(),
//                                               );

//                                               navigationPush(
//                                                 context,
//                                                 PublicProfile(userId: user.id),
//                                               );
//                                             },
//                                             child: CircleAvatar(
//                                               backgroundImage:
//                                                   user.profilePicture != null
//                                                   ? MemoryImage(
//                                                       userProvider
//                                                           .getProfileImage(
//                                                             user.profilePicture,
//                                                           )!,
//                                                     )
//                                                   : null,
//                                               child: user.profilePicture == null
//                                                   ? Image.asset(
//                                                       Assets.assetsImagesIcUser,
//                                                       height: 27.h,
//                                                       width: 27.w,
//                                                     )
//                                                   : null,
//                                             ),
//                                           ),
//                                           SizedBox(width: 12.w),
//                                           Expanded(
//                                             child: GestureDetector(
//                                               onTap: () {
//                                                 _addProfileToHistory(
//                                                   user.username,
//                                                   user.id.toString(),
//                                                 );
//                                                 navigationPush(
//                                                   context,
//                                                   PublicProfile(
//                                                     userId: user.id,
//                                                   ),
//                                                 );
//                                               },
//                                               child: Column(
//                                                 crossAxisAlignment:
//                                                     CrossAxisAlignment.start,
//                                                 children: [
//                                                   Text(
//                                                     user.username,
//                                                     maxLines: 1,
//                                                     overflow:
//                                                         TextOverflow.ellipsis,
//                                                     softWrap: false,
//                                                     style: TextStyle(
//                                                       color: Theme.of(context)
//                                                           .colorScheme
//                                                           .onBackground,
//                                                       fontSize: 11.sp,
//                                                       fontWeight:
//                                                           FontWeight.w400,
//                                                     ),
//                                                   ),
//                                                   Text(
//                                                     '${user.firstName} ${user.lastName}',
//                                                     style: TextStyle(
//                                                       color: Theme.of(context)
//                                                           .colorScheme
//                                                           .onBackground
//                                                           .withOpacity(0.4),
//                                                       fontSize: 10.5.sp,
//                                                     ),
//                                                   ),
//                                                 ],
//                                               ),
//                                             ),
//                                           ),
//                                           //   SizedBox(width: 5.w),
//                                           // _buttonEvent(
//                                           //   const Color(0XFFC8FEC5),
//                                           //   Assets.assetsImagesIcFollow,
//                                           //   onTap: () {
//                                           //     userProvider.sendFriendRequest(
//                                           //       user.username,
//                                           //     );
//                                           //   },
//                                           // ),

//                                           // SizedBox(width: 5.w),
//                                           // _buttonEvent(
//                                           //   const Color(0XFFFFEAEA),
//                                           //   Assets.assetsImagesIcBlock,
//                                           //   onTap: () {
//                                           //     _showBlockSheet(context);
//                                           //   },
//                                           // ),
//                                           StatefulBuilder(
//                                             builder: (context, setLocalState) {
//                                               // Determine button label based on follow_status and is_friend
//                                               String getButtonLabel() {
//                                                 if (_chasedUserIds.contains(
//                                                   user.id,
//                                                 )) {
//                                                   return 'Chased';
//                                                 }
//                                                 if (user.isFriend &&
//                                                     user.followStatus ==
//                                                         'following') {
//                                                   return 'Chased';
//                                                 }
//                                                 if (user.followStatus ==
//                                                     'follower') {
//                                                   return 'Chase Back';
//                                                 }
//                                                 return 'Chase';
//                                               }

//                                               final label = getButtonLabel();
//                                               final isChased =
//                                                   label == 'Chased';

//                                               return GestureDetector(
//                                                 onTap: () async {
//                                                   if (isChased) {
//                                                     setLocalState(
//                                                       () => _chasedUserIds
//                                                           .remove(user.id),
//                                                     );
//                                                     try {
//                                                       await _apiService
//                                                           .unfriend(user.id);
//                                                     } catch (e) {
//                                                       setLocalState(
//                                                         () => _chasedUserIds
//                                                             .add(user.id),
//                                                       );
//                                                     }
//                                                   } else {
//                                                     setLocalState(
//                                                       () => _chasedUserIds.add(
//                                                         user.id,
//                                                       ),
//                                                     );
//                                                     try {
//                                                       await _apiService
//                                                           .sendFriendRequest(
//                                                             user.username,
//                                                           );
//                                                     } catch (e) {
//                                                       setLocalState(
//                                                         () => _chasedUserIds
//                                                             .remove(user.id),
//                                                       );
//                                                     }
//                                                   }
//                                                 },
//                                                 child: AnimatedContainer(
//                                                   duration: const Duration(
//                                                     milliseconds: 250,
//                                                   ),
//                                                   height: 22.h,
//                                                   padding: EdgeInsets.symmetric(
//                                                     horizontal: 7.w,
//                                                   ),
//                                                   margin: EdgeInsets.only(
//                                                     left: 8.w,
//                                                   ),
//                                                   decoration: BoxDecoration(
//                                                     color: isChased
//                                                         ? Colors.grey.shade400
//                                                         : Theme.of(
//                                                             context,
//                                                           ).colorScheme.primary,
//                                                     borderRadius:
//                                                         BorderRadius.circular(
//                                                           25.r,
//                                                         ),
//                                                   ),
//                                                   child: Center(
//                                                     child: Row(
//                                                       mainAxisAlignment:
//                                                           MainAxisAlignment
//                                                               .center,
//                                                       children: [
//                                                         if (label ==
//                                                             'Chase') ...[
//                                                           Icon(
//                                                             Icons.add,
//                                                             color: Colors.white,
//                                                             size: 15.sp,
//                                                           ),
//                                                           SizedBox(width: 3.w),
//                                                         ],
//                                                         Text(
//                                                           label,
//                                                           style: TextStyle(
//                                                             color: Colors.white,
//                                                             fontSize: 10.2.sp,
//                                                           ),
//                                                         ),
//                                                       ],
//                                                     ),
//                                                   ),
//                                                 ),
//                                               );
//                                             },
//                                           ),
//                                         ],
//                                       ),
//                                     ),
//                                   );
//                                 },
//                               ),
//                             ),
//                     ),
//                   ],
//                 ),
//                 const Center(child: Text('Accounts')),
//                 const Center(child: Text('Photos')),
//                 _isHashtagsLoading
//                     ? const Center(child: CircularProgressIndicator())
//                     : _hashtagsData == null
//                     ? Center(
//                         child: Text(
//                           'Failed to load tags',
//                           style: TextStyle(
//                             fontSize: 12.sp,
//                             color: Theme.of(
//                               context,
//                             ).colorScheme.onBackground.withOpacity(0.5),
//                           ),
//                         ),
//                       )
//                     : SingleChildScrollView(
//                         padding: EdgeInsets.symmetric(
//                           horizontal: 10.w,
//                           vertical: 8.h,
//                         ),
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             // Trending last 24h
//                             if (_hashtagsData!.trendingLast24h.isNotEmpty) ...[
//                               Text(
//                                  AppLocalizations.of(context)!.trendingtoday,
//                                 style: TextStyle(
//                                   fontSize: 12.5.sp,
//                                   fontWeight: FontWeight.w600,
//                                   color: Theme.of(
//                                     context,
//                                   ).colorScheme.onBackground,
//                                 ),
//                               ),
//                               SizedBox(height: 8.h),
//                               ..._hashtagsData!.trendingLast24h.map(
//                                 (tag) => _buildHashtagItem(tag),
//                               ),
//                               SizedBox(height: 12.h),
//                             ],

//                             // All time popular
//                             if (_hashtagsData!.allTimePopular.isNotEmpty) ...[
//                               Text(
//                                 AppLocalizations.of(context)!.alltimepopular,
//                                 style: TextStyle(
//                                   fontSize: 11.sp,
//                                   fontWeight: FontWeight.w600,
//                                   color: Theme.of(
//                                     context,
//                                   ).colorScheme.onBackground,
//                                 ),
//                               ),
//                               SizedBox(height: 8.h),
//                               ..._hashtagsData!.allTimePopular.map(
//                                 (tag) => _buildHashtagItem(tag),
//                               ),
//                             ],

//                             // Both empty
//                             if (_hashtagsData!.trendingLast24h.isEmpty &&
//                                 _hashtagsData!.allTimePopular.isEmpty)
//                               Center(
//                                 child: Padding(
//                                   padding: EdgeInsets.only(top: 50.h),
//                                   child: Text(
//                                     AppLocalizations.of(context)!.notagsavailable,
//                                     style: TextStyle(
//                                       fontSize: 12.sp,
//                                       color: Theme.of(context)
//                                           .colorScheme
//                                           .onBackground
//                                           .withOpacity(0.5),
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                           ],
//                         ),
//                       ),
//                 const Center(child: Text('Places')),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildHashtagItem(HashtagModel tag) {
//     return Padding(
//       padding: EdgeInsets.only(bottom: 8.h),
//       child: CustomCard(
//         widget: Row(
//           children: [
//             Container(
//               height: 32.h,
//               width: 32.w,
//               decoration: BoxDecoration(
//                 color: Theme.of(context).colorScheme.primaryContainer,
//                 shape: BoxShape.circle,
//                 border: Border.all(
//                   color: Colors.grey.withOpacity(0.5),
//                   width: 1.w,
//                 ),
//               ),
//               child: Center(
//                 child: Text(
//                   '#',
//                   style: TextStyle(
//                     fontSize: 15.sp,
//                     fontWeight: FontWeight.w700,
//                     color: Theme.of(
//                       context,
//                     ).colorScheme.primary.withOpacity(0.7),
//                   ),
//                 ),
//               ),
//             ),
//             SizedBox(width: 8.w),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     tag.name,
//                     style: TextStyle(
//                       fontSize: 11.sp,
//                       fontWeight: FontWeight.w500,
//                       color: Theme.of(context).colorScheme.onBackground,
//                     ),
//                   ),
//                   Text(
//                     '${tag.count} ${tag.count == 1 ? 'post' : 'posts'}',
//                     style: TextStyle(
//                       fontSize: 10.sp,
//                       color: Theme.of(
//                         context,
//                       ).colorScheme.onBackground.withOpacity(0.45),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   _buttonEvent(Color btnColor, String image, {required Null Function() onTap}) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         height: 25.h,
//         width: 25.w,
//         padding: const EdgeInsets.all(5).w,
//         decoration: BoxDecoration(
//           color: btnColor,
//           borderRadius: BorderRadius.circular(5.r),
//         ),
//         child: Image.asset(image),
//       ),
//     );
//   }

//   void _showBlockSheet(BuildContext context) {
//     showModalBottomSheet(
//       context: context,
//       builder: (BuildContext context) {
//         return StatefulBuilder(
//           builder: (BuildContext context, StateSetter setModalState) {
//             return Container(
//               padding: EdgeInsets.fromLTRB(12.w, 10.h, 12.w, 0),
//               decoration: BoxDecoration(
//                 color: Theme.of(context).colorScheme.secondaryContainer,
//                 borderRadius: BorderRadius.only(
//                   topLeft: Radius.circular(50.r),
//                   topRight: Radius.circular(50.r),
//                 ),
//               ),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Container(
//                     height: 2.h,
//                     width: 70.w,
//                     decoration: BoxDecoration(
//                       color: const Color(0x7C868686),
//                       borderRadius: BorderRadius.circular(5.r),
//                     ),
//                   ),
//                   SizedBox(height: 15.h),
//                   Text(
//                     AppLocalizations.of(context)!.blockadweekttl,
//                     style: CustomTextStyles.popTitleText(context),
//                   ),
//                   Divider(
//                     color: Theme.of(
//                       context,
//                     ).colorScheme.onBackground.withOpacity(0.1),
//                     height: 25.h,
//                   ),
//                   Text(
//                     AppLocalizations.of(context)!.theywonotbeable,
//                     textAlign: TextAlign.center,
//                     style: TextStyle(
//                       color: const Color(0XFFAAAAAA),
//                       fontSize: 11.5.sp,
//                       fontWeight: FontWeight.w400,
//                     ),
//                   ),
//                   SizedBox(height: 20.h),
//                   Row(
//                     crossAxisAlignment: CrossAxisAlignment.center,
//                     children: [
//                       const Icon(FeatherIcons.users),
//                       SizedBox(width: 10.w),
//                       Expanded(
//                         child: Text(
//                           AppLocalizations.of(
//                             context,
//                           )!.blockadweekandnewaccounts,
//                           textAlign: TextAlign.start,
//                           style: CustomTextStyles.lblSecondryText(context),
//                         ),
//                       ),
//                       SizedBox(width: 7.w),
//                       GestureDetector(
//                         onTap: () {
//                           setModalState(() {
//                             _isUsers = !_isUsers;
//                           });
//                         },
//                         child: Container(
//                           height: 20.h,
//                           width: 20.w,
//                           decoration: BoxDecoration(
//                             shape: BoxShape.circle,
//                             border: Border.all(
//                               color: _isUsers
//                                   ? AppColors.primaryColor
//                                   : Theme.of(
//                                       context,
//                                     ).colorScheme.onBackground.withOpacity(0.2),
//                               width: _isUsers ? 4 : 1,
//                             ),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                   SizedBox(height: 12.h),
//                   Row(
//                     crossAxisAlignment: CrossAxisAlignment.center,
//                     children: [
//                       const Icon(FeatherIcons.user),
//                       SizedBox(width: 10.w),
//                       Expanded(
//                         child: Text(
//                           AppLocalizations.of(context)!.blockadweek,
//                           textAlign: TextAlign.start,
//                           style: CustomTextStyles.lblSecondryText(context),
//                         ),
//                       ),
//                       SizedBox(width: 7.w),
//                       GestureDetector(
//                         onTap: () {
//                           setModalState(() {
//                             _isUser = !_isUser;
//                           });
//                         },
//                         child: Container(
//                           height: 20.h,
//                           width: 20.w,
//                           decoration: BoxDecoration(
//                             shape: BoxShape.circle,
//                             border: Border.all(
//                               color: _isUser
//                                   ? AppColors.primaryColor
//                                   : Theme.of(
//                                       context,
//                                     ).colorScheme.onBackground.withOpacity(0.2),
//                               width: _isUser ? 4 : 1,
//                             ),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                   Divider(
//                     color: Theme.of(
//                       context,
//                     ).colorScheme.onBackground.withOpacity(0.1),
//                     height: 20.h,
//                   ),
//                   PrimaryButton(
//                     onPressed: () {},
//                     height: 35.h,
//                     title: AppLocalizations.of(context)!.block,
//                     isLoading: _isLoading,
//                   ),
//                 ],
//               ),
//             );
//           },
//         );
//       },
//     );
//   }
// }
