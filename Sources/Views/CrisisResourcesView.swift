import SwiftUI

/// Immediate crisis resources. Lilac is a journaling/therapy-companion tool, not
/// a crisis service — this screen points to real help. US-focused; a person
/// outside the US should reach their local emergency number or crisis line.
struct CrisisResourcesView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("If you're in crisis or thinking about harming yourself, you don't have to handle it alone. Reach out now.")
                        .font(.system(.subheadline, design: .serif))
                        .foregroundStyle(Color.homeAccentDeep)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .homeCardBackground()

                    resource(
                        title: "988 Suicide & Crisis Lifeline",
                        detail: "Call or text 988 · 24/7, free, confidential (US)",
                        systemImage: "phone.fill",
                        url: URL(string: "tel:988")
                    )
                    resource(
                        title: "Crisis Text Line",
                        detail: "Text HOME to 741741 (US)",
                        systemImage: "message.fill",
                        url: URL(string: "sms:741741&body=HOME")
                    )
                    resource(
                        title: "Emergency services",
                        detail: "Call 911 if you or someone else is in immediate danger",
                        systemImage: "cross.case.fill",
                        url: URL(string: "tel:911")
                    )

                    Text("Outside the US, contact your local emergency number or a nearby crisis line. Consider reaching out to someone you trust, too.")
                        .font(.footnote)
                        .foregroundStyle(Color.homeSecondary)
                        .padding(.top, 4)
                }
                .padding(20)
            }
            .background(
                LinearGradient(colors: [.homeBackgroundTop, .homeBackgroundBottom],
                               startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            )
            .navigationTitle("Get help now")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(.homeAccent)
    }

    @ViewBuilder
    private func resource(title: String, detail: String, systemImage: String, url: URL?) -> some View {
        let content = HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.homeTint).frame(width: 44, height: 44)
                Image(systemName: systemImage).foregroundStyle(Color.homeAccent)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(.headline, design: .serif))
                    .foregroundStyle(Color.homeHeading)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Color.homeSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .homeCardBackground()

        if let url {
            Link(destination: url) { content }.buttonStyle(.plain)
        } else {
            content
        }
    }
}
