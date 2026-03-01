import Testing
import Foundation
@testable import PrinterSimulator
import ThermalPrinterCommand

@Suite("TextReceiptRenderer Tests")
struct TextReceiptRendererTests {

    private func makeSimulator(ansiStyleEnabled: Bool = true, sixelEnabled: Bool = false) -> (ESCPOSPrinterSimulator, () -> [String]) {
        var lines: [String] = []
        var renderer = TextReceiptRenderer(ansiStyleEnabled: ansiStyleEnabled, sixelEnabled: sixelEnabled)
        renderer.outputLine = { lines.append($0) }
        let simulator = ESCPOSPrinterSimulator(renderer: renderer)
        return (simulator, { lines })
    }

    // MARK: - テキスト出力

    @Test("text + lineFeed で行が出力される")
    func textOutput() {
        var (simulator, getLines) = makeSimulator()
        _ = simulator.process([.text(Data("Hello".utf8)), .lineFeed])
        let lines = getLines()
        #expect(lines.count == 1)
        #expect(lines[0] == "Hello")
    }

    // MARK: - 太字

    @Test("boldOn で ANSI 太字コード付きで出力される")
    func boldText() {
        var (simulator, getLines) = makeSimulator()
        _ = simulator.process([.boldOn, .text(Data("Bold".utf8)), .lineFeed])
        let lines = getLines()
        #expect(lines.count == 1)
        #expect(lines[0].contains(TextReceiptRenderer.ansiBoldOn))
        #expect(lines[0].contains("Bold"))
        #expect(lines[0].hasSuffix(TextReceiptRenderer.ansiReset))
    }

    // MARK: - 下線

    @Test("underline(.single) で ANSI 下線コード付きで出力される")
    func underlineText() {
        var (simulator, getLines) = makeSimulator()
        _ = simulator.process([.underline(.single), .text(Data("Underlined".utf8)), .lineFeed])
        let lines = getLines()
        #expect(lines.count == 1)
        #expect(lines[0].contains(TextReceiptRenderer.ansiUnderlineOn))
        #expect(lines[0].contains("Underlined"))
        #expect(lines[0].hasSuffix(TextReceiptRenderer.ansiReset))
    }

    // MARK: - 反転

    @Test("reverseMode(true) で ANSI 反転コード付きで出力される")
    func reverseText() {
        var (simulator, getLines) = makeSimulator()
        _ = simulator.process([.reverseMode(enabled: true), .text(Data("Reversed".utf8)), .lineFeed])
        let lines = getLines()
        #expect(lines.count == 1)
        #expect(lines[0].contains(TextReceiptRenderer.ansiReverseOn))
        #expect(lines[0].contains("Reversed"))
        #expect(lines[0].hasSuffix(TextReceiptRenderer.ansiReset))
    }

    // MARK: - 中央揃え

    @Test("justification(.center) でパディング付きで出力される")
    func centerJustification() {
        var (simulator, getLines) = makeSimulator()
        _ = simulator.process([.justification(.center), .text(Data("Center".utf8)), .lineFeed])
        let lines = getLines()
        #expect(lines.count == 1)
        let expectedPadding = (48 - 6) / 2
        #expect(lines[0].hasPrefix(String(repeating: " ", count: expectedPadding)))
        #expect(lines[0].contains("Center"))
    }

    // MARK: - 右揃え

    @Test("justification(.right) でパディング付きで出力される")
    func rightJustification() {
        var (simulator, getLines) = makeSimulator()
        _ = simulator.process([.justification(.right), .text(Data("Right".utf8)), .lineFeed])
        let lines = getLines()
        #expect(lines.count == 1)
        let expectedPadding = 48 - 5
        #expect(lines[0].hasPrefix(String(repeating: " ", count: expectedPadding)))
        #expect(lines[0].contains("Right"))
    }

    // MARK: - 初期化

    @Test("initialize で [PRINTER INITIALIZED] が中央揃えで出力される")
    func initializeCommand() {
        var (simulator, getLines) = makeSimulator()
        _ = simulator.process([.initialize])
        let lines = getLines()
        #expect(lines.count == 1)
        let text = "[PRINTER INITIALIZED]"
        let expectedPadding = (48 - text.count) / 2
        #expect(lines[0] == String(repeating: " ", count: expectedPadding) + text)
    }

