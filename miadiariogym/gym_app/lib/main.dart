import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as scala;
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'gif_exercise_catalog.dart';
import 'exercise_catalog.dart';

// Colore accento globale (tema)
final ValueNotifier<Color> appAccentNotifier = ValueNotifier<Color>(
  const Color(0xFF00F2FF),
);

// Istanza globale del plugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

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

  @override
  void initState() {
    super.initState();
    // Creiamo il link di ricerca
    final String query = Uri.encodeComponent("esecuzione ${widget.esercizio}");
    final String url = "https://www.youtube.com/results?search_query=$query";

    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Video: ${widget.esercizio}"),
        backgroundColor: Colors.black,
      ),
      body: WebViewWidget(controller: controller),
    );
  }
}

// Flag globale: notifiche pronte
bool _notificationsReady = false;

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // Avvia subito l'app — nessun await che blocchi
  runApp(const ClientGymApp());

  // Inizializza plugin in background (errori non crashano l'app)
  _initPluginsBackground();
}

Future<void> _initPluginsBackground() async {
  // AdMob
  try {
    if (!kIsWeb) await MobileAds.instance.initialize();
  } catch (_) {}

  // Notifiche
  try {
    const AndroidInitializationSettings initAndroid =
        AndroidInitializationSettings('ic_notification');
    const InitializationSettings initSettings = InitializationSettings(
      android: initAndroid,
    );
    await flutterLocalNotificationsPlugin.initialize(initSettings);
    _notificationsReady = true;
  } catch (_) {}

  // Permessi (solo Android)
  if (!kIsWeb && Platform.isAndroid) {
    try {
      final androidPlugin = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.requestNotificationsPermission();
      await androidPlugin?.requestExactAlarmsPermission();
    } catch (_) {}
  }

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

  static String get mySchedule => _lang == 'en' ? 'My Schedule' : 'La mia scheda';
  static String get noSchedule => _lang == 'en' ? 'No schedule yet' : 'Nessuna scheda';
  static String get createSchedule => _lang == 'en' ? 'Create your schedule' : 'Crea la tua scheda';
  static String get train => _lang == 'en' ? 'Train' : 'Allenati';
  static String get progress => _lang == 'en' ? 'Progress' : 'Progressi';
  static String get settings => _lang == 'en' ? 'Settings' : 'Impostazioni';
  static String get deleteData => _lang == 'en' ? 'Delete data' : 'Cancella dati';
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
  static String get startWorkout => _lang == 'en' ? 'Start Workout' : 'Inizia Allenamento';
  static String get proTrainer => _lang == 'en' ? 'Are you a Personal Trainer?' : 'Sei un Personal Trainer?';
  static String get pause => _lang == 'en' ? 'Pause between exercises (s)' : 'Pausa tra esercizi (s)';
  static String get browseArchive => _lang == 'en' ? 'Browse archive' : 'Sfoglia archivio';
  static String get repsPerSet => _lang == 'en' ? 'Reps per set' : 'Reps per serie';
  static String get muscleGroup => _lang == 'en' ? 'Muscle group' : 'Gruppo muscolare';
  static String get chooseExercise => _lang == 'en' ? 'Choose exercise' : 'Scegli esercizio';
}

class AdManager {
  AdManager._();
  static final AdManager instance = AdManager._();

  InterstitialAd? _interstitialAd;
  bool _isAdLoaded = false;

  // TODO: Sostituire con veri Ad Unit ID prima di rilasciare in produzione
  static const String _interstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712'; // TEST
  static const String bannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111'; // TEST

