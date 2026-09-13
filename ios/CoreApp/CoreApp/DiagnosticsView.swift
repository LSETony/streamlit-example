import SwiftUI

private enum DiagnosticsTab: String, CaseIterable {
    case body = "Body", blood = "Blood", vitamins = "Vitamins"
}

struct DiagnosticsView: View {
    @EnvironmentObject var appState: AppState
    @State private var tab: DiagnosticsTab = .body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("LAST SCAN \(appState.lastScanDate) · NEXT \(appState.nextScanDate)")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.4)
                        .foregroundStyle(Color.appTextSecondary)
                    Text("Diagnostics")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white)
                }

                segmentedControl

                switch tab {
                case .body: bodyContent
                case .blood: bloodContent
                case .vitamins: VitaminsListView()
                }
            }
            .screenPadding()
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Body")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var segmentedControl: some View {
        HStack(spacing: 6) {
            ForEach(DiagnosticsTab.allCases, id: \.self) { t in
                Button {
                    tab = t
                } label: {
                    Text(t.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(tab == t ? Color.white : Color.appTextSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(tab == t ? Color.appAccent : Color.clear)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.appSurface)
        .clipShape(Capsule())
    }

    private var bodyContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text(String(format: "%.1f", appState.weightHistory.last?.value ?? 0))
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("kg").font(.system(size: 16)).foregroundStyle(Color.appTextSecondary)
                    Text("+1.4").font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.appSuccess)
                }
                WeightChart(points: appState.weightHistory)
                    .frame(height: 90)
            }
            .appCard()

            metricRow(title: "Body fat", value: String(format: "%.1f%%", appState.bodyFatPercent), progress: appState.bodyFatPercent / 30, note: appState.bodyFatNote)
            metricRow(title: "Total body water", value: String(format: "%.1f%%", appState.totalBodyWaterPercent), progress: appState.totalBodyWaterPercent / 100, note: "In range", color: .white)
            metricRow(title: "Visceral fat index", value: "\(appState.visceralFatIndex)", progress: Double(appState.visceralFatIndex) / 20, note: "Healthy band is 1–9", color: .appSuccess)
            metricRow(title: "Basal metabolic rate", value: "\(appState.basalMetabolicRate)", progress: Double(appState.basalMetabolicRate) / 2400, note: "kcal at rest", color: .white)
        }
    }

    private func metricRow(title: String, value: String, progress: Double, note: String, color: Color = .appAccent) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                Spacer()
                Text(value).font(.system(size: 18, weight: .bold, design: .rounded)).foregroundStyle(.white)
            }
            ProgressBarView(value: progress, color: color, height: 5)
            Text(note).font(.system(size: 12)).foregroundStyle(Color.appTextTertiary)
        }
    }

    private var bloodContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            bloodRow(name: "Ferritin", value: "24 ng/mL", note: "Below reference range", color: .appAccent)
            bloodRow(name: "Vitamin D (25-OH)", value: "38 ng/mL", note: "In range", color: .appSuccess)
            bloodRow(name: "HbA1c", value: "5.1%", note: "In range", color: .appSuccess)
            bloodRow(name: "Total cholesterol", value: "184 mg/dL", note: "In range", color: .appSuccess)
            bloodRow(name: "TSH", value: "2.1 mIU/L", note: "In range", color: .appSuccess)
        }
    }

    private func bloodRow(name: String, value: String, note: String, color: Color) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                Text(note).font(.system(size: 12)).foregroundStyle(Color.appTextTertiary)
            }
            Spacer()
            Text(value).font(.system(size: 14, weight: .semibold)).foregroundStyle(color)
        }
        .padding(14)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
    }
}

private struct WeightChart: View {
    let points: [BodyMetricPoint]

    var body: some View {
        GeometryReader { geo in
            let maxV = points.map(\.value).max() ?? 1
            let minV = points.map(\.value).min() ?? 0
            let range = max(maxV - minV, 0.1)

            ZStack(alignment: .bottomLeading) {
                Path { path in
                    for (i, p) in points.enumerated() {
                        let x = geo.size.width * CGFloat(i) / CGFloat(max(points.count - 1, 1))
                        let normalized = (p.value - minV) / range
                        let y = geo.size.height * (1 - CGFloat(normalized)) * 0.85
                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(Color.appAccent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                HStack {
                    ForEach(points) { p in
                        Text(p.label)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.appTextTertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
    }
}

#Preview {
    NavigationStack { DiagnosticsView() }
        .environmentObject(AppState())
}
