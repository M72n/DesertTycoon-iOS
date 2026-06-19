import SpriteKit
import SwiftUI

@MainActor
struct ContentView: View {
    @StateObject private var sceneHost = GameSceneHost()

    var body: some View {
        GeometryReader { proxy in
            SpriteView(scene: sceneHost.scene, options: [.ignoresSiblingOrder])
                .ignoresSafeArea()
                .background(Color.black)
                .onAppear {
                    sceneHost.resize(to: proxy.size)
                }
                .onChange(of: proxy.size) { _, newSize in
                    sceneHost.resize(to: newSize)
                }
        }
        .preferredColorScheme(.dark)
    }
}

@MainActor
private final class GameSceneHost: ObservableObject {
    let scene: DesertTycoonScene

    init() {
        scene = DesertTycoonScene(size: CGSize(width: 390, height: 844))
        scene.scaleMode = .resizeFill
    }

    func resize(to size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        scene.size = size
        scene.layoutCamera()
    }
}

#Preview {
    ContentView()
}
