import Testing
import Foundation
@testable import ThermalPrinterCommand

@Suite("ESCPOSDecoder Tests")
struct ESCPOSDecoderTests {
    var decoder = ESCPOSDecoder()

    @Test("Initialize command")
    mutating func testInitializeCommand() {
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

    @Test("Carriage return")
    mutating func testCarriageReturn() {
        let data = Data([0x0D])  // CR
        let commands = decoder.decode(data)
        #expect(commands == [.carriageReturn])
    }

    @Test("Horizontal tab")
    mutating func testHorizontalTab() {
        let data = Data([0x09])  // HT
        let commands = decoder.decode(data)
        #expect(commands == [.horizontalTab])
    }

    @Test("Select print mode (ESC !)")
    mutating func testSelectPrintMode() {
        // 標準モード
        let standard = Data([0x1B, 0x21, 0x00])
        #expect(decoder.decode(standard) == [.selectPrintMode([])])
        // Font B + 強調
        let fontBBold = Data([0x1B, 0x21, 0x09])
        #expect(decoder.decode(fontBBold) == [.selectPrintMode([.fontB, .emphasized])])
        // 全モード: 0xB9 = Font B(1) + 強調(8) + 倍高(0x10) + 倍幅(0x20) + アンダーライン(0x80)
        let all = Data([0x1B, 0x21, 0xB9])
        #expect(decoder.decode(all) == [.selectPrintMode([.fontB, .emphasized, .doubleHeight, .doubleWidth, .underline])])
    }

    @Test("Bold on/off")
    mutating func testBold() {
        let dataOn = Data([0x1B, 0x45, 0x01])   // ESC E 1
        let dataOff = Data([0x1B, 0x45, 0x00])  // ESC E 0
        #expect(decoder.decode(dataOn) == [.boldOn])
        #expect(decoder.decode(dataOff) == [.boldOff])
    }

    @Test("Font selection")
    mutating func testFontSelection() {
        let dataA = Data([0x1B, 0x4D, 0x00])  // ESC M 0
        let dataB = Data([0x1B, 0x4D, 0x01])  // ESC M 1
        #expect(decoder.decode(dataA) == [.selectFont(.fontA)])
        #expect(decoder.decode(dataB) == [.selectFont(.fontB)])
    }

    @Test("Underline modes")
    mutating func testUnderline() {
        let off = Data([0x1B, 0x2D, 0x00])     // ESC - 0
        let single = Data([0x1B, 0x2D, 0x01])  // ESC - 1
        let double = Data([0x1B, 0x2D, 0x02])  // ESC - 2
        #expect(decoder.decode(off) == [.underline(.off)])
        #expect(decoder.decode(single) == [.underline(.single)])
        #expect(decoder.decode(double) == [.underline(.double)])
    }

    @Test("Justification")
    mutating func testJustification() {
        let left = Data([0x1B, 0x61, 0x00])    // ESC a 0
        let center = Data([0x1B, 0x61, 0x01])  // ESC a 1
        let right = Data([0x1B, 0x61, 0x02])   // ESC a 2
        #expect(decoder.decode(left) == [.justification(.left)])
        #expect(decoder.decode(center) == [.justification(.center)])
        #expect(decoder.decode(right) == [.justification(.right)])
    }

    @Test("Character size")
    mutating func testCharacterSize() {
        let data = Data([0x1D, 0x21, 0x11])  // GS ! 0x11 (2x width, 2x height)
        let commands = decoder.decode(data)
        #expect(commands == [.characterSize(width: 2, height: 2)])
    }

    @Test("Line spacing")
    mutating func testLineSpacing() {
        let defaultSpacing = Data([0x1B, 0x32])        // ESC 2
        let customSpacing = Data([0x1B, 0x33, 0x30])   // ESC 3 48
        #expect(decoder.decode(defaultSpacing) == [.defaultLineSpacing])
        #expect(decoder.decode(customSpacing) == [.lineSpacing(dots: 48)])
    }

    @Test("Paper cut")
    mutating func testPaperCut() {
        let fullCut = Data([0x1D, 0x56, 0x00])      // GS V 0
        let partialCut = Data([0x1D, 0x56, 0x01])   // GS V 1
        #expect(decoder.decode(fullCut) == [.cut(.full)])
        #expect(decoder.decode(partialCut) == [.cut(.partial)])
    }

    @Test("Paper cut with feed")
    mutating func testPaperCutWithFeed() {
        let data = Data([0x1D, 0x56, 0x42, 0x10])  // GS V B 16
        let commands = decoder.decode(data)
        #expect(commands == [.cutWithFeed(mode: .partialWithFeed, feed: 16)])
    }

    @Test("Left margin")
    mutating func testLeftMargin() {
        let data = Data([0x1D, 0x4C, 0x20, 0x00])  // GS L 32 0 (32 dots)
        let commands = decoder.decode(data)
        #expect(commands == [.leftMargin(dots: 32)])
    }

    @Test("Print width")
    mutating func testPrintWidth() {
        let data = Data([0x1D, 0x57, 0x00, 0x02])  // GS W 0 2 (512 dots)
        let commands = decoder.decode(data)
        #expect(commands == [.printingWidth(dots: 512)])
    }

    @Test("Barcode height and width")
    mutating func testBarcodeSettings() {
        let height = Data([0x1D, 0x68, 0x50])  // GS h 80
        let width = Data([0x1D, 0x77, 0x02])   // GS w 2
        #expect(decoder.decode(height) == [.barcodeHeight(dots: 80)])
        #expect(decoder.decode(width) == [.barcodeWidth(multiplier: 2)])
    }

    @Test("Barcode HRI position")
    mutating func testBarcodeHRI() {
        let below = Data([0x1D, 0x48, 0x02])  // GS H 2
        #expect(decoder.decode(below) == [.barcodeHRIPosition(.below)])
    }

    @Test("Barcode printing (NUL terminated)")
    mutating func testBarcodeNULTerminated() {
        // GS k 2 "4912345678904" NUL (EAN-13)
        var data = Data([0x1D, 0x6B, 0x02])
        data.append(contentsOf: "4912345678904".utf8)
        data.append(0x00)
        let commands = decoder.decode(data)
        #expect(commands.count == 1)
        if case .barcode(let type, let barcodeData) = commands[0] {
            #expect(type == .ean13)
            #expect(String(data: barcodeData, encoding: .utf8) == "4912345678904")
        } else {
            Issue.record("Expected barcode command")
        }
    }

    @Test("Barcode printing (length specified)")
    mutating func testBarcodeLengthSpecified() {
        // GS k 73 10 "{B12345678" (Code128)
        var data = Data([0x1D, 0x6B, 73, 10])
        data.append(contentsOf: "{B12345678".utf8)
        let commands = decoder.decode(data)
        #expect(commands.count == 1)
        if case .barcode(let type, let barcodeData) = commands[0] {
            #expect(type == .code128)
            #expect(barcodeData.count == 10)
        } else {
            Issue.record("Expected barcode command")
        }
    }

    @Test("Reverse mode")
    mutating func testReverseMode() {
        let on = Data([0x1D, 0x42, 0x01])   // GS B 1
        let off = Data([0x1D, 0x42, 0x00])  // GS B 0
        #expect(decoder.decode(on) == [.reverseMode(enabled: true)])
        #expect(decoder.decode(off) == [.reverseMode(enabled: false)])
    }

    @Test("Cash drawer")
    mutating func testCashDrawer() {
        let data = Data([0x1B, 0x70, 0x00, 0x19, 0x78])  // ESC p 0 25 120
        let commands = decoder.decode(data)
        #expect(commands == [.openCashDrawer(pin: 0, onTime: 25, offTime: 120)])
    }

    @Test("Print and feed")
    mutating func testPrintAndFeed() {
        let feedDots = Data([0x1B, 0x4A, 0x20])   // ESC J 32
        let feedLines = Data([0x1B, 0x64, 0x03])  // ESC d 3
        #expect(decoder.decode(feedDots) == [.printAndFeed(dots: 32)])
        #expect(decoder.decode(feedLines) == [.feedLines(count: 3)])
    }

    @Test("Realtime status request")
    mutating func testRealtimeStatus() {
        let data = Data([0x10, 0x04, 0x01])  // DLE EOT 1
        let commands = decoder.decode(data)
        #expect(commands == [.realtimeStatusRequest(type: 1)])
    }

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

    @Test("Mixed commands")
    mutating func testMixedCommands() {
        var data = Data()
        data.append(contentsOf: [0x1B, 0x40])           // Initialize
        data.append(contentsOf: [0x1B, 0x61, 0x01])     // Center
        data.append(contentsOf: [0x1B, 0x45, 0x01])     // Bold on
        data.append(contentsOf: "Title".utf8)           // Text
        data.append(0x0A)                               // LF
        data.append(contentsOf: [0x1B, 0x45, 0x00])     // Bold off
        data.append(contentsOf: "Content".utf8)         // Text
        data.append(0x0A)                               // LF
        data.append(contentsOf: [0x1D, 0x56, 0x00])     // Cut

        let commands = decoder.decode(data)

        // Initialize, Center, BoldOn, Text("Title"), LF, BoldOff, Text("Content"), LF, Cut
        #expect(commands.count == 9)
        #expect(commands[0] == .initialize)
        #expect(commands[1] == .justification(.center))
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
        #expect(commands[8] == .cut(.full))
    }

    @Test("QR code commands")
    mutating func testQRCodeCommands() {
        // QR code size: GS ( k pL pH cn fn n
        let sizeCmd = Data([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, 0x08])
        let commands = decoder.decode(sizeCmd)
        #expect(commands == [.qrCodeSize(moduleSize: 8)])
    }

    @Test("QR code error correction")
    mutating func testQRCodeErrorCorrection() {
        // GS ( k pL pH cn fn n (error correction L)
        let ecCmd = Data([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, 0x30])
        let commands = decoder.decode(ecCmd)
        #expect(commands == [.qrCodeErrorCorrection(level: .l)])
    }

    @Test("QR code store")
    mutating func testQRCodeStore() {
        // GS ( k pL pH cn fn m d1...dk
        let text = "https://example.com"
        let textData = Data(text.utf8)
        let length = 3 + textData.count  // cn + fn + m + data
        var storeCmd = Data([0x1D, 0x28, 0x6B, UInt8(length & 0xFF), UInt8((length >> 8) & 0xFF), 0x31, 0x50, 0x30])
        storeCmd.append(textData)
        let commands = decoder.decode(storeCmd)
        #expect(commands.count == 1)
        if case .qrCodeStore(let data) = commands[0] {
            #expect(data == textData)
            #expect(String(data: data, encoding: .utf8) == text)
        } else {
            Issue.record("Expected qrCodeStore command")
        }
    }

    @Test("QR code print")
    mutating func testQRCodePrint() {
        // GS ( k pL pH cn fn m
        let printCmd = Data([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30])
        let commands = decoder.decode(printCmd)
        #expect(commands == [.qrCodePrint])
    }

    @Test("Raster image")
    mutating func testRasterImage() {
        // GS v 0 m xL xH yL yH d1...dk
        // 2x2 pixels (2 bytes width = 16 pixels, 2 lines)
        var data = Data([0x1D, 0x76, 0x30, 0x00, 0x02, 0x00, 0x02, 0x00])
        data.append(contentsOf: [0xFF, 0x00, 0x00, 0xFF])  // 4 bytes of image data
        let commands = decoder.decode(data)
        #expect(commands.count == 1)
        if case .rasterImage(let mode, let width, let height, let imageData) = commands[0] {
            #expect(mode == .normal)
            #expect(width == 2)
            #expect(height == 2)
            #expect(imageData.count == 4)
        } else {
            Issue.record("Expected raster image command")
        }
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

    @Test("Rotate 90 degrees")
    mutating func testRotate90() {
        let on = Data([0x1B, 0x56, 0x01])   // ESC V 1
        let off = Data([0x1B, 0x56, 0x00])  // ESC V 0
        #expect(decoder.decode(on) == [.rotate90(enabled: true)])
        #expect(decoder.decode(off) == [.rotate90(enabled: false)])
    }

    @Test("Upside down mode")
    mutating func testUpsideDown() {
        let on = Data([0x1B, 0x7B, 0x01])   // ESC { 1
        let off = Data([0x1B, 0x7B, 0x00])  // ESC { 0
        #expect(decoder.decode(on) == [.upsideDown(enabled: true)])
        #expect(decoder.decode(off) == [.upsideDown(enabled: false)])
    }

    @Test("Kanji code system selection")
    mutating func testKanjiCodeSystem() {
        // FS C 0 - JIS
        let jis = Data([0x1C, 0x43, 0x00])
        #expect(decoder.decode(jis) == [.selectKanjiCodeSystem(.jis)])

        // FS C 1 - Shift JIS
        let shiftJIS = Data([0x1C, 0x43, 0x01])
        #expect(decoder.decode(shiftJIS) == [.selectKanjiCodeSystem(.shiftJIS)])

        // FS C 2 - Shift_JIS-2004
        let shiftJIS2004 = Data([0x1C, 0x43, 0x02])
        #expect(decoder.decode(shiftJIS2004) == [.selectKanjiCodeSystem(.shiftJIS2004)])

        // FS C '0' (48) - JIS (文字コード)
        let jisChar = Data([0x1C, 0x43, 0x30])
        #expect(decoder.decode(jisChar) == [.selectKanjiCodeSystem(.jis)])

        // FS C '1' (49) - Shift JIS (文字コード)
        let shiftJISChar = Data([0x1C, 0x43, 0x31])
        #expect(decoder.decode(shiftJISChar) == [.selectKanjiCodeSystem(.shiftJIS)])

        // FS C '2' (50) - Shift_JIS-2004 (文字コード)
        let shiftJIS2004Char = Data([0x1C, 0x43, 0x32])
        #expect(decoder.decode(shiftJIS2004Char) == [.selectKanjiCodeSystem(.shiftJIS2004)])
    }

    // MARK: - プロセスIDレスポンス (GS ( H fn=48)

    @Test("Realtime status request")
    mutating func testRealtimeStatusRequest() {
        // DLE EOT n
        let data = Data([0x10, 0x04, 0x01])
        let commands = decoder.decode(data)
        #expect(commands == [.realtimeStatusRequest(type: 1)])
    }

    @Test("Request process ID response")
    mutating func testRequestProcessIdResponse() {
        // GS ( H pL pH fn m d1 d2 d3 d4
        // 1D 28 48 06 00 30 30 30 30 30 31  = processId "0001"
        let data = Data([0x1D, 0x28, 0x48, 0x06, 0x00, 0x30, 0x30, 0x30, 0x30, 0x30, 0x31])
        let commands = decoder.decode(data)
        #expect(commands == [.requestProcessIdResponse(d1: 0x30, d2: 0x30, d3: 0x30, d4: 0x31)])
    }

    @Test("Request process ID response with printable ASCII range")
    mutating func testRequestProcessIdResponseASCIIRange() {
        // d1=32(' '), d2=126('~'), d3=65('A'), d4=90('Z')
        let data = Data([0x1D, 0x28, 0x48, 0x06, 0x00, 0x30, 0x30, 0x20, 0x7E, 0x41, 0x5A])
        let commands = decoder.decode(data)
        #expect(commands == [.requestProcessIdResponse(d1: 0x20, d2: 0x7E, d3: 0x41, d4: 0x5A)])
    }

    @Test("Enable automatic status")
    mutating func testEnableAutomaticStatus() {
        let data = Data([0x1D, 0x61, 0xFF])  // GS a 0xFF
        let commands = decoder.decode(data)
        #expect(commands == [.enableAutomaticStatus(flags: 0xFF)])
    }

    @Test("Printer info request")
    mutating func testPrinterInfoRequest() {
        let data = Data([0x1D, 0x49, 0x01])  // GS I 1
        let commands = decoder.decode(data)
        #expect(commands == [.printerInfoRequest(type: 0x01)])
    }

    @Test("Unknown FS command")
    mutating func testUnknownFSCommand() {
        let unknown = Data([0x1C, 0xFF])  // Unknown FS command
        let commands = decoder.decode(unknown)
        #expect(commands.count == 1)
        if case .unknown(let data) = commands[0] {
            #expect(data == Data([0x1C, 0xFF]))
        } else {
            Issue.record("Expected unknown command")
        }
    }

    // MARK: - receiptio 互換性テスト

    @Test("ESC t n decodes as selectCharacterCodeTable")
    mutating func testESCt() {
        let data = Data([0x1B, 0x74, 0x01])  // ESC t 1
        let commands = decoder.decode(data)
        #expect(commands == [.selectCharacterCodeTable(page: 1)])
    }

    @Test("ESC r n - Print color selection")
    mutating func testESCr() {
        // ESC r 0 = 黒
        let black = Data([0x1B, 0x72, 0x00])
        #expect(decoder.decode(black) == [.selectPrintColor(.black)])

        // ESC r 1 = 赤
        let red = Data([0x1B, 0x72, 0x01])
        #expect(decoder.decode(red) == [.selectPrintColor(.red)])

        // ESC r 48 ('0') = 黒
        let blackChar = Data([0x1B, 0x72, 0x30])
        #expect(decoder.decode(blackChar) == [.selectPrintColor(.black)])

        // ESC r 49 ('1') = 赤
        let redChar = Data([0x1B, 0x72, 0x31])
        #expect(decoder.decode(redChar) == [.selectPrintColor(.red)])

        // 未定義値 → unknown
        let invalid = Data([0x1B, 0x72, 0xFF])
        let cmds = decoder.decode(invalid)
        #expect(cmds.count == 1)
        if case .unknown(let d) = cmds[0] {
            #expect(d == Data([0x1B, 0x72, 0xFF]))
        } else {
            Issue.record("Expected unknown for invalid ESC r value")
        }
    }

    @Test("ESC R n - International character set selection")
    mutating func testESCR() {
        // ESC R 8 = Japan
        let japan = Data([0x1B, 0x52, 0x08])
        #expect(decoder.decode(japan) == [.selectInternationalCharacterSet(.japan)])

        // ESC R 0 = USA
        let usa = Data([0x1B, 0x52, 0x00])
        #expect(decoder.decode(usa) == [.selectInternationalCharacterSet(.usa)])

        // ESC R 13 = Korea
        let korea = Data([0x1B, 0x52, 0x0D])
        #expect(decoder.decode(korea) == [.selectInternationalCharacterSet(.korea)])

        // ESC R 66 = India (Devanagari)
        let india = Data([0x1B, 0x52, 0x42])
        #expect(decoder.decode(india) == [.selectInternationalCharacterSet(.indiaDevanagari)])

        // ESC R 82 = India (Marathi)
        let marathi = Data([0x1B, 0x52, 0x52])
        #expect(decoder.decode(marathi) == [.selectInternationalCharacterSet(.indiaMarathi)])

        // 未定義値 → unknown
        let invalid = Data([0x1B, 0x52, 0xFF])
        let cmds = decoder.decode(invalid)
        #expect(cmds.count == 1)
        if case .unknown(let d) = cmds[0] {
            #expect(d == Data([0x1B, 0x52, 0xFF]))
        } else {
            Issue.record("Expected unknown for invalid ESC R value")
        }
    }

    @Test("FS - n decodes kanji underline")
    mutating func testFSHyphen() {
        // n = 0x30 ('0') → off
        let data0 = Data([0x1C, 0x2D, 0x30])
        let cmds0 = decoder.decode(data0)
        #expect(cmds0 == [.kanjiUnderline(.off)])

        // n = 1 → single
        let data1 = Data([0x1C, 0x2D, 0x01])
        let cmds1 = decoder.decode(data1)
        #expect(cmds1 == [.kanjiUnderline(.single)])

        // n = 2 → double
        let data2 = Data([0x1C, 0x2D, 0x02])
        let cmds2 = decoder.decode(data2)
        #expect(cmds2 == [.kanjiUnderline(.double)])

        // n = 0x32 ('2') → double
        let data50 = Data([0x1C, 0x2D, 0x32])
        let cmds50 = decoder.decode(data50)
        #expect(cmds50 == [.kanjiUnderline(.double)])

        // 不正な値 → unknown
        let dataInvalid = Data([0x1C, 0x2D, 0xFF])
        let cmdsInvalid = decoder.decode(dataInvalid)
        #expect(cmdsInvalid.count == 1)
        if case .unknown = cmdsInvalid[0] {
            // OK
        } else {
            Issue.record("Expected unknown for invalid FS - value")
        }
    }

    @Test("ESC E 0x30 is boldOff (LSB check)")
    mutating func testBoldLSB() {
        let data = Data([0x1B, 0x45, 0x30])  // ESC E '0' (0x30)
        let commands = decoder.decode(data)
        #expect(commands == [.boldOff])
    }

    @Test("GS B 0x30 is reverseMode disabled (LSB check)")
    mutating func testReverseLSB() {
        let data = Data([0x1D, 0x42, 0x30])  // GS B '0' (0x30)
        let commands = decoder.decode(data)
        #expect(commands == [.reverseMode(enabled: false)])
    }

    @Test("ESC - 0x30 is underline off (ASCII value)")
    mutating func testUnderlineASCII() {
        let off = Data([0x1B, 0x2D, 0x30])   // ESC - '0'
        let single = Data([0x1B, 0x2D, 0x31])  // ESC - '1'
        let double = Data([0x1B, 0x2D, 0x32])  // ESC - '2'
        #expect(decoder.decode(off) == [.underline(.off)])
        #expect(decoder.decode(single) == [.underline(.single)])
        #expect(decoder.decode(double) == [.underline(.double)])
    }

    // MARK: - 第2弾: 位置制御・漢字・ステータス

    @Test("ESC $ nL nH - Absolute position")
    mutating func testAbsolutePosition() {
        // ESC $ 0x80 0x01 = 384 dots
        let data = Data([0x1B, 0x24, 0x80, 0x01])
        let commands = decoder.decode(data)
        #expect(commands == [.absolutePosition(dots: 0x0180)])
    }

    @Test("ESC \\ nL nH - Relative position")
    mutating func testRelativePosition() {
        // ESC \ 0x20 0x00 = 32 dots
        let data = Data([0x1B, 0x5C, 0x20, 0x00])
        let commands = decoder.decode(data)
        #expect(commands == [.relativePosition(dots: 32)])
    }

    @Test("ESC \\ negative relative position")
    mutating func testRelativePositionNegative() {
        // ESC \ 0xE0 0xFF = -32 (signed)
        let data = Data([0x1B, 0x5C, 0xE0, 0xFF])
        let commands = decoder.decode(data)
        #expect(commands == [.relativePosition(dots: -32)])
    }

    @Test("ESC SP n - Character spacing")
    mutating func testCharacterSpacing() {
        let data = Data([0x1B, 0x20, 0x04])  // ESC SP 4
        let commands = decoder.decode(data)
        #expect(commands == [.characterSpacing(dots: 4)])
    }

    @Test("FS S n1 n2 - Kanji double size")
    mutating func testKanjiDoubleSize() {
        let data = Data([0x1C, 0x53, 0x01, 0x02])  // FS S 1 2
        let commands = decoder.decode(data)
        #expect(commands == [.kanjiDoubleSize(width: 1, height: 2)])
    }

    @Test("FS & - Select kanji mode")
    mutating func testSelectKanjiMode() {
        let data = Data([0x1C, 0x26])  // FS &
        let commands = decoder.decode(data)
        #expect(commands == [.selectKanjiMode])
    }

    @Test("FS . - Cancel kanji mode")
    mutating func testCancelKanjiMode() {
        let data = Data([0x1C, 0x2E])  // FS .
        let commands = decoder.decode(data)
        #expect(commands == [.cancelKanjiMode])
    }

    @Test("FS & and FS . roundtrip")
    mutating func testKanjiModeRoundtrip() {
        let encoder = ESCPOSEncoder()
        // selectKanjiMode
        let encoded1 = encoder.encode(.selectKanjiMode)
        var decoder1 = ESCPOSDecoder()
        let decoded1 = decoder1.decode(encoded1)
        #expect(decoded1 == [.selectKanjiMode])
        // cancelKanjiMode
        let encoded2 = encoder.encode(.cancelKanjiMode)
        var decoder2 = ESCPOSDecoder()
        let decoded2 = decoder2.decode(encoded2)
        #expect(decoded2 == [.cancelKanjiMode])
    }

    @Test("GS r n - Transmit print status")
    mutating func testTransmitPrintStatus() {
        let data = Data([0x1D, 0x72, 0x01])  // GS r 1
        let commands = decoder.decode(data)
        #expect(commands == [.transmitPrintStatus(type: 1)])
    }

    @Test("GS r needs response")
    mutating func testTransmitPrintStatusNeedsResponse() {
        let cmd = ESCPOSCommand.transmitPrintStatus(type: 1)
        #expect(cmd.needsResponse == true)
    }

    @Test("ESC ACK n consumed as unknown (3 bytes)")
    mutating func testESCACK() {
        // ESC ACK n followed by text — should not leak parameter
        let data = Data([0x1B, 0x06, 0x01, 0x41])  // ESC ACK 1 + "A"
        let commands = decoder.decode(data)
        #expect(commands.count == 2)
        if case .unknown(let d) = commands[0] {
            #expect(d == Data([0x1B, 0x06, 0x01]))
        } else {
            Issue.record("Expected unknown command for ESC ACK")
        }
        #expect(commands[1] == .text(Data([0x41])))
    }

    // MARK: - receiptio normal() 統合テスト

    @Test("receiptio normal() sequence does not leak parameter bytes")
    mutating func testReceiptioNormalSequence() {
        // receiptio が送信する典型的なコマンドシーケンス（簡略版）
        var data = Data()
        // ESC @ - 初期化
        data.append(contentsOf: [0x1B, 0x40])
        // ESC t 0 - 文字コードテーブル
        data.append(contentsOf: [0x1B, 0x74, 0x00])
        // ESC R 8 - 国際文字セット
        data.append(contentsOf: [0x1B, 0x52, 0x08])
        // FS C 1 - 漢字コード体系
        data.append(contentsOf: [0x1C, 0x43, 0x01])
        // FS . - 漢字モード解除
        data.append(contentsOf: [0x1C, 0x2E])
        // ESC SP 0 - 文字間スペース
        data.append(contentsOf: [0x1B, 0x20, 0x00])
        // ESC E '0' - 太字OFF
        data.append(contentsOf: [0x1B, 0x45, 0x30])
        // ESC - '0' - アンダーラインOFF
        data.append(contentsOf: [0x1B, 0x2D, 0x30])
        // GS B '0' - 反転OFF
        data.append(contentsOf: [0x1D, 0x42, 0x30])
        // ESC a 1 - センタリング
        data.append(contentsOf: [0x1B, 0x61, 0x01])
        // GS ! 0x00 - 通常サイズ
        data.append(contentsOf: [0x1D, 0x21, 0x00])
        // テキスト + LF
        data.append(contentsOf: "Store Name".utf8)
        data.append(0x0A)
        // ESC $ 0 0 - 絶対位置0
        data.append(contentsOf: [0x1B, 0x24, 0x00, 0x00])
        // テキスト + LF
        data.append(contentsOf: "Item".utf8)
        data.append(0x0A)
        // GS r 1 - 印刷ステータス
        data.append(contentsOf: [0x1D, 0x72, 0x01])
        // GS V B 0 - カット
        data.append(contentsOf: [0x1D, 0x56, 0x42, 0x00])

        let commands = decoder.decode(data)

        // テキストコマンドがパラメータバイトを含んでいないことを確認
        for command in commands {
            if case .text(let textData) = command {
                let text = String(data: textData, encoding: .utf8) ?? ""
                // テキストは可読文字のみで構成されるべき
                for char in text.unicodeScalars {
                    #expect(char.value >= 0x20, "Text contains control character: \\(\(char.value))")
                }
            }
        }

        // 特定のコマンドが正しくデコードされていることを確認
        #expect(commands.contains(.initialize))
        #expect(commands.contains(.selectInternationalCharacterSet(.japan)))
        #expect(commands.contains(.cancelKanjiMode))
        #expect(commands.contains(.characterSpacing(dots: 0)))
        #expect(commands.contains(.absolutePosition(dots: 0)))
        #expect(commands.contains(.transmitPrintStatus(type: 1)))
        #expect(commands.contains(.cutWithFeed(mode: .partialWithFeed, feed: 0)))
    }

    @Test("Character encoding type selection (FS ( C fn=48)")
    mutating func testCharacterEncodingTypeSelection() {
        // コードページ方式 (m=1)
        let codePage = Data([0x1C, 0x28, 0x43, 0x02, 0x00, 0x30, 0x01])
        #expect(decoder.decode(codePage) == [.selectCharacterEncoding(.codePage)])

        // UTF-8方式 (m=2)
        let utf8 = Data([0x1C, 0x28, 0x43, 0x02, 0x00, 0x30, 0x02])
        #expect(decoder.decode(utf8) == [.selectCharacterEncoding(.utf8)])

        // ASCII文字コードによる指定 (m=49='1' → codePage)
        let codePageAscii = Data([0x1C, 0x28, 0x43, 0x02, 0x00, 0x30, 0x31])
        #expect(decoder.decode(codePageAscii) == [.selectCharacterEncoding(.codePage)])

        // ASCII文字コードによる指定 (m=50='2' → utf8)
        let utf8Ascii = Data([0x1C, 0x28, 0x43, 0x02, 0x00, 0x30, 0x32])
        #expect(decoder.decode(utf8Ascii) == [.selectCharacterEncoding(.utf8)])

        // 不正なm値 → unknown
        let invalidM = Data([0x1C, 0x28, 0x43, 0x02, 0x00, 0x30, 0x05])
        let result = decoder.decode(invalidM)
        #expect(result.count == 1)
        if case .unknown = result.first {} else {
            Issue.record("Expected .unknown but got \(String(describing: result.first))")
        }
    }

    @Test("Character encoding type - incomplete data")
    mutating func testCharacterEncodingTypeIncompleteData() {
        // 不完全なデータ — バッファに保持される
        let incomplete = Data([0x1C, 0x28, 0x43, 0x02, 0x00])
        let result = decoder.decode(incomplete)
        #expect(result.isEmpty)
        #expect(decoder.pendingBuffer == incomplete)
    }
}
