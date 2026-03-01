import Testing
import Foundation
@testable import ThermalPrinterCommand

@Suite("StarPRNTDecoder Tests")
struct StarPRNTDecoderTests {
    var decoder = StarPRNTDecoder()

    // MARK: - 制御コマンド

    @Test("Initialize command")
    mutating func testInitialize() {
        let data = Data([0x1B, 0x40])  // ESC @
        let commands = decoder.decode(data)
        #expect(commands == [.initialize])
    }

    @Test("Line feed")
    mutating func testLineFeed() {
        let data = Data([0x0A])  // LF
        let commands = decoder.decode(data)
        #expect(commands == [.lineFeed])
    }

    @Test("Form feed")
    mutating func testFormFeed() {
        let data = Data([0x0C])  // FF
        let commands = decoder.decode(data)
        #expect(commands == [.formFeed])
    }

    @Test("Horizontal tab")
    mutating func testHorizontalTab() {
        let data = Data([0x09])  // HT
        let commands = decoder.decode(data)
        #expect(commands == [.horizontalTab])
    }

    // MARK: - フォントスタイル

    @Test("Select font")
    mutating func testSelectFont() {
        let fontA = Data([0x1B, 0x1E, 0x46, 0x00])  // ESC RS F 0
        let fontB = Data([0x1B, 0x1E, 0x46, 0x01])  // ESC RS F 1
        #expect(decoder.decode(fontA) == [.selectFont(.fontA)])
        #expect(decoder.decode(fontB) == [.selectFont(.fontB)])
    }

    @Test("Select code page")
    mutating func testSelectCodePage() {
        let data = Data([0x1B, 0x1D, 0x74, 0x05])  // ESC GS t 5
        let commands = decoder.decode(data)
        #expect(commands == [.selectCodePage(5)])
    }

    @Test("Select international character set")
    mutating func testSelectInternationalCharacter() {
        let data = Data([0x1B, 0x52, 0x08])  // ESC R 8
        let commands = decoder.decode(data)
        #expect(commands == [.selectInternationalCharacter(8)])
    }

    @Test("Slash zero")
    mutating func testSlashZero() {
        let on = Data([0x1B, 0x2F, 0x01])   // ESC / 1
        let off = Data([0x1B, 0x2F, 0x00])  // ESC / 0
        #expect(decoder.decode(on) == [.slashZero(enabled: true)])
        #expect(decoder.decode(off) == [.slashZero(enabled: false)])
    }

    @Test("ANK right space")
    mutating func testAnkRightSpace() {
        let data = Data([0x1B, 0x20, 0x03])  // ESC SP 3
        let commands = decoder.decode(data)
        #expect(commands == [.ankRightSpace(dots: 3)])
    }

    @Test("Download character enabled")
    mutating func testDownloadCharacterEnabled() {
        let on = Data([0x1B, 0x25, 0x01])   // ESC % 1
        let off = Data([0x1B, 0x25, 0x00])  // ESC % 0
        #expect(decoder.decode(on) == [.downloadCharacterEnabled(true)])
        #expect(decoder.decode(off) == [.downloadCharacterEnabled(false)])
    }

    // MARK: - 漢字

    @Test("JIS Kanji mode")
    mutating func testJisKanjiMode() {
        let on = Data([0x1B, 0x70])   // ESC p
        let off = Data([0x1B, 0x71])  // ESC q
        #expect(decoder.decode(on) == [.jisKanjiMode])
        #expect(decoder.decode(off) == [.jisKanjiModeCancel])
    }

    @Test("Shift JIS Kanji mode")
    mutating func testShiftJISKanjiMode() {
        let on = Data([0x1B, 0x24, 0x01])   // ESC $ 1
        let off = Data([0x1B, 0x24, 0x00])  // ESC $ 0
        #expect(decoder.decode(on) == [.shiftJISKanjiMode(enabled: true)])
        #expect(decoder.decode(off) == [.shiftJISKanjiMode(enabled: false)])
    }

    // MARK: - プリントモード

    @Test("Bold on/off")
    mutating func testBold() {
        let on = Data([0x1B, 0x45])   // ESC E
        let off = Data([0x1B, 0x46])  // ESC F
        #expect(decoder.decode(on) == [.boldOn])
        #expect(decoder.decode(off) == [.boldOff])
    }

