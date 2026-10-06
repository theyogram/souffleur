# Souffleur

Téléprompteur macOS qui suit ta voix, mot à mot. Une petite fenêtre translucide, toujours au premier plan, que tu places sous ta webcam : le texte défile au rythme de ta lecture, s'arrête quand tu t'arrêtes et t'attend quand tu improvises.

- Reconnaissance vocale sur l'appareil (moteur Apple), rien ne quitte ton Mac.
- Modes Voix, Son (défile tant que tu parles) et Constant.
- Scripts stockés en local, sans compte ni serveur.

## Installation

Télécharge le DMG depuis la page [Releases](../../releases/latest), ouvre-le et glisse **Souffleur** dans **Applications**.

**Configuration requise** : macOS 26 ou plus récent, Mac Apple Silicon.

### Premier lancement

L'app n'est pas notarisée par Apple, donc macOS bloque le premier lancement. Deux façons de l'autoriser :

1. Lance Souffleur une fois, puis va dans **Réglages Système › Confidentialité et sécurité** et clique sur **Ouvrir quand même**.
2. Ou, dans le Terminal :

   ```bash
   xattr -dr com.apple.quarantine /Applications/Souffleur.app
   ```

Au premier appui sur Lecture, macOS demande l'accès au micro et à la reconnaissance vocale : accepte les deux.

## Utilisation

Souffleur vit dans la barre des menus. Colle ton script dans la bibliothèque (⌘E), place la fenêtre sous ta caméra, puis :

| Raccourci | Action |
|---|---|
| Espace | Lecture / Pause |
| ⌘R | Recommencer |
| ⌘E | Éditer le script |
| ⌘+ / ⌘− / ⌘0 | Taille du texte |
| ↑ / ↓ | Ligne précédente / suivante |
| ⌥⌘D | Afficher ce que l'app entend |

## Compiler depuis les sources

Prérequis : Xcode 27 et [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
make build      # compile
make test       # lance les tests
make install    # compile en Release et installe dans /Applications
make dmg        # produit build/dist/Souffleur-<version>.dmg
```

La spécification complète est dans [PRD.md](PRD.md).