    // MARK: - フルカット

    @Test("cut(.full) で FULL CUT が中央揃えで出力される")
    func fullCut() {
        var (simulator, getLines) = makeSimulator()
        _ = simulator.process([.cut(.full)])
        let lines = getLines()
        let text = "--- ✂ FULL CUT ---"
        let expectedPadding = (48 - text.count) / 2
        #expect(lines.last == String(repeating: " ", count: expectedPadding) + text)
    }

    // MARK: - パーシャルカット

    @Test("cut(.partial) で PARTIAL CUT が中央揃えで出力される")
    func partialCut() {
        var (simulator, getLines) = makeSimulator()
        _ = simulator.process([.cut(.partial)])
        let lines = getLines()
        let text = "--- ✂ PARTIAL CUT ---"
        let expectedPadding = (48 - text.count) / 2
        #expect(lines.last == String(repeating: " ", count: expectedPadding) + text)
    }

    // MARK: - バーコード

    @Test("barcode で CODE128 フォーマットが中央揃えで出力される")
    func barcodeOutput() {
        var (simulator, getLines) = makeSimulator()
        _ = simulator.process([.barcode(type: .code128, data: Data("12345".utf8))])
        let lines = getLines()
        let text = "[CODE128] ||| 12345 |||"
        let expectedPadding = (48 - text.count) / 2
        #expect(lines.last == String(repeating: " ", count: expectedPadding) + text)
    }

    // MARK: - QRコード

    @Test("qrCodePrint で QR CODE が中央揃えで出力される")
    func qrCodeOutput() {
        var (simulator, getLines) = makeSimulator()
        _ = simulator.process([.qrCodeStore(data: Data("https://example.com".utf8)), .qrCodePrint])
        let lines = getLines()
        let text = "[QR CODE: https://example.com]"
        let expectedPadding = (48 - text.count) / 2
        #expect(lines.last == String(repeating: " ", count: expectedPadding) + text)
    }

    @Test("sixelEnabled=true: QRコードがSixel形式で出力される")
    func qrCodeSixel() {
        var (simulator, getLines) = makeSimulator(sixelEnabled: true)
        _ = simulator.process([.qrCodeStore(data: Data("https://example.com".utf8)), .qrCodePrint])
        let lines = getLines()
        #expect(lines.last?.hasPrefix("\u{1B}P0;1;q") == true)
        #expect(lines.last?.hasSuffix("\u{1B}\\") == true)
    }

    @Test("sixelEnabled=true: qrCodeSizeがSixel出力のモジュールサイズに反映される")
    func qrCodeModuleSizeAffectsSixel() {
        var (sim1, get1) = makeSimulator(sixelEnabled: true)
        _ = sim1.process([.qrCodeSize(moduleSize: 2), .qrCodeStore(data: Data("TEST".utf8)), .qrCodePrint])
        let sixel1 = get1().last ?? ""

        var (sim2, get2) = makeSimulator(sixelEnabled: true)
        _ = sim2.process([.qrCodeSize(moduleSize: 6), .qrCodeStore(data: Data("TEST".utf8)), .qrCodePrint])
        let sixel2 = get2().last ?? ""

        #expect(sixel1.count < sixel2.count)
    }

    @Test("sixelEnabled=true: qrCodePrint後にデータがクリアされる")
    func qrCodeDataClearedAfterPrint() {
        var (simulator, getLines) = makeSimulator(sixelEnabled: true)
        _ = simulator.process([.qrCodeStore(data: Data("TEST".utf8)), .qrCodePrint, .qrCodePrint])
        let lines = getLines()
        let sixelCount = lines.filter { $0.contains("\u{1B}P0;1;q") }.count
        #expect(sixelCount == 1)
    }

    // MARK: - 画像

    @Test("rasterImage で IMAGE サイズが中央揃えで出力される")
    func rasterImageOutput() {
        var (simulator, getLines) = makeSimulator()
        _ = simulator.process([.rasterImage(mode: .normal, width: 6, height: 100, data: Data())])
        let lines = getLines()
        let text = "[IMAGE: 48x100 dots]"
        let expectedPadding = (48 - text.count) / 2
        #expect(lines.last == String(repeating: " ", count: expectedPadding) + text)
    }

