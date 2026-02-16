import Testing
import Foundation
@testable import ThermalPrinterCommand

@Suite("StarPRNTEncoder Tests")
struct StarPRNTEncoderTests {
    let encoder = StarPRNTEncoder()

    // MARK: - 制御コマンド

    @Test("Initialize command")
    func testInitialize() {
        let data = encoder.encode(.initialize)
        #expect(data == Data([0x1B, 0x40]))
    }

    @Test("Line feed")
    func testLineFeed() {
        let data = encoder.encode(.lineFeed)
        #expect(data == Data([0x0A]))
    }

    @Test("Form feed")
    func testFormFeed() {
        let data = encoder.encode(.formFeed)
        #expect(data == Data([0x0C]))
    }

    @Test("Horizontal tab")
    func testHorizontalTab() {
        let data = encoder.encode(.horizontalTab)
        #expect(data == Data([0x09]))
    }

    // MARK: - フォントスタイル・キャラクタセット

    @Test("Select font")
    func testSelectFont() {
        #expect(encoder.encode(.selectFont(.fontA)) == Data([0x1B, 0x1E, 0x46, 0x00]))
        #expect(encoder.encode(.selectFont(.fontB)) == Data([0x1B, 0x1E, 0x46, 0x01]))
        #expect(encoder.encode(.selectFont(.fontC)) == Data([0x1B, 0x1E, 0x46, 0x02]))
    }

    @Test("Select code page")
    func testSelectCodePage() {
        let data = encoder.encode(.selectCodePage(5))
        #expect(data == Data([0x1B, 0x1D, 0x74, 0x05]))
    }

    @Test("Select international character set")
    func testSelectInternationalCharacter() {
        let data = encoder.encode(.selectInternationalCharacter(8))
        #expect(data == Data([0x1B, 0x52, 0x08]))
    }

    @Test("Slash zero")
    func testSlashZero() {
        #expect(encoder.encode(.slashZero(enabled: true)) == Data([0x1B, 0x2F, 0x01]))
        #expect(encoder.encode(.slashZero(enabled: false)) == Data([0x1B, 0x2F, 0x00]))
    }

    @Test("ANK right space")
    func testAnkRightSpace() {
        let data = encoder.encode(.ankRightSpace(dots: 3))
        #expect(data == Data([0x1B, 0x20, 0x03]))
    }

    @Test("Download character enabled")
    func testDownloadCharacterEnabled() {
        #expect(encoder.encode(.downloadCharacterEnabled(true)) == Data([0x1B, 0x25, 0x01]))
        #expect(encoder.encode(.downloadCharacterEnabled(false)) == Data([0x1B, 0x25, 0x00]))
    }

    // MARK: - 漢字

    @Test("JIS Kanji mode")
    func testJisKanjiMode() {
        #expect(encoder.encode(.jisKanjiMode) == Data([0x1B, 0x70]))
        #expect(encoder.encode(.jisKanjiModeCancel) == Data([0x1B, 0x71]))
    }

    @Test("Shift JIS Kanji mode")
    func testShiftJISKanjiMode() {
        #expect(encoder.encode(.shiftJISKanjiMode(enabled: true)) == Data([0x1B, 0x24, 0x01]))
        #expect(encoder.encode(.shiftJISKanjiMode(enabled: false)) == Data([0x1B, 0x24, 0x00]))
    }

    // MARK: - プリントモード

    @Test("Bold on/off")
    func testBold() {
        #expect(encoder.encode(.boldOn) == Data([0x1B, 0x45]))
        #expect(encoder.encode(.boldOff) == Data([0x1B, 0x46]))
    }

    @Test("Underline")
    func testUnderline() {
        #expect(encoder.encode(.underline(enabled: true)) == Data([0x1B, 0x2D, 0x01]))
        #expect(encoder.encode(.underline(enabled: false)) == Data([0x1B, 0x2D, 0x00]))
    }

    @Test("Upperline")
    func testUpperline() {
        #expect(encoder.encode(.upperline(enabled: true)) == Data([0x1B, 0x5F, 0x01]))
        #expect(encoder.encode(.upperline(enabled: false)) == Data([0x1B, 0x5F, 0x00]))
    }

    @Test("Reverse on/off")
    func testReverse() {
        #expect(encoder.encode(.reverseOn) == Data([0x1B, 0x34]))
        #expect(encoder.encode(.reverseOff) == Data([0x1B, 0x35]))
    }

