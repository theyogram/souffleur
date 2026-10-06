# PRD — Souffleur

> Téléprompteur macOS flottant qui suit la voix, mot par mot.
> Téléprompteur perso et minimaliste, sans compte ni cloud.

| | |
|---|---|
| **Nom de code** | Souffleur (le souffleur, au théâtre, c'est celui qui chuchote le texte) |
| **Plateforme** | macOS 26 (Tahoe) et plus, Apple Silicon |
| **Auteur** | Théo |
| **Date** | 30 septembre 2026 |
| **Statut** | Brouillon v1, prêt à implémenter |
| **Utilisateur cible** | Un seul : moi. Pas de compte, pas de cloud, pas de licence. |

---

## 1. TL;DR

Une petite fenêtre transparente et redimensionnable, toujours au premier plan, que je place juste sous la webcam. Elle affiche mon script en gros. Quand je parle, le texte défile tout seul en suivant exactement le mot que je suis en train de prononcer. Si je m'arrête, il s'arrête. Si j'improvise, il m'attend. Quand je reprends, il se recale.

Sous la fenêtre, une pilule de 4 boutons : **Éditer · Lecture/Pause · Recommencer · Fermer**.

Tout tourne en local : reconnaissance vocale sur l'appareil, scripts stockés dans un fichier JSON, réglages dans `UserDefaults`. Pas de base de données, pas de réseau (sauf le téléchargement unique du modèle de langue).

---

## 2. Contexte et problème

- Je tourne des vidéos YouTube et des reels face caméra avec des scripts de 2 000 à 3 500 mots, en français.
- Un téléprompteur à vitesse constante m'oblige à caler mon débit sur la machine. Ça s'entend et ça se voit.
- Les téléprompteurs qui suivent la voix existent, mais sont payants pour une fonction essentielle qui tient en 2 000 lignes de Swift.
- Je veux la même chose, en plus simple, et que je contrôle.

## 3. Objectifs et non-objectifs

### Objectifs

| # | Objectif | Mesure de succès |
|---|---|---|
| O1 | Le texte suit ma voix sans que j'y pense | Sur un script de 3 min lu normalement, la ligne lue reste dans la zone de lecture **≥ 97 % du temps**, avec **≤ 1 correction manuelle** |
| O2 | C'est réactif | Latence entre un mot prononcé et le début du défilement : **p50 < 400 ms, p95 < 800 ms** |
| O3 | C'est discret à l'écran | Fenêtre translucide et sans chrome, contrôles visibles seulement au survol |
| O4 | C'est trivial à utiliser | Du lancement de l'app au début de la lecture en **≤ 3 actions** (coller, lancer, parler) |
| O5 | Zéro dépendance externe | Fonctionne hors ligne, sans compte, sans serveur, sans télémétrie |

### Non-objectifs (on ne les fait pas, point)

- Synchro iCloud, comptes, licence, paywall, statistiques, script de démo, pages Aide et À propos.
- Version iOS ou iPad, télécommande depuis le téléphone.
- Éditeur riche (gras, couleurs par mot, import .docx ou .pdf).
- Enregistrement vidéo intégré.
- Distribution sur le Mac App Store ou notarisation publique.

---

## 4. Scénarios d'usage

1. **Tournage YouTube.** Je colle mon script, je place la fenêtre sous la caméra, j'appuie sur Lecture et je parle. Le texte suit. Je me trompe, je reprends la phrase : le texte ne recule pas (par défaut), il m'attend et repart.
2. **Improvisation.** Je sors du script pendant 20 secondes pour une anecdote. Le texte reste figé. Je reviens au script, il se recale en 2 ou 3 mots.
3. **Saut.** Je décide de sauter un paragraphe. Je lis la phrase suivante : le texte saute jusqu'à elle après 3 mots reconnus.
4. **Retake.** J'appuie sur Recommencer : retour au début, prêt à relancer.
5. **Correction à la volée.** J'appuie sur Éditer, je corrige une phrase, j'enregistre. La lecture reprend là où j'en étais.

## 5. Parcours principal

```
Lancer l'app (icône dans la barre des menus)
   └─► Fenêtre prompteur (dernier script ouvert, ou éditeur vide si aucun script)
         ├─ Éditer ─► Éditeur : coller / écrire ─► « Enregistrer » ─► retour au prompteur
         ├─ Lecture ─► permissions (1re fois) ─► modèle de langue (1re fois) ─► écoute
         │               └─ Je parle ─► le texte défile ─► Pause / Recommencer
         └─ Fermer ─► la fenêtre se masque, l'écoute s'arrête, l'app reste dans la barre des menus
```

---

## 6. Périmètre et priorités

Chaque fonction a une priorité. **P0 = MVP**, le seul périmètre obligatoire de la v1.

| Fonction | Zone | Priorité | Note |
|---|---|---|---|
| Fenêtre flottante, translucide, redimensionnable, toujours au premier plan | fenêtre | **P0** | |
| Pilule Éditer / Lecture-Pause / Recommencer / Fermer | fenêtre | **P0** | |
| Suivi vocal mot à mot (mode **Voice**) | Scrolling | **P0** | Le cœur du produit |
| Mode **Constant** (vitesse fixe) | Scrolling | **P0** | Solution de repli, 30 lignes de code |
| Éditeur de script et coller depuis le presse-papier | Scripts | **P0** | |
| Bibliothèque multi-scripts (liste, nouveau, supprimer) | Scripts | **P0** | Version minimale |
| Police, taille, interligne, alignement | General | **P0** | |
| Langue de reconnaissance (auto ou manuelle) | Scrolling | **P0** | |
| Choix de l'entrée audio | Scrolling | **P0** | Micro Shure MVX2U |
| Supprimer les lignes vides | Scripts | **P0** | |
| Icône et menu dans la barre des menus | Menu Bar | **P0** | Menu fixe, non configurable |
| Opacité du fond | (implicite) | **P0** | Lisibilité sur fond clair |
| Mode **Sound** (défile tant qu'il y a du son) | Scrolling | P1 | |
| Retour en arrière à la voix (option stricte) | Scrolling | P1 | |
| Vumètre du micro | Menu Bar | P1 | |
| Mode miroir (horizontal) pour vitre de téléprompteur | — | P1 | Ajout |
| Raccourci global Lecture/Pause (app en arrière-plan) | — | P1 | Ajout |
| Moteur Parakeet (alternative au moteur Apple) | — | P1 | Voir §9.2 |
| Recherche dans la bibliothèque | Scripts | P1 | |
| Masquer la fenêtre des captures d'écran | — | P1 | Au mieux, voir risques |
| Préréglages (presets) | Presets | P2 | |
| Commandes vocales (« go next », etc.) | Scrolling | P2 | |
| Menu de la barre des menus configurable | Menu Bar | P2 | |
| Direction du texte de droite à gauche | General | P2 | |
| Didascalies `[entre crochets]` affichées en grisé et ignorées par le suivi | — | P2 | Ajout |
| iCloud, licence, statistiques, aide, démo | divers | ✗ | Non-objectifs |

---

## 7. Spécifications fonctionnelles

### 7.1 Fenêtre prompteur

```
                ┌───────────────────────────────────────────┐
                │  Bien plus qu'Astra ou Fable.             │ ← lignes passées (grisées)
   zone de ──►  │  Le problème d'Astra ou Fable, c'était    │ ← ligne en cours (opacité 100 %)
   lecture      │  le coût. On avait l'impression d'un      │
   (20 % haut)  │  mirage qui ne se dissipait jamais…       │
                │                                           │ ← fondu en bas
                └──────────┬─────────────────────┬──────────┘
                           │  ✎    ❚❚    ↺    ✕  │  ← pilule (au survol)
                           └─────────────────────┘
```

| Exigence | Détail |
|---|---|
| F-W1 | Type `NSPanel`, niveau `.floating`, `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]` : visible sur tous les bureaux et au-dessus des apps en plein écran. |
| F-W2 | **Non activante** (`.nonactivatingPanel`) : cliquer sur la fenêtre ou la pilule ne vole pas le focus de l'app d'enregistrement (OBS, Screen Studio, QuickTime). Les boutons acceptent le premier clic (`acceptsFirstMouse`). |
| F-W3 | Pas de chrome visible : `.titled` + `.fullSizeContentView`, barre de titre transparente, titre et feux tricolores masqués. `.resizable` pour redimensionner par les bords. |
| F-W4 | Fond « verre dépoli » : `NSGlassEffectView` (macOS 26), avec en dessous un calque noir dont l'opacité est réglable (défaut 35 %). Coins arrondis de 16 pt, ombre portée. |
| F-W5 | Déplaçable en cliquant-glissant n'importe où sur le fond (`isMovableByWindowBackground`). |
| F-W6 | Taille minimale 280 × 120 pt. Au premier lancement : 560 × 320 pt, centrée horizontalement en haut de l'écran principal, juste sous la barre des menus ou l'encoche (donc au plus près de la webcam). |
| F-W7 | La position et la taille sont mémorisées et restaurées (`setFrameAutosaveName`). |
| F-W8 | Défilement manuel à la molette ou au trackpad autorisé à tout moment (voir F-S6). |
| F-W9 | Dégradé de fondu de 24 pt en haut et en bas du texte (masque). |

### 7.2 Pilule de contrôle

| Bouton | Symbole SF | Action | Raccourci (fenêtre active) |
|---|---|---|---|
| Éditer | `pencil` | Met en pause et ouvre l'éditeur sur le script courant | ⌘E |
| Lecture / Pause | `play.fill` / `pause.fill` (rouge pendant l'écoute) | Démarre ou met en pause l'écoute et le défilement | Espace |
| Recommencer | `arrow.counterclockwise` | Curseur au mot 0, défilement animé vers le haut, **conserve** l'état lecture ou pause | ⌘R |
| Fermer | `xmark` | Arrête l'écoute, masque la fenêtre et mémorise la position dans le script | Échap |

| Exigence | Détail |
|---|---|
| F-T1 | La pilule est un panneau enfant (`addChildWindow`) centré sous la fenêtre, qui déborde de 30 % sur son bord inférieur. Elle suit les déplacements et les redimensionnements. |
| F-T2 | Visible quand la souris survole la fenêtre ou la pilule, et **toujours** visible en pause. En lecture, elle disparaît en fondu 1,5 s après la sortie de la souris. |
| F-T3 | Fond en verre (`NSGlassEffectView`, forme capsule), icônes blanches à 90 %, boutons de 36 pt. |
| F-T4 | Pendant la préparation (permissions ou téléchargement du modèle), le bouton Lecture affiche un indicateur de progression. |

### 7.3 Rendu du texte

| Exigence | Détail |
|---|---|
| F-R1 | Le texte est rendu par un `NSTextView` non éditable, non sélectionnable, dans un `NSScrollView` sans barres de défilement. TextKit 2 et `NSTextLayoutManager` servent à calculer le rectangle de n'importe quel mot. |
| F-R2 | Police : Système (SF Pro), **Arrondie (SF Rounded, défaut)**, Serif (New York), Mono (SF Mono). Graisse Semibold. |
| F-R3 | Taille de 16 à 120 pt, défaut 32. Raccourcis ⌘+, ⌘− et ⌘0 (réinitialiser). |
| F-R4 | Interligne de 80 à 200 %, défaut 100 % (via `lineHeightMultiple`). |
| F-R5 | Alignement à gauche (défaut), centré ou à droite. |
| F-R6 | Couleur blanche. Les mots **déjà prononcés** passent à 40 % d'opacité (désactivable). |
| F-R7 | **Zone de lecture** : la ligne qui contient le mot courant est placée à 20 % de la hauteur visible depuis le haut (réglable de 0 à 50 %). |
| F-R8 | Un changement de taille, de police ou de largeur de fenêtre relance la mise en page et recale immédiatement (sans animation) la ligne courante dans la zone de lecture. |
| F-R9 | Mode miroir (P1) : retournement horizontal du calque de texte uniquement, pas de la pilule. |

### 7.4 Modes de défilement

Les trois modes partagent un même `ScrollDriver` qui produit une **position cible** (en points). Le rendu interpole ensuite vers cette cible (§7.5.6).

| Mode | Principe | Réglages |
|---|---|---|
| **Voice** (défaut, P0) | La cible est la ligne du mot courant, déterminé par le suivi vocal (§7.5). | Langue, entrée audio, retour arrière (P1) |
| **Constant** (P0) | La cible avance à vitesse fixe tant que la lecture est active. | Vitesse de 10 à 200 pt/s, défaut 40. ← et → pour ±10 pt/s en direct. |
| **Sound** (P1) | La cible avance à vitesse fixe **tant que le niveau micro dépasse un seuil**, avec une attaque de 80 ms et un maintien de 400 ms. | Vitesse, sensibilité de −70 à −20 dBFS (défaut −45) |

### 7.5 Suivi vocal (le cœur)

C'est la seule partie difficile. Elle doit être **isolée, déterministe et testée unitairement** (un module `Tracking` en Swift pur, sans dépendance à AppKit ni à Speech).

#### 7.5.1 Vue d'ensemble

```
Micro ─► AVAudioEngine (tap) ─► SpeechEngine (streaming) ─► texte entendu (volatil + finalisé)
                                                              │
Script ─► Tokenizer ─► [ScriptToken] ─────────────────────► ScriptMatcher ─► curseur (index du mot)
                                                              │
                                                  ScrollDriver ─► position cible ─► animation ─► rendu
```

#### 7.5.2 Tokenisation (script et transcription, **même fonction**)

Chaque `ScriptToken` contient `display` (le mot d'origine), `key` (clé normalisée), `range` (plage de caractères dans le texte d'origine, pour le rendu) et `weight`.

Normalisation de `key`, dans cet ordre :

1. Minuscules, puis suppression des diacritiques (`é → e`, `ç → c`), via `folding(options: [.caseInsensitive, .diacriticInsensitive])`.
2. Unification des apostrophes (`’ ʼ ` → `'`), puis découpage sur l'apostrophe : `l'impression` donne `l` + `impression`, `aujourd'hui` reste une exception connue.
3. Suppression de la ponctuation. Les tirets deviennent des espaces (`peut-être` donne `peut` + `etre`).
4. Petite table de symboles : `€ → euros`, `$ → dollars`, `% → pourcent`, `& → et`.
5. Les nombres restent des chiffres. On ne convertit pas les chiffres en lettres en v1 : un décalage entre « 90 » et « quatre-vingt-dix » est simplement absorbé par l'alignement (§7.5.3).
6. **Racine approximative** `stem` : on retire un suffixe final parmi `ent, es, s, x, e, t`, sans descendre sous 3 lettres. Utilisée pour les correspondances proches.

Poids `weight` :
- **faible (0,3)** : mot de 2 lettres ou moins, ou présent dans une liste de mots vides (fr : le, la, les, de, des, du, un, une, et, a, en, que, qui, ne, pas, je, tu, il, on, ce, se, sa, son, au, aux, l, d, j, n, s, c, qu, m, t ; en : the, a, an, of, to, and, is, it, in, that).
- **fort (1,0)** : tous les autres.

La tokenisation du script est recalculée à chaque modification du texte (coût négligeable, moins de 5 ms pour 5 000 mots).

#### 7.5.3 Algorithme de correspondance

État : `cursor: Int` = index du dernier mot du script reconnu comme prononcé (−1 au départ).

À **chaque** mise à jour du moteur (résultat volatil ou final) :

1. **Queue entendue** `H` = les K = 8 derniers tokens de (tokens finalisés + tokens volatils courants). Les tokens volatils remplacent les précédents du même segment, ils ne s'y ajoutent pas.
2. **Fenêtre de recherche** : positions de fin candidates `e ∈ [cursor − 2, cursor + 40]`, bornées au script.
3. Pour chaque `e`, on calcule un **alignement local** (programmation dynamique de type Smith-Waterman) entre `H` et `script[e − 11 … e]`, **ancré** : l'alignement doit se terminer sur `script[e]` et couvrir la fin de `H`. Jusqu'à 2 tokens entendus en fin de queue peuvent rester non appariés (mot mal reconnu en cours), avec une pénalité.
   - similarité `sim(h, s)` : `1,0` si `key` identique ; `0,8` si `stem` identique ou si la similarité de Levenshtein normalisée est ≥ 0,75 (mots de 4 lettres ou plus) ; sinon non-correspondance.
   - score d'une correspondance = `sim × weight(s)` ; non-correspondance = −0,5 ; trou (mot sauté d'un côté ou de l'autre) = −0,4 ; token final non apparié = −0,3.
   - **pénalité de distance** : `score −= 0,03 × max(0, e − cursor − 1)`, pour préférer l'occurrence la plus proche en cas de phrases répétées.
4. On retient le meilleur `e` et on l'**accepte** selon la zone :

| Zone | Condition d'acceptation |
|---|---|
| Proche : `cursor < e ≤ cursor + 6` | score ≥ 1,0 **et** au moins 1 mot fort apparié |
| Moyenne : `cursor + 6 < e ≤ cursor + 40` | score ≥ 2,2 **et** au moins 2 mots forts appariés |
| Recul : `e < cursor` | **ignoré**, sauf si le retour arrière est activé (P1) : au moins 4 mots forts consécutifs appariés à l'identique |

5. Si accepté : `cursor = e`. Le curseur n'avance jamais à cause d'une révision de résultat volatil vers le bas : en mode avant seul, `cursor = max(cursor, e)`.
6. **Recalage global** : si des mots sont entendus (au moins 12 tokens) sans aucune acceptation pendant 6 s, on cherche dans **tout** le script en avant du curseur (et en arrière si le retour arrière est activé). On saute si au moins 5 mots forts sont appariés et que le score est ≥ 4,5.

Tous les seuils vivent dans une struct `MatcherConfig` et ne sont pas codés en dur ailleurs.

#### 7.5.4 Comportements attendus (ce sont aussi les cas de test)

| Situation | Comportement attendu |
|---|---|
| Lecture normale | Le curseur suit le dernier mot dit, avec un retard de 0 à 2 mots |
| Silence | Rien ne bouge |
| Improvisation hors script | Rien ne bouge. Pas de saut parasite sur des mots vides isolés (« et », « de ») |
| Reprise après improvisation | Recalage en 1 à 3 mots forts |
| Je répète une phrase déjà lue | Rien ne bouge (retour arrière désactivé) |
| Saut d'un paragraphe (moins de 40 mots) | Saut après 2 ou 3 mots forts |
| Saut plus loin | Recalage global en ≤ 6 s + 5 mots |
| Erreur du moteur (« Astra » entendu « astrat ») | Tolérée par `stem` et Levenshtein, ou absorbée par les voisins |
| Phrase répétée plus loin dans le script | L'occurrence la plus proche l'emporte |
| Nombre écrit en lettres dans le script, en chiffres à l'oral | Mot sauté, les voisins portent l'alignement |

#### 7.5.5 Biais de vocabulaire

À chaque chargement du script, on extrait jusqu'à 100 mots rares (mots forts de 5 lettres ou plus absents d'une liste de fréquence, noms propres, mots avec majuscule en milieu de phrase), puis on les fournit au moteur comme **chaînes contextuelles**. Apple : `AnalysisContext.contextualStrings`, signature exacte à vérifier. Résultat : « Astra » et « Fable » sont mieux reconnus.

#### 7.5.6 Du curseur au défilement

- `targetY = y(ligne du mot cursor) − readingLine × hauteurVisible`, bornée à `[0, hauteurContenu − hauteurVisible]`.
- L'animation suit un **ressort à amortissement critique** (ω ≈ 7 rad/s) à chaque image, via `NSView.displayLink` (60 ou 120 Hz). Jamais de saut sec, sauf pour Recommencer depuis la pause ou pour un changement de mise en page.
- Le curseur change par mots, mais la position change par lignes, ce qui évite les micro-secousses. Option P1 : avancée fractionnée à l'intérieur de la ligne selon la position du mot, pour un rendu plus fluide avec les grandes polices.
- **Défilement manuel** (F-S6) : un geste molette ou trackpad suspend le pilotage automatique pendant le geste. À la fin, en mode Voice, le curseur est **réancré** sur le premier mot de la ligne qui se trouve dans la zone de lecture. En mode Constant ou Sound, la position reprend depuis là.

#### 7.5.7 Superposition de débogage

Le raccourci ⌥⌘D affiche en bas de la fenêtre, en petit : la queue entendue `H`, le texte volatil, `cursor`, le meilleur `e`, le score, la zone, la latence du dernier résultat et le niveau du micro en dBFS. **Indispensable pour régler les seuils.** Livré en P0.

### 7.6 Éditeur et bibliothèque

| Exigence | Détail |
|---|---|
| F-E1 | Fenêtre standard (activante) : barre latérale avec la liste des scripts (titre, date de modification, nombre de mots), éditeur de texte brut à droite. |
| F-E2 | Titre = première ligne non vide, tronquée à 80 caractères (pas de champ titre séparé). |
| F-E3 | Actions : **Nouveau** (⌘N), **Nouveau depuis le presse-papier** (⇧⌘V), **Supprimer** (avec confirmation), **Ouvrir dans le prompteur** (⌘↩). |
| F-E4 | Sauvegarde automatique 800 ms après la dernière frappe, et à la fermeture. Aucun bouton Enregistrer. |
| F-E5 | Option « Supprimer les lignes vides » (défaut : désactivée, les sauts de ligne du script sont conservés) appliquée **à l'ouverture dans le prompteur**. Le texte stocké n'est pas modifié. |
| F-E6 | Retour au prompteur après une édition : le curseur est conservé grâce au décalage en caractères du mot courant, remappé sur le nouveau texte (mot le plus proche). |
| F-E7 | Glisser-déposer d'un fichier `.txt` ou `.md` dans la liste : crée un script. |
| F-E8 | Police de l'éditeur : SF Mono 14 pt, compteur de mots et durée estimée (à 150 mots par minute) en bas. |

### 7.7 Réglages

Une fenêtre `Settings` SwiftUI avec 3 onglets : **Général**, **Défilement**, **Scripts**. Toutes les valeurs sont stockées avec `@AppStorage` et s'appliquent **en direct** au prompteur.

| Clé | Onglet | Type | Défaut | Plage ou valeurs |
|---|---|---|---|---|
| `fontFamily` | Général | enum | `rounded` | system, rounded, serif, mono |
| `fontSize` | Général | Double | 32 | 16–120 |
| `lineSpacing` | Général | Double | 1,0 | 0,8–2,0 |
| `alignment` | Général | enum | `left` | left, center, right |
| `backgroundOpacity` | Général | Double | 0,35 | 0–0,95 |
| `dimSpokenText` | Général | Bool | true | |
| `readingLine` | Général | Double | 0,20 | 0–0,5 |
| `mirror` (P1) | Général | Bool | false | |
| `scrollMode` | Défilement | enum | `voice` | voice, constant, sound |
| `constantSpeed` | Défilement | Double | 40 | 10–200 pt/s |
| `soundThresholdDb` (P1) | Défilement | Double | −45 | −70 à −20 |
| `recognitionLocale` | Défilement | String? | nil (= auto) | locales prises en charge par le moteur |
| `audioInputUID` | Défilement | String? | nil (= défaut système) | UID CoreAudio |
| `allowBackward` (P1) | Défilement | Bool | false | |
| `speechEngine` (P1) | Défilement | enum | `apple` | apple, parakeet |
| `removeEmptyLines` | Scripts | Bool | false | |
| `lastScriptID` | (interne) | UUID? | nil | |

**Langue automatique** : `NLLanguageRecognizer` sur le script, puis choix de la locale prise en charge la plus proche de la région système. Exemple : français détecté, région BE, `fr-BE` non pris en charge, donc `fr-FR`. L'interface affiche « Automatique (français (France)) ».

**Entrée audio** : liste des périphériques d'entrée CoreAudio (`kAudioHardwarePropertyDevices` filtrés sur les flux d'entrée), mise à jour à chaud lors d'un branchement ou d'un débranchement. Note sous le sélecteur : « Les AirPods peuvent ajouter de la latence. »

### 7.8 Barre des menus

Icône `text.viewfinder`, ou `waveform` pendant l'écoute. Menu (`MenuBarExtra`, style menu) :

```
Afficher le prompteur          ⌘1
Lecture / Pause                Espace
Recommencer
─────────────
Mode ▸  ✓ Voix · Constant · Son
Taille du texte ▸  − / + / Réinitialiser
Entrée audio ▸  (liste)
─────────────
Scripts…                       ⌘E
Réglages…                      ⌘,
Quitter Souffleur              ⌘Q
```

L'app tourne en `LSUIElement = YES` : pas d'icône dans le Dock, pour ne jamais s'intercaler dans ⌘Tab pendant un tournage.

### 7.9 Raccourcis

| Raccourci | Portée | Action |
|---|---|---|
| Espace | prompteur au premier plan | Lecture / Pause |
| ⌘R | prompteur | Recommencer |
| ⌘E | prompteur | Éditer |
| Échap | prompteur | Fermer |
| ⌘+ / ⌘− / ⌘0 | prompteur | Taille du texte |
| ↑ / ↓ | prompteur | Ligne précédente ou suivante (réancre le curseur) |
| ← / → | prompteur, mode Constant | Vitesse ±10 |
| ⌥⌘D | prompteur | Superposition de débogage |
| ⌃⌥Espace (P1, **global**) | système | Lecture / Pause même si l'app n'est pas au premier plan |

### 7.10 Permissions et premier lancement

1. Premier appui sur Lecture : demande d'accès au micro (`AVCaptureDevice.requestAccess(for: .audio)`), puis à la reconnaissance vocale (`SFSpeechRecognizer.requestAuthorization`, par précaution même si SpeechAnalyzer ne l'exige pas, à vérifier).
2. Vérification du modèle de langue : s'il n'est pas installé, téléchargement avec `AssetInventory.assetInstallationRequest(supporting:)`. La pilule affiche la progression, et un texte « Téléchargement du modèle français… » s'affiche dans la fenêtre.
3. L'écoute démarre.