  void loadInterstitial() {
    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isAdLoaded = true;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitialAd = null;
              _isAdLoaded = false;
              loadInterstitial();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _interstitialAd = null;
              _isAdLoaded = false;
              loadInterstitial();
            },
          );
        },
        onAdFailedToLoad: (error) {
          _isAdLoaded = false;
          debugPrint('Interstitial failed to load: $error');
        },
      ),
    );
  }

  void showInterstitialThenRun(VoidCallback onComplete) {
    if (_isAdLoaded && _interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _interstitialAd = null;
          _isAdLoaded = false;
          loadInterstitial();
          onComplete();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _interstitialAd = null;
          _isAdLoaded = false;
          loadInterstitial();
          onComplete();
        },
      );
      _interstitialAd!.show();
    } else {
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
    if (mounted) setState(() { _langChosen = langChosen; _onboardingDone = done; _loading = false; });
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
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, height: 1.4),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('🇮🇹  Italiano', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.white24)),
                    ),
                    child: const Text('🇬🇧  English', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
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

  final List<_OnboardingPage> _pages = [
    _OnboardingPage(
      icon: '🏋️',
      title: 'Benvenuto in GymApp',
      text: 'La tua app per allenarsi in modo intelligente, ovunque tu sia.',
    ),
    _OnboardingPage(
      icon: '📋',
      title: 'Crea la tua scheda',
      text: 'Costruisci la tua routine personalizzata con esercizi dal nostro database di 1200+ movimenti con GIF animate.',
    ),
    _OnboardingPage(
      icon: '⏱️',
      title: 'Allena e registra',
      text: 'Segui ogni serie con timer automatico, registra pesi e ripetizioni, visualizza i tuoi progressi nel tempo.',
    ),
    _OnboardingPage(
      icon: '📊',
      title: 'Monitora i progressi',
      text: 'Grafici per ogni esercizio, storico delle sessioni e suggerimenti automatici per aumentare i carichi.',
    ),
    _OnboardingPage(
      icon: '👨‍💼',
      title: 'Sei un Personal Trainer?',
      text: 'Porta i tuoi clienti al livello successivo con l\'ecosistema completo: app PT per creare schede e monitorare tutti i tuoi atleti da un\'unica dashboard.',
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
              children: List.generate(_pages.length, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
                width: _currentPage == i ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _currentPage == i ? accent : Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
              )),
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text('INIZIA', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 2)),
                      ),
                    )
                  : SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () => _pageCtrl.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text('AVANTI', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
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
            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5),
          ),
          const SizedBox(height: 16),
          Text(
            page.text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white60, fontSize: 16, height: 1.6),
          ),
          if (page.isPromo) ...[
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: () async {
                final uri = Uri.parse('mailto:osare199@gmail.com');
                if (await canLaunchUrl(uri)) await launchUrl(uri);
              },
              icon: const Text('📧', style: TextStyle(fontSize: 18)),
              label: const Text('Contatta Gianmarco'),
              style: OutlinedButton.styleFrom(
                foregroundColor: accent,
                side: BorderSide(color: accent.withAlpha(120)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Scrivi per info sull\'ecosistema GymApp Pro',
              style: TextStyle(color: Colors.white30, fontSize: 12),
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
  const _OnboardingPage({required this.icon, required this.title, required this.text, this.isPromo = false});
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

  // 1. Match diretto su nome italiano o inglese
  for (final ex in kGifCatalog) {
    if (ex.name.toLowerCase().contains(q) || ex.nameEn.toLowerCase().contains(q)) {
      tryAdd(ex);
    }
  }

  // 2. Match tramite parole chiave italiane
  if (results.length < limit) {
    for (final entry in kItalianKeywords.entries) {
      if (entry.key.contains(q) || q.contains(entry.key)) {
        for (final eng in entry.value) {
          for (final ex in kGifCatalog) {
            if (ex.name.toLowerCase().contains(eng) || ex.nameEn.toLowerCase().contains(eng)) {
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
          (json['recoveryTime'] as num? ?? json['rest'] as num?)?.toInt() ?? 60,
      interExercisePause:
          (json['interExercisePause'] as num? ?? json['pause'] as num?)
              ?.toInt() ??
          120,
      notePT: json['notePT'] ?? "",
      noteCliente: json['noteCliente'] ?? "",
      supersetGroup: (json['supersetGroup'] as num?)?.toInt() ?? 0,
      gifFilename: json['gifFilename'] as String?,
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
  'schiena': '🔙',
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
  'schiena': 'Schiena',
  'gambe': 'Gambe',
  'spalle': 'Spalle',
  'braccia': 'Braccia',
  'core': 'Core',
  'full_body': 'Full Body',
  'cardio': 'Cardio',
  'glutei': 'Glutei',
  'altro': 'Altro',
};

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

  // Impostazioni
  bool _stTimerSound = true;
  bool _stVibration = true;
  bool _stWakelock = true;
  bool _stAutoTimer = true;
  bool _stConfirmSeries = true;
  bool _stWeightHint = true;

  String _appLang = 'it';
  BannerAd? _bannerAd;
  bool _bannerAdLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
    _loadMainSettings();
    _loadLanguage();
    _loadBannerAd();
    try { AdManager.instance.loadInterstitial(); } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // noop - no clipboard/deep link logic needed
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bannerAd?.dispose();
    super.dispose();
  }

  void _mostraMessaggio(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final lang = prefs.getString('app_lang') ?? 'it';
    AppL.setLang(lang);
    if (mounted) setState(() => _appLang = lang);
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
            const Text(
              'Sei un Personal Trainer?',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Porta i tuoi clienti al livello successivo con l\'ecosistema GymApp Pro.',
              style: TextStyle(color: Colors.white60, fontSize: 15, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ...['✅ Schede personalizzate per ogni atleta', '✅ Monitoraggio progressi in tempo reale', '✅ Database esercizi condiviso', '✅ Senza abbonamenti mensili'].map((v) =>
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Expanded(child: Text(v, style: const TextStyle(color: Colors.white70, fontSize: 14))),
                ]),
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
                label: const Text('Contatta Gianmarco'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _mostraAdEAvviaAllenamento(WorkoutDay day) {
    AdManager.instance.showInterstitialThenRun(() => _startWorkout(day));
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
                      const Text(
                        'Impostazioni',
                        style: TextStyle(color: Colors.white38, fontSize: 12),
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
                'Suono fine timer',
                _stTimerSound,
                (v) {
                  setState(() => _stTimerSound = v);
                  _saveMainSettings();
                },
              ),
              _mainSettingRow(
                Icons.vibration,
                'Vibrazione fine timer',
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
                'Avvia timer automaticamente',
                _stAutoTimer,
                (v) {
                  setState(() => _stAutoTimer = v);
                  _saveMainSettings();
                },
              ),
              _mainSettingRow(
                Icons.screen_lock_portrait_outlined,
                'Schermo sempre acceso',
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
                'Finestra di conferma serie',
                _stConfirmSeries,
                (v) {
                  setState(() => _stConfirmSeries = v);
                  _saveMainSettings();
                },
              ),
              _mainSettingRow(
                Icons.trending_up,
                'Suggerimento aumento peso',
                _stWeightHint,
                (v) {
                  setState(() => _stWeightHint = v);
                  _saveMainSettings();
                },
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
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text('LINGUA / LANGUAGE', style: TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 1.5)),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(children: [
                    Icon(Icons.language, color: Colors.white54, size: 20),
                    SizedBox(width: 12),
                    Text('Lingua / Language', style: TextStyle(color: Colors.white, fontSize: 14)),
                  ]),
                  DropdownButton<String>(
                    value: _appLang,
                    dropdownColor: const Color(0xFF2C2C2E),
                    style: const TextStyle(color: Colors.white),
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'it', child: Text('🇮🇹 Italiano')),
                      DropdownMenuItem(value: 'en', child: Text('🇬🇧 English')),
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
                child: Text('GYMAPP PRO', style: TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 1.5)),
              ),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Text('👨‍💼', style: TextStyle(fontSize: 16)),
                  label: const Text('GymApp Pro - Per PT', style: TextStyle(color: Colors.white70)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                  label: const Text(
                    'Gestione Dati',
                    style: TextStyle(color: Colors.redAccent),
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
                    );
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
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: appAccentNotifier.value, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: appAccentNotifier.value,
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
        leading: null,
        actions: [
          Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.settings_outlined, size: 22),
              onPressed: () => Scaffold.of(ctx).openEndDrawer(),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _currentIndex == 0 ? _buildRoutinePage() : _buildTrainPage()),
          if (_bannerAdLoaded && _bannerAd != null && !kIsWeb)
            SizedBox(
              width: _bannerAd!.size.width.toDouble(),
              height: _bannerAd!.size.height.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        backgroundColor: Colors.black,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.white24,
        type: BottomNavigationBarType.fixed,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.view_list_rounded),
            label: "Scheda",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center_rounded),
            label: "Allenati",
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
            const Text(
              'Nessuna scheda caricata',
              style: TextStyle(color: Colors.white38, fontSize: 16),
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
            label: const Text('Modifica / Crea nuova scheda'),
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
                        'assets/muscle/${day.muscleImage}',
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
                            day.dayName,
                          ),
                          child: Hero(
                            tag: 'muscle_${day.muscleImage}',
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.asset(
                                'assets/muscle/${day.muscleImage}',
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
                          day.dayName,
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
                    label: const Text('Esercizi'),
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
                          'assets/muscle/${day.muscleImage}',
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
            const SizedBox(height: 16),
            // Titolo grafico
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  const Icon(
                    Icons.trending_up_rounded,
                    color: Colors.white38,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'ANDAMENTO ALLENAMENTO',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Grafico
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: _WorkoutProgressChart(
                  day: day,
                  history: history,
                  accent: accent,
                ),
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
                          'assets/muscle/$imageFile',
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
      builder: (c) => Container(
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
                    '${day.exercises.length} esercizi',
                    style: const TextStyle(color: Colors.white24, fontSize: 12),
                  ),
                ],
              ),
            ),
            Divider(color: Colors.white.withAlpha(10), height: 1),
            // Exercise list
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: day.exercises.length,
                separatorBuilder: (_, __) => Divider(
                  color: Colors.white.withAlpha(8),
                  height: 1,
                  indent: 24,
                  endIndent: 24,
                ),
                itemBuilder: (ctx, idx) {
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
                                        color: Colors.deepPurple.withAlpha(80),
                                        borderRadius: BorderRadius.circular(4),
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
                                        ex.name,
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
    );
  }

  void _showExerciseDetail(BuildContext ctx, ExerciseConfig ex) {
    final accent = Theme.of(ctx).colorScheme.primary;
    // Le info seguono la GIF (se presente), altrimenti il nome
    final info = (ex.gifFilename != null ? findByGifSlug(ex.gifFilename!) : null) ??
        findAnyExercise(ex.name);
    final gifPath = ex.gifFilename != null
        ? 'assets/gif/${ex.gifFilename}.gif'
        : info != null ? 'assets/gif/${info.gifSlug}.gif' : null;

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
                    ex.name.toUpperCase(),
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
                info.nameEn,
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
                      'assets/muscle/${info.muscleImages[i]}',
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
                'MUSCOLO PRINCIPALE',
                info.primaryMuscle,
                accent,
              ),
              if (info.secondaryMuscles.isNotEmpty)
                _infoTile(
                  Icons.grain_rounded,
                  'MUSCOLI SECONDARI',
                  info.secondaryMuscles,
                  Colors.white54,
                ),
              const SizedBox(height: 12),
              _sectionCard(
                '📋 ESECUZIONE',
                info.execution,
                const Color(0xFF1C1C1E),
              ),
              const SizedBox(height: 8),
              _sectionCard(
                '💡 CONSIGLI',
                info.tips,
                Colors.amber.withAlpha(15),
              ),
            ] else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Esercizio non in catalogo.\nUsa YouTube per vedere la tecnica.',
                  style: TextStyle(color: Colors.white38, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 16),
            Divider(color: Colors.white12),
            const SizedBox(height: 8),
            Row(
              children: [
                _statChip(
                  '${ex.targetSets} serie',
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
                    '${ex.recoveryTime}s riposo',
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
                label: const Text(
                  'Guarda su YouTube',
                  style: TextStyle(color: Colors.red),
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
      builder: (c) => Container(
        height: MediaQuery.of(context).size.height * 0.72,
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(10),
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
            const Text(
              'Progressi nel tempo — una linea per serie',
              style: TextStyle(color: Colors.white24, fontSize: 11),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: PTGraphWidget(exerciseName: name, history: history),
            ),
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
    if (latest == null) return 'Mai allenato';
    final diff = DateTime.now().difference(latest).inDays;
    if (diff == 0) return 'Oggi';
    if (diff == 1) return 'Ieri';
    return '$diff giorni fa';
  }

  void _startWorkout(WorkoutDay d) async {
    // Cancella SEMPRE lo snapshot precedente: ogni tap su "Allena ora" è una nuova sessione.
    // Il ripristino automatico avviene solo se l'app viene chiusa MID-workout.
    final prefs = await SharedPreferences.getInstance();
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
            const Text(
              'Nessuna scheda caricata',
              style: TextStyle(color: Colors.white38, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Crea la tua scheda prima di allenarti',
              style: TextStyle(color: Colors.white24, fontSize: 13),
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
                      'ALLENATI',
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
                const Text(
                  'Scegli e inizia il tuo allenamento',
                  style: TextStyle(color: Colors.white38, fontSize: 13),
                ),
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
              final isToday = label == 'Oggi';
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
                                    '${d.bodyParts.map((k) => kBodyPartIcons[k] ?? '').where((e) => e.isNotEmpty).join(' ')} ${d.dayName.toUpperCase()}'
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
                                          '${d.exercises.length} esercizi',
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
                                          '${d.exercises.fold(0, (s, ex) => s + ex.targetSets)} serie',
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
                                    '+ ${d.exercises.length - 4} altri',
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
                            onPressed: () => _startWorkout(d),
                            icon: const Icon(
                              Icons.play_arrow_rounded,
                              size: 22,
                            ),
                            label: const Text(
                              'ALLENATI ORA',
                              style: TextStyle(
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
}


// --- COSTRUTTORE SCHEDA AUTONOMO ---
class ScheduleBuilderScreen extends StatefulWidget {
  const ScheduleBuilderScreen({super.key});
  @override
  State<ScheduleBuilderScreen> createState() => _ScheduleBuilderScreenState();
}

class _ScheduleBuilderScreenState extends State<ScheduleBuilderScreen> {
  List<WorkoutDay> _days = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('client_routine') ?? '[]';
    try {
      final list = jsonDecode(raw) as List;
      _days = list.map((e) => WorkoutDay.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      _days = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('client_routine', jsonEncode(_days.map((d) => d.toJson()).toList()));
  }

  void _aggiungiGiorno() {
    final nameCtrl = TextEditingController();
    final List<String> selectedParts = [];
    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(AppL.day, style: const TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: AppL.day,
                  labelStyle: const TextStyle(color: Colors.white54),
                  enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: appAccentNotifier.value)),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: kBodyPartNames.entries.where((e) => e.key != 'nessuno').map((e) {
                  final sel = selectedParts.contains(e.key);
                  return FilterChip(
                    label: Text('${kBodyPartIcons[e.key] ?? ''} ${e.value}', style: TextStyle(fontSize: 12, color: sel ? Colors.black : Colors.white70)),
                    selected: sel,
                    onSelected: (v) => setS(() { if (v) selectedParts.add(e.key); else selectedParts.remove(e.key); }),
                    backgroundColor: Colors.white10,
                    selectedColor: appAccentNotifier.value,
                    checkmarkColor: Colors.black,
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: Text(AppL.cancel, style: const TextStyle(color: Colors.white54))),
            TextButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                Navigator.pop(c);
                setState(() {
                  _days.add(WorkoutDay(dayName: name, bodyParts: List.from(selectedParts), exercises: []));
                });
                _save();
              },
              child: Text(AppL.add, style: TextStyle(color: appAccentNotifier.value, fontWeight: FontWeight.bold)),
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
        title: const Text('Elimina giorno?', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(AppL.cancel)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('ELIMINA', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _days.removeAt(idx));
    _save();
  }

  void _aggiungiEsercizio(int dayIdx) {
    final accent = appAccentNotifier.value;
    final nameCtrl = TextEditingController();
    final setsCtrl = TextEditingController(text: '3');
    final recoveryCtrl = TextEditingController(text: '60');
    final pausaCtrl = TextEditingController(text: '120');

    int currentSets = 3;
    List<TextEditingController> repsCtrls = List.generate(3, (_) => TextEditingController(text: '10'));
    ExerciseInfo? selectedExInfo;
    List<ExerciseInfo> suggestions = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (c) => StatefulBuilder(
        builder: (ctx, setS) {
          void updateSets(String val) {
            final n = (int.tryParse(val) ?? 1).clamp(1, 20);
            setS(() {
              currentSets = n;
              while (repsCtrls.length < n) {
                repsCtrls.add(TextEditingController(text: repsCtrls.isNotEmpty ? repsCtrls.last.text : '10'));
              }
              while (repsCtrls.length > n) {
                repsCtrls.last.dispose();
                repsCtrls.removeLast();
              }
            });
          }

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: DraggableScrollableSheet(
              initialChildSize: 0.9,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (_, scrollCtrl) => ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                children: [
                  Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
                  Text(AppL.exercises, style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 16),

                  // — Nome esercizio
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: AppL.lang == 'en' ? 'Exercise name' : 'Nome esercizio',
                      labelStyle: const TextStyle(color: Colors.white54),
                      suffixIcon: nameCtrl.text.isNotEmpty
                          ? IconButton(icon: const Icon(Icons.clear, color: Colors.white38), onPressed: () { nameCtrl.clear(); setS(() { suggestions = []; selectedExInfo = null; }); })
                          : null,
                      filled: true, fillColor: Colors.black26,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    onChanged: (v) => setS(() => suggestions = searchExercisesWithItalian(v, limit: 6)),
                  ),

                  // — Suggerimenti con GIF
                  if (suggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(color: const Color(0xFF2C2C2E), borderRadius: BorderRadius.circular(12)),
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const ClampingScrollPhysics(),
                        itemCount: suggestions.length,
                        separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                        itemBuilder: (_, i) {
                          final ex = suggestions[i];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            leading: ex.gifFilename != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.asset(
                                      'assets/gif/${ex.gifFilename}.gif',
                                      width: 64, height: 64, fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const SizedBox(width: 64, height: 64, child: Icon(Icons.fitness_center, color: Colors.white30)),
                                    ),
                                  )
                                : const SizedBox(width: 64, height: 64, child: Icon(Icons.fitness_center, color: Colors.white30)),
                            title: Text(ex.name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                            subtitle: ex.primaryMuscle.isNotEmpty && ex.primaryMuscle != 'Muscolatura principale coinvolta'
                                ? Text(ex.primaryMuscle, style: const TextStyle(color: Colors.white38, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis)
                                : null,
                            onTap: () {
                              nameCtrl.text = ex.name;
                              setS(() { suggestions = []; selectedExInfo = ex; });
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
                      setS(() { selectedExInfo = ex; suggestions = []; });
                    }),
                    icon: const Icon(Icons.library_books_rounded, size: 18),
                    label: Text(AppL.browseArchive),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accent,
                      side: BorderSide(color: accent.withAlpha(80)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // — Preview GIF selezionata
                  if (selectedExInfo != null && selectedExInfo!.gifFilename != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/gif/${selectedExInfo!.gifFilename}.gif',
                        height: 160, width: double.infinity, fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                    if (selectedExInfo!.primaryMuscle.isNotEmpty && selectedExInfo!.primaryMuscle != 'Muscolatura principale coinvolta')
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('💪 ${selectedExInfo!.primaryMuscle}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      ),
                    const SizedBox(height: 12),
                  ],

                  // — Serie
                  Row(children: [
                    Expanded(child: TextField(
                      controller: setsCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: AppL.sets,
                        labelStyle: const TextStyle(color: Colors.white54),
                        filled: true, fillColor: Colors.black26,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      onChanged: updateSets,
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(
                      controller: recoveryCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: AppL.recovery,
                        labelStyle: const TextStyle(color: Colors.white54),
                        filled: true, fillColor: Colors.black26,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(
                      controller: pausaCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: AppL.lang == 'en' ? 'Pause (s)' : 'Pausa (s)',
                        labelStyle: const TextStyle(color: Colors.white54),
                        filled: true, fillColor: Colors.black26,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    )),
                  ]),

                  const SizedBox(height: 12),

                  // — Reps per serie
                  Text(AppL.repsPerSet, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: List.generate(currentSets, (i) => SizedBox(
                      width: 58,
                      child: TextField(
                        controller: repsCtrls[i],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'S${i + 1}',
                          labelStyle: const TextStyle(color: Colors.white38, fontSize: 11),
                          filled: true, fillColor: Colors.black26,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                      ),
                    )),
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) return;
                        final sets = (int.tryParse(setsCtrl.text) ?? 3).clamp(1, 20);
                        final repsList = repsCtrls.map((c) => int.tryParse(c.text) ?? 10).toList();
                        final recovery = int.tryParse(recoveryCtrl.text) ?? 60;
                        final pausa = int.tryParse(pausaCtrl.text) ?? 120;
                        final ex = ExerciseConfig(
                          name: name,
                          targetSets: sets,
                          repsList: repsList,
                          recoveryTime: recovery,
                          interExercisePause: pausa,
                          notePT: '',
                          noteCliente: '',
                          gifFilename: selectedExInfo?.gifFilename,
                        );
                        Navigator.pop(c);
                        setState(() => _days[dayIdx].exercises.add(ex));
                        _save();
                      },
                      child: Text(AppL.save, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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

  void _apriArchivioEsercizi(BuildContext context, StateSetter setS, Function(ExerciseInfo) onSelect) {
    String? selectedCategory;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (c) => StatefulBuilder(
        builder: (ctx, setA) {
          // Categorie disponibili (escludi 'altro')
          final cats = kGifCatalog
              .map((e) => e.category)
              .toSet()
              .where((c) => c.isNotEmpty)
              .toList()..sort();

          final exercisesInCat = selectedCategory != null
              ? kGifCatalog.where((e) => e.category == selectedCategory).toList()
              : <ExerciseInfo>[];

          return Container(
            height: MediaQuery.of(ctx).size.height * 0.78,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
                if (selectedCategory != null)
                  Row(children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                      onPressed: () => setA(() => selectedCategory = null),
                    ),
                    Text(selectedCategory!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ])
                else
                  Text(AppL.muscleGroup, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                if (selectedCategory == null)
                  Expanded(
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 8, runSpacing: 8,
                        children: cats.map((cat) {
                          final icon = kBodyPartIcons[cat] ?? '⚡';
                          final label = kBodyPartNames[cat] ?? cat;
                          return ActionChip(
                            avatar: Text(icon, style: const TextStyle(fontSize: 18)),
                            label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
                            backgroundColor: Colors.white10,
                            side: const BorderSide(color: Colors.white12),
                            onPressed: () => setA(() => selectedCategory = cat),
                          );
                        }).toList(),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.85,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                      ),
                      itemCount: exercisesInCat.length,
                      itemBuilder: (_, i) {
                        final ex = exercisesInCat[i];
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
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                    child: ex.gifFilename != null
                                        ? Image.asset(
                                            'assets/gif/${ex.gifFilename}.gif',
                                            fit: BoxFit.cover, width: double.infinity,
                                            errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.fitness_center, color: Colors.white30, size: 32)),
                                          )
                                        : const Center(child: Icon(Icons.fitness_center, color: Colors.white30, size: 32)),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: Text(
                                    ex.name,
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
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

  void _eliminaEsercizio(int dayIdx, int exIdx) {
    setState(() => _days[dayIdx].exercises.removeAt(exIdx));
    _save();
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
            onPressed: () async { await _save(); if (mounted) Navigator.pop(context); },
            child: Text(AppL.save, style: TextStyle(color: accent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _aggiungiGiorno,
        backgroundColor: accent,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: Text(AppL.day),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _days.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.fitness_center_rounded, color: accent.withAlpha(60), size: 64),
                  const SizedBox(height: 16),
                  const Text('Nessun giorno ancora', style: TextStyle(color: Colors.white38, fontSize: 16)),
                  const SizedBox(height: 8),
                  const Text('Premi + per aggiungere il primo giorno', style: TextStyle(color: Colors.white24, fontSize: 13)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: _days.length,
              itemBuilder: (_, dayIdx) {
                final day = _days[dayIdx];
                return Card(
                  color: const Color(0xFF1C1C1E),
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Text(day.bodyParts.map((k) => kBodyPartIcons[k] ?? '').where((e) => e.isNotEmpty).join(' '), style: const TextStyle(fontSize: 22)),
                    title: Text(day.dayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    subtitle: Text('${day.exercises.length} ${AppL.exercises.toLowerCase()}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                          onPressed: () => _eliminaGiorno(dayIdx),
                        ),
                        const Icon(Icons.expand_more, color: Colors.white38),
                      ],
                    ),
                    children: [
                      ...day.exercises.asMap().entries.map((e) {
                        final ex = e.value;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                          leading: ex.gifFilename != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.asset('assets/gif/${ex.gifFilename}.gif', width: 40, height: 40, fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.fitness_center, color: Colors.white30, size: 28)),
                                )
                              : const Icon(Icons.fitness_center_rounded, color: Colors.white30),
                          title: Text(ex.name, style: const TextStyle(color: Colors.white, fontSize: 14)),
                          subtitle: Builder(builder: (context) {
                            final exInfo = findAnyExercise(ex.name);
                            return Row(
                              children: [
                                Text('${ex.targetSets}x${ex.repsList.isNotEmpty ? ex.repsList.first : "?"} | ${ex.recoveryTime}s', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                                if (exInfo != null && exInfo.muscleImages.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Image.asset('assets/muscle/${exInfo.muscleImages.first}', height: 20, width: 20, fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                                ],
                              ],
                            );
                          }),
                          trailing: IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
                            onPressed: () => _eliminaEsercizio(dayIdx, e.key),
                          ),
                        );
                      }),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _aggiungiEsercizio(dayIdx),
                            icon: Icon(Icons.add, color: accent, size: 18),
                            label: Text('${AppL.add} ${AppL.exercises.toLowerCase()}', style: TextStyle(color: accent)),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: accent.withAlpha(80)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
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
  const WorkoutEngine({
    super.key,
    required this.day,
    required this.history,
    required this.onDone,
    this.carryoverWeights = const {},
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
  final Map<int, List<Map<String, dynamic>>> _supersetAccumulated = {};
  // Risultati sessione precedente: nome esercizio → lista serie {w, r}
  final Map<String, List<Map<String, dynamic>>> _previousResults = {};
  // Chiave persistenza allenamento in corso
  String get _inProgressKey => 'workout_in_progress_${widget.day.dayName}';
  // Suono fine timer
  bool _timerSoundEnabled = true;
  bool _vibrationEnabled = true;
  bool _wakelockEnabled = true;
  // Contatore generazione notifica (annulla notifiche di timer precedenti)
  int _notifGen = 0;
  // ID univoco sessione (per separare sessioni stessa giornata nei grafici)
  late final String _sessionId;
  bool _autoStartTimer = true;
  bool _confirmSeriesEnabled = true;
  bool _showWeightSuggestion = true;

  @override
  void initState() {
    super.initState();
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
      });
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
          const SnackBar(
            content: Text('♻️ Allenamento precedente ripristinato'),
            duration: Duration(seconds: 3),
            backgroundColor: Color(0xFF1C1C2E),
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

    if (mounted) Navigator.pop(context);
  }

  Future<bool> _mostraDialogConfermaUscita() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1C1C1E),
            title: const Text(
              "Interrompere?",
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              "Vuoi davvero uscire dall'allenamento? I progressi fin qui fatti sono comunque salvati.",
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  "ANNULLA",
                  style: TextStyle(color: Colors.white38),
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
                  "ESCI E SALVA",
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
  Future<void> _programmaNotificaFine(int secondi) async {
    final gen = ++_notifGen;
    try {
      await Future.delayed(Duration(seconds: secondi));
      if (gen != _notifGen) return;
      if (!mounted) return;

      const androidDetails = AndroidNotificationDetails(
        'timer_gym',
        'Timer Recupero',
        importance: Importance.max,
        priority: Priority.high,
        icon: 'ic_notification', //
      );

      await flutterLocalNotificationsPlugin.show(
        0,
        'Recupero Terminato!',
        'Torna ad allenarti!',
        const NotificationDetails(android: androidDetails),
      );
    } catch (e) {
      debugPrint("Errore notifica: $e");
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_bgTimer != null) _bgTimer!.cancel();
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
    if (state == AppLifecycleState.resumed) {
      flutterLocalNotificationsPlugin.cancelAll();
    }
  }

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
          'Riepilogo allenamento',
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
              'CHIUDI',
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
          perfLabel = 'Prima sessione!';
        } else if (score > 0) {
          perfIcon = Icons.trending_up;
          perfColor = Colors.greenAccent;
          perfLabel = 'In miglioramento!';
        } else if (score < 0) {
          perfIcon = Icons.trending_down;
          perfColor = Colors.redAccent;
          perfLabel = 'In calo';
        } else {
          perfIcon = Icons.trending_flat;
          perfColor = Colors.orangeAccent;
          perfLabel = 'Stallo';
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
                'ALLENAMENTO COMPLETATO!',
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
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Divider(color: Colors.white24),
              const SizedBox(height: 8),
              _recapRow(
                Icons.fitness_center,
                'Esercizi',
                '${_allCompletedExercises.length}',
              ),
              _recapRow(Icons.repeat, 'Serie totali', '$totalSeries'),
              const SizedBox(height: 8),
              const Divider(color: Colors.white24),
              const SizedBox(height: 4),
              Text(
                widget.day.dayName,
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
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
                child: const Text(
                  'DETTAGLI',
                  style: TextStyle(fontWeight: FontWeight.bold),
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
                child: const Text(
                  'OTTIMO LAVORO!',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        );
      },
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

  // Avvia il timer al primo tocco — se è già attivo non fa nulla
  void _avviaTimerSeNonAttivo(int sec) {
    if (timerActive) return; // già in corso, non azzerare
    _triggerTimer(sec, force: true);
  }

  void _triggerTimer(int sec, {bool force = false}) {
    // Se il timer è già attivo e NON stiamo forzando, usciamo subito
    // SENZA cancellare il timer che sta correndo.
    if (timerActive && !force) return;
    if (!_autoStartTimer && !force) return;

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

    // 2. Programmiamo la notifica (una sola, con _notifGen per annullare precedenti)
    _programmaNotificaFine(sec);

    // 3. Timer visivo
    _bgTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_endTime == null) {
        t.cancel();
        return;
      }

      final remaining = _endTime!.difference(DateTime.now()).inSeconds;

      if (remaining <= 0) {
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
    if (kIsWeb) return;
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
      debugPrint("TIMER FINITO!");
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
        const SnackBar(
          content: Text("Inserisci kg e reps prima di confermare"),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    final currentEx = widget.day.exercises[exI];
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
              currentEx.supersetGroup) groupStart--;
      while (groupEnd < widget.day.exercises.length - 1 &&
          widget.day.exercises[groupEnd + 1].supersetGroup ==
              currentEx.supersetGroup) groupEnd++;
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
              "Serie $setN",
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
                    child: const Text("ANNULLA"),
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
                    child: const Text(
                      "SALVA SERIE",
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

    final currentEx = widget.day.exercises[exI];

    // Controlla record personale
    final exHistory = widget.history
        .where((h) => h['exercise'] == currentEx.name)
        .toList();
    double maxPast = 0;
    for (final h in exHistory) {
      for (final s in (h['series'] as List)) {
        final sw = (s['w'] as num).toDouble();
        if (sw > maxPast) maxPast = sw;
      }
    }
    setState(() => _isNewRecord = maxPast > 0 && w > maxPast);

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
          if (mounted) {
            if (!kIsWeb) {
              AdManager.instance.showInterstitialThenRun(_showRecapDialog);
            } else {
              _showRecapDialog();
            }
          }
          return; // Non salvare stato dopo workout completato
        } else if (groupEnd + 1 < widget.day.exercises.length) {
          final pause = widget.day.exercises[groupEnd].interExercisePause > 0
              ? widget.day.exercises[groupEnd].interExercisePause
              : 120;
          setState(() {
            exI = groupEnd + 1;
            setN = 1;
            currentExSeries = [];
            isRestingFullScreen = true;
            _isNewRecord = false;
          });
          _setDrumValues(groupEnd + 1, 1);
          _triggerTimer(pause, force: true); // fine gruppo superset: pausa inter-esercizio
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
        if (mounted) {
          if (!kIsWeb) {
            AdManager.instance.showInterstitialThenRun(_showRecapDialog);
          } else {
            _showRecapDialog();
          }
        }
        return; // Non salvare stato dopo workout completato
      } else if (exI < widget.day.exercises.length - 1) {
        final pauseTime = currentEx.interExercisePause > 0
            ? currentEx.interExercisePause
            : 120;
        setState(() {
          isRestingFullScreen = true;
          exI++;
          setN = 1;
          currentExSeries = [];
          _isNewRecord = false;
        });
        _setDrumValues(exI, 1);
        _triggerTimer(pauseTime, force: true); // fine esercizio: sempre pausa inter-esercizio
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.orange,
            content: Text(
              "Hai completato questo esercizio, ma ne mancano altri! Usa le frecce.",
            ),
          ),
        );
      }
    }
    _persistInProgress();
  }

  void _skipRest() {
    _bgTimer?.cancel();
    try {
      if (!kIsWeb) flutterLocalNotificationsPlugin.cancelAll();
    } catch (_) {}
    setState(() {
      isRestingFullScreen = false;
      timerActive = false;
      _bgCounter = 0;
      _endTime = null;
    });
    try {
      WakelockPlus.disable();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    // 1. DEFINIAMO L'ESERCIZIO ATTUALE
    var ex = widget.day.exercises[exI];

    void _cambiaEsercizio(int nuovoIndice) {
      setState(() {
        // Salviamo i progressi dell'esercizio che stiamo lasciando
        widget.day.exercises[exI].results = List.from(currentExSeries);

        exI = nuovoIndice;
        var nuovoEx = widget.day.exercises[exI];
        currentExSeries = List.from(nuovoEx.results);

        // Se l'esercizio è già stato completato, puntiamo all'ultima serie
        // altrimenti puntiamo alla serie successiva da fare
        if (eserciziCompletati.contains(nuovoEx.name)) {
          setN = nuovoEx.targetSets;
        } else {
          setN = currentExSeries.length + 1;
        }
      });
      _setDrumValues(nuovoIndice, setN);
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
            const Text(
              "ESERCIZIO COMPLETATO",
              style: TextStyle(
                color: Color(0xFF00FF88),
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              "I dati sono stati salvati e non sono più modificabili.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      );
    }

    // 2. CALCOLIAMO COSA FARE DOPO(Logica originale)
    if (setN <= ex.targetSets) {
      _infoProssimo =
          "${ex.name.toUpperCase()}\nSerie $setN di ${ex.targetSets}";
      _prossimoNome = ex.name;
    } else if (exI < widget.day.exercises.length - 1) {
      var prossimoEs = widget.day.exercises[exI + 1];
      _infoProssimo = "CAMBIO ESERCIZIO:\n${prossimoEs.name.toUpperCase()}";
      _prossimoNome = prossimoEs.name;
    } else {
      _infoProssimo = "ALLENAMENTO COMPLETATO!";
      _prossimoNome = '';
    }

    // 3. SE IL TIMER È ATTIVO, MOSTRA LA SCHERMATA NERA (Tua logica originale)
    if (isRestingFullScreen) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Usa il tasto 'SKIP' per tornare all'esercizio"),
            ),
          );
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
        : (ex.recoveryTime > 0 ? ex.recoveryTime : 60);
    final Color accent = Theme.of(context).colorScheme.primary;

    // CONTROLLO CRUCIALE: L'esercizio attuale è nella lista dei completati?
    bool giaFatto = eserciziCompletati.contains(ex.name);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        bool conferma = await _mostraDialogConfermaUscita();
        if (conferma && mounted) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // FRECCIA SINISTRA
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.white),
                onPressed: exI > 0 ? () => _cambiaEsercizio(exI - 1) : null,
              ),

              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      ex.name.toUpperCase(),
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
                      "SERIE FATTE: ${currentExSeries.length} DI ${ex.targetSets}",
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
                onPressed: exI < widget.day.exercises.length - 1
                    ? () => _cambiaEsercizio(exI + 1)
                    : null,
              ),
            ],
          ),
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () async {
              bool conferma = await _mostraDialogConfermaUscita();
              if (conferma) {
                if (mounted) Navigator.pop(context);
              }
            },
          ),
          actions: const [],
        ),
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _triggerTimer(timeToUse, force: false),
          child: Column(
            children: [
              // Compact badges row (only if needed)
              if (_isNewRecord || ex.supersetGroup > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      if (_isNewRecord)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.emoji_events,
                                color: Colors.black,
                                size: 16,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'NUOVO RECORD! 🔥',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (ex.supersetGroup > 0)
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

              // Info panel: ultima volta + notes
              _buildInfoPanel(ex, lastW, lastR, suggerisciAumento, accent, timeToUse),

              // Drums or completed box
              if (giaFatto)
                Expanded(child: Center(child: _buildBoxEsercizioCompletato()))
              else
                Expanded(
                  child: _DrumPickers(
                    key: ValueKey('drum_${exI}_$setN'),
                    initialKg: lastW <= 0 ? 20.0 : lastW,
                    initialReps: targetR,
                    suggerisciAumento:
                        suggerisciAumento && _showWeightSuggestion,
                    accent: accent,
                    onKgChanged: (v) {
                      wC.text = v % 1 == 0
                          ? v.toInt().toString()
                          : v.toStringAsFixed(1);
                    },
                    onRepsChanged: (v) {
                      rC.text = v.toString();
                    },
                    onInteraction: () => _avviaTimerSeNonAttivo(timeToUse),
                  ),
                ),

              // Fixed CONFERMA SERIE
              if (!giaFatto)
                Container(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    12,
                    24,
                    MediaQuery.of(context).padding.bottom + 16,
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
                      child: const Text("CONFERMA SERIE"),
                    ),
                  ),
                ),
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
    wC.text = kg % 1 == 0 ? kg.toInt().toString() : kg.toStringAsFixed(1);
    rC.text = tR.toString();
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
                    'ULTIMA VOLTA: ${lastW % 1 == 0 ? lastW.toInt() : lastW} kg × $lastR reps',
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
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.trending_up_rounded,
                          color: Colors.amber,
                          size: 13,
                        ),
                        SizedBox(width: 3),
                        Text(
                          'AUMENTA',
                          style: TextStyle(
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
            decoration: const InputDecoration(
              hintText: 'Le mie note...',
              hintStyle: TextStyle(color: Colors.white24, fontSize: 12),
              prefixIcon: Icon(
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
              _avviaTimerSeNonAttivo(timeToUse > 0 ? timeToUse : 60);
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
    final info = (gifFilename != null ? findByGifSlug(gifFilename) : null) ??
        findAnyExercise(exName);
    final gifPath = gifFilename != null
        ? 'assets/gif/$gifFilename.gif'
        : info != null ? 'assets/gif/${info.gifSlug}.gif' : null;

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
                    exName.toUpperCase(),
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
                info.nameEn,
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
                        'assets/muscle/${info.muscleImages[i]}',
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
                            'MUSCOLO PRINCIPALE',
                            style: TextStyle(
                              color: accent.withAlpha(180),
                              fontSize: 10,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            info.primaryMuscle,
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
                      '📋 ESECUZIONE',
                      style: TextStyle(
                        color: accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      info.execution,
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
                      '💡 CONSIGLI',
                      style: TextStyle(
                        color: Colors.amber,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      info.tips,
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
                child: const Text(
                  'Esercizio non in catalogo.',
                  style: TextStyle(color: Colors.white38, fontSize: 13),
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
        ? 'assets/gif/${prossimoConfig!.gifFilename}.gif'
        : prossimoInfo != null
            ? 'assets/gif/${prossimoInfo.gifSlug}.gif'
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
                  final ringSize =
                      (constraints.maxHeight * 0.85).clamp(80.0, 320.0);
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
                                  'PROSSIMA',
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
                            // GIF del prossimo esercizio (piccola, inline)
                            if (prossimoGifPath != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.asset(
                                    prossimoGifPath,
                                    height: 90,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) =>
                                        const SizedBox.shrink(),
                                  ),
                                ),
                              ),
                            Text(
                              _infoProssimo,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 3,
                              style: TextStyle(
                                color: accent.withAlpha(210),
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (lastW > 0) ...[
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.history_rounded,
                                    color: Colors.white.withAlpha(70),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'ULTIMA VOLTA\n${lastW}kg × ${lastR} reps',
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 3,
                                    style: TextStyle(
                                      color: Colors.white.withAlpha(160),
                                      fontSize: 17,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (suggerisciAumento) const _AumentaPesoWidget(),
                    // SKIP
                    GestureDetector(
                      onTap: _skipRest,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 60,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.white.withAlpha(40),
                          ),
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
      final setData = s <= prevSeries.length ? prevSeries[s - 1] : prevSeries.last;
      final double weight = (setData['w'] ?? setData['weight'] ?? 0.0).toDouble();
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
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('🔥', style: TextStyle(fontSize: 20)),
              SizedBox(width: 10),
              Text(
                'AUMENTA IL PESO',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  letterSpacing: 1.5,
                ),
              ),
              SizedBox(width: 10),
              Text('🔥', style: TextStyle(fontSize: 20)),
            ],
          ),
        ),
      ),
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

// --- GRAFICO ANDAMENTO ALLENAMENTO (una linea, per sessione) ---
class _DrumPickers extends StatefulWidget {
  final double initialKg;
  final int initialReps;
  final bool suggerisciAumento;
  final Color accent;
  final ValueChanged<double> onKgChanged;
  final ValueChanged<int> onRepsChanged;
  final VoidCallback onInteraction; // chiamato ad ogni scroll

  const _DrumPickers({
    super.key,
    required this.initialKg,
    required this.initialReps,
    required this.suggerisciAumento,
    required this.accent,
    required this.onKgChanged,
    required this.onRepsChanged,
    required this.onInteraction,
  });

  @override
  State<_DrumPickers> createState() => _DrumPickersState();
}

class _DrumPickersState extends State<_DrumPickers>
    with SingleTickerProviderStateMixin {
  // 0-100 kg a step di 2.5, poi 105-300 a step di 5
  static final List<double> _kgValues = [
    ...List.generate(41, (i) => i * 2.5),
    ...List.generate(40, (i) => 105.0 + i * 5.0),
  ];
  static final List<int> _repsValues = List.generate(50, (i) => i + 1);

  static int _kgToIndex(double kg) {
    if (kg <= 100) return (kg / 2.5).round().clamp(0, 40);
    return (40 + ((kg - 100) / 5).round()).clamp(0, 80);
  }

  late FixedExtentScrollController _kgCtrl;
  late FixedExtentScrollController _repsCtrl;
  late int _selKg;
  late int _selReps;
  bool _interacted = false;

  // Animazione freccia suggerimento aumento peso
  late AnimationController _arrowCtrl;
  late Animation<double> _arrowAnim;

  @override
  void initState() {
    super.initState();
    _selKg = _kgToIndex(widget.initialKg);
    _selReps = (widget.initialReps - 1).clamp(0, 49);
    _kgCtrl = FixedExtentScrollController(initialItem: _selKg);
    _repsCtrl = FixedExtentScrollController(initialItem: _selReps);

    _arrowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _arrowAnim = Tween<double>(begin: 0, end: -10).animate(
      CurvedAnimation(parent: _arrowCtrl, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onKgChanged(_kgValues[_selKg]);
      widget.onRepsChanged(_repsValues[_selReps]);
    });
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

  void _editValue({required bool isKg}) {
    final textCtrl = TextEditingController(
      text: isKg
          ? (_kgValues[_selKg] % 1 == 0
                ? _kgValues[_selKg].toInt().toString()
                : _kgValues[_selKg].toStringAsFixed(1))
          : _repsValues[_selReps].toString(),
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1E),
        title: Text(
          isKg ? 'Inserisci KG' : 'Inserisci REPS',
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
            child: const Text(
              'Annulla',
              style: TextStyle(color: Colors.white38),
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
      int best = 0;
      double bestDiff = double.infinity;
      for (int i = 0; i < _kgValues.length; i++) {
        final diff = (_kgValues[i] - v).abs();
        if (diff < bestDiff) {
          bestDiff = diff;
          best = i;
        }
      }
      setState(() => _selKg = best);
      _kgCtrl.animateToItem(
        best,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      widget.onKgChanged(_kgValues[best]);
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
    final bool showNudge = isKg && highlightAbove &&
        selectedIdx < items.length &&
        (items[selectedIdx] as double) <= referenceKg;

    // Dimensioni e opacità basate sulla distanza dal centro
    double _itemSize(int dist) {
      switch (dist) {
        case 0: return 82;
        case 1: return 54;
        case 2: return 38;
        default: return 26;
      }
    }
    int _itemAlpha(int dist) {
      switch (dist) {
        case 0: return 255;
        case 1: return 160;
        case 2: return 100;
        default: return 55;
      }
    }
    FontWeight _itemWeight(int dist) {
      switch (dist) {
        case 0: return FontWeight.w700;
        case 1: return FontWeight.w500;
        default: return FontWeight.w300;
      }
    }

    return Column(
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
              ListWheelScrollView.useDelegate(
                controller: ctrl,
                itemExtent: 96,
                diameterRatio: 1.2,
                perspective: 0.003,
                squeeze: 0.85,
                physics: const FixedExtentScrollPhysics(),
                onSelectedItemChanged: (i) {
                  setState(() {
                    if (isKg) _selKg = i;
                    else _selReps = i;
                  });
                  onChanged(i);
                  _triggerInteraction();
                },
                childDelegate: ListWheelChildBuilderDelegate(
                  childCount: items.length,
                  builder: (ctx, i) {
                    final dist = (i - selectedIdx).abs();
                    final isSel = dist == 0;
                    final isAmber = isKg && highlightAbove && isSel &&
                        (items[i] as double) > referenceKg;
                    final color = isSel
                        ? (isAmber ? Colors.amber : accent)
                        : Colors.white.withAlpha(_itemAlpha(dist));
                    final textWidget = Text(
                      formatter(items[i]),
                      style: TextStyle(
                        fontSize: _itemSize(dist),
                        height: 1.0,
                        color: color,
                        fontWeight: _itemWeight(dist),
                        letterSpacing: isSel ? 1 : 0,
                      ),
                    );
                    return Center(
                      child: isSel
                          ? GestureDetector(
                              onTap: () => _editValue(isKg: isKg),
                              child: textWidget,
                            )
                          : textWidget,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildDrum(
              ctrl: _kgCtrl,
              items: _kgValues,
              selectedIdx: _selKg,
              label: 'KG',
              onChanged: (i) => widget.onKgChanged(_kgValues[i]),
              formatter: (v) {
                final d = v as double;
                return d % 1 == 0 ? d.toInt().toString() : d.toStringAsFixed(1);
              },
              highlightAbove: widget.suggerisciAumento,
              referenceKg: widget.initialKg,
              isKg: true,
            ),
          ),
          Container(
            width: 1,
            color: Colors.white10,
            margin: const EdgeInsets.symmetric(vertical: 40),
          ),
          Expanded(
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
      final sessionKey =
          (h['session_id'] as String?)?.isNotEmpty == true
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
      return const Center(
        child: Text(
          'Nessun dato registrato',
          style: TextStyle(color: Colors.white38),
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
      final dd = d.length >= 10 ? '${d.substring(8, 10)}/${d.substring(5, 7)}' : d;
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
    final n = labels.length;

    for (int i = 0; i < n; i++) {
      final x = n == 1 ? size.width / 2 : size.width / (n - 1) * i;
      final norm = flat ? 0.5 : (scores[i] - minS) / range;
      final y = size.height * 0.9 - (size.height * 0.8 * norm.clamp(0.0, 1.0));
      if (i == 0)
        path.moveTo(x, y);
      else
        path.lineTo(x, y);
    }
    canvas.drawPath(path, linePaint);

    // Punti + etichette data
    for (int i = 0; i < n; i++) {
      final x = n == 1 ? size.width / 2 : size.width / (n - 1) * i;
      final norm = flat ? 0.5 : (scores[i] - minS) / range;
      final y = size.height * 0.9 - (size.height * 0.8 * norm.clamp(0.0, 1.0));
      canvas.drawCircle(Offset(x, y), 5, dotBg);
      canvas.drawCircle(Offset(x, y), 4, dotPaint);

      if (n <= 8 || i % ((n / 6).ceil()) == 0) {
        final tp = TextPainter(
          text: TextSpan(
            text: labels[i],
            style: const TextStyle(color: Colors.white38, fontSize: 9),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
          canvas,
          Offset(
            (x - tp.width / 2).clamp(0, size.width - tp.width),
            size.height - 14,
          ),
        );
      }
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

    if (logs.isEmpty) return const Center(child: Text("Nessun dato"));

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
              ? const Center(child: Text("Nessun dato"))
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
      bool first = true;

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
            first = false;
          } else
            path.lineTo(x, y);
          canvas.drawCircle(Offset(x, y), 3, Paint()..color = color);
        }
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
    return byDay.entries
        .where((e) => e.value.isNotEmpty)
        .toList();
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
      const SnackBar(
        content: Text('Dati eliminati'),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  Future<void> _resetTotale() async {
    final ok1 = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text(
          'Reset completo',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Eliminerà TUTTI i dati: scheda, storico e impostazioni.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ANNULLA'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'CONTINUA',
              style: TextStyle(color: Colors.redAccent),
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
        title: const Text('Sei sicuro?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Operazione irreversibile.',
          style: TextStyle(color: Colors.red),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ANNULLA'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'CANCELLA TUTTO',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (ok2 != true || !mounted) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pop(context);
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
        title: const Row(
          children: [
            Icon(Icons.storage_rounded, color: Colors.redAccent, size: 20),
            SizedBox(width: 8),
            Text(
              'Gestione Dati',
              style: TextStyle(
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
                      'Nessuno storico presente',
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
                                    '${sessions.length} session${sessions.length == 1 ? 'e' : 'i'}',
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
                    'Elimina selezionati (${_selected.length})',
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
              'RESET TOTALE',
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
                label: const Text(
                  'Reset completo dati',
                  style: TextStyle(color: Colors.redAccent),
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
        title: const Text(
          'Elimina sessione?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Tutti i dati di questa sessione verranno eliminati.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ANNULLA'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'ELIMINA',
              style: TextStyle(color: Colors.redAccent),
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
        const SnackBar(
          content: Text('Sessione eliminata'),
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
        title: const Text(
          'Elimina serie?',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ANNULLA'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'ELIMINA',
              style: TextStyle(color: Colors.redAccent),
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
              decoration: const InputDecoration(
                labelText: 'Peso (kg)',
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: UnderlineInputBorder(
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
            child: const Text('ANNULLA'),
          ),
          TextButton(
            onPressed: () async {
              final newW = double.tryParse(wCtrl.text) ?? 0.0;
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
            child: const Text(
              'SALVA',
              style: TextStyle(color: Color(0xFF00F2FF)),
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
                'Nessuna sessione',
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
                              tooltip: 'Elimina sessione',
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
