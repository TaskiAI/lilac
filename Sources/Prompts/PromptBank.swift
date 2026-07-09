import Foundation

/// Local, curated therapeutic journaling prompts for v1, organized by
/// journaling style. The AI-generated prompt engine replaces this in a
/// later version — this keeps the app fully functional and demoable with
/// no network or API key.
enum PromptBank {
    static let emotional: [String] = [
        "Describe a moment that made you cringe. What did it reveal about what you care about?",
        "What happened today that hit harder than you expected?",
        "What did you avoid today, and what were you protecting yourself from?",
        "Write about a moment you felt genuinely at ease this week.",
        "What's a feeling you had today that you never actually named?",
        "Describe the last time you felt truly proud of yourself.",
        "What would you say to a friend who was going through exactly what you are?",
        "Name one thing you're carrying that isn't actually yours to carry.",
        "What did your body feel like today? Start there, not with your thoughts.",
        "Who came to mind today, and what did they stir up?",
        "What are you pretending not to know?",
        "What boundary did you hold, or wish you had held?",
        "If your anxiety could talk, what is it trying to protect you from?",
        "What's a moment from today you'd rather forget? Write it down anyway.",
    ]

    static let gratitude: [String] = [
        "What are you grateful for that you almost took for granted?",
        "Describe an awesome week you had recently. What made it awesome?",
        "Who is a friend you want to thank right now, and for what?",
        "What's a small win you'd normally dismiss? Give it a paragraph.",
        "What made you laugh this week?",
        "Describe a moment someone showed up for you without being asked.",
        "What's something ordinary about your day that you'd miss if it were gone?",
        "Write a thank-you note to a version of yourself from a hard time.",
        "What's one thing you're looking forward to, and why does it matter?",
        "Where did you feel most like yourself today?",
        "What's a comfort you rely on that you've never actually thanked?",
        "Describe a place that always makes you feel grateful to exist.",
    ]

    static let freeFlow: [String] = [
        "What's taking up the most space in your head right now?",
        "Start with the weather today, and see where it takes you.",
        "Finish this: 'I'd feel lighter if I could just...'",
        "Write about the last conversation that's still echoing in your head.",
        "What's one thing you wish someone had asked you this week?",
        "Describe today as weather. What was the forecast?",
        "What would 'enough' look like for you this week?",
        "What did you need today that you didn't ask for?",
        "Start with the last thing you ate, and let your mind wander from there.",
        "What thought kept looping? Write it out fully so it can rest.",
        "Pick any object within arm's reach and write until it leads somewhere else.",
        "What's a question you've been avoiding asking yourself?",
        "Start mid-thought, as if you were already halfway through a sentence.",
        "What's on the edge of your attention that you keep pushing aside?",
    ]

    static let replayAnalysis: [String] = [
        "Play back today like a replay file. What's the first moment you'd pause on?",
        "Where in today did you react on autopilot? What would slow-motion reveal?",
        "What's a blind spot from this week you only see now, looking back?",
        "Rewind to a conversation today. What would you change if you could replay it?",
        "What decision today deserves a second look, away from the heat of the moment?",
        "If a stranger watched today's footage, what would they notice that you didn't?",
        "What pattern keeps showing up when you review your last few days?",
        "Where did you flinch today, and what triggered it?",
        "What moment today would you bookmark to study later?",
        "Looking back at this week from the outside, what's the one thing you'd flag?",
        "What did you do on instinct today that's worth examining more closely?",
        "If you could add commentary to today's replay, what would you point out?",
    ]

    static func prompts(for style: JournalStyle) -> [String] {
        switch style {
        case .emotional: return emotional
        case .gratitude: return gratitude
        case .freeFlow: return freeFlow
        case .replayAnalysis: return replayAnalysis
        }
    }

    static func random(for style: JournalStyle, excluding current: String? = nil) -> String {
        let pool = prompts(for: style)
        let filtered = pool.filter { $0 != current }
        return filtered.randomElement() ?? pool.first ?? ""
    }
}
