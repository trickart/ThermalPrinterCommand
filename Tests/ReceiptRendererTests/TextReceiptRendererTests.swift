import Testing
import Foundation
@testable import ReceiptRenderer
import ThermalPrinterCommand

@Suite("TextReceiptRenderer Tests")
struct TextReceiptRendererTests {

    private func makeRenderer(ansiStyleEnabled: Bool = true, sixelEnabled: Bool = false) -> (TextReceiptRenderer, () -> [String]) {
        var lines: [String] = []
        var renderer = TextReceiptRenderer(ansiStyleEnabled: ansiStyleEnabled, sixelEnabled: sixelEnabled)
        renderer.outputLine = { lines.append($0) }
        return (renderer, { lines })
    }

    // MARK: - テキスト出力

    @Test("text + lineFeed で行が出力される")
    func textOutput() {
        var (renderer, getLines) = makeRenderer()
        renderer.render(.text(Data("Hello".utf8)))
        renderer.render(.lineFeed)
        let lines = getLines()
        #expect(lines.count == 1)
        #expect(lines[0] == "Hello")
    }

    // MARK: - 太字

    @Test("boldOn で ANSI 太字コード付きで出力される")
    func boldText() {
        var (renderer, getLines) = makeRenderer()
        renderer.render(.boldOn)
        renderer.render(.text(Data("Bold".utf8)))
        renderer.render(.lineFeed)
        let lines = getLines()
        #expect(lines.count == 1)
        #expect(lines[0].contains(TextReceiptRenderer.ansiBoldOn))
        #expect(lines[0].contains("Bold"))
        #expect(lines[0].hasSuffix(TextReceiptRenderer.ansiReset))
    }

    // MARK: - 下線

    @Test("underline(.single) で ANSI 下線コード付きで出力される")
    func underlineText() {
        var (renderer, getLines) = makeRenderer()
        renderer.render(.underline(.single))
        renderer.render(.text(Data("Underlined".utf8)))
        renderer.render(.lineFeed)
        let lines = getLines()
        #expect(lines.count == 1)
        #expect(lines[0].contains(TextReceiptRenderer.ansiUnderlineOn))
        #expect(lines[0].contains("Underlined"))
        #expect(lines[0].hasSuffix(TextReceiptRenderer.ansiReset))
    }

    // MARK: - 反転

    @Test("reverseMode(true) で ANSI 反転コード付きで出力される")
    func reverseText() {
        var (renderer, getLines) = makeRenderer()
        renderer.render(.reverseMode(enabled: true))
        renderer.render(.text(Data("Reversed".utf8)))
        renderer.render(.lineFeed)
        let lines = getLines()
        #expect(lines.count == 1)
        #expect(lines[0].contains(TextReceiptRenderer.ansiReverseOn))
        #expect(lines[0].contains("Reversed"))
        #expect(lines[0].hasSuffix(TextReceiptRenderer.ansiReset))
    }

    // MARK: - 中央揃え

    @Test("justification(.center) でパディング付きで出力される")
    func centerJustification() {
        var (renderer, getLines) = makeRenderer()
        renderer.render(.justification(.center))
        renderer.render(.text(Data("Center".utf8)))
        renderer.render(.lineFeed)
        let lines = getLines()
        #expect(lines.count == 1)
        // paperWidth=48, "Center"=6文字, padding=(48-6)/2=21
        let expectedPadding = (48 - 6) / 2
        #expect(lines[0].hasPrefix(String(repeating: " ", count: expectedPadding)))
        #expect(lines[0].contains("Center"))
    }

    // MARK: - 右揃え

    @Test("justification(.right) でパディング付きで出力される")
    func rightJustification() {
        var (renderer, getLines) = makeRenderer()
        renderer.render(.justification(.right))
        renderer.render(.text(Data("Right".utf8)))
        renderer.render(.lineFeed)
        let lines = getLines()
        #expect(lines.count == 1)
        // paperWidth=48, "Right"=5文字, padding=48-5=43
        let expectedPadding = 48 - 5
        #expect(lines[0].hasPrefix(String(repeating: " ", count: expectedPadding)))
        #expect(lines[0].contains("Right"))
    }

    // MARK: - 初期化

    @Test("initialize で [PRINTER INITIALIZED] が中央揃えで出力される")
    func initializeCommand() {
        var (renderer, getLines) = makeRenderer()
        renderer.render(.initialize)
        let lines = getLines()
        #expect(lines.count == 1)
        let text = "[PRINTER INITIALIZED]"
        let expectedPadding = (48 - text.count) / 2
        #expect(lines[0] == String(repeating: " ", count: expectedPadding) + text)
    }

