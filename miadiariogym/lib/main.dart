import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:fl_chart/fl_chart.dart';

class ExerciseChart extends StatelessWidget {
  final String exerciseName;
  final List<SetLog> history;

  const ExerciseChart({
    super.key,
    required this.exerciseName,
    required this.history,
  });

  @override
  Widget build(BuildContext context) {
    // Filtriamo i log per l'esercizio scelto e prendiamo solo il peso massimo per ogni data
    List<SetLog> filtered = history
        .where((l) => l.exerciseName == exerciseName)
        .toList();
    filtered.sort((a, b) => a.date.compareTo(b.date));

    if (filtered.isEmpty)
      return const Center(child: Text("Nessun dato disponibile"));

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: filtered.asMap().entries.map((e) {
              return FlSpot(e.key.toDouble(), e.value.weight);
            }).toList(),
            isCurved: true,
            color: const Color(0xFF00F2FF),
            barWidth: 4,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF00F2FF).withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GymLogbook());
}

class GymLogbook extends StatelessWidget {
  const GymLogbook({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00F2FF),
          secondary: Color(0xFF7000FF),
          surface: Color(0xFF121212),
        ),
      ),
      home: const MainNavigation(),
    );
  }
}

// --- MODELLI DATI ---
class ExerciseConfig {
  String name;
  int targetSets;
  List<int> repsList;
  int recoveryTime;
  int interExercisePause; // Rimuovi 'required' se lo avevi messo

  ExerciseConfig({
    required this.name,
    required this.targetSets,
    required this.repsList,
    required this.recoveryTime,
    this.interExercisePause = 180, // Default 3 minuti
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'targetSets': targetSets,
    'repsList': repsList,
    'recoveryTime': recoveryTime,
    'interExercisePause': interExercisePause,
  };

  factory ExerciseConfig.fromJson(Map<String, dynamic> json) => ExerciseConfig(
    name: json['name'],
    targetSets: json['targetSets'],
    repsList: List<int>.from(json['repsList']),
    recoveryTime: json['recoveryTime'],
    interExercisePause: json['interExercisePause'] ?? 180, // Se nullo, usa 180
  );
}

class WorkoutDay {
  String dayName;
  List<ExerciseConfig> exercises;

  WorkoutDay({required this.dayName, required this.exercises});

  Map<String, dynamic> toJson() => {
    'dayName': dayName,
    'exercises': exercises.map((e) => e.toJson()).toList(),
  };
  factory WorkoutDay.fromJson(Map<String, dynamic> json) => WorkoutDay(
    dayName: json['dayName'],
    exercises: (json['exercises'] as List)
        .map((e) => ExerciseConfig.fromJson(e))
        .toList(),
  );
}

class SetLog {
  final String exerciseName;
  final double weight;
  final int reps;
  final DateTime date;