    @Test("Underline")
    mutating func testUnderline() {
        let on = Data([0x1B, 0x2D, 0x01])   // ESC - 1
        let off = Data([0x1B, 0x2D, 0x00])  // ESC - 0
        #expect(decoder.decode(on) == [.underline(enabled: true)])
        #expect(decoder.decode(off) == [.underline(enabled: false)])
    }

    @Test("Upperline")
    mutating func testUpperline() {
        let on = Data([0x1B, 0x5F, 0x01])   // ESC _ 1
        let off = Data([0x1B, 0x5F, 0x00])  // ESC _ 0
        #expect(decoder.decode(on) == [.upperline(enabled: true)])
        #expect(decoder.decode(off) == [.upperline(enabled: false)])
    }

    @Test("Reverse on/off")
    mutating func testReverse() {
        let on = Data([0x1B, 0x34])   // ESC 4
        let off = Data([0x1B, 0x35])  // ESC 5
        #expect(decoder.decode(on) == [.reverseOn])
        #expect(decoder.decode(off) == [.reverseOff])
    }

    @Test("Upside down on/off")
    mutating func testUpsideDown() {
        let on = Data([0x0F])   // SI
        let off = Data([0x12])  // DC2
        #expect(decoder.decode(on) == [.upsideDownOn])
        #expect(decoder.decode(off) == [.upsideDownOff])
    }

    @Test("Expansion")
    mutating func testExpansion() {
        let data = Data([0x1B, 0x69, 0x02, 0x03])  // ESC i 2 3
        let commands = decoder.decode(data)
        #expect(commands == [.expansion(vertical: 2, horizontal: 3)])
    }

    @Test("Horizontal expansion")
    mutating func testHorizontalExpansion() {
        let data = Data([0x1B, 0x57, 0x02])  // ESC W 2
        let commands = decoder.decode(data)
        #expect(commands == [.horizontalExpansion(2)])
    }

    @Test("Vertical expansion")
    mutating func testVerticalExpansion() {
        let data = Data([0x1B, 0x68, 0x02])  // ESC h 2
        let commands = decoder.decode(data)
        #expect(commands == [.verticalExpansion(2)])
    }

    @Test("Smoothing")
    mutating func testSmoothing() {
        let on = Data([0x1B, 0x1D, 0x62, 0x01])   // ESC GS b 1
        let off = Data([0x1B, 0x1D, 0x62, 0x00])  // ESC GS b 0
        #expect(decoder.decode(on) == [.smoothing(enabled: true)])
        #expect(decoder.decode(off) == [.smoothing(enabled: false)])
    }

    // MARK: - 水平方向位置

    @Test("Left margin")
    mutating func testLeftMargin() {
        let data = Data([0x1B, 0x6C, 0x05])  // ESC l 5
        let commands = decoder.decode(data)
        #expect(commands == [.leftMargin(5)])
    }

    @Test("Right margin")
    mutating func testRightMargin() {
        let data = Data([0x1B, 0x51, 0x30])  // ESC Q 48
        let commands = decoder.decode(data)
        #expect(commands == [.rightMargin(48)])
    }

    @Test("Absolute position")
    mutating func testAbsolutePosition() {
        let data = Data([0x1B, 0x1D, 0x41, 0x00, 0x01])  // ESC GS A 0 1 (256)
        let commands = decoder.decode(data)
        #expect(commands == [.absolutePosition(256)])
    }

    @Test("Relative position")
    mutating func testRelativePosition() {
        // Positive: 100
        let pos = Data([0x1B, 0x1D, 0x52, 0x64, 0x00])  // ESC GS R 100 0
        #expect(decoder.decode(pos) == [.relativePosition(100)])

        // Negative: -100 (0xFF9C in two's complement)
        let neg = Data([0x1B, 0x1D, 0x52, 0x9C, 0xFF])  // ESC GS R 0x9C 0xFF
        #expect(decoder.decode(neg) == [.relativePosition(-100)])
    }

    @Test("Alignment")
    mutating func testAlignment() {
        let left = Data([0x1B, 0x1D, 0x61, 0x00])    // ESC GS a 0
        let center = Data([0x1B, 0x1D, 0x61, 0x01])  // ESC GS a 1
        let right = Data([0x1B, 0x1D, 0x61, 0x02])   // ESC GS a 2
        #expect(decoder.decode(left) == [.alignment(.left)])
        #expect(decoder.decode(center) == [.alignment(.center)])
        #expect(decoder.decode(right) == [.alignment(.right)])
    }

