import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:archive/archive.dart' as arc;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:vibration/vibration.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as scala;
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
// ignore: deprecated_member_use
import 'js_stub.dart' if (dart.library.js) 'dart:js' as js;
import 'gif_exercise_catalog.dart';
import 'exercise_catalog.dart';
import 'workout_tutorial.dart';

// Colore accento globale (tema)
final ValueNotifier<Color> appAccentNotifier = ValueNotifier<Color>(
  const Color(0xFF00F2FF),
);

// Istanza globale del plugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

String _limitToOneEmoji(String s) {
  final RegExp emojiRe = RegExp(
    r'[\u{1F300}-\u{1F9FF}]|[\u{2600}-\u{27BF}]|[\u{FE00}-\u{FE0F}]',
    unicode: true,
  );
  final matches = emojiRe.allMatches(s).toList();
  if (matches.length <= 1) return s;
  String result = s;
  for (int i = matches.length - 1; i >= 1; i--) {
    result = result.replaceRange(matches[i].start, matches[i].end, '');
  }
  return result.trim();
}

// Channel per leggere file content:// da WhatsApp/Telegram via ContentResolver
const _gymFileChannel = MethodChannel('gym_file_reader');

Future<String> _readFileUri(Uri uri) async {
  if (uri.scheme == 'content') {
    final bytes = await _gymFileChannel.invokeMethod<List<int>>(
      'readBytes',
      uri.toString(),
    );
    return utf8.decode(bytes!);
  }
  return await File(uri.toFilePath()).readAsString();
}

Future<void> cercaEsercizioSuYoutube(String nomeEsercizio) async {
  String query = Uri.encodeComponent("esecuzione $nomeEsercizio");
  final Uri url = Uri.parse(
    "https://www.youtube.com/results?search_query=$query",
  );

  if (kIsWeb) {
    // Se sei su WEB, apre una nuova scheda del browser
    await launchUrl(url, webOnlyWindowName: '_blank');
  } else {
    // Se sei su APP, usa la modalità esterna per non bloccare l'app
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Errore apertura YouTube');
    }
  }
}

class YouTubeSearchView extends StatefulWidget {
  final String esercizio;
  const YouTubeSearchView({super.key, required this.esercizio});

  @override
  State<YouTubeSearchView> createState() => _YouTubeSearchViewState();
}

class _YouTubeSearchViewState extends State<YouTubeSearchView> {
  late final WebViewController controller;
  NativeAd? _tutorialNativeAd;
  bool _tutorialNativeAdLoaded = false;

  @override
  void initState() {
    super.initState();
    // Creiamo il link di ricerca
    final String query = Uri.encodeComponent("esecuzione ${widget.esercizio}");
    final String url = "https://www.youtube.com/results?search_query=$query";

    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(url));
    if (!kIsWeb) {
      _tutorialNativeAd = NativeAd(
        adUnitId: kTutorialNativeAdUnitId,
        factoryId: kWorkoutNativeAdFactoryId,
        request: const AdRequest(),
        listener: NativeAdListener(
          onAdLoaded: (loadedAd) {
            if (!mounted) {
              loadedAd.dispose();
              return;
            }
            setState(() {
              _tutorialNativeAd = loadedAd as NativeAd;
              _tutorialNativeAdLoaded = true;
            });
          },
          onAdFailedToLoad: (failedAd, error) {
            failedAd.dispose();
            if (!mounted) return;
            setState(() {
              _tutorialNativeAd = null;
              _tutorialNativeAdLoaded = false;
            });
            debugPrint('tutorial native ad failed to load: $error');
          },
        ),
      )..load();
    }
  }

  @override
  void dispose() {
    _tutorialNativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Video: ${widget.esercizio}"),
        backgroundColor: Colors.black,
      ),
      body: Column(
        children: [
          Expanded(child: WebViewWidget(controller: controller)),
          if (!kIsWeb && _tutorialNativeAdLoaded && _tutorialNativeAd != null)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 86,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AdWidget(ad: _tutorialNativeAd!),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Flag globale: notifiche pronte
bool _notificationsReady = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz_data.initializeTimeZones();

  // Inizializza notifiche prima di runApp — stesso pattern di app_cliente (funziona!)
  const AndroidInitializationSettings initAndroid =
      AndroidInitializationSettings('ic_notification');
  const InitializationSettings initSettings = InitializationSettings(
    android: initAndroid,
  );
  await flutterLocalNotificationsPlugin.initialize(initSettings);
  _notificationsReady = true;

  if (!kIsWeb && Platform.isAndroid) {
    final androidPlugin = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();
    // Canali con importanza corretta — allineati ad app_cliente
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'timer_gym',
        'Timer Recupero',
        importance: Importance.max,
      ),
    );
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'timer_gym_alert',
        'Timer Fine Recupero',
        importance: Importance.max,
      ),
    );
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'timer_gym_cd',
        'Timer in corso',
        importance: Importance.defaultImportance,
      ),
    );
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'streak_reminder',
        'Streak Reminder',
        importance: Importance.high,
      ),
    );
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const ClientGymApp());
  _initPluginsBackground();
}

Future<void> _initPluginsBackground() async {
  // AdMob
  try {
    if (!kIsWeb) await MobileAds.instance.initialize();
  } catch (_) {}

  // Precarica annuncio interstitial
  if (!kIsWeb) {
    try {
      AdManager.instance.loadInterstitial();
    } catch (_) {}
  }
}

class ClientGymApp extends StatefulWidget {
  const ClientGymApp({super.key});
  @override
  State<ClientGymApp> createState() => _ClientGymAppState();
}

class _ClientGymAppState extends State<ClientGymApp> {
  @override
  void initState() {
    super.initState();
    _loadAccentColor();
  }

  Future<void> _loadAccentColor() async {
    final prefs = await SharedPreferences.getInstance();
    final hex = prefs.getInt('accent_color') ?? 0xFF00F2FF;
    appAccentNotifier.value = Color(hex);
  }

  ThemeData _buildTheme(Color accent) {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: Colors.black,
      primaryColor: accent,
      colorScheme: ColorScheme.dark(
        primary: accent,
        surface: const Color(0xFF1C1C1E),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: appAccentNotifier,
      builder: (_, accent, __) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(accent),
        home: const GymAppHome(),
      ),
    );
  }
}

class AppL {
  static String _lang = 'it';
  static void setLang(String lang) => _lang = lang;
  static String get lang => _lang;

  static String get mySchedule =>
      _lang == 'en' ? 'My Schedule' : 'La mia scheda';
  static String get noSchedule =>
      _lang == 'en' ? 'No schedule yet' : 'Nessuna scheda';
  static String get createSchedule =>
      _lang == 'en' ? 'Create your schedule' : 'Crea la tua scheda';
  static String get train => _lang == 'en' ? 'Train' : 'Allenati';
  static String get progress => _lang == 'en' ? 'Progress' : 'Progressi';
  static String get settings => _lang == 'en' ? 'Settings' : 'Impostazioni';
  static String get deleteData =>
      _lang == 'en' ? 'Delete data' : 'Cancella dati';
  static String get day => _lang == 'en' ? 'Day' : 'Giorno';
  static String get exercises => _lang == 'en' ? 'Exercises' : 'Esercizi';
  static String get sets => _lang == 'en' ? 'Sets' : 'Serie';
  static String get reps => _lang == 'en' ? 'Reps' : 'Ripetizioni';
  static String get recovery => _lang == 'en' ? 'Recovery (s)' : 'Recupero (s)';
  static String get notes => _lang == 'en' ? 'Notes' : 'Note';
  static String get save => _lang == 'en' ? 'Save' : 'Salva';
  static String get cancel => _lang == 'en' ? 'Cancel' : 'Annulla';
  static String get add => _lang == 'en' ? 'Add' : 'Aggiungi';
  static String get weight => _lang == 'en' ? 'Weight (kg)' : 'Peso (kg)';
  static String get weightUnit => _lang == 'en' ? 'Weight unit' : 'Unita peso';
  static String get usePounds =>
      _lang == 'en' ? 'Use pounds (lb)' : 'Usa libbre (lb)';
  static String get startWorkout =>
      _lang == 'en' ? 'Start Workout' : 'Inizia Allenamento';
  static String get proTrainer => _lang == 'en'
      ? 'Are you a Personal Trainer?'
      : 'Sei un Personal Trainer?';
  static String get pause =>
      _lang == 'en' ? 'Pause between exercises (s)' : 'Pausa tra esercizi (s)';
  static String get browseArchive =>
      _lang == 'en' ? 'Browse archive' : 'Sfoglia archivio';
  static String get repsPerSet =>
      _lang == 'en' ? 'Reps per set' : 'Reps per serie';
  static String get muscleGroup =>
      _lang == 'en' ? 'Muscle group' : 'Gruppo muscolare';
  static String get chooseExercise =>
      _lang == 'en' ? 'Choose exercise' : 'Scegli esercizio';
  static String get noScheduleYet =>
      _lang == 'en' ? 'No days yet' : 'Nessun giorno ancora';
  static String get addFirstDay => _lang == 'en'
      ? 'Press + to add the first day'
      : 'Premi + per aggiungere il primo giorno';
  static String get deleteDay =>
      _lang == 'en' ? 'Delete day?' : 'Elimina giorno?';
  static String get delete => _lang == 'en' ? 'DELETE' : 'ELIMINA';
  static String get circuit =>
      _lang == 'en' ? 'Superset & circuit' : 'Superserie e circuito';
  static String get circuitHint => _lang == 'en'
      ? 'Assign the same number to exercises done back-to-back without rest. 0 = normal, 1/2/3 = superset/circuit group.'
      : 'Assegna lo stesso numero agli esercizi da fare in sequenza senza recupero. 0 = normale, 1/2/3 = gruppo superserie/circuito.';
  static String get exerciseName =>
      _lang == 'en' ? 'Exercise name' : 'Nome esercizio';
  static String get pauseSec => _lang == 'en' ? 'Pause (s)' : 'Pausa (s)';
  static String get tapToChooseMuscle => _lang == 'en'
      ? 'Tap to choose muscle image'
      : 'Tocca per scegliere immagine muscolo';
  static String get noScheduleMsg => _lang == 'en'
      ? 'No schedule yet.\nCreate your first workout!'
      : 'Nessuna scheda.\nCrea il tuo primo allenamento!';
  static String get history => _lang == 'en' ? 'History' : 'Storico';
  static String get workoutOf =>
      _lang == 'en' ? 'Workout of' : 'Allenamento del';
  static String get restTimer =>
      _lang == 'en' ? 'Rest timer' : 'Timer recupero';
  static String get nextSet => _lang == 'en' ? 'Next set' : 'Prossima serie';
  static String get done => _lang == 'en' ? 'Done' : 'Fatto';
  static String get skip => _lang == 'en' ? 'Skip' : 'Salta';
  static String get confirm => _lang == 'en' ? 'Confirm' : 'Conferma';
  static String get workout => _lang == 'en' ? 'Workout' : 'Allenamento';
  static String get totalVolume =>
      _lang == 'en' ? 'Total volume' : 'Volume totale';
  static String get personalBest =>
      _lang == 'en' ? 'Personal best' : 'Record personale';
  static String get language => _lang == 'en' ? 'Language' : 'Lingua';
  static String get italian => _lang == 'en' ? 'Italian' : 'Italiano';
  static String get english => _lang == 'en' ? 'English' : 'Inglese';
  static String get accentColor =>
      _lang == 'en' ? 'Accent color' : 'Colore accento';
  static String get chooseLanguage =>
      _lang == 'en' ? 'Choose your language' : 'Scegli la tua lingua';
  static String get continueBtn => _lang == 'en' ? 'Continue' : 'Continua';
  static String get welcomeTitle =>
      _lang == 'en' ? 'Welcome to GymApp' : 'Benvenuto in GymApp';
  static String get setGroup => _lang == 'en' ? 'Group' : 'Gruppo';

  // Onboarding pages
  static String get onboardingWelcomeText => _lang == 'en'
      ? 'Your smart workout app, wherever you are.'
      : 'La tua app per allenarsi in modo intelligente, ovunque tu sia.';
  static String get onboardingScheduleTitle =>
      _lang == 'en' ? 'Build your schedule' : 'Crea la tua scheda';
  static String get onboardingScheduleText => _lang == 'en'
      ? 'Build your personalized routine with exercises from our database of 1200+ movements with animated GIFs.'
      : 'Costruisci la tua routine personalizzata con esercizi dal nostro database di 1200+ movimenti con GIF animate.';
  static String get onboardingTrainTitle =>
      _lang == 'en' ? 'Train & track' : 'Allena e registra';
  static String get onboardingTrainText => _lang == 'en'
      ? 'Follow each set with automatic timer, record weights and reps, view your progress over time.'
      : 'Segui ogni serie con timer automatico, registra pesi e ripetizioni, visualizza i tuoi progressi nel tempo.';
  static String get onboardingProgressTitle =>
      _lang == 'en' ? 'Monitor progress' : 'Monitora i progressi';
  static String get onboardingProgressText => _lang == 'en'
      ? 'Charts for each exercise, session history and automatic suggestions to increase loads.'
      : 'Grafici per ogni esercizio, storico delle sessioni e suggerimenti automatici per aumentare i carichi.';
  static String get onboardingProText => _lang == 'en'
      ? 'Take your clients to the next level with the complete ecosystem: PT app to create schedules and monitor all your athletes from a single dashboard.'
      : 'Porta i tuoi clienti al livello successivo con l\'ecosistema completo: app PT per creare schede e monitorare tutti i tuoi atleti da un\'unica dashboard.';
  static String get contactGianmarco =>
      _lang == 'en' ? 'Contact Gianmarco' : 'Contatta Gianmarco';
  static String get proInfoText => _lang == 'en'
      ? 'Write for info on the GymApp Pro ecosystem'
      : 'Scrivi per info sull\'ecosistema GymApp Pro';
  static String get startBtn => _lang == 'en' ? 'START' : 'INIZIA';
  static String get nextBtn => _lang == 'en' ? 'NEXT' : 'AVANTI';
  static String get chooseMuscleImage =>
      _lang == 'en' ? 'Workout image' : 'Immagine allenamento';
  static String get noImage => _lang == 'en' ? 'None' : 'Nessuna';
  static String get promoText => _lang == 'en'
      ? 'Take your clients to the next level with the GymApp Pro ecosystem.'
      : 'Porta i tuoi clienti al livello successivo con l\'ecosistema GymApp Pro.';
  static String get noScheduleLoaded =>
      _lang == 'en' ? 'No schedule loaded' : 'Nessuna scheda caricata';
  static String get editOrCreate => _lang == 'en'
      ? 'Edit or create schedule'
      : 'Modifica o crea una nuova scheda';
  static String get trainNow => _lang == 'en' ? 'TRAIN NOW' : 'ALLENATI ORA';
  static String get train2 => _lang == 'en' ? 'TRAIN' : 'ALLENATI';
  static String get chooseAndStart => _lang == 'en'
      ? 'Choose and start your workout'
      : 'Scegli e inizia il tuo allenamento';
  static String get createFirstSchedule => _lang == 'en'
      ? 'Create your schedule before training'
      : 'Crea la tua scheda prima di allenarti';
  static String get workoutProgress =>
      _lang == 'en' ? 'WORKOUT PROGRESS' : 'ANDAMENTO ALLENAMENTO';
  static String get neverTrained =>
      _lang == 'en' ? 'Never trained' : 'Mai allenato';
  static String get today => _lang == 'en' ? 'Today' : 'Oggi';
  static String get yesterday => _lang == 'en' ? 'Yesterday' : 'Ieri';
  static String get daysAgo => _lang == 'en' ? 'days ago' : 'giorni fa';
  static String get others => _lang == 'en' ? 'others' : 'altri';
  static String get timerSound =>
      _lang == 'en' ? 'Timer sound' : 'Suono fine timer';
  static String get timerVibration =>
      _lang == 'en' ? 'Timer vibration' : 'Vibrazione fine timer';
  static String get autoStartTimer =>
      _lang == 'en' ? 'Auto-start timer' : 'Avvia timer automaticamente';
  static String get screenAlwaysOn =>
      _lang == 'en' ? 'Screen always on' : 'Schermo sempre acceso';
  static String get confirmSeriesWindow =>
      _lang == 'en' ? 'Set confirmation window' : 'Finestra di conferma serie';
  static String get weightSuggestion => _lang == 'en'
      ? 'Weight increase suggestion'
      : 'Suggerimento aumento peso';
  static String get dataManagement =>
      _lang == 'en' ? 'Data Management' : 'Gestione Dati';
  static String get insertKg => _lang == 'en' ? 'Enter KG' : 'Inserisci KG';
  static String get insertReps =>
      _lang == 'en' ? 'Enter REPS' : 'Inserisci REPS';
  static String get enterKgReps => _lang == 'en'
      ? 'Enter kg and reps before confirming'
      : 'Inserisci kg e reps prima di confermare';
  static String get saveSeries => _lang == 'en' ? 'SAVE SET' : 'SALVA SERIE';
  static String get confirmSeries =>
      _lang == 'en' ? 'CONFIRM SET' : 'CONFERMA SERIE';
  static String get quitWorkout => _lang == 'en' ? 'Quit?' : 'Interrompere?';
  static String get quitWorkoutMsg => _lang == 'en'
      ? 'Do you really want to exit? Progress made so far is saved.'
      : 'Vuoi davvero uscire dall\'allenamento? I progressi fin qui fatti sono comunque salvati.';
  static String get exitAndSave =>
      _lang == 'en' ? 'EXIT & SAVE' : 'ESCI E SALVA';
  static String get exerciseComplete =>
      _lang == 'en' ? 'EXERCISE COMPLETED' : 'ESERCIZIO COMPLETATO';
  static String get exerciseCompleteMsg => _lang == 'en'
      ? 'Data has been saved and cannot be modified.'
      : 'I dati sono stati salvati e non sono più modificabili.';
  static String get nextInfo => _lang == 'en' ? 'NEXT' : 'PROSSIMA';
  static String get lastTime => _lang == 'en' ? 'LAST TIME' : 'ULTIMA VOLTA';
  static String get increaseWeight =>
      _lang == 'en' ? 'INCREASE WEIGHT' : 'AUMENTA IL PESO';
  static String get increase => _lang == 'en' ? 'INCREASE' : 'AUMENTA';
  static String get workoutComplete =>
      _lang == 'en' ? 'WORKOUT COMPLETE!' : 'ALLENAMENTO COMPLETATO!';
  static String get firstSession =>
      _lang == 'en' ? 'First session!' : 'Prima sessione!';
  static String get improving =>
      _lang == 'en' ? 'Improving!' : 'In miglioramento!';
  static String get declining => _lang == 'en' ? 'Declining' : 'In calo';
  static String get plateau => _lang == 'en' ? 'Plateau' : 'Stallo';
  static String get details => _lang == 'en' ? 'DETAILS' : 'DETTAGLI';
  static String get greatWork =>
      _lang == 'en' ? 'GREAT JOB!' : 'OTTIMO LAVORO!';
  static String get workoutSummary =>
      _lang == 'en' ? 'Workout summary' : 'Riepilogo allenamento';
  static String get close => _lang == 'en' ? 'CLOSE' : 'CHIUDI';
  static String get totalSeries =>
      _lang == 'en' ? 'Total sets' : 'Serie totali';
  static String get exercisesLabel => _lang == 'en' ? 'Exercises' : 'Esercizi';
  static String get primaryMuscle =>
      _lang == 'en' ? 'PRIMARY MUSCLE' : 'MUSCOLO PRINCIPALE';
  static String get secondaryMuscles =>
      _lang == 'en' ? 'SECONDARY MUSCLES' : 'MUSCOLI SECONDARI';
  static String get execution =>
      _lang == 'en' ? '📋 EXECUTION' : '📋 ESECUZIONE';
  static String get tips => _lang == 'en' ? '💡 TIPS' : '💡 CONSIGLI';
  static String get notInCatalog => _lang == 'en'
      ? 'Exercise not in catalog.\nUse YouTube to watch the technique.'
      : 'Esercizio non in catalogo.\nUsa YouTube per vedere la tecnica.';
  static String get notInCatalogShort =>
      _lang == 'en' ? 'Exercise not in catalog.' : 'Esercizio non in catalogo.';
  static String get watchOnYoutube =>
      _lang == 'en' ? 'Watch on YouTube' : 'Guarda su YouTube';
  static String get progressOverTime => _lang == 'en'
      ? 'Progress over time — one line per set'
      : 'Progressi nel tempo — una linea per serie';
  static String get noData => _lang == 'en' ? 'No data' : 'Nessun dato';
  static String get noDataRegistered =>
      _lang == 'en' ? 'No recorded data' : 'Nessun dato registrato';
  static String get myNotes => _lang == 'en' ? 'My notes...' : 'Le mie note...';
  static String get coachNotes => _lang == 'en' ? 'COACH' : 'COACH';
  static String get setsDone => _lang == 'en' ? 'SETS DONE' : 'SERIE FATTE';
  static String get of => _lang == 'en' ? 'OF' : 'DI';
  static String get changeExercise =>
      _lang == 'en' ? 'CHANGE EXERCISE' : 'CAMBIO ESERCIZIO';
  static String get noHistory =>
      _lang == 'en' ? 'No history' : 'Nessuno storico presente';
  static String get deleteSelected =>
      _lang == 'en' ? 'Delete selected' : 'Elimina selezionati';
  static String get totalReset =>
      _lang == 'en' ? 'TOTAL RESET' : 'RESET TOTALE';
  static String get fullReset =>
      _lang == 'en' ? 'Full data reset' : 'Reset completo dati';
  static String get fullResetTitle =>
      _lang == 'en' ? 'Full reset' : 'Reset completo';
  static String get fullResetMsg => _lang == 'en'
      ? 'Will delete ALL data: schedule, history and settings.'
      : 'Eliminerà TUTTI i dati: scheda, storico e impostazioni.';
  static String get continueLabel => _lang == 'en' ? 'CONTINUE' : 'CONTINUA';
  static String get areYouSure =>
      _lang == 'en' ? 'Are you sure?' : 'Sei sicuro?';
  static String get irreversible => _lang == 'en'
      ? 'This operation is irreversible.'
      : 'Operazione irreversibile.';
  static String get deleteAll =>
      _lang == 'en' ? 'DELETE ALL' : 'CANCELLA TUTTO';
  static String get noSession =>
      _lang == 'en' ? 'No sessions' : 'Nessuna sessione';
  static String get deleteSession =>
      _lang == 'en' ? 'Delete session?' : 'Elimina sessione?';
  static String get deleteSessionMsg => _lang == 'en'
      ? 'All data from this session will be deleted.'
      : 'Tutti i dati di questa sessione verranno eliminati.';
  static String get sessionDeleted =>
      _lang == 'en' ? 'Session deleted' : 'Sessione eliminata';
  static String get deleteSeries =>
      _lang == 'en' ? 'Delete set?' : 'Elimina serie?';
  static String get dataDeleted =>
      _lang == 'en' ? 'Data deleted' : 'Dati eliminati';
  static String get skipUseButton => _lang == 'en'
      ? 'Use the SKIP button to return to the exercise'
      : 'Usa il tasto \'SKIP\' per tornare all\'esercizio';
  static String get restoreWorkout => _lang == 'en'
      ? '♻️ Previous workout restored'
      : '♻️ Allenamento precedente ripristinato';
  static String get workoutNotDone => _lang == 'en'
      ? 'You completed this exercise, but there are more! Use the arrows.'
      : 'Hai completato questo esercizio, ma ne mancano altri! Usa le frecce.';
  static String get proFeature1 => _lang == 'en'
      ? '✅ Personalized schedules for each athlete'
      : '✅ Schede personalizzate per ogni atleta';
  static String get proFeature2 => _lang == 'en'
      ? '✅ Real-time progress monitoring'
      : '✅ Monitoraggio progressi in tempo reale';
  static String get proFeature3 => _lang == 'en'
      ? '✅ Shared exercise database'
      : '✅ Database esercizi condiviso';
  static String get proFeature4 => _lang == 'en'
      ? '✅ No monthly subscriptions'
      : '✅ Senza abbonamenti mensili';
  static String get gymAppPro =>
      _lang == 'en' ? 'GymApp Pro - For PT' : 'GymApp Pro - Per PT';
  static String get recoverySuffix => _lang == 'en' ? 's rest' : 's riposo';
  static String get sessionCount => _lang == 'en' ? 'session' : 'session';
  static String get sessionCountPlural =>
      _lang == 'en' ? 'sessions' : 'sessioni';
  static String get loadExample =>
      _lang == 'en' ? 'Load example' : 'Carica esempio';
  static String get renameSession =>
      _lang == 'en' ? 'Rename session' : 'Rinomina sessione';
  static String get sessionName =>
      _lang == 'en' ? 'Session name' : 'Nome sessione';
  static String get editExercise =>
      _lang == 'en' ? 'Edit exercise' : 'Modifica esercizio';
  static String get streakWeeks =>
      _lang == 'en' ? 'Week streak' : 'Microcicli di fila';
  static String get streakMsg => _lang == 'en'
      ? '🔥 Keep your streak alive!'
      : '🔥 Mantieni la tua streak!';
  static String get newRecord =>
      _lang == 'en' ? 'NEW RECORD!' : 'NUOVO RECORD!';
}

double kgToLb(double kg) => kg * 2.2046226218;

double lbToKg(double lb) => lb / 2.2046226218;

String formatWeightValue(
  double kg, {
  bool usePounds = false,
  int maxDecimals = 2,
}) {
  final value = usePounds ? kgToLb(kg) : kg;
  final fixed = value.toStringAsFixed(maxDecimals);
  return fixed.contains('.')
      ? fixed.replaceFirst(RegExp(r'\.?0+$'), '')
      : fixed;
}

const String kWorkoutNativeAdFactoryId = 'workout_native';
const String kWorkoutInlineNativeAdUnitId =
    'ca-app-pub-2556899149200560/1884973095';
const String kConfirmPopupNativeAdUnitId =
    'ca-app-pub-2556899149200560/9356269000';
const String kTimerRestNativeAdUnitId =
    'ca-app-pub-2556899149200560/7742361478';
const String kWorkoutStartNativeAdUnitId =
    'ca-app-pub-2556899149200560/1171323500';
const String kWorkoutRecapNativeAdUnitId =
    'ca-app-pub-2556899149200560/8785030152';
const String kExerciseListNativeAdUnitId =
    'ca-app-pub-2556899149200560/5601523103';
const String kChartsNativeAdUnitId = 'ca-app-pub-2556899149200560/5601523103';
const String kWorkoutProgressNativeAdUnitId =
    'ca-app-pub-2556899149200560/3760460847';
const String kOverallProgressNativeAdUnitId =
    'ca-app-pub-2556899149200560/8735561710';
const String kTutorialNativeAdUnitId = 'ca-app-pub-2556899149200560/4047708794';
const String _webDonationPromptedAtKey = 'web_donation_prompted_at';
const String _webDonationProceededAtKey = 'web_donation_proceeded_at';
const String _webDonationReceiptKey = 'web_donation_receipt_id';
const String _webIosInstallHintSeenKey = 'web_ios_install_hint_seen';
const String _webDonationBannerDismissedAtKey = 'web_donation_banner_dismissed_at';
const Duration _webDonationGracePeriod = Duration(days: 30);
const Duration _webDonationBannerHideDuration = Duration(days: 7);

Future<void> openPaypalDonationPage() async {
  final uri = Uri.parse('https://paypal.me/gianmarcosare');
  if (kIsWeb) {
    await launchUrl(uri, webOnlyWindowName: '_blank');
    return;
  }
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<void> _recordWebDonationPromptIfNeeded() async {
  if (!kIsWeb) return;
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getString(_webDonationPromptedAtKey) == null) {
    await prefs.setString(
      _webDonationPromptedAtKey,
      DateTime.now().toIso8601String(),
    );
  }
}

Future<void> _recordWebDonationProceed(String receiptId) async {
  if (!kIsWeb) return;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    _webDonationProceededAtKey,
    DateTime.now().toIso8601String(),
  );
  await prefs.setString(_webDonationReceiptKey, receiptId.trim().toUpperCase());
}

Future<bool> _isWebDonationLocked() async {
  if (!kIsWeb) return false;
  final prefs = await SharedPreferences.getInstance();
  final acknowledgedAtRaw = prefs.getString(_webDonationProceededAtKey);
  final receiptId = prefs.getString(_webDonationReceiptKey)?.trim() ?? '';
  if (acknowledgedAtRaw != null && receiptId.isNotEmpty) return false;
  final promptedAtRaw = prefs.getString(_webDonationPromptedAtKey);
  if (promptedAtRaw == null) return false;
  final promptedAt = DateTime.tryParse(promptedAtRaw);
  if (promptedAt == null) return false;
  return DateTime.now().difference(promptedAt) >= _webDonationGracePeriod;
}

Future<({bool locked, bool acknowledged, int daysLeft})>
getWebDonationGateState() async {
  if (!kIsWeb) {
    return (locked: false, acknowledged: true, daysLeft: 999);
  }
  final prefs = await SharedPreferences.getInstance();
  final now = DateTime.now();
  final promptedAtRaw = prefs.getString(_webDonationPromptedAtKey);
  final acknowledgedAtRaw = prefs.getString(_webDonationProceededAtKey);
  final receiptId = prefs.getString(_webDonationReceiptKey)?.trim() ?? '';

  DateTime? promptedAt = DateTime.tryParse(promptedAtRaw ?? '');
  final acknowledgedAt = DateTime.tryParse(acknowledgedAtRaw ?? '');
  if (promptedAt == null) {
    promptedAt = now;
    await prefs.setString(_webDonationPromptedAtKey, now.toIso8601String());
  }

  final anchor = acknowledgedAt ?? promptedAt;
  final daysSince = now.difference(anchor).inDays;
  final daysLeft = scala.max(0, _webDonationGracePeriod.inDays - daysSince);
  return (
    locked: acknowledgedAt == null || receiptId.isEmpty
        ? daysSince >= _webDonationGracePeriod.inDays
        : false,
    acknowledged: acknowledgedAt != null && receiptId.isNotEmpty,
    daysLeft: daysLeft,
  );
}

class AdManager {
  AdManager._();
  static final AdManager instance = AdManager._();

  InterstitialAd? _finishInterstitialAd;
  InterstitialAd? _startInterstitialAd;
  bool _isFinishAdLoaded = false;
  bool _isStartAdLoaded = false;

  static const String _finishInterstitialAdUnitId =
      'ca-app-pub-2556899149200560/4751310597';
  static const String _startInterstitialAdUnitId =
      'ca-app-pub-2556899149200560/8622605985';
  static const String bannerAdUnitId = 'ca-app-pub-2556899149200560/2699862325';

  void loadInterstitial() {
    _loadFinishInterstitial();
    _loadStartInterstitial();
  }

  void _loadFinishInterstitial() {
    InterstitialAd.load(
      adUnitId: _finishInterstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _finishInterstitialAd = ad;
          _isFinishAdLoaded = true;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _finishInterstitialAd = null;
              _isFinishAdLoaded = false;
              _loadFinishInterstitial();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _finishInterstitialAd = null;
              _isFinishAdLoaded = false;
              _loadFinishInterstitial();
            },
          );
        },
        onAdFailedToLoad: (error) {
          _isFinishAdLoaded = false;
          debugPrint('Finish interstitial failed to load: $error');
        },
      ),
    );
  }

  void _loadStartInterstitial() {
    InterstitialAd.load(
      adUnitId: _startInterstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _startInterstitialAd = ad;
          _isStartAdLoaded = true;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _startInterstitialAd = null;
              _isStartAdLoaded = false;
              _loadStartInterstitial();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _startInterstitialAd = null;
              _isStartAdLoaded = false;
              _loadStartInterstitial();
            },
          );
        },
        onAdFailedToLoad: (error) {
          _isStartAdLoaded = false;
          debugPrint('Start interstitial failed to load: $error');
        },
      ),
    );
  }

  void showInterstitialThenRun(VoidCallback onComplete) {
    if (kIsWeb) {
      onComplete();
      return;
    }
    if (_isFinishAdLoaded && _finishInterstitialAd != null) {
      _finishInterstitialAd!.fullScreenContentCallback =
          FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _finishInterstitialAd = null;
              _isFinishAdLoaded = false;
              _loadFinishInterstitial();
              onComplete();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _finishInterstitialAd = null;
              _isFinishAdLoaded = false;
              _loadFinishInterstitial();
              onComplete();
            },
          );
      _finishInterstitialAd!.show();
    } else {
      _loadFinishInterstitial();
      onComplete();
    }
  }

  void showStartInterstitialThenRun(VoidCallback onComplete) {
    if (kIsWeb) {
      onComplete();
      return;
    }
    if (_isStartAdLoaded && _startInterstitialAd != null) {
      _startInterstitialAd!.fullScreenContentCallback =
          FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _startInterstitialAd = null;
              _isStartAdLoaded = false;
              _loadStartInterstitial();
              onComplete();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _startInterstitialAd = null;
              _isStartAdLoaded = false;
              _loadStartInterstitial();
              onComplete();
            },
          );
      _startInterstitialAd!.show();
    } else {
      _loadStartInterstitial();
      onComplete();
    }
  }
}

class GymAppHome extends StatefulWidget {
  const GymAppHome({super.key});
  @override
  State<GymAppHome> createState() => _GymAppHomeState();
}

class _GymAppHomeState extends State<GymAppHome> {
  bool _loading = true;
  bool _langChosen = false;
  bool _onboardingDone = false;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final langChosen = prefs.getBool('lang_chosen') ?? false;
    final done = prefs.getBool('onboarding_done') ?? false;
    final lang = prefs.getString('app_lang') ?? 'it';
    AppL.setLang(lang);
    if (mounted)
      setState(() {
        _langChosen = langChosen;
        _onboardingDone = done;
        _loading = false;
      });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0A0A),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_langChosen) {
      return const LanguagePickerScreen();
    }
    if (!_onboardingDone) {
      return const OnboardingScreen();
    }
    return const ClientMainPage();
  }
}

class LanguagePickerScreen extends StatelessWidget {
  const LanguagePickerScreen({super.key});

  Future<void> _choose(BuildContext context, String lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_lang', lang);
    await prefs.setBool('lang_chosen', true);
    AppL.setLang(lang);
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🌍', style: TextStyle(fontSize: 72)),
                const SizedBox(height: 32),
                const Text(
                  'Scegli la lingua\nChoose your language',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => _choose(context, 'it'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00F2FF),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      '🇮🇹  Italiano',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => _choose(context, 'en'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white12,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: Colors.white24),
                      ),
                    ),
                    child: const Text(
                      '🇬🇧  English',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageCtrl = PageController();
  int _currentPage = 0;

  List<_OnboardingPage> get _pages => [
    _OnboardingPage(
      icon: '🏋️',
      title: AppL.welcomeTitle,
      text: AppL.onboardingWelcomeText,
    ),
    _OnboardingPage(
      icon: '📋',
      title: AppL.onboardingScheduleTitle,
      text: AppL.onboardingScheduleText,
    ),
    _OnboardingPage(
      icon: '⏱️',
      title: AppL.onboardingTrainTitle,
      text: AppL.onboardingTrainText,
    ),
    _OnboardingPage(
      icon: '📊',
      title: AppL.onboardingProgressTitle,
      text: AppL.onboardingProgressText,
    ),
    _OnboardingPage(
      icon: '👨‍💼',
      title: AppL.proTrainer,
      text: AppL.onboardingProText,
      isPromo: true,
    ),
  ];

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ClientMainPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF00F2FF);
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _pages.length,
                itemBuilder: (_, i) => _buildPage(_pages[i], accent),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 16,
                  ),
                  width: _currentPage == i ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == i ? accent : Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: _currentPage == _pages.length - 1
                  ? SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _completeOnboarding,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          AppL.startBtn,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    )
                  : SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () => _pageCtrl.nextPage(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOut,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          AppL.nextBtn,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(_OnboardingPage page, Color accent) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(page.icon, style: const TextStyle(fontSize: 72)),
          const SizedBox(height: 32),
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            page.text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 16,
              height: 1.6,
            ),
          ),
          if (page.isPromo) ...[
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: () async {
                final uri = Uri.parse('mailto:osare199@gmail.com');
                if (await canLaunchUrl(uri)) await launchUrl(uri);
              },
              icon: const Text('📧', style: TextStyle(fontSize: 18)),
              label: Text(AppL.contactGianmarco),
              style: OutlinedButton.styleFrom(
                foregroundColor: accent,
                side: BorderSide(color: accent.withAlpha(120)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppL.proInfoText,
              style: const TextStyle(color: Colors.white30, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _OnboardingPage {
  final String icon;
  final String title;
  final String text;
  final bool isPromo;
  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.text,
    this.isPromo = false,
  });
}

/// Mappa parole chiave italiane → termini inglesi per la ricerca esercizi
const Map<String, List<String>> kItalianKeywords = {
  'panca': ['bench'],
  'petto': ['chest', 'pec', 'bench', 'fly', 'push'],
  'dorsale': ['lat', 'pulldown', 'pull', 'row'],
  'rematore': ['row'],
  'tirate': ['pulldown', 'pull'],
  'bicipite': ['curl', 'bicep'],
  'tricipite': ['tricep', 'extension', 'pushdown', 'dip'],
  'spalla': ['shoulder', 'press', 'raise', 'delt', 'arnold'],
  'squat': ['squat'],
  'affondi': ['lunge'],
  'stacco': ['deadlift'],
  'curl': ['curl'],
  'croci': ['fly', 'flye', 'crossover'],
  'pressa': ['press', 'leg press'],
  'gambe': ['leg', 'squat', 'lunge'],
  'glutei': ['glute', 'hip', 'bridge'],
  'addome': ['ab', 'crunch', 'plank', 'core'],
  'plank': ['plank'],
  'polpaccio': ['calf', 'raise'],
  'pull': ['pull', 'pulldown', 'pullup'],
  'push': ['push', 'press'],
  'dip': ['dip'],
  'manubri': ['dumbbell'],
  'bilanciere': ['barbell'],
  'cavo': ['cable'],
  'corda': ['rope'],
  'kettlebell': ['kettlebell'],
  'alzate': ['raise', 'lateral', 'front'],
  'lat': ['lat', 'pulldown'],
  'lombari': ['back extension', 'hyperextension', 'deadlift'],
  'adduttori': ['adductor'],
  'abduttori': ['abductor'],
};

/// Cerca esercizi nel catalogo con supporto parole chiave italiane.
/// Restituisce al massimo [limit] risultati.
List<ExerciseInfo> searchExercisesWithItalian(String query, {int limit = 6}) {
  if (query.length < 2) return [];
  final q = query.toLowerCase().trim();
  final results = <ExerciseInfo>[];
  final seen = <String>{};

  void tryAdd(ExerciseInfo ex) {
    if (seen.add(ex.name) && results.length < limit) results.add(ex);
  }

  if (AppL.lang == 'en') {
    // EN mode: search kGifCatalog (English names) first, then kExerciseCatalog by nameEn
    for (final ex in kGifCatalog) {
      if (ex.name.toLowerCase().contains(q) ||
          ex.nameEn.toLowerCase().contains(q)) {
        tryAdd(ex);
      }
    }
    for (final ex in kExerciseCatalog) {
      if (ex.nameEn.toLowerCase().contains(q) ||
          ex.aliases.any((a) => a.toLowerCase().contains(q))) {
        tryAdd(ex);
      }
    }
    return results;
  }

  // IT mode: cerca prima nel catalogo italiano, poi GIF, poi keywords
  // 1. Match diretto nel catalogo italiano (kExerciseCatalog) — nomi IT come "Trazioni"
  for (final ex in kExerciseCatalog) {
    if (ex.name.toLowerCase().contains(q) ||
        ex.nameEn.toLowerCase().contains(q) ||
        ex.aliases.any((a) => a.toLowerCase().contains(q))) {
      tryAdd(ex);
    }
  }

  // 2. Match diretto nel catalogo GIF (nomi EN) — es. "Pull-Up", "Bench Press"
  for (final ex in kGifCatalog) {
    if (ex.name.toLowerCase().contains(q) ||
        ex.nameEn.toLowerCase().contains(q)) {
      tryAdd(ex);
    }
  }

  // 3. Match tramite parole chiave italiane → inglese
  if (results.length < limit) {
    for (final entry in kItalianKeywords.entries) {
      if (entry.key.contains(q) || q.contains(entry.key)) {
        for (final eng in entry.value) {
          for (final ex in kGifCatalog) {
            if (ex.name.toLowerCase().contains(eng) ||
                ex.nameEn.toLowerCase().contains(eng)) {
              tryAdd(ex);
              if (results.length >= limit) return results;
            }
          }
        }
      }
    }
  }

  return results;
}

// --- STREAK SYSTEM ---

/// Restituisce la stringa ISO-week "YYYY-Www" per la data fornita.
String _isoWeek(DateTime d) {
  final thursday = d.add(Duration(days: 4 - (d.weekday == 7 ? 0 : d.weekday)));
  final year = thursday.year;
  final startOfYear = DateTime(year, 1, 1);
  final weekNum = ((thursday.difference(startOfYear).inDays) / 7).ceil() + 1;
  return '$year-W${weekNum.toString().padLeft(2, '0')}';
}

/// Aggiorna la streak dopo aver completato una sessione.
/// [dayName] = nome del giorno completato
/// [totalSessionNames] = nomi di tutti i giorni nella scheda
Future<int> updateStreak(String dayName, List<String> totalSessionNames) async {
  final prefs = await SharedPreferences.getInstance();
  final now = DateTime.now();
  int streak = prefs.getInt('streak_count') ?? 0;

  // Sessioni già completate nel microciclo corrente
  final microJson = prefs.getString('microcycle_done') ?? '[]';
  Set<String> microDone = Set<String>.from(jsonDecode(microJson));
  // Rimuovi sessioni non più presenti nella scheda
  if (totalSessionNames.isNotEmpty) {
    microDone = microDone.intersection(Set<String>.from(totalSessionNames));
  }

  // REGOLA 7 GIORNI: se una sessione del piano non è stata fatta da >7 giorni → reset streak
  for (final name in totalSessionNames) {
    if (name == dayName) continue;
    final lastStr = prefs.getString('last_session_date_$name');
    if (lastStr != null) {
      final last = DateTime.tryParse(lastStr);
      if (last != null && now.difference(last).inDays > 13) {
        streak = 0;
        break;
      }
    }
  }

  // LOGICA MICROCICLO
  final bool newCycleStarting = microDone.isEmpty;
  if (microDone.contains(dayName)) {
    // Questa sessione era già nel microciclo corrente → microciclo incompleto, si ricomincia
    streak = 0;
    microDone = {dayName};
    await prefs.remove('microcycle_completed_at');
  } else {
    if (newCycleStarting) {
      // Prima sessione del nuovo microciclo — cancella lo stato "appena completato"
      await prefs.remove('microcycle_completed_at');
    }
    microDone.add(dayName);
    // Microciclo completo quando tutte le sessioni sono state fatte
    if (totalSessionNames.isNotEmpty &&
        totalSessionNames.every((n) => microDone.contains(n))) {
      streak++;
      await prefs.setString('microcycle_completed_at', now.toIso8601String());
      await prefs.setString('microcycle_last_sessions', jsonEncode(microDone.toList()));
      microDone = {}; // Azzera per il prossimo microciclo
    }
  }

  await prefs.setInt('streak_count', streak);
  await prefs.setString('microcycle_done', jsonEncode(microDone.toList()));
  await prefs.setString('last_session_date_$dayName', now.toIso8601String());
  await prefs.setString('last_workout_date', now.toIso8601String());

  // Gestisci il reset dei badge
  await manageBadgeReset();

  return streak;
}

/// Legge il valore attuale della streak.
Future<int> getStreak() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt('streak_count') ?? 0;
}

/// Legge streak count + sessioni completate nel microciclo corrente.
Future<({int count, Set<String> done})> getStreakData() async {
  final prefs = await SharedPreferences.getInstance();
  final count = prefs.getInt('streak_count') ?? 0;
  final json = prefs.getString('microcycle_done') ?? '[]';
  Set<String> done = Set<String>.from(jsonDecode(json));
  // Se il microciclo è stato appena completato (< 2 giorni fa) e non è ancora
  // iniziato il successivo, mostra tutti i badge come conquistati
  if (done.isEmpty) {
    final completedAtStr = prefs.getString('microcycle_completed_at');
    if (completedAtStr != null) {
      final completedAt = DateTime.tryParse(completedAtStr);
      if (completedAt != null && DateTime.now().difference(completedAt).inDays < 2) {
        final lastJson = prefs.getString('microcycle_last_sessions') ?? '[]';
        done = Set<String>.from(jsonDecode(lastJson));
      }
    }
  }
  return (count: count, done: done);
}

/// Gestisce il reset dei badge se 1 settimana dal primo conquistato OR nuovo microciclo
Future<void> manageBadgeReset() async {
  final prefs = await SharedPreferences.getInstance();
  final now = DateTime.now();
  final thisWeek = _isoWeek(now);
  
  // Data di quando è stato conquistato il primo badge
  final badgesStartStr = prefs.getString('badges_start_date');
  if (badgesStartStr == null) {
    // Primo accesso, salva la data
    await prefs.setString('badges_start_date', now.toIso8601String());
    return;
  }
  
  final badgesStart = DateTime.tryParse(badgesStartStr);
  if (badgesStart == null) return;
  
  // Controlla se è passata 1 settimana
  final daysPassed = now.difference(badgesStart).inDays;
  final shouldResetByTime = daysPassed >= 7;
  
  // Controlla se è iniziato un nuovo microciclo
  final lastBadgeMicrocycleWeek = prefs.getString('last_badge_microcycle_week') ?? '';
  final currentMicrocycleWeek = prefs.getString('current_microcycle_week') ?? thisWeek;
  final shouldResetByMicrocycle = lastBadgeMicrocycleWeek.isNotEmpty && lastBadgeMicrocycleWeek != currentMicrocycleWeek;
  
  if (shouldResetByTime || shouldResetByMicrocycle) {
    // Reset badge
    await prefs.remove('badges_start_date');
    if (shouldResetByTime) {
      await prefs.setString('last_badge_reset_week', thisWeek);
    }
  } else {
    // Aggiorna il microciclo corrente
    await prefs.setString('current_microcycle_week', thisWeek);
  }
}

/// Controlla se l'utente non si allena da più di 2 giorni e mostra notifica giornaliera.
Future<void> checkAndScheduleStreakNotification(String lang) async {
  if (kIsWeb) return;
  final prefs = await SharedPreferences.getInstance();
  final lastStr = prefs.getString('last_workout_date');
  if (lastStr == null) return;
  final last = DateTime.tryParse(lastStr);
  if (last == null) return;
  final daysSince = DateTime.now().difference(last).inDays;
  if (daysSince >= 2) {
    const channelId = 'streak_reminder';
    const androidDetails = AndroidNotificationDetails(
      channelId,
      'Streak Reminder',
      channelDescription: 'Remind user to train to keep their streak',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_notification',
    );
    final title = lang == 'en'
        ? '🔥 Keep your streak alive!'
        : '🔥 Non perdere i tuoi progressi!';
    final body = lang == 'en'
        ? "You haven't trained in $daysSince days. Train today to keep your progress!"
        : "Non ti alleni da $daysSince giorni. Allenati oggi per non perdere i tuoi progressi!";
    await flutterLocalNotificationsPlugin.show(
      9902,
      title,
      body,
      const NotificationDetails(android: androidDetails),
    );
  }
}

/// Pianifica notifica streak giornaliera 48h dopo l'ultimo allenamento, poi ripete ogni giorno.
/// Chiamare dopo ogni allenamento completato per resettare il timer.
Future<void> scheduleStreakReminder(String lang) async {
  if (kIsWeb) return;
  try {
    await flutterLocalNotificationsPlugin.cancel(9901);
    try {
      await _gymFileChannel.invokeMethod('cancelStreakReminderNotification');
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    final lastStr = prefs.getString('last_workout_date');
    final lastWorkout =
        DateTime.tryParse(lastStr ?? '')?.toLocal() ?? DateTime.now();
    final scheduledDate = lastWorkout.add(const Duration(hours: 48));
    final title = lang == 'en'
        ? '🔥 Keep your streak alive!'
        : '🔥 Non perdere i tuoi progressi!';
    final body = lang == 'en'
        ? "You haven't trained in 2 days. Train today to keep your progress!"
        : "Non ti alleni da 2 giorni. Allenati oggi per non perdere i tuoi progressi!";
    if (Platform.isAndroid) {
      final delayMs = scheduledDate
          .difference(DateTime.now())
          .inMilliseconds
          .clamp(0, 2147483647);
      await _gymFileChannel.invokeMethod('scheduleStreakReminderNotification', {
        'delayMs': delayMs,
        'title': title,
        'body': body,
      });
      return;
    }
    await flutterLocalNotificationsPlugin.zonedSchedule(
      9901,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'streak_reminder',
          'Streak Reminder',
          channelDescription: 'Remind user to train to keep their streak',
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_notification',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  } catch (e) {
    debugPrint('scheduleStreakReminder: $e');
  }
}

// --- TRADUZIONE MUSCOLI E TESTO ESERCIZI IT → EN ---

/// Traduce i nomi dei muscoli dall'italiano all'inglese quando la lingua è EN.
String translateMuscle(String italian) {
  if (AppL.lang != 'en' || italian.isEmpty) return italian;
  const m = {
    'Gran dorsale': 'Latissimus Dorsi',
    'Romboidi': 'Rhomboids',
    'Grande pettorale': 'Pectoralis Major',
    'Gran pettorale': 'Pectoralis Major',
    'Pettorale minore': 'Pectoralis Minor',
    'Bicipiti': 'Biceps',
    'Tricipiti': 'Triceps',
    'Deltoidi anteriori': 'Front Deltoids',
    'Deltoide anteriore': 'Front Deltoid',
    'Deltoide laterale': 'Lateral Deltoid',
    'Deltoide posteriore': 'Rear Deltoid',
    'Brachioradiale': 'Brachioradialis',
    'Deltoide (fascio anteriore e laterale)': 'Deltoid (front & lateral)',
    'Deltoide (tutte le fasce)': 'Deltoid (all heads)',
    'Deltoide': 'Deltoid',
    'Trapezio superiore': 'Upper Trapezius',
    'Trapezio medio': 'Mid Trapezius',
    'Trapezio': 'Trapezius',
    'Serratura anteriore': 'Serratus Anterior',
    'Quadricipiti': 'Quadriceps',
    'Femorali': 'Hamstrings',
    'Ischiocrurali': 'Hamstrings',
    'Gluteo grande': 'Gluteus Maximus',
    'Gluteo medio': 'Gluteus Medius',
    'Gluteo minore': 'Gluteus Minimus',
    'Glutei': 'Glutes',
    'Polpacci': 'Calves',
    'Gastrocnemio': 'Gastrocnemius',
    'Soleo': 'Soleus',
    'Adduttori dell\'anca': 'Hip Adductors',
    'Adduttori': 'Adductors',
    'Abduttori': 'Abductors',
    'Flessori anca': 'Hip Flexors',
    'Flessori avambraccio': 'Forearm Flexors',
    'Avambracci': 'Forearms',
    'Lombari': 'Lower Back',
    'Erettori spinali': 'Spinal Erectors',
    'Rettosaddominale (fascio inferiore)': 'Lower Rectus Abdominis',
    'Rettosaddominale': 'Rectus Abdominis',
    'Obliqui': 'Obliques',
    'Trasverso addome': 'Transverse Abdominis',
    'Sovraspinato': 'Supraspinatus',
    'Grande rotondo': 'Teres Major',
    'Piccolo rotondo': 'Teres Minor',
    'Piriforme': 'Piriformis',
    'Gracile': 'Gracilis',
    'Pettineo': 'Pectineus',
    'Bicipiti (picco)': 'Biceps (peak)',
    'Bicipiti, Brachioradiale': 'Biceps, Brachioradialis',
    'Tricipiti (capo laterale)': 'Triceps (lateral head)',
    'Tricipiti (capo lungo)': 'Triceps (long head)',
    'Capo laterale e mediale': 'Lateral and medial heads',
    'Petto superiore (clavicolare)': 'Upper chest (clavicular head)',
    'Petto (grande pettorale)': 'Chest (pectoralis major)',
    'Glutei (grande gluteo)': 'Glutes (gluteus maximus)',
    'Muscolatura principale coinvolta': 'Main muscles',
    'Muscolatura di supporto': 'Supporting muscles',
    'Mobilità articolare generale': 'General joint mobility',
    'Sistema cardiovascolare': 'Cardiovascular system',
    'Polpacci, Sistema cardiovascolare': 'Calves, Cardiovascular system',
    'Core': 'Core',
    'Spalle': 'Shoulders',
    'Dorso': 'Back',
    'Gambe': 'Legs',
    'Braccia': 'Arms',
  };
  // Sort by length descending to match longer phrases first
  final sorted = m.entries.toList()
    ..sort((a, b) => b.key.length.compareTo(a.key.length));
  String result = italian;
  for (final e in sorted) {
    result = result.replaceAll(e.key, e.value);
  }
  return result;
}

String _normalizeExerciseText(String text) =>
    text.replaceAll('’', "'").trim().replaceAll(RegExp(r'\s+'), ' ');

bool _containsItalianMarkers(String text) {
  final normalized = _normalizeExerciseText(text).toLowerCase();
  final markerRegex = RegExp(
    r"\b(?:il|lo|la|le|gli|dei|delle|della|dello|degli|con|verso|durante|mantieni|controlla|evita|abbassa|alz[aei]|spingi|tira|porta|respira|schiena|petto|gomiti|gomito|ginocchio|ginocchia|fianchi|busto|addome|glute[io]|allungamento|slancio|discesa|salita|panca|cavo|manubri?|bilanciere|sbarra|presa|prona|supinata|neutra|punta|piede|piedi|polsi?|spalle|avambracci|quadricipiti|femorali|lombare|lombari|tallone|talloni|contrazione|allinea|ruota|macchina|lateralmente|indietro|avanti|sdraiati|siediti|afferra|estendi|fletti|contrai|dondolare|concentrati|retrai|tecnica|muscoli|completa|padroneggiare|ascendente|discendente|eccentrica|concentrica|collo|orecchie)\b",
  );
  return markerRegex.hasMatch(normalized);
}

String _fallbackEnglishExerciseText(String italian) {
  final lower = _normalizeExerciseText(italian).toLowerCase();
  if (lower.contains('20-30 secondi') || lower.contains('allungamento')) {
    return 'Move into the stretch position and hold for 20-30 seconds.';
  }
  if (lower.contains('respira') && lower.contains('non forzare')) {
    return 'Breathe deeply and stay within a comfortable range.';
  }
  if (lower.contains('ritmo') ||
      lower.contains('pedala') ||
      lower.contains('passi')) {
    return 'Keep a steady rhythm and maintain correct posture throughout the movement.';
  }
  if (lower.contains('core') || lower.contains('addome')) {
    return 'Keep your core engaged and control every phase of the movement.';
  }
  if (lower.contains('gomiti')) {
    return 'Keep your elbows fixed and perform each rep with control.';
  }
  if (lower.contains('scapole')) {
    return 'Set your shoulders, control the movement, and avoid using momentum.';
  }
  if (lower.contains('ginocchi') || lower.contains('ginocchio')) {
    return 'Keep your knees aligned and control both the lowering and lifting phases.';
  }
  if (lower.contains('schiena')) {
    return 'Keep your back neutral, brace your core, and control the movement.';
  }
  return 'Perform the movement with control, proper posture, and a full range of motion.';
}

/// Traduce testi di esecuzione/consigli dall'italiano all'inglese quando la lingua è EN.
String translateExerciseText(String italian) {
  if (AppL.lang != 'en' || italian.isEmpty) return italian;
  final source = _normalizeExerciseText(italian);
  const exactPhrases = {
    'Esegui il movimento lentamente e con controllo. Mantieni una postura corretta.':
        'Perform the movement slowly and under control. Maintain correct posture.',
    'Inizia con peso moderato per padroneggiare la tecnica.':
        'Start with moderate weight to master the technique.',
    'Porta le braccia in posizione di allungamento. Mantieni 20-30 secondi.':
        'Bring your arms into the stretch position and hold for 20-30 seconds.',
    'Porta le gambe in posizione di allungamento. Mantieni 20-30 secondi.':
        'Bring your legs into the stretch position and hold for 20-30 seconds.',
    'Porta il corpo in posizione di allungamento. Mantieni 20-30 secondi.':
        'Move into the stretch position and hold for 20-30 seconds.',
    'Porta la gamba in posizione di allungamento. Mantieni 20-30 secondi.':
        'Bring your leg into the stretch position and hold for 20-30 seconds.',
    'Posizionati in allungamento del polpaccio. Mantieni 20-30 secondi.':
        'Move into the calf stretch position and hold for 20-30 seconds.',
    'Respira profondamente. Non forzare mai oltre il limite naturale.':
        'Breathe deeply. Never force beyond your natural range.',
    'Respira profondamente. Non forzare oltre il limite.':
        'Breathe deeply. Do not force beyond your limit.',
    'Respira profondamente. Non forzare oltre il limite di comfort.':
        'Breathe deeply. Do not push beyond your comfort limit.',
    'Non forzare oltre il limite di comfort. Respira profondamente.':
        'Do not push beyond your comfort limit. Breathe deeply.',
    'Non tirare il collo. Respira normalmente.':
        'Do not pull on your neck. Breathe normally.',
    'Non tirare il collo. Concentrati sulla contrazione dell\'addome.':
        'Do not pull on your neck. Focus on contracting your abs.',
    'Contrai l\'addome durante tutto l\'esercizio. Controlla la fase eccentrica.':
        'Keep your core engaged throughout the exercise. Control the eccentric phase.',
    'Concentrati sulla contrazione dei glutei. Mantieni il core stabile.':
        'Focus on squeezing your glutes and keep your core stable.',
    'Esegui il movimento controllando fase eccentrica e concentrica.':
        'Control both the eccentric and concentric phases of the movement.',
    'Esegui il movimento con controllo. Mantieni il core stabile.':
        'Perform the movement under control and keep your core stable.',
    'Esegui il movimento esplosivo verso l\'alto. Controlla la discesa.':
        'Drive the movement explosively upward and control the lowering phase.',
    'Mantieni il core stabile durante l\'esercizio.':
        'Keep your core stable throughout the exercise.',
    'Evita di dondolare. Controlla sia la fase ascendente che discendente.':
        'Avoid swinging. Control both the upward and downward phases.',
    'Non arrotondare la schiena. Mantieni il core contratto.':
        'Do not round your back. Keep your core braced.',
    'Non usare lo slancio. Concentrati sull\'isolamento dei muscoli target.':
        'Do not use momentum. Focus on isolating the target muscles.',
  };
  if (exactPhrases.containsKey(source)) return exactPhrases[source]!;

  const fragmentMap = {
    'Esegui il movimento lentamente e con controllo.':
        'Perform the movement slowly and under control.',
    'Esegui il movimento con controllo.': 'Perform the movement under control.',
    'Esegui il movimento controllando fase eccentrica e concentrica.':
        'Control both the eccentric and concentric phases of the movement.',
    'Esegui il movimento esplosivo verso l\'alto.':
        'Drive the movement explosively upward.',
    'Mantieni una postura corretta.': 'Maintain correct posture.',
    'Mantieni il core stabile.': 'Keep your core stable.',
    'Mantieni il core contratto.': 'Keep your core braced.',
    'Mantieni il petto alto': 'Keep your chest high',
    'Mantieni il busto eretto': 'Keep your torso upright',
    'Mantieni il busto stabile': 'Keep your torso stable',
    'Mantieni la schiena dritta': 'Keep your back straight',
    'Mantieni la schiena in posizione neutra.':
        'Keep your back in a neutral position.',
    'Mantieni le scapole retratte': 'Keep your shoulder blades retracted',
    'Controlla la discesa.': 'Control the lowering phase.',
    'Controlla la fase eccentrica.': 'Control the eccentric phase.',
    'Controlla entrambe le fasi.': 'Control both phases.',
    'Controlla sia la fase ascendente che discendente.':
        'Control both the upward and downward phases.',
    'Respira profondamente.': 'Breathe deeply.',
    'Respira normalmente.': 'Breathe normally.',
    'Evita lo slancio.': 'Avoid using momentum.',
    'Evita di dondolare.': 'Avoid swinging.',
    'Non usare lo slancio.': 'Do not use momentum.',
    'Non arrotondare la schiena.': 'Do not round your back.',
    'Non forzare oltre il limite di comfort.':
        'Do not push beyond your comfort limit.',
    'Non forzare oltre il limite.': 'Do not force beyond your limit.',
    'Inizia con peso moderato': 'Start with moderate weight',
    'per padroneggiare la tecnica.': 'to master the technique.',
    'Concentrati sulla contrazione completa.': 'Focus on a full contraction.',
    'Concentrati sulla contrazione dell\'addome.':
        'Focus on contracting your abs.',
    'Concentrati sulla contrazione.': 'Focus on the contraction.',
    'Concentrati sui muscoli target.': 'Focus on the target muscles.',
    'Concentrati sull\'isolamento dei muscoli target.':
        'Focus on isolating the target muscles.',
    'Porta il corpo in posizione di allungamento.':
        'Move into the stretch position.',
    'Porta le braccia in posizione di allungamento.':
        'Bring your arms into the stretch position.',
    'Porta le gambe in posizione di allungamento.':
        'Bring your legs into the stretch position.',
    'Porta la gamba in posizione di allungamento.':
        'Bring your leg into the stretch position.',
    'Mantieni 20-30 secondi.': 'Hold for 20-30 seconds.',
    'Tieni i gomiti fissi': 'Keep your elbows fixed',
    'Mantieni i gomiti fissi': 'Keep your elbows fixed',
    'Retrai le scapole': 'Retract your shoulder blades',
    'tecnica': 'technique',
    'muscoli target': 'target muscles',
    'fase ascendente': 'upward phase',
    'fase discendente': 'downward phase',
    'fase concentrica': 'concentric phase',
    'fase eccentrica': 'eccentric phase',
    'Abbassa lentamente.': 'Lower slowly.',
    'Alza le spalle verso le orecchie': 'Raise your shoulders toward your ears',
    'Spingi verso l\'alto': 'Press upward',
    'Tira verso il petto': 'Pull toward your chest',
    'Tira verso il punto vita': 'Pull toward your waist',
  };

  final fragments = fragmentMap.entries.toList()
    ..sort((a, b) => b.key.length.compareTo(a.key.length));
  String result = source;
  for (final entry in fragments) {
    result = result.replaceAll(entry.key, entry.value);
  }

  if (_containsItalianMarkers(result)) {
    return _fallbackEnglishExerciseText(source);
  }
  return result;
}

/// Restituisce il nome del gruppo muscolare localizzato.
String bodyPartName(String key) {
  if (AppL.lang == 'en') {
    const en = {
      'nessuno': 'None',
      'petto': 'Chest',
      'dorso': 'Back',
      'gambe': 'Legs',
      'spalle': 'Shoulders',
      'braccia': 'Arms',
      'core': 'Core',
      'full_body': 'Full Body',
      'cardio': 'Cardio',
      'glutei': 'Glutes',
      'altro': 'Other',
    };
    return en[key] ?? key;
  }
  return kBodyPartNames[key] ?? key;
}

/// Restituisce il label dell'immagine muscolo localizzato.
String muscleImageLabel(Map<String, String> m) {
  if (AppL.lang == 'en') {
    const en = {
      'petto.png': 'Chest',
      'dorso.png': 'Back',
      'spalle.png': 'Shoulders',
      'braccia.png': 'Arms',
      'bicipiti.png': 'Biceps',
      'tricipiti.png': 'Triceps',
      'gambe.png': 'Legs',
      'quadricipiti.png': 'Quads',
      'femorali.png': 'Hamstrings',
      'glutei.png': 'Glutes',
      'push.png': 'Push',
      'pull.png': 'Pull',
    };
    return en[m['file']] ?? m['label'] ?? '';
  }
  return m['label'] ?? '';
}

ExerciseInfo? resolveExerciseInfo(String rawName) {
  final cleaned = rawName.trim();
  final direct = findAnyExercise(cleaned);
  if (direct != null) return direct;
  for (final part in cleaned.split('/')) {
    final normalizedPart = part.trim();
    final info = findAnyExercise(normalizedPart);
    if (info != null) return info;
  }
  final normalized = normalizeExerciseLookup(cleaned);
  for (final ex in [...kGifCatalog, ...kExerciseCatalog]) {
    final candidates = <String>{ex.name, ex.nameEn, ...ex.aliases, ex.gifSlug};
    for (final candidate in candidates) {
      if (normalizeExerciseLookup(candidate) == normalized) {
        return ex;
      }
    }
  }
  return null;
}

String localizeMixedLabel(String raw) {
  final cleaned = raw.trim();
  if (!cleaned.contains('/')) return cleaned;
  final parts = cleaned
      .split('/')
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return cleaned;
  if (AppL.lang == 'en') return parts.length > 1 ? parts.last : parts.first;
  return parts.first;
}

String localizedExerciseName(String rawName) {
  final info = resolveExerciseInfo(rawName);
  if (info != null) {
    return AppL.lang == 'en' ? info.nameEn : info.name;
  }
  return localizeMixedLabel(rawName);
}

const String kExerciseAnimationExtension = 'webp';

String exerciseAnimationAssetPath(String slug) =>
    'assets/gif/$slug.$kExerciseAnimationExtension';

String muscleAssetPath(String? fileName) =>
    'assets/muscle/${fileName!.replaceAll(RegExp(r"\.png$", caseSensitive: false), ".webp")}';

/// Returns all category labels an exercise belongs to, derived from its
/// primary [category] and its [muscleImages] list. Used by the browse screen
/// so that e.g. a "petto" exercise with tricipiti.webp also appears under
/// "braccia".
Set<String> exerciseAllCategories(ExerciseInfo e) {
  final cats = <String>{e.category};
  for (final img in e.muscleImages) {
    final base = img.replaceAll(RegExp(r'\.(png|webp)$', caseSensitive: false), '');
    switch (base) {
      case 'petto': cats.add('petto');
      case 'dorso': cats.add('dorso');
      case 'spalle': cats.add('spalle');
      case 'braccia':
      case 'bicipiti':
      case 'tricipiti': cats.add('braccia');
      case 'gambe':
      case 'quadricipiti':
      case 'femorali': cats.add('gambe');
      case 'glutei': cats.add('glutei');
      case 'addome':
      case 'core': cats.add('core');
      case 'cardio': cats.add('cardio');
      case 'pull': cats.add('dorso');
      case 'push': cats.add('petto');
    }
  }
  return cats;
}

bool usesQuarterStepIncrement(double valueKg) {
  final centiKg = (valueKg.abs() * 100).round();
  if (centiKg % 125 != 0) return false;
  // Values like 1.25, 3.75, 6.25… (odd multiples of 1.25)
  if (centiKg % 250 == 125) return true;
  // Above 100 kg the standard wheel steps are 5 kg, so 2.5-step values need quarter wheel
  if (valueKg.abs() > 100.0 && centiKg % 500 == 250) return true;
  return false;
}

bool usesEvenStepIncrement(double valueKg) {
  final milliKg = (valueKg.abs() * 1000).round();
  return milliKg % 1000 == 0 &&
      valueKg.abs() >= 2 &&
      valueKg.toInt().isEven &&
      valueKg.toInt() % 10 != 0;
}

bool usesSingleStepIncrement(double valueKg) {
  final centiKg = (valueKg.abs() * 100).round();
  // Standard 2.5-step values (multiples of 250 centi-kg) that are NOT quarter-step
  final isStandardStep = centiKg % 250 == 0 && !usesQuarterStepIncrement(valueKg);
  return !usesQuarterStepIncrement(valueKg) &&
      !usesEvenStepIncrement(valueKg) &&
      !isStandardStep;
}

// --- MODELLI DATI (SINCRONIZZATI AL 100% CON APP PT) ---
class ExerciseConfig {
  String name;
  int targetSets;
  List<int> repsList;
  int recoveryTime;
  int interExercisePause;
  String notePT;
  String noteCliente;
  // 0 = normale, 1+ = gruppo superserie (stessi numeri = stesso gruppo)
  int supersetGroup;
  List<Map<String, dynamic>> results = [];

  /// GIF slug personalizzato (es. 'barbell-curl') per esercizi non in catalogo.
  /// Se null, viene cercato il GIF tramite il catalogo.
  String? gifFilename;
  bool useQuarterStep;
  bool useEvenStep;
  bool useSingleStep;

  ExerciseConfig({
    required this.name,
    required this.targetSets,
    required this.repsList,
    required this.recoveryTime,
    this.interExercisePause = 120,
    this.notePT = "",
    this.noteCliente = "",
    this.supersetGroup = 0,
    this.gifFilename,
    this.useQuarterStep = false,
    this.useEvenStep = false,
    this.useSingleStep = false,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'targetSets': targetSets,
    'repsList': repsList,
    'recoveryTime': recoveryTime,
    'interExercisePause': interExercisePause,
    'notePT': notePT,
    'noteCliente': noteCliente,
    'supersetGroup': supersetGroup,
    'results': results,
    if (gifFilename != null) 'gifFilename': gifFilename,
    if (useQuarterStep) 'useQuarterStep': useQuarterStep,
    if (useEvenStep) 'useEvenStep': useEvenStep,
    if (useSingleStep) 'useSingleStep': useSingleStep,
  };

  factory ExerciseConfig.fromJson(Map<String, dynamic> json) {
    var ex = ExerciseConfig(
      name: json['name'] ?? "Esercizio",
      targetSets:
          (json['targetSets'] as num? ?? json['sets'] as num?)?.toInt() ?? 0,
      repsList:
          (json['repsList'] as List? ?? json['reps'] as List?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          [],
      recoveryTime:
          (json['recoveryTime'] as num? ?? json['rest'] as num?)?.toInt() ?? 90,
      interExercisePause:
          (json['interExercisePause'] as num? ?? json['pause'] as num?)
              ?.toInt() ??
          120,
      notePT: json['notePT'] ?? "",
      noteCliente: json['noteCliente'] ?? "",
      supersetGroup: (json['supersetGroup'] as num?)?.toInt() ?? 0,
      gifFilename: json['gifFilename'] as String?,
      useQuarterStep: json['useQuarterStep'] == true,
      useEvenStep: json['useEvenStep'] == true,
      useSingleStep: json['useSingleStep'] == true,
    );
    if (json['results'] != null) {
      ex.results = List<Map<String, dynamic>>.from(json['results']);
    }
    return ex;
  }
}

class WorkoutDay {
  String dayName;
  List<String> bodyParts;
  String? muscleImage;
  List<ExerciseConfig> exercises;

  WorkoutDay({
    required this.dayName,
    List<String>? bodyParts,
    this.muscleImage,
    required this.exercises,
  }) : bodyParts = bodyParts ?? [];

  Map<String, dynamic> toJson() => {
    'dayName': dayName,
    'bodyParts': bodyParts,
    'muscleImage': muscleImage,
    'exercises': exercises.map((e) => e.toJson()).toList(),
  };

  factory WorkoutDay.fromJson(Map<String, dynamic> json) {
    return WorkoutDay(
      dayName: json['dayName'] ?? 'Giorno',
      bodyParts: json['bodyParts'] != null
          ? List<String>.from(json['bodyParts'])
          : (json['bodyPart'] != null &&
                    json['bodyPart'] != 'altro' &&
                    json['bodyPart'] != 'nessuno'
                ? [json['bodyPart'] as String]
                : []),
      muscleImage: json['muscleImage'] as String?,
      exercises: (json['exercises'] as List? ?? json['esercizi'] as List? ?? [])
          .map((e) => ExerciseConfig.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

const Map<String, String> kBodyPartIcons = {
  'nessuno': '',
  'petto': '🦍',
  'dorso': '🔙',
  'gambe': '🦵',
  'spalle': '🏋️',
  'braccia': '💪',
  'core': '🔥',
  'full_body': '🏃',
  'cardio': '❤️',
  'glutei': '🍑',
  'altro': '⚡',
};
const Map<String, String> kBodyPartNames = {
  'nessuno': 'Nessuna',
  'petto': 'Petto',
  'dorso': 'Dorso',
  'gambe': 'Gambe',
  'spalle': 'Spalle',
  'braccia': 'Braccia',
  'core': 'Core',
  'full_body': 'Full Body',
  'cardio': 'Cardio',
  'glutei': 'Glutei',
  'altro': 'Altro',
};

const List<Map<String, String>> kMuscleImages = [
  {'file': 'petto.png', 'label': 'Petto'},
  {'file': 'dorso.png', 'label': 'Dorso'},
  {'file': 'spalle.png', 'label': 'Spalle'},
  {'file': 'braccia.png', 'label': 'Braccia'},
  {'file': 'bicipiti.png', 'label': 'Bicipiti'},
  {'file': 'tricipiti.png', 'label': 'Tricipiti'},
  {'file': 'gambe.png', 'label': 'Gambe'},
  {'file': 'quadricipiti.png', 'label': 'Quadricipiti'},
  {'file': 'femorali.png', 'label': 'Femorali'},
  {'file': 'glutei.png', 'label': 'Glutei'},
  {'file': 'push.png', 'label': 'Push'},
  {'file': 'pull.png', 'label': 'Pull'},
];

const List<Map<String, dynamic>> kWorkoutTemplates = [
  {
    'name': 'PRO SPLIT',
    'desc': '5 giorni · petto, dorso, gambe, spalle, braccia',
    'icon': '🏋️',
    'days': [
      {
        'dayName': 'Petto',
        'bodyParts': ['petto'],
        'muscleImage': 'petto.png',
        'exercises': [
          {
            'name': 'Smith Machine Bench Press',
            'targetSets': 4,
            'repsList': [8, 8, 8, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': 'Utilizzare Multipower',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'smith-machine-bench-press',
          },
          {
            'name': 'High Cable Crossover',
            'targetSets': 4,
            'repsList': [8, 8, 8, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'high-cable-crossover',
          },
          {
            'name': 'Distensioni con Manubri',
            'targetSets': 4,
            'repsList': [8, 8, 8, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'alternate-dumbbell-bench-press',
          },
          {
            'name': 'Peck Deck',
            'targetSets': 4,
            'repsList': [8, 8, 8, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'pec-deck-fly',
          },
        ],
      },
      {
        'dayName': 'Dorso',
        'bodyParts': ['schiena'],
        'muscleImage': 'dorso.png',
        'exercises': [
          {
            'name': 'Lat Machine',
            'targetSets': 4,
            'repsList': [8, 8, 8, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'lat-pulldown',
          },
          {
            'name': 'Seated Row Machine',
            'targetSets': 4,
            'repsList': [8, 8, 8, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'seated-row-machine',
          },
          {
            'name': 'Pulley Basso',
            'targetSets': 4,
            'repsList': [8, 8, 8, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'seated-cable-row',
          },
          {
            'name': 'Cable Straight Arm Pulldown',
            'targetSets': 4,
            'repsList': [10, 10, 10, 10],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'cable-straight-arm-pulldown',
          },
        ],
      },
      {
        'dayName': 'Gambe',
        'bodyParts': ['gambe'],
        'muscleImage': 'gambe.png',
        'exercises': [
          {
            'name': 'Belt Squat',
            'targetSets': 8,
            'repsList': [8, 8, 8, 8, 8, 8, 8, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'belt-squat',
          },
          {
            'name': 'Leg Extension',
            'targetSets': 3,
            'repsList': [15, 12, 10],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'leg-extension',
          },
          {
            'name': 'Seated Leg Curl',
            'targetSets': 4,
            'repsList': [8, 8, 8, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'seated-leg-curl',
          },
          {
            'name': 'Leg Curl',
            'targetSets': 4,
            'repsList': [8, 8, 8, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'leg-curl',
          },
        ],
      },
      {
        'dayName': 'Spalle',
        'bodyParts': ['spalle'],
        'muscleImage': 'spalle.png',
        'exercises': [
          {
            'name': 'Shoulder Press Macchina',
            'targetSets': 4,
            'repsList': [8, 8, 8, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'lever-shoulder-press',
          },
          {
            'name': 'Alzate Frontali',
            'targetSets': 3,
            'repsList': [10, 10, 10],
            'recoveryTime': 60,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'dumbbell-front-raise',
          },
          {
            'name': 'Lateral Raise Machine',
            'targetSets': 8,
            'repsList': [12, 10, 12, 10, 12, 10, 12, 10],
            'recoveryTime': 60,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'lateral-raise-machine',
          },
          {
            'name': 'Alzate Laterali',
            'targetSets': 4,
            'repsList': [10, 8, 12, 10],
            'recoveryTime': 60,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'dumbbell-lateral-raise',
          },
          {
            'name': 'Alzate Posteriori',
            'targetSets': 4,
            'repsList': [12, 10, 10, 8],
            'recoveryTime': 60,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'bent-over-lateral-raise',
          },
        ],
      },
      {
        'dayName': 'Braccia',
        'bodyParts': ['braccia'],
        'muscleImage': 'braccia.png',
        'exercises': [
          {
            'name': 'Lever Preacher Curl',
            'targetSets': 5,
            'repsList': [8, 8, 8, 8, 8],
            'recoveryTime': 60,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'lever-preacher-curl',
          },
          {
            'name': 'Curl al Cavo Basso',
            'targetSets': 5,
            'repsList': [8, 8, 8, 8, 8],
            'recoveryTime': 60,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'cable-curl',
          },
          {
            'name': 'Curl Martello',
            'targetSets': 5,
            'repsList': [8, 8, 8, 8, 8],
            'recoveryTime': 60,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'hammer-curl',
          },
          {
            'name': 'Push Down',
            'targetSets': 5,
            'repsList': [8, 8, 8, 8, 8],
            'recoveryTime': 60,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'push-down',
          },
          {
            'name': 'Rope Pushdown',
            'targetSets': 5,
            'repsList': [8, 8, 8, 8, 8],
            'recoveryTime': 60,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'rope-pushdown',
          },
          {
            'name': 'French Press',
            'targetSets': 5,
            'repsList': [8, 8, 8, 8, 8],
            'recoveryTime': 60,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'seated-ez-bar-overhead-triceps-extension',
          },
        ],
      },
    ],
  },
  {
    'name': 'Essentials',
    'desc': '2 giorni · upper/lower mix',
    'icon': '🔥',
    'days': [
      {
        'dayName': 'A',
        'bodyParts': ['petto', 'dorso', 'braccia'],
        'muscleImage': 'push.png',
        'exercises': [
          {
            'name': 'Panca Piana',
            'targetSets': 4,
            'repsList': [12, 10, 8, 6],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'bench-press',
          },
          {
            'name': 'Peck Deck',
            'targetSets': 3,
            'repsList': [12, 10, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'pec-deck-fly',
          },
          {
            'name': 'Lat Machine',
            'targetSets': 3,
            'repsList': [12, 10, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'lat-pulldown',
          },
          {
            'name': 'Pulley Basso',
            'targetSets': 4,
            'repsList': [12, 10, 8, 6],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'seated-cable-row',
          },
          {
            'name': 'Curl con Bilanciere',
            'targetSets': 3,
            'repsList': [12, 10, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'barbell-curl',
          },
          {
            'name': 'Curl Martello',
            'targetSets': 3,
            'repsList': [12, 10, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'hammer-curl',
          },
        ],
      },
      {
        'dayName': 'B',
        'bodyParts': ['gambe', 'spalle', 'braccia'],
        'muscleImage': 'gambe.png',
        'exercises': [
          {
            'name': 'Leg Press',
            'targetSets': 3,
            'repsList': [15, 12, 10],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'leg-press',
          },
          {
            'name': 'Leg Extension',
            'targetSets': 2,
            'repsList': [12, 10],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'leg-extension',
          },
          {
            'name': 'Leg Curl',
            'targetSets': 3,
            'repsList': [12, 10, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'leg-curl',
          },
          {
            'name': 'Lento Avanti',
            'targetSets': 3,
            'repsList': [12, 10, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'barbell-shoulder-press',
          },
          {
            'name': 'Alzate Laterali',
            'targetSets': 3,
            'repsList': [12, 10, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'dumbbell-lateral-raise',
          },
          {
            'name': 'Push Down',
            'targetSets': 3,
            'repsList': [12, 10, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'push-down',
          },
          {
            'name': 'Rope Pushdown',
            'targetSets': 3,
            'repsList': [12, 10, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'rope-pushdown',
          },
        ],
      },
    ],
  },
  {
    'name': 'Push Pull Leg',
    'desc': '3 giorni · lower focus + upper work',
    'icon': '🌿',
    'days': [
      {
        'dayName': 'Push',
        'bodyParts': ['petto', 'dorso', 'glutei', 'braccia'],
        'muscleImage': 'push.png',
        'exercises': [
          {
            'name': 'Chest Press Macchina',
            'targetSets': 4,
            'repsList': [8, 8, 8, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'chest-press-machine',
          },
          {
            'name': 'Pulley Basso',
            'targetSets': 4,
            'repsList': [8, 8, 8, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'seated-cable-row',
          },
          {
            'name': 'Romanian Deadlift',
            'targetSets': 3,
            'repsList': [8, 8, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'romanian-deadlift',
          },
          {
            'name': 'Glute Kickback',
            'targetSets': 3,
            'repsList': [8, 8, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'glute-kickback-machine',
          },
          {
            'name': 'Glute Kickback',
            'targetSets': 4,
            'repsList': [10, 10, 8, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'glute-kickback-machine',
          },
          {
            'name': 'Overhead Tricep Extension',
            'targetSets': 4,
            'repsList': [10, 10, 8, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'seated-ez-bar-overhead-triceps-extension',
          },
        ],
      },
      {
        'dayName': 'Pull',
        'bodyParts': ['petto', 'gambe', 'braccia'],
        'muscleImage': 'pull.png',
        'exercises': [
          {
            'name': 'Knee Push Up',
            'targetSets': 4,
            'repsList': [18, 18, 18, 18],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'knee-push-up',
          },
          {
            'name': 'Peck Deck',
            'targetSets': 4,
            'repsList': [8, 8, 8, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'pec-deck-fly',
          },
          {
            'name': 'Hip Adduction Machine',
            'targetSets': 3,
            'repsList': [10, 10, 10],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'hip-adduction-machine',
          },
          {
            'name': 'Hip Abduction Machine',
            'targetSets': 3,
            'repsList': [10, 10, 10],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'hip-abduction-machine',
          },
          {
            'name': 'Seated Incline Dumbbell Curl',
            'targetSets': 4,
            'repsList': [10, 10, 8, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'seated-incline-dumbbell-curl',
          },
          {
            'name': 'Curl Martello',
            'targetSets': 4,
            'repsList': [10, 10, 8, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'hammer-curl',
          },
        ],
      },
      {
        'dayName': 'Leg',
        'bodyParts': ['gambe', 'spalle'],
        'muscleImage': 'gambe.png',
        'exercises': [
          {
            'name': 'Squat con Bilanciere',
            'targetSets': 4,
            'repsList': [8, 8, 8, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'squat',
          },
          {
            'name': 'Pendulum Squat',
            'targetSets': 3,
            'repsList': [8, 8, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'pendulum-squat',
          },
          {
            'name': 'Leg Extension',
            'targetSets': 3,
            'repsList': [10, 10, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'leg-extension',
          },
          {
            'name': 'Leg Curl',
            'targetSets': 2,
            'repsList': [10, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'leg-curl',
          },
          {
            'name': 'Dumbbell Shoulder Press',
            'targetSets': 3,
            'repsList': [8, 8, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'dumbbell-shoulder-press',
          },
          {
            'name': 'Alzate Frontali',
            'targetSets': 3,
            'repsList': [10, 10, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'dumbbell-front-raise',
          },
          {
            'name': 'Alzate Laterali',
            'targetSets': 5,
            'repsList': [12, 10, 8, 10, 8],
            'recoveryTime': 90,
            'interExercisePause': 180,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'dumbbell-lateral-raise',
          },
        ],
      },
    ],
  },
  {
    'name': 'PPL Starter',
    'desc': '3 giorni · push, pull, leg day',
    'icon': '✨',
    'days': [
      {
        'dayName': 'Pull day',
        'bodyParts': ['dorso', 'braccia', 'gambe'],
        'muscleImage': 'pull.png',
        'exercises': [
          {
            'name': 'Seated Row Machine',
            'targetSets': 4,
            'repsList': [8, 8, 8, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'seated-row-machine',
          },
          {
            'name': 'Cable Straight Arm Pulldown',
            'targetSets': 3,
            'repsList': [8, 8, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'cable-straight-arm-pulldown',
          },
          {
            'name': 'Curl al Cavo Basso',
            'targetSets': 3,
            'repsList': [8, 8, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'cable-curl',
          },
          {
            'name': 'Romanian Deadlift',
            'targetSets': 4,
            'repsList': [8, 8, 10, 10],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'romanian-deadlift',
          },
          {
            'name': 'Leg Curl',
            'targetSets': 4,
            'repsList': [8, 8, 8, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'leg-curl',
          },
        ],
      },
      {
        'dayName': 'Push day',
        'bodyParts': ['petto', 'spalle', 'braccia'],
        'muscleImage': 'push.png',
        'exercises': [
          {
            'name': 'Chest Press Macchina',
            'targetSets': 3,
            'repsList': [8, 8, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'chest-press-machine',
          },
          {
            'name': 'Croci ai Cavi',
            'targetSets': 3,
            'repsList': [8, 8, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'cable-crossover',
          },
          {
            'name': 'Rope Pushdown',
            'targetSets': 3,
            'repsList': [8, 8, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'rope-pushdown',
          },
          {
            'name': 'Overhead Tricep Extension',
            'targetSets': 3,
            'repsList': [8, 8, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'seated-ez-bar-overhead-triceps-extension',
          },
          {
            'name': 'Lento Avanti',
            'targetSets': 3,
            'repsList': [8, 8, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'barbell-shoulder-press',
          },
          {
            'name': 'Alzate Laterali',
            'targetSets': 4,
            'repsList': [15, 12, 10, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'dumbbell-lateral-raise',
          },
        ],
      },
      {
        'dayName': 'Leg day',
        'bodyParts': ['gambe', 'glutei'],
        'muscleImage': 'gambe.png',
        'exercises': [
          {
            'name': 'Leg Press',
            'targetSets': 4,
            'repsList': [8, 8, 8, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'leg-press',
          },
          {
            'name': 'Hack Squats Machine',
            'targetSets': 3,
            'repsList': [8, 8, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'hack-squats-machine',
          },
          {
            'name': 'Leg Extension',
            'targetSets': 3,
            'repsList': [10, 10, 10],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'leg-extension',
          },
          {
            'name': 'Hip Thrust',
            'targetSets': 4,
            'repsList': [8, 8, 8, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'barbell-hip-thrusts',
          },
          {
            'name': 'Leg Curl',
            'targetSets': 4,
            'repsList': [8, 8, 8, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'leg-curl',
          },
        ],
      },
    ],
  },
  {
    'name': 'Strength Split',
    'desc': '3 giorni · pull, push, legs',
    'icon': '🧱',
    'days': [
      {
        'dayName': 'Pull',
        'bodyParts': ['braccia'],
        'muscleImage': 'pull.png',
        'exercises': [
          {
            'name': 'Seated Row Machine',
            'targetSets': 5,
            'repsList': [6, 8, 8, 8, 10],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'seated-row-machine',
          },
          {
            'name': 'Pulley Basso',
            'targetSets': 4,
            'repsList': [6, 8, 8, 10],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'seated-cable-row',
          },
          {
            'name': 'Lat Machine',
            'targetSets': 4,
            'repsList': [10, 10, 10, 10],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'lat-pulldown',
          },
          {
            'name': 'Curl con Bilanciere',
            'targetSets': 4,
            'repsList': [6, 8, 8, 10],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'barbell-curl',
          },
          {
            'name': 'Curl al Cavo Basso',
            'targetSets': 4,
            'repsList': [10, 10, 10, 10],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'cable-curl',
          },
          {
            'name': 'Cable Rope Hammer Curl',
            'targetSets': 3,
            'repsList': [10, 10, 10],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'cable-rope-hammer-curl',
          },
        ],
      },
      {
        'dayName': 'Push',
        'bodyParts': ['spalle'],
        'muscleImage': 'push.png',
        'exercises': [
          {
            'name': 'Distensioni con Manubri',
            'targetSets': 4,
            'repsList': [6, 8, 8, 10],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'alternate-dumbbell-bench-press',
          },
          {
            'name': 'Croci ai Cavi',
            'targetSets': 4,
            'repsList': [10, 10, 10, 10],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'cable-crossover',
          },
          {
            'name': 'Peck Deck',
            'targetSets': 3,
            'repsList': [8, 8, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'pec-deck-fly',
          },
          {
            'name': 'Lento Avanti',
            'targetSets': 4,
            'repsList': [6, 8, 8, 10],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'barbell-shoulder-press',
          },
          {
            'name': 'Alzate Laterali',
            'targetSets': 4,
            'repsList': [10, 10, 8, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'dumbbell-lateral-raise',
          },
          {
            'name': 'Alzate Posteriori',
            'targetSets': 3,
            'repsList': [10, 10, 10],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'bent-over-lateral-raise',
          },
        ],
      },
      {
        'dayName': 'Legs',
        'bodyParts': ['gambe'],
        'muscleImage': 'gambe.png',
        'exercises': [
          {
            'name': 'Leg Press',
            'targetSets': 4,
            'repsList': [6, 8, 8, 10],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'leg-press',
          },
          {
            'name': 'Hack Squats Machine',
            'targetSets': 3,
            'repsList': [10, 10, 10],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'hack-squats-machine',
          },
          {
            'name': 'Leg Extension',
            'targetSets': 2,
            'repsList': [8, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'leg-extension',
          },
          {
            'name': 'Leg Curl',
            'targetSets': 3,
            'repsList': [8, 8, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'leg-curl',
          },
          {
            'name': 'One Arm Triceps Pushdown',
            'targetSets': 4,
            'repsList': [6, 8, 8, 10],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'one-arm-triceps-pushdown',
          },
          {
            'name': 'Rope Pushdown',
            'targetSets': 4,
            'repsList': [10, 10, 10, 10],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'rope-pushdown',
          },
          {
            'name': 'French Press',
            'targetSets': 3,
            'repsList': [8, 8, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'seated-ez-bar-overhead-triceps-extension',
          },
        ],
      },
    ],
  },
  {
    'name': '4-Day Sculpt',
    'desc': '4 giorni · schiena, quad, upper, glutei',
    'icon': '🍑',
    'days': [
      {
        'dayName': 'Workout 1/4',
        'bodyParts': [],
        'muscleImage': 'pull.png',
        'exercises': [
          {
            'name': 'Lat Machine',
            'targetSets': 3,
            'repsList': [10, 8, 6],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'lat-pulldown',
          },
          {
            'name': 'T Bar Row',
            'targetSets': 3,
            'repsList': [10, 8, 6],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 't-bar-row',
          },
          {
            'name': '45 Degree Incline Row',
            'targetSets': 3,
            'repsList': [10, 8, 6],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': '45-degree-incline-row',
          },
          {
            'name': 'Cable Straight Arm Pulldown',
            'targetSets': 3,
            'repsList': [10, 8, 6],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': 'Se c\'è usa la vulken',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'cable-straight-arm-pulldown',
          },
          {
            'name': 'Dumbbell Kickback',
            'targetSets': 3,
            'repsList': [10, 8, 6],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'dumbbell-kickback',
          },
          {
            'name': 'Rope Pushdown',
            'targetSets': 3,
            'repsList': [10, 8, 6],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'rope-pushdown',
          },
          {
            'name': 'High Pulley Overhead Tricep Extension',
            'targetSets': 2,
            'repsList': [10, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': 'vulken',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'high-pulley-overhead-tricep-extension',
          },
          {
            'name': 'Weighted Sit Ups',
            'targetSets': 3,
            'repsList': [15, 15, 15],
            'recoveryTime': 30,
            'interExercisePause': 120,
            'notePT': '3 x max',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'weighted-sit-ups',
          },
        ],
      },
      {
        'dayName': 'Workout 2/4',
        'bodyParts': [],
        'muscleImage': 'quadricipiti.png',
        'exercises': [
          {
            'name': 'Smith Machine Squat',
            'targetSets': 4,
            'repsList': [10, 8, 8, 6],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'smith-machine-squat',
          },
          {
            'name': 'Hack Squats Machine',
            'targetSets': 4,
            'repsList': [12, 10, 10, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'hack-squats-machine',
          },
          {
            'name': 'Leg Extension',
            'targetSets': 3,
            'repsList': [10, 8, 6],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'leg-extension',
          },
          {
            'name': 'Hip Adduction Machine',
            'targetSets': 3,
            'repsList': [10, 8, 6],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'hip-adduction-machine',
          },
          {
            'name': 'Affondi',
            'targetSets': 3,
            'repsList': [10, 10, 10],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'bodyweight-lunge',
          },
          {
            'name': 'Calf Raises',
            'targetSets': 4,
            'repsList': [18, 15, 18, 15],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'calf-raise',
          },
          {
            'name': 'Russian Twist',
            'targetSets': 3,
            'repsList': [15, 15, 15],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '3 x max',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'russian-twist',
          },
        ],
      },
      {
        'dayName': 'Workout 3/4',
        'bodyParts': [],
        'muscleImage': 'push.png',
        'exercises': [
          {
            'name': 'Peck Deck',
            'targetSets': 4,
            'repsList': [10, 8, 8, 6],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'pec-deck-fly',
          },
          {
            'name': 'Incline Cable Fly',
            'targetSets': 3,
            'repsList': [10, 8, 6],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': 'Usa le cavigliere',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'incline-cable-fly',
          },
          {
            'name': 'High Cable Crossover',
            'targetSets': 3,
            'repsList': [10, 8, 6],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': 'Usa le cavigliere',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'high-cable-crossover',
          },
          {
            'name': 'Alzate Frontali',
            'targetSets': 3,
            'repsList': [10, 10, 10],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': 'vulken',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'dumbbell-front-raise',
          },
          {
            'name': 'Alzate Laterali',
            'targetSets': 5,
            'repsList': [12, 10, 10, 8, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'dumbbell-lateral-raise',
          },
          {
            'name': 'Crunch',
            'targetSets': 4,
            'repsList': [18, 18, 18, 18],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '4x max',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'crunch',
          },
        ],
      },
      {
        'dayName': 'Workout 4/4',
        'bodyParts': [],
        'muscleImage': 'glutei.png',
        'exercises': [
          {
            'name': 'Hip Thrust',
            'targetSets': 3,
            'repsList': [10, 8, 6],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'barbell-hip-thrusts',
          },
          {
            'name': 'Romanian Deadlift',
            'targetSets': 3,
            'repsList': [10, 8, 6],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'romanian-deadlift',
          },
          {
            'name': 'Leg Curl',
            'targetSets': 3,
            'repsList': [10, 8, 6],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'leg-curl',
          },
          {
            'name': 'Hip Abduction Machine',
            'targetSets': 3,
            'repsList': [10, 10, 10],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'hip-abduction-machine',
          },
          {
            'name': 'Curl al Cavo Basso',
            'targetSets': 4,
            'repsList': [10, 8, 8, 6],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': 'Usa le cavigliere',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'cable-curl',
          },
          {
            'name': 'Cable Rope Hammer Curl',
            'targetSets': 4,
            'repsList': [10, 8, 8, 6],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'cable-rope-hammer-curl',
          },
          {
            'name': 'Crunch',
            'targetSets': 3,
            'repsList': [18, 18, 18],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '3 x max',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'crunch',
          },
        ],
      },
    ],
  },
  {
    'name': '4/4 Progression',
    'desc': '4 giorni · schiena, lower, push, legs',
    'icon': '⚙️',
    'days': [
      {
        'dayName': '1/4',
        'bodyParts': ['dorso'],
        'muscleImage': 'pull.png',
        'exercises': [
          {
            'name': 'Seated Row Machine',
            'targetSets': 3,
            'repsList': [12, 10, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'seated-row-machine',
          },
          {
            'name': 'Lat Machine',
            'targetSets': 3,
            'repsList': [12, 10, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'lat-pulldown',
          },
          {
            'name': '45 Degree Incline Row',
            'targetSets': 3,
            'repsList': [12, 10, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': '45-degree-incline-row',
          },
          {
            'name': 'Cable Straight Arm Pulldown',
            'targetSets': 3,
            'repsList': [12, 10, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'cable-straight-arm-pulldown',
          },
          {
            'name': 'Push Down',
            'targetSets': 3,
            'repsList': [12, 10, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'push-down',
          },
          {
            'name': 'Overhead Tricep Extension',
            'targetSets': 3,
            'repsList': [12, 10, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'seated-ez-bar-overhead-triceps-extension',
          },
          {
            'name': 'French Press',
            'targetSets': 2,
            'repsList': [12, 10],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'seated-ez-bar-overhead-triceps-extension',
          },
        ],
      },
      {
        'dayName': '2/4',
        'bodyParts': ['glutei'],
        'muscleImage': 'glutei.png',
        'exercises': [
          {
            'name': 'Squat con Bilanciere',
            'targetSets': 4,
            'repsList': [12, 12, 10, 10],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'squat',
          },
          {
            'name': 'Hip Thrust',
            'targetSets': 4,
            'repsList': [12, 10, 10, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'barbell-hip-thrusts',
          },
          {
            'name': 'Dumbbell Romanian Deadlift',
            'targetSets': 4,
            'repsList': [12, 10, 10, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'dumbbell-romanian-deadlift',
          },
          {
            'name': 'Hip Abduction Machine',
            'targetSets': 3,
            'repsList': [12, 10, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'hip-abduction-machine',
          },
          {
            'name': 'Calf Raises',
            'targetSets': 4,
            'repsList': [18, 18, 15, 12],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'calf-raise',
          },
          {
            'name': 'Crunch',
            'targetSets': 3,
            'repsList': [15, 15, 15],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '3 x max',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'crunch',
          },
        ],
      },
      {
        'dayName': '3/4',
        'bodyParts': ['petto'],
        'muscleImage': 'push.png',
        'exercises': [
          {
            'name': 'Distensioni con Manubri',
            'targetSets': 4,
            'repsList': [12, 10, 8, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'alternate-dumbbell-bench-press',
          },
          {
            'name': 'Incline Dumbbell Fly',
            'targetSets': 3,
            'repsList': [12, 10, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'incline-dumbbell-fly',
          },
          {
            'name': 'Chest Press Macchina',
            'targetSets': 3,
            'repsList': [12, 10, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'chest-press-machine',
          },
          {
            'name': 'Lento Avanti',
            'targetSets': 3,
            'repsList': [12, 10, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'barbell-shoulder-press',
          },
          {
            'name': 'Alzate Laterali',
            'targetSets': 4,
            'repsList': [12, 10, 10, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'dumbbell-lateral-raise',
          },
          {
            'name': 'Crunch',
            'targetSets': 4,
            'repsList': [15, 15, 15, 15],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '4 x max',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'crunch',
          },
        ],
      },
      {
        'dayName': '4/4',
        'bodyParts': ['gambe'],
        'muscleImage': 'gambe.png',
        'exercises': [
          {
            'name': 'Dumbbell Goblet Squat',
            'targetSets': 3,
            'repsList': [12, 10, 10],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'dumbbell-goblet-squat',
          },
          {
            'name': 'Hip Abduction Machine',
            'targetSets': 3,
            'repsList': [12, 10, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'hip-abduction-machine',
          },
          {
            'name': 'Leg Extension',
            'targetSets': 3,
            'repsList': [12, 10, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'leg-extension',
          },
          {
            'name': 'Leg Curl',
            'targetSets': 3,
            'repsList': [12, 10, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'leg-curl',
          },
          {
            'name': 'Curl con Manubri Alternati',
            'targetSets': 3,
            'repsList': [12, 10, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'dumbbell-curl',
          },
          {
            'name': 'Curl al Cavo Basso',
            'targetSets': 3,
            'repsList': [12, 10, 8],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'cable-curl',
          },
          {
            'name': 'Cable Rope Hammer Curl',
            'targetSets': 2,
            'repsList': [12, 10],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'cable-rope-hammer-curl',
          },
          {
            'name': 'Crunch',
            'targetSets': 3,
            'repsList': [10, 10, 10],
            'recoveryTime': 90,
            'interExercisePause': 120,
            'notePT': '3 x max',
            'noteCliente': '',
            'supersetGroup': 0,
            'gifFilename': 'crunch',
          },
        ],
      },
    ],
  },
];

List<dynamic> _templateDays(Map<String, dynamic> template) {
  final directDays = template['days'];
  if (directDays is List) return directDays;
  final payload = template['payload'] as String?;
  if (payload == null || payload.isEmpty) return const [];
  var raw = payload.trim();
  if (raw.startsWith('GYM1:')) {
    final b64 = raw.substring(5).replaceAll(RegExp(r'\s'), '');
    final padded = b64.padRight(b64.length + (4 - b64.length % 4) % 4, '=');
    final bytes = base64Url.decode(padded);
    raw = utf8.decode(arc.GZipDecoder().decodeBytes(bytes));
  }
  final decoded = jsonDecode(raw);
  if (decoded is Map<String, dynamic>) {
    final routine = decoded['routine'];
    if (routine is List) return routine;
  }
  return decoded is List ? decoded : const [];
}

final List<Map<String, dynamic>> kCuratedWorkoutTemplates = [
  {
    'name': '5-Day Split',
    'desc': '5 giorni · petto / dorso / gambe / spalle / braccia',
    'icon': '🔥',
    'payload':
        'GYM1:H4sIAApl5WkC_81XXU_bMBT9K1ae4wnYQGxvtHxsEkwRZU9THxznklhz7Mx2KAXx33cdp12bhCJNootaVdW1Y5_j43vuzXPEpQDlvrMSoi_RlWCqZIbrKI6Mrp1QGP35HGVs2c5IwDk_mupsmTDjLI5HVROcx1FZWy7hW8lyP7cJf6hUjvPhEQwXFmyzngqLzUrhCnLDeIEbkQkoXpDEgLX4gGMmBzcDv8MnRAOVvRbW4eOncfOZ-yDXD2CWd8Iv9_kgjoRyYC7avRJWW4wfHuGA0g6SO9zzhxNSPD0xA-Smlk5UegEmChOmzVl4ZBiwdQXGgrvCg6iiL7hGLu4vhYQWvPXgaRnA09SDp1UD_iVeM_wq8oJMWSqBTI221sN9R3L_wqNAiJR7iJSvIW5QOEdgoKzQSpCSqTo1YmQMsrpMU5Cyf_wJcKcNk6SVaWTAK-A0A_6L3stl9DL3wP9m2rk2tpdpFmng0_1cy_zsXbl2zdwq00Z2CpI5WtVSZnqhNsVb-cKtXowMsQXmIKNGL1b5v3XpkAssyYTZRr8RAg_ZjvA3YQeXmjnD0BAcOTMlSVaq7GJxeBCvvntkEijYFi1lpty4Q51MumJlCt1MyptgL4-a8K48moB0xP6umeucyumQtvH-NUYndDQA3FD3GnJy8dgaeQf5x209j-PDo_2KKSGnsAbXQT2tjSQzyGo30mzy6DmCHAI-NqtdQ-2kyKxiaFq9ahOivSQJ8Z2dXaFrmYEJ7ZwvPN4m2dgE3GrhbIu530acySdUmlwarRyTYnf6vOaFJ-_f_9x7gBQt0W4VJCz94JugWz_wShOw7V6NAcS93z1ykgFzIDNUZVtNWm7irRJ1uncGa1W2qAxQSDQ22EboN_rqVoeDgQw5ecdighfK79Rl0fGPicEMF6xrIGkb7jlIO7Cz0AqO5F_p3I-Hi-0-Lyg8BKtAfPinWwCaqsXZgyAZZl460Av-fwqhh3IL3bRPngHVigrF5fqNtkepYGXZe4UdCxWjK6ABYU-QpLYF8e2hV2V8Wmg8ca-C8dcKHa9CuLT7RrTBQZuMjY5Ec_4eeRc4thecM26YEuM7-raNWymw9m1nGgfa7Ezn-PkDop31-TMTAAA',
  },
  {
    'name': 'A/B',
    'desc': '2 giorni · upper / lower',
    'icon': '🏋️',
    'payload':
        'GYM1:H4sIAApl5WkC_82VUWvbMBDHv4rQsw1Nuo2tb03WjUG6GZq3EcJZvsXHZElIctqs7LvvZJs2c9Y-ZsYgzJ18-p3811-PUmlCE79Cg_JKftmDkZn0to1kOPD9UVZwGJLXnMEH9IoChi5n-kQBRoEoCAzwlAh-h_EOI895w7XQhRWFyB_M5tnsInufvduksLJ79Ic1pRIfLjJJJqK_GeoX0AaOz-acMDZiseZ1ZP--7IixD4TWoQ8YPzOzk1c8fUc_PpHGga1Eo-rceQxB_s6ekVH9FB95GAFf_gv4jLiOkbZV4jqCXUEUt6Dq9Eumhash5q7VurL35q_t5RgexAJCsJOTRECIWOUKSo25t_fH4MvWa6GsEQvSrGpCP7UtL8GXqHWumPSE_BZ85KSdGHMNTYN-QN4k6GdXWbzkKivciaI7t6828zbr-jmn6HF3aiiJ9uYhoglkzYh4frr9Z8bFJ7IRclLN1DyFecfivqttqyv0vSCSGSY3hImRh4ZinTe9U-dhYD7VyrX-xQ4k2NbRg6aJdVG1Tdk5jO75cg9c_ph_7UmRo0gCSCxhP7UOvHXI11Kox9fSN169RqhE6gDdiwf2fzdgB85t7Di3R8d3w88fY9uharUJAAA',
  },
  {
    'name': '3-Day Split',
    'desc': '3 giorni · split personalizzata',
    'icon': '⚡',
    'payload':
        'GYM1:H4sIAApl5WkC_82Wb2_aMBDGv0qU11gCtkms7ygr2ws6ocFeTVXlOAc54diZ_7RlVb_7ziR0WdKiVZpClAghX-z8zr7nyT3GQiIo95XnEF_EU7UFyeNBbLR3qGjox2Oc8n0VXnqbURAewAi0YA9hVcW4EjxaIldhvuNmC24Fjp55T8tBYRdoHU2YDA7XTRgU-g7Mfo1hgY_DQYzKgbmqVl9yb2l8NKaA0g6Wa3pLXP6fHaChHLC-AGPBfSboIr6gx7e4maOEiiwBJTJWGLA2fhr8AfZSwj665NbqnhFb4A5SJngigRl9X8f-pnOuaJejT8BTiRvXYH_XZu-Q3FR0LD3S1dC_YBGtM-Ntv5gzLG5diVWDXRsUWKDDiGM043d4skZGwwHdXe91AawgSab6XtXR5yZUfLQ8VHzfqFOfJwlIyeyOBMgE7XsGJn66CQnUrUbKV62GprDvxenUJoPj3WFy4TQYReo2A2JHWhW7nnlMQUi3aeBqKHSapF44bU5qtKyc0bBjmfIj29td5UzEbWOZeSMjoVV0zZVPDEZTSS9X3GF_tSqIuZXDNTeOgrp32BnPczAVdMNXFrB9zVZWPz13h5O5REndDIKBvjUGAbF-EJTOiz5_3i-qhG273wqoVw8OlEWt_kGqXQPDM1sDOhR7g3fc5O0atinIVaa9TMGUxUDSFCLDVid-3qqwObqM5TyQAbMVcbtQpvIXtb_R3GjluMSelcqzJ24CHzOcFn-BfkE_pk3_4W_6cWmOb0th8t9SkCXkMYkbun4D0U-glBEOAAA',
  },
  {
    'name': 'PPL',
    'desc': '3 giorni · pull / push / legs',
    'icon': '💎',
    'payload':
        'GYM1:H4sIAApl5WkC_9WWwW7bMAyGX0Xw2QKabgO23lY33Q7dFjS5DUGgyExMTJY8Sm6aFX33UbFbGE2Q9ZRqsA-2RMuf6Z8_9ZBpg2DDd1VDdpGNDXqV5Rm5NqDlkZ8PWam2_eykNUbwLQfAPZBGD34XYrv5b0pX_JS4dRsOCYrWEKYQOOY9LwmNv0Ef-IGP-e6Yx0Ht7oC2M4wLfDrLM7QBaNyvPlGt5_HROU9YF2Ay47dk3XWx44ZuwLcNkIfwhcGb7ILD17i6RgM9mQcVoJTkNrLuILPH_Jn7RgXRs7_gfrfPfUJqo4JsOOel29ghb9GSEcqIQt05cam8d0lha7U0IDVDDqFvXa0sKiuuQJUGV-GfEhmd8XlCbuoJZflEONQIrEXMe2LCNrDuMz2PsMNa9dWxWi0q8EFMCLyP2o_iV2mpKALKJgIeqtmCnEahnWV62y4Jk4Iv23q5BGPkymyH1D_45RWrS8wINTRifB_AenQ2KXrXUy7CjnIBz5SDT7kmsLrqFJRm7v0v9k6piSsBaIg-rVxrSqCU5e9rDNWT8KXvibt6GH7LZ_OHW5vgFgakDB61p9GHfHQebfVNfofpECUpXn7Pr6K_HrGrOH1Iain4794_mf5ueUcRvekSjbIagdLaWPgI-LK7vc6Ldk35tH055vigBX3FRswqru-QmCoqbBahA_u_thDzx79h3fVZEQwAAA',
  },
  {
    'name': 'PPL STRONG',
    'desc': '3 giorni · pull / push / legs',
    'icon': '🧠',
    'payload':
        'GYM1:H4sIAApl5WkC_82Wb2-bMBDGvwry6zCl3R9tfbdmbTUp2dCSd1UUHeYKVo3NbNOUVf3uOwONUkqjvAooURTZ5vy788NzfmJcClTuF-TILtgNoAOl2YQZXTqhaOz2iSVQtfNRKSVNxjqpIjDO0jSLDXAugK0nLC8tl_gzh9QvLmjxh0Kl9AA-ouHCoq3jqSbYAnhGWwR_9JaWODApuiX6oJ9pfyzsXFhHD3yZfK0_Z9O1H-f6AU21Ej7Gt-mECeXQXLUbRFBaGj87pwmlHUYr2og1_2d1ptgM2LJAY9HdUKIFu6Dlqbi7FhJbOIvgMAmN3oZ5w8meJzt0XwesgkuwVnfYP_WwD0HOIZbo-fe55-CCtuwHsc-mk5fvCckluNCLJtFbtU89K40MuFbBpZCguECDYyt6DCZGKUNOqG_QQQYzeNBHyGWYujdS6UVf0FtOeXWpP_ZSnxA5gzxH0zKvPfW-Sdmsa1K2AHpj-zzKZoc8amY0F7X2FqDK2IixCS8p87hW3p2sXp1eDQ7CK0-M8V2vhEpbk-qgR8jvgx_0c1B0dU84IXBBQJvEU-2hLjNdygRNEBm01lur91YYXUvIhcte-lhoW-iw8ND76XyX_6h3BNQl0IA8RjanPYOd2GVDGBqg8MdnMLhtvZdAx8HmmNqug6WQxz0GVg8fcjCK1ahzbKKUmL5V4PJvSVeUg71-8EO0nvHVrYpKfPXoUFmhVYf2vGtaJ64w7rg6wL69j8pgPW33DrIygotCuOM62QAiNrrA0F8iunfW37R7hpAEPgUs3tXHGHqxblk3rmbd9Grm2qDiWa-VDKubnafa-9LfwA2dBhrvqevn_68FreTfDgAA',
  },
  {
    'name': 'bOOTY',
    'desc': '4 giorni · split completa',
    'icon': '🚀',
    'payload':
        'GYM1:H4sIAApl5WkC_82Y0U7bMBSGX8XKzW6SDWiZgDsosE2CrYJuu5gQOnFOU6uOndkO0CHeZ--xF9txUlhpSmGlrSJFVZs48Xdi-_9_9zbgUqBynyHDYC_4BpJ-CAVBGBhd0Dc6--M2SGA0bvFdmyFdYJvv2tQm1smoC8ZZanURBllhucRPGaS-aV5I-TZXKbXDGzRcWLTl01T1qBNw7BT4wHcSBg5Miu4c_bNa1Dvm9kRYRzdsboQ74fsLf47rKzSjnvD3726EgVAOzdH44V0oLJ3f3KILSjvs9qiToPreKavE6oQtcjQW3QcqMQ_2qHkq-seCSq_AJLjIwyf6WgV34QPwGWbgtEHGtWIHQoLiAk3D4GMwMUoZxXRL5HuMjL6erKJLleGIHYC1ulnoFsFhEnGIJU5TP3r3p6CK2IgV4p9TR2_-_GaFBSaBXRVyiGqRmpIii8vxmKqnZwQXuXCCgWAduBLNGgqjc6Q1YAfTa-AL9T5ASJgvAHN2dONQWaFVs_j1GPPSlZiX-IA5UcuxQcUHrGvQ2in8rRr-gvBLmDl2SCs24oZGA80kf8cUxD__xW-H5VGjb72IvsVuWAY3i-DzCu7uwgPX_WPref_4WUByv0rm-cg5NXTzNbldn41rljbPODl2J5jOnHhTpFshwb5i-i1kf5hGeYk2xdvQte55Z67vjyJn-3FScDKOZiEPRH4J92QTxPv9vlbJs15QHmvEfZAiWShampMSBLLPzqBcknMn8k6pQzuzpGh13JzoIuPpHkWJwloBivWuPdtC6rm7avU0FWPkSsanRLT1khBuB_PEs4t8yA7po2mKmRPTZeLBHjme5mtITF996qMESJ2kcmwn_y9LI6HScZjty9GjCE4uBaxLAwwNLyL2CanuBvvyF0V1dmy0ciBXqldLCFB9j1nXgXERtA1FUy9i-wkjXqsV_xPeCrJexMwMWNfe8bEgentVKbD9vIClsnA4N_95m-8NSDFd80zeVVyT7qMzUN5-Dml7IkXfNW3jV-FFyT3eVAjsFEY2L_9xT7Vg9Ft3mnoq_Pk3y0B6b9Mz_55ZqicvxR4qd5t--WUhp7SgSbl003LFALIMTZ35BXvp14noUvbSF3d_AeQpIbSyFQAA',
  },
  {
    'name': '4/4 BEGINNER',
    'desc': '4 giorni · split completa',
    'icon': '👊',
    'payload':
        'GYM1:H4sIAApl5WkC_9WXX0_bMBDAv4qV50RraZEYb6WDDQmmCvo2VdPFuTbWHDuzHWiH-O47JwGytupQ2cBIfajs2P7d_7u7iEuByn2FAqPjaKQygxDFkdGVE4qWvt1FGaza7f6HIe2lOltNwDhLu7M4KirLJZ4XsKBPVCVlHOESDRcWbX1eNYcvged0JbvSt3SJA7NAd43-lgG9h6W9ENbRgf5B3O_FRzO_yPUNmtVU-As-9uJIKIfmtL19ApWl9f4BbSjtcDKlV6Lm_7iWCpsFW5VoLLrPJFUZHdPnCzE_ExJbMovgMEuMvk2KBjK6jx-5L8Cxlj0wbgkuKUnhmb5VXeIrLMBpg4xrxU6EBMUFmtDoUzApSpmkdCTxL3oDvG_FT43gohROMBBsDDciMG6jSyRwm6-DnxlUPGcTg9YGxpxVRVr7if1BGk-4IXw0XfhxZeRuVz_YlOENHJ0TZ3Q_8-RPKfXgJSn1-mdFMbJT9OGG6LUFX1UB1mN2LfZFlGyakyXdX2l7r-1vuSi_u4atm1J1AUqAYp8QMinmAYKbFjHJHhDXND5Ks4pTXQgswL3C4QGtG9Yg5-wKap_fqeyj2P8OybNfkZoTXWI83R_MpqI8ulvBhzXr4Z6sA7ZkBSz3Qm7g1jPQ4CUZaGw0F3UGugRVpUY8Iy6O3qZ-zOWqa6oJ5UtgEwoYCK0x8rU4Keta3PWtHK1rSrRvi3xfFBo594gN-bZO-jrXlczQhC2ELYTLH_AT2zJv2mMkf9HYwKhLRQNShFcQHj1fNoib6aqJgXNFM6ACB7tFaPPW_qlruH_qEjUiJp2Z4SlE1vLZ8D93VIOtln3rduqdFfcLXLDTpUNlhVahTXe4SPCRbQ3aDxsB8jazxZaZqC3LbCTpaQpyEep4t1UCkH6M1uwErNWhFTtIJW7HvqTEQzLpoMbQHIqC6tgG8DNa1t6Lctw_aVln978BapFsfKsUAAA',
  },
];

List<Map<String, dynamic>> get kAllWorkoutTemplates => [
  ...kCuratedWorkoutTemplates,
  ...kWorkoutTemplates,
];

// --- DASHBOARD ---
class ClientMainPage extends StatefulWidget {
  const ClientMainPage({super.key});
  @override
  State<ClientMainPage> createState() => _ClientMainPageState();
}

class _ClientMainPageState extends State<ClientMainPage>
    with WidgetsBindingObserver {
  List<WorkoutDay> myRoutine = [];
  List<dynamic> history = [];
  Map<String, Map<String, dynamic>> _carryoverWeights = {};
  int _currentIndex = 0;
  int _streak = 0; // streak corrente
  Set<String> _streakDone = {}; // sessioni completate questa settimana

  // Impostazioni
  bool _stTimerSound = true;
  bool _stVibration = true;
  bool _stWakelock = true;
  bool _stAutoTimer = true;
  bool _stConfirmSeries = true;
  bool _stWeightHint = true;
  bool _stUsePounds = false;
  bool _stDisableWeightKeyboard = false;

  String _appLang = 'it';
  BannerAd? _bannerAd;
  bool _bannerAdLoaded = false;
  NativeAd? _exerciseListNativeAd;
  NativeAd? _graphNativeAd;
  NativeAd? _workoutProgressNativeAd;
  NativeAd? _overallProgressNativeAd;
  bool _exerciseListNativeAdLoaded = false;
  bool _graphNativeAdLoaded = false;
  bool _workoutProgressNativeAdLoaded = false;
  bool _overallProgressNativeAdLoaded = false;
  bool _webDonationLocked = false;
  bool _webDonationAcknowledged = false;
  bool _webDonationBannerHidden = false;
  int _webDonationDaysLeft = _webDonationGracePeriod.inDays;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
    _loadMainSettings();
    _loadLanguage();
    _loadBannerAd();
    _loadLibraryNativeAds();
    getStreakData().then((d) {
      if (mounted)
        setState(() {
          _streak = d.count;
          _streakDone = d.done;
        });
    });
    checkAndScheduleStreakNotification(_appLang);
    scheduleStreakReminder(_appLang);
    _refreshWebDonationGate();
    _maybeShowIosInstallHint();
    try {
      AdManager.instance.loadInterstitial();
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // noop - no clipboard/deep link logic needed
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bannerAd?.dispose();
    _exerciseListNativeAd?.dispose();
    _graphNativeAd?.dispose();
    super.dispose();
  }

  void _mostraMessaggio(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final lang = prefs.getString('app_lang') ?? 'it';
    AppL.setLang(lang);
    if (mounted) {
      setState(() => _appLang = lang);
      _refreshWebDonationGate();
    }
  }

  void _loadBannerAd() {
    if (kIsWeb) return;
    try {
      _bannerAd = BannerAd(
        adUnitId: AdManager.bannerAdUnitId,
        request: const AdRequest(),
        size: AdSize.banner,
        listener: BannerAdListener(
          onAdLoaded: (_) {
            if (mounted) setState(() => _bannerAdLoaded = true);
          },
          onAdFailedToLoad: (ad, error) {
            ad.dispose();
            _bannerAd = null;
          },
        ),
      )..load();
    } catch (_) {
      _bannerAd = null;
    }
  }

  void _loadLibraryNativeAds() {
    if (kIsWeb) return;
    void loadAd({required String placement, required String adUnitId}) {
      final current = switch (placement) {
        'exercise-list' => _exerciseListNativeAd,
        'graph' => _graphNativeAd,
        'workout-progress' => _workoutProgressNativeAd,
        'overall-progress' => _overallProgressNativeAd,
        _ => null,
      };
      current?.dispose();
      final ad = NativeAd(
        adUnitId: adUnitId,
        factoryId: kWorkoutNativeAdFactoryId,
        request: const AdRequest(),
        listener: NativeAdListener(
          onAdLoaded: (loadedAd) {
            if (!mounted) {
              loadedAd.dispose();
              return;
            }
            setState(() {
              switch (placement) {
                case 'exercise-list':
                  _exerciseListNativeAd = loadedAd as NativeAd;
                  _exerciseListNativeAdLoaded = true;
                  break;
                case 'graph':
                  _graphNativeAd = loadedAd as NativeAd;
                  _graphNativeAdLoaded = true;
                  break;
                case 'workout-progress':
                  _workoutProgressNativeAd = loadedAd as NativeAd;
                  _workoutProgressNativeAdLoaded = true;
                  break;
                case 'overall-progress':
                  _overallProgressNativeAd = loadedAd as NativeAd;
                  _overallProgressNativeAdLoaded = true;
                  break;
              }
            });
          },
          onAdFailedToLoad: (failedAd, error) {
            failedAd.dispose();
            if (!mounted) return;
            setState(() {
              switch (placement) {
                case 'exercise-list':
                  _exerciseListNativeAd = null;
                  _exerciseListNativeAdLoaded = false;
                  break;
                case 'graph':
                  _graphNativeAd = null;
                  _graphNativeAdLoaded = false;
                  break;
                case 'workout-progress':
                  _workoutProgressNativeAd = null;
                  _workoutProgressNativeAdLoaded = false;
                  break;
                case 'overall-progress':
                  _overallProgressNativeAd = null;
                  _overallProgressNativeAdLoaded = false;
                  break;
              }
            });
            debugPrint('$placement native ad failed to load: $error');
          },
        ),
      );
      switch (placement) {
        case 'exercise-list':
          _exerciseListNativeAd = ad;
          break;
        case 'graph':
          _graphNativeAd = ad;
          break;
        case 'workout-progress':
          _workoutProgressNativeAd = ad;
          break;
        case 'overall-progress':
          _overallProgressNativeAd = ad;
          break;
      }
      ad.load();
    }

    loadAd(placement: 'exercise-list', adUnitId: kExerciseListNativeAdUnitId);
    loadAd(placement: 'graph', adUnitId: kChartsNativeAdUnitId);
    loadAd(placement: 'workout-progress', adUnitId: kWorkoutProgressNativeAdUnitId);
    loadAd(placement: 'overall-progress', adUnitId: kOverallProgressNativeAdUnitId);
  }

  Widget _buildExerciseListNativeAd() {
    if (kIsWeb ||
        !_exerciseListNativeAdLoaded ||
        _exerciseListNativeAd == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: SizedBox(
        width: double.infinity,
        height: 86,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AdWidget(ad: _exerciseListNativeAd!),
        ),
      ),
    );
  }

  Widget _buildGraphNativeAd() {
    if (kIsWeb || !_graphNativeAdLoaded || _graphNativeAd == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: SizedBox(
        width: double.infinity,
        height: 86,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AdWidget(ad: _graphNativeAd!),
        ),
      ),
    );
  }

  Widget _buildWorkoutProgressNativeAd() {
    if (kIsWeb || !_workoutProgressNativeAdLoaded || _workoutProgressNativeAd == null)
      return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SizedBox(height: 80, child: AdWidget(ad: _workoutProgressNativeAd!)),
    );
  }

  Widget _buildOverallProgressNativeAd() {
    if (kIsWeb || !_overallProgressNativeAdLoaded || _overallProgressNativeAd == null)
      return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SizedBox(height: 80, child: AdWidget(ad: _overallProgressNativeAd!)),
    );
  }

  void _apriCostruttoreScheda() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ScheduleBuilderScreen()),
    ).then((_) => _loadData());
  }

  void _mostraPromoScreen() {
    final accent = Theme.of(context).colorScheme.primary;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('👨‍💼', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(
              AppL.proTrainer,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              AppL.promoText,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 15,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ...[
              AppL.proFeature1,
              AppL.proFeature2,
              AppL.proFeature3,
              AppL.proFeature4,
            ].map(
              (v) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        v,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final uri = Uri.parse('mailto:osare199@gmail.com');
                  if (await canLaunchUrl(uri)) await launchUrl(uri);
                },
                icon: const Text('📧', style: TextStyle(fontSize: 16)),
                label: Text(AppL.contactGianmarco),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _mostraAdEAvviaAllenamento(WorkoutDay day) {
    AdManager.instance.showStartInterstitialThenRun(() => _startWorkout(day));
  }

  Widget _buildMainSettingsDrawer() {
    final Color accent = appAccentNotifier.value;
    final List<Color> presets = [
      const Color(0xFF00F2FF), // ciano originale
      const Color(0xFF00E676), // verde lime
      const Color(0xFFFFD740), // giallo ambra
      const Color(0xFFFF6D00), // arancione
      const Color(0xFFEA80FC), // viola chiaro
      const Color(0xFFFF4081), // rosa
      const Color(0xFF448AFF), // blu elettrico
      const Color(0xFF69FF47), // verde neon
      const Color(0xFFFF6E40), // corallo
      const Color(0xFFE040FB), // viola neon
    ];
    return Drawer(
      backgroundColor: const Color(0xFF1C1C1E),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FutureBuilder<SharedPreferences>(
                future: SharedPreferences.getInstance(),
                builder: (ctx, snap) {
                  final name = snap.data?.getString('athlete_name') ?? '';
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isNotEmpty ? name.toUpperCase() : 'ATLETA',
                        style: TextStyle(
                          color: accent,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AppL.settings,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              const Divider(color: Colors.white12),

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'FEEDBACK',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              _mainSettingRow(
                Icons.notifications_active_outlined,
                AppL.timerSound,
                _stTimerSound,
                (v) {
                  setState(() => _stTimerSound = v);
                  _saveMainSettings();
                },
              ),
              _mainSettingRow(
                Icons.vibration,
                AppL.timerVibration,
                _stVibration,
                (v) {
                  setState(() => _stVibration = v);
                  _saveMainSettings();
                },
              ),
              const Divider(color: Colors.white12),

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'TIMER',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              _mainSettingRow(
                Icons.timer_outlined,
                AppL.autoStartTimer,
                _stAutoTimer,
                (v) {
                  setState(() => _stAutoTimer = v);
                  _saveMainSettings();
                },
              ),
              _mainSettingRow(
                Icons.screen_lock_portrait_outlined,
                AppL.screenAlwaysOn,
                _stWakelock,
                (v) {
                  setState(() => _stWakelock = v);
                  _saveMainSettings();
                },
              ),
              const Divider(color: Colors.white12),

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'SERIE',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              _mainSettingRow(
                Icons.check_circle_outline,
                AppL.confirmSeriesWindow,
                _stConfirmSeries,
                (v) {
                  setState(() => _stConfirmSeries = v);
                  _saveMainSettings();
                },
              ),
              _mainSettingRow(
                Icons.trending_up,
                AppL.weightSuggestion,
                _stWeightHint,
                (v) {
                  setState(() => _stWeightHint = v);
                  _saveMainSettings();
                },
              ),
              _mainSegmentSettingRow(
                Icons.straighten,
                AppL.lang == 'en' ? 'Weight unit' : 'Unita peso',
                selectedKey: _stUsePounds ? 'lb' : 'kg',
                options: {
                  'kg': AppL.lang == 'en' ? 'KG' : 'KG',
                  'lb': AppL.lang == 'en' ? 'POUNDS' : 'LIBBRE',
                },
                onChanged: (value) {
                  setState(() => _stUsePounds = value == 'lb');
                  _saveMainSettings();
                },
              ),
              _mainSettingRow(
                Icons.keyboard_hide_outlined,
                AppL.lang == 'en' ? 'No keyboard' : 'No tastiera',
                _stDisableWeightKeyboard,
                (v) {
                  setState(() => _stDisableWeightKeyboard = v);
                  _saveMainSettings();
                },
              ),
              const Divider(color: Colors.white12),

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'TUTORIAL',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('workout_tutorial_shown', false);
                  if (mounted) {
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (c, anim, _) => WorkoutTutorial(
                          accentColor: accent,
                          onComplete: () {
                            Navigator.pop(context);
                            prefs.setBool('workout_tutorial_shown', true);
                          },
                        ),
                        transitionsBuilder: (c, anim, _, child) => FadeTransition(
                          opacity: anim,
                          child: child,
                        ),
                      ),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(10),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: accent.withAlpha(100),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.school_outlined,
                        color: accent,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          AppL.lang == 'en' ? 'Watch Tutorial' : 'Rivedere Tutorial',
                          style: TextStyle(
                            color: accent,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(color: Colors.white12),

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'COLORE TEMA',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: presets.map((c) {
                  final selected = accent.toARGB32() == c.toARGB32();
                  return GestureDetector(
                    onTap: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setInt('accent_color', c.toARGB32());
                      appAccentNotifier.value = c;
                      setState(() {});
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: selected
                            ? Border.all(color: Colors.white, width: 3)
                            : null,
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: c.withAlpha(120),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                      child: selected
                          ? const Icon(
                              Icons.check,
                              color: Colors.black,
                              size: 18,
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const Divider(color: Colors.white12),

              const Divider(color: Colors.white12),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  AppL.language.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.language,
                            color: Colors.white54,
                            size: 20,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            AppL.language,
                            softWrap: true,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: _appLang,
                    dropdownColor: const Color(0xFF2C2C2E),
                    style: const TextStyle(color: Colors.white),
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(
                        value: 'it',
                        child: Text('🇮🇹 Italiano'),
                      ),
                      DropdownMenuItem(
                        value: 'en',
                        child: Text('🇬🇧 English'),
                      ),
                    ],
                    onChanged: (v) async {
                      if (v == null) return;
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString('app_lang', v);
                      AppL.setLang(v);
                      setState(() => _appLang = v);
                    },
                  ),
                ],
              ),
              const Divider(color: Colors.white12),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'GYMAPP PRO',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Text('👨‍💼', style: TextStyle(fontSize: 16)),
                  label: Text(
                    AppL.gymAppPro,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _mostraPromoScreen();
                  },
                ),
              ),
              const Divider(color: Colors.white12),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'DATI',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    letterSpacing: 1.5,
                  ),
                ),
              ),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(
                    Icons.storage_rounded,
                    color: Colors.redAccent,
                  ),
                  label: Text(
                    AppL.dataManagement,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CancellazioneScreen(
                          history: history,
                          routine: myRoutine,
                          onSave: (newHistory) async {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setString(
                              'client_history',
                              jsonEncode(newHistory),
                            );
                            if (mounted) {
                              setState(() {
                                history = newHistory;
                              });
                            }
                          },
                        ),
                      ),
                    ).then((didChange) {
                      if (didChange == true) {
                        _loadData();
                      }
                    });
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mainSettingRow(
    IconData icon,
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(icon, color: appAccentNotifier.value, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  softWrap: true,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: appAccentNotifier.value,
        ),
      ],
    );
  }

  Widget _mainSegmentSettingRow(
    IconData icon,
    String label, {
    required String selectedKey,
    required Map<String, String> options,
    required ValueChanged<String> onChanged,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(icon, color: appAccentNotifier.value, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  softWrap: true,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Wrap(
          spacing: 8,
          children: options.entries.map((entry) {
            final selected = selectedKey == entry.key;
            return ChoiceChip(
              label: Text(
                entry.value,
                style: TextStyle(
                  color: selected ? Colors.black : Colors.white70,
                  fontWeight: FontWeight.w700,
                ),
              ),
              selected: selected,
              onSelected: (_) => onChanged(entry.key),
              selectedColor: appAccentNotifier.value,
              backgroundColor: Colors.white10,
              side: BorderSide(
                color: selected ? appAccentNotifier.value : Colors.white12,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Future<void> _loadMainSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _stTimerSound = prefs.getBool('timer_sound_enabled') ?? true;
      _stVibration = prefs.getBool('vibration_enabled') ?? true;
      _stWakelock = prefs.getBool('wakelock_enabled') ?? true;
      _stAutoTimer = prefs.getBool('auto_start_timer') ?? true;
      _stConfirmSeries = prefs.getBool('confirm_series_enabled') ?? true;
      _stWeightHint = prefs.getBool('show_weight_suggestion') ?? true;
      _stUsePounds = prefs.getBool('use_pounds') ?? false;
      _stDisableWeightKeyboard =
          prefs.getBool('disable_weight_keyboard') ?? false;
    });
  }

  Future<void> _saveMainSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('timer_sound_enabled', _stTimerSound);
    await prefs.setBool('vibration_enabled', _stVibration);
    await prefs.setBool('wakelock_enabled', _stWakelock);
    await prefs.setBool('auto_start_timer', _stAutoTimer);
    await prefs.setBool('confirm_series_enabled', _stConfirmSeries);
    await prefs.setBool('show_weight_suggestion', _stWeightHint);
    await prefs.setBool('use_pounds', _stUsePounds);
    await prefs.setBool('disable_weight_keyboard', _stDisableWeightKeyboard);
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    // Recuperiamo le stringhe, se sono null usiamo una stringa che rappresenta una lista vuota "[]"
    final String routineString = prefs.getString('client_routine') ?? "[]";
    final String historyString = prefs.getString('client_history') ?? "[]";
    final String carryoverString = prefs.getString('carryover_weights') ?? "{}";

    setState(() {
      try {
        // Se la stringa è proprio vuota "", jsonDecode si rompe.
        // Quindi controlliamo che non sia vuota prima di procedere.
        if (routineString.trim().isNotEmpty && routineString != "null") {
          myRoutine = (jsonDecode(routineString) as List)
              .map((i) => WorkoutDay.fromJson(i))
              .toList();
        } else {
          myRoutine = [];
        }

        if (historyString.trim().isNotEmpty && historyString != "null") {
          history = jsonDecode(historyString);
        } else {
          history = [];
        }

        try {
          if (carryoverString.trim().isNotEmpty && carryoverString != "null") {
            final raw = jsonDecode(carryoverString) as Map<String, dynamic>;
            _carryoverWeights = raw.map(
              (k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map)),
            );
          }
        } catch (_) {
          _carryoverWeights = {};
        }
      } catch (e) {
        // Se c'è un errore nel formato, resettiamo a liste vuote invece di crashare
        debugPrint("Errore nel caricamento dati: $e");
        myRoutine = [];
        history = [];
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      endDrawer: _buildMainSettingsDrawer(),
      appBar: AppBar(
        title: const Text(
          "GYM LOGBOOK",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.bar_chart_rounded, color: Colors.white),
          tooltip: AppL.lang == 'en' ? 'Overall Progress' : 'Progressi',
          onPressed: _showOverallProgressPage,
        ),
        actions: [
          Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.settings_outlined, size: 22),
              onPressed: () => Scaffold.of(ctx).openEndDrawer(),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              if (kIsWeb && _currentIndex == 1) _buildWebDonationBanner(),
              Expanded(
                child: _currentIndex == 0
                    ? _buildRoutinePage()
                    : _buildTrainPage(),
              ),
              if (_bannerAdLoaded && _bannerAd != null && !kIsWeb)
                SizedBox(
                  width: _bannerAd!.size.width.toDouble(),
                  height: _bannerAd!.size.height.toDouble(),
                  child: AdWidget(ad: _bannerAd!),
                ),
            ],
          ),
          _buildWebDonationOverlay(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        backgroundColor: Colors.black,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.white24,
        type: BottomNavigationBarType.fixed,
        onTap: (i) => setState(() => _currentIndex = i),
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.view_list_rounded),
            label: AppL.mySchedule,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.fitness_center_rounded),
            label: AppL.train,
          ),
        ],
      ),
    );
  }

  Widget _buildRoutinePage() {
    final accent = Theme.of(context).colorScheme.primary;
    if (myRoutine.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.view_list_rounded,
              color: accent.withAlpha(60),
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              AppL.noScheduleLoaded,
              style: const TextStyle(color: Colors.white38, fontSize: 16),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _apriCostruttoreScheda,
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: Text(AppL.createSchedule.toUpperCase()),
              style: OutlinedButton.styleFrom(
                foregroundColor: accent,
                side: BorderSide(color: accent.withAlpha(120)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
      children: [
        for (int i = 0; i < myRoutine.length; i++) ...[
          _buildRoutineCard(myRoutine[i], accent, i),
          const SizedBox(height: 14),
        ],
        Center(
          child: TextButton.icon(
            onPressed: _apriCostruttoreScheda,
            icon: const Icon(Icons.edit_note_rounded, size: 16),
            label: Text(AppL.editOrCreate),
            style: TextButton.styleFrom(foregroundColor: Colors.white38),
          ),
        ),
      ],
    );
  }

  Widget _buildRoutineCard(WorkoutDay day, Color accent, int index) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => _showWorkoutProgress(day),
        borderRadius: BorderRadius.circular(20),
        splashColor: accent.withAlpha(30),
        highlightColor: accent.withAlpha(15),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [accent.withAlpha(28), const Color(0xFF1C1C1E)],
            ),
            border: Border.all(color: accent.withAlpha(55), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: accent.withAlpha(30),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                // Immagine sfondo sfumata a destra
                if (day.muscleImage != null)
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.15,
                      child: Image.asset(
                        muscleAssetPath(day.muscleImage),
                        fit: BoxFit.cover,
                        alignment: Alignment.centerRight,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 18,
                  ),
                  child: Row(
                    children: [
                      // Immagine / emoji a sinistra
                      if (day.muscleImage != null)
                        GestureDetector(
                          onTap: () => _showImageFullscreen(
                            context,
                            day.muscleImage!,
                            localizeMixedLabel(day.dayName),
                          ),
                          child: Hero(
                            tag: 'muscle_${day.muscleImage}',
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.asset(
                                muscleAssetPath(day.muscleImage),
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        )
                      else if (day.bodyParts.isNotEmpty)
                        SizedBox(
                          width: 64,
                          height: 64,
                          child: Center(
                            child: Text(
                              day.bodyParts
                                  .map((k) => kBodyPartIcons[k] ?? '')
                                  .where((e) => e.isNotEmpty)
                                  .join(' '),
                              style: const TextStyle(fontSize: 28),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      const SizedBox(width: 16),
                      // Nome centrato alla destra dell'immagine
                      Expanded(
                        child: Text(
                          localizeMixedLabel(day.dayName),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      // Icona lista esercizi: tap → lista diretta
                      GestureDetector(
                        onTap: () => _showDayDetail(day),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.format_list_bulleted_rounded,
                            color: Colors.white38,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showWorkoutProgress(WorkoutDay day) {
    final accent = Theme.of(context).colorScheme.primary;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E0E10),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (c) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.78,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            // Header: nome + link esercizi
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 16, 8),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 22,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      day.dayName.toUpperCase(),
                      style: TextStyle(
                        color: accent,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(c);
                      _showDayDetail(day);
                    },
                    icon: const Icon(Icons.list_alt_rounded, size: 16),
                    label: Text(AppL.exercises),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: Colors.white.withAlpha(10), height: 1),
            // Immagine muscolo (tap → fullscreen)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: day.muscleImage != null
                  ? GestureDetector(
                      onTap: () {
                        Navigator.pop(c);
                        _showImageFullscreen(
                          context,
                          day.muscleImage!,
                          day.dayName,
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.asset(
                          muscleAssetPath(day.muscleImage),
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    )
                  : day.bodyParts.isNotEmpty
                  ? Center(
                      child: Text(
                        day.bodyParts
                            .map((k) => kBodyPartIcons[k] ?? '')
                            .where((e) => e.isNotEmpty)
                            .join(' '),
                        style: const TextStyle(fontSize: 60),
                      ),
                    )
                  : const SizedBox(height: 8),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.trending_up_rounded,
                        color: Colors.white38,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        AppL.workoutProgress,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 260,
                    child: _WorkoutProgressChart(
                      day: day,
                      history: history,
                      accent: accent,
                    ),
                  ),
                  _buildWorkoutProgressNativeAd(),
                  if (!kIsWeb) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _shareLastSession(context, day),
                            icon: const Icon(Icons.share_rounded, size: 16),
                            label: const Text('Condividi 🏋️'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: accent,
                              side: BorderSide(color: accent.withAlpha(80)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(c);
                              _showOverallProgressPage();
                            },
                            icon: const Icon(Icons.bar_chart_rounded, size: 16),
                            label: Text(AppL.lang == 'en' ? 'Progress' : 'Progressi'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: accent,
                              side: BorderSide(color: accent.withAlpha(80)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showImageFullscreen(BuildContext ctx, String imageFile, String label) {
    Navigator.push(
      ctx,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        barrierDismissible: true,
        pageBuilder: (_, __, ___) => GestureDetector(
          onTap: () => Navigator.pop(ctx),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: Stack(
                children: [
                  Center(
                    child: Hero(
                      tag: 'muscle_$imageFile',
                      child: InteractiveViewer(
                        child: Image.asset(
                          muscleAssetPath(imageFile),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 16,
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        shadows: [Shadow(blurRadius: 8, color: Colors.black)],
                      ),
                    ),
                  ),
                  const Positioned(
                    top: 12,
                    right: 16,
                    child: Icon(Icons.close, color: Colors.white70, size: 28),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showDayDetail(WorkoutDay day) {
    final accent = Theme.of(context).colorScheme.primary;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E0E10),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (c) => StatefulBuilder(
        builder: (ctx2, setSheet) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            children: [
              // Handle bar
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 24,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        day.dayName.toUpperCase(),
                        style: TextStyle(
                          color: accent,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    Text(
                      '${day.exercises.length} ${AppL.exercises.toLowerCase()}',
                      style: const TextStyle(
                        color: Colors.white24,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(color: Colors.white.withAlpha(10), height: 1),
              // Exercise list
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: day.exercises.length + 1,
                  separatorBuilder: (_, __) => Divider(
                    color: Colors.white.withAlpha(8),
                    height: 1,
                    indent: 24,
                    endIndent: 24,
                  ),
                  itemBuilder: (ctx, idx) {
                    if (idx == day.exercises.length) {
                      return _buildExerciseListNativeAd();
                    }
                    final ex = day.exercises[idx];
                    final scheme = _repsSchemeText(ex);
                    final isSuperset = ex.supersetGroup > 0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          // YouTube button
                          InkWell(
                            borderRadius: BorderRadius.circular(22),
                            onTap: () {
                              if (kIsWeb) {
                                cercaEsercizioSuYoutube(ex.name);
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        YouTubeSearchView(esercizio: ex.name),
                                  ),
                                );
                              }
                            },
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: Colors.red.withAlpha(18),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.red.withAlpha(40),
                                ),
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.red,
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Exercise info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    if (isSuperset)
                                      Container(
                                        margin: const EdgeInsets.only(right: 6),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 5,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.deepPurple.withAlpha(
                                            80,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          border: Border.all(
                                            color: Colors.deepPurple.withAlpha(
                                              100,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          'S${ex.supersetGroup}',
                                          style: const TextStyle(
                                            fontSize: 9,
                                            color: Colors.purpleAccent,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    Expanded(
                                      child: InkWell(
                                        onTap: () =>
                                            _showExerciseDetail(context, ex),
                                        borderRadius: BorderRadius.circular(6),
                                        child: Text(
                                          localizedExerciseName(ex.name),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                            color: Colors.white,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  scheme,
                                  style: TextStyle(
                                    color: Colors.white.withAlpha(100),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Edit exercise button
                          InkWell(
                            borderRadius: BorderRadius.circular(22),
                            onTap: () async {
                              Navigator.pop(c);
                              final dayIdx = myRoutine.indexOf(day);
                              if (dayIdx >= 0) await _editExercise(dayIdx, idx);
                              if (mounted) _showDayDetail(day);
                            },
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white10,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.edit_rounded,
                                color: Colors.white38,
                                size: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Chart button
                          InkWell(
                            borderRadius: BorderRadius.circular(22),
                            onTap: () {
                              _showGraph(ex.name);
                            },
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: accent.withAlpha(18),
                                shape: BoxShape.circle,
                                border: Border.all(color: accent.withAlpha(40)),
                              ),
                              child: Icon(
                                Icons.insights_rounded,
                                color: accent,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showExerciseDetail(BuildContext ctx, ExerciseConfig ex) {
    final accent = Theme.of(ctx).colorScheme.primary;
    // Le info seguono la GIF (se presente), altrimenti il nome
    final info =
        (ex.gifFilename != null ? findByGifSlug(ex.gifFilename!) : null) ??
        findAnyExercise(ex.name);
    final gifPath = ex.gifFilename != null
        ? exerciseAnimationAssetPath(ex.gifFilename!)
        : info != null
        ? exerciseAnimationAssetPath(info.gifSlug)
        : null;

    showModalBottomSheet(
      context: ctx,
      backgroundColor: const Color(0xFF0E0E10),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (c) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 3,
                  height: 22,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    localizedExerciseName(ex.name).toUpperCase(),
                    style: TextStyle(
                      color: accent,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
            if (info != null) ...[
              const SizedBox(height: 4),
              Text(
                AppL.lang == 'en' ? info.nameEn : info.name,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 16),
            // GIF esercizio
            if (gifPath != null)
              Image.asset(
                gifPath,
                width: 280,
                height: 280,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.fitness_center,
                  size: 80,
                  color: Colors.white30,
                ),
              ),
            const SizedBox(height: 16),
            if (info != null && info.muscleImages.isNotEmpty)
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: info.muscleImages.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      muscleAssetPath(info.muscleImages[i]),
                      width: 100,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            if (info != null && info.muscleImages.isNotEmpty)
              const SizedBox(height: 16),
            if (info != null) ...[
              _infoTile(
                Icons.fitness_center_rounded,
                AppL.primaryMuscle,
                translateMuscle(info.primaryMuscle),
                Colors.white70,
              ),
              if (info.secondaryMuscles.isNotEmpty)
                _infoTile(
                  Icons.grain_rounded,
                  AppL.secondaryMuscles,
                  translateMuscle(info.secondaryMuscles),
                  Colors.white54,
                ),
              const SizedBox(height: 12),
              _sectionCard(
                AppL.execution,
                translateExerciseText(info.execution),
                const Color(0xFF1C1C1E),
              ),
              const SizedBox(height: 8),
              _sectionCard(
                AppL.tips,
                translateExerciseText(info.tips),
                Colors.amber.withAlpha(15),
              ),
            ] else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  AppL.notInCatalog,
                  style: const TextStyle(color: Colors.white38, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 16),
            Divider(color: Colors.white12),
            const SizedBox(height: 8),
            Row(
              children: [
                _statChip(
                  '${ex.targetSets} ${AppL.sets.toLowerCase()}',
                  Icons.repeat_rounded,
                  accent,
                ),
                const SizedBox(width: 8),
                _statChip(
                  '${ex.repsList.isNotEmpty ? ex.repsList.join('-') : '?'} reps',
                  Icons.numbers_rounded,
                  accent,
                ),
                if (ex.recoveryTime > 0) ...[
                  const SizedBox(width: 8),
                  _statChip(
                    '${ex.recoveryTime}s ${AppL.recoverySuffix}',
                    Icons.timer_outlined,
                    Colors.white38,
                  ),
                ],
              ],
            ),
            if (ex.notePT.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                  border: const Border(
                    left: BorderSide(color: Colors.amber, width: 3),
                  ),
                ),
                child: Text(
                  'NOTE COACH: ${ex.notePT}',
                  style: const TextStyle(color: Colors.amber, fontSize: 13),
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(c);
                  if (kIsWeb) {
                    cercaEsercizioSuYoutube(info?.nameEn ?? ex.name);
                  } else {
                    Navigator.push(
                      ctx,
                      MaterialPageRoute(
                        builder: (_) => YouTubeSearchView(
                          esercizio: info?.nameEn ?? ex.name,
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(
                  Icons.play_circle_outline_rounded,
                  color: Colors.red,
                ),
                label: Text(
                  AppL.watchOnYoutube,
                  style: const TextStyle(color: Colors.red),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.red.withAlpha(80)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value, Color color) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              '$label: ',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            Expanded(
              child: Text(value, style: TextStyle(color: color, fontSize: 12)),
            ),
          ],
        ),
      );

  Widget _sectionCard(String title, String body, Color bg) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          body,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ],
    ),
  );

  Widget _statChip(String label, IconData icon, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withAlpha(20),
      border: Border.all(color: color.withAlpha(60)),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 11)),
      ],
    ),
  );

  void _showGraph(String name) {
    final accent = Theme.of(context).colorScheme.primary;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0E0E10),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (c) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(Icons.insights_rounded, color: accent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              AppL.progressOverTime,
              style: const TextStyle(color: Colors.white24, fontSize: 11),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 320,
              child: PTGraphWidget(exerciseName: name, history: history),
            ),
            _buildGraphNativeAd(),
          ],
        ),
      ),
    );
  }

  String _repsSchemeText(ExerciseConfig ex) {
    if (ex.repsList.isEmpty) return '${ex.targetSets}×?';
    final reps = ex.repsList.take(ex.targetSets).toList();
    if (reps.every((r) => r == reps.first))
      return '${reps.length}×${reps.first}';
    return reps.join('–');
  }

  Widget _exPreviewRow(
    String name,
    String scheme,
    Color accent,
    bool isSuperset,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: isSuperset ? 8 : 6,
            height: isSuperset ? 8 : 6,
            margin: EdgeInsets.only(right: 10, top: isSuperset ? 3 : 4),
            decoration: BoxDecoration(
              color: isSuperset ? accent : accent.withAlpha(180),
              shape: isSuperset ? BoxShape.rectangle : BoxShape.circle,
              borderRadius: isSuperset ? BorderRadius.circular(2) : null,
            ),
          ),
          Expanded(
            child: Text(
              '$name  •  $scheme',
              style: TextStyle(
                color: isSuperset ? Colors.white70 : Colors.white60,
                fontSize: 13,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExPreviewList(WorkoutDay d, Color accent) {
    final List<Widget> items = [];
    final Set<int> processedGroups = {};
    int count = 0;
    for (final ex in d.exercises) {
      if (count >= 4) break;
      if (ex.supersetGroup == 0) {
        items.add(_exPreviewRow(ex.name, _repsSchemeText(ex), accent, false));
        count++;
      } else {
        if (!processedGroups.contains(ex.supersetGroup)) {
          processedGroups.add(ex.supersetGroup);
          final group = d.exercises
              .where((e) => e.supersetGroup == ex.supersetGroup)
              .toList();
          final names = group.map((e) => e.name).join(' + ');
          final schemes = group.map((e) => _repsSchemeText(e)).join(' / ');
          items.add(_exPreviewRow(names, schemes, accent, true));
          count++;
        }
      }
    }
    return Column(children: items);
  }

  String _lastTrainedLabel(WorkoutDay day) {
    DateTime? latest;
    for (final ex in day.exercises) {
      for (final h in history) {
        if ((h as Map)['exercise'] == ex.name) {
          try {
            final d = DateTime.parse(h['date'] as String);
            if (latest == null || d.isAfter(latest)) latest = d;
          } catch (_) {}
        }
      }
    }
    if (latest == null) return AppL.neverTrained;
    final diff = DateTime.now().difference(latest).inDays;
    if (diff == 0) return AppL.today;
    if (diff == 1) return AppL.yesterday;
    return '$diff ${AppL.daysAgo}';
  }

  Future<void> _dismissWebDonationBanner() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _webDonationBannerDismissedAtKey,
      DateTime.now().toIso8601String(),
    );
    if (mounted) setState(() => _webDonationBannerHidden = true);
  }

  Future<void> _refreshWebDonationGate() async {
    if (!kIsWeb) return;
    final gate = await getWebDonationGateState();
    if (!mounted) return;
    bool bannerHidden = false;
    if (!gate.locked) {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_webDonationBannerDismissedAtKey);
      if (raw != null) {
        final dismissedAt = DateTime.tryParse(raw);
        if (dismissedAt != null &&
            DateTime.now().difference(dismissedAt) < _webDonationBannerHideDuration) {
          bannerHidden = true;
        }
      }
    }
    setState(() {
      _webDonationLocked = gate.locked;
      _webDonationAcknowledged = gate.acknowledged;
      _webDonationDaysLeft = gate.daysLeft;
      _webDonationBannerHidden = bannerHidden;
    });
  }

  Future<void> _maybeShowIosInstallHint() async {
    if (!kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_webIosInstallHintSeenKey) ?? false) return;
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            AppL.lang == 'en'
                ? 'Use GymApp like an iPhone app'
                : 'Usa GymApp come un\'app su iPhone',
            textAlign: TextAlign.center,
          ),
          content: Text(
            AppL.lang == 'en'
                ? 'On iPhone or iPad, open GymApp in Safari, tap Share, choose \"Add to Home Screen\", then tap Add. You will get the app icon directly on the home screen.'
                : 'Su iPhone o iPad apri GymApp in Safari, tocca Condividi, scegli \"Aggiungi a Home\", poi tocca Aggiungi. Avrai l\'icona dell\'app direttamente nella schermata Home.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, height: 1.4),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(c),
                child: Text(AppL.lang == 'en' ? 'Got it' : 'Ho capito'),
              ),
            ),
          ],
        ),
      );
      await prefs.setBool(_webIosInstallHintSeenKey, true);
    });
  }

  Future<bool> _acknowledgeWebDonation() async {
    final textCtrl = TextEditingController();
    final receiptId = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          AppL.lang == 'en'
              ? 'Enter the PayPal transaction ID'
              : 'Inserisci l\'ID transazione PayPal',
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppL.lang == 'en'
                  ? 'GymApp Web unlocks only after you enter the transaction code from your PayPal receipt for this month.'
                  : 'GymApp Web si sblocca solo dopo aver inserito il codice transazione presente nella ricevuta PayPal di questo mese.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: AppL.lang == 'en'
                    ? 'Example: 8AB12345CD6789012'
                    : 'Esempio: 8AB12345CD6789012',
                hintStyle: const TextStyle(color: Colors.white38),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Theme.of(c).colorScheme.primary,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(AppL.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, textCtrl.text.trim()),
            child: Text(AppL.lang == 'en' ? 'Confirm' : 'Conferma'),
          ),
        ],
      ),
    );
    final normalized = receiptId?.trim().toUpperCase() ?? '';
    if (!RegExp(r'^[A-Z0-9]{10,24}$').hasMatch(normalized)) {
      if (mounted && normalized.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppL.lang == 'en'
                  ? 'Enter a valid PayPal transaction ID.'
                  : 'Inserisci un ID transazione PayPal valido.',
            ),
          ),
        );
      }
      return false;
    }
    await _recordWebDonationProceed(normalized);
    await _refreshWebDonationGate();
    return true;
  }

  Future<bool> _handleWebDonationStartGate() async {
    final gate = await getWebDonationGateState();
    if (!gate.locked) return true;
    if (!mounted) return false;
    final proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          AppL.lang == 'en'
              ? 'Monthly donation required'
              : 'Donazione mensile richiesta',
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppL.lang == 'en'
                  ? 'To keep using GymApp Web, donate at least €1 every month. These funds are used to publish the app on the Apple App Store.'
                  : 'Per continuare a usare GymApp Web devi donare almeno 1€ al mese. Questi fondi vengono usati per pubblicare l\'app su Apple App Store.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              AppL.lang == 'en'
                  ? 'After donating, enter the PayPal transaction ID from your receipt to unlock the workout.'
                  : 'Dopo la donazione inserisci l\'ID transazione PayPal presente nella ricevuta per sbloccare l\'allenamento.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(AppL.lang == 'en' ? 'Close app' : 'Chiudi'),
          ),
          OutlinedButton(
            onPressed: () async {
              await openPaypalDonationPage();
            },
            child: Text(AppL.lang == 'en' ? 'Open PayPal' : 'Apri PayPal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(
              AppL.lang == 'en'
                  ? 'Enter transaction ID'
                  : 'Inserisci ID transazione',
            ),
          ),
        ],
      ),
    );
    if (proceed == true) {
      return _acknowledgeWebDonation();
    }
    return false;
  }

  Widget _buildWebDonationBanner() {
    if (!kIsWeb) return const SizedBox.shrink();
    if (_webDonationBannerHidden && !_webDonationLocked) return const SizedBox.shrink();
    final accent = Theme.of(context).colorScheme.primary;
    final dueLabel = _webDonationAcknowledged
        ? (AppL.lang == 'en'
              ? 'Next monthly donation due in $_webDonationDaysLeft day${_webDonationDaysLeft == 1 ? '' : 's'}.'
              : 'Prossima donazione mensile tra $_webDonationDaysLeft giorn${_webDonationDaysLeft == 1 ? 'o' : 'i'}.')
        : (AppL.lang == 'en'
              ? 'Donate at least €1 within $_webDonationDaysLeft day${_webDonationDaysLeft == 1 ? '' : 's'} to keep using the web app.'
              : 'Dona almeno 1€ entro $_webDonationDaysLeft giorn${_webDonationDaysLeft == 1 ? 'o' : 'i'} per continuare a usare la web app.');
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _webDonationLocked ? Colors.redAccent : accent.withAlpha(90),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppL.lang == 'en'
                      ? 'GymApp Web requires a monthly donation'
                      : 'GymApp Web richiede una donazione mensile',
                  style: TextStyle(
                    color: _webDonationLocked ? Colors.redAccent : accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              if (!_webDonationLocked)
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: _dismissWebDonationBanner,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            AppL.lang == 'en'
                ? 'If you do not donate at least €1 every month, GymApp Web will stop working. Donations fund the Apple App Store publication.'
                : 'Se non doni almeno 1€ ogni mese, GymApp Web non potra piu essere usata. Le donazioni finanziano la pubblicazione su Apple App Store.',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            dueLabel,
            style: TextStyle(
              color: _webDonationLocked ? Colors.redAccent : Colors.white60,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: openPaypalDonationPage,
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: Text(AppL.lang == 'en' ? 'Open PayPal' : 'Apri PayPal'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: accent,
                  side: BorderSide(color: accent),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _acknowledgeWebDonation,
                  child: Text(
                    AppL.lang == 'en'
                        ? 'Enter transaction ID'
                        : 'Inserisci ID transazione',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWebDonationOverlay() {
    if (!kIsWeb || !_webDonationLocked) return const SizedBox.shrink();
    final accent = Theme.of(context).colorScheme.primary;
    return Positioned.fill(
      child: Container(
        color: Colors.black.withAlpha(220),
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.redAccent.withAlpha(180)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.lock_outline_rounded,
                    color: Colors.redAccent,
                    size: 42,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AppL.lang == 'en'
                        ? 'GymApp Web is locked until you confirm this month\'s donation'
                        : 'GymApp Web e bloccata finche non confermi la donazione di questo mese',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    AppL.lang == 'en'
                        ? 'Donate at least €1 to support development and fund the Apple App Store release, then enter the PayPal transaction ID from your receipt.'
                        : 'Dona almeno 1€ per supportare lo sviluppo e finanziare l\'uscita su Apple App Store, poi inserisci l\'ID transazione PayPal presente nella ricevuta.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, height: 1.35),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: openPaypalDonationPage,
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: Text(
                        AppL.lang == 'en'
                            ? 'Open paypal.me/gianmarcosare'
                            : 'Apri paypal.me/gianmarcosare',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: accent,
                        side: BorderSide(color: accent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _acknowledgeWebDonation,
                      child: Text(
                        AppL.lang == 'en'
                            ? 'Enter transaction ID'
                            : 'Inserisci ID transazione',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _startWorkout(WorkoutDay d) async {
    if (!await _handleWebDonationStartGate()) return;
    
    // Check if tutorial should be shown
    final prefs = await SharedPreferences.getInstance();
    final tutorialShown = prefs.getBool('workout_tutorial_shown') ?? false;
    
    if (!tutorialShown && !kIsWeb) {
      // Show tutorial first
      if (!mounted) return;
      await Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (c, anim, _) => WorkoutTutorial(
            accentColor: appAccentNotifier.value,
            onComplete: () {
              Navigator.pop(context);
            },
          ),
          transitionsBuilder: (c, anim, _, child) => FadeTransition(
            opacity: anim,
            child: child,
          ),
        ),
      );
      await prefs.setBool('workout_tutorial_shown', true);
      if (!mounted) return;
    }
    
    // Cancella SEMPRE lo snapshot precedente: ogni tap su "Allena ora" è una nuova sessione.
    // Il ripristino automatico avviene solo se l'app viene chiusa MID-workout.
    await prefs.remove('workout_in_progress_${d.dayName}');
    // Resetta i risultati in memoria dell'allenamento precedente
    for (final ex in d.exercises) {
      ex.results = [];
    }
    if (!mounted) return;
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (c, anim, _) => WorkoutEngine(
          day: d,
          history: history,
          carryoverWeights: _carryoverWeights,
          allSessionNames: myRoutine.map((r) => r.dayName).toList(),
          onDone: (session) async {
            history.add(session);
            final prefs2 = await SharedPreferences.getInstance();
            await prefs2.setString('client_history', jsonEncode(history));
            _loadData();
          },
        ),
        transitionsBuilder: (c, anim, _, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    ).then((_) async {
      // Ricarica streak aggiornata quando si torna dalla schermata allenamento
      final d = await getStreakData();
      if (mounted)
        setState(() {
          _streak = d.count;
          _streakDone = d.done;
        });
    });
  }

  void _showOverallProgressPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _OverallProgressPage(
          history: history,
          routine: myRoutine,
          streak: _streak,
          accent: appAccentNotifier.value,
          buildAd: _buildOverallProgressNativeAd,
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _buildLastSessionExercises(String dayName) {
    final Map<String, List<Map<String, dynamic>>> bySid = {};
    final Map<String, DateTime> sidDate = {};
    for (final h in history) {
      if ((h['dayName'] as String?) != dayName) continue;
      final sid = (h['session_id'] as String?)?.isNotEmpty == true
          ? h['session_id'] as String
          : ((h['date'] as String?) ?? '').substring(0, 10);
      bySid.putIfAbsent(sid, () => []).add(Map<String, dynamic>.from(h));
      sidDate.putIfAbsent(sid, () => DateTime.tryParse((h['date'] as String?) ?? '') ?? DateTime(2000));
    }
    if (bySid.isEmpty) return [];
    final lastSid = sidDate.entries.reduce((a, b) => a.value.isAfter(b.value) ? a : b).key;
    return bySid[lastSid]!.map((h) => {
      'exercise': h['exercise'] as String? ?? '',
      'series': (h['series'] as List?) ?? [],
    }).toList();
  }

  void _shareLastSession(BuildContext ctx, WorkoutDay day) {
    final exercises = _buildLastSessionExercises(day.dayName);
    if (exercises.isEmpty) return;
    final allNames = myRoutine.map((r) => r.dayName).toList();
    final now = DateTime.now();
    const months = ['gen','feb','mar','apr','mag','giu','lug','ago','set','ott','nov','dic'];
    final todayLabel = '${now.day} ${months[now.month - 1]}';
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WorkoutShareSheet(
        dayName: day.dayName,
        todayLabel: todayLabel,
        exercises: exercises,
        streak: _streak,
        accent: appAccentNotifier.value,
        streakDoneNames: Set<String>.from(_streakDone),
        allSessionNames: allNames,
      ),
    );
  }

  void _shareStreakFromHome(BuildContext ctx, List<dynamic> routine) {
    final allNames = routine.map<String>((d) => d.dayName as String).toList();
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => _StreakShareSheet(
        streak: _streak,
        streakDoneNames: Set<String>.from(_streakDone),
        allSessionNames: allNames,
        accent: appAccentNotifier.value,
      ),
    );
  }

  void _showStreakInfo() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            const Text('🔥', style: TextStyle(fontSize: 36)),
            const SizedBox(height: 4),
            Text(
              '$_streak',
              style: const TextStyle(
                color: Colors.orange,
                fontSize: 48,
                fontWeight: FontWeight.w900,
                height: 1.0,
              ),
            ),
            Text(
              AppL.lang == 'en'
                  ? (_streak == 1 ? 'week streak' : 'weeks streak')
                  : (_streak == 1 ? 'microciclo' : 'microcicli'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppL.lang == 'en'
                  ? 'Complete ALL sessions in your plan every microcycle to increase your streak counter.\n\nMiss even one session in a microcycle and your streak resets to 0.\n\nStay consistent — every microcycle counts! 💪'
                  : 'Completa TUTTE le sessioni della tua scheda ogni microciclo per incrementare il contatore.\n\nSe salti anche solo una sessione in un microciclo, la streak si azzera.\n\nSii costante — ogni microciclo conta! 💪',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            // Mini progress strip
            if (myRoutine.isNotEmpty) ...[
              Text(
                '${_streakDone.where((n) => myRoutine.any((d) => d.dayName == n)).length}/${myRoutine.length} ${AppL.lang == 'en' ? 'sessions this microcycle' : 'sessioni questo microciclo'}',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
              const SizedBox(height: 6),
              LayoutBuilder(
                builder: (ctx, constraints) {
                  final n = myRoutine.length;
                  final iconSize = n > 0
                      ? (constraints.maxWidth / n - 8).clamp(20.0, 48.0)
                      : 48.0;
                  return Row(
                    children: List.generate(n, (i) {
                      final name = myRoutine[i].dayName;
                      final done = _streakDone.contains(name);
                      return Expanded(
                        child: Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: iconSize,
                            height: iconSize,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              gradient: done
                                  ? const LinearGradient(
                                      colors: [
                                        Color(0xFFFF6B00),
                                        Color(0xFFFFAB00),
                                      ],
                                    )
                                  : null,
                              color: done ? null : const Color(0xFF2C2C2E),
                              boxShadow: done
                                  ? [
                                      BoxShadow(
                                        color: Colors.orange.withAlpha(80),
                                        blurRadius: 6,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Opacity(
                                opacity: done ? 1.0 : 0.2,
                                child: Image.asset(
                                  'assets/icon_client.png',
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
            ],
          ],
        ),
        actions: [
          if (!kIsWeb)
            TextButton.icon(
              icon: const Text('🔥', style: TextStyle(fontSize: 14)),
              label: Text(
                AppL.lang == 'en' ? 'Share Streak' : 'Condividi',
                style: const TextStyle(color: Colors.orange),
              ),
              onPressed: () {
                Navigator.pop(c);
                _shareStreakFromHome(context, myRoutine);
              },
            ),
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('OK', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  Widget _buildTrainPage() {
    final Color accent = appAccentNotifier.value;
    if (myRoutine.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fitness_center, color: accent.withAlpha(80), size: 64),
            const SizedBox(height: 16),
            Text(
              AppL.noScheduleLoaded,
              style: const TextStyle(color: Colors.white38, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              AppL.createFirstSchedule,
              style: const TextStyle(color: Colors.white24, fontSize: 13),
            ),
          ],
        ),
      );
    }
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 28,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      AppL.train2,
                      style: TextStyle(
                        color: accent,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  AppL.chooseAndStart,
                  style: const TextStyle(color: Colors.white38, fontSize: 13),
                ),
                if (myRoutine.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _showStreakInfo,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _streak > 0
                              ? const Color(0xFFFF6B00).withAlpha(80)
                              : Colors.white12,
                        ),
                      ),
                      child: LayoutBuilder(
                        builder: (ctx, bannerConstraints) {
                          final n = myRoutine.length;
                          final sideIconsWidth =
                              bannerConstraints.maxWidth - 68 - 10 - 6 - 18;
                          final fullIconsWidth = bannerConstraints.maxWidth;
                          final fitsSide =
                              n == 0 ||
                              (n * 38.0 + (n - 1) * 6.0) <= sideIconsWidth;
                          final fitsFull =
                              n == 0 ||
                              (n * 38.0 + (n - 1) * 6.0) <= fullIconsWidth;

                          final Widget Function(double)
                          buildIconRow = (availWidth) {
                            final iconSize = n > 0
                                ? (availWidth / n - 8).clamp(20.0, 48.0)
                                : 48.0;
                            return Row(
                              children: List.generate(n, (i) {
                                final name = myRoutine[i].dayName;
                                final done = _streakDone.contains(name);
                                return Expanded(
                                  child: Center(
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      width: iconSize,
                                      height: iconSize,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        gradient: done
                                            ? const LinearGradient(
                                                colors: [
                                                  Color(0xFFFF6B00),
                                                  Color(0xFFFFAB00),
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              )
                                            : null,
                                        color: done
                                            ? null
                                            : const Color(0xFF2C2C2E),
                                        boxShadow: done
                                            ? [
                                                BoxShadow(
                                                  color: Colors.orange
                                                      .withAlpha(100),
                                                  blurRadius: 6,
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Opacity(
                                          opacity: done ? 1.0 : 0.2,
                                          child: Image.asset(
                                            'assets/icon_client.png',
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            );
                          };

                          final doneCount = _streakDone
                              .where(
                                (nm) => myRoutine.any((d) => d.dayName == nm),
                              )
                              .length;

                          if (fitsSide) {
                            return Row(
                              children: [
                                SizedBox(
                                  width: 68,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Text(
                                            '🔥',
                                            style: TextStyle(fontSize: 22),
                                          ),
                                          const SizedBox(width: 2),
                                          Text(
                                            '$_streak',
                                            style: const TextStyle(
                                              color: Colors.orange,
                                              fontSize: 30,
                                              fontWeight: FontWeight.w900,
                                              height: 1.0,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        AppL.lang == 'en'
                                            ? (_streak == 1 ? 'week' : 'weeks')
                                            : (_streak == 1
                                                  ? 'micro'
                                                  : 'micro'),
                                        style: const TextStyle(
                                          color: Colors.white38,
                                          fontSize: 10,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$doneCount/${myRoutine.length}',
                                        style: TextStyle(
                                          color: doneCount >= myRoutine.length
                                              ? Colors.orange
                                              : Colors.white38,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(child: buildIconRow(sideIconsWidth)),
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.info_outline,
                                  color: Colors.white24,
                                  size: 15,
                                ),
                              ],
                            );
                          } else {
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      '🔥',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$_streak ${AppL.lang == 'en' ? (_streak == 1 ? 'week' : 'weeks') : (_streak == 1 ? 'micro' : 'micro')}',
                                      style: const TextStyle(
                                        color: Colors.orange,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      '$doneCount/${myRoutine.length}',
                                      style: TextStyle(
                                        color: doneCount >= myRoutine.length
                                            ? Colors.orange
                                            : Colors.white38,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const Spacer(),
                                    const Icon(
                                      Icons.info_outline,
                                      color: Colors.white24,
                                      size: 15,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                buildIconRow(
                                  fitsFull ? fullIconsWidth : fullIconsWidth,
                                ),
                              ],
                            );
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((_, i) {
              final d = myRoutine[i];
              final label = _lastTrainedLabel(d);
              final isToday = label == AppL.today;
              return GestureDetector(
                onTap: () => _mostraAdEAvviaAllenamento(d),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111113),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isToday
                          ? accent.withAlpha(120)
                          : Colors.white.withAlpha(15),
                      width: isToday ? 1.5 : 1,
                    ),
                    boxShadow: isToday
                        ? [
                            BoxShadow(
                              color: accent.withAlpha(40),
                              blurRadius: 16,
                              spreadRadius: 0,
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top: nome + badge "ultimo allenamento"
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.white.withAlpha(10),
                            ),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${d.bodyParts.map((k) => kBodyPartIcons[k] ?? '').where((e) => e.isNotEmpty).take(2).join(' ')} ${d.dayName.toUpperCase()}'
                                        .trim(),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 2,
                                    style: TextStyle(
                                      color: isToday ? accent : Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.fitness_center,
                                        size: 12,
                                        color: Colors.white38,
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          '${d.exercises.length} ${AppL.exercises.toLowerCase()}',
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                          style: const TextStyle(
                                            color: Colors.white38,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Icon(
                                        Icons.repeat,
                                        size: 12,
                                        color: Colors.white38,
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          '${d.exercises.fold(0, (s, ex) => s + ex.targetSets)} ${AppL.sets.toLowerCase()}',
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                          style: const TextStyle(
                                            color: Colors.white38,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: isToday
                                    ? accent.withAlpha(30)
                                    : Colors.white.withAlpha(10),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isToday
                                      ? accent.withAlpha(120)
                                      : Colors.white12,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isToday
                                        ? Icons.check_circle
                                        : Icons.history,
                                    size: 12,
                                    color: isToday ? accent : Colors.white38,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    label,
                                    style: TextStyle(
                                      color: isToday ? accent : Colors.white38,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Exercise preview list
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                        child: Column(
                          children: [
                            _buildExPreviewList(d, accent),
                            if (d.exercises.length > 4)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    '+ ${d.exercises.length - 4} ${AppL.others}',
                                    style: TextStyle(
                                      color: accent.withAlpha(150),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      // CTA button
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _mostraAdEAvviaAllenamento(d),
                            icon: const Icon(
                              Icons.play_arrow_rounded,
                              size: 22,
                            ),
                            label: Text(
                              AppL.trainNow,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                letterSpacing: 1,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accent,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }, childCount: myRoutine.length),
          ),
        ),
      ],
    );
  }

  Future<void> _saveMyRoutine() async {
    final prefs = await SharedPreferences.getInstance();
    final fullRoutine = myRoutine.map((d) => d.toJson()).toList();
    await prefs.setString('client_routine', jsonEncode(fullRoutine));
  }

  void _renameSession(int idx) async {
    final ctrl = TextEditingController(text: myRoutine[idx].dayName);
    final accent = appAccentNotifier.value;
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: Text(
          AppL.lang == 'en' ? 'Rename Session' : 'Rinomina Sessione',
          style: const TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: accent.withAlpha(100)),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: accent),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppL.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: accent),
            child: Text(AppL.save, style: const TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      setState(() => myRoutine[idx].dayName = result);
      _saveMyRoutine();
    }
  }

  Future<void> _editExercise(int dayIdx, int exIdx) async {
    final accent = appAccentNotifier.value;
    final original = myRoutine[dayIdx].exercises[exIdx];
    final nameCtrl = TextEditingController(text: original.name);
    final setsCtrl = TextEditingController(text: '${original.targetSets}');
    final recoveryCtrl = TextEditingController(
      text: '${original.recoveryTime}',
    );
    final pausaCtrl = TextEditingController(
      text: '${original.interExercisePause}',
    );
    final noteCtrl = TextEditingController(text: original.notePT);
    int supersetGroup = original.supersetGroup;
    int currentSets = original.targetSets;
    List<TextEditingController> repsCtrls = List.generate(
      original.repsList.length,
      (i) => TextEditingController(text: '${original.repsList[i]}'),
    );
    ExerciseInfo? selectedExInfo;
    if (original.gifFilename != null) {
      selectedExInfo = findByGifSlug(original.gifFilename!);
    }
    List<ExerciseInfo> suggestions = [];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (c) => StatefulBuilder(
        builder: (ctx, setS) {
          void updateSets(String val) {
            final n = (int.tryParse(val) ?? 1).clamp(1, 20);
            setS(() {
              currentSets = n;
              while (repsCtrls.length < n)
                repsCtrls.add(
                  TextEditingController(
                    text: repsCtrls.isNotEmpty ? repsCtrls.last.text : '10',
                  ),
                );
              while (repsCtrls.length > n) {
                repsCtrls.last.dispose();
                repsCtrls.removeLast();
              }
            });
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: DraggableScrollableSheet(
              initialChildSize: 0.9,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (_, scrollCtrl) => ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    AppL.lang == 'en' ? 'Edit Exercise' : 'Modifica Esercizio',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: AppL.exerciseName,
                      labelStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (v) => setS(
                      () =>
                          suggestions = searchExercisesWithItalian(v, limit: 6),
                    ),
                  ),
                  if (suggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2C2E),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      constraints: const BoxConstraints(maxHeight: 240),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const ClampingScrollPhysics(),
                        itemCount: suggestions.length,
                        separatorBuilder: (_, __) =>
                            const Divider(color: Colors.white10, height: 1),
                        itemBuilder: (_, i) {
                          final ex = suggestions[i];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            leading: ex.gifFilename != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.asset(
                                      exerciseAnimationAssetPath(
                                        ex.gifFilename!,
                                      ),
                                      width: 48,
                                      height: 48,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.fitness_center,
                                        color: Colors.white30,
                                      ),
                                    ),
                                  )
                                : const Icon(
                                    Icons.fitness_center,
                                    color: Colors.white30,
                                  ),
                            title: Text(
                              ex.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                            onTap: () {
                              nameCtrl.text = ex.name;
                              setS(() {
                                suggestions = [];
                                selectedExInfo = ex;
                              });
                            },
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 8),
                  if (selectedExInfo != null &&
                      selectedExInfo!.gifFilename != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        exerciseAnimationAssetPath(
                          selectedExInfo!.gifFilename!,
                        ),
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: setsCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: AppL.sets,
                            labelStyle: const TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: Colors.black26,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: updateSets,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: recoveryCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: AppL.recovery,
                            labelStyle: const TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: Colors.black26,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: pausaCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: AppL.pauseSec,
                            labelStyle: const TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: Colors.black26,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AppL.repsPerSet,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(
                      currentSets,
                      (i) => SizedBox(
                        width: 58,
                        child: TextField(
                          controller: repsCtrls[i],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                          decoration: InputDecoration(
                            labelText: 'S${i + 1}',
                            labelStyle: const TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                            filled: true,
                            fillColor: Colors.black26,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: noteCtrl,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: AppL.notes,
                      labelStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '🔗  ${AppL.circuit}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppL.circuitHint,
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(
                      6,
                      (i) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setS(() => supersetGroup = i),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: supersetGroup == i
                                  ? accent
                                  : Colors.white10,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                '$i',
                                style: TextStyle(
                                  color: supersetGroup == i
                                      ? Colors.black
                                      : Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) return;
                        final sets = (int.tryParse(setsCtrl.text) ?? 3).clamp(
                          1,
                          20,
                        );
                        final repsList = repsCtrls
                            .map((c) => int.tryParse(c.text) ?? 10)
                            .toList();
                        final recovery = int.tryParse(recoveryCtrl.text) ?? 90;
                        final pausa = int.tryParse(pausaCtrl.text) ?? 120;
                        Navigator.pop(c);
                        setState(() {
                          final updated = ExerciseConfig(
                            name: name,
                            targetSets: sets,
                            repsList: repsList,
                            recoveryTime: recovery,
                            interExercisePause: pausa,
                            notePT: noteCtrl.text.trim(),
                            noteCliente: original.noteCliente,
                            supersetGroup: supersetGroup,
                            gifFilename:
                                selectedExInfo?.gifFilename ??
                                original.gifFilename,
                            useQuarterStep: original.useQuarterStep,
                          );
                          updated.results = original.results;
                          myRoutine[dayIdx].exercises[exIdx] = updated;
                        });
                        _saveMyRoutine();
                      },
                      child: Text(
                        AppL.save,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// --- COSTRUTTORE SCHEDA AUTONOMO ---
class ScheduleBuilderScreen extends StatefulWidget {
  const ScheduleBuilderScreen({super.key});
  @override
  State<ScheduleBuilderScreen> createState() => _ScheduleBuilderScreenState();
}

class _ScheduleBuilderScreenState extends State<ScheduleBuilderScreen>
    with SingleTickerProviderStateMixin {
  List<WorkoutDay> _days = [];
  bool _loading = true;
  bool _isReordering = false;
  late final AnimationController _wiggleCtrl;

  @override
  void initState() {
    super.initState();
    _wiggleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _loadExisting();
  }

  @override
  void dispose() {
    _wiggleCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('client_routine') ?? '[]';
    try {
      final list = jsonDecode(raw) as List;
      _days = list
          .map((e) => WorkoutDay.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      _days = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'client_routine',
      jsonEncode(_days.map((d) => d.toJson()).toList()),
    );
    // Reset microcycle in progress when the routine changes (keep streak count)
    await prefs.setString('microcycle_done', '[]');
  }

  void _aggiungiGiorno() {
    final nameCtrl = TextEditingController();
    final List<String> selectedParts = [];
    String? selectedMuscleImage;

    Future<void> pickMuscleImage(StateSetter setS) async {
      await showDialog<void>(
        context: context,
        builder: (c) => StatefulBuilder(
          builder: (c, setSInner) => AlertDialog(
            backgroundColor: const Color(0xFF1C1C1E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              AppL.chooseMuscleImage,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: GridView.builder(
                shrinkWrap: true,
                itemCount: kMuscleImages.length + 1,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.75,
                ),
                itemBuilder: (_, i) {
                  if (i == 0) {
                    final bool sel = selectedMuscleImage == null;
                    return GestureDetector(
                      onTap: () {
                        setSInner(() {});
                        setS(() => selectedMuscleImage = null);
                        Navigator.pop(c);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: sel
                              ? appAccentNotifier.value.withAlpha(40)
                              : Colors.white10,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: sel
                                ? appAccentNotifier.value
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.hide_image_outlined,
                              color: sel
                                  ? appAccentNotifier.value
                                  : Colors.white38,
                              size: 28,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              AppL.noImage,
                              style: TextStyle(
                                color: sel
                                    ? appAccentNotifier.value
                                    : Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  final img = kMuscleImages[i - 1];
                  final bool sel = selectedMuscleImage == img['file'];
                  return GestureDetector(
                    onTap: () {
                      setSInner(() {});
                      setS(() => selectedMuscleImage = img['file']);
                      Navigator.pop(c);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: sel
                              ? appAccentNotifier.value
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.asset(
                              muscleAssetPath(img['file']!),
                              fit: BoxFit.cover,
                            ),
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                color: Colors.black54,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Text(
                                  muscleImageLabel(img),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: sel
                                        ? appAccentNotifier.value
                                        : Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: Text(AppL.cancel),
              ),
            ],
          ),
        ),
      );
    }

    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(AppL.day, style: const TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: AppL.day,
                    labelStyle: const TextStyle(color: Colors.white54),
                    enabledBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: appAccentNotifier.value),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: kBodyPartNames.entries
                      .where((e) => e.key != 'nessuno')
                      .map((e) {
                        final sel = selectedParts.contains(e.key);
                        return FilterChip(
                          label: Text(
                            '${kBodyPartIcons[e.key] ?? ''} ${bodyPartName(e.key)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: sel ? Colors.black : Colors.white70,
                            ),
                          ),
                          selected: sel,
                          onSelected: (v) => setS(() {
                            if (v)
                              selectedParts.add(e.key);
                            else
                              selectedParts.remove(e.key);
                          }),
                          backgroundColor: Colors.white10,
                          selectedColor: appAccentNotifier.value,
                          checkmarkColor: Colors.black,
                        );
                      })
                      .toList(),
                ),
                const SizedBox(height: 12),
                // Selezione immagine muscolo
                GestureDetector(
                  onTap: () => pickMuscleImage(setS),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: appAccentNotifier.value.withAlpha(80),
                      ),
                    ),
                    child: Row(
                      children: [
                        if (selectedMuscleImage != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset(
                              muscleAssetPath(selectedMuscleImage),
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                            ),
                          )
                        else
                          const Icon(
                            Icons.image_outlined,
                            color: Colors.white38,
                            size: 48,
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            selectedMuscleImage != null
                                ? (muscleImageLabel(
                                    kMuscleImages.firstWhere(
                                      (m) => m['file'] == selectedMuscleImage,
                                      orElse: () => {
                                        'label': selectedMuscleImage!,
                                      },
                                    ),
                                  ))
                                : AppL.tapToChooseMuscle,
                            style: TextStyle(
                              color: selectedMuscleImage != null
                                  ? Colors.white
                                  : Colors.white38,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: appAccentNotifier.value,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: Text(
                AppL.cancel,
                style: const TextStyle(color: Colors.white54),
              ),
            ),
            TextButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(c);
                setState(() {
                  _days.add(
                    WorkoutDay(
                      dayName: _limitToOneEmoji(name),
                      bodyParts: List.from(selectedParts),
                      muscleImage: selectedMuscleImage,
                      exercises: [],
                    ),
                  );
                });
                _save();
              },
              child: Text(
                AppL.add,
                style: TextStyle(
                  color: appAccentNotifier.value,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _eliminaGiorno(int idx) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: Text(
          AppL.deleteDay,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppL.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              AppL.delete,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _days.removeAt(idx));
    _save();
  }

  void _setReordering(bool value) {
    if (_isReordering == value) return;
    setState(() => _isReordering = value);
    if (value) {
      _wiggleCtrl.repeat(reverse: true);
    } else {
      _wiggleCtrl.stop();
      _wiggleCtrl.value = 0.5;
    }
  }

  Widget _reorderCue({required int index, required Widget child}) {
    return AnimatedBuilder(
      animation: _wiggleCtrl,
      child: child,
      builder: (_, wiggleChild) {
        final direction = index.isEven ? -1.0 : 1.0;
        final angle = _isReordering
            ? direction * (0.008 + (_wiggleCtrl.value * 0.01))
            : 0.0;
        return Transform.rotate(angle: angle, child: wiggleChild);
      },
    );
  }

  void _mostraTemplateDialog() {
    final accent = appAccentNotifier.value;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (c) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  AppL.lang == 'en'
                      ? 'Choose a template'
                      : 'Scegli un template',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: accent,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white38),
                  onPressed: () => Navigator.pop(c),
                ),
              ],
            ),
            Text(
              AppL.lang == 'en'
                  ? 'Load a pre-built plan as a starting point. You can edit it afterwards.'
                  : 'Carica una scheda pre-impostata come punto di partenza. Puoi modificarla dopo il caricamento.',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ...kAllWorkoutTemplates.map(
              (t) => ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accent.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: accent.withAlpha(60)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    t['icon'] as String,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
                title: Text(
                  localizeMixedLabel(t['name'] as String),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  t['desc'] as String,
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Colors.white24,
                ),
                onTap: () {
                  Navigator.pop(c);
                  _confermaCaricaTemplate(t);
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _confermaCaricaTemplate(Map<String, dynamic> template) {
    final accent = appAccentNotifier.value;
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '"${localizeMixedLabel(template['name'] as String)}"?',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: Text(
          AppL.lang == 'en'
              ? 'This will add ${_templateDays(template).length} sessions to your schedule. Existing sessions will be kept.'
              : 'Verranno aggiunte ${_templateDays(template).length} sessioni alla scheda. Le sessioni esistenti verranno mantenute.',
          style: const TextStyle(color: Colors.white54, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(
              AppL.cancel,
              style: const TextStyle(color: Colors.white38),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(c);
              setState(() {
                for (final dayData in _templateDays(template)) {
                  final rawDay = Map<String, dynamic>.from(dayData as Map);
                  rawDay['dayName'] = localizeMixedLabel(
                    rawDay['dayName'] as String? ?? 'Giorno',
                  );
                  final exercises =
                      (rawDay['exercises'] as List? ?? <dynamic>[]).map((e) {
                        final rawEx = Map<String, dynamic>.from(e as Map);
                        final rawName = rawEx['name'] as String? ?? 'Exercise';
                        final resolved = resolveExerciseInfo(rawName);
                        rawEx['name'] = resolved?.nameEn ?? rawName.trim();
                        rawEx['gifFilename'] ??=
                            resolved?.gifFilename ?? resolved?.gifSlug;
                        return rawEx;
                      }).toList();
                  rawDay['exercises'] = exercises;
                  final day = WorkoutDay.fromJson(rawDay);
                  _days.add(day);
                }
              });
              await _save();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      AppL.lang == 'en'
                          ? 'Template "${localizeMixedLabel(template['name'] as String)}" loaded! Edit exercises as needed.'
                          : 'Template "${localizeMixedLabel(template['name'] as String)}" caricato! Modifica gli esercizi secondo le esigenze.',
                    ),
                    backgroundColor: Colors.amber.shade800,
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(AppL.lang == 'en' ? 'LOAD' : 'CARICA'),
          ),
        ],
      ),
    );
  }

  void _aggiungiEsercizio(int dayIdx) {
    final accent = appAccentNotifier.value;
    final nameCtrl = TextEditingController();
    final setsCtrl = TextEditingController(text: '3');
    final recoveryCtrl = TextEditingController(text: '90');
    final pausaCtrl = TextEditingController(text: '120');
    final noteCtrl = TextEditingController();
    int supersetGroup = 0;

    int currentSets = 3;
    List<TextEditingController> repsCtrls = List.generate(
      3,
      (_) => TextEditingController(text: '10'),
    );
    ExerciseInfo? selectedExInfo;
    List<ExerciseInfo> suggestions = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (c) => StatefulBuilder(
        builder: (ctx, setS) {
          void updateSets(String val) {
            final n = (int.tryParse(val) ?? 1).clamp(1, 20);
            setS(() {
              currentSets = n;
              while (repsCtrls.length < n) {
                repsCtrls.add(
                  TextEditingController(
                    text: repsCtrls.isNotEmpty ? repsCtrls.last.text : '10',
                  ),
                );
              }
              while (repsCtrls.length > n) {
                repsCtrls.last.dispose();
                repsCtrls.removeLast();
              }
            });
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: DraggableScrollableSheet(
              initialChildSize: 0.9,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (_, scrollCtrl) => ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    AppL.exercises,
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // — Nome esercizio
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: AppL.exerciseName,
                      labelStyle: const TextStyle(color: Colors.white54),
                      suffixIcon: nameCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.clear,
                                color: Colors.white38,
                              ),
                              onPressed: () {
                                nameCtrl.clear();
                                setS(() {
                                  suggestions = [];
                                  selectedExInfo = null;
                                });
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (v) => setS(
                      () =>
                          suggestions = searchExercisesWithItalian(v, limit: 6),
                    ),
                  ),

                  // — Suggerimenti con GIF
                  if (suggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2C2E),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const ClampingScrollPhysics(),
                        itemCount: suggestions.length,
                        separatorBuilder: (_, __) =>
                            const Divider(color: Colors.white10, height: 1),
                        itemBuilder: (_, i) {
                          final ex = suggestions[i];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            leading: ex.gifFilename != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.asset(
                                      exerciseAnimationAssetPath(
                                        ex.gifFilename!,
                                      ),
                                      width: 64,
                                      height: 64,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const SizedBox(
                                            width: 64,
                                            height: 64,
                                            child: Icon(
                                              Icons.fitness_center,
                                              color: Colors.white30,
                                            ),
                                          ),
                                    ),
                                  )
                                : const SizedBox(
                                    width: 64,
                                    height: 64,
                                    child: Icon(
                                      Icons.fitness_center,
                                      color: Colors.white30,
                                    ),
                                  ),
                            title: Text(
                              ex.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle:
                                ex.primaryMuscle.isNotEmpty &&
                                    ex.primaryMuscle !=
                                        'Muscolatura principale coinvolta'
                                ? Text(
                                    translateMuscle(ex.primaryMuscle),
                                    style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 11,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : null,
                            onTap: () {
                              nameCtrl.text = ex.name;
                              setS(() {
                                suggestions = [];
                                selectedExInfo = ex;
                              });
                            },
                          );
                        },
                      ),
                    ),

                  const SizedBox(height: 8),

                  // — Sfoglia archivio per gruppo muscolare
                  OutlinedButton.icon(
                    onPressed: () => _apriArchivioEsercizi(ctx, setS, (ex) {
                      nameCtrl.text = ex.name;
                      setS(() {
                        selectedExInfo = ex;
                        suggestions = [];
                      });
                    }),
                    icon: const Icon(Icons.library_books_rounded, size: 18),
                    label: Text(AppL.browseArchive),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accent,
                      side: BorderSide(color: accent.withAlpha(80)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // — Preview GIF selezionata
                  if (selectedExInfo != null &&
                      selectedExInfo!.gifFilename != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        exerciseAnimationAssetPath(
                          selectedExInfo!.gifFilename!,
                        ),
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                    if (selectedExInfo!.primaryMuscle.isNotEmpty &&
                        selectedExInfo!.primaryMuscle !=
                            'Muscolatura principale coinvolta')
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '💪 ${translateMuscle(selectedExInfo!.primaryMuscle)}',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                  ],

                  // — Serie
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: setsCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: AppL.sets,
                            labelStyle: const TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: Colors.black26,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: updateSets,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: recoveryCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: AppL.recovery,
                            labelStyle: const TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: Colors.black26,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: pausaCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: AppL.pauseSec,
                            labelStyle: const TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: Colors.black26,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // — Reps per serie
                  Text(
                    AppL.repsPerSet,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(
                      currentSets,
                      (i) => SizedBox(
                        width: 58,
                        child: TextField(
                          controller: repsCtrls[i],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                          decoration: InputDecoration(
                            labelText: 'S${i + 1}',
                            labelStyle: const TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                            filled: true,
                            fillColor: Colors.black26,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // — Note
                  TextField(
                    controller: noteCtrl,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: AppL.notes,
                      labelStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // — Superserie / Circuito
                  Text(
                    '🔗  ${AppL.circuit}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppL.circuitHint,
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(
                      6,
                      (i) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setS(() => supersetGroup = i),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: supersetGroup == i
                                  ? accent
                                  : Colors.white10,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                '$i',
                                style: TextStyle(
                                  color: supersetGroup == i
                                      ? Colors.black
                                      : Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) return;
                        final sets = (int.tryParse(setsCtrl.text) ?? 3).clamp(
                          1,
                          20,
                        );
                        final repsList = repsCtrls
                            .map((c) => int.tryParse(c.text) ?? 10)
                            .toList();
                        final recovery = int.tryParse(recoveryCtrl.text) ?? 90;
                        final pausa = int.tryParse(pausaCtrl.text) ?? 120;
                        final ex = ExerciseConfig(
                          name: name,
                          targetSets: sets,
                          repsList: repsList,
                          recoveryTime: recovery,
                          interExercisePause: pausa,
                          notePT: noteCtrl.text.trim(),
                          noteCliente: '',
                          supersetGroup: supersetGroup,
                          gifFilename: selectedExInfo?.gifFilename,
                        );
                        Navigator.pop(c);
                        setState(() => _days[dayIdx].exercises.add(ex));
                        _save();
                      },
                      child: Text(
                        AppL.save,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _apriArchivioEsercizi(
    BuildContext context,
    StateSetter setS,
    Function(ExerciseInfo) onSelect,
  ) {
    String? selectedCategory;
    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (c) => StatefulBuilder(
        builder: (ctx, setA) {
          final cats =
              kGifCatalog
                  .map((e) => e.category)
                  .toSet()
                  .where((c) => c.isNotEmpty && c != 'altro')
                  .toList()
                ..sort();

          List<ExerciseInfo> filtered = selectedCategory != null
              ? kGifCatalog
                    .where(
                      (e) => exerciseAllCategories(e).contains(selectedCategory),
                    )
                    .toList()
              : kGifCatalog.where((e) => e.category != 'altro').toList();

          if (searchQuery.isNotEmpty) {
            final q = searchQuery.toLowerCase();
            filtered = filtered
                .where(
                  (e) =>
                      e.name.toLowerCase().contains(q) ||
                      e.nameEn.toLowerCase().contains(q) ||
                      e.aliases.any((a) => a.toLowerCase().contains(q)),
                )
                .toList();
          }

          return Container(
            height: MediaQuery.of(ctx).size.height * 0.85,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                TextField(
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: AppL.lang == 'en'
                        ? 'Search exercise...'
                        : 'Cerca esercizio...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(Icons.search, color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  onChanged: (v) => setA(() => searchQuery = v),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _archiveChip(
                        label: AppL.lang == 'en' ? 'All' : 'Tutti',
                        selected: selectedCategory == null,
                        onTap: () => setA(() => selectedCategory = null),
                        accent: appAccentNotifier.value,
                      ),
                      ...cats.map(
                        (cat) => _archiveChip(
                          label:
                              '${kBodyPartIcons[cat] ?? ''} ${bodyPartName(cat)}',
                          selected: selectedCategory == cat,
                          onTap: () => setA(() => selectedCategory = cat),
                          accent: appAccentNotifier.value,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.85,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final ex = filtered[i];
                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(c);
                          setS(() => onSelect(ex));
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(12),
                                  ),
                                  child: ex.gifFilename != null
                                      ? Image.asset(
                                          exerciseAnimationAssetPath(
                                            ex.gifFilename!,
                                          ),
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          errorBuilder: (_, __, ___) =>
                                              const Center(
                                                child: Icon(
                                                  Icons.fitness_center,
                                                  color: Colors.white30,
                                                  size: 32,
                                                ),
                                              ),
                                        )
                                      : const Center(
                                          child: Icon(
                                            Icons.fitness_center,
                                            color: Colors.white30,
                                            size: 32,
                                          ),
                                        ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(6),
                                child: Text(
                                  ex.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _archiveChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required Color accent,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? accent.withAlpha(40) : Colors.white10,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? accent : Colors.white24,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? accent : Colors.white60,
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  void _eliminaEsercizio(int dayIdx, int exIdx) {
    setState(() => _days[dayIdx].exercises.removeAt(exIdx));
    _save();
  }

  void _riordinaGiorni(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    setState(() {
      final day = _days.removeAt(oldIndex);
      _days.insert(newIndex, day);
    });
    _save();
  }

  void _riordinaEsercizi(int dayIdx, int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    setState(() {
      final ex = _days[dayIdx].exercises.removeAt(oldIndex);
      _days[dayIdx].exercises.insert(newIndex, ex);
    });
    _save();
  }

  void _rinominaGiorno(int dayIdx) {
    final ctrl = TextEditingController(text: _days[dayIdx].dayName);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: Text(
          AppL.renameSession,
          style: const TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: AppL.sessionName,
            labelStyle: const TextStyle(color: Colors.white54),
            filled: true,
            fillColor: Colors.black26,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppL.cancel),
          ),
          TextButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              setState(() => _days[dayIdx].dayName = _limitToOneEmoji(name));
              _save();
              Navigator.pop(context);
            },
            child: Text(
              AppL.save,
              style: TextStyle(
                color: appAccentNotifier.value,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _modificaEsercizio(int dayIdx, int exIdx) {
    final orig = _days[dayIdx].exercises[exIdx];
    final accent = appAccentNotifier.value;
    final nameCtrl = TextEditingController(text: orig.name);
    final setsCtrl = TextEditingController(text: '${orig.targetSets}');
    final recoveryCtrl = TextEditingController(text: '${orig.recoveryTime}');
    final pausaCtrl = TextEditingController(text: '${orig.interExercisePause}');
    final noteCtrl = TextEditingController(text: orig.notePT);
    int supersetGroup = orig.supersetGroup;
    int currentSets = orig.targetSets;
    List<TextEditingController> repsCtrls = List.generate(
      orig.repsList.length,
      (i) => TextEditingController(text: '${orig.repsList[i]}'),
    );
    if (repsCtrls.isEmpty) repsCtrls = [TextEditingController(text: '10')];
    ExerciseInfo? selectedExInfo;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (c) => StatefulBuilder(
        builder: (ctx, setS) {
          void updateSets(String val) {
            final n = (int.tryParse(val) ?? 1).clamp(1, 20);
            setS(() {
              currentSets = n;
              while (repsCtrls.length < n) {
                repsCtrls.add(
                  TextEditingController(
                    text: repsCtrls.isNotEmpty ? repsCtrls.last.text : '10',
                  ),
                );
              }
              while (repsCtrls.length > n) {
                repsCtrls.last.dispose();
                repsCtrls.removeLast();
              }
            });
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: DraggableScrollableSheet(
              initialChildSize: 0.9,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (_, scrollCtrl) => ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    AppL.editExercise,
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: AppL.exerciseName,
                      labelStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _apriArchivioEsercizi(ctx, setS, (ex) {
                      nameCtrl.text = ex.name;
                      setS(() => selectedExInfo = ex);
                    }),
                    icon: const Icon(Icons.library_books_rounded, size: 18),
                    label: Text(AppL.browseArchive),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accent,
                      side: BorderSide(color: accent.withAlpha(80)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: setsCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: AppL.sets,
                            labelStyle: const TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: Colors.black26,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: updateSets,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: recoveryCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: AppL.recovery,
                            labelStyle: const TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: Colors.black26,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: pausaCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: AppL.pauseSec,
                            labelStyle: const TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: Colors.black26,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AppL.repsPerSet,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(
                      currentSets,
                      (i) => SizedBox(
                        width: 58,
                        child: TextField(
                          controller: repsCtrls[i],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                          decoration: InputDecoration(
                            labelText: 'S${i + 1}',
                            labelStyle: const TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                            filled: true,
                            fillColor: Colors.black26,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: noteCtrl,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: AppL.notes,
                      labelStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) return;
                        final sets = (int.tryParse(setsCtrl.text) ?? 3).clamp(
                          1,
                          20,
                        );
                        final repsList = repsCtrls
                            .map((c) => int.tryParse(c.text) ?? 10)
                            .toList();
                        final recovery = int.tryParse(recoveryCtrl.text) ?? 90;
                        final pausa = int.tryParse(pausaCtrl.text) ?? 120;
                        final newEx = ExerciseConfig(
                          name: name,
                          targetSets: sets,
                          repsList: repsList,
                          recoveryTime: recovery,
                          interExercisePause: pausa,
                          notePT: noteCtrl.text.trim(),
                          noteCliente: orig.noteCliente,
                          supersetGroup: supersetGroup,
                          gifFilename:
                              selectedExInfo?.gifFilename ?? orig.gifFilename,
                          useQuarterStep: orig.useQuarterStep,
                        );
                        Navigator.pop(c);
                        setState(() => _days[dayIdx].exercises[exIdx] = newEx);
                        _save();
                      },
                      child: Text(
                        AppL.save,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = appAccentNotifier.value;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: Text(AppL.mySchedule),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await _save();
              if (mounted) Navigator.pop(context);
            },
            child: Text(
              AppL.save,
              style: TextStyle(color: accent, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'templates_fab',
            onPressed: _mostraTemplateDialog,
            backgroundColor: const Color(0xFF2C2C2E),
            foregroundColor: Colors.amber,
            icon: const Icon(Icons.auto_awesome_rounded),
            label: Text(AppL.lang == 'en' ? 'Templates' : 'Template'),
          ),
          const SizedBox(width: 12),
          FloatingActionButton.extended(
            heroTag: 'add_day_fab',
            onPressed: _aggiungiGiorno,
            backgroundColor: accent,
            foregroundColor: Colors.black,
            icon: const Icon(Icons.add),
            label: Text(AppL.day),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _days.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.fitness_center_rounded,
                    color: accent.withAlpha(60),
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppL.noScheduleYet,
                    style: const TextStyle(color: Colors.white38, fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  // Speech bubble hint
                  GestureDetector(
                    onTap: _mostraTemplateDialog,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withAlpha(20),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: accent.withAlpha(80)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('💬', style: const TextStyle(fontSize: 22)),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              AppL.lang == 'en'
                                  ? "Don't know where to start?\nTap to browse pre-built plans!"
                                  : "Non sai da dove iniziare?\nSfoglia le schede precompilate!",
                              style: TextStyle(
                                color: accent,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.auto_awesome_rounded,
                            color: accent,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            )
          : ReorderableListView.builder(
              buildDefaultDragHandles: false,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: _days.length,
              onReorderStart: (_) => _setReordering(true),
              onReorderEnd: (_) => _setReordering(false),
              onReorder: _riordinaGiorni,
              itemBuilder: (_, dayIdx) {
                final day = _days[dayIdx];
                final dayCard = Card(
                  key: ObjectKey(day),
                  color: const Color(0xFF1C1C1E),
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    leading:
                        day.muscleImage != null && day.muscleImage!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset(
                              muscleAssetPath(day.muscleImage),
                              width: 42,
                              height: 42,
                              fit: BoxFit.cover,
                            ),
                          )
                        : day.bodyParts.isNotEmpty
                        ? Text(
                            day.bodyParts
                                .map((k) => kBodyPartIcons[k] ?? '')
                                .where((e) => e.isNotEmpty)
                                .take(2)
                                .join(' '),
                            style: const TextStyle(fontSize: 22),
                          )
                        : const Icon(
                            Icons.fitness_center,
                            color: Colors.white38,
                          ),
                    title: Text(
                      localizeMixedLabel(day.dayName),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      '${day.exercises.length} ${AppL.exercises.toLowerCase()}',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.edit_rounded,
                            color: Colors.white38,
                            size: 20,
                          ),
                          onPressed: () => _rinominaGiorno(dayIdx),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                            size: 20,
                          ),
                          onPressed: () => _eliminaGiorno(dayIdx),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Icon(
                            Icons.drag_indicator_rounded,
                            color: _isReordering ? accent : Colors.white38,
                            size: 20,
                          ),
                        ),
                        const Icon(Icons.expand_more, color: Colors.white38),
                      ],
                    ),
                    children: [
                      ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        buildDefaultDragHandles: false,
                        itemCount: day.exercises.length,
                        onReorderStart: (_) => _setReordering(true),
                        onReorderEnd: (_) => _setReordering(false),
                        onReorder: (oldIndex, newIndex) =>
                            _riordinaEsercizi(dayIdx, oldIndex, newIndex),
                        itemBuilder: (_, exIdx) {
                          final ex = day.exercises[exIdx];
                          final exerciseTile = ListTile(
                            key: ObjectKey(ex),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                            ),
                            leading: ex.gifFilename != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.asset(
                                      exerciseAnimationAssetPath(
                                        ex.gifFilename!,
                                      ),
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                      gaplessPlayback: true,
                                      filterQuality: FilterQuality.high,
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.fitness_center,
                                        color: Colors.white30,
                                        size: 28,
                                      ),
                                    ),
                                  )
                                : const Icon(
                                    Icons.fitness_center_rounded,
                                    color: Colors.white30,
                                  ),
                            title: Text(
                              localizedExerciseName(ex.name),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Builder(
                              builder: (context) {
                                final exInfo = findAnyExercise(ex.name);
                                return Row(
                                  children: [
                                    Text(
                                      '${ex.targetSets}x${ex.repsList.isNotEmpty ? ex.repsList.first : "?"} | ${ex.recoveryTime}s',
                                      style: const TextStyle(
                                        color: Colors.white38,
                                        fontSize: 12,
                                      ),
                                    ),
                                    if (exInfo != null &&
                                        exInfo.muscleImages.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Image.asset(
                                        muscleAssetPath(
                                          exInfo.muscleImages.first,
                                        ),
                                        height: 20,
                                        width: 20,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) =>
                                            const SizedBox.shrink(),
                                      ),
                                    ],
                                  ],
                                );
                              },
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit_rounded,
                                    color: Colors.white38,
                                    size: 18,
                                  ),
                                  onPressed: () =>
                                      _modificaEsercizio(dayIdx, exIdx),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.remove_circle_outline,
                                    color: Colors.redAccent,
                                    size: 20,
                                  ),
                                  onPressed: () =>
                                      _eliminaEsercizio(dayIdx, exIdx),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                  ),
                                  child: Icon(
                                    Icons.drag_indicator_rounded,
                                    color: _isReordering
                                        ? accent
                                        : Colors.white38,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                          );
                          return ReorderableDelayedDragStartListener(
                            key: ObjectKey(ex),
                            index: exIdx,
                            child: _reorderCue(
                              index: exIdx,
                              child: exerciseTile,
                            ),
                          );
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _aggiungiEsercizio(dayIdx),
                            icon: Icon(Icons.add, color: accent, size: 18),
                            label: Text(
                              '${AppL.add} ${AppL.exercises.toLowerCase()}',
                              style: TextStyle(color: accent),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: accent.withAlpha(80)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
                return ReorderableDelayedDragStartListener(
                  key: ObjectKey(day),
                  index: dayIdx,
                  child: _reorderCue(index: dayIdx, child: dayCard),
                );
              },
            ),
    );
  }
}

// --- MOTORE ALLENAMENTO ---
class WorkoutEngine extends StatefulWidget {
  final WorkoutDay day;
  final List<dynamic> history;
  final Map<String, Map<String, dynamic>> carryoverWeights;
  final Function(Map<String, dynamic>) onDone;
  final List<String> allSessionNames; // per calcolo streak
  const WorkoutEngine({
    super.key,
    required this.day,
    required this.history,
    required this.onDone,
    this.carryoverWeights = const {},
    this.allSessionNames = const [],
  });
  @override
  State<WorkoutEngine> createState() => _WorkoutEngineState();
}

class _WorkoutEngineState extends State<WorkoutEngine>
    with WidgetsBindingObserver {
  int exI = 0;
  int setN = 1;
  String _infoProssimo = ""; // Serve per far vedere cosa fare dopo nel timer
  String _prossimoNome =
      ""; // Nome esercizio prossimo (per aprire dettaglio dal timer)
  List<Map<String, dynamic>> currentExSeries = [];
  final TextEditingController wC = TextEditingController();
  final TextEditingController rC = TextEditingController();
  int _bgCounter = 0;
  int _maxTime = 1;
  DateTime? _endTime;
  Timer? _bgTimer;
  bool isRestingFullScreen = false;
  bool timerActive = false;
  List<String> eserciziCompletati = [];
  final Map<String, TextEditingController> _noteControllers = {};
  List<Map<String, dynamic>> _allCompletedExercises = [];
  bool _isNewRecord = false;
  int _currentStreak = 0; // streak aggiornata dopo fine allenamento
  int _streakDoneCount = 0;
  int _streakTotalCount = 0;
  Set<String> _streakDoneNames = {};
  final Map<int, List<Map<String, dynamic>>> _supersetAccumulated = {};
  // Risultati sessione precedente: nome esercizio → lista serie {w, r}
  final Map<String, List<Map<String, dynamic>>> _previousResults = {};
  // Chiave persistenza allenamento in corso
  String get _inProgressKey => 'workout_in_progress_${widget.day.dayName}';
  // Suono fine timer
  bool _timerSoundEnabled = true;
  bool _vibrationEnabled = true;
  bool _wakelockEnabled = true;
  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;
  // Contatore generazione notifica (annulla notifiche di timer precedenti)
  int _notifGen = 0;
  int _timerRunId = 0;
  int _newTimerRunId() => DateTime.now().microsecondsSinceEpoch;
  // ID univoco sessione (per separare sessioni stessa giornata nei grafici)
  late final String _sessionId;
  bool _autoStartTimer = true;
  bool _confirmSeriesEnabled = true;
  bool _showWeightSuggestion = true;
  bool _displayInPounds = false;
  bool _disableWeightKeyboard = false;
  bool _awaitingFirstExerciseStart = true;
  NativeAd? _inlineWorkoutNativeAd;
  NativeAd? _startWorkoutNativeAd;
  NativeAd? _confirmPopupNativeAd;
  NativeAd? _timerRestNativeAd;
  NativeAd? _recapWorkoutNativeAd;
  bool _isInlineWorkoutNativeAdLoaded = false;
  bool _isStartWorkoutNativeAdLoaded = false;
  bool _isConfirmPopupNativeAdLoaded = false;
  bool _isTimerRestNativeAdLoaded = false;
  bool _isRecapWorkoutNativeAdLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // per didChangeAppLifecycleState
    _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    exI = 0;
    currentExSeries = [];
    setN = 1;
    // Popola _previousResults dall'ultima sessione dello storico
    for (var ex in widget.day.exercises) {
      Map<String, dynamic>? lastEntry;
      for (final h in widget.history) {
        if ((h as Map<String, dynamic>)['exercise'] == ex.name) {
          if (lastEntry == null) {
            lastEntry = h;
          } else {
            try {
              final dLast = DateTime.parse(lastEntry['date'] as String);
              final dH = DateTime.parse(h['date'] as String);
              if (dH.isAfter(dLast)) lastEntry = h;
            } catch (_) {}
          }
        }
      }
      if (lastEntry != null) {
        _previousResults[ex.name] = (lastEntry['series'] as List)
            .map((s) => Map<String, dynamic>.from(s as Map))
            .toList();
      }
      ex.results = [];
    }
    _loadSettings();
    _loadWorkoutNativeAds();
    _restoreInProgressWorkout();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted)
      setState(() {
        _timerSoundEnabled = prefs.getBool('timer_sound_enabled') ?? true;
        _vibrationEnabled = prefs.getBool('vibration_enabled') ?? true;
        _wakelockEnabled = prefs.getBool('wakelock_enabled') ?? true;
        _autoStartTimer = prefs.getBool('auto_start_timer') ?? true;
        _confirmSeriesEnabled = prefs.getBool('confirm_series_enabled') ?? true;
        _showWeightSuggestion = prefs.getBool('show_weight_suggestion') ?? true;
        _displayInPounds = prefs.getBool('use_pounds') ?? false;
        _disableWeightKeyboard =
            prefs.getBool('disable_weight_keyboard') ?? false;
      });
  }

  void _loadWorkoutNativeAds() {
    if (kIsWeb) return;
    void loadAd({required String adUnitId, required String placement}) {
      final current = switch (placement) {
        'inline' => _inlineWorkoutNativeAd,
        'start' => _startWorkoutNativeAd,
        'confirm' => _confirmPopupNativeAd,
        'timer' => _timerRestNativeAd,
        'recap' => _recapWorkoutNativeAd,
        _ => null,
      };
      current?.dispose();
      final ad = NativeAd(
        adUnitId: adUnitId,
        factoryId: kWorkoutNativeAdFactoryId,
        request: const AdRequest(),
        listener: NativeAdListener(
          onAdLoaded: (loadedAd) {
            if (!mounted) {
              loadedAd.dispose();
              return;
            }
            setState(() {
              switch (placement) {
                case 'inline':
                  _inlineWorkoutNativeAd = loadedAd as NativeAd;
                  _isInlineWorkoutNativeAdLoaded = true;
                  break;
                case 'start':
                  _startWorkoutNativeAd = loadedAd as NativeAd;
                  _isStartWorkoutNativeAdLoaded = true;
                  break;
                case 'confirm':
                  _confirmPopupNativeAd = loadedAd as NativeAd;
                  _isConfirmPopupNativeAdLoaded = true;
                  break;
                case 'timer':
                  _timerRestNativeAd = loadedAd as NativeAd;
                  _isTimerRestNativeAdLoaded = true;
                  break;
                case 'recap':
                  _recapWorkoutNativeAd = loadedAd as NativeAd;
                  _isRecapWorkoutNativeAdLoaded = true;
                  break;
              }
            });
          },
          onAdFailedToLoad: (failedAd, error) {
            failedAd.dispose();
            if (!mounted) return;
            setState(() {
              switch (placement) {
                case 'inline':
                  _inlineWorkoutNativeAd = null;
                  _isInlineWorkoutNativeAdLoaded = false;
                  break;
                case 'start':
                  _startWorkoutNativeAd = null;
                  _isStartWorkoutNativeAdLoaded = false;
                  break;
                case 'confirm':
                  _confirmPopupNativeAd = null;
                  _isConfirmPopupNativeAdLoaded = false;
                  break;
                case 'timer':
                  _timerRestNativeAd = null;
                  _isTimerRestNativeAdLoaded = false;
                  break;
                case 'recap':
                  _recapWorkoutNativeAd = null;
                  _isRecapWorkoutNativeAdLoaded = false;
                  break;
              }
            });
            debugPrint('$placement workout native ad failed to load: $error');
          },
        ),
      );
      switch (placement) {
        case 'inline':
          _inlineWorkoutNativeAd = ad;
          break;
        case 'start':
          _startWorkoutNativeAd = ad;
          break;
        case 'confirm':
          _confirmPopupNativeAd = ad;
          break;
        case 'timer':
          _timerRestNativeAd = ad;
          break;
        case 'recap':
          _recapWorkoutNativeAd = ad;
          break;
      }
      ad.load();
    }

    loadAd(adUnitId: kWorkoutInlineNativeAdUnitId, placement: 'inline');
    loadAd(adUnitId: kWorkoutStartNativeAdUnitId, placement: 'start');
    loadAd(adUnitId: kConfirmPopupNativeAdUnitId, placement: 'confirm');
    loadAd(adUnitId: kTimerRestNativeAdUnitId, placement: 'timer');
    loadAd(adUnitId: kWorkoutRecapNativeAdUnitId, placement: 'recap');
  }

  /// Salva lo stato corrente dell'allenamento in SharedPreferences
  Future<void> _persistInProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final snapshot = {
      'exI': exI,
      'setN': setN,
      'eserciziCompletati': eserciziCompletati,
      'currentExSeries': currentExSeries,
      'supersetAccumulated': _supersetAccumulated.map(
        (k, v) => MapEntry(k.toString(), v),
      ),
      'allCompletedExercises': _allCompletedExercises,
    };
    await prefs.setString(_inProgressKey, jsonEncode(snapshot));
  }

  /// Ripristina un allenamento in corso (se esiste) all'avvio
  Future<void> _restoreInProgressWorkout() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_inProgressKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final snap = jsonDecode(raw) as Map<String, dynamic>;
      final savedExI = (snap['exI'] as num).toInt();
      final savedSetN = (snap['setN'] as num).toInt();
      final savedCompleted = (snap['eserciziCompletati'] as List)
          .cast<String>();
      final savedCurrent = (snap['currentExSeries'] as List)
          .cast<Map<String, dynamic>>();
      final savedSuperset =
          (snap['supersetAccumulated'] as Map<String, dynamic>).map(
            (k, v) => MapEntry(
              int.parse(k),
              (v as List).cast<Map<String, dynamic>>(),
            ),
          );
      final savedAllDone = (snap['allCompletedExercises'] as List)
          .cast<Map<String, dynamic>>();

      // Difesa: se lo snapshot contiene un allenamento già completato, cancella e riparte
      if (savedCompleted.length >= widget.day.exercises.length) {
        await prefs.remove(_inProgressKey);
        return;
      }

      if (!mounted) return;
      setState(() {
        exI = savedExI.clamp(0, widget.day.exercises.length - 1);
        setN = savedSetN;
        eserciziCompletati = savedCompleted;
        currentExSeries = savedCurrent;
        _supersetAccumulated.addAll(savedSuperset);
        _allCompletedExercises = savedAllDone;
        _awaitingFirstExerciseStart = false;
        // Ripristina i risultati degli esercizi completati nel modello
        for (final done in savedAllDone) {
          final name = done['exercise'] as String;
          final series = (done['series'] as List).cast<Map<String, dynamic>>();
          final ex = widget.day.exercises.firstWhere(
            (e) => e.name == name,
            orElse: () => widget.day.exercises.first,
          );
          ex.results = series;
        }
        if (currentExSeries.isNotEmpty) {
          widget.day.exercises[exI].results = currentExSeries;
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppL.restoreWorkout),
            duration: const Duration(seconds: 3),
            backgroundColor: const Color(0xFF1C1C2E),
          ),
        );
      }
    } catch (_) {
      // Snapshot corrotto: ignora
      final prefs2 = await SharedPreferences.getInstance();
      await prefs2.remove(_inProgressKey);
    }
  }

  Future<void> _saveAndExit() async {
    final prefs = await SharedPreferences.getInstance();

    // Sincronizza l'esercizio corrente prima di chiudere
    widget.day.exercises[exI].results = List.from(currentExSeries);

    // Recupera la routine dal disco (quella che leggono i grafici)
    String? routineString = prefs.getString('client_routine');
    if (routineString != null) {
      List<dynamic> fullRoutine = jsonDecode(routineString);

      // Trova il giorno attuale e aggiornalo con i nuovi risultati (serie e note)
      for (int i = 0; i < fullRoutine.length; i++) {
        if (fullRoutine[i]['dayName'] == widget.day.dayName) {
          fullRoutine[i] = widget.day.toJson();
          break;
        }
      }

      // Sovrascrivi il file sul disco: ora i grafici vedranno le modifiche!
      await prefs.setString('client_routine', jsonEncode(fullRoutine));
    }

    _timerRunId = _newTimerRunId();
    _bgTimer?.cancel();
    timerActive = false;
    _bgCounter = 0;
    _endTime = null;
    await _clearTimerNotifications();
    if (mounted) Navigator.pop(context);
  }

  Future<bool> _mostraDialogConfermaUscita() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1C1C1E),
            title: Text(
              AppL.quitWorkout,
              style: const TextStyle(color: Colors.white),
            ),
            content: Text(
              AppL.quitWorkoutMsg,
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  AppL.cancel.toUpperCase(),
                  style: const TextStyle(color: Colors.white38),
                ),
              ),
              // Nel metodo _mostraDialogConfermaUscita
              TextButton(
                onPressed: () async {
                  // 1. Chiudi il Dialog immediatamente
                  Navigator.of(context).pop();

                  // 2. Esegui il salvataggio e la chiusura della pagina
                  await _saveAndExit();
                },
                child: Text(
                  AppL.exitAndSave,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  // --- NUOVA FUNZIONE NOTIFICA ---
  Future<void> _programmaNotificaFine(int secondi, int timerRunId) async {
    ++_notifGen;
    final gen = _notifGen;
    if (kIsWeb) {
      await Future.delayed(Duration(seconds: secondi));
      if (gen != _notifGen || timerRunId != _timerRunId || _endTime == null) {
        return;
      }
      _showWebTimerNotification();
      return;
    }

    // Cancella notifica finale precedente
    try {
      await flutterLocalNotificationsPlugin.cancel(0);
      await flutterLocalNotificationsPlugin.cancel(2);
    } catch (_) {}
    try {
      await _gymFileChannel.invokeMethod('cancelTimerFinishedNotification');
    } catch (_) {}

    try {
      await _gymFileChannel.invokeMethod('scheduleTimerFinishedNotification', {
        'delayMs': secondi * 1000,
        'title': AppL.lang == 'en'
            ? '💪 GET BACK TO TRAINING!'
            : '💪 TORNA AD ALLENARTI!',
        'body': AppL.lang == 'en' ? '' : '',
      });
    } catch (e) {
      debugPrint("Errore notifica: $e");
    }
  }

  Future<void> _showTimerFinishedNotificationNow() async {
    if (kIsWeb) return;
    try {
      await flutterLocalNotificationsPlugin.cancel(2);
      await _gymFileChannel.invokeMethod('cancelTimerFinishedNotification');
      await flutterLocalNotificationsPlugin.show(
        0,
        AppL.lang == 'en'
            ? '💪 GET BACK TO TRAINING!'
            : '💪 TORNA AD ALLENARTI!',
        AppL.lang == 'en'
            ? 'Rest timer completed.'
            : 'Il timer di recupero è terminato.',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'timer_gym_alert',
            'Timer Fine Recupero',
            importance: Importance.max,
            priority: Priority.max,
            icon: 'ic_notification',
            playSound: true,
            enableVibration: true,
            category: AndroidNotificationCategory.message,
            visibility: NotificationVisibility.public,
            ticker: 'Torna ad allenarti',
          ),
        ),
      );
    } catch (_) {}
  }

  // Aggiorna la notifica countdown nel pannello con il tempo rimanente grande (nativo)
  void _aggiornaCountdown(int remaining, int timerRunId) {
    if (kIsWeb) return;
    if (timerRunId != _timerRunId || !timerActive || _endTime == null) return;
    final mins = remaining ~/ 60;
    final secs = remaining % 60;
    final timeStr =
        '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    final subtitle = AppL.lang == 'en'
        ? '⏱ Rest in progress'
        : '⏱ Recupero in corso';
    try {
      _gymFileChannel.invokeMethod('showTimerNotification', {
        'time': timeStr,
        'subtitle': subtitle,
        'channel': 'timer_gym_cd',
        'remainingSeconds': remaining,
        'token': timerRunId,
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_bgTimer != null) _bgTimer!.cancel();
    _clearTimerNotifications();
    _inlineWorkoutNativeAd?.dispose();
    _startWorkoutNativeAd?.dispose();
    _confirmPopupNativeAd?.dispose();
    _timerRestNativeAd?.dispose();
    _recapWorkoutNativeAd?.dispose();
    wC.dispose();
    rC.dispose();
    for (final ctrl in _noteControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  // Questo metodo rileva quando l'utente esce dall'app (va su YouTube)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appLifecycleState = state;
    if (state == AppLifecycleState.resumed) {
      _clearTimerNotifications();
    }
  }

  Future<void> _clearCountdownNotification() async {
    if (kIsWeb) return;
    try {
      await flutterLocalNotificationsPlugin.cancel(0);
      await flutterLocalNotificationsPlugin.cancel(1);
      await flutterLocalNotificationsPlugin.cancel(2);
    } catch (_) {}
    try {
      await _gymFileChannel.invokeMethod('cancelCountdownNotification');
    } catch (_) {}
  }

  Future<void> _clearTimerNotifications() async {
    if (kIsWeb) {
      ++_notifGen;
      return;
    }
    ++_notifGen;
    try {
      await flutterLocalNotificationsPlugin.cancel(0);
    } catch (_) {}
    try {
      await flutterLocalNotificationsPlugin.cancel(1);
    } catch (_) {}
    try {
      await flutterLocalNotificationsPlugin.cancel(2);
    } catch (_) {}
    try {
      await _gymFileChannel.invokeMethod('cancelTimerFinishedNotification');
    } catch (_) {}
    try {
      await _gymFileChannel.invokeMethod('cancelTimerNotification');
    } catch (_) {}
  }

  void _prepareWebTimerFeedback() {
    if (!kIsWeb) return;
    try {
      js.context.callMethod('eval', [
        """
(() => {
  try {
    if ('Notification' in window && Notification.permission === 'default') {
      Notification.requestPermission();
    }
    const Ctx = window.AudioContext || window.webkitAudioContext;
    if (Ctx) {
      const ctx = window.__gymTimerAudioCtx || (window.__gymTimerAudioCtx = new Ctx());
      if (ctx.state === 'suspended') ctx.resume();
    }
  } catch (_) {}
})();
""",
      ]);
    } catch (_) {}
  }

  void _showWebTimerNotification() {
    if (!kIsWeb) return;
    final title = jsonEncode(
      AppL.lang == 'en' ? 'Workout timer finished' : 'Timer recupero finito',
    );
    final body = jsonEncode(
      AppL.lang == 'en' ? 'Get back to training.' : 'Torna ad allenarti.',
    );
    try {
      js.context.callMethod('eval', [
        """
(() => {
  try {
    if (!('Notification' in window)) return;
    const show = () => new Notification($title, {
      body: $body,
      tag: 'gymapp-rest-timer',
      renotify: true,
    });
    if (Notification.permission === 'granted') {
      show();
    } else if (Notification.permission !== 'denied') {
      Notification.requestPermission().then((permission) => {
        if (permission === 'granted') show();
      });
    }
  } catch (_) {}
})();
""",
      ]);
    } catch (_) {}
  }

  void _playWebTimerBeep() {
    if (!kIsWeb) return;
    try {
      js.context.callMethod('eval', [
        """
(() => {
  try {
    const Ctx = window.AudioContext || window.webkitAudioContext;
    if (!Ctx) return;
    const ctx = window.__gymTimerAudioCtx || (window.__gymTimerAudioCtx = new Ctx());
    const base = ctx.currentTime + 0.01;
    [740, 740, 880].forEach((freq, index) => {
      const offset = index * 0.35;
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = 'sine';
      osc.frequency.value = freq;
      gain.gain.setValueAtTime(0.0001, base + offset);
      gain.gain.exponentialRampToValueAtTime(0.12, base + offset + 0.02);
      gain.gain.exponentialRampToValueAtTime(0.0001, base + offset + 0.28);
      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.start(base + offset);
      osc.stop(base + offset + 0.30);
    });
    if (ctx.state === 'suspended') ctx.resume();
  } catch (_) {}
})();
""",
      ]);
    } catch (_) {}
  }

  void _vibrateWebTimer() {
    if (!kIsWeb) return;
    try {
      js.context.callMethod('eval', [
        "try { if (navigator.vibrate) navigator.vibrate([0, 500, 200, 500, 200, 500]); } catch (_) {}",
      ]);
    } catch (_) {}
  }

  String _formatWeightLabel(double kg) =>
      '${formatWeightValue(kg, usePounds: _displayInPounds)} ${_displayInPounds ? 'lb' : 'kg'}';

  // Calcola il punteggio performance: > 0 miglioramento, < 0 peggioramento, 0 stallo
  int _calcPerformanceScore() {
    int improved = 0, regressed = 0;
    for (final ex in _allCompletedExercises) {
      final name = ex['exercise'] as String;
      final currSeries = (ex['series'] as List).cast<Map<String, dynamic>>();
      final prevSeries = _previousResults[name];
      if (prevSeries == null || prevSeries.isEmpty || currSeries.isEmpty)
        continue;
      final prevAvgW =
          prevSeries
              .map((s) => (s['w'] as num).toDouble())
              .reduce((a, b) => a + b) /
          prevSeries.length;
      final prevAvgR =
          prevSeries
              .map((s) => (s['r'] as num).toDouble())
              .reduce((a, b) => a + b) /
          prevSeries.length;
      final currAvgW =
          currSeries
              .map((s) => (s['w'] as num).toDouble())
              .reduce((a, b) => a + b) /
          currSeries.length;
      final currAvgR =
          currSeries
              .map((s) => (s['r'] as num).toDouble())
              .reduce((a, b) => a + b) /
          currSeries.length;
      if (currAvgW > prevAvgW + 0.05 || currAvgR > prevAvgR + 0.05)
        improved++;
      else if (currAvgW < prevAvgW - 0.05 && currAvgR < prevAvgR - 0.05)
        regressed++;
    }
    return improved - regressed;
  }

  // Ritorna lista dettagli miglioramenti per esercizio
  void _showDettagliMiglioramenti(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          AppL.workoutSummary,
          style: TextStyle(
            color: Theme.of(c).colorScheme.primary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _allCompletedExercises.length,
            itemBuilder: (_, i) {
              final ex = _allCompletedExercises[i];
              final name = ex['exercise'] as String;
              final currSeries = (ex['series'] as List)
                  .map((s) => Map<String, dynamic>.from(s as Map))
                  .toList();
              final prevSeries = _previousResults[name];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...List.generate(currSeries.length, (si) {
                      final s = currSeries[si];
                      final double w = (s['w'] as num).toDouble();
                      final int r = (s['r'] as num).toInt();
                      // Confronto con la stessa serie del giro precedente
                      Color serieColor = Colors.white70;
                      String compareStr = '';
                      if (prevSeries != null && si < prevSeries.length) {
                        final ps = prevSeries[si];
                        final double pw = (ps['w'] as num).toDouble();
                        final int pr = (ps['r'] as num).toInt();
                        final dW = w - pw;
                        final dR = r - pr;
                        if (dW > 0.05 || dR > 0) {
                          serieColor = Colors.greenAccent;
                          if (dW > 0.05 && dR > 0)
                            compareStr =
                                ' (+${dW.toStringAsFixed(1)}kg, +$dR reps)';
                          else if (dW > 0.05)
                            compareStr = ' (+${dW.toStringAsFixed(1)}kg)';
                          else
                            compareStr = ' (+$dR reps)';
                        } else if (dW < -0.05 && dR < 0) {
                          serieColor = Colors.redAccent;
                          compareStr =
                              ' (${dW.toStringAsFixed(1)}kg, ${dR}reps)';
                        } else {
                          serieColor = Colors.white60;
                          compareStr = ' (=)';
                        }
                      } else if (prevSeries == null) {
                        serieColor = Colors.white54;
                      }
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 28,
                              child: Text(
                                'S${si + 1}',
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Text(
                              '${w % 1 == 0 ? w.toInt() : w} kg × $r reps$compareStr',
                              style: TextStyle(
                                color: serieColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const Divider(color: Colors.white12, height: 20),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(
              AppL.close,
              style: TextStyle(color: Theme.of(c).colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  void _showRecapDialog() {
    int totalSeries = 0;
    for (final ex in _allCompletedExercises) {
      totalSeries += (ex['series'] as List).length;
    }
    final score = _calcPerformanceScore();
    // hasPrev = almeno un esercizio ha dati dalla sessione precedente
    final hasPrev = _allCompletedExercises.any(
      (ex) => _previousResults.containsKey(ex['exercise']),
    );
    if (kIsWeb) {
      _recordWebDonationPromptIfNeeded();
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) {
        IconData perfIcon;
        Color perfColor;
        String perfLabel;
        if (!hasPrev) {
          perfIcon = Icons.fitness_center;
          perfColor = Theme.of(c).colorScheme.primary;
          perfLabel = AppL.firstSession;
        } else if (score > 0) {
          perfIcon = Icons.trending_up;
          perfColor = Colors.greenAccent;
          perfLabel = AppL.improving;
        } else if (score < 0) {
          perfIcon = Icons.trending_down;
          perfColor = Colors.redAccent;
          perfLabel = AppL.declining;
        } else {
          perfIcon = Icons.trending_flat;
          perfColor = Colors.orangeAccent;
          perfLabel = AppL.plateau;
        }
        return AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Column(
            children: [
              Icon(perfIcon, color: perfColor, size: 52),
              const SizedBox(height: 8),
              Text(
                AppL.workoutComplete,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(c).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                perfLabel,
                style: TextStyle(
                  color: perfColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Divider(color: Colors.white24),
                const SizedBox(height: 8),
                _recapRow(
                  Icons.fitness_center,
                  AppL.exercisesLabel,
                  '${_allCompletedExercises.length}',
                ),
                _recapRow(Icons.repeat, AppL.totalSeries, '$totalSeries'),
                const SizedBox(height: 8),
                const Divider(color: Colors.white24),
                const SizedBox(height: 8),
                // Streak progress section
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF252527),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _currentStreak > 0
                          ? Colors.orange.withAlpha(80)
                          : Colors.white12,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('🔓', style: TextStyle(fontSize: 15)),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              AppL.lang == 'en'
                                  ? 'Session unlocked! $_streakDoneCount/$_streakTotalCount this microcycle'
                                  : 'Sessione sbloccata! $_streakDoneCount/$_streakTotalCount questo microciclo',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (widget.allSessionNames.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        LayoutBuilder(
                          builder: (ctx, constraints) {
                            final n = widget.allSessionNames.length;
                            final iconSize = n > 0
                                ? (constraints.maxWidth / n - 8).clamp(
                                    18.0,
                                    48.0,
                                  )
                                : 48.0;
                            return Row(
                              children: List.generate(n, (i) {
                                final name = widget.allSessionNames[i];
                                final done = _streakDoneNames.contains(name);
                                return Expanded(
                                  child: Center(
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      width: iconSize,
                                      height: iconSize,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(7),
                                        gradient: done
                                            ? const LinearGradient(
                                                colors: [
                                                  Color(0xFFFF6B00),
                                                  Color(0xFFFFAB00),
                                                ],
                                              )
                                            : null,
                                        color: done
                                            ? null
                                            : const Color(0xFF1C1C1E),
                                        boxShadow: done
                                            ? [
                                                BoxShadow(
                                                  color: Colors.orange
                                                      .withAlpha(80),
                                                  blurRadius: 6,
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(7),
                                        child: Opacity(
                                          opacity: done ? 1.0 : 0.2,
                                          child: Image.asset(
                                            'assets/icon_client.png',
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            );
                          },
                        ),
                      ],
                      const SizedBox(height: 8),
                      if (_streakDoneCount >= _streakTotalCount &&
                          _streakTotalCount > 0)
                        Text(
                          AppL.lang == 'en'
                              ? '🔥 Microcycle complete! Streak continues!'
                              : '🔥 Microciclo completato! La streak continua!',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        )
                      else ...[
                        Text(
                          AppL.lang == 'en'
                              ? 'Complete ${_streakTotalCount - _streakDoneCount} more session${_streakTotalCount - _streakDoneCount == 1 ? '' : 's'} to keep your streak!'
                              : 'Completa ancora ${_streakTotalCount - _streakDoneCount} session${_streakTotalCount - _streakDoneCount == 1 ? 'e' : 'i'} per non perdere i tuoi progressi!',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 11,
                          ),
                        ),
                      ],
                      if (_currentStreak > 0) ...[
                        const SizedBox(height: 6),
                        Text(
                          AppL.lang == 'en'
                              ? '🔥 $_currentStreak microcycle${_currentStreak == 1 ? '' : 's'} streak!'
                              : '🔥 $_currentStreak ${_currentStreak == 1 ? 'micro' : 'micro'} di fila!',
                          style: const TextStyle(
                            color: Colors.orange,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _buildRecapNativeAd(),
                if (!kIsWeb) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.share_rounded),
                      label: Text(
                        AppL.lang == 'en' ? 'Share workout' : 'Condividi allenamento',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(c).colorScheme.primary,
                        side: BorderSide(color: Theme.of(c).colorScheme.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => _shareWorkoutResult(c),
                    ),
                  ),
                ],
                if (kIsWeb) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF252527),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Theme.of(c).colorScheme.primary.withAlpha(70),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppL.lang == 'en'
                              ? 'Monthly donation required on GymApp Web'
                              : 'Donazione mensile richiesta su GymApp Web',
                          style: TextStyle(
                            color: Theme.of(c).colorScheme.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          AppL.lang == 'en'
                              ? 'Donate at least €1 every month or the web app will stop working. These funds are used to publish GymApp on the Apple App Store.'
                              : 'Dona almeno 1€ ogni mese oppure la web app smettera di funzionare. Questi fondi vengono usati per pubblicare GymApp su Apple App Store.',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: openPaypalDonationPage,
                                icon: const Icon(Icons.open_in_new_rounded),
                                label: Text(
                                  AppL.lang == 'en'
                                      ? 'Open PayPal'
                                      : 'Apri PayPal',
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Theme.of(
                                    c,
                                  ).colorScheme.primary,
                                  side: BorderSide(
                                    color: Theme.of(c).colorScheme.primary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  await openPaypalDonationPage();
                                },
                                child: Text(
                                  AppL.lang == 'en'
                                      ? 'Donate on PayPal'
                                      : 'Dona con PayPal',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppL.lang == 'en'
                              ? 'Automatic verification is not possible here without a server: confirmation is stored locally on this device.'
                              : 'Senza server la verifica automatica non e possibile: la conferma viene salvata localmente su questo dispositivo.',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(c).colorScheme.primary,
                  side: BorderSide(color: Theme.of(c).colorScheme.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => _showDettagliMiglioramenti(c),
                child: Text(
                  AppL.details,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(c).colorScheme.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(c);
                  Navigator.pop(context);
                },
                child: Text(
                  AppL.greatWork,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildWorkoutReadyScreen(
    ExerciseConfig ex,
    double lastW,
    int lastR,
    bool suggerisciAumento,
    Color accent,
  ) {
    final info =
        (ex.gifFilename != null ? findByGifSlug(ex.gifFilename!) : null) ??
        findAnyExercise(ex.name);
    final gifPath = ex.gifFilename != null
        ? exerciseAnimationAssetPath(ex.gifFilename!)
        : info != null
        ? exerciseAnimationAssetPath(info.gifSlug)
        : null;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              children: [
                Text(
                  AppL.lang == 'en'
                      ? (exI == 0
                            ? 'Get ready for the first exercise'
                            : 'Get ready for this exercise')
                      : (exI == 0
                            ? 'Preparati al primo esercizio'
                            : 'Preparati a questo esercizio'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: accent,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  localizedExerciseName(ex.name),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    IconButton(
                      onPressed: exI > 0
                          ? () => _cambiaEsercizioMethod(exI - 1)
                          : null,
                      icon: const Icon(
                        Icons.chevron_left,
                        color: Colors.white70,
                      ),
                    ),
                    Expanded(
                      child: gifPath != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Image.asset(
                                gifPath,
                                height: 220,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.fitness_center,
                                  size: 72,
                                  color: Colors.white24,
                                ),
                              ),
                            )
                          : const SizedBox(
                              height: 220,
                              child: Center(
                                child: Icon(
                                  Icons.fitness_center,
                                  size: 72,
                                  color: Colors.white24,
                                ),
                              ),
                            ),
                    ),
                    IconButton(
                      onPressed: exI < widget.day.exercises.length - 1
                          ? () => _cambiaEsercizioMethod(exI + 1)
                          : null,
                      icon: const Icon(
                        Icons.chevron_right,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                if (lastW > 0) ...[
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(6),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppL.lastTime.toUpperCase(),
                          style: TextStyle(
                            color: accent.withAlpha(210),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${_formatWeightLabel(lastW)} x $lastR reps',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (suggerisciAumento && _showWeightSuggestion) ...[
                          const SizedBox(height: 8),
                          Text(
                            AppL.lang == 'en'
                                ? 'You closed the target last time: consider increasing the load.'
                                : 'Hai chiuso il target l\'ultima volta: valuta un aumento del carico.',
                            style: const TextStyle(
                              color: Colors.amber,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                if (ex.notePT.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.amber.withAlpha(12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'COACH: ${ex.notePT}',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _awaitingFirstExerciseStart = false;
                      });
                    },
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(
                      AppL.lang == 'en'
                          ? (exI == 0
                                ? 'Start first exercise'
                                : 'Start from this exercise')
                          : (exI == 0
                                ? 'Inizia il primo esercizio'
                                : 'Inizia da questo esercizio'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutNativeAd() {
    if (kIsWeb ||
        !_isInlineWorkoutNativeAdLoaded ||
        _inlineWorkoutNativeAd == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      child: SizedBox(
        width: double.infinity,
        height: 86,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AdWidget(ad: _inlineWorkoutNativeAd!),
        ),
      ),
    );
  }

  Widget _buildWorkoutStartNativeAd() {
    if (kIsWeb ||
        !_isStartWorkoutNativeAdLoaded ||
        _startWorkoutNativeAd == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      child: SizedBox(
        width: double.infinity,
        height: 86,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AdWidget(ad: _startWorkoutNativeAd!),
        ),
      ),
    );
  }

  Widget _buildConfirmPopupNativeAd() {
    if (kIsWeb ||
        !_isConfirmPopupNativeAdLoaded ||
        _confirmPopupNativeAd == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 6, 0, 6),
      child: SizedBox(
        width: double.infinity,
        height: 86,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AdWidget(ad: _confirmPopupNativeAd!),
        ),
      ),
    );
  }

  Widget _buildTimerRestNativeAd() {
    if (kIsWeb || !_isTimerRestNativeAdLoaded || _timerRestNativeAd == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: SizedBox(
        width: double.infinity,
        height: 86,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AdWidget(ad: _timerRestNativeAd!),
        ),
      ),
    );
  }

  Widget _buildRecapNativeAd() {
    if (kIsWeb ||
        !_isRecapWorkoutNativeAdLoaded ||
        _recapWorkoutNativeAd == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: SizedBox(
        width: double.infinity,
        height: 86,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AdWidget(ad: _recapWorkoutNativeAd!),
        ),
      ),
    );
  }

  Widget _recapRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Icon(icon, color: Colors.amber, size: 20),
        const SizedBox(width: 12),
        Flexible(
          child: Text(label, style: const TextStyle(color: Colors.white60)),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    ),
  );

  Future<void> _shareWorkoutResult(BuildContext ctx) async {
    await showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) {
        // Compute session progress vs previous session
        double? progressPct;
        if (_previousResults.isNotEmpty && _allCompletedExercises.isNotEmpty) {
          double curMax = 0, prevMax = 0;
          for (final ex in _allCompletedExercises) {
            for (final s in (ex['series'] as List)) {
              final w = (s['w'] ?? 0.0).toDouble();
              if (w > curMax) curMax = w;
            }
            final pSeries = _previousResults[ex['exercise']];
            if (pSeries != null) {
              for (final s in pSeries) {
                final w = (s['w'] ?? 0.0).toDouble();
                if (w > prevMax) prevMax = w;
              }
            }
          }
          if (prevMax > 0) progressPct = (curMax - prevMax) / prevMax * 100;
        }
        return _WorkoutShareSheet(
          dayName: widget.day.dayName,
          todayLabel: _todayLabel(),
          exercises: List.from(_allCompletedExercises),
          streak: _currentStreak,
          accent: Theme.of(ctx).colorScheme.primary,
          streakDoneNames: Set<String>.from(_streakDoneNames),
          progressPercent: progressPct,
          allSessionNames: List<String>.from(widget.allSessionNames),
        );
      },
    );
  }

  Future<void> _shareStreakStory(BuildContext ctx) async {
    final allNames = widget.allSessionNames;
    await showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => _StreakShareSheet(
        streak: _currentStreak,
        streakDoneNames: Set<String>.from(_streakDoneNames),
        allSessionNames: List<String>.from(allNames),
        accent: Theme.of(ctx).colorScheme.primary,
      ),
    );
  }

  String _todayLabel() {
    final now = DateTime.now();
    return '${now.day}/${now.month}/${now.year}';
  }

  // Avvia il timer al primo tocco — se è già attivo non fa nulla
  void _avviaTimerSeNonAttivo(int sec) {
    if (timerActive) return; // già in corso, non azzerare
    _triggerTimer(sec, force: true);
  }

  void _cambiaEsercizioMethod(int nuovoIndice) {
    setState(() {
      widget.day.exercises[exI].results = List.from(currentExSeries);
      exI = nuovoIndice;
      var nuovoEx = widget.day.exercises[exI];
      currentExSeries = List.from(nuovoEx.results);
      if (eserciziCompletati.contains(nuovoEx.name)) {
        setN = nuovoEx.targetSets;
      } else {
        setN = currentExSeries.length + 1;
      }
    });
    _setDrumValues(nuovoIndice, setN);
  }

  void _triggerTimer(int sec, {bool force = false}) {
    // Se il timer è già attivo e NON stiamo forzando, usciamo subito
    // SENZA cancellare il timer che sta correndo.
    if (timerActive && !force) return;
    if (!_autoStartTimer && !force) return;
    _prepareWebTimerFeedback();

    if (_wakelockEnabled)
      try {
        WakelockPlus.enable();
      } catch (_) {}
    _bgTimer?.cancel();

    // 1. Calcoliamo l'orario esatto di fine
    _endTime = DateTime.now().add(Duration(seconds: sec));

    setState(() {
      _bgCounter = sec;
      _maxTime = sec;
      timerActive = true;
    });

    final timerRunId = _newTimerRunId();
    _timerRunId = timerRunId;

    // 2. Programmiamo la notifica finale (Future.delayed) e mostriamo countdown
    _programmaNotificaFine(sec, timerRunId);
    _aggiornaCountdown(
      sec,
      timerRunId,
    ); // countdown iniziale nel pannello notifiche

    // 3. Timer visivo
    _bgTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (timerRunId != _timerRunId || _endTime == null) {
        t.cancel();
        return;
      }

      final remaining = _endTime!.difference(DateTime.now()).inSeconds;

      if (remaining <= 0) {
        _clearCountdownNotification();
        if (_appLifecycleState == AppLifecycleState.resumed) {
          _showTimerFinishedNotificationNow();
        }
        _eseguiFeedbackFineTimer();
        t.cancel();
        if (mounted) {
          setState(() {
            timerActive = false;
            isRestingFullScreen = false;
            _bgCounter = 0;
            _endTime = null;
          });
        }
        try {
          WakelockPlus.disable();
        } catch (_) {}
      } else {
        if (mounted) {
          setState(() {
            _bgCounter = remaining;
          });
        }
      }
    });
  }

  // Suono di avviso tramite ToneGenerator nativo Android — campanella bassa x3
  Future<void> _playBeep() async {
    if (kIsWeb) {
      _playWebTimerBeep();
      return;
    }
    try {
      // ♪ dong dong DONG — tre rintocchi lenti da campanella
      await _gymFileChannel.invokeMethod('playBeep', 500);
      await Future.delayed(const Duration(milliseconds: 350));
      await _gymFileChannel.invokeMethod('playBeep', 500);
      await Future.delayed(const Duration(milliseconds: 350));
      await _gymFileChannel.invokeMethod('playBeep', 700);
    } catch (e) {
      debugPrint("Errore beep: $e");
    }
  }

  void _eseguiFeedbackFineTimer() async {
    if (kIsWeb) {
      _showWebTimerNotification();
      if (_timerSoundEnabled) _playWebTimerBeep();
      if (_vibrationEnabled) _vibrateWebTimer();
    } else {
      if (_timerSoundEnabled) _playBeep();
      if (_vibrationEnabled && (await Vibration.hasVibrator()) == true) {
        Vibration.vibrate(pattern: [0, 500, 200, 500, 200, 500]);
      }
      HapticFeedback.heavyImpact();
      Future.delayed(
        const Duration(milliseconds: 300),
        () => HapticFeedback.heavyImpact(),
      );
    }
  }

  Future<void> _aggiornaJsonSuDisco() async {
    final prefs = await SharedPreferences.getInstance();
    String? routineString = prefs.getString('client_routine');

    if (routineString != null) {
      List<dynamic> fullRoutine = jsonDecode(routineString);

      // Cerchiamo il giorno corrente (es. "Push") nella lista globale
      for (int i = 0; i < fullRoutine.length; i++) {
        if (fullRoutine[i]['dayName'] == widget.day.dayName) {
          // Sovrascriviamo il giorno vecchio con quello aggiornato (che ha i nuovi results)
          fullRoutine[i] = widget.day.toJson();
          break;
        }
      }

      // Scriviamo il JSON aggiornato sul telefono
      await prefs.setString('client_routine', jsonEncode(fullRoutine));
      debugPrint("Grafici aggiornati sul disco!");
    }
  }

  void _confermaSerie() {
    final double w = double.tryParse(wC.text) ?? -1;
    final int r = int.tryParse(rC.text) ?? 0;
    if (w < 0 || r <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppL.enterKgReps),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    final currentEx = widget.day.exercises[exI];
    _setExerciseWeightMode(
      currentEx,
      useQuarterStep: _usesQuarterStepForExercise(currentEx, w),
      useEvenStep: _usesEvenStepForExercise(currentEx, w),
      useSingleStep: _usesSingleStepForExercise(currentEx, w),
    );
    if (!_confirmSeriesEnabled) {
      _saveSet();
      return;
    }

    // ── Avvia subito il timer al tap su "Conferma Serie" ──────────────────
    // Usiamo il recoveryTime dell'esercizio corrente (o maxRecovery del gruppo)
    int previewRecovery = currentEx.recoveryTime;
    if (currentEx.supersetGroup > 0) {
      int groupStart = exI, groupEnd = exI;
      while (groupStart > 0 &&
          widget.day.exercises[groupStart - 1].supersetGroup ==
              currentEx.supersetGroup)
        groupStart--;
      while (groupEnd < widget.day.exercises.length - 1 &&
          widget.day.exercises[groupEnd + 1].supersetGroup ==
              currentEx.supersetGroup)
        groupEnd++;
      previewRecovery = widget.day.exercises
          .sublist(groupStart, groupEnd + 1)
          .map((e) => e.recoveryTime)
          .reduce((a, b) => a > b ? a : b);
    }
    // Avvia il timer al tap su Conferma (solo se non è già partito)
    _avviaTimerSeNonAttivo(previewRecovery);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              currentEx.name.toUpperCase(),
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "${AppL.sets} $setN",
              style: const TextStyle(color: Colors.white38, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _chipConferma(
                  "${w % 1 == 0 ? w.toInt() : w} kg",
                  const Color(0xFFFFD700),
                ),
                const SizedBox(width: 20),
                _chipConferma("$r reps", Theme.of(ctx).colorScheme.primary),
              ],
            ),
            _buildConfirmPopupNativeAd(),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      // Annulla: il timer continua a scorrere
                      Navigator.pop(ctx);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white54,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(AppL.cancel.toUpperCase()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      // Il timer è già avviato, _saveSet non deve riavviarlo
                      _saveSet();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00C853),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      AppL.saveSeries,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showNewRecordOverlay() {
    HapticFeedback.heavyImpact();
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _RecordOverlay(
        lang: AppL.lang,
        onDone: () {
          if (entry.mounted) entry.remove();
        },
      ),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(milliseconds: 3200), () {
      if (entry.mounted) entry.remove();
    });
  }

  bool _usesQuarterStepForExercise(ExerciseConfig ex, double fallbackWeight) {
    if (ex.useQuarterStep || ex.useEvenStep || ex.useSingleStep) {
      return ex.useQuarterStep;
    }
    return ex.useQuarterStep || usesQuarterStepIncrement(fallbackWeight);
  }

  bool _usesEvenStepForExercise(ExerciseConfig ex, double fallbackWeight) {
    if (ex.useQuarterStep || ex.useEvenStep || ex.useSingleStep) {
      return ex.useEvenStep;
    }
    if (_displayInPounds || _usesQuarterStepForExercise(ex, fallbackWeight)) {
      return false;
    }
    return usesEvenStepIncrement(fallbackWeight);
  }

  bool _usesSingleStepForExercise(ExerciseConfig ex, double fallbackWeight) {
    if (ex.useQuarterStep || ex.useEvenStep || ex.useSingleStep) {
      return ex.useSingleStep;
    }
    if (_displayInPounds ||
        _usesQuarterStepForExercise(ex, fallbackWeight) ||
        _usesEvenStepForExercise(ex, fallbackWeight)) {
      return false;
    }
    return usesSingleStepIncrement(fallbackWeight);
  }

  void _setExerciseWeightMode(
    ExerciseConfig ex, {
    required bool useQuarterStep,
    required bool useEvenStep,
    required bool useSingleStep,
  }) {
    setState(() {
      ex.useQuarterStep = useQuarterStep;
      ex.useEvenStep = !useQuarterStep && useEvenStep;
      ex.useSingleStep = !useQuarterStep && !useEvenStep && useSingleStep;
    });
    _aggiornaJsonSuDisco();
  }

  bool get _showWorkoutReadyScreen =>
      _awaitingFirstExerciseStart &&
      setN == 1 &&
      currentExSeries.isEmpty &&
      widget.day.exercises.isNotEmpty &&
      !eserciziCompletati.contains(widget.day.exercises[exI].name);

  Widget _chipConferma(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    decoration: BoxDecoration(
      color: color.withAlpha(30),
      border: Border.all(color: color.withAlpha(180), width: 1.5),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold),
    ),
  );

  void _saveSet() async {
    double w = double.tryParse(wC.text) ?? 0.0;
    int r = int.tryParse(rC.text) ?? 0;
    if (w < 0 || r <= 0) return;
    _awaitingFirstExerciseStart = false;

    final currentEx = widget.day.exercises[exI];

    // Controlla record personale rispetto all'ultima sessione
    final suggest = _getSuggest(currentEx.name, setN);
    final lastW = (suggest['w'] as num?)?.toDouble() ?? 0.0;
    final lastR = (suggest['r'] as num?)?.toInt() ?? 0;
    setState(
      () => _isNewRecord = (lastW > 0 || lastR > 0) && (w > lastW || r > lastR),
    );
    if (_isNewRecord && mounted) {
      _showNewRecordOverlay();
    }

    final entry = {'s': setN, 'w': w, 'r': r};

    // ========== SUPERSERIE / CIRCUITO (round-robin) ==========
    final currentGroup = currentEx.supersetGroup;
    if (currentGroup > 0) {
      _supersetAccumulated.putIfAbsent(exI, () => []);
      _supersetAccumulated[exI]!.add(entry);

      // Trova confini del gruppo
      int groupStart = exI;
      while (groupStart > 0 &&
          widget.day.exercises[groupStart - 1].supersetGroup == currentGroup) {
        groupStart--;
      }
      int groupEnd = exI;
      while (groupEnd < widget.day.exercises.length - 1 &&
          widget.day.exercises[groupEnd + 1].supersetGroup == currentGroup) {
        groupEnd++;
      }

      int maxRounds = widget.day.exercises
          .sublist(groupStart, groupEnd + 1)
          .map((e) => e.targetSets)
          .reduce((a, b) => a > b ? a : b);
      int maxRecovery = widget.day.exercises
          .sublist(groupStart, groupEnd + 1)
          .map((e) => e.recoveryTime)
          .reduce((a, b) => a > b ? a : b);

      // Prossimo esercizio nel round corrente con ancora serie da fare (gestisce set diversi)
      int? nextExInRound;
      for (int i = exI + 1; i <= groupEnd; i++) {
        if (setN <= widget.day.exercises[i].targetSets) {
          nextExInRound = i;
          break;
        }
      }

      if (nextExInRound != null) {
        // Vai al prossimo esercizio nel round, senza riposo
        setState(() {
          exI = nextExInRound!;
          currentExSeries = List.from(_supersetAccumulated[exI] ?? []);
          _isNewRecord = false;
        });
        _setDrumValues(nextExInRound, setN);
      } else if (setN < maxRounds) {
        // Fine del round corrente, riposa e ricomincia al prossimo round
        final nextRound = setN + 1;
        // Trova il primo esercizio del prossimo round (skippa quelli con meno serie)
        int firstExNextRound = groupStart;
        for (int i = groupStart; i <= groupEnd; i++) {
          if (nextRound <= widget.day.exercises[i].targetSets) {
            firstExNextRound = i;
            break;
          }
        }
        setState(() {
          setN = nextRound;
          exI = firstExNextRound;
          currentExSeries = List.from(
            _supersetAccumulated[firstExNextRound] ?? [],
          );
          isRestingFullScreen = true;
          _isNewRecord = false;
        });
        _setDrumValues(firstExNextRound, nextRound);
        _avviaTimerSeNonAttivo(maxRecovery);
      } else {
        // Superserie/Circuito completato! Salva tutti gli esercizi del gruppo
        for (int i = groupStart; i <= groupEnd; i++) {
          final s = List<Map<String, dynamic>>.from(
            _supersetAccumulated[i] ?? [],
          );
          if (s.isNotEmpty) {
            _allCompletedExercises.add({
              'exercise': widget.day.exercises[i].name,
              'series': s,
            });
            widget.onDone({
              'exercise': widget.day.exercises[i].name,
              'series': s,
              'date': DateTime.now().toIso8601String(),
              'dayName': widget.day.dayName,
              'session_id': _sessionId,
            });
            if (!eserciziCompletati.contains(widget.day.exercises[i].name))
              eserciziCompletati.add(widget.day.exercises[i].name);
          }
        }
        _supersetAccumulated.clear();
        final bool tuttoFinito =
            eserciziCompletati.length == widget.day.exercises.length;
        if (tuttoFinito) {
          _bgTimer?.cancel();
          await _clearTimerNotifications();
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove(
            _inProgressKey,
          ); // Cancella snapshot: permette di rifare l'allenamento
          final routineStr = prefs.getString('client_routine');
          if (routineStr != null) {
            List<dynamic> full = jsonDecode(routineStr);
            for (int i = 0; i < full.length; i++) {
              if (full[i]['dayName'] == widget.day.dayName)
                full[i] = widget.day.toJson();
            }
            await prefs.setString('client_routine', jsonEncode(full));
          }
          // Aggiorna streak
          final streak = await updateStreak(
            widget.day.dayName,
            widget.allSessionNames,
          );
          final sData = await getStreakData();
          scheduleStreakReminder(AppL.lang); // reset reminder: prossimo in 48h
          if (mounted)
            setState(() {
              _currentStreak = streak;
              _streakDoneCount = sData.done.length;
              _streakTotalCount = widget.allSessionNames.length;
              _streakDoneNames = sData.done;
            });
          if (mounted) {
            if (!kIsWeb) {
              AdManager.instance.showInterstitialThenRun(_showRecapDialog);
            } else {
              _showRecapDialog();
            }
          }
          return; // Non salvare stato dopo workout completato
        } else if (_nextPendingExerciseIndex(fromExclusive: groupEnd)
            case final nextIndex?) {
          final pause = widget.day.exercises[groupEnd].interExercisePause > 0
              ? widget.day.exercises[groupEnd].interExercisePause
              : 120;
          setState(() {
            exI = nextIndex;
            setN = 1;
            currentExSeries = [];
            isRestingFullScreen = true;
            _isNewRecord = false;
          });
          _setDrumValues(nextIndex, 1);
          _triggerTimer(
            pause,
            force: true,
          ); // fine gruppo superset: pausa inter-esercizio
        } else {}
      }
      _persistInProgress();
      return; // Fine branch superserie/circuito
    }

    // ========== ESERCIZIO NORMALE ==========
    currentExSeries.add(entry);

    if (setN < currentEx.targetSets) {
      setState(() {
        isRestingFullScreen = true;
        setN++;
      });
      _setDrumValues(exI, setN);
      _avviaTimerSeNonAttivo(currentEx.recoveryTime);
    } else {
      _allCompletedExercises.add({
        'exercise': currentEx.name,
        'series': List.from(currentExSeries),
      });
      widget.onDone({
        'exercise': currentEx.name,
        'series': List.from(currentExSeries),
        'date': DateTime.now().toIso8601String(),
        'dayName': widget.day.dayName,
        'session_id': _sessionId,
      });
      if (!eserciziCompletati.contains(currentEx.name)) {
        eserciziCompletati.add(currentEx.name);
      }

      final bool tuttoFinito =
          eserciziCompletati.length == widget.day.exercises.length;
      if (tuttoFinito) {
        if (_bgTimer != null) _bgTimer!.cancel();
        await _clearTimerNotifications();
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(
          _inProgressKey,
        ); // Cancella snapshot: permette di rifare l'allenamento
        final routineStr = prefs.getString('client_routine');
        if (routineStr != null) {
          List<dynamic> full = jsonDecode(routineStr);
          for (int i = 0; i < full.length; i++) {
            if (full[i]['dayName'] == widget.day.dayName) {
              full[i] = widget.day.toJson();
            }
          }
          await prefs.setString('client_routine', jsonEncode(full));
        }
        // Aggiorna streak
        final streak = await updateStreak(
          widget.day.dayName,
          widget.allSessionNames,
        );
        final sData = await getStreakData();
        scheduleStreakReminder(AppL.lang); // reset reminder: prossimo in 48h
        if (mounted)
          setState(() {
            _currentStreak = streak;
            _streakDoneCount = sData.done.length;
            _streakTotalCount = widget.allSessionNames.length;
            _streakDoneNames = sData.done;
          });
        if (mounted) {
          if (!kIsWeb) {
            AdManager.instance.showInterstitialThenRun(_showRecapDialog);
          } else {
            _showRecapDialog();
          }
        }
        return; // Non salvare stato dopo workout completato
      } else if (_nextPendingExerciseIndex(fromExclusive: exI)
          case final nextIndex?) {
        final pauseTime = currentEx.interExercisePause > 0
            ? currentEx.interExercisePause
            : 120;
        setState(() {
          isRestingFullScreen = true;
          exI = nextIndex;
          setN = 1;
          currentExSeries = [];
          _isNewRecord = false;
        });
        _setDrumValues(nextIndex, 1);
        _triggerTimer(
          pauseTime,
          force: true,
        ); // fine esercizio: sempre pausa inter-esercizio
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.orange,
            content: Text(AppL.workoutNotDone),
          ),
        );
      }
    }
    _persistInProgress();
  }

  Future<void> _skipRest() async {
    ++_notifGen; // previene notifica Future.delayed pendente
    _timerRunId = _newTimerRunId();
    _bgTimer?.cancel();
    setState(() {
      isRestingFullScreen = false;
      timerActive = false;
      _bgCounter = 0;
      _endTime = null;
    });
    await _clearTimerNotifications();
    try {
      WakelockPlus.disable();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    // 1. DEFINIAMO L'ESERCIZIO ATTUALE
    var ex = widget.day.exercises[exI];

    void _cambiaEsercizio(int nuovoIndice) {
      _cambiaEsercizioMethod(nuovoIndice);
    }

    Widget _buildBoxEsercizioCompletato() {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(30),
        margin: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF00FF88).withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.5)),
        ),
        child: Column(
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF00FF88), size: 50),
            const SizedBox(height: 15),
            Text(
              AppL.exerciseComplete,
              style: const TextStyle(
                color: Color(0xFF00FF88),
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              AppL.exerciseCompleteMsg,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      );
    }

    // 2. CALCOLIAMO COSA FARE DOPO(Logica originale)
    if (setN <= ex.targetSets) {
      _infoProssimo =
          "${localizedExerciseName(ex.name).toUpperCase()}\n${AppL.sets} $setN ${AppL.of} ${ex.targetSets}";
      _prossimoNome = ex.name;
    } else if (_nextPendingExerciseIndex(fromExclusive: exI)
        case final nextIndex?) {
      var prossimoEs = widget.day.exercises[nextIndex];
      _infoProssimo =
          "${AppL.changeExercise}:\n${prossimoEs.name.toUpperCase()}";
      _prossimoNome = prossimoEs.name;
    } else {
      _infoProssimo = AppL.workoutComplete;
      _prossimoNome = '';
    }

    // 3. SE IL TIMER È ATTIVO, MOSTRA LA SCHERMATA NERA (Tua logica originale)
    if (isRestingFullScreen) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(AppL.skipUseButton)));
        },
        child: _buildRestUI(),
      );
    }

    // --- DA QUI IN POI CONTINUA IL TUO CODICE ORIGINALE ---
    // var suggest = _getSuggest(ex.name, setN);
    // ... rest of your code ...

    // Suggerimento basato sullo storico (se esiste)
    var suggest = _getSuggest(ex.name, setN);
    double lastW = (suggest['w'] as num?)?.toDouble() ?? 0.0;
    int lastR = (suggest['r'] as num?)?.toInt() ?? 0;

    // CALCOLO SICURO REPS (Correzione Errore Bad State)
    int targetR = ex.repsList.isNotEmpty
        ? (setN <= ex.repsList.length
              ? ex.repsList[setN - 1]
              : ex.repsList.last)
        : 10;
    // Il suggerimento si attiva SOLO se le reps dell'ultima volta sono MAGGIORI del target
    bool suggerisciAumento = lastR > targetR && lastR > 0;
    if (ex.repsList.isNotEmpty) {
      if (setN <= ex.repsList.length) {
        targetR = ex.repsList[setN - 1];
      } else {
        targetR = ex.repsList.last;
      }
    }

    bool isLastSet = (setN >= ex.targetSets);
    int timeToUse = isLastSet
        ? (ex.interExercisePause > 0 ? ex.interExercisePause : 120)
        : (ex.recoveryTime > 0 ? ex.recoveryTime : 90);
    final Color accent = Theme.of(context).colorScheme.primary;

    // CONTROLLO CRUCIALE: L'esercizio attuale è nella lista dei completati?
    bool giaFatto = eserciziCompletati.contains(ex.name);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        bool conferma = await _mostraDialogConfermaUscita();
        if (conferma) {
          _bgTimer?.cancel();
          timerActive = false;
          _bgCounter = 0;
          _endTime = null;
          await _clearTimerNotifications();
          if (mounted) Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // FRECCIA SINISTRA
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.white),
                onPressed: exI <= 0 ? null : () => _cambiaEsercizio(exI - 1),
              ),

              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      localizedExerciseName(ex.name).toUpperCase(),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                      ),
                    ),
                    // --- AGGIUNGIAMO IL PROGRESSO QUI SOTTO ---
                    const SizedBox(
                      height: 4,
                    ), // Un po' di spazio tra nome e progresso
                    Text(
                      "${AppL.setsDone}: ${currentExSeries.length} ${AppL.of} ${ex.targetSets}",
                      style: TextStyle(
                        color: currentExSeries.length >= ex.targetSets
                            ? const Color(0xFF00FF88) // Verde se hai finito
                            : Theme.of(context).colorScheme.primary.withAlpha(
                                180,
                              ), // Azzurrino mentre procedi
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.white),
                onPressed: exI >= widget.day.exercises.length - 1
                    ? null
                    : () => _cambiaEsercizio(exI + 1),
              ),
            ],
          ),
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () async {
              bool conferma = await _mostraDialogConfermaUscita();
              if (conferma) {
                _bgTimer?.cancel();
                timerActive = false;
                _bgCounter = 0;
                _endTime = null;
                await _clearTimerNotifications();
                if (mounted) Navigator.pop(context);
              }
            },
          ),
          actions: const [],
        ),
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _showWorkoutReadyScreen
              ? null
              : () => _triggerTimer(timeToUse, force: false),
          child: Column(
            children: [
              _showWorkoutReadyScreen
                  ? _buildWorkoutStartNativeAd()
                  : _buildWorkoutNativeAd(),
              // Compact badges row (only superset, record badge removed - shown as overlay at save time)
              if (ex.supersetGroup > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.link,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'SUPERSERIE ${ex.supersetGroup}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              if (_showWorkoutReadyScreen)
                Expanded(
                  child: _buildWorkoutReadyScreen(
                    ex,
                    lastW,
                    lastR,
                    suggerisciAumento,
                    accent,
                  ),
                )
              else ...[
                _buildInfoPanel(
                  ex,
                  lastW,
                  lastR,
                  suggerisciAumento,
                  accent,
                  timeToUse,
                ),
                if (giaFatto)
                  Expanded(child: Center(child: _buildBoxEsercizioCompletato()))
                else
                  Expanded(
                    child: _DrumPickers(
                      key: ValueKey('drum_$exI'),
                      initialKg: lastW <= 0 ? 20.0 : lastW,
                      initialReps: targetR,
                      suggerisciAumento:
                          suggerisciAumento && _showWeightSuggestion,
                      useQuarterStep: _usesQuarterStepForExercise(ex, lastW),
                      useEvenStep: _usesEvenStepForExercise(ex, lastW),
                      useSingleStep: _usesSingleStepForExercise(ex, lastW),
                      displayInPounds: _displayInPounds,
                      allowKeyboardInput: !_disableWeightKeyboard,
                      accent: accent,
                      onKgChanged: (v) {
                        wC.text = formatWeightValue(v, maxDecimals: 2);
                      },
                      onRepsChanged: (v) {
                        rC.text = v.toString();
                      },
                      onWeightModeChanged:
                          (useQuarterStep, useEvenStep, useSingleStep) {
                            _setExerciseWeightMode(
                              ex,
                              useQuarterStep: useQuarterStep,
                              useEvenStep: useEvenStep,
                              useSingleStep: useSingleStep,
                            );
                          },
                      onInteraction: () => _avviaTimerSeNonAttivo(timeToUse),
                    ),
                  ),
                if (!giaFatto)
                  Container(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      12,
                      24,
                      scala.max(
                            MediaQuery.of(context).padding.bottom,
                            MediaQuery.of(context).viewPadding.bottom,
                          ) +
                          16,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1C1C1E),
                      border: Border(
                        top: BorderSide(color: Colors.white12, width: 1),
                      ),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _confermaSerie,
                        child: Text(AppL.confirmSeries),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ), // closes GestureDetector (body)
      ), // closes Scaffold
    ); // chiude PopScope
  }

  void _setDrumValues(int targetExI, int targetSetN) {
    if (targetExI >= widget.day.exercises.length) return;
    final ex = widget.day.exercises[targetExI];
    final suggest = _getSuggest(ex.name, targetSetN);
    final double kg = (suggest['w'] as num?)?.toDouble() ?? 0.0;
    int tR = ex.repsList.isNotEmpty
        ? (targetSetN <= ex.repsList.length
              ? ex.repsList[targetSetN - 1]
              : ex.repsList.last)
        : 10;
    wC.text = formatWeightValue(kg, maxDecimals: 2);
    rC.text = tR.toString();
  }

  int? _nextPendingExerciseIndex({int fromExclusive = -1}) {
    for (int i = fromExclusive + 1; i < widget.day.exercises.length; i++) {
      if (!eserciziCompletati.contains(widget.day.exercises[i].name)) return i;
    }
    for (
      int i = 0;
      i <= fromExclusive && i < widget.day.exercises.length;
      i++
    ) {
      if (!eserciziCompletati.contains(widget.day.exercises[i].name)) return i;
    }
    return null;
  }

  Widget _buildInfoPanel(
    ExerciseConfig ex,
    double lastW,
    int lastR,
    bool suggerisciAumento,
    Color accent,
    int timeToUse,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (lastW > 0)
            Row(
              children: [
                const Icon(
                  Icons.history_rounded,
                  color: Colors.white38,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '${AppL.lastTime}: ${_formatWeightLabel(lastW)} × $lastR reps',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: const TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                ),
                if (suggerisciAumento && _showWeightSuggestion) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withAlpha(30),
                      border: Border.all(color: Colors.amber),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.trending_up_rounded,
                          color: Colors.amber,
                          size: 13,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          AppL.increase,
                          style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          if (ex.notePT.isNotEmpty) ...[
            if (lastW > 0) const Divider(color: Colors.white10, height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 3,
                  height: 14,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'COACH: ${ex.notePT}',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const Divider(color: Colors.white10, height: 10),
          TextField(
            style: const TextStyle(fontSize: 12, color: Colors.white54),
            decoration: InputDecoration(
              hintText: AppL.myNotes,
              hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
              prefixIcon: const Icon(
                Icons.edit_note,
                size: 16,
                color: Colors.white24,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            controller: _noteControllers.putIfAbsent(
              ex.name,
              () => TextEditingController(text: ex.noteCliente),
            ),
            onChanged: (v) {
              ex.noteCliente = v;
              _aggiornaJsonSuDisco();
              _avviaTimerSeNonAttivo(timeToUse > 0 ? timeToUse : 90);
            },
          ),
        ],
      ),
    );
  }

  void _showCatalogDetail(String exName, {String? gifFilename}) {
    if (exName.isEmpty) return;
    final accent = Theme.of(context).colorScheme.primary;
    // Se c'è una GIF assegnata, le info seguono la GIF (muscoli/esecuzione dalla GIF)
    // Solo se la GIF non ha info si fa fallback sul nome
    final info =
        (gifFilename != null ? findByGifSlug(gifFilename) : null) ??
        findAnyExercise(exName);
    final gifPath = gifFilename != null
        ? exerciseAnimationAssetPath(gifFilename)
        : info != null
        ? exerciseAnimationAssetPath(info.gifSlug)
        : null;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E0E10),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (c) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 3,
                  height: 22,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    (info != null
                            ? (AppL.lang == 'en' ? info.nameEn : info.name)
                            : localizedExerciseName(exName))
                        .toUpperCase(),
                    style: TextStyle(
                      color: accent,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
            if (info != null) ...[
              const SizedBox(height: 4),
              Text(
                AppL.lang == 'en' ? info.nameEn : info.name,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),
              // GIF esercizio
              if (gifPath != null)
                Image.asset(
                  gifPath,
                  width: 280,
                  height: 280,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.fitness_center,
                    size: 80,
                    color: Colors.white30,
                  ),
                ),
              const SizedBox(height: 16),
              if (info.muscleImages.isNotEmpty) ...[
                SizedBox(
                  height: 80,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: info.muscleImages.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        muscleAssetPath(info.muscleImages[i]),
                        width: 100,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(7),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.fitness_center_rounded, size: 16, color: accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppL.primaryMuscle,
                            style: TextStyle(
                              color: accent.withAlpha(180),
                              fontSize: 10,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            translateMuscle(info.primaryMuscle),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppL.execution,
                      style: TextStyle(
                        color: accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      translateExerciseText(info.execution),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                  color: Colors.amber.withAlpha(15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppL.tips,
                      style: TextStyle(
                        color: Colors.amber,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      translateExerciseText(info.tips),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ] else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  AppL.notInCatalogShort,
                  style: const TextStyle(color: Colors.white38, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRestUI() {
    var ex = widget.day.exercises[exI];
    var suggest = _getSuggest(ex.name, setN);
    double lastW = (suggest['w'] as num?)?.toDouble() ?? 0.0;
    int lastR = (suggest['r'] as num?)?.toInt() ?? 0;

    int targetR = ex.repsList.isNotEmpty
        ? (setN <= ex.repsList.length
              ? ex.repsList[setN - 1]
              : ex.repsList.last)
        : 10;
    bool suggerisciAumento = lastR > targetR && lastR > 0;

    // GIF del prossimo esercizio
    ExerciseConfig? prossimoConfig;
    if (_prossimoNome.isNotEmpty) {
      try {
        prossimoConfig = widget.day.exercises.firstWhere(
          (e) => e.name == _prossimoNome,
        );
      } catch (_) {}
    }
    final prossimoInfo = _prossimoNome.isNotEmpty
        ? ((prossimoConfig?.gifFilename != null
                  ? findByGifSlug(prossimoConfig!.gifFilename!)
                  : null) ??
              findAnyExercise(_prossimoNome))
        : null;
    final prossimoGifPath = prossimoConfig?.gifFilename != null
        ? exerciseAnimationAssetPath(prossimoConfig!.gifFilename!)
        : prossimoInfo != null
        ? exerciseAnimationAssetPath(prossimoInfo.gifSlug)
        : null;

    final accent = Theme.of(context).colorScheme.primary;
    final progress = timerActive
        ? (_bgCounter / _maxTime).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Text(
              'REST',
              style: TextStyle(
                color: Colors.white.withAlpha(80),
                fontSize: 12,
                letterSpacing: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),

            // ── METÀ SUPERIORE: ring adattivo ──────────────────────────
            Expanded(
              child: LayoutBuilder(
                builder: (ctx, constraints) {
                  // Il ring occupa l'85% dell'altezza disponibile (max 320)
                  final ringSize = (constraints.maxHeight * 0.85).clamp(
                    80.0,
                    320.0,
                  );
                  return Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: ringSize,
                          height: ringSize,
                          child: CustomPaint(
                            painter: _RestRingPainter(
                              progress: progress,
                              color: accent,
                            ),
                          ),
                        ),
                        Text(
                          '$_bgCounter',
                          style: TextStyle(
                            fontSize: ringSize * 0.38,
                            fontWeight: FontWeight.w100,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // ── METÀ INFERIORE: suggerimenti + skip ────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Card prossimo esercizio
                    GestureDetector(
                      onTap: _prossimoNome.isNotEmpty
                          ? () => _showCatalogDetail(
                              _prossimoNome,
                              gifFilename: prossimoConfig?.gifFilename,
                            )
                          : null,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(8),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _prossimoNome.isNotEmpty
                                ? accent.withAlpha(60)
                                : Colors.white10,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  AppL.nextInfo,
                                  style: TextStyle(
                                    color: Colors.white.withAlpha(70),
                                    fontSize: 15,
                                    letterSpacing: 4,
                                  ),
                                ),
                                if (_prossimoNome.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.play_circle_outline_rounded,
                                    color: accent.withAlpha(150),
                                    size: 16,
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            // GIF + info side by side
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                if (prossimoGifPath != null) ...[
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.asset(
                                      prossimoGifPath,
                                      height: 72,
                                      width: 72,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const SizedBox.shrink(),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                ],
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _infoProssimo,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 2,
                                        style: TextStyle(
                                          color: accent.withAlpha(210),
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (lastW > 0) ...[
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.history_rounded,
                                              color: Colors.white.withAlpha(70),
                                              size: 15,
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                '${AppL.lastTime} ${lastW}kg × ${lastR} reps',
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 2,
                                                style: TextStyle(
                                                  color: Colors.white.withAlpha(
                                                    160,
                                                  ),
                                                  fontSize: 14,
                                                  height: 1.4,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (suggerisciAumento) const _AumentaPesoWidget(),
                    _buildTimerRestNativeAd(),
                    // SKIP
                    GestureDetector(
                      onTap: _skipRest,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 60,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white.withAlpha(40)),
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: const Text(
                          'SKIP',
                          style: TextStyle(
                            letterSpacing: 3,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Suggerisce peso/reps dalla sessione PRECEDENTE (snapshot in _previousResults)
  Map<String, dynamic> _getSuggest(String ex, int s) {
    try {
      final prevSeries = _previousResults[ex];
      if (prevSeries == null || prevSeries.isEmpty) {
        final carry = widget.carryoverWeights[ex];
        if (carry != null) return carry;
        return {'w': 0.0, 'r': 0};
      }
      final setData = s <= prevSeries.length
          ? prevSeries[s - 1]
          : prevSeries.last;
      final double weight = (setData['w'] ?? setData['weight'] ?? 0.0)
          .toDouble();
      final int reps = (setData['r'] ?? setData['reps'] ?? 0).toInt();
      return {'w': weight, 'r': reps};
    } catch (e) {
      debugPrint("Errore suggerimenti: $e");
      return {'w': 0.0, 'r': 0};
    }
  }
}

// --- BADGE ANIMATO AUMENTA IL PESO ---
class _AumentaPesoWidget extends StatefulWidget {
  const _AumentaPesoWidget();

  @override
  State<_AumentaPesoWidget> createState() => _AumentaPesoWidgetState();
}

class _AumentaPesoWidgetState extends State<_AumentaPesoWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _glow;
  int _flashes = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _scale = Tween(
      begin: 1.0,
      end: 1.07,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _glow = Tween(
      begin: 0.0,
      end: 22.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

    _ctrl.addStatusListener((status) {
      if (!mounted) return;
      if (status == AnimationStatus.completed) {
        _ctrl.reverse();
      } else if (status == AnimationStatus.dismissed) {
        _flashes++;
        if (_flashes < 3) _ctrl.forward();
        // dopo 3 lampeggi rimane a valore 0 = aspetto normale
      }
    });
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Transform.scale(
        scale: _scale.value,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.amber.shade700,
                Colors.deepOrange.shade600,
                Colors.red.shade700,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: _glow.value > 0
                ? [
                    BoxShadow(
                      color: Colors.amber.withAlpha(180),
                      blurRadius: _glow.value,
                      spreadRadius: _glow.value / 5,
                    ),
                    BoxShadow(
                      color: Colors.red.withAlpha(100),
                      blurRadius: _glow.value * 1.6,
                      spreadRadius: _glow.value / 4,
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🔥', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Text(
                AppL.increaseWeight,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(width: 10),
              const Text('🔥', style: TextStyle(fontSize: 20)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordOverlay extends StatefulWidget {
  final String lang;
  final VoidCallback onDone;
  const _RecordOverlay({required this.lang, required this.onDone});
  @override
  State<_RecordOverlay> createState() => _RecordOverlayState();
}

class _RecordOverlayState extends State<_RecordOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _cardCtrl;
  late final AnimationController _sparkCtrl;
  late final Animation<double> _cardScale;
  late final Animation<double> _sparkAnim;

  static const List<String> _sparks = [
    '🎆',
    '✨',
    '🔥',
    '⭐',
    '💥',
    '🎇',
    '🏆',
    '💫',
  ];
  static const List<Offset> _dirs = [
    Offset(-1.0, -1.2),
    Offset(0.0, -1.5),
    Offset(1.0, -1.2),
    Offset(-1.3, 0.0),
    Offset(1.3, 0.0),
    Offset(-0.8, 1.2),
    Offset(0.0, 1.5),
    Offset(0.8, 1.2),
  ];

  @override
  void initState() {
    super.initState();
    _cardCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _sparkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _cardScale = CurvedAnimation(parent: _cardCtrl, curve: Curves.elasticOut);
    _sparkAnim = CurvedAnimation(parent: _sparkCtrl, curve: Curves.easeOut);
    _cardCtrl.forward();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _sparkCtrl.forward();
    });
  }

  @override
  void dispose() {
    _cardCtrl.dispose();
    _sparkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final cx = size.width / 2;
    final cy = size.height * 0.4;
    return Stack(
      children: [
        ...List.generate(_sparks.length, (i) {
          final dir = _dirs[i % _dirs.length];
          return AnimatedBuilder(
            animation: _sparkAnim,
            builder: (_, __) {
              final t = _sparkAnim.value;
              final dx = dir.dx * 120 * t;
              final dy = dir.dy * 120 * t;
              final opacity = (1.0 - t).clamp(0.0, 1.0);
              return Positioned(
                left: cx + dx - 16,
                top: cy + dy - 16,
                child: Opacity(
                  opacity: opacity,
                  child: Text(_sparks[i], style: const TextStyle(fontSize: 24)),
                ),
              );
            },
          );
        }),
        Positioned(
          top: cy - 90,
          left: 24,
          right: 24,
          child: Material(
            color: Colors.transparent,
            child: ScaleTransition(
              scale: _cardScale,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withAlpha(120),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🏆', style: TextStyle(fontSize: 52)),
                    const SizedBox(height: 8),
                    Text(
                      widget.lang == 'en'
                          ? 'NEW PERSONAL RECORD!'
                          : 'NUOVO RECORD PERSONALE!',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.lang == 'en'
                          ? '🚀 Keep pushing! 💪'
                          : '🚀 Continua così! 💪',
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// --- RING PAINTER TIMER ---
class _RestRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  const _RestRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 14;
    const strokeW = 12.0;
    const startAngle = -scala.pi / 2;

    // Traccia di sfondo
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white.withAlpha(20)
        ..strokeWidth = strokeW
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    if (progress <= 0) return;

    // Glow (arco allargato e sfocato)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      2 * scala.pi * progress,
      false,
      Paint()
        ..color = color.withAlpha(60)
        ..strokeWidth = strokeW + 10
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // Arco principale
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      2 * scala.pi * progress,
      false,
      Paint()
        ..color = color
        ..strokeWidth = strokeW
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RestRingPainter old) =>
      old.progress != progress || old.color != color;
}

// ─── SHARE WORKOUT IMAGE SHEET ────────────────────────────────────────────────
class _WorkoutShareSheet extends StatefulWidget {
  final String dayName;
  final String todayLabel;
  final List<Map<String, dynamic>> exercises;
  final int streak;
  final Color accent;
  final Set<String> streakDoneNames;
  final double? progressPercent;
  final List<String> allSessionNames;
  const _WorkoutShareSheet({
    required this.dayName,
    required this.todayLabel,
    required this.exercises,
    required this.streak,
    required this.accent,
    this.streakDoneNames = const {},
    this.progressPercent,
    this.allSessionNames = const [],
  });
  @override
  State<_WorkoutShareSheet> createState() => _WorkoutShareSheetState();
}

class _WorkoutShareSheetState extends State<_WorkoutShareSheet> {
  bool _showStreak = true;
  bool _showWeeklyBadges = false;
  bool _showSessionProgress = false;
  bool _showExercises = true;
  bool _sharing = false;
  final GlobalKey _cardKey = GlobalKey();

  double _computeMaxWeight() {
    double max = 0;
    for (final ex in widget.exercises) {
      for (final s in (ex['series'] as List)) {
        final w = (s['w'] ?? 0.0).toDouble();
        if (w > max) max = w;
      }
    }
    return max;
  }

  Widget _buildCard(Color accent) {
    return Container(
      width: 360,
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withAlpha(80)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/icon_client.png',
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Text('💪', style: TextStyle(fontSize: 28)),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GymApp',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    '${widget.dayName} · ${widget.todayLabel}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_showExercises) ...[
            const Divider(color: Colors.white12),
            const SizedBox(height: 8),
            ...widget.exercises.map((ex) {
              final name = ex['exercise'] as String;
              final series = ex['series'] as List;
              double maxW = 0;
              int maxR = 0;
              for (final s in series) {
                final w = (s['w'] ?? 0.0).toDouble();
                final r = (s['r'] ?? 0) as int;
                if (w > maxW) { maxW = w; maxR = r; }
              }
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${maxW.toStringAsFixed(maxW % 1 == 0 ? 0 : 1)} kg × $maxR rep',
                      style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
          ],
          if (_showStreak || _showWeeklyBadges || _showSessionProgress) ...[
            const Divider(color: Colors.white12),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (_showStreak)
                  _badgeChip(
                    icon: '🔥',
                    label: 'Streak',
                    value: '${widget.streak} ${AppL.lang == 'en' ? 'micro' : 'micro.'}',
                    accent: Colors.orange,
                  ),
                if (_showSessionProgress && widget.progressPercent != null)
                  _badgeChip(
                    icon: widget.progressPercent! >= 0 ? '📈' : '📉',
                    label: AppL.lang == 'en' ? 'vs prev.' : 'vs prec.',
                    value: '${widget.progressPercent! >= 0 ? '+' : ''}${widget.progressPercent!.toStringAsFixed(0)}%',
                    accent: widget.progressPercent! >= 0 ? Colors.greenAccent : Colors.redAccent,
                  ),
              ],
            ),
            if (_showWeeklyBadges) ...[
              const SizedBox(height: 8),
              Builder(builder: (ctx) {
                final names = widget.allSessionNames.isNotEmpty
                    ? widget.allSessionNames
                    : widget.streakDoneNames.toList();
                final doneCount = widget.streakDoneNames.length;
                final total = names.length;
                return SizedBox(
                  width: double.infinity,
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      runAlignment: WrapAlignment.center,
                      children: names.map((name) {
                        final done = widget.streakDoneNames.contains(name);
                        return Container(
                          width: 60,
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            gradient: done ? const LinearGradient(
                              colors: [Color(0xFFFF6B00), Color(0xFFFFAB00)],
                              begin: Alignment.topLeft, end: Alignment.bottomRight,
                            ) : null,
                            color: done ? null : Colors.white10,
                            border: Border.all(color: done ? Colors.orange : Colors.white12),
                            boxShadow: done ? [BoxShadow(color: Colors.orange.withAlpha(60), blurRadius: 6)] : null,
                          ),
                          child: Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: ColorFiltered(
                                  colorFilter: done
                                      ? const ColorFilter.mode(Colors.transparent, BlendMode.multiply)
                                      : const ColorFilter.matrix([
                                          0.2126, 0.7152, 0.0722, 0, 0,
                                          0.2126, 0.7152, 0.0722, 0, 0,
                                          0.2126, 0.7152, 0.0722, 0, 0,
                                          0,      0,      0,      1, 0,
                                        ]),
                                  child: Image.asset('assets/icon_client.png', width: 28, height: 28,
                                      errorBuilder: (_, __, ___) => Icon(Icons.fitness_center, color: done ? Colors.white : Colors.white24, size: 24)),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                name,
                                style: TextStyle(fontSize: 7, color: done ? Colors.white : Colors.white38, fontWeight: FontWeight.w700),
                                textAlign: TextAlign.center, overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$doneCount/$total questo microciclo',
                      style: const TextStyle(color: Colors.white54, fontSize: 9),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  ),
                );
              }),
            ],
            const SizedBox(height: 4),
          ],
          const SizedBox(height: 6),
          Center(
            child: Text(
              '',
              style: TextStyle(color: accent.withAlpha(120), fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badgeChip({
    required String icon,
    required String label,
    required String value,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withAlpha(80)),
      ),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          Text(value, style: TextStyle(color: accent, fontWeight: FontWeight.w800, fontSize: 14)),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
        ],
      ),
    );
  }

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final boundary = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 4.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/gymapp_workout.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: '',
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          Text(
            AppL.lang == 'en' ? 'Share workout' : 'Condividi allenamento',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 14),
          RepaintBoundary(key: _cardKey, child: _buildCard(accent)),
          const SizedBox(height: 16),
          // Badge toggles
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _toggleChip(
                AppL.lang == 'en' ? 'Exercises' : 'Esercizi',
                _showExercises,
                () => setState(() => _showExercises = !_showExercises),
                accent,
              ),
              _toggleChip(
                'Streak 🔥',
                _showStreak,
                () => setState(() => _showStreak = !_showStreak),
                Colors.orange,
              ),
              _toggleChip(
                AppL.lang == 'en' ? 'Microcycle badges' : 'Badge microciclo',
                _showWeeklyBadges,
                () => setState(() => _showWeeklyBadges = !_showWeeklyBadges),
                Colors.amber,
              ),
              if (widget.progressPercent != null)
                _toggleChip(
                  AppL.lang == 'en' ? 'vs previous' : 'vs prec.',
                  _showSessionProgress,
                  () => setState(() => _showSessionProgress = !_showSessionProgress),
                  Colors.greenAccent,
                ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _sharing ? null : _share,
              icon: _sharing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.share_rounded),
              label: Text(AppL.lang == 'en' ? 'Share image' : 'Condividi immagine'),
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggleChip(String label, bool active, VoidCallback onTap, Color c) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? c.withAlpha(40) : Colors.white12,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? c : Colors.white24),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? c : Colors.white54,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// --- STREAK SHARE SHEET (Stories format) ---
class _StreakShareSheet extends StatefulWidget {
  final int streak;
  final Set<String> streakDoneNames;
  final List<String> allSessionNames;
  final Color accent;
  const _StreakShareSheet({
    required this.streak,
    required this.streakDoneNames,
    required this.allSessionNames,
    required this.accent,
  });
  @override
  State<_StreakShareSheet> createState() => _StreakShareSheetState();
}

class _StreakShareSheetState extends State<_StreakShareSheet> {
  bool _sharing = false;
  bool _showBadges = true;
  bool _showSessionCount = true;
  final GlobalKey _cardKey = GlobalKey();

  // Day-of-week badges: Mon-Sun, highlight those with a completed session
  static const _dayEmojis = ['☀️', '🔥', '💪', '⚡', '🏃', '🎯', '🌟'];

  Widget _buildStoryCard() {
    final doneCount = widget.streakDoneNames.intersection(widget.allSessionNames.toSet()).length;
    final total = widget.allSessionNames.length;

    return Container(
      width: 340,
      height: 600,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A0A0C), Color(0xFF1A0D00), Color(0xFF0A0A0C)],
          stops: [0.0, 0.5, 1.0],
        ),
        border: Border.all(color: Colors.orange.withAlpha(60)),
      ),
      child: Stack(
        children: [
          // Glowing fire effect at top
          Positioned(
            top: -40,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Colors.orange.withAlpha(60), Colors.transparent],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Header with icon + name
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        'assets/icon_client.png',
                        width: 72,
                        height: 72,
                        errorBuilder: (_, __, ___) => const Text('💪', style: TextStyle(fontSize: 20)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'GymApp',
                      style: TextStyle(
                        color: widget.accent,
                        fontWeight: FontWeight.w900,
                        fontSize: 32,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                // Giant flame + streak
                const Text('🔥', style: TextStyle(fontSize: 72)),
                const SizedBox(height: 8),
                Text(
                  '${widget.streak}',
                  style: const TextStyle(
                    color: Colors.orange,
                    fontSize: 96,
                    fontWeight: FontWeight.w900,
                    height: 0.9,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppL.lang == 'en'
                      ? '${widget.streak == 1 ? 'microcycle' : 'microcycles'} on fire! 🔥'
                      : '${widget.streak == 1 ? 'micro' : 'micro'} di fila! 🔥',
                  style: const TextStyle(
                    color: Colors.orange,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 32),
                // Weekly badges: session circles
                if (_showBadges && widget.allSessionNames.isNotEmpty) ...[
                  Text(
                    AppL.lang == 'en' ? 'This microcycle' : 'Questo microciclo',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: List.generate(widget.allSessionNames.length, (i) {
                      final name = widget.allSessionNames[i];
                      final done = widget.streakDoneNames.contains(name);
                      return Container(
                        width: 72,
                        height: 84,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: done
                              ? const LinearGradient(
                                  colors: [Color(0xFFFF6B00), Color(0xFFFFAB00)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          color: done ? null : Colors.white10,
                          border: Border.all(
                            color: done ? Colors.orange : Colors.white12,
                          ),
                          boxShadow: done
                              ? [BoxShadow(color: Colors.orange.withAlpha(80), blurRadius: 8)]
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: done
                                  ? Image.asset('assets/icon_client.png', width: 36, height: 36,
                                      errorBuilder: (_, __, ___) => const Icon(Icons.fitness_center, color: Colors.white, size: 32))
                                  : ColorFiltered(
                                      colorFilter: const ColorFilter.matrix([
                                        0.2126, 0.7152, 0.0722, 0, 0,
                                        0.2126, 0.7152, 0.0722, 0, 0,
                                        0.2126, 0.7152, 0.0722, 0, 0,
                                        0,      0,      0,      0.3, 0,
                                      ]),
                                      child: Image.asset('assets/icon_client.png', width: 36, height: 36,
                                          errorBuilder: (_, __, ___) => const Icon(Icons.fitness_center, color: Colors.white24, size: 32)),
                                    ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              name,
                              style: TextStyle(
                                fontSize: 9,
                                color: done ? Colors.white : Colors.white24,
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                  if (_showSessionCount) ...[
                    const SizedBox(height: 12),
                    Text(
                      '$doneCount / $total ${AppL.lang == 'en' ? 'sessions done' : 'sessioni completate'}',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ],
                const Spacer(),
                // Bottom hashtags
                Text(
                  '',
                  style: TextStyle(color: widget.accent.withAlpha(100), fontSize: 10),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final boundary = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 4.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/gymapp_streak.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: AppL.lang == 'en'
            ? '🔥 ${widget.streak} microcycle${widget.streak == 1 ? '' : 's'} streak!'
            : '🔥 ${widget.streak} ${widget.streak == 1 ? 'micro' : 'micro'} di fila!',
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          Text(
            AppL.lang == 'en' ? 'Share Streak 🔥' : 'Condividi Streak 🔥',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 8),
          // Composer toggles
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _toggleChip(
                label: AppL.lang == 'en' ? '🏅 Badges' : '🏅 Badge',
                active: _showBadges,
                onTap: () => setState(() => _showBadges = !_showBadges),
              ),
              const SizedBox(width: 8),
              _toggleChip(
                label: AppL.lang == 'en' ? '📊 Sessions' : '📊 Sessioni',
                active: _showSessionCount,
                onTap: () => setState(() => _showSessionCount = !_showSessionCount),
              ),
            ],
          ),
          const SizedBox(height: 14),
          RepaintBoundary(key: _cardKey, child: _buildStoryCard()),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _sharing ? null : _share,
              icon: _sharing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Text('🔥', style: TextStyle(fontSize: 16)),
              label: Text(AppL.lang == 'en' ? 'Share to Stories' : 'Condividi nelle Storie'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggleChip({required String label, required bool active, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? Colors.orange.withAlpha(40) : Colors.white10,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? Colors.orange : Colors.white24),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: active ? Colors.orange : Colors.white54,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// --- PROGRESS SHARE SHEET ---
class _ProgressShareSheet extends StatefulWidget {
  final GlobalKey chartKey;
  final int streak;
  final List<_SessionPoint> points;
  final Color accent;
  const _ProgressShareSheet({
    required this.chartKey,
    required this.streak,
    required this.points,
    required this.accent,
  });
  @override
  State<_ProgressShareSheet> createState() => _ProgressShareSheetState();
}

class _ProgressShareSheetState extends State<_ProgressShareSheet> {
  bool _sharing = false;
  bool _includeStreak = true;
  bool _includeSessionCount = true;
  bool _includeTrend = true;

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final boundary = widget.chartKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      // Capture the chart at high resolution
      final chartImage = await boundary.toImage(pixelRatio: 6.0);
      final chartBytes = await chartImage.toByteData(format: ui.ImageByteFormat.png);
      if (chartBytes == null) return;

      // Build composed image using PictureRecorder (2x scale for higher quality)
      const double s = 2.0;
      const double w = 1080 * s;
      const double hPad = 20.0 * s; // horizontal padding
      final double chartW = w - 2 * hPad; // chart fills content width
      const double cardSize = 220.0 * s;
      final double badgesH = (_includeStreak || _includeSessionCount || _includeTrend) ? (cardSize + 40.0 * s) : 0.0;
      const double headerH = 260.0 * s; // reduced from 300

      // Calculate chart height based on actual chart image dimensions
      final chartAspect = chartImage.width / chartImage.height;
      const double gap = 16.0 * s;
      final double chartH = chartW / chartAspect; // Height proportional to width
      final double totalH = headerH + chartH + badgesH + 40 * s;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Rounded corners clip
      canvas.clipRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, totalH), const Radius.circular(32 * s)));

      // Background
      final bgPaint = Paint()..color = const Color(0xFF0E0E10);
      canvas.drawRect(Rect.fromLTWH(0, 0, w, totalH), bgPaint);

      // Colored border for 3D effect
      final borderPaint = Paint()
        ..color = widget.accent.withAlpha(120)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * s;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, totalH), Radius.circular(32 * s)),
        borderPaint,
      );

      // Header: icon + "GymApp"
      final codec = await ui.instantiateImageCodec(
        (await rootBundle.load('assets/icon_client.png')).buffer.asUint8List(),
        targetWidth: (180 * s).round(),
        targetHeight: (180 * s).round(),
      );
      final frame = await codec.getNextFrame();
      const double iconSz = 180.0 * s;
      final iconX = (w - iconSz) / 2;
      canvas.drawImageRect(
        frame.image,
        Rect.fromLTWH(0, 0, frame.image.width.toDouble(), frame.image.height.toDouble()),
        Rect.fromLTWH(iconX, 16 * s, iconSz, iconSz),
        Paint(),
      );

      // Border around icon with rounded corners
      final iconBorderPaint = Paint()
        ..color = widget.accent.withAlpha(150)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 * s;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(iconX, 16 * s, iconSz, iconSz), Radius.circular(16 * s)),
        iconBorderPaint,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: 'GymApp',
          style: TextStyle(
            color: widget.accent,
            fontSize: 48 * s,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((w - tp.width) / 2, (16 + 180 + 12) * s));

      // Chart background (dark box behind the transparent chart)
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(hPad, headerH, chartW, chartH), const Radius.circular(16 * s)),
        Paint()..color = const Color(0xFF1C1C1E),
      );

      // Draw chart below header, filling content width
      final chartUi = await ui.instantiateImageCodec(chartBytes.buffer.asUint8List());
      final chartFrame = await chartUi.getNextFrame();
      final double innerPad = 12.0 * s;
      final dst = Rect.fromLTWH(hPad + innerPad, headerH + innerPad, chartW - 2 * innerPad, chartH - 2 * innerPad);
      canvas.drawImageRect(
        chartFrame.image,
        Rect.fromLTWH(0, 0, chartImage.width.toDouble(), chartImage.height.toDouble()),
        dst,
        Paint(),
      );

      // Stat cards row
      if (_includeStreak || _includeSessionCount || _includeTrend) {
        final double bY = headerH + chartH + 16 * s;
        final trendPct = widget.points.length >= 2 && widget.points.first.score > 0
            ? ((widget.points.last.score - widget.points.first.score) / widget.points.first.score * 100)
            : 0.0;
        final trendUp = trendPct >= 0;
        final isMicrocycle = widget.points.isNotEmpty && widget.points.first.dayName.startsWith('Microciclo');

        final activeCards = <(Color, String, String, String)>[];
        if (_includeSessionCount) activeCards.add((const Color(0xFF00BCD4), '📅', '${widget.points.length}', isMicrocycle ? (AppL.lang == 'en' ? 'Microcycles' : 'Microcicli') : (AppL.lang == 'en' ? 'Sessions' : 'Sessioni')));
        if (_includeStreak) activeCards.add((const Color(0xFFFF6B00), '🔥', '${widget.streak}', 'Streak'));
        if (_includeTrend) activeCards.add((trendUp ? Colors.greenAccent : Colors.redAccent, trendUp ? '📈' : '📉', '${trendUp ? '+' : ''}${trendPct.toStringAsFixed(0)}%', 'Trend'));

        if (activeCards.isNotEmpty) {
          final double totalCardsW = activeCards.length * cardSize + (activeCards.length + 1) * gap;
          final double firstCardX = (w - totalCardsW) / 2 + gap;

          void drawStatCard(Canvas canvas, double cx, Color cardColor, String emoji, String val, String lbl) {
            final rect = RRect.fromRectAndRadius(
              Rect.fromLTWH(cx, bY, cardSize, cardSize),
              Radius.circular(24 * s),
            );
            canvas.drawRRect(rect, Paint()..color = cardColor.withAlpha(25));
            canvas.drawRRect(rect, Paint()..color = cardColor.withAlpha(130)..style = PaintingStyle.stroke..strokeWidth = 2 * s);
            // Glow effect
            canvas.drawRRect(rect, Paint()..color = Colors.white.withAlpha(15)..style = PaintingStyle.stroke..strokeWidth = 1 * s);
            final emojiTp = TextPainter(
              text: TextSpan(text: emoji, style: TextStyle(fontSize: 44 * s)),
              textDirection: TextDirection.ltr,
            )..layout();
            emojiTp.paint(canvas, Offset(cx + (cardSize - emojiTp.width) / 2, bY + cardSize * 0.10));
            final valTp = TextPainter(
              text: TextSpan(text: val, style: TextStyle(color: cardColor, fontSize: 48 * s, fontWeight: FontWeight.w900)),
              textDirection: TextDirection.ltr,
            )..layout(maxWidth: cardSize - 8 * s);
            valTp.paint(canvas, Offset(cx + (cardSize - valTp.width) / 2, bY + cardSize * 0.42));
            final lblTp = TextPainter(
              text: TextSpan(text: lbl, style: TextStyle(color: Colors.white54, fontSize: 20 * s)),
              textDirection: TextDirection.ltr,
            )..layout(maxWidth: cardSize - 8 * s);
            lblTp.paint(canvas, Offset(cx + (cardSize - lblTp.width) / 2, bY + cardSize * 0.74));
          }

          for (int ci = 0; ci < activeCards.length; ci++) {
            final cx = firstCardX + ci * (cardSize + gap);
            drawStatCard(canvas, cx, activeCards[ci].$1, activeCards[ci].$2, activeCards[ci].$3, activeCards[ci].$4);
          }
        }
      }

      final picture = recorder.endRecording();
      final finalImage = await picture.toImage(w.toInt(), totalH.toInt());
      final finalBytes = await finalImage.toByteData(format: ui.ImageByteFormat.png);
      if (finalBytes == null) return;

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/gymapp_progress.png');
      await file.writeAsBytes(finalBytes.buffer.asUint8List());
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: AppL.lang == 'en'
            ? '💪 My GymApp progress!'
            : '💪 I miei progressi su GymApp!',
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  void _drawBadge(Canvas canvas, String text, Color color, double y, double x, double maxW) {
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, maxW - x * 2, 40),
      const Radius.circular(10),
    );
    canvas.drawRRect(bgRect, Paint()..color = color.withAlpha(40));
    canvas.drawRRect(bgRect, Paint()..color = color.withAlpha(80)..style = PaintingStyle.stroke..strokeWidth = 1);
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w700)),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxW - x * 2 - 20);
    tp.paint(canvas, Offset(x + 10, y + 12));
  }

  Widget _toggleChip({required String label, required bool active, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? widget.accent.withAlpha(40) : Colors.white10,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? widget.accent : Colors.white24),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: active ? widget.accent : Colors.white54,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          Text(
            AppL.lang == 'en' ? 'Share Progress 📊' : 'Condividi Progressi 📊',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Text(
            AppL.lang == 'en' ? 'Choose what to include:' : 'Scegli cosa includere:',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _toggleChip(
                label: '🔥 Streak',
                active: _includeStreak,
                onTap: () => setState(() => _includeStreak = !_includeStreak),
              ),
              _toggleChip(
                label: '🏋 ${AppL.lang == 'en' ? 'Sessions' : 'Sessioni'}',
                active: _includeSessionCount,
                onTap: () => setState(() => _includeSessionCount = !_includeSessionCount),
              ),
              _toggleChip(
                label: '📈 Trend',
                active: _includeTrend,
                onTap: () => setState(() => _includeTrend = !_includeTrend),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _sharing ? null : _share,
              icon: _sharing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.share_rounded),
              label: Text(AppL.lang == 'en' ? 'Share Progress' : 'Condividi Progressi'),
              style: FilledButton.styleFrom(
                backgroundColor: widget.accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- DRUM PICKERS ---
class _DrumPickers extends StatefulWidget {
  final double initialKg;
  final int initialReps;
  final bool suggerisciAumento;
  final bool useQuarterStep;
  final bool useEvenStep;
  final bool useSingleStep;
  final bool displayInPounds;
  final bool allowKeyboardInput;
  final Color accent;
  final ValueChanged<double> onKgChanged;
  final ValueChanged<int> onRepsChanged;
  final void Function(
    bool useQuarterStep,
    bool useEvenStep,
    bool useSingleStep,
  )?
  onWeightModeChanged;
  final VoidCallback onInteraction; // chiamato ad ogni scroll

  const _DrumPickers({
    super.key,
    required this.initialKg,
    required this.initialReps,
    required this.suggerisciAumento,
    this.useQuarterStep = false,
    this.useEvenStep = false,
    this.useSingleStep = false,
    this.displayInPounds = false,
    this.allowKeyboardInput = true,
    required this.accent,
    required this.onKgChanged,
    required this.onRepsChanged,
    this.onWeightModeChanged,
    required this.onInteraction,
  });

  @override
  State<_DrumPickers> createState() => _DrumPickersState();
}

class _DrumPickersState extends State<_DrumPickers>
    with SingleTickerProviderStateMixin {
  static final List<double> _kgValues = [
    ...List.generate(41, (i) => i * 2.5),
    ...List.generate(80, (i) => 105.0 + i * 5.0),
  ];
  static final List<double> _kgQuarterValues = [
    ...List.generate(81, (i) => i * 1.25),
    ...List.generate(80, (i) => 102.5 + i * 2.5),
  ];
  static final List<double> _kgEvenValues = List.generate(151, (i) => i * 2.0);
  static final List<double> _kgSingleValues = List.generate(
    301,
    (i) => i * 1.0,
  );
  static final List<double> _lbValues = [
    ...List.generate(61, (i) => i * 5.0),
    ...List.generate(70, (i) => 310.0 + i * 10.0),
  ];
  static final List<double> _lbQuarterValues = [
    ...List.generate(121, (i) => i * 2.5),
    ...List.generate(140, (i) => 302.5 + i * 5.0),
  ];
  static final List<double> _lbSingleValues = List.generate(
    661,
    (i) => i * 1.0,
  );
  static final List<double> _kgMergedValues = (() {
    final values = <double>{
      ..._kgValues,
      ..._kgQuarterValues,
      ..._kgEvenValues,
      ..._kgSingleValues,
    }.toList()..sort();
    return values;
  })();
  static final List<double> _lbMergedValues = (() {
    final values = <double>{
      ..._lbValues,
      ..._lbQuarterValues,
      ..._lbSingleValues,
    }.toList()..sort();
    return values;
  })();
  static final List<int> _repsValues = List.generate(50, (i) => i + 1);

  List<double> get _weightValues => widget.displayInPounds
      ? (!widget.allowKeyboardInput
            ? _lbMergedValues
            : (_manualUseSingleStep || widget.useSingleStep)
            ? _lbSingleValues
            : (_manualUseQuarterStep || widget.useQuarterStep)
            ? _lbQuarterValues
            : _lbValues)
      : (!widget.allowKeyboardInput
            ? _kgMergedValues
            : (_manualUseQuarterStep || widget.useQuarterStep)
            ? _kgQuarterValues
            : (_manualUseEvenStep || widget.useEvenStep)
            ? _kgEvenValues
            : (_manualUseSingleStep || widget.useSingleStep)
            ? _kgSingleValues
            : _kgValues);

  static int _nearestIndex(List<double> values, double target) {
    int best = 0;
    double bestDiff = double.infinity;
    for (int i = 0; i < values.length; i++) {
      final diff = (values[i] - target).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        best = i;
      }
    }
    return best;
  }

  late FixedExtentScrollController _kgCtrl;
  late FixedExtentScrollController _repsCtrl;
  late int _selKg;
  late int _selReps;
  double? _customKgValue;
  bool _manualUseQuarterStep = false;
  bool _manualUseEvenStep = false;
  bool _manualUseSingleStep = false;
  bool _interacted = false;

  // Animazione freccia suggerimento aumento peso
  late AnimationController _arrowCtrl;
  late Animation<double> _arrowAnim;

  @override
  void initState() {
    super.initState();
    _manualUseQuarterStep = widget.useQuarterStep;
    _manualUseEvenStep = widget.useEvenStep;
    _manualUseSingleStep = widget.useSingleStep;
    _selKg = _displayIndexFromKg(widget.initialKg);
    _selReps = (widget.initialReps - 1).clamp(0, 49);
    _kgCtrl = FixedExtentScrollController(initialItem: _selKg);
    _repsCtrl = FixedExtentScrollController(initialItem: _selReps);

    _arrowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _arrowAnim = Tween<double>(
      begin: 0,
      end: -10,
    ).animate(CurvedAnimation(parent: _arrowCtrl, curve: Curves.easeInOut));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _interacted) return;
      widget.onKgChanged(_selectedKgValue());
      widget.onRepsChanged(_repsValues[_selReps]);
    });
  }

  @override
  void didUpdateWidget(_DrumPickers oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When the parent updates the wheel mode (e.g. after onWeightModeChanged),
    // re-sync _manual flags and jump the controller to the correct position.
    if (oldWidget.useQuarterStep != widget.useQuarterStep ||
        oldWidget.useEvenStep != widget.useEvenStep ||
        oldWidget.useSingleStep != widget.useSingleStep) {
      _manualUseQuarterStep = widget.useQuarterStep;
      _manualUseEvenStep = widget.useEvenStep;
      _manualUseSingleStep = widget.useSingleStep;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final kg = _customKgValue ?? _displayValueToKg(_weightValues[_selKg.clamp(0, _weightValues.length - 1)]);
        final newIdx = _nearestIndex(_weightValues, widget.displayInPounds ? kgToLb(kg) : kg);
        setState(() => _selKg = newIdx);
        _kgCtrl.jumpToItem(newIdx);
      });
    }
  }

  @override
  void dispose() {
    _arrowCtrl.dispose();
    _kgCtrl.dispose();
    _repsCtrl.dispose();
    super.dispose();
  }

  void _triggerInteraction() {
    _interacted = true;
    widget.onInteraction();
  }

  double _displayValueToKg(double value) =>
      widget.displayInPounds ? lbToKg(value) : value;

  int _displayIndexFromKg(double kg) {
    final target = widget.displayInPounds ? kgToLb(kg) : kg;
    return _nearestIndex(_weightValues, target);
  }

  double _selectedKgValue() =>
      _customKgValue ?? _displayValueToKg(_weightValues[_selKg]);

  double _selectedDisplayedWeight() =>
      widget.displayInPounds ? kgToLb(_selectedKgValue()) : _selectedKgValue();

  String _formatDisplayedWeight(double value) {
    final fixed = value.toStringAsFixed(value % 1 == 0 ? 0 : 2);
    return fixed.contains('.')
        ? fixed.replaceFirst(RegExp(r'\.?0+$'), '')
        : fixed;
  }

  void _editValue({required bool isKg}) {
    if (!widget.allowKeyboardInput) return;
    final textCtrl = TextEditingController(
      text: isKg
          ? _formatDisplayedWeight(_selectedDisplayedWeight())
          : _repsValues[_selReps].toString(),
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1E),
        title: Text(
          isKg ? AppL.insertKg : AppL.insertReps,
          style: const TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: textCtrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: Colors.white, fontSize: 28),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white24),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: widget.accent),
            ),
          ),
          onSubmitted: (_) {
            Navigator.pop(ctx);
            _applyTextInput(textCtrl.text, isKg: isKg);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              AppL.cancel,
              style: const TextStyle(color: Colors.white38),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _applyTextInput(textCtrl.text, isKg: isKg);
            },
            child: const Text(
              'OK',
              style: TextStyle(
                color: Colors.amber,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _applyTextInput(String raw, {required bool isKg}) {
    if (isKg) {
      final v = double.tryParse(raw.replaceAll(',', '.'));
      if (v == null) return;
      final kg = widget.displayInPounds ? lbToKg(v) : v;
      final normalizedKg = kg.clamp(0.0, lbToKg(_lbValues.last));
      final useQuarterStep = widget.displayInPounds
          ? (((v.abs() * 100).round()) % 500 == 250)
          : usesQuarterStepIncrement(normalizedKg);
      final useEvenStep =
          !widget.displayInPounds &&
          !useQuarterStep &&
          usesEvenStepIncrement(normalizedKg);
      final useSingleStep = widget.displayInPounds
          ? (!useQuarterStep && ((v.abs() * 100).round()) % 250 != 0)
          : (!useQuarterStep &&
                !useEvenStep &&
                usesSingleStepIncrement(normalizedKg));
      final best = _nearestIndex(
        widget.displayInPounds
            ? (useSingleStep
                  ? _lbSingleValues
                  : useQuarterStep
                  ? _lbQuarterValues
                  : _lbValues)
            : (useQuarterStep
                  ? _kgQuarterValues
                  : useEvenStep
                  ? _kgEvenValues
                  : useSingleStep
                  ? _kgSingleValues
                  : _kgValues),
        widget.displayInPounds ? v : normalizedKg,
      );
      setState(() {
        _manualUseQuarterStep = useQuarterStep;
        _manualUseEvenStep = useEvenStep;
        _manualUseSingleStep = useSingleStep;
        _selKg = best;
        _customKgValue = normalizedKg;
      });
      _kgCtrl.animateToItem(
        best,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      _triggerInteraction();
      widget.onKgChanged(_customKgValue!);
      widget.onWeightModeChanged?.call(
        useQuarterStep,
        useEvenStep,
        useSingleStep,
      );
    } else {
      final v = int.tryParse(raw);
      if (v == null) return;
      final idx = (v - 1).clamp(0, 49);
      setState(() => _selReps = idx);
      _repsCtrl.animateToItem(
        idx,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      _triggerInteraction();
      widget.onRepsChanged(_repsValues[idx]);
    }
  }

  Widget _buildDrum({
    required FixedExtentScrollController ctrl,
    required List items,
    required int selectedIdx,
    required String label,
    required Function(int) onChanged,
    required String Function(dynamic) formatter,
    required bool highlightAbove,
    required double referenceKg,
    required bool isKg,
  }) {
    final accent = widget.accent;
    // Rimbalzo quando il peso NON è ancora stato aumentato (invita a salire)
    final currentSelectedValue = isKg ? _selectedDisplayedWeight() : 0.0;
    final referenceDisplayed = widget.displayInPounds
        ? kgToLb(referenceKg)
        : referenceKg;
    final bool showNudge =
        isKg && highlightAbove && currentSelectedValue <= referenceDisplayed;

    // Dimensioni e opacità basate sulla distanza dal centro
    double _itemSize(int dist) {
      switch (dist) {
        case 0:
          return 82;
        case 1:
          return 54;
        case 2:
          return 38;
        default:
          return 26;
      }
    }

    int _itemAlpha(int dist) {
      switch (dist) {
        case 0:
          return 255;
        case 1:
          return 160;
        case 2:
          return 100;
        default:
          return 55;
      }
    }

    FontWeight _itemWeight(int dist) {
      switch (dist) {
        case 0:
          return FontWeight.w700;
        case 1:
          return FontWeight.w500;
        default:
          return FontWeight.w300;
      }
    }

    return ClipRect(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 22,
              letterSpacing: 4,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: AnimatedBuilder(
              animation: _arrowAnim,
              builder: (_, child) => Transform.translate(
                offset: Offset(0, showNudge ? _arrowAnim.value : 0),
                child: child,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Linee di selezione
                  IgnorePointer(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          height: 1.5,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          color: accent.withAlpha(130),
                        ),
                        const SizedBox(height: 96),
                        Container(
                          height: 1.5,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          color: accent.withAlpha(130),
                        ),
                      ],
                    ),
                  ),
                  // Scroller
                  _buildWheelScroller(
                    ctrl: ctrl,
                    items: items,
                    selectedIdx: selectedIdx,
                    formatter: formatter,
                    highlightAbove: highlightAbove,
                    referenceDisplayed: referenceDisplayed,
                    isKg: isKg,
                    accent: accent,
                    onChanged: onChanged,
                    itemAlpha: _itemAlpha,
                    itemSize: _itemSize,
                    itemWeight: _itemWeight,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleDrumSelection({
    required bool isKg,
    required int index,
    required List items,
    required Function(int) onChanged,
  }) {
    setState(() {
      if (isKg) {
        _selKg = index;
        _customKgValue = null;
      } else {
        _selReps = index;
      }
    });
    if (isKg) {
      widget.onKgChanged(_displayValueToKg(items[index] as double));
    } else {
      onChanged(index);
    }
    _triggerInteraction();
  }

  Widget _buildWheelScroller({
    required FixedExtentScrollController ctrl,
    required List items,
    required int selectedIdx,
    required String Function(dynamic) formatter,
    required bool highlightAbove,
    required double referenceDisplayed,
    required bool isKg,
    required Color accent,
    required Function(int) onChanged,
    required int Function(int) itemAlpha,
    required double Function(int) itemSize,
    required FontWeight Function(int) itemWeight,
  }) {
    Widget buildItem(int i) {
      final dist = (i - selectedIdx).abs();
      final isSel = dist == 0;
      final double displayedWeight = isKg
          ? (isSel ? _selectedDisplayedWeight() : (items[i] as double))
          : 0;
      final displayText = isKg
          ? _formatDisplayedWeight(displayedWeight)
          : formatter(items[i]);
      final isAmber =
          isKg &&
          highlightAbove &&
          isSel &&
          displayedWeight > referenceDisplayed;
      final color = isSel
          ? (isKg ? (isAmber ? Colors.amber : accent) : accent)
          : Colors.white.withAlpha(itemAlpha(dist));
      final fontSize = isKg && displayText.length >= 4
          ? (itemSize(dist) - (dist == 0 ? 16 : 8)).clamp(18.0, 82.0)
          : itemSize(dist);
      final textWidget = Text(
        displayText,
        style: TextStyle(
          fontSize: fontSize,
          height: 1.0,
          color: color,
          fontWeight: itemWeight(dist),
          letterSpacing: isSel ? 1 : 0,
          shadows: isSel
              ? const [Shadow(color: Colors.black87, blurRadius: 10)]
              : null,
        ),
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.visible,
      );
      final centeredText = SizedBox(
        width: double.infinity,
        child: Center(child: textWidget),
      );
      return isSel
          ? GestureDetector(
              onTap: widget.allowKeyboardInput
                  ? () => _editValue(isKg: isKg)
                  : null,
              child: centeredText,
            )
          : centeredText;
    }

    if (Theme.of(context).platform == TargetPlatform.android) {
      return ListWheelScrollView.useDelegate(
        controller: ctrl,
        itemExtent: 96,
        diameterRatio: 1.2,
        perspective: 0.003,
        physics: const FixedExtentScrollPhysics(),
        overAndUnderCenterOpacity: 0.25,
        onSelectedItemChanged: (i) => _handleDrumSelection(
          isKg: isKg,
          index: i,
          items: items,
          onChanged: onChanged,
        ),
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: items.length,
          builder: (ctx, i) {
            if (i == null || i < 0 || i >= items.length) return null;
            return buildItem(i);
          },
        ),
      );
    }

    return CupertinoPicker.builder(
      scrollController: ctrl,
      itemExtent: 96,
      diameterRatio: 1.2,
      squeeze: 0.85,
      selectionOverlay: const SizedBox.shrink(),
      backgroundColor: Colors.transparent,
      onSelectedItemChanged: (i) => _handleDrumSelection(
        isKg: isKg,
        index: i,
        items: items,
        onChanged: onChanged,
      ),
      childCount: items.length,
      itemBuilder: (ctx, i) => buildItem(i),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: ClipRect(
              child: _buildDrum(
                ctrl: _kgCtrl,
                items: _weightValues,
                selectedIdx: _selKg,
                label: widget.displayInPounds ? 'LB' : 'KG',
                onChanged: (_) {},
                formatter: (v) {
                  final d = v as double;
                  return formatWeightValue(
                    d,
                    usePounds: widget.displayInPounds,
                  );
                },
                highlightAbove: widget.suggerisciAumento,
                referenceKg: widget.initialKg,
                isKg: true,
              ),
            ),
          ),
          Container(
            width: 1,
            color: Colors.white10,
            margin: const EdgeInsets.symmetric(vertical: 40),
          ),
          Expanded(
            child: ClipRect(
              child: _buildDrum(
                ctrl: _repsCtrl,
                items: _repsValues,
                selectedIdx: _selReps,
                label: 'REPS',
                onChanged: (i) => widget.onRepsChanged(_repsValues[i]),
                formatter: (v) => v.toString(),
                highlightAbove: false,
                referenceKg: 0,
                isKg: false,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkoutProgressChart extends StatelessWidget {
  final WorkoutDay day;
  final List<dynamic> history;
  final Color accent;
  const _WorkoutProgressChart({
    required this.day,
    required this.history,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final exerciseNames = day.exercises.map((e) => e.name).toSet();

    // Raggruppa per session_id (separa più sessioni stesso giorno)
    final Map<String, Map<String, double>> bySession = {};
    final Map<String, String> sessionDate = {};
    for (final h in history) {
      final exName = h['exercise'] as String? ?? '';
      if (!exerciseNames.contains(exName)) continue;
      final dateRaw = h['date'] as String? ?? '';
      if (dateRaw.isEmpty) continue;
      final dateOnly = dateRaw.substring(0, 10);
      final sessionKey = (h['session_id'] as String?)?.isNotEmpty == true
          ? h['session_id'] as String
          : dateOnly;
      sessionDate.putIfAbsent(sessionKey, () => dateOnly);
      final series = h['series'] as List? ?? [];
      double maxEst1RM = 0;
      for (final s in series) {
        final w = (s['w'] ?? 0.0).toDouble();
        final r = (s['r'] ?? 0).toDouble();
        final est1RM = r > 0 ? w * (1 + r / 30.0) : w;
        if (est1RM > maxEst1RM) maxEst1RM = est1RM;
      }
      bySession.putIfAbsent(sessionKey, () => {})[exName] = maxEst1RM;
    }

    if (bySession.isEmpty) {
      return Center(
        child: Text(
          AppL.noDataRegistered,
          style: const TextStyle(color: Colors.white38),
        ),
      );
    }

    final sessions = bySession.keys.toList()
      ..sort((a, b) => (sessionDate[a] ?? a).compareTo(sessionDate[b] ?? b));
    final scores = sessions
        .map((s) => bySession[s]!.values.fold(0.0, (a, b) => a + b))
        .toList();

    final Map<String, int> dateTotal = {};
    for (final s in sessions) {
      final d = sessionDate[s] ?? '';
      dateTotal[d] = (dateTotal[d] ?? 0) + 1;
    }
    final Map<String, int> dateCounter = {};
    final labels = sessions.map((s) {
      final d = sessionDate[s] ?? s;
      final dd = d.length >= 10
          ? '${d.substring(8, 10)}/${d.substring(5, 7)}'
          : d;
      if ((dateTotal[d] ?? 1) > 1) {
        dateCounter[d] = (dateCounter[d] ?? 0) + 1;
        return '$dd(${dateCounter[d]})';
      }
      return dd;
    }).toList();

    final minS = scores.reduce((a, b) => a < b ? a : b);
    final maxS = scores.reduce((a, b) => a > b ? a : b);

    return CustomPaint(
      painter: _WorkoutProgressPainter(
        labels: labels,
        scores: scores,
        minS: minS,
        maxS: maxS,
        accent: accent,
      ),
    );
  }
}

class _WorkoutProgressPainter extends CustomPainter {
  final List<String> labels;
  final List<double> scores;
  final double minS, maxS;
  final Color accent;
  _WorkoutProgressPainter({
    required this.labels,
    required this.scores,
    required this.minS,
    required this.maxS,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (labels.isEmpty) return;

    final double range = (maxS - minS).abs();
    final bool flat = range < 1.0;

    // Assi
    final axisPaint = Paint()
      ..color = Colors.white12
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      axisPaint,
    );

    // Linea gradiente
    final linePaint = Paint()
      ..color = accent
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final dotPaint = Paint()
      ..color = accent
      ..style = PaintingStyle.fill;
    final dotBg = Paint()
      ..color = const Color(0xFF0E0E10)
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();
    final n = labels.length;

    for (int i = 0; i < n; i++) {
      final x = n == 1 ? size.width / 2 : size.width / (n - 1) * i;
      final norm = flat ? 0.5 : (scores[i] - minS) / range;
      final y = size.height * 0.9 - (size.height * 0.8 * norm.clamp(0.0, 1.0));
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    // Close fill path along the bottom
    final lastX = n == 1 ? size.width / 2 : size.width;
    fillPath.lineTo(lastX, size.height);
    fillPath.close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [accent.withAlpha(55), accent.withAlpha(0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
    canvas.drawPath(path, linePaint);

    // Punti + etichette data
    for (int i = 0; i < n; i++) {
      final x = n == 1 ? size.width / 2 : size.width / (n - 1) * i;
      final norm = flat ? 0.5 : (scores[i] - minS) / range;
      final y = size.height * 0.9 - (size.height * 0.8 * norm.clamp(0.0, 1.0));
      canvas.drawCircle(Offset(x, y), 5, dotBg);
      canvas.drawCircle(Offset(x, y), 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_WorkoutProgressPainter old) => true;
}

// --- GRAFICI ---

class PTGraphWidget extends StatelessWidget {
  final String exerciseName;
  final List<dynamic> history;

  const PTGraphWidget({
    super.key,
    required this.exerciseName,
    required this.history,
  });

  @override
  Widget build(BuildContext context) {
    final List<Color> seriesColors = [
      Theme.of(context).colorScheme.primary,
      Colors.purpleAccent,
      Colors.greenAccent,
      Colors.orangeAccent,
      Colors.redAccent,
    ];
    var logs = history
        .where((h) => h['exercise'] == exerciseName)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    if (logs.isEmpty) return Center(child: Text(AppL.noData));

    // 1. Troviamo il numero massimo di serie per questo esercizio
    int maxSetsFound = 0;
    for (var l in logs) {
      var series = l['series'] as List;
      if (series.length > maxSetsFound) maxSetsFound = series.length;
    }

    // 2. Score = 1RM stimato (Epley) per serie → normalizzazione min-max per indice serie
    Map<int, double> minScore = {};
    Map<int, double> maxScore = {};
    for (var l in logs) {
      var series = l['series'] as List;
      for (int i = 0; i < series.length; i++) {
        double w = (series[i]['w'] ?? 0.0).toDouble();
        double r = (series[i]['r'] ?? 0.0).toDouble();
        double sc = w * (1 + r / 30.0); // Epley 1RM estimate
        minScore[i] = sc < (minScore[i] ?? sc) ? sc : (minScore[i] ?? sc);
        maxScore[i] = sc > (maxScore[i] ?? sc) ? sc : (maxScore[i] ?? sc);
      }
    }

    // 3. Applica normalizzazione score
    for (var l in logs) {
      var series = l['series'] as List;
      for (int i = 0; i < series.length; i++) {
        double w = (series[i]['w'] ?? 0.0).toDouble();
        double r = (series[i]['r'] ?? 0.0).toDouble();
        double sc = w * (1 + r / 30.0); // Epley 1RM estimate
        double lo = minScore[i] ?? 0;
        double hi = maxScore[i] ?? 1;
        double range = hi - lo;
        series[i]['s_norm'] = range > 0.5 ? (sc - lo) / range : 0.5;
        series[i]['s_min'] = lo;
        series[i]['s_max'] = hi;
      }
    }

    return Column(
      children: [
        const SizedBox(height: 10),
        Text(
          exerciseName.toUpperCase(),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 15,
          runSpacing: 15,
          children: List.generate(
            maxSetsFound,
            (i) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 3,
                  color: seriesColors[i % seriesColors.length],
                ),
                const SizedBox(width: 5),
                Text(
                  "S${i + 1}",
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 160,
          child: logs.isEmpty
              ? Center(child: Text(AppL.noData))
              : CustomPaint(
                  size: Size.infinite,
                  painter: PTChartPainter(logs: logs, colors: seriesColors),
                ),
        ),
      ],
    );
  }
}

class PTChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> logs;
  final List<Color> colors;
  PTChartPainter({required this.logs, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    if (logs.isEmpty) return;

    int maxSets = 0;
    for (var log in logs) {
      if ((log['series'] as List).length > maxSets)
        maxSets = (log['series'] as List).length;
    }

    for (int sIdx = 0; sIdx < maxSets; sIdx++) {
      final color = colors[sIdx % colors.length];
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final path = Path();
      final fillPath = Path();
      bool first = true;
      double firstX = 0, lastX = 0;

      for (int i = 0; i < logs.length; i++) {
        final sData = logs[i]['series'] as List;
        if (sIdx < sData.length) {
          double x = logs.length == 1
              ? size.width / 2
              : size.width / (logs.length - 1) * i;
          double sNorm = ((sData[sIdx]['s_norm'] ?? 0.5) as double).clamp(
            0.0,
            1.0,
          );
          double y = size.height * (1.0 - sNorm);
          if (first) {
            path.moveTo(x, y);
            fillPath.moveTo(x, size.height);
            fillPath.lineTo(x, y);
            firstX = x;
            first = false;
          } else {
            path.lineTo(x, y);
            fillPath.lineTo(x, y);
          }
          lastX = x;
          canvas.drawCircle(Offset(x, y), 3, Paint()..color = color);
        }
      }
      if (!first) {
        fillPath.lineTo(lastX, size.height);
        fillPath.close();
        canvas.drawPath(
          fillPath,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [color.withAlpha(40), color.withAlpha(0)],
            ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
        );
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(old) => true;
}

// --- SCHERMATA GESTIONE DATI ---
class CancellazioneScreen extends StatefulWidget {
  final List<dynamic> history;
  final List<WorkoutDay> routine;
  final Future<void> Function(List<dynamic> newHistory) onSave;

  const CancellazioneScreen({
    super.key,
    required this.history,
    required this.onSave,
    this.routine = const [],
  });

  @override
  State<CancellazioneScreen> createState() => _CancellazioneScreenState();
}

class _CancellazioneScreenState extends State<CancellazioneScreen> {
  late List<dynamic> _history;
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _history = List<dynamic>.from(widget.history);
  }

  Map<String, List<dynamic>> get _grouped {
    final Map<String, List<dynamic>> map = {};
    for (final h in _history) {
      final name = (h['exercise'] as String?) ?? '';
      if (name.isEmpty) continue;
      map.putIfAbsent(name, () => []).add(h);
    }
    return map;
  }

  /// Raggruppa lo storico per allenamento (dayName), rispettando l'ordine della scheda.
  List<MapEntry<String, Map<String, List<dynamic>>>> get _groupedByDay {
    // dayName → { exerciseName → [sessions] }
    final Map<String, Map<String, List<dynamic>>> byDay = {};

    // Inizializza i giorni nell'ordine della scheda
    for (final day in widget.routine) {
      byDay[day.dayName] = {};
    }

    for (final h in _history) {
      final exName = (h['exercise'] as String?) ?? '';
      if (exName.isEmpty) continue;
      final dayName = (h['dayName'] as String?) ?? '';

      // Trova il dayName dalla scheda se non presente nell'entry
      String resolvedDay = dayName;
      if (resolvedDay.isEmpty) {
        for (final day in widget.routine) {
          if (day.exercises.any((e) => e.name == exName)) {
            resolvedDay = day.dayName;
            break;
          }
        }
        if (resolvedDay.isEmpty) resolvedDay = 'Altro';
      }

      byDay.putIfAbsent(resolvedDay, () => {});
      byDay[resolvedDay]!.putIfAbsent(exName, () => []).add(h);
    }

    // Rimuovi giorni vuoti e restituisci come lista ordinata
    return byDay.entries.where((e) => e.value.isNotEmpty).toList();
  }

  Future<void> _eliminaSelezionati() async {
    if (_selected.isEmpty) return;
    final toDelete = Set<String>.from(_selected);
    final filtered = _history
        .where((h) => !toDelete.contains(h['exercise']))
        .toList();
    await widget.onSave(filtered);
    if (!mounted) return;
    setState(() {
      _history = filtered;
      _selected.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppL.dataDeleted),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  Future<void> _resetTotale() async {
    final ok1 = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: Text(
          AppL.fullResetTitle,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          AppL.fullResetMsg,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppL.cancel.toUpperCase()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              AppL.continueLabel,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (ok1 != true || !mounted) return;
    final ok2 = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: Text(
          AppL.areYouSure,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          AppL.irreversible,
          style: const TextStyle(color: Colors.red),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppL.cancel.toUpperCase()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              AppL.deleteAll,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (ok2 != true || !mounted) return;
    final prefs = await SharedPreferences.getInstance();
    try {
      await _gymFileChannel.invokeMethod('cancelStreakReminderNotification');
      await _gymFileChannel.invokeMethod('cancelCountdownNotification');
      await _gymFileChannel.invokeMethod('cancelTimerFinishedNotification');
    } catch (_) {}
    await prefs.clear();
    if (!mounted) return;
    setState(() {
      _history = [];
      _selected.clear();
    });
    Navigator.pop(context, true);
  }

  void _apriDettaglio(String exName, List<dynamic> sessions) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _DettaglioEsercizioScreen(
          exerciseName: exName,
          sessions: sessions,
          onSave: (updatedSessions) async {
            final newHistory =
                _history.where((h) => h['exercise'] != exName).toList()
                  ..addAll(updatedSessions);
            await widget.onSave(newHistory);
            if (mounted) setState(() => _history = newHistory);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final days = _groupedByDay;
    // Raccogliamo tutti gli esercizi per la selezione multipla
    final grouped = _grouped;

    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            const Icon(
              Icons.storage_rounded,
              color: Colors.redAccent,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              AppL.dataManagement,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: days.isEmpty
                ? Center(
                    child: Text(
                      AppL.noHistory,
                      style: TextStyle(
                        color: Colors.white.withAlpha(80),
                        fontSize: 15,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    itemCount: days.length,
                    itemBuilder: (_, dayIdx) {
                      final dayName = days[dayIdx].key;
                      final exercises = days[dayIdx].value;
                      final exNames = exercises.keys.toList();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header giorno
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
                            child: Row(
                              children: [
                                Container(
                                  width: 3,
                                  height: 16,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                Text(
                                  dayName.toUpperCase(),
                                  style: TextStyle(
                                    color: Colors.white.withAlpha(180),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Esercizi del giorno
                          ...exNames.map((exName) {
                            final sessions = exercises[exName]!;
                            final isSelected = _selected.contains(exName);
                            return GestureDetector(
                              onLongPress: () => setState(() {
                                _selected.clear();
                                _selected.add(exName);
                              }),
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 3),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.redAccent.withAlpha(30)
                                      : Colors.white.withAlpha(8),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.redAccent.withAlpha(120)
                                        : Colors.white10,
                                  ),
                                ),
                                child: ListTile(
                                  onTap: () => _apriDettaglio(
                                    exName,
                                    grouped[exName] ?? sessions,
                                  ),
                                  leading: Checkbox(
                                    value: isSelected,
                                    activeColor: Colors.redAccent,
                                    checkColor: Colors.white,
                                    onChanged: (v) => setState(() {
                                      if (v == true)
                                        _selected.add(exName);
                                      else
                                        _selected.remove(exName);
                                    }),
                                  ),
                                  title: Text(
                                    exName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${sessions.length} ${sessions.length == 1 ? AppL.sessionCount : AppL.sessionCountPlural}',
                                    style: TextStyle(
                                      color: Colors.white.withAlpha(100),
                                      fontSize: 12,
                                    ),
                                  ),
                                  trailing: const Icon(
                                    Icons.chevron_right_rounded,
                                    color: Colors.white24,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      );
                    },
                  ),
          ),
          if (_selected.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(
                    Icons.delete_sweep_outlined,
                    color: Colors.white,
                  ),
                  label: Text(
                    '${AppL.deleteSelected} (${_selected.length})',
                    style: const TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _eliminaSelezionati,
                ),
              ),
            ),
          const Divider(color: Colors.white12, height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              AppL.totalReset,
              style: TextStyle(
                color: Colors.white.withAlpha(100),
                fontSize: 11,
                letterSpacing: 2,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(
                  Icons.delete_forever_outlined,
                  color: Colors.redAccent,
                ),
                label: Text(
                  AppL.fullReset,
                  style: const TextStyle(color: Colors.redAccent),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.redAccent),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _resetTotale,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- DETTAGLIO ESERCIZIO — modifica e cancella serie ---
class _DettaglioEsercizioScreen extends StatefulWidget {
  final String exerciseName;
  final List<dynamic> sessions;
  final Future<void> Function(List<dynamic> updated) onSave;

  const _DettaglioEsercizioScreen({
    required this.exerciseName,
    required this.sessions,
    required this.onSave,
  });

  @override
  State<_DettaglioEsercizioScreen> createState() =>
      _DettaglioEsercizioScreenState();
}

class _DettaglioEsercizioScreenState extends State<_DettaglioEsercizioScreen> {
  late List<dynamic> _sessions;

  @override
  void initState() {
    super.initState();
    _sessions = List<dynamic>.from(
      widget.sessions.map((s) => Map<String, dynamic>.from(s)),
    );
  }

  Future<void> _save() => widget.onSave(_sessions);

  void _eliminaSessione(int sIdx) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: Text(
          AppL.deleteSession,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          AppL.deleteSessionMsg,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppL.cancel.toUpperCase()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              AppL.delete,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _sessions.removeAt(sIdx));
    await _save();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppL.sessionDeleted),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _eliminaSerie(int sIdx, int serieIdx) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: Text(
          AppL.deleteSeries,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppL.cancel.toUpperCase()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              AppL.delete,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      final series = List<dynamic>.from(_sessions[sIdx]['series'] ?? []);
      series.removeAt(serieIdx);
      _sessions[sIdx] = Map<String, dynamic>.from(_sessions[sIdx])
        ..['series'] = series;
    });
    await _save();
  }

  void _modificaSerie(int sIdx, int serieIdx) {
    final serie = (_sessions[sIdx]['series'] as List)[serieIdx] as Map;
    final wCtrl = TextEditingController(
      text: '${serie['w'] ?? serie['weight'] ?? ''}',
    );
    final rCtrl = TextEditingController(
      text: '${serie['r'] ?? serie['reps'] ?? ''}',
    );
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: Text(
          'Serie ${serieIdx + 1}',
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: wCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: AppL.weight,
                labelStyle: const TextStyle(color: Colors.white54),
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: rCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Reps',
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppL.cancel.toUpperCase()),
          ),
          TextButton(
            onPressed: () async {
              final newW =
                  double.tryParse(wCtrl.text.replaceAll(',', '.')) ?? 0.0;
              final newR = int.tryParse(rCtrl.text) ?? 0;
              setState(() {
                final series = List<dynamic>.from(
                  _sessions[sIdx]['series'] ?? [],
                );
                series[serieIdx] = {'w': newW, 'r': newR};
                _sessions[sIdx] = Map<String, dynamic>.from(_sessions[sIdx])
                  ..['series'] = series;
              });
              await _save();
              if (mounted) Navigator.pop(context);
            },
            child: Text(
              AppL.save.toUpperCase(),
              style: const TextStyle(color: Color(0xFF00F2FF)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.exerciseName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _sessions.isEmpty
          ? Center(
              child: Text(
                AppL.noSession,
                style: TextStyle(
                  color: Colors.white.withAlpha(80),
                  fontSize: 15,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _sessions.length,
              itemBuilder: (_, sIdx) {
                final session = _sessions[sIdx];
                final date = session['date'] as String? ?? '';
                final series = (session['series'] as List?) ?? [];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header sessione
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                date,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent,
                                size: 20,
                              ),
                              tooltip: AppL.lang == 'en'
                                  ? 'Delete session'
                                  : 'Elimina sessione',
                              onPressed: () => _eliminaSessione(sIdx),
                            ),
                          ],
                        ),
                      ),
                      const Divider(color: Colors.white10, height: 1),
                      // Serie
                      ...series.asMap().entries.map((e) {
                        final idx = e.key;
                        final s = e.value as Map;
                        final w = s['w'] ?? s['weight'] ?? 0;
                        final r = s['r'] ?? s['reps'] ?? 0;
                        return ListTile(
                          dense: true,
                          title: Text(
                            'Serie ${idx + 1}:  ${w}kg × ${r} reps',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.edit_rounded,
                                  color: Colors.white38,
                                  size: 18,
                                ),
                                onPressed: () => _modificaSerie(sIdx, idx),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.remove_circle_outline,
                                  color: Colors.redAccent,
                                  size: 18,
                                ),
                                onPressed: () => _eliminaSerie(sIdx, idx),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _OverallProgressPage extends StatefulWidget {
  final List<dynamic> history;
  final List<WorkoutDay> routine;
  final int streak;
  final Color accent;
  final Widget Function() buildAd;

  const _OverallProgressPage({
    required this.history,
    required this.routine,
    required this.streak,
    required this.accent,
    required this.buildAd,
  });

  @override
  State<_OverallProgressPage> createState() => _OverallProgressPageState();
}

class _OverallProgressPageState extends State<_OverallProgressPage> {
  String? _filterDay;
  final GlobalKey _chartKey = GlobalKey();

  List<_SessionPoint> _computePoints() {
    // Group history by session, then by exercise
    final Map<String, Map<String, double>> bySessionEx = {};
    final Map<String, String> sessionDate = {};
    final Map<String, String> sessionDayName = {};

    for (final h in widget.history) {
      final sid = (h['session_id'] as String?)?.isNotEmpty == true
          ? h['session_id'] as String
          : ((h['date'] as String?) ?? '').substring(0, 10);
      if (_filterDay != null && h['dayName'] != _filterDay) continue;
      final exName = (h['exercise'] as String?) ?? '';
      if (exName.isEmpty) continue;
      sessionDate.putIfAbsent(sid, () => (h['date'] as String?) ?? '');
      sessionDayName.putIfAbsent(sid, () => (h['dayName'] as String?) ?? '');

      // Compute max estimated 1RM for this exercise in this session
      final series = (h['series'] as List?) ?? [];
      double maxEst1RM = 0;
      for (final s in series) {
        final w = (s['w'] ?? 0.0).toDouble();
        final r = (s['r'] ?? 0).toDouble();
        final est1RM = r > 0 ? w * (1 + r / 30.0) : w;
        if (est1RM > maxEst1RM) maxEst1RM = est1RM;
      }
      final exMap = bySessionEx.putIfAbsent(sid, () => {});
      if ((exMap[exName] ?? 0) < maxEst1RM) exMap[exName] = maxEst1RM;
    }

    final List<_SessionPoint> points = [];
    for (final sid in bySessionEx.keys) {
      final date = sessionDate[sid] ?? '';
      if (date.isEmpty) continue;
      // Score = sum of max estimated 1RM across all exercises in the session
      final score = bySessionEx[sid]!.values.fold(0.0, (a, b) => a + b);
      points.add(_SessionPoint(
        sessionId: sid,
        date: DateTime.tryParse(date) ?? DateTime(2000),
        score: score,
        dayName: sessionDayName[sid] ?? '',
      ));
    }
    points.sort((a, b) => a.date.compareTo(b.date));

    // When showing all sessions, group by microcycle (one complete pass through all workout days)
    if (_filterDay == null && widget.routine.length > 1) {
      return _groupByMicrocycle(points);
    }
    return points;
  }

  List<_SessionPoint> _groupByMicrocycle(List<_SessionPoint> sessions) {
    final dayNames = widget.routine.map((d) => d.dayName).toSet();
    if (dayNames.length <= 1) return sessions;

    final List<_SessionPoint> result = [];
    List<_SessionPoint> currentCycle = [];
    Set<String> seenDays = {};
    int cycleIndex = 1;

    for (final s in sessions) {
      final day = s.dayName;
      if (!dayNames.contains(day)) continue;

      if (seenDays.contains(day)) {
        // This day was already done in current cycle → close it
        if (currentCycle.isNotEmpty) {
          result.add(_aggregateCycle(currentCycle, cycleIndex++));
        }
        currentCycle = [s];
        seenDays = {day};
      } else {
        currentCycle.add(s);
        seenDays.add(day);
        if (seenDays.length == dayNames.length) {
          // All days completed: microcycle done
          result.add(_aggregateCycle(currentCycle, cycleIndex++));
          currentCycle = [];
          seenDays = {};
        }
      }
    }

    // Partial last cycle
    if (currentCycle.isNotEmpty) {
      result.add(_aggregateCycle(currentCycle, cycleIndex));
    }

    return result;
  }

  _SessionPoint _aggregateCycle(List<_SessionPoint> sessions, int index) {
    final avgScore = sessions.fold(0.0, (sum, s) => sum + s.score) / sessions.length;
    return _SessionPoint(
      sessionId: 'cycle_$index',
      date: sessions.last.date,
      score: avgScore,
      dayName: 'Microciclo $index',
    );
  }

  Future<void> _shareProgress(BuildContext context) async {
    // Show composer sheet with options
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProgressShareSheet(
        chartKey: _chartKey,
        streak: widget.streak,
        points: _computePoints(),
        accent: widget.accent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    final points = _computePoints();
    final dayNames = widget.routine.map((d) => d.dayName).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0E0E10),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E0E10),
        title: Text(
          AppL.lang == 'en' ? 'Overall Progress' : 'Progressi Generali',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (!kIsWeb)
            IconButton(
              icon: const Icon(Icons.share_rounded),
              onPressed: () => _shareProgress(context),
              tooltip: AppL.lang == 'en' ? 'Share' : 'Condividi',
            ),
        ],
      ),
      body: Column(
        children: [
          if (dayNames.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _filterChip(
                    label: AppL.lang == 'en' ? 'All' : 'Tutti',
                    selected: _filterDay == null,
                    accent: accent,
                    onTap: () => setState(() => _filterDay = null),
                  ),
                  const SizedBox(width: 8),
                  ...dayNames.map(
                    (d) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _filterChip(
                        label: d,
                        selected: _filterDay == d,
                        accent: accent,
                        onTap: () =>
                            setState(() => _filterDay = _filterDay == d ? null : d),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: points.isEmpty
                ? Center(
                    child: Text(
                      AppL.noData,
                      style: const TextStyle(color: Colors.white38, fontSize: 16),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStatsRow(points, accent),
                        const SizedBox(height: 20),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C1C1E),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 4,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: accent,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _filterDay == null && widget.routine.length > 1
                                        ? (AppL.lang == 'en' ? 'Progress per microcycle' : 'Progressi per microciclo')
                                        : (AppL.lang == 'en' ? 'Progress per session' : 'Progressi per sessione'),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              RepaintBoundary(
                                key: _chartKey,
                                child: SizedBox(
                                  height: 220,
                                  child: CustomPaint(
                                    size: Size.infinite,
                                    painter: _OverallProgressPainter(
                                      points: points,
                                      accent: accent,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        widget.buildAd(),
                        if (!kIsWeb) ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.share_rounded),
                              label: Text(
                                AppL.lang == 'en'
                                    ? 'Share progress'
                                    : 'Condividi progressi',
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: accent,
                                side: BorderSide(color: accent),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () => _shareProgress(context),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? accent.withAlpha(40) : const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? accent : Colors.white12,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? accent : Colors.white60,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow(List<_SessionPoint> points, Color accent) {
    final totalSessions = points.length;
    final streak = widget.streak;
    final trendPct = points.length >= 2 && points.first.score > 0
        ? ((points.last.score - points.first.score) / points.first.score * 100)
        : 0.0;
    final trendUp = trendPct >= 0;

    return Row(
      children: [
        _statCard(
          _filterDay == null && widget.routine.length > 1
              ? (AppL.lang == 'en' ? 'Microcycles' : 'Microcicli')
              : (AppL.lang == 'en' ? 'Sessions' : 'Sessioni'),
          '$totalSessions',
          Icons.calendar_today_rounded,
          accent,
        ),
        const SizedBox(width: 8),
        _statCard(
          'Streak',
          '🔥 $streak',
          Icons.local_fire_department_rounded,
          Colors.orange,
        ),
        const SizedBox(width: 8),
        _statCard(
          AppL.lang == 'en' ? 'Trend' : 'Trend',
          points.length >= 2
              ? '${trendUp ? '+' : ''}${trendPct.toStringAsFixed(0)}%'
              : '—',
          trendUp ? Icons.trending_up : Icons.trending_down,
          trendUp ? Colors.greenAccent : Colors.redAccent,
        ),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(100), width: 1.5),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: Colors.white38, fontSize: 10),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionPoint {
  final String sessionId;
  final DateTime date;
  final double score; // sum of max estimated 1RM per exercise
  final String dayName;
  const _SessionPoint({
    required this.sessionId,
    required this.date,
    required this.score,
    required this.dayName,
  });
}

class _OverallProgressPainter extends CustomPainter {
  final List<_SessionPoint> points;
  final Color accent;

  const _OverallProgressPainter({required this.points, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final n = points.length;
    final volumes = points.map((p) => p.score).toList();
    final minV = volumes.reduce((a, b) => a < b ? a : b);
    final maxV = volumes.reduce((a, b) => a > b ? a : b);
    final range = (maxV - minV).abs();

    final axisPaint = Paint()..color = Colors.white12..strokeWidth = 1;
    const leftPad = 10.0;
    const botPad = 20.0;
    final chartH = size.height - botPad;
    canvas.drawLine(Offset(leftPad, 0), Offset(leftPad, chartH), axisPaint);
    canvas.drawLine(Offset(leftPad, chartH), Offset(size.width, chartH), axisPaint);

    final fillPath = Path();
    final linePath = Path();
    for (int i = 0; i < n; i++) {
      final x = leftPad + (size.width - leftPad) / (n > 1 ? (n - 1) : 1) * i;
      final norm = range > 0.5 ? (volumes[i] - minV) / range : 0.5;
      final y = chartH * 0.9 - (chartH * 0.8 * norm.clamp(0.0, 1.0));
      if (i == 0) {
        fillPath.moveTo(x, chartH);
        fillPath.lineTo(x, y);
        linePath.moveTo(x, y);
      } else {
        fillPath.lineTo(x, y);
        linePath.lineTo(x, y);
      }
    }
    fillPath.lineTo(leftPad + (size.width - leftPad), chartH);
    fillPath.close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [accent.withAlpha(60), accent.withAlpha(0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, chartH)),
    );
    canvas.drawPath(
      linePath,
      Paint()
        ..color = accent
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final dotPaint = Paint()..color = accent..style = PaintingStyle.fill;
    final dotBg = Paint()
      ..color = const Color(0xFF1C1C1E)
      ..style = PaintingStyle.fill;
    for (int i = 0; i < n; i++) {
      final x = leftPad + (size.width - leftPad) / (n > 1 ? (n - 1) : 1) * i;
      final norm = range > 0.5 ? (volumes[i] - minV) / range : 0.5;
      final y = chartH * 0.9 - (chartH * 0.8 * norm.clamp(0.0, 1.0));
      canvas.drawCircle(Offset(x, y), 5, dotBg);
      canvas.drawCircle(Offset(x, y), 4, dotPaint);

      if (n <= 8 || i % ((n / 6).ceil()) == 0 || i == n - 1) {
        // Date labels removed from share card
      }
    }
  }

  @override
  bool shouldRepaint(_OverallProgressPainter old) => true;
}