`Info.plist` : `NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`, `LSUIElement`.

### 7.11 États d'erreur

| Cas | Comportement |
|---|---|
| Micro refusé | Message dans la fenêtre avec un bouton « Ouvrir les Réglages Système » (`x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone`). Le mode Constant reste utilisable. |
| Langue non prise en charge | Repli sur `en-US` et bandeau d'avertissement. Le sélecteur de langue est mis en évidence. |
| Téléchargement du modèle impossible (hors ligne) | Message avec un bouton Réessayer. Suggestion : passer en mode Constant. |
| Périphérique audio débranché pendant l'écoute | Bascule automatique sur l'entrée par défaut, notification discrète dans la fenêtre, **l'écoute continue**. |
| Moteur interrompu (erreur interne) | Redémarrage automatique du moteur en ≤ 1 s, sans réinitialiser le curseur. 3 échecs consécutifs : pause et message. |
| Script vide | La fenêtre affiche « Aucun script. Appuie sur ✎ pour en coller un. » Lecture est désactivé. |

---

## 8. Exigences non fonctionnelles

| # | Exigence |
|---|---|
| NF1 | **Latence** (du mot prononcé au début du mouvement) : p50 < 400 ms, p95 < 800 ms, mesurée avec la superposition de débogage. |
| NF2 | **Fluidité** : défilement à la fréquence de l'écran (60 ou 120 Hz), aucune image perdue visible sur un script de 5 000 mots. |
| NF3 | **CPU** < 15 % d'un cœur de performance M1 en écoute (moteur Apple). **RAM** < 250 Mo (moteur Apple), < 1,2 Go (Parakeet). |
| NF4 | **Hors ligne** : aucune requête réseau hormis le téléchargement unique du modèle. Pas de télémétrie, pas de SDK tiers d'analytique. |
| NF5 | **Robustesse** : écriture atomique des fichiers (`Data.write(options: .atomic)`) ; un JSON corrompu est renommé `library.corrupt-<date>.json` et l'app repart sur une bibliothèque vide, sans planter. |
| NF6 | **Démarrage** : l'app est prête (fenêtre affichée) en < 1 s ; l'écoute démarre en < 1,5 s après Lecture (modèle déjà installé). |
| NF7 | **Sessions longues** : 30 min d'écoute continue sans dérive mémoire, sans coupure du moteur et sans perte de suivi. |
| NF8 | **Accessibilité minimale** : boutons de la pilule avec libellés VoiceOver, et contraste suffisant grâce à l'opacité du fond. |

