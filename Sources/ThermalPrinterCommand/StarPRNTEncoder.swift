import Foundation

/// StarPRNTコマンドをバイト列にエンコードするエンコーダー
public struct StarPRNTEncoder: Sendable {
    // 制御コード
    private static let NUL: UInt8 = 0x00
    private static let BEL: UInt8 = 0x07
    private static let HT: UInt8 = 0x09
    private static let LF: UInt8 = 0x0A
    private static let FF: UInt8 = 0x0C
    private static let SI: UInt8 = 0x0F
    private static let DC2: UInt8 = 0x12
    private static let EM: UInt8 = 0x19
    private static let SUB: UInt8 = 0x1A
    private static let ESC: UInt8 = 0x1B
    private static let FS: UInt8 = 0x1C
    private static let GS: UInt8 = 0x1D
    private static let RS: UInt8 = 0x1E
    private static let ACK: UInt8 = 0x06
    private static let SOH: UInt8 = 0x01
    private static let CAN: UInt8 = 0x18

    public init() {}

    /// 単一のStarPRNTコマンドをバイト列にエンコード
    public func encode(_ command: StarPRNTCommand) -> Data {
        switch command {
        // MARK: - 制御コマンド
        case .initialize:
            return Data([Self.ESC, 0x40])

        case .lineFeed:
            return Data([Self.LF])

        case .formFeed:
            return Data([Self.FF])

        case .horizontalTab:
            return Data([Self.HT])

        // MARK: - フォントスタイル・キャラクタセット
        case .selectFont(let font):
            // ESC RS F n
            return Data([Self.ESC, Self.RS, 0x46, font.rawValue])

        case .selectCodePage(let n):
            // ESC GS t n
            return Data([Self.ESC, Self.GS, 0x74, n])

        case .selectInternationalCharacter(let n):
            // ESC R n
            return Data([Self.ESC, 0x52, n])

        case .slashZero(let enabled):
            // ESC / n
            return Data([Self.ESC, 0x2F, enabled ? 0x01 : 0x00])

        case .ankRightSpace(let dots):
            // ESC SP n
            return Data([Self.ESC, 0x20, dots])

        case .downloadCharacterEnabled(let enabled):
            // ESC % n
            return Data([Self.ESC, 0x25, enabled ? 0x01 : 0x00])

        // MARK: - 漢字
        case .jisKanjiMode:
            // ESC p
            return Data([Self.ESC, 0x70])

        case .jisKanjiModeCancel:
            // ESC q
            return Data([Self.ESC, 0x71])

        case .shiftJISKanjiMode(let enabled):
            // ESC $ n
            return Data([Self.ESC, 0x24, enabled ? 0x01 : 0x00])

        // MARK: - プリントモード
        case .expansion(let vertical, let horizontal):
            // ESC i n1 n2
            return Data([Self.ESC, 0x69, vertical, horizontal])

        case .horizontalExpansion(let n):
            // ESC W n
            return Data([Self.ESC, 0x57, n])

        case .verticalExpansion(let n):
            // ESC h n
            return Data([Self.ESC, 0x68, n])

        case .boldOn:
            // ESC E
            return Data([Self.ESC, 0x45])

        case .boldOff:
            // ESC F
            return Data([Self.ESC, 0x46])

        case .underline(let enabled):
            // ESC - n
            return Data([Self.ESC, 0x2D, enabled ? 0x01 : 0x00])

        case .upperline(let enabled):
            // ESC _ n
            return Data([Self.ESC, 0x5F, enabled ? 0x01 : 0x00])

        case .reverseOn:
            // ESC 4
            return Data([Self.ESC, 0x34])

        case .reverseOff:
            // ESC 5
            return Data([Self.ESC, 0x35])

        case .upsideDownOn:
            // SI
            return Data([Self.SI])

        case .upsideDownOff:
            // DC2
            return Data([Self.DC2])

        case .smoothing(let enabled):
            // ESC GS b n
            return Data([Self.ESC, Self.GS, 0x62, enabled ? 0x01 : 0x00])

        // MARK: - 水平方向位置
        case .leftMargin(let n):
            // ESC l n
            return Data([Self.ESC, 0x6C, n])

        case .rightMargin(let n):
            // ESC Q n
            return Data([Self.ESC, 0x51, n])

        case .absolutePosition(let pos):
            // ESC GS A n1 n2
            let n1 = UInt8(pos & 0xFF)
            let n2 = UInt8((pos >> 8) & 0xFF)
            return Data([Self.ESC, Self.GS, 0x41, n1, n2])

        case .relativePosition(let pos):
            // ESC GS R n1 n2
            let unsigned = UInt16(bitPattern: pos)
            let n1 = UInt8(unsigned & 0xFF)
            let n2 = UInt8((unsigned >> 8) & 0xFF)
            return Data([Self.ESC, Self.GS, 0x52, n1, n2])

        case .alignment(let alignment):
            // ESC GS a n
            return Data([Self.ESC, Self.GS, 0x61, alignment.rawValue])

        case .setHorizontalTab(let tabs):
            // ESC D n1...nk NUL
            var result = Data([Self.ESC, 0x44])
            for tab in tabs {
                result.append(tab)
            }
            result.append(Self.NUL)
            return result

        case .clearHorizontalTab:
            // ESC D NUL
            return Data([Self.ESC, 0x44, Self.NUL])

        // MARK: - 行間隔
        case .feedLines(let n):
            // ESC a n
            return Data([Self.ESC, 0x61, n])

        case .lineSpacingMode(let n):
            // ESC z n
            return Data([Self.ESC, 0x7A, n])

        case .lineSpacing3mm:
            // ESC 0
            return Data([Self.ESC, 0x30])

        case .feedQuarterMM(let n):
            // ESC J n
            return Data([Self.ESC, 0x4A, n])

        case .feedEighthMM(let n):
            // ESC I n
            return Data([Self.ESC, 0x49, n])

        // MARK: - ページ管理
        case .pageLength(let lines):
            // ESC C n
            return Data([Self.ESC, 0x43, lines])

        // MARK: - トップマージン
        case .topMargin(let n):
            // ESC RS T n
            return Data([Self.ESC, Self.RS, 0x54, n])

        // MARK: - カッター
        case .cut(let mode):
            // ESC d n
            return Data([Self.ESC, 0x64, mode.rawValue])

        // MARK: - ページモード
        case .pageModeOn:
            // ESC GS P 0
            return Data([Self.ESC, Self.GS, 0x50, 0x30])

        case .pageModeOff:
            // ESC GS P 1
            return Data([Self.ESC, Self.GS, 0x50, 0x31])

        case .pageModeDirection(let n):
            // ESC GS P 2 n
            return Data([Self.ESC, Self.GS, 0x50, 0x32, n])

        case .pageModePrintArea(let x, let y, let dx, let dy):
            // ESC GS P 3 xL xH yL yH dxL dxH dyL dyH
            return Data([
                Self.ESC, Self.GS, 0x50, 0x33,
                UInt8(x & 0xFF), UInt8((x >> 8) & 0xFF),
                UInt8(y & 0xFF), UInt8((y >> 8) & 0xFF),
                UInt8(dx & 0xFF), UInt8((dx >> 8) & 0xFF),
                UInt8(dy & 0xFF), UInt8((dy >> 8) & 0xFF)
            ])

        case .pageModePrint:
            // ESC GS P 6
            return Data([Self.ESC, Self.GS, 0x50, 0x36])

        case .pageModePrintAndExit:
            // ESC GS P 7
            return Data([Self.ESC, Self.GS, 0x50, 0x37])

        case .pageModeCancel:
            // ESC GS P 8
            return Data([Self.ESC, Self.GS, 0x50, 0x38])

        // MARK: - ビットイメージ
        case .bitImageNormal(let width, let data):
            return encodeBitImage(prefix: 0x4B, width: width, data: data)

        case .bitImageHigh(let width, let data):
            return encodeBitImage(prefix: 0x4C, width: width, data: data)

        case .bitImageFine(let width, let data):
            return encodeBitImage(prefix: 0x6B, width: width, data: data)

        case .rasterGraphics(let mode, let width, let height, let data):
            return encodeRasterGraphics(mode: mode, width: width, height: height, data: data)

        // MARK: - バーコード
        case .barcode(let type, let mode, let width, let height, let data):
            return encodeBarcode(type: type, mode: mode, width: width, height: height, data: data)

        // MARK: - QRコード
        case .qrCodeModel(let n):
            // ESC GS y S 0 n
            return Data([Self.ESC, Self.GS, 0x79, 0x53, 0x00, n])

        case .qrCodeErrorCorrection(let n):
            // ESC GS y S 1 n
            return Data([Self.ESC, Self.GS, 0x79, 0x53, 0x01, n])

        case .qrCodeCellSize(let n):
            // ESC GS y S 2 n
            return Data([Self.ESC, Self.GS, 0x79, 0x53, 0x02, n])

        case .qrCodeStore(let data):
            return encodeQRCodeStore(data: data)

        case .qrCodePrint:
            // ESC GS y P
            return Data([Self.ESC, Self.GS, 0x79, 0x50])

        // MARK: - PDF417
        case .pdf417Size(let n, let p1, let p2):
            // ESC GS x S 0 n p1 p2
            return Data([Self.ESC, Self.GS, 0x78, 0x53, 0x00, n, p1, p2])

        case .pdf417ECC(let n):
            // ESC GS x S 1 n
            return Data([Self.ESC, Self.GS, 0x78, 0x53, 0x01, n])

        case .pdf417ModuleWidth(let n):
            // ESC GS x S 2 n
            return Data([Self.ESC, Self.GS, 0x78, 0x53, 0x02, n])

        case .pdf417AspectRatio(let n):
            // ESC GS x S 3 n
            return Data([Self.ESC, Self.GS, 0x78, 0x53, 0x03, n])

        case .pdf417Store(let data):
            return encodePDF417Store(data: data)

        case .pdf417Print:
            // ESC GS x P
            return Data([Self.ESC, Self.GS, 0x78, 0x50])

        // MARK: - 初期化
        case .realtimeReset:
            // ESC ACK CAN
            return Data([Self.ESC, Self.ACK, Self.CAN])

        case .printerReset:
            // ESC ? LF NUL
            return Data([Self.ESC, 0x3F, Self.LF, Self.NUL])

        // MARK: - ステータス
        case .autoStatusSetting(let n):
            // ESC RS a n
            return Data([Self.ESC, Self.RS, 0x61, n])

        case .realtimeStatus:
            // ESC ACK SOH
            return Data([Self.ESC, Self.ACK, Self.SOH])

        // MARK: - 外部機器
        case .buzzer(let n1, let n2):
            // ESC BEL n1 n2
            return Data([Self.ESC, Self.BEL, n1, n2])

        case .externalDevice1A:
            // BEL
            return Data([Self.BEL])

        case .externalDevice1B:
            // FS
            return Data([Self.FS])

        case .externalDevice2A:
            // SUB
            return Data([Self.SUB])

        case .externalDevice2B:
            // EM
            return Data([Self.EM])

        // MARK: - 印字設定
        case .printArea(let n):
            // ESC RS A n
            return Data([Self.ESC, Self.RS, 0x41, n])

        case .printDensity(let n):
            // ESC RS d n
            return Data([Self.ESC, Self.RS, 0x64, n])

        case .printSpeed(let n):
            // ESC RS r n
            return Data([Self.ESC, Self.RS, 0x72, n])

        // MARK: - 2色印字
        case .twoColorPrintColor(let n):
            // ESC RS c n
            return Data([Self.ESC, Self.RS, 0x63, n])

        case .twoColorMode(let enabled):
            // ESC RS C n
            return Data([Self.ESC, Self.RS, 0x43, enabled ? 0x01 : 0x00])

        // MARK: - テキスト
        case .text(let data):
            return data

        // MARK: - その他
        case .unknown(let data):
            return data
        }
    }

