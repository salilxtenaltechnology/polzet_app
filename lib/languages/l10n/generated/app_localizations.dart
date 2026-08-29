import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_id.dart';
import 'app_localizations_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('hi'),
    Locale('id'),
    Locale('vi'),
  ];

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @hindi.
  ///
  /// In en, this message translates to:
  /// **'Hindi'**
  String get hindi;

  /// No description provided for @arabic.
  ///
  /// In en, this message translates to:
  /// **'Árabe'**
  String get arabic;

  /// No description provided for @hello.
  ///
  /// In en, this message translates to:
  /// **'Hello'**
  String get hello;

  /// No description provided for @improveyourprofile.
  ///
  /// In en, this message translates to:
  /// **'Improve your profile'**
  String get improveyourprofile;

  /// No description provided for @completeprofilesetup.
  ///
  /// In en, this message translates to:
  /// **'Complete profile setup'**
  String get completeprofilesetup;

  /// No description provided for @peopleyoumayknow.
  ///
  /// In en, this message translates to:
  /// **'People you may know'**
  String get peopleyoumayknow;

  /// No description provided for @discoverdusers.
  ///
  /// In en, this message translates to:
  /// **'Discoverd users'**
  String get discoverdusers;

  /// No description provided for @searchgroup.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchgroup;

  /// No description provided for @searchusers.
  ///
  /// In en, this message translates to:
  /// **'Search users'**
  String get searchusers;

  /// No description provided for @usernotfound.
  ///
  /// In en, this message translates to:
  /// **'User not found'**
  String get usernotfound;

  /// No description provided for @recentsearches.
  ///
  /// In en, this message translates to:
  /// **'Recent searches'**
  String get recentsearches;

  /// No description provided for @clearall.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get clearall;

  /// No description provided for @nohistory.
  ///
  /// In en, this message translates to:
  /// **'No history'**
  String get nohistory;

  /// No description provided for @yoursearchhistory.
  ///
  /// In en, this message translates to:
  /// **'Your search history will appear here'**
  String get yoursearchhistory;

  /// No description provided for @clearsearchhistory.
  ///
  /// In en, this message translates to:
  /// **'Clear search history?'**
  String get clearsearchhistory;

  /// No description provided for @areyousurewanttoclearallsaerchhistory.
  ///
  /// In en, this message translates to:
  /// **'Are you sure want to clear all saerch history?'**
  String get areyousurewanttoclearallsaerchhistory;

  /// No description provided for @insights.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get insights;

  /// No description provided for @pollcreated.
  ///
  /// In en, this message translates to:
  /// **'Poll Created'**
  String get pollcreated;

  /// No description provided for @weeklyviews.
  ///
  /// In en, this message translates to:
  /// **'Weekly Views'**
  String get weeklyviews;

  /// No description provided for @insightsareavailable.
  ///
  /// In en, this message translates to:
  /// **'Insights are available only for Business Accounts'**
  String get insightsareavailable;

  /// No description provided for @trackpollvotesreactions.
  ///
  /// In en, this message translates to:
  /// **'Track poll votes, reactions, shares, followers, and growth trends with advanced analytics. Upgrade to a Business Account today to unlock insights.'**
  String get trackpollvotesreactions;

  /// No description provided for @switchtobusinessaccount.
  ///
  /// In en, this message translates to:
  /// **'SWITCH TO BUSINESS ACCOUNT'**
  String get switchtobusinessaccount;

  /// No description provided for @upgradetobusinessaccount.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to business account?'**
  String get upgradetobusinessaccount;

  /// No description provided for @morefunctionalitywillbesoon.
  ///
  /// In en, this message translates to:
  /// **'More Functionality will be soon!'**
  String get morefunctionalitywillbesoon;

  /// No description provided for @youareabouttounlockpowerfull.
  ///
  /// In en, this message translates to:
  /// **'You are about to unlock powerful analytics and features. Confirm to proceed.'**
  String get youareabouttounlockpowerfull;

  /// No description provided for @upgrade.
  ///
  /// In en, this message translates to:
  /// **'Upgrade'**
  String get upgrade;

  /// No description provided for @totalviews.
  ///
  /// In en, this message translates to:
  /// **'Total Views'**
  String get totalviews;

  /// No description provided for @engagementrate.
  ///
  /// In en, this message translates to:
  /// **'Engagement Rate'**
  String get engagementrate;

  /// No description provided for @blockadweekttl.
  ///
  /// In en, this message translates to:
  /// **'Block Adweek?'**
  String get blockadweekttl;

  /// No description provided for @theywonotbeable.
  ///
  /// In en, this message translates to:
  /// **'They Won’t be able to message you or find your profile, posts or story on Polzet.They won’t be notified that you blckred them.'**
  String get theywonotbeable;

  /// No description provided for @blockadweekandnewaccounts.
  ///
  /// In en, this message translates to:
  /// **'Block adweek and new accounts they may create'**
  String get blockadweekandnewaccounts;

  /// No description provided for @blockadweek.
  ///
  /// In en, this message translates to:
  /// **'Block adweek'**
  String get blockadweek;

  /// No description provided for @block.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get block;

  /// No description provided for @unblock.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get unblock;

  /// No description provided for @messages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get messages;

  /// No description provided for @pollgroup.
  ///
  /// In en, this message translates to:
  /// **'Poll group'**
  String get pollgroup;

  /// No description provided for @newgroup.
  ///
  /// In en, this message translates to:
  /// **'New Group'**
  String get newgroup;

  /// No description provided for @creategroup.
  ///
  /// In en, this message translates to:
  /// **'Create Group'**
  String get creategroup;

  /// No description provided for @namegroup.
  ///
  /// In en, this message translates to:
  /// **'Name Group'**
  String get namegroup;

  /// No description provided for @entergroupame.
  ///
  /// In en, this message translates to:
  /// **'Enter group name'**
  String get entergroupame;

  /// No description provided for @addmemberstothegroup.
  ///
  /// In en, this message translates to:
  /// **'Add members to the group'**
  String get addmemberstothegroup;

  /// No description provided for @members.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get members;

  /// No description provided for @admin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get admin;

  /// No description provided for @addmemberstogroup.
  ///
  /// In en, this message translates to:
  /// **'Add members to group'**
  String get addmemberstogroup;

  /// No description provided for @nousersfound.
  ///
  /// In en, this message translates to:
  /// **'No users found'**
  String get nousersfound;

  /// No description provided for @nousersavailable.
  ///
  /// In en, this message translates to:
  /// **'No users available'**
  String get nousersavailable;

  /// No description provided for @startchasepeopletoseethemhere.
  ///
  /// In en, this message translates to:
  /// **'Start chase people to see them here!'**
  String get startchasepeopletoseethemhere;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @makeadmin.
  ///
  /// In en, this message translates to:
  /// **'Make Admin'**
  String get makeadmin;

  /// No description provided for @removefromgroup.
  ///
  /// In en, this message translates to:
  /// **'Remove from group'**
  String get removefromgroup;

  /// No description provided for @addmember.
  ///
  /// In en, this message translates to:
  /// **'Add Member'**
  String get addmember;

  /// No description provided for @invitetogroupvialink.
  ///
  /// In en, this message translates to:
  /// **'Invite to group via link'**
  String get invitetogroupvialink;

  /// No description provided for @forpolloption.
  ///
  /// In en, this message translates to:
  /// **'For Poll Option'**
  String get forpolloption;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @poll.
  ///
  /// In en, this message translates to:
  /// **'Poll'**
  String get poll;

  /// No description provided for @request.
  ///
  /// In en, this message translates to:
  /// **'Request'**
  String get request;

  /// No description provided for @norequestavailable.
  ///
  /// In en, this message translates to:
  /// **'No request available'**
  String get norequestavailable;

  /// No description provided for @mutenotifications.
  ///
  /// In en, this message translates to:
  /// **'Mute Notifications'**
  String get mutenotifications;

  /// No description provided for @appnotification.
  ///
  /// In en, this message translates to:
  /// **'App Notification'**
  String get appnotification;

  /// No description provided for @likeonyourposts.
  ///
  /// In en, this message translates to:
  /// **'Like on your posts'**
  String get likeonyourposts;

  /// No description provided for @commentsonyourposts.
  ///
  /// In en, this message translates to:
  /// **'Comments on your posts'**
  String get commentsonyourposts;

  /// No description provided for @message.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get message;

  /// No description provided for @membersinchat.
  ///
  /// In en, this message translates to:
  /// **'members'**
  String get membersinchat;

  /// No description provided for @nomessagesyetstarttheconversation.
  ///
  /// In en, this message translates to:
  /// **'No messages yet.\nStart the conversation!'**
  String get nomessagesyetstarttheconversation;

  /// No description provided for @seeallmembers.
  ///
  /// In en, this message translates to:
  /// **'See all members'**
  String get seeallmembers;

  /// No description provided for @medialinksdocs.
  ///
  /// In en, this message translates to:
  /// **'Media, Links & Documents'**
  String get medialinksdocs;

  /// No description provided for @media.
  ///
  /// In en, this message translates to:
  /// **'Media'**
  String get media;

  /// No description provided for @nomedia.
  ///
  /// In en, this message translates to:
  /// **'No media'**
  String get nomedia;

  /// No description provided for @mediasharedinthischatwillappearhere.
  ///
  /// In en, this message translates to:
  /// **'Media shared in this chat will appear here!'**
  String get mediasharedinthischatwillappearhere;

  /// No description provided for @link.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get link;

  /// No description provided for @nolinks.
  ///
  /// In en, this message translates to:
  /// **'No links'**
  String get nolinks;

  /// No description provided for @linkssharedinthischatwillappearhere.
  ///
  /// In en, this message translates to:
  /// **'Links shared in this chat will appear here!'**
  String get linkssharedinthischatwillappearhere;

  /// No description provided for @document.
  ///
  /// In en, this message translates to:
  /// **'Document'**
  String get document;

  /// No description provided for @nodocuments.
  ///
  /// In en, this message translates to:
  /// **'No documents'**
  String get nodocuments;

  /// No description provided for @docssharedinthischatwillappearhere.
  ///
  /// In en, this message translates to:
  /// **'Docs shared in this chat will appear here!'**
  String get docssharedinthischatwillappearhere;

  /// No description provided for @mutenotification.
  ///
  /// In en, this message translates to:
  /// **'Mute Notification'**
  String get mutenotification;

  /// No description provided for @customnotification.
  ///
  /// In en, this message translates to:
  /// **'Custom Notification'**
  String get customnotification;

  /// No description provided for @protectedchat.
  ///
  /// In en, this message translates to:
  /// **'Protected Chat'**
  String get protectedchat;

  /// No description provided for @hidechat.
  ///
  /// In en, this message translates to:
  /// **'Hide Chat'**
  String get hidechat;

  /// No description provided for @hidechathistory.
  ///
  /// In en, this message translates to:
  /// **'Hide Chat History'**
  String get hidechathistory;

  /// No description provided for @customcolorchat.
  ///
  /// In en, this message translates to:
  /// **'Custom Color Chat'**
  String get customcolorchat;

  /// No description provided for @custombackgroundchat.
  ///
  /// In en, this message translates to:
  /// **'Custom Background Chat'**
  String get custombackgroundchat;

  /// No description provided for @deletegroup.
  ///
  /// In en, this message translates to:
  /// **'Delete group'**
  String get deletegroup;

  /// No description provided for @areyousureyouwanttodeletedeletethisgroup.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this group?'**
  String get areyousureyouwanttodeletedeletethisgroup;

  /// No description provided for @areyousureyouwanttoreportchatthisuser.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to report chat this user?'**
  String get areyousureyouwanttoreportchatthisuser;

  /// No description provided for @newvibe.
  ///
  /// In en, this message translates to:
  /// **'New Vibe'**
  String get newvibe;

  /// No description provided for @mentionsandtags.
  ///
  /// In en, this message translates to:
  /// **'Mentions & Tags'**
  String get mentionsandtags;

  /// No description provided for @answer.
  ///
  /// In en, this message translates to:
  /// **'Answer'**
  String get answer;

  /// No description provided for @image.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get image;

  /// No description provided for @addnewpoll.
  ///
  /// In en, this message translates to:
  /// **'Add New Poll'**
  String get addnewpoll;

  /// No description provided for @addnewpollanswer.
  ///
  /// In en, this message translates to:
  /// **'Add New Poll Answer'**
  String get addnewpollanswer;

  /// No description provided for @question.
  ///
  /// In en, this message translates to:
  /// **'Question'**
  String get question;

  /// No description provided for @pleaseenteraquestion.
  ///
  /// In en, this message translates to:
  /// **'Please enter a question'**
  String get pleaseenteraquestion;

  /// No description provided for @pleaseenteratleasttwooptions.
  ///
  /// In en, this message translates to:
  /// **'Please enter at least 2 options!'**
  String get pleaseenteratleasttwooptions;

  /// No description provided for @pleaseenteratleastoneimage.
  ///
  /// In en, this message translates to:
  /// **'Please select at least two image!'**
  String get pleaseenteratleastoneimage;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @enteryourquestion.
  ///
  /// In en, this message translates to:
  /// **'Enter your question'**
  String get enteryourquestion;

  /// No description provided for @option.
  ///
  /// In en, this message translates to:
  /// **'Option'**
  String get option;

  /// No description provided for @option1.
  ///
  /// In en, this message translates to:
  /// **'Option 1'**
  String get option1;

  /// No description provided for @option2.
  ///
  /// In en, this message translates to:
  /// **'Option 2'**
  String get option2;

  /// No description provided for @option3.
  ///
  /// In en, this message translates to:
  /// **'Option 3'**
  String get option3;

  /// No description provided for @option4.
  ///
  /// In en, this message translates to:
  /// **'Option 4'**
  String get option4;

  /// No description provided for @addoption.
  ///
  /// In en, this message translates to:
  /// **'Add Option'**
  String get addoption;

  /// No description provided for @enteryouranswerhere.
  ///
  /// In en, this message translates to:
  /// **'Enter your answer here'**
  String get enteryouranswerhere;

  /// No description provided for @addpoll.
  ///
  /// In en, this message translates to:
  /// **'Add Poll'**
  String get addpoll;

  /// No description provided for @addnewpollimage.
  ///
  /// In en, this message translates to:
  /// **'Add New Poll Image'**
  String get addnewpollimage;

  /// No description provided for @addimage.
  ///
  /// In en, this message translates to:
  /// **'Add image'**
  String get addimage;

  /// No description provided for @polls.
  ///
  /// In en, this message translates to:
  /// **'Polls'**
  String get polls;

  /// No description provided for @allpolls.
  ///
  /// In en, this message translates to:
  /// **'All Polls'**
  String get allpolls;

  /// No description provided for @noactivepollfound.
  ///
  /// In en, this message translates to:
  /// **'No active poll found!'**
  String get noactivepollfound;

  /// No description provided for @rememberme.
  ///
  /// In en, this message translates to:
  /// **'Remember me'**
  String get rememberme;

  /// No description provided for @report.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get report;

  /// No description provided for @unfollow.
  ///
  /// In en, this message translates to:
  /// **'Unfollow'**
  String get unfollow;

  /// No description provided for @addtofavorites.
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get addtofavorites;

  /// No description provided for @gotopost.
  ///
  /// In en, this message translates to:
  /// **'Go to post'**
  String get gotopost;

  /// No description provided for @shareto.
  ///
  /// In en, this message translates to:
  /// **'Share to...'**
  String get shareto;

  /// No description provided for @embed.
  ///
  /// In en, this message translates to:
  /// **'Embed'**
  String get embed;

  /// No description provided for @aboutthisaccount.
  ///
  /// In en, this message translates to:
  /// **'About this account'**
  String get aboutthisaccount;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @moresettings.
  ///
  /// In en, this message translates to:
  /// **'More Settings'**
  String get moresettings;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @darkmode.
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkmode;

  /// No description provided for @editprofile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editprofile;

  /// No description provided for @cropimage.
  ///
  /// In en, this message translates to:
  /// **'Crop Image?'**
  String get cropimage;

  /// No description provided for @wouldyouliketocroptheimage.
  ///
  /// In en, this message translates to:
  /// **'Would you like to crop the image?'**
  String get wouldyouliketocroptheimage;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @crop.
  ///
  /// In en, this message translates to:
  /// **'Crop'**
  String get crop;

  /// No description provided for @usersettings.
  ///
  /// In en, this message translates to:
  /// **'User Settings'**
  String get usersettings;

  /// No description provided for @pollthings.
  ///
  /// In en, this message translates to:
  /// **'Poll Things'**
  String get pollthings;

  /// No description provided for @vibe.
  ///
  /// In en, this message translates to:
  /// **'Chase'**
  String get vibe;

  /// No description provided for @nochaseyet.
  ///
  /// In en, this message translates to:
  /// **'No chase yet'**
  String get nochaseyet;

  /// No description provided for @whenpeoplechasechaseyoutheywillappearhere.
  ///
  /// In en, this message translates to:
  /// **'When people chase you, they will appear here!'**
  String get whenpeoplechasechaseyoutheywillappearhere;

  /// No description provided for @startrechasepeopletoseethemhere.
  ///
  /// In en, this message translates to:
  /// **'Start re-chase people to see them here!'**
  String get startrechasepeopletoseethemhere;

  /// No description provided for @revibe.
  ///
  /// In en, this message translates to:
  /// **'Re-chase'**
  String get revibe;

  /// No description provided for @norechaseyet.
  ///
  /// In en, this message translates to:
  /// **'No re-chase yet'**
  String get norechaseyet;

  /// No description provided for @notusersfound.
  ///
  /// In en, this message translates to:
  /// **'No users found'**
  String get notusersfound;

  /// No description provided for @trysearchingwithadifferent.
  ///
  /// In en, this message translates to:
  /// **'Try searching with a different keyword'**
  String get trysearchingwithadifferent;

  /// No description provided for @posts.
  ///
  /// In en, this message translates to:
  /// **'Posts'**
  String get posts;

  /// No description provided for @nopostwithimage.
  ///
  /// In en, this message translates to:
  /// **'No post with image'**
  String get nopostwithimage;

  /// No description provided for @nopostswiththings.
  ///
  /// In en, this message translates to:
  /// **'No post with things'**
  String get nopostswiththings;

  /// No description provided for @nopostsfound.
  ///
  /// In en, this message translates to:
  /// **'No Posts found'**
  String get nopostsfound;

  /// No description provided for @seeall.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get seeall;

  /// No description provided for @nopostavailable.
  ///
  /// In en, this message translates to:
  /// **'No posts available!'**
  String get nopostavailable;

  /// No description provided for @createsomethingcool.
  ///
  /// In en, this message translates to:
  /// **'Create something cool'**
  String get createsomethingcool;

  /// No description provided for @createyourfirstpoll.
  ///
  /// In en, this message translates to:
  /// **'Create your first poll'**
  String get createyourfirstpoll;

  /// No description provided for @createyourfirstthings.
  ///
  /// In en, this message translates to:
  /// **'Create your first things'**
  String get createyourfirstthings;

  /// No description provided for @likes.
  ///
  /// In en, this message translates to:
  /// **'Likes'**
  String get likes;

  /// No description provided for @comments.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get comments;

  /// No description provided for @nocommentsyet.
  ///
  /// In en, this message translates to:
  /// **'No comments yet!'**
  String get nocommentsyet;

  /// No description provided for @bethefirsttocomment.
  ///
  /// In en, this message translates to:
  /// **'Be the first to comment'**
  String get bethefirsttocomment;

  /// No description provided for @addacomment.
  ///
  /// In en, this message translates to:
  /// **'Add a comment..'**
  String get addacomment;

  /// No description provided for @deletecomment.
  ///
  /// In en, this message translates to:
  /// **'Delete Comment'**
  String get deletecomment;

  /// No description provided for @areyousurewanttodeletethiscomments.
  ///
  /// In en, this message translates to:
  /// **'Are you sure want to delete this comments?'**
  String get areyousurewanttodeletethiscomments;

  /// No description provided for @voters.
  ///
  /// In en, this message translates to:
  /// **'Voters'**
  String get voters;

  /// No description provided for @pickedthisastopchoice.
  ///
  /// In en, this message translates to:
  /// **'picked this as\ntop choice'**
  String get pickedthisastopchoice;

  /// No description provided for @novotersthisimageyet.
  ///
  /// In en, this message translates to:
  /// **'No voters this images yet!'**
  String get novotersthisimageyet;

  /// No description provided for @votes.
  ///
  /// In en, this message translates to:
  /// **'votes'**
  String get votes;

  /// No description provided for @firstname.
  ///
  /// In en, this message translates to:
  /// **'First Name'**
  String get firstname;

  /// No description provided for @enterfirstname.
  ///
  /// In en, this message translates to:
  /// **'Enter first name'**
  String get enterfirstname;

  /// No description provided for @lastname.
  ///
  /// In en, this message translates to:
  /// **'Last Name'**
  String get lastname;

  /// No description provided for @enterlastname.
  ///
  /// In en, this message translates to:
  /// **'Enter last name'**
  String get enterlastname;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @enterusername.
  ///
  /// In en, this message translates to:
  /// **'Enter username'**
  String get enterusername;

  /// No description provided for @dateofbirth.
  ///
  /// In en, this message translates to:
  /// **'Date of Birth'**
  String get dateofbirth;

  /// No description provided for @gender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get gender;

  /// No description provided for @bio.
  ///
  /// In en, this message translates to:
  /// **'Bio'**
  String get bio;

  /// No description provided for @enterbio.
  ///
  /// In en, this message translates to:
  /// **'Enter your bio'**
  String get enterbio;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @enteryouremail.
  ///
  /// In en, this message translates to:
  /// **'Enter your email'**
  String get enteryouremail;

  /// No description provided for @phonenumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phonenumber;

  /// No description provided for @enteryourphonenumber.
  ///
  /// In en, this message translates to:
  /// **'Enter phone number'**
  String get enteryourphonenumber;

  /// No description provided for @savechanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get savechanges;

  /// No description provided for @changepassword.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changepassword;

  /// No description provided for @currentpassword.
  ///
  /// In en, this message translates to:
  /// **'Current Password'**
  String get currentpassword;

  /// No description provided for @entercurrentpassword.
  ///
  /// In en, this message translates to:
  /// **'Enter current password'**
  String get entercurrentpassword;

  /// No description provided for @forgotyourpassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot your password?'**
  String get forgotyourpassword;

  /// No description provided for @newpassword.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get newpassword;

  /// No description provided for @enternewpassword.
  ///
  /// In en, this message translates to:
  /// **'Enter new password'**
  String get enternewpassword;

  /// No description provided for @confirmpassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmpassword;

  /// No description provided for @enterconfirmpassword.
  ///
  /// In en, this message translates to:
  /// **'Enter confirm password'**
  String get enterconfirmpassword;

  /// No description provided for @security.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get security;

  /// No description provided for @pinsecurity.
  ///
  /// In en, this message translates to:
  /// **'PIN Security'**
  String get pinsecurity;

  /// No description provided for @enablesecurityfirsttoaccess.
  ///
  /// In en, this message translates to:
  /// **'Enable security first to access security options like PIN, Face Recognition and Fingerprint.'**
  String get enablesecurityfirsttoaccess;

  /// No description provided for @lastchanged.
  ///
  /// In en, this message translates to:
  /// **'Last changed: '**
  String get lastchanged;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @disablepinsecurity.
  ///
  /// In en, this message translates to:
  /// **'Disable PIN Security'**
  String get disablepinsecurity;

  /// No description provided for @areyousurewanttodisablepinsecurity.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to disable PIN security? Your PIN will remain saved but won\'t be used for authentication.'**
  String get areyousurewanttodisablepinsecurity;

  /// No description provided for @enterfourdigitpin.
  ///
  /// In en, this message translates to:
  /// **'Enter a 4-digit PIN'**
  String get enterfourdigitpin;

  /// No description provided for @reenteryournewpin.
  ///
  /// In en, this message translates to:
  /// **'Re-enter your new PIN to confirm'**
  String get reenteryournewpin;

  /// No description provided for @entercurrentpin.
  ///
  /// In en, this message translates to:
  /// **'Enter your current PIN'**
  String get entercurrentpin;

  /// No description provided for @setpin.
  ///
  /// In en, this message translates to:
  /// **'Set PIN'**
  String get setpin;

  /// No description provided for @enternewpin.
  ///
  /// In en, this message translates to:
  /// **'Enter New PIN'**
  String get enternewpin;

  /// No description provided for @confirmnewpin.
  ///
  /// In en, this message translates to:
  /// **'Confirm New PIN'**
  String get confirmnewpin;

  /// No description provided for @verifycurrentpin.
  ///
  /// In en, this message translates to:
  /// **'Verify Current PIN'**
  String get verifycurrentpin;

  /// No description provided for @remainingattempts.
  ///
  /// In en, this message translates to:
  /// **'Remaining attempts: '**
  String get remainingattempts;

  /// No description provided for @facerecognition.
  ///
  /// In en, this message translates to:
  /// **'Face Recognition'**
  String get facerecognition;

  /// No description provided for @fingerprintsecurity.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint Security'**
  String get fingerprintsecurity;

  /// No description provided for @getstarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getstarted;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @polldesign.
  ///
  /// In en, this message translates to:
  /// **'Poll Design'**
  String get polldesign;

  /// No description provided for @things.
  ///
  /// In en, this message translates to:
  /// **'Things'**
  String get things;

  /// No description provided for @photos.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get photos;

  /// No description provided for @accountprivacy.
  ///
  /// In en, this message translates to:
  /// **'Account Privacy'**
  String get accountprivacy;

  /// No description provided for @privatepolzet.
  ///
  /// In en, this message translates to:
  /// **'Private Polzet'**
  String get privatepolzet;

  /// No description provided for @whenyourpolzetaccountispublic.
  ///
  /// In en, this message translates to:
  /// **'• When your Polzet account is public, anyone can see your posts, polls, followers and following lists.'**
  String get whenyourpolzetaccountispublic;

  /// No description provided for @whenyourpolzetaccountisprivate.
  ///
  /// In en, this message translates to:
  /// **'• When your account is private, only the people you approve can see what you share on Polzet.'**
  String get whenyourpolzetaccountisprivate;

  /// No description provided for @blockedaccounts.
  ///
  /// In en, this message translates to:
  /// **'Blocked Accounts'**
  String get blockedaccounts;

  /// No description provided for @noblockedaccount.
  ///
  /// In en, this message translates to:
  /// **'No blocked account'**
  String get noblockedaccount;

  /// No description provided for @supportandabout.
  ///
  /// In en, this message translates to:
  /// **'Support & About'**
  String get supportandabout;

  /// No description provided for @actions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get actions;

  /// No description provided for @reportaproblem.
  ///
  /// In en, this message translates to:
  /// **'Report a problem'**
  String get reportaproblem;

  /// No description provided for @addaccount.
  ///
  /// In en, this message translates to:
  /// **'Add account'**
  String get addaccount;

  /// No description provided for @feedbackttl.
  ///
  /// In en, this message translates to:
  /// **'Feedback'**
  String get feedbackttl;

  /// No description provided for @sharefeedback.
  ///
  /// In en, this message translates to:
  /// **'Share Feedback'**
  String get sharefeedback;

  /// No description provided for @howwouldyourateyourexperince.
  ///
  /// In en, this message translates to:
  /// **'How would you rate your experince?'**
  String get howwouldyourateyourexperince;

  /// No description provided for @broken.
  ///
  /// In en, this message translates to:
  /// **'Broken'**
  String get broken;

  /// No description provided for @confusing.
  ///
  /// In en, this message translates to:
  /// **'Confusing'**
  String get confusing;

  /// No description provided for @okay.
  ///
  /// In en, this message translates to:
  /// **'Okay'**
  String get okay;

  /// No description provided for @good.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get good;

  /// No description provided for @loveit.
  ///
  /// In en, this message translates to:
  /// **'Love it'**
  String get loveit;

  /// No description provided for @tapastartorate.
  ///
  /// In en, this message translates to:
  /// **'Tap a star to rate'**
  String get tapastartorate;

  /// No description provided for @subject.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get subject;

  /// No description provided for @egAppissueloginproblem.
  ///
  /// In en, this message translates to:
  /// **'e.g. App Issue, Login Problem...'**
  String get egAppissueloginproblem;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @bugreport.
  ///
  /// In en, this message translates to:
  /// **'Bug Report'**
  String get bugreport;

  /// No description provided for @featurerequest.
  ///
  /// In en, this message translates to:
  /// **'Feature Request'**
  String get featurerequest;

  /// No description provided for @uiissue.
  ///
  /// In en, this message translates to:
  /// **'UI Issue'**
  String get uiissue;

  /// No description provided for @perfomance.
  ///
  /// In en, this message translates to:
  /// **'Perfomance'**
  String get perfomance;

  /// No description provided for @general.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get general;

  /// No description provided for @complaint.
  ///
  /// In en, this message translates to:
  /// **'Complaint'**
  String get complaint;

  /// No description provided for @describeyourissueorsuggestionindetails.
  ///
  /// In en, this message translates to:
  /// **'Describe your issue or suggestion in details...'**
  String get describeyourissueorsuggestionindetails;

  /// No description provided for @characters.
  ///
  /// In en, this message translates to:
  /// **'Characters'**
  String get characters;

  /// No description provided for @submitfeedback.
  ///
  /// In en, this message translates to:
  /// **'Submit Feedback'**
  String get submitfeedback;

  /// No description provided for @deleteaccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteaccount;

  /// No description provided for @areyousureyouwanttodeleteyouraccount.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete your account? Permanently remove your account and all associated data. You can restore it within 30 days.'**
  String get areyousureyouwanttodeleteyouraccount;

  /// No description provided for @confirmdelete.
  ///
  /// In en, this message translates to:
  /// **'CONFIRM, DELETE'**
  String get confirmdelete;

  /// No description provided for @yesdelete.
  ///
  /// In en, this message translates to:
  /// **'Yes, Delete'**
  String get yesdelete;

  /// No description provided for @confirmaccountdeletion.
  ///
  /// In en, this message translates to:
  /// **'Confirm Account Deletion'**
  String get confirmaccountdeletion;

  /// No description provided for @enteryourpasswordtopermentlydeleteyouraccount.
  ///
  /// In en, this message translates to:
  /// **'Enter your password to permently delete your account.'**
  String get enteryourpasswordtopermentlydeleteyouraccount;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get logout;

  /// No description provided for @areyousurewanttologout.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to log out?'**
  String get areyousurewanttologout;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @privacypolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacypolicy;

  /// No description provided for @lastupdated.
  ///
  /// In en, this message translates to:
  /// **'Last Updated: April 19,2025'**
  String get lastupdated;

  /// No description provided for @privacypolicydescriptions.
  ///
  /// In en, this message translates to:
  /// **'At Polzet, we are committed to protecting your privacy and ensuring transparency about how we handle your personal information. This Privacy Policy explains how Polzet  We collects, uses, shares, and safeguards your information when you access or use our website, mobile application, and related services. By using the Platform, you consent to the practices described in this Privacy Policy. If you do not agree with this Privacy Policy, please do not use the Platform.'**
  String get privacypolicydescriptions;

  /// No description provided for @informationwecollect.
  ///
  /// In en, this message translates to:
  /// **'1. Information We Collect'**
  String get informationwecollect;

  /// No description provided for @wecollectiinformation.
  ///
  /// In en, this message translates to:
  /// **'We collect information in the following categories :'**
  String get wecollectiinformation;

  /// No description provided for @informationyouprovide.
  ///
  /// In en, this message translates to:
  /// **'1.1 Information You Provide'**
  String get informationyouprovide;

  /// No description provided for @accountinformation.
  ///
  /// In en, this message translates to:
  /// **'✧ Account Information :'**
  String get accountinformation;

  /// No description provided for @whenyoucreateanaccount.
  ///
  /// In en, this message translates to:
  /// **'When you create an account, we collect your username, email address, password, and any optional information you provide, such as your name, profile picture, or bio.'**
  String get whenyoucreateanaccount;

  /// No description provided for @usecontent.
  ///
  /// In en, this message translates to:
  /// **'✧ User Content :'**
  String get usecontent;

  /// No description provided for @wecollectimages.
  ///
  /// In en, this message translates to:
  /// **'We collect images, text, and other content you upload or post on the Platform.'**
  String get wecollectimages;

  /// No description provided for @communications.
  ///
  /// In en, this message translates to:
  /// **'✧ Communications :'**
  String get communications;

  /// No description provided for @wecollectyourcontactdetails.
  ///
  /// In en, this message translates to:
  /// **'We collect your contact details and the content of your communications If You Give Permission.'**
  String get wecollectyourcontactdetails;

  /// No description provided for @surveysandfeedback.
  ///
  /// In en, this message translates to:
  /// **'✧ Surveys and Feedback :'**
  String get surveysandfeedback;

  /// No description provided for @wemaycollectinformationyourovide.
  ///
  /// In en, this message translates to:
  /// **'We may collect information you provide through surveys, feedback forms, or promotions.'**
  String get wemaycollectinformationyourovide;

  /// No description provided for @informationcollectedautomatically.
  ///
  /// In en, this message translates to:
  /// **'1.2 Information Callected Autometically'**
  String get informationcollectedautomatically;

  /// No description provided for @usagedata.
  ///
  /// In en, this message translates to:
  /// **'✧ Usage Data :'**
  String get usagedata;

  /// No description provided for @wecollectinformationaboutyourinteractions.
  ///
  /// In en, this message translates to:
  /// **'We collect information about your interactions with the Platform, such as pages viewed, features used, time spent, and clicks.'**
  String get wecollectinformationaboutyourinteractions;

  /// No description provided for @deviceandtechnicalinformation.
  ///
  /// In en, this message translates to:
  /// **'✧ Device and Technical Information :'**
  String get deviceandtechnicalinformation;

  /// No description provided for @wecollectdetailsaboutyourdevice.
  ///
  /// In en, this message translates to:
  /// **'We collect details about your device, including IP address, browser type, operating system, device identifiers, and network information.'**
  String get wecollectdetailsaboutyourdevice;

  /// No description provided for @locationdata.
  ///
  /// In en, this message translates to:
  /// **'✧ Location Data :'**
  String get locationdata;

  /// No description provided for @withyourconsentwemay.
  ///
  /// In en, this message translates to:
  /// **'With your consent, we may collect approximate location data (e.g., based on IP address or device settings) to provide location-based features.'**
  String get withyourconsentwemay;

  /// No description provided for @cookiesandtrackingtechnologies.
  ///
  /// In en, this message translates to:
  /// **'✧ Cookies and Tracking Technologies :'**
  String get cookiesandtrackingtechnologies;

  /// No description provided for @weusecookieswebbeacons.
  ///
  /// In en, this message translates to:
  /// **'We use cookies, web beacons, and similar technologies to enhance your experience, analyse usage, and deliver personalized content. You can manage cookie preferences through your browser settings.'**
  String get weusecookieswebbeacons;

  /// No description provided for @informationfromthirdparties.
  ///
  /// In en, this message translates to:
  /// **'1.3 Information from Third Parties'**
  String get informationfromthirdparties;

  /// No description provided for @socialmediaintegrations.
  ///
  /// In en, this message translates to:
  /// **'✧ Social Media Integrations :'**
  String get socialmediaintegrations;

  /// No description provided for @ifyouconnectyourpolzetaccount.
  ///
  /// In en, this message translates to:
  /// **'If you connect your Polzet account to third-party platforms , we may receive information such as your profile details, subject to the third party’s privacy policies.'**
  String get ifyouconnectyourpolzetaccount;

  /// No description provided for @analyticsandadvertisingpartners.
  ///
  /// In en, this message translates to:
  /// **'✧ Analytics and Advertising Partners :'**
  String get analyticsandadvertisingpartners;

  /// No description provided for @wemayreceiveaggregatedoranonymized.
  ///
  /// In en, this message translates to:
  /// **'We may receive aggregated or anonymized data from third-party analytics providers or advertising partners to improve our services.'**
  String get wemayreceiveaggregatedoranonymized;

  /// No description provided for @howweuseyourinformation.
  ///
  /// In en, this message translates to:
  /// **'2. How We Use Your Information'**
  String get howweuseyourinformation;

  /// No description provided for @weuseyourinformationto.
  ///
  /// In en, this message translates to:
  /// **'We use your information to :'**
  String get weuseyourinformationto;

  /// No description provided for @provideandimprovetheplatform.
  ///
  /// In en, this message translates to:
  /// **'✧ Provide and Improve the Platform :'**
  String get provideandimprovetheplatform;

  /// No description provided for @operatemaintainandenhanc.
  ///
  /// In en, this message translates to:
  /// **'Operate, maintain, and enhance the Platform’s functionality, including displaying your User Content and personalizing your experience.'**
  String get operatemaintainandenhanc;

  /// No description provided for @accountmanagement.
  ///
  /// In en, this message translates to:
  /// **'✧ Account Management :'**
  String get accountmanagement;

  /// No description provided for @createandmanageyouraccount.
  ///
  /// In en, this message translates to:
  /// **'Create and manage your account, authenticate logins, and provide customer support.'**
  String get createandmanageyouraccount;

  /// No description provided for @communication.
  ///
  /// In en, this message translates to:
  /// **'✧ Communication :'**
  String get communication;

  /// No description provided for @respondtoyourinquiriessend.
  ///
  /// In en, this message translates to:
  /// **'Respond to your inquiries, send service-related notifications (e.g., account updates), and, with your consent, deliver promotional content or newsletters.'**
  String get respondtoyourinquiriessend;

  /// No description provided for @analyticsandresearch.
  ///
  /// In en, this message translates to:
  /// **'✧ Analytics and Research :'**
  String get analyticsandresearch;

  /// No description provided for @analysesusagetrends.
  ///
  /// In en, this message translates to:
  /// **'Analyses usage trends, monitor Platform performance, and conduct research to improve our services.'**
  String get analysesusagetrends;

  /// No description provided for @advertising.
  ///
  /// In en, this message translates to:
  /// **'✧ Advertising :'**
  String get advertising;

  /// No description provided for @delivertargetedadvertisements.
  ///
  /// In en, this message translates to:
  /// **'Deliver targeted advertisements based on your interests and interactions, either directly or through third-party partners.'**
  String get delivertargetedadvertisements;

  /// No description provided for @safetyandsecurity.
  ///
  /// In en, this message translates to:
  /// **'✧ Safety and Security :'**
  String get safetyandsecurity;

  /// No description provided for @detectandpreventfraud.
  ///
  /// In en, this message translates to:
  /// **'Detect and prevent fraud, abuse, or illegal activities, and enforce our Terms and Conditions.'**
  String get detectandpreventfraud;

  /// No description provided for @legalcompliance.
  ///
  /// In en, this message translates to:
  /// **'✧ Legal Compliance :'**
  String get legalcompliance;

  /// No description provided for @complywithapplicablelaws.
  ///
  /// In en, this message translates to:
  /// **'Comply with applicable laws, regulations, and legal processes.'**
  String get complywithapplicablelaws;

  /// No description provided for @howweshareyourinformation.
  ///
  /// In en, this message translates to:
  /// **'3. How We Share Your Information'**
  String get howweshareyourinformation;

  /// No description provided for @wemayshareyourinformationasfollows.
  ///
  /// In en, this message translates to:
  /// **'We may share your information as follows :'**
  String get wemayshareyourinformationasfollows;

  /// No description provided for @withotherusers.
  ///
  /// In en, this message translates to:
  /// **'3.1 With Other Users'**
  String get withotherusers;

  /// No description provided for @publiccontent.
  ///
  /// In en, this message translates to:
  /// **'✧ Public Content :'**
  String get publiccontent;

  /// No description provided for @usercontentyoupostpublicly.
  ///
  /// In en, this message translates to:
  /// **'User Content you post publicly On may be visible to other users or the public, depending on your privacy settings.'**
  String get usercontentyoupostpublicly;

  /// No description provided for @profileinformation.
  ///
  /// In en, this message translates to:
  /// **'✧ Profile Information :'**
  String get profileinformation;

  /// No description provided for @yourusernameprofilepicture.
  ///
  /// In en, this message translates to:
  /// **'Your username, profile picture, and bio may be visible to other users unless you adjust your privacy settings.'**
  String get yourusernameprofilepicture;

  /// No description provided for @withserviceproviders.
  ///
  /// In en, this message translates to:
  /// **'3.2 With Service Providers'**
  String get withserviceproviders;

  /// No description provided for @weshareinformationwiththirdparty.
  ///
  /// In en, this message translates to:
  /// **'We share information with third-party service providers who perform services on our behalf, such as hosting, data storage, analytics, payment processing, and customer support. These providers are contractually obligated to protect your information and use it only for the purposes we specify.'**
  String get weshareinformationwiththirdparty;

  /// No description provided for @withbusinesspartners.
  ///
  /// In en, this message translates to:
  /// **'3.3 With Business Partners'**
  String get withbusinesspartners;

  /// No description provided for @wemayshareanonymizedoraggregated.
  ///
  /// In en, this message translates to:
  /// **'We may share anonymized or aggregated data with advertising or analytics partners to improve our services or deliver targeted ads.'**
  String get wemayshareanonymizedoraggregated;

  /// No description provided for @forlegalreasons.
  ///
  /// In en, this message translates to:
  /// **'3.4 For Legal Reasons'**
  String get forlegalreasons;

  /// No description provided for @wemaydiscloseyourinformationtocomply.
  ///
  /// In en, this message translates to:
  /// **'We may disclose your information to comply with applicable laws, regulations, legal processes (e.g., subpoenas), or to protect the rights, property, or safety of Polzet, our users, or others.'**
  String get wemaydiscloseyourinformationtocomply;

  /// No description provided for @intheeventofamerger.
  ///
  /// In en, this message translates to:
  /// **'In the event of a merger, acquisition, or sale of assets, your information may be transferred to the acquiring entity, subject to this Privacy Policy.'**
  String get intheeventofamerger;

  /// No description provided for @withyourconsent.
  ///
  /// In en, this message translates to:
  /// **'3.5 With Your Consent'**
  String get withyourconsent;

  /// No description provided for @wemayshareyourinformationfor.
  ///
  /// In en, this message translates to:
  /// **'We may share your information for other purposes if you provide explicit consent.'**
  String get wemayshareyourinformationfor;

  /// No description provided for @yourchoicesandrights.
  ///
  /// In en, this message translates to:
  /// **'4. Your Choices and Rights'**
  String get yourchoicesandrights;

  /// No description provided for @accountandprivacysettings.
  ///
  /// In en, this message translates to:
  /// **'4.1 Account and Privacy Settings'**
  String get accountandprivacysettings;

  /// No description provided for @youcanmanageyourprivacysettings.
  ///
  /// In en, this message translates to:
  /// **'You can manage your privacy settings on the Platform to control who sees your User Content and profile information.'**
  String get youcanmanageyourprivacysettings;

  /// No description provided for @youmayupdateordelete.
  ///
  /// In en, this message translates to:
  /// **'You may update or delete your account information at any time through your account settings.'**
  String get youmayupdateordelete;

  /// No description provided for @marketingcommunications.
  ///
  /// In en, this message translates to:
  /// **'4.2 Marketing Communications'**
  String get marketingcommunications;

  /// No description provided for @youcanoptoutofreceiving.
  ///
  /// In en, this message translates to:
  /// **'You can opt out of receiving promotional emails by following the unsubscribe instructions in those emails or updating your communication preferences in your account settings.'**
  String get youcanoptoutofreceiving;

  /// No description provided for @cookies.
  ///
  /// In en, this message translates to:
  /// **'4.3 Cookies'**
  String get cookies;

  /// No description provided for @youcandisablecookiesthrough.
  ///
  /// In en, this message translates to:
  /// **'You can disable cookies through your browser settings, but this may affect your ability to use certain Platform features.'**
  String get youcandisablecookiesthrough;

  /// No description provided for @datarights.
  ///
  /// In en, this message translates to:
  /// **'4.4 Data Rights'**
  String get datarights;

  /// No description provided for @dependingonyourjurisdiction.
  ///
  /// In en, this message translates to:
  /// **'Depending on your jurisdiction, you may have the following rights regarding your personal information :'**
  String get dependingonyourjurisdiction;

  /// No description provided for @access.
  ///
  /// In en, this message translates to:
  /// **'✧ Access :'**
  String get access;

  /// No description provided for @requestacopyof.
  ///
  /// In en, this message translates to:
  /// **'Request a copy of the personal information we hold about you.'**
  String get requestacopyof;

  /// No description provided for @correction.
  ///
  /// In en, this message translates to:
  /// **'✧ Correction :'**
  String get correction;

  /// No description provided for @requestcorrectionsto.
  ///
  /// In en, this message translates to:
  /// **'Request corrections to inaccurate or incomplete information.'**
  String get requestcorrectionsto;

  /// No description provided for @deletion.
  ///
  /// In en, this message translates to:
  /// **'✧ Deletion :'**
  String get deletion;

  /// No description provided for @requestdeletionof.
  ///
  /// In en, this message translates to:
  /// **'Request deletion of your personal information, subject to legal obligations.'**
  String get requestdeletionof;

  /// No description provided for @restriction.
  ///
  /// In en, this message translates to:
  /// **'✧ Restriction :'**
  String get restriction;

  /// No description provided for @requestrestrictionson.
  ///
  /// In en, this message translates to:
  /// **'Request restrictions on how we process your information.'**
  String get requestrestrictionson;

  /// No description provided for @portability.
  ///
  /// In en, this message translates to:
  /// **'\'✧ Portability :'**
  String get portability;

  /// No description provided for @requestacopyofyour.
  ///
  /// In en, this message translates to:
  /// **'Request a copy of your information in a structured, machine-readable format.'**
  String get requestacopyofyour;

  /// No description provided for @objection.
  ///
  /// In en, this message translates to:
  /// **'✧ Objection :'**
  String get objection;

  /// No description provided for @objecttocertainprocessing.
  ///
  /// In en, this message translates to:
  /// **'Object to certain processing activities, such as targeted advertising.'**
  String get objecttocertainprocessing;

  /// No description provided for @toexercisetheserights.
  ///
  /// In en, this message translates to:
  /// **'To exercise these rights, please contact us at contact@polzet.com. We will respond to your request in accordance with applicable laws With in 10 Days'**
  String get toexercisetheserights;

  /// No description provided for @dataretention.
  ///
  /// In en, this message translates to:
  /// **'5. Data Retention'**
  String get dataretention;

  /// No description provided for @weretainyourpersonalinformationfor.
  ///
  /// In en, this message translates to:
  /// **'We retain your personal information for as long as necessary to provide the Platform, fulfill the purposes outlined in this Privacy Policy, or comply with legal obligations. For example :'**
  String get weretainyourpersonalinformationfor;

  /// No description provided for @accountinformationisretained.
  ///
  /// In en, this message translates to:
  /// **'◆︎ Account information is retained until you delete your account or request deletion.'**
  String get accountinformationisretained;

  /// No description provided for @usercontentmayremain.
  ///
  /// In en, this message translates to:
  /// **'◆︎ User Content may remain on the Platform if shared or reposted by others, even after account deletion.'**
  String get usercontentmayremain;

  /// No description provided for @usagedatamayberetained.
  ///
  /// In en, this message translates to:
  /// **'Usage data may be retained in anonymized form for analytics purposes.'**
  String get usagedatamayberetained;

  /// No description provided for @whenwenolongerneed.
  ///
  /// In en, this message translates to:
  /// **'When we no longer need your information, we will securely delete or anonymize it.'**
  String get whenwenolongerneed;

  /// No description provided for @datascurity.
  ///
  /// In en, this message translates to:
  /// **'6. Data Security'**
  String get datascurity;

  /// No description provided for @weimplementreasonabletechnical.
  ///
  /// In en, this message translates to:
  /// **'We implement reasonable technical and organizational measures to protect your personal information from unauthorized access, loss, or misuse. These measures include encryption, access controls, and secure data storage. However, no system is completely secure, and we cannot guarantee the absolute security of your information.'**
  String get weimplementreasonabletechnical;

  /// No description provided for @internationalsdatatransfers.
  ///
  /// In en, this message translates to:
  /// **'7. International Data Transfers'**
  String get internationalsdatatransfers;

  /// No description provided for @polzetoperatesglobally.
  ///
  /// In en, this message translates to:
  /// **'Polzet operates globally, and your information may be transferred to, stored, or processed in countries outside your jurisdiction, including the United States. These countries may have different data protection laws. We take steps to ensure that any international transfers comply with applicable laws, such as using standard contractual clauses or relying on adequacy decisions.'**
  String get polzetoperatesglobally;

  /// No description provided for @childrensprivacy.
  ///
  /// In en, this message translates to:
  /// **'8. Children’s Privacy'**
  String get childrensprivacy;

  /// No description provided for @theplatformisnotintended.
  ///
  /// In en, this message translates to:
  /// **'The Platform is not intended for users under 13 years of age. We do not knowingly collect personal information from children under 13. If we become aware that a child under 13 has provided us with personal information, we will take steps to delete it. If you believe a child under 13 has provided us with information, please contact us at'**
  String get theplatformisnotintended;

  /// No description provided for @thirdpartylinksandservices.
  ///
  /// In en, this message translates to:
  /// **'9. Third-Party Links and Services'**
  String get thirdpartylinksandservices;

  /// No description provided for @theplatformmaycontainlinks.
  ///
  /// In en, this message translates to:
  /// **'The Platform may contain links to third-party websites, services, or advertisements. We are not responsible for the privacy practices or content of these third parties. We encourage you to review their privacy policies before providing any personal information.'**
  String get theplatformmaycontainlinks;

  /// No description provided for @changestothisprivacypolicy.
  ///
  /// In en, this message translates to:
  /// **'10. Changes to This Privacy Policy'**
  String get changestothisprivacypolicy;

  /// No description provided for @wemayupdatethisprivacypolicy.
  ///
  /// In en, this message translates to:
  /// **'We may update this Privacy Policy from time to time to reflect changes in our practices or legal requirements. We will notify you of material changes by posting the updated Privacy Policy on the Platform or through other communication channels (e.g., email). Your continued use of the Platform after such changes constitutes your acceptance of the updated Privacy Policy.'**
  String get wemayupdatethisprivacypolicy;

  /// No description provided for @contactus.
  ///
  /// In en, this message translates to:
  /// **'11. Contact Us'**
  String get contactus;

  /// No description provided for @ifyouhavequestions.
  ///
  /// In en, this message translates to:
  /// **'If you have questions, concerns, or requests regarding this Privacy Policy or our data practices, please contact us at :'**
  String get ifyouhavequestions;

  /// No description provided for @thankyoufortrusting.
  ///
  /// In en, this message translates to:
  /// **'Thank you for trusting Polzet with your personal information. We are committed to protecting your privacy and providing a safe and enjoyable experience on our Platform.'**
  String get thankyoufortrusting;

  /// No description provided for @helpandsupport.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get helpandsupport;

  /// No description provided for @helpandsupportdescriptions.
  ///
  /// In en, this message translates to:
  /// **'At Polzet, we’re here to support you in making the most of our social media platform, where you can connect, share images, and post text. Whether you have questions, need technical assistance, want to report an issue, or wish to share feedback, our team is ready to help. This page outlines how you can reach us and what to expect when you do.'**
  String get helpandsupportdescriptions;

  /// No description provided for @howtocontactus.
  ///
  /// In en, this message translates to:
  /// **'How to contact us'**
  String get howtocontactus;

  /// No description provided for @weoffermultipleways.
  ///
  /// In en, this message translates to:
  /// **'We offer multiple ways to get in touch, depending on your needs.'**
  String get weoffermultipleways;

  /// No description provided for @generalsupport.
  ///
  /// In en, this message translates to:
  /// **'1.1 General Support'**
  String get generalsupport;

  /// No description provided for @forquestionsaboutyouraccount.
  ///
  /// In en, this message translates to:
  /// **'For questions about your account, Platform features, or general inquiries.'**
  String get forquestionsaboutyouraccount;

  /// No description provided for @privacyanddatarequests.
  ///
  /// In en, this message translates to:
  /// **'1.2 Privacy and Data Requests'**
  String get privacyanddatarequests;

  /// No description provided for @forquestionsaboutyourpersonalinformation.
  ///
  /// In en, this message translates to:
  /// **'For questions about your personal information, data rights (e.g., access, deletion), or our Privacy Policy.'**
  String get forquestionsaboutyourpersonalinformation;

  /// No description provided for @reportingviolationsorabuse.
  ///
  /// In en, this message translates to:
  /// **'1.3 Reporting Violations or Abuse'**
  String get reportingviolationsorabuse;

  /// No description provided for @toreportcontentthatviolates.
  ///
  /// In en, this message translates to:
  /// **'To report content that violates our Terms and Conditions (e.g., harassment, hate speech, or copyright infringement).'**
  String get toreportcontentthatviolates;

  /// No description provided for @copyrightinfringement.
  ///
  /// In en, this message translates to:
  /// **'1.4 Copyright Infringement (DMCA)'**
  String get copyrightinfringement;

  /// No description provided for @tosubmitadmca.
  ///
  /// In en, this message translates to:
  /// **'To submit a Digital Millennium Copyright Act (DMCA) notice for copyrighted material posted without permission.'**
  String get tosubmitadmca;

  /// No description provided for @feedbackandsuggestions.
  ///
  /// In en, this message translates to:
  /// **'1.5 Feedback and Suggestions'**
  String get feedbackandsuggestions;

  /// No description provided for @welovehearingyourideas.
  ///
  /// In en, this message translates to:
  /// **'We love hearing your ideas to improve Polzet! Share your feedback or suggestions :'**
  String get welovehearingyourideas;

  /// No description provided for @responsetime.
  ///
  /// In en, this message translates to:
  /// **'✧ Response Time :'**
  String get responsetime;

  /// No description provided for @wereviewreportswithin.
  ///
  /// In en, this message translates to:
  /// **'We review reports within 24-72 hours and take appropriate action.'**
  String get wereviewreportswithin;

  /// No description provided for @helpcenter.
  ///
  /// In en, this message translates to:
  /// **'2. Help Center'**
  String get helpcenter;

  /// No description provided for @ouronlinehelpcenterprovides.
  ///
  /// In en, this message translates to:
  /// **'Our online Help Center provides answers to common questions, troubleshooting guides, and step-by-step instructions for using the Platform. Topics include :'**
  String get ouronlinehelpcenterprovides;

  /// No description provided for @accountsetupandmanagement.
  ///
  /// In en, this message translates to:
  /// **'◆︎ Account setup and management'**
  String get accountsetupandmanagement;

  /// No description provided for @uploadingimagesandtext.
  ///
  /// In en, this message translates to:
  /// **'◆︎ Uploading images and text'**
  String get uploadingimagesandtext;

  /// No description provided for @privacyandsecuritysettings.
  ///
  /// In en, this message translates to:
  /// **'◆︎ Privacy and security settings'**
  String get privacyandsecuritysettings;

  /// No description provided for @reportingissuesorabusivecontent.
  ///
  /// In en, this message translates to:
  /// **'◆︎ Reporting issues or abusive content'**
  String get reportingissuesorabusivecontent;

  /// No description provided for @troubleshootingtechnicalproblems.
  ///
  /// In en, this message translates to:
  /// **'◆︎ Troubleshooting technical problems'**
  String get troubleshootingtechnicalproblems;

  /// No description provided for @whattoexpectwhenyoucontactus.
  ///
  /// In en, this message translates to:
  /// **'2. What to Expect When You Contact Us'**
  String get whattoexpectwhenyoucontactus;

  /// No description provided for @acknowledgment.
  ///
  /// In en, this message translates to:
  /// **'✧ Acknowledgment : '**
  String get acknowledgment;

  /// No description provided for @foremailinquiriesyouwill.
  ///
  /// In en, this message translates to:
  /// **'For email inquiries, you’ll receive an automated confirmation with a ticket number. Please keep this for reference.'**
  String get foremailinquiriesyouwill;

  /// No description provided for @resolutionprocess.
  ///
  /// In en, this message translates to:
  /// **'✧ Resolution Process : '**
  String get resolutionprocess;

  /// No description provided for @oursupportteamwillreviewyourinquiry.
  ///
  /// In en, this message translates to:
  /// **'Our support team will review your inquiry and may request additional information to resolve your issue. We strive to provide clear and helpful responses.'**
  String get oursupportteamwillreviewyourinquiry;

  /// No description provided for @escalation.
  ///
  /// In en, this message translates to:
  /// **'✧ Escalation : '**
  String get escalation;

  /// No description provided for @ifyouarenotsatisfied.
  ///
  /// In en, this message translates to:
  /// **'If you’re not satisfied with the initial response, you can request escalation to a supervisor by replying to the support email.'**
  String get ifyouarenotsatisfied;

  /// No description provided for @confidentiality.
  ///
  /// In en, this message translates to:
  /// **'✧ Confidentiality : '**
  String get confidentiality;

  /// No description provided for @wehandleyourinquiries.
  ///
  /// In en, this message translates to:
  /// **'We handle your inquiries in accordance with our Privacy Policy and protect your personal information.'**
  String get wehandleyourinquiries;

  /// No description provided for @communityguidelines.
  ///
  /// In en, this message translates to:
  /// **'4. Community Guidelines'**
  String get communityguidelines;

  /// No description provided for @ensureyourcontent.
  ///
  /// In en, this message translates to:
  /// **'◆︎ Ensure your content complies with our acceptable use policy.'**
  String get ensureyourcontent;

  /// No description provided for @verifythatyouhave.
  ///
  /// In en, this message translates to:
  /// **'◆︎ Verify that you have the rights to upload images or text you’ve posted.'**
  String get verifythatyouhave;

  /// No description provided for @checkyourprivacysettings.
  ///
  /// In en, this message translates to:
  /// **'◆︎ Check your privacy settings to control who sees your content.'**
  String get checkyourprivacysettings;

  /// No description provided for @reportingtechnicalissues.
  ///
  /// In en, this message translates to:
  /// **'5. Reporting Technical Issues'**
  String get reportingtechnicalissues;

  /// No description provided for @ifyouencounterbugs.
  ///
  /// In en, this message translates to:
  /// **'If you encounter bugs, crashes, or other technical problems :'**
  String get ifyouencounterbugs;

  /// No description provided for @adescriptionoftheissue.
  ///
  /// In en, this message translates to:
  /// **'◆︎ A description of the issue'**
  String get adescriptionoftheissue;

  /// No description provided for @yourdevicetypeandoperatingsystem.
  ///
  /// In en, this message translates to:
  /// **'Your device type and operating system'**
  String get yourdevicetypeandoperatingsystem;

  /// No description provided for @screenshotsorscreenrecordings.
  ///
  /// In en, this message translates to:
  /// **'◆︎ Screenshots or screen recordings, if possible'**
  String get screenshotsorscreenrecordings;

  /// No description provided for @ourtechnicalteamwillinvestigate.
  ///
  /// In en, this message translates to:
  /// **'◆︎ Our technical team will investigate and work to resolve the issue promptly.'**
  String get ourtechnicalteamwillinvestigate;

  /// No description provided for @accessibilitysupport.
  ///
  /// In en, this message translates to:
  /// **'6. Accessibility Support'**
  String get accessibilitysupport;

  /// No description provided for @wearecommittedtomaking.
  ///
  /// In en, this message translates to:
  /// **'We are committed to making Polzet accessible to all users. If you have accessibility-related questions or need assistance using the Platform with assistive technologies :'**
  String get wearecommittedtomaking;

  /// No description provided for @feedbackmakesusbetter.
  ///
  /// In en, this message translates to:
  /// **'7. Feedback Makes Us Better'**
  String get feedbackmakesusbetter;

  /// No description provided for @yourinputhelpsusimprovethe.
  ///
  /// In en, this message translates to:
  /// **'Your input helps us improve the Platform and create a better experience for everyone. Whether it’s a feature request, a suggestion for new tools, or a comment on our services, we value your perspective. Share your thoughts via on email.'**
  String get yourinputhelpsusimprovethe;

  /// No description provided for @stayconnected.
  ///
  /// In en, this message translates to:
  /// **'8. Stay Connected'**
  String get stayconnected;

  /// No description provided for @forthelatestupdates.
  ///
  /// In en, this message translates to:
  /// **'For the latest updates, tips, and community news :'**
  String get forthelatestupdates;

  /// No description provided for @followusx.
  ///
  /// In en, this message translates to:
  /// **'◆︎ Follow us X on Polzet: @OFFICIALPOLZET'**
  String get followusx;

  /// No description provided for @contactsummary.
  ///
  /// In en, this message translates to:
  /// **'9. Contact Summary'**
  String get contactsummary;

  /// No description provided for @generalsupportsummary.
  ///
  /// In en, this message translates to:
  /// **'◆︎ General Support'**
  String get generalsupportsummary;

  /// No description provided for @privacydatarequests.
  ///
  /// In en, this message translates to:
  /// **'◆︎ Privacy/Data Requests'**
  String get privacydatarequests;

  /// No description provided for @abusereports.
  ///
  /// In en, this message translates to:
  /// **'◆︎ Abuse Reports'**
  String get abusereports;

  /// No description provided for @copyrightissues.
  ///
  /// In en, this message translates to:
  /// **'◆︎ Copyright Issues'**
  String get copyrightissues;

  /// No description provided for @feedback.
  ///
  /// In en, this message translates to:
  /// **'◆︎ Feedback'**
  String get feedback;

  /// No description provided for @accessibility.
  ///
  /// In en, this message translates to:
  /// **'◆︎ Accessibility'**
  String get accessibility;

  /// No description provided for @helpcentersummary.
  ///
  /// In en, this message translates to:
  /// **'◆︎ Help Center'**
  String get helpcentersummary;

  /// No description provided for @responsetimesummary.
  ///
  /// In en, this message translates to:
  /// **'✧ Response Time : '**
  String get responsetimesummary;

  /// No description provided for @wereviewreports.
  ///
  /// In en, this message translates to:
  /// **'We review reports within 24-72 hours and take appropriate action.'**
  String get wereviewreports;

  /// No description provided for @termsandconditions.
  ///
  /// In en, this message translates to:
  /// **'Terms & Conditions'**
  String get termsandconditions;

  /// No description provided for @termsconditionsdescriptions.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Polzet, a social media platform where users can upload images and text to connect and share with others. These Terms and Conditions govern your access to and use of Polzet website, mobile application, and related services (collectively, the Platform.By accessing or using the Platform, you agree to be bound by these Terms. If you do not agree with any part of these Terms, you must not use the Platform.'**
  String get termsconditionsdescriptions;

  /// No description provided for @acceptanceofterms.
  ///
  /// In en, this message translates to:
  /// **'1. Acceptance of Terms'**
  String get acceptanceofterms;

  /// No description provided for @bycreatinganaccountorusing.
  ///
  /// In en, this message translates to:
  /// **'By creating an account or using the Platform, you confirm that you have read, understood, and agree to these Terms, as well as our Privacy Policy, which is incorporated by reference. These Terms form a legally binding agreement between you and Polzet Inc , We may update these Terms from time to time at our sole discretion. Continued use of the Platform after changes are posted constitutes your acceptance of the updated Terms.'**
  String get bycreatinganaccountorusing;

  /// No description provided for @eligibility.
  ///
  /// In en, this message translates to:
  /// **'2. Eligibility'**
  String get eligibility;

  /// No description provided for @tousethePlatform.
  ///
  /// In en, this message translates to:
  /// **'✧ To use the Platform, you must :'**
  String get tousethePlatform;

  /// No description provided for @beatleast13yearsofage.
  ///
  /// In en, this message translates to:
  /// **'◆︎ Be at least 13 years of age. Users under 18 must have parental or guardian consent.'**
  String get beatleast13yearsofage;

  /// No description provided for @notbeaconvictedsexoffender.
  ///
  /// In en, this message translates to:
  /// **'◆︎ Not be a convicted sex offender or otherwise prohibited from using the Platform under applicable law.'**
  String get notbeaconvictedsexoffender;

  /// No description provided for @provideaccurateandcomplete.
  ///
  /// In en, this message translates to:
  /// **'◆︎ Provide accurate and complete information during account registration.'**
  String get provideaccurateandcomplete;

  /// No description provided for @useraccounts.
  ///
  /// In en, this message translates to:
  /// **'3. User Accounts'**
  String get useraccounts;

  /// No description provided for @accountresponsibility.
  ///
  /// In en, this message translates to:
  /// **'✧ Account Responsibility :'**
  String get accountresponsibility;

  /// No description provided for @youareresponsiblefor.
  ///
  /// In en, this message translates to:
  /// **'You are responsible for maintaining the confidentiality of your account credentials (e.g., username and password). You agree to notify us immediately of any unauthorized use of your account.'**
  String get youareresponsiblefor;

  /// No description provided for @termination.
  ///
  /// In en, this message translates to:
  /// **'✧ Termination :'**
  String get termination;

  /// No description provided for @wereservetherightto.
  ///
  /// In en, this message translates to:
  /// **'We reserve the right to suspend or terminate your account at our discretion, including for violations of these Terms or applicable law.'**
  String get wereservetherightto;

  /// No description provided for @usercontent.
  ///
  /// In en, this message translates to:
  /// **'4. User Content'**
  String get usercontent;

  /// No description provided for @definition.
  ///
  /// In en, this message translates to:
  /// **'✧ Definition :'**
  String get definition;

  /// No description provided for @usercontentincludes.
  ///
  /// In en, this message translates to:
  /// **'User Content includes any images, text, or other data you upload, post, or transmit on the Platform.'**
  String get usercontentincludes;

  /// No description provided for @ownership.
  ///
  /// In en, this message translates to:
  /// **'✧ Ownership :'**
  String get ownership;

  /// No description provided for @youretainownershipof.
  ///
  /// In en, this message translates to:
  /// **'You retain ownership of your User Content. By uploading User Content, you grant Polzet a non-exclusive, worldwide, royalty-free, transferable, and sublicensable license to host, store, display, reproduce, modify (e.g., for formatting purposes), distribute, and use your User Content to operate, promote, and improve the Platform. This license continues until you delete your User Content or terminate your account, except where content has been shared or reposted by others in accordance with Platform functionality.'**
  String get youretainownershipof;

  /// No description provided for @responsibility.
  ///
  /// In en, this message translates to:
  /// **'✧ Responsibility :'**
  String get responsibility;

  /// No description provided for @tyouaresolelyresponsible.
  ///
  /// In en, this message translates to:
  /// **'◆︎ You are solely responsible for your User Content. You represent and warrant that :'**
  String get tyouaresolelyresponsible;

  /// No description provided for @youownorhavethenecessary.
  ///
  /// In en, this message translates to:
  /// **'◆︎ You own or have the necessary rights to upload and share your User Content.'**
  String get youownorhavethenecessary;

  /// No description provided for @yourusercontentdoesnot.
  ///
  /// In en, this message translates to:
  /// **'◆︎ Your User Content does not violate any third-party rights, including intellectual property, privacy, or publicity rights.'**
  String get yourusercontentdoesnot;

  /// No description provided for @yourusercontentcomplies.
  ///
  /// In en, this message translates to:
  /// **'◆︎ Your User Content complies with these Terms and all applicable laws.'**
  String get yourusercontentcomplies;

  /// No description provided for @contentremoval.
  ///
  /// In en, this message translates to:
  /// **'✧ Content Removal :'**
  String get contentremoval;

  /// No description provided for @wemaybutarenotobligated.
  ///
  /// In en, this message translates to:
  /// **'We may, but are not obligated to, monitor or review User Content. We reserve the right to remove or disable access to any User Content that violates these Terms, infringes on intellectual property, or is otherwise objectionable, without prior notice.'**
  String get wemaybutarenotobligated;

  /// No description provided for @acceptableusepolicy.
  ///
  /// In en, this message translates to:
  /// **'5. Acceptable Use Policy'**
  String get acceptableusepolicy;

  /// No description provided for @youagreenotto.
  ///
  /// In en, this message translates to:
  /// **'✧ You agree not to :'**
  String get youagreenotto;

  /// No description provided for @postoruploadusercontent.
  ///
  /// In en, this message translates to:
  /// **'◆︎ Post or upload User Content that is unlawful, harmful, defamatory, obscene, pornographic, harassing, discriminatory, or otherwise offensive.'**
  String get postoruploadusercontent;

  /// No description provided for @engageinhatespeech.
  ///
  /// In en, this message translates to:
  /// **'◆︎ Engage in hate speech, threats, or incitement to violence.'**
  String get engageinhatespeech;

  /// No description provided for @uploadcontentthatcontains.
  ///
  /// In en, this message translates to:
  /// **'◆︎ Upload content that contains viruses, malware, or other harmful code.'**
  String get uploadcontentthatcontains;

  /// No description provided for @usetheplatformfor.
  ///
  /// In en, this message translates to:
  /// **'◆︎ Use the Platform for commercial purposes without our prior written consent, including spamming, advertising, or soliciting.'**
  String get usetheplatformfor;

  /// No description provided for @impersonateothersor.
  ///
  /// In en, this message translates to:
  /// **'◆︎ Impersonate others or misrepresent your identity or affiliation.'**
  String get impersonateothersor;

  /// No description provided for @attempttoaccesscollect.
  ///
  /// In en, this message translates to:
  /// **'◆︎ Attempt to access, collect, or use data from the Platform through automated means (e.g., bots, scrapers) without our permission.'**
  String get attempttoaccesscollect;

  /// No description provided for @violateanyapplicable.
  ///
  /// In en, this message translates to:
  /// **'◆︎ Violate any applicable laws, regulations, or third-party rights.'**
  String get violateanyapplicable;

  /// No description provided for @intellectualproperty.
  ///
  /// In en, this message translates to:
  /// **'6. Intellectual Property'**
  String get intellectualproperty;

  /// No description provided for @polzetcontent.
  ///
  /// In en, this message translates to:
  /// **'✧ Polzet’s Content :'**
  String get polzetcontent;

  /// No description provided for @allcontenttrademarks.
  ///
  /// In en, this message translates to:
  /// **'All content, trademarks, logos, and intellectual property owned by Polzet (excluding User Content) are protected by copyright, trademark, and other laws. You may not copy, reproduce, distribute, or create derivative works from Polzet content without our prior written consent.'**
  String get allcontenttrademarks;

  /// No description provided for @dmcacompliance.
  ///
  /// In en, this message translates to:
  /// **'✧ DMCA Compliance :'**
  String get dmcacompliance;

  /// No description provided for @polzetcomplieswith.
  ///
  /// In en, this message translates to:
  /// **'Polzet complies with the Digital Millennium Copyright Act (DMCA). If you believe your copyrighted work has been infringed on the Platform, please submit a notice to our designated copyright agent. We will respond to valid notices and may remove infringing content.'**
  String get polzetcomplieswith;

  /// No description provided for @usercontentinfringement.
  ///
  /// In en, this message translates to:
  /// **'✧ User Content Infringement :'**
  String get usercontentinfringement;

  /// No description provided for @ifyouuploadcontent.
  ///
  /// In en, this message translates to:
  /// **'If you upload content without proper authorization, you may be liable for copyright infringement. We encourage users to use original content or obtain permission before sharing third-party content.'**
  String get ifyouuploadcontent;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'7. Privacy'**
  String get privacy;

  /// No description provided for @youruseoftheplatform.
  ///
  /// In en, this message translates to:
  /// **'Your use of the Platform is subject to our Privacy Policy, which outlines how we collect, use, and protect your personal information. By using the Platform, you consent to our data practices as described in the Privacy Policy.'**
  String get youruseoftheplatform;

  /// No description provided for @thirdpartylinks.
  ///
  /// In en, this message translates to:
  /// **'8. Third-Party Links and Services'**
  String get thirdpartylinks;

  /// No description provided for @theplatformmaycontain.
  ///
  /// In en, this message translates to:
  /// **'The Platform may contain links to third-party websites, services, or advertisements. We are not responsible for the content, privacy practices, or terms of third-party sites. Accessing these links is at your own risk, and you should review the applicable terms and policies.'**
  String get theplatformmaycontain;

  /// No description provided for @limitationofliability.
  ///
  /// In en, this message translates to:
  /// **'9. Limitation of Liability'**
  String get limitationofliability;

  /// No description provided for @asisbasis.
  ///
  /// In en, this message translates to:
  /// **'✧ As-Is Basis :'**
  String get asisbasis;

  /// No description provided for @theplatformisprovidedas.
  ///
  /// In en, this message translates to:
  /// **'The Platform is provided as is without warranties of any kind, express or implied, including warranties of merchantability, fitness for a particular purpose, or non-infringement.'**
  String get theplatformisprovidedas;

  /// No description provided for @noliabilityfor.
  ///
  /// In en, this message translates to:
  /// **'✧ No Liability for User Content :'**
  String get noliabilityfor;

  /// No description provided for @polzetisnotresponsible.
  ///
  /// In en, this message translates to:
  /// **'Polzet is not responsible for the accuracy, integrity, or legality of User Content. You use the Platform and interact with User Content at your own risk.'**
  String get polzetisnotresponsible;

  /// No description provided for @noconsequentialdamages.
  ///
  /// In en, this message translates to:
  /// **'✧ No Consequential Damages :'**
  String get noconsequentialdamages;

  /// No description provided for @tothefullestextent.
  ///
  /// In en, this message translates to:
  /// **'To the fullest extent permitted by law, Polzet, its affiliates, and their respective officers, directors, employees, or agents will not be liable for any indirect, incidental, special, consequential, or punitive damages arising from your use of the Platform, even if advised of the possibility of such damages.'**
  String get tothefullestextent;

  /// No description provided for @indemnification.
  ///
  /// In en, this message translates to:
  /// **'10. Indemnification'**
  String get indemnification;

  /// No description provided for @youagreetoindemnify.
  ///
  /// In en, this message translates to:
  /// **'You agree to indemnify, defend, and hold harmless Polzet, its affiliates, and their respective officers, directors, employees, and agents from any claims, liabilities, damages, losses, or expenses (including reasonable attorneys’ fees) arising from your use of the Platform, your User Content, or your violation of these Terms or applicable law.'**
  String get youagreetoindemnify;

  /// No description provided for @terminationlabel.
  ///
  /// In en, this message translates to:
  /// **'11. Termination'**
  String get terminationlabel;

  /// No description provided for @youmayterminateyour.
  ///
  /// In en, this message translates to:
  /// **'You may terminate your account at any time by following the instructions on the Platform. Upon termination, your User Content may remain on the Platform if shared or reposted by others.'**
  String get youmayterminateyour;

  /// No description provided for @byyou.
  ///
  /// In en, this message translates to:
  /// **'✧ By You :'**
  String get byyou;

  /// No description provided for @bypolzet.
  ///
  /// In en, this message translates to:
  /// **'✧ By Polzet :'**
  String get bypolzet;

  /// No description provided for @wemaysuspendor.
  ///
  /// In en, this message translates to:
  /// **'We may suspend or terminate your access to the Platform at any time, with or without cause, and with or without notice.'**
  String get wemaysuspendor;

  /// No description provided for @survival.
  ///
  /// In en, this message translates to:
  /// **'✧ Survival :'**
  String get survival;

  /// No description provided for @provisionsofthese.
  ///
  /// In en, this message translates to:
  /// **'Provisions of these Terms that by their nature should survive termination (e.g., intellectual property, limitation of liability, indemnification) will continue to apply.'**
  String get provisionsofthese;

  /// No description provided for @miscellaneous.
  ///
  /// In en, this message translates to:
  /// **'12. Miscellaneous'**
  String get miscellaneous;

  /// No description provided for @entireagreement.
  ///
  /// In en, this message translates to:
  /// **'✧ Entire Agreement :'**
  String get entireagreement;

  /// No description provided for @thesetermstogether.
  ///
  /// In en, this message translates to:
  /// **'These Terms, together with our Privacy Policy, constitute the entire agreement between you and Polzet regarding your use of the Platform.'**
  String get thesetermstogether;

  /// No description provided for @nowaiver.
  ///
  /// In en, this message translates to:
  /// **'✧ No Waiver :'**
  String get nowaiver;

  /// No description provided for @ourfailureto.
  ///
  /// In en, this message translates to:
  /// **'Our failure to enforce any provision of these Terms does not constitute a waiver of that provision.'**
  String get ourfailureto;

  /// No description provided for @severability.
  ///
  /// In en, this message translates to:
  /// **'✧ Severability :'**
  String get severability;

  /// No description provided for @ifanyprovisionofthese.
  ///
  /// In en, this message translates to:
  /// **'If any provision of these Terms is found to be invalid or unenforceable, the remaining provisions will remain in full force and effect.'**
  String get ifanyprovisionofthese;

  /// No description provided for @assignment.
  ///
  /// In en, this message translates to:
  /// **'✧ Assignment :'**
  String get assignment;

  /// No description provided for @youmaynotassign.
  ///
  /// In en, this message translates to:
  /// **'You may not assign these Terms or your rights under them without our prior written consent. We may assign these Terms at our discretion.'**
  String get youmaynotassign;

  /// No description provided for @forcemajeure.
  ///
  /// In en, this message translates to:
  /// **'✧ Force Majeure :'**
  String get forcemajeure;

  /// No description provided for @polzetwillnotbeliable.
  ///
  /// In en, this message translates to:
  /// **'Polzet will not be liable for any failure to perform due to causes beyond our reasonable control (e.g., natural disasters, cyberattacks).'**
  String get polzetwillnotbeliable;

  /// No description provided for @contactusterms.
  ///
  /// In en, this message translates to:
  /// **'13. Contact Us'**
  String get contactusterms;

  /// No description provided for @ifyouhavequestionsabout.
  ///
  /// In en, this message translates to:
  /// **'If you have questions about these Terms, please contact us at :'**
  String get ifyouhavequestionsabout;

  /// No description provided for @byusingpolzetyouacknowledge.
  ///
  /// In en, this message translates to:
  /// **'By using Polzet, you acknowledge that you have read and understood these Terms and agree to be bound by them. Thank you for being part of our community!'**
  String get byusingpolzetyouacknowledge;

  /// No description provided for @polloptions.
  ///
  /// In en, this message translates to:
  /// **'Poll Options'**
  String get polloptions;

  /// No description provided for @takephoto.
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get takephoto;

  /// No description provided for @choosefromgallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get choosefromgallery;

  /// No description provided for @leavegroup.
  ///
  /// In en, this message translates to:
  /// **'Leave Group'**
  String get leavegroup;

  /// No description provided for @areyousureyouwanttoleavethisgroup.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to leave this group?'**
  String get areyousureyouwanttoleavethisgroup;

  /// No description provided for @yesleave.
  ///
  /// In en, this message translates to:
  /// **'Yes, Leave'**
  String get yesleave;

  /// No description provided for @member.
  ///
  /// In en, this message translates to:
  /// **'member'**
  String get member;

  /// No description provided for @subjectisrequired.
  ///
  /// In en, this message translates to:
  /// **'Subject is required'**
  String get subjectisrequired;

  /// No description provided for @messagemustbeatleasttencharacters.
  ///
  /// In en, this message translates to:
  /// **'Message must be at least 10 characters'**
  String get messagemustbeatleasttencharacters;

  /// No description provided for @setaccountpassword.
  ///
  /// In en, this message translates to:
  /// **'Set Account Password'**
  String get setaccountpassword;

  /// No description provided for @addapasswordtosigninwithoutgoogle.
  ///
  /// In en, this message translates to:
  /// **'Add a password to sign in without Google'**
  String get addapasswordtosigninwithoutgoogle;

  /// No description provided for @setapasswordsoyoucansigninwithoutgoogle.
  ///
  /// In en, this message translates to:
  /// **'Set a password so you can sign in without Google'**
  String get setapasswordsoyoucansigninwithoutgoogle;

  /// No description provided for @setpassword.
  ///
  /// In en, this message translates to:
  /// **'Set Password'**
  String get setpassword;

  /// No description provided for @reenternewpassword.
  ///
  /// In en, this message translates to:
  /// **'Re-enter new password'**
  String get reenternewpassword;

  /// No description provided for @savepassword.
  ///
  /// In en, this message translates to:
  /// **'Save Password'**
  String get savepassword;

  /// No description provided for @trendingtoday.
  ///
  /// In en, this message translates to:
  /// **'Trending today'**
  String get trendingtoday;

  /// No description provided for @alltimepopular.
  ///
  /// In en, this message translates to:
  /// **'All time popular'**
  String get alltimepopular;

  /// No description provided for @nochatsyet.
  ///
  /// In en, this message translates to:
  /// **'No chats yet'**
  String get nochatsyet;

  /// No description provided for @editmembers.
  ///
  /// In en, this message translates to:
  /// **'Edit members'**
  String get editmembers;

  /// No description provided for @nolikesthispost.
  ///
  /// In en, this message translates to:
  /// **'No likes this post'**
  String get nolikesthispost;

  /// No description provided for @editcomments.
  ///
  /// In en, this message translates to:
  /// **'Edit comment..'**
  String get editcomments;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @whatdoyouthinkforthis.
  ///
  /// In en, this message translates to:
  /// **'What do you think for this?'**
  String get whatdoyouthinkforthis;

  /// No description provided for @reportchat.
  ///
  /// In en, this message translates to:
  /// **'Report chat'**
  String get reportchat;

  /// No description provided for @yesreport.
  ///
  /// In en, this message translates to:
  /// **'Yes, Report'**
  String get yesreport;

  /// No description provided for @allimages.
  ///
  /// In en, this message translates to:
  /// **'All images'**
  String get allimages;

  /// No description provided for @polled.
  ///
  /// In en, this message translates to:
  /// **'Polled'**
  String get polled;

  /// No description provided for @voterspickedthisastopchoicesheet.
  ///
  /// In en, this message translates to:
  /// **'picked this as top choice '**
  String get voterspickedthisastopchoicesheet;

  /// No description provided for @peoplelikeyouchosetop.
  ///
  /// In en, this message translates to:
  /// **'people like you chose top'**
  String get peoplelikeyouchosetop;

  /// No description provided for @notagsavailable.
  ///
  /// In en, this message translates to:
  /// **'No tags available'**
  String get notagsavailable;

  /// No description provided for @messageisrequired.
  ///
  /// In en, this message translates to:
  /// **'Message is required'**
  String get messageisrequired;

  /// No description provided for @pleasefillinallfields.
  ///
  /// In en, this message translates to:
  /// **'Please fill in all fields'**
  String get pleasefillinallfields;

  /// No description provided for @passwordmustbeatleasteightcharacters.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get passwordmustbeatleasteightcharacters;

  /// No description provided for @passworddonotmatch.
  ///
  /// In en, this message translates to:
  /// **'Password do not match'**
  String get passworddonotmatch;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @chats.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get chats;

  /// No description provided for @groups.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get groups;

  /// No description provided for @shareprofile.
  ///
  /// In en, this message translates to:
  /// **'Share Profile'**
  String get shareprofile;

  /// No description provided for @images.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get images;

  /// No description provided for @nothingsavedyet.
  ///
  /// In en, this message translates to:
  /// **'Nothing saved yet'**
  String get nothingsavedyet;

  /// No description provided for @savedpollsyouwanttorevisitlater.
  ///
  /// In en, this message translates to:
  /// **'Saved polls you want to revisit later.'**
  String get savedpollsyouwanttorevisitlater;

  /// No description provided for @nothingspollyet.
  ///
  /// In en, this message translates to:
  /// **'No things poll yet'**
  String get nothingspollyet;

  /// No description provided for @createyourfirstpollandstartgatheringopinions.
  ///
  /// In en, this message translates to:
  /// **'Create your first poll and start gathering opinions.'**
  String get createyourfirstpollandstartgatheringopinions;

  /// No description provided for @noimagepollyet.
  ///
  /// In en, this message translates to:
  /// **'No image poll yet'**
  String get noimagepollyet;

  /// No description provided for @submitranking.
  ///
  /// In en, this message translates to:
  /// **'Submit ranking'**
  String get submitranking;

  /// No description provided for @rankyourchoices.
  ///
  /// In en, this message translates to:
  /// **'Rank your choices'**
  String get rankyourchoices;

  /// No description provided for @holdanddragtorankimage.
  ///
  /// In en, this message translates to:
  /// **'Hold & drag to rank image'**
  String get holdanddragtorankimage;

  /// No description provided for @holdanddragtorankanswer.
  ///
  /// In en, this message translates to:
  /// **'Hold & drag to rank answer'**
  String get holdanddragtorankanswer;

  /// No description provided for @stayactiveandsharepollstobuildyourcommunity.
  ///
  /// In en, this message translates to:
  /// **'Stay active and share polls to build your community'**
  String get stayactiveandsharepollstobuildyourcommunity;

  /// No description provided for @askopinionsandgetanswers.
  ///
  /// In en, this message translates to:
  /// **'Ask opinions & get answers'**
  String get askopinionsandgetanswers;

  /// No description provided for @updateyourpasswordandsecureyouraccount.
  ///
  /// In en, this message translates to:
  /// **'Update your password and secure your account'**
  String get updateyourpasswordandsecureyouraccount;

  /// No description provided for @controlwhocanviewyouractivityandpolls.
  ///
  /// In en, this message translates to:
  /// **'Control who can view your activity and polls'**
  String get controlwhocanviewyouractivityandpolls;

  /// No description provided for @managepeopleyouveblockedonpolzet.
  ///
  /// In en, this message translates to:
  /// **'Manage people you\'ve blocked on Polzet'**
  String get managepeopleyouveblockedonpolzet;

  /// No description provided for @preferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferences;

  /// No description provided for @choosewhatupdatesandalertsyouwanttoreceive.
  ///
  /// In en, this message translates to:
  /// **'Choose what updates and alerts you want to receive'**
  String get choosewhatupdatesandalertsyouwanttoreceive;

  /// No description provided for @chooseyourpreferredapplanguage.
  ///
  /// In en, this message translates to:
  /// **'Choose your preferred app language'**
  String get chooseyourpreferredapplanguage;

  /// No description provided for @gethelpwithyouraccount.
  ///
  /// In en, this message translates to:
  /// **'Get help with your account'**
  String get gethelpwithyouraccount;

  /// No description provided for @shareyourthoughtsandhelpimprovepolzet.
  ///
  /// In en, this message translates to:
  /// **'Share your thoughts and help improve Polzet.'**
  String get shareyourthoughtsandhelpimprovepolzet;

  /// No description provided for @readtherulesandguidelinesforusingpolzet.
  ///
  /// In en, this message translates to:
  /// **'Read the rules and guidelines for using Polzet.'**
  String get readtherulesandguidelinesforusingpolzet;

  /// No description provided for @continueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueButton;

  /// No description provided for @currentpasswordisrequired.
  ///
  /// In en, this message translates to:
  /// **'Current password is required.'**
  String get currentpasswordisrequired;

  /// No description provided for @newpasswordisrequired.
  ///
  /// In en, this message translates to:
  /// **'New password is required.'**
  String get newpasswordisrequired;

  /// No description provided for @mustbeeightpluscharacterswithaletternumberandspecialcharacter.
  ///
  /// In en, this message translates to:
  /// **'Must be 8+ characters with a letter, number & special character.'**
  String get mustbeeightpluscharacterswithaletternumberandspecialcharacter;

  /// No description provided for @pleaseconfirmyournewpassword.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your new password.'**
  String get pleaseconfirmyournewpassword;

  /// No description provided for @passwordsdonotmatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match.'**
  String get passwordsdonotmatch;

  /// No description provided for @pushnotification.
  ///
  /// In en, this message translates to:
  /// **'Push Notification'**
  String get pushnotification;

  /// No description provided for @receivealertandupdatesacrosspolzet.
  ///
  /// In en, this message translates to:
  /// **'Receive alert and updates across Polzet.'**
  String get receivealertandupdatesacrosspolzet;

  /// No description provided for @pollactivity.
  ///
  /// In en, this message translates to:
  /// **'Poll Activity'**
  String get pollactivity;

  /// No description provided for @commentsandreplies.
  ///
  /// In en, this message translates to:
  /// **'Comments & Replies'**
  String get commentsandreplies;

  /// No description provided for @socialactivity.
  ///
  /// In en, this message translates to:
  /// **'Social Activity'**
  String get socialactivity;

  /// No description provided for @searchaccountspostsplaces.
  ///
  /// In en, this message translates to:
  /// **'Search accounts, posts, places…'**
  String get searchaccountspostsplaces;

  /// No description provided for @norecentsearches.
  ///
  /// In en, this message translates to:
  /// **'No recent searches'**
  String get norecentsearches;

  /// No description provided for @tryanotherkeywordorexploretrendingpolls.
  ///
  /// In en, this message translates to:
  /// **'Try another keyword or explore trending polls.'**
  String get tryanotherkeywordorexploretrendingpolls;

  /// No description provided for @searching.
  ///
  /// In en, this message translates to:
  /// **'Searching...'**
  String get searching;

  /// No description provided for @notfound.
  ///
  /// In en, this message translates to:
  /// **'Not found'**
  String get notfound;

  /// No description provided for @accounts.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get accounts;

  /// No description provided for @accountslower.
  ///
  /// In en, this message translates to:
  /// **'accounts'**
  String get accountslower;

  /// No description provided for @trysearchingwithadifferentusernameorkeyword.
  ///
  /// In en, this message translates to:
  /// **'Try searching with a different username or keyword.'**
  String get trysearchingwithadifferentusernameorkeyword;

  /// No description provided for @tags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get tags;

  /// No description provided for @tag.
  ///
  /// In en, this message translates to:
  /// **'tags'**
  String get tag;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @found.
  ///
  /// In en, this message translates to:
  /// **'found'**
  String get found;

  /// No description provided for @post.
  ///
  /// In en, this message translates to:
  /// **'posts'**
  String get post;

  /// No description provided for @exploretrendingconversationsortryanothersearch.
  ///
  /// In en, this message translates to:
  /// **'Explore trending conversations or try another search.'**
  String get exploretrendingconversationsortryanothersearch;

  /// No description provided for @photoslower.
  ///
  /// In en, this message translates to:
  /// **'photos'**
  String get photoslower;

  /// No description provided for @wecouldnotfindanymatchingphotos.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find any matching photos.'**
  String get wecouldnotfindanymatchingphotos;

  /// No description provided for @trysearchingforanothertopicorkeyword.
  ///
  /// In en, this message translates to:
  /// **'Try searching for another topic or keyword.'**
  String get trysearchingforanothertopicorkeyword;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @lastsavendays.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get lastsavendays;

  /// No description provided for @lastthirtydays.
  ///
  /// In en, this message translates to:
  /// **'Last 30 days'**
  String get lastthirtydays;

  /// No description provided for @older.
  ///
  /// In en, this message translates to:
  /// **'Older'**
  String get older;

  /// No description provided for @clearallnotifications.
  ///
  /// In en, this message translates to:
  /// **'Clear all notifications'**
  String get clearallnotifications;

  /// No description provided for @areyousureyouwanttoclearallnotifications.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to clear all notifications?'**
  String get areyousureyouwanttoclearallnotifications;

  /// No description provided for @yesclearall.
  ///
  /// In en, this message translates to:
  /// **'Yes, clear all'**
  String get yesclearall;

  /// No description provided for @deletenotifications.
  ///
  /// In en, this message translates to:
  /// **'Delete notifications'**
  String get deletenotifications;

  /// No description provided for @areyousureyouwanttodeletethesenotifications.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete these notifications?'**
  String get areyousureyouwanttodeletethesenotifications;

  /// No description provided for @thisoinwillbeusedtosecureyouraccount.
  ///
  /// In en, this message translates to:
  /// **'This PIN will be used to secure your account'**
  String get thisoinwillbeusedtosecureyouraccount;

  /// No description provided for @changeoin.
  ///
  /// In en, this message translates to:
  /// **'Change PIN'**
  String get changeoin;

  /// No description provided for @likedby.
  ///
  /// In en, this message translates to:
  /// **'Liked by'**
  String get likedby;

  /// No description provided for @bethefirsttostarttheconversation.
  ///
  /// In en, this message translates to:
  /// **'Be the first to start the conversation'**
  String get bethefirsttostarttheconversation;

  /// No description provided for @suggestedforyou.
  ///
  /// In en, this message translates to:
  /// **'Suggested for you'**
  String get suggestedforyou;

  /// No description provided for @pollresult.
  ///
  /// In en, this message translates to:
  /// **'Poll result'**
  String get pollresult;

  /// No description provided for @totalvotes.
  ///
  /// In en, this message translates to:
  /// **'Total votes'**
  String get totalvotes;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @screenshotsoptional.
  ///
  /// In en, this message translates to:
  /// **'Screenshots (Optional)'**
  String get screenshotsoptional;

  /// No description provided for @nomessagesyet.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get nomessagesyet;

  /// No description provided for @nofavoritechatyet.
  ///
  /// In en, this message translates to:
  /// **'No favorite chat yet'**
  String get nofavoritechatyet;

  /// No description provided for @chatsyoufavoritewillappearhere.
  ///
  /// In en, this message translates to:
  /// **'Chats you favorite will appear here.'**
  String get chatsyoufavoritewillappearhere;

  /// No description provided for @nonotificationsyet.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get nonotificationsyet;

  /// No description provided for @likescommentsandupdateswillappearhere.
  ///
  /// In en, this message translates to:
  /// **'Likes, comments, and updates will appear here.'**
  String get likescommentsandupdateswillappearhere;

  /// No description provided for @votesupdateswillappearhere.
  ///
  /// In en, this message translates to:
  /// **'Votes updates will appear here.'**
  String get votesupdateswillappearhere;

  /// No description provided for @chaserequestsupdateswillappearhere.
  ///
  /// In en, this message translates to:
  /// **'Chase requests updates will appear here.'**
  String get chaserequestsupdateswillappearhere;

  /// No description provided for @startchattingbysharingpollsorreactingtoconversations.
  ///
  /// In en, this message translates to:
  /// **'Start chatting by sharing polls or reacting\nto conversations.'**
  String get startchattingbysharingpollsorreactingtoconversations;

  /// No description provided for @doyouwanttochangeyourcurrentpin.
  ///
  /// In en, this message translates to:
  /// **'Do you want to change your current PIN?'**
  String get doyouwanttochangeyourcurrentpin;

  /// No description provided for @top.
  ///
  /// In en, this message translates to:
  /// **'Top'**
  String get top;

  /// No description provided for @searchvoters.
  ///
  /// In en, this message translates to:
  /// **'Search voters'**
  String get searchvoters;

  /// No description provided for @fingerprint.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint'**
  String get fingerprint;

  /// No description provided for @enablefingerprint.
  ///
  /// In en, this message translates to:
  /// **'Enable Fingerprint'**
  String get enablefingerprint;

  /// No description provided for @unlocktheappfasterandmoresecurelybyusingyourfingerprint.
  ///
  /// In en, this message translates to:
  /// **'Unlock the app faster and more securely by\nusing your fingerprint'**
  String get unlocktheappfasterandmoresecurelybyusingyourfingerprint;

  /// No description provided for @thisaccountisprivate.
  ///
  /// In en, this message translates to:
  /// **'This account is private'**
  String get thisaccountisprivate;

  /// No description provided for @chasethisaccounttoseetheirposts.
  ///
  /// In en, this message translates to:
  /// **'Chase this account to see their posts.'**
  String get chasethisaccounttoseetheirposts;

  /// No description provided for @online.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get online;

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offline;

  /// No description provided for @startchasingpeopletodiscoverfreshopinionsthenwillappearusershere.
  ///
  /// In en, this message translates to:
  /// **'Start chasing people to discover fresh opinions\nthen will appear users here'**
  String get startchasingpeopletodiscoverfreshopinionsthenwillappearusershere;

  /// No description provided for @selectyourdateofbirth.
  ///
  /// In en, this message translates to:
  /// **'Select your date of birth'**
  String get selectyourdateofbirth;

  /// No description provided for @selected.
  ///
  /// In en, this message translates to:
  /// **'selected'**
  String get selected;

  /// No description provided for @chasing.
  ///
  /// In en, this message translates to:
  /// **'Chasing'**
  String get chasing;

  /// No description provided for @chaseback.
  ///
  /// In en, this message translates to:
  /// **'Chase Back'**
  String get chaseback;

  /// No description provided for @requested.
  ///
  /// In en, this message translates to:
  /// **'Requested'**
  String get requested;

  /// No description provided for @usefingerprint.
  ///
  /// In en, this message translates to:
  /// **'Use fingerprint'**
  String get usefingerprint;

  /// No description provided for @novotersfound.
  ///
  /// In en, this message translates to:
  /// **'No voters found'**
  String get novotersfound;

  /// No description provided for @permanentlydeleteyourpolzetaccountandalldata.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete your Polzet account and all data'**
  String get permanentlydeleteyourpolzetaccountandalldata;

  /// No description provided for @unblockuser.
  ///
  /// In en, this message translates to:
  /// **'Unblock User'**
  String get unblockuser;

  /// No description provided for @blockuser.
  ///
  /// In en, this message translates to:
  /// **'Block User'**
  String get blockuser;

  /// No description provided for @areyousureyouwanttounblockthisuser.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to unblock this user?'**
  String get areyousureyouwanttounblockthisuser;

  /// No description provided for @areyousureyouwanttoblockthisuser.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to block this user?'**
  String get areyousureyouwanttoblockthisuser;

  /// No description provided for @nopostsavailable.
  ///
  /// In en, this message translates to:
  /// **'No posts available'**
  String get nopostsavailable;

  /// No description provided for @searchsettingsfeatures.
  ///
  /// In en, this message translates to:
  /// **'Search settings & features...'**
  String get searchsettingsfeatures;

  /// No description provided for @choosehowyouwanttoaskyourquestion.
  ///
  /// In en, this message translates to:
  /// **'Choose how you want to ask your question'**
  String get choosehowyouwanttoaskyourquestion;

  /// No description provided for @textpoll.
  ///
  /// In en, this message translates to:
  /// **'Text Poll'**
  String get textpoll;

  /// No description provided for @asksimplequestionswithtextchoices.
  ///
  /// In en, this message translates to:
  /// **'Ask simple questions with text choices'**
  String get asksimplequestionswithtextchoices;

  /// No description provided for @imagepoll.
  ///
  /// In en, this message translates to:
  /// **'Image Poll'**
  String get imagepoll;

  /// No description provided for @comparephotosandvisualchoices.
  ///
  /// In en, this message translates to:
  /// **'Compare photos and visual choices'**
  String get comparephotosandvisualchoices;

  /// No description provided for @battlepoll.
  ///
  /// In en, this message translates to:
  /// **'Battle Poll'**
  String get battlepoll;

  /// No description provided for @comparerivalsandcrownawinner.
  ///
  /// In en, this message translates to:
  /// **'Compare rivals and crown a winner'**
  String get comparerivalsandcrownawinner;

  /// No description provided for @thisorthat.
  ///
  /// In en, this message translates to:
  /// **'This or That'**
  String get thisorthat;

  /// No description provided for @pickbetweentwoquickchoices.
  ///
  /// In en, this message translates to:
  /// **'Pick between two quick choices'**
  String get pickbetweentwoquickchoices;

  /// No description provided for @hottakespoll.
  ///
  /// In en, this message translates to:
  /// **'Hot Takes Poll'**
  String get hottakespoll;

  /// No description provided for @shareahottake.
  ///
  /// In en, this message translates to:
  /// **'Share a Hot Take'**
  String get shareahottake;

  /// No description provided for @postboldopinionssparkdebatesandhearbothsides.
  ///
  /// In en, this message translates to:
  /// **'Post bold opinions, spark debates, and hear both sides'**
  String get postboldopinionssparkdebatesandhearbothsides;

  /// No description provided for @yourhottake.
  ///
  /// In en, this message translates to:
  /// **'Your hot take'**
  String get yourhottake;

  /// No description provided for @shareopinionsandstartdebates.
  ///
  /// In en, this message translates to:
  /// **'Share opinions and start debates'**
  String get shareopinionsandstartdebates;

  /// No description provided for @anonymouspoll.
  ///
  /// In en, this message translates to:
  /// **'Anonymous Poll'**
  String get anonymouspoll;

  /// No description provided for @gethonestopinionsprivately.
  ///
  /// In en, this message translates to:
  /// **'Get honest opinions privately'**
  String get gethonestopinionsprivately;

  /// No description provided for @descriptionhashtagsoptional.
  ///
  /// In en, this message translates to:
  /// **'Description & Hashtags (Optional)'**
  String get descriptionhashtagsoptional;

  /// No description provided for @typedescriptionorhashtags.
  ///
  /// In en, this message translates to:
  /// **'Type description or hashtags'**
  String get typedescriptionorhashtags;

  /// No description provided for @generatequestion.
  ///
  /// In en, this message translates to:
  /// **'Generate'**
  String get generatequestion;

  /// No description provided for @regeneratequestion.
  ///
  /// In en, this message translates to:
  /// **'Regenerate'**
  String get regeneratequestion;

  /// No description provided for @generating.
  ///
  /// In en, this message translates to:
  /// **'Generating'**
  String get generating;

  /// No description provided for @generateoptions.
  ///
  /// In en, this message translates to:
  /// **'Generate'**
  String get generateoptions;

  /// No description provided for @regenerateoptions.
  ///
  /// In en, this message translates to:
  /// **'Regenerate'**
  String get regenerateoptions;

  /// No description provided for @votingmode.
  ///
  /// In en, this message translates to:
  /// **'Voting Mode'**
  String get votingmode;

  /// No description provided for @singlechoice.
  ///
  /// In en, this message translates to:
  /// **'Single Choice'**
  String get singlechoice;

  /// No description provided for @voterspickoneoption.
  ///
  /// In en, this message translates to:
  /// **'Voters pick one option'**
  String get voterspickoneoption;

  /// No description provided for @multiplechoice.
  ///
  /// In en, this message translates to:
  /// **'Multiple Choice'**
  String get multiplechoice;

  /// No description provided for @votersrankalloptions.
  ///
  /// In en, this message translates to:
  /// **'Voters rank all options'**
  String get votersrankalloptions;

  /// No description provided for @pleaseenteratopic.
  ///
  /// In en, this message translates to:
  /// **'Please enter a topic'**
  String get pleaseenteratopic;

  /// No description provided for @addlabel.
  ///
  /// In en, this message translates to:
  /// **'Add label'**
  String get addlabel;

  /// No description provided for @putcompetitorsheadtoheadandseewhichsidewins.
  ///
  /// In en, this message translates to:
  /// **'Put competitors head-to-head and see which side wins'**
  String get putcompetitorsheadtoheadandseewhichsidewins;

  /// No description provided for @startbattel.
  ///
  /// In en, this message translates to:
  /// **'Start battel'**
  String get startbattel;

  /// No description provided for @competitors.
  ///
  /// In en, this message translates to:
  /// **'Competitors'**
  String get competitors;

  /// No description provided for @comparetwochoicesanddiscoverwhatpeopleprefer.
  ///
  /// In en, this message translates to:
  /// **'Compare two choices and discover what people prefer'**
  String get comparetwochoicesanddiscoverwhatpeopleprefer;

  /// No description provided for @askquickly.
  ///
  /// In en, this message translates to:
  /// **'Ask quickly'**
  String get askquickly;

  /// No description provided for @optional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optional;

  /// No description provided for @reactions.
  ///
  /// In en, this message translates to:
  /// **'Reactions'**
  String get reactions;

  /// No description provided for @camera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get camera;

  /// No description provided for @gallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get gallery;

  /// No description provided for @askanonymously.
  ///
  /// In en, this message translates to:
  /// **'Ask Anonymously'**
  String get askanonymously;

  /// No description provided for @sharequestionsprivatelyandgethonestopinionsfrompeople.
  ///
  /// In en, this message translates to:
  /// **'Share questions privately and get honest opinions from people'**
  String get sharequestionsprivatelyandgethonestopinionsfrompeople;

  /// No description provided for @yourvoterswillbehiddenonthispoll.
  ///
  /// In en, this message translates to:
  /// **'Your voters will be hidden on this poll'**
  String get yourvoterswillbehiddenonthispoll;

  /// No description provided for @pin.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get pin;

  /// No description provided for @unpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get unpin;

  /// No description provided for @mute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get mute;

  /// No description provided for @unmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get unmute;

  /// No description provided for @removefromfavorites.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get removefromfavorites;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @unread.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get unread;

  /// No description provided for @archivedchats.
  ///
  /// In en, this message translates to:
  /// **'Archived Chats'**
  String get archivedchats;

  /// No description provided for @archive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archive;

  /// No description provided for @unarchive.
  ///
  /// In en, this message translates to:
  /// **'Unarchive'**
  String get unarchive;

  /// No description provided for @deletechat.
  ///
  /// In en, this message translates to:
  /// **'Delete Chat'**
  String get deletechat;

  /// No description provided for @areyousureyouwanttodeletethischatthisactioncannotbeundone.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this chat? This action cannot be undone.'**
  String get areyousureyouwanttodeletethischatthisactioncannotbeundone;

  /// No description provided for @clearchat.
  ///
  /// In en, this message translates to:
  /// **'Clear Chat'**
  String get clearchat;

  /// No description provided for @areyousureyouwanttoclearallmessagesinthischatthisactioncannotbeundone.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to clear all messages in this chat? This action cannot be undone'**
  String
  get areyousureyouwanttoclearallmessagesinthischatthisactioncannotbeundone;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @joinrequests.
  ///
  /// In en, this message translates to:
  /// **'Join Requests'**
  String get joinrequests;

  /// No description provided for @nopendingjoinrequests.
  ///
  /// In en, this message translates to:
  /// **'No pending join requests'**
  String get nopendingjoinrequests;

  /// No description provided for @newchat.
  ///
  /// In en, this message translates to:
  /// **'New Chat'**
  String get newchat;

  /// No description provided for @addtwosimilarimagesegoutfitsplacesfood.
  ///
  /// In en, this message translates to:
  /// **'Add 2 similar images (e.g. outfits, places, food)'**
  String get addtwosimilarimagesegoutfitsplacesfood;

  /// No description provided for @addtwoorfoursimilarimagesegoutfitsplacesfood.
  ///
  /// In en, this message translates to:
  /// **'Add 2-4 similar images (e.g. outfits, places, food)'**
  String get addtwoorfoursimilarimagesegoutfitsplacesfood;

  /// No description provided for @startabattle.
  ///
  /// In en, this message translates to:
  /// **'Start a battle'**
  String get startabattle;

  /// No description provided for @createthisorthat.
  ///
  /// In en, this message translates to:
  /// **'Create This or That'**
  String get createthisorthat;

  /// No description provided for @pleaseenteraquestionortopic.
  ///
  /// In en, this message translates to:
  /// **'Please enter a question or topic'**
  String get pleaseenteraquestionortopic;

  /// No description provided for @pleaseselecttwoimages.
  ///
  /// In en, this message translates to:
  /// **'Please select 2 images'**
  String get pleaseselecttwoimages;

  /// No description provided for @markasread.
  ///
  /// In en, this message translates to:
  /// **'Mark as read'**
  String get markasread;

  /// No description provided for @markasunread.
  ///
  /// In en, this message translates to:
  /// **'Mark as unread'**
  String get markasunread;

  /// No description provided for @archivedgroups.
  ///
  /// In en, this message translates to:
  /// **'Archived Groups'**
  String get archivedgroups;

  /// No description provided for @noarchivedchatsyet.
  ///
  /// In en, this message translates to:
  /// **'No archived chats yet'**
  String get noarchivedchatsyet;

  /// No description provided for @public.
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get public;

  /// No description provided for @anyonecanfindjoinandviewmessages.
  ///
  /// In en, this message translates to:
  /// **'Anyone can find, join, and view messages.'**
  String get anyonecanfindjoinandviewmessages;

  /// No description provided for @private.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get private;

  /// No description provided for @onlyapprovedmemberscanjoinandview.
  ///
  /// In en, this message translates to:
  /// **'Only approved members can join and view.'**
  String get onlyapprovedmemberscanjoinandview;

  /// No description provided for @inviteonly.
  ///
  /// In en, this message translates to:
  /// **'Invite Only'**
  String get inviteonly;

  /// No description provided for @hiddenfromsearchjoinbyinvitelink.
  ///
  /// In en, this message translates to:
  /// **'Hidden from search. Join by invite link.'**
  String get hiddenfromsearchjoinbyinvitelink;

  /// No description provided for @privacygroup.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacygroup;

  /// No description provided for @popularthings.
  ///
  /// In en, this message translates to:
  /// **'Popular things'**
  String get popularthings;

  /// No description provided for @places.
  ///
  /// In en, this message translates to:
  /// **'Places'**
  String get places;

  /// No description provided for @searchpollsfriendsandhashtags.
  ///
  /// In en, this message translates to:
  /// **'Search polls, friends and hashtags...'**
  String get searchpollsfriendsandhashtags;

  /// No description provided for @lookupaccountstagsorplaces.
  ///
  /// In en, this message translates to:
  /// **'Look up accounts, tags or places...'**
  String get lookupaccountstagsorplaces;

  /// No description provided for @findtrendingtopics.
  ///
  /// In en, this message translates to:
  /// **'Find trending topics...'**
  String get findtrendingtopics;

  /// No description provided for @trendingpolls.
  ///
  /// In en, this message translates to:
  /// **'Trending Polls'**
  String get trendingpolls;

  /// No description provided for @contentpreferences.
  ///
  /// In en, this message translates to:
  /// **'Content Preferences'**
  String get contentpreferences;

  /// No description provided for @choosewhatyouwanttoseeonpolzet.
  ///
  /// In en, this message translates to:
  /// **'Choose what you want to see on Polzet'**
  String get choosewhatyouwanttoseeonpolzet;

  /// No description provided for @country.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get country;

  /// No description provided for @choosethecountryforyourcontentandpolls.
  ///
  /// In en, this message translates to:
  /// **'Choose the country for your content and polls'**
  String get choosethecountryforyourcontentandpolls;

  /// No description provided for @interests.
  ///
  /// In en, this message translates to:
  /// **'Interests'**
  String get interests;

  /// No description provided for @choosethetopicsyouwanttoseemoreof.
  ///
  /// In en, this message translates to:
  /// **'Choose the topics you want to see more of'**
  String get choosethetopicsyouwanttoseemoreof;

  /// No description provided for @searchcountry.
  ///
  /// In en, this message translates to:
  /// **'Search country'**
  String get searchcountry;

  /// No description provided for @searchinterest.
  ///
  /// In en, this message translates to:
  /// **'Search interest'**
  String get searchinterest;

  /// No description provided for @nointerestsfound.
  ///
  /// In en, this message translates to:
  /// **'No interests found'**
  String get nointerestsfound;

  /// No description provided for @nocountriesfound.
  ///
  /// In en, this message translates to:
  /// **'No countries found'**
  String get nocountriesfound;

  /// No description provided for @copyprofilelink.
  ///
  /// In en, this message translates to:
  /// **'Copy Profile Link'**
  String get copyprofilelink;

  /// No description provided for @noaigenerationsleft.
  ///
  /// In en, this message translates to:
  /// **'No AI generations left today'**
  String get noaigenerationsleft;

  /// No description provided for @creditsresettomorrow.
  ///
  /// In en, this message translates to:
  /// **'Your credits will reset tomorrow'**
  String get creditsresettomorrow;

  /// No description provided for @lefttoday.
  ///
  /// In en, this message translates to:
  /// **'left today'**
  String get lefttoday;

  /// No description provided for @comingsoon.
  ///
  /// In en, this message translates to:
  /// **'COMING SOON'**
  String get comingsoon;

  /// No description provided for @newfeaturescomingsoon.
  ///
  /// In en, this message translates to:
  /// **'New features coming soon'**
  String get newfeaturescomingsoon;

  /// No description provided for @comingsoondescription.
  ///
  /// In en, this message translates to:
  /// **'We\'re working on powerful business profile tools, advanced analytics, and more ways to grow your presence on Polzet.'**
  String get comingsoondescription;

  /// No description provided for @indevelopment.
  ///
  /// In en, this message translates to:
  /// **'In Development'**
  String get indevelopment;

  /// No description provided for @businessprofiletools.
  ///
  /// In en, this message translates to:
  /// **'Business Profile Tools'**
  String get businessprofiletools;

  /// No description provided for @businessprofiletoolsdescription.
  ///
  /// In en, this message translates to:
  /// **'Custom branding, verified badges, action buttons, & business links.'**
  String get businessprofiletoolsdescription;

  /// No description provided for @comingq4.
  ///
  /// In en, this message translates to:
  /// **'Coming Q4'**
  String get comingq4;

  /// No description provided for @advancedanalytics.
  ///
  /// In en, this message translates to:
  /// **'Advanced Analytics'**
  String get advancedanalytics;

  /// No description provided for @advancedanalyticsdescription.
  ///
  /// In en, this message translates to:
  /// **'Demographic breakdown, peak activity hours, & voter retention stats.'**
  String get advancedanalyticsdescription;

  /// No description provided for @planned.
  ///
  /// In en, this message translates to:
  /// **'Planned'**
  String get planned;

  /// No description provided for @growthandpromotions.
  ///
  /// In en, this message translates to:
  /// **'Growth & Promotions'**
  String get growthandpromotions;

  /// No description provided for @growthandpromotionsdescription.
  ///
  /// In en, this message translates to:
  /// **'Boosted poll placement, targeted reach, & audience retargeting.'**
  String get growthandpromotionsdescription;

  /// No description provided for @getvipearlyaccess.
  ///
  /// In en, this message translates to:
  /// **'Get VIP Early Access'**
  String get getvipearlyaccess;

  /// No description provided for @vipearlyaccessdescription.
  ///
  /// In en, this message translates to:
  /// **'Be the first to test new tools when they launch.'**
  String get vipearlyaccessdescription;

  /// No description provided for @onearlyaccesslist.
  ///
  /// In en, this message translates to:
  /// **'You\'re on the early access list!'**
  String get onearlyaccesslist;

  /// No description provided for @joinwaitlist.
  ///
  /// In en, this message translates to:
  /// **'Join Waitlist'**
  String get joinwaitlist;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'ar',
    'de',
    'en',
    'es',
    'hi',
    'id',
    'vi',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'hi':
      return AppLocalizationsHi();
    case 'id':
      return AppLocalizationsId();
    case 'vi':
      return AppLocalizationsVi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