    // MARK: - キャッシュドロワー

    @Test("openCashDrawer で CASH DRAWER OPEN が中央揃えで出力される")
    func cashDrawerOutput() {
        var (simulator, getLines) = makeSimulator()
        _ = simulator.process([.openCashDrawer(pin: 0, onTime: 1, offTime: 1)])
        let lines = getLines()
        #expect(lines.count == 1)
        let text = "[CASH DRAWER OPEN]"
        let expectedPadding = (48 - text.count) / 2
        #expect(lines[0] == String(repeating: " ", count: expectedPadding) + text)
    }

    // MARK: - 状態リセット

    @Test("initialize 後に bold 等がリセットされる")
    func initializeResetsState() {
        var (simulator, getLines) = makeSimulator()
        _ = simulator.process([
            .boldOn,
            .underline(.single),
            .reverseMode(enabled: true),
            .justification(.center),
            .characterSize(width: 2, height: 2),
            .initialize,
            .text(Data("Plain".utf8)),
            .lineFeed,
        ])

        let lines = getLines()
        #expect(lines.count == 2)
        #expect(lines[1] == "Plain")
    }

    // MARK: - ansiStyleEnabled

    @Test("ansiStyleEnabled=false: boldOnでもANSIコードが付かない")
    func boldWithoutAnsi() {
        var (simulator, getLines) = makeSimulator(ansiStyleEnabled: false)
        _ = simulator.process([.boldOn, .text(Data("Bold".utf8)), .lineFeed])
        let lines = getLines()
        #expect(lines.count == 1)
        #expect(lines[0] == "Bold")
        #expect(!lines[0].contains("\u{1B}"))
    }

    @Test("ansiStyleEnabled=false: underlineでもANSIコードが付かない")
    func underlineWithoutAnsi() {
        var (simulator, getLines) = makeSimulator(ansiStyleEnabled: false)
        _ = simulator.process([.underline(.single), .text(Data("Underlined".utf8)), .lineFeed])
        let lines = getLines()
        #expect(lines.count == 1)
        #expect(lines[0] == "Underlined")
        #expect(!lines[0].contains("\u{1B}"))
    }

    @Test("ansiStyleEnabled=false: reverseModeでもANSIコードが付かない")
    func reverseWithoutAnsi() {
        var (simulator, getLines) = makeSimulator(ansiStyleEnabled: false)
        _ = simulator.process([.reverseMode(enabled: true), .text(Data("Reversed".utf8)), .lineFeed])
        let lines = getLines()
        #expect(lines.count == 1)
        #expect(lines[0] == "Reversed")
        #expect(!lines[0].contains("\u{1B}"))
    }

    @Test("ansiStyleEnabled=false: 複数の装飾を同時に有効にしてもANSIコードが付かない")
    func multipleStylesWithoutAnsi() {
        var (simulator, getLines) = makeSimulator(ansiStyleEnabled: false)
        _ = simulator.process([
            .boldOn,
            .underline(.double),
            .reverseMode(enabled: true),
            .text(Data("Styled".utf8)),
            .lineFeed,
        ])
        let lines = getLines()
        #expect(lines.count == 1)
        #expect(lines[0] == "Styled")
        #expect(!lines[0].contains("\u{1B}"))
    }

    // MARK: - Sixel画像出力

    @Test("sixelEnabled=false: rasterImageでプレースホルダーが出力される")
    func rasterImagePlaceholder() {
        var (simulator, getLines) = makeSimulator(sixelEnabled: false)
        let imageData = Data(repeating: 0xFF, count: 6)
        _ = simulator.process([.rasterImage(mode: .normal, width: 1, height: 6, data: imageData)])
        let lines = getLines()
        #expect(lines.last?.contains("[IMAGE:") == true)
    }

    @Test("sixelEnabled=true: rasterImageでDCS...ST形式のSixel出力が得られる")
    func rasterImageSixel() {
        var (simulator, getLines) = makeSimulator(sixelEnabled: true)
        let imageData = Data(repeating: 0xFF, count: 6)
        _ = simulator.process([.rasterImage(mode: .normal, width: 1, height: 6, data: imageData)])
        let lines = getLines()
        #expect(lines.last?.hasPrefix("\u{1B}P0;1;q") == true)
        #expect(lines.last?.hasSuffix("\u{1B}\\") == true)
    }