---

## 9. Architecture technique

### 9.1 Décision : Swift natif, pas Tauri

| Critère | Swift (AppKit + SwiftUI) | Tauri |
|---|---|---|
| Panneau flottant non activant, tous les bureaux | natif (`NSPanel`) | plugin ou code Objective-C via Rust |
| Verre dépoli (Liquid Glass) | natif (`NSGlassEffectView`) | API privée `macOSPrivateApi`, rendu approximatif |
| Reconnaissance vocale sur l'appareil | `SpeechAnalyzer` natif, en streaming | pont Rust vers Swift obligatoire |
| Sélection du périphérique audio | CoreAudio direct | pont Rust (cpal) |
| Poids de l'app | ~5 Mo | ~15 Mo + webview |
| Code à écrire | 1 langage | 3 (TS, Rust, Swift pour la parole) |

**Décision : Swift 6, AppKit pour les fenêtres, SwiftUI pour l'éditeur et les réglages.** Tauri n'apporte rien ici : tout ce qui compte (fenêtre, parole, audio) est natif macOS, et il faudrait de toute façon l'écrire en Swift.

### 9.2 Décision : moteur de reconnaissance (Apple d'abord, Parakeet en option)

Le moteur est caché derrière un protocole, ce qui rend le choix réversible :

```swift
protocol SpeechEngine: AnyObject {
    var updates: AsyncStream<TranscriptUpdate> { get }   // volatile | final, tokens, horodatage
    func prepare(locale: Locale, contextualWords: [String]) async throws  // permissions + modèle
    func start(audio: AsyncStream<AVAudioPCMBuffer>) async throws
    func stop() async
}
```

