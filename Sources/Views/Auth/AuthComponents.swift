import SwiftUI

/// The Lilac wordmark — the rounded, soft logotype from the splash. Pairs with
/// `GlowOrbView` as the mark.
struct LilacWordmark: View {
    var size: CGFloat = 40

    var body: some View {
        Text("Lilac")
            .font(.system(size: size, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.homeAccent)
            .accessibilityAddTraits(.isHeader)
    }
}

/// The full lockup used on the splash and auth screens: orb over the wordmark.
struct LilacLockup: View {
    var orbSize: CGFloat = 110
    var wordmarkSize: CGFloat = 40

    var body: some View {
        VStack(spacing: 8) {
            GlowOrbView(size: orbSize)
            LilacWordmark(size: wordmarkSize)
        }
    }
}

// MARK: - Passcode pad

/// A numeric passcode pad with a row of progress dots. Appends digits to `code`
/// up to `length`, then reports `onComplete`. The parent clears/keeps `code`.
struct PasscodePad: View {
    @Binding var code: String
    var length: Int = 4
    var showsBiometryButton = false
    var biometrySymbol = "faceid"
    var onBiometry: () -> Void = {}
    var onComplete: (String) -> Void

    private let keys: [[String]] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        ["", "0", "⌫"]
    ]

    var body: some View {
        VStack(spacing: 28) {
            dots
            VStack(spacing: 18) {
                ForEach(keys, id: \.self) { row in
                    HStack(spacing: 26) {
                        ForEach(row, id: \.self) { key in
                            keyButton(key)
                        }
                    }
                }
            }
        }
    }

    private var dots: some View {
        HStack(spacing: 18) {
            ForEach(0..<length, id: \.self) { index in
                Circle()
                    .strokeBorder(Color.homeAccent, lineWidth: 1.5)
                    .background(Circle().fill(index < code.count ? Color.homeAccent : .clear))
                    .frame(width: 14, height: 14)
            }
        }
    }

    @ViewBuilder
    private func keyButton(_ key: String) -> some View {
        switch key {
        case "":
            if showsBiometryButton {
                Button(action: onBiometry) {
                    Image(systemName: biometrySymbol)
                        .font(.title2)
                        .foregroundStyle(Color.homeAccent)
                        .frame(width: 72, height: 72)
                }
            } else {
                Color.clear.frame(width: 72, height: 72)
            }
        case "⌫":
            Button(action: deleteLast) {
                Image(systemName: "delete.left")
                    .font(.title2)
                    .foregroundStyle(Color.homeAccent)
                    .frame(width: 72, height: 72)
            }
            .disabled(code.isEmpty)
            .opacity(code.isEmpty ? 0.35 : 1)
        default:
            Button { append(key) } label: {
                Text(key)
                    .font(.system(size: 30, weight: .regular, design: .rounded))
                    .foregroundStyle(Color.homeAccentDeep)
                    .frame(width: 72, height: 72)
                    .background(
                        Circle().fill(Color.homeCard)
                            .overlay(Circle().stroke(Color.homeHairline, lineWidth: 1))
                    )
            }
        }
    }

    private func append(_ digit: String) {
        guard code.count < length else { return }
        code += digit
        if code.count == length {
            onComplete(code)
        }
    }

    private func deleteLast() {
        guard !code.isEmpty else { return }
        code.removeLast()
    }
}

/// A horizontal shake, used to signal a wrong passcode.
struct ShakeEffect: GeometryEffect {
    var travel: CGFloat = 8
    var shakes: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = travel * sin(animatableData * .pi * shakes)
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}
