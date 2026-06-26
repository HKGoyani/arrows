import 'prefs.dart';

class Tr {
  static String get(String key) {
    final lang = Prefs.language;
    final map = _translations[lang] ?? _translations['English']!;
    return map[key] ?? _translations['English']![key] ?? key;
  }

  static String param(String key, Map<String, String> params) {
    var s = get(key);
    params.forEach((k, v) => s = s.replaceAll('{$k}', v));
    return s;
  }

  static List<String> get winWords =>
      (_winWords[Prefs.language] ?? _winWords['English']!);

  static String winWord(int index) => winWords[index % winWords.length];

  // ---------------------------------------------------------------------------
  // Translations
  // ---------------------------------------------------------------------------

  static const _translations = <String, Map<String, String>>{
    // =========================================================================
    // English
    // =========================================================================
    'English': {
      // Home
      'clearEveryArrow': 'Clear every arrow on the board',
      'level': 'Level',
      'play': 'Play',
      'continueYourRun': 'Continue your run',
      'tapToBegin': 'Tap to begin',

      // Game
      'hint': 'Hint',
      'tapToMove': 'Tap to move',
      'outOfLives': 'Out of lives',
      'addMoreLives': 'Add More Lives',
      'restart': 'Restart',

      // Settings
      'language': 'Language',
      'vibrations': 'Vibrations',
      'sounds': 'Sounds',
      'music': 'Music',
      'darkMode': 'Dark mode',
      'accountConnection': 'Account Connection',
      'removeAds': 'Remove Ads',
      'restorePurchases': 'Restore purchases',
      'howToPlay': 'How to play',
      'restoreProgress': 'Restore Progress',
      'resetProgress': 'Reset progress',
      'rateUs': 'Rate us',
      'writeUs': 'Write us',
      'privacy': 'Privacy',
      'termsOfService': 'Terms of Service',
      'comingSoon': 'Coming Soon',
      'close': 'Close',
      'submit': 'Submit',
      'cancel': 'Cancel',
      'howCanWeImprove': 'How can we improve?',
      'enterYourFeedback': 'Enter your feedback...',
      'enjoyingArrows': 'Enjoying Arrows?',
      'rateMessage':
          'Take a moment to rate the game!\nThank you for your support',
      'oneToFourStars': '1-4 Stars',
      'fiveStars': '5 Stars',
      'howToPlayText':
          'Tap an arrow to fire it off the board.\n\n• If its path to the edge is clear, it flies off.\n• If it is blocked, it turns red and you lose a life.\n• You have 3 lives. Clear the whole board to win.\n\nBoards get bigger and busier as you level up.',
      'gotIt': 'Got it',
      'resetProgressQuestion': 'Reset progress?',
      'resetWarning':
          'This clears your level and streak. This cannot be undone.',
      'reset': 'Reset',

      // Celebrations
      'newUnlock': 'New Unlock!',
      'continueButton': 'Continue',
      'levelLegendEarned':
          'You earned Level Legend by\nreaching level {milestone}!',
      'perfectPlayEarned':
          'You earned Perfect Play by\nwinning {milestone} levels on your\nfirst attempt!',

      // Collection - Records
      'records': 'Records',
      'longestStreak': 'Longest Streak',
      'streakDayText': 'You reached a {count} day streak!',
      'currentStreak': 'Current Streak',
      'highestWinStreak': 'Highest Win\nStreak',
      'winStreakText': 'You won {count} levels in a row!',
      'winStreakCurrent': "You're on {count} wins in a row.",
      'mostWins': 'Most Wins',
      'mostWinsText': 'You won {count} levels in a day!',
      'mostWinsToday': 'You won {count} levels today.',

      // Collection - Awards
      'awards': 'Awards',
      'levelLegend': 'Level Legend',
      'perfectPlay': 'Perfect Play',
      'unstoppable': 'Unstoppable',
      'awardEarned': 'Award earned!',
      'reachLevelToEarn': 'Reach Level {target} to earn this award.',
      'nextAwardAtLevel': 'Next award at level {next}',
      'nextAwardAtLevels': 'Next award at {next} levels',
      'winNightmareLevels':
          'Win {count} Nightmare levels to earn this award.',
      'earnedUnstoppable':
          'You earned Unstoppable by\nwinning {count} Nightmare levels!',
      'earnedPerfectPlay':
          'You earned Perfect Play by winning {count} levels on your first attempt!',
      'winFirstAttempt':
          'Win {count} levels on your first attempt to earn this award.',
      'reachLevelLegend': 'Reach Level {target} to earn this award.',

      // Collection - Challenge
      'challengeTrophies': 'Challenge Trophies',
      'xOfY': '{x} of {y}',
      'goToMonth': 'Go to month',
      'newLevelIn': 'New level in {time}',
      'replay': 'Replay',
      'current': 'Current',

      // Streak
      'dayStreak': '{count} day streak',
      'dayStreakSuffix': 'day streak',
      'extendStreakText': 'Win a level today to extend your streak!',
      'streakFreezers': 'Streak Freezers',
      'freezerStatus': '0/3 Equipped',

      // Nav
      'home': 'Home',
      'challenge': 'Challenge',
      'collection': 'Collection',
      'settings': 'Settings',

      // Difficulty tiers
      'normal': 'Normal',
      'hard': 'Hard',
      'superHard': 'Super Hard',
      'nightmare': 'Nightmare',

      // Months (full)
      'january': 'January',
      'february': 'February',
      'march': 'March',
      'april': 'April',
      'may': 'May',
      'june': 'June',
      'july': 'July',
      'august': 'August',
      'september': 'September',
      'october': 'October',
      'november': 'November',
      'december': 'December',

      // Months (short)
      'janShort': 'Jan',
      'febShort': 'Feb',
      'marShort': 'Mar',
      'aprShort': 'Apr',
      'mayShort': 'May',
      'junShort': 'Jun',
      'julShort': 'Jul',
      'augShort': 'Aug',
      'sepShort': 'Sep',
      'octShort': 'Oct',
      'novShort': 'Nov',
      'decShort': 'Dec',

      // Weekdays
      'mo': 'Mo',
      'tu': 'Tu',
      'we': 'We',
      'th': 'Th',
      'fr': 'Fr',
      'sa': 'Sa',
      'su': 'Su',
    },

    // =========================================================================
    // Deutsch (German)
    // =========================================================================
    'Deutsch': {
      // Home
      'clearEveryArrow': 'Entferne jeden Pfeil vom Spielfeld',
      'level': 'Level',
      'play': 'Spielen',
      'continueYourRun': 'Weiterspielen',
      'tapToBegin': 'Tippe zum Starten',

      // Game
      'hint': 'Hinweis',
      'tapToMove': 'Tippe zum Bewegen',
      'outOfLives': 'Keine Leben mehr',
      'addMoreLives': 'Mehr Leben',
      'restart': 'Neustart',

      // Settings
      'language': 'Sprache',
      'vibrations': 'Vibration',
      'sounds': 'Töne',
      'music': 'Musik',
      'darkMode': 'Dunkler Modus',
      'accountConnection': 'Kontoverbindung',
      'removeAds': 'Werbung entfernen',
      'restorePurchases': 'Käufe wiederherstellen',
      'howToPlay': 'Spielanleitung',
      'restoreProgress': 'Fortschritt wiederherstellen',
      'resetProgress': 'Fortschritt zurücksetzen',
      'rateUs': 'Bewerte uns',
      'writeUs': 'Schreib uns',
      'privacy': 'Datenschutz',
      'termsOfService': 'Nutzungsbedingungen',
      'comingSoon': 'Demnächst',
      'close': 'Schließen',
      'submit': 'Absenden',
      'cancel': 'Abbrechen',
      'howCanWeImprove': 'Wie können wir uns verbessern?',
      'enterYourFeedback': 'Gib dein Feedback ein …',
      'enjoyingArrows': 'Gefällt dir Arrows?',
      'rateMessage':
          'Nimm dir einen Moment, um das Spiel zu bewerten!\nVielen Dank für deine Unterstützung',
      'oneToFourStars': '1–4 Sterne',
      'fiveStars': '5 Sterne',
      'howToPlayText':
          'Tippe auf einen Pfeil, um ihn vom Spielfeld zu schießen.\n\n• Ist sein Weg zum Rand frei, fliegt er hinaus.\n• Ist er blockiert, wird er rot und du verlierst ein Leben.\n• Du hast 3 Leben. Räume das gesamte Spielfeld ab, um zu gewinnen.\n\nDie Spielfelder werden mit jedem Level größer und voller.',
      'gotIt': 'Verstanden',
      'resetProgressQuestion': 'Fortschritt zurücksetzen?',
      'resetWarning':
          'Dein Level und deine Serie werden gelöscht. Das kann nicht rückgängig gemacht werden.',
      'reset': 'Zurücksetzen',

      // Celebrations
      'newUnlock': 'Neue Freischaltung!',
      'continueButton': 'Weiter',
      'levelLegendEarned':
          'Du hast Level-Legende verdient,\nindem du Level {milestone} erreicht hast!',
      'perfectPlayEarned':
          'Du hast Perfektes Spiel verdient,\nindem du {milestone} Level beim\nersten Versuch gewonnen hast!',

      // Collection - Records
      'records': 'Rekorde',
      'longestStreak': 'Längste Serie',
      'streakDayText': 'Du hast eine Serie von {count} Tagen erreicht!',
      'currentStreak': 'Aktuelle Serie',
      'highestWinStreak': 'Beste Gewinn-\nSerie',
      'winStreakText': 'Du hast {count} Level hintereinander gewonnen!',
      'winStreakCurrent': 'Du bist bei {count} Siegen in Folge.',
      'mostWins': 'Meiste Siege',
      'mostWinsText': 'Du hast {count} Level an einem Tag gewonnen!',
      'mostWinsToday': 'Du hast heute {count} Level gewonnen.',

      // Collection - Awards
      'awards': 'Auszeichnungen',
      'levelLegend': 'Level-Legende',
      'perfectPlay': 'Perfektes Spiel',
      'unstoppable': 'Unaufhaltsam',
      'awardEarned': 'Auszeichnung erhalten!',
      'reachLevelToEarn':
          'Erreiche Level {target}, um diese Auszeichnung zu erhalten.',
      'nextAwardAtLevel': 'Nächste Auszeichnung bei Level {next}',
      'nextAwardAtLevels': 'Nächste Auszeichnung bei {next} Leveln',
      'winNightmareLevels':
          'Gewinne {count} Albtraum-Level, um diese Auszeichnung zu erhalten.',
      'earnedUnstoppable':
          'Du hast Unaufhaltsam verdient,\nindem du {count} Albtraum-Level gewonnen hast!',
      'earnedPerfectPlay':
          'Du hast Perfektes Spiel verdient, indem du {count} Level beim ersten Versuch gewonnen hast!',
      'winFirstAttempt':
          'Gewinne {count} Level beim ersten Versuch, um diese Auszeichnung zu erhalten.',
      'reachLevelLegend':
          'Erreiche Level {target}, um diese Auszeichnung zu erhalten.',

      // Collection - Challenge
      'challengeTrophies': 'Herausforderungs-Trophäen',
      'xOfY': '{x} von {y}',
      'goToMonth': 'Zum Monat',
      'newLevelIn': 'Neues Level in {time}',
      'replay': 'Wiederholen',
      'current': 'Aktuell',

      // Streak
      'dayStreak': '{count}-Tage-Serie',
      'dayStreakSuffix': 'Tage-Serie',
      'extendStreakText':
          'Gewinne heute ein Level, um deine Serie zu verlängern!',
      'streakFreezers': 'Serien-Schutz',
      'freezerStatus': '0/3 Ausgerüstet',

      // Nav
      'home': 'Start',
      'challenge': 'Herausforderung',
      'collection': 'Sammlung',
      'settings': 'Einstellungen',

      // Difficulty tiers
      'normal': 'Normal',
      'hard': 'Schwer',
      'superHard': 'Sehr schwer',
      'nightmare': 'Albtraum',

      // Months (full)
      'january': 'Januar',
      'february': 'Februar',
      'march': 'März',
      'april': 'April',
      'may': 'Mai',
      'june': 'Juni',
      'july': 'Juli',
      'august': 'August',
      'september': 'September',
      'october': 'Oktober',
      'november': 'November',
      'december': 'Dezember',

      // Months (short)
      'janShort': 'Jan',
      'febShort': 'Feb',
      'marShort': 'Mär',
      'aprShort': 'Apr',
      'mayShort': 'Mai',
      'junShort': 'Jun',
      'julShort': 'Jul',
      'augShort': 'Aug',
      'sepShort': 'Sep',
      'octShort': 'Okt',
      'novShort': 'Nov',
      'decShort': 'Dez',

      // Weekdays
      'mo': 'Mo',
      'tu': 'Di',
      'we': 'Mi',
      'th': 'Do',
      'fr': 'Fr',
      'sa': 'Sa',
      'su': 'So',
    },

    // =========================================================================
    // français (French)
    // =========================================================================
    'français': {
      // Home
      'clearEveryArrow': 'Élimine chaque flèche du plateau',
      'level': 'Niveau',
      'play': 'Jouer',
      'continueYourRun': 'Reprendre la partie',
      'tapToBegin': 'Appuie pour commencer',

      // Game
      'hint': 'Indice',
      'tapToMove': 'Appuie pour déplacer',
      'outOfLives': 'Plus de vies',
      'addMoreLives': 'Plus de vies',
      'restart': 'Recommencer',

      // Settings
      'language': 'Langue',
      'vibrations': 'Vibrations',
      'sounds': 'Sons',
      'music': 'Musique',
      'darkMode': 'Mode sombre',
      'accountConnection': 'Connexion au compte',
      'removeAds': 'Supprimer les pubs',
      'restorePurchases': 'Restaurer les achats',
      'howToPlay': 'Comment jouer',
      'restoreProgress': 'Restaurer la progression',
      'resetProgress': 'Réinitialiser la progression',
      'rateUs': 'Évalue-nous',
      'writeUs': 'Écris-nous',
      'privacy': 'Confidentialité',
      'termsOfService': "Conditions d'utilisation",
      'comingSoon': 'Bientôt disponible',
      'close': 'Fermer',
      'submit': 'Envoyer',
      'cancel': 'Annuler',
      'howCanWeImprove': 'Comment peut-on s’améliorer ?',
      'enterYourFeedback': 'Entre ton avis …',
      'enjoyingArrows': 'Tu aimes Arrows ?',
      'rateMessage':
          'Prends un moment pour noter le jeu !\nMerci pour ton soutien',
      'oneToFourStars': '1-4 Étoiles',
      'fiveStars': '5 Étoiles',
      'howToPlayText':
          'Appuie sur une flèche pour la lancer hors du plateau.\n\n• Si le chemin vers le bord est libre, elle s’envole.\n• Si elle est bloquée, elle devient rouge et tu perds une vie.\n• Tu as 3 vies. Élimine toutes les flèches pour gagner.\n\nLes plateaux deviennent plus grands et plus chargés à chaque niveau.',
      'gotIt': 'Compris',
      'resetProgressQuestion': 'Réinitialiser la progression ?',
      'resetWarning':
          'Cela efface ton niveau et ta série. Cette action est irréversible.',
      'reset': 'Réinitialiser',

      // Celebrations
      'newUnlock': 'Nouveau déblocage !',
      'continueButton': 'Continuer',
      'levelLegendEarned':
          'Tu as obtenu Légende de niveau en\natteignant le niveau {milestone} !',
      'perfectPlayEarned':
          'Tu as obtenu Jeu parfait en\ngagnant {milestone} niveaux du\npremier coup !',

      // Collection - Records
      'records': 'Records',
      'longestStreak': 'Plus longue série',
      'streakDayText': 'Tu as atteint une série de {count} jours !',
      'currentStreak': 'Série actuelle',
      'highestWinStreak': 'Meilleure série\nde victoires',
      'winStreakText': 'Tu as gagné {count} niveaux d’affilée !',
      'winStreakCurrent': 'Tu en es à {count} victoires d’affilée.',
      'mostWins': 'Record de victoires',
      'mostWinsText': 'Tu as gagné {count} niveaux en une journée !',
      'mostWinsToday': 'Tu as gagné {count} niveaux aujourd’hui.',

      // Collection - Awards
      'awards': 'Récompenses',
      'levelLegend': 'Légende de niveau',
      'perfectPlay': 'Jeu parfait',
      'unstoppable': 'Inarrêtable',
      'awardEarned': 'Récompense obtenue !',
      'reachLevelToEarn':
          'Atteins le niveau {target} pour obtenir cette récompense.',
      'nextAwardAtLevel': 'Prochaine récompense au niveau {next}',
      'nextAwardAtLevels': 'Prochaine récompense à {next} niveaux',
      'winNightmareLevels':
          'Gagne {count} niveaux Cauchemar pour obtenir cette récompense.',
      'earnedUnstoppable':
          'Tu as obtenu Inarrêtable en\ngagnant {count} niveaux Cauchemar !',
      'earnedPerfectPlay':
          'Tu as obtenu Jeu parfait en gagnant {count} niveaux du premier coup !',
      'winFirstAttempt':
          'Gagne {count} niveaux du premier coup pour obtenir cette récompense.',
      'reachLevelLegend':
          'Atteins le niveau {target} pour obtenir cette récompense.',

      // Collection - Challenge
      'challengeTrophies': 'Trophées de défi',
      'xOfY': '{x} sur {y}',
      'goToMonth': 'Aller au mois',
      'newLevelIn': 'Nouveau niveau dans {time}',
      'replay': 'Rejouer',
      'current': 'Actuel',

      // Streak
      'dayStreak': 'Série de {count} jours',
      'dayStreakSuffix': 'jours de série',
      'extendStreakText':
          'Gagne un niveau aujourd’hui pour prolonger ta série !',
      'streakFreezers': 'Gel de série',
      'freezerStatus': '0/3 Équipés',

      // Nav
      'home': 'Accueil',
      'challenge': 'Défi',
      'collection': 'Collection',
      'settings': 'Paramètres',

      // Difficulty tiers
      'normal': 'Normal',
      'hard': 'Difficile',
      'superHard': 'Très difficile',
      'nightmare': 'Cauchemar',

      // Months (full)
      'january': 'Janvier',
      'february': 'Février',
      'march': 'Mars',
      'april': 'Avril',
      'may': 'Mai',
      'june': 'Juin',
      'july': 'Juillet',
      'august': 'Août',
      'september': 'Septembre',
      'october': 'Octobre',
      'november': 'Novembre',
      'december': 'Décembre',

      // Months (short)
      'janShort': 'Jan',
      'febShort': 'Fév',
      'marShort': 'Mar',
      'aprShort': 'Avr',
      'mayShort': 'Mai',
      'junShort': 'Juin',
      'julShort': 'Juil',
      'augShort': 'Août',
      'sepShort': 'Sep',
      'octShort': 'Oct',
      'novShort': 'Nov',
      'decShort': 'Déc',

      // Weekdays
      'mo': 'Lu',
      'tu': 'Ma',
      'we': 'Me',
      'th': 'Je',
      'fr': 'Ve',
      'sa': 'Sa',
      'su': 'Di',
    },

    // =========================================================================
    // italiano (Italian)
    // =========================================================================
    'italiano': {
      // Home
      'clearEveryArrow': 'Elimina ogni freccia dal tabellone',
      'level': 'Livello',
      'play': 'Gioca',
      'continueYourRun': 'Continua la partita',
      'tapToBegin': 'Tocca per iniziare',

      // Game
      'hint': 'Suggerimento',
      'tapToMove': 'Tocca per muovere',
      'outOfLives': 'Vite esaurite',
      'addMoreLives': 'Aggiungi vite',
      'restart': 'Ricomincia',

      // Settings
      'language': 'Lingua',
      'vibrations': 'Vibrazioni',
      'sounds': 'Suoni',
      'music': 'Musica',
      'darkMode': 'Modalità scura',
      'accountConnection': 'Collegamento account',
      'removeAds': 'Rimuovi pubblicità',
      'restorePurchases': 'Ripristina acquisti',
      'howToPlay': 'Come si gioca',
      'restoreProgress': 'Ripristina progresso',
      'resetProgress': 'Azzera progresso',
      'rateUs': 'Valutaci',
      'writeUs': 'Scrivici',
      'privacy': 'Privacy',
      'termsOfService': 'Termini di servizio',
      'comingSoon': 'In arrivo',
      'close': 'Chiudi',
      'submit': 'Invia',
      'cancel': 'Annulla',
      'howCanWeImprove': 'Come possiamo migliorare?',
      'enterYourFeedback': 'Inserisci il tuo feedback…',
      'enjoyingArrows': 'Ti piace Arrows?',
      'rateMessage':
          'Prenditi un momento per valutare il gioco!\nGrazie per il tuo supporto',
      'oneToFourStars': '1-4 Stelle',
      'fiveStars': '5 Stelle',
      'howToPlayText':
          'Tocca una freccia per lanciarla fuori dal tabellone.\n\n• Se il percorso verso il bordo è libero, vola via.\n• Se è bloccata, diventa rossa e perdi una vita.\n• Hai 3 vite. Elimina tutte le frecce per vincere.\n\nI tabelloni diventano più grandi e più affollati con ogni livello.',
      'gotIt': 'Capito',
      'resetProgressQuestion': 'Azzerare il progresso?',
      'resetWarning':
          'Questo cancella il tuo livello e la tua serie. Non è possibile annullare.',
      'reset': 'Azzera',

      // Celebrations
      'newUnlock': 'Nuovo sblocco!',
      'continueButton': 'Continua',
      'levelLegendEarned':
          'Hai ottenuto Leggenda di livello\nraggiungendo il livello {milestone}!',
      'perfectPlayEarned':
          'Hai ottenuto Gioco perfetto\nvincendo {milestone} livelli al\nprimo tentativo!',

      // Collection - Records
      'records': 'Record',
      'longestStreak': 'Serie più lunga',
      'streakDayText': 'Hai raggiunto una serie di {count} giorni!',
      'currentStreak': 'Serie attuale',
      'highestWinStreak': 'Miglior serie\ndi vittorie',
      'winStreakText': 'Hai vinto {count} livelli di fila!',
      'winStreakCurrent': 'Sei a {count} vittorie consecutive.',
      'mostWins': 'Record vittorie',
      'mostWinsText': 'Hai vinto {count} livelli in un giorno!',
      'mostWinsToday': 'Hai vinto {count} livelli oggi.',

      // Collection - Awards
      'awards': 'Premi',
      'levelLegend': 'Leggenda di livello',
      'perfectPlay': 'Gioco perfetto',
      'unstoppable': 'Inarrestabile',
      'awardEarned': 'Premio ottenuto!',
      'reachLevelToEarn':
          'Raggiungi il livello {target} per ottenere questo premio.',
      'nextAwardAtLevel': 'Prossimo premio al livello {next}',
      'nextAwardAtLevels': 'Prossimo premio a {next} livelli',
      'winNightmareLevels':
          'Vinci {count} livelli Incubo per ottenere questo premio.',
      'earnedUnstoppable':
          'Hai ottenuto Inarrestabile\nvincendo {count} livelli Incubo!',
      'earnedPerfectPlay':
          'Hai ottenuto Gioco perfetto vincendo {count} livelli al primo tentativo!',
      'winFirstAttempt':
          'Vinci {count} livelli al primo tentativo per ottenere questo premio.',
      'reachLevelLegend':
          'Raggiungi il livello {target} per ottenere questo premio.',

      // Collection - Challenge
      'challengeTrophies': 'Trofei sfida',
      'xOfY': '{x} di {y}',
      'goToMonth': 'Vai al mese',
      'newLevelIn': 'Nuovo livello tra {time}',
      'replay': 'Rigioca',
      'current': 'Attuale',

      // Streak
      'dayStreak': 'Serie di {count} giorni',
      'dayStreakSuffix': 'giorni di serie',
      'extendStreakText':
          'Vinci un livello oggi per prolungare la tua serie!',
      'streakFreezers': 'Protezione serie',
      'freezerStatus': '0/3 Equipaggiati',

      // Nav
      'home': 'Home',
      'challenge': 'Sfida',
      'collection': 'Collezione',
      'settings': 'Impostazioni',

      // Difficulty tiers
      'normal': 'Normale',
      'hard': 'Difficile',
      'superHard': 'Super difficile',
      'nightmare': 'Incubo',

      // Months (full)
      'january': 'Gennaio',
      'february': 'Febbraio',
      'march': 'Marzo',
      'april': 'Aprile',
      'may': 'Maggio',
      'june': 'Giugno',
      'july': 'Luglio',
      'august': 'Agosto',
      'september': 'Settembre',
      'october': 'Ottobre',
      'november': 'Novembre',
      'december': 'Dicembre',

      // Months (short)
      'janShort': 'Gen',
      'febShort': 'Feb',
      'marShort': 'Mar',
      'aprShort': 'Apr',
      'mayShort': 'Mag',
      'junShort': 'Giu',
      'julShort': 'Lug',
      'augShort': 'Ago',
      'sepShort': 'Set',
      'octShort': 'Ott',
      'novShort': 'Nov',
      'decShort': 'Dic',

      // Weekdays
      'mo': 'Lu',
      'tu': 'Ma',
      'we': 'Me',
      'th': 'Gi',
      'fr': 'Ve',
      'sa': 'Sa',
      'su': 'Do',
    },

    // =========================================================================
    // 日本語 (Japanese)
    // =========================================================================
    '日本語': {
      // Home
      'clearEveryArrow': 'ボード上のすべての矢印をクリアしよう',
      'level': 'レベル',
      'play': 'プレイ',
      'continueYourRun': 'つづきから',
      'tapToBegin': 'タップして始めよう',

      // Game
      'hint': 'ヒント',
      'tapToMove': 'タップして動かそう',
      'outOfLives': 'ライフがなくなった',
      'addMoreLives': 'ライフを追加',
      'restart': 'リスタート',

      // Settings
      'language': '言語',
      'vibrations': '振動',
      'sounds': '効果音',
      'music': '音楽',
      'darkMode': 'ダークモード',
      'accountConnection': 'アカウント連携',
      'removeAds': '広告を削除',
      'restorePurchases': '購入を復元',
      'howToPlay': '遊び方',
      'restoreProgress': '進行状況を復元',
      'resetProgress': '進行状況をリセット',
      'rateUs': 'レビューする',
      'writeUs': 'お問い合わせ',
      'privacy': 'プライバシー',
      'termsOfService': '利用規約',
      'comingSoon': '近日公開',
      'close': '閉じる',
      'submit': '送信',
      'cancel': 'キャンセル',
      'howCanWeImprove': 'どうすればもっと良くなる？',
      'enterYourFeedback': 'フィードバックを入力…',
      'enjoyingArrows': 'Arrowsを楽しんでる？',
      'rateMessage': 'ゲームを評価してね！\n応援ありがとう',
      'oneToFourStars': '1〜4つ星',
      'fiveStars': '5つ星',
      'howToPlayText':
          '矢印をタップしてボードの外に飛ばそう。\n\n• 端までの道が空いていれば、飛んでいくよ。\n• 道がふさがっていると、赤くなってライフが1つ減るよ。\n• ライフは3つ。すべての矢印をクリアすれば勝ち。\n\nレベルが上がるとボードは大きく、矢印も増えていくよ。',
      'gotIt': 'わかった',
      'resetProgressQuestion': '進行状況をリセットする？',
      'resetWarning': 'レベルと連続記録が消去されます。元に戻せません。',
      'reset': 'リセット',

      // Celebrations
      'newUnlock': '新しい解放！',
      'continueButton': '続ける',
      'levelLegendEarned':
          'レベル{milestone}に到達して\nレベルレジェンドを獲得！',
      'perfectPlayEarned':
          '{milestone}レベルを初回クリアして\nパーフェクトプレイを獲得！',

      // Collection - Records
      'records': '記録',
      'longestStreak': '最長連続記録',
      'streakDayText': '{count}日連続を達成！',
      'currentStreak': '現在の連続記録',
      'highestWinStreak': '最高連勝\n記録',
      'winStreakText': '{count}レベル連続クリア！',
      'winStreakCurrent': '現在{count}連勝中。',
      'mostWins': '1日の最多勝利',
      'mostWinsText': '1日で{count}レベルクリア！',
      'mostWinsToday': '今日{count}レベルクリア。',

      // Collection - Awards
      'awards': 'アワード',
      'levelLegend': 'レベルレジェンド',
      'perfectPlay': 'パーフェクトプレイ',
      'unstoppable': 'アンストッパブル',
      'awardEarned': 'アワード獲得！',
      'reachLevelToEarn': 'レベル{target}に到達してこのアワードを獲得しよう。',
      'nextAwardAtLevel': '次のアワードはレベル{next}',
      'nextAwardAtLevels': '次のアワードは{next}レベル',
      'winNightmareLevels':
          'ナイトメアレベルを{count}回クリアしてこのアワードを獲得しよう。',
      'earnedUnstoppable':
          'ナイトメアレベルを{count}回クリアして\nアンストッパブルを獲得！',
      'earnedPerfectPlay':
          '{count}レベルを初回クリアしてパーフェクトプレイを獲得！',
      'winFirstAttempt':
          '{count}レベルを初回クリアしてこのアワードを獲得しよう。',
      'reachLevelLegend':
          'レベル{target}に到達してこのアワードを獲得しよう。',

      // Collection - Challenge
      'challengeTrophies': 'チャレンジトロフィー',
      'xOfY': '{x}/{y}',
      'goToMonth': '月を選択',
      'newLevelIn': '新しいレベルまで{time}',
      'replay': 'リプレイ',
      'current': '現在',

      // Streak
      'dayStreak': '{count}日連続',
      'dayStreakSuffix': '日連続',
      'extendStreakText': '今日レベルをクリアして連続記録を伸ばそう！',
      'streakFreezers': '連続記録の保護',
      'freezerStatus': '0/3 装備中',

      // Nav
      'home': 'ホーム',
      'challenge': 'チャレンジ',
      'collection': 'コレクション',
      'settings': '設定',

      // Difficulty tiers
      'normal': 'ノーマル',
      'hard': 'ハード',
      'superHard': 'スーパーハード',
      'nightmare': 'ナイトメア',

      // Months (full)
      'january': '1月',
      'february': '2月',
      'march': '3月',
      'april': '4月',
      'may': '5月',
      'june': '6月',
      'july': '7月',
      'august': '8月',
      'september': '9月',
      'october': '10月',
      'november': '11月',
      'december': '12月',

      // Months (short)
      'janShort': '1月',
      'febShort': '2月',
      'marShort': '3月',
      'aprShort': '4月',
      'mayShort': '5月',
      'junShort': '6月',
      'julShort': '7月',
      'augShort': '8月',
      'sepShort': '9月',
      'octShort': '10月',
      'novShort': '11月',
      'decShort': '12月',

      // Weekdays
      'mo': '月',
      'tu': '火',
      'we': '水',
      'th': '木',
      'fr': '金',
      'sa': '土',
      'su': '日',
    },

    // =========================================================================
    // 한국어 (Korean)
    // =========================================================================
    '한국어': {
      // Home
      'clearEveryArrow': '보드 위의 모든 화살표를 제거하세요',
      'level': '레벨',
      'play': '플레이',
      'continueYourRun': '이어서 하기',
      'tapToBegin': '탭하여 시작',

      // Game
      'hint': '힌트',
      'tapToMove': '탭하여 이동',
      'outOfLives': '생명 소진',
      'addMoreLives': '생명 추가',
      'restart': '다시 시작',

      // Settings
      'language': '언어',
      'vibrations': '진동',
      'sounds': '효과음',
      'music': '음악',
      'darkMode': '다크 모드',
      'accountConnection': '계정 연결',
      'removeAds': '광고 제거',
      'restorePurchases': '구매 복원',
      'howToPlay': '게임 방법',
      'restoreProgress': '진행 상황 복원',
      'resetProgress': '진행 상황 초기화',
      'rateUs': '평가하기',
      'writeUs': '문의하기',
      'privacy': '개인정보 보호',
      'termsOfService': '이용 약관',
      'comingSoon': '곧 출시',
      'close': '닫기',
      'submit': '제출',
      'cancel': '취소',
      'howCanWeImprove': '어떻게 개선하면 좋을까요?',
      'enterYourFeedback': '의견을 입력하세요…',
      'enjoyingArrows': 'Arrows 재미있나요?',
      'rateMessage': '잠깐 시간을 내어 게임을 평가해 주세요!\n응원 감사합니다',
      'oneToFourStars': '1-4점',
      'fiveStars': '5점',
      'howToPlayText':
          '화살표를 탭하여 보드 밖으로 날려보세요.\n\n• 가장자리까지 길이 비어 있으면 날아갑니다.\n• 막혀 있으면 빨갛게 변하고 생명이 줄어듭니다.\n• 생명은 3개. 모든 화살표를 제거하면 승리!\n\n레벨이 올라갈수록 보드가 커지고 화살표가 많아집니다.',
      'gotIt': '알겠어요',
      'resetProgressQuestion': '진행 상황을 초기화할까요?',
      'resetWarning': '레벨과 연속 기록이 삭제됩니다. 되돌릴 수 없습니다.',
      'reset': '초기화',

      // Celebrations
      'newUnlock': '새로운 잠금 해제!',
      'continueButton': '계속',
      'levelLegendEarned':
          '레벨 {milestone}에 도달하여\n레벨 레전드를 획득했습니다!',
      'perfectPlayEarned':
          '{milestone}개 레벨을 첫 시도에\n클리어하여 퍼펙트 플레이를\n획득했습니다!',

      // Collection - Records
      'records': '기록',
      'longestStreak': '최장 연속 기록',
      'streakDayText': '{count}일 연속을 달성했습니다!',
      'currentStreak': '현재 연속 기록',
      'highestWinStreak': '최고 연승\n기록',
      'winStreakText': '{count}개 레벨을 연속 클리어!',
      'winStreakCurrent': '현재 {count}연승 중.',
      'mostWins': '최다 승리',
      'mostWinsText': '하루에 {count}개 레벨 클리어!',
      'mostWinsToday': '오늘 {count}개 레벨 클리어.',

      // Collection - Awards
      'awards': '어워드',
      'levelLegend': '레벨 레전드',
      'perfectPlay': '퍼펙트 플레이',
      'unstoppable': '언스토퍼블',
      'awardEarned': '어워드 획득!',
      'reachLevelToEarn': '레벨 {target}에 도달하여 이 어워드를 획득하세요.',
      'nextAwardAtLevel': '다음 어워드는 레벨 {next}',
      'nextAwardAtLevels': '다음 어워드는 {next}개 레벨',
      'winNightmareLevels':
          '나이트메어 레벨을 {count}번 클리어하여 이 어워드를 획득하세요.',
      'earnedUnstoppable':
          '나이트메어 레벨을 {count}번 클리어하여\n언스토퍼블을 획득했습니다!',
      'earnedPerfectPlay':
          '{count}개 레벨을 첫 시도에 클리어하여 퍼펙트 플레이를 획득했습니다!',
      'winFirstAttempt':
          '{count}개 레벨을 첫 시도에 클리어하여 이 어워드를 획득하세요.',
      'reachLevelLegend':
          '레벨 {target}에 도달하여 이 어워드를 획득하세요.',

      // Collection - Challenge
      'challengeTrophies': '챌린지 트로피',
      'xOfY': '{x}/{y}',
      'goToMonth': '해당 월로 이동',
      'newLevelIn': '새 레벨까지 {time}',
      'replay': '다시 하기',
      'current': '현재',

      // Streak
      'dayStreak': '{count}일 연속',
      'dayStreakSuffix': '일 연속',
      'extendStreakText': '오늘 레벨을 클리어하여 연속 기록을 이어가세요!',
      'streakFreezers': '연속 기록 보호',
      'freezerStatus': '0/3 장착 중',

      // Nav
      'home': '홈',
      'challenge': '챌린지',
      'collection': '컬렉션',
      'settings': '설정',

      // Difficulty tiers
      'normal': '보통',
      'hard': '어려움',
      'superHard': '매우 어려움',
      'nightmare': '나이트메어',

      // Months (full)
      'january': '1월',
      'february': '2월',
      'march': '3월',
      'april': '4월',
      'may': '5월',
      'june': '6월',
      'july': '7월',
      'august': '8월',
      'september': '9월',
      'october': '10월',
      'november': '11월',
      'december': '12월',

      // Months (short)
      'janShort': '1월',
      'febShort': '2월',
      'marShort': '3월',
      'aprShort': '4월',
      'mayShort': '5월',
      'junShort': '6월',
      'julShort': '7월',
      'augShort': '8월',
      'sepShort': '9월',
      'octShort': '10월',
      'novShort': '11월',
      'decShort': '12월',

      // Weekdays
      'mo': '월',
      'tu': '화',
      'we': '수',
      'th': '목',
      'fr': '금',
      'sa': '토',
      'su': '일',
    },

    // =========================================================================
    // português (Brasil) (Brazilian Portuguese)
    // =========================================================================
    'português (Brasil)': {
      // Home
      'clearEveryArrow': 'Elimine todas as setas do tabuleiro',
      'level': 'Nível',
      'play': 'Jogar',
      'continueYourRun': 'Continuar jogando',
      'tapToBegin': 'Toque para começar',

      // Game
      'hint': 'Dica',
      'tapToMove': 'Toque para mover',
      'outOfLives': 'Sem vidas',
      'addMoreLives': 'Mais vidas',
      'restart': 'Recomeçar',

      // Settings
      'language': 'Idioma',
      'vibrations': 'Vibração',
      'sounds': 'Sons',
      'music': 'Música',
      'darkMode': 'Modo escuro',
      'accountConnection': 'Conexão de conta',
      'removeAds': 'Remover anúncios',
      'restorePurchases': 'Restaurar compras',
      'howToPlay': 'Como jogar',
      'restoreProgress': 'Restaurar progresso',
      'resetProgress': 'Resetar progresso',
      'rateUs': 'Avalie-nos',
      'writeUs': 'Escreva-nos',
      'privacy': 'Privacidade',
      'termsOfService': 'Termos de Serviço',
      'comingSoon': 'Em breve',
      'close': 'Fechar',
      'submit': 'Enviar',
      'cancel': 'Cancelar',
      'howCanWeImprove': 'Como podemos melhorar?',
      'enterYourFeedback': 'Digite seu feedback…',
      'enjoyingArrows': 'Curtindo o Arrows?',
      'rateMessage':
          'Reserve um momento para avaliar o jogo!\nObrigado pelo seu apoio',
      'oneToFourStars': '1-4 Estrelas',
      'fiveStars': '5 Estrelas',
      'howToPlayText':
          'Toque em uma seta para lançá-la para fora do tabuleiro.\n\n• Se o caminho até a borda estiver livre, ela voa.\n• Se estiver bloqueada, fica vermelha e você perde uma vida.\n• Você tem 3 vidas. Elimine todas as setas para vencer.\n\nOs tabuleiros ficam maiores e mais cheios conforme você sobe de nível.',
      'gotIt': 'Entendi',
      'resetProgressQuestion': 'Resetar progresso?',
      'resetWarning':
          'Isso apaga seu nível e sua sequência. Não é possível desfazer.',
      'reset': 'Resetar',

      // Celebrations
      'newUnlock': 'Novo desbloqueio!',
      'continueButton': 'Continuar',
      'levelLegendEarned':
          'Você conquistou Lenda de Nível ao\nalcançar o nível {milestone}!',
      'perfectPlayEarned':
          'Você conquistou Jogo Perfeito ao\nvencer {milestone} níveis na\nprimeira tentativa!',

      // Collection - Records
      'records': 'Recordes',
      'longestStreak': 'Maior sequência',
      'streakDayText': 'Você alcançou uma sequência de {count} dias!',
      'currentStreak': 'Sequência atual',
      'highestWinStreak': 'Maior sequência\nde vitórias',
      'winStreakText': 'Você venceu {count} níveis seguidos!',
      'winStreakCurrent': 'Você está com {count} vitórias seguidas.',
      'mostWins': 'Mais vitórias',
      'mostWinsText': 'Você venceu {count} níveis em um dia!',
      'mostWinsToday': 'Você venceu {count} níveis hoje.',

      // Collection - Awards
      'awards': 'Prêmios',
      'levelLegend': 'Lenda de Nível',
      'perfectPlay': 'Jogo Perfeito',
      'unstoppable': 'Imparável',
      'awardEarned': 'Prêmio conquistado!',
      'reachLevelToEarn':
          'Alcance o nível {target} para conquistar este prêmio.',
      'nextAwardAtLevel': 'Próximo prêmio no nível {next}',
      'nextAwardAtLevels': 'Próximo prêmio em {next} níveis',
      'winNightmareLevels':
          'Vença {count} níveis Pesadelo para conquistar este prêmio.',
      'earnedUnstoppable':
          'Você conquistou Imparável ao\nvencer {count} níveis Pesadelo!',
      'earnedPerfectPlay':
          'Você conquistou Jogo Perfeito ao vencer {count} níveis na primeira tentativa!',
      'winFirstAttempt':
          'Vença {count} níveis na primeira tentativa para conquistar este prêmio.',
      'reachLevelLegend':
          'Alcance o nível {target} para conquistar este prêmio.',

      // Collection - Challenge
      'challengeTrophies': 'Troféus de Desafio',
      'xOfY': '{x} de {y}',
      'goToMonth': 'Ir para o mês',
      'newLevelIn': 'Novo nível em {time}',
      'replay': 'Rejogar',
      'current': 'Atual',

      // Streak
      'dayStreak': 'Sequência de {count} dias',
      'dayStreakSuffix': 'dias de sequência',
      'extendStreakText':
          'Vença um nível hoje para manter sua sequência!',
      'streakFreezers': 'Proteção de sequência',
      'freezerStatus': '0/3 Equipados',

      // Nav
      'home': 'Início',
      'challenge': 'Desafio',
      'collection': 'Coleção',
      'settings': 'Configurações',

      // Difficulty tiers
      'normal': 'Normal',
      'hard': 'Difícil',
      'superHard': 'Super difícil',
      'nightmare': 'Pesadelo',

      // Months (full)
      'january': 'Janeiro',
      'february': 'Fevereiro',
      'march': 'Março',
      'april': 'Abril',
      'may': 'Maio',
      'june': 'Junho',
      'july': 'Julho',
      'august': 'Agosto',
      'september': 'Setembro',
      'october': 'Outubro',
      'november': 'Novembro',
      'december': 'Dezembro',

      // Months (short)
      'janShort': 'Jan',
      'febShort': 'Fev',
      'marShort': 'Mar',
      'aprShort': 'Abr',
      'mayShort': 'Mai',
      'junShort': 'Jun',
      'julShort': 'Jul',
      'augShort': 'Ago',
      'sepShort': 'Set',
      'octShort': 'Out',
      'novShort': 'Nov',
      'decShort': 'Dez',

      // Weekdays
      'mo': 'Seg',
      'tu': 'Ter',
      'we': 'Qua',
      'th': 'Qui',
      'fr': 'Sex',
      'sa': 'Sáb',
      'su': 'Dom',
    },

    // =========================================================================
    // русский (Russian)
    // =========================================================================
    'русский': {
      // Home
      'clearEveryArrow': 'Убери все стрелки с поля',
      'level': 'Уровень',
      'play': 'Играть',
      'continueYourRun': 'Продолжить',
      'tapToBegin': 'Нажми, чтобы начать',

      // Game
      'hint': 'Подсказка',
      'tapToMove': 'Нажми, чтобы двигать',
      'outOfLives': 'Жизни закончились',
      'addMoreLives': 'Добавить жизни',
      'restart': 'Начать заново',

      // Settings
      'language': 'Язык',
      'vibrations': 'Вибрация',
      'sounds': 'Звуки',
      'music': 'Музыка',
      'darkMode': 'Тёмная тема',
      'accountConnection': 'Привязка аккаунта',
      'removeAds': 'Убрать рекламу',
      'restorePurchases': 'Восстановить покупки',
      'howToPlay': 'Как играть',
      'restoreProgress': 'Восстановить прогресс',
      'resetProgress': 'Сбросить прогресс',
      'rateUs': 'Оценить нас',
      'writeUs': 'Написать нам',
      'privacy': 'Конфиденциальность',
      'termsOfService': 'Условия использования',
      'comingSoon': 'Скоро',
      'close': 'Закрыть',
      'submit': 'Отправить',
      'cancel': 'Отмена',
      'howCanWeImprove': 'Что можно улучшить?',
      'enterYourFeedback': 'Введите ваш отзыв…',
      'enjoyingArrows': 'Нравится Arrows?',
      'rateMessage':
          'Удели минутку, чтобы оценить игру!\nСпасибо за поддержку',
      'oneToFourStars': '1–4 звезды',
      'fiveStars': '5 звёзд',
      'howToPlayText':
          'Нажми на стрелку, чтобы запустить её с поля.\n\n• Если путь к краю свободен, она улетает.\n• Если путь заблокирован, она краснеет и ты теряешь жизнь.\n• У тебя 3 жизни. Убери все стрелки, чтобы победить.\n\nС каждым уровнем поля становятся больше и сложнее.',
      'gotIt': 'Понятно',
      'resetProgressQuestion': 'Сбросить прогресс?',
      'resetWarning':
          'Это удалит ваш уровень и серию. Отменить невозможно.',
      'reset': 'Сбросить',

      // Celebrations
      'newUnlock': 'Новая разблокировка!',
      'continueButton': 'Продолжить',
      'levelLegendEarned':
          'Ты получил Легенду уровней,\nдостигнув уровня {milestone}!',
      'perfectPlayEarned':
          'Ты получил Идеальную игру,\nпройдя {milestone} уровней с\nпервой попытки!',

      // Collection - Records
      'records': 'Рекорды',
      'longestStreak': 'Самая длинная серия',
      'streakDayText': 'Ты достиг серии в {count} дней!',
      'currentStreak': 'Текущая серия',
      'highestWinStreak': 'Лучшая серия\nпобед',
      'winStreakText': 'Ты выиграл {count} уровней подряд!',
      'winStreakCurrent': 'Сейчас {count} побед подряд.',
      'mostWins': 'Больше всего побед',
      'mostWinsText': 'Ты выиграл {count} уровней за день!',
      'mostWinsToday': 'Сегодня ты выиграл {count} уровней.',

      // Collection - Awards
      'awards': 'Награды',
      'levelLegend': 'Легенда уровней',
      'perfectPlay': 'Идеальная игра',
      'unstoppable': 'Неудержимый',
      'awardEarned': 'Награда получена!',
      'reachLevelToEarn':
          'Достигни уровня {target}, чтобы получить эту награду.',
      'nextAwardAtLevel': 'Следующая награда на уровне {next}',
      'nextAwardAtLevels': 'Следующая награда через {next} уровней',
      'winNightmareLevels':
          'Пройди {count} уровней «Кошмар», чтобы получить эту награду.',
      'earnedUnstoppable':
          'Ты получил «Неудержимый»,\nпройдя {count} уровней «Кошмар»!',
      'earnedPerfectPlay':
          'Ты получил «Идеальную игру», пройдя {count} уровней с первой попытки!',
      'winFirstAttempt':
          'Пройди {count} уровней с первой попытки, чтобы получить эту награду.',
      'reachLevelLegend':
          'Достигни уровня {target}, чтобы получить эту награду.',

      // Collection - Challenge
      'challengeTrophies': 'Трофеи испытаний',
      'xOfY': '{x} из {y}',
      'goToMonth': 'Перейти к месяцу',
      'newLevelIn': 'Новый уровень через {time}',
      'replay': 'Переиграть',
      'current': 'Текущий',

      // Streak
      'dayStreak': 'Серия {count} дней',
      'dayStreakSuffix': 'дней серия',
      'extendStreakText':
          'Выиграй уровень сегодня, чтобы продлить серию!',
      'streakFreezers': 'Заморозка серии',
      'freezerStatus': '0/3 Установлено',

      // Nav
      'home': 'Главная',
      'challenge': 'Испытание',
      'collection': 'Коллекция',
      'settings': 'Настройки',

      // Difficulty tiers
      'normal': 'Обычный',
      'hard': 'Сложный',
      'superHard': 'Очень сложный',
      'nightmare': 'Кошмар',

      // Months (full)
      'january': 'Январь',
      'february': 'Февраль',
      'march': 'Март',
      'april': 'Апрель',
      'may': 'Май',
      'june': 'Июнь',
      'july': 'Июль',
      'august': 'Август',
      'september': 'Сентябрь',
      'october': 'Октябрь',
      'november': 'Ноябрь',
      'december': 'Декабрь',

      // Months (short)
      'janShort': 'Янв',
      'febShort': 'Фев',
      'marShort': 'Мар',
      'aprShort': 'Апр',
      'mayShort': 'Май',
      'junShort': 'Июн',
      'julShort': 'Июл',
      'augShort': 'Авг',
      'sepShort': 'Сен',
      'octShort': 'Окт',
      'novShort': 'Ноя',
      'decShort': 'Дек',

      // Weekdays
      'mo': 'Пн',
      'tu': 'Вт',
      'we': 'Ср',
      'th': 'Чт',
      'fr': 'Пт',
      'sa': 'Сб',
      'su': 'Вс',
    },

    // =========================================================================
    // español (Spanish)
    // =========================================================================
    'español': {
      // Home
      'clearEveryArrow': 'Elimina todas las flechas del tablero',
      'level': 'Nivel',
      'play': 'Jugar',
      'continueYourRun': 'Seguir jugando',
      'tapToBegin': 'Toca para empezar',

      // Game
      'hint': 'Pista',
      'tapToMove': 'Toca para mover',
      'outOfLives': 'Sin vidas',
      'addMoreLives': 'Más vidas',
      'restart': 'Reiniciar',

      // Settings
      'language': 'Idioma',
      'vibrations': 'Vibración',
      'sounds': 'Sonidos',
      'music': 'Música',
      'darkMode': 'Modo oscuro',
      'accountConnection': 'Conexión de cuenta',
      'removeAds': 'Quitar anuncios',
      'restorePurchases': 'Restaurar compras',
      'howToPlay': 'Cómo jugar',
      'restoreProgress': 'Restaurar progreso',
      'resetProgress': 'Restablecer progreso',
      'rateUs': 'Califícanos',
      'writeUs': 'Escríbenos',
      'privacy': 'Privacidad',
      'termsOfService': 'Términos de servicio',
      'comingSoon': 'Próximamente',
      'close': 'Cerrar',
      'submit': 'Enviar',
      'cancel': 'Cancelar',
      'howCanWeImprove': '¿Cómo podemos mejorar?',
      'enterYourFeedback': 'Escribe tu opinión…',
      'enjoyingArrows': '¿Te gusta Arrows?',
      'rateMessage':
          '¡Tómate un momento para calificar el juego!\nGracias por tu apoyo',
      'oneToFourStars': '1-4 Estrellas',
      'fiveStars': '5 Estrellas',
      'howToPlayText':
          'Toca una flecha para lanzarla fuera del tablero.\n\n• Si el camino al borde está libre, sale volando.\n• Si está bloqueada, se vuelve roja y pierdes una vida.\n• Tienes 3 vidas. Elimina todas las flechas para ganar.\n\nLos tableros se hacen más grandes y complejos con cada nivel.',
      'gotIt': 'Entendido',
      'resetProgressQuestion': '¿Restablecer progreso?',
      'resetWarning':
          'Esto borra tu nivel y tu racha. No se puede deshacer.',
      'reset': 'Restablecer',

      // Celebrations
      'newUnlock': '¡Nuevo desbloqueo!',
      'continueButton': 'Continuar',
      'levelLegendEarned':
          '¡Obtuviste Leyenda de nivel al\nalcanzar el nivel {milestone}!',
      'perfectPlayEarned':
          '¡Obtuviste Juego perfecto al\nganar {milestone} niveles en tu\nprimer intento!',

      // Collection - Records
      'records': 'Récords',
      'longestStreak': 'Racha más larga',
      'streakDayText': '¡Alcanzaste una racha de {count} días!',
      'currentStreak': 'Racha actual',
      'highestWinStreak': 'Mayor racha\nde victorias',
      'winStreakText': '¡Ganaste {count} niveles seguidos!',
      'winStreakCurrent': 'Llevas {count} victorias seguidas.',
      'mostWins': 'Más victorias',
      'mostWinsText': '¡Ganaste {count} niveles en un día!',
      'mostWinsToday': 'Hoy ganaste {count} niveles.',

      // Collection - Awards
      'awards': 'Premios',
      'levelLegend': 'Leyenda de nivel',
      'perfectPlay': 'Juego perfecto',
      'unstoppable': 'Imparable',
      'awardEarned': '¡Premio obtenido!',
      'reachLevelToEarn':
          'Alcanza el nivel {target} para obtener este premio.',
      'nextAwardAtLevel': 'Próximo premio en el nivel {next}',
      'nextAwardAtLevels': 'Próximo premio en {next} niveles',
      'winNightmareLevels':
          'Gana {count} niveles Pesadilla para obtener este premio.',
      'earnedUnstoppable':
          '¡Obtuviste Imparable al\nganar {count} niveles Pesadilla!',
      'earnedPerfectPlay':
          '¡Obtuviste Juego perfecto al ganar {count} niveles en tu primer intento!',
      'winFirstAttempt':
          'Gana {count} niveles en tu primer intento para obtener este premio.',
      'reachLevelLegend':
          'Alcanza el nivel {target} para obtener este premio.',

      // Collection - Challenge
      'challengeTrophies': 'Trofeos de desafío',
      'xOfY': '{x} de {y}',
      'goToMonth': 'Ir al mes',
      'newLevelIn': 'Nuevo nivel en {time}',
      'replay': 'Repetir',
      'current': 'Actual',

      // Streak
      'dayStreak': 'Racha de {count} días',
      'dayStreakSuffix': 'días de racha',
      'extendStreakText':
          '¡Gana un nivel hoy para mantener tu racha!',
      'streakFreezers': 'Protección de racha',
      'freezerStatus': '0/3 Equipados',

      // Nav
      'home': 'Inicio',
      'challenge': 'Desafío',
      'collection': 'Colección',
      'settings': 'Ajustes',

      // Difficulty tiers
      'normal': 'Normal',
      'hard': 'Difícil',
      'superHard': 'Muy difícil',
      'nightmare': 'Pesadilla',

      // Months (full)
      'january': 'Enero',
      'february': 'Febrero',
      'march': 'Marzo',
      'april': 'Abril',
      'may': 'Mayo',
      'june': 'Junio',
      'july': 'Julio',
      'august': 'Agosto',
      'september': 'Septiembre',
      'october': 'Octubre',
      'november': 'Noviembre',
      'december': 'Diciembre',

      // Months (short)
      'janShort': 'Ene',
      'febShort': 'Feb',
      'marShort': 'Mar',
      'aprShort': 'Abr',
      'mayShort': 'May',
      'junShort': 'Jun',
      'julShort': 'Jul',
      'augShort': 'Ago',
      'sepShort': 'Sep',
      'octShort': 'Oct',
      'novShort': 'Nov',
      'decShort': 'Dic',

      // Weekdays
      'mo': 'Lu',
      'tu': 'Ma',
      'we': 'Mi',
      'th': 'Ju',
      'fr': 'Vi',
      'sa': 'Sá',
      'su': 'Do',
    },

    // =========================================================================
    // Türkçe (Turkish)
    // =========================================================================
    'Türkçe': {
      // Home
      'clearEveryArrow': 'Tahtadaki tüm okları temizle',
      'level': 'Seviye',
      'play': 'Oyna',
      'continueYourRun': 'Devam et',
      'tapToBegin': 'Başlamak için dokun',

      // Game
      'hint': 'İpucu',
      'tapToMove': 'Hareket ettirmek için dokun',
      'outOfLives': 'Can kalmadı',
      'addMoreLives': 'Can ekle',
      'restart': 'Yeniden başla',

      // Settings
      'language': 'Dil',
      'vibrations': 'Titreşim',
      'sounds': 'Sesler',
      'music': 'Müzik',
      'darkMode': 'Karanlık mod',
      'accountConnection': 'Hesap Bağlantısı',
      'removeAds': 'Reklamları kaldır',
      'restorePurchases': 'Satın alımları geri yükle',
      'howToPlay': 'Nasıl oynanır',
      'restoreProgress': 'İlerlemeyi geri yükle',
      'resetProgress': 'İlerlemeyi sıfırla',
      'rateUs': 'Bizi değerlendir',
      'writeUs': 'Bize yaz',
      'privacy': 'Gizlilik',
      'termsOfService': 'Kullanım Koşulları',
      'comingSoon': 'Yakında',
      'close': 'Kapat',
      'submit': 'Gönder',
      'cancel': 'İptal',
      'howCanWeImprove': 'Nasıl geliştirebiliriz?',
      'enterYourFeedback': 'Görüşlerinizi yazın…',
      'enjoyingArrows': 'Arrows hoşuna gidiyor mu?',
      'rateMessage':
          'Oyunu değerlendirmek için bir dakikanı ayır!\nDesteğin için teşekkürler',
      'oneToFourStars': '1-4 Yıldız',
      'fiveStars': '5 Yıldız',
      'howToPlayText':
          'Bir oka dokunarak onu tahtadan fırlat.\n\n• Kenara giden yol açıksa, uçup gider.\n• Yol kapalıysa, ok kırmızıya döner ve bir can kaybedersin.\n• 3 canın var. Kazanmak için tüm okları temizle.\n\nSeviye arttıkça tahtalar büyür ve daha dolu olur.',
      'gotIt': 'Anladım',
      'resetProgressQuestion': 'İlerleme sıfırlansın mı?',
      'resetWarning':
          'Seviye ve seri bilgilerin silinir. Bu işlem geri alınamaz.',
      'reset': 'Sıfırla',

      // Celebrations
      'newUnlock': 'Yeni Açılım!',
      'continueButton': 'Devam',
      'levelLegendEarned':
          'Seviye {milestone}’e ulaşarak\nSeviye Efsanesi kazandın!',
      'perfectPlayEarned':
          '{milestone} seviyeyi ilk denemede\ngeçerek Mükemmel Oyun\nkazandın!',

      // Collection - Records
      'records': 'Rekorlar',
      'longestStreak': 'En uzun seri',
      'streakDayText': '{count} günlük seriye ulaştın!',
      'currentStreak': 'Mevcut seri',
      'highestWinStreak': 'En yüksek\nkazanma serisi',
      'winStreakText': 'Art arda {count} seviye kazandın!',
      'winStreakCurrent': 'Şu anda {count} galibiyet serisinde.',
      'mostWins': 'En çok galibiyet',
      'mostWinsText': 'Bir günde {count} seviye kazandın!',
      'mostWinsToday': 'Bugün {count} seviye kazandın.',

      // Collection - Awards
      'awards': 'Ödüller',
      'levelLegend': 'Seviye Efsanesi',
      'perfectPlay': 'Mükemmel Oyun',
      'unstoppable': 'Durdurulamaz',
      'awardEarned': 'Ödül kazanıldı!',
      'reachLevelToEarn':
          'Bu ödülü kazanmak için seviye {target}’e ulaş.',
      'nextAwardAtLevel': 'Sonraki ödül seviye {next}’de',
      'nextAwardAtLevels': 'Sonraki ödül {next} seviyede',
      'winNightmareLevels':
          'Bu ödülü kazanmak için {count} Kabus seviyesini geç.',
      'earnedUnstoppable':
          '{count} Kabus seviyesini geçerek\nDurdurulamaz kazandın!',
      'earnedPerfectPlay':
          '{count} seviyeyi ilk denemede geçerek Mükemmel Oyun kazandın!',
      'winFirstAttempt':
          'Bu ödülü kazanmak için {count} seviyeyi ilk denemede geç.',
      'reachLevelLegend':
          'Bu ödülü kazanmak için seviye {target}’e ulaş.',

      // Collection - Challenge
      'challengeTrophies': 'Meydan Okuma Kupaları',
      'xOfY': '{x} / {y}',
      'goToMonth': 'Aya git',
      'newLevelIn': 'Yeni seviye {time} sonra',
      'replay': 'Tekrar oyna',
      'current': 'Güncel',

      // Streak
      'dayStreak': '{count} günlük seri',
      'dayStreakSuffix': 'günlük seri',
      'extendStreakText': 'Serini uzatmak için bugün bir seviye kazan!',
      'streakFreezers': 'Seri Koruyucu',
      'freezerStatus': '0/3 Donanımlı',

      // Nav
      'home': 'Ana sayfa',
      'challenge': 'Meydan Okuma',
      'collection': 'Koleksiyon',
      'settings': 'Ayarlar',

      // Difficulty tiers
      'normal': 'Normal',
      'hard': 'Zor',
      'superHard': 'Çok zor',
      'nightmare': 'Kabus',

      // Months (full)
      'january': 'Ocak',
      'february': 'Şubat',
      'march': 'Mart',
      'april': 'Nisan',
      'may': 'Mayıs',
      'june': 'Haziran',
      'july': 'Temmuz',
      'august': 'Ağustos',
      'september': 'Eylül',
      'october': 'Ekim',
      'november': 'Kasım',
      'december': 'Aralık',

      // Months (short)
      'janShort': 'Oca',
      'febShort': 'Şub',
      'marShort': 'Mar',
      'aprShort': 'Nis',
      'mayShort': 'May',
      'junShort': 'Haz',
      'julShort': 'Tem',
      'augShort': 'Ağu',
      'sepShort': 'Eyl',
      'octShort': 'Eki',
      'novShort': 'Kas',
      'decShort': 'Ara',

      // Weekdays
      'mo': 'Pt',
      'tu': 'Sa',
      'we': 'Ça',
      'th': 'Pe',
      'fr': 'Cu',
      'sa': 'Ct',
      'su': 'Pa',
    },
  };

