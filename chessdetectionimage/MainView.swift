import SwiftUI

struct MainView: View {
    var body: some View {
        TabView {
            NavigationStack {
                TrainingView()
                    .navigationTitle("Eğitim")
            }
            .tabItem {
                Label("Eğitim", systemImage: "bolt.fill")
            }

            NavigationStack {
                PredictView()
                    .navigationTitle("Tahmin")
            }
            .tabItem {
                Label("Tahmin", systemImage: "camera.fill")
            }

            NavigationStack {
                TrainingGraphsView()
                    .navigationTitle("Grafikler")
            }
            .tabItem {
                Label("Grafikler", systemImage: "chart.bar.xaxis")
            }
        }
    }
}
