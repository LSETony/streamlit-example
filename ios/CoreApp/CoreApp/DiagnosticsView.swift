import SwiftUI

private enum DiagnosticsTab: String, CaseIterable {
    case body = "Body", blood = "Blood", vitamins = "Vitamins"
}

struct DiagnosticsView: View {
    @EnvironmentObject var appState: AppState
    @State private var tab: DiagnosticsTab = .body
    @State private var showBooking = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Text("Diagnostics")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(.white)
                        Spacer()
                        Button { showBooking = true } label: {
                            Image(systemName: "calendar.badge.plus")
                                .font(.system(size: 20))
                                .foregroundStyle(Color.appAccent)
                        }
                        .buttonStyle(.plain)
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
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showBooking) { NavigationStack { BookingView() } }
        }
    }

    private var segmentedControl: some View {
        HStack(spacing: 2) {
            ForEach(DiagnosticsTab.allCases, id: \.self) { t in
                Text(t.rawValue)
                    .font(.system(size: 13, weight: tab == t ? .semibold : .medium))
                    .foregroundStyle(tab == t ? .white : Color.appTextSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(tab == t ? Color.appSurface : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .onTapGesture { tab = t }
            }
        }
        .padding(2)
        .background(Color.appSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var bodyContent: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Muscle mass").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                    Spacer()
                    Text("+\(String(format: "%.1f", appState.muscleMassGainKg)) kg").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.appSuccess)
                }
                HStack(alignment: .bottom, spacing: 6) {
                    Text(String(format: "%.1f", appState.weightHistory.last?.value ?? 0))
                        .font(.digitalTimer(40))
                        .foregroundStyle(.white)
                    Text("kg").font(.system(size: 14)).foregroundStyle(Color.appTextSecondary)
                }
                WeightChart(points: appState.weightHistory).frame(height: 80).padding(.top, 6)
                HStack {
                    ForEach(appState.weightHistory) { point in
                        Text(point.label).font(.system(size: 11)).foregroundStyle(Color.appTextSecondary).frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(18)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 7) {
                Text("BODY COMPOSITION · \(appState.lastScanDate)").font(.system(size: 13)).foregroundStyle(Color.appTextSecondary)
                VStack(spacing: 0) {
                    ForEach(Array(appState.bodyMetrics.enumerated()), id: \.element.id) { index, metric in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(metric.name).font(.system(size: 16)).foregroundStyle(.white)
                                Text(metric.note).font(.system(size: 12)).foregroundStyle(Color.appTextSecondary)
                            }
                            Spacer()
                            Text(metric.value).font(.digitalTimer(17)).foregroundStyle(Color.appTextSecondary)
                            Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(Color.appTextSecondary)
                        }
                        .padding(.vertical, 13)
                        .padding(.horizontal, 16)
                        if index < appState.bodyMetrics.count - 1 { AppDivider() }
                    }
                }
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text("Measured on the club's bioimpedance scanner. Values drift up to 1% with hydration.")
                    .font(.system(size: 12)).foregroundStyle(Color.appTextSecondary)
            }

            VStack(spacing: 0) {
                Button { showBooking = true } label: {
                    linkRow("Book the \(appState.nextScanDate) scan · 09:00", color: .appAccent)
                }
                .buttonStyle(.plain)
                AppDivider()
                linkRow("Discuss with Elena Vasnetsova", color: .appTextPrimary)
            }
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func linkRow(_ text: String, color: Color) -> some View {
        HStack {
            Text(text).font(.system(size: 16)).foregroundStyle(color)
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(Color.appTextSecondary)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
    }

    private var bloodContent: some View {
        VStack(alignment: .leading, spacing: 22) {
            labGroup(title: "NEEDS ATTENTION", labs: appState.flaggedLabs)
            labGroup(title: "IN RANGE", labs: appState.okLabs)
            VStack(spacing: 0) {
                NavigationLink { AIAssistantView() } label: {
                    linkRow("Ask core AI to explain the panel", color: .appAccent)
                }
            }
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func labGroup(title: String, labs: [LabResult]) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.system(size: 13)).foregroundStyle(Color.appTextSecondary)
            VStack(spacing: 0) {
                ForEach(Array(labs.enumerated()), id: \.element.id) { index, lab in
                    HStack(spacing: 12) {
                        Circle().fill(lab.color).frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(lab.name).font(.system(size: 16)).foregroundStyle(.white)
                            Text("Range \(lab.range)").font(.system(size: 12)).foregroundStyle(Color.appTextSecondary)
                        }
                        Spacer()
                        Text(lab.value).font(.digitalTimer(17)).foregroundStyle(lab.color)
                        Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(Color.appTextSecondary)
                    }
                    .padding(.vertical, 13)
                    .padding(.horizontal, 16)
                    if index < labs.count - 1 { AppDivider() }
                }
            }
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

private struct WeightChart: View {
    let points: [BodyMetricPoint]

    var body: some View {
        GeometryReader { geo in
            let maxV = points.map(\.value).max() ?? 1
            let minV = points.map(\.value).min() ?? 0
            let range = max(maxV - minV, 0.1)
            Path { path in
                for (i, p) in points.enumerated() {
                    let x = geo.size.width * CGFloat(i) / CGFloat(max(points.count - 1, 1))
                    let normalized = (p.value - minV) / range
                    let y = geo.size.height * (1 - CGFloat(normalized)) * 0.85
                    if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
            }
            .stroke(Color.appAccent, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        }
    }
}

#Preview {
    NavigationStack { DiagnosticsView() }
        .environmentObject(AppState())
}
