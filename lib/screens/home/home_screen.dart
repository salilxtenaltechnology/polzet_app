// ignore_for_file: deprecated_member_use
part of 'home_imports.dart';

class HomeScreen extends StatefulWidget {
  final int initialIndex;
  final Widget? pendingDestination;
  
  const HomeScreen({
    super.key, 
    this.initialIndex = 0,
    this.pendingDestination,
  });

  @override
  State<StatefulWidget> createState() {
    return HomeScreenState();
  }
}

class HomeScreenState extends State<HomeScreen> with UtilityMixin {
  String? firstname;
  String? lastname;
  int pageIndex = 0;
  GlobalKey<CurvedNavigationBarState> bottomNavigationKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    pageIndex = widget.initialIndex;
    _loadCachedUserData();
    
    // Initialize notifications and request permissions after login/splash
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService().initialize();

      // ✅ Handle pending navigation (safely after build)
      if (widget.pendingDestination != null) {
        debugPrint('🚀 HomeScreen: Navigating to pending destination: ${widget.pendingDestination.runtimeType}');
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => widget.pendingDestination!,
          ),
        );
        // ✅ Cleared pending notification after handling
        NotificationRouter().clear();
      }
      // ✅ NEW: Safety check for pending notifications (intermittent fix)
      // Handles cases where main.dart didn't pass it (e.g., warm start)
      else if (NotificationRouter().hasPendingNotification()) {
         debugPrint('🚀 HomeScreen: Found pending notification in Router (intermittent fix)');
         NotificationRouter().handlePendingNotification(context);
      }
    });
  }

  // ✅ Load cached user data for immediate display
  Future<void> _loadCachedUserData() async {
    try {
      final fName = await SharedPrefService.getFirstName();
      final lName = await SharedPrefService.getLastName();
      
      if (mounted) {
        setState(() {
          firstname = fName;
          lastname = lName;
        });
      }
    } catch (e) {
      debugPrint('Error loading cached user data: $e');
    }
  }

  final List screens = [
    const Dashboard(),
    const InsightsScreen(),
    const PollPop(),
    const Notifications(),
    const UserProfile(),
  ];

  void navigateToNotifications() {
    setState(() {
      pageIndex = 3;
    });
    bottomNavigationKey.currentState?.setPage(3);
  }

  void navigateToUserProfile() {
    setState(() {
      pageIndex = 4;
    });
    bottomNavigationKey.currentState?.setPage(4);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    userProvider.loadUserDataSilently();
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: pageIndex == 4
          ? const PreferredSize(
              preferredSize: Size.zero,
              child: SizedBox.shrink(),
            )
          : AppBar(
              backgroundColor: Theme.of(context).colorScheme.background,
              surfaceTintColor: Theme.of(context).colorScheme.background,
              automaticallyImplyLeading: false,
              toolbarHeight: 38.h,
              title: pageIndex == 0
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.hello,
                          style: GoogleFonts.poppins(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Text(
                              userProvider.isLoading
                                  ? firstname ?? ''
                                  : (userProvider.firstName ?? ''),
                              style: GoogleFonts.poppins(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onBackground,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.2,
                              ),
                            ),
                            SizedBox(width: 5.w),
                            Text(
                              userProvider.isLoading
                                  ? lastname ?? ''
                                  : ((userProvider.lastName ?? '').isNotEmpty
                                        ? "${userProvider.lastName} 👋"
                                        : " "),
                              style: GoogleFonts.poppins(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onBackground,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : pageIndex == 1
                  ? Text(
                      AppLocalizations.of(context)!.insights,
                      style: CustomTextStyles.appBarTitleText(context),
                    )
                  : pageIndex == 3
                  ? Text(
                      AppLocalizations.of(context)!.notifications,
                      style: CustomTextStyles.appBarTitleText(context),
                    )
                  : null,
              centerTitle: pageIndex == 2
                  ? pageIndex == 3
                        ? true
                        : false
                  : true,
              actions: [
                // home icons
                if (pageIndex == 0)
                  AppIcons(
                    onTap: () {
                      navigationPush(context, const UserSearch());
                    },
                    icon: FeatherIcons.search,
                  ),
                SizedBox(width: 9.w),
                if (pageIndex == 0)
                  AppIcons(
                    onTap: () {
                      navigationPush(context, const MessageList());
                    },
                    icon: FeatherIcons.messageSquare,
                  ),
                // SizedBox(width: 7.w),
                // if (pageIndex == 0)
                //   AppIcons(
                //     onTap: () {
                //       navigationPush(context, const Settings());
                //     },
                //     icon: FeatherIcons.settings,
                //   ),
                SizedBox(width: 8.w),
              ],
            ),
      body: SafeArea(child: screens[pageIndex]),
      floatingActionButton: SafeArea(
        child: CustomFloatingActionButton(
          onTap: () {
            _showNewPollSheet(context);
          },
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: SafeArea(
        child: CustomBottomNavigationBar(
          index: pageIndex,
          bottomNavigationKey: bottomNavigationKey,
          onTap: (index) {
            setState(() {
              pageIndex = index;
            });
          },
        ),
      ),
    );
  }

  void _showNewPollSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Builder(
          builder: (BuildContext context) {
            return const NewPollBottomsheet();
          },
        );
      },
    );
  }
}