    /// 複数のStarPRNTコマンドをバイト列にエンコード
    public func encode(_ commands: [StarPRNTCommand]) -> Data {
        var result = Data()
        for command in commands {
            result.append(encode(command))
        }
        return result
    }

    // MARK: - Private Methods

    private func encodeBitImage(prefix: UInt8, width: UInt16, data: Data) -> Data {
        // ESC K/L/k n1 n2 d...
        var result = Data([Self.ESC, prefix])
        result.append(UInt8(width & 0xFF))
        result.append(UInt8((width >> 8) & 0xFF))
        result.append(data)
        return result
    }

    private func encodeRasterGraphics(mode: UInt8, width: UInt16, height: UInt16, data: Data) -> Data {
        // ESC GS S m xL xH yL yH d...
        var result = Data([Self.ESC, Self.GS, 0x53, mode])
        result.append(UInt8(width & 0xFF))
        result.append(UInt8((width >> 8) & 0xFF))
        result.append(UInt8(height & 0xFF))
        result.append(UInt8((height >> 8) & 0xFF))
        result.append(data)
        return result
    }

    private func encodeBarcode(type: StarPRNTCommand.BarcodeType, mode: UInt8, width: UInt8, height: UInt8, data: Data) -> Data {
        // ESC b n1 n2 n3 n4 d1...dk RS
        var result = Data([Self.ESC, 0x62, type.rawValue, mode, width, height])
        result.append(data)
        result.append(Self.RS)
        return result
    }

