import SwiftUI

struct TrainingView: View {
    @State private var epochs: Int = 10
    @State private var progressText: String = ""
    @State private var statusText: String = ""
    @State private var percent: Double = 0
    @State private var isPolling = false
    @State private var trained = false
    @State private var runId: Int = 0

    var body: some View {
        VStack(spacing: 16) {
            Text("Eğitim Süreci").font(.title3.bold())

            HStack {
                Text("Epoch:")
                Stepper(value: $epochs, in: 1...50) {
                    Text("\(epochs)")
                }
            }

            Button {
                Task { await startTraining() }
            } label: {
                Text("🚀 Eğitimi Başlat")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            ProgressView(value: percent)
                .tint(.green)
                .padding(.vertical, 4)

            Text(progressText).bold()
            Text(statusText).bold()

            Spacer()
        }
        .padding()
        .onDisappear {
            isPolling = false
        }
    }

    private func startTraining() async {
        do {
            try await ApiClient.shared.startTraining(epochs: epochs)
            isPolling = true
            await pollProgress()
        } catch {
            statusText = "Eğitim başlatılamadı."
        }
    }

    private func pollProgress() async {
        while isPolling {
            do {
                let prog = try await ApiClient.shared.fetchProgress()
                runId = prog.run_id
                trained = prog.trained

                if prog.total > 0 {
                    percent = min(1.0, Double(prog.current) / Double(prog.total))
                    progressText = "Eğitim: \(prog.current) / \(prog.total) epoch"
                } else {
                    progressText = ""
                    percent = 0
                }

                if prog.running {
                    statusText = "⏳ Eğitim devam ediyor..."
                } else if prog.trained {
                    statusText = "✅ Eğitim tamamlandı!"
                    isPolling = false
                } else {
                    statusText = ""
                }

                try? await Task.sleep(nanoseconds: prog.running ? 800_000_000 : 2_000_000_000)
            } catch {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }
}
