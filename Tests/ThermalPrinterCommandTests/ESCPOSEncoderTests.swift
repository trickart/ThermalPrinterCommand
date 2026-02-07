import Testing
import Foundation
@testable import ThermalPrinterCommand

@Suite("ESCPOSEncoder Tests")
struct ESCPOSEncoderTests {
    let encoder = ESCPOSEncoder()

    @Test("Initialize command")
    func testInitializeCommand() {
        let data = encoder.encode(.initialize)
        #expect(data == Data([0x1B, 0x40]))
    }

    @Test("Control commands")
    func testControlCommands() {
        #expect(encoder.encode(.lineFeed) == Data([0x0A]))
        #expect(encoder.encode(.carriageReturn) == Data([0x0D]))
        #expect(encoder.encode(.horizontalTab) == Data([0x09]))
    }

    @Test("Feed commands")
    func testFeedCommands() {
        #expect(encoder.encode(.printAndFeed(dots: 32)) == Data([0x1B, 0x4A, 0x20]))
        #expect(encoder.encode(.printAndReverseFeed(dots: 16)) == Data([0x1B, 0x4B, 0x10]))
        #expect(encoder.encode(.feedLines(count: 3)) == Data([0x1B, 0x64, 0x03]))
    }

    @Test("Text data")
    func testTextData() {
        let text = "Hello"
        let textData = Data(text.utf8)
        #expect(encoder.encode(.text(textData)) == textData)
    }

    @Test("Font selection")
    func testFontSelection() {
        #expect(encoder.encode(.selectFont(.fontA)) == Data([0x1B, 0x4D, 0x00]))
        #expect(encoder.encode(.selectFont(.fontB)) == Data([0x1B, 0x4D, 0x01]))
        #expect(encoder.encode(.selectFont(.fontC)) == Data([0x1B, 0x4D, 0x02]))
    }

    @Test("Bold on/off")
    func testBold() {
        #expect(encoder.encode(.boldOn) == Data([0x1B, 0x45, 0x01]))
        #expect(encoder.encode(.boldOff) == Data([0x1B, 0x45, 0x00]))
    }

    @Test("Underline modes")
    func testUnderline() {
        #expect(encoder.encode(.underline(.off)) == Data([0x1B, 0x2D, 0x00]))
        #expect(encoder.encode(.underline(.single)) == Data([0x1B, 0x2D, 0x01]))
        #expect(encoder.encode(.underline(.double)) == Data([0x1B, 0x2D, 0x02]))
    }

    @Test("Character size")
    func testCharacterSize() {
        // 2x width, 2x height -> (1 << 4) | 1 = 0x11
        #expect(encoder.encode(.characterSize(width: 2, height: 2)) == Data([0x1D, 0x21, 0x11]))
        // 1x width, 1x height -> (0 << 4) | 0 = 0x00
        #expect(encoder.encode(.characterSize(width: 1, height: 1)) == Data([0x1D, 0x21, 0x00]))
        // 4x width, 3x height -> (3 << 4) | 2 = 0x32
        #expect(encoder.encode(.characterSize(width: 4, height: 3)) == Data([0x1D, 0x21, 0x32]))
    }

    @Test("Reverse mode")
    func testReverseMode() {
        #expect(encoder.encode(.reverseMode(enabled: true)) == Data([0x1D, 0x42, 0x01]))
        #expect(encoder.encode(.reverseMode(enabled: false)) == Data([0x1D, 0x42, 0x00]))
    }

    @Test("Rotate 90 degrees")
    func testRotate90() {
        #expect(encoder.encode(.rotate90(enabled: true)) == Data([0x1B, 0x56, 0x01]))
        #expect(encoder.encode(.rotate90(enabled: false)) == Data([0x1B, 0x56, 0x00]))
    }

    @Test("Upside down mode")
    func testUpsideDown() {
        #expect(encoder.encode(.upsideDown(enabled: true)) == Data([0x1B, 0x7B, 0x01]))
        #expect(encoder.encode(.upsideDown(enabled: false)) == Data([0x1B, 0x7B, 0x00]))
    }

    @Test("Justification")
    func testJustification() {
        #expect(encoder.encode(.justification(.left)) == Data([0x1B, 0x61, 0x00]))
        #expect(encoder.encode(.justification(.center)) == Data([0x1B, 0x61, 0x01]))
        #expect(encoder.encode(.justification(.right)) == Data([0x1B, 0x61, 0x02]))
    }