    private func encodeQRCodeStore(data: Data) -> Data {
        // ESC GS y D 1 m nL nH d...
        let nL = UInt8(data.count & 0xFF)
        let nH = UInt8((data.count >> 8) & 0xFF)
        var result = Data([Self.ESC, Self.GS, 0x79, 0x44, 0x01, 0x00, nL, nH])
        result.append(data)
        return result
    }

    private func encodePDF417Store(data: Data) -> Data {
        // ESC GS x D nL nH d...
        let nL = UInt8(data.count & 0xFF)
        let nH = UInt8((data.count >> 8) & 0xFF)
        var result = Data([Self.ESC, Self.GS, 0x78, 0x44, nL, nH])
        result.append(data)
        return result
    }
}

// MARK: - StarPRNTCommand Extension for Encoding

public extension StarPRNTCommand {
    /// コマンドをバイト列にエンコード
    func encode() -> Data {
        StarPRNTEncoder().encode(self)
    }
}

// MARK: - Array Extension for Encoding

public extension Array where Element == StarPRNTCommand {
    /// コマンド配列をバイト列にエンコード
    func encode() -> Data {
        StarPRNTEncoder().encode(self)
    }
}

// MARK: - Convenience Builders

public extension StarPRNTEncoder {
    /// テキストを印刷するコマンドを生成（改行なし）
    static func text(_ text: String, encoding: String.Encoding = .shiftJIS) -> StarPRNTCommand? {
        guard let data = text.data(using: encoding) else { return nil }
        return .text(data)
    }