| | **Apple SpeechAnalyzer / SpeechTranscriber** (macOS 26) | **Parakeet TDT 0.6B v3** via FluidAudio (CoreML, ANE) |
|---|---|---|
| Streaming | natif, résultats volatils en continu | par fenêtres glissantes (≈ 1–1,5 s) |
| Français | oui | oui (v3 multilingue, 25 langues européennes) |
| Précision brute | bonne | excellente |
| Biais de vocabulaire | oui (chaînes contextuelles) | non |
| Installation | modèle système téléchargé par l'OS, partagé | ~600 Mo à télécharger et gérer soi-même |
| Dépendances | aucune | paquet SPM FluidAudio |

**Décision v1 : Apple par défaut.** Pour un téléprompteur, la **latence** et le **streaming** priment sur la précision brute. L'algorithme compare à un texte connu à l'avance et tolère les erreurs du moteur, et le biais de vocabulaire rattrape les noms propres.
**Parakeet = P1**, sous forme d'un second moteur sélectionnable dans les réglages.

**Spike obligatoire au jalon M2** : lire le même script de 3 min avec les deux moteurs, en enregistrant la latence p50/p95 et le taux de temps dans la zone de lecture (O1). Si Parakeet est meilleur sur O1 **et** reste dans NF1, il devient le moteur par défaut. Les API FluidAudio exactes (gestionnaire de streaming, version du modèle) sont à vérifier au moment du spike.

