import SwiftUI

enum NearNoteStyle {
    static let accent = Color(red: 38 / 255, green: 99 / 255, blue: 1)
    static let canvas = Color(red: 6 / 255, green: 14 / 255, blue: 23 / 255)
    static let surface = Color(red: 18 / 255, green: 26 / 255, blue: 36 / 255)
    static let raisedSurface = Color(red: 24 / 255, green: 33 / 255, blue: 45 / 255)
    static let secondarySurface = Color(red: 30 / 255, green: 42 / 255, blue: 57 / 255)
    static let hairline = Color.white.opacity(0.07)
    static let secondaryText = Color.white.opacity(0.58)

    static func categoryColor(_ category: PlaceCategory?) -> Color {
        switch category {
        case .pharmacy, .hospital: Color(red: 139 / 255, green: 92 / 255, blue: 246 / 255)
        case .supermarket, .mall: Color(red: 249 / 255, green: 144 / 255, blue: 14 / 255)
        case .gasStation, .parking: Color(red: 34 / 255, green: 197 / 255, blue: 94 / 255)
        case .cafe, .restaurant, .bakery: Color(red: 196 / 255, green: 129 / 255, blue: 74 / 255)
        case .florist, .gym: Color(red: 43 / 255, green: 183 / 255, blue: 129 / 255)
        case .atm, .bank, .office, .hardwareStore, .postOffice, .none: accent
        }
    }
}

struct NearNoteBackground: View {
    var body: some View {
        ZStack {
            NearNoteStyle.canvas
            RadialGradient(
                colors: [NearNoteStyle.accent.opacity(0.08), .clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 360
            )
        }
        .ignoresSafeArea()
    }
}

struct PlaceIcon: View {
    let category: PlaceCategory?
    var size: CGFloat = 44

    var body: some View {
        let color = NearNoteStyle.categoryColor(category)
        Image(systemName: category?.symbol ?? "mappin.and.ellipse")
            .font(.system(size: size * 0.38, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                LinearGradient(
                    colors: [color.opacity(0.98), color.opacity(0.65)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: Circle()
            )
            .shadow(color: color.opacity(0.22), radius: 10, y: 4)
    }
}

struct SectionHeading: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.title2.weight(.bold))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct NearNoteCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(16)
            .background(NearNoteStyle.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(NearNoteStyle.hairline, lineWidth: 0.5)
            }
    }
}

extension Double {
    var distanceText: String {
        if self < 1_000 { return "\(Int(self.rounded())) m" }
        return String(format: "%.1f km", self / 1_000)
    }
}
