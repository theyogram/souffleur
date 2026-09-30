# Notes d'intégration (écarts et consignes remontés par les workers)

## library (commit c2530b7, 8/8 tests)
- `ScriptStore` est isolé `@MainActor`.
- L'intégration doit appeler `store.flush()` à la fermeture de l'app (applicationWillTerminate) et appliquer `ScriptStore.removingEmptyLines` à l'ouverture d'un script dans le prompteur si le réglage est actif.

## tracking (commit c35357a, 23/23 tests)
- Aucun écart d'API. Swift pur (Foundation seulement).
- `ScriptMatcher` n'est pas thread-safe : l'appeler depuis un seul acteur (le main actor convient, ingest < 2 ms).
- `ScrollDriver.step` renvoie des points pour `dt` ; à brancher sur `PrompterWindowController.onFrame`.

## speech (commit 2f1ffef, 5/5 tests)
- API Apple utilisées (SDK macOS 27) : SpeechTranscriber(locale:transcriptionOptions:reportingOptions:[.volatileResults,.fastResults]:attributeOptions:), SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith:), setContext(_:), prepareToAnalyze(in:), start(inputSequence:), AssetInventory.status/assetInstallationRequest, AnalysisContext.contextualStrings[.general].
- `AppleSpeechEngine.updates` renvoie un NOUVEAU flux créé dans `start` : lire `engine.updates` APRÈS `try await engine.start(audio:)` (tampon des 100 derniers, rien n'est perdu).
- Propriété en plus du protocole : `AppleSpeechEngine.onError: ((SpeechEngineError) -> Void)?`, appelée HORS main thread → la brancher (redémarrage auto ≤ 3, §7.11) en repassant sur le main actor.
- `TranscriptUpdate.timestamp` = temps audio (début d'analyse + position) ; pour la latence de l'overlay debug, mesurer `Date()` à la réception.
- `AudioCapture.onLevel` / `onDeviceLost` sont appelés sur le main thread.
- ⚠️ À CORRIGER : avec l'entrée « défaut système » (UID vide), un changement du périphérique par défaut arrête AVAudioEngine sans relance. Observer `.AVAudioEngineConfigurationChange` dans AudioCapture et redémarrer le moteur sur le nouveau défaut (continuation conservée), puis appeler onDeviceLost.
- Validation manuelle requise : transcription micro réelle (`-speechSmokeTest`), débranchement, latence.

## prompter (commit 901e1f4, 5/5 tests)
- Aucun écart d'API. NSGlassEffectView, panneau non activant, CADisplayLink via view.displayLink.
- `PrompterDemo.show()` à brancher sur `-prompterDemo` ; capture visuelle de la démo non encore faite.