    @Test("Upside down on/off")
    func testUpsideDown() {
        #expect(encoder.encode(.upsideDownOn) == Data([0x0F]))
        #expect(encoder.encode(.upsideDownOff) == Data([0x12]))
    }

    @Test("Expansion")
    func testExpansion() {
        let data = encoder.encode(.expansion(vertical: 2, horizontal: 3))
        #expect(data == Data([0x1B, 0x69, 0x02, 0x03]))
    }

    @Test("Horizontal expansion")
    func testHorizontalExpansion() {
        let data = encoder.encode(.horizontalExpansion(2))
        #expect(data == Data([0x1B, 0x57, 0x02]))
    }

    @Test("Vertical expansion")
    func testVerticalExpansion() {
        let data = encoder.encode(.verticalExpansion(2))
        #expect(data == Data([0x1B, 0x68, 0x02]))
    }

    @Test("Smoothing")
    func testSmoothing() {
        #expect(encoder.encode(.smoothing(enabled: true)) == Data([0x1B, 0x1D, 0x62, 0x01]))
        #expect(encoder.encode(.smoothing(enabled: false)) == Data([0x1B, 0x1D, 0x62, 0x00]))
    }

    // MARK: - 水平方向位置

    @Test("Left margin")
    func testLeftMargin() {
        let data = encoder.encode(.leftMargin(5))
        #expect(data == Data([0x1B, 0x6C, 0x05]))
    }

    @Test("Right margin")
    func testRightMargin() {
        let data = encoder.encode(.rightMargin(48))
        #expect(data == Data([0x1B, 0x51, 0x30]))
    }

    @Test("Absolute position")
    func testAbsolutePosition() {
        let data = encoder.encode(.absolutePosition(256))
        #expect(data == Data([0x1B, 0x1D, 0x41, 0x00, 0x01]))
    }

    @Test("Relative position positive")
    func testRelativePositionPositive() {
        let data = encoder.encode(.relativePosition(100))
        #expect(data == Data([0x1B, 0x1D, 0x52, 0x64, 0x00]))
    }

    @Test("Relative position negative")
    func testRelativePositionNegative() {
        let data = encoder.encode(.relativePosition(-100))
        #expect(data == Data([0x1B, 0x1D, 0x52, 0x9C, 0xFF]))
    }

    @Test("Alignment")
    func testAlignment() {
        #expect(encoder.encode(.alignment(.left)) == Data([0x1B, 0x1D, 0x61, 0x00]))
        #expect(encoder.encode(.alignment(.center)) == Data([0x1B, 0x1D, 0x61, 0x01]))
        #expect(encoder.encode(.alignment(.right)) == Data([0x1B, 0x1D, 0x61, 0x02]))
    }

    @Test("Set horizontal tab positions")
    func testSetHorizontalTab() {
        let data = encoder.encode(.setHorizontalTab([8, 16, 24]))
        #expect(data == Data([0x1B, 0x44, 0x08, 0x10, 0x18, 0x00]))
    }

    @Test("Clear horizontal tab")
    func testClearHorizontalTab() {
        let data = encoder.encode(.clearHorizontalTab)
        #expect(data == Data([0x1B, 0x44, 0x00]))
    }

    // MARK: - 行間隔

    @Test("Feed lines")
    func testFeedLines() {
        let data = encoder.encode(.feedLines(3))
        #expect(data == Data([0x1B, 0x61, 0x03]))
    }

    @Test("Line spacing mode")
    func testLineSpacingMode() {
        let data = encoder.encode(.lineSpacingMode(1))
        #expect(data == Data([0x1B, 0x7A, 0x01]))
    }

    @Test("Line spacing 3mm")
    func testLineSpacing3mm() {
        let data = encoder.encode(.lineSpacing3mm)
        #expect(data == Data([0x1B, 0x30]))
    }

    @Test("Feed quarter mm")
    func testFeedQuarterMM() {
        let data = encoder.encode(.feedQuarterMM(16))
        #expect(data == Data([0x1B, 0x4A, 0x10]))
    }

    @Test("Feed eighth mm")
    func testFeedEighthMM() {
        let data = encoder.encode(.feedEighthMM(8))
        #expect(data == Data([0x1B, 0x49, 0x08]))
    }

