import AppKit

@MainActor
enum PrompterDemo {
    private static var retainedController: PrompterWindowController?

    static func show() -> PrompterWindowController {
        let paragraphs = [
            "Aujourd’hui, je prends quelques minutes pour expliquer une idée simple. Quand on parle face à une caméra, on veut regarder les gens, pas chercher la ligne suivante. Un bon prompteur se fait oublier. Il reste sous l’objectif, affiche les mots clairement et avance au rythme de la voix. Si je fais une pause pour réfléchir, le texte m’attend.",
            "Je peux aussi changer d’avis au milieu d’une phrase. Parfois une anecdote arrive sans prévenir, et c’est très bien comme ça. La machine ne doit pas me presser. Elle doit garder mon point de départ, puis retrouver la suite quand je reviens à mon histoire. C’est ce détail qui rend la lecture naturelle.",
            "Pour cette démonstration, le curseur avance régulièrement, un mot après l’autre. Les lignes déjà lues deviennent plus discrètes. La ligne courante reste près du haut de la fenêtre, juste sous la caméra. Je peux agrandir le texte, redimensionner la fenêtre ou déplacer le prompteur, et chaque ligne retrouve sa place sans hésiter.",
            "Les quatre boutons sont toujours à portée de main. Je peux éditer le texte, lancer ou interrompre la lecture, recommencer et fermer la fenêtre. Avec un vrai script et un microphone, le mouvement suivra les mots prononcés. Ici, le rythme automatique permet surtout de vérifier le rendu, les transitions et la lisibilité sur différents fonds."
        ]
        let script = (paragraphs + paragraphs.prefix(2)).joined(separator: "\n\n")
        let regex = try? NSRegularExpression(pattern: #"[\p{L}\p{N}]+"#)
        let matches = regex?.matches(in: script, range: NSRange(location: 0, length: (script as NSString).length)) ?? []
        let tokens = matches.map { match in
            let word = (script as NSString).substring(with: match.range)
            return ScriptToken(display: word, key: word.lowercased(), stem: word.lowercased(), range: match.range, weight: 1)
        }
        let controller = PrompterWindowController()
        controller.setScript(text: script, tokens: tokens)
        controller.show()
        var index = -1
        controller.demoTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak controller] _ in
            MainActor.assumeIsolated {
                guard let controller else { return }
                index = (index + 1) % max(tokens.count, 1)
                controller.setCursor(wordIndex: index, animated: true)
            }
        }
        retainedController = controller
        return controller
    }
}
