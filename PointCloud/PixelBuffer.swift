import CoreVideo
import simd

// Simple struct to store the width and height of a buffer.
struct Size {
    let width: Int
    let height: Int
    
    var asFloat: simd_float2 {
        simd_float2(Float(width), Float(height))
    }
}

final class PixelBuffer<T> {
    
    let size: Size
    let bytesPerRow: Int
    
    private let pixelBuffer: CVPixelBuffer
    private let baseAddress: UnsafeMutableRawPointer
    
    init?(pixelBuffer: CVPixelBuffer) {
        self.pixelBuffer = pixelBuffer
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        
        guard let base = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0) else {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
            return nil
        }
        baseAddress = base
        
        size = Size(width: CVPixelBufferGetWidth(pixelBuffer),
                    height: CVPixelBufferGetHeight(pixelBuffer))
        bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
    }
    
    func value(x: Int, y: Int) -> T {
        let offset = y * bytesPerRow
        let rowPtr = baseAddress.advanced(by: offset)
        return rowPtr.assumingMemoryBound(to: T.self)[x]
    }
    
    deinit {
        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
    }
}