    // MARK: - ページ管理

    @Test("Page length")
    func testPageLength() {
        let data = encoder.encode(.pageLength(lines: 64))
        #expect(data == Data([0x1B, 0x43, 0x40]))
    }

    // MARK: - トップマージン

    @Test("Top margin")
    func testTopMargin() {
        let data = encoder.encode(.topMargin(5))
        #expect(data == Data([0x1B, 0x1E, 0x54, 0x05]))
    }

    // MARK: - カッター

    @Test("Cut modes")
    func testCut() {
        #expect(encoder.encode(.cut(.fullCut)) == Data([0x1B, 0x64, 0x00]))
        #expect(encoder.encode(.cut(.partialCut)) == Data([0x1B, 0x64, 0x01]))
        #expect(encoder.encode(.cut(.tearBar)) == Data([0x1B, 0x64, 0x02]))
    }

    // MARK: - ページモード

    @Test("Page mode on/off")
    func testPageMode() {
        #expect(encoder.encode(.pageModeOn) == Data([0x1B, 0x1D, 0x50, 0x30]))
        #expect(encoder.encode(.pageModeOff) == Data([0x1B, 0x1D, 0x50, 0x31]))
    }

    @Test("Page mode direction")
    func testPageModeDirection() {
        let data = encoder.encode(.pageModeDirection(1))
        #expect(data == Data([0x1B, 0x1D, 0x50, 0x32, 0x01]))
    }