    @Test("Left margin")
    func testLeftMargin() {
        #expect(encoder.encode(.leftMargin(dots: 32)) == Data([0x1D, 0x4C, 0x20, 0x00]))
        #expect(encoder.encode(.leftMargin(dots: 512)) == Data([0x1D, 0x4C, 0x00, 0x02]))
    }

    @Test("Print width")
    func testPrintWidth() {
        #expect(encoder.encode(.printingWidth(dots: 512)) == Data([0x1D, 0x57, 0x00, 0x02]))
    }

    @Test("Line spacing")
    func testLineSpacing() {
        #expect(encoder.encode(.defaultLineSpacing) == Data([0x1B, 0x32]))
        #expect(encoder.encode(.lineSpacing(dots: 48)) == Data([0x1B, 0x33, 0x30]))
    }

    @Test("Paper cut")
    func testPaperCut() {
        #expect(encoder.encode(.cut(.full)) == Data([0x1D, 0x56, 0x00]))
        #expect(encoder.encode(.cut(.partial)) == Data([0x1D, 0x56, 0x01]))
    }

    @Test("Paper cut with feed")
    func testPaperCutWithFeed() {
        #expect(encoder.encode(.cutWithFeed(mode: .partialWithFeed, feed: 16)) == Data([0x1D, 0x56, 0x42, 0x10]))
    }

    @Test("Cash drawer")
    func testCashDrawer() {
        #expect(encoder.encode(.openCashDrawer(pin: 0, onTime: 25, offTime: 120)) == Data([0x1B, 0x70, 0x00, 0x19, 0x78]))
    }

    @Test("Barcode settings")
    func testBarcodeSettings() {
        #expect(encoder.encode(.barcodeHeight(dots: 80)) == Data([0x1D, 0x68, 0x50]))
        #expect(encoder.encode(.barcodeWidth(multiplier: 2)) == Data([0x1D, 0x77, 0x02]))
        #expect(encoder.encode(.barcodeHRIPosition(.below)) == Data([0x1D, 0x48, 0x02]))
        #expect(encoder.encode(.barcodeHRIFont(.fontA)) == Data([0x1D, 0x66, 0x00]))
    }

    @Test("Barcode encoding")
    func testBarcodeEncoding() {
        let barcodeData = Data("4912345678904".utf8)
        let encoded = encoder.encode(.barcode(type: .ean13, data: barcodeData))
        // GS k 67 13 "4912345678904"
        var expected = Data([0x1D, 0x6B, 67, 13])
        expected.append(barcodeData)
        #expect(encoded == expected)
    }

    @Test("Code128 barcode")
    func testCode128Barcode() {
        let barcodeData = Data("{B12345678".utf8)
        let encoded = encoder.encode(.barcode(type: .code128, data: barcodeData))
        var expected = Data([0x1D, 0x6B, 73, 10])
        expected.append(barcodeData)
        #expect(encoded == expected)
    }

    @Test("QR code size")
    func testQRCodeSize() {
        let encoded = encoder.encode(.qrCodeSize(moduleSize: 8))
        #expect(encoded == Data([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, 0x08]))
    }

    @Test("QR code error correction")
    func testQRCodeErrorCorrection() {
        #expect(encoder.encode(.qrCodeErrorCorrection(level: .l)) == Data([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, 0x30]))
        #expect(encoder.encode(.qrCodeErrorCorrection(level: .m)) == Data([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, 0x31]))
        #expect(encoder.encode(.qrCodeErrorCorrection(level: .q)) == Data([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, 0x32]))
        #expect(encoder.encode(.qrCodeErrorCorrection(level: .h)) == Data([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, 0x33]))
    }

    @Test("QR code print")
    func testQRCodePrint() {
        #expect(encoder.encode(.qrCodePrint) == Data([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30]))
    }

    @Test("QR code store")
    func testQRCodeStore() {
        let qrData = Data("https://example.com".utf8)
        let encoded = encoder.encode(.qrCodeStore(data: qrData))
        // GS ( k pL pH cn fn m d1...dk
        // length = 3 + 19 = 22 = 0x16
        var expected = Data([0x1D, 0x28, 0x6B, 0x16, 0x00, 0x31, 0x50, 0x30])
        expected.append(qrData)
        #expect(encoded == expected)
    }