    @Test("sixelEnabled=true: graphicsStoreでSixel出力が得られる")
    func graphicsStoreSixel() {
        var (simulator, getLines) = makeSimulator(sixelEnabled: true)
        let imageData = Data(repeating: 0xFF, count: 6)
        _ = simulator.process([.graphicsStore(
            tone: .monochrome, scaleX: 1, scaleY: 1, color: .color1,
            width: 8, height: 6, data: imageData
        )])
        let lines = getLines()
        #expect(lines.last?.hasPrefix("\u{1B}P0;1;q") == true)
        #expect(lines.last?.hasSuffix("\u{1B}\\") == true)
    }

    @Test("sixelEnabled=true: graphicsStoreのwidthが8の倍数でなくても正しく変換される")
    func graphicsStoreNonAlignedWidth() {
        var (simulator, getLines) = makeSimulator(sixelEnabled: true)
        let imageData = Data(repeating: 0xFF, count: 2)
        _ = simulator.process([.graphicsStore(
            tone: .monochrome, scaleX: 1, scaleY: 1, color: .color1,
            width: 12, height: 1, data: imageData
        )])
        let lines = getLines()
        #expect(lines.last?.hasPrefix("\u{1B}P0;1;q") == true)
        #expect(lines.last?.contains("\"1;1;16;1") == true)
    }

    // MARK: - バーコードSixel出力

    @Test("sixelEnabled=true: CODE128バーコードがSixel形式で出力される")
    func barcodeSixelCode128() {
        var (simulator, getLines) = makeSimulator(sixelEnabled: true)
        _ = simulator.process([.barcode(type: .code128, data: Data("12345".utf8))])
        let lines = getLines()
        #expect(lines.last?.hasPrefix("\u{1B}P0;1;q") == true)
        #expect(lines.last?.hasSuffix("\u{1B}\\") == true)
    }

    @Test("sixelEnabled=true: EAN13バーコードがSixel形式で出力される")
    func barcodeSixelEAN13() {
        var (simulator, getLines) = makeSimulator(sixelEnabled: true)
        _ = simulator.process([.barcode(type: .ean13, data: Data("4901234567894".utf8))])
        let lines = getLines()
        #expect(lines.last?.hasPrefix("\u{1B}P0;1;q") == true)
    }

    @Test("sixelEnabled=true: EAN8バーコードがSixel形式で出力される")
    func barcodeSixelEAN8() {
        var (simulator, getLines) = makeSimulator(sixelEnabled: true)
        _ = simulator.process([.barcode(type: .ean8, data: Data("12345670".utf8))])
        let lines = getLines()
        #expect(lines.last?.hasPrefix("\u{1B}P0;1;q") == true)
    }

    @Test("sixelEnabled=true: CODE39バーコードがSixel形式で出力される")
    func barcodeSixelCode39() {
        var (simulator, getLines) = makeSimulator(sixelEnabled: true)
        _ = simulator.process([.barcode(type: .code39, data: Data("ABC123".utf8))])
        let lines = getLines()
        #expect(lines.last?.hasPrefix("\u{1B}P0;1;q") == true)
    }

    @Test("sixelEnabled=true: ITFバーコードがSixel形式で出力される")
    func barcodeSixelITF() {
        var (simulator, getLines) = makeSimulator(sixelEnabled: true)
        _ = simulator.process([.barcode(type: .itf, data: Data("1234567890".utf8))])
        let lines = getLines()
        #expect(lines.last?.hasPrefix("\u{1B}P0;1;q") == true)
    }

    @Test("sixelEnabled=true: CODABARバーコードがSixel形式で出力される")
    func barcodeSixelCodabar() {
        var (simulator, getLines) = makeSimulator(sixelEnabled: true)
        _ = simulator.process([.barcode(type: .codabar, data: Data("A12345B".utf8))])
        let lines = getLines()
        #expect(lines.last?.hasPrefix("\u{1B}P0;1;q") == true)
    }

