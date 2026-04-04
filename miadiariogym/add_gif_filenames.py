import re

CATALOG_PATH = r"C:\Users\Gianmarco\app\miadiariogym\app_cliente\lib\exercise_catalog.dart"

GIF_MAP = {
    'Panca Piana':                    'bench-press',
    'Distensioni con Manubri':        'alternate-dumbbell-bench-press',
    'Croci ai Cavi':                  'cable-crossover',
    'Panca Inclinata':                'incline-barbell-bench-press',
    'Croci con Manubri':              'dumbbell-fly',
    'Push-Up':                        'push-up',
    'Dip alle Parallele':             'triceps-dips',
    'Stacchi da Terra':               'deadlift',
    'Trazioni alla Sbarra':           'pull-up',
    'Lat Machine':                    'lat-pulldown',
    'Rematore con Bilanciere':        'barbell-bent-over-row',
    'Rematore con Manubrio':          'dumbbell-row',
    'Lento Avanti':                   'barbell-shoulder-press',
    'Alzate Laterali':                'dumbbell-lateral-raise',
    'Alzate Frontali':                'dumbbell-front-raise',
    'Alzate Posteriori':              'bent-over-lateral-raise',
    'Curl con Bilanciere':            'barbell-curl',
    'Curl con Manubri Alternati':     'dumbbell-curl',
    'Curl Martello':                  'hammer-curl',
    'Curl al Cavo Basso':             'cable-curl',
    'French Press':                   'seated-ez-bar-overhead-triceps-extension',
    'Tricipiti ai Cavi':              'rope-pushdown',
    'Dip ai Tricipiti':               'triceps-dips',
    'Squat con Bilanciere':           'squat',
    'Leg Press':                      'leg-press',
    'Affondi':                        'bodyweight-lunge',
    'Leg Extension':                  'leg-extension',
    'Leg Curl':                       'seated-leg-curl',
    'Romanian Deadlift':              'romanian-deadlift',
    'Hip Thrust':                     'barbell-hip-thrusts',
    'Glute Kickback':                 'glute-kickback-machine',
    'Calf Raises':                    'calf-raise',
    'Plank':                          'plank',
    'Crunch':                         'crunch',
    'Russian Twist':                  'russian-twist',
    'Leg Raise':                      'hanging-leg-raises',
    'Clean and Press':                'barbell-clean-and-press',
    'Kettlebell Swing':               'kettlebell-swings',
    'Face Pull':                      'face-pull',
    'Panca Declinata':                'decline-barbell-bench-press',
    'Peck Deck':                      'pec-deck-fly',
    'Pull Over':                      'dumbbell-pullover',
    'Chest Press Macchina':           'chest-press-machine',
    'Pulley Basso':                   'seated-cable-row',
    'Trazioni Presa Neutra':          'neutral-grip-pull-up',
    'Back Extension':                 'hyperextension',
    'Good Morning':                   'good-morning',
    'Arnold Press':                   'arnold-press',
    'Alzate di Spalle':               'barbell-shrug',
    'Push Up Diamante':               'diamond-push-up',
    'Concentration Curl':             'concentration-curl',
    'Scott Curl':                     'dumbbell-scott-curl',
    'Overhead Tricep Extension':      'seated-ez-bar-overhead-triceps-extension',
    'Hip Abductor':                   'hip-abduction-machine',
    'Donkey Kick':                    'donkey-kicks',
    'Bulgarian Split Squat':          'barbell-bulgarian-split-squat',
    'Goblet Squat':                   'kettlebell-goblet-squat',
    'Sumo Deadlift':                  'sumo-deadlift',
    'V Bar Pushdown':                 'v-bar-pushdown',
}

with open(CATALOG_PATH, encoding='utf-8') as f:
    content = f.read()

def add_gif_filename(content, exercise_name, gif_filename):
    name_pattern = "name: '" + exercise_name + "'"
    pos = content.find(name_pattern)
    if pos == -1:
        print(f"NOT FOUND: {exercise_name}")
        return content

    # Find the closing ),  of this ExerciseInfo block
    block_end = content.find('\n  ),', pos)
    if block_end == -1:
        print(f"Could not find block end for: {exercise_name}")
        return content

    block = content[pos:block_end]
    if 'gifFilename' in block:
        print(f"Already has gifFilename: {exercise_name}")
        return content

    insertion = f"\n    gifFilename: '{gif_filename}',"
    content = content[:block_end] + insertion + content[block_end:]
    print(f"OK: {exercise_name} → {gif_filename}")
    return content

for name, gif in GIF_MAP.items():
    content = add_gif_filename(content, name, gif)

with open(CATALOG_PATH, 'w', encoding='utf-8') as f:
    f.write(content)

print(f"\nAggiornato {CATALOG_PATH}")
