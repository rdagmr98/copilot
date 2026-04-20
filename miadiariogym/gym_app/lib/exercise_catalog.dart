// Banca dati esercizi locali
class ExerciseInfo {
  final String name; // Nome (italiano o inglese)
  final String nameEn; // English name (for YouTube search)
  final String
  category; // 'petto','dorso','spalle','braccia','gambe','glutei','core','cardio','altro'
  final List<String> muscleImages; // filenames in assets/muscle/ (can be empty)
  final String primaryMuscle; // Italian description
  final String secondaryMuscles;
  final String execution; // How to perform (2-4 sentences)
  final String tips; // Coaching tips (1-2 sentences)
  final List<String> aliases; // Nomi alternativi/brevi usati in scheda
  /// Slug esplicito del file GIF (es. 'barbell-curl').
  /// Se null, viene calcolato da name rimuovendo accenti e sostituendo spazi con _.
  final String? gifFilename;

  const ExerciseInfo({
    required this.name,
    required this.nameEn,
    required this.category,
    required this.muscleImages,
    required this.primaryMuscle,
    required this.secondaryMuscles,
    required this.execution,
    required this.tips,
    this.aliases = const [],
    this.gifFilename,
  });

  /// Slug del file GIF da usare come 'assets/gif/$gifSlug.gif'.
  /// Usa gifFilename se esplicito, altrimenti lo calcola dal nome.
  String get gifSlug =>
      gifFilename ??
      name
          .toLowerCase()
          .replaceAll('è', 'e')
          .replaceAll('é', 'e')
          .replaceAll('à', 'a')
          .replaceAll('á', 'a')
          .replaceAll('ì', 'i')
          .replaceAll('í', 'i')
          .replaceAll('ò', 'o')
          .replaceAll('ó', 'o')
          .replaceAll('ù', 'u')
          .replaceAll('ú', 'u')
          .replaceAll("'", '')
          .replaceAll('(', '')
          .replaceAll(')', '')
          .replaceAll(' ', '_');

  /// Controlla se questo esercizio corrisponde a un nome (inclusi alias)
  bool matchesName(String query) {
    final q = normalizeExerciseLookup(query);
    if (normalizeExerciseLookup(name) == q) return true;
    if (normalizeExerciseLookup(nameEn) == q) return true;
    if (normalizeExerciseLookup(gifSlug) == q) return true;
    return aliases.any((a) => normalizeExerciseLookup(a) == q);
  }
}

