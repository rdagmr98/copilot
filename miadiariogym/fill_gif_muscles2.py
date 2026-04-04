#!/usr/bin/env python3
"""
Ricostruisce primaryMuscle, secondaryMuscles, execution, tips e muscleImages
per tutti i 1213 esercizi del GIF catalog.
La logica usa sia il nome che il gifFilename (slug) per massima precisione.
"""
import re

# ─────────────────────────────────────────────────────────────────────────────
#  HELPER
# ─────────────────────────────────────────────────────────────────────────────
def esc(s):
    return s.replace('\\', '\\\\').replace("'", "\\'")

def imgs(*args):
    return list(args)

# ─────────────────────────────────────────────────────────────────────────────
#  CORE LOGIC
#  Restituisce (primaryMuscle, secondaryMuscles, execution, tips, muscleImages)
#  Usa prima il gifFilename (slug), poi il nome, poi la categoria come fallback.
# ─────────────────────────────────────────────────────────────────────────────
def get_info(name, category, gif):
    n = name.lower()
    g = gif.lower()   # gifFilename slug (es. 'barbell-bench-press')
    src = g if g else n   # primary signal

    # ── BENCH PRESS ──────────────────────────────────────────────────────────
    if 'bench-press' in g or 'chest-press' in g or \
       (('bench press' in n or 'chest press' in n) and 'push-up' not in n):
        if 'incline' in src:
            return ('Grande pettorale (fascio clavicolare)', 'Tricipiti, Deltoide anteriore',
                    'Siediti sulla panca inclinata con i piedi a terra. Afferra l\'attrezzo '
                    'con presa più larga delle spalle. Abbassa fino all\'altezza della parte '
                    'alta del petto. Spingi in modo deciso tornando alla posizione di partenza.',
                    'La panca inclinata enfatizza la parte superiore del petto. '
                    'Mantieni le scapole retratte durante tutto il movimento.',
                    imgs('petto.png', 'push.png'))
        if 'decline' in src:
            return ('Grande pettorale (fascio sternale)', 'Tricipiti, Deltoide anteriore',
                    'Sdraiati sulla panca declinata con i piedi bloccati. Afferra l\'attrezzo '
                    'con presa più larga delle spalle. Abbassa fino alla parte bassa del petto. '
                    'Spingi in modo deciso tornando alla posizione di partenza.',
                    'Mantieni le scapole retratte. Controlla la discesa per almeno 2 secondi.',
                    imgs('petto.png', 'push.png'))
        if 'close' in src or 'narrow' in src:
            return ('Tricipiti', 'Grande pettorale, Deltoide anteriore',
                    'Sdraiati sulla panca con presa alla larghezza delle spalle. Abbassa '
                    'il bilanciere mantenendo i gomiti vicini al busto. Spingi verso l\'alto '
                    'contraendo i tricipiti.',
                    'Tieni i gomiti aderenti al corpo. Evita di allargare i gomiti.',
                    imgs('tricipiti.png', 'petto.png'))
        if 'dumbbell' in src or 'db' in src:
            return ('Grande pettorale', 'Tricipiti, Deltoide anteriore',
                    'Sdraiati sulla panca con un manubrio per mano. Abbassa i manubri '
                    'verso il petto tenendo i polsi stabili. Spingi verso l\'alto in modo '
                    'deciso tornando alla posizione di partenza.',
                    'I manubri permettono un range di movimento maggiore. '
                    'Mantieni le scapole retratte durante tutto il movimento.',
                    imgs('petto.png', 'push.png'))
        return ('Grande pettorale', 'Tricipiti, Deltoide anteriore',
                'Sdraiati sulla panca con i piedi a terra. Afferra il bilanciere con presa '
                'più larga delle spalle. Abbassa il bilanciere fino al petto mantenendo i '
                'gomiti a circa 45°. Spingi verso l\'alto in modo deciso.',
                'Retrai le scapole e mantienile bloccate. Non rimbalzare il peso sul petto.',
                imgs('petto.png', 'push.png'))

    # ── PUSH-UP ──────────────────────────────────────────────────────────────
    if 'push-up' in g or 'push-ups' in g or 'pushup' in g or \
       ('press-up' in g) or \
       (('push up' in n or 'push-up' in n or 'pushup' in n or 'press up' in n) and 'bench' not in n):
        if 'diamond' in src or ('close' in src and 'grip' in src) or 'narrow' in src:
            return ('Tricipiti', 'Grande pettorale, Deltoide anteriore',
                    'Posiziona le mani a forma di diamante sotto il petto. Abbassa il corpo '
                    'mantenendo i gomiti vicini al busto. Spingi verso l\'alto contraendo i tricipiti.',
                    'La presa stretta isola i tricipiti. Mantieni il corpo in linea retta.',
                    imgs('tricipiti.png', 'push.png'))
        if 'wide' in src:
            return ('Grande pettorale', 'Tricipiti, Deltoide anteriore',
                    'In posizione di push-up con le mani più larghe delle spalle. Abbassa '
                    'il petto verso il suolo con i gomiti verso l\'esterno. Spingi verso l\'alto.',
                    'La presa larga enfatizza il grande pettorale. Mantieni il corpo in linea retta.',
                    imgs('petto.png', 'push.png'))
        if 'decline' in src:
            return ('Grande pettorale (fascio clavicolare)', 'Tricipiti, Core',
                    'Con i piedi su una superficie rialzata, abbassa il petto verso il suolo. '
                    'Spingi verso l\'alto tornando alla posizione di partenza.',
                    'Più alta è la superficie, più lavora la parte alta del petto.',
                    imgs('petto.png', 'push.png'))
        if 'incline' in src:
            return ('Grande pettorale (fascio sternale)', 'Tricipiti',
                    'Con le mani su una superficie rialzata, abbassa il petto verso le mani. '
                    'Spingi verso l\'alto tornando alla posizione di partenza.',
                    'La versione inclinata è più facile e coinvolge la parte bassa del petto.',
                    imgs('petto.png', 'push.png'))
        return ('Grande pettorale, Tricipiti', 'Deltoide anteriore, Core',
                'In posizione prona con le mani alla larghezza delle spalle. Abbassa il petto '
                'verso il suolo flettendo i gomiti. Spingi verso l\'alto tornando alla posizione '
                'di partenza mantenendo il corpo in linea retta.',
                'Non lasciare che i fianchi cedano verso il basso. Retrai le scapole.',
                imgs('petto.png', 'push.png'))

    # ── CHEST FLY / CABLE FLY / PEC DECK ─────────────────────────────────────
    if any(k in g for k in ['chest-fly', 'cable-fly', 'dumbbell-fly', 'incline-fly',
                              'decline-fly', 'pec-deck', 'peck-deck', 'cable-crossover',
                              'high-cable-crossover', 'low-cable-crossover']) or \
       (any(k in n for k in ['chest fly', 'dumbbell fly', 'pec fly', 'cable fly',
                               'pec deck', 'peck deck', 'cable crossover']) and 'bench' not in n):
        if 'cable' in src or 'crossover' in src:
            return ('Grande pettorale', 'Deltoide anteriore',
                    'In piedi al centro del cavo con una maniglia per mano. Tieni le braccia '
                    'leggermente piegate. Porta le mani verso il centro incrociandole. '
                    'Torna lentamente alla posizione di partenza.',
                    'Mantieni la stessa flessione del gomito durante il movimento. '
                    'Concentrati sulla contrazione del petto a fine movimento.',
                    imgs('petto.png'))
        if 'pec' in src or 'deck' in src:
            return ('Grande pettorale', 'Deltoide anteriore',
                    'Siediti sulla macchina con la schiena appoggiata. Posiziona i gomiti '
                    'sui cuscinetti. Porta le braccia verso il centro contraendo il petto. '
                    'Torna lentamente alla posizione di partenza.',
                    'Non iperestendere le braccia nella fase di apertura. '
                    'Concentrati sulla contrazione del petto.',
                    imgs('petto.png'))
        return ('Grande pettorale', 'Deltoide anteriore',
                'Sdraiati sulla panca con un manubrio per mano. Abbassa le braccia '
                'lateralmente mantenendo una leggera flessione del gomito. Porta i manubri '
                'verso l\'alto descrivendo un arco come se abbracciassi un albero. '
                'Torna lentamente.',
                'Mantieni la stessa flessione del gomito. Controlla la discesa per 2 secondi.',
                imgs('petto.png'))

    # ── DIP ───────────────────────────────────────────────────────────────────
    if 'dip' in g and 'nordic' not in g:
        if 'tricep' in g or 'bench' in g or 'chair' in g or 'assisted' in g:
            return ('Tricipiti', 'Grande pettorale, Deltoide anteriore',
                    'Con le mani sul bordo di una panca, avanza con i glutei fuori. '
                    'Abbassa il corpo flettendo i gomiti a 90°. Spingi verso l\'alto.',
                    'Mantieni il busto verticale per isolare i tricipiti. '
                    'Più ti abbassi, maggiore è il coinvolgimento del petto.',
                    imgs('tricipiti.png'))
        return ('Grande pettorale, Tricipiti', 'Deltoide anteriore',
                'Afferrare le parallele con le braccia tese. Abbassa il corpo inclinando '
                'leggermente il busto in avanti flettendo i gomiti. Spingi verso l\'alto '
                'tornando alla posizione di partenza.',
                'L\'inclinazione in avanti aumenta il coinvolgimento del petto. '
                'La posizione verticale isola i tricipiti.',
                imgs('petto.png', 'tricipiti.png'))

    # ── PULL-UP / CHIN-UP ─────────────────────────────────────────────────────
    if any(k in g for k in ['pull-up', 'pullup', 'chin-up', 'chinup',
                              'muscle-up', 'bar-pull', 'archer-pull']):
        if 'chin' in g or 'supinated' in g or 'underhand' in g:
            return ('Gran dorsale, Bicipiti', 'Romboidi, Trapezio, Deltoide posteriore',
                    'Afferrare la sbarra con presa supinata (palmi verso di te) alla '
                    'larghezza delle spalle. Partendo con le braccia tese, tira il corpo '
                    'verso l\'alto finché il mento supera la sbarra. Abbassa lentamente.',
                    'La presa supinata aumenta il coinvolgimento dei bicipiti. '
                    'Evita di usare lo slancio.',
                    imgs('dorso.png', 'bicipiti.png'))
        if 'wide' in g:
            return ('Gran dorsale', 'Romboidi, Bicipiti, Deltoide posteriore',
                    'Afferrare la sbarra con presa prona larga. Tira il corpo verso l\'alto '
                    'finché il mento supera la sbarra. Abbassa lentamente.',
                    'La presa larga isola il gran dorsale. Inizia dalla retrazione delle scapole.',
                    imgs('dorso.png', 'pull.png'))
        if 'close' in g or 'narrow' in g:
            return ('Gran dorsale, Bicipiti', 'Romboidi, Deltoide posteriore',
                    'Afferrare la sbarra con presa prona stretta. Tira il corpo verso l\'alto '
                    'finché il mento supera la sbarra. Abbassa lentamente.',
                    'La presa stretta aumenta il range di movimento. Retrai le scapole.',
                    imgs('dorso.png', 'bicipiti.png'))
        return ('Gran dorsale', 'Romboidi, Bicipiti, Deltoide posteriore',
                'Afferrare la sbarra con presa prona alla larghezza delle spalle. Partendo '
                'con le braccia tese, tira il corpo verso l\'alto finché il mento supera la '
                'sbarra. Abbassa lentamente tornando alla posizione di partenza.',
                'Inizia il movimento dalla retrazione delle scapole. Evita lo slancio.',
                imgs('dorso.png', 'pull.png'))

    # ── LAT PULLDOWN ──────────────────────────────────────────────────────────
    if 'pulldown' in g or 'pull-down' in g or 'lat-pull' in g:
        if 'straight-arm' in g or 'straight arm' in n:
            return ('Gran dorsale', 'Tricipiti (capo lungo), Core',
                    'In piedi di fronte al cavo alto con le braccia quasi tese. Porta la '
                    'sbarra verso le cosce descrivendo un arco mantenendo le braccia tese. '
                    'Torna lentamente alla posizione di partenza.',
                    'Mantieni le braccia dritte. Concentrati sulla contrazione del gran dorsale.',
                    imgs('dorso.png', 'pull.png'))
        if 'close' in g or 'narrow' in g or 'v-bar' in g:
            return ('Gran dorsale', 'Bicipiti, Romboidi, Deltoide posteriore',
                    'Siediti alla lat machine con presa stretta o neutra. Tira la sbarra '
                    'verso il petto mantenendo i gomiti vicini al corpo. Controlla il ritorno.',
                    'La presa stretta aumenta il range di movimento. Inizia dalla retrazione.',
                    imgs('dorso.png', 'pull.png'))
        return ('Gran dorsale', 'Romboidi, Bicipiti, Deltoide posteriore',
                'Siediti alla lat machine e afferra la sbarra con presa prona più larga '
                'delle spalle. Tira la sbarra verso il petto inclinando leggermente il busto. '
                'Controlla il ritorno alla posizione di partenza.',
                'Inizia dalla retrazione delle scapole. Non portare il busto troppo indietro.',
                imgs('dorso.png', 'pull.png'))

    # ── ROW ───────────────────────────────────────────────────────────────────
    if 'row' in g and 'upright' not in g and 'turkish' not in g:
        if 'cable' in g or 'seated' in g or 'low' in g or 'pulley' in g:
            return ('Gran dorsale, Romboidi', 'Bicipiti, Trapezio, Deltoide posteriore',
                    'Siediti al cavo basso con i piedi sui supporti. Tira la maniglia verso '
                    'il punto vita mantenendo la schiena dritta. Contrai i muscoli della schiena '
                    'e torna lentamente.',
                    'Non arrotondare la schiena. Controlla la fase di allungamento.',
                    imgs('dorso.png', 'bicipiti.png'))
        if 'bent' in g or 'barbell' in g or 't-bar' in g or 'pendlay' in g:
            return ('Gran dorsale, Romboidi', 'Bicipiti, Trapezio, Deltoide posteriore',
                    'In piedi con il busto inclinato a 45°. Afferra il bilanciere con presa '
                    'prona. Tira verso l\'addome mantenendo la schiena neutra. Abbassa lentamente.',
                    'Mantieni la schiena piatta e il core contratto. Evita lo slancio del busto.',
                    imgs('dorso.png', 'bicipiti.png'))
        if 'dumbbell' in g or 'one-arm' in g or 'single-arm' in g:
            return ('Gran dorsale, Romboidi', 'Bicipiti, Deltoide posteriore',
                    'Con una mano e un ginocchio sulla panca. Tira il manubrio verso il '
                    'fianco mantenendo il gomito vicino al corpo. Abbassa lentamente.',
                    'Mantieni la schiena parallela al suolo. '
                    'Ruota leggermente il busto a fine movimento.',
                    imgs('dorso.png', 'bicipiti.png'))
        if 'chest' in g or 'prone' in g or 'incline' in g:
            return ('Gran dorsale, Romboidi', 'Bicipiti, Deltoide posteriore',
                    'Sdraiati sul supporto inclinato con i pesi che pendono. Tira verso il '
                    'busto contraendo i dorsali. Abbassa lentamente.',
                    'Il supporto elimina lo stress lombare. Concentrati sulla retrazione.',
                    imgs('dorso.png', 'bicipiti.png'))
        if 'inverted' in g or 'australian' in g:
            return ('Gran dorsale, Romboidi', 'Bicipiti, Core',
                    'Con il corpo inclinato sotto una sbarra bassa, afferra con presa prona. '
                    'Tira il petto verso la sbarra mantenendo il corpo rigido. Abbassa lentamente.',
                    'Più il corpo è orizzontale, più è difficile. Core sempre contratto.',
                    imgs('dorso.png', 'pull.png'))
        return ('Gran dorsale, Romboidi', 'Bicipiti, Trapezio',
                'Mantieni la schiena in posizione neutra. Tira verso il punto vita o il petto. '
                'Contrai i muscoli della schiena a fine movimento.',
                'Inizia dalla retrazione delle scapole. Controlla la fase eccentrica.',
                imgs('dorso.png', 'bicipiti.png'))

    # ── DEADLIFT ──────────────────────────────────────────────────────────────
    if 'deadlift' in g or 'dead-lift' in g:
        if 'romanian' in g or 'rdl' in g or 'stiff' in g:
            return ('Ischiocrurali, Glutei', 'Lombari, Gran dorsale',
                    'In piedi con i piedi alla larghezza delle anche. Abbassa il bilanciere '
                    'lungo le gambe mantenendo le ginocchia leggermente piegate e la schiena '
                    'dritta. Scendi fino a sentire tensione negli ischiocrurali poi torna su.',
                    'La barra deve sfiorare le gambe durante tutto il movimento. '
                    'Concentrati sull\'allungamento degli ischiocrurali nella discesa.',
                    imgs('femorali.png', 'glutei.png'))
        if 'sumo' in g:
            return ('Quadricipiti, Glutei, Ischiocrurali', 'Lombari, Gran dorsale, Adduttori',
                    'Piedi più larghi delle spalle con le punte verso l\'esterno. Abbassati '
                    'afferrando il bilanciere con presa interna. Spingi con le gambe e stendi '
                    'le anche contemporaneamente mantenendo la schiena dritta.',
                    'Mantieni le ginocchia allineate con le punte dei piedi. '
                    'Il sumo riduce il percorso del bilanciere.',
                    imgs('quadricipiti.png', 'glutei.png', 'femorali.png'))
        if 'trap' in g or 'hex' in g:
            return ('Quadricipiti, Glutei, Ischiocrurali', 'Lombari, Trapezio',
                    'Entra nel trap bar. Piedi alla larghezza delle anche. Abbassati '
                    'afferrando le maniglie con schiena dritta. Spingi con i piedi estendendo '
                    'anche e ginocchia contemporaneamente.',
                    'Il trap bar riduce lo stress sulla colonna. '
                    'Mantieni le spalle in linea con le maniglie.',
                    imgs('quadricipiti.png', 'femorali.png', 'glutei.png'))
        if 'single' in g or 'one-leg' in g or 'unilateral' in g:
            return ('Ischiocrurali, Glutei', 'Lombari, Core',
                    'In piedi su una gamba sola. Abbassa il busto in avanti mantenendo '
                    'la schiena dritta mentre la gamba libera si allunga dietro. '
                    'Torna alla posizione eretta contraendo i glutei.',
                    'Mantieni il bacino livellato. Inizia con un peso leggero.',
                    imgs('femorali.png', 'glutei.png'))
        return ('Ischiocrurali, Glutei, Lombari', 'Quadricipiti, Gran dorsale, Trapezio',
                'In piedi con i piedi alla larghezza delle anche. Abbassati con la schiena '
                'dritta e il petto alto. Spingi i piedi a terra e stendi anche e ginocchia '
                'contemporaneamente mantenendo la barra aderente alle gambe.',
                'Non arrotondare la schiena in nessuna fase. Blocca il core prima di tirare.',
                imgs('femorali.png', 'glutei.png', 'dorso.png'))

    # ── GOOD MORNING ──────────────────────────────────────────────────────────
    if 'good-morning' in g or 'good morning' in n:
        return ('Ischiocrurali, Lombari', 'Glutei, Gran dorsale',
                'In piedi con il bilanciere sulle spalle. Inclina il busto in avanti '
                'mantenendo la schiena dritta e le ginocchia leggermente piegate. '
                'Senti lo stretching degli ischiocrurali. Torna alla posizione eretta.',
                'Non arrotondare la schiena. Inizia con un peso leggero.',
                imgs('femorali.png', 'dorso.png'))

    # ── OVERHEAD / SHOULDER PRESS ─────────────────────────────────────────────
    if 'arnold-press' in g or ('arnold' in g and 'press' in g):
        return ('Deltoide (tutte le fasce)', 'Tricipiti, Trapezio superiore',
                'Seduto con i manubri all\'altezza delle spalle e i palmi verso di te. '
                'Premi verso l\'alto ruotando i polsi verso l\'esterno finché i palmi '
                'guardano avanti. Abbassa tornando alla posizione iniziale.',
                'Esegui la rotazione in modo fluido e continuo. '
                'L\'Arnold press è uno dei pochi esercizi che coinvolge tutte le fasce.',
                imgs('spalle.png', 'tricipiti.png'))

    if any(k in g for k in ['overhead-press', 'shoulder-press', 'military-press',
                              'seated-press', 'standing-press', 'barbell-press',
                              'dumbbell-shoulder-press', 'landmine-press']):
        if 'behind' in g and 'neck' in g:
            return ('Deltoide (fascio laterale e posteriore)', 'Trapezio, Tricipiti',
                    'In posizione seduta, porta il bilanciere dietro la nuca. Spingi verso '
                    'l\'alto estendendo le braccia completamente. Abbassa lentamente.',
                    'Esercizio ad alto rischio; eseguire solo se già praticato. '
                    'Mantieni il collo in posizione neutra.',
                    imgs('spalle.png', 'tricipiti.png'))
        return ('Deltoide (fascio anteriore e laterale)', 'Trapezio superiore, Tricipiti',
                'In piedi o seduto con l\'attrezzo all\'altezza delle spalle. Spingi verso '
                'l\'alto estendendo completamente le braccia. Abbassa lentamente tornando '
                'alla posizione di partenza con il peso all\'altezza delle spalle.',
                'Mantieni il core contratto e la schiena dritta. '
                'Evita di iperestendere la colonna lombare.',
                imgs('spalle.png', 'tricipiti.png'))

    # ── LATERAL RAISE ─────────────────────────────────────────────────────────
    if 'lateral-raise' in g or 'side-raise' in g or 'side-lateral' in g:
        return ('Deltoide laterale', 'Trapezio superiore, Sovraspinato',
                'In piedi con un manubrio per mano lungo i fianchi. Alza le braccia '
                'lateralmente fino all\'altezza delle spalle mantenendo i gomiti '
                'leggermente piegati. Abbassa lentamente.',
                'Non portare le braccia oltre l\'altezza delle spalle. '
                'Ruota leggermente i polsi verso il basso (come versando acqua) '
                'per isolare il deltoide laterale.',
                imgs('spalle.png'))

    # ── FRONT RAISE ───────────────────────────────────────────────────────────
    if 'front-raise' in g or 'anterior-raise' in g:
        return ('Deltoide anteriore', 'Grande pettorale (fascio clavicolare), Trapezio',
                'In piedi con l\'attrezzo davanti alle cosce. Alza le braccia davanti a te '
                'fino all\'altezza delle spalle mantenendo i gomiti leggermente piegati. '
                'Abbassa lentamente.',
                'Mantieni il busto stabile evitando di dondolare. Controlla la discesa.',
                imgs('spalle.png'))

    # ── REAR DELT / FACE PULL ─────────────────────────────────────────────────
    if 'face-pull' in g or 'rear-delt' in g or 'reverse-fly' in g or 'reverse-flye' in g:
        return ('Deltoide posteriore', 'Romboidi, Trapezio medio, Rotatori esterni',
                'Con le braccia davanti a te al cavo o con i manubri, porta l\'attrezzo '
                'verso il viso mantenendo i gomiti alti. Separa le mani portando i pugni '
                'vicino alle orecchie. Torna lentamente.',
                'Mantieni i gomiti all\'altezza delle spalle o leggermente sopra. '
                'Fondamentale per la salute della cuffia dei rotatori.',
                imgs('spalle.png', 'dorso.png'))

    # ── SHRUG ─────────────────────────────────────────────────────────────────
    if 'shrug' in g:
        return ('Trapezio', 'Elevatore della scapola, Romboidi',
                'In piedi con un peso per mano lungo i fianchi. Alza le spalle verso '
                'le orecchie contraendo il trapezio. Mantieni la contrazione un secondo '
                'poi abbassa lentamente.',
                'Evita di ruotare le spalle. Concentrati solo sul movimento verticale.',
                imgs('spalle.png'))

    # ── UPRIGHT ROW ───────────────────────────────────────────────────────────
    if 'upright-row' in g or 'upright row' in n:
        return ('Deltoide, Trapezio', 'Bicipiti, Romboidi',
                'In piedi con l\'attrezzo davanti alle cosce con presa prona. Tira verso '
                'il mento mantenendo i gomiti più alti dei polsi. Abbassa lentamente.',
                'Evita di alzare i gomiti oltre l\'altezza delle spalle. '
                'Una presa più larga riduce il rischio di impingement.',
                imgs('spalle.png', 'dorso.png'))

    # ── CURL (BICIPITI) ───────────────────────────────────────────────────────
    if 'hammer-curl' in g or ('hammer' in g and 'curl' in g):
        return ('Brachioradiale, Bicipiti', 'Brachiale',
                'In piedi con i manubri lungo i fianchi con presa neutra (pollici in su). '
                'Fletti i gomiti portando i manubri verso le spalle. Abbassa lentamente.',
                'Mantieni i gomiti fissi ai fianchi. '
                'La presa neutra enfatizza il brachioradiale rispetto al bicipite.',
                imgs('bicipiti.png'))

    if 'reverse-curl' in g or ('reverse' in g and 'curl' in g and 'wrist' not in g):
        return ('Brachioradiale', 'Bicipiti, Estensori avambraccio',
                'In piedi con l\'attrezzo con presa prona (palmi verso il basso). '
                'Fletti i gomiti portando l\'attrezzo verso le spalle. Abbassa lentamente.',
                'Mantieni i polsi in posizione neutra. '
                'Il curl inverso rinforza i muscoli dell\'avambraccio.',
                imgs('braccia.png'))

    if 'wrist-curl' in g or 'wrist curl' in n:
        return ('Flessori avambraccio', 'Brachioradiale',
                'Siediti con gli avambracci sulle cosce. Afferra l\'attrezzo con presa '
                'supinata. Fletti i polsi verso l\'alto e abbassa lentamente.',
                'Usa un peso leggero. Mantieni gli avambracci fermi sulle cosce.',
                imgs('braccia.png'))

    if 'concentration-curl' in g or 'spider-curl' in g:
        return ('Bicipiti (picco)', 'Brachiale',
                'Seduto con il gomito appoggiato sulla coscia interna. Fletti il gomito '
                'portando il manubrio verso la spalla. Abbassa lentamente.',
                'Ruota il polso verso l\'esterno in cima per massimizzare il picco. '
                'Mantieni il busto fermo.',
                imgs('bicipiti.png'))

    if 'preacher-curl' in g or 'scott-curl' in g:
        return ('Bicipiti', 'Brachiale',
                'Siediti al banco Larry Scott con le braccia appoggiate sul cuscinetto. '
                'Fletti i gomiti portando l\'attrezzo verso le spalle. Abbassa lentamente '
                'quasi fino all\'estensione completa.',
                'Il preacher elimina l\'uso dello slancio. '
                'Non lasciare cadere il peso in basso.',
                imgs('bicipiti.png'))

    if 'zottman' in g:
        return ('Bicipiti, Brachioradiale', 'Brachiale',
                'Esegui la fase di salita con presa supinata. Ruota i polsi in pronazione '
                'in cima. Abbassa con presa prona. Torna supinato in basso.',
                'Il Zottman allena sia flessione che estensione dell\'avambraccio.',
                imgs('bicipiti.png', 'braccia.png'))

    if any(k in g for k in ['barbell-curl', 'dumbbell-curl', 'bicep-curl', 'biceps-curl',
                              'cable-curl', 'ez-bar-curl', 'ez-curl', 'incline-curl',
                              'lying-curl', 'seated-curl', 'arm-curl', 'cross-body-curl']):
        return ('Bicipiti', 'Brachiale, Brachioradiale',
                'In piedi con l\'attrezzo con presa supinata. Fletti i gomiti portando '
                'l\'attrezzo verso le spalle mantenendo i gomiti fissi ai lati del busto. '
                'Abbassa lentamente tornando alla posizione di partenza.',
                'Mantieni i gomiti fissi durante tutto il movimento. '
                'Concentrati sulla contrazione completa in cima.',
                imgs('bicipiti.png'))

    # ── TRICIPITI ─────────────────────────────────────────────────────────────
    if 'rope-pushdown' in g or ('rope' in g and 'pushdown' in g) or ('rope' in g and 'push-down' in g):
        return ('Tricipiti (capo laterale)', 'Capo mediale e lungo',
                'In piedi al cavo alto con la corda. Tieni i gomiti fissi ai lati del busto. '
                'Spingi la corda verso il basso separando le estremità. Ritorna lentamente.',
                'Separa la corda in basso per massimizzare la contrazione. '
                'Mantieni i gomiti fissi.',
                imgs('tricipiti.png'))

    if any(k in g for k in ['pushdown', 'push-down', 'press-down', 'tricep-pushdown']):
        return ('Tricipiti', 'Nessuno significativo',
                'In piedi al cavo alto. Tieni i gomiti fissi ai lati del busto. Spingi '
                'verso il basso estendendo completamente le braccia. Ritorna lentamente.',
                'Mantieni i gomiti fissi. Concentrati sull\'estensione completa.',
                imgs('tricipiti.png'))

    if 'skull-crusher' in g or 'nosebreaker' in g or ('lying' in g and 'tricep' in g):
        return ('Tricipiti (capo lungo)', 'Capo laterale e mediale',
                'Sdraiati sulla panca con l\'attrezzo sopra il petto, braccia tese. Fletti '
                'i gomiti abbassando il peso verso la fronte. Estendi tornando alla posizione.',
                'Mantieni i gomiti fissi puntando verso il soffitto. Controlla la discesa.',
                imgs('tricipiti.png'))

    if 'overhead-tricep' in g or ('overhead' in g and 'tricep' in g) or 'french-press' in g:
        return ('Tricipiti (capo lungo)', 'Capo laterale e mediale',
                'In piedi o seduto con l\'attrezzo sopra la testa, braccia tese. Fletti '
                'i gomiti abbassando il peso dietro la testa. Estendi tornando su.',
                'Mantieni i gomiti puntati verso il soffitto e vicini alla testa. '
                'Il capo lungo è massimamente attivato in posizione allungata.',
                imgs('tricipiti.png'))

    if 'tricep-kickback' in g or ('kickback' in g and 'tricep' in g):
        return ('Tricipiti (capo laterale)', 'Capo mediale',
                'Con il busto inclinato e il gomito piegato a 90°, estendi il braccio '
                'verso l\'indietro fino alla completa estensione. Ripiega lentamente.',
                'Mantieni la parte superiore del braccio parallela al suolo. '
                'Evita lo slancio.',
                imgs('tricipiti.png'))

    if any(k in g for k in ['tricep', 'triceps']) or \
       (any(k in n for k in ['tricep', 'triceps']) and category == 'braccia'):
        return ('Tricipiti', 'Deltoide anteriore, Grande pettorale',
                'Estendi completamente le braccia nella fase concentrica. '
                'Torna lentamente alla posizione di partenza controllando il movimento.',
                'Mantieni i gomiti fermi. Concentrati sulla contrazione completa.',
                imgs('tricipiti.png'))

    # ── SQUAT ─────────────────────────────────────────────────────────────────
    if 'squat' in g:
        if 'hack-squat' in g:
            return ('Quadricipiti', 'Glutei, Ischiocrurali',
                    'Posizionati nella macchina hack squat con le spalle sotto i cuscinetti. '
                    'Scendi flettendo le ginocchia fino a 90° poi spingi verso l\'alto.',
                    'Mantieni le ginocchia allineate con le punte dei piedi. '
                    'La posizione dei piedi cambia il muscolo più coinvolto.',
                    imgs('quadricipiti.png', 'glutei.png'))
        if 'goblet' in g:
            return ('Quadricipiti, Glutei', 'Ischiocrurali, Core',
                    'In piedi con i piedi alla larghezza delle spalle, tieni un manubrio '
                    'davanti al petto. Scendi mantenendo il petto alto. Torna su spingendo '
                    'sui talloni.',
                    'Il peso davanti aiuta la postura verticale. Mantieni le ginocchia allineate.',
                    imgs('quadricipiti.png', 'glutei.png'))
        if 'front-squat' in g:
            return ('Quadricipiti', 'Glutei, Ischiocrurali, Core',
                    'Bilanciere sulla parte anteriore delle spalle con gomiti alti. Scendi '
                    'mantenendo il busto il più verticale possibile. Torna su spingendo.',
                    'I gomiti alti impediscono al bilanciere di scivolare. '
                    'Richiede molta mobilità di polso e caviglia.',
                    imgs('quadricipiti.png', 'glutei.png'))
        if any(k in g for k in ['split', 'bulgarian', 'pistol', 'single-leg']):
            return ('Quadricipiti, Glutei', 'Ischiocrurali, Polpacci',
                    'In posizione di affondo monolaterale. Abbassa il corpo flettendo '
                    'il ginocchio anteriore. Spingi verso l\'alto tornando alla partenza.',
                    'Mantieni il ginocchio anteriore allineato con la punta del piede. '
                    'Corregge gli squilibri tra le gambe.',
                    imgs('quadricipiti.png', 'glutei.png'))
        if 'overhead' in g:
            return ('Quadricipiti, Glutei, Core', 'Ischiocrurali, Spalle, Lombari',
                    'Con il bilanciere sopra la testa, scendi in squat mantenendo le '
                    'braccia tese e stabili. Torna su mantenendo il bilanciere allineato.',
                    'Richiede ottima mobilità di spalle, anche e caviglie. Inizia senza peso.',
                    imgs('quadricipiti.png', 'glutei.png'))
        if 'jump' in g:
            return ('Quadricipiti, Glutei', 'Ischiocrurali, Polpacci',
                    'Scendi in squat poi salta verso l\'alto esplosivamente. '
                    'Atterrai morbidamente flettendo le ginocchia.',
                    'Atterrai sempre in modo morbido. Non bloccare le ginocchia.',
                    imgs('quadricipiti.png', 'glutei.png'))
        return ('Quadricipiti, Glutei', 'Ischiocrurali, Lombari, Core',
                'In piedi con i piedi alla larghezza delle spalle. Abbassa il corpo '
                'flettendo ginocchia e anche come se ti sedessi su una sedia. Scendi '
                'fino a quando le cosce sono parallele al suolo. Spingi sui talloni.',
                'Mantieni il petto alto e le ginocchia allineate con le punte dei piedi. '
                'Non lasciare che le ginocchia collassino verso l\'interno.',
                imgs('quadricipiti.png', 'glutei.png'))

    # ── LUNGE ─────────────────────────────────────────────────────────────────
    if 'lunge' in g:
        if 'lateral' in g or 'side' in g:
            return ('Quadricipiti, Adduttori, Glutei', 'Ischiocrurali',
                    'In piedi con i piedi uniti. Fai un passo laterale ampio mantenendo '
                    'il piede opposto fisso. Abbassa verso il lato flettendo il ginocchio.',
                    'Mantieni il piede opposto completamente a terra. Busto eretto.',
                    imgs('quadricipiti.png', 'glutei.png'))
        if 'reverse' in g or 'backward' in g:
            return ('Quadricipiti, Glutei', 'Ischiocrurali, Polpacci',
                    'Fai un passo indietro abbassando il ginocchio posteriore verso il suolo. '
                    'Il ginocchio anteriore rimane allineato con la caviglia.',
                    'Il reverse lunge è più sicuro per le ginocchia del forward lunge.',
                    imgs('quadricipiti.png', 'glutei.png'))
        if 'walking' in g:
            return ('Quadricipiti, Glutei', 'Ischiocrurali, Polpacci',
                    'Fai un passo avanti abbassando il ginocchio posteriore. Avanza col '
                    'passo successivo alternando le gambe in modo continuo.',
                    'Fai passi lunghi per coinvolgere maggiormente i glutei.',
                    imgs('quadricipiti.png', 'glutei.png'))
        return ('Quadricipiti, Glutei', 'Ischiocrurali, Polpacci',
                'Fai un passo avanti abbassando il ginocchio posteriore verso il suolo. '
                'Il ginocchio anteriore rimane allineato con la caviglia. Spingi tornando.',
                'Mantieni il busto eretto e il core contratto. '
                'Evita che il ginocchio anteriore superi la punta del piede.',
                imgs('quadricipiti.png', 'glutei.png'))

    # ── LEG PRESS ─────────────────────────────────────────────────────────────
    if 'leg-press' in g:
        return ('Quadricipiti, Glutei', 'Ischiocrurali, Polpacci',
                'Siediti nella macchina con i piedi sulla piattaforma alla larghezza delle '
                'anche. Abbassa flettendo le ginocchia fino a 90°. Spingi estendendo le gambe.',
                'Non bloccare le ginocchia in estensione. '
                'I piedi più in alto coinvolgono maggiormente i glutei.',
                imgs('quadricipiti.png', 'glutei.png'))

    # ── LEG EXTENSION ────────────────────────────────────────────────────────
    if 'leg-extension' in g:
        return ('Quadricipiti', 'Nessuno significativo',
                'Siediti alla macchina con i cuscinetti sulle caviglie. Estendi le gambe '
                'verso l\'alto contraendo i quadricipiti. Abbassa lentamente.',
                'Mantieni la contrazione in cima per un secondo. Evita lo slancio.',
                imgs('quadricipiti.png'))

    # ── LEG CURL ─────────────────────────────────────────────────────────────
    if 'leg-curl' in g or 'hamstring-curl' in g or 'lying-leg-curl' in g or 'seated-leg-curl' in g:
        if 'seated' in g:
            return ('Ischiocrurali', 'Gastrocnemio',
                    'Siediti alla macchina con i cuscinetti sulle caviglie. Fletti le '
                    'ginocchia portando i talloni verso i glutei. Abbassa lentamente.',
                    'Il leg curl seduto aumenta il range di movimento. '
                    'Evita di sollevare i glutei dal sedile.',
                    imgs('femorali.png'))
        return ('Ischiocrurali', 'Gastrocnemio',
                'A pancia in giù sulla macchina con i cuscinetti sulle caviglie. Fletti '
                'le ginocchia portando i talloni verso i glutei. Abbassa lentamente.',
                'Non sollevare i fianchi. Mantieni la contrazione in cima un secondo.',
                imgs('femorali.png'))

    # ── NORDIC CURL ───────────────────────────────────────────────────────────
    if 'nordic' in g:
        return ('Ischiocrurali', 'Glutei, Polpacci',
                'In ginocchio con i piedi bloccati. Abbassa lentamente il busto verso '
                'il suolo controllando la discesa con gli ischiocrurali. Usa le mani '
                'per frenare la caduta.',
                'Uno degli esercizi più efficaci per la prevenzione degli infortuni '
                'agli ischiocrurali. Progredisci gradualmente.',
                imgs('femorali.png'))

    # ── HIP THRUST / GLUTE BRIDGE ─────────────────────────────────────────────
    if 'hip-thrust' in g or 'hip-bridge' in g or 'glute-bridge' in g:
        return ('Gluteo grande', 'Ischiocrurali, Core',
                'Con la parte superiore della schiena su una panca e il peso sulle anche. '
                'Spingi le anche verso l\'alto contraendo i glutei. Torna lentamente.',
                'Mantieni la contrazione in cima per un secondo. '
                'Mantieni il mento verso il petto.',
                imgs('glutei.png', 'femorali.png'))

    # ── CALF RAISE ───────────────────────────────────────────────────────────
    if 'calf-raise' in g or 'calf raise' in n or 'standing-calf' in g or 'seated-calf' in g:
        return ('Gastrocnemio, Soleo', 'Tibiale anteriore',
                'In piedi con i talloni oltre il bordo di un rialzo. Alza sulle punte '
                'dei piedi contraendo i polpacci. Abbassa lentamente lasciando scendere '
                'i talloni sotto il livello del rialzo.',
                'Esegui il movimento lentamente in entrambe le fasi. '
                'La pausa in basso aumenta l\'allungamento del polpaccio.',
                imgs('gambe.png'))

    # ── STEP UP ───────────────────────────────────────────────────────────────
    if 'step-up' in g or 'step up' in n:
        return ('Quadricipiti, Glutei', 'Ischiocrurali, Polpacci',
                'In piedi di fronte a una panca. Appoggia un piede sul rialzo e spingi '
                'verso l\'alto. Abbassa lentamente controllando il movimento.',
                'Spingi principalmente con il piede sul rialzo. Mantieni il busto eretto.',
                imgs('quadricipiti.png', 'glutei.png'))

    # ── HIP ABDUCTION / ADDUCTION ────────────────────────────────────────────
    if 'hip-abduction' in g or 'abductor' in g or 'fire-hydrant' in g or 'clamshell' in g:
        return ('Gluteo medio, Gluteo minore', 'TFL',
                'Porta la gamba verso l\'esterno in abduzione controllando il movimento. '
                'Torna lentamente. Mantieni il core stabile.',
                'Non usare lo slancio del busto. Concentrati sull\'isolamento del gluteo medio.',
                imgs('glutei.png'))

    if 'hip-adduction' in g or 'adductor' in g or 'inner-thigh' in g:
        return ('Adduttori dell\'anca', 'Gracile, Pettineo',
                'Porta la gamba verso il centro in adduzione controllando il movimento. '
                'Torna lentamente. Mantieni il core stabile.',
                'Non usare lo slancio. Concentrati sull\'isolamento degli adduttori.',
                imgs('gambe.png'))

    # ── GLUTE KICKBACK ────────────────────────────────────────────────────────
    if 'glute-kickback' in g or 'donkey-kick' in g or 'cable-kickback' in g or \
       ('hip-extension' in g and 'cable' in g):
        return ('Gluteo grande', 'Ischiocrurali, Lombari',
                'In appoggio su mani e ginocchia o in piedi al cavo. Estendi la gamba '
                'verso l\'indietro contraendo il gluteo. Torna lentamente.',
                'Mantieni il core contratto per proteggere la schiena. '
                'Evita di iperestendere la colonna lombare.',
                imgs('glutei.png'))

    # ── PULLOVER ──────────────────────────────────────────────────────────────
    if 'pullover' in g:
        return ('Gran dorsale', 'Grande pettorale, Tricipiti (capo lungo)',
                'Sdraiati sulla panca con l\'attrezzo sopra il petto, braccia quasi tese. '
                'Abbassa il peso dietro la testa mantenendo i gomiti leggermente piegati. '
                'Torna alla posizione di partenza descrivendo un arco.',
                'Mantieni la leggera flessione del gomito. '
                'Il pullover è uno dei pochi esercizi che allunga il gran dorsale.',
                imgs('dorso.png', 'petto.png'))

    # ── KETTLEBELL SWING ──────────────────────────────────────────────────────
    if 'swing' in g and ('kettlebell' in g or 'kb' in g or 'dumbbell' in g):
        return ('Glutei, Ischiocrurali', 'Lombari, Core, Spalle',
                'In piedi con i piedi alla larghezza delle anche. Piega le anche '
                'portando il peso tra le gambe, poi spingi esplosivamente le anche in '
                'avanti facendo oscillare il peso fino all\'altezza delle spalle.',
                'Il movimento viene dalle anche, non dalla schiena. '
                'Mantieni la schiena dritta nella fase di spinta.',
                imgs('glutei.png', 'femorali.png'))

    # ── PLANK ─────────────────────────────────────────────────────────────────
    if 'plank' in g:
        if 'side' in g:
            return ('Obliqui', 'Rettosaddominale, Gluteo medio',
                    'Su un fianco in appoggio sull\'avambraccio con il corpo in linea retta. '
                    'Solleva i fianchi mantenendo la posizione.',
                    'Mantieni i fianchi allineati. Evita che cedano verso il basso.',
                    [])
        return ('Rettosaddominale, Trasverso addome', 'Obliqui, Glutei, Lombari',
                'In posizione prona in appoggio sugli avambracci e sulle punte dei piedi. '
                'Il corpo forma una linea retta dalla testa ai talloni. Mantieni contraendo '
                'il core.',
                'Non lasciare che i fianchi cedano o si alzino. Respira normalmente.',
                [])

    # ── CRUNCH / SIT-UP ───────────────────────────────────────────────────────
    if 'crunch' in g or 'sit-up' in g or 'situp' in g:
        if 'reverse' in g:
            return ('Rettosaddominale (fascio inferiore)', 'Flessori anca, Obliqui',
                    'Sdraiati con le gambe alzate. Porta le ginocchia verso il petto '
                    'sollevando il bacino. Torna lentamente.',
                    'Evita il momentum. Concentrati sul sollevamento del bacino.',
                    [])
        if any(k in g for k in ['oblique', 'twist', 'bicycle', 'russian', 'side']):
            return ('Obliqui', 'Rettosaddominale',
                    'Ruota il busto portando un gomito verso il ginocchio opposto. '
                    'Ripeti dall\'altro lato.',
                    'La rotazione parte dalla vita, non dalla testa.',
                    [])
        return ('Rettosaddominale', 'Obliqui',
                'Sdraiati con le ginocchia piegate. Porta le spalle verso le ginocchia '
                'contraendo l\'addome. Abbassa lentamente.',
                'Non tirare il collo. Concentrati sulla contrazione dell\'addome.',
                [])

    # ── LEG RAISE ─────────────────────────────────────────────────────────────
    if 'leg-raise' in g or 'knee-raise' in g or 'toes-to-bar' in g or 'hanging-leg' in g:
        return ('Rettosaddominale (fascio inferiore), Flessori anca', 'Obliqui',
                'In appeso alla sbarra o sdraiato, porta le gambe verso l\'alto controllando '
                'il movimento. Abbassa lentamente.',
                'Evita di dondolare. Controlla sia la fase ascendente che discendente.',
                [])

    # ── RUSSIAN TWIST ─────────────────────────────────────────────────────────
    if 'russian-twist' in g:
        return ('Obliqui', 'Rettosaddominale, Flessori anca',
                'Seduto con i piedi sollevati e il busto a 45°. Ruota il busto da un '
                'lato all\'altro portando le mani al suolo accanto ai fianchi.',
                'Ruota dalla vita, non solo dalle braccia.',
                [])

    # ── MOUNTAIN CLIMBER ──────────────────────────────────────────────────────
    if 'mountain-climber' in g:
        return ('Rettosaddominale, Flessori anca', 'Spalle, Glutei, Quadricipiti',
                'In posizione di push-up. Porta alternativamente le ginocchia verso il '
                'petto in modo rapido mantenendo i fianchi bassi.',
                'Non alzare i fianchi. Mantieni le spalle sopra i polsi.',
                [])

    # ── AB WHEEL ──────────────────────────────────────────────────────────────
    if 'ab-wheel' in g or 'ab-roller' in g or 'rollout' in g:
        return ('Rettosaddominale, Trasverso addome', 'Gran dorsale, Spalle, Tricipiti',
                'In ginocchio con la ruota davanti. Fai rotolare la ruota in avanti '
                'abbassando il corpo verso il suolo. Tira la ruota verso le ginocchia.',
                'Non lasciare che la schiena si incurvi. Inizia con rollout parziali.',
                [])

    # ── BURPEE ────────────────────────────────────────────────────────────────
    if 'burpee' in g:
        return ('Grande pettorale, Tricipiti, Quadricipiti, Core', 'Spalle, Glutei',
                'Abbassati in squat, appoggia le mani a terra e salta i piedi in posizione '
                'di push-up. Esegui un push-up, salta i piedi verso le mani, poi salta '
                'verso l\'alto con le braccia sopra la testa.',
                'Mantieni il core contratto. Adatta la velocità alla tua forma fisica.',
                imgs('petto.png', 'quadricipiti.png'))

    # ── JUMP / PLYOMETRIC ─────────────────────────────────────────────────────
    if any(k in g for k in ['box-jump', 'jump-squat', 'depth-jump', 'broad-jump', 'jump-lunge']):
        return ('Quadricipiti, Glutei, Polpacci', 'Ischiocrurali, Core',
                'Esegui il movimento esplosivo verso l\'alto o in avanti. Atterrai '
                'morbidamente flettendo le ginocchia. Controlla l\'atterraggio.',
                'Atterrai sempre morbidamente. Non bloccare le ginocchia.',
                imgs('quadricipiti.png', 'glutei.png'))

    # ── JUMP ROPE ─────────────────────────────────────────────────────────────
    if 'jump-rope' in g or 'skipping' in g or 'double-under' in g:
        return ('Polpacci, Sistema cardiovascolare', 'Quadricipiti, Spalle, Core',
                'Tieni le estremità della corda ai lati. Fai ruotare la corda sopra la '
                'testa e salta quando passa sotto i piedi.',
                'Mantieni i salti bassi. Usa i polsi, non le braccia, per far ruotare.',
                imgs('gambe.png'))

    # ── BIKE / CYCLING ────────────────────────────────────────────────────────
    if any(k in g for k in ['bike', 'cycling', 'airbike', 'stationary-bike', 'spin']):
        return ('Quadricipiti, Ischiocrurali, Glutei', 'Polpacci, Core',
                'Pedala mantenendo un ritmo costante. Mantieni la schiena in posizione neutra.',
                'Regola il sellino: le ginocchia non devono iperestendersi.',
                imgs('gambe.png'))

    # ── RUNNING / TREADMILL ───────────────────────────────────────────────────
    if any(k in g for k in ['running', 'sprint', 'jogging', 'treadmill', 'air-runner']):
        return ('Quadricipiti, Ischiocrurali, Glutei', 'Polpacci, Core',
                'Mantieni postura eretta con leggera inclinazione in avanti. '
                'Alterna i passi a ritmo costante. Atterrai con il piede a metà del passo.',
                'Mantieni le spalle rilassate. Adatta il ritmo all\'intensità desiderata.',
                imgs('gambe.png'))

    # ── ROWING MACHINE ───────────────────────────────────────────────────────
    if any(k in g for k in ['rowing-machine', 'air-rower', 'ergometer', 'concept']):
        return ('Gran dorsale, Bicipiti, Quadricipiti', 'Core, Spalle, Glutei',
                'Spingi con le gambe, poi inclina il busto indietro, infine tira il remo '
                'verso l\'addome. Inverti l\'ordine nel ritorno.',
                'Sequenza: gambe → busto → braccia nella trazione.',
                imgs('dorso.png', 'gambe.png'))

    # ── STRETCH / YOGA / MOBILITY ─────────────────────────────────────────────
    if any(k in g for k in ['stretch', 'stretching', 'yoga', 'pose', 'asana',
                              'mobility', 'foam-roll', 'foam-roller', 'release']):
        if any(k in g for k in ['hamstring', 'posterior']):
            return ('Ischiocrurali', 'Lombari, Glutei',
                    'Porta la gamba in posizione di allungamento con la schiena dritta. '
                    'Mantieni per 20-30 secondi respirando profondamente.',
                    'Tensione moderata, mai dolore. Espira allungandoti.',
                    imgs('femorali.png'))
        if any(k in g for k in ['quad', 'thigh', 'hip-flexor', 'psoas', 'iliopsoas']):
            return ('Quadricipiti, Flessori anca', 'Iliopsoas',
                    'Porta la gamba in posizione di allungamento mantenendo il busto eretto. '
                    'Mantieni per 20-30 secondi.',
                    'Mantieni il ginocchio puntato verso il suolo. '
                    'Evita di iperestendere la schiena.',
                    imgs('quadricipiti.png'))
        if any(k in g for k in ['calf', 'ankle', 'achilles', 'soleus']):
            return ('Gastrocnemio, Soleo', 'Tendine d\'Achille',
                    'Posizionati in allungamento del polpaccio. Mantieni 20-30 secondi.',
                    'Tieni il tallone a terra. Piega il ginocchio per allungare il soleo.',
                    imgs('gambe.png'))
        if any(k in g for k in ['shoulder', 'chest', 'pec', 'bicep']):
            return ('Grande pettorale, Deltoide anteriore', 'Bicipiti',
                    'Porta le braccia in posizione di allungamento. Mantieni 20-30 secondi.',
                    'Non forzare oltre il limite di comfort. Respira profondamente.',
                    imgs('petto.png'))
        if any(k in g for k in ['back', 'lat', 'spine', 'thoracic', 'lumbar', 'lower-back']):
            return ('Gran dorsale, Lombari', 'Trapezio, Romboidi',
                    'Porta il corpo in posizione di allungamento della schiena. '
                    'Mantieni 20-30 secondi.',
                    'Respira profondamente. Non forzare oltre il limite di comfort.',
                    imgs('dorso.png'))
        if any(k in g for k in ['hip', 'glute', 'piriform', 'it-band', 'iliotibial', 'pigeon']):
            return ('Glutei, Flessori anca', 'Piriforme, TFL',
                    'Porta la gamba in posizione di allungamento. Mantieni 20-30 secondi.',
                    'Respira profondamente. Non forzare oltre il limite.',
                    imgs('glutei.png'))
        return ('Mobilità articolare generale', 'Muscolatura di supporto',
                'Porta il corpo in posizione di allungamento. Mantieni 20-30 secondi.',
                'Respira profondamente. Non forzare mai oltre il limite naturale.',
                [])

    # ── PRESS GENERICO SPALLE ─────────────────────────────────────────────────
    if 'press' in g and category == 'spalle':
        return ('Deltoide (fascio anteriore e laterale)', 'Trapezio superiore, Tricipiti',
                'In piedi o seduto con l\'attrezzo all\'altezza delle spalle. Spingi verso '
                'l\'alto estendendo completamente le braccia. Abbassa lentamente.',
                'Mantieni il core contratto. Evita di iperestendere la colonna.',
                imgs('spalle.png', 'tricipiti.png'))

    # ── ROW GENERICO DORSO ────────────────────────────────────────────────────
    if 'row' in g and category == 'dorso':
        return ('Gran dorsale, Romboidi', 'Bicipiti, Trapezio',
                'Mantieni la schiena neutra. Tira verso il punto vita. '
                'Contrai i dorsali a fine movimento.',
                'Inizia dalla retrazione delle scapole. Controlla la fase eccentrica.',
                imgs('dorso.png', 'bicipiti.png'))

    # ── CURL GENERICO BRACCIA ─────────────────────────────────────────────────
    if 'curl' in g and category == 'braccia' and 'leg' not in g:
        return ('Bicipiti', 'Brachiale, Brachioradiale',
                'Fletti i gomiti portando il peso verso le spalle. Abbassa lentamente.',
                'Mantieni i gomiti fissi. Non usare lo slancio.',
                imgs('bicipiti.png'))

    # ── FALLBACK PER CATEGORIA ────────────────────────────────────────────────
    cat = {
        'petto':   ('Grande pettorale', 'Tricipiti, Deltoide anteriore',
                    'Esegui il movimento controllando fase eccentrica e concentrica. '
                    'Mantieni le scapole retratte.',
                    'Retrai le scapole per stabilizzare la spalla.',
                    imgs('petto.png')),
        'dorso':   ('Gran dorsale, Romboidi', 'Bicipiti, Trapezio',
                    'Inizia il movimento dalla retrazione delle scapole. Controlla la '
                    'fase di allungamento.',
                    'Non arrotondare la schiena. Controlla la fase eccentrica.',
                    imgs('dorso.png')),
        'spalle':  ('Deltoide', 'Trapezio, Rotatori spalla',
                    'Esegui il movimento controllando fase eccentrica e concentrica. '
                    'Mantieni il core contratto.',
                    'Evita lo slancio del busto. Controlla entrambe le fasi.',
                    imgs('spalle.png')),
        'braccia': ('Bicipiti, Tricipiti', 'Muscoli avambraccio',
                    'Esegui il movimento controllando fase eccentrica e concentrica. '
                    'Mantieni i gomiti fissi.',
                    'Non usare lo slancio. Concentrati sulla contrazione.',
                    imgs('braccia.png')),
        'gambe':   ('Quadricipiti, Glutei', 'Ischiocrurali, Polpacci',
                    'Mantieni la schiena dritta e le ginocchia allineate. '
                    'Controlla la fase eccentrica.',
                    'Core contratto. Non lasciare che le ginocchia collassino.',
                    imgs('gambe.png')),
        'glutei':  ('Gluteo grande', 'Ischiocrurali, Core',
                    'Concentrati sulla contrazione dei glutei. Mantieni il core stabile.',
                    'Mantieni la contrazione in cima. Evita di compensare con la schiena.',
                    imgs('glutei.png')),
        'core':    ('Rettosaddominale, Obliqui', 'Trasverso addome, Lombari',
                    'Contrai l\'addome durante tutto l\'esercizio. Controlla la fase eccentrica.',
                    'Non tirare il collo. Respira normalmente.',
                    []),
        'cardio':  ('Sistema cardiovascolare', 'Muscolatura arti inferiori',
                    'Mantieni un ritmo costante. Postura corretta durante tutto l\'esercizio.',
                    'Inizia a ritmo moderato e aumenta gradualmente.',
                    []),
    }
    if category in cat:
        return cat[category]

    return ('Muscolatura principale coinvolta', 'Muscolatura di supporto',
            'Esegui il movimento lentamente e con controllo. Mantieni una postura corretta.',
            'Inizia con peso moderato per padroneggiare la tecnica.',
            [])


