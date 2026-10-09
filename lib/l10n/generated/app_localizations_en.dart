// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Chiplux';

  @override
  String get discover => 'Discover';

  @override
  String get search => 'Search';

  @override
  String get watch => 'Watch';

  @override
  String get community => 'Community';

  @override
  String get profile => 'Profile';

  @override
  String get customize => 'CUSTOMIZE';

  @override
  String get settings => 'SETTINGS';

  @override
  String get help => 'HELP';

  @override
  String get account => 'Account';

  @override
  String get accountSubtitle => 'Your Chiplux account and sign-in information.';

  @override
  String get email => 'Email';

  @override
  String get notAvailable => 'Not available';

  @override
  String get changePassword => 'Change Password';

  @override
  String get changePasswordSubtitle => 'Update your account password';

  @override
  String get adminModeration => 'Admin Moderation';

  @override
  String get adminModerationSubtitle =>
      'Review user, comment, bug and feature reports';

  @override
  String get preferences => 'Preferences';

  @override
  String get preferencesSubtitle =>
      'Choose how Chiplux behaves on this device.';

  @override
  String get notifications => 'Notifications';

  @override
  String get notificationsSubtitle =>
      'Episodes, releases and community activity';

  @override
  String get privacy => 'Privacy';

  @override
  String get privacySubtitle => 'Profile, activity and interaction controls';

  @override
  String get dataExport => 'Data & Export';

  @override
  String get dataExportSubtitle =>
      'Export your Chiplux data and schedule backups';

  @override
  String get language => 'Language';

  @override
  String get languageSubtitle =>
      'Choose the language used by the Chiplux interface.';

  @override
  String get systemDefault => 'System default';

  @override
  String get english => 'English';

  @override
  String get croatian => 'Hrvatski';

  @override
  String get languagePageSubtitle =>
      'Choose the language for Chiplux menus, buttons and messages. Media titles and user content are never translated by this setting.';

  @override
  String get languageChanged => 'Language changed.';

  @override
  String get signOut => 'Sign Out';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get helpSubtitle => 'Support, policies and answers about Chiplux.';

  @override
  String get faq => 'FAQ';

  @override
  String get faqSubtitle => 'Common Chiplux questions';

  @override
  String get contact => 'Contact';

  @override
  String get contactSubtitle => 'Contact details and support';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get privacyPolicySubtitle => 'How Chiplux handles data';

  @override
  String get terms => 'Terms';

  @override
  String get termsSubtitle => 'Terms of use';

  @override
  String get suggestFeature => 'Suggest a Feature';

  @override
  String get suggestFeatureSubtitle =>
      'Share an idea with the Chiplux developer';

  @override
  String get reportBug => 'Report a Bug';

  @override
  String get reportBugSubtitle => 'Send a problem directly to Chiplux';

  @override
  String get informationSupport => 'Information and support for Chiplux.';

  @override
  String get commentsLockedEpisode =>
      'Comments are locked until you watch this episode.';

  @override
  String get commentsLockedTitle =>
      'Comments are locked until you finish this title.';

  @override
  String get couldNotLoadComments => 'Could not load comments.';

  @override
  String get letsComment => 'Let’s Comment';

  @override
  String get reply => 'Reply';

  @override
  String get replies => 'Replies';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get save => 'Save';

  @override
  String get edit => 'Edit';

  @override
  String get report => 'Report';

  @override
  String get block => 'Block';

  @override
  String get unblock => 'Unblock';

  @override
  String get spoiler => 'Spoiler';

  @override
  String get showSpoiler => 'Show spoiler';

  @override
  String get dataExportPageSubtitle =>
      'Back up your Chiplux account data or create an export whenever you want.';

  @override
  String get automaticBackup => 'Automatic backup';

  @override
  String get automaticBackupDescription =>
      'Choose how often Chiplux should create a local JSON backup.';

  @override
  String get everyDay => 'Every day';

  @override
  String get everyWeek => 'Every week';

  @override
  String get everyMonth => 'Every month';

  @override
  String get off => 'Off';

  @override
  String get exportNow => 'Export now';

  @override
  String get exportNowSubtitle =>
      'Create a JSON backup and choose where to save or share it.';

  @override
  String get automaticBackupInfo =>
      'Automatic backups are checked when Chiplux opens. If an interval passed while the app was closed, the backup is created the next time the app starts.';

  @override
  String get exportIncludes =>
      'Exports include your profile settings, library, watched episodes, ratings, comments, activity, following list, notifications, reports, feature suggestions and blocked-user list.';

  @override
  String couldNotExportData(String error) {
    return 'Could not export data: $error';
  }

  @override
  String whileChipluxUsed(String cadence) {
    return '$cadence while Chiplux is being used';
  }

  @override
  String get users => 'Users';

  @override
  String get comments => 'Comments';

  @override
  String get bugs => 'Bugs';

  @override
  String get suggestions => 'Suggestions';

  @override
  String get pending => 'Pending';

  @override
  String get inProgress => 'In Progress';

  @override
  String get implemented => 'Implemented';

  @override
  String get rejected => 'Rejected';

  @override
  String get ignored => 'Ignored';

  @override
  String get resolve => 'Resolve';

  @override
  String get dismiss => 'Dismiss';

  @override
  String get reviewing => 'Reviewing';

  @override
  String get deleteComment => 'Delete comment';

  @override
  String get developerAccessRequired => 'Developer access required.';

  @override
  String couldNotLoadModeration(String error) {
    return 'Could not load moderation reports: $error';
  }

  @override
  String get resolveBugQuestion => 'Resolve this bug?';

  @override
  String get resolveBugBody =>
      'This will mark the bug as solved and remove it from the active Bugs queue.';

  @override
  String get deleteReportedComment => 'Delete reported comment?';

  @override
  String get deleteReportedCommentBody =>
      'This permanently removes the comment.';

  @override
  String get ignoreSuggestionQuestion => 'Ignore suggestion?';

  @override
  String get ignoreSuggestionBody =>
      'This suggestion will not appear on the Feature Board and will be permanently deleted. The user’s 30-day submission cooldown stays active.';

  @override
  String publishAs(String status) {
    return 'Publish as $status';
  }

  @override
  String get optionalDeveloperNote =>
      'You can add an optional developer note. It will appear publicly on the Feature Board.';

  @override
  String get optionalChipluxUpdate => 'Optional Chiplux update…';

  @override
  String get rejectionReasonHint => 'Why is this suggestion being rejected?';

  @override
  String couldNotUpdateSuggestion(String error) {
    return 'Could not update feature suggestion: $error';
  }

  @override
  String couldNotIgnoreSuggestion(String error) {
    return 'Could not ignore feature suggestion: $error';
  }

  @override
  String get featureBoard => 'Feature Board';

  @override
  String get all => 'All';

  @override
  String suggestedByUser(String user) {
    return 'Suggested by $user';
  }

  @override
  String get suggestedByCommunity => 'Suggested by a Chiplux user';

  @override
  String get developerUpdate => 'CHIPLUX UPDATE';

  @override
  String get noFeatureSuggestions => 'No feature suggestions here yet.';

  @override
  String get languageMediaRule =>
      'Movies, TV shows, episode titles and future music titles remain in their original form.';
}
