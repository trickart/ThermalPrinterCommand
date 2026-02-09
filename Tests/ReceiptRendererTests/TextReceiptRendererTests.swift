import Testing
import Foundation
@testable import ReceiptRenderer
import ThermalPrinterCommand

@Suite("TextReceiptRenderer Tests")
struct TextReceiptRendererTests {

    private func makeRenderer(ansiStyleEnabled: Bool = true) -> (TextReceiptRenderer, () -> [String]) {
        var lines: [String] = []
        var renderer = TextReceiptRenderer(ansiStyleEnabled: ansiStyleEnabled)
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

    @Test("qrCodeStore で QR CODE が中央揃えで出力される")
    func qrCodeOutput() {
        var (renderer, getLines) = makeRenderer()
        renderer.render(.qrCodeStore(data: Data("https://example.com".utf8)))
        let lines = getLines()
        let text = "[QR CODE: https://example.com]"
        let expectedPadding = (48 - text.count) / 2
        #expect(lines.last == String(repeating: " ", count: expectedPadding) + text)
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
}
