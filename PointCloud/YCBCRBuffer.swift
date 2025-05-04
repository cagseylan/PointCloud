import CoreVideo
import simd
import UIKit

final class YCBCRBuffer {
    
    let size: Size
    
    private let pixelBuffer: CVPixelBuffer
    private let yPlane: UnsafeMutableRawPointer
    private let cbCrPlane: UnsafeMutableRawPointer
    
    init?(pixelBuffer: CVPixelBuffer) {
        self.pixelBuffer = pixelBuffer
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        
        guard let yBase = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0),
              let cbCrBase = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1) else {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
            return nil
        }
        
        yPlane = yBase
        cbCrPlane = cbCrBase
        
        size = Size(width: CVPixelBufferGetWidth(pixelBuffer),
                    height: CVPixelBufferGetHeight(pixelBuffer))
    }
    
    func color(x: Int, y: Int) -> simd_float4 {
        let yRowStride = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
        let uvRowStride = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1)
        
        // Indices for the Y, Cb, Cr
        let yIndex = y * yRowStride + x
        let uvIndex = (y / 2) * uvRowStride + (x / 2) * 2
        
        let yValue = yPlane.advanced(by: yIndex)
            .assumingMemoryBound(to: UInt8.self).pointee
        let cbValue = cbCrPlane.advanced(by: uvIndex)
            .assumingMemoryBound(to: UInt8.self).pointee
        let crValue = cbCrPlane.advanced(by: uvIndex + 1)
            .assumingMemoryBound(to: UInt8.self).pointee
        
        // YCbCr -> RGB (BT.601-ish)
        let Y  = Float(yValue) - 16.0
        let Cb = Float(cbValue) - 128.0
        let Cr = Float(crValue) - 128.0
        
        let r = 1.164 * Y + 1.596 * Cr
        let g = 1.164 * Y - 0.392 * Cb - 0.813 * Cr
        let b = 1.164 * Y + 2.017 * Cb
        
        // clamp [0..255], normalize to [0..1]
        let rf = max(0, min(255, r)) / 255.0
        let gf = max(0, min(255, g)) / 255.0
        let bf = max(0, min(255, b)) / 255.0
        
        return simd_float4(rf, gf, bf, 1.0)
    }
    
    deinit {
        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
    }
}
