import SwiftUI

struct PLYFile: Transferable {
    
    let pointCloud: PointCloud
    
    enum PLYError: LocalizedError {
        case cannotExport
        
        var errorDescription: String? {
            switch self {
            case .cannotExport:
                return "Could not convert PLY content to ASCII data."
            }
        }
    }
    
    func export() async throws -> Data {
        let verticesDict = await pointCloud.vertices
        let vertexCount = verticesDict.count
        
        // PLY Header
        var plyContent = """
        ply
        format ascii 1.0
        element vertex \(vertexCount)
        property float x
        property float y
        property float z
        property uchar red
        property uchar green
        property uchar blue
        property uchar alpha
        end_header
        """
        
        // Append each vertex line: x y z r g b a
        for vertex in verticesDict.values {
            let x = vertex.position.x
            let y = vertex.position.y
            let z = vertex.position.z
            
            let r = UInt8(max(0, min(255, vertex.color.x * 255)))
            let g = UInt8(max(0, min(255, vertex.color.y * 255)))
            let b = UInt8(max(0, min(255, vertex.color.z * 255)))
            let a = UInt8(max(0, min(255, vertex.color.w * 255)))
            
            plyContent += "\n\(x) \(y) \(z) \(r) \(g) \(b) \(a)"
        }
        
        guard let data = plyContent.data(using: .ascii) else {
            throw PLYError.cannotExport
        }
        
        return data
    }
    
    // MARK: - TransferRepresentation
    
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .data) {
            try await $0.export()
        }
        .suggestedFileName("exported.ply")
    }
}