# ─────────────────────────────────────────────────────────────────────────────
#  SOSTITUZIONE NEL FILE DART
# ─────────────────────────────────────────────────────────────────────────────
FILE = r'C:\Users\Gianmarco\app\miadiariogym\app_cliente\lib\gif_exercise_catalog.dart'

with open(FILE, 'r', encoding='utf-8') as f:
    content = f.read()

# Extract (name, nameEn, category, gifFilename) — these fields never have escaped quotes
# Using .*? (non-greedy) to skip over any content between category and gifFilename
ENTRY = re.compile(
    r"ExerciseInfo\(name: '([^']+)', nameEn: '([^']+)', category: '([^']+)',"
    r".*?gifFilename: '([^']*)'\)"
)

def dart_list(lst):
    if not lst:
        return '[]'
    items = ', '.join(f"'{x}'" for x in lst)
    return f'[{items}]'

replaced = 0
def replace_fn(m):
    global replaced
    name, name_en, cat, gif = m.group(1), m.group(2), m.group(3), m.group(4)
    primary, secondary, execution, tips, muscle_imgs = get_info(name, cat, gif)
    replaced += 1
    return (
        f"ExerciseInfo(name: '{name}', nameEn: '{name_en}', category: '{cat}', "
        f"muscleImages: {dart_list(muscle_imgs)}, "
        f"primaryMuscle: '{esc(primary)}', "
        f"secondaryMuscles: '{esc(secondary)}', "
        f"execution: '{esc(execution)}', "
        f"tips: '{esc(tips)}', "
        f"gifFilename: '{gif}')"
    )

new_content = ENTRY.sub(replace_fn, content)

with open(FILE, 'w', encoding='utf-8') as f:
    f.write(new_content)

print(f"Completato: {replaced} esercizi aggiornati.")