    // MARK: - フルカット

    @Test("cut(.full) で FULL CUT が中央揃えで出力される")
    func fullCut() {
        var (renderer, getLines) = makeRenderer()
        renderer.render(.cut(.full))
        let lines = getLines()
        let text = "--- ✂ FULL CUT ---"
        let expectedPadding = (48 - text.count) / 2
        #expect(lines.last == String(repeating: " ", count: expectedPadding) + text)
    }

    // MARK: - パーシャルカット

    @Test("cut(.partial) で PARTIAL CUT が中央揃えで出力される")
    func partialCut() {
        var (renderer, getLines) = makeRenderer()
        renderer.render(.cut(.partial))
        let lines = getLines()
        let text = "--- ✂ PARTIAL CUT ---"
        let expectedPadding = (48 - text.count) / 2
        #expect(lines.last == String(repeating: " ", count: expectedPadding) + text)
    }

    // MARK: - バーコード

    @Test("barcode で CODE128 フォーマットが中央揃えで出力される")
    func barcodeOutput() {
        var (renderer, getLines) = makeRenderer()
        renderer.render(.barcode(type: .code128, data: Data("12345".utf8)))
        let lines = getLines()
        let text = "[CODE128] ||| 12345 |||"
        let expectedPadding = (48 - text.count) / 2
        #expect(lines.last == String(repeating: " ", count: expectedPadding) + text)
    }

    // MARK: - QRコード

    @Test("qrCodePrint で QR CODE が中央揃えで出力される")
    func qrCodeOutput() {
        var (renderer, getLines) = makeRenderer()
        renderer.render(.qrCodeStore(data: Data("https://example.com".utf8)))
        renderer.render(.qrCodePrint)
        let lines = getLines()
        let text = "[QR CODE: https://example.com]"
        let expectedPadding = (48 - text.count) / 2
        #expect(lines.last == String(repeating: " ", count: expectedPadding) + text)
    }

    @Test("sixelEnabled=true: QRコードがSixel形式で出力される")
    func qrCodeSixel() {
        var (renderer, getLines) = makeRenderer(sixelEnabled: true)
        renderer.render(.qrCodeStore(data: Data("https://example.com".utf8)))
        renderer.render(.qrCodePrint)
        let lines = getLines()
        #expect(lines.last?.hasPrefix("\u{1B}P0;1;q") == true)
        #expect(lines.last?.hasSuffix("\u{1B}\\") == true)
    }

    @Test("sixelEnabled=true: qrCodeSizeがSixel出力のモジュールサイズに反映される")
    func qrCodeModuleSizeAffectsSixel() {
        var (r1, get1) = makeRenderer(sixelEnabled: true)
        r1.render(.qrCodeSize(moduleSize: 2))
        r1.render(.qrCodeStore(data: Data("TEST".utf8)))
        r1.render(.qrCodePrint)
        let sixel1 = get1().last ?? ""

        var (r2, get2) = makeRenderer(sixelEnabled: true)
        r2.render(.qrCodeSize(moduleSize: 6))
        r2.render(.qrCodeStore(data: Data("TEST".utf8)))
        r2.render(.qrCodePrint)
        let sixel2 = get2().last ?? ""

        // moduleSize=6 の方が大きい
        #expect(sixel1.count < sixel2.count)
    }

    @Test("sixelEnabled=true: qrCodePrint後にデータがクリアされる")
    func qrCodeDataClearedAfterPrint() {
        var (renderer, getLines) = makeRenderer(sixelEnabled: true)
        renderer.render(.qrCodeStore(data: Data("TEST".utf8)))
        renderer.render(.qrCodePrint)
        renderer.render(.qrCodePrint) // 2回目はデータなし
        let lines = getLines()
        // Sixel出力は1回のみ
        let sixelCount = lines.filter { $0.contains("\u{1B}P0;1;q") }.count
        #expect(sixelCount == 1)
    }

    // MARK: - 画像

    @Test("rasterImage で IMAGE サイズが中央揃えで出力される")
    func rasterImageOutput() {
        var (renderer, getLines) = makeRenderer()
        renderer.render(.rasterImage(mode: .normal, width: 6, height: 100, data: Data()))
        let lines = getLines()
        let text = "[IMAGE: 48x100 dots]"
        let expectedPadding = (48 - text.count) / 2
        #expect(lines.last == String(repeating: " ", count: expectedPadding) + text)
    }

