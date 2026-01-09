import SwiftUI

struct TrainingGraphsView: View {
    private let learningCurveURL = URL(string: "https://projectgit-production.up.railway.app/static/learning_curve.png")!
    private let confusionMatrixURL = URL(string: "https://projectgit-production.up.railway.app/static/confusion_matrix.png")!
    private let rocCurveURL = URL(string: "https://projectgit-production.up.railway.app/static/roc_curve.png")!

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Eğitim Grafikleri")
                    .font(.title3.bold())

                graphSection(title: "Learning Curve", url: learningCurveURL)
                graphSection(title: "Confusion Matrix", url: confusionMatrixURL)
                graphSection(title: "ROC Curve", url: rocCurveURL)
            }
            .padding()
        }
        .background(Color(.systemBackground))
    }

    @ViewBuilder
    private func graphSection(title: String, url: URL) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.secondary.opacity(0.08))
                            .frame(maxWidth: .infinity)
                            .frame(height: 220)
                        ProgressView()
                    }
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                case .failure:
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.secondary.opacity(0.08))
                            .frame(maxWidth: .infinity)
                            .frame(height: 220)
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                            Text("Görsel yüklenemedi")
                                .foregroundStyle(.secondary)
                                .font(.footnote)
                            Text(url.absoluteString)
                                .foregroundStyle(.secondary)
                                .font(.caption2)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .padding()
                    }
                @unknown default:
                    EmptyView()
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        TrainingGraphsView()
            .navigationTitle("Grafikler")
    }
}

