import SwiftUI

struct UIViewWrapper<V: UIView>: UIViewRepresentable {
    let view: V
    
    func makeUIView(context: Context) -> V {
        return view
    }
    
    func updateUIView(_ uiView: V, context: Context) { }
}

    @main
    struct PointCloudApp: App {
        
        @StateObject var arManager = ARManager()
        
        var body: some Scene {
            WindowGroup {
                ZStack(alignment: .bottom) {
                    // The AR view (SceneKit-based)
                    UIViewWrapper(view: arManager.sceneView)
                        .ignoresSafeArea()
                    
                    // Bottom toolbar: capture toggle & share button
                    HStack(spacing: 30) {
                        
                        // Start/Stop LiDAR capture
                        Button {
                            arManager.isCapturing.toggle()
                        } label: {
                            Image(systemName: arManager.isCapturing
                                  ? "stop.circle.fill"
                                  : "play.circle.fill")
                        }
                        
                        // Export the final point cloud as .PLY via ShareLink
                        ShareLink(
                            item: PLYFile(pointCloud: arManager.pointCloud),
                            preview: SharePreview("exported.ply")
                        ) {
                            Image(systemName: "square.and.arrow.up.circle.fill")
                        }
                    }
                    .foregroundStyle(.black, .white)
                    .font(.system(size: 50))
                    .padding(25)
                }
            }
        }
    }