  // ---------------------------------------------------------------------------
  // Win words
  // ---------------------------------------------------------------------------

  static const _winWords = <String, List<String>>{
    'English': [
      'Awesome!',
      'Fabulous!',
      'Fantastic!',
      'Terrific!',
      'Excellent!',
      'Great!',
      'Wonderful!',
      'Superb!',
      'Magnificent!',
      'Phenomenal!',
      'Stunning!',
      'Stellar!',
      'Mind-blowing!',
      'Marvelous!',
      'Brilliant!',
      'Well done!',
      'Outstanding!',
    ],
    'Deutsch': [
      'Super!',
      'Fabelhaft!',
      'Fantastisch!',
      'Toll!',
      'Exzellent!',
      'Großartig!',
      'Wunderbar!',
      'Hervorragend!',
      'Grandios!',
      'Phänomenal!',
      'Atemberaubend!',
      'Spitze!',
      'Unglaublich!',
      'Wundervoll!',
      'Brillant!',
      'Gut gemacht!',
      'Ausgezeichnet!',
    ],
    'français': [
      'Génial !',
      'Fabuleux !',
      'Fantastique !',
      'Formidable !',
      'Excellent !',
      'Super !',
      'Merveilleux !',
      'Superbe !',
      'Magnifique !',
      'Phénoménal !',
      'Éblouissant !',
      'Stellaire !',
      'Époustouflant !',
      'Prodigieux !',
      'Brillant !',
      'Bien joué !',
      'Exceptionnel !',
    ],
    'italiano': [
      'Fantastico!',
      'Favoloso!',
      'Incredibile!',
      'Eccezionale!',
      'Eccellente!',
      'Grandioso!',
      'Meraviglioso!',
      'Superbo!',
      'Magnifico!',
      'Fenomenale!',
      'Stupendo!',
      'Stellare!',
      'Strabiliante!',
      'Prodigioso!',
      'Brillante!',
      'Ben fatto!',
      'Straordinario!',
    ],
    '日本語': [
      'すごい！',
      'すばらしい！',
      'ファンタスティック！',
      'やったね！',
      'エクセレント！',
      'グレート！',
      'ワンダフル！',
      '最高！',
      '見事！',
      '驚異的！',
      '圧巻！',
      'ステラ！',
      '度肝を抜く！',
      'マーベラス！',
      'ブリリアント！',
      'お見事！',
      'アウトスタンディング！',
    ],
    '한국어': [
      '대단해!',
      '훌륭해!',
      '환상적!',
      '멋져!',
      '탁월해!',
      '잘했어!',
      '놀라워!',
      '최고!',
      '굉장해!',
      '경이로워!',
      '압도적!',
      '빛나는!',
      '감탄사!',
      '기막혀!',
      '브릴리언트!',
      '수고했어!',
      '뛰어나!',
    ],
    'português (Brasil)': [
      'Incrível!',
      'Fabuloso!',
      'Fantástico!',
      'Sensacional!',
      'Excelente!',
      'Ótimo!',
      'Maravilhoso!',
      'Soberbo!',
      'Magnífico!',
      'Fenomenal!',
      'Deslumbrante!',
      'Estelar!',
      'Impressionante!',
      'Espetacular!',
      'Brilhante!',
      'Muito bem!',
      'Excepcional!',
    ],
    'русский': [
      'Потрясающе!',
      'Великолепно!',
      'Фантастика!',
      'Здорово!',
      'Превосходно!',
      'Отлично!',
      'Чудесно!',
      'Бесподобно!',
      'Восхитительно!',
      'Феноменально!',
      'Ошеломляюще!',
      'Блестяще!',
      'Невероятно!',
      'Изумительно!',
      'Гениально!',
      'Молодец!',
      'Выдающееся!',
    ],
    'español': [
      '¡Genial!',
      '¡Fabuloso!',
      '¡Fantástico!',
      '¡Tremendo!',
      '¡Excelente!',
      '¡Estupendo!',
      '¡Maravilloso!',
      '¡Soberbio!',
      '¡Magnífico!',
      '¡Fenomenal!',
      '¡Impresionante!',
      '¡Estelar!',
      '¡Alucinante!',
      '¡Espectacular!',
      '¡Brillante!',
      '¡Bien hecho!',
      '¡Excepcional!',
    ],
    'Türkçe': [
      'Harika!',
      'Muhteşem!',
      'Fantastik!',
      'Müthiş!',
      'Mükemmel!',
      'Süper!',
      'Olağanüstü!',
      'Enfes!',
      'Görkemli!',
      'Fevkalade!',
      'Büyüleyici!',
      'Yıldız!',
      'Akıl almaz!',
      'Şahane!',
      'Parlak!',
      'Aferin!',
      'Üstün!',
    ],
  };
}