    @Test("Raster image")
    func testRasterImage() {
        let imageData = Data([0xFF, 0x00, 0x00, 0xFF])
        let encoded = encoder.encode(.rasterImage(mode: .normal, width: 2, height: 2, data: imageData))
        var expected = Data([0x1D, 0x76, 0x30, 0x00, 0x02, 0x00, 0x02, 0x00])
        expected.append(imageData)
        #expect(encoded == expected)
    }

    @Test("Realtime status request")
    func testRealtimeStatusRequest() {
        #expect(encoder.encode(.realtimeStatusRequest(type: 1)) == Data([0x10, 0x04, 0x01]))
    }

    @Test("Kanji code system selection")
    func testKanjiCodeSystem() {
        // FS C n (0x1C 0x43 n)
        #expect(encoder.encode(.selectKanjiCodeSystem(.jis)) == Data([0x1C, 0x43, 0x00]))
        #expect(encoder.encode(.selectKanjiCodeSystem(.shiftJIS)) == Data([0x1C, 0x43, 0x01]))
        #expect(encoder.encode(.selectKanjiCodeSystem(.shiftJIS2004)) == Data([0x1C, 0x43, 0x02]))
    }

    @Test("Multiple commands")
    func testMultipleCommands() {
        let commands: [ESCPOSCommand] = [
            .initialize,
            .justification(.center),
            .boldOn,
            .lineFeed
        ]
        let encoded = encoder.encode(commands)
        var expected = Data()
        expected.append(contentsOf: [0x1B, 0x40])        // Initialize
        expected.append(contentsOf: [0x1B, 0x61, 0x01])  // Center
        expected.append(contentsOf: [0x1B, 0x45, 0x01])  // Bold on
        expected.append(0x0A)                            // LF
        #expect(encoded == expected)
    }

    @Test("Command extension encode method")
    func testCommandExtensionEncode() {
        let command = ESCPOSCommand.initialize
        #expect(command.encode() == Data([0x1B, 0x40]))
    }

    @Test("Array extension encode method")
    func testArrayExtensionEncode() {
        let commands: [ESCPOSCommand] = [.lineFeed, .lineFeed]
        #expect(commands.encode() == Data([0x0A, 0x0A]))
    }

    @Test("Unknown and raw data passthrough")
    func testPassthroughData() {
        let unknownData = Data([0xFF, 0xFE, 0xFD])
        #expect(encoder.encode(.unknown(unknownData)) == unknownData)
        #expect(encoder.encode(.rawData(unknownData)) == unknownData)
    }
}

// MARK: - Encoder Convenience Builders Tests

@Suite("ESCPOSEncoder Builders Tests")
struct ESCPOSEncoderBuildersTests {

    @Test("Text helper")
    func testTextHelper() {
        let command = ESCPOSEncoder.text("Hello")
        #expect(command != nil)
        if case .text(let data) = command {
            #expect(String(data: data, encoding: .utf8) == "Hello")
        }
    }

    @Test("Print QR code helper")
    func testPrintQRCode() {
        let commands = ESCPOSEncoder.printQRCode("https://example.com", moduleSize: 6, errorCorrection: .h)
        #expect(commands.count == 5)
        #expect(commands[0] == .qrCodeModel(model: 2))
        #expect(commands[1] == .qrCodeSize(moduleSize: 6))
        #expect(commands[2] == .qrCodeErrorCorrection(level: .h))
        if case .qrCodeStore(let data) = commands[3] {
            #expect(String(data: data, encoding: .utf8) == "https://example.com")
        }
        #expect(commands[4] == .qrCodePrint)
    }

    @Test("Print barcode helper")
    func testPrintBarcode() {
        let commands = ESCPOSEncoder.printBarcode("4912345678904", type: .ean13, height: 100, width: 3, hriPosition: .both)
        #expect(commands.count == 4)
        #expect(commands[0] == .barcodeHeight(dots: 100))
        #expect(commands[1] == .barcodeWidth(multiplier: 3))
        #expect(commands[2] == .barcodeHRIPosition(.both))
        if case .barcode(let type, let data) = commands[3] {
            #expect(type == .ean13)
            #expect(String(data: data, encoding: .utf8) == "4912345678904")
        }
    }
}

// MARK: - Roundtrip Tests

