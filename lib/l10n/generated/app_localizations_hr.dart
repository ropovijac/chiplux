// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Croatian (`hr`).
class AppLocalizationsHr extends AppLocalizations {
  AppLocalizationsHr([String locale = 'hr']) : super(locale);

  @override
  String get appName => 'Chiplux';

  @override
  String get discover => 'Otkrivaj';

  @override
  String get search => 'Pretraži';

  @override
  String get watch => 'Gledaj';

  @override
  String get community => 'Zajednica';

  @override
  String get profile => 'Profil';

  @override
  String get customize => 'PRILAGODI';

  @override
  String get settings => 'POSTAVKE';

  @override
  String get help => 'POMOĆ';

  @override
  String get account => 'Račun';

  @override
  String get accountSubtitle => 'Podaci o vašem Chiplux računu i prijavi.';

  @override
  String get email => 'E-pošta';

  @override
  String get notAvailable => 'Nije dostupno';

  @override
  String get changePassword => 'Promijeni lozinku';

  @override
  String get changePasswordSubtitle => 'Ažurirajte lozinku računa';

  @override
  String get adminModeration => 'Administratorska moderacija';

  @override
  String get adminModerationSubtitle =>
      'Pregled prijava korisnika, komentara, grešaka i prijedloga';

  @override
  String get preferences => 'Postavke';

  @override
  String get preferencesSubtitle =>
      'Odaberite kako se Chiplux ponaša na ovom uređaju.';

  @override
  String get notifications => 'Obavijesti';

  @override
  String get notificationsSubtitle => 'Epizode, izdanja i aktivnost zajednice';

  @override
  String get privacy => 'Privatnost';

  @override
  String get privacySubtitle => 'Kontrole profila, aktivnosti i interakcija';

  @override
  String get dataExport => 'Podaci i izvoz';

  @override
  String get dataExportSubtitle =>
      'Izvezite svoje Chiplux podatke i zakažite sigurnosne kopije';

  @override
  String get language => 'Jezik';

  @override
  String get languageSubtitle => 'Odaberite jezik Chiplux sučelja.';

  @override
  String get systemDefault => 'Jezik uređaja';

  @override
  String get english => 'English';

  @override
  String get croatian => 'Hrvatski';

  @override
  String get languagePageSubtitle =>
      'Odaberite jezik izbornika, gumba i poruka u Chipluxu. Ova postavka nikada ne prevodi naslove sadržaja ni sadržaj korisnika.';

  @override
  String get languageChanged => 'Jezik je promijenjen.';

  @override
  String get signOut => 'Odjava';

  @override
  String get deleteAccount => 'Izbriši račun';

  @override
  String get helpSubtitle => 'Podrška, pravila i odgovori o Chipluxu.';

  @override
  String get faq => 'Česta pitanja';

  @override
  String get faqSubtitle => 'Česta pitanja o Chipluxu';

  @override
  String get contact => 'Kontakt';

  @override
  String get contactSubtitle => 'Kontaktni podaci i podrška';

  @override
  String get privacyPolicy => 'Pravila privatnosti';

  @override
  String get privacyPolicySubtitle => 'Kako Chiplux postupa s podacima';

  @override
  String get terms => 'Uvjeti';

  @override
  String get termsSubtitle => 'Uvjeti korištenja';

  @override
  String get suggestFeature => 'Predloži značajku';

  @override
  String get suggestFeatureSubtitle => 'Podijelite ideju s Chiplux developerom';

  @override
  String get reportBug => 'Prijavi grešku';

  @override
  String get reportBugSubtitle => 'Pošaljite problem izravno Chipluxu';

  @override
  String get informationSupport => 'Informacije i podrška za Chiplux.';

  @override
  String get commentsLockedEpisode =>
      'Komentari su zaključani dok ne pogledate ovu epizodu.';

  @override
  String get commentsLockedTitle =>
      'Komentari su zaključani dok ne dovršite ovaj naslov.';

  @override
  String get couldNotLoadComments => 'Nije moguće učitati komentare.';

  @override
  String get letsComment => 'Komentiraj';

  @override
  String get reply => 'Odgovori';

  @override
  String get replies => 'Odgovori';

  @override
  String get cancel => 'Odustani';

  @override
  String get delete => 'Izbriši';

  @override
  String get save => 'Spremi';

  @override
  String get edit => 'Uredi';

  @override
  String get report => 'Prijavi';

  @override
  String get block => 'Blokiraj';

  @override
  String get unblock => 'Odblokiraj';

  @override
  String get spoiler => 'Spojler';