### 9.3 Pile et structure du projet

- **Swift 6**, cible macOS 26.0, Apple Silicon uniquement.
- **XcodeGen** (`project.yml`) : le projet se génère et se compile entièrement en ligne de commande (`xcodegen && xcodebuild`), idéal pour itérer avec Claude Code.
- **Dépendances** : aucune en P0. En P1 : `FluidAudio` (Parakeet) et `KeyboardShortcuts` (sindresorhus, raccourci global).
- Signature : certificat « Apple Development » stable (Apple ID gratuit), **pas** de signature ad hoc (voir risque R3). Pas de sandbox, runtime renforcé désactivé (usage perso).

```
Souffleur/
├── project.yml
├── Souffleur/
│   ├── App/
│   │   ├── SouffleurApp.swift          # @main, MenuBarExtra, Settings, fenêtre Éditeur
│   │   └── AppState.swift              # @Observable : script courant, état lecture, mode
│   ├── Prompter/
│   │   ├── PrompterPanel.swift         # NSPanel (F-W*)
│   │   ├── PrompterViewController.swift
│   │   ├── PrompterTextView.swift      # rendu, estompage, rect d'un mot (F-R*)
│   │   ├── ControlPillPanel.swift      # panneau enfant et 4 boutons (F-T*)
│   │   ├── ScrollAnimator.swift        # ressort + displayLink
│   │   └── DebugOverlay.swift
│   ├── Audio/
│   │   ├── AudioCapture.swift          # AVAudioEngine, tap, conversion de format, niveau dBFS
│   │   └── AudioDevices.swift          # liste et sélection CoreAudio, écoute des changements
│   ├── Speech/
│   │   ├── SpeechEngine.swift          # protocole et TranscriptUpdate
│   │   ├── AppleSpeechEngine.swift     # SpeechAnalyzer + SpeechTranscriber + AssetInventory
│   │   └── ParakeetSpeechEngine.swift  # P1
│   ├── Tracking/                       # ⚠️ Swift pur, sans import AppKit ni Speech
│   │   ├── Tokenizer.swift
│   │   ├── ScriptMatcher.swift         # §7.5.3
│   │   ├── MatcherConfig.swift
│   │   └── ScrollDriver.swift          # voice / constant / sound → position cible
│   ├── Library/
│   │   ├── Script.swift
│   │   └── ScriptStore.swift           # JSON local, écritures atomiques
│   ├── Editor/
│   │   └── LibraryView.swift           # NavigationSplitView liste + TextEditor
│   ├── Settings/
│   │   ├── SettingsKeys.swift
│   │   └── SettingsView.swift          # onglets Général, Défilement, Scripts
│   └── Resources/ (Info.plist, Assets, stopwords-fr.txt, stopwords-en.txt, freq-fr.txt)
└── SouffleurTests/
    ├── TokenizerTests.swift
    ├── ScriptMatcherTests.swift        # cas du §7.5.4
    └── Fixtures/*.json                 # séquences de transcriptions enregistrées → curseur attendu
```

