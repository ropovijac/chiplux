import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hr.dart';

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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
    Locale('en'),
    Locale('hr'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Chiplux'**
  String get appName;

  /// No description provided for @discover.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get discover;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @watch.
  ///
  /// In en, this message translates to:
  /// **'Watch'**
  String get watch;

  /// No description provided for @community.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get community;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @customize.
  ///
  /// In en, this message translates to:
  /// **'CUSTOMIZE'**
  String get customize;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'SETTINGS'**
  String get settings;

  /// No description provided for @help.
  ///
  /// In en, this message translates to:
  /// **'HELP'**
  String get help;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @accountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your Chiplux account and sign-in information.'**
  String get accountSubtitle;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @notAvailable.
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get notAvailable;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePassword;

  /// No description provided for @changePasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Update your account password'**
  String get changePasswordSubtitle;

  /// No description provided for @adminModeration.
  ///
  /// In en, this message translates to:
  /// **'Admin Moderation'**
  String get adminModeration;

  /// No description provided for @adminModerationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Review user, comment, bug and feature reports'**
  String get adminModerationSubtitle;

  /// No description provided for @preferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferences;

  /// No description provided for @preferencesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose how Chiplux behaves on this device.'**
  String get preferencesSubtitle;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @notificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Episodes, releases and community activity'**
  String get notificationsSubtitle;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// No description provided for @privacySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Profile, activity and interaction controls'**
  String get privacySubtitle;

  /// No description provided for @dataExport.
  ///
  /// In en, this message translates to:
  /// **'Data & Export'**
  String get dataExport;

  /// No description provided for @dataExportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Export your Chiplux data and schedule backups'**
  String get dataExportSubtitle;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose the language used by the Chiplux interface.'**
  String get languageSubtitle;

  /// No description provided for @systemDefault.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get systemDefault;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @croatian.
  ///
  /// In en, this message translates to:
  /// **'Hrvatski'**
  String get croatian;

  /// No description provided for @languagePageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose the language for Chiplux menus, buttons and messages. Media titles and user content are never translated by this setting.'**
  String get languagePageSubtitle;

  /// No description provided for @languageChanged.
  ///
  /// In en, this message translates to:
  /// **'Language changed.'**
  String get languageChanged;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccount;

  /// No description provided for @helpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Support, policies and answers about Chiplux.'**
  String get helpSubtitle;

  /// No description provided for @faq.
  ///
  /// In en, this message translates to:
  /// **'FAQ'**
  String get faq;

  /// No description provided for @faqSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Common Chiplux questions'**
  String get faqSubtitle;

  /// No description provided for @contact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get contact;

  /// No description provided for @contactSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Contact details and support'**
  String get contactSubtitle;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @privacyPolicySubtitle.
  ///
  /// In en, this message translates to:
  /// **'How Chiplux handles data'**
  String get privacyPolicySubtitle;

  /// No description provided for @terms.
  ///
  /// In en, this message translates to:
  /// **'Terms'**
  String get terms;

  /// No description provided for @termsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Terms of use'**
  String get termsSubtitle;

  /// No description provided for @suggestFeature.
  ///
  /// In en, this message translates to:
  /// **'Suggest a Feature'**
  String get suggestFeature;

  /// No description provided for @suggestFeatureSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Share an idea with the Chiplux developer'**
  String get suggestFeatureSubtitle;

  /// No description provided for @reportBug.
  ///
  /// In en, this message translates to:
  /// **'Report a Bug'**
  String get reportBug;

  /// No description provided for @reportBugSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Send a problem directly to Chiplux'**
  String get reportBugSubtitle;

  /// No description provided for @informationSupport.
  ///
  /// In en, this message translates to:
  /// **'Information and support for Chiplux.'**
  String get informationSupport;

  /// No description provided for @commentsLockedEpisode.
  ///
  /// In en, this message translates to:
  /// **'Comments are locked until you watch this episode.'**
  String get commentsLockedEpisode;

  /// No description provided for @commentsLockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Comments are locked until you finish this title.'**
  String get commentsLockedTitle;

  /// No description provided for @couldNotLoadComments.
  ///
  /// In en, this message translates to:
  /// **'Could not load comments.'**
  String get couldNotLoadComments;

  /// No description provided for @letsComment.
  ///
  /// In en, this message translates to:
  /// **'Let’s Comment'**
  String get letsComment;

  /// No description provided for @reply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get reply;

  /// No description provided for @replies.
  ///
  /// In en, this message translates to:
  /// **'Replies'**
  String get replies;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @report.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get report;

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

  /// No description provided for @spoiler.
  ///
  /// In en, this message translates to:
  /// **'Spoiler'**
  String get spoiler;

  /// No description provided for @showSpoiler.
  ///
  /// In en, this message translates to:
  /// **'Show spoiler'**
  String get showSpoiler;

  /// No description provided for @dataExportPageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Back up your Chiplux account data or create an export whenever you want.'**
  String get dataExportPageSubtitle;

  /// No description provided for @automaticBackup.
  ///
  /// In en, this message translates to:
  /// **'Automatic backup'**
  String get automaticBackup;

  /// No description provided for @automaticBackupDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose how often Chiplux should create a local JSON backup.'**
  String get automaticBackupDescription;

  /// No description provided for @everyDay.
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get everyDay;

  /// No description provided for @everyWeek.
  ///
  /// In en, this message translates to:
  /// **'Every week'**
  String get everyWeek;

  /// No description provided for @everyMonth.
  ///
  /// In en, this message translates to:
  /// **'Every month'**
  String get everyMonth;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get off;

  /// No description provided for @exportNow.
  ///
  /// In en, this message translates to:
  /// **'Export now'**
  String get exportNow;

  /// No description provided for @exportNowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create a JSON backup and choose where to save or share it.'**
  String get exportNowSubtitle;

  /// No description provided for @automaticBackupInfo.
  ///
  /// In en, this message translates to:
  /// **'Automatic backups are checked when Chiplux opens. If an interval passed while the app was closed, the backup is created the next time the app starts.'**
  String get automaticBackupInfo;

  /// No description provided for @exportIncludes.
  ///
  /// In en, this message translates to:
  /// **'Exports include your profile settings, library, watched episodes, ratings, comments, activity, following list, notifications, reports, feature suggestions and blocked-user list.'**
  String get exportIncludes;

  /// No description provided for @couldNotExportData.
  ///
  /// In en, this message translates to:
  /// **'Could not export data: {error}'**
  String couldNotExportData(String error);

  /// No description provided for @whileChipluxUsed.
  ///
  /// In en, this message translates to:
  /// **'{cadence} while Chiplux is being used'**
  String whileChipluxUsed(String cadence);

  /// No description provided for @users.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get users;

  /// No description provided for @comments.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get comments;

  /// No description provided for @bugs.
  ///
  /// In en, this message translates to:
  /// **'Bugs'**
  String get bugs;

  /// No description provided for @suggestions.
  ///
  /// In en, this message translates to:
  /// **'Suggestions'**
  String get suggestions;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @inProgress.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get inProgress;

  /// No description provided for @implemented.
  ///
  /// In en, this message translates to:
  /// **'Implemented'**
  String get implemented;

  /// No description provided for @rejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get rejected;

  /// No description provided for @ignored.
  ///
  /// In en, this message translates to:
  /// **'Ignored'**
  String get ignored;

  /// No description provided for @resolve.
  ///
  /// In en, this message translates to:
  /// **'Resolve'**
  String get resolve;

  /// No description provided for @dismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// No description provided for @reviewing.
  ///
  /// In en, this message translates to:
  /// **'Reviewing'**
  String get reviewing;

  /// No description provided for @deleteComment.
  ///
  /// In en, this message translates to:
  /// **'Delete comment'**
  String get deleteComment;

  /// No description provided for @developerAccessRequired.
  ///
  /// In en, this message translates to:
  /// **'Developer access required.'**
  String get developerAccessRequired;

  /// No description provided for @couldNotLoadModeration.
  ///
  /// In en, this message translates to:
  /// **'Could not load moderation reports: {error}'**
  String couldNotLoadModeration(String error);

  /// No description provided for @resolveBugQuestion.
  ///
  /// In en, this message translates to:
  /// **'Resolve this bug?'**
  String get resolveBugQuestion;

  /// No description provided for @resolveBugBody.
  ///
  /// In en, this message translates to:
  /// **'This will mark the bug as solved and remove it from the active Bugs queue.'**
  String get resolveBugBody;

  /// No description provided for @deleteReportedComment.
  ///
  /// In en, this message translates to:
  /// **'Delete reported comment?'**
  String get deleteReportedComment;

  /// No description provided for @deleteReportedCommentBody.
  ///
  /// In en, this message translates to:
  /// **'This permanently removes the comment.'**
  String get deleteReportedCommentBody;

  /// No description provided for @ignoreSuggestionQuestion.
  ///
  /// In en, this message translates to:
  /// **'Ignore suggestion?'**
  String get ignoreSuggestionQuestion;

  /// No description provided for @ignoreSuggestionBody.
  ///
  /// In en, this message translates to:
  /// **'This suggestion will not appear on the Feature Board and will be permanently deleted. The user’s 30-day submission cooldown stays active.'**
  String get ignoreSuggestionBody;

  /// No description provided for @publishAs.
  ///
  /// In en, this message translates to:
  /// **'Publish as {status}'**
  String publishAs(String status);

  /// No description provided for @optionalDeveloperNote.
  ///
  /// In en, this message translates to:
  /// **'You can add an optional developer note. It will appear publicly on the Feature Board.'**
  String get optionalDeveloperNote;

  /// No description provided for @optionalChipluxUpdate.
  ///
  /// In en, this message translates to:
  /// **'Optional Chiplux update…'**
  String get optionalChipluxUpdate;

  /// No description provided for @rejectionReasonHint.
  ///
  /// In en, this message translates to:
  /// **'Why is this suggestion being rejected?'**
  String get rejectionReasonHint;

  /// No description provided for @couldNotUpdateSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Could not update feature suggestion: {error}'**
  String couldNotUpdateSuggestion(String error);

  /// No description provided for @couldNotIgnoreSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Could not ignore feature suggestion: {error}'**
  String couldNotIgnoreSuggestion(String error);

  /// No description provided for @featureBoard.
  ///
  /// In en, this message translates to:
  /// **'Feature Board'**
  String get featureBoard;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @suggestedByUser.
  ///
  /// In en, this message translates to:
  /// **'Suggested by {user}'**
  String suggestedByUser(String user);

  /// No description provided for @suggestedByCommunity.
  ///
  /// In en, this message translates to:
  /// **'Suggested by a Chiplux user'**
  String get suggestedByCommunity;

  /// No description provided for @developerUpdate.
  ///
  /// In en, this message translates to:
  /// **'CHIPLUX UPDATE'**
  String get developerUpdate;

  /// No description provided for @noFeatureSuggestions.
  ///
  /// In en, this message translates to:
  /// **'No feature suggestions here yet.'**
  String get noFeatureSuggestions;

  /// No description provided for @languageMediaRule.
  ///
  /// In en, this message translates to:
  /// **'Movies, TV shows, episode titles and future music titles remain in their original form.'**
  String get languageMediaRule;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hr':
      return AppLocalizationsHr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
