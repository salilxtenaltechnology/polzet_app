// ignore_for_file: deprecated_member_use
part of 'home_imports.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

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

  final List screens = [
    Dashboard(),
    InsightsScreen(),
    PollPop(),
    Notifications(),
    UserProfile(),
  ];

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
    // Load user data silently in background without showing loading state
    userProvider.loadUserDataSilently();
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: pageIndex == 4
          ? PreferredSize(preferredSize: Size.zero, child: SizedBox.shrink())
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
                            fontSize: 16.sp,
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
                                fontSize: 13.sp,
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
                                fontSize: 13.sp,
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
                      navigationPush(context, UserSearch());
                    },
                    icon: FeatherIcons.search,
                  ),
                SizedBox(width: 9.w),
                if (pageIndex == 0)
                  AppIcons(
                    onTap: () {
                      navigationPush(context, MessageList());
                    },
                    icon: FeatherIcons.messageSquare,
                  ),
                SizedBox(width: 7.w),
                if (pageIndex == 0)
                  AppIcons(
                    onTap: () {
                      navigationPush(context, Settings());
                    },
                    icon: FeatherIcons.settings,
                  ),
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
            return NewPollBottomsheet();
          },
        );
      },
    );
  }
}