### 9.4 Modèle de données et stockage

Tout est dans `~/Library/Application Support/Souffleur/`.

```jsonc
// library.json : un seul fichier, réécrit de façon atomique à chaque sauvegarde
{
  "version": 1,
  "scripts": [
    {
      "id": "8F1C…",
      "body": "ChatGPT devient impossible à quitter…",
      "createdAt": "2026-09-30T12:00:00Z",
      "updatedAt": "2026-09-30T12:42:00Z",
      "lastCharOffset": 10423          // position de reprise (décalage caractère du mot courant)
    }
  ]
}
```

- Réglages : `UserDefaults` (`@AppStorage`).
- Cadre de la fenêtre : `NSWindow` frame autosave.
- Pas de Core Data, SwiftData ou SQLite. Pour une centaine de scripts de 20 Ko chacun, un JSON de 2 Mo se lit et s'écrit en quelques millisecondes.

### 9.5 Pipeline audio

- `AVAudioEngine.inputNode` avec le périphérique choisi, forcé via `AudioUnitSetProperty(kAudioOutputUnitProperty_CurrentDevice)` sur `inputNode.audioUnit` **avant** `engine.start()`.
- Tap avec un tampon de 1 024 trames, conversion (`AVAudioConverter`) vers le format demandé par le moteur (`SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith:)`).
- À chaque tampon : calcul du RMS, puis des dBFS, publié pour le mode Sound et le vumètre.
- Les tampons sont poussés dans une `AsyncStream<AnalyzerInput>` consommée par le moteur.
- Tout le travail audio et parole se fait hors du thread principal. Seuls `cursor` et `targetY` sont publiés sur `@MainActor`.