    @Test("Set horizontal tab positions")
    mutating func testSetHorizontalTab() {
        let data = Data([0x1B, 0x44, 0x08, 0x10, 0x18, 0x00])  // ESC D 8 16 24 NUL
        let commands = decoder.decode(data)
        #expect(commands == [.setHorizontalTab([8, 16, 24])])
    }

    @Test("Clear horizontal tab")
    mutating func testClearHorizontalTab() {
        let data = Data([0x1B, 0x44, 0x00])  // ESC D NUL
        let commands = decoder.decode(data)
        #expect(commands == [.clearHorizontalTab])
    }

    // MARK: - 行間隔

    @Test("Feed lines")
    mutating func testFeedLines() {
        let data = Data([0x1B, 0x61, 0x03])  // ESC a 3
        let commands = decoder.decode(data)
        #expect(commands == [.feedLines(3)])
    }

    @Test("Line spacing mode")
    mutating func testLineSpacingMode() {
        let data = Data([0x1B, 0x7A, 0x01])  // ESC z 1
        let commands = decoder.decode(data)
        #expect(commands == [.lineSpacingMode(1)])
    }

    @Test("Line spacing 3mm")
    mutating func testLineSpacing3mm() {
        let data = Data([0x1B, 0x30])  // ESC 0
        let commands = decoder.decode(data)
        #expect(commands == [.lineSpacing3mm])
    }

    @Test("Feed quarter mm")
    mutating func testFeedQuarterMM() {
        let data = Data([0x1B, 0x4A, 0x10])  // ESC J 16
        let commands = decoder.decode(data)
        #expect(commands == [.feedQuarterMM(16)])
    }

    @Test("Feed eighth mm")
    mutating func testFeedEighthMM() {
        let data = Data([0x1B, 0x49, 0x08])  // ESC I 8
        let commands = decoder.decode(data)
        #expect(commands == [.feedEighthMM(8)])
    }

    // MARK: - ページ管理

    @Test("Page length")
    mutating func testPageLength() {
        let data = Data([0x1B, 0x43, 0x40])  // ESC C 64
        let commands = decoder.decode(data)
        #expect(commands == [.pageLength(lines: 64)])
    }

    // MARK: - トップマージン

    @Test("Top margin")
    mutating func testTopMargin() {
        let data = Data([0x1B, 0x1E, 0x54, 0x05])  // ESC RS T 5
        let commands = decoder.decode(data)
        #expect(commands == [.topMargin(5)])
    }

    // MARK: - カッター

    @Test("Cut modes")
    mutating func testCut() {
        let full = Data([0x1B, 0x64, 0x00])     // ESC d 0
        let partial = Data([0x1B, 0x64, 0x01])  // ESC d 1
        let tear = Data([0x1B, 0x64, 0x02])     // ESC d 2
        #expect(decoder.decode(full) == [.cut(.fullCut)])
        #expect(decoder.decode(partial) == [.cut(.partialCut)])
        #expect(decoder.decode(tear) == [.cut(.tearBar)])
    }

    // MARK: - ページモード

    @Test("Page mode on/off")
    mutating func testPageMode() {
        let on = Data([0x1B, 0x1D, 0x50, 0x30])   // ESC GS P 0
        let off = Data([0x1B, 0x1D, 0x50, 0x31])  // ESC GS P 1
        #expect(decoder.decode(on) == [.pageModeOn])
        #expect(decoder.decode(off) == [.pageModeOff])
    }

    @Test("Page mode direction")
    mutating func testPageModeDirection() {
        let data = Data([0x1B, 0x1D, 0x50, 0x32, 0x01])  // ESC GS P 2 1
        let commands = decoder.decode(data)
        #expect(commands == [.pageModeDirection(1)])
    }

    @Test("Page mode print area")
    mutating func testPageModePrintArea() {
        // ESC GS P 3 xL xH yL yH dxL dxH dyL dyH
        let data = Data([0x1B, 0x1D, 0x50, 0x33,
                         0x00, 0x00,  // x=0
                         0x00, 0x00,  // y=0
                         0x80, 0x01,  // dx=384
                         0x00, 0x02]) // dy=512
        let commands = decoder.decode(data)
        #expect(commands == [.pageModePrintArea(x: 0, y: 0, dx: 384, dy: 512)])
    }

