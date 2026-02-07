import Foundation
import ThermalPrinterCommand

public struct TextReceiptRenderer {
    // MARK: - Output

    public var outputLine: (String) -> Void = { Swift.print($0) }

    // MARK: - Options

    public var ansiStyleEnabled: Bool
    public var sixelEnabled: Bool

    // MARK: - Printer State

    private var bold = false
    private var underlineMode: ESCPOSCommand.UnderlineMode = .off
    private var reverse = false
    private var justification: ESCPOSCommand.Justification = .left
    private var widthMultiplier: UInt8 = 1
    private var heightMultiplier: UInt8 = 1
    private var lineBuffer = ""
    private var barcodeHeight: UInt8 = 162
    private var barcodeWidthMultiplier: UInt8 = 3
    private var barcodeHRIPosition: ESCPOSCommand.HRIPosition = .notPrinted

    private let paperWidth = 48  // 標準的な58mmプリンタの文字幅

    // MARK: - ANSI Escape Codes

    static let ansiReset = "\u{1B}[0m"
    static let ansiBoldOn = "\u{1B}[1m"
    static let ansiBoldOff = "\u{1B}[22m"
    static let ansiUnderlineOn = "\u{1B}[4m"
    static let ansiUnderlineOff = "\u{1B}[24m"
    static let ansiReverseOn = "\u{1B}[7m"
    static let ansiReverseOff = "\u{1B}[27m"

    // MARK: - Initializer

    public init(ansiStyleEnabled: Bool = false, sixelEnabled: Bool = false) {
        self.ansiStyleEnabled = ansiStyleEnabled
        self.sixelEnabled = sixelEnabled
    }

    // MARK: - Rendering

    public mutating func render(_ commands: [ESCPOSCommand]) {
        for command in commands {
            render(command)
        }
    }

