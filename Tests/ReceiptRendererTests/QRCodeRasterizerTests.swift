// テスト: QRCodeRasterizer のビットマップをPBMとして出力し、
// CIFilter参照QRと行列レベルで比較する


import Testing
import Foundation
@testable import ReceiptRenderer

#if canImport(CoreGraphics) && canImport(CoreImage) && canImport(Vision)
import CoreImage
import CoreGraphics
import Vision

@Suite("QRCodeRasterizer Tests")
struct QRCodeRasterizerTests {

    @Test("QRCodeRasterizer出力がVisionで読み取れる")
    func qrCodeReadableByVision() throws {
        // QRコード生成
        let testData = Data("Hello".utf8)
        guard let image = QRCodeRasterizer.rasterize(data: testData, ecLevel: 0, moduleSize: 10) else {
            Issue.record("QRCodeRasterizer.rasterize returned nil")
            return
        }
        
        // ビットマップをCGImageに変換
        let pixelWidth = image.widthBytes * 8
        let height = image.height
        var rgbaData = [UInt8](repeating: 255, count: pixelWidth * height * 4)
        
        for y in 0..<height {
            for x in 0..<pixelWidth {
                let byteIdx = y * image.widthBytes + x / 8
                let bitIdx = 7 - (x % 8)
                let isBlack = (image.data[byteIdx] >> bitIdx) & 1 == 1
                let offset = (y * pixelWidth + x) * 4
                let val: UInt8 = isBlack ? 0 : 255
                rgbaData[offset] = val      // R
                rgbaData[offset + 1] = val  // G
                rgbaData[offset + 2] = val  // B
                rgbaData[offset + 3] = 255  // A
            }
        }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: &rgbaData,
            width: pixelWidth, height: height,
            bitsPerComponent: 8, bytesPerRow: pixelWidth * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            Issue.record("CGContext creation failed")
            return
        }
        
        guard let cgImage = ctx.makeImage() else {
            Issue.record("makeImage failed")
            return
        }
        
        // Visionで読み取り
        let ciImage = CIImage(cgImage: cgImage)
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        try handler.perform([request])
        let results = request.results ?? []
        
        #expect(results.count == 1, "QRコードが1つ検出されるべき")
        if let first = results.first {
            #expect(first.payloadStringValue == "Hello", "QRコードの内容が'Hello'であるべき")
        }
    }
    
    @Test("QRCodeRasterizer出力行列とCIFilter参照の比較")
    func qrCodeMatrixComparison() throws {
        let testData = Data("Hello".utf8)
        
        // 独自QR生成（moduleSize=1 で行列そのまま取得）
        guard let image = QRCodeRasterizer.rasterize(data: testData, ecLevel: 0, moduleSize: 1) else {
            Issue.record("QRCodeRasterizer.rasterize returned nil")
            return
        }
        
        // ビットマップから行列を復元
        let pixelWidth = image.widthBytes * 8
        var ourFull: [[Bool]] = []
        for y in 0..<image.height {
            var row: [Bool] = []
            for x in 0..<pixelWidth {
                let byteIdx = y * image.widthBytes + x / 8
                let bitIdx = 7 - (x % 8)
                row.append((image.data[byteIdx] >> bitIdx) & 1 == 1)
            }
            ourFull.append(row)
        }
        
        // quiet zoneを除去して純粋なQR行列を取得
        var mnX = pixelWidth, mxX = 0, mnY = image.height, mxY = 0
        for y in 0..<image.height { for x in 0..<pixelWidth {
            if ourFull[y][x] { mnX = min(mnX, x); mxX = max(mxX, x); mnY = min(mnY, y); mxY = max(mxY, y) }
        }}
        var ourQR: [[Bool]] = []
        for y in mnY...mxY {
            var row: [Bool] = []
            for x in mnX...mxX { row.append(ourFull[y][x]) }
            ourQR.append(row)
        }
        
        // CIFilter参照QR生成
        let filter = CIFilter(name: "CIQRCodeGenerator")!
        filter.setValue(testData, forKey: "inputMessage")
        filter.setValue("L", forKey: "inputCorrectionLevel")
        let ciImage = filter.outputImage!
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            Issue.record("CIFilter failed"); return
        }
        
        guard let dp = cgImage.dataProvider, let pd = dp.data else {
            Issue.record("dataProvider failed"); return
        }
        let raw = pd as Data
        let bpp = cgImage.bitsPerPixel / 8
        let bpr = cgImage.bytesPerRow
        let w = cgImage.width, h = cgImage.height
        
        var refFull: [[Bool]] = []
        for y in 0..<h {
            var row: [Bool] = []
            for x in 0..<w { row.append(raw[y * bpr + x * bpp] < 128) }
            refFull.append(row)
        }
        
        // quiet zone除去
        var rmnX = w, rmxX = 0, rmnY = h, rmxY = 0
        for y in 0..<h { for x in 0..<w {
            if refFull[y][x] { rmnX = min(rmnX, x); rmxX = max(rmxX, x); rmnY = min(rmnY, y); rmxY = max(rmxY, y) }
        }}
        var refQR: [[Bool]] = []
        for y in rmnY...rmxY {
            var row: [Bool] = []
            for x in rmnX...rmxX { row.append(refFull[y][x]) }
            refQR.append(row)
        }
        
        // 比較（直接 & 上下反転）
        guard ourQR.count == refQR.count, ourQR[0].count == refQR[0].count else {
            Issue.record("Size mismatch: our=\(ourQR.count)x\(ourQR[0].count), ref=\(refQR.count)x\(refQR[0].count)")
            return
        }
        
        var directDiffs = 0
        var flippedDiffs = 0
        let refFlipped = Array(refQR.reversed())
        
        for r in 0..<ourQR.count { for c in 0..<ourQR[r].count {
            if ourQR[r][c] != refQR[r][c] { directDiffs += 1 }
            if ourQR[r][c] != refFlipped[r][c] { flippedDiffs += 1 }
        }}
        
        let bestDiffs = min(directDiffs, flippedDiffs)
        #expect(bestDiffs == 0, "CIFilter参照QRとの差分が0であるべき（直接:\(directDiffs), 反転:\(flippedDiffs)）")
    }
}

#endif