    @Test("Page mode print/exit/cancel")
    mutating func testPageModeActions() {
        let print = Data([0x1B, 0x1D, 0x50, 0x36])       // ESC GS P 6
        let printExit = Data([0x1B, 0x1D, 0x50, 0x37])   // ESC GS P 7
        let cancel = Data([0x1B, 0x1D, 0x50, 0x38])      // ESC GS P 8
        #expect(decoder.decode(print) == [.pageModePrint])
        #expect(decoder.decode(printExit) == [.pageModePrintAndExit])
        #expect(decoder.decode(cancel) == [.pageModeCancel])
    }

    // MARK: - ビットイメージ

    @Test("Bit image normal")
    mutating func testBitImageNormal() {
        // ESC K n1 n2 d... (width=3 bytes)
        let data = Data([0x1B, 0x4B, 0x03, 0x00, 0xFF, 0x00, 0xAA])
        let commands = decoder.decode(data)
        #expect(commands.count == 1)
        if case .bitImageNormal(let width, let imgData) = commands[0] {
            #expect(width == 3)
            #expect(imgData == Data([0xFF, 0x00, 0xAA]))
        } else {
            Issue.record("Expected bitImageNormal command")
        }
    }

    @Test("Bit image high density")
    mutating func testBitImageHigh() {
        // ESC L n1 n2 d... (width=2 bytes)
        let data = Data([0x1B, 0x4C, 0x02, 0x00, 0xCC, 0x33])
        let commands = decoder.decode(data)
        #expect(commands.count == 1)
        if case .bitImageHigh(let width, let imgData) = commands[0] {
            #expect(width == 2)
            #expect(imgData == Data([0xCC, 0x33]))
        } else {
            Issue.record("Expected bitImageHigh command")
        }
    }

    // MARK: - バーコード

    @Test("Barcode")
    mutating func testBarcode() {
        // ESC b type mode width height data... RS
        var data = Data([0x1B, 0x62, 0x04, 0x02, 0x02, 0x40])  // Code128, mode=2, width=2, height=64
        data.append(contentsOf: "ABC123".utf8)
        data.append(0x1E)  // RS terminator
        let commands = decoder.decode(data)
        #expect(commands.count == 1)
        if case .barcode(let type, let mode, let width, let height, let barcodeData) = commands[0] {
            #expect(type == .code128)
            #expect(mode == 2)
            #expect(width == 2)
            #expect(height == 64)
            #expect(String(data: barcodeData, encoding: .utf8) == "ABC123")
        } else {
            Issue.record("Expected barcode command")
        }
    }

    // MARK: - QRコード

    @Test("QR code model")
    mutating func testQRCodeModel() {
        let data = Data([0x1B, 0x1D, 0x79, 0x53, 0x00, 0x02])  // ESC GS y S 0 2
        let commands = decoder.decode(data)
        #expect(commands == [.qrCodeModel(2)])
    }

    @Test("QR code error correction")
    mutating func testQRCodeErrorCorrection() {
        let data = Data([0x1B, 0x1D, 0x79, 0x53, 0x01, 0x01])  // ESC GS y S 1 1
        let commands = decoder.decode(data)
        #expect(commands == [.qrCodeErrorCorrection(1)])
    }

    @Test("QR code cell size")
    mutating func testQRCodeCellSize() {
        let data = Data([0x1B, 0x1D, 0x79, 0x53, 0x02, 0x04])  // ESC GS y S 2 4
        let commands = decoder.decode(data)
        #expect(commands == [.qrCodeCellSize(4)])
    }

    @Test("QR code store")
    mutating func testQRCodeStore() {
        let text = "https://example.com"
        let textData = Data(text.utf8)
        // ESC GS y D 1 m nL nH d...
        var data = Data([0x1B, 0x1D, 0x79, 0x44, 0x01, 0x00])
        data.append(UInt8(textData.count & 0xFF))
        data.append(UInt8((textData.count >> 8) & 0xFF))
        data.append(textData)
        let commands = decoder.decode(data)
        #expect(commands.count == 1)
        if case .qrCodeStore(let storedData) = commands[0] {
            #expect(storedData == textData)
            #expect(String(data: storedData, encoding: .utf8) == text)
        } else {
            Issue.record("Expected qrCodeStore command")
        }
    }

    @Test("QR code print")
    mutating func testQRCodePrint() {
        let data = Data([0x1B, 0x1D, 0x79, 0x50])  // ESC GS y P
        let commands = decoder.decode(data)
        #expect(commands == [.qrCodePrint])
    }

    // MARK: - PDF417

    @Test("PDF417 size")
    mutating func testPDF417Size() {
        let data = Data([0x1B, 0x1D, 0x78, 0x53, 0x00, 0x00, 0x03, 0x05])
        let commands = decoder.decode(data)
        #expect(commands == [.pdf417Size(0, p1: 3, p2: 5)])
    }