    @Test("Page mode print area")
    func testPageModePrintArea() {
        let data = encoder.encode(.pageModePrintArea(x: 0, y: 0, dx: 384, dy: 512))
        #expect(data == Data([
            0x1B, 0x1D, 0x50, 0x33,
            0x00, 0x00,  // x=0
            0x00, 0x00,  // y=0
            0x80, 0x01,  // dx=384
            0x00, 0x02   // dy=512
        ]))
    }

    @Test("Page mode print/exit/cancel")
    func testPageModeActions() {
        #expect(encoder.encode(.pageModePrint) == Data([0x1B, 0x1D, 0x50, 0x36]))
        #expect(encoder.encode(.pageModePrintAndExit) == Data([0x1B, 0x1D, 0x50, 0x37]))
        #expect(encoder.encode(.pageModeCancel) == Data([0x1B, 0x1D, 0x50, 0x38]))
    }

    // MARK: - ビットイメージ

    @Test("Bit image normal")
    func testBitImageNormal() {
        let imageData = Data([0xFF, 0x00, 0xAA])
        let data = encoder.encode(.bitImageNormal(width: 3, data: imageData))
        #expect(data == Data([0x1B, 0x4B, 0x03, 0x00, 0xFF, 0x00, 0xAA]))
    }

    @Test("Bit image high density")
    func testBitImageHigh() {
        let imageData = Data([0xCC, 0x33])
        let data = encoder.encode(.bitImageHigh(width: 2, data: imageData))
        #expect(data == Data([0x1B, 0x4C, 0x02, 0x00, 0xCC, 0x33]))
    }

    @Test("Bit image fine")
    func testBitImageFine() {
        let imageData = Data([0xFF])
        let data = encoder.encode(.bitImageFine(width: 1, data: imageData))
        #expect(data == Data([0x1B, 0x6B, 0x01, 0x00, 0xFF]))
    }

    @Test("Raster graphics")
    func testRasterGraphics() {
        let imageData = Data([0xFF, 0x00, 0x00, 0xFF])
        let data = encoder.encode(.rasterGraphics(mode: 0, width: 2, height: 2, data: imageData))
        #expect(data == Data([0x1B, 0x1D, 0x53, 0x00, 0x02, 0x00, 0x02, 0x00, 0xFF, 0x00, 0x00, 0xFF]))
    }

    // MARK: - バーコード

    @Test("Barcode")
    func testBarcode() {
        let barcodeData = Data("ABC123".utf8)
        let data = encoder.encode(.barcode(type: .code128, mode: 2, width: 2, height: 64, data: barcodeData))
        var expected = Data([0x1B, 0x62, 0x04, 0x02, 0x02, 0x40])
        expected.append(barcodeData)
        expected.append(0x1E)  // RS terminator
        #expect(data == expected)
    }

    // MARK: - QRコード

    @Test("QR code model")
    func testQRCodeModel() {
        let data = encoder.encode(.qrCodeModel(2))
        #expect(data == Data([0x1B, 0x1D, 0x79, 0x53, 0x00, 0x02]))
    }

    @Test("QR code error correction")
    func testQRCodeErrorCorrection() {
        let data = encoder.encode(.qrCodeErrorCorrection(1))
        #expect(data == Data([0x1B, 0x1D, 0x79, 0x53, 0x01, 0x01]))
    }

    @Test("QR code cell size")
    func testQRCodeCellSize() {
        let data = encoder.encode(.qrCodeCellSize(4))
        #expect(data == Data([0x1B, 0x1D, 0x79, 0x53, 0x02, 0x04]))
    }

    @Test("QR code store")
    func testQRCodeStore() {
        let text = "https://example.com"
        let textData = Data(text.utf8)
        let data = encoder.encode(.qrCodeStore(data: textData))
        var expected = Data([0x1B, 0x1D, 0x79, 0x44, 0x01, 0x00])
        expected.append(UInt8(textData.count & 0xFF))
        expected.append(UInt8((textData.count >> 8) & 0xFF))
        expected.append(textData)
        #expect(data == expected)
    }

    @Test("QR code print")
    func testQRCodePrint() {
        let data = encoder.encode(.qrCodePrint)
        #expect(data == Data([0x1B, 0x1D, 0x79, 0x50]))
    }

    // MARK: - PDF417

    @Test("PDF417 size")
    func testPDF417Size() {
        let data = encoder.encode(.pdf417Size(0, p1: 3, p2: 5))
        #expect(data == Data([0x1B, 0x1D, 0x78, 0x53, 0x00, 0x00, 0x03, 0x05]))
    }

    @Test("PDF417 ECC")
    func testPDF417ECC() {
        let data = encoder.encode(.pdf417ECC(2))
        #expect(data == Data([0x1B, 0x1D, 0x78, 0x53, 0x01, 0x02]))
    }

    @Test("PDF417 module width")
    func testPDF417ModuleWidth() {
        let data = encoder.encode(.pdf417ModuleWidth(3))
        #expect(data == Data([0x1B, 0x1D, 0x78, 0x53, 0x02, 0x03]))
    }

    @Test("PDF417 aspect ratio")
    func testPDF417AspectRatio() {
        let data = encoder.encode(.pdf417AspectRatio(2))
        #expect(data == Data([0x1B, 0x1D, 0x78, 0x53, 0x03, 0x02]))
    }

    @Test("PDF417 store")
    func testPDF417Store() {
        let text = "HELLO"
        let textData = Data(text.utf8)
        let data = encoder.encode(.pdf417Store(data: textData))
        var expected = Data([0x1B, 0x1D, 0x78, 0x44])
        expected.append(UInt8(textData.count & 0xFF))
        expected.append(UInt8((textData.count >> 8) & 0xFF))
        expected.append(textData)
        #expect(data == expected)
    }

    @Test("PDF417 print")
    func testPDF417Print() {
        let data = encoder.encode(.pdf417Print)
        #expect(data == Data([0x1B, 0x1D, 0x78, 0x50]))
    }

    // MARK: - リセット・ステータス

    @Test("Realtime reset")
    func testRealtimeReset() {
        let data = encoder.encode(.realtimeReset)
        #expect(data == Data([0x1B, 0x06, 0x18]))
    }

    @Test("Printer reset")
    func testPrinterReset() {
        let data = encoder.encode(.printerReset)
        #expect(data == Data([0x1B, 0x3F, 0x0A, 0x00]))
    }

    @Test("Auto status setting")
    func testAutoStatusSetting() {
        let data = encoder.encode(.autoStatusSetting(3))
        #expect(data == Data([0x1B, 0x1E, 0x61, 0x03]))
    }

    @Test("Realtime status")
    func testRealtimeStatus() {
        let data = encoder.encode(.realtimeStatus)
        #expect(data == Data([0x1B, 0x06, 0x01]))
    }

    // MARK: - 外部機器

    @Test("Buzzer")
    func testBuzzer() {
        let data = encoder.encode(.buzzer(n1: 3, n2: 5))
        #expect(data == Data([0x1B, 0x07, 0x03, 0x05]))
    }

    @Test("External devices")
    func testExternalDevices() {
        #expect(encoder.encode(.externalDevice1A) == Data([0x07]))
        #expect(encoder.encode(.externalDevice1B) == Data([0x1C]))
        #expect(encoder.encode(.externalDevice2A) == Data([0x1A]))
        #expect(encoder.encode(.externalDevice2B) == Data([0x19]))
    }

    // MARK: - 印字設定

    @Test("Print area")
    func testPrintArea() {
        let data = encoder.encode(.printArea(1))
        #expect(data == Data([0x1B, 0x1E, 0x41, 0x01]))
    }

    @Test("Print density")
    func testPrintDensity() {
        let data = encoder.encode(.printDensity(2))
        #expect(data == Data([0x1B, 0x1E, 0x64, 0x02]))
    }

    @Test("Print speed")
    func testPrintSpeed() {
        let data = encoder.encode(.printSpeed(1))
        #expect(data == Data([0x1B, 0x1E, 0x72, 0x01]))
    }

    // MARK: - 2色印字

    @Test("Two color print color")
    func testTwoColorPrintColor() {
        let data = encoder.encode(.twoColorPrintColor(1))
        #expect(data == Data([0x1B, 0x1E, 0x63, 0x01]))
    }

    @Test("Two color mode")
    func testTwoColorMode() {
        #expect(encoder.encode(.twoColorMode(enabled: true)) == Data([0x1B, 0x1E, 0x43, 0x01]))
        #expect(encoder.encode(.twoColorMode(enabled: false)) == Data([0x1B, 0x1E, 0x43, 0x00]))
    }

    // MARK: - テキスト

    @Test("Text data")
    func testTextData() {
        let text = "Hello"
        let textData = Data(text.utf8)
        let data = encoder.encode(.text(textData))
        #expect(data == textData)
    }

    @Test("Unknown data passthrough")
    func testUnknownData() {
        let unknownData = Data([0xFF, 0xFE, 0xFD])
        let data = encoder.encode(.unknown(unknownData))
        #expect(data == unknownData)
    }

    // MARK: - 複数コマンド

    @Test("Multiple commands encoding")
    func testMultipleCommands() {
        let commands: [StarPRNTCommand] = [
            .initialize,
            .boldOn,
            .lineFeed
        ]
        let data = encoder.encode(commands)
        var expected = Data([0x1B, 0x40])  // initialize
        expected.append(contentsOf: [0x1B, 0x45])  // bold on
        expected.append(0x0A)  // LF
        #expect(data == expected)
    }

    // MARK: - Extension メソッド

    @Test("Command encode extension")
    func testCommandEncodeExtension() {
        let data = StarPRNTCommand.initialize.encode()
        #expect(data == Data([0x1B, 0x40]))
    }

    @Test("Array encode extension")
    func testArrayEncodeExtension() {
        let commands: [StarPRNTCommand] = [.lineFeed, .formFeed]
        let data = commands.encode()
        #expect(data == Data([0x0A, 0x0C]))
    }
}

