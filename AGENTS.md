# Souffleur — règles pour les agents

- Spéc de référence : `PRD.md`. Les numéros (F-W1, §7.5.3…) y renvoient.
- Build : `make build DERIVED=build/<ton-nom>` ; tests : `make test DERIVED=build/<ton-nom>`. Toujours un `DERIVED` à toi (builds parallèles).
- Le projet est généré par XcodeGen depuis `project.yml` : tout fichier ajouté sous `Souffleur/` ou `SouffleurTests/` est inclus automatiquement après `make gen`. Ne pas éditer `Souffleur.xcodeproj` à la main ; il n'est pas versionné.
- `Souffleur/Shared/*` est FIGÉ (contrats). Ne pas le modifier.
- Ne modifier que les fichiers de ton périmètre. Pas de dépendance tierce.
- Swift 6 toolchain, mode de langage Swift 5, concurrence stricte minimale. macOS 26+, Apple Silicon.
- Code et commentaires : noms en anglais, commentaires en français, sobres.
- Commits locaux uniquement (pas de push), message clair, sur ta branche.