    @Test("PDF417 ECC")
    mutating func testPDF417ECC() {
        let data = Data([0x1B, 0x1D, 0x78, 0x53, 0x01, 0x02])
        let commands = decoder.decode(data)
        #expect(commands == [.pdf417ECC(2)])
    }

    @Test("PDF417 module width")
    mutating func testPDF417ModuleWidth() {
        let data = Data([0x1B, 0x1D, 0x78, 0x53, 0x02, 0x03])
        let commands = decoder.decode(data)
        #expect(commands == [.pdf417ModuleWidth(3)])
    }

    @Test("PDF417 aspect ratio")
    mutating func testPDF417AspectRatio() {
        let data = Data([0x1B, 0x1D, 0x78, 0x53, 0x03, 0x02])
        let commands = decoder.decode(data)
        #expect(commands == [.pdf417AspectRatio(2)])
    }

    @Test("PDF417 store")
    mutating func testPDF417Store() {
        let text = "HELLO"
        let textData = Data(text.utf8)
        // ESC GS x D nL nH d...
        var data = Data([0x1B, 0x1D, 0x78, 0x44])
        data.append(UInt8(textData.count & 0xFF))
        data.append(UInt8((textData.count >> 8) & 0xFF))
        data.append(textData)
        let commands = decoder.decode(data)
        #expect(commands.count == 1)
        if case .pdf417Store(let storedData) = commands[0] {
            #expect(storedData == textData)
        } else {
            Issue.record("Expected pdf417Store command")
        }
    }

    @Test("PDF417 print")
    mutating func testPDF417Print() {
        let data = Data([0x1B, 0x1D, 0x78, 0x50])  // ESC GS x P
        let commands = decoder.decode(data)
        #expect(commands == [.pdf417Print])
    }

    // MARK: - リセット・ステータス

    @Test("Realtime reset")
    mutating func testRealtimeReset() {
        let data = Data([0x1B, 0x06, 0x18])  // ESC ACK CAN
        let commands = decoder.decode(data)
        #expect(commands == [.realtimeReset])
    }

    @Test("Printer reset")
    mutating func testPrinterReset() {
        let data = Data([0x1B, 0x3F, 0x0A, 0x00])  // ESC ? LF NUL
        let commands = decoder.decode(data)
        #expect(commands == [.printerReset])
    }

    @Test("Auto status setting")
    mutating func testAutoStatusSetting() {
        let data = Data([0x1B, 0x1E, 0x61, 0x03])  // ESC RS a 3
        let commands = decoder.decode(data)
        #expect(commands == [.autoStatusSetting(3)])
    }

    @Test("Realtime status")
    mutating func testRealtimeStatus() {
        let data = Data([0x1B, 0x06, 0x01])  // ESC ACK SOH
        let commands = decoder.decode(data)
        #expect(commands == [.realtimeStatus])
    }

    // MARK: - 外部機器

    @Test("Buzzer")
    mutating func testBuzzer() {
        let data = Data([0x1B, 0x07, 0x03, 0x05])  // ESC BEL 3 5
        let commands = decoder.decode(data)
        #expect(commands == [.buzzer(n1: 3, n2: 5)])
    }

    @Test("External devices")
    mutating func testExternalDevices() {
        #expect(decoder.decode(Data([0x07])) == [.externalDevice1A])  // BEL
        #expect(decoder.decode(Data([0x1C])) == [.externalDevice1B])  // FS
        #expect(decoder.decode(Data([0x1A])) == [.externalDevice2A])  // SUB
        #expect(decoder.decode(Data([0x19])) == [.externalDevice2B])  // EM
    }

    // MARK: - 印字設定

    @Test("Print area")
    mutating func testPrintArea() {
        let data = Data([0x1B, 0x1E, 0x41, 0x01])  // ESC RS A 1
        let commands = decoder.decode(data)
        #expect(commands == [.printArea(1)])
    }

    @Test("Print density")
    mutating func testPrintDensity() {
        let data = Data([0x1B, 0x1E, 0x64, 0x02])  // ESC RS d 2
        let commands = decoder.decode(data)
        #expect(commands == [.printDensity(2)])
    }

    @Test("Print speed")
    mutating func testPrintSpeed() {
        let data = Data([0x1B, 0x1E, 0x72, 0x01])  // ESC RS r 1
        let commands = decoder.decode(data)
        #expect(commands == [.printSpeed(1)])
    }