// MARK: - Convenience Builder Tests

@Suite("StarPRNTEncoder Builders Tests")
struct StarPRNTEncoderBuildersTests {

    @Test("Text builder")
    func testTextBuilder() {
        let command = StarPRNTEncoder.text("ABC")
        #expect(command != nil)
        if case .text(let data) = command {
            #expect(String(data: data, encoding: .shiftJIS) == "ABC")
        }
    }

    @Test("QR code builder")
    func testQRCodeBuilder() {
        let commands = StarPRNTEncoder.printQRCode("https://example.com")
        #expect(commands.count == 5)
        #expect(commands[0] == .qrCodeModel(2))
        #expect(commands[1] == .qrCodeErrorCorrection(1))
        #expect(commands[2] == .qrCodeCellSize(4))
        #expect(commands[4] == .qrCodePrint)
    }

    @Test("Barcode builder")
    func testBarcodeBuilder() {
        let commands = StarPRNTEncoder.printBarcode("ABC123", type: .code128)
        #expect(commands.count == 1)
        if case .barcode(let type, let mode, let width, let height, _) = commands[0] {
            #expect(type == .code128)
            #expect(mode == 2)
            #expect(width == 2)
            #expect(height == 40)
        }
    }

    @Test("PDF417 builder")
    func testPDF417Builder() {
        let commands = StarPRNTEncoder.printPDF417("HELLO")
        #expect(commands.count == 4)
        #expect(commands[0] == .pdf417ModuleWidth(2))
        #expect(commands[1] == .pdf417ECC(1))
        #expect(commands[3] == .pdf417Print)
    }
}