String normalizeExerciseLookup(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll('_', ' ')
    .replaceAll('-', ' ')
    .replaceAll(RegExp(r'[^a-z0-9 ]+'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Cerca nel catalogo per nome esatto o alias (case-insensitive)
ExerciseInfo? findExercise(String name) {
  final q = normalizeExerciseLookup(name);
  for (final e in kExerciseCatalog) {
    if (e.matchesName(q)) return e;
  }
  return null;
}

const List<ExerciseInfo> kExerciseCatalog = [
  // ── PETTO ──
  ExerciseInfo(
    name: 'Panca Piana',
    nameEn: 'Barbell Bench Press',
    category: 'petto',
    muscleImages: ['petto.png', 'tricipiti.png'],
    primaryMuscle: 'Petto (grande pettorale)',
    secondaryMuscles: 'Tricipiti, Deltoidi anteriori',
    execution:
        'Sdraiati sulla panca, piedi a terra. Prendi il bilanciere con presa leggermente più larga delle spalle. Abbassa il bilanciere fino al petto mantenendo i gomiti a circa 45°. Spingi verso l\'alto in modo esplosivo.',
    tips:
        'Retrai le scapole e mantienile bloccate. Non rimbalzare il bilanciere sul petto.',
    aliases: ['Panca piana', 'Bench press'],
    gifFilename: 'bench-press',
  ),
  ExerciseInfo(
    name: 'Distensioni con Manubri',
    nameEn: 'Dumbbell Bench Press',
    category: 'petto',
    muscleImages: ['petto.png', 'tricipiti.png'],
    primaryMuscle: 'Grande pettorale',
    secondaryMuscles: 'Tricipiti, Deltoidi anteriori',
    execution:
        'Sdraiato sulla panca con un manubrio in ogni mano. Parti con i manubri alle spalle, gomiti a 45°. Spingi verso l\'alto portando i manubri a toccarsi in cima. Abbassa lentamente.',
    tips:
        'Rispetto al bilanciere, i manubri permettono un range of motion maggiore e lavorano la stabilità.',
    aliases: ['Distensioni manubri', 'Distensioni con manubri'],
    gifFilename: 'alternate-dumbbell-bench-press',
  ),
  ExerciseInfo(
    name: 'Croci ai Cavi',
    nameEn: 'Cable Crossover',
    category: 'petto',
    muscleImages: ['petto.png'],
    primaryMuscle: 'Grande pettorale',
    secondaryMuscles: 'Deltoidi anteriori',
    execution:
        'Ai cavi alti o medi con un cavo per mano. Porta le braccia in avanti e verso il centro in un arco ampio, contraendo il petto al centro. Abbassa lentamente con controllo.',
    tips:
        'Mantieni tensione costante su tutto il range of motion grazie ai cavi. Prova diverse angolazioni (alto→basso, medio, basso→alto) per colpire aree diverse.',
    aliases: ['Croci ai cavi'],
    gifFilename: 'cable-crossover',
  ),
  ExerciseInfo(
    name: 'Panca Inclinata',
    nameEn: 'Incline Bench Press',
    category: 'petto',
    muscleImages: ['petto.png'],
    primaryMuscle: 'Petto superiore (clavicolare)',
    secondaryMuscles: 'Tricipiti, Deltoidi anteriori',
    execution:
        'Panca inclinata a 30-45°. Stessa tecnica della panca piana, ma l\'angolo sposta il carico sulla parte alta del petto.',
    tips:
        'Non superare i 45° di inclinazione per evitare di coinvolgere troppo le spalle.',
    gifFilename: 'incline-barbell-bench-press',
  ),
  ExerciseInfo(
    name: 'Croci con Manubri',
    nameEn: 'Dumbbell Flyes',
    category: 'petto',
    muscleImages: ['petto.png'],
    primaryMuscle: 'Grande pettorale (stretching)',
    secondaryMuscles: 'Deltoidi anteriori',
    execution:
        'Sdraiato, braccia tese con manubri sopra il petto. Abbassa lentamente le braccia ad arco fino a sentire lo stretching, poi riporta in posizione.',
    tips:
        'Mantieni una leggera flessione al gomito per proteggere l\'articolazione.',
    gifFilename: 'dumbbell-fly',
  ),
  ExerciseInfo(
    name: 'Push-Up',
    nameEn: 'Push-Up',
    category: 'petto',
    muscleImages: ['petto.png', 'tricipiti.png'],
    primaryMuscle: 'Grande pettorale',
    secondaryMuscles: 'Tricipiti, Core, Deltoidi anteriori',
    execution:
        'Posizione plank con le mani leggermente più larghe delle spalle. Abbassa il corpo mantenendo il core attivo e il corpo in linea retta. Spingi verso il basso esplosivamente.',
    tips: 'Evita di far cadere i fianchi o di alzare il sedere.',
    gifFilename: 'push-up',
  ),
  ExerciseInfo(
    name: 'Dip alle Parallele',
    nameEn: 'Parallel Bar Dips',
    category: 'petto',
    muscleImages: ['petto.png', 'tricipiti.png'],
    primaryMuscle: 'Grande pettorale (parte bassa)',
    secondaryMuscles: 'Tricipiti, Deltoidi anteriori',
    execution:
        'Inclinati leggermente in avanti per enfatizzare il petto. Scendi fino a quando i gomiti sono a 90°, poi spingi su.',
    tips:
        'Più sei inclinato in avanti, più lavora il petto. Più sei dritto, più lavorano i tricipiti.',
    gifFilename: 'triceps-dips',
  ),
  // ── DORSO ──
  ExerciseInfo(
    name: 'Stacchi da Terra',
    nameEn: 'Deadlift',
    category: 'dorso',
    muscleImages: ['dorso.png', 'gambe.png', 'glutei.png'],
    primaryMuscle: 'Erettori spinali, Trapezio, Romboidi',
    secondaryMuscles: 'Glutei, Femorali, Core',
    execution:
        'Piedi a larghezza delle anche, bilanciere sopra la metà del piede. Presa prona o mista. Abbassa i fianchi, petto alto, schiena neutra. Spingi il pavimento verso il basso e porta i fianchi avanti simultaneamente.',
    tips:
        'Non arrotondare mai la schiena bassa. La barra deve sfiorare le gambe per tutta la salita.',
    aliases: ['Stacchi', 'Deadlift'],
    gifFilename: 'deadlift',
  ),
  ExerciseInfo(
    name: 'Trazioni alla Sbarra',
    nameEn: 'Pull-Up',
    category: 'dorso',
    muscleImages: ['dorso.png', 'bicipiti.png'],
    primaryMuscle: 'Gran dorsale',
    secondaryMuscles: 'Bicipiti, Romboidi, Trapezio medio',
    execution:
        'Presa prona, più larga delle spalle. Contrai le scapole e tira il corpo verso l\'alto fino a portare il mento sopra la barra. Scendi lentamente e con controllo.',
    tips: 'Inizia il movimento retraendo le scapole, non flettendo i gomiti.',
    aliases: ['Trazioni', 'Pull-up', 'Pullup'],
    gifFilename: 'pull-up',
  ),
  ExerciseInfo(
    name: 'Lat Machine',
    nameEn: 'Lat Pulldown',
    category: 'dorso',
    muscleImages: ['dorso.png', 'bicipiti.png'],
    primaryMuscle: 'Gran dorsale',
    secondaryMuscles: 'Bicipiti, Romboidi, Trapezio medio',
    execution:
        'Seduto, presa prona larga. Tira il bilanciere verso il petto inclinando leggermente il busto. Concentrati sul portare i gomiti verso i fianchi.',
    tips:
        'Non usare il momentum del corpo. Tira con i gomiti, non con le mani.',
    aliases: ['Pulldown', 'Lat machine', 'Lat pulldown'],
    gifFilename: 'lat-pulldown',
  ),
  ExerciseInfo(
    name: 'Rematore con Bilanciere',
    nameEn: 'Barbell Row',
    category: 'dorso',
    muscleImages: ['dorso.png'],
    primaryMuscle: 'Gran dorsale, Romboidi',
    secondaryMuscles: 'Bicipiti, Trapezio, Erettori spinali',
    execution:
        'Busto inclinato a circa 45°, schiena neutra, bilanciere appeso. Tira il bilanciere verso l\'ombelico retraendo le scapole. Abbassa lentamente.',
    tips:
        'Mantieni la schiena ferma. Il movimento deve partire dalle scapole, non dalle braccia.',
    aliases: ['Rematore', 'Rematore bilanciere'],
    gifFilename: 'barbell-bent-over-row',
  ),
  ExerciseInfo(
    name: 'Rematore con Manubrio',
    nameEn: 'Dumbbell Row',
    category: 'dorso',
    muscleImages: ['dorso.png'],
    primaryMuscle: 'Gran dorsale, Romboidi',
    secondaryMuscles: 'Bicipiti, Trapezio',
    execution:
        'Appoggia un ginocchio e una mano sulla panca. Con la mano libera, tira il manubrio verso il fianco retraendo la scapola. Abbassa lentamente.',
    tips: 'Non ruotare il busto. Mantieni la colonna neutra.',
    gifFilename: 'dumbbell-row',
  ),
  // ── SPALLE ──
  ExerciseInfo(
    name: 'Lento Avanti',
    nameEn: 'Overhead Press',
    category: 'spalle',
    muscleImages: ['spalle.png', 'tricipiti.png'],
    primaryMuscle: 'Deltoide anteriore e medio',
    secondaryMuscles: 'Tricipiti, Trapezio superiore, Core',
    execution:
        'In piedi o seduto, bilanciere al petto con presa leggermente più larga delle spalle. Spingi verso l\'alto fino a braccia tese. Riporta controllato al petto.',
    tips: 'Contrai il core. Non estendere eccessivamente la schiena bassa.',
    aliases: ['Shoulder Press', 'Overhead press', 'Military press'],
    gifFilename: 'barbell-shoulder-press',
  ),
  ExerciseInfo(
    name: 'Alzate Laterali',
    nameEn: 'Lateral Raises',
    category: 'spalle',
    muscleImages: ['spalle.png'],
    primaryMuscle: 'Deltoide medio',
    secondaryMuscles: 'Trapezio superiore',
    execution:
        'In piedi, manubri ai lati. Alza le braccia lateralmente fino all\'altezza delle spalle con i gomiti leggermente flessi. Abbassa lentamente.',
    tips:
        'Immagina di versare acqua dai manubri: polso leggermente più basso del gomito.',
    aliases: ['Alzate laterali'],
    gifFilename: 'dumbbell-lateral-raise',
  ),
  ExerciseInfo(
    name: 'Alzate Frontali',
    nameEn: 'Front Raises',
    category: 'spalle',
    muscleImages: ['spalle.png'],
    primaryMuscle: 'Deltoide anteriore',
    secondaryMuscles: 'Deltoide medio, Petto superiore',
    execution:
        'In piedi, manubri davanti alle cosce. Alza le braccia in avanti fino all\'altezza delle spalle mantenendo i gomiti quasi tesi.',
    tips: 'Evita di usare il momentum del corpo oscillando.',
    gifFilename: 'dumbbell-front-raise',
  ),
  ExerciseInfo(
    name: 'Alzate Posteriori',
    nameEn: 'Rear Delt Flyes',
    category: 'spalle',
    muscleImages: ['spalle.png', 'dorso.png'],
    primaryMuscle: 'Deltoide posteriore',
    secondaryMuscles: 'Romboidi, Trapezio medio',
    execution:
        'Busto piegato a 90°, braccia verso il basso. Alza i manubri lateralmente fino all\'altezza delle spalle tenendo i gomiti leggermente flessi.',
    tips:
        'Focalizzati sul deltoide posteriore, non sul trapezio. Mantieni il collo neutro.',
    gifFilename: 'bent-over-lateral-raise',
  ),
  // ── BICIPITI ──
  ExerciseInfo(
    name: 'Curl con Bilanciere',
    nameEn: 'Barbell Curl',
    category: 'braccia',
    muscleImages: ['bicipiti.png'],
    primaryMuscle: 'Bicipite brachiale',
    secondaryMuscles: 'Brachiale, Brachioradiale',
    execution:
        'In piedi, bilanciere con presa supina alla larghezza delle spalle. Piega i gomiti portando il bilanciere verso le spalle. Abbassa lentamente.',
    tips: 'Non oscillare il busto. I gomiti devono restare fermi ai fianchi.',
    aliases: ['Curl', 'Barbell curl'],
    gifFilename: 'barbell-curl',
  ),
  ExerciseInfo(
    name: 'Curl con Manubri Alternati',
    nameEn: 'Alternating Dumbbell Curl',
    category: 'braccia',
    muscleImages: ['bicipiti.png'],
    primaryMuscle: 'Bicipite brachiale',
    secondaryMuscles: 'Brachiale, Brachioradiale',
    execution:
        'In piedi, manubri ai lati. Alza un manubrio ruotando il polso (supinazione) durante il movimento. Abbassa e ripeti con l\'altro braccio.',
    tips: 'La supinazione del polso massimizza l\'attivazione del bicipite.',
    gifFilename: 'dumbbell-curl',
  ),
  ExerciseInfo(
    name: 'Curl Martello',
    nameEn: 'Hammer Curl',
    category: 'braccia',
    muscleImages: ['bicipiti.png', 'braccia.png'],
    primaryMuscle: 'Brachiale, Brachioradiale',
    secondaryMuscles: 'Bicipite brachiale',
    execution:
        'Presa neutrale (pollici verso l\'alto). Piega i gomiti portando i manubri verso le spalle senza ruotare il polso.',
    tips: 'Ottimo per lo spessore del braccio e la forza dell\'avambraccio.',
    aliases: ['Curl hammer', 'Hammer curl'],
    gifFilename: 'hammer-curl',
  ),
  ExerciseInfo(
    name: 'Curl al Cavo Basso',
    nameEn: 'Cable Curl',
    category: 'braccia',
    muscleImages: ['bicipiti.png'],
    primaryMuscle: 'Bicipite brachiale',
    secondaryMuscles: 'Brachiale',
    execution:
        'In piedi davanti al cavo basso, barra o corda. Piega i gomiti portando il peso verso le spalle mantenendo i gomiti fissi.',
    tips:
        'Il cavo mantiene tensione costante anche nella posizione di massima contrazione.',
    gifFilename: 'cable-curl',
  ),
  // ── TRICIPITI ──
  ExerciseInfo(
    name: 'French Press',
    nameEn: 'Skull Crusher',
    category: 'braccia',
    muscleImages: ['tricipiti.png'],
    primaryMuscle: 'Tricipite brachiale (capo lungo)',
    secondaryMuscles: 'Tricipite (capo laterale e mediale)',
    execution:
        'Sdraiato, bilanciere o manubri sopra il petto. Abbassa lentamente verso la fronte flettendo solo i gomiti. Estendi le braccia.',
    tips: 'Controlla la discesa. Non allargare i gomiti.',
    aliases: ['Pushdown barra', 'Skull crusher'],
    gifFilename: 'seated-ez-bar-overhead-triceps-extension',
  ),
  ExerciseInfo(
    name: 'Tricipiti ai Cavi',
    nameEn: 'Cable Tricep Pushdown',
    category: 'braccia',
    muscleImages: ['tricipiti.png'],
    primaryMuscle: 'Tricipite brachiale',
    secondaryMuscles: '',
    execution:
        'In piedi, cavo alto con corda o barra. Tieni i gomiti fissi ai fianchi. Estendi le braccia verso il basso fino a massima contrazione.',
    tips:
        'Ruota i polsi verso l\'esterno a fine movimento con la corda per massimizzare la contrazione.',
    aliases: ['Pushdown corda', 'Pushdown', 'Tricep pushdown'],
    gifFilename: 'rope-pushdown',
  ),
  ExerciseInfo(
    name: 'Dip ai Tricipiti',
    nameEn: 'Tricep Dips',
    category: 'braccia',
    muscleImages: ['tricipiti.png'],
    primaryMuscle: 'Tricipite brachiale',
    secondaryMuscles: 'Petto, Deltoide anteriore',
    execution:
        'Alle parallele o con panca, busto dritto e verticale. Scendi flettendo i gomiti. Spingi su.',
    tips:
        'Più sei dritto, più lavora il tricipite. Inclinati in avanti per coinvolgere il petto.',
    gifFilename: 'triceps-dips',
  ),
  // ── GAMBE ──
  ExerciseInfo(
    name: 'Squat con Bilanciere',
    nameEn: 'Barbell Squat',
    category: 'gambe',
    muscleImages: ['gambe.png', 'quadricipiti.png', 'glutei.png'],
    primaryMuscle: 'Quadricipiti, Glutei',
    secondaryMuscles: 'Femorali, Core, Erettori spinali',
    execution:
        'Bilanciere sul trapezio. Piedi a larghezza spalle, punte leggermente verso l\'esterno. Scendi flettendo le ginocchia e aprendo le anche fino alla profondità desiderata. Spingi attraverso i talloni per salire.',
    tips:
        'Le ginocchia devono seguire la direzione delle punte dei piedi. Non lasciare che crollino verso l\'interno.',
    aliases: ['Squat', 'Back squat'],
    gifFilename: 'squat',
  ),
  ExerciseInfo(
    name: 'Leg Press',
    nameEn: 'Leg Press',
    category: 'gambe',
    muscleImages: ['gambe.png', 'quadricipiti.png'],
    primaryMuscle: 'Quadricipiti',
    secondaryMuscles: 'Glutei, Femorali',
    execution:
        'Seduto nella macchina, piedi alla larghezza delle anche sulla piattaforma. Abbassa controllato fino a 90° ai ginocchi. Spingi via la piattaforma.',
    tips:
        'Non bloccare completamente le ginocchia in cima. Mantieni i piedi piatti sulla piattaforma.',
    aliases: ['Leg press'],
    gifFilename: 'leg-press',
  ),
  ExerciseInfo(
    name: 'Affondi',
    nameEn: 'Lunges',
    category: 'gambe',
    muscleImages: ['gambe.png', 'glutei.png'],
    primaryMuscle: 'Quadricipiti, Glutei',
    secondaryMuscles: 'Femorali, Core',
    execution:
        'In piedi, fai un passo avanti con una gamba. Abbassa il ginocchio posteriore verso il suolo. Torna alla posizione iniziale e ripeti con l\'altra gamba.',
    tips:
        'Il ginocchio anteriore non deve superare la punta del piede. Mantieni il busto dritto.',
    gifFilename: 'bodyweight-lunge',
  ),
  ExerciseInfo(
    name: 'Leg Extension',
    nameEn: 'Leg Extension',
    category: 'gambe',
    muscleImages: ['quadricipiti.png'],
    primaryMuscle: 'Quadricipiti',
    secondaryMuscles: '',
    execution:
        'Seduto nella macchina, gomma sotto le caviglie. Estendi le gambe completamente contraendo i quadricipiti. Abbassa lentamente.',
    tips: 'Esercizio di isolamento. Utile come finisher o per riabilitazione.',
    aliases: ['Leg extension'],
    gifFilename: 'leg-extension',
  ),
  ExerciseInfo(
    name: 'Leg Curl',
    nameEn: 'Leg Curl',
    category: 'gambe',
    muscleImages: ['femorali.png'],
    primaryMuscle: 'Femorali (bicipite femorale)',
    secondaryMuscles: 'Gastrocnemio',
    execution:
        'Prono sulla macchina (o seduto). Fletti le gambe portando i talloni verso i glutei. Abbassa lentamente.',
    tips:
        'Non sollevare i fianchi dalla panca. Contrai i femorali nella posizione massima.',
    aliases: ['Leg curl'],
    gifFilename: 'seated-leg-curl',
  ),
  ExerciseInfo(
    name: 'Romanian Deadlift',
    nameEn: 'Romanian Deadlift',
    category: 'gambe',
    muscleImages: ['femorali.png', 'glutei.png'],
    primaryMuscle: 'Femorali, Glutei',
    secondaryMuscles: 'Erettori spinali',
    execution:
        'In piedi con bilanciere. Abbassa il bilanciere lungo le gambe flettendo i fianchi (non le ginocchia) finché senti lo stretch nei femorali. Spingi i fianchi in avanti per tornare su.',
    tips:
        'Schiena sempre neutra. Non piegarti con la schiena: il movimento parte dai fianchi.',
    aliases: ['Stacco rumeno', 'Stacchi rumeni', 'RDL'],
    gifFilename: 'romanian-deadlift',
  ),
  ExerciseInfo(
    name: 'Hip Thrust',
    nameEn: 'Hip Thrust',
    category: 'glutei',
    muscleImages: ['glutei.png', 'femorali.png'],
    primaryMuscle: 'Glutei (grande gluteo)',
    secondaryMuscles: 'Femorali, Core',
    execution:
        'Spalle sulla panca, bilanciere sull\'anca. Piedi piatti a terra. Spingi i fianchi verso l\'alto contraendo i glutei. Fai una pausa in cima. Abbassa lentamente.',
    tips:
        'Contrai intensamente i glutei in cima. Ginocchia aperte durante il movimento.',
    aliases: ['Hip thrust'],
    gifFilename: 'barbell-hip-thrusts',
  ),
  ExerciseInfo(
    name: 'Glute Kickback',
    nameEn: 'Cable Glute Kickback',
    category: 'glutei',
    muscleImages: ['glutei.png'],
    primaryMuscle: 'Grande gluteo',
    secondaryMuscles: 'Femorali',
    execution:
        'Al cavo basso con cavigliera. Spingi la gamba indietro contraendo il gluteo. Abbassa controllato.',
    tips:
        'Non iperestendere la schiena. Fai una pausa nella contrazione massima.',
    gifFilename: 'glute-kickback-machine',
  ),
  ExerciseInfo(
    name: 'Calf Raises',
    nameEn: 'Standing Calf Raises',
    category: 'gambe',
    muscleImages: ['gambe.png'],
    primaryMuscle: 'Gastrocnemio',
    secondaryMuscles: 'Soleo',
    execution:
        'In piedi sui bordi di un gradino o sulla macchina. Alza i talloni più in alto possibile. Abbassa lentamente fino al massimo stretch.',
    tips:
        'Fai una pausa in cima. Il range of motion completo è fondamentale per questo muscolo.',
    gifFilename: 'calf-raise',
  ),
  // ── CORE ──
  ExerciseInfo(
    name: 'Plank',
    nameEn: 'Plank',
    category: 'core',
    muscleImages: [],
    primaryMuscle: 'Core (trasverso dell\'addome, retto)',
    secondaryMuscles: 'Erettori spinali, Deltoidi, Glutei',
    execution:
        'Posizione di push-up sugli avambracci. Corpo in linea retta dalla testa ai talloni. Contrai il core e mantieni.',
    tips:
        'Non lasciare cadere i fianchi né alzare il sedere. Respira normalmente.',
    gifFilename: 'plank',
  ),
  ExerciseInfo(
    name: 'Crunch',
    nameEn: 'Crunch',
    category: 'core',
    muscleImages: [],
    primaryMuscle: 'Retto dell\'addome',
    secondaryMuscles: 'Obliqui',
    execution:
        'Sdraiato con ginocchia flesse. Mani dietro la testa. Curva il busto verso le ginocchia contraendo l\'addome. Abbassa lentamente.',
    tips:
        'Non tirare il collo con le mani. Il movimento è breve: solleva solo le spalle.',
    gifFilename: 'crunch',
  ),
  ExerciseInfo(
    name: 'Russian Twist',
    nameEn: 'Russian Twist',
    category: 'core',
    muscleImages: [],
    primaryMuscle: 'Obliqui addominali',
    secondaryMuscles: 'Retto dell\'addome',
    execution:
        'Seduto con gambe leggermente sollevate, busto inclinato. Ruota il busto da un lato all\'altro toccando il pavimento con le mani.',
    tips:
        'Tieni i piedi sollevati per aumentare l\'intensità. Ruota dal busto, non dalle braccia.',
    gifFilename: 'russian-twist',
  ),
  ExerciseInfo(
    name: 'Leg Raise',
    nameEn: 'Hanging Leg Raise',
    category: 'core',
    muscleImages: [],
    primaryMuscle: 'Retto dell\'addome (parte bassa)',
    secondaryMuscles: 'Flessori dell\'anca, Obliqui',
    execution:
        'Appeso alla sbarra, gambe tese o piegate. Alza le gambe fino all\'orizzontale o oltre contraendo l\'addome. Abbassa lentamente.',
    tips: 'Evita di oscillare. Il movimento deve essere controllato.',
    gifFilename: 'hanging-leg-raises',
  ),
  // ── MOVIMENTI COMPOSTI ──
  ExerciseInfo(
    name: 'Clean and Press',
    nameEn: 'Clean and Press',
    category: 'spalle',
    muscleImages: ['spalle.png', 'gambe.png'],
    primaryMuscle: 'Corpo intero',
    secondaryMuscles: 'Gambe, Schiena, Spalle, Core',
    execution:
        'Bilanciere a terra. Tira esplosivamente verso le spalle (clean), poi spingi sopra la testa (press). Abbassa controllato.',
    tips:
        'Esercizio tecnico. Impara separatamente il clean e il press prima di combinarli.',
    gifFilename: 'barbell-clean-and-press',
  ),
  ExerciseInfo(
    name: 'Kettlebell Swing',
    nameEn: 'Kettlebell Swing',
    category: 'glutei',
    muscleImages: ['glutei.png', 'femorali.png', 'dorso.png'],
    primaryMuscle: 'Catena posteriore (glutei, femorali)',
    secondaryMuscles: 'Core, Spalle, Erettori spinali',
    execution:
        'Piedi leggermente più larghi delle anche. Hinges sui fianchi portando il kettlebell tra le gambe. Estendi esplosivamente i fianchi per proiettare il kettlebell verso l\'alto.',
    tips: 'Il potere viene dai fianchi, non dalle braccia. Non è uno squat.',
    gifFilename: 'kettlebell-swings',
  ),
  ExerciseInfo(
    name: 'Face Pull',
    nameEn: 'Face Pull',
    category: 'spalle',
    muscleImages: ['spalle.png', 'dorso.png'],
    primaryMuscle: 'Deltoide posteriore, Rotatori esterni',
    secondaryMuscles: 'Trapezio medio, Romboidi',
    execution:
        'Al cavo alto con corda. Tira la corda verso il viso aprendo i gomiti verso l\'alto. Separa le estremità della corda all\'arrivo.',
    tips:
        'Fondamentale per la salute della cuffia dei rotatori. Non skipper mai questo esercizio.',
    gifFilename: 'face-pull',
  ),
  // ── PETTO (extra) ──
  ExerciseInfo(
    name: 'Panca Declinata',
    nameEn: 'Decline Bench Press',
    category: 'petto',
    muscleImages: ['petto.png', 'tricipiti.png'],
    primaryMuscle: 'Petto inferiore (sternale)',
    secondaryMuscles: 'Tricipiti, Deltoidi anteriori',
    execution:
        'Panca inclinata verso il basso a 15-30°. Stessa tecnica della panca piana. L\'angolo sposta il carico sulla parte inferiore del petto.',
    tips:
        'Assicurati di fissare bene i piedi alla panca. Retrai le scapole come nella panca piana.',
    gifFilename: 'decline-barbell-bench-press',
  ),
  ExerciseInfo(
    name: 'Peck Deck',
    nameEn: 'Pec Deck Machine',
    category: 'petto',
    muscleImages: ['petto.png'],
    primaryMuscle: 'Grande pettorale',
    secondaryMuscles: 'Deltoidi anteriori',
    execution:
        'Seduto nella macchina, avambracci sulle leve o mani sulle maniglie. Porta le braccia verso il centro contraendo il petto. Torna lentamente alla posizione di partenza.',
    tips:
        'Ottimo per l\'isolamento del petto. Non usare un peso eccessivo che ti costringa ad aprire troppo i gomiti.',
    gifFilename: 'pec-deck-fly',
  ),
  ExerciseInfo(
    name: 'Pull Over',
    nameEn: 'Dumbbell Pullover',
    category: 'petto',
    muscleImages: ['petto.png', 'dorso.png'],
    primaryMuscle: 'Grande pettorale, Gran dorsale',
    secondaryMuscles: 'Tricipiti, Dentato anteriore',
    execution:
        'Sdraiato sulla panca, manubrio con entrambe le mani sopra il petto. Abbassa il manubrio ad arco dietro la testa mantenendo i gomiti leggermente flessi. Riporta sopra il petto.',
    tips:
        'Ottimo per espandere la cassa toracica e allungare il grande pettorale. Vai lento nella fase eccentrica.',
    gifFilename: 'dumbbell-pullover',
  ),
  ExerciseInfo(
    name: 'Chest Press Macchina',
    nameEn: 'Machine Chest Press',
    category: 'petto',
    muscleImages: ['petto.png', 'tricipiti.png'],
    primaryMuscle: 'Grande pettorale',
    secondaryMuscles: 'Tricipiti, Deltoidi anteriori',
    execution:
        'Seduto nella macchina, schiena contro lo schienale. Spingi le maniglie in avanti estendendo le braccia. Riporta lentamente.',
    tips:
        'Perfetto per principianti e per isolare il petto con traiettoria guidata.',
    aliases: ['Pectoral machine', 'Chest press'],
    gifFilename: 'chest-press-machine',
  ),
  // ── DORSO (extra) ──
  ExerciseInfo(
    name: 'Pulley Basso',
    nameEn: 'Seated Cable Row',
    category: 'dorso',
    muscleImages: ['dorso.png', 'bicipiti.png'],
    primaryMuscle: 'Gran dorsale, Romboidi',
    secondaryMuscles: 'Bicipiti, Trapezio medio, Erettori spinali',
    execution:
        'Seduto al cavo basso, piedi sulla pedana, ginocchia leggermente flesse. Tira la maniglia verso l\'addome retraendo le scapole. Abbassa lentamente mantenendo la schiena neutra.',
    tips:
        'Tira con i gomiti, non con le mani. Controlla la fase di ritorno per massimizzare il lavoro muscolare.',
    aliases: ['Pulley', 'Rematore ai cavi', 'Seated row'],
    gifFilename: 'seated-cable-row',
  ),
  ExerciseInfo(
    name: 'Trazioni Presa Neutra',
    nameEn: 'Neutral Grip Pull-Up',
    category: 'dorso',
    muscleImages: ['dorso.png', 'bicipiti.png'],
    primaryMuscle: 'Gran dorsale, Bicipiti',
    secondaryMuscles: 'Romboidi, Brachiale, Trapezio medio',
    execution:
        'Presa neutra (palmi contrapposti). Tira il corpo verso l\'alto fino al mento sopra la barra. Scendi lentamente con controllo.',
    tips:
        'La presa neutra riduce lo stress sui polsi ed è più naturale per molte persone rispetto alla presa prona.',
    gifFilename: 'neutral-grip-pull-up',
  ),
  ExerciseInfo(
    name: 'Back Extension',
    nameEn: 'Back Extension',
    category: 'dorso',
    muscleImages: ['dorso.png'],
    primaryMuscle: 'Erettori spinali',
    secondaryMuscles: 'Glutei, Femorali',
    execution:
        'Sulla macchina roman chair o GHD, fianchi sull\'imbottitura, piedi bloccati. Abbassa il busto verso il basso, poi estendi la schiena fino alla posizione neutra. Non iperestendere.',
    tips:
        'Esercizio fondamentale per il rafforzamento della schiena bassa. Aggiungi peso solo quando la tecnica è perfetta.',
    gifFilename: 'hyperextension',
  ),
  ExerciseInfo(
    name: 'Good Morning',
    nameEn: 'Good Morning',
    category: 'dorso',
    muscleImages: ['dorso.png', 'femorali.png'],
    primaryMuscle: 'Erettori spinali, Femorali',
    secondaryMuscles: 'Glutei, Core',
    execution:
        'Bilanciere sul trapezio, piedi a larghezza spalle. Fletti i fianchi portando il busto in avanti fino a circa 45° mantenendo la schiena neutra. Estendi i fianchi per tornare in posizione.',
    tips:
        'Non arrotondare la schiena. Esercizio avanzato: inizia senza peso per imparare il movimento.',
    gifFilename: 'good-morning',
  ),
  // ── SPALLE (extra) ──
  ExerciseInfo(
    name: 'Arnold Press',
    nameEn: 'Arnold Press',
    category: 'spalle',
    muscleImages: ['spalle.png'],
    primaryMuscle: 'Deltoide anteriore e medio',
    secondaryMuscles: 'Tricipiti, Trapezio superiore',
    execution:
        'Seduto o in piedi, manubri davanti al viso con palmi verso di te. Spingi i manubri verso l\'alto ruotando i polsi verso l\'esterno fino ad avere i palmi in avanti in cima. Abbassa invertendo la rotazione.',
    tips:
        'Inventato da Arnold Schwarzenegger: attiva tutti e tre i capi del deltoide grazie alla rotazione.',
    gifFilename: 'arnold-press',
  ),
  ExerciseInfo(
    name: 'Shoulder Press Macchina',
    nameEn: 'Machine Shoulder Press',
    category: 'spalle',
    muscleImages: ['spalle.png'],
    primaryMuscle: 'Deltoide anteriore e medio',
    secondaryMuscles: 'Tricipiti, Trapezio superiore',
    execution:
        'Seduto nella macchina, schiena contro lo schienale. Spingi le maniglie verso l\'alto fino a estensione quasi completa. Abbassa lentamente.',
    tips:
        'Ottimo per principianti e per allenare le spalle con traiettoria guidata.',
  ),
  ExerciseInfo(
    name: 'Alzate di Spalle',
    nameEn: 'Shoulder Shrug',
    category: 'spalle',
    muscleImages: ['spalle.png'],
    primaryMuscle: 'Trapezio superiore',
    secondaryMuscles: 'Elevatori della scapola',
    execution:
        'In piedi con bilanciere o manubri. Alza le spalle più in alto possibile verso le orecchie. Mantieni un secondo, poi abbassa lentamente.',
    tips:
        'Non ruotare le spalle — il movimento deve essere verticale. Usa un peso gestibile per evitare problemi al collo.',
    gifFilename: 'barbell-shrug',
  ),
  // ── BRACCIA (extra) ──
  ExerciseInfo(
    name: 'Push Up Diamante',
    nameEn: 'Diamond Push-Up',
    category: 'braccia',
    muscleImages: ['tricipiti.png', 'petto.png'],
    primaryMuscle: 'Tricipite brachiale',
    secondaryMuscles: 'Petto, Deltoidi anteriori',
    execution:
        'Posizione push-up con le mani vicine formando un triangolo (diamante) tra pollici e indici. Abbassa il petto verso le mani e spingi su.',
    tips:
        'I gomiti devono restare vicini al corpo. È una delle varianti più efficaci per i tricipiti.',
    gifFilename: 'diamond-push-up',
  ),
  ExerciseInfo(
    name: 'Concentration Curl',
    nameEn: 'Concentration Curl',
    category: 'braccia',
    muscleImages: ['bicipiti.png'],
    primaryMuscle: 'Bicipite brachiale (picco)',
    secondaryMuscles: 'Brachiale',
    execution:
        'Seduto con gomito appoggiato alla coscia interna. Porta il manubrio verso la spalla con una contrazione lenta e controllata. Abbassa lentamente.',
    tips:
        'Ideale per sviluppare il picco del bicipite. Supina completamente il polso in cima.',
    gifFilename: 'concentration-curl',
  ),
  ExerciseInfo(
    name: 'Scott Curl',
    nameEn: 'Preacher Curl',
    category: 'braccia',
    muscleImages: ['bicipiti.png'],
    primaryMuscle: 'Bicipite brachiale (capo corto)',
    secondaryMuscles: 'Brachiale',
    execution:
        'Sul banco scott (preacher bench), braccia appoggiate sul cuscino inclinato. Porta il bilanciere o i manubri verso le spalle. Abbassa lentamente per massimo stretch.',
    tips:
        'Il banco scott elimina il cheating. Scendi fino alla quasi-estensione completa per il massimo range of motion.',
    gifFilename: 'dumbbell-scott-curl',
  ),
  ExerciseInfo(
    name: 'Overhead Tricep Extension',
    nameEn: 'Overhead Tricep Extension',
    category: 'braccia',
    muscleImages: ['tricipiti.png'],
    primaryMuscle: 'Tricipite (capo lungo)',
    secondaryMuscles: 'Tricipite (capi laterale e mediale)',
    execution:
        'In piedi o seduto, manubrio o barra sopra la testa. Abbassa il peso dietro la testa flettendo solo i gomiti. Estendi le braccia verso l\'alto.',
    tips:
        'Il capo lungo del tricipite è più attivato quando le braccia sono sopra la testa. Tieni i gomiti vicini.',
    gifFilename: 'seated-ez-bar-overhead-triceps-extension',
  ),
  // ── GAMBE/GLUTEI (extra) ──
  ExerciseInfo(
    name: 'Hip Abductor',
    nameEn: 'Hip Abductor Machine',
    category: 'glutei',
    muscleImages: ['glutei.png'],
    primaryMuscle: 'Gluteo medio, Piccolo gluteo',
    secondaryMuscles: 'Tensore della fascia lata',
    execution:
        'Seduto nella macchina, gambe appoggiate sulle leve. Apri le gambe verso l\'esterno contro la resistenza. Ritorna lentamente.',
    tips:
        'Essenziale per la stabilità del ginocchio e la definizione del gluteo laterale.',
    gifFilename: 'hip-abduction-machine',
  ),
  ExerciseInfo(
    name: 'Donkey Kick',
    nameEn: 'Donkey Kick',
    category: 'glutei',
    muscleImages: ['glutei.png'],
    primaryMuscle: 'Grande gluteo',
    secondaryMuscles: 'Femorali, Erettori spinali',
    execution:
        'In quadrupedia con ginocchia e mani a terra. Spingi una gamba indietro e verso l\'alto con il ginocchio flesso a 90°, contraendo il gluteo in cima. Abbassa senza toccare il suolo.',
    tips:
        'Non iperestendere la schiena. Fai una pausa nella contrazione massima per maggior efficacia.',
    gifFilename: 'donkey-kicks',
  ),
  ExerciseInfo(
    name: 'Bulgarian Split Squat',
    nameEn: 'Bulgarian Split Squat',
    category: 'gambe',
    muscleImages: ['gambe.png', 'glutei.png'],
    primaryMuscle: 'Quadricipiti, Glutei',
    secondaryMuscles: 'Femorali, Core, Stabilizzatori della caviglia',
    execution:
        'Piede posteriore su una panca, piede anteriore avanti. Abbassa il ginocchio posteriore verso il suolo. Spingi con il piede anteriore per tornare su.',
    tips:
        'Esercizio unilaterale eccellente per correggere asimmetrie. Il busto leggermente inclinato in avanti attiva più i glutei.',
    gifFilename: 'barbell-bulgarian-split-squat',
  ),
  ExerciseInfo(
    name: 'Goblet Squat',
    nameEn: 'Goblet Squat',
    category: 'gambe',
    muscleImages: ['gambe.png', 'glutei.png'],
    primaryMuscle: 'Quadricipiti, Glutei',
    secondaryMuscles: 'Core, Femorali',
    execution:
        'In piedi, kettlebell o manubrio tenuto al petto con entrambe le mani. Scendi in squat profondo con busto eretto. Spingi le ginocchia verso fuori. Risali.',
    tips:
        'Il peso anteriore aiuta a mantenere il busto eretto. Ottimo per imparare la tecnica dello squat.',
    gifFilename: 'kettlebell-goblet-squat',
  ),
  ExerciseInfo(
    name: 'Sumo Deadlift',
    nameEn: 'Sumo Deadlift',
    category: 'gambe',
    muscleImages: ['gambe.png', 'glutei.png', 'dorso.png'],
    primaryMuscle: 'Glutei, Adduttori, Quadricipiti',
    secondaryMuscles: 'Femorali, Erettori spinali',
    execution:
        'Stance larga, punte verso l\'esterno, presa stretta sulla barra. Abbassa i fianchi, petto alto. Spingi le ginocchia verso fuori mentre estendi le gambe. Fianchi e spalle salgono insieme.',
    tips:
        'La stance larga riduce il carico sulla schiena bassa. Attiva molto di più i glutei rispetto al deadlift convenzionale.',
    gifFilename: 'sumo-deadlift',
  ),
  ExerciseInfo(
    name: 'Step Up',
    nameEn: 'Step Up',
    category: 'gambe',
    muscleImages: ['gambe.png', 'glutei.png'],
    primaryMuscle: 'Quadricipiti, Glutei',
    secondaryMuscles: 'Femorali, Core',
    execution:
        'Con manubri o bilanciere, metti un piede su una panca o gradino. Spingi verso l\'alto portando l\'altro piede sulla panca. Scendi controllato. Alterna le gambe.',
    tips:
        'Più alto è il gradino, più lavora il gluteo. Spingi con il tallone per massimizzare l\'attivazione glutea.',
  ),
  // ── CORE (extra) ──
  ExerciseInfo(
    name: 'Plank Laterale',
    nameEn: 'Side Plank',
    category: 'core',
    muscleImages: [],
    primaryMuscle: 'Obliqui addominali, Quadrato dei lombi',
    secondaryMuscles: 'Core, Deltoidi, Gluteo medio',
    execution:
        'Sdraiato su un fianco, corpo in linea retta, appoggiato su un avambraccio e il bordo del piede. Alza i fianchi da terra e mantieni la posizione.',
    tips:
        'Non lasciare cadere i fianchi. Il corpo deve formare una linea retta dalla testa ai piedi.',
  ),
  ExerciseInfo(
    name: 'Mountain Climber',
    nameEn: 'Mountain Climber',
    category: 'core',
    muscleImages: [],
    primaryMuscle: 'Core (retto e obliqui)',
    secondaryMuscles: 'Flessori dell\'anca, Spalle, Glutei',
    execution:
        'Posizione plank con braccia tese. Porta alternativamente le ginocchia verso il petto in modo rapido, come se stessi correndo in posizione orizzontale.',
    tips:
        'Mantieni i fianchi stabili e allineati. Più veloce è il movimento, più alto è l\'impatto cardiovascolare.',
  ),
];