### 9.6 Machine à états de la lecture

```
            ┌───────────── Recommencer (curseur = −1, état conservé) ─────────────┐
            ▼                                                                       │
 [Inactif] ──Lecture──► [Préparation] ──ok──► [Écoute] ◄──Lecture──► [Pause] ─────┘
    ▲                        │                    │  │
    │                        └─erreur─► [Erreur] ◄┘  └─ moteur interrompu → redémarrage auto (≤ 3)
    └──────────── Fermer (depuis n'importe quel état : arrêt de l'audio et du moteur) ──────
```

- En **Pause**, le moteur et le micro sont **arrêtés**, pas juste ignorés : on libère le micro (le voyant orange disparaît).
- Mode Constant : Préparation = instantané, pas de micro.

---

## 10. Plan de tests et recette

### 10.1 Tests automatisés (obligatoires, `xcodebuild test`)

| Suite | Contenu |
|---|---|
| `TokenizerTests` | élisions (`l'`, `qu'`, `aujourd'hui`), diacritiques, apostrophes typographiques, tirets, symboles `€ %`, stems, poids |
| `ScriptMatcherTests` | **un test par ligne du tableau §7.5.4**, construit à partir de séquences de `TranscriptUpdate` synthétiques (volatils qui se révisent, puis finaux) |
| `FixtureReplayTests` | rejoue des sessions réelles enregistrées (JSON : horodatage + texte volatil ou final) et vérifie que le curseur ne s'écarte jamais de plus de 3 mots de la vérité terrain annotée |
| `ScriptStoreTests` | aller-retour JSON, écriture atomique, récupération d'un fichier corrompu |
| `ScrollDriverTests` | Constant (distance = vitesse × temps), Sound (attaque et maintien), bornes |

Pour enregistrer une fixture, le raccourci ⌥⌘S (build de débogage uniquement) sauvegarde dans `~/Desktop` le flux de `TranscriptUpdate` de la session en cours.

### 10.2 Recette manuelle (avant de déclarer la v1 terminée)

