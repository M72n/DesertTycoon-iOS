import SwiftUI
import UIKit

struct ContentView: View {
    @State private var selectedPhase: GamePhase = .phaseOne
    @State private var selectedPanel: GamePanel = .map

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let safeArea = geometry.safeAreaInsets
            let isWide = size.width > size.height

            ZStack {
                BundleImage(name: "preview_splash_arabic.jpg")
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipped()
                    .overlay(Color.black.opacity(0.24))
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 14) {
                        headerBar(isWide: isWide)

                        if isWide {
                            HStack(alignment: .stretch, spacing: 14) {
                                stagePanel
                                controlPanel
                                    .frame(width: min(320, size.width * 0.32))
                            }
                        } else {
                            VStack(spacing: 14) {
                                stagePanel
                                controlPanel
                            }
                        }

                        phasePicker
                    }
                    .padding(.top, safeArea.top + 12)
                    .padding(.bottom, safeArea.bottom + 18)
                    .padding(.horizontal, max(14, min(28, size.width * 0.04)))
                    .frame(minHeight: max(0, size.height - safeArea.top - safeArea.bottom), alignment: .top)
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .preferredColorScheme(.dark)
    }

    private func headerBar(isWide: Bool) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("سلطان الصحراء")
                    .font(isWide ? .title.bold() : .title2.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(selectedPhase.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                ResourceMeter(systemImage: "dollarsign.circle.fill", value: "12.4K", tint: .yellow)
                ResourceMeter(systemImage: "drop.fill", value: "860", tint: .cyan)
                ResourceMeter(systemImage: "person.2.fill", value: "24", tint: .green)
            }
        }
        .panelStyle()
    }

    private var stagePanel: some View {
        ZStack(alignment: .bottomLeading) {
            BundleImage(name: selectedPanel == .map ? selectedPhase.mapAssetName : "preview_souk_bg.jpg")
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: selectedPanel == .map ? 390 : 340)
                .clipped()
                .overlay(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.58)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                )

            VStack(alignment: .leading, spacing: 8) {
                Text(selectedPanel == .map ? selectedPhase.subtitle : "السوق")
                    .font(.headline.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                HStack(spacing: 8) {
                    Button {
                        selectedPanel = .map
                    } label: {
                        Label("الخريطة", systemImage: "map.fill")
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        selectedPanel = .souk
                    } label: {
                        Label("السوق", systemImage: "cart.fill")
                    }
                    .buttonStyle(.bordered)
                }
                .labelStyle(.titleAndIcon)
                .font(.subheadline.weight(.semibold))
            }
            .padding(14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.24), lineWidth: 1)
        )
    }

    private var controlPanel: some View {
        VStack(alignment: .stretch, spacing: 12) {
            Picker("المشهد", selection: $selectedPanel) {
                ForEach(GamePanel.allCases) { panel in
                    Text(panel.title).tag(panel)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 10) {
                ObjectiveRow(icon: "hammer.fill", title: "تطوير الواحة", progress: 0.68, tint: .orange)
                ObjectiveRow(icon: "fuelpump.fill", title: "رفع إنتاج النفط", progress: 0.42, tint: .cyan)
                ObjectiveRow(icon: "building.2.fill", title: "توسيع السوق", progress: 0.31, tint: .green)
            }

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                Button {
                    selectedPanel = .map
                } label: {
                    Label("ابدأ", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    selectedPanel = .souk
                } label: {
                    Image(systemName: "bag.fill")
                        .frame(width: 34)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("السوق")
            }
            .font(.headline)
        }
        .panelStyle()
    }

    private var phasePicker: some View {
        HStack(spacing: 10) {
            ForEach(GamePhase.allCases) { phase in
                Button {
                    selectedPhase = phase
                    selectedPanel = .map
                } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        Image(systemName: phase.symbolName)
                            .font(.title3)
                            .foregroundStyle(phase.tint)

                        Text(phase.title)
                            .font(.subheadline.bold())
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(selectedPhase == phase ? phase.tint.opacity(0.28) : .white.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(selectedPhase == phase ? phase.tint.opacity(0.8) : .white.opacity(0.16), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .panelStyle()
    }
}

private enum GamePanel: String, CaseIterable, Identifiable {
    case map
    case souk

    var id: String { rawValue }

    var title: String {
        switch self {
        case .map:
            return "الخريطة"
        case .souk:
            return "السوق"
        }
    }
}

private enum GamePhase: String, CaseIterable, Identifiable {
    case phaseOne
    case phaseTwo
    case phaseThree

    var id: String { rawValue }

    var title: String {
        switch self {
        case .phaseOne:
            return "المرحلة الأولى"
        case .phaseTwo:
            return "المرحلة الثانية"
        case .phaseThree:
            return "المرحلة الثالثة"
        }
    }

    var subtitle: String {
        switch self {
        case .phaseOne:
            return "بناء الواحة الأولى"
        case .phaseTwo:
            return "توسيع خطوط السفر"
        case .phaseThree:
            return "إدارة المدينة النفطية"
        }
    }

    var mapAssetName: String {
        switch self {
        case .phaseOne:
            return "preview_phase1_map.png"
        case .phaseTwo:
            return "preview_phase2_map.png"
        case .phaseThree:
            return "preview_phase3_map.png"
        }
    }

    var symbolName: String {
        switch self {
        case .phaseOne:
            return "leaf.fill"
        case .phaseTwo:
            return "road.lanes"
        case .phaseThree:
            return "building.columns.fill"
        }
    }

    var tint: Color {
        switch self {
        case .phaseOne:
            return .green
        case .phaseTwo:
            return .orange
        case .phaseThree:
            return .cyan
        }
    }
}

private struct BundleImage: View {
    let name: String

    var body: some View {
        if let image = UIImage(named: name) {
            Image(uiImage: image)
                .resizable()
        } else {
            Rectangle()
                .fill(.black.opacity(0.34))
                .overlay(
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.white.opacity(0.6))
                )
        }
    }
}

private struct ResourceMeter: View {
    let systemImage: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
            Text(value)
                .font(.subheadline.monospacedDigit().bold())
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(.black.opacity(0.22), in: Capsule())
    }
}

private struct ObjectiveRow: View {
    let icon: String
    let title: String
    let progress: Double
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                    .frame(width: 20)

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)

                Spacer(minLength: 4)

                Text(progress, format: .percent.precision(.fractionLength(0)))
                    .font(.caption.monospacedDigit().bold())
                    .foregroundStyle(.white.opacity(0.78))
            }

            ProgressView(value: progress)
                .tint(tint)
        }
        .padding(10)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private extension View {
    func panelStyle() -> some View {
        self
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.white.opacity(0.22), lineWidth: 1)
            )
    }
}

#Preview {
    ContentView()
}