    @Test("sixelEnabled=true: CODE93バーコードがSixel形式で出力される")
    func barcodeSixelCode93() {
        var (simulator, getLines) = makeSimulator(sixelEnabled: true)
        _ = simulator.process([.barcode(type: .code93, data: Data("12345".utf8))])
        let lines = getLines()
        #expect(lines.last?.hasPrefix("\u{1B}P0;1;q") == true)
    }

    @Test("sixelEnabled=true: UPC-Aバーコードがsixel形式で出力される")
    func barcodeSixelUPCA() {
        var (simulator, getLines) = makeSimulator(sixelEnabled: true)
        _ = simulator.process([.barcode(type: .upcA, data: Data("012345678905".utf8))])
        let lines = getLines()
        #expect(lines.last?.hasPrefix("\u{1B}P0;1;q") == true)
    }

    @Test("sixelEnabled=true: UPC-Eバーコードがsixel形式で出力される")
    func barcodeSixelUPCE() {
        var (simulator, getLines) = makeSimulator(sixelEnabled: true)
        _ = simulator.process([.barcode(type: .upcE, data: Data("123456".utf8))])
        let lines = getLines()
        #expect(lines.last?.hasPrefix("\u{1B}P0;1;q") == true)
    }

    @Test("sixelEnabled=false: バーコードは従来のテキスト形式で出力される")
    func barcodeFallbackWhenSixelDisabled() {
        var (simulator, getLines) = makeSimulator(sixelEnabled: false)
        _ = simulator.process([.barcode(type: .code128, data: Data("12345".utf8))])
        let lines = getLines()
        let text = "[CODE128] ||| 12345 |||"
        let expectedPadding = (48 - text.count) / 2
        #expect(lines.last == String(repeating: " ", count: expectedPadding) + text)
    }

    @Test("barcodeHeight設定がSixel出力のサイズに反映される")
    func barcodeHeightAffectsSixel() {
        var (sim1, getLines1) = makeSimulator(sixelEnabled: true)
        _ = sim1.process([.barcodeHeight(dots: 50), .barcode(type: .code128, data: Data("ABC".utf8))])
        let sixel1 = getLines1().last ?? ""

        var (sim2, getLines2) = makeSimulator(sixelEnabled: true)
        _ = sim2.process([.barcodeHeight(dots: 100), .barcode(type: .code128, data: Data("ABC".utf8))])
        let sixel2 = getLines2().last ?? ""

        #expect(sixel1.count < sixel2.count)
    }

    @Test("barcodeHRIPosition(.below)でバーコード下にHRIテキストが出力される")
    func barcodeHRIBelow() {
        var (simulator, getLines) = makeSimulator(sixelEnabled: true)
        _ = simulator.process([.barcodeHRIPosition(.below), .barcode(type: .code128, data: Data("12345".utf8))])
        let nonEmpty = getLines().filter { !$0.isEmpty }
        #expect(nonEmpty.count == 2)
        #expect(nonEmpty[0].contains("\u{1B}P0;1;q") == true)
        #expect(nonEmpty[1].contains("12345") == true)
    }

    @Test("barcodeHRIPosition(.above)でバーコード上にHRIテキストが出力される")
    func barcodeHRIAbove() {
        var (simulator, getLines) = makeSimulator(sixelEnabled: true)
        _ = simulator.process([.barcodeHRIPosition(.above), .barcode(type: .code128, data: Data("12345".utf8))])
        let nonEmpty = getLines().filter { !$0.isEmpty }
        #expect(nonEmpty.count == 2)
        #expect(nonEmpty[0].contains("12345") == true)
        #expect(nonEmpty[1].contains("\u{1B}P0;1;q") == true)
    }

    @Test("barcodeHRIPosition(.both)でバーコード上下にHRIテキストが出力される")
    func barcodeHRIBoth() {
        var (simulator, getLines) = makeSimulator(sixelEnabled: true)
        _ = simulator.process([.barcodeHRIPosition(.both), .barcode(type: .code128, data: Data("12345".utf8))])
        let nonEmpty = getLines().filter { !$0.isEmpty }
        #expect(nonEmpty.count == 3)
        #expect(nonEmpty[0].contains("12345") == true)
        #expect(nonEmpty[1].contains("\u{1B}P0;1;q") == true)
        #expect(nonEmpty[2].contains("12345") == true)
    }