| # | Scénario | Critère |
|---|---|---|
| R1 | Lire à voix normale un script français de 3 min (le script ChatGPT, par exemple) | ≥ 97 % du temps dans la zone de lecture, ≤ 1 correction manuelle |
| R2 | Improviser 20 s, puis reprendre | aucun mouvement pendant l'improvisation, recalage en ≤ 3 mots |
| R3 | Sauter un paragraphe | recalage en ≤ 3 mots forts |
| R4 | Répéter une phrase déjà lue | aucun recul |
| R5 | Cliquer sur la pilule pendant qu'OBS ou Screen Studio est au premier plan | le focus reste sur OBS |
| R6 | Passer une app en plein écran | le prompteur reste visible par-dessus |
| R7 | Débrancher le Shure MVX2U pendant l'écoute | bascule sur le micro interne, l'écoute continue |
| R8 | Éditer une phrase en pleine lecture | reprise au bon endroit |
| R9 | 30 min d'écoute continue | pas de dérive, pas de coupure, RAM stable |
| R10 | Mode Constant, sans permission micro | fonctionne |

---

## 11. Plan de livraison

Chaque jalon se termine par une app **qui compile et se lance**, avec des tests au vert.

| Jalon | Contenu | Définition de terminé |
|---|---|---|
| **M0 Squelette** | XcodeGen, app `LSUIElement`, `MenuBarExtra`, Info.plist, signature | `xcodegen && xcodebuild` passe, l'icône apparaît dans la barre des menus |
| **M1 Fenêtre** | `PrompterPanel` (F-W*), pilule (F-T*), rendu (F-R*), mode Constant, raccourcis | Un texte codé en dur défile en Constant, la fenêtre flotte au-dessus d'une app en plein écran, R5 et R6 OK |
| **M2 Audio et parole** | `AudioCapture`, `AudioDevices`, `AppleSpeechEngine`, permissions, téléchargement du modèle, superposition de débogage (texte brut entendu) | La transcription française s'affiche en direct dans la superposition, avec sélection du Shure ; **spike Apple contre Parakeet documenté** (§9.2) |
| **M3 Suivi** | `Tokenizer`, `ScriptMatcher`, `ScrollDriver` voice, animation ressort, réancrage manuel | Tous les tests du §7.5.4 au vert ; R1 à R4 OK |
| **M4 Scripts et réglages** | `ScriptStore`, éditeur et bibliothèque, réglages en direct, reprise de position | R8 OK, les réglages persistent après redémarrage |
| **M5 Finitions v1** | États d'erreur (§7.11), R7, R9, polissage visuel | Recette §10.2 complète |
| **M6 P1** | Mode Sound, retour arrière, vumètre, miroir, raccourci global, Parakeet, recherche | Au cas par cas |

Installation perso : `xcodebuild -scheme Souffleur -configuration Release`, puis copie de `Souffleur.app` dans `/Applications`. Un script `make install` le fait.

---

## 12. Risques et mitigations

| # | Risque | Impact | Mitigation |
|---|---|---|---|
| R1 | Faux sauts sur des mots fréquents (« de », « et ») | Élevé | Poids faibles, au moins 1 à 2 mots forts exigés, pénalité de distance, tests dédiés |
| R2 | Latence du moteur Apple trop élevée en français | Élevé | Spike M2 ; moteur Parakeet derrière le même protocole ; mesure dans la superposition de débogage |
| R3 | Permission micro perdue à chaque recompilation (signature ad hoc, donc empreinte différente pour TCC) | Moyen, mais très agaçant | Signer avec un certificat Apple Development stable et un identifiant de bundle fixe `co.theyo.souffleur` |
| R4 | `sharingType = .none` n'empêche plus la capture par ScreenCaptureKit depuis macOS 15 | Faible | Fonction P1 « au mieux », documentée comme non garantie |
| R5 | Coupure ou redémarrage du moteur pendant une longue session | Moyen | Redémarrage automatique sans réinitialiser le curseur, test R9 |
| R6 | Le français en `fr-BE` n'est pas pris en charge | Faible | Repli sur la locale prise en charge la plus proche (§7.7) |
| R7 | Les AirPods ajoutent de la latence et basculent en HFP 16 kHz | Faible | Avertissement dans l'interface ; usage prévu avec le Shure en USB |
| R8 | Les API citées (SpeechAnalyzer, AnalysisContext, FluidAudio) ont évolué | Moyen | Vérifier les signatures dans la doc de la version installée au début de M2 ; l'abstraction `SpeechEngine` limite l'impact |

## 13. Questions ouvertes

1. **Nom et icône** : « Souffleur » te va ?
2. **Dock** : l'app est uniquement dans la barre des menus (recommandé pour les tournages). Faut-il une option « Afficher dans le Dock » ?
3. **Vitre de téléprompteur physique** : si tu utilises un vrai téléprompteur à miroir, le mode miroir passe de P1 à P0.
4. **Moteur par défaut** : Apple (recommandé) ou Parakeet d'emblée ? Le spike M2 tranche de toute façon avec des chiffres.

---

## Annexe : glossaire

- **Curseur** : index du dernier mot du script considéré comme prononcé.
- **Zone de lecture** : hauteur (en % depuis le haut) où la ligne courante est maintenue.
- **Résultat volatil** : hypothèse provisoire du moteur, qui peut être révisée ; **final** : hypothèse figée.
- **Mot fort / faible** : mot porteur de sens (poids 1,0) contre mot vide ou très court (poids 0,3).
- **Recalage global** : recherche dans tout le script quand le suivi est perdu.
