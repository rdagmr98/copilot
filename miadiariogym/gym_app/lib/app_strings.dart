// Localizzazione app GymApp — aggiungere qui nuove stringhe
// Usare AppL.xxx nei widget per supporto IT/EN automatico.

class AppL {
  static String _lang = 'it';

  static void setLang(String lang) => _lang = lang;
  static String get lang => _lang;

  // ── Navigazione principale ──
  static String get mySchedule    => _lang == 'en' ? 'My Schedule'      : 'La mia scheda';
  static String get noSchedule    => _lang == 'en' ? 'No schedule yet'  : 'Nessuna scheda';
  static String get createSchedule=> _lang == 'en' ? 'Create Schedule'  : 'Crea la tua scheda';
  static String get editSchedule  => _lang == 'en' ? 'Edit Schedule'    : 'Modifica scheda';
  static String get train         => _lang == 'en' ? 'Train'            : 'Allenati';
  static String get progress      => _lang == 'en' ? 'Progress'         : 'Progressi';
  static String get settings      => _lang == 'en' ? 'Settings'         : 'Impostazioni';

  // ── Scheda ──
  static String get day           => _lang == 'en' ? 'Day'              : 'Giorno';
  static String get addDay        => _lang == 'en' ? 'Add Day'          : 'Aggiungi Giorno';
  static String get exercises     => _lang == 'en' ? 'Exercises'        : 'Esercizi';
  static String get addExercise   => _lang == 'en' ? 'Add Exercise'     : 'Aggiungi Esercizio';
  static String get sets          => _lang == 'en' ? 'Sets'             : 'Serie';
  static String get reps          => _lang == 'en' ? 'Reps'             : 'Ripetizioni';
  static String get recovery      => _lang == 'en' ? 'Recovery (s)'     : 'Recupero (s)';
  static String get notes         => _lang == 'en' ? 'Notes'            : 'Note';
  static String get exerciseName  => _lang == 'en' ? 'Exercise name'    : 'Nome esercizio';
  static String get muscleGroup   => _lang == 'en' ? 'Muscle group'     : 'Gruppo muscolare';
  static String get pause         => _lang == 'en' ? 'Pause between exercises (s)' : 'Pausa tra esercizi (s)';

  // ── Azioni ──
  static String get save          => _lang == 'en' ? 'Save'             : 'Salva';
  static String get cancel        => _lang == 'en' ? 'Cancel'           : 'Annulla';
  static String get add           => _lang == 'en' ? 'Add'              : 'Aggiungi';
  static String get delete        => _lang == 'en' ? 'Delete'           : 'Elimina';
  static String get confirm       => _lang == 'en' ? 'Confirm'          : 'Conferma';
  static String get edit          => _lang == 'en' ? 'Edit'             : 'Modifica';

  // ── Allenamento ──
  static String get weight        => _lang == 'en' ? 'Weight (kg)'      : 'Peso (kg)';
  static String get startWorkout  => _lang == 'en' ? 'Start Workout'    : 'Inizia Allenamento';
  static String get nextExercise  => _lang == 'en' ? 'Next exercise'    : 'Prossimo esercizio';
  static String get rest          => _lang == 'en' ? 'Rest'             : 'Recupero';
  static String get set           => _lang == 'en' ? 'Set'              : 'Serie';
  static String get lastTime      => _lang == 'en' ? 'Last time'        : 'Ultima volta';
  static String get suggestion    => _lang == 'en' ? 'Suggestion'       : 'Suggerimento';
  static String get increaseWeight=> _lang == 'en' ? '💡 Consider increasing the weight!'
                                                   : '💡 Potresti aumentare il peso!';

  // ── Promo PT ──
  static String get proTrainer    => _lang == 'en' ? 'Are you a Personal Trainer?'
                                                   : 'Sei un Personal Trainer?';
  static String get proDesc       => _lang == 'en'
      ? 'Manage all your clients with the complete GymApp ecosystem: create custom schedules, monitor progress and communicate directly with your athletes.'
      : 'Gestisci tutti i tuoi clienti con l\'ecosistema completo GymApp: crea schede personalizzate, monitora i progressi e comunica direttamente con i tuoi atleti.';
  static String get contactMe     => _lang == 'en' ? '📧 Contact Gianmarco' : '📧 Contatta Gianmarco';
  static String get proEmail      => 'osare199@gmail.com';

  // ── Settings ──
  static String get language      => _lang == 'en' ? '🌐 Language'      : '🌐 Lingua';
  static String get deleteData    => _lang == 'en' ? 'Delete data'      : 'Cancella dati';
  static String get accentColor   => _lang == 'en' ? 'Accent color'     : 'Colore accento';
  static String get gymAppPro     => '👨‍💼 GymApp Pro';

  // ── Messaggi ──
  static String get savedOk       => _lang == 'en' ? 'Saved!'           : 'Salvato!';
  static String get deletedOk     => _lang == 'en' ? 'Deleted!'         : 'Eliminato!';
  static String get confirmDelete => _lang == 'en' ? 'Confirm delete?'  : 'Confermare eliminazione?';
  static String get noData        => _lang == 'en' ? 'No data yet'      : 'Nessun dato ancora';
}
