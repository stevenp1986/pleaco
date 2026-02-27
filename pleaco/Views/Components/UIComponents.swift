import SwiftUI

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        Label(title, systemImage: icon)
            .font(.headline.weight(.semibold))
            .foregroundColor(Color.appAccent.opacity(0.9))
    }
}

// MARK: - Standard App Card Style

struct AppCardModifier: ViewModifier {
    let isSelected: Bool
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(isSelected ? AnyShapeStyle(LinearGradient.accentGradient) : AnyShapeStyle(Color.cardBackground))
            )
            .overlay(
                LinearGradient.cardGradient
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .opacity(isSelected ? 1 : 0)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(
                        isSelected ? Color.white.opacity(0.12) : Color.subtleBorder,
                        lineWidth: 0.5
                    )
            )
            .shadow(
                color: isSelected ? Color.glowAccent : .black.opacity(0.05),
                radius: isSelected ? 14 : 3,
                x: 0,
                y: isSelected ? 7 : 2
            )
    }
}

extension View {
    func appCardStyle(isSelected: Bool = false) -> some View {
        self.modifier(AppCardModifier(isSelected: isSelected))
    }
}
