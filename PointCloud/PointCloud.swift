import ARKit
import SceneKit
import simd

actor PointCloud {
    
    // MARK: - Nested Types
    
    struct GridKey: Hashable {
        
        static let density: Float = 100
        
        private let id: Int
        
        // Rounds each coordinate to group nearby points into the same key.
        init(_ position: SCNVector3) {
            var hasher = Hasher()
            for component in [position.x, position.y, position.z] {
                hasher.combine(Int(round(component * Self.density)))
            }
            id = hasher.finalize()
        }
    }
    
    struct Vertex {
        let position: SCNVector3
        let color: simd_float4
    }
    
    // A dictionary: each GridKey maps to one "representative" vertex.
    private(set) var vertices: [GridKey : Vertex] = [:]
    
    // MARK: - Public API
    
    func process(frame: ARFrame) async {
        guard let depthData = frame.smoothedSceneDepth ?? frame.sceneDepth,
              let depthBuffer = PixelBuffer<Float32>(pixelBuffer: depthData.depthMap),
              let confidenceMap = depthData.confidenceMap,
              let confidenceBuffer = PixelBuffer<UInt8>(pixelBuffer: confidenceMap),
              let imageBuffer = YCBCRBuffer(pixelBuffer: frame.capturedImage)
        else {
            return
        }
        
        // Rotation/flip matrix for camera orientation
        let rotateToARCamera = makeRotateToARCameraMatrix(orientation: .portrait)
        
        // ARKit camera transform: from camera to world space
        let cameraTransform = frame.camera.viewMatrix(for: .portrait).inverse * rotateToARCamera
        
        // Inverse intrinsics for unprojecting 2D to 3D
        let invIntrinsics = simd_inverse(frame.camera.intrinsics)
        
        for row in 0..<depthBuffer.size.height {
            for col in 0..<depthBuffer.size.width {
                
                // 1) Confidence
                let confidenceRawValue = Int(confidenceBuffer.value(x: col, y: row))
                guard let confidence = ARConfidenceLevel(rawValue: confidenceRawValue),
                      confidence == .high else {
                    continue
                }
                
                // 2) Depth
                let depth = depthBuffer.value(x: col, y: row)
                if depth > 2 {
                    continue
                }
                
                // 3) Convert (col, row) -> normalized [0..1]
                let nx = Float(col) / Float(depthBuffer.size.width)
                let ny = Float(row) / Float(depthBuffer.size.height)
                
                // 4) Map to color image for color sampling
                let imageSize = imageBuffer.size.asFloat
                let pixelX = Int(round(nx * imageSize.x))
                let pixelY = Int(round(ny * imageSize.y))
                
                // Check bounds
                guard pixelX >= 0, pixelX < Int(imageSize.x),
                      pixelY >= 0, pixelY < Int(imageSize.y) else {
                    continue
                }
                
                let color = imageBuffer.color(x: pixelX, y: pixelY)
                
                // 5) Unproject to camera space
                let screenPoint = simd_float3(nx * imageSize.x, ny * imageSize.y, 1)
                let localPoint = invIntrinsics * screenPoint * depth
                
                // 6) Transform camera space -> AR world space
                let worldPoint4 = cameraTransform * simd_float4(localPoint, 1)
                let wp = worldPoint4 / worldPoint4.w
                
                let position = SCNVector3(wp.x, wp.y, wp.z)
                
                // 7) Merge using GridKey
                let key = GridKey(position)
                if vertices[key] == nil {
                    vertices[key] = Vertex(position: position, color: color)
                }
            }
        }
    }
    
    // MARK: - Orientation Helpers
    
    func makeRotateToARCameraMatrix(orientation: UIInterfaceOrientation) -> matrix_float4x4 {
        let flipYZ = matrix_float4x4(
            [ 1,  0,  0, 0],
            [ 0, -1,  0, 0],
            [ 0,  0, -1, 0],
            [ 0,  0,  0, 1]
        )
        let rotationAngle: Float = {
            switch orientation {
            case .landscapeLeft:      return .pi
            case .portrait:           return .pi / 2
            case .portraitUpsideDown: return -.pi / 2
            default:                  return 0
            }
        }()
        
        let quat = simd_quaternion(rotationAngle, simd_float3(0, 0, 1))
        let rotationMatrix = matrix_float4x4(quat)
        return flipYZ * rotationMatrix
    }
}
