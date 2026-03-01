import Foundation
import ThermalPrinterCommand

public struct TextReceiptRenderer {
    // MARK: - Output

    public var outputLine: (String) -> Void = { Swift.print($0) }

    // MARK: - Options

    public var ansiStyleEnabled: Bool
    public var sixelEnabled: Bool
    /// セル幅（ピクセル）。0 の場合はバーコード幅の自動制限を行わない。
    public var cellPixelWidth: Int = 0
    /// HiDPIディスプレイのスケールファクター（2=Retina 2x）。Sixel画像を拡大して表示する。
    public var displayScale: Int = 1

    // MARK: - Line Buffer

    private var lineBuffer = ""
    let paperWidth = 48  // 標準的な58mmプリンタの文字幅

    // MARK: - ANSI Escape Codes

    static let ansiReset = "\u{1B}[0m"
    static let ansiBoldOn = "\u{1B}[1m"
    static let ansiBoldOff = "\u{1B}[22m"
    static let ansiUnderlineOn = "\u{1B}[4m"
    static let ansiDoubleUnderlineOn = "\u{1B}[21m"
    static let ansiUnderlineOff = "\u{1B}[24m"
    static let ansiReverseOn = "\u{1B}[7m"
    static let ansiReverseOff = "\u{1B}[27m"

    // MARK: - Initializer

    public init(ansiStyleEnabled: Bool = false, sixelEnabled: Bool = false) {
        self.ansiStyleEnabled = ansiStyleEnabled
        self.sixelEnabled = sixelEnabled
    }

    // MARK: - Rendering (with simulator state)