    // MARK: - キャッシュドロワー

    @Test("openCashDrawer で CASH DRAWER OPEN が中央揃えで出力される")
    func cashDrawerOutput() {
        var (renderer, getLines) = makeRenderer()
        renderer.render(.openCashDrawer(pin: 0, onTime: 1, offTime: 1))
        let lines = getLines()
        #expect(lines.count == 1)
        let text = "[CASH DRAWER OPEN]"
        let expectedPadding = (48 - text.count) / 2
        #expect(lines[0] == String(repeating: " ", count: expectedPadding) + text)
    }

    // MARK: - 状態リセット

    @Test("initialize 後に bold 等がリセットされる")
    func initializeResetsState() {
        var (renderer, getLines) = makeRenderer()
        // 太字と下線を有効に
        renderer.render(.boldOn)
        renderer.render(.underline(.single))
        renderer.render(.reverseMode(enabled: true))
        renderer.render(.justification(.center))
        renderer.render(.characterSize(width: 2, height: 2))

        // initializeでリセット
        renderer.render(.initialize)

        // リセット後のテキスト出力は装飾なし・左揃え
        renderer.render(.text(Data("Plain".utf8)))
        renderer.render(.lineFeed)

        let lines = getLines()
        // [PRINTER INITIALIZED] + "Plain" の2行
        #expect(lines.count == 2)
        // "Plain" は装飾なし（ANSIコードなし）・左揃え（パディングなし）
        #expect(lines[1] == "Plain")
    }

    // MARK: - ansiStyleEnabled

    @Test("ansiStyleEnabled=false: boldOnでもANSIコードが付かない")
    func boldWithoutAnsi() {
        var (renderer, getLines) = makeRenderer(ansiStyleEnabled: false)
        renderer.render(.boldOn)
        renderer.render(.text(Data("Bold".utf8)))
        renderer.render(.lineFeed)
        let lines = getLines()
        #expect(lines.count == 1)
        #expect(lines[0] == "Bold")
        #expect(!lines[0].contains("\u{1B}"))
    }

    @Test("ansiStyleEnabled=false: underlineでもANSIコードが付かない")
    func underlineWithoutAnsi() {
        var (renderer, getLines) = makeRenderer(ansiStyleEnabled: false)
        renderer.render(.underline(.single))
        renderer.render(.text(Data("Underlined".utf8)))
        renderer.render(.lineFeed)
        let lines = getLines()
        #expect(lines.count == 1)
        #expect(lines[0] == "Underlined")
        #expect(!lines[0].contains("\u{1B}"))
    }

    @Test("ansiStyleEnabled=false: reverseModeでもANSIコードが付かない")
    func reverseWithoutAnsi() {
        var (renderer, getLines) = makeRenderer(ansiStyleEnabled: false)
        renderer.render(.reverseMode(enabled: true))
        renderer.render(.text(Data("Reversed".utf8)))
        renderer.render(.lineFeed)
        let lines = getLines()
        #expect(lines.count == 1)
        #expect(lines[0] == "Reversed")
        #expect(!lines[0].contains("\u{1B}"))
    }

    @Test("ansiStyleEnabled=false: 複数の装飾を同時に有効にしてもANSIコードが付かない")
    func multipleStylesWithoutAnsi() {
        var (renderer, getLines) = makeRenderer(ansiStyleEnabled: false)
        renderer.render(.boldOn)
        renderer.render(.underline(.double))
        renderer.render(.reverseMode(enabled: true))
        renderer.render(.text(Data("Styled".utf8)))
        renderer.render(.lineFeed)
        let lines = getLines()
        #expect(lines.count == 1)
        #expect(lines[0] == "Styled")
        #expect(!lines[0].contains("\u{1B}"))
    }

    // MARK: - Sixel画像出力

    @Test("sixelEnabled=false: rasterImageでプレースホルダーが出力される")
    func rasterImagePlaceholder() {
        var (renderer, getLines) = makeRenderer(sixelEnabled: false)
        let imageData = Data(repeating: 0xFF, count: 6)
        renderer.render(.rasterImage(mode: .normal, width: 1, height: 6, data: imageData))
        let lines = getLines()
        #expect(lines.last?.contains("[IMAGE:") == true)
    }