  SetLog({
    required this.exerciseName,
    required this.weight,
    required this.reps,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
    'ex': exerciseName,
    'w': weight,
    'r': reps,
    'd': date.toIso8601String(),
  };
  factory SetLog.fromJson(Map<String, dynamic> json) => SetLog(
    exerciseName: json['ex'],
    weight: (json['w'] as num).toDouble(),
    reps: json['r'],
    date: DateTime.parse(json['d']),
  );
}

// --- MAIN NAVIGATION ---
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});
  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  final LocalAuthentication auth = LocalAuthentication();
  List<WorkoutDay> myRoutine = [];
  List<SetLog> history = [];
  bool isPTMode = false;
  final String _masterPassword = "osare199";
  final List<String> commonExercises = [
    "Panca Piana",
    "Squat",
    "Stacco da Terra",
    "Military Press",
    "Trazioni",
    "Rematore",
    "Leg Press",
    "Curl Bilanciere",
    "Lat Machine",
    "Dips",
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      final rS = prefs.getString('my_routine');
      final hS = prefs.getString('workout_history');
      if (rS != null)
        myRoutine = (jsonDecode(rS) as List)
            .map((i) => WorkoutDay.fromJson(i))
            .toList();
      if (hS != null)
        history = (jsonDecode(hS) as List)
            .map((i) => SetLog.fromJson(i))
            .toList();
    });
  }

  Future<void> _saveAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'my_routine',
      jsonEncode(myRoutine.map((d) => d.toJson()).toList()),
    );
    await prefs.setString(
      'workout_history',
      jsonEncode(history.map((h) => h.toJson()).toList()),
    );
  }

  // --- LOGICA IMPORT / EXPORT PROTOCOLLO ---
  void _exportProtocol() {
    Clipboard.setData(
      ClipboardData(
        text: jsonEncode(myRoutine.map((d) => d.toJson()).toList()),
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Protocollo PT copiato negli appunti!")),
    );
  }

  void _importProtocol() {
    String input = "";
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Importa Protocollo"),
        content: TextField(
          maxLines: 4,
          onChanged: (v) => input = v,
          decoration: const InputDecoration(hintText: "Incolla JSON qui"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text("ANNULLA"),
          ),
          ElevatedButton(
            onPressed: () {
              try {
                final decoded = jsonDecode(input) as List;
                setState(() {
                  myRoutine = decoded
                      .map((i) => WorkoutDay.fromJson(i))
                      .toList();
                });
                _saveAll();
                Navigator.pop(c);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Errore nel formato")),
                );
              }
            },
            child: const Text("IMPORTA"),
          ),
        ],
      ),
    );
  }

  // --- LOGICA IMPORT / EXPORT LOG (PROGRESSI CLIENTE) ---
  void _exportLogs() {
    Clipboard.setData(
      ClipboardData(text: jsonEncode(history.map((h) => h.toJson()).toList())),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Progressi copiati! Inviali al tuo PT.")),
    );
  }

  void _clearRoutine() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Reset Scheda"),
        content: const Text("Vuoi cancellare l'intera scheda attuale?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text("NO"),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => myRoutine = []);
              _saveAll();
              Navigator.pop(c);
            },
            child: const Text("SÌ, CANCELLA"),
          ),
        ],
      ),
    );
  }

  void _clearHistory() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Reset Storico"),
        content: const Text("Vuoi cancellare tutti i log e i grafici?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text("NO"),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => history = []);
              _saveAll();
              Navigator.pop(c);
            },
            child: const Text("SÌ, RESETTA GRAFICI"),
          ),
        ],
      ),
    );
  }

  void _importLogs() {
    String input = "";
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Importa Progressi Cliente"),
        content: TextField(maxLines: 4, onChanged: (v) => input = v),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text("ANNULLA"),
          ),
          ElevatedButton(
            onPressed: () {
              try {
                final decoded = jsonDecode(input) as List;
                setState(() {
                  history = decoded.map((i) => SetLog.fromJson(i)).toList();
                });
                _saveAll();
                Navigator.pop(c);
              } catch (e) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text("Errore dati")));
              }
            },
            child: const Text("CARICA"),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePTAccess() async {
    if (isPTMode) {
      setState(() => isPTMode = false);
      return;
    }
    try {
      bool authenticated = await auth.authenticate(
        localizedReason: 'Accesso Core Analytics',
      );
      if (authenticated) {
        setState(() => isPTMode = true);
      }
    } catch (e) {
      _showPasswordDialog();
    }
  }

  void _showPasswordDialog() {
    String input = "";
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Area PT"),
        content: TextField(
          obscureText: true,
          onChanged: (v) => input = v,
          decoration: const InputDecoration(hintText: "Password"),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              if (input == _masterPassword) {
                setState(() => isPTMode = true);
                Navigator.pop(c);
              }
            },
            child: const Text("SBLOCCA"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.black,
          centerTitle: true,
          title: Text(
            isPTMode ? "CORE ANALYTICS" : "GYM LOGBOOK",
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: Color(0xFF00F2FF),
              letterSpacing: 2,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.upload, color: Colors.orangeAccent),
              onPressed: _importProtocol,
            ),
            if (isPTMode)
              IconButton(
                icon: const Icon(Icons.download, color: Colors.greenAccent),
                onPressed: _exportProtocol,
              ),
            IconButton(
              icon: Icon(
                isPTMode ? Icons.radar : Icons.fingerprint,
                color: const Color(0xFF7000FF),
              ),
              onPressed: _handlePTAccess,
            ),
          ],
          bottom: const TabBar(
            dividerColor: Colors.transparent,
            indicatorColor: Color(0xFF00F2FF),
            tabs: [
              Tab(text: "PLAN"),
              Tab(text: "TRAIN"),
            ],
          ),
        ),
        body: TabBarView(
          children: [_buildRoutinePage(), _buildWorkoutSelector()],
        ),
      ),
    );
  }

  // --- UI PIANIFICAZIONE (CON QUADRATINI E GRAFICI) ---
  Widget _buildRoutinePage() => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      if (isPTMode)
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: ElevatedButton.icon(
            onPressed: _addNewDay,
            icon: const Icon(Icons.add),
            label: const Text("NUOVO GIORNO"),
          ),
        ),
      ...myRoutine.asMap().entries.map(
        (entry) => Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            title: Text(
              entry.value.dayName,
              style: const TextStyle(
                color: Color(0xFF00F2FF),
                fontWeight: FontWeight.bold,
              ),
            ),
            children: [
              // --- UI PIANIFICAZIONE (CON ICONA GRAFICO PER TUTTI) ---
              ...entry.value.exercises.asMap().entries.map(
                (ex) => ListTile(
                  // 1. Icona del grafico a sinistra per far capire che è cliccabile
                  leading: const Icon(
                    Icons.show_chart,
                    color: Color(0xFF00F2FF),
                    size: 24,
                  ),
                  title: Text(
                    ex.value.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    "${ex.value.targetSets} serie - Target: ${ex.value.repsList.join('-')}",
                  ),
                  // 2. Il tocco funziona per TUTTI (PT e Cliente)
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled:
                          true, // Permette al grafico di avere più spazio
                      backgroundColor: const Color(0xFF121212),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(25),
                        ),
                      ),
                      builder: (c) => Container(
                        padding: const EdgeInsets.all(20),
                        height:
                            MediaQuery.of(context).size.height *
                            0.6, // 60% dello schermo
                        child: Column(
                          children: [
                            Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              "STORICO CARICHI: ${ex.value.name.toUpperCase()}",
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF00F2FF),
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 30),
                            // Il grafico recupera i dati dalla history locale del cliente o del PT
                            Expanded(
                              child: ExerciseChart(
                                exerciseName: ex.value.name,
                                history: history,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.info_outline,
                                  size: 12,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 5),
                                const Text(
                                  "Il grafico mostra il miglior peso per ogni sessione",
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                          ],
                        ),
                      ),
                    );
                  },
                  // 3. Il tasto Edit resta solo per il PT
                  trailing: isPTMode
                      ? IconButton(
                          icon: const Icon(
                            Icons.edit,
                            color: Colors.blueAccent,
                          ),
                          onPressed: () =>
                              _showExDialog(dayIdx: entry.key, exIdx: ex.key),
                        )
                      : const Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.white10,
                          size: 14,
                        ),
                ),
              ),
              if (isPTMode)
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Color(0xFF00F2FF)),
                  onPressed: () => _showExDialog(dayIdx: entry.key),
                ),
            ],
          ),
        ),
      ),
    ],
  );

  void _showExDialog({required int dayIdx, int? exIdx}) {
    bool isEdit = exIdx != null;
    var existingEx = isEdit ? myRoutine[dayIdx].exercises[exIdx] : null;

    // 1. DICHIARAZIONI (Definiamo tutto PRIMA di usarlo)
    String name = existingEx?.name ?? "";
    int sets = existingEx?.targetSets ?? 3;
    int rec = existingEx?.recoveryTime ?? 90;
    int pause = existingEx?.interExercisePause ?? 180;

    List<TextEditingController> ctrls = List.generate(12, (i) {
      return TextEditingController(
        text: isEdit && i < existingEx!.repsList.length
            ? existingEx.repsList[i].toString()
            : "10",
      );
    });
    List<FocusNode> nodes = List.generate(12, (i) => FocusNode());

    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: Text(isEdit ? "Modifica Esercizio" : "Nuovo Esercizio"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Autocomplete<String>(
                  optionsBuilder: (v) => commonExercises.where(
                    (s) => s.toLowerCase().contains(v.text.toLowerCase()),
                  ),
                  initialValue: TextEditingValue(text: name),
                  onSelected: (s) => name = s,
                  fieldViewBuilder: (ctx, ctrl, focus, onSub) => TextField(
                    controller: ctrl,
                    focusNode: focus,
                    decoration: const InputDecoration(labelText: "Esercizio"),
                    onChanged: (v) => name = v,
                  ),
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(labelText: "Serie"),
                        keyboardType: TextInputType.number,
                        onChanged: (v) {
                          setS(() {
                            sets = int.tryParse(v) ?? 1;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: "Recupero (s)",
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (v) => rec = int.tryParse(v) ?? 90,
                      ),
                    ),
                  ],
                ),
                TextField(
                  decoration: const InputDecoration(
                    labelText: "Pausa Cambio Es. (s)",
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => pause = int.tryParse(v) ?? 180,
                ),
                const SizedBox(height: 15),
                const Text(
                  "Suggerimenti Reps Target",
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
                Wrap(
                  spacing: 5,
                  children: [6, 8, 10, 12, 15].map((v) {
                    return ActionChip(
                      label: Text("$v"),
                      onPressed: () {
                        setS(() {
                          for (var i = 0; i < sets; i++) {
                            ctrls[i].text = v.toString();
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 15),
                const Text(
                  "Dettaglio Serie (Quadratini)",
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(sets, (i) {
                    return SizedBox(
                      width: 45,
                      child: TextField(
                        controller: ctrls[i],
                        focusNode: nodes[i],
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.zero,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) {
                          if (v.length >= 2 ||
                              (v.isNotEmpty && int.parse(v) > 1)) {
                            if (i < sets - 1) {
                              nodes[i + 1].requestFocus();
                            }
                          }
                        },
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                // CREIAMO E SALVIAMO L'ESERCIZIO
                var newEx = ExerciseConfig(
                  name: name,
                  targetSets: sets,
                  repsList: ctrls
                      .take(sets)
                      .map((e) => int.tryParse(e.text) ?? 10)
                      .toList(),
                  recoveryTime: rec,
                  interExercisePause: pause,
                );

                setState(() {
                  if (isEdit) {
                    myRoutine[dayIdx].exercises[exIdx] = newEx;
                  } else {
                    myRoutine[dayIdx].exercises.add(newEx);
                  }
                });
                _saveAll();
                Navigator.pop(c);
              },
              child: const Text("SALVA"),
            ),
          ],
        ),
      ),
    );
  }

  void _addNewDay() {
    String n = "";
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Nome Giorno"),
        content: TextField(onChanged: (v) => n = v),
        actions: [
          ElevatedButton(
            onPressed: () {
              if (n.isNotEmpty) {
                setState(
                  () => myRoutine.add(WorkoutDay(dayName: n, exercises: [])),
                );
                _saveAll();
              }
              Navigator.pop(c);
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutSelector() => Column(
    children: [
      Expanded(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: myRoutine
              .map(
                (d) => Card(
                  child: ListTile(
                    title: Text(
                      d.dayName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: const Icon(
                      Icons.play_circle,
                      color: Color(0xFF00F2FF),
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => WorkoutEngine(
                          day: d,
                          history: history,
                          onDone: (l) {
                            setState(() => history.addAll(l));
                            _saveAll();
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
      Container(
        color: Colors.white10,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: SingleChildScrollView(
          // Per evitare overflow su schermi piccoli
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              TextButton.icon(
                icon: const Icon(Icons.share),
                label: const Text("Esporta Log"),
                onPressed: _exportLogs,
              ),
              if (isPTMode) ...[
                TextButton.icon(
                  icon: const Icon(Icons.analytics),
                  label: const Text("Importa Log"),
                  onPressed: _importLogs,
                ),
                TextButton.icon(
                  icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
                  label: const Text("Reset Scheda"),
                  onPressed: _clearRoutine,
                ),
                TextButton.icon(
                  icon: const Icon(Icons.history, color: Colors.orangeAccent),
                  label: const Text("Reset Storico"),
                  onPressed: _clearHistory,
                ),
              ],
            ],
          ),
        ),
      ),
    ],
  );
}

// --- ENGINE WORKOUT (CON BOTTONI DINAMICI) ---
class WorkoutEngine extends StatefulWidget {
  final WorkoutDay day;
  final List<SetLog> history;
  final Function(List<SetLog>) onDone;
  const WorkoutEngine({
    super.key,
    required this.day,
    required this.history,
    required this.onDone,
  });
  @override
  State<WorkoutEngine> createState() => _WorkoutEngineState();
}

class _WorkoutEngineState extends State<WorkoutEngine> {
  int exI = 0;
  int setN = 1;
  List<SetLog> session = [];
  final wC = TextEditingController();
  final rC = TextEditingController();
  int _counter = 0;
  Timer? _timer;
  bool isResting = false;

  // Sostituisci la vecchia funzione con questa:
  void _startTimer(int seconds, String label) {
    // Ora accetta i parametri
    setState(() {
      isResting = true;
      _counter = seconds;
      // Puoi aggiungere una variabile String currentLabel = label; per mostrarla nella UI
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_counter > 0) {
        setState(() => _counter--);
      } else {
        _stopTimer();
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() => isResting = false);
    HapticFeedback.vibrate();
  }

  void _saveSet() {
    double w = double.tryParse(wC.text) ?? 0;
    int r = int.tryParse(rC.text) ?? 0;
    if (w == 0 || r == 0) return;

    session.add(
      SetLog(
        exerciseName: widget.day.exercises[exI].name,
        weight: w,
        reps: r,
        date: DateTime.now(),
      ),
    );

    if (setN < widget.day.exercises[exI].targetSets) {
      // Stesso esercizio -> RECUPERO
      _startTimer(widget.day.exercises[exI].recoveryTime, "RECUPERO SERIE");
      setN++;
      wC.clear();
      rC.clear();
    } else if (exI < widget.day.exercises.length - 1) {
      // Cambio esercizio -> PAUSA LUNGA
      _startTimer(
        widget.day.exercises[exI].interExercisePause,
        "PAUSA CAMBIO ESERCIZIO",
      );
      exI++;
      setN = 1;
      wC.clear();
      rC.clear();
    } else {
      // Fine workout
      widget.onDone(session);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    var ex = widget.day.exercises[exI];
    double lastW = 0;
    try {
      lastW = widget.history.lastWhere((l) => l.exerciseName == ex.name).weight;
    } catch (_) {
      lastW = 0;
    }
    int targetR = (setN <= ex.repsList.length) ? ex.repsList[setN - 1] : 10;

    return Scaffold(
      appBar: AppBar(title: Text(ex.name), backgroundColor: Colors.black),
      body: Padding(
        padding: const EdgeInsets.all(25),
        child: isResting
            ? _buildRestUI()
            : SingleChildScrollView(
                child: Column(
                  children: [
                    Text(
                      "SERIE $setN / ${ex.targetSets}",
                      style: const TextStyle(
                        fontSize: 22,
                        color: Color(0xFF00F2FF),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      "KG (Ultima volta: al centro)",
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 7,
                      children:
                          [
                                lastW - 5,
                                lastW - 2.5,
                                lastW,
                                lastW + 2.5,
                                lastW + 5,
                              ]
                              .where((v) => v >= 0)
                              .map(
                                (v) => ActionChip(
                                  backgroundColor: v == lastW
                                      ? const Color(0xFF7000FF).withAlpha(100)
                                      : null,
                                  label: Text("${v}kg"),
                                  onPressed: () =>
                                      setState(() => wC.text = v.toString()),
                                ),
                              )
                              .toList(),
                    ),
                    TextField(
                      controller: wC,
                      decoration: const InputDecoration(
                        labelText: "KG Effettivi",
                      ),
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      "REPS (Target: al centro)",
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 7,
                      children:
                          [
                                targetR - 2,
                                targetR - 1,
                                targetR,
                                targetR + 1,
                                targetR + 2,
                              ]
                              .where((v) => v > 0)
                              .map(
                                (v) => ActionChip(
                                  backgroundColor: v == targetR
                                      ? const Color(0xFF00F2FF).withAlpha(100)
                                      : null,
                                  label: Text("$v"),
                                  onPressed: () =>
                                      setState(() => rC.text = v.toString()),
                                ),
                              )
                              .toList(),
                    ),
                    TextField(
                      controller: rC,
                      decoration: const InputDecoration(
                        labelText: "REPS Effettive",
                      ),
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    ElevatedButton(
                      onPressed: _saveSet,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 60),
                        backgroundColor: const Color(0xFF00F2FF),
                      ),
                      child: const Text(
                        "SALVA SERIE",
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildRestUI() => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Text(
        "RECUPERO",
        style: TextStyle(letterSpacing: 4, color: Color(0xFF00F2FF)),
      ),
      Center(
        child: Text(
          "$_counter",
          style: const TextStyle(fontSize: 110, fontWeight: FontWeight.bold),
        ),
      ),
      const SizedBox(height: 20),
      TextButton(onPressed: _stopTimer, child: const Text("SALTA")),
    ],
  );
}