// MARK: - Roundtrip Tests

@Suite("StarPRNT Roundtrip Tests")
struct StarPRNTRoundtripTests {
    let encoder = StarPRNTEncoder()

    @Test("Control commands roundtrip")
    func testControlRoundtrip() {
        let commands: [StarPRNTCommand] = [
            .initialize, .lineFeed, .formFeed, .horizontalTab
        ]
        for command in commands {
            let encoded = encoder.encode(command)
            var decoder = StarPRNTDecoder()
            let decoded = decoder.decode(encoded)
            #expect(decoded == [command])
        }
    }

    @Test("Font and character set roundtrip")
    func testFontRoundtrip() {
        let commands: [StarPRNTCommand] = [
            .selectFont(.fontA),
            .selectFont(.fontB),
            .selectCodePage(5),
            .selectInternationalCharacter(8),
            .slashZero(enabled: true),
            .ankRightSpace(dots: 3),
            .downloadCharacterEnabled(true),
        ]
        for command in commands {
            let encoded = encoder.encode(command)
            var decoder = StarPRNTDecoder()
            let decoded = decoder.decode(encoded)
            #expect(decoded == [command])
        }
    }

    @Test("Kanji roundtrip")
    func testKanjiRoundtrip() {
        let commands: [StarPRNTCommand] = [
            .jisKanjiMode,
            .jisKanjiModeCancel,
            .shiftJISKanjiMode(enabled: true),
            .shiftJISKanjiMode(enabled: false),
        ]
        for command in commands {
            let encoded = encoder.encode(command)
            var decoder = StarPRNTDecoder()
            let decoded = decoder.decode(encoded)
            #expect(decoded == [command])
        }
    }

    @Test("Print mode roundtrip")
    func testPrintModeRoundtrip() {
        let commands: [StarPRNTCommand] = [
            .boldOn, .boldOff,
            .underline(enabled: true), .underline(enabled: false),
            .upperline(enabled: true), .upperline(enabled: false),
            .reverseOn, .reverseOff,
            .upsideDownOn, .upsideDownOff,
            .expansion(vertical: 2, horizontal: 3),
            .horizontalExpansion(2),
            .verticalExpansion(2),
            .smoothing(enabled: true),
        ]
        for command in commands {
            let encoded = encoder.encode(command)
            var decoder = StarPRNTDecoder()
            let decoded = decoder.decode(encoded)
            #expect(decoded == [command])
        }
    }

    @Test("Position and margin roundtrip")
    func testPositionRoundtrip() {
        let commands: [StarPRNTCommand] = [
            .leftMargin(5),
            .rightMargin(48),
            .absolutePosition(256),
            .relativePosition(100),
            .relativePosition(-100),
            .alignment(.left),
            .alignment(.center),
            .alignment(.right),
        ]
        for command in commands {
            let encoded = encoder.encode(command)
            var decoder = StarPRNTDecoder()
            let decoded = decoder.decode(encoded)
            #expect(decoded == [command])
        }
    }

    @Test("Line spacing roundtrip")
    func testLineSpacingRoundtrip() {
        let commands: [StarPRNTCommand] = [
            .feedLines(3),
            .lineSpacingMode(1),
            .lineSpacing3mm,
            .feedQuarterMM(16),
            .feedEighthMM(8),
        ]
        for command in commands {
            let encoded = encoder.encode(command)
            var decoder = StarPRNTDecoder()
            let decoded = decoder.decode(encoded)
            #expect(decoded == [command])
        }
    }

    @Test("Cut roundtrip")
    func testCutRoundtrip() {
        let commands: [StarPRNTCommand] = [
            .cut(.fullCut), .cut(.partialCut), .cut(.tearBar),
        ]
        for command in commands {
            let encoded = encoder.encode(command)
            var decoder = StarPRNTDecoder()
            let decoded = decoder.decode(encoded)
            #expect(decoded == [command])
        }
    }

