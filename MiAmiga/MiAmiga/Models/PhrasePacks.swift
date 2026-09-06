import Foundation

/// The built-in phrase packs, seeded into SwiftData on first launch.
///
/// These are written as they'd actually be said, not as a textbook would put
/// them — "¿Me pones…?" rather than "Yo quisiera…", because the first is what
/// you hear in a bar in Madrid and the second marks you as reading from a book.
/// Spanish here is peninsular (es-ES) to match the TTS voice.
enum PhrasePacks {

    struct Pack {
        let category: String
        let symbol: String
        let phrases: [(english: String, spanish: String)]
    }

    static let all: [Pack] = [greetings, ordering, askingFor, everyday]

    // MARK: - Greetings

    static let greetings = Pack(
        category: "Greetings",
        symbol: "hand.wave",
        phrases: [
            ("Hello, how are you?", "Hola, ¿qué tal?"),
            ("Good morning", "Buenos días"),
            ("Good afternoon", "Buenas tardes"),
            ("Good evening", "Buenas noches"),
            ("Nice to meet you", "Encantado de conocerte"),
            ("My name is…", "Me llamo…"),
            ("What's your name?", "¿Cómo te llamas?"),
            ("Where are you from?", "¿De dónde eres?"),
            ("I'm from India", "Soy de la India"),
            ("See you later", "Hasta luego"),
            ("See you tomorrow", "Hasta mañana"),
            ("Have a good day", "Que tengas un buen día"),
            ("Thank you very much", "Muchas gracias"),
            ("You're welcome", "De nada"),
            ("Excuse me", "Perdona"),
            ("I'm sorry", "Lo siento"),
        ]
    )

    // MARK: - Ordering

    static let ordering = Pack(
        category: "Ordering",
        symbol: "fork.knife",
        phrases: [
            ("A table for two, please", "Una mesa para dos, por favor"),
            ("Can I see the menu?", "¿Me pasas la carta?"),
            ("What do you recommend?", "¿Qué me recomiendas?"),
            ("I'll have this one", "Yo quiero este"),
            ("A coffee, please", "Un café, por favor"),
            ("A beer, please", "Una caña, por favor"),
            ("Still water", "Agua sin gas"),
            ("Sparkling water", "Agua con gas"),
            ("I'm vegetarian", "Soy vegetariano"),
            ("Does this have meat?", "¿Esto lleva carne?"),
            ("Does this have nuts?", "¿Esto lleva frutos secos?"),
            ("It's delicious", "Está buenísimo"),
            ("The bill, please", "La cuenta, por favor"),
            ("Can I pay by card?", "¿Puedo pagar con tarjeta?"),
            ("Keep the change", "Quédate con el cambio"),
            ("Anything else?", "¿Algo más?"),
        ]
    )

    // MARK: - Asking for things

    static let askingFor = Pack(
        category: "Asking",
        symbol: "questionmark.circle",
        phrases: [
            ("Where is the bathroom?", "¿Dónde está el baño?"),
            ("How much does it cost?", "¿Cuánto cuesta?"),
            ("Can you help me?", "¿Me puedes ayudar?"),
            ("I don't understand", "No entiendo"),
            ("Can you repeat that?", "¿Puedes repetirlo?"),
            ("More slowly, please", "Más despacio, por favor"),
            ("Do you speak English?", "¿Hablas inglés?"),
            ("I don't speak much Spanish", "No hablo mucho español"),
            ("How do you say this in Spanish?", "¿Cómo se dice esto en español?"),
            ("What does that mean?", "¿Qué significa eso?"),
            ("Where is the station?", "¿Dónde está la estación?"),
            ("Is it far?", "¿Está lejos?"),
            ("I'm looking for this address", "Estoy buscando esta dirección"),
            ("Can you write it down?", "¿Me lo puedes escribir?"),
            ("What time does it open?", "¿A qué hora abre?"),
            ("What time does it close?", "¿A qué hora cierra?"),
        ]
    )

    // MARK: - Everyday

    static let everyday = Pack(
        category: "Everyday",
        symbol: "sun.max",
        phrases: [
            ("Yes, of course", "Sí, claro"),
            ("No, thank you", "No, gracias"),
            ("Maybe", "Quizás"),
            ("I don't know", "No lo sé"),
            ("I think so", "Creo que sí"),
            ("No problem", "No pasa nada"),
            ("It doesn't matter", "Da igual"),
            ("I like it a lot", "Me gusta mucho"),
            ("I don't like it", "No me gusta"),
            ("I'm tired", "Estoy cansado"),
            ("I'm hungry", "Tengo hambre"),
            ("I'm thirsty", "Tengo sed"),
            ("Let's go", "Vamos"),
            ("One moment", "Un momento"),
            ("Right now", "Ahora mismo"),
            ("What a shame", "Qué pena"),
            ("How nice!", "¡Qué bien!"),
            ("Don't worry", "No te preocupes"),
        ]
    )

    /// Flattened list used to seed the store on first launch.
    static var seedPhrases: [(english: String, spanish: String, category: String)] {
        all.flatMap { pack in
            pack.phrases.map { ($0.english, $0.spanish, pack.category) }
        }
    }

    static func symbol(for category: String) -> String {
        all.first { $0.category == category }?.symbol ?? "star"
    }
}