    public mutating func render(_ command: ESCPOSCommand, status: PrinterStatus) {
        switch command {
        case .initialize:
            lineBuffer = ""
            printCentered("[PRINTER INITIALIZED]")

        case .text(let data):
            let text = decodeText(data, status: status)
            lineBuffer += text

        case .lineFeed:
            flushLine(status: status)

        case .carriageReturn:
            break

        case .horizontalTab:
            lineBuffer += ("\t")

        case .printAndFeed:
            flushLine(status: status)

        case .printAndReverseFeed:
            flushLine(status: status)

        case .feedLines(let count):
            flushLine(status: status)
            for _ in 1..<count {
                outputLine("")
            }

        case .cut(let mode):
            flushLine(status: status)
            let modeStr = (mode == .full || mode == .fullWithFeed) ? "FULL" : "PARTIAL"
            printCentered("--- ✂ \(modeStr) CUT ---")

        case .cutWithFeed(let mode, _):
            flushLine(status: status)
            let modeStr = (mode == .full || mode == .fullWithFeed) ? "FULL" : "PARTIAL"
            printCentered("--- ✂ \(modeStr) CUT ---")

        case .barcode(let type, let data):
            flushLine(status: status)
            let moduleWidth = effectiveBarcodeModuleWidth(type: type, data: data, status: status)
            if sixelEnabled,
               let image = BarcodeRasterizer.rasterize(
                   type: type,
                   data: data,
                   moduleWidth: moduleWidth,
                   height: Int(status.barcodeHeight)
               ) {
                let dataStr = String(data: data, encoding: .ascii) ?? data.map { String(format: "%02X", $0) }.joined()
                if status.barcodeHRIPosition == .above || status.barcodeHRIPosition == .both {
                    printCentered(dataStr)
                }
                let sixel = SixelEncoder.encode(data: image.data, widthBytes: image.widthBytes, height: image.height, scale: displayScale)
                outputLine(applySixelJustification(sixel, imageCharWidth: image.widthBytes, justification: status.justification))
                if status.barcodeHRIPosition == .below || status.barcodeHRIPosition == .both {
                    printCentered(dataStr)
                }
            } else {
                let typeName = barcodeTypeName(type)
                let dataStr = String(data: data, encoding: .ascii) ?? data.map { String(format: "%02X", $0) }.joined()
                printCentered("[\(typeName)] ||| \(dataStr) |||")
            }

        case .qrCodePrint:
            flushLine(status: status)
            if let data = status.qrCodeStoredData {
                if sixelEnabled,
                   let image = QRCodeRasterizer.rasterize(
                       data: data,
                       ecLevel: Int(status.qrCodeErrorCorrection.rawValue) - 48,
                       moduleSize: Int(status.qrCodeModuleSize)
                   ) {
                    let sixel = SixelEncoder.encode(data: image.data, widthBytes: image.widthBytes, height: image.height, scale: displayScale)
                    outputLine(applySixelJustification(sixel, imageCharWidth: image.widthBytes, justification: status.justification))
                } else {
                    let content = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .shiftJIS) ?? "<binary>"
                    printCentered("[QR CODE: \(content)]")
                }
            }

        case .rasterImage(_, let width, let height, let data):
            flushLine(status: status)
            if sixelEnabled {
                let sixel = SixelEncoder.encode(data: data, widthBytes: Int(width), height: Int(height), scale: displayScale)
                outputLine(applySixelJustification(sixel, imageCharWidth: Int(width), justification: status.justification))
            } else {
                printCentered("[IMAGE: \(width * 8)x\(height) dots]")
            }

        case .graphicsStore(_, _, _, _, let width, let height, let data):
            flushLine(status: status)
            if sixelEnabled {
                let widthBytes = (Int(width) + 7) / 8
                let sixel = SixelEncoder.encode(data: data, widthBytes: widthBytes, height: Int(height), scale: displayScale)
                outputLine(applySixelJustification(sixel, imageCharWidth: widthBytes, justification: status.justification))
            } else {
                printCentered("[IMAGE: \(width)x\(height) dots]")
            }

        case .graphicsPrint:
            break  // graphicsStoreで既に表示済み

        case .nvGraphicsPrint(let kc1, let kc2, let scaleX, let scaleY):
            flushLine(status: status)
            if sixelEnabled {
                let logo = Self.generateNVGraphicsPlaceholder(text: "\(kc1):\(kc2)", scaleX: Int(scaleX), scaleY: Int(scaleY))
                let sixel = SixelEncoder.encode(data: logo.data, widthBytes: logo.widthBytes, height: logo.height, scale: displayScale)
                outputLine(applySixelJustification(sixel, imageCharWidth: logo.widthBytes, justification: status.justification))
            } else {
                printCentered("[NV GRAPHICS: key=(\(kc1),\(kc2)) scale=\(scaleX)x\(scaleY)]")
            }

        case .absolutePosition(let dots):
            let charPos = dotsToChars(dots: Int(dots), status: status)
            let currentLen = lineBuffer.count
            if charPos > currentLen {
                lineBuffer += String(repeating: " ", count: charPos - currentLen)
            }

        case .relativePosition(let dots):
            let charDelta = dotsToChars(dots: Int(dots), status: status)
            if charDelta > 0 {
                lineBuffer += String(repeating: " ", count: charDelta)
            }

        case .openCashDrawer:
            printCentered("[CASH DRAWER OPEN]")

        case .boldOn, .boldOff, .underline, .kanjiUnderline, .reverseMode, .justification,
             .characterSize, .characterSpacing,
             .barcodeHeight, .barcodeWidth, .barcodeHRIPosition,
             .qrCodeSize, .qrCodeErrorCorrection, .qrCodeStore,
             .selectFont, .barcodeHRIFont,
             .qrCodeModel,
             .leftMargin, .printingWidth,
             .defaultLineSpacing, .lineSpacing,
             .rotate90, .upsideDown,
             .selectCharacterCodeTable,
             .selectKanjiCodeSystem,
             .kanjiDoubleSize, .cancelKanjiMode,
             .realtimeStatusRequest,
             .printerInfoRequest,
             .enableAutomaticStatus,
             .transmitPrintStatus,
             .requestProcessIdResponse:
            break  // 状態はシミュレーターが管理

        case .unknown, .rawData:
            break
        }
    }

    // MARK: - Private Helpers

    func decodeText(_ data: Data, status: PrinterStatus) -> String {
        // シングルバイトコードページが明示選択されている場合はコードページテーブルを使用
        if status.characterCodeTable > 0 {
            if data.allSatisfy({ $0 >= 0x20 }) {
                let mapper: (UInt8) -> Character = status.characterCodeTable == 1
                    ? { Self.codePage1toUnicode(byte: $0) }
                    : { Self.cp437toUnicode(byte: $0) }
                let mapped = String(data.map { mapper($0) })
                if !mapped.isEmpty { return mapped }
            }
        }
        // デフォルト: UTF-8 → Shift_JIS → CP437
        if let str = String(data: data, encoding: .utf8) {
            return str
        }
        if let str = String(data: data, encoding: .shiftJIS) {
            return str
        }
        if data.allSatisfy({ $0 >= 0x20 }) {
            let mapped = String(data.map { Self.cp437toUnicode(byte: $0) })
            if !mapped.isEmpty {
                return mapped
            }
        }
        return String(data: data, encoding: .ascii) ?? ""
    }

    /// コードページ437 の 0x80-0xFF をUnicode文字にマッピング
    private static func cp437toUnicode(byte: UInt8) -> Character {
        if byte < 0x80 {
            return Character(UnicodeScalar(byte))
        }
        // CP437 upper half (0x80-0xFF) mapping table
        let cp437Upper: [Character] = [
            // 0x80-0x8F
            "Ç", "ü", "é", "â", "ä", "à", "å", "ç", "ê", "ë", "è", "ï", "î", "ì", "Ä", "Å",
            // 0x90-0x9F
            "É", "æ", "Æ", "ô", "ö", "ò", "û", "ù", "ÿ", "Ö", "Ü", "¢", "£", "¥", "₧", "ƒ",
            // 0xA0-0xAF
            "á", "í", "ó", "ú", "ñ", "Ñ", "ª", "º", "¿", "⌐", "¬", "½", "¼", "¡", "«", "»",
            // 0xB0-0xBF
            "░", "▒", "▓", "│", "┤", "╡", "╢", "╖", "╕", "╣", "║", "╗", "╝", "╜", "╛", "┐",
            // 0xC0-0xCF
            "└", "┴", "┬", "├", "─", "┼", "╞", "╟", "╚", "╔", "╩", "╦", "╠", "═", "╬", "╧",
            // 0xD0-0xDF
            "╨", "╤", "╥", "╙", "╘", "╒", "╓", "╫", "╪", "┘", "┌", "█", "▄", "▌", "▐", "▀",
            // 0xE0-0xEF
            "α", "ß", "Γ", "π", "Σ", "σ", "µ", "τ", "Φ", "Θ", "Ω", "δ", "∞", "φ", "ε", "∩",
            // 0xF0-0xFF
            "≡", "±", "≥", "≤", "⌠", "⌡", "÷", "≈", "°", "∙", "·", "√", "ⁿ", "²", "■", " ",
        ]
        return cp437Upper[Int(byte) - 0x80]
    }

    /// コードページ1 (カタカナ) の 0x80-0xFF をUnicode文字にマッピング
    private static func codePage1toUnicode(byte: UInt8) -> Character {
        if byte < 0x80 {
            return Character(UnicodeScalar(byte))
        }
        let page1Upper: [Character] = [
            // 0x80-0x8F: ブロック要素・罫線
            "▁", "▂", "▃", "▄", "▅", "▆", "▇", "█", "▏", "▎", "▍", "▌", "▋", "▊", "▉", "┼",
            // 0x90-0x9F: 罫線・コーナー
            "┴", "┬", "┤", "├", "¯", "─", "│", "▕", "┌", "┐", "└", "┘", "╭", "╮", "╰", "╯",
            // 0xA0-0xAF: 半角カタカナ記号・小文字
            " ", "｡", "｢", "｣", "､", "･", "ｦ", "ｧ", "ｨ", "ｩ", "ｪ", "ｫ", "ｬ", "ｭ", "ｮ", "ｯ",
            // 0xB0-0xBF: 半角カタカナ
            "ｰ", "ｱ", "ｲ", "ｳ", "ｴ", "ｵ", "ｶ", "ｷ", "ｸ", "ｹ", "ｺ", "ｻ", "ｼ", "ｽ", "ｾ", "ｿ",
            // 0xC0-0xCF: 半角カタカナ
            "ﾀ", "ﾁ", "ﾂ", "ﾃ", "ﾄ", "ﾅ", "ﾆ", "ﾇ", "ﾈ", "ﾉ", "ﾊ", "ﾋ", "ﾌ", "ﾍ", "ﾎ", "ﾏ",
            // 0xD0-0xDF: 半角カタカナ・濁点
            "ﾐ", "ﾑ", "ﾒ", "ﾓ", "ﾔ", "ﾕ", "ﾖ", "ﾗ", "ﾘ", "ﾙ", "ﾚ", "ﾛ", "ﾜ", "ﾝ", "ﾞ", "ﾟ",
            // 0xE0-0xEF: 罫線・図形・カードマーク
            "═", "╞", "╪", "╡", "◢", "◣", "◥", "◤", "♠", "♥", "♦", "♣", "●", "○", "╱", "╲",
            // 0xF0-0xFF: 漢字・記号
            "╳", "円", "年", "月", "日", "時", "分", "秒", "〒", "市", "区", "町", "村", "人", "▓", " ",
        ]
        return page1Upper[Int(byte) - 0x80]
    }

    private mutating func flushLine(status: PrinterStatus) {
        let content = lineBuffer
        lineBuffer = ""

        var styled = content
        if ansiStyleEnabled {
            if status.bold { styled = Self.ansiBoldOn + styled }
            // 有効なアンダーラインモード: underlineMode と kanjiUnderlineMode の強い方を採用
            let effectiveUnderline = max(status.underlineMode.rawValue, status.kanjiUnderlineMode.rawValue)
            if effectiveUnderline == ESCPOSCommand.UnderlineMode.double.rawValue {
                styled = Self.ansiDoubleUnderlineOn + styled
            } else if effectiveUnderline == ESCPOSCommand.UnderlineMode.single.rawValue {
                styled = Self.ansiUnderlineOn + styled
            }
            if status.reverse { styled = Self.ansiReverseOn + styled }
        }

        let aligned = applyJustification(content, styled: styled, justification: status.justification)

        let needsReset = ansiStyleEnabled && (status.bold || status.underlineMode != .off || status.kanjiUnderlineMode != .off || status.reverse)
        if needsReset {
            outputLine(aligned + Self.ansiReset)
        } else {
            outputLine(aligned)
        }
    }

    private func applyJustification(_ raw: String, styled: String, justification: ESCPOSCommand.Justification) -> String {
        let visibleLength = raw.count
        guard visibleLength < paperWidth else { return styled }

        switch justification {
        case .left:
            return styled
        case .center:
            let padding = (paperWidth - visibleLength) / 2
            return String(repeating: " ", count: padding) + styled
        case .right:
            let padding = paperWidth - visibleLength
            return String(repeating: " ", count: padding) + styled
        }
    }

    private func applySixelJustification(_ sixel: String, imageCharWidth: Int, justification: ESCPOSCommand.Justification) -> String {
        guard imageCharWidth < paperWidth else { return sixel }

        switch justification {
        case .left:
            return sixel
        case .center:
            let padding = (paperWidth - imageCharWidth) / 2
            return String(repeating: " ", count: padding) + sixel
        case .right:
            let padding = paperWidth - imageCharWidth
            return String(repeating: " ", count: padding) + sixel
        }
    }

    private func printCentered(_ text: String) {
        let length = text.count
        if length >= paperWidth {
            outputLine(text)
        } else {
            let padding = (paperWidth - length) / 2
            outputLine(String(repeating: " ", count: padding) + text)
        }
    }

    // MARK: - NV Graphics Placeholder

    /// 指定テキストを描いたダミービットマップを生成する
    private static func generateNVGraphicsPlaceholder(text: String, scaleX: Int, scaleY: Int) -> (data: Data, widthBytes: Int, height: Int) {
        let glyphs = text.compactMap { pixelFont[$0] }
        guard !glyphs.isEmpty else {
            return (Data([0x80]), 1, 1)
        }

        let charW = 5, charH = 7, gap = 1, pad = 2, border = 1
        let textW = glyphs.count * charW + (glyphs.count - 1) * gap
        let baseW = textW + 2 * pad + 2 * border
        let baseH = charH + 2 * pad + 2 * border

        let baseScale = 4
        let sx = max(scaleX, 1) * baseScale, sy = max(scaleY, 1) * baseScale
        let w = baseW * sx, h = baseH * sy
        let widthBytes = (w + 7) / 8
        var bitmap = Data(repeating: 0, count: widthBytes * h)

        func setPixel(_ x: Int, _ y: Int) {
            guard x >= 0, x < w, y >= 0, y < h else { return }
            bitmap[y * widthBytes + x / 8] |= UInt8(1 << (7 - x % 8))
        }
        func fill(bx: Int, by: Int) {
            for dy in 0..<sy { for dx in 0..<sx { setPixel(bx * sx + dx, by * sy + dy) } }
        }

        for x in 0..<baseW { fill(bx: x, by: 0); fill(bx: x, by: baseH - 1) }
        for y in 0..<baseH { fill(bx: 0, by: y); fill(bx: baseW - 1, by: y) }

        let ox = border + pad, oy = border + pad
        for (gi, glyph) in glyphs.enumerated() {
            let gx = ox + gi * (charW + gap)
            for row in 0..<charH {
                for col in 0..<charW {
                    if (glyph[row] >> (charW - 1 - col)) & 1 == 1 {
                        fill(bx: gx + col, by: oy + row)
                    }
                }
            }
        }

        return (bitmap, widthBytes, h)
    }

    private static let pixelFont: [Character: [UInt8]] = [
        "0": [0b01110, 0b10001, 0b10001, 0b10001, 0b10001, 0b10001, 0b01110],
        "1": [0b00100, 0b01100, 0b00100, 0b00100, 0b00100, 0b00100, 0b01110],
        "2": [0b01110, 0b10001, 0b00001, 0b00110, 0b01000, 0b10000, 0b11111],
        "3": [0b01110, 0b10001, 0b00001, 0b00110, 0b00001, 0b10001, 0b01110],
        "4": [0b00010, 0b00110, 0b01010, 0b10010, 0b11111, 0b00010, 0b00010],
        "5": [0b11111, 0b10000, 0b11110, 0b00001, 0b00001, 0b10001, 0b01110],
        "6": [0b00110, 0b01000, 0b10000, 0b11110, 0b10001, 0b10001, 0b01110],
        "7": [0b11111, 0b00001, 0b00010, 0b00100, 0b01000, 0b01000, 0b01000],
        "8": [0b01110, 0b10001, 0b10001, 0b01110, 0b10001, 0b10001, 0b01110],
        "9": [0b01110, 0b10001, 0b10001, 0b01111, 0b00001, 0b00010, 0b01100],
        ":": [0b00000, 0b00100, 0b00100, 0b00000, 0b00100, 0b00100, 0b00000],
    ]

    private func dotsToChars(dots: Int, status: PrinterStatus) -> Int {
        let dotsPerChar = max(Int(status.printingWidth) / paperWidth, 1)
        return dots / dotsPerChar
    }

    private func effectiveBarcodeModuleWidth(type: ESCPOSCommand.BarcodeType, data: Data, status: PrinterStatus) -> Int {
        let moduleWidth = Int(status.barcodeWidthMultiplier)
        let paperPixelWidth = cellPixelWidth * paperWidth
        let scale = max(displayScale, 1)
        guard paperPixelWidth > 0, moduleWidth > 1 else { return moduleWidth }

        guard let trial = BarcodeRasterizer.rasterize(
            type: type, data: data, moduleWidth: moduleWidth, height: 1
        ) else {
            return moduleWidth
        }

        let imagePixelWidth = trial.widthBytes * 8
        guard imagePixelWidth * scale > paperPixelWidth else { return moduleWidth }

        let moduleCount = imagePixelWidth / moduleWidth
        guard moduleCount > 0 else { return moduleWidth }
        return max(1, paperPixelWidth / (moduleCount * scale))
    }

    private func barcodeTypeName(_ type: ESCPOSCommand.BarcodeType) -> String {
        switch type {
        case .upcA: return "UPC-A"
        case .upcE: return "UPC-E"
        case .ean13: return "EAN13"
        case .ean8: return "EAN8"
        case .code39: return "CODE39"
        case .itf: return "ITF"
        case .codabar: return "CODABAR"
        case .code93: return "CODE93"
        case .code128: return "CODE128"
        }
    }
}