@Suite("ESCPOSEncoder/Decoder Roundtrip Tests")
struct ESCPOSRoundtripTests {
    let encoder = ESCPOSEncoder()
    var decoder = ESCPOSDecoder()

    @Test("Control commands roundtrip")
    mutating func testControlCommandsRoundtrip() {
        let commands: [ESCPOSCommand] = [
            .initialize,
            .lineFeed,
            .carriageReturn,
            .horizontalTab
        ]
        for command in commands {
            let encoded = encoder.encode(command)
            let decoded = decoder.decode(encoded)
            #expect(decoded == [command])
        }
    }

    @Test("Format commands roundtrip")
    mutating func testFormatCommandsRoundtrip() {
        let commands: [ESCPOSCommand] = [
            .boldOn,
            .boldOff,
            .underline(.single),
            .underline(.double),
            .justification(.center),
            .justification(.right),
            .selectFont(.fontB),
            .characterSize(width: 2, height: 2),
            .reverseMode(enabled: true),
            .rotate90(enabled: true),
            .upsideDown(enabled: true)
        ]
        for command in commands {
            let encoded = encoder.encode(command)
            let decoded = decoder.decode(encoded)
            #expect(decoded == [command])
        }
    }

    @Test("Cut commands roundtrip")
    mutating func testCutCommandsRoundtrip() {
        let commands: [ESCPOSCommand] = [
            .cut(.full),
            .cut(.partial),
            .cutWithFeed(mode: .partialWithFeed, feed: 16)
        ]
        for command in commands {
            let encoded = encoder.encode(command)
            let decoded = decoder.decode(encoded)
            #expect(decoded == [command])
        }
    }

    @Test("Margin commands roundtrip")
    mutating func testMarginCommandsRoundtrip() {
        let commands: [ESCPOSCommand] = [
            .leftMargin(dots: 32),
            .printingWidth(dots: 512),
            .lineSpacing(dots: 48),
            .defaultLineSpacing
        ]
        for command in commands {
            let encoded = encoder.encode(command)
            let decoded = decoder.decode(encoded)
            #expect(decoded == [command])
        }
    }

    @Test("Barcode settings roundtrip")
    mutating func testBarcodeSettingsRoundtrip() {
        let commands: [ESCPOSCommand] = [
            .barcodeHeight(dots: 80),
            .barcodeWidth(multiplier: 2),
            .barcodeHRIPosition(.below),
            .barcodeHRIFont(.fontA)
        ]
        for command in commands {
            let encoded = encoder.encode(command)
            let decoded = decoder.decode(encoded)
            #expect(decoded == [command])
        }
    }

    @Test("QR code commands roundtrip")
    mutating func testQRCodeCommandsRoundtrip() {
        let commands: [ESCPOSCommand] = [
            .qrCodeSize(moduleSize: 8),
            .qrCodeErrorCorrection(level: .l),
            .qrCodeStore(data: Data("https://example.com".utf8)),
            .qrCodePrint
        ]
        for command in commands {
            let encoded = encoder.encode(command)
            let decoded = decoder.decode(encoded)
            #expect(decoded == [command])
        }
    }

    @Test("Cash drawer roundtrip")
    mutating func testCashDrawerRoundtrip() {
        let command = ESCPOSCommand.openCashDrawer(pin: 0, onTime: 25, offTime: 120)
        let encoded = encoder.encode(command)
        let decoded = decoder.decode(encoded)
        #expect(decoded == [command])
    }

    @Test("Realtime status roundtrip")
    mutating func testRealtimeStatusRoundtrip() {
        let command = ESCPOSCommand.realtimeStatusRequest(type: 1)
        let encoded = encoder.encode(command)
        let decoded = decoder.decode(encoded)
        #expect(decoded == [command])
    }

    @Test("Process ID response roundtrip")
    mutating func testProcessIdResponseRoundtrip() {
        let command = ESCPOSCommand.requestProcessIdResponse(d1: 0x30, d2: 0x30, d3: 0x30, d4: 0x31)
        let encoded = encoder.encode(command)
        #expect(encoded == Data([0x1D, 0x28, 0x48, 0x06, 0x00, 0x30, 0x30, 0x30, 0x30, 0x30, 0x31]))
        let decoded = decoder.decode(encoded)
        #expect(decoded == [command])
    }

