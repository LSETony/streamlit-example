import SwiftUI

/// A small animated "thinking" orb — native SwiftUI stand-in for the
/// "thinking-orbs" npm package (React-only, zero-dependency but built for
/// React 18+, so it can't be installed into this native Swift target).
/// Three soft blurred blobs orbit a breathing gradient core, driven by a
/// continuous `TimelineView` clock instead of discrete keyframes. Used by
/// CoreAIChatView while Core AI is composing a reply.
struct ThinkingOrb: View {
    var size: CGFloat = 20
    var speed: Double = 1

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate * speed
            Canvas { ctx, canvasSize in
                let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                let baseRadius = min(canvasSize.width, canvasSize.height) / 2

                for i in 0..<3 {
                    let phase = t + Double(i) * (2 * .pi / 3)
                    let orbit = baseRadius * 0.22
                    let x = center.x + cos(phase * 1.3) * orbit
                    let y = center.y + sin(phase * 1.7) * orbit
                    let blobRadius = baseRadius * (0.62 + 0.08 * sin(phase))
                    let rect = CGRect(x: x - blobRadius, y: y - blobRadius, width: blobRadius * 2, height: blobRadius * 2)
                    let hue = (0.02 + Double(i) * 0.12 + t * 0.02).truncatingRemainder(dividingBy: 1)
                    let color = Color(hue: hue, saturation: 0.85, brightness: 1)
                    ctx.drawLayer { layer in
                        layer.addFilter(.blur(radius: baseRadius * 0.35))
                        layer.opacity = 0.85
                        layer.fill(Path(ellipseIn: rect), with: .color(color))
                    }
                }

                let breath = 1 + 0.06 * sin(t * 2)
                let coreRadius = baseRadius * 0.5 * breath
                let coreRect = CGRect(x: center.x - coreRadius, y: center.y - coreRadius, width: coreRadius * 2, height: coreRadius * 2)
                ctx.fill(
                    Path(ellipseIn: coreRect),
                    with: .radialGradient(
                        Gradient(colors: [.white, Color.appAccent, Color.appAccentPurple]),
                        center: center, startRadius: 0, endRadius: coreRadius
                    )
                )
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

#Preview {
    VStack(spacing: 24) {
        ThinkingOrb(size: 64)
        ThinkingOrb(size: 20)
    }
    .padding()
    .background(Color.appBackground)
}
