import SwiftUI

struct ScoreHeaderView: View {
    let score: SkinScore?

    var body: some View {
        VStack(spacing: 12) {
            Text(dateTitle)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(overallText)
                .font(.system(size: 44, weight: .bold, design: .rounded))

            chipGrid
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .multilineTextAlignment(.center)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
        )
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
        .padding(.horizontal)
    }

    private var overallText: String {
        guard let s = score else { return "—/100" }
        return "\(s.overall)/100"
    }

    private var dateTitle: String {
        guard let d = score?.createdAt else { return "SKIN SCORE" }
        let f = DateFormatter()
        f.dateFormat = "MMM d • SKIN SCORE"
        return f.string(from: d).uppercased()
    }

    private var chipGrid: some View {
        let s = score?.subscores
        return VStack(spacing: 8) {
            HStack(spacing: 8) {
                chip("HYDRATION", s?.barrierHydration)
                chip("COMPLEXION", s?.complexion)
            }
            HStack(spacing: 8) {
                chip("ACNE & TEXTURE", s?.acneTexture)
                chip("WRINKLES", s?.fineLines)
            }
            HStack(spacing: 8) {
                chip("DARK CIRCLES", s?.eyes)
            }
        }
    }

    private func chip(_ title: String, _ value: Int?) -> some View {
        Text("\(title) • \(value ?? 0)")
            .font(.footnote)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(Color(.secondarySystemBackground))
            )
    }
}