    @Test("Graphics commands roundtrip")
    mutating func testGraphicsCommandsRoundtrip() {
        // graphicsPrint roundtrip
        let printCommand = ESCPOSCommand.graphicsPrint
        let printEncoded = encoder.encode(printCommand)
        let printDecoded = decoder.decode(printEncoded)
        #expect(printDecoded == [printCommand])

        // graphicsStore roundtrip
        let imageData = Data([0xFF, 0x00, 0xFF, 0x00])
        let storeCommand = ESCPOSCommand.graphicsStore(
            tone: .monochrome,
            scaleX: 1,
            scaleY: 1,
            color: .color1,
            width: 16,
            height: 2,
            data: imageData
        )
        let storeEncoded = encoder.encode(storeCommand)
        let storeDecoded = decoder.decode(storeEncoded)
        #expect(storeDecoded == [storeCommand])
    }

    @Test("Kanji code system roundtrip")
    mutating func testKanjiCodeSystemRoundtrip() {
        let commands: [ESCPOSCommand] = [
            .selectKanjiCodeSystem(.jis),
            .selectKanjiCodeSystem(.shiftJIS),
            .selectKanjiCodeSystem(.shiftJIS2004)
        ]
        for command in commands {
            let encoded = encoder.encode(command)
            let decoded = decoder.decode(encoded)
            #expect(decoded == [command])
        }
    }
}

// MARK: - Graphics Tests

@Suite("ESCPOSEncoder Graphics Tests")
struct ESCPOSEncoderGraphicsTests {
    let encoder = ESCPOSEncoder()

    @Test("Graphics store encoding")
    func testGraphicsStoreEncoding() {
        let imageData = Data([0xFF, 0x00])
        let command = ESCPOSCommand.graphicsStore(
            tone: .monochrome,
            scaleX: 1,
            scaleY: 2,
            color: .color1,
            width: 8,
            height: 2,
            data: imageData
        )
        let encoded = encoder.encode(command)

        // GS ( L pL pH m fn a bx by c xL xH yL yH d1...dk
        // パラメータ長 = 10 + 2 = 12 = 0x0C
        var expected = Data([0x1D, 0x28, 0x4C])  // GS ( L
        expected.append(0x0C)  // pL
        expected.append(0x00)  // pH
        expected.append(0x30)  // m = 48
        expected.append(0x70)  // fn = 112
        expected.append(0x30)  // a = 48 (monochrome)
        expected.append(0x01)  // bx = 1
        expected.append(0x02)  // by = 2
        expected.append(0x31)  // c = 49 (color1)
        expected.append(0x08)  // xL = 8
        expected.append(0x00)  // xH = 0
        expected.append(0x02)  // yL = 2
        expected.append(0x00)  // yH = 0
        expected.append(contentsOf: imageData)

        #expect(encoded == expected)
    }

    @Test("Graphics store with multi-tone")
    func testGraphicsStoreMultiTone() {
        let imageData = Data([0xAA, 0x55])
        let command = ESCPOSCommand.graphicsStore(
            tone: .multiTone,
            scaleX: 2,
            scaleY: 2,
            color: .color2,
            width: 8,
            height: 2,
            data: imageData
        )
        let encoded = encoder.encode(command)

        #expect(encoded[7] == 0x34)  // a = 52 (multiTone)
        #expect(encoded[8] == 0x02)  // bx = 2
        #expect(encoded[9] == 0x02)  // by = 2
        #expect(encoded[10] == 0x32) // c = 50 (color2)
    }

    @Test("Graphics print encoding")
    func testGraphicsPrintEncoding() {
        let command = ESCPOSCommand.graphicsPrint
        let encoded = encoder.encode(command)

        // GS ( L pL pH m fn
        let expected = Data([0x1D, 0x28, 0x4C, 0x02, 0x00, 0x30, 0x32])
        #expect(encoded == expected)
    }

    @Test("NV graphics print encoding")
    func testNVGraphicsPrintEncoding() {
        let command = ESCPOSCommand.nvGraphicsPrint(keyCode1: 0x41, keyCode2: 0x42, scaleX: 1, scaleY: 2)
        let encoded = encoder.encode(command)

        // GS ( L pL pH m fn kc1 kc2 x y
        let expected = Data([0x1D, 0x28, 0x4C, 0x06, 0x00, 0x30, 0x45, 0x41, 0x42, 0x01, 0x02])
        #expect(encoded == expected)
    }

