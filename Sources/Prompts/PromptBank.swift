import Foundation

/// Local, curated therapeutic journaling prompts for v1.
/// The AI-generated prompt engine replaces this in a later version — this
/// keeps the app fully functional and demoable with no network or API key.
enum PromptBank {
    static let prompts: [String] = [
        "What's taking up the most space in your head right now?",
        "Describe a feeling you had today without naming it directly.",
        "What did you avoid today, and what were you protecting yourself from?",
        "Write about a moment you felt genuinely at ease this week.",
        "What would you say to a friend who was going through exactly what you are?",
        "Name one thing you're carrying that isn't actually yours to carry.",
        "What did your body feel like today? Start there, not with your thoughts.",
        "What's a small win you'd normally dismiss? Give it a paragraph.",
        "Who came to mind today, and what did they stir up?",
        "What are you pretending not to know?",
        "Finish this: 'I'd feel lighter if I could just...'",
        "What's one thing you wish someone had asked you this week?",
        "Describe today as weather. What was the forecast?",
        "What boundary did you hold, or wish you had held?",
        "What are you grateful for that you almost took for granted?",
        "Where did you feel most like yourself today?",
        "What thought kept looping? Write it out fully so it can rest.",
        "What would 'enough' look like for you this week?",
        "What did you need today that you didn't ask for?",
        "If your anxiety could talk, what is it trying to protect you from?",
    ]

    static func random(excluding current: String? = nil) -> String {
        let pool = prompts.filter { $0 != current }
        return pool.randomElement() ?? prompts[0]
    }
}
