import SwiftUI
import SwiftData
import PencilKit

/// The reusable writing surface every journaling type is built on: the day's
/// date, an optional `accessory` (a prompt, a mood, anything a type adds above
/// the page), a ruled page you write on, and a slider that tightens the lines.
///
/// The free-form diary is just `JournalPage(entry:)`. A future prompted type
/// passes an `accessory` — and its own `theme` if it wants a different look:
///
///     JournalPage(entry: entry) {
///         PromptBanner(text: entry.prompt)
///     }
struct JournalPage<Accessory: View>: View {
    @Bindable var entry: JournalEntry
    var theme: JournalTheme
    @ViewBuilder var accessory: () -> Accessory

    @State private var lineSpacing: CGFloat

    init(
        entry: JournalEntry,
        theme: JournalTheme = .diary,
        @ViewBuilder accessory: @escaping () -> Accessory = { EmptyView() }
    ) {
        self.entry = entry
        self.theme = theme
        self.accessory = accessory
        _lineSpacing = State(initialValue: theme.defaultSpacing)
    }

    private var loadedDrawing: PKDrawing {
        (try? PKDrawing(data: entry.drawingData)) ?? PKDrawing()
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ZStack {
                RuledPaper(spacing: lineSpacing, rule: theme.rule, margin: theme.margin)
                DrawingCanvas(initialDrawing: loadedDrawing, ink: UIColor(theme.ink)) { drawing in
                    entry.drawingData = drawing.dataRepresentation()
                }
            }

            spacingControl
        }
        .background(theme.paper)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(theme.paper, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .tint(theme.ink)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.createdAt.formatted(.dateTime.weekday(.wide)))
                    .font(.system(.largeTitle, design: .serif))
                    .foregroundStyle(theme.ink)
                Text(entry.createdAt.formatted(.dateTime.day().month(.wide).year()))
                    .font(.system(.subheadline, design: .serif).italic())
                    .foregroundStyle(theme.ink.opacity(0.55))
            }
            accessory()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 18)
    }

    private var spacingControl: some View {
        HStack(spacing: 16) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 10))
                .foregroundStyle(theme.ink.opacity(0.4))
            Slider(value: $lineSpacing, in: theme.spacingRange)
                .tint(theme.margin)
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 18))
                .foregroundStyle(theme.ink.opacity(0.4))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(theme.paper)
        .overlay(alignment: .top) {
            Rectangle().fill(theme.rule).frame(height: 0.75)
        }
    }
}
