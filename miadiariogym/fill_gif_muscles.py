#!/usr/bin/env python3
"""
Riempie primaryMuscle, secondaryMuscles, execution e tips per tutti i 1213 esercizi
nel GIF catalog usando regole keyword sul nome e sulla categoria dell'esercizio.
"""
import re

# ─────────────────────────────────────────────────────────────────────────────
#  REGOLE KEYWORD  →  (primaryMuscle, secondaryMuscles, execution, tips)
#  Controllate nell'ordine: la prima che matcha vince.
# ─────────────────────────────────────────────────────────────────────────────
def get_info(name, category):
    n = name.lower()

    # ── PUSH-UP ──────────────────────────────────────────────────────────────
    if any(k in n for k in ['push-up', 'push up', 'pushup', 'press up']):
        if 'wide' in n:
            return ('Grande pettorale', 'Tricipiti, Deltoide anteriore',
                    'In posizione di push-up con le mani più larghe delle spalle. Abbassa il petto verso il suolo flettendo i gomiti verso l\'esterno. Spingi verso l\'alto tornando alla posizione di partenza.',
                    'La presa larga aumenta il coinvolgimento del petto. Mantieni il corpo in linea retta dalla testa ai talloni.')
        if 'close' in n or 'narrow' in n or 'diamond' in n:
            return ('Tricipiti', 'Grande pettorale, Deltoide anteriore',
                    'In posizione di push-up con le mani ravvicinate sotto il petto. Abbassa il petto verso le mani mantenendo i gomiti vicino al busto. Spingi verso l\'alto contraendo i tricipiti.',
                    'La presa stretta isola i tricipiti. Mantieni i gomiti aderenti al corpo durante tutto il movimento.')
        if 'decline' in n:
            return ('Grande pettorale (fascio clavicolare), Tricipiti', 'Deltoide anteriore, Core',
                    'Con i piedi su una superficie rialzata, abbassa il petto verso il suolo. Spingi verso l\'alto tornando alla posizione di partenza.',
                    'Più alta è la superficie, più lavora la parte alta del petto. Mantieni il core contratto.')
        if 'incline' in n:
            return ('Grande pettorale (fascio sternale), Tricipiti', 'Deltoide anteriore',
                    'Con le mani su una superficie rialzata, abbassa il petto verso le mani. Spingi verso l\'alto tornando alla posizione di partenza.',
                    'La versione inclinata è più facile e coinvolge maggiormente la parte bassa del petto.')
        return ('Grande pettorale, Tricipiti', 'Deltoide anteriore, Core',
                'In posizione di push-up con le mani alla larghezza delle spalle. Abbassa il petto verso il suolo flettendo i gomiti. Spingi verso l\'alto tornando alla posizione di partenza.',
                'Mantieni il corpo perfettamente allineato dalla testa ai talloni. Non lasciare che i fianchi cedano verso il basso.')

    # ── BENCH PRESS ──────────────────────────────────────────────────────────
    if any(k in n for k in ['bench press', 'chest press']):
        if 'incline' in n:
            return ('Grande pettorale (fascio clavicolare)', 'Tricipiti, Deltoide anteriore',
                    'Sdraiati sulla panca inclinata con i piedi a terra. Abbassa l\'attrezzo fino all\'altezza della parte alta del petto. Spingi verso l\'alto in modo deciso.',
                    'Mantieni le scapole retratte e il petto alto. La panca inclinata enfatizza la parte superiore del petto.')
        if 'decline' in n:
            return ('Grande pettorale (fascio sternale)', 'Tricipiti, Deltoide anteriore',
                    'Sdraiati sulla panca declinata con i piedi bloccati. Abbassa l\'attrezzo fino alla parte bassa del petto. Spingi verso l\'alto in modo deciso.',
                    'Mantieni le scapole retratte durante tutto il movimento. Controlla la discesa per almeno 2 secondi.')
        if 'close' in n or 'narrow' in n:
            return ('Tricipiti', 'Grande pettorale, Deltoide anteriore',
                    'Sdraiati sulla panca con presa alla larghezza delle spalle. Abbassa il bilanciere mantenendo i gomiti vicini al busto. Spingi verso l\'alto contraendo i tricipiti.',
                    'Tieni i gomiti aderenti al corpo durante tutto il movimento. Evita di allargare i gomiti per isolare i tricipiti.')
        return ('Grande pettorale', 'Tricipiti, Deltoide anteriore',
                'Sdraiati sulla panca con i piedi a terra. Abbassa l\'attrezzo fino al petto mantenendo i gomiti a circa 45°. Spingi verso l\'alto in modo deciso.',
                'Retrai le scapole e mantienile bloccate. Non rimbalzare il peso sul petto.')

    # ── CHEST FLY / FLYE / CROSSOVER / PEC DECK ──────────────────────────────
    if any(k in n for k in ['chest fly', 'chest flye', 'pec fly', 'pec flye', 'peck fly',
                              'cable crossover', 'cable fly', 'cable flye', 'pec deck', 'peck deck']):
        if 'cable' in n or 'crossover' in n:
            return ('Grande pettorale', 'Deltoide anteriore',
                    'In piedi al centro del cavo con una maniglia per mano. Porta le mani verso il centro incrociandole mantenendo le braccia leggermente piegate. Torna lentamente alla posizione di partenza.',
                    'Mantieni una leggera flessione del gomito. Concentrati sulla contrazione del petto nella fase finale del movimento.')
        if 'pec deck' in n or 'peck deck' in n or 'machine' in n:
            return ('Grande pettorale', 'Deltoide anteriore',
                    'Siediti sulla macchina con la schiena appoggiata. Porta le braccia verso il centro contraendo il petto. Torna lentamente alla posizione di partenza.',
                    'Non iperestendere le braccia nella fase di apertura. Concentrati sulla contrazione del petto.')
        return ('Grande pettorale', 'Deltoide anteriore',
                'Sdraiati sulla panca con un manubrio per mano. Abbassa le braccia lateralmente mantenendo una leggera flessione del gomito. Porta i manubri verso l\'alto contraendo il petto.',
                'Mantieni la stessa flessione del gomito durante tutto il movimento. Controlla la discesa per almeno 2 secondi.')

    # ── DIPS ─────────────────────────────────────────────────────────────────
    if any(k in n for k in ['dip', 'dips']) and 'nordic' not in n:
        if 'bench' in n or 'chair' in n or 'tricep dip' in n:
            return ('Tricipiti', 'Grande pettorale, Deltoide anteriore',
                    'Con le mani sul bordo di una panca, avanza con i glutei fuori e abbassa il corpo flettendo i gomiti a 90°. Spingi verso l\'alto estendendo le braccia.',
                    'Mantieni il busto verticale per isolare i tricipiti. Più ti abbassi, maggiore è il coinvolgimento del petto.')
        return ('Grande pettorale, Tricipiti', 'Deltoide anteriore',
                'Afferrare le parallele con le braccia tese. Abbassa il corpo inclinando il busto in avanti flettendo i gomiti. Spingi verso l\'alto fino alla posizione di partenza.',
                'L\'inclinazione in avanti aumenta il coinvolgimento del petto. La posizione verticale isola i tricipiti.')

    # ── PULL-UP / CHIN-UP ─────────────────────────────────────────────────────
    if any(k in n for k in ['pull-up', 'pull up', 'pullup', 'chin-up', 'chin up', 'chinup']):
        if 'chin' in n or 'supinated' in n or 'underhand' in n:
            return ('Gran dorsale, Bicipiti', 'Romboidi, Trapezio, Deltoide posteriore',
                    'Afferrare la sbarra con presa supinata alla larghezza delle spalle. Tira il corpo verso l\'alto finché il mento supera la sbarra. Abbassa lentamente tornando alla posizione di partenza.',
                    'La presa supinata aumenta il coinvolgimento dei bicipiti. Evita di dondolare usando lo slancio.')
        if 'wide' in n:
            return ('Gran dorsale', 'Romboidi, Bicipiti, Deltoide posteriore',
                    'Afferrare la sbarra con presa prona larga. Tira il corpo verso l\'alto finché il mento supera la sbarra. Abbassa lentamente tornando alla posizione di partenza.',
                    'La presa larga isola maggiormente il gran dorsale. Inizia il movimento dalla retrazione delle scapole.')
        return ('Gran dorsale', 'Romboidi, Bicipiti, Deltoide posteriore',
                'Afferrare la sbarra con presa prona alla larghezza delle spalle. Tira il corpo verso l\'alto finché il mento supera la sbarra. Abbassa lentamente tornando alla posizione di partenza.',
                'Inizia il movimento dalla retrazione delle scapole. Evita di usare lo slancio del corpo.')

    # ── LAT PULLDOWN ──────────────────────────────────────────────────────────
    if any(k in n for k in ['pulldown', 'pull-down', 'lat pulldown', 'lat pull']):
        if 'straight arm' in n or 'straight-arm' in n:
            return ('Gran dorsale', 'Tricipiti (capo lungo), Core',
                    'In piedi di fronte al cavo alto con le braccia quasi tese. Porta la sbarra verso le cosce descrivendo un arco, mantenendo le braccia tese. Torna lentamente alla posizione di partenza.',
                    'Mantieni le braccia dritte durante tutto il movimento. Concentrati sulla contrazione del gran dorsale.')
        if 'close' in n or 'narrow' in n:
            return ('Gran dorsale', 'Bicipiti, Romboidi, Deltoide posteriore',
                    'Siediti alla lat machine con presa stretta o neutra. Tira la sbarra verso il petto contraendo i dorsali. Controlla il ritorno alla posizione di partenza.',
                    'La presa stretta aumenta il range di movimento. Inizia dalla retrazione delle scapole.')
        return ('Gran dorsale', 'Romboidi, Bicipiti, Deltoide posteriore',
                'Siediti alla lat machine e afferra la sbarra con presa prona. Tira la sbarra verso il petto inclinando leggermente il busto. Controlla il ritorno alla posizione di partenza.',
                'Inizia il movimento dalla retrazione delle scapole. Evita di portare il busto troppo indietro.')

    # ── ROW ───────────────────────────────────────────────────────────────────
    if 'row' in n and any(k in n for k in ['barbell', 'dumbbell', 'cable', 'seated', 'bent', 't-bar', 'chest', 'pendlay', 'kroc', 'meadows', 'machine', 'inverted', 'prone']):
        if 'cable' in n or 'seated' in n or 'low' in n or 'pulley' in n:
            return ('Gran dorsale, Romboidi', 'Bicipiti, Trapezio, Deltoide posteriore',
                    'Siediti al cavo basso con i piedi sui supporti. Tira la maniglia verso il punto vita mantenendo la schiena dritta. Contrai i muscoli della schiena e torna lentamente alla posizione di partenza.',
                    'Non arrotondare la schiena durante il movimento. Controlla la fase di allungamento tenendo il core attivo.')
        if 'bent' in n or 'barbell' in n or 't-bar' in n or 'pendlay' in n:
            return ('Gran dorsale, Romboidi', 'Bicipiti, Trapezio, Deltoide posteriore',
                    'In piedi con il busto inclinato a circa 45°, afferra il bilanciere con presa prona. Tira verso l\'addome mantenendo la schiena in posizione neutra. Abbassa lentamente tornando alla posizione di partenza.',
                    'Mantieni la schiena piatta e il core contratto. Evita di usare lo slancio del busto.')
        if 'dumbbell' in n:
            return ('Gran dorsale, Romboidi', 'Bicipiti, Deltoide posteriore',
                    'Con una mano e un ginocchio sulla panca, afferra il manubrio. Tira verso il fianco mantenendo il gomito vicino al corpo. Abbassa lentamente tornando alla posizione di partenza.',
                    'Mantieni la schiena parallela al suolo. Ruota leggermente il busto a fine movimento per una maggiore contrazione.')
        if 'inverted' in n or 'prone' in n:
            return ('Gran dorsale, Romboidi', 'Bicipiti, Trapezio',
                    'Sdraiati su un supporto inclinato con i pesi che pendono. Tira i pesi verso il busto contraendo i muscoli della schiena. Abbassa lentamente tornando alla posizione di partenza.',
                    'Mantieni il petto aderente al supporto durante tutto il movimento. Concentrati sulla retrazione delle scapole.')
        return ('Gran dorsale, Romboidi', 'Bicipiti, Trapezio',
                'Mantieni la schiena in posizione neutra. Tira verso il punto vita o il petto. Contrai i muscoli della schiena a fine movimento.',
                'Inizia il movimento dalla retrazione delle scapole. Controlla la fase eccentrica per 2-3 secondi.')

    # ── DEADLIFT ──────────────────────────────────────────────────────────────
    if any(k in n for k in ['deadlift', 'dead lift', 'dead-lift']):
        if any(k in n for k in ['romanian', 'rdl', 'stiff leg', 'stiff-leg']):
            return ('Ischiocrurali, Glutei', 'Lombari, Gran dorsale',
                    'In piedi con i piedi alla larghezza delle anche. Abbassa il bilanciere lungo le gambe mantenendo le ginocchia leggermente piegate e la schiena dritta. Scendi fino a sentire tensione negli ischiocrurali poi torna su.',
                    'Mantieni la barra aderente alle gambe. Concentrati sulla sensazione di allungamento degli ischiocrurali nella discesa.')
        if 'sumo' in n:
            return ('Quadricipiti, Glutei, Ischiocrurali', 'Lombari, Gran dorsale, Adduttori',
                    'Posizionati con i piedi più larghi delle spalle e le punte verso l\'esterno. Abbassati afferrando il bilanciere con presa interna. Spingi con le gambe e stendi le anche contemporaneamente.',
                    'La posizione sumo riduce il percorso del bilanciere. Mantieni le ginocchia allineate con le punte dei piedi.')
        if 'trap' in n or 'hex' in n:
            return ('Quadricipiti, Glutei, Ischiocrurali', 'Lombari, Trapezio',
                    'Entra nel trap bar con i piedi alla larghezza delle anche. Abbassati afferrando le maniglie mantenendo la schiena dritta. Spingi con i piedi estendendo anche e ginocchia.',
                    'Il trap bar riduce lo stress sulla colonna vertebrale. Mantieni le spalle in linea con le maniglie.')
        return ('Ischiocrurali, Glutei, Lombari', 'Quadricipiti, Gran dorsale, Trapezio',
                'In piedi con i piedi alla larghezza delle anche. Abbassati mantenendo la schiena dritta e il petto alto. Spingi i piedi a terra e stendi le anche e le ginocchia contemporaneamente mantenendo la barra aderente.',
                'Non arrotondare la schiena in nessuna fase del movimento. Blocca il core prima di iniziare la trazione.')

    # ── OVERHEAD / SHOULDER PRESS ─────────────────────────────────────────────
    if any(k in n for k in ['arnold press', 'arnold']):
        return ('Deltoide (tutte le fasce)', 'Tricipiti, Trapezio superiore',
                'Seduto con i manubri all\'altezza delle spalle e i palmi verso di te. Premi verso l\'alto ruotando i polsi verso l\'esterno. Abbassa tornando alla posizione iniziale con la rotazione inversa.',
                'Esegui la rotazione in modo fluido. L\'Arnold press coinvolge tutte le fasce del deltoide.')

    if any(k in n for k in ['overhead press', 'shoulder press', 'military press', 'ohp']):
        if 'behind' in n and 'neck' in n:
            return ('Deltoide (fascio laterale e posteriore)', 'Trapezio, Tricipiti',
                    'In posizione seduta porta il bilanciere dietro la nuca. Spingi verso l\'alto estendendo le braccia. Abbassa lentamente tornando alla posizione di partenza.',
                    'Esercizio ad alto rischio per le spalle; eseguire solo se già praticato. Mantieni il collo in posizione neutra.')
        return ('Deltoide (fascio anteriore e laterale)', 'Trapezio superiore, Tricipiti',
                'In piedi o seduto con l\'attrezzo all\'altezza delle spalle. Spingi verso l\'alto estendendo completamente le braccia. Abbassa lentamente tornando alla posizione di partenza.',
                'Mantieni il core contratto e la schiena dritta. Evita di iperestendere la colonna lombare.')

    # ── LATERAL / FRONT / REAR RAISE ─────────────────────────────────────────
    if any(k in n for k in ['lateral raise', 'side raise', 'side lateral']):
        return ('Deltoide laterale', 'Trapezio superiore, Sovraspinato',
                'In piedi con un manubrio per mano. Alza le braccia lateralmente fino all\'altezza delle spalle mantenendo i gomiti leggermente piegati. Abbassa lentamente.',
                'Non portare le braccia oltre l\'altezza delle spalle. Ruota leggermente i polsi verso l\'interno per isolare il deltoide laterale.')

    if any(k in n for k in ['front raise', 'anterior raise']):
        return ('Deltoide anteriore', 'Grande pettorale (fascio clavicolare), Trapezio',
                'In piedi con i manubri lungo i fianchi. Alza le braccia davanti a te fino all\'altezza delle spalle mantenendo i gomiti leggermente piegati. Abbassa lentamente.',
                'Mantieni il busto stabile evitando di dondolare. Controlla la fase di discesa.')

    if any(k in n for k in ['face pull', 'rear delt', 'rear deltoid', 'reverse fly', 'reverse flye', 'posterior delt']):
        return ('Deltoide posteriore', 'Romboidi, Trapezio medio, Rotatori esterni',
                'Con le braccia davanti, tira l\'attrezzo verso il viso mantenendo i gomiti alti. Separa le mani durante la trazione portando i pugni vicino alle orecchie. Torna lentamente.',
                'Mantieni i gomiti all\'altezza delle spalle. Fondamentale per la salute della cuffia dei rotatori.')

    # ── SHRUG ─────────────────────────────────────────────────────────────────
    if 'shrug' in n:
        return ('Trapezio', 'Elevatore della scapola, Romboidi',
                'In piedi con un peso per mano lungo i fianchi. Alza le spalle verso le orecchie contraendo il trapezio. Mantieni un secondo poi abbassa lentamente.',
                'Evita di ruotare le spalle durante il movimento. Concentrati solo sul movimento verticale.')

    # ── UPRIGHT ROW ───────────────────────────────────────────────────────────
    if 'upright row' in n:
        return ('Deltoide, Trapezio', 'Bicipiti, Romboidi',
                'In piedi con l\'attrezzo davanti alle cosce. Tira verso il mento mantenendo i gomiti più alti dei polsi. Abbassa lentamente tornando alla posizione di partenza.',
                'Evita di alzare i gomiti oltre l\'altezza delle spalle. Una presa più larga riduce il rischio di impingement.')

    # ── CURL (BICIPITI) ───────────────────────────────────────────────────────
    if any(k in n for k in ['hammer curl', 'hammer']) and 'curl' in n:
        return ('Brachioradiale, Bicipiti', 'Brachiale',
                'In piedi con presa neutra (pollici verso l\'alto). Fletti i gomiti portando i manubri verso le spalle. Abbassa lentamente tornando alla posizione di partenza.',
                'Mantieni i gomiti fissi ai lati del busto. La presa neutra enfatizza il brachioradiale.')

    if 'reverse curl' in n or ('reverse' in n and 'curl' in n and 'wrist' not in n):
        return ('Brachioradiale', 'Bicipiti, Estensori dell\'avambraccio',
                'In piedi con l\'attrezzo con presa prona (palmi verso il basso). Fletti i gomiti portando l\'attrezzo verso le spalle. Abbassa lentamente.',
                'Mantieni i polsi in posizione neutra. Questo curl rinforza i muscoli dell\'avambraccio.')

    if 'wrist curl' in n:
        return ('Flessori dell\'avambraccio', 'Brachioradiale',
                'Siediti con gli avambracci sulle cosce. Tieni l\'attrezzo con presa supinata. Fletti i polsi verso l\'alto e abbassa lentamente.',
                'Usa un peso leggero. Mantieni gli avambracci fermi sulle cosce.')

    if any(k in n for k in ['concentration curl', 'spider curl']):
        return ('Bicipiti (picco)', 'Brachiale',
                'Seduto con il gomito appoggiato sulla coscia interna o sul banco larry scott. Fletti il gomito portando il manubrio verso la spalla. Abbassa lentamente.',
                'Mantieni il busto fermo. Ruota leggermente il polso verso l\'esterno in cima per massimizzare la contrazione.')

    if 'preacher curl' in n or 'scott curl' in n:
        return ('Bicipiti', 'Brachiale',
                'Siediti al banco Larry Scott con le braccia appoggiate sul cuscinetto inclinato. Fletti i gomiti portando l\'attrezzo verso le spalle. Abbassa lentamente quasi fino all\'estensione completa.',
                'Non lasciare cadere il peso alla fine della fase eccentrica. Il preacher elimina l\'uso dello slancio del busto.')

    if 'zottman' in n:
        return ('Bicipiti, Brachioradiale', 'Brachiale',
                'Esegui il curl con presa supinata nella salita. Ruota i polsi in posizione prona in cima al movimento. Abbassa con presa prona e torna supinato in basso.',
                'Il Zottman curl allena sia la fase di flessione che quella di estensione dell\'avambraccio.')

    if any(k in n for k in ['bicep curl', 'biceps curl', 'barbell curl', 'dumbbell curl', 'ez curl', 'ez-bar curl', 'cable curl', 'arm curl']) or \
       (('curl' in n) and category == 'braccia' and 'leg' not in n and 'wrist' not in n and 'nordic' not in n):
        return ('Bicipiti', 'Brachiale, Brachioradiale',
                'In piedi con l\'attrezzo con presa supinata. Fletti i gomiti portando l\'attrezzo verso le spalle mantenendo i gomiti fissi ai lati del busto. Abbassa lentamente.',
                'Mantieni i gomiti fissi durante tutto il movimento. Concentrati sulla contrazione completa in cima al movimento.')

    # ── TRICIPITI ─────────────────────────────────────────────────────────────
    if any(k in n for k in ['rope pushdown', 'rope push-down', 'rope press-down']):
        return ('Tricipiti (capo laterale)', 'Capo mediale e lungo del tricipite',
                'In piedi di fronte al cavo alto con la corda. Tieni i gomiti fissi ai lati del busto e spingi la corda verso il basso separando le estremità. Ritorna lentamente.',
                'Separa le estremità della corda in basso per massimizzare la contrazione. Mantieni i gomiti fissi.')

    if any(k in n for k in ['pushdown', 'push-down', 'press-down', 'tricep pushdown', 'triceps pushdown']):
        return ('Tricipiti', 'Nessuno significativo',
                'In piedi di fronte al cavo alto. Tieni i gomiti fissi ai lati del busto e spingi verso il basso estendendo completamente le braccia. Ritorna lentamente.',
                'Mantieni i gomiti fissi durante tutto il movimento. Concentrati sull\'estensione completa.')

    if any(k in n for k in ['skull crusher', 'lying tricep', 'lying ez', 'nosebreaker', 'nose breaker']):
        return ('Tricipiti (capo lungo)', 'Capo laterale e mediale del tricipite',
                'Sdraiati sulla panca con l\'attrezzo sopra il petto con le braccia tese. Fletti i gomiti abbassando il peso verso la fronte. Estendi le braccia tornando alla posizione di partenza.',
                'Mantieni i gomiti fissi puntando verso il soffitto. Controlla la discesa per evitare infortuni.')

    if any(k in n for k in ['overhead tricep', 'overhead extension', 'french press']):
        return ('Tricipiti (capo lungo)', 'Capo laterale e mediale del tricipite',
                'In piedi o seduto con l\'attrezzo sopra la testa. Fletti i gomiti abbassando il peso dietro la testa. Estendi le braccia tornando alla posizione di partenza.',
                'Mantieni i gomiti puntati verso il soffitto e vicini alla testa. Il capo lungo è massimamente attivato in posizione allungata.')

    if 'tricep kickback' in n or ('kickback' in n and 'glute' not in n and 'donkey' not in n):
        return ('Tricipiti (capo laterale)', 'Capo mediale del tricipite',
                'Con il busto inclinato e il gomito piegato a 90°, estendi il braccio verso l\'indietro fino alla completa estensione. Ripiega lentamente.',
                'Mantieni la parte superiore del braccio parallela al suolo. Evita di usare lo slancio.')

    if any(k in n for k in ['tricep', 'triceps']) and any(k in n for k in ['extension', 'press', 'dip', 'push']):
        return ('Tricipiti', 'Deltoide anteriore, Grande pettorale',
                'Esegui il movimento controllando la fase eccentrica e concentrica. Estendi completamente le braccia nella fase concentrica. Torna lentamente.',
                'Mantieni i gomiti fermi durante il movimento. Concentrati sulla contrazione completa.')

    # ── SQUAT ─────────────────────────────────────────────────────────────────
    if 'squat' in n:
        if 'hack' in n:
            return ('Quadricipiti', 'Glutei, Ischiocrurali',
                    'Posizionati nella macchina hack squat con le spalle sotto i cuscinetti. Scendi flettendo le ginocchia fino a 90° poi spingi verso l\'alto.',
                    'Mantieni le ginocchia allineate con le punte dei piedi. La posizione dei piedi determina il muscolo più coinvolto.')
        if 'goblet' in n:
            return ('Quadricipiti, Glutei', 'Ischiocrurali, Core',
                    'In piedi con i piedi alla larghezza delle spalle, tieni un manubrio davanti al petto. Scendi mantenendo il petto alto. Torna su spingendo sui talloni.',
                    'Il peso davanti al petto aiuta a mantenere il busto verticale. Mantieni le ginocchia allineate.')
        if 'front' in n:
            return ('Quadricipiti', 'Glutei, Ischiocrurali, Core',
                    'Posiziona il bilanciere sulla parte anteriore delle spalle. Scendi mantenendo il busto più verticale possibile. Torna su spingendo con i quadricipiti.',
                    'Mantieni i gomiti alti per non far scivolare il bilanciere. Richiede molta mobilità del polso e della caviglia.')
        if any(k in n for k in ['split', 'bulgarian', 'pistol', 'single']):
            return ('Quadricipiti, Glutei', 'Ischiocrurali, Polpacci',
                    'In posizione di affondo monolaterale. Abbassa il corpo flettendo il ginocchio anteriore. Spingi verso l\'alto tornando alla posizione di partenza.',
                    'Mantieni il ginocchio anteriore allineato con la punta del piede. Questo esercizio corregge gli squilibri tra le gambe.')
        if 'overhead' in n:
            return ('Quadricipiti, Glutei, Core', 'Ischiocrurali, Spalle, Lombari',
                    'Con il bilanciere sopra la testa, scendi in squat mantenendo le braccia tese. Torna su mantenendo il bilanciere stabile.',
                    'Richiede ottima mobilità di spalle, anche e caviglie. Inizia senza peso.')
        if 'sumo' in n:
            return ('Quadricipiti, Adduttori, Glutei', 'Ischiocrurali, Lombari',
                    'In piedi con i piedi più larghi delle spalle e le punte verso l\'esterno. Scendi mantenendo il petto alto. Torna su spingendo verso l\'esterno le ginocchia.',
                    'Mantieni le ginocchia allineate con le punte dei piedi. Il sumo squat coinvolge maggiormente gli adduttori.')
        if 'jump' in n:
            return ('Quadricipiti, Glutei', 'Ischiocrurali, Polpacci',
                    'Scendi in squat poi salta verso l\'alto in modo esplosivo. Atterrai morbidamente flettendo le ginocchia.',
                    'Atterrai sempre in modo morbido. Evita di atterrare con le ginocchia bloccate.')
        return ('Quadricipiti, Glutei', 'Ischiocrurali, Lombari, Core',
                'In piedi con i piedi alla larghezza delle spalle. Abbassa il corpo come se ti sedessi su una sedia fino a quando le cosce sono parallele al suolo. Spingi verso l\'alto tornando alla posizione di partenza.',
                'Mantieni il petto alto e le ginocchia allineate con le punte dei piedi. Non lasciare che le ginocchia collassino verso l\'interno.')

    # ── LUNGE ─────────────────────────────────────────────────────────────────
    if any(k in n for k in ['lunge', 'lunges']):
        if 'lateral' in n or 'side' in n:
            return ('Quadricipiti, Adduttori, Glutei', 'Ischiocrurali',
                    'In piedi con i piedi uniti. Fai un passo laterale ampio mantenendo il piede opposto fisso. Abbassa verso il lato flettendo il ginocchio. Torna alla posizione di partenza.',
                    'Mantieni il piede opposto completamente a terra. Il busto rimane eretto durante tutto il movimento.')
        if 'reverse' in n or 'backward' in n:
            return ('Quadricipiti, Glutei', 'Ischiocrurali, Polpacci',
                    'Fai un passo indietro abbassando il ginocchio verso il suolo. Il ginocchio anteriore rimane allineato con la caviglia. Spingi verso l\'alto con la gamba anteriore.',
                    'Il reverse lunge è più sicuro per le ginocchia. Mantieni il busto eretto.')
        if 'walking' in n:
            return ('Quadricipiti, Glutei', 'Ischiocrurali, Polpacci',
                    'Fai un passo avanti abbassando il ginocchio posteriore verso il suolo. Spingi verso l\'alto avanzando con il passo successivo alternando le gambe.',
                    'Mantieni il busto eretto e il core contratto. Fai passi lunghi per coinvolgere maggiormente i glutei.')
        return ('Quadricipiti, Glutei', 'Ischiocrurali, Polpacci',
                'Fai un passo avanti abbassando il ginocchio posteriore verso il suolo. Il ginocchio anteriore rimane allineato con la caviglia. Spingi verso l\'alto tornando alla posizione di partenza.',
                'Mantieni il busto eretto e il core contratto. Evita che il ginocchio anteriore superi la punta del piede.')

    # ── LEG PRESS ─────────────────────────────────────────────────────────────
    if 'leg press' in n:
        return ('Quadricipiti, Glutei', 'Ischiocrurali, Polpacci',
                'Siediti nella macchina con i piedi sulla piattaforma. Abbassa flettendo le ginocchia fino a 90°. Spingi con i piedi estendendo le gambe.',
                'Non bloccare completamente le ginocchia in estensione. I piedi più in alto coinvolgono maggiormente i glutei.')

    # ── LEG EXTENSION ────────────────────────────────────────────────────────
    if 'leg extension' in n:
        return ('Quadricipiti', 'Nessuno significativo',
                'Siediti alla macchina con i cuscinetti sulle caviglie. Estendi le gambe verso l\'alto contraendo i quadricipiti. Abbassa lentamente.',
                'Mantieni la contrazione in cima per un secondo. Evita di usare lo slancio.')

    # ── LEG CURL ─────────────────────────────────────────────────────────────
    if any(k in n for k in ['leg curl', 'hamstring curl', 'lying leg curl', 'seated leg curl']):
        if 'seated' in n:
            return ('Ischiocrurali', 'Gastrocnemio',
                    'Siediti alla macchina con i cuscinetti sulle caviglie. Fletti le ginocchia portando i talloni verso i glutei. Abbassa lentamente.',
                    'Il leg curl seduto aumenta il range di movimento. Evita di sollevare i glutei dal sedile.')
        return ('Ischiocrurali', 'Gastrocnemio',
                'A pancia in giù sulla macchina con i cuscinetti sulle caviglie. Fletti le ginocchia portando i talloni verso i glutei. Abbassa lentamente.',
                'Non sollevare i fianchi durante il movimento. Mantieni la contrazione in cima per un secondo.')

    # ── NORDIC CURL ───────────────────────────────────────────────────────────
    if 'nordic' in n and any(k in n for k in ['curl', 'hamstring']):
        return ('Ischiocrurali', 'Glutei, Polpacci',
                'In ginocchio con i piedi bloccati, abbassa lentamente il busto verso il suolo controllando la discesa con gli ischiocrurali. Usa le mani per frenare la caduta.',
                'Uno degli esercizi più efficaci per la prevenzione degli infortuni agli ischiocrurali. Progredisci gradualmente.')

    # ── HIP THRUST / GLUTE BRIDGE ─────────────────────────────────────────────
    if any(k in n for k in ['hip thrust', 'hip bridge', 'glute bridge', 'glute thrust', 'barbell hip']):
        return ('Gluteo grande', 'Ischiocrurali, Core',
                'Con la parte superiore della schiena su una panca e il peso sulle anche. Spingi le anche verso l\'alto contraendo i glutei. Torna lentamente alla posizione di partenza.',
                'Mantieni la contrazione dei glutei in cima per un secondo. Mantieni il mento verso il petto.')

    # ── CALF RAISE ───────────────────────────────────────────────────────────
    if any(k in n for k in ['calf raise', 'calf press', 'seated calf', 'standing calf', 'donkey calf']):
        return ('Gastrocnemio, Soleo', 'Tibiale anteriore',
                'In piedi con i talloni oltre il bordo di un rialzo. Alza sulle punte dei piedi contraendo i polpacci. Abbassa lentamente lasciando scendere i talloni sotto il livello.',
                'Esegui il movimento lentamente in entrambe le fasi. Una pausa in basso aumenta l\'allungamento del polpaccio.')

    # ── STEP UP ───────────────────────────────────────────────────────────────
    if 'step up' in n or 'step-up' in n:
        return ('Quadricipiti, Glutei', 'Ischiocrurali, Polpacci',
                'In piedi di fronte a una panca. Appoggia un piede sul rialzo e spingi verso l\'alto. Abbassa lentamente tornando alla posizione di partenza.',
                'Spingi principalmente con il piede sul rialzo. Mantieni il busto eretto.')

    # ── GOOD MORNING ─────────────────────────────────────────────────────────
    if 'good morning' in n:
        return ('Ischiocrurali, Lombari', 'Glutei, Gran dorsale',
                'In piedi con il bilanciere sulle spalle. Inclina il busto in avanti mantenendo la schiena dritta e le ginocchia leggermente piegate. Senti lo stretching degli ischiocrurali. Torna alla posizione eretta.',
                'Non arrotondare la schiena. Inizia con un peso leggero.')

    # ── HIP ABDUCTION / ADDUCTION ────────────────────────────────────────────
    if any(k in n for k in ['hip abduction', 'abductor', 'fire hydrant', 'clamshell', 'glute medius', 'side lying abduction']):
        return ('Gluteo medio, Gluteo minore', 'TFL (tensore della fascia lata)',
                'Porta la gamba verso l\'esterno in abduzione controllando il movimento. Torna lentamente alla posizione di partenza. Mantieni il core stabile.',
                'Non usare lo slancio del busto. Concentrati sull\'isolamento del gluteo medio.')

    if any(k in n for k in ['hip adduction', 'adductor', 'inner thigh']) and 'sumo' not in n:
        return ('Adduttori dell\'anca', 'Gracile, Pettineo',
                'Porta la gamba verso il centro in adduzione controllando il movimento. Torna lentamente alla posizione di partenza. Mantieni il core stabile.',
                'Non usare lo slancio del busto. Concentrati sull\'isolamento degli adduttori.')

    # ── GLUTE KICKBACK / DONKEY KICK ─────────────────────────────────────────
    if any(k in n for k in ['glute kickback', 'donkey kick', 'cable kickback', 'hip extension', 'donkey']):
        return ('Gluteo grande', 'Ischiocrurali, Lombari',
                'In appoggio su mani e ginocchia o in piedi al cavo. Estendi la gamba verso l\'indietro contraendo il gluteo. Torna lentamente alla posizione di partenza.',
                'Mantieni il core contratto per proteggere la schiena. Evita di iperestendere la colonna lombare.')

    # ── PULLOVER ──────────────────────────────────────────────────────────────
    if 'pullover' in n:
        return ('Gran dorsale', 'Grande pettorale, Tricipiti (capo lungo)',
                'Sdraiati sulla panca con l\'attrezzo sopra il petto. Abbassa il peso dietro la testa mantenendo i gomiti leggermente piegati. Torna alla posizione di partenza.',
                'Mantieni una leggera flessione del gomito. Il pullover allunga il gran dorsale.')

    # ── PLANK ─────────────────────────────────────────────────────────────────
    if 'plank' in n:
        if 'side' in n:
            return ('Obliqui', 'Rettosaddominale, Gluteo medio',
                    'Su un fianco in appoggio sull\'avambraccio con il corpo in linea retta. Solleva i fianchi mantenendo la posizione.',
                    'Mantieni i fianchi allineati. Evita che cedano verso il basso.')
        return ('Rettosaddominale, Trasverso dell\'addome', 'Obliqui, Glutei, Lombari',
                'In posizione prona in appoggio sugli avambracci. Il corpo forma una linea retta dalla testa ai talloni. Mantieni la posizione contraendo il core.',
                'Non lasciare che i fianchi cedano o si alzino. Respira normalmente.')

    # ── CRUNCH / SIT-UP ───────────────────────────────────────────────────────
    if any(k in n for k in ['crunch', 'sit-up', 'situp', 'sit up']):
        if 'reverse' in n:
            return ('Rettosaddominale (fascio inferiore)', 'Flessori dell\'anca, Obliqui',
                    'Sdraiati con le gambe alzate. Porta le ginocchia verso il petto sollevando il bacino. Torna lentamente.',
                    'Evita di usare il momentum. Concentrati sul sollevamento del bacino con l\'addome inferiore.')
        if any(k in n for k in ['oblique', 'side', 'bicycle', 'russian', 'twist']):
            return ('Obliqui', 'Rettosaddominale',
                    'Sdraiati con le mani dietro la testa. Ruota il busto portando un gomito verso il ginocchio opposto. Ripeti dall\'altro lato.',
                    'Evita di tirare il collo con le mani. La rotazione parte dalla vita.')
        return ('Rettosaddominale', 'Obliqui',
                'Sdraiati con le ginocchia piegate. Porta le spalle verso le ginocchia contraendo l\'addome. Abbassa lentamente.',
                'Non tirare il collo con le mani. Concentrati sulla contrazione dell\'addome.')

    # ── LEG RAISE ─────────────────────────────────────────────────────────────
    if any(k in n for k in ['leg raise', 'knee raise', 'toes to bar', 'hanging leg', 'captain', 'ab strap', 'hanging knee']):
        return ('Rettosaddominale (fascio inferiore), Flessori dell\'anca', 'Obliqui',
                'In appeso alla sbarra o sdraiato, porta le gambe verso l\'alto. Abbassa lentamente controllando il movimento.',
                'Evita di dondolare quando appeso. Controlla il movimento sia nella fase ascendente che discendente.')

    # ── RUSSIAN TWIST ─────────────────────────────────────────────────────────
    if 'russian twist' in n or 'oblique twist' in n:
        return ('Obliqui', 'Rettosaddominale, Flessori dell\'anca',
                'Seduto con i piedi sollevati e il busto a 45°. Ruota il busto da un lato all\'altro portando le mani al suolo accanto ai fianchi.',
                'Ruota dalla vita, non solo dalle braccia. Più inclini il busto verso il basso, più è difficile.')

    # ── MOUNTAIN CLIMBER ──────────────────────────────────────────────────────
    if 'mountain climber' in n:
        return ('Rettosaddominale, Flessori dell\'anca', 'Spalle, Glutei, Quadricipiti',
                'In posizione di push-up. Porta alternativamente le ginocchia verso il petto in modo rapido mantenendo i fianchi bassi.',
                'Non alzare i fianchi. Mantieni le spalle sopra i polsi.')

    # ── AB WHEEL / ROLLOUT ────────────────────────────────────────────────────
    if any(k in n for k in ['ab wheel', 'ab roller', 'rollout', 'wheel rollout']):
        return ('Rettosaddominale, Trasverso dell\'addome', 'Gran dorsale, Spalle, Tricipiti',
                'In ginocchio con la ruota davanti. Fai rotolare la ruota in avanti abbassando il corpo verso il suolo. Tira la ruota verso le ginocchia tornando alla posizione di partenza.',
                'Non lasciare che la schiena si incurvi. Inizia con rollout parziali.')

    # ── KETTLEBELL SWING ──────────────────────────────────────────────────────
    if 'swing' in n and ('kettlebell' in n or 'kb' in n or 'dumbbell' in n):
        return ('Glutei, Ischiocrurali', 'Lombari, Core, Spalle',
                'In piedi con i piedi alla larghezza delle anche. Piega le anche portando il peso tra le gambe poi spingi esplosivamente le anche in avanti.',
                'Il movimento viene dalle anche, non dalla schiena. Mantieni la schiena dritta durante la spinta.')

    # ── CABLE PULL THROUGH ────────────────────────────────────────────────────
    if 'pull through' in n:
        return ('Glutei, Ischiocrurali', 'Lombari, Core',
                'In piedi di fronte al cavo basso con la corda tra le gambe. Inclinati in avanti piegando le anche mantenendo la schiena dritta. Spingi le anche in avanti tornando alla posizione eretta.',
                'Il movimento viene principalmente dalle anche. Mantieni la schiena in posizione neutra.')

    # ── BURPEE ────────────────────────────────────────────────────────────────
    if 'burpee' in n:
        return ('Grande pettorale, Tricipiti, Quadricipiti, Core', 'Spalle, Glutei',
                'Abbassati in squat, appoggia le mani a terra e salta i piedi in posizione di push-up. Esegui un push-up, salta i piedi verso le mani, poi salta verso l\'alto con le braccia sopra la testa.',
                'Mantieni il core contratto durante tutto il movimento. Adatta la velocità alla tua forma fisica.')

    # ── JUMP / PLYOMETRIC ─────────────────────────────────────────────────────
    if any(k in n for k in ['box jump', 'jump squat', 'jump lunge', 'depth jump', 'broad jump']):
        return ('Quadricipiti, Glutei, Polpacci', 'Ischiocrurali, Core',
                'Esegui il movimento esplosivo verso l\'alto o in avanti. Atterrai morbidamente flettendo le ginocchia. Mantieni il controllo durante la fase di atterraggio.',
                'Atterrai sempre in modo morbido con le ginocchia leggermente piegate. Evita di atterrare con le ginocchia bloccate.')

    # ── JUMPING JACK ──────────────────────────────────────────────────────────
    if 'jumping jack' in n or 'jumping jacks' in n:
        return ('Sistema cardiovascolare', 'Quadricipiti, Gluteo medio, Spalle',
                'In piedi con i piedi uniti. Salta aprendo le gambe e portando le braccia sopra la testa. Salta tornando alla posizione di partenza.',
                'Mantieni le ginocchia leggermente piegate durante il salto. Atterrai morbidamente sulle punte dei piedi.')

    # ── JUMP ROPE / SKIPPING ──────────────────────────────────────────────────
    if any(k in n for k in ['jump rope', 'skipping', 'rope skip', 'double under']):
        return ('Polpacci, Sistema cardiovascolare', 'Quadricipiti, Spalle, Core',
                'Tieni le estremità della corda ai lati del corpo. Fai ruotare la corda sopra la testa e salta quando passa sotto i piedi.',
                'Mantieni i salti bassi. Usa i polsi, non le braccia, per far ruotare la corda.')

    # ── BIKE / CYCLING ────────────────────────────────────────────────────────
    if any(k in n for k in ['bike', 'cycling', 'cycle', 'stationary bike', 'spin', 'airbike']):
        return ('Quadricipiti, Ischiocrurali, Glutei', 'Polpacci, Core',
                'Pedala mantenendo un ritmo costante. Mantieni una postura corretta con la schiena in posizione neutra.',
                'Regola il sellino in modo che le ginocchia non si iperestendano. Mantieni una cadenza regolare.')

    # ── RUNNING / TREADMILL ───────────────────────────────────────────────────
    if any(k in n for k in ['running', 'sprint', 'jogging', 'treadmill', 'air runner']):
        return ('Quadricipiti, Ischiocrurali, Glutei', 'Polpacci, Core',
                'Mantieni una postura eretta con leggera inclinazione in avanti. Alterna i passi a ritmo costante. Atterrai con il piede a metà del passo.',
                'Mantieni le spalle rilassate. Adatta il ritmo all\'intensità desiderata.')

    # ── ROWING MACHINE ───────────────────────────────────────────────────────
    if any(k in n for k in ['rowing machine', 'ergometer', 'concept', 'row machine', 'air rower']):
        return ('Gran dorsale, Bicipiti, Quadricipiti', 'Core, Spalle, Glutei',
                'Spingi con le gambe, poi inclina il busto indietro, infine tira il remo verso l\'addome. Inverte l\'ordine nel ritorno.',
                'Sequenza: gambe → busto → braccia nella trazione. Inversa nel ritorno: braccia → busto → gambe.')

    # ── STRETCHING / YOGA / MOBILITA' ────────────────────────────────────────
    if any(k in n for k in ['stretch', 'stretching', 'yoga', 'pose', 'asana', 'mobility', 'flexibility',
                              'foam roll', 'foam roller', 'myofascial', 'massage', 'release', 'roll out']):
        if any(k in n for k in ['hamstring', 'posterior thigh']):
            return ('Ischiocrurali', 'Lombari, Glutei',
                    'Porta la gamba in posizione di allungamento mantenendo la schiena dritta. Mantieni per 20-30 secondi respirando profondamente.',
                    'Senti una tensione moderata, mai dolore. Espira mentre ti allunghi.')
        if any(k in n for k in ['quad', 'thigh', 'rectus femoris', 'hip flexor', 'psoas', 'iliopsoas']):
            return ('Quadricipiti, Flessori dell\'anca', 'Iliopsoas',
                    'Porta la gamba in posizione di allungamento mantenendo il busto eretto. Mantieni per 20-30 secondi.',
                    'Mantieni il ginocchio puntato verso il suolo. Evita di iperestendere la schiena.')
        if any(k in n for k in ['calf', 'ankle', 'achilles', 'soleus']):
            return ('Gastrocnemio, Soleo', 'Tendine d\'Achille',
                    'Posizionati in allungamento del polpaccio. Mantieni per 20-30 secondi. Ripeti dall\'altro lato.',
                    'Tieni il tallone a terra. Per allungare il soleo, piega leggermente il ginocchio.')
        if any(k in n for k in ['shoulder', 'chest', 'pec', 'bicep', 'anterior']):
            return ('Grande pettorale, Deltoide anteriore, Bicipiti', 'Pettorali minori',
                    'Porta le braccia in posizione di allungamento. Mantieni per 20-30 secondi respirando profondamente.',
                    'Non forzare oltre il limite di comfort. Respira profondamente per favorire il rilascio.')
        if any(k in n for k in ['back', 'lat', 'spine', 'thoracic', 'lumbar', 'lower back']):
            return ('Gran dorsale, Lombari', 'Trapezio, Romboidi',
                    'Porta il corpo in posizione di allungamento della schiena. Mantieni per 20-30 secondi.',
                    'Respira profondamente per favorire il rilascio. Non forzare oltre il limite di comfort.')
        if any(k in n for k in ['hip', 'glute', 'piriform', 'it band', 'iliotibial', 'pigeon']):
            return ('Glutei, Flessori dell\'anca', 'Piriforme, TFL',
                    'Porta la gamba o l\'anca in posizione di allungamento. Mantieni per 20-30 secondi.',
                    'Respira profondamente. Non forzare oltre il limite di comfort.')
        if any(k in n for k in ['neck', 'cervical', 'trap']):
            return ('Trapezio, Elevatore della scapola, Sternocleidomastoideo', 'Romboidi',
                    'Inclina lentamente la testa verso un lato. Mantieni per 20-30 secondi. Ripeti dall\'altro lato.',
                    'Esegui il movimento lentamente. Non forzare mai oltre il naturale limite di movimento.')
        return ('Mobilità articolare generale', 'Muscolatura di supporto',
                'Porta il corpo in posizione di allungamento. Mantieni per 20-30 secondi respirando profondamente.',
                'Respira profondamente durante l\'allungamento. Non forzare mai oltre il limite naturale.')

    # ── ROWING (SPORT) ───────────────────────────────────────────────────────
    if 'rowing' in n and 'machine' not in n and 'row' not in n:
        return ('Sistema cardiovascolare, Dorsali', 'Braccia, Core',
                'Mantieni un ritmo costante coordinando gambe, busto e braccia. Spingi con le gambe nella fase di trazione.',
                'Mantieni la schiena in posizione neutra durante tutto il movimento.')

    # ── PRESS generico su spalle ──────────────────────────────────────────────
    if 'press' in n and category == 'spalle':
        return ('Deltoide (fascio anteriore e laterale)', 'Trapezio superiore, Tricipiti',
                'In piedi o seduto con l\'attrezzo all\'altezza delle spalle. Spingi verso l\'alto estendendo le braccia. Abbassa lentamente.',
                'Mantieni il core contratto. Evita di iperestendere la colonna lombare.')

    # ── ROW generico su dorso ─────────────────────────────────────────────────
    if 'row' in n and category == 'dorso':
        return ('Gran dorsale, Romboidi', 'Bicipiti, Trapezio',
                'Mantieni la schiena in posizione neutra. Tira verso il punto vita o il petto. Contrai i muscoli della schiena a fine movimento.',
                'Inizia il movimento dalla retrazione delle scapole. Controlla la fase eccentrica.')

    # ── CURL generico su braccia ──────────────────────────────────────────────
    if 'curl' in n and category == 'braccia' and 'leg' not in n:
        return ('Bicipiti', 'Brachiale, Brachioradiale',
                'Fletti i gomiti portando il peso verso le spalle mantenendo i gomiti fissi. Abbassa lentamente.',
                'Mantieni i gomiti fissi. Non usare lo slancio del busto.')

    # ── EXTENSION generico su braccia ────────────────────────────────────────
    if 'extension' in n and category == 'braccia':
        return ('Tricipiti', 'Nessuno significativo',
                'Estendi completamente le braccia nella fase concentrica. Torna lentamente alla posizione di partenza.',
                'Mantieni i gomiti fermi. Concentrati sulla contrazione completa.')

    # ── FALLBACK PER CATEGORIA ────────────────────────────────────────────────
    cat_fallback = {
        'petto': ('Grande pettorale', 'Tricipiti, Deltoide anteriore',
                  'Esegui il movimento controllando la fase eccentrica e concentrica. Mantieni le scapole retratte durante tutto l\'esercizio.',
                  'Mantieni una respirazione controllata. Retrai le scapole per stabilizzare la spalla.'),
        'dorso': ('Gran dorsale, Romboidi', 'Bicipiti, Trapezio',
                  'Esegui il movimento controllando la fase eccentrica e concentrica. Inizia dalla retrazione delle scapole.',
                  'Non arrotondare la schiena. Controlla la fase di allungamento.'),
        'spalle': ('Deltoide', 'Trapezio, Rotatori della spalla',
                   'Esegui il movimento controllando la fase eccentrica e concentrica. Mantieni il core contratto.',
                   'Evita di usare lo slancio del busto. Controlla il movimento in entrambe le fasi.'),
        'braccia': ('Bicipiti, Tricipiti', 'Muscoli dell\'avambraccio',
                    'Esegui il movimento controllando la fase eccentrica e concentrica. Mantieni i gomiti fissi.',
                    'Non usare lo slancio del busto. Concentrati sulla contrazione muscolare.'),
        'gambe': ('Quadricipiti, Glutei', 'Ischiocrurali, Polpacci',
                  'Esegui il movimento mantenendo la schiena dritta e le ginocchia allineate. Controlla la fase eccentrica.',
                  'Mantieni il core contratto. Non lasciare che le ginocchia collassino verso l\'interno.'),
        'glutei': ('Gluteo grande', 'Ischiocrurali, Core',
                   'Esegui il movimento concentrandoti sulla contrazione dei glutei. Mantieni il core stabile.',
                   'Mantieni la contrazione in cima al movimento. Evita di compensare con la schiena.'),
        'core': ('Rettosaddominale, Obliqui', 'Trasverso dell\'addome, Lombari',
                 'Esegui il movimento contraendo l\'addome. Mantieni il core attivo durante tutto l\'esercizio.',
                 'Non tirare il collo con le mani. Respira normalmente.'),
        'cardio': ('Sistema cardiovascolare', 'Muscolatura degli arti inferiori',
                   'Esegui il movimento mantenendo un ritmo costante. Mantieni una postura corretta.',
                   'Inizia a ritmo moderato e aumenta gradualmente l\'intensità.'),
    }
    if category in cat_fallback:
        return cat_fallback[category]

    # ── ULTIMATE FALLBACK ─────────────────────────────────────────────────────
    return ('Muscolatura principale coinvolta', 'Muscolatura di supporto',
            'Esegui il movimento lentamente e con controllo in entrambe le fasi. Mantieni una postura corretta.',
            'Inizia con un peso moderato per padroneggiare la tecnica. Mantieni una respirazione controllata.')