    /// QRコードを印刷する一連のコマンドを生成
    static func printQRCode(
        _ text: String,
        model: UInt8 = 2,
        cellSize: UInt8 = 4,
        errorCorrection: UInt8 = 1,
        encoding: String.Encoding = .utf8
    ) -> [StarPRNTCommand] {
        guard let data = text.data(using: encoding) else { return [] }
        return [
            .qrCodeModel(model),
            .qrCodeErrorCorrection(errorCorrection),
            .qrCodeCellSize(cellSize),
            .qrCodeStore(data: data),
            .qrCodePrint
        ]
    }

    /// バーコードを印刷する一連のコマンドを生成
    static func printBarcode(
        _ text: String,
        type: StarPRNTCommand.BarcodeType,
        mode: UInt8 = 2,
        width: UInt8 = 2,
        height: UInt8 = 40,
        encoding: String.Encoding = .utf8
    ) -> [StarPRNTCommand] {
        guard let data = text.data(using: encoding) else { return [] }
        return [
            .barcode(type: type, mode: mode, width: width, height: height, data: data)
        ]
    }

    /// PDF417を印刷する一連のコマンドを生成
    static func printPDF417(
        _ text: String,
        moduleWidth: UInt8 = 2,
        ecc: UInt8 = 1,
        encoding: String.Encoding = .utf8
    ) -> [StarPRNTCommand] {
        guard let data = text.data(using: encoding) else { return [] }
        return [
            .pdf417ModuleWidth(moduleWidth),
            .pdf417ECC(ecc),
            .pdf417Store(data: data),
            .pdf417Print
        ]
    }
}
