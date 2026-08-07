import Foundation
import SwiftData

enum SampleDataSeeder {
    private static let flagKey = "afterna.sample.bigConversation.v1"

    /// Seeds a long sample memory (+ supporting list rows) once, so native feed ads have room to show.
    @MainActor
    static func seedIfNeeded(modelContext: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: flagKey) else { return }

        let existing = (try? modelContext.fetch(FetchDescriptor<ConversationEntity>())) ?? []
        // Don't spam if the user already has a large library.
        if existing.count >= 8 {
            UserDefaults.standard.set(true, forKey: flagKey)
            return
        }

        let big = ConversationEntity(
            title: "Client strategy workshop — sample",
            createdAt: Date().addingTimeInterval(-3600),
            durationMs: 48 * 60_000,
            statusRaw: "succeeded",
            isPinned: true
        )
        big.segments = Self.longTranscriptSegments()
        big.quotes = [
            QuoteEntity(
                text: "Let's treat the phone-on-the-table moment as the product.",
                speakerLabel: "A",
                startMs: 120_000,
                endMs: 126_000,
                conversation: big
            ),
            QuoteEntity(
                text: "If we can't find the commitment later, the note failed.",
                speakerLabel: "B",
                startMs: 540_000,
                endMs: 546_000,
                conversation: big
            ),
        ]
        big.actionItems = [
            ActionItemEntity(text: "Draft follow-up email with decisions", conversation: big),
            ActionItemEntity(text: "Share transcript highlights with Alex", conversation: big),
            ActionItemEntity(text: "Book next workshop for Thursday", status: .open, conversation: big),
        ]
        modelContext.insert(big)

        // Extra list rows so native ads can insert every N memories.
        let extras: [(String, Int)] = [
            ("Site walkthrough — Riverside lot", 12),
            ("Physician consult notes (sample)", 9),
            ("Tutor session: algebra review", 8),
            ("Inspect HVAC unit — Unit 4B", 7),
            ("Journalism interview — draft quotes", 11),
            ("Real-estate open home debrief", 6),
            ("Team standup catch-up", 5),
            ("Vendor negotiation call", 10),
            ("Patient intake summary (demo)", 8),
            ("Lecture capture — week 3", 14),
            ("Coffee chat with mentor", 4),
            ("Project kickoff with design", 9),
        ]

        for (index, pair) in extras.enumerated() {
            let conv = ConversationEntity(
                title: pair.0,
                createdAt: Date().addingTimeInterval(-Double(index + 2) * 7200),
                durationMs: pair.1 * 60_000,
                statusRaw: "succeeded"
            )
            conv.segments = Self.shortSegments(for: pair.0, count: max(pair.1, 4))
            modelContext.insert(conv)
        }

        try? modelContext.save()
        UserDefaults.standard.set(true, forKey: flagKey)
        print("[SampleData] Seeded big conversation + library rows")
    }

    private static func longTranscriptSegments() -> [TranscriptSegmentEntity] {
        let lines: [(String, String)] = [
            ("A", "Thanks for making time — I want to map how Afterna should feel in the first week."),
            ("B", "Agreed. The core loop is record, structure, recall, follow-up."),
            ("A", "Right. No bot in the meeting, no wearable pin, just the phone on the table."),
            ("B", "Let's treat the phone-on-the-table moment as the product."),
            ("A", "Capture has to be one thumb. Start, stop, done."),
            ("B", "And credits should stay quiet — people hate minute meters."),
            ("A", "Five welcome credits at ten minutes each gives a fair first session."),
            ("B", "Rewarded top-ups after that, opt-in only from the credits sheet."),
            ("A", "Ads never interrupt an active recording. That's non-negotiable."),
            ("B", "Native in the library every few rows is fine. Capture stays clean."),
            ("A", "For organization we need folders, pins, and a real to-do list."),
            ("B", "Pull quotes from the transcript matter for consultants and journalists."),
            ("A", "Long-press a line, save the quote to that memory."),
            ("B", "If we can't find the commitment later, the note failed."),
            ("A", "Action items should sync when signed in — guests can stay local."),
            ("B", "Folders for clients: Riverside, Clinic, Tutoring."),
            ("A", "Pin the active deal to the top of Memories."),
            ("B", "Search across transcripts has to feel instant on device."),
            ("A", "Ask AI later — citations back to the segment."),
            ("B", "For field work, Bluetooth headset quality still matters."),
            ("A", "Simulator testing needs a fallback tone if mic is unavailable."),
            ("B", "We should seed a long sample so design and ads can be reviewed."),
            ("A", "Native ads in the feed, interstitial after save, rewarded for credits."),
            ("B", "Banner only on Memories and Search — never on Capture."),
            ("A", "App open is okay on cold start."),
            ("B", "Privacy copy: user chooses what leaves the device."),
            ("A", "Supabase for sync, AssemblyAI for STT, OpenAI for extract."),
            ("B", "No provider keys on the phone."),
            ("A", "When transcription finishes, extract decisions and owners."),
            ("B", "Then surface them in the To-dos tab."),
            ("A", "Quotes tab is for the lines you'd put in a deck."),
            ("B", "Summary stays scannable — three beats, not a novel."),
            ("A", "Let's ship folders and pins this week."),
            ("B", "And make the sample conversation long enough to scroll."),
            ("A", "I'll add twelve supporting memories for the library feed."),
            ("B", "Perfect — that gives native ads places to sit."),
            ("A", "Any concerns on monetization optics?"),
            ("B", "Keep rewards honest. Cap daily rewarded ads."),
            ("A", "Remote config for reward minutes and feed interval."),
            ("B", "Default native every five rows feels right."),
            ("A", "I'll write that into the offline config defaults."),
            ("B", "Great. Next: TestFlight with a real device for Sign in with Apple."),
            ("A", "Simulator will keep showing Test mode on AdMob — that's expected."),
            ("B", "Document that for the partner."),
            ("A", "Anything else before we wrap?"),
            ("B", "Pin this workshop memory so it stays on top."),
            ("A", "Done. Thanks — clear next steps."),
            ("B", "Talk Thursday."),
        ]

        var segments: [TranscriptSegmentEntity] = []
        var t = 0
        for (speaker, text) in lines {
            let duration = max(3500, text.count * 45)
            segments.append(
                TranscriptSegmentEntity(
                    speakerLabel: speaker,
                    text: text,
                    startMs: t,
                    endMs: t + duration
                )
            )
            t += duration + 200
        }
        return segments
    }

    private static func shortSegments(for title: String, count: Int) -> [TranscriptSegmentEntity] {
        (0..<count).map { i in
            let start = i * 5000
            return TranscriptSegmentEntity(
                speakerLabel: i % 2 == 0 ? "A" : "B",
                text: "\(title): beat \(i + 1) — sample line for search and native feed layout.",
                startMs: start,
                endMs: start + 4200
            )
        }
    }
}