    @Test("NV graphics print round-trip")
    func testNVGraphicsPrintRoundTrip() {
        let command = ESCPOSCommand.nvGraphicsPrint(keyCode1: 0x20, keyCode2: 0x7E, scaleX: 2, scaleY: 3)
        let encoded = encoder.encode(command)
        var decoder = ESCPOSDecoder()
        let decoded = decoder.decode(encoded)

        #expect(decoded.count == 1)
        #expect(decoded[0] == command)
    }

    @Test("Print graphics helper")
    func testPrintGraphicsHelper() {
        let imageData = Data([0xFF, 0x00, 0xFF, 0x00])
        let commands = ESCPOSEncoder.printGraphics(
            data: imageData,
            width: 16,
            height: 2,
            tone: .monochrome,
            scaleX: 2,
            scaleY: 1,
            color: .color1
        )

        #expect(commands.count == 2)
        if case .graphicsStore(let tone, let scaleX, let scaleY, let color, let width, let height, let data) = commands[0] {
            #expect(tone == .monochrome)
            #expect(scaleX == 2)
            #expect(scaleY == 1)
            #expect(color == .color1)
            #expect(width == 16)
            #expect(height == 2)
            #expect(data == imageData)
        } else {
            Issue.record("Expected graphicsStore command")
        }
        #expect(commands[1] == .graphicsPrint)
    }
}

// MARK: - CGImage Raster Tests

#if canImport(CoreGraphics)
import CoreGraphics

@Suite("ESCPOSEncoder CGImage Raster Tests")
struct ESCPOSEncoderCGImageTests {

    /// テスト用の白黒画像を生成（左半分が黒、右半分が白）
    func createTestImage(width: Int, height: Int) -> CGImage? {
        let bytesPerRow = width
        var pixels = [UInt8](repeating: 255, count: width * height)

        // 左半分を黒にする
        for y in 0..<height {
            for x in 0..<(width / 2) {
                pixels[y * width + x] = 0
            }
        }

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return nil
        }