    @Test("Page mode roundtrip")
    func testPageModeRoundtrip() {
        let commands: [StarPRNTCommand] = [
            .pageModeOn, .pageModeOff,
            .pageModeDirection(1),
            .pageModePrintArea(x: 0, y: 0, dx: 384, dy: 512),
            .pageModePrint, .pageModePrintAndExit, .pageModeCancel,
        ]
        for command in commands {
            let encoded = encoder.encode(command)
            var decoder = StarPRNTDecoder()
            let decoded = decoder.decode(encoded)
            #expect(decoded == [command])
        }
    }

    @Test("QR code roundtrip")
    func testQRCodeRoundtrip() {
        let commands: [StarPRNTCommand] = [
            .qrCodeModel(2),
            .qrCodeErrorCorrection(1),
            .qrCodeCellSize(4),
            .qrCodeStore(data: Data("https://example.com".utf8)),
            .qrCodePrint,
        ]
        for command in commands {
            let encoded = encoder.encode(command)
            var decoder = StarPRNTDecoder()
            let decoded = decoder.decode(encoded)
            #expect(decoded == [command])
        }
    }

    @Test("PDF417 roundtrip")
    func testPDF417Roundtrip() {
        let commands: [StarPRNTCommand] = [
            .pdf417Size(0, p1: 3, p2: 5),
            .pdf417ECC(2),
            .pdf417ModuleWidth(3),
            .pdf417AspectRatio(2),
            .pdf417Store(data: Data("HELLO".utf8)),
            .pdf417Print,
        ]
        for command in commands {
            let encoded = encoder.encode(command)
            var decoder = StarPRNTDecoder()
            let decoded = decoder.decode(encoded)
            #expect(decoded == [command])
        }
    }

    @Test("Reset and status roundtrip")
    func testResetStatusRoundtrip() {
        let commands: [StarPRNTCommand] = [
            .realtimeReset,
            .printerReset,
            .autoStatusSetting(3),
            .realtimeStatus,
        ]
        for command in commands {
            let encoded = encoder.encode(command)
            var decoder = StarPRNTDecoder()
            let decoded = decoder.decode(encoded)
            #expect(decoded == [command])
        }
    }

    @Test("Print settings roundtrip")
    func testPrintSettingsRoundtrip() {
        let commands: [StarPRNTCommand] = [
            .printArea(1),
            .printDensity(2),
            .printSpeed(1),
            .twoColorPrintColor(1),
            .twoColorMode(enabled: true),
        ]
        for command in commands {
            let encoded = encoder.encode(command)
            var decoder = StarPRNTDecoder()
            let decoded = decoder.decode(encoded)
            #expect(decoded == [command])
        }
    }

    @Test("Barcode roundtrip")
    func testBarcodeRoundtrip() {
        let command = StarPRNTCommand.barcode(
            type: .code128, mode: 2, width: 2, height: 64,
            data: Data("ABC123".utf8)
        )
        let encoded = encoder.encode(command)
        var decoder = StarPRNTDecoder()
        let decoded = decoder.decode(encoded)
        #expect(decoded == [command])
    }

    @Test("Bit image roundtrip")
    func testBitImageRoundtrip() {
        let imageData = Data([0xFF, 0x00, 0xAA])
        let command = StarPRNTCommand.bitImageNormal(width: 3, data: imageData)
        let encoded = encoder.encode(command)
        var decoder = StarPRNTDecoder()
        let decoded = decoder.decode(encoded)
        #expect(decoded == [command])
    }

    @Test("Raster graphics roundtrip")
    func testRasterGraphicsRoundtrip() {
        let imageData = Data([0xFF, 0x00, 0x00, 0xFF])
        let command = StarPRNTCommand.rasterGraphics(mode: 0, width: 2, height: 2, data: imageData)
        let encoded = encoder.encode(command)
        var decoder = StarPRNTDecoder()
        let decoded = decoder.decode(encoded)
        #expect(decoded == [command])
    }

    @Test("Mixed commands roundtrip")
    func testMixedCommandsRoundtrip() {
        let commands: [StarPRNTCommand] = [
            .initialize,
            .alignment(.center),
            .boldOn,
            .lineFeed,
            .boldOff,
            .lineFeed,
            .cut(.partialCut),
        ]
        let encoded = encoder.encode(commands)
        var decoder = StarPRNTDecoder()
        let decoded = decoder.decode(encoded)
        #expect(decoded == commands)
    }
}