    @Test("sixelEnabled=true: rasterImageでDCS...ST形式のSixel出力が得られる")
    func rasterImageSixel() {
        var (renderer, getLines) = makeRenderer(sixelEnabled: true)
        let imageData = Data(repeating: 0xFF, count: 6)
        renderer.render(.rasterImage(mode: .normal, width: 1, height: 6, data: imageData))
        let lines = getLines()
        #expect(lines.last?.hasPrefix("\u{1B}P0;1;q") == true)
        #expect(lines.last?.hasSuffix("\u{1B}\\") == true)
    }

    @Test("sixelEnabled=true: graphicsStoreでSixel出力が得られる")
    func graphicsStoreSixel() {
        var (renderer, getLines) = makeRenderer(sixelEnabled: true)
        // width=8ピクセル → widthBytes=1
        let imageData = Data(repeating: 0xFF, count: 6)
        renderer.render(.graphicsStore(
            tone: .monochrome, scaleX: 1, scaleY: 1, color: .color1,
            width: 8, height: 6, data: imageData
        ))
        let lines = getLines()
        #expect(lines.last?.hasPrefix("\u{1B}P0;1;q") == true)
        #expect(lines.last?.hasSuffix("\u{1B}\\") == true)
    }

    @Test("sixelEnabled=true: graphicsStoreのwidthが8の倍数でなくても正しく変換される")
    func graphicsStoreNonAlignedWidth() {
        var (renderer, getLines) = makeRenderer(sixelEnabled: true)
        // width=12ピクセル → widthBytes=(12+7)/8=2
        let imageData = Data(repeating: 0xFF, count: 2)
        renderer.render(.graphicsStore(
            tone: .monochrome, scaleX: 1, scaleY: 1, color: .color1,
            width: 12, height: 1, data: imageData
        ))
        let lines = getLines()
        #expect(lines.last?.hasPrefix("\u{1B}P0;1;q") == true)
        // widthBytes=2 → 16ピクセル幅
        #expect(lines.last?.contains("\"1;1;16;1") == true)
    }

    // MARK: - バーコードSixel出力

    @Test("sixelEnabled=true: CODE128バーコードがSixel形式で出力される")
    func barcodeSixelCode128() {
        var (renderer, getLines) = makeRenderer(sixelEnabled: true)
        renderer.render(.barcode(type: .code128, data: Data("12345".utf8)))
        let lines = getLines()
        #expect(lines.last?.hasPrefix("\u{1B}P0;1;q") == true)
        #expect(lines.last?.hasSuffix("\u{1B}\\") == true)
    }

    @Test("sixelEnabled=true: EAN13バーコードがSixel形式で出力される")
    func barcodeSixelEAN13() {
        var (renderer, getLines) = makeRenderer(sixelEnabled: true)
        renderer.render(.barcode(type: .ean13, data: Data("4901234567894".utf8)))
        let lines = getLines()
        #expect(lines.last?.hasPrefix("\u{1B}P0;1;q") == true)
    }

    @Test("sixelEnabled=true: EAN8バーコードがSixel形式で出力される")
    func barcodeSixelEAN8() {
        var (renderer, getLines) = makeRenderer(sixelEnabled: true)
        renderer.render(.barcode(type: .ean8, data: Data("12345670".utf8)))
        let lines = getLines()
        #expect(lines.last?.hasPrefix("\u{1B}P0;1;q") == true)
    }

    @Test("sixelEnabled=true: CODE39バーコードがSixel形式で出力される")
    func barcodeSixelCode39() {
        var (renderer, getLines) = makeRenderer(sixelEnabled: true)
        renderer.render(.barcode(type: .code39, data: Data("ABC123".utf8)))
        let lines = getLines()
        #expect(lines.last?.hasPrefix("\u{1B}P0;1;q") == true)
    }

    @Test("sixelEnabled=true: ITFバーコードがSixel形式で出力される")
    func barcodeSixelITF() {
        var (renderer, getLines) = makeRenderer(sixelEnabled: true)
        renderer.render(.barcode(type: .itf, data: Data("1234567890".utf8)))
        let lines = getLines()
        #expect(lines.last?.hasPrefix("\u{1B}P0;1;q") == true)
    }

    @Test("sixelEnabled=true: CODABARバーコードがSixel形式で出力される")
    func barcodeSixelCodabar() {
        var (renderer, getLines) = makeRenderer(sixelEnabled: true)
        renderer.render(.barcode(type: .codabar, data: Data("A12345B".utf8)))
        let lines = getLines()
        #expect(lines.last?.hasPrefix("\u{1B}P0;1;q") == true)
    }