# ─────────────────────────────────────────────────────────────────────────────
#  SOSTITUZIONE NEL FILE DART
# ─────────────────────────────────────────────────────────────────────────────
FILE = r'C:\Users\Gianmarco\app\miadiariogym\app_cliente\lib\gif_exercise_catalog.dart'

with open(FILE, 'r', encoding='utf-8') as f:
    content = f.read()

PATTERN = re.compile(
    r"ExerciseInfo\(name: '([^']+)', nameEn: '([^']+)', category: '([^']+)', "
    r"muscleImages: \[\], primaryMuscle: '', secondaryMuscles: '', execution: '', tips: '', "
    r"gifFilename: '([^']*)'\)"
)

def escape_dart(s):
    return s.replace("\\", "\\\\").replace("'", "\\'")

replaced = 0
def replace_fn(m):
    global replaced
    name, name_en, cat, gif = m.group(1), m.group(2), m.group(3), m.group(4)
    primary, secondary, execution, tips = get_info(name, cat)
    replaced += 1
    return (
        f"ExerciseInfo(name: '{name}', nameEn: '{name_en}', category: '{cat}', "
        f"muscleImages: [], primaryMuscle: '{escape_dart(primary)}', "
        f"secondaryMuscles: '{escape_dart(secondary)}', "
        f"execution: '{escape_dart(execution)}', "
        f"tips: '{escape_dart(tips)}', "
        f"gifFilename: '{gif}')"
    )

new_content = PATTERN.sub(replace_fn, content)

with open(FILE, 'w', encoding='utf-8') as f:
    f.write(new_content)

print(f"Completato: {replaced} esercizi aggiornati.")