        return context.makeImage()
    }

    /// テスト用のグラデーション画像を生成
    func createGradientImage(width: Int, height: Int) -> CGImage? {
        let bytesPerRow = width
        var pixels = [UInt8](repeating: 0, count: width * height)

        for y in 0..<height {
            for x in 0..<width {
                // 左から右へのグラデーション
                pixels[y * width + x] = UInt8(x * 255 / max(width - 1, 1))
            }
        }

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return nil
        }

        return context.makeImage()
    }

    @Test("Raster data from CGImage - basic")
    func testRasterDataBasic() {
        guard let image = createTestImage(width: 16, height: 4) else {
            Issue.record("Failed to create test image")
            return
        }

        guard let raster = ESCPOSEncoder.rasterData(from: image) else {
            Issue.record("Failed to convert image to raster data")
            return
        }

        // 16ピクセル幅 = 2バイト幅
        #expect(raster.widthBytes == 2)
        #expect(raster.height == 4)
        #expect(raster.widthDots == 16)

        // データサイズ = 2バイト × 4行 = 8バイト
        #expect(raster.data.count == 8)

        // 左半分（8ピクセル）が黒 = 0xFF、右半分が白 = 0x00
        for row in 0..<4 {
            #expect(raster.data[row * 2] == 0xFF)      // 左8ピクセル = 黒
            #expect(raster.data[row * 2 + 1] == 0x00)  // 右8ピクセル = 白
        }
    }

    @Test("Raster data with max width")
    func testRasterDataMaxWidth() {
        guard let image = createTestImage(width: 200, height: 100) else {
            Issue.record("Failed to create test image")
            return
        }

        guard let raster = ESCPOSEncoder.rasterData(from: image, maxWidth: 80) else {
            Issue.record("Failed to convert image to raster data")
            return
        }

        // 80ピクセル幅 = 10バイト幅
        #expect(raster.widthBytes == 10)
        // 高さは比率維持: 100 * (80/200) = 40
        #expect(raster.height == 40)
    }

    @Test("Raster data with invert colors")
    func testRasterDataInvertColors() {
        guard let image = createTestImage(width: 16, height: 2) else {
            Issue.record("Failed to create test image")
            return
        }

        guard let raster = ESCPOSEncoder.rasterData(from: image, invertColors: true) else {
            Issue.record("Failed to convert image to raster data")
            return
        }

        // 色反転: 左半分が白 = 0x00、右半分が黒 = 0xFF
        #expect(raster.data[0] == 0x00)  // 左8ピクセル = 白（反転）
        #expect(raster.data[1] == 0xFF)  // 右8ピクセル = 黒（反転）
    }

    @Test("Raster data with Floyd-Steinberg dither")
    func testRasterDataFloydSteinberg() {
        guard let image = createGradientImage(width: 32, height: 8) else {
            Issue.record("Failed to create gradient image")
            return
        }

        guard let raster = ESCPOSEncoder.rasterData(from: image, dither: .floydSteinberg) else {
            Issue.record("Failed to convert image to raster data")
            return
        }

        #expect(raster.widthBytes == 4)
        #expect(raster.height == 8)
        // ディザリングにより、グラデーションがドットパターンに変換される
        // 具体的な値は検証せず、データが生成されることを確認
        #expect(raster.data.count == 32)
    }

    @Test("Raster data with Atkinson dither")
    func testRasterDataAtkinson() {
        guard let image = createGradientImage(width: 32, height: 8) else {
            Issue.record("Failed to create gradient image")
            return
        }

        guard let raster = ESCPOSEncoder.rasterData(from: image, dither: .atkinson) else {
            Issue.record("Failed to convert image to raster data")
            return
        }

        #expect(raster.widthBytes == 4)
        #expect(raster.height == 8)
        #expect(raster.data.count == 32)
    }

    @Test("Raster image command from CGImage")
    func testRasterImageCommand() {
        guard let image = createTestImage(width: 16, height: 4) else {
            Issue.record("Failed to create test image")
            return
        }

        guard let command = ESCPOSEncoder.rasterImage(from: image, mode: .doubleWidth) else {
            Issue.record("Failed to create raster image command")
            return
        }

        if case .rasterImage(let mode, let width, let height, let data) = command {
            #expect(mode == .doubleWidth)
            #expect(width == 2)   // 16ピクセル = 2バイト
            #expect(height == 4)
            #expect(data.count == 8)
        } else {
            Issue.record("Expected rasterImage command")
        }
    }

    @Test("Raster data width padding")
    func testRasterDataWidthPadding() {
        // 幅が8の倍数でない場合のテスト（10ピクセル幅）
        guard let context = CGContext(
            data: nil,
            width: 10,
            height: 2,
            bitsPerComponent: 8,
            bytesPerRow: 10,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            Issue.record("Failed to create context")
            return
        }

        // 全体を黒で塗りつぶし
        context.setFillColor(gray: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 10, height: 2))

        guard let image = context.makeImage() else {
            Issue.record("Failed to create image")
            return
        }

        guard let raster = ESCPOSEncoder.rasterData(from: image) else {
            Issue.record("Failed to convert image to raster data")
            return
        }

        // 10ピクセル → 2バイト（16ピクセル分にパディング）
        #expect(raster.widthBytes == 2)
        #expect(raster.widthDots == 16)

        // 最初の10ビットが1、残り6ビットが0
        // 0b11111111 0b11000000 = 0xFF 0xC0
        #expect(raster.data[0] == 0xFF)
        #expect(raster.data[1] == 0xC0)
    }

    @Test("Threshold affects output")
    func testThresholdAffectsOutput() {
        guard let image = createGradientImage(width: 16, height: 1) else {
            Issue.record("Failed to create gradient image")
            return
        }

        // 低い閾値（より多くのピクセルが白になる）
        guard let rasterLow = ESCPOSEncoder.rasterData(from: image, threshold: 64) else {
            Issue.record("Failed with low threshold")
            return
        }

        // 高い閾値（より多くのピクセルが黒になる）
        guard let rasterHigh = ESCPOSEncoder.rasterData(from: image, threshold: 192) else {
            Issue.record("Failed with high threshold")
            return
        }

        // 高い閾値のほうが多くのビットが立つ（黒ピクセルが多い）
        let bitsLow = rasterLow.data.reduce(0) { $0 + $1.nonzeroBitCount }
        let bitsHigh = rasterHigh.data.reduce(0) { $0 + $1.nonzeroBitCount }
        #expect(bitsHigh > bitsLow)
    }

    // MARK: - GS ( L Graphics from CGImage Tests

    @Test("Graphics data from CGImage")
    func testGraphicsDataFromCGImage() {
        guard let image = createTestImage(width: 16, height: 4) else {
            Issue.record("Failed to create test image")
            return
        }

        guard let graphics = ESCPOSEncoder.graphicsData(from: image) else {
            Issue.record("Failed to convert image to graphics data")
            return
        }

        // graphicsDataはrasterDataと同じ結果を返す
        #expect(graphics.widthBytes == 2)
        #expect(graphics.widthDots == 16)
        #expect(graphics.height == 4)
        #expect(graphics.data.count == 8)
    }

    @Test("Graphics store command from CGImage")
    func testGraphicsStoreFromCGImage() {
        guard let image = createTestImage(width: 16, height: 4) else {
            Issue.record("Failed to create test image")
            return
        }

        guard let command = ESCPOSEncoder.graphicsStore(
            from: image,
            tone: .monochrome,
            scaleX: 2,
            scaleY: 1,
            color: .color1
        ) else {
            Issue.record("Failed to create graphics store command")
            return
        }

        if case .graphicsStore(let tone, let scaleX, let scaleY, let color, let width, let height, let data) = command {
            #expect(tone == .monochrome)
            #expect(scaleX == 2)
            #expect(scaleY == 1)
            #expect(color == .color1)
            #expect(width == 16)  // widthDotsを使用
            #expect(height == 4)
            #expect(data.count == 8)
        } else {
            Issue.record("Expected graphicsStore command")
        }
    }

    @Test("Graphics store with dithering")
    func testGraphicsStoreWithDithering() {
        guard let image = createGradientImage(width: 32, height: 8) else {
            Issue.record("Failed to create gradient image")
            return
        }

        guard let command = ESCPOSEncoder.graphicsStore(
            from: image,
            dither: .floydSteinberg
        ) else {
            Issue.record("Failed to create graphics store command with dithering")
            return
        }

        if case .graphicsStore(_, _, _, _, let width, let height, let data) = command {
            #expect(width == 32)
            #expect(height == 8)
            #expect(data.count == 32)  // 4バイト × 8行
        } else {
            Issue.record("Expected graphicsStore command")
        }
    }

    @Test("Print graphics from CGImage")
    func testPrintGraphicsFromCGImage() {
        guard let image = createTestImage(width: 16, height: 4) else {
            Issue.record("Failed to create test image")
            return
        }

        let commands = ESCPOSEncoder.printGraphics(
            from: image,
            scaleX: 1,
            scaleY: 2,
            color: .color2,
            dither: .atkinson
        )

        #expect(commands.count == 2)

        if case .graphicsStore(let tone, let scaleX, let scaleY, let color, let width, let height, _) = commands[0] {
            #expect(tone == .monochrome)
            #expect(scaleX == 1)
            #expect(scaleY == 2)
            #expect(color == .color2)
            #expect(width == 16)
            #expect(height == 4)
        } else {
            Issue.record("Expected graphicsStore command")
        }

        #expect(commands[1] == .graphicsPrint)
    }

    @Test("Print graphics with max width")
    func testPrintGraphicsWithMaxWidth() {
        guard let image = createTestImage(width: 200, height: 100) else {
            Issue.record("Failed to create test image")
            return
        }

        let commands = ESCPOSEncoder.printGraphics(
            from: image,
            maxWidth: 80
        )

        #expect(commands.count == 2)

        if case .graphicsStore(_, _, _, _, let width, let height, _) = commands[0] {
            #expect(width == 80)  // maxWidthに制限
            #expect(height == 40)  // アスペクト比維持
        } else {
            Issue.record("Expected graphicsStore command")
        }
    }

    @Test("Print graphics returns empty for invalid image")
    func testPrintGraphicsReturnsEmptyForInvalidImage() {
        // 幅0の画像は作成できないので、このテストは実際の失敗ケースをシミュレート
        // 実際にはCGContextの作成に失敗するケースをテスト
        guard let context = CGContext(
            data: nil,
            width: 0,  // 無効な幅
            height: 10,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            // 期待通り失敗
            return
        }

        // もしcontextが作成された場合（通常はない）
        if let image = context.makeImage() {
            let commands = ESCPOSEncoder.printGraphics(from: image)
            #expect(commands.isEmpty)
        }
    }
}

#endif