    @Test("sixelEnabled=true: CODE93バーコードがSixel形式で出力される")
    func barcodeSixelCode93() {
        var (renderer, getLines) = makeRenderer(sixelEnabled: true)
        renderer.render(.barcode(type: .code93, data: Data("12345".utf8)))
        let lines = getLines()
        #expect(lines.last?.hasPrefix("\u{1B}P0;1;q") == true)
    }

    @Test("sixelEnabled=true: UPC-Aバーコードがsixel形式で出力される")
    func barcodeSixelUPCA() {
        var (renderer, getLines) = makeRenderer(sixelEnabled: true)
        renderer.render(.barcode(type: .upcA, data: Data("012345678905".utf8)))
        let lines = getLines()
        #expect(lines.last?.hasPrefix("\u{1B}P0;1;q") == true)
    }

    @Test("sixelEnabled=true: UPC-Eバーコードがsixel形式で出力される")
    func barcodeSixelUPCE() {
        var (renderer, getLines) = makeRenderer(sixelEnabled: true)
        renderer.render(.barcode(type: .upcE, data: Data("123456".utf8)))
        let lines = getLines()
        #expect(lines.last?.hasPrefix("\u{1B}P0;1;q") == true)
    }

    @Test("sixelEnabled=false: バーコードは従来のテキスト形式で出力される")
    func barcodeFallbackWhenSixelDisabled() {
        var (renderer, getLines) = makeRenderer(sixelEnabled: false)
        renderer.render(.barcode(type: .code128, data: Data("12345".utf8)))
        let lines = getLines()
        let text = "[CODE128] ||| 12345 |||"
        let expectedPadding = (48 - text.count) / 2
        #expect(lines.last == String(repeating: " ", count: expectedPadding) + text)
    }

    @Test("barcodeHeight設定がSixel出力のサイズに反映される")
    func barcodeHeightAffectsSixel() {
        var (renderer1, getLines1) = makeRenderer(sixelEnabled: true)
        renderer1.render(.barcodeHeight(dots: 50))
        renderer1.render(.barcode(type: .code128, data: Data("ABC".utf8)))
        let sixel1 = getLines1().last ?? ""

        var (renderer2, getLines2) = makeRenderer(sixelEnabled: true)
        renderer2.render(.barcodeHeight(dots: 100))
        renderer2.render(.barcode(type: .code128, data: Data("ABC".utf8)))
        let sixel2 = getLines2().last ?? ""

        // 高さ50のSixelは高さ100より短い（バンド数が少ない）
        #expect(sixel1.count < sixel2.count)
    }

    @Test("barcodeHRIPosition(.below)でバーコード下にHRIテキストが出力される")
    func barcodeHRIBelow() {
        var (renderer, getLines) = makeRenderer(sixelEnabled: true)
        renderer.render(.barcodeHRIPosition(.below))
        renderer.render(.barcode(type: .code128, data: Data("12345".utf8)))
        let nonEmpty = getLines().filter { !$0.isEmpty }
        // Sixel + HRI text
        #expect(nonEmpty.count == 2)
        #expect(nonEmpty[0].contains("\u{1B}P0;1;q") == true)
        #expect(nonEmpty[1].contains("12345") == true)
    }

    @Test("barcodeHRIPosition(.above)でバーコード上にHRIテキストが出力される")
    func barcodeHRIAbove() {
        var (renderer, getLines) = makeRenderer(sixelEnabled: true)
        renderer.render(.barcodeHRIPosition(.above))
        renderer.render(.barcode(type: .code128, data: Data("12345".utf8)))
        let nonEmpty = getLines().filter { !$0.isEmpty }
        #expect(nonEmpty.count == 2)
        #expect(nonEmpty[0].contains("12345") == true)
        #expect(nonEmpty[1].contains("\u{1B}P0;1;q") == true)
    }

    @Test("barcodeHRIPosition(.both)でバーコード上下にHRIテキストが出力される")
    func barcodeHRIBoth() {
        var (renderer, getLines) = makeRenderer(sixelEnabled: true)
        renderer.render(.barcodeHRIPosition(.both))
        renderer.render(.barcode(type: .code128, data: Data("12345".utf8)))
        let nonEmpty = getLines().filter { !$0.isEmpty }
        #expect(nonEmpty.count == 3)
        #expect(nonEmpty[0].contains("12345") == true)
        #expect(nonEmpty[1].contains("\u{1B}P0;1;q") == true)
        #expect(nonEmpty[2].contains("12345") == true)
    }

