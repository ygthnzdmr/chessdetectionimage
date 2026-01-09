import SwiftUI
import PhotosUI

struct PredictView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var resultText: String?
    @State private var confidence: Double?
    @State private var isLoading = false
    @State private var errorText: String?
    @State private var serverImageURLString: String?

    var body: some View {
        VStack(spacing: 16) {
            Text("♟ Satranç Taşı Tanıma").font(.title3.bold())

            if let imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Text("Bir görüntü seçin").foregroundColor(.secondary)
            }

            PhotosPicker("Görüntü Seç", selection: $selectedItem, matching: .images)

            Button("📸 Foto Yükle ve Tahmin Et") {
                Task { await predict() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(imageData == nil || isLoading)

            if isLoading {
                ProgressView("Tahmin ediliyor...")
            }

            if let resultText {
                Text("Tahmin: \(resultText)").font(.headline)
            }
            if let confidence {
                Text(String(format: "Güven: %.2f%%", confidence))
                    .foregroundColor(.secondary)
            }

            if let urlString = serverImageURLString, let url = URL(string: urlString) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sunucunun döndürdüğü görsel")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(height: 120)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        case .failure:
                            Text("Görsel yüklenemedi: \(url.absoluteString)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
            }

            if let errorText {
                Text(errorText).foregroundColor(.red)
            }

            Spacer()
        }
        .padding()
        .onChange(of: selectedItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    imageData = data
                    resultText = nil
                    confidence = nil
                    errorText = nil
                    serverImageURLString = nil
                }
            }
        }
    }

    private func predict() async {
        guard let imageData else { return }
        isLoading = true
        errorText = nil
        defer { isLoading = false }

        do {
            let resp = try await ApiClient.shared.predict(imageData: imageData)
            resultText = resp.label
            confidence = resp.confidence
            serverImageURLString = resp.additionalInfo
        } catch {
            errorText = "Tahmin başarısız. /predict JSON yanıtı alınamadı."
        }
    }
}

