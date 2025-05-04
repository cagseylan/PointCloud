import Foundation
import ARKit
import SceneKit
import SwiftUI

actor ARManager: NSObject, ARSessionDelegate, ObservableObject {
    
    // The SceneKit-based AR view
    @MainActor let sceneView = ARSCNView()
    
    // Node to display our point cloud geometry
    @MainActor let geometryNode = SCNNode()
    
    // Concurrency flags
    @MainActor private var isProcessing = false
    
    // UI toggle for starting/stopping capture
    @MainActor @Published var isCapturing = false
    
    // Reference to the point cloud actor
    let pointCloud = PointCloud()
    
    @MainActor
    override init() {
        super.init()
        
        // Configure AR session to use LiDAR depth
        sceneView.session.delegate = self
        let configuration = ARWorldTrackingConfiguration()
        configuration.frameSemantics = .sceneDepth
        sceneView.session.run(configuration)
        
        // Add geometry node to the scene's root
        sceneView.scene.rootNode.addChildNode(geometryNode)
    }
    
    // MARK: - ARSessionDelegate
    
    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        Task { await process(frame: frame) }
    }
    
    @MainActor
    private func process(frame: ARFrame) async {
        // Process only if capturing is ON and not currently busy
        guard !isProcessing && isCapturing else { return }
        
        isProcessing = true
        
        // 1) Merge new points into the point cloud
        await pointCloud.process(frame: frame)
        
        // 2) Update the point cloud geometry in the AR scene
        await updateGeometry()
        
        isProcessing = false
    }
    
    // Creates a SCNGeometry from the point cloud and updates geometryNode
    func updateGeometry() async {
        // Downsample: take only every 10th vertex for rendering
        let allVertices = await pointCloud.vertices.values
        let sampledVertices = allVertices.enumerated().compactMap { index, vertex in
            index % 10 == 0 ? vertex : nil
        }
        
        // 1) Positions (SCNGeometrySource)
        let vertexSource = SCNGeometrySource(vertices: sampledVertices.map { $0.position })
        
        // 2) Colors (SCNGeometrySource)
        let colorData = Data(bytes: sampledVertices.map { $0.color },
                             count: MemoryLayout<simd_float4>.size * sampledVertices.count)
        
        let colorSource = SCNGeometrySource(
            data: colorData,
            semantic: .color,
            vectorCount: sampledVertices.count,
            usesFloatComponents: true,
            componentsPerVector: 4,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<simd_float4>.size
        )
        
        // 3) Indices (SCNGeometryElement for .point)
        let pointIndices: [UInt32] = (0..<UInt32(sampledVertices.count)).map { $0 }
        let element = SCNGeometryElement(indices: pointIndices, primitiveType: .point)
        element.maximumPointScreenSpaceRadius = 15
        
        // 4) Combine sources & element into SCNGeometry
        let geometry = SCNGeometry(sources: [vertexSource, colorSource],
                                   elements: [element])
        
        geometry.firstMaterial?.isDoubleSided = true
        geometry.firstMaterial?.lightingModel = .constant
        
        // Assign geometry to geometryNode on the main actor
        Task { @MainActor in
            geometryNode.geometry = geometry
        }
    }
}