    @Test("initialize後にバーコード設定がリセットされる")
    func initializeResetsBarcodeState() {
        var (renderer, getLines) = makeRenderer(sixelEnabled: true)
        renderer.render(.barcodeHeight(dots: 50))
        renderer.render(.barcodeHRIPosition(.below))
        renderer.render(.initialize)
        renderer.render(.barcode(type: .code128, data: Data("ABC".utf8)))
        let nonEmpty = getLines().filter { !$0.isEmpty }
        // [PRINTER INITIALIZED] + Sixel（HRIなし）
        #expect(nonEmpty.count == 2)
        #expect(nonEmpty[0].contains("PRINTER INITIALIZED") == true)
        #expect(nonEmpty[1].contains("\u{1B}P0;1;q") == true)
    }

    // MARK: - NVグラフィクスSixel出力

    @Test("sixelEnabled=true: nvGraphicsPrintでSixelロゴプレースホルダーが出力される")
    func nvGraphicsSixel() {
        var (renderer, getLines) = makeRenderer(sixelEnabled: true)
        renderer.render(.nvGraphicsPrint(keyCode1: 1, keyCode2: 2, scaleX: 1, scaleY: 1))
        let lines = getLines()
        #expect(lines.last?.hasPrefix("\u{1B}P0;1;q") == true)
        #expect(lines.last?.hasSuffix("\u{1B}\\") == true)
    }

    @Test("sixelEnabled=false: nvGraphicsPrintでテキストプレースホルダーが出力される")
    func nvGraphicsPlaceholder() {
        var (renderer, getLines) = makeRenderer(sixelEnabled: false)
        renderer.render(.nvGraphicsPrint(keyCode1: 1, keyCode2: 2, scaleX: 1, scaleY: 1))
        let lines = getLines()
        #expect(lines.last?.contains("NV GRAPHICS") == true)
    }

    @Test("nvGraphicsPrintのscaleでSixel画像サイズが変わる")
    func nvGraphicsScale() {
        var (r1, get1) = makeRenderer(sixelEnabled: true)
        r1.render(.nvGraphicsPrint(keyCode1: 0, keyCode2: 0, scaleX: 1, scaleY: 1))
        let sixel1 = get1().last ?? ""

        var (r2, get2) = makeRenderer(sixelEnabled: true)
        r2.render(.nvGraphicsPrint(keyCode1: 0, keyCode2: 0, scaleX: 2, scaleY: 2))
        let sixel2 = get2().last ?? ""

        // scale=2x2 の方が大きい
        #expect(sixel1.count < sixel2.count)
    }

    // MARK: - HiDPIスケーリング

    @Test("displayScale=2: rasterImageのSixel出力が2倍にスケールされる")
    func displayScaleRasterImage() {
        var (r1, get1) = makeRenderer(sixelEnabled: true)
        let imageData = Data(repeating: 0xFF, count: 6)
        r1.render(.rasterImage(mode: .normal, width: 1, height: 6, data: imageData))
        let sixel1 = get1().last ?? ""

        var (r2, get2) = makeRenderer(sixelEnabled: true)
        r2.displayScale = 2
        r2.render(.rasterImage(mode: .normal, width: 1, height: 6, data: imageData))
        let sixel2 = get2().last ?? ""

        // displayScale=2 の方が大きい
        #expect(sixel2.count > sixel1.count)
        // ラスター属性で2倍の寸法が宣言される
        #expect(sixel1.contains("\"1;1;8;6"))
        #expect(sixel2.contains("\"1;1;16;12"))
    }

    @Test("displayScale=2: QRコードのSixel出力が2倍にスケールされる")
    func displayScaleQRCode() {
        var (r1, get1) = makeRenderer(sixelEnabled: true)
        r1.render(.qrCodeStore(data: Data("TEST".utf8)))
        r1.render(.qrCodePrint)
        let sixel1 = get1().last ?? ""

        var (r2, get2) = makeRenderer(sixelEnabled: true)
        r2.displayScale = 2
        r2.render(.qrCodeStore(data: Data("TEST".utf8)))
        r2.render(.qrCodePrint)
        let sixel2 = get2().last ?? ""

        #expect(sixel2.count > sixel1.count)
    }
}