    @Test("initialize後にバーコード設定がリセットされる")
    func initializeResetsBarcodeState() {
        var (simulator, getLines) = makeSimulator(sixelEnabled: true)
        _ = simulator.process([
            .barcodeHeight(dots: 50),
            .barcodeHRIPosition(.below),
            .initialize,
            .barcode(type: .code128, data: Data("ABC".utf8)),
        ])
        let nonEmpty = getLines().filter { !$0.isEmpty }
        #expect(nonEmpty.count == 2)
        #expect(nonEmpty[0].contains("PRINTER INITIALIZED") == true)
        #expect(nonEmpty[1].contains("\u{1B}P0;1;q") == true)
    }

    // MARK: - NVグラフィクスSixel出力

    @Test("sixelEnabled=true: nvGraphicsPrintでSixelロゴプレースホルダーが出力される")
    func nvGraphicsSixel() {
        var (simulator, getLines) = makeSimulator(sixelEnabled: true)
        _ = simulator.process([.nvGraphicsPrint(keyCode1: 1, keyCode2: 2, scaleX: 1, scaleY: 1)])
        let lines = getLines()
        #expect(lines.last?.hasPrefix("\u{1B}P0;1;q") == true)
        #expect(lines.last?.hasSuffix("\u{1B}\\") == true)
    }

    @Test("sixelEnabled=false: nvGraphicsPrintでテキストプレースホルダーが出力される")
    func nvGraphicsPlaceholder() {
        var (simulator, getLines) = makeSimulator(sixelEnabled: false)
        _ = simulator.process([.nvGraphicsPrint(keyCode1: 1, keyCode2: 2, scaleX: 1, scaleY: 1)])
        let lines = getLines()
        #expect(lines.last?.contains("NV GRAPHICS") == true)
    }

    @Test("nvGraphicsPrintのscaleでSixel画像サイズが変わる")
    func nvGraphicsScale() {
        var (sim1, get1) = makeSimulator(sixelEnabled: true)
        _ = sim1.process([.nvGraphicsPrint(keyCode1: 0, keyCode2: 0, scaleX: 1, scaleY: 1)])
        let sixel1 = get1().last ?? ""

        var (sim2, get2) = makeSimulator(sixelEnabled: true)
        _ = sim2.process([.nvGraphicsPrint(keyCode1: 0, keyCode2: 0, scaleX: 2, scaleY: 2)])
        let sixel2 = get2().last ?? ""

        #expect(sixel1.count < sixel2.count)
    }

    // MARK: - HiDPIスケーリング

    @Test("displayScale=2: rasterImageのSixel出力が2倍にスケールされる")
    func displayScaleRasterImage() {
        var (sim1, get1) = makeSimulator(sixelEnabled: true)
        let imageData = Data(repeating: 0xFF, count: 6)
        _ = sim1.process([.rasterImage(mode: .normal, width: 1, height: 6, data: imageData)])
        let sixel1 = get1().last ?? ""

        var (sim2, get2) = makeSimulator(sixelEnabled: true)
        sim2.renderer.displayScale = 2
        _ = sim2.process([.rasterImage(mode: .normal, width: 1, height: 6, data: imageData)])
        let sixel2 = get2().last ?? ""

        #expect(sixel2.count > sixel1.count)
        #expect(sixel1.contains("\"1;1;8;6"))
        #expect(sixel2.contains("\"1;1;16;12"))
    }

    @Test("displayScale=2: QRコードのSixel出力が2倍にスケールされる")
    func displayScaleQRCode() {
        var (sim1, get1) = makeSimulator(sixelEnabled: true)
        _ = sim1.process([.qrCodeStore(data: Data("TEST".utf8)), .qrCodePrint])
        let sixel1 = get1().last ?? ""

        var (sim2, get2) = makeSimulator(sixelEnabled: true)
        sim2.renderer.displayScale = 2
        _ = sim2.process([.qrCodeStore(data: Data("TEST".utf8)), .qrCodePrint])
        let sixel2 = get2().last ?? ""

        #expect(sixel2.count > sixel1.count)
    }
}