    // MARK: - 2色印字

    @Test("Two color print color")
    mutating func testTwoColorPrintColor() {
        let data = Data([0x1B, 0x1E, 0x63, 0x01])  // ESC RS c 1
        let commands = decoder.decode(data)
        #expect(commands == [.twoColorPrintColor(1)])
    }

    @Test("Two color mode")
    mutating func testTwoColorMode() {
        let on = Data([0x1B, 0x1E, 0x43, 0x01])   // ESC RS C 1
        let off = Data([0x1B, 0x1E, 0x43, 0x00])  // ESC RS C 0
        #expect(decoder.decode(on) == [.twoColorMode(enabled: true)])
        #expect(decoder.decode(off) == [.twoColorMode(enabled: false)])
    }

    // MARK: - テキスト

    @Test("Text data")
    mutating func testTextData() {
        let text = "Hello"
        let data = Data(text.utf8)
        let commands = decoder.decode(data)
        #expect(commands.count == 1)
        if case .text(let textData) = commands[0] {
            #expect(String(data: textData, encoding: .utf8) == text)
        } else {
            Issue.record("Expected text command")
        }
    }

    // MARK: - 複合テスト

    @Test("Mixed commands")
    mutating func testMixedCommands() {
        var data = Data()
        data.append(contentsOf: [0x1B, 0x40])              // Initialize
        data.append(contentsOf: [0x1B, 0x1D, 0x61, 0x01])  // Alignment center
        data.append(contentsOf: [0x1B, 0x45])               // Bold on
        data.append(contentsOf: "Title".utf8)               // Text
        data.append(0x0A)                                   // LF
        data.append(contentsOf: [0x1B, 0x46])               // Bold off
        data.append(contentsOf: "Content".utf8)             // Text
        data.append(0x0A)                                   // LF
        data.append(contentsOf: [0x1B, 0x64, 0x01])        // Partial cut

        let commands = decoder.decode(data)

        #expect(commands.count == 9)
        #expect(commands[0] == .initialize)
        #expect(commands[1] == .alignment(.center))
        #expect(commands[2] == .boldOn)
        if case .text(let titleData) = commands[3] {
            #expect(String(data: titleData, encoding: .utf8) == "Title")
        }
        #expect(commands[4] == .lineFeed)
        #expect(commands[5] == .boldOff)
        if case .text(let contentData) = commands[6] {
            #expect(String(data: contentData, encoding: .utf8) == "Content")
        }
        #expect(commands[7] == .lineFeed)
        #expect(commands[8] == .cut(.partialCut))
    }

    @Test("Unknown command handling")
    mutating func testUnknownCommand() {
        let data = Data([0x1B, 0xFF])  // Unknown ESC command
        let commands = decoder.decode(data)
        #expect(commands.count == 1)
        if case .unknown(let unknownData) = commands[0] {
            #expect(unknownData == Data([0x1B, 0xFF]))
        } else {
            Issue.record("Expected unknown command")
        }
    }

    // MARK: - インクリメンタルデコード

    @Test("Incremental decode with pending buffer")
    mutating func testIncrementalDecode() {
        // 最初のチャンク: ESC だけ（不完全）
        let chunk1 = Data([0x1B])
        let commands1 = decoder.decode(chunk1)
        #expect(commands1.isEmpty)
        #expect(decoder.pendingBuffer == Data([0x1B]))

        // 2番目のチャンク: @ を送信して初期化コマンドを完成
        let chunk2 = Data([0x40])
        let commands2 = decoder.decode(chunk2)
        #expect(commands2 == [.initialize])
        #expect(decoder.pendingBuffer.isEmpty)
    }

    @Test("Raster graphics")
    mutating func testRasterGraphics() {
        // ESC GS S m xL xH yL yH d...
        // mode=0, width=2, height=2, 4 bytes of data
        var data = Data([0x1B, 0x1D, 0x53, 0x00, 0x02, 0x00, 0x02, 0x00])
        data.append(contentsOf: [0xFF, 0x00, 0x00, 0xFF])
        let commands = decoder.decode(data)
        #expect(commands.count == 1)
        if case .rasterGraphics(let mode, let width, let height, let imgData) = commands[0] {
            #expect(mode == 0)
            #expect(width == 2)
            #expect(height == 2)
            #expect(imgData.count == 4)
        } else {
            Issue.record("Expected rasterGraphics command")
        }
    }
}