    public mutating func render(_ command: ESCPOSCommand) {
        switch command {
        case .initialize:
            resetState()
            printCentered("[PRINTER INITIALIZED]")

        case .text(let data):
            let text = decodeText(data)
            lineBuffer += text

        case .lineFeed:
            flushLine()

        case .carriageReturn:
            break  // 通常LFと組み合わせ、単独では無視

        case .horizontalTab:
            lineBuffer += ("\t")

        case .printAndFeed:
            flushLine()

        case .printAndReverseFeed:
            flushLine()

        case .feedLines(let count):
            flushLine()
            for _ in 1..<count {
                outputLine("")
            }

        case .boldOn:
            bold = true

        case .boldOff:
            bold = false

        case .underline(let mode):
            underlineMode = mode

        case .reverseMode(let enabled):
            reverse = enabled

        case .justification(let j):
            justification = j

        case .characterSize(let width, let height):
            widthMultiplier = width
            heightMultiplier = height

        case .cut(let mode):
            flushLine()
            let modeStr = (mode == .full || mode == .fullWithFeed) ? "FULL" : "PARTIAL"
            printCentered("--- ✂ \(modeStr) CUT ---")

        case .cutWithFeed(let mode, _):
            flushLine()
            let modeStr = (mode == .full || mode == .fullWithFeed) ? "FULL" : "PARTIAL"
            printCentered("--- ✂ \(modeStr) CUT ---")

        case .barcode(let type, let data):
            flushLine()
            if sixelEnabled,
               let image = BarcodeRasterizer.rasterize(
                   type: type,
                   data: data,
                   moduleWidth: Int(barcodeWidthMultiplier),
                   height: Int(barcodeHeight)
               ) {
                let dataStr = String(data: data, encoding: .ascii) ?? data.map { String(format: "%02X", $0) }.joined()
                if barcodeHRIPosition == .above || barcodeHRIPosition == .both {
                    printCentered(dataStr)
                }
                let sixel = SixelEncoder.encode(data: image.data, widthBytes: image.widthBytes, height: image.height)
                outputLine(applySixelJustification(sixel, imageCharWidth: image.widthBytes))
                if barcodeHRIPosition == .below || barcodeHRIPosition == .both {
                    printCentered(dataStr)
                }
            } else {
                let typeName = barcodeTypeName(type)
                let dataStr = String(data: data, encoding: .ascii) ?? data.map { String(format: "%02X", $0) }.joined()
                printCentered("[\(typeName)] ||| \(dataStr) |||")
            }

        case .qrCodeStore(let data):
            flushLine()
            let content = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .shiftJIS) ?? "<binary>"
            printCentered("[QR CODE: \(content)]")

        case .qrCodePrint:
            break  // qrCodeStoreで既に表示済み

        case .rasterImage(_, let width, let height, let data):
            flushLine()
            if sixelEnabled {
                let sixel = SixelEncoder.encode(data: data, widthBytes: Int(width), height: Int(height))
                outputLine(applySixelJustification(sixel, imageCharWidth: Int(width)))
            } else {
                printCentered("[IMAGE: \(width * 8)x\(height) dots]")
            }

        case .graphicsStore(_, _, _, _, let width, let height, let data):
            flushLine()
            if sixelEnabled {
                let widthBytes = (Int(width) + 7) / 8
                let sixel = SixelEncoder.encode(data: data, widthBytes: widthBytes, height: Int(height))
                outputLine(applySixelJustification(sixel, imageCharWidth: widthBytes))
            } else {
                printCentered("[IMAGE: \(width)x\(height) dots]")
            }

        case .graphicsPrint:
            break  // graphicsStoreで既に表示済み

        case .nvGraphicsPrint(let kc1, let kc2, let scaleX, let scaleY):
            flushLine()
            printCentered("[NV GRAPHICS: key=(\(kc1),\(kc2)) scale=\(scaleX)x\(scaleY)]")

        case .openCashDrawer:
            printCentered("[CASH DRAWER OPEN]")

        case .barcodeHeight(let dots):
            barcodeHeight = dots

        case .barcodeWidth(let multiplier):
            barcodeWidthMultiplier = multiplier

        case .barcodeHRIPosition(let position):
            barcodeHRIPosition = position

        case .selectFont, .barcodeHRIFont,
             .qrCodeModel, .qrCodeSize, .qrCodeErrorCorrection,
             .leftMargin, .printingWidth,
             .defaultLineSpacing, .lineSpacing,
             .rotate90, .upsideDown,
             .selectKanjiCodeSystem,
             .realtimeStatusRequest,
             .requestProcessIdResponse:
            break  // 表示には影響しない設定コマンド

        case .unknown, .rawData:
            break
        }
    }

    // MARK: - Private Helpers

    private func decodeText(_ data: Data) -> String {
        // UTF-8を試し、失敗したらShift-JIS
        if let str = String(data: data, encoding: .utf8) {
            return str
        }
        if let str = String(data: data, encoding: .shiftJIS) {
            return str
        }
        return String(data: data, encoding: .ascii) ?? ""
    }

    private mutating func flushLine() {
        let content = lineBuffer
        lineBuffer = ""

        // ANSI装飾を適用
        var styled = content
        if ansiStyleEnabled {
            if bold { styled = Self.ansiBoldOn + styled }
            if underlineMode != .off { styled = Self.ansiUnderlineOn + styled }
            if reverse { styled = Self.ansiReverseOn + styled }
        }

        // 配置を適用
        let aligned = applyJustification(content, styled: styled)

        // リセットを付加して出力
        let needsReset = ansiStyleEnabled && (bold || underlineMode != .off || reverse)
        if needsReset {
            outputLine(aligned + Self.ansiReset)
        } else {
            outputLine(aligned)
        }
    }

    private func applyJustification(_ raw: String, styled: String) -> String {
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

    private func applySixelJustification(_ sixel: String, imageCharWidth: Int) -> String {
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

    private mutating func resetState() {
        bold = false
        underlineMode = .off
        reverse = false
        justification = .left
        widthMultiplier = 1
        heightMultiplier = 1
        lineBuffer = ""
        barcodeHeight = 162
        barcodeWidthMultiplier = 3
        barcodeHRIPosition = .notPrinted
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