  @override
  String get showSpoiler => 'Prikaži spojler';

  @override
  String get dataExportPageSubtitle =>
      'Sigurnosno kopirajte podatke Chiplux računa ili izradite izvoz kad god želite.';

  @override
  String get automaticBackup => 'Automatska sigurnosna kopija';

  @override
  String get automaticBackupDescription =>
      'Odaberite koliko često Chiplux treba izraditi lokalnu JSON sigurnosnu kopiju.';

  @override
  String get everyDay => 'Svaki dan';

  @override
  String get everyWeek => 'Svaki tjedan';

  @override
  String get everyMonth => 'Svaki mjesec';

  @override
  String get off => 'Isključeno';

  @override
  String get exportNow => 'Izvezi sada';

  @override
  String get exportNowSubtitle =>
      'Izradite JSON sigurnosnu kopiju i odaberite gdje je želite spremiti ili podijeliti.';

  @override
  String get automaticBackupInfo =>
      'Automatske sigurnosne kopije provjeravaju se kada se Chiplux otvori. Ako je interval prošao dok je aplikacija bila zatvorena, sigurnosna kopija izrađuje se pri sljedećem pokretanju.';

  @override
  String get exportIncludes =>
      'Izvoz uključuje postavke profila, biblioteku, pogledane epizode, ocjene, komentare, aktivnosti, popis praćenja, obavijesti, prijave, prijedloge značajki i popis blokiranih korisnika.';

  @override
  String couldNotExportData(String error) {
    return 'Nije moguće izvesti podatke: $error';
  }

  @override
  String whileChipluxUsed(String cadence) {
    return '$cadence dok se Chiplux koristi';
  }

  @override
  String get users => 'Korisnici';

  @override
  String get comments => 'Komentari';

  @override
  String get bugs => 'Greške';

  @override
  String get suggestions => 'Prijedlozi';

  @override
  String get pending => 'Na čekanju';

  @override
  String get inProgress => 'U izradi';

  @override
  String get implemented => 'Implementirano';

  @override
  String get rejected => 'Odbijeno';

  @override
  String get ignored => 'Ignorirano';

  @override
  String get resolve => 'Riješi';

  @override
  String get dismiss => 'Odbaci';

  @override
  String get reviewing => 'U pregledu';

  @override
  String get deleteComment => 'Izbriši komentar';

  @override
  String get developerAccessRequired => 'Potreban je developerski pristup.';

  @override
  String couldNotLoadModeration(String error) {
    return 'Nije moguće učitati prijave za moderaciju: $error';
  }

  @override
  String get resolveBugQuestion => 'Označiti grešku riješenom?';

  @override
  String get resolveBugBody =>
      'Greška će biti označena kao riješena i uklonjena iz aktivnog popisa grešaka.';

  @override
  String get deleteReportedComment => 'Izbrisati prijavljeni komentar?';

  @override
  String get deleteReportedCommentBody => 'Ovo trajno uklanja komentar.';

  @override
  String get ignoreSuggestionQuestion => 'Ignorirati prijedlog?';

  @override
  String get ignoreSuggestionBody =>
      'Prijedlog se neće pojaviti na Ploči prijedloga i bit će trajno izbrisan. Korisnikovo ograničenje od 30 dana ostaje aktivno.';

  @override
  String publishAs(String status) {
    return 'Objavi kao: $status';
  }

  @override
  String get optionalDeveloperNote =>
      'Možete dodati neobaveznu poruku developera. Bit će javno prikazana na Ploči prijedloga.';

  @override
  String get optionalChipluxUpdate => 'Neobavezna Chiplux objava…';

  @override
  String get rejectionReasonHint => 'Zašto je ovaj prijedlog odbijen?';

  @override
  String couldNotUpdateSuggestion(String error) {
    return 'Nije moguće ažurirati prijedlog značajke: $error';
  }

  @override
  String couldNotIgnoreSuggestion(String error) {
    return 'Nije moguće ignorirati prijedlog značajke: $error';
  }

  @override
  String get featureBoard => 'Ploča prijedloga';

  @override
  String get all => 'Sve';

  @override
  String suggestedByUser(String user) {
    return 'Predložio/la $user';
  }

  @override
  String get suggestedByCommunity => 'Predložio korisnik Chipluxa';

  @override
  String get developerUpdate => 'CHIPLUX NOVOST';

  @override
  String get noFeatureSuggestions => 'Ovdje još nema prijedloga značajki.';

  @override
  String get languageMediaRule =>
      'Filmovi, serije, nazivi epizoda i budući nazivi glazbe ostaju u izvornom obliku.';
}
