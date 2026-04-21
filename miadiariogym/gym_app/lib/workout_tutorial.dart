import 'package:flutter/material.dart';
import 'dart:async';

/// Tutorial interattivo per il primo workout
class WorkoutTutorial extends StatefulWidget {
  final Color accentColor;
  final VoidCallback onComplete;

  const WorkoutTutorial({
    super.key,
    required this.accentColor,
    required this.onComplete,
  });

  @override
  State<WorkoutTutorial> createState() => _WorkoutTutorialState();
}

class _WorkoutTutorialState extends State<WorkoutTutorial> with TickerProviderStateMixin {
  late PageController _pageController;
  int _currentStep = 0;
  int _seriesCount = 1;
  int _exerciseIndex = 0;
  bool _weightEntered = false;
  bool _repsEntered = false;
  String _enteredWeight = '';
  String _enteredReps = '';
  int _recoveryTimeLeft = 10;
  Timer? _recoveryTimer;
  bool _showRecoveryTimer = false;
  bool _canSkip = false;

  final List<Map<String, dynamic>> _exercises = [
    {'name': 'Panca Piana', 'emoji': '🏋️'},
    {'name': 'Trazioni', 'emoji': '💪'},
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _canSkip = true);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _recoveryTimer?.cancel();
    super.dispose();
  }

  void _startRecoveryTimer() {
    _recoveryTimer?.cancel();
    _recoveryTimeLeft = 10;
    _showRecoveryTimer = true;
    setState(() {});

    _recoveryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_recoveryTimeLeft <= 0) {
        timer.cancel();
        _showRecoveryTimer = false;
        if (_seriesCount < 3) {
          setState(() {
            _seriesCount++;
            _weightEntered = false;
            _repsEntered = false;
            _enteredWeight = '';
            _enteredReps = '';
          });
        } else {
          // Cambio esercizio
          _seriesCount = 1;
          _exerciseIndex++;
          _weightEntered = false;
          _repsEntered = false;
          _enteredWeight = '';
          _enteredReps = '';
          if (_exerciseIndex >= _exercises.length) {
            _showCompletionScreen();
            return;
          }
        }
        setState(() {});
      } else {
        setState(() => _recoveryTimeLeft--);
      }
    });
  }

  void _addWeightButtonPress(String value) {
    final newWeight = _enteredWeight + value;
    if (newWeight.length <= 4) {
      setState(() => _enteredWeight = newWeight);
    }
  }

  void _addRepsButtonPress(String value) {
    final newReps = _enteredReps + value;
    if (newReps.length <= 2) {
      setState(() => _enteredReps = newReps);
    }
  }

  void _confirmSeries() {
    if (_enteredWeight.isNotEmpty && _enteredReps.isNotEmpty) {
      setState(() {
        _weightEntered = true;
        _repsEntered = true;
      });
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _startRecoveryTimer();
        }
      });
    }
  }

  void _backspace(String field) {
    if (field == 'weight' && _enteredWeight.isNotEmpty) {
      setState(() => _enteredWeight = _enteredWeight.substring(0, _enteredWeight.length - 1));
    } else if (field == 'reps' && _enteredReps.isNotEmpty) {
      setState(() => _enteredReps = _enteredReps.substring(0, _enteredReps.length - 1));
    }
  }

  void _showCompletionScreen() {
    setState(() => _currentStep = 99);
  }

  void _nextStep() {
    if (_currentStep < 5) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep++);
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep--);
    }
  }

  void _skipTutorial() {
    if (_canSkip) {
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentStep == 99) {
      return _buildCompletionScreen();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0E0E10),
      body: SafeArea(
        child: Stack(
          children: [
            PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStep1Welcome(),
                _buildStep2PrepareExercise(),
                _buildStep3DoSeries(),
                _buildStep4RegisterResults(),
                _buildStep5RecoveryAndNav(),
                _buildStep6MultipleExercises(),
              ],
            ),
            // Header con skip
            Positioned(
              top: 16,
              right: 16,
              child: _canSkip
                  ? GestureDetector(
                      onTap: _skipTutorial,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: widget.accentColor.withAlpha(80),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Salta',
                          style: TextStyle(
                            color: widget.accentColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    )
                  : const SizedBox(),
            ),
            // Navigation buttons
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentStep > 0)
                    GestureDetector(
                      onTap: _previousStep,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(80),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_back, color: Color(0xFF0E0E10)),
                      ),
                    )
                  else
                    const SizedBox(width: 48),
                  Text(
                    '${_currentStep + 1}/6',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 14,
                    ),
                  ),
                  if (_currentStep < 5)
                    GestureDetector(
                      onTap: _nextStep,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: widget.accentColor.withAlpha(200),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_forward, color: Color(0xFF0E0E10)),
                      ),
                    )
                  else
                    const SizedBox(width: 48),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1Welcome() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '🏋️',
                style: TextStyle(fontSize: 80),
              ),
            ),
            const SizedBox(height: 30),
            Text(
              'Benvenuto in GymApp!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Questo tutorial ti guiderà attraverso il tuo primo allenamento passo dopo passo.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: widget.accentColor.withAlpha(40),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'In questo tutorial imparerai:',
                    style: TextStyle(
                      color: widget.accentColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildBullet('✓ Come prepararsi al primo esercizio'),
                  _buildBullet('✓ Come registrare peso e ripetizioni'),
                  _buildBullet('✓ Come funziona il recupero automatico'),
                  _buildBullet('✓ Come navigare tra gli esercizi'),
                ],
              ),
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2PrepareExercise() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Text(
              'Step 1: Prepararsi al primo esercizio',
              style: TextStyle(
                color: widget.accentColor,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(10),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: widget.accentColor.withAlpha(150),
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    _exercises[0]['emoji'],
                    style: const TextStyle(fontSize: 80),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _exercises[0]['name'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Questo è il primo esercizio della tua scheda.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withAlpha(40),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '💡 Consiglio:',
                    style: TextStyle(
                      color: Colors.amber[300],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Preparati fisicamente all\'esercizio. Quando sei pronto, scorri verso il basso per iniziare.',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildStep3DoSeries() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Text(
              'Step 2: Esegui la serie',
              style: TextStyle(
                color: widget.accentColor,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  const Text(
                    '⏱️',
                    style: TextStyle(fontSize: 60),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Serie ${_seriesCount}/3',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Adesso esegui l\'esercizio per la serie numero $_seriesCount.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Quando hai finito di fare le ripetizioni, passa al prossimo step per registrare il risultato.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withAlpha(40),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Text('✓', style: TextStyle(fontSize: 24, color: Colors.green)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Una volta completata la serie, avrai registrato il peso e le ripetizioni.',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildStep4RegisterResults() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Text(
              'Step 3: Registra peso e ripetizioni',
              style: TextStyle(
                color: widget.accentColor,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 30),
            // Peso
            Text(
              'Inserisci il peso:',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.accentColor.withAlpha(100),
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    _enteredWeight.isEmpty ? '0' : _enteredWeight,
                    style: TextStyle(
                      color: widget.accentColor,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'kg',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildQuickButton('5', () => _addWeightButtonPress('5')),
                _buildQuickButton('10', () => _addWeightButtonPress('10')),
                _buildQuickButton('20', () => _addWeightButtonPress('20')),
                _buildQuickButton('50', () => _addWeightButtonPress('50')),
                _buildQuickButton('⌫', () => _backspace('weight')),
              ],
            ),
            const SizedBox(height: 30),
            // Reps
            Text(
              'Inserisci le ripetizioni:',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.accentColor.withAlpha(100),
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    _enteredReps.isEmpty ? '0' : _enteredReps,
                    style: TextStyle(
                      color: widget.accentColor,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'reps',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildQuickButton('5', () => _addRepsButtonPress('5')),
                _buildQuickButton('8', () => _addRepsButtonPress('8')),
                _buildQuickButton('10', () => _addRepsButtonPress('10')),
                _buildQuickButton('12', () => _addRepsButtonPress('12')),
                _buildQuickButton('⌫', () => _backspace('reps')),
              ],
            ),
            const SizedBox(height: 30),
            // Confirm button
            if (_enteredWeight.isNotEmpty && _enteredReps.isNotEmpty)
              GestureDetector(
                onTap: _confirmSeries,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  decoration: BoxDecoration(
                    color: widget.accentColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Conferma Serie',
                    style: TextStyle(
                      color: Color(0xFF0E0E10),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(40),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Inserisci peso e reps',
                  style: TextStyle(
                    color: Colors.white38,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildStep5RecoveryAndNav() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Text(
              'Step 4: Recupero automatico',
              style: TextStyle(
                color: widget.accentColor,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 30),
            if (_showRecoveryTimer)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.orange.withAlpha(150),
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    const Text(
                      '⏱️',
                      style: TextStyle(fontSize: 80),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Recupero in corso',
                      style: TextStyle(
                        color: Colors.orange[300],
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withAlpha(80),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$_recoveryTimeLeft"',
                        style: TextStyle(
                          color: Colors.orange[300],
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Puoi navigare tra gli esercizi mentre recuperi.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    const Text(
                      '⏱️',
                      style: TextStyle(fontSize: 60),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Dopo ogni serie, il recupero inizia automaticamente.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Puoi:',
                      style: TextStyle(
                        color: widget.accentColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildBullet('👈 Scorrere verso sinistra per l\'esercizio precedente'),
                    _buildBullet('👉 Scorrere verso destra per il prossimo esercizio'),
                    _buildBullet('🔔 Riceverai una notifica quando il recupero termina'),
                  ],
                ),
              ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildStep6MultipleExercises() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Text(
              'Step 5: Cambio esercizio',
              style: TextStyle(
                color: widget.accentColor,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Text(
                    _exercises[1]['emoji'],
                    style: const TextStyle(fontSize: 80),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _exercises[1]['name'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Dopo aver completato le serie del primo esercizio, puoi passare al successivo.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withAlpha(40),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '✓ Il processo si ripete:',
                    style: TextStyle(
                      color: Colors.green[300],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildBullet('Prepararsi al nuovo esercizio'),
                  _buildBullet('Eseguire le serie'),
                  _buildBullet('Registrare peso e reps'),
                  _buildBullet('Recuperare'),
                  _buildBullet('Passare all\'esercizio successivo'),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: widget.accentColor.withAlpha(40),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '💡 Suggerimento finale:',
                    style: TextStyle(
                      color: widget.accentColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'I tuoi dati vengono salvati automaticamente. Puoi sempre riprendere da dove hai lasciato.',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E10),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      '🎉',
                      style: TextStyle(fontSize: 120),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    'Complimenti!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Hai imparato come usare GymApp nel tuo primo allenamento.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.withAlpha(40),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '✓ Cosa hai imparato:',
                          style: TextStyle(
                            color: Colors.green[300],
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildBullet('Come preparare il primo esercizio'),
                        _buildBullet('Registrare peso e ripetizioni'),
                        _buildBullet('Usare il recupero automatico'),
                        _buildBullet('Navigare tra gli esercizi'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    'Puoi sempre rivedere questo tutorial dal menu impostazioni.',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  GestureDetector(
                    onTap: widget.onComplete,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 16),
                      decoration: BoxDecoration(
                        color: widget.accentColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Inizia il tuo allenamento!',
                        style: TextStyle(
                          color: Color(0xFF0E0E10),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: widget.accentColor.withAlpha(150),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF0E0E10),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBullet(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 14,
        ),
      ),
    );
  }
}
