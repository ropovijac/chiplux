import 'package:flutter/material.dart';

/// Lightweight localization bridge for legacy Chiplux UI strings.
///
/// Existing AppLocalizations entries remain in use. This helper covers older
/// hard-coded interface copy while keeping media titles, episode names,
/// usernames, display names and user-authored content untouched unless the
/// caller explicitly routes a known UI string through [trUi].
String trUi(BuildContext context, String value) {
  if (Localizations.localeOf(context).languageCode != 'hr') {
    return value;
  }

  final exact = _hrExact[value];
  if (exact != null) {
    return exact;
  }

  final folded = _hrFolded[value.toLowerCase()];
  if (folded != null) {
    final hasLetters = value.toUpperCase() != value.toLowerCase();
    if (hasLetters && value == value.toUpperCase()) {
      return folded.toUpperCase();
    }
    return folded;
  }

  return _translateCroatianPattern(value);
}

class UiText extends StatelessWidget {
  const UiText(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    return Text(
      trUi(context, data),
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

String _translateCroatianPattern(String value) {
  RegExpMatch? match;

  match = RegExp(r'^Watch (\d+) movies$').firstMatch(value);
  if (match != null) return 'Pogledaj ${match.group(1)} filmova';

  match = RegExp(r'^Complete (\d+) TV shows$').firstMatch(value);
  if (match != null) return 'Dovrši ${match.group(1)} serija';

  match = RegExp(r'^Watch (\d+) episodes$').firstMatch(value);
  if (match != null) return 'Pogledaj ${match.group(1)} epizoda';

  match = RegExp(r'^Rate (\d+) episodes$').firstMatch(value);
  if (match != null) return 'Ocijeni ${match.group(1)} epizoda';

  match = RegExp(r'^Rate (\d+) TV shows$').firstMatch(value);
  if (match != null) return 'Ocijeni ${match.group(1)} serija';

  match = RegExp(r'^Rate (\d+) movies$').firstMatch(value);
  if (match != null) return 'Ocijeni ${match.group(1)} filmova';

  match = RegExp(r'^Reach Runtime Level (\d+)$').firstMatch(value);
  if (match != null) return 'Dosegni razinu gledanja ${match.group(1)}';

  match = RegExp(r'^Reach Ratings Level (\d+)$').firstMatch(value);
  if (match != null) return 'Dosegni razinu ocjenjivanja ${match.group(1)}';

  match = RegExp(r'^Log in on (\d+) different days$').firstMatch(value);
  if (match != null)
    {return 'Prijavi se tijekom ${match.group(1)} različitih dana';}

  match = RegExp(r'^Unlock (\d+) achievement milestones$').firstMatch(value);
  if (match != null)
    {return 'Otključaj ${match.group(1)} prekretnica postignuća';}

  match = RegExp(r'^Have (\d+) followers$').firstMatch(value);
  if (match != null) return 'Imati ${match.group(1)} pratitelja';

  match = RegExp(r'^View (\d+) public profiles$').firstMatch(value);
  if (match != null) return 'Pregledaj ${match.group(1)} javnih profila';

  match = RegExp(r'^Show all (\d+) genres$').firstMatch(value);
  if (match != null) return 'Prikaži svih ${match.group(1)} žanrova';

  match = RegExp(r'^(\d+) ratings$').firstMatch(value);
  if (match != null) return '${match.group(1)} ocjena';

  match = RegExp(r'^(\d+) rating$').firstMatch(value);
  if (match != null) return '${match.group(1)} ocjena';

  match = RegExp(r'^Chiplux average · (\d+) ratings$').firstMatch(value);
  if (match != null) return 'Chiplux prosjek · ${match.group(1)} ocjena';

  if (value == 'Chiplux average · 1 rating')
    {return 'Chiplux prosjek · 1 ocjena';}

  match = RegExp(r'^(\d+) comments$').firstMatch(value);
  if (match != null) return '${match.group(1)} komentara';

  match = RegExp(r'^(\d+) completed$').firstMatch(value);
  if (match != null) return '${match.group(1)} dovršeno';

  match = RegExp(r'^(\d+) watched$').firstMatch(value);
  if (match != null) return '${match.group(1)} pogledano';

  match = RegExp(r'^(\d+) / (\d+) episodes$').firstMatch(value);
  if (match != null) return '${match.group(1)} / ${match.group(2)} epizoda';

  match = RegExp(r'^(\d+) (Season|Seasons)$').firstMatch(value);
  if (match != null) return '${match.group(1)} sezona';

  match = RegExp(r"^(.+)'s TV Shows$").firstMatch(value);
  if (match != null) return 'Serije korisnika ${match.group(1)}';

  match = RegExp(r"^(.+)'s Movies$").firstMatch(value);
  if (match != null) return 'Filmovi korisnika ${match.group(1)}';

  match = RegExp(r'^(.+) has no completed TV shows yet\.$').firstMatch(value);
  if (match != null)
    {return 'Korisnik ${match.group(1)} još nema dovršenih serija.';}

  match = RegExp(r'^(.+) has no watched movies yet\.$').firstMatch(value);
  if (match != null)
    {return 'Korisnik ${match.group(1)} još nema pogledanih filmova.';}

  match = RegExp(r'^(.+) has no followers yet\.$').firstMatch(value);
  if (match != null) return 'Korisnik ${match.group(1)} još nema pratitelja.';

  match = RegExp(r"^Viewing (.+)'s achievements$").firstMatch(value);
  if (match != null) return 'Pregled postignuća korisnika ${match.group(1)}';

  match = RegExp(r"^(.+)'s Achievements$").firstMatch(value);
  if (match != null) return 'Postignuća korisnika ${match.group(1)}';

  match = RegExp(r'^Season (\d+)$').firstMatch(value);
  if (match != null) return 'Sezona ${match.group(1)}';

  match = RegExp(r'^Age (\d+)$').firstMatch(value);
  if (match != null) return 'Dob ${match.group(1)}';

  match = RegExp(r'^Turns (\d+) today 🎂$').firstMatch(value);
  if (match != null) return 'Danas puni ${match.group(1)} 🎂';

  match = RegExp(r'^Born (\d+)$').firstMatch(value);
  if (match != null) return 'Rođen/a ${match.group(1)}';

  match = RegExp(r'^Popularity (.+)$').firstMatch(value);
  if (match != null) return 'Popularnost ${match.group(1)}';

  match = RegExp(r'^(\d+) / (\d+) unlocked$').firstMatch(value);
  if (match != null) return '${match.group(1)} / ${match.group(2)} otključano';

  match = RegExp(r'^(\d+) UNREAD$').firstMatch(value);
  if (match != null) return '${match.group(1)} NEPROČITANO';

  match = RegExp(r'^(\d+) XP left$').firstMatch(value);
  if (match != null) return 'Preostalo ${match.group(1)} XP';

  match = RegExp(r'^to Level (\d+)$').firstMatch(value);
  if (match != null) return 'do razine ${match.group(1)}';

  match = RegExp(r'^Next: (\d+)$').firstMatch(value);
  if (match != null) return 'Sljedeće: ${match.group(1)}';

  match = RegExp(r'^Available (.+)$').firstMatch(value);
  if (match != null) return 'Dostupno ${match.group(1)}';

  match = RegExp(r'^Next suggestion: (.+)$').firstMatch(value);
  if (match != null) return 'Sljedeći prijedlog: ${match.group(1)}';

  match = RegExp(r'^Effective (.+)$').firstMatch(value);
  if (match != null) return 'Na snazi od ${match.group(1)}';

  match = RegExp(r'^(\d+)m ago$').firstMatch(value);
  if (match != null) return 'prije ${match.group(1)} min';

  match = RegExp(r'^(\d+)h ago$').firstMatch(value);
  if (match != null) return 'prije ${match.group(1)} h';

  match = RegExp(r'^(\d+)d ago$').firstMatch(value);
  if (match != null) return 'prije ${match.group(1)} d';

  match = RegExp(r'^(\d+) minute$').firstMatch(value);
  if (match != null) return '${match.group(1)} min';

  match = RegExp(r'^(\d+) minutes$').firstMatch(value);
  if (match != null) return '${match.group(1)} min';

  match = RegExp(r'^(\d+) month$').firstMatch(value);
  if (match != null) return '${match.group(1)} mj.';

  match = RegExp(r'^(\d+) months$').firstMatch(value);
  if (match != null) return '${match.group(1)} mj.';

  match = RegExp(r'^(\d+) months? (\d+)d$').firstMatch(value);
  if (match != null) return '${match.group(1)} mj. ${match.group(2)} d';

  match = RegExp(r'^(\d+) year$').firstMatch(value);
  if (match != null) return '${match.group(1)} g.';

  match = RegExp(r'^(\d+) years$').firstMatch(value);
  if (match != null) return '${match.group(1)} g.';

  match = RegExp(r'^(\d+) years? (\d+) months?$').firstMatch(value);
  if (match != null) return '${match.group(1)} g. ${match.group(2)} mj.';

  match = RegExp(r'^View (\d+) replies$').firstMatch(value);
  if (match != null) return 'Prikaži ${match.group(1)} odgovora';

  match = RegExp(r'^View (\d+) reply$').firstMatch(value);
  if (match != null) return 'Prikaži ${match.group(1)} odgovor';

  match = RegExp(r'^Replying to (.+)$').firstMatch(value);
  if (match != null) return 'Odgovaraš korisniku ${match.group(1)}';

  match = RegExp(r'^As (.+)$').firstMatch(value);
  if (match != null) return 'Kao ${match.group(1)}';

  match = RegExp(r'^as (.+)$').firstMatch(value);
  if (match != null) return 'kao ${match.group(1)}';

  match = RegExp(r'^watched (S\d+E\d+) of$').firstMatch(value);
  if (match != null) return 'pogledao/la je ${match.group(1)} serije';

  match = RegExp(r'^rated (S\d+E\d+) of$').firstMatch(value);
  if (match != null) return 'ocijenio/la je ${match.group(1)} serije';

  match = RegExp(r'^watched Season (\d+) of$').firstMatch(value);
  if (match != null) return 'pogledao/la je sezonu ${match.group(1)} serije';

  match = RegExp(r'^S(\d+)E(\d+) marked watched$').firstMatch(value);
  if (match != null)
    {return 'S${match.group(1)}E${match.group(2)} označeno kao pogledano';}

  match = RegExp(r'^(\d+) / (\d+) watched$').firstMatch(value);
  if (match != null) return '${match.group(1)} / ${match.group(2)} pogledano';

  match = RegExp(
    r'^No (in progress|implemented|rejected|pending) suggestions\.$',
    caseSensitive: false,
  ).firstMatch(value);
  if (match != null) {
    final status = switch (match.group(1)!.toLowerCase()) {
      'in progress' => 'u izradi',
      'implemented' => 'implementiranih',
      'rejected' => 'odbijenih',
      'pending' => 'na čekanju',
      _ => match.group(1)!,
    };
    return 'Nema prijedloga $status.';
  }

  match = RegExp(r'^Publish as (.+)$').firstMatch(value);
  if (match != null) {
    return 'Objavi kao ${_hrExact[match.group(1)] ?? _hrFolded[match.group(1)!.toLowerCase()] ?? match.group(1)}';
  }

  const errorPrefixes = <String, String>{
    'Could not update like: ': 'Nije moguće ažurirati sviđanje: ',
    'Could not update report: ': 'Nije moguće ažurirati prijavu: ',
    'Could not update feature suggestion: ':
        'Nije moguće ažurirati prijedlog značajke: ',
    'Could not ignore suggestion: ': 'Nije moguće zanemariti prijedlog: ',
    'Could not publish update: ': 'Nije moguće objaviti novost: ',
    'Could not save rating: ': 'Nije moguće spremiti ocjenu: ',
    'Could not remove rating: ': 'Nije moguće ukloniti ocjenu: ',
    'Could not update favorite: ': 'Nije moguće ažurirati omiljeno: ',
    'Could not save: ': 'Nije moguće spremiti: ',
    'Could not send bug report: ': 'Nije moguće poslati prijavu greške: ',
    'Could not save change: ': 'Nije moguće spremiti promjenu: ',
    'Could not save profile: ': 'Nije moguće spremiti profil: ',
    'Could not select image: ': 'Nije moguće odabrati sliku: ',
    'Could not export data: ': 'Nije moguće izvesti podatke: ',
    'TMDB request failed: ': 'TMDB zahtjev nije uspio: ',
  };

  for (final entry in errorPrefixes.entries) {
    if (value.startsWith(entry.key)) {
      return '${entry.value}${value.substring(entry.key.length)}';
    }
  }

  return value;
}

const Map<String, String> _hrExact = {
  "1 comment": "1 komentar",
  "1. About this policy": "1. O ovim pravilima privatnosti",
  "1. Acceptance": "1. Prihvaćanje uvjeta",
  "10. Changes to these terms": "10. Promjene ovih uvjeta",
  "10. Children": "10. Djeca",
  "100 Lists": "Top 100 liste",
  "11. Changes to this policy": "11. Promjene ovih pravila",
  "11. Governing law": "11. Mjerodavno pravo",
  "12. Contact": "12. Kontakt",
  "2. Information we collect": "2. Podaci koje prikupljamo",
  "2. Your account": "2. Tvoj račun",
  "3. Acceptable use": "3. Prihvatljivo korištenje",
  "3. How we use information": "3. Kako koristimo podatke",
  "30 DAYS": "30 DANA",
  "4. Service providers and third-party data":
      "4. Pružatelji usluga i podaci trećih strana",
  "4. Your content": "4. Tvoj sadržaj",
  "5. Community content": "5. Sadržaj zajednice",
  "5. Moderation and reports": "5. Moderacija i prijave",
  "6. Movie and TV information": "6. Podaci o filmovima i serijama",
  "6. Your controls and choices": "6. Tvoje kontrole i izbori",
  "7. Retention and deletion": "7. Čuvanje i brisanje podataka",
  "7. Service availability": "7. Dostupnost usluge",
  "8. Account suspension and termination": "8. Suspenzija i ukidanje računa",
  "8. European privacy rights": "8. Europska prava na privatnost",
  "9. Disclaimers and liability": "9. Odricanje od odgovornosti",
  "9. Security": "9. Sigurnost",
  "ACHIEVEMENT": "POSTIGNUĆE",
  "ACHIEVEMENT UNLOCKED": "POSTIGNUĆE OTKLJUČANO",
  "ACTION HERO": "AKCIJSKI JUNAK",
  "ACTIVITY": "AKTIVNOST",
  "ADMIRER": "OBOŽAVATELJ",
  "ADVENTURER": "AVANTURIST",
  "ALL CAUGHT UP": "SVE JE PROČITANO",
  "ARCHIVIST": "ARHIVIST",
  "Account": "Račun",
  "Account created. Check your email and confirm your account, then sign in.":
      "Račun je izrađen. Provjeri e-poštu, potvrdi račun i zatim se prijavi.",
  "Account information may include your email address, account identifier and authentication information handled through our authentication provider. Profile information may include your username, display name, avatar, banner and profile settings.\n\nUsage information may include your library, watched movies and episodes, ratings, reviews, favorites, achievements, comments, likes, follows, blocks, feature suggestions and notification preferences. If you submit a bug, moderation report or feature suggestion, we store the information you provide with that submission.\n\nFor push notifications, Chiplux may store a device registration token associated with your account. Service providers may also process technical information such as device, network, diagnostic and security data as necessary to provide their services.": "Podaci o računu mogu uključivati tvoju adresu e-pošte, identifikator računa i podatke za autentifikaciju kojima upravlja naš pružatelj autentifikacije. Podaci profila mogu uključivati korisničko ime, prikazano ime, avatar, banner i postavke profila.\n\nPodaci o korištenju mogu uključivati tvoju biblioteku, pogledane filmove i epizode, ocjene, recenzije, omiljeno, postignuća, komentare, sviđanja, praćenja, blokiranja, prijedloge značajki i postavke obavijesti. Ako pošalješ prijavu greške, moderacijsku prijavu ili prijedlog značajke, pohranjujemo podatke koje navedeš u toj prijavi.\n\nZa push obavijesti Chiplux može pohraniti registracijski token uređaja povezan s tvojim računom. Pružatelji usluga također mogu obrađivati tehničke podatke poput podataka o uređaju, mreži, dijagnostici i sigurnosti kada je to potrebno za pružanje njihovih usluga.",
  "Achievement Button": "Gumb postignuća",
  "Achievement requirement": "Uvjet postignuća",
  "Achievement unlocked": "Postignuće otključano",
  "Achievements": "Postignuća",
  "Achievements track your Chiplux progress and unlock profile cosmetics such as frames, colors and titles.": "Postignuća prate tvoj napredak u Chipluxu i otključavaju ukrase profila poput okvira, boja i titula.",
  "Acting": "Gluma",
  "Action": "Akcija",
  "Action & Adventure": "Akcija i avantura",
  "Activity from you and people you follow will appear here.":
      "Ovdje će se prikazivati aktivnosti tebe i osoba koje pratiš.",
  "Actor": "Glumac",
  "Actors, directors and producers": "Glumci, redatelji i producenti",
  "Add Chiplux update": "Dodaj Chiplux novost",
  "Add Comment": "Dodaj komentar",
  "Add Developer Update": "Dodaj novost developera",
  "Add comment": "Dodaj komentar",
  "Add to Favorites": "Dodaj u omiljeno",
  "Add to favorites": "Dodaj u omiljeno",
  "Admin Moderation": "Administratorska moderacija",
  "Adventure": "Avantura",
  "Airing Today": "Emitira se danas",
  "All": "Sve",
  "Allow achievement unlocks to appear in Friends Watch.":
      "Dopusti prikaz otključanih postignuća u aktivnosti prijatelja.",
  "Allow other users to find you in Find Friends.":
      "Dopusti drugim korisnicima da te pronađu u Pronađi prijatelje.",
  "Allow other users to open your social connections.":
      "Dopusti drugim korisnicima da otvore tvoje društvene veze.",
  "Allow other users to see your genre runtime.":
      "Dopusti drugim korisnicima da vide tvoje vrijeme gledanja po žanru.",
  "Allow ratings to appear in Friends Watch.":
      "Dopusti prikaz ocjena u aktivnosti prijatelja.",
  "Allow replies to my comments": "Dopusti odgovore na moje komentare",
  "Already have an account? Sign In": "Već imaš račun? Prijavi se",
  "Android / iOS / Windows": "Android / iOS / Windows",
  "Animation": "Animacija",
  "Any Chiplux user can follow you.":
      "Bilo koji Chiplux korisnik može te pratiti.",
  "Anyone can see your full profile.":
      "Svatko može vidjeti tvoj cijeli profil.",
  "Appear in user search": "Prikaži me u pretrazi korisnika",
  "Automatic backup": "Automatska sigurnosna kopija",
  "Automatic backups are checked when Chiplux opens. If an interval passed while the app was closed, the backup is created the next time the app starts.": "Automatske sigurnosne kopije provjeravaju se kada se Chiplux otvori. Ako je interval prošao dok je aplikacija bila zatvorena, sigurnosna kopija izrađuje se pri sljedećem pokretanju.",
  "Avatar Frame": "Okvir avatara",
  "Average": "Prosjek",
  "BALANCED CRITIC": "URAVNOTEŽENI KRITIČAR",
  "BUG REPORT": "PRIJAVA GREŠKE",
  "Back up your Chiplux account data or create an export whenever you want.": "Sigurnosno kopiraj podatke Chiplux računa ili izradi izvoz kad god želiš.",
  "Backdrops from movies and TV shows you completed.":
      "Pozadine iz filmova i serija koje si dovršio/la.",
  "Be the first to start the discussion.":
      "Budi prvi/a koji će započeti raspravu.",
  "Binge Critic": "Maratonski kritičar",
  "Binge Watcher": "Maratonski gledatelj",
  "Block": "Blokiraj",
  "Block user": "Blokiraj korisnika",
  "Block user?": "Blokirati korisnika?",
  "Blocked users": "Blokirani korisnici",
  "Bug report sent. Thank you.": "Prijava greške je poslana. Hvala.",
  "Bugs": "Greške",
  "By creating an account or using Chiplux, you agree to these Terms of Use. If you do not agree, do not use the service. If local law requires a parent or guardian to authorize your use, you may use Chiplux only with that authorization.": "Izradom računa ili korištenjem Chipluxa prihvaćaš ove Uvjete korištenja. Ako ih ne prihvaćaš, nemoj koristiti uslugu. Ako lokalni zakon zahtijeva odobrenje roditelja ili skrbnika za tvoje korištenje, Chiplux smiješ koristiti samo uz takvo odobrenje.",
  "CHIPLUX INBOX": "CHIPLUX SANDUČIĆ",
  "CHIPLUX UPDATE": "CHIPLUX NOVOST",
  "COMEDIAN": "KOMIČAR",
  "COMMENT REPORT": "PRIJAVA KOMENTARA",
  "COMMUNITY": "ZAJEDNICA",
  "COMMUNITY CONTRIBUTIONS": "DOPRINOSI ZAJEDNICI",
  "COMPLETE": "DOVRŠENO",
  "CONVERSATIONALIST": "RAZGOVARAČ",
  "CRITIC LEVEL": "RAZINA KRITIČARA",
  "CURRENT PASSWORD": "TRENUTNA LOZINKA",
  "CUSTOMIZE": "PRILAGODI",
  "Can I control what other users see?":
      "Mogu li odrediti što drugi korisnici vide?",
  "Can I export my Chiplux data?": "Mogu li izvesti svoje Chiplux podatke?",
  "Cancel": "Odustani",
  "Canceled": "Otkazano",
  "Change Password": "Promijeni lozinku",
  "Channel Surfer": "Šaltač kanala",
  "Checking In": "Redovita prijava",
  "Checking username...": "Provjera korisničkog imena...",
  "Chiplux Icon": "Chiplux ikona",
  "Chiplux Influencer": "Chiplux influencer",
  "Chiplux Loyalist": "Chiplux veteran vjernosti",
  "Chiplux Updates": "Chiplux novosti",
  "Chiplux User": "Korisnik Chipluxa",
  "Chiplux Veteran": "Chiplux veteran",
  "Chiplux average · 1 rating": "Chiplux prosjek · 1 ocjena",
  "Chiplux contact details will be added before release.":
      "Kontaktni podaci Chipluxa bit će dodani prije objave.",
  "Chiplux data export": "Izvoz Chiplux podataka",
  "Chiplux is not intended to knowingly collect personal information from children who are below the minimum age permitted to use an online service without parental authorization under applicable law. If you believe a child has provided personal information unlawfully, contact Chiplux so the issue can be reviewed.": "Chiplux nije namijenjen svjesnom prikupljanju osobnih podataka djece koja su mlađa od minimalne dobi za samostalno korištenje internetske usluge prema primjenjivom zakonu. Ako smatraš da je dijete nezakonito dostavilo osobne podatke, kontaktiraj Chiplux kako bi se slučaj mogao provjeriti.",
  "Chiplux may review reports and may remove content, restrict features, suspend accounts or take other reasonable moderation action when content or behavior violates these Terms, applicable law or community safety rules. Moderation decisions may be made using automated signals and human review.": "Chiplux može pregledavati prijave te uklanjati sadržaj, ograničiti značajke, suspendirati račune ili poduzeti druge razumne moderacijske mjere kada sadržaj ili ponašanje krši ove Uvjete, primjenjivi zakon ili pravila sigurnosti zajednice. Odluke o moderaciji mogu se donositi uz pomoć automatiziranih signala i ljudskog pregleda.",
  "Chiplux provides controls for profile visibility, search visibility, activity visibility, statistics, follows, comment interactions, public feature-suggestion attribution, blocked users and notification categories. You can also use Data & Export to create a copy of supported account data and can request account deletion through the app.": "Chiplux nudi kontrole za vidljivost profila, vidljivost u pretraživanju, vidljivost aktivnosti, statistike, praćenja, interakcije s komentarima, javno pripisivanje prijedloga značajki, blokirane korisnike i kategorije obavijesti. Također možeš koristiti Podaci i izvoz za izradu kopije podržanih podataka računa i zatražiti brisanje računa kroz aplikaciju.",
  "Chiplux user": "Korisnik Chipluxa",
  "Chiplux uses service providers to operate the app. Supabase is used for services such as authentication, database, storage and server-side functions. Firebase Cloud Messaging is used to deliver push notifications. The Movie Database (TMDB) provides movie, TV and person metadata and images; searches and content requests may therefore be sent to TMDB.\n\nThese providers process information under their own terms and privacy practices. Chiplux does not sell your personal information.": "Chiplux za rad aplikacije koristi pružatelje usluga. Supabase se koristi za usluge poput autentifikacije, baze podataka, pohrane i funkcija na poslužitelju. Firebase Cloud Messaging koristi se za slanje push obavijesti. The Movie Database (TMDB) pruža metapodatke i slike filmova, serija i osoba; stoga se pretrage i zahtjevi za sadržajem mogu slati TMDB-u.\n\nTi pružatelji obrađuju podatke prema vlastitim uvjetima i pravilima privatnosti. Chiplux ne prodaje tvoje osobne podatke.",
  "Chiplux uses third-party movie, TV and person information, including data and images supplied through TMDB. Chiplux does not own that third-party content and cannot guarantee that all metadata, release dates, ratings or images are complete or error-free. This product uses the TMDB API but is not endorsed or certified by TMDB.": "Chiplux koristi podatke trećih strana o filmovima, serijama i osobama, uključujući podatke i slike dobivene putem TMDB-a. Chiplux nije vlasnik tog sadržaja trećih strana i ne može jamčiti da su svi metapodaci, datumi izlaska, ocjene ili slike potpuni ili bez pogrešaka. Ovaj proizvod koristi TMDB API, ali ga TMDB ne podržava niti certificira.",
  "Choose Banner": "Odaberi banner",
  "Choose a color unlocked through your Medal Collection achievements.":
      "Odaberi boju otključanu kroz postignuća Zbirke medalja.",
  "Choose a different password.": "Odaberi drugu lozinku.",
  "Choose a username.": "Odaberi korisničko ime.",
  "Choose an available username.": "Odaberi dostupno korisničko ime.",
  "Choose how Chiplux behaves on this device.":
      "Odaberite kako se Chiplux ponaša na ovom uređaju.",
  "Choose how often Chiplux should create a local JSON backup.": "Odaberi koliko često Chiplux treba izraditi lokalnu JSON sigurnosnu kopiju.",
  "Choose the frame surrounding your full profile page.":
      "Odaberi okvir koji okružuje cijelu stranicu profila.",
  "Choose the language for Chiplux menus, buttons and messages. Media titles and user content are never translated by this setting.": "Odaberite jezik izbornika, gumba i poruka u Chipluxu. Ova postavka nikada ne prevodi naslove sadržaja ni sadržaj korisnika.",
  "Choose the language used by the Chiplux interface.":
      "Odaberite jezik Chiplux sučelja.",
  "Choose the reason for this report.": "Odaberi razlog prijave.",
  "Choose the unlocked Followers style used for your follower counter border and icon.":
      "Odaberi otključani stil Pratitelja za okvir i ikonu brojača pratitelja.",
  "Choose the unlocked Medal Collection style used for your profile achievement button.":
      "Odaberi otključani stil Zbirke medalja za gumb postignuća na profilu.",
  "Choose which Chiplux notifications you want to receive.":
      "Odaberi koje Chiplux obavijesti želiš primati.",
  "Choose who can see the detailed contents of your profile.":
      "Odaberi tko može vidjeti detaljan sadržaj tvog profila.",
  "Choose who can see your full public profile.":
      "Odaberi tko može vidjeti tvoj cijeli javni profil.",
  "Choose your Episodes Rated achievement style.":
      "Odaberi stil postignuća Ocijenjene epizode.",
  "Choose your Episodes Watched achievement style.":
      "Odaberi stil postignuća Pogledane epizode.",
  "Choose your Movies Rated achievement style.":
      "Odaberi stil postignuća Ocijenjeni filmovi.",
  "Choose your Movies Watched achievement style.":
      "Odaberi stil postignuća Pogledani filmovi.",
  "Choose your Ratings Level achievement style.":
      "Odaberi stil postignuća Razine ocjenjivanja.",
  "Choose your Runtime Level achievement style.":
      "Odaberi stil postignuća Razine gledanja.",
  "Choose your TV Shows Rated achievement style.":
      "Odaberi stil postignuća Ocijenjene serije.",
  "Choose your TV Shows Watched achievement style.":
      "Odaberi stil postignuća Pogledane serije.",
  "Cinema Expert": "Filmski stručnjak",
  "Cinema Legend": "Filmska legenda",
  "Cinema Master": "Majstor filma",
  "Cinephile": "Cinefil",
  "Clear season": "Poništi sezonu",
  "Close": "Zatvori",
  "Collector": "Kolekcionar",
  "Comedy": "Komedija",
  "Comment": "Komentar",
  "Comment Likes": "Sviđanja komentara",
  "Comment cannot be empty.": "Komentar ne smije biti prazan.",
  "Comment is too long.": "Komentar je predugačak.",
  "Comment no longer exists.": "Komentar više ne postoji.",
  "Comment reported.": "Komentar je prijavljen.",
  "Comments": "Komentari",
  "Comments & Replies": "Komentari i odgovori",
  "Comments are locked until you finish this title.":
      "Komentari su zaključani dok ne dovršite ovaj naslov.",
  "Comments are locked until you watch this episode.":
      "Komentari su zaključani dok ne pogledate ovu epizodu.",
  "Comments, reviews, profile information and other content you choose to make public may be visible to other users according to your privacy settings. If a feature suggestion is published to the Feature Board, Chiplux may show your username and link to your profile when public suggestion attribution is enabled; otherwise the suggestion is shown without identifying you publicly. You should not post personal information that you do not want other people to see.": "Komentari, recenzije, podaci profila i drugi sadržaj koji odlučiš učiniti javnim mogu biti vidljivi drugim korisnicima prema tvojim postavkama privatnosti. Ako se prijedlog značajke objavi na Ploči prijedloga, Chiplux može prikazati tvoje korisničko ime i poveznicu na profil kada je uključeno javno pripisivanje prijedloga; u suprotnom se prijedlog prikazuje bez javnog otkrivanja tvog identiteta. Nemoj objavljivati osobne podatke koje ne želiš da drugi vide.",
  "Committed Regular": "Predani redoviti korisnik",
  "Common Chiplux questions": "Česta pitanja o Chipluxu",
  "Community": "Zajednica",
  "Community Explorer": "Istraživač zajednice",
  "Community Legend": "Legenda zajednice",
  "Community Scout": "Izviđač zajednice",
  "Community Veteran": "Veteran zajednice",
  "Community Voice": "Glas zajednice",
  "Complete TV shows to upgrade your TV Shows Watched stat border.": "Dovršavaj serije kako bi unaprijedio/la okvir statistike Pogledane serije.",
  "Complete a movie or TV show to unlock profile banners.":
      "Dovrši film ili seriju kako bi otključao/la bannere profila.",
  "Completed": "Dovršeno",
  "Confirm New Password": "Potvrdi novu lozinku",
  "Contact": "Kontakt",
  "Contact details and support": "Kontaktni podaci i podrška",
  "Content Rating": "Dobna oznaka",
  "Control who can find you, see your profile and interact with you.":
      "Odredi tko te može pronaći, vidjeti tvoj profil i komunicirati s tobom.",
  "Control who is allowed to start following you.":
      "Odredi tko te smije početi pratiti.",
  "Could not block user.": "Nije moguće blokirati korisnika.",
  "Could not change follow state.": "Nije moguće promijeniti stanje praćenja.",
  "Could not change password.": "Nije moguće promijeniti lozinku.",
  "Could not check username.": "Nije moguće provjeriti korisničko ime.",
  "Could not delete comment.": "Nije moguće izbrisati komentar.",
  "Could not delete notification.": "Nije moguće izbrisati obavijest.",
  "Could not find this episode.": "Nije moguće pronaći ovu epizodu.",
  "Could not find your account email.":
      "Nije moguće pronaći e-poštu tvog računa.",
  "Could not load comments.": "Nije moguće učitati komentare.",
  "Could not load details.": "Nije moguće učitati detalje.",
  "Could not load notifications.": "Nije moguće učitati obavijesti.",
  "Could not load projects.": "Nije moguće učitati projekte.",
  "Could not load the Feature Board.": "Nije moguće učitati Ploču prijedloga.",
  "Could not load this episode.": "Nije moguće učitati ovu epizodu.",
  "Could not load this list.": "Nije moguće učitati ovaj popis.",
  "Could not load today's picks.": "Nije moguće učitati današnje odabire.",
  "Could not load trending titles.": "Nije moguće učitati sadržaj u trendu.",
  "Could not open this discussion.": "Nije moguće otvoriti ovu raspravu.",
  "Could not open this episode.": "Nije moguće otvoriti ovu epizodu.",
  "Could not open this notification.": "Nije moguće otvoriti ovu obavijest.",
  "Could not open this profile.": "Nije moguće otvoriti ovaj profil.",
  "Could not open this title.": "Nije moguće otvoriti ovaj naslov.",
  "Could not remove rating.": "Nije moguće ukloniti ocjenu.",
  "Could not save rating.": "Nije moguće spremiti ocjenu.",
  "Could not save. Please try again.": "Nije moguće spremiti. Pokušaj ponovno.",
  "Could not submit report.": "Nije moguće poslati prijavu.",
  "Could not unblock user.": "Nije moguće odblokirati korisnika.",
  "Could not update favorite.": "Nije moguće ažurirati omiljeno.",
  "Could not update notification setting.":
      "Nije moguće ažurirati postavku obavijesti.",
  "Could not update privacy setting.":
      "Nije moguće ažurirati postavku privatnosti.",
  "Could not verify this account.": "Nije moguće potvrditi ovaj račun.",
  "Create Account": "Izradi račun",
  "Create Password": "Izradi lozinku",
  "Create a JSON backup and choose where to save or share it.": "Izradi JSON sigurnosnu kopiju i odaberi gdje je želiš spremiti ili podijeliti.",
  "Credit me if published": "Navedi me kao autora ako se objavi",
  "Crime": "Kriminalistički",
  "Critic Legend": "Legenda kritike",
  "Critical Authority": "Autoritet kritike",
  "Critical Veteran": "Veteran kritike",
  "Crowd Favorite": "Miljenik publike",
  "Current Password": "Trenutna lozinka",
  "Current password is incorrect.": "Trenutačna lozinka nije točna.",
  "DEVELOPER": "PROGRAMER",
  "DRAMATIST": "DRAMATIČAR",
  "DREAMWEAVER": "TKALAC SNOVA",
  "Daily Logins": "Dnevne prijave",
  "Data & Export": "Podaci i izvoz",
  "Dedicated Viewer": "Predani gledatelj",
  "Default": "Zadano",
  "Delete": "Izbriši",
  "Delete Chiplux account?": "Izbrisati Chiplux račun?",
  "Delete account": "Izbriši račun",
  "Delete comment": "Izbriši komentar",
  "Delete comment?": "Izbrisati komentar?",
  "Delete reported comment?": "Izbrisati prijavljeni komentar?",
  "Deleted user": "Izbrisani korisnik",
  "Describe the problem...": "Opiši problem...",
  "Describe what happened, what you expected and what you were doing just before the problem appeared.": "Opiši što se dogodilo, što si očekivao/la i što si radio/la neposredno prije pojave problema.",
  "Describe your idea": "Opiši svoju ideju",
  "Describe your idea in at least 20 characters.":
      "Opiši svoju ideju s najmanje 20 znakova.",
  "Developer": "Programer",
  "Developer access required.": "Potreban je developerski pristup.",
  "Developer frame is not available.": "Developerski okvir nije dostupan.",
  "Developer profile frame is not available for this account.":
      "Developerski okvir profila nije dostupan za ovaj račun.",
  "Developer title is not available for this account.":
      "Developerska titula nije dostupna za ovaj račun.",
  "Developer updates only": "Samo novosti developera",
  "Directing": "Režija",
  "Director": "Redatelj",
  "Discover": "Otkrivaj",
  "Discussion": "Rasprava",
  "Dismiss": "Odbaci",
  "Display Name": "Prikazano ime",
  "Display Name Color": "Boja prikazanog imena",
  "Display Name Frame": "Okvir prikazanog imena",
  "Display name cannot be empty.": "Prikazano ime ne smije biti prazno.",
  "Documentary": "Dokumentarni",
  "Don't have an account? Create Account": "Nemaš račun? Izradi račun",
  "Drama": "Drama",
  "Dropped": "Odbačeno",
  "ENTHUSIAST": "ENTUZIJAST",
  "EXCLUSIVE": "EKSKLUZIVNO",
  "EXPLORER": "ISTRAŽIVAČ",
  "Edit": "Uredi",
  "Edit Comment": "Uredi komentar",
  "Edit Profile": "Uredi profil",
  "Email": "E-pošta",
  "Email or username": "E-pošta ili korisničko ime",
  "Enable Public suggestion attribution in Privacy first.": "Najprije uključi Javno pripisivanje prijedloga u postavkama privatnosti.",
  "Ended": "Završeno",
  "English": "English",
  "Enter a valid email address.": "Unesi valjanu adresu e-pošte.",
  "Enter your current password.": "Unesi trenutačnu lozinku.",
  "Enter your email and a password of at least 6 characters.":
      "Unesi e-poštu i lozinku od najmanje 6 znakova.",
  "Enter your email or username and a password of at least 6 characters.":
      "Unesi e-poštu ili korisničko ime i lozinku od najmanje 6 znakova.",
  "Enter your email or username.": "Unesi e-poštu ili korisničko ime.",
  "Enter your full username and password.":
      "Unesi puno korisničko ime i lozinku.",
  "Enter your password.": "Unesi lozinku.",
  "Episode": "Epizoda",
  "Episode Analyst": "Analitičar epizoda",
  "Episode Authority": "Autoritet za epizode",
  "Episode Collector": "Kolekcionar epizoda",
  "Episode Grandmaster": "Velemajstor epizoda",
  "Episode Legend": "Legenda epizoda",
  "Episode Regular": "Redoviti gledatelj epizoda",
  "Episode Reviewer": "Recenzent epizoda",
  "Episodes Rated": "Ocijenjene epizode",
  "Episodes Watched": "Pogledane epizode",
  "Episodes, releases and community activity":
      "Epizode, izdanja i aktivnost zajednice",
  "Established Critic": "Afirmirani kritičar",
  "Every day": "Svaki dan",
  "Every month": "Svaki mjesec",
  "Every week": "Svaki tjedan",
  "Everyone": "Svi",
  "Explore other Chiplux profiles to upgrade your avatar frame.":
      "Istražuj druge Chiplux profile kako bi unaprijedio/la okvir avatara.",
  "Export now": "Izvezi sada",
  "Export your Chiplux data and schedule backups":
      "Izvezite svoje Chiplux podatke i zakažite sigurnosne kopije",
  "Exports include your profile settings, library, watched episodes, ratings, comments, activity, following list, notifications, reports, feature suggestions and blocked-user list.": "Izvoz uključuje postavke profila, biblioteku, pogledane epizode, ocjene, komentare, aktivnosti, popis praćenja, obavijesti, prijave, prijedloge značajki i popis blokiranih korisnika.",
  "FAQ": "Česta pitanja",
  "FEATURE SUGGESTION": "PRIJEDLOG ZNAČAJKE",
  "FEATURE UPDATE": "NOVOST ZNAČAJKE",
  "FUTURIST": "FUTURIST",
  "Failed to load credits":
      "Učitavanje glumačke i produkcijske ekipe nije uspjelo",
  "Failed to load details": "Učitavanje detalja nije uspjelo",
  "Failed to load episodes": "Učitavanje epizoda nije uspjelo",
  "Failed to load person projects": "Učitavanje projekata osobe nije uspjelo",
  "Failed to load trending TV shows": "Učitavanje serija u trendu nije uspjelo",
  "Failed to load trending anime":
      "Učitavanje anime sadržaja u trendu nije uspjelo",
  "Failed to load trending movies": "Učitavanje filmova u trendu nije uspjelo",
  "Failed to search TMDB": "Pretraživanje TMDB-a nije uspjelo",
  "Failed to search people": "Pretraživanje osoba nije uspjelo",
  "Family": "Obiteljski",
  "Fantasy": "Fantastika",
  "Favorite": "Omiljeno",
  "Favorites": "Omiljeno",
  "Feature Board": "Ploča prijedloga",
  "Feature Board update published.":
      "Novost na Ploči prijedloga je objavljena.",
  "Feature suggestion": "Prijedlog značajke",
  "Feature title": "Naslov značajke",
  "Film Adjudicator": "Filmski ocjenjivač",
  "Film Analyst": "Filmski analitičar",
  "Film Authority": "Filmski autoritet",
  "Film Buff": "Filmofil",
  "Film Collector": "Filmski kolekcionar",
  "Film Explorer": "Filmski istraživač",
  "Find Friends": "Pronađi prijatelje",
  "First Air Date": "Datum prvog emitiranja",
  "First Review": "Prva recenzija",
  "First Reviews": "Prve recenzije",
  "First Screening": "Prva projekcija",
  "First Verdict": "Prvi sud",
  "Follow": "Prati",
  "Follow Developer": "Prati developera",
  "Follow Developer frame is still locked.":
      "Okvir Praćenje developera još je zaključan.",
  "Follow Developer profile frame is still locked.":
      "Okvir profila Prati developera još je zaključan.",
  "Follow the Chiplux developer": "Prati Chiplux developera",
  "Follow the Chiplux developer to unlock a special Profile Page Frame.": "Prati Chiplux developera kako bi otključao/la poseban okvir stranice profila.",
  "Follow the Developer": "Prati developera",
  "Follow this user to see the profile details they share.":
      "Prati ovog korisnika kako bi vidio/la detalje profila koje dijeli.",
  "Follow unavailable": "Praćenje nije dostupno",
  "Follower Counter": "Brojač pratitelja",
  "Followers": "Pratitelji",
  "Followers-only profile": "Profil samo za pratitelje",
  "Following": "Pratim",
  "For You": "Za tebe",
  "For privacy questions or requests, use the Contact option in Chiplux. Before public release, the developer should also publish a monitored privacy or support email address here.": "Za pitanja ili zahtjeve u vezi s privatnošću koristi opciju Kontakt u Chipluxu. Prije javne objave developer bi ovdje također trebao objaviti nadziranu adresu e-pošte za privatnost ili podršku.",
  "Friends Watch": "Aktivnost prijatelja",
  "Full Cast": "Cijela glumačka postava",
  "Full username": "Puno korisničko ime",
  "GOT IT": "U REDU",
  "GUNSLINGER": "REVOLVERAŠ",
  "Genre Runtime": "Vrijeme gledanja po žanru",
  "Getting Noticed": "Postaješ primijećen/a",
  "Give your idea a title of at least 4 characters.":
      "Daj svojoj ideji naslov od najmanje 4 znaka.",
  "Got it": "U redu",
  "Great!": "Odlično!",
  "Grow your Chiplux audience to upgrade your follower counter.": "Povećavaj svoju Chiplux publiku kako bi unaprijedio/la brojač pratitelja.",
  "HARD TO IMPRESS": "TEŠKO GA JE IMPRESIONIRATI",
  "HEARTWARMER": "TOPLO SRCE",
  "HELP": "POMOĆ",
  "HISTORIAN": "POVJESNIČAR",
  "HUB": "CENTAR",
  "Happy Birthday!": "Sretan rođendan!",
  "Heroes, villains and comic-book worlds":
      "Junaci, zlikovci i svjetovi stripova",
  "Hide password": "Sakrij lozinku",
  "Hide replies": "Sakrij odgovore",
  "Highly-rated movies for a shorter watch":
      "Visoko ocijenjeni filmovi za kraće gledanje",
  "Highly-rated movies outside the mainstream":
      "Visoko ocijenjeni filmovi izvan mainstreama",
  "History": "Povijesni",
  "Horror": "Horor",
  "How Chiplux collects, uses and protects information.":
      "Kako Chiplux prikuplja, koristi i štiti podatke.",
  "How Chiplux handles data": "Kako Chiplux postupa s podacima",
  "How do I track a movie or TV show?": "Kako pratim film ili seriju?",
  "How do notifications work?": "Kako rade obavijesti?",
  "Hrvatski": "Hrvatski",
  "INTERACTIONS": "INTERAKCIJE",
  "If the GDPR or similar privacy law applies to you, you may have rights to access, correct, delete, restrict or object to certain processing, receive a portable copy of your data, and withdraw consent where processing is based on consent. You may also have the right to complain to your local data protection authority.": "Ako se na tebe primjenjuje GDPR ili sličan propis o privatnosti, možeš imati pravo na pristup, ispravak i brisanje podataka, ograničenje ili prigovor na određenu obradu, prijenosnu kopiju svojih podataka te povlačenje privole kada se obrada temelji na privoli. Također možeš imati pravo podnijeti pritužbu nadležnom tijelu za zaštitu podataka.",
  "Ignore": "Zanemari",
  "Ignore & Delete": "Zanemari i izbriši",
  "Ignore suggestion?": "Ignorirati prijedlog?",
  "Ignored": "Ignorirano",
  "Implemented": "Implementirano",
  "In Memoriam": "In memoriam",
  "In Production": "U produkciji",
  "In Progress": "U izradi",
  "Information and support for Chiplux.": "Informacije i podrška za Chiplux.",
  "Invalid backup frequency.": "Neispravna učestalost sigurnosne kopije.",
  "Invalid email, username or password.":
      "Neispravna e-pošta, korisničko ime ili lozinka.",
  "Invalid follow permission.": "Neispravno dopuštenje praćenja.",
  "Invalid profile visibility.": "Neispravna vidljivost profila.",
  "Invalid username or password.": "Neispravno korisničko ime ili lozinka.",
  "Just now": "Upravo sada",
  "Keep watching movies to upgrade this medal.":
      "Nastavi gledati filmove kako bi unaprijedio/la ovu medalju.",
  "Keep your Chiplux account secure.": "Zaštiti svoj Chiplux račun.",
  "Kids": "Dječji",
  "LIKE MILESTONE": "PREKRETNICA SVIĐANJA",
  "LVL": "RAZ.",
  "Language": "Jezik",
  "Language changed.": "Jezik je promijenjen.",
  "Legendary Collection": "Legendarna zbirka",
  "Let’s Comment": "Komentiraj",
  "Loading next episode...": "Učitavanje sljedeće epizode...",
  "Locked": "Zaključano",
  "MAESTRO": "MAESTRO",
  "MOVIE": "FILM",
  "Manage": "Upravljaj",
  "Marathon Viewer": "Maratonski gledatelj",
  "Mark as Watched": "Označi kao pogledano",
  "Mark as watched": "Označi kao pogledano",
  "Mark season watched": "Označi sezonu kao pogledanu",
  "Mark this episode as Watched to rate it.":
      "Označi ovu epizodu kao pogledanu kako bi je mogao/la ocijeniti.",
  "Mark this episode as watched before rating it.":
      "Označi ovu epizodu kao pogledanu prije ocjenjivanja.",
  "Mark this movie as Watched to rate or favorite it.": "Označi ovaj film kao pogledan kako bi ga mogao/la ocijeniti ili dodati u omiljeno.",
  "Master Collector": "Majstor kolekcionar",
  "Master Critic": "Majstor kritike",
  "Master switch for your Friends Watch activity.":
      "Glavni prekidač za tvoju aktivnost prijatelja.",
  "Max tier": "Najviša razina",
  "Medal Collection": "Zbirka medalja",
  "Medal Hunter": "Lovac na medalje",
  "Missing episode information.": "Nedostaju podaci o epizodi.",
  "Monthly Regular": "Mjesečni redoviti korisnik",
  "Movie": "Film",
  "Movie Critic": "Filmski kritičar",
  "Movies": "Filmovi",
  "Movies & TV": "Filmovi i serije",
  "Movies Rated": "Ocijenjeni filmovi",
  "Movies Watched": "Pogledani filmovi",
  "Movies, TV shows, episode titles and future music titles remain in their original form.": "Filmovi, serije, nazivi epizoda i budući nazivi glazbe ostaju u izvornom obliku.",
  "Movies, TV shows, episodes and watched runtime.":
      "Filmovi, serije, epizode i vrijeme gledanja.",
  "Music": "Glazbeni",
  "Mystery": "Misterij",
  "NEW": "NOVO",
  "NEW CRITIC": "NOVI KRITIČAR",
  "NEW EPISODE": "NOVA EPIZODA",
  "NEW FOLLOWER": "NOVI PRATITELJ",
  "NEW PASSWORD": "NOVA LOZINKA",
  "NEWS HOUND": "LOVAC NA VIJESTI",
  "NIGHT DWELLER": "NOĆNI STANOVNIK",
  "Name": "Ime",
  "New": "Novo",
  "New Episodes": "Nove epizode",
  "New Followers": "Novi pratitelji",
  "New Password": "Nova lozinka",
  "New follows are disabled.": "Novo praćenje je onemogućeno.",
  "New password must contain at least 6 characters.":
      "Nova lozinka mora imati najmanje 6 znakova.",
  "New passwords do not match.": "Nove lozinke se ne podudaraju.",
  "News": "Vijesti",
  "Next episode": "Sljedeća epizoda",
  "Next suggestion": "Sljedeći prijedlog",
  "No TV recommendation available.": "Nema dostupne preporuke serije.",
  "No backdrop": "Bez pozadine",
  "No birthday spotlight available today.":
      "Danas nema dostupne rođendanske osobe.",
  "No comments yet": "Još nema komentara",
  "No description available.": "Opis nije dostupan.",
  "No feature suggestions here yet.": "Ovdje još nema prijedloga značajki.",
  "No feature suggestions in this category yet.":
      "U ovoj kategoriji još nema prijedloga značajki.",
  "No followers yet.": "Još nema pratitelja.",
  "No genre runtime yet.": "Još nema vremena gledanja po žanru.",
  "No memorial spotlight available today.":
      "Danas nema dostupne osobe za In memoriam.",
  "No movie recommendation available.": "Nema dostupne preporuke filma.",
  "No notable TV show is airing today.":
      "Danas se ne emitira nijedna značajnija serija.",
  "No notable movie releases today.":
      "Danas nema značajnijih filmskih izdanja.",
  "No notifications yet": "Još nema obavijesti",
  "No projects found.": "Nema pronađenih projekata.",
  "No public stats yet.": "Još nema javnih statistika.",
  "No reason": "Bez razloga",
  "No reports.": "Nema prijava.",
  "No signed in user.": "Nema prijavljenog korisnika.",
  "No tier unlocked": "Nijedna razina nije otključana",
  "No users found.": "Nema pronađenih korisnika.",
  "Nobody": "Nitko",
  "None": "Bez",
  "Not Rated": "Nije ocijenjeno",
  "Not available": "Nije dostupno",
  "Nothing here yet.": "Ovdje još nema ničega.",
  "Notification": "Obavijest",
  "Notifications": "Obavijesti",
  "Notifications from Chiplux.": "Obavijesti iz Chipluxa.",
  "Notify me when I unlock a new Chiplux achievement.":
      "Obavijesti me kada otključam novo Chiplux postignuće.",
  "Notify me when a new episode of a show I am watching becomes available.":
      "Obavijesti me kada postane dostupna nova epizoda serije koju gledam.",
  "Notify me when a planned movie or TV show is released.":
      "Obavijesti me kada bude objavljen planirani film ili serija.",
  "Notify me when someone follows my profile.":
      "Obavijesti me kada netko počne pratiti moj profil.",
  "Notify me when someone replies to one of my comments.":
      "Obavijesti me kada netko odgovori na moj komentar.",
  "Notify me whenever one of my comments reaches another 100 likes.": "Obavijesti me svaki put kada jedan od mojih komentara dosegne novih 100 sviđanja.",
  "OFFICIAL": "SLUŽBENO",
  "OUTLAW": "ODMETNIK",
  "Off": "Isključeno",
  "Official announcement from Chiplux": "Službena objava Chipluxa",
  "Only developer updates can appear below Feature Board posts.": "Ispod objava na Ploči prijedloga mogu se prikazivati samo novosti developera.",
  "Only people following you can see your full profile.":
      "Samo osobe koje te prate mogu vidjeti tvoj cijeli profil.",
  "Only people you already follow can follow you.":
      "Mogu te pratiti samo osobe koje već pratiš.",
  "Open Chiplux on different days to upgrade your display name frame.": "Otvaraj Chiplux različitim danima kako bi unaprijedio/la okvir prikazanog imena.",
  "Open Settings → Notifications to choose which episode, release, community, achievement and Chiplux update notifications you want to receive.": "Otvori Postavke → Obavijesti i odaberi koje obavijesti o epizodama, izdanjima, zajednici, postignućima i Chiplux novostima želiš primati.",
  "Open a title and add it to your library. Movies can be marked watched, while TV shows track individual episodes and completion.": "Otvori naslov i dodaj ga u svoju biblioteku. Filmove možeš označiti kao pogledane, dok se za serije prate pojedine epizode i dovršenost.",
  "Optional Chiplux update...": "Neobavezna Chiplux novost...",
  "Optional Chiplux update…": "Neobavezna Chiplux objava…",
  "Other": "Ostalo",
  "Other users only see your basic identity.":
      "Drugi korisnici vide samo osnovne podatke o tvom identitetu.",
  "Overview": "Sažetak",
  "PINNED": "PRIKVAČENO",
  "PINNED ACHIEVEMENT": "PRIKVAČENO POSTIGNUĆE",
  "PROFILE": "PROFIL",
  "PUBLIC PROFILE": "JAVNI PROFIL",
  "Password": "Lozinka",
  "Password changed successfully.": "Lozinka je uspješno promijenjena.",
  "Pending": "Na čekanju",
  "People": "Osobe",
  "People I Follow": "Osobe koje pratim",
  "People Watcher": "Promatrač ljudi",
  "Person": "Osoba",
  "Pilot": "Pilot",
  "Pin to Display Name": "Prikvači uz prikazano ime",
  "Plan": "Planirano",
  "Plan to Watch": "Planiram gledati",
  "Planned": "Planirano",
  "Please describe the problem in a little more detail.":
      "Opiši problem malo detaljnije.",
  "Popularity": "Popularnost",
  "Post Comment": "Objavi komentar",
  "Post Production": "Postprodukcija",
  "Post Reply": "Objavi odgovor",
  "Potential spoiler · Tap to reveal": "Mogući spojler · Dodirni za prikaz",
  "Preferences": "Postavke",
  "Previous episode": "Prethodna epizoda",
  "Privacy": "Privatnost",
  "Privacy Policy": "Pravila privatnosti",
  "Private": "Privatno",
  "Private profile": "Privatni profil",
  "Producer": "Producent",
  "Production": "Produkcija",
  "Profile": "Profil",
  "Profile Banner": "Banner profila",
  "Profile Browser": "Pregledavatelj profila",
  "Profile Explorer": "Istraživač profila",
  "Profile Menu": "Izbornik profila",
  "Profile Page Frame": "Okvir stranice profila",
  "Profile Title": "Titula profila",
  "Profile customization saved.": "Prilagodba profila je spremljena.",
  "Profile not found.": "Profil nije pronađen.",
  "Profile options": "Opcije profila",
  "Profile visibility": "Vidljivost profila",
  "Profile, activity and interaction controls":
      "Kontrole profila, aktivnosti i interakcija",
  "Projects": "Projekti",
  "Public suggestion attribution": "Javno pripisivanje prijedloga",
  "Public suggestion attribution is disabled in Privacy.":
      "Javno pripisivanje prijedloga isključeno je u postavkama privatnosti.",
  "Publish Update": "Objavi novost",
  "Publish without user attribution.": "Objavi bez pripisivanja korisniku.",
  "Questions about these Terms can be sent through the Contact option in Chiplux. Before public release, the developer should also publish a monitored support email address here.": "Pitanja o ovim Uvjetima možeš poslati putem opcije Kontakt u Chipluxu. Prije javne objave developer bi ovdje također trebao objaviti nadziranu adresu e-pošte za podršku.",
  "Quick answers to common questions about using Chiplux.":
      "Brzi odgovori na česta pitanja o korištenju Chipluxa.",
  "READ ALL": "OZNAČI SVE PROČITANO",
  "REALITY STAR": "REALITY ZVIJEZDA",
  "RECENT ACTIVITY": "NEDAVNA AKTIVNOST",
  "RELEASE": "IZDANJE",
  "REMEMBERING": "SJEĆANJE",
  "REMOVE": "UKLONI",
  "REPLY": "ODGOVOR",
  "REWARD · Avatar Frame": "NAGRADA · Okvir avatara",
  "REWARD · Display Frame": "NAGRADA · Okvir prikaza",
  "ROMANTIC": "ROMANTIČAR",
  "RUNTIME LEVEL": "RAZINA GLEDANJA",
  "Rate TV shows to upgrade your TV Shows Rated stat border.": "Ocjenjuj serije kako bi unaprijedio/la okvir statistike Ocijenjene serije.",
  "Rate episodes to upgrade your Episodes Rated stat border.": "Ocjenjuj epizode kako bi unaprijedio/la okvir statistike Ocijenjene epizode.",
  "Rate movies to upgrade your Movies Rated stat border.": "Ocjenjuj filmove kako bi unaprijedio/la okvir statistike Ocijenjeni filmovi.",
  "Rated": "Ocijenjeno",
  "Rating Distribution": "Raspodjela ocjena",
  "Ratings Level": "Razina ocjenjivanja",
  "Ratings Level, averages and rating distribution.":
      "Razina ocjenjivanja, prosjeci i raspodjela ocjena.",
  "Ratings and comments unlock after the related movie, show or episode has been watched.": "Ocjene i komentari otključavaju se nakon što pogledaš povezani film, seriju ili epizodu.",
  "Reach higher Ratings Levels to upgrade your Ratings Level border and gradient.": "Doseži više razine ocjenjivanja kako bi unaprijedio/la okvir i gradijent Razine ocjenjivanja.",
  "Reach higher Runtime Levels to upgrade your Runtime Level border and gradient.": "Doseži više razine gledanja kako bi unaprijedio/la okvir i gradijent Razine gledanja.",
  "Reality": "Reality",
  "Receive important Chiplux feature and app updates.":
      "Primaj važne obavijesti o Chiplux značajkama i aplikaciji.",
  "Regular Visitor": "Redoviti posjetitelj",
  "Rejected": "Odbijeno",
  "Release Date": "Datum izlaska",
  "Release Reminders": "Podsjetnici na izdanja",
  "Released": "Objavljeno",
  "Released Today": "Objavljeno danas",
  "Remember Me": "Zapamti me",
  "Remembered today": "Sjećamo se danas",
  "Remove banner": "Ukloni banner",
  "Remove from Display Name": "Ukloni iz prikazanog imena",
  "Remove from Watch": "Ukloni iz Gledaj",
  "Remove from favorites": "Ukloni iz omiljenog",
  "Remove rating": "Ukloni ocjenu",
  "Replies": "Odgovori",
  "Replies, followers, achievements and Chiplux activity will appear here.": "Ovdje će se prikazivati odgovori, pratitelji, postignuća i Chiplux aktivnosti.",
  "Reply": "Odgovori",
  "Reply cannot be empty.": "Odgovor ne smije biti prazan.",
  "Reply is too long.": "Odgovor je predugačak.",
  "Replying to ": "Odgovaraš korisniku ",
  "Report": "Prijavi",
  "Report a Bug": "Prijavi grešku",
  "Report comment": "Prijavi komentar",
  "Report spoiler": "Prijavi spojler",
  "Report submitted. Thank you.": "Prijava je poslana. Hvala.",
  "Report user": "Prijavi korisnika",
  "Resolve": "Riješi",
  "Resolve this bug?": "Označiti grešku riješenom?",
  "Returning Series": "Serija se nastavlja",
  "Review and unblock people you have blocked.":
      "Pregledaj i odblokiraj osobe koje si blokirao/la.",
  "Review reports, resolve bugs and decide which community feature ideas become public.": "Pregledaj prijave, riješi greške i odluči koje će ideje zajednice postati javne.",
  "Review user, comment, bug and feature reports":
      "Pregled prijava korisnika, komentara, grešaka i prijedloga",
  "Reviewing": "U pregledu",
  "Rising Critic": "Kritičar u usponu",
  "Rising Profile": "Profil u usponu",
  "Romance": "Romansa",
  "Rumored": "Glasina",
  "Runtime": "Trajanje",
  "Runtime Level": "Razina gledanja",
  "Runtime Master": "Majstor gledanja",
  "Runtime Regular": "Redoviti gledatelj",
  "Runtime Rookie": "Početnik gledanja",
  "SAFETY": "SIGURNOST",
  "SETTINGS": "POSTAVKE",
  "SKEPTIC": "SKEPTIK",
  "SLEUTH": "DETEKTIV",
  "SOAP DEVOTEE": "LJUBITELJ SAPUNICA",
  "SPOILER REPORT": "PRIJAVA SPOJLERA",
  "STRATEGIST": "STRATEG",
  "SUPERFAN": "SUPERFAN",
  "Save": "Spremi",
  "Save Changes": "Spremi promjene",
  "Sci-Fi & Fantasy": "SF i fantastika",
  "Science Fiction": "Znanstvena fantastika",
  "Screen Legend": "Legenda ekrana",
  "Search": "Pretraži",
  "Search failed": "Pretraga nije uspjela",
  "Search for friends by display name or username.":
      "Pretraži prijatelje prema prikazanom imenu ili korisničkom imenu.",
  "Search movies and TV shows": "Pretraži filmove i serije",
  "Search name or username": "Pretraži ime ili korisničko ime",
  "Season": "Sezona",
  "Season Critic": "Kritičar sezona",
  "Seasoned Binger": "Iskusni maratonac",
  "Seasoned Critic": "Iskusni kritičar",
  "Seasoned Viewer": "Iskusni gledatelj",
  "Seasons": "Sezone",
  "See which community ideas Chiplux is building, has shipped or has decided not to pursue.": "Pogledaj koje ideje zajednice Chiplux razvija, koje je objavio i od kojih je odustao.",
  "Send Bug Report": "Pošalji prijavu greške",
  "Send a problem directly to Chiplux": "Pošaljite problem izravno Chipluxu",
  "Series Analyst": "Analitičar serija",
  "Series Buff": "Ljubitelj serija",
  "Series Critic": "Kritičar serija",
  "Series Starter": "Početnik serija",
  "Share an idea with the Chiplux developer":
      "Podijelite ideju s Chiplux developerom",
  "Share one meaningful idea every 30 days. Suggestions are reviewed before anything becomes public.": "Podijeli jednu smisleniju ideju svakih 30 dana. Prijedlozi se pregledavaju prije javne objave.",
  "Share your thoughts...": "Podijeli svoje mišljenje...",
  "Show achievement collection and pinned achievement.":
      "Prikaži zbirku postignuća i prikvačeno postignuće.",
  "Show achievements": "Prikaži postignuća",
  "Show followers/following": "Prikaži pratitelje/praćenje",
  "Show genre statistics": "Prikaži statistike žanrova",
  "Show less": "Prikaži manje",
  "Show my activity": "Prikaži moju aktivnost",
  "Show password": "Prikaži lozinku",
  "Show rating statistics": "Prikaži statistike ocjena",
  "Show ratings": "Prikaži ocjene",
  "Show spoiler": "Prikaži spojler",
  "Show watch activity": "Prikaži aktivnost gledanja",
  "Show watch statistics": "Prikaži statistike gledanja",
  "Show your username and profile when one of your feature suggestions is published.": "Prikaži tvoje korisničko ime i profil kada se objavi jedan od tvojih prijedloga značajki.",
  "Sign In": "Prijava",
  "Sign Out": "Odjava",
  "Small Screen Legend": "Legenda malog ekrana",
  "Small Screen Reviewer": "Recenzent malog ekrana",
  "Soap": "Sapunica",
  "Social Voyager": "Društveni putnik",
  "Something went wrong": "Nešto je pošlo po zlu",
  "Sort": "Sortiraj",
  "Sort by Not Rated": "Sortiraj po neocijenjenima",
  "Sort by Rated": "Sortiraj po ocijenjenima",
  "Spoiler": "Spojler",
  "Spoiler reported.": "Spojler je prijavljen.",
  "Spoiler reported. This comment is now hidden by default.":
      "Spojler je prijavljen. Ovaj komentar sada je zadano skriven.",
  "Start Watching or complete this show to rate or favorite it.": "Počni gledati ili dovrši ovu seriju kako bi je mogao/la ocijeniti ili dodati u omiljeno.",
  "Starting Collection": "Početna zbirka",
  "Stats will appear after this user syncs their profile.":
      "Statistike će se prikazati nakon što ovaj korisnik sinkronizira profil.",
  "Status": "Status",
  "Submit Suggestion": "Pošalji prijedlog",
  "Suggest a Feature": "Predloži značajku",
  "Suggested by ": "Predložio/la ",
  "Suggested by a Chiplux user": "Predložio korisnik Chipluxa",
  "Suggestion Sent!": "Prijedlog poslan!",
  "Suggestion available": "Prijedlog je dostupan",
  "Suggestions": "Prijedlozi",
  "Support, policies and answers about Chiplux.":
      "Podrška, pravila i odgovori o Chipluxu.",
  "System default": "Jezik uređaja",
  "THRILL SEEKER": "LOVAC NA UZBUĐENJE",
  "TMDB request failed: ": "TMDB zahtjev nije uspio: ",
  "TODAY'S BIRTHDAY": "DANAŠNJI ROĐENDAN",
  "TOONMASTER": "MAJSTOR ANIMACIJE",
  "TV": "TV",
  "TV Authority": "Televizijski autoritet",
  "TV Connoisseur": "Poznavatelj televizije",
  "TV Legend": "TV legenda",
  "TV Movie": "TV film",
  "TV Show": "Serija",
  "TV Shows": "Serije",
  "TV Shows Rated": "Ocijenjene serije",
  "TV Shows Watched": "Pogledane serije",
  "Talk": "Razgovorni",
  "Tap to change banner": "Dodirni za promjenu bannera",
  "Tap to change profile picture": "Dodirni za promjenu profilne slike",
  "Television Expert": "Televizijski stručnjak",
  "Tell us what happened so the issue can be reproduced and fixed.":
      "Opiši što se dogodilo kako bi se problem mogao ponoviti i ispraviti.",
  "Terms": "Uvjeti",
  "Terms of Use": "Uvjeti korištenja",
  "Terms of use": "Uvjeti korištenja",
  "That achievement customization is no longer available.":
      "Ta prilagodba postignuća više nije dostupna.",
  "That achievement customization is still locked.":
      "Ta prilagodba postignuća još je zaključana.",
  "That avatar frame is still locked.": "Taj okvir avatara još je zaključan.",
  "That display name frame is still locked.":
      "Taj okvir prikazanog imena još je zaključan.",
  "That profile page frame is not available.":
      "Taj okvir stranice profila nije dostupan.",
  "That profile title is still locked.": "Ta titula profila još je zaključana.",
  "That username is already taken.": "To korisničko ime je već zauzeto.",
  "The developer can publish a suggestion as In Progress, Implemented or Rejected. Ignored duplicates or unsuitable submissions are deleted and never shown publicly.": "Developer može objaviti prijedlog kao U izradi, Implementirano ili Odbijeno. Zanemareni duplikati ili neprikladni prijedlozi brišu se i nikada se javno ne prikazuju.",
  "The highest-rated TV series on TMDB": "Najbolje ocijenjene serije na TMDB-u",
  "The highest-rated movies on TMDB": "Najbolje ocijenjeni filmovi na TMDB-u",
  "The rules for using Chiplux and its community features.":
      "Pravila korištenja Chipluxa i njegovih značajki zajednice.",
  "These Terms are governed by the laws of Croatia, except where mandatory consumer or other laws in your country require a different result. Any mandatory rights available to consumers remain unaffected.": "Na ove Uvjete primjenjuje se pravo Republike Hrvatske, osim kada obvezna potrošačka ili druga pravila u tvojoj državi zahtijevaju drukčiji ishod. Sva obvezna prava potrošača ostaju nepromijenjena.",
  "These preferences control Chiplux notifications. Your phone notification permission must also be enabled.": "Ove postavke upravljaju Chiplux obavijestima. Dopuštenje za obavijesti na telefonu također mora biti uključeno.",
  "These providers process information under their own terms and privacy practices. Chiplux does not sell your personal information.": "Ti pružatelji obrađuju podatke prema vlastitim uvjetima i pravilima privatnosti. Chiplux ne prodaje tvoje osobne podatke.",
  "This Privacy Policy explains how Chiplux handles personal information when you create an account, use movie and TV tracking features, participate in community features, receive notifications, submit reports or otherwise use the Chiplux app.": "Ova Pravila privatnosti objašnjavaju kako Chiplux postupa s osobnim podacima kada izradiš račun, koristiš značajke praćenja filmova i serija, sudjeluješ u značajkama zajednice, primaš obavijesti, šalješ prijave ili na drugi način koristiš aplikaciju Chiplux.",
  "This permanently deletes your account and Chiplux data. This cannot be undone.": "Ovo trajno briše tvoj račun i Chiplux podatke. Radnju nije moguće poništiti.",
  "This permanently removes the comment.": "Ovo trajno uklanja komentar.",
  "This suggestion will not appear on the Feature Board and will be permanently deleted. The user will still keep their 30-day submission cooldown.": "Ovaj prijedlog neće se pojaviti na Ploči prijedloga i bit će trajno izbrisan. Korisniku će i dalje vrijediti ograničenje od 30 dana za slanje novog prijedloga.",
  "This suggestion will not appear on the Feature Board and will be permanently deleted. The user’s 30-day submission cooldown stays active.": "Prijedlog se neće pojaviti na Ploči prijedloga i bit će trajno izbrisan. Korisnikovo ograničenje od 30 dana ostaje aktivno.",
  "This user chose not to share profile statistics.":
      "Ovaj korisnik ne dijeli statistike profila.",
  "This user only shares their basic profile information.":
      "Ovaj korisnik dijeli samo osnovne podatke profila.",
  "This will mark the bug as solved and remove it from the active Bugs queue.": "Ovo će označiti grešku kao riješenu i ukloniti je s aktivnog popisa grešaka.",
  "This will permanently delete this comment, all of its replies, and all likes.":
      "Ovo će trajno izbrisati komentar, sve njegove odgovore i sva sviđanja.",
  "Thriller": "Triler",
  "Time Legend": "Legenda vremena",
  "Titles Rated": "Ocijenjeni naslovi",
  "To the maximum extent permitted by applicable law, Chiplux is provided without warranties beyond those that cannot legally be excluded. Chiplux is not responsible for decisions made solely on the basis of third-party entertainment metadata or user-generated content. Nothing in these Terms limits rights or remedies that cannot be limited under applicable consumer law.": "U najvećoj mjeri dopuštenoj primjenjivim zakonom, Chiplux se pruža bez jamstava osim onih koja se zakonski ne mogu isključiti. Chiplux nije odgovoran za odluke donesene isključivo na temelju metapodataka trećih strana o zabavnom sadržaju ili sadržaja koji su izradili korisnici. Ništa u ovim Uvjetima ne ograničava prava ili pravne lijekove koje prema primjenjivom potrošačkom pravu nije dopušteno ograničiti.",
  "Today": "Danas",
  "Today's Movie for You": "Današnji film za tebe",
  "Today's TV Show for You": "Današnja serija za tebe",
  "Top 100 Hidden Gems": "Top 100 skrivenih dragulja",
  "Top 100 Movies Under 90 Minutes": "Top 100 filmova kraćih od 90 minuta",
  "Top 100 Movies of All Time": "Top 100 filmova svih vremena",
  "Top 100 Superhero Movies": "Top 100 filmova o superjunacima",
  "Top 100 TV Shows of All Time": "Top 100 serija svih vremena",
  "Top Billed Cast": "Glavna glumačka postava",
  "Trending": "U trendu",
  "Trending Anime": "Anime u trendu",
  "Trending Movies": "Filmovi u trendu",
  "Trending TV Shows": "Serije u trendu",
  "Try Again": "Pokušaj ponovno",
  "Try one of these:": "Pokušaj s jednim od ovih:",
  "USER REPORT": "PRIJAVA KORISNIKA",
  "Unavailable": "Nedostupno",
  "Unblock": "Odblokiraj",
  "Unknown": "Nepoznato",
  "Unknown Actor": "Nepoznati glumac",
  "Unknown Movie": "Nepoznat film",
  "Unknown TV Show": "Nepoznata serija",
  "Unknown profile page frame.": "Nepoznat okvir stranice profila.",
  "Unknown title": "Nepoznati naslov",
  "Unlock Medal Collection milestones to unlock display name colors.": "Otključavaj prekretnice Zbirke medalja kako bi otključao/la boje prikazanog imena.",
  "Unlock a tier first": "Najprije otključaj razinu",
  "Unlock achievement milestones to upgrade your achievement button and unlock display name colors.": "Otključavaj prekretnice postignuća kako bi unaprijedio/la gumb postignuća i otključao/la boje prikazanog imena.",
  "Unlock an achievement milestone to earn your first title.":
      "Otključaj prekretnicu postignuća kako bi dobio/la svoju prvu titulu.",
  "Unlock new avatar frames through Profile Explorer achievements.":
      "Otključaj nove okvire avatara kroz postignuća Istraživača profila.",
  "Unlock new frames through Daily Login achievements.":
      "Otključaj nove okvire kroz postignuća dnevnih prijava.",
  "Untitled suggestion": "Prijedlog bez naslova",
  "Update your account password": "Ažurirajte lozinku računa",
  "Use any unlocked achievement milestone as the title shown above your display name.": "Upotrijebi bilo koju otključanu prekretnicu postignuća kao titulu iznad prikazanog imena.",
  "Use at least 6 characters.": "Upotrijebi najmanje 6 znakova.",
  "Use only letters, numbers and underscores.":
      "Koristi samo slova, brojeve i donje crte.",
  "User requested public credit if published.":
      "Korisnik je zatražio javno pripisivanje ako se prijedlog objavi.",
  "Username": "Korisničko ime",
  "Username cannot be longer than 20 characters.":
      "Korisničko ime ne smije imati više od 20 znakova.",
  "Username does not match this account.":
      "Korisničko ime ne odgovara ovom računu.",
  "Username is already taken.": "Korisničko ime je već zauzeto.",
  "Username is available.": "Korisničko ime je dostupno.",
  "Username must be at least 3 characters.":
      "Korisničko ime mora imati najmanje 3 znaka.",
  "Username must contain 3–20 letters, numbers, or underscores.":
      "Korisničko ime mora sadržavati 3–20 slova, brojeva ili podvlaka.",
  "Users": "Korisnici",
  "VIEWER": "GLEDATELJ",
  "View Developer Profile": "Prikaži profil developera",
  "View less": "Prikaži manje",
  "View more": "Prikaži više",
  "WATCHING": "GLEDANJE",
  "WHAT'S NEW": "ŠTO JE NOVO",
  "WORLDWALKER": "SVJETSKI PUTNIK",
  "Wait for the username check to finish.":
      "Pričekaj da provjera korisničkog imena završi.",
  "War": "Ratni",
  "War & Politics": "Rat i politika",
  "Watch": "Gledaj",
  "Watch Veteran": "Veteran gledanja",
  "Watch episodes to upgrade your Episodes Watched stat border.": "Gledaj epizode kako bi unaprijedio/la okvir statistike Pogledane epizode.",
  "Watched": "Pogledano",
  "Watched, started, planned, dropped and favorite activity.":
      "Aktivnosti za pogledano, započeto, planirano, odbačeno i omiljeno.",
  "Watching": "Gledam",
  "We may add, change or discontinue features and may perform maintenance or suspend access when reasonably necessary. Chiplux is provided on an as-available basis, and uninterrupted or error-free operation is not guaranteed.": "Možemo dodavati, mijenjati ili ukidati značajke te provoditi održavanje ili privremeno obustaviti pristup kada je to razumno potrebno. Chiplux se pruža prema dostupnosti i ne jamči se neprekinut rad bez pogrešaka.",
  "We may update these Terms as the service changes. If a change materially affects users, Chiplux may provide notice in the app or by another appropriate method. Continued use after the updated Terms take effect constitutes acceptance where permitted by law.": "Ove Uvjete možemo ažurirati kako se usluga mijenja. Ako promjena značajno utječe na korisnike, Chiplux može poslati obavijest u aplikaciji ili na drugi prikladan način. Nastavak korištenja nakon stupanja ažuriranih Uvjeta na snagu smatra se prihvaćanjem tamo gdje je to dopušteno zakonom.",
  "We may update this Privacy Policy as Chiplux changes. Material changes may be communicated in the app or through another appropriate notice. The effective date shown above indicates the current version.": "Ova Pravila privatnosti možemo ažurirati kako se Chiplux mijenja. O značajnim promjenama možemo obavijestiti unutar aplikacije ili na drugi prikladan način. Gore navedeni datum stupanja na snagu označava trenutačnu verziju.",
  "We retain information for as long as reasonably necessary to provide Chiplux, maintain security, resolve disputes and meet legal obligations. When an account is deleted, associated account data is deleted or de-identified where reasonably possible, subject to limited retention that may be required for security, backups, fraud prevention or law.": "Podatke čuvamo onoliko dugo koliko je razumno potrebno za pružanje Chipluxa, održavanje sigurnosti, rješavanje sporova i ispunjavanje pravnih obveza. Kada se račun izbriše, povezani podaci računa brišu se ili anonimiziraju gdje je to razumno moguće, uz ograničeno zadržavanje koje može biti potrebno radi sigurnosti, sigurnosnih kopija, sprječavanja prijevara ili zakonskih obveza.",
  "We use information to provide and synchronize your account and library, personalize your Chiplux experience, calculate statistics and achievements, operate community features, deliver notifications, process reports, prevent abuse, troubleshoot problems, secure the service and comply with applicable legal obligations.": "Podatke koristimo za pružanje i sinkronizaciju tvog računa i biblioteke, prilagodbu Chiplux iskustva, izračun statistika i postignuća, rad značajki zajednice, slanje obavijesti, obradu prijava, sprječavanje zloupotrebe, rješavanje problema, zaštitu usluge i ispunjavanje primjenjivih pravnih obveza.",
  "We use reasonable technical and organizational measures intended to protect account information. No online service can guarantee absolute security, so you should use a strong password and keep access to your account and devices secure.": "Primjenjujemo razumne tehničke i organizacijske mjere namijenjene zaštiti podataka računa. Nijedna internetska usluga ne može jamčiti apsolutnu sigurnost, stoga koristi snažnu lozinku i zaštiti pristup svom računu i uređajima.",
  "Weekend Watcher": "Vikend gledatelj",
  "Western": "Vestern",
  "What are achievements for?": "Čemu služe postignuća?",
  "What should Chiplux add, and how would you expect it to work?":
      "Što bi Chiplux trebao dodati i kako očekuješ da to radi?",
  "When can I rate or comment?": "Kada mogu ocjenjivati ili komentirati?",
  "When off, other users cannot reply to your comments.": "Kada je isključeno, drugi korisnici ne mogu odgovarati na tvoje komentare.",
  "Who can follow me": "Tko me može pratiti",
  "Why is this suggestion being rejected?": "Zašto se ovaj prijedlog odbija?",
  "Write a comment first.": "Najprije napiši komentar.",
  "Write a progress update...": "Napiši novost o napretku...",
  "Write a reply first.": "Najprije napiši odgovor.",
  "Write a reply...": "Napiši odgovor...",
  "YOUNG AT HEART": "MLAD U DUŠI",
  "Yes. Open Settings → Data & Export to create a JSON backup. You can also enable automatic local backups.": "Da. Otvori Postavke → Podaci i izvoz kako bi izradio/la JSON sigurnosnu kopiju. Možeš uključiti i automatske lokalne sigurnosne kopije.",
  "Yes. Open Settings → Privacy to control profile visibility, activity, statistics, follows and blocked users.": "Da. Otvori Postavke → Privatnost kako bi upravljao/la vidljivošću profila, aktivnošću, statistikama, praćenjem i blokiranim korisnicima.",
  "You": "Ti",
  "You are not following anyone yet.": "Još nikoga ne pratiš.",
  "You are responsible for the accuracy of information you provide, for keeping your login credentials secure and for activity performed through your account. You may not impersonate another person, misrepresent your identity or use another user’s account without permission.": "Odgovoran/na si za točnost podataka koje pružaš, sigurnost podataka za prijavu i aktivnosti izvršene putem tvog računa. Ne smiješ se predstavljati kao druga osoba, lažno prikazivati svoj identitet niti koristiti račun drugog korisnika bez dopuštenja.",
  "You can add an optional developer note. It will appear publicly on the Feature Board.": "Možeš dodati neobaveznu poruku developera. Bit će javno prikazana na Ploči prijedloga.",
  "You can submit one feature idea now.":
      "Sada možeš poslati jedan prijedlog značajke.",
  "You have not blocked anyone.": "Nisi nikoga blokirao/la.",
  "You may not use Chiplux to harass or threaten others, post unlawful or abusive material, spam users, manipulate ratings or engagement, distribute malware, attempt unauthorized access, interfere with the service, scrape or harvest data in a prohibited manner, or otherwise use Chiplux in a way that harms users or the service.": "Chiplux ne smiješ koristiti za uznemiravanje ili prijetnje drugima, objavu nezakonitog ili uvredljivog sadržaja, neželjene poruke, manipuliranje ocjenama ili angažmanom, širenje zlonamjernog softvera, pokušaje neovlaštenog pristupa, ometanje usluge, zabranjeno prikupljanje podataka ili na drugi način koji šteti korisnicima ili usluzi.",
  "You may stop using Chiplux and may delete your account through the available account controls. Chiplux may suspend or terminate access when reasonably necessary for serious or repeated violations, security risks, fraud, unlawful conduct or protection of other users.": "Možeš prestati koristiti Chiplux i izbrisati račun putem dostupnih kontrola računa. Chiplux može suspendirati ili ukinuti pristup kada je to razumno potrebno zbog ozbiljnih ili ponovljenih kršenja, sigurnosnih rizika, prijevare, nezakonitog ponašanja ili zaštite drugih korisnika.",
  "You must be signed in.": "Moraš biti prijavljen/a.",
  "You retain ownership of content you create, such as comments, reviews and feature suggestions. By posting content to Chiplux, you grant Chiplux a non-exclusive, worldwide, royalty-free license to host, store, reproduce and display that content only as reasonably necessary to operate, moderate and improve the service. Feature suggestions may be reviewed, ignored, rejected, published or implemented at the developer’s discretion, and submitting an idea does not create an obligation to implement it or provide compensation. You represent that you have the right to post the content you submit.": "Zadržavaš vlasništvo nad sadržajem koji izradiš, poput komentara, recenzija i prijedloga značajki. Objavom sadržaja na Chipluxu daješ Chipluxu neisključivu, svjetsku i besplatnu licencu za smještaj, pohranu, reproduciranje i prikaz tog sadržaja samo u mjeri razumno potrebnoj za rad, moderiranje i poboljšavanje usluge. Prijedlozi značajki mogu biti pregledani, zanemareni, odbijeni, objavljeni ili implementirani prema odluci developera, a slanje ideje ne stvara obvezu implementacije niti pravo na naknadu. Izjavljuješ da imaš pravo objaviti sadržaj koji šalješ.",
  "You will stop following each other and will no longer be able to interact.": "Prestat ćete pratiti jedno drugo i više nećete moći međusobno komunicirati.",
  "Your Chiplux account and sign-in information.":
      "Podaci o vašem Chiplux računu i prijavi.",
  "Your Chiplux data export.": "Tvoj izvoz Chiplux podataka.",
  "Your Episode Rating": "Tvoja ocjena epizode",
  "Your Rating": "Tvoja ocjena",
  "Your Taste · Your Story": "Tvoj ukus · Tvoja priča",
  "Your idea is now waiting for developer review. If it is published, it will appear on the Community Feature Board.": "Tvoja ideja sada čeka pregled developera. Ako bude objavljena, pojavit će se na Ploči prijedloga zajednice.",
  "Your identity is still stored privately with the submission for moderation and the 30-day limit, even when public credit is off.": "Tvoj identitet i dalje se privatno pohranjuje uz prijedlog radi moderacije i ograničenja od 30 dana, čak i kada je javno pripisivanje isključeno.",
  "Your rating and notes were saved.": "Tvoja ocjena i bilješke su spremljene.",
  "added to favorites": "dodao/la je u omiljeno",
  "an achievement": "postignuće",
  "dropped": "odustao/la je od",
  "e.g. Collaborative Lists": "npr. Zajedničke liste",
  "has completed": "dovršio/la je",
  "just now": "upravo sada",
  "less": "manje",
  "more": "više",
  "plans to watch": "planira gledati",
  "rated": "ocijenio/la je",
  "started watching": "počeo/la je gledati",
  "unlocked": "otključao/la je",
  "watched": "pogledao/la je",
  "watched a season of": "pogledao/la je sezonu serije",
  "watched an episode of": "pogledao/la je epizodu serije",
  "• edited": "• uređeno",
};

final Map<String, String> _hrFolded = <String, String>{
  for (final entry in _hrExact.entries) entry.key.toLowerCase(): entry.value,
};
