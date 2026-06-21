// ignore_for_file: deprecated_member_use
part of 'home_imports.dart';

class HomeScreen extends StatefulWidget {
  final int initialIndex;
  final Widget? pendingDestination;

  const HomeScreen({super.key, this.initialIndex = 0, this.pendingDestination});

  @override
  State<StatefulWidget> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> with UtilityMixin, WidgetsBindingObserver {
  String? firstname;
  String? lastname;
  int pageIndex = 0;
  GlobalKey<CurvedNavigationBarState> bottomNavigationKey = GlobalKey();
  final GlobalKey _addFabShowcaseKey = GlobalKey();
  final GlobalKey _insightsShowcaseKey = GlobalKey();
  bool _showcaseChecked = false;
  DateTime? _lastPressed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    pageIndex = widget.initialIndex;
    _loadCachedUserData();
    _initializeDeepLinking();
    MessageListState.startGlobalPolling();
    NotificationState.startGlobalPolling();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService().initialize();

      // Set the flag that home screen is now visible and ready for direct navigation
      NotificationRouter.isHomeScreenVisible = true;

      if (widget.pendingDestination != null) {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => widget.pendingDestination!));
        NotificationRouter().clear();
      } else if (NotificationRouter().hasPendingNotification()) {
        NotificationRouter().handlePendingNotification(context);
      }

      // Check for app updates (Play Store vs App Side fallback)
      AppUpdateService().checkForUpdate(context);
    });
  }

  @override
  void dispose() {
    NotificationRouter.isHomeScreenVisible = false;
    WidgetsBinding.instance.removeObserver(this);
    MessageListState.stopGlobalPolling();
    NotificationState.stopGlobalPolling();
    DeepLinkService().dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('📱 HomeScreen resumed from background: Fetching fresh data...');
      Future.wait([
        MessageListState.refreshGlobally(),
        NotificationState.refreshGlobally(),
      ]);
      DashboardState.triggerRefresh();
    }
  }

  void _initializeDeepLinking() {
    DeepLinkService().initialize(
      onPostLinkReceived: (username, postId) {
        _navigateToPostDetail(username, postId);
      },
      onProfileLinkReceived: (username) {
        _navigateToProfileDetail(username);
      },
    );
  }

  void _navigateToProfileDetail(String username) async {
    if (!mounted) return;

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUsername = userProvider.username;

    if (currentUsername != null &&
        currentUsername.toLowerCase() == username.toLowerCase()) {
      // Pop all other screens to return to the base HomeScreen
      Navigator.popUntil(context, (route) => route.isFirst);
      // Navigate to current user profile tab
      navigateToUserProfile();
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PublicProfileScreen(username: username),
      ),
    );
  }

  void _navigateToPostDetail(String username, String postId) {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SinglePostDetails(
          username: username,
          postId: postId,
        ),
      ),
    );
  }

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
    const MessageList(),
    const PollPop(),
    const InsightsScreen(),
    const ProfileScreen(),
  ];

  void navigateToNotifications() {
    setState(() => pageIndex = 3);
    bottomNavigationKey.currentState?.setPage(3);
  }

  void navigateToUserProfile() {
    setState(() => pageIndex = 4);
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

    return ShowCaseWidget(
      builder: (showcaseContext) {
        if (!_showcaseChecked) {
          _showcaseChecked = true;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            final prefs = await SharedPreferences.getInstance();
            final bool hasShownShowcase =
                prefs.getBool('hasShownShowcase') ?? false;
            if (!hasShownShowcase && mounted) {
              ShowCaseWidget.of(
                showcaseContext,
              ).startShowCase([_addFabShowcaseKey, _insightsShowcaseKey]);
              await prefs.setBool('hasShownShowcase', true);
            }
          });
        }

        return SafeArea(
          top: false,
          child: PopScope(
            canPop: false,
            onPopInvoked: (didPop) async {
              if (didPop) return;
              final now = DateTime.now();
              final backButtonHasNotBeenPressedOrSnackBarHasClosed =
                  _lastPressed == null ||
                  now.difference(_lastPressed!) > const Duration(seconds: 2);

              if (backButtonHasNotBeenPressedOrSnackBarHasClosed) {
                _lastPressed = now;
                showToast(message: 'Press back again to exit app');
              } else {
                SystemNavigator.pop();
              }
            },
            child: Scaffold(
              extendBody: true,
              backgroundColor: Theme.of(context).colorScheme.background,
              appBar: pageIndex == 4
                  ? null
                  : AppBar(
                      backgroundColor: Theme.of(context).colorScheme.background,
                      surfaceTintColor: Theme.of(
                        context,
                      ).colorScheme.background,
                      automaticallyImplyLeading: false,
                      toolbarHeight: 42.h,
                      title: pageIndex == 0
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppLocalizations.of(context)!.hello,
                                  style: AppTextStyles.cardTitle.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Text(
                                      userProvider.isLoading
                                          ? firstname ?? ''
                                          : (userProvider.firstName ?? ''),
                                      style: AppTextStyles.bodyText.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onBackground,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(width: 5.w),
                                    Text(
                                      userProvider.isLoading
                                          ? lastname ?? ''
                                          : ((userProvider.lastName ?? '')
                                                    .isNotEmpty
                                                ? "${userProvider.lastName} 👋"
                                                : " "),
                                      style: AppTextStyles.bodyText.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onBackground,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          : pageIndex == 1
                          ? Text(
                              AppLocalizations.of(context)!.messages,
                              style: AppTextStyles.pageTitleTextStyle(context),
                            )
                          : pageIndex == 3
                          ? Text(
                              AppLocalizations.of(context)!.insights,
                              style: AppTextStyles.pageTitleTextStyle(context),
                            )
                          : null,
                      // centerTitle: pageIndex == 2 ? false : true,
                      centerTitle: false,
                      actions: [
                        if (pageIndex == 0)
                          // AppIcons(
                          //   onTap: () {
                          //   ConnectivityOverlay.showTestSheet(context, 'server');
                          //     showModalBottomSheet(
                          //       context: context,
                          //       isScrollControlled: true, // ← required for tall sheets
                          //       backgroundColor: Colors.transparent,
                          //       builder: (_) => const FeedbackBottomsheet(),
                          //     );
                          //   },
                          //   icon: Icons.feedback,
                          // ),
                          // if (pageIndex == 0)
                          //   AppIcons(
                          //     onTap: () {
                          //       navigationPush(context, const FlowScreen());
                          //     },
                          //     icon: Icons.person,
                          //   ),
                          // SizedBox(width: 9.w),
                          if (pageIndex == 0)
                            AppIcons(
                              onTap: () => navigationPush(
                                context,
                                const GlobalSearchScreen(),
                              ),
                              icon: FeatherIcons.search,
                            ),
                        SizedBox(width: 9.w),
                        if (pageIndex == 0)
                          ValueListenableBuilder<int>(
                            valueListenable:
                                NotificationState.unreadNotificationCount,
                            builder: (context, unreadCount, _) {
                              return GestureDetector(
                                onTap: () {
                                  navigationPush(
                                    context,
                                    const Notifications(),
                                  );
                                },
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    AppIcons(
                                      onTap: () {
                                        navigationPush(
                                          context,
                                          const Notifications(),
                                        );
                                      },
                                      icon: FeatherIcons.bell,
                                    ),
                                    if (unreadCount > 0)
                                      Positioned(
                                        top: -8,
                                        right: -7,
                                        child: Container(
                                          width: 19.5,
                                          height: 19.5,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFB82B53),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.background,
                                              width: 1.5,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              unreadCount.toString(),
                                              style: AppTextStyles.subText
                                                  .copyWith(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 9.8,
                                                  ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        SizedBox(width: 8.w),
                        if (pageIndex == 1)
                          GestureDetector(
                            onTap: () async {
                              final createdChatId = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const CreateGroup(),
                                ),
                              );
                              if (createdChatId != null) {
                                MessageListState.refreshGlobally();
                                MessageListState.selectTab(1);
                              }
                            },
                            child: Assets.images.addGroup.image(
                              width: 28,
                              height: 28,
                              fit: BoxFit.contain,
                              color: Theme.of(context).colorScheme.onBackground,
                            ),
                          ),
                        SizedBox(width: 9.w),
                      ],
                    ),
              body: pageIndex == 4
                  ? screens[pageIndex]
                  : SafeArea(bottom: false, child: screens[pageIndex]),
              bottomNavigationBar: ValueListenableBuilder<int>(
                valueListenable: NotificationState.unreadNotificationCount,
                builder: (context, unreadNotificationCount, _) {
                  return ValueListenableBuilder<int>(
                    valueListenable: MessageListState.unreadMessageCount,
                    builder: (context, unreadMessageCount, _) {
                      return CustomBottomNavigationBar(
                        index: pageIndex,
                        bottomNavigationKey: bottomNavigationKey,
                        onTap: (i) {
                          if (i != 2) {
                            if (pageIndex == i) {
                              if (i == 0) {
                                DashboardState.triggerRefresh();
                              } else if (i == 1) {
                                MessageListState.refreshGlobally();
                              }
                            } else {
                              setState(() => pageIndex = i);
                            }
                          }
                        },
                        notificationCount: unreadNotificationCount,
                        messageCount: unreadMessageCount,
                        onAddTap: () =>
                            BottomSheetUtils.showNewPollBottomSheet(context),
                        addFabShowcaseKey: _addFabShowcaseKey,
                        insightsShowcaseKey: _insightsShowcaseKey,
                      );
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
