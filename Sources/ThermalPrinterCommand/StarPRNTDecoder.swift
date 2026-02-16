import Foundation

/// StarPRNTバイト列をコマンドにデコードするデコーダー
public struct StarPRNTDecoder: Sendable {
    // 制御コード
    private static let LF: UInt8 = 0x0A
    private static let FF: UInt8 = 0x0C
    private static let HT: UInt8 = 0x09
    private static let SI: UInt8 = 0x0F
    private static let DC2: UInt8 = 0x12
    private static let ETB: UInt8 = 0x17
    private static let EM: UInt8 = 0x19
    private static let SUB: UInt8 = 0x1A
    private static let ESC: UInt8 = 0x1B
    private static let FS: UInt8 = 0x1C
    private static let RS: UInt8 = 0x1E
    private static let GS: UInt8 = 0x1D
    private static let NUL: UInt8 = 0x00
    private static let BEL: UInt8 = 0x07
    private static let ACK: UInt8 = 0x06
    private static let SOH: UInt8 = 0x01
    private static let CAN: UInt8 = 0x18

    /// 不完全なコマンドを保持するバッファ
    private(set) var pendingBuffer = Data()

    public init() {}

    /// バイト列をStarPRNTコマンドの配列にデコード
    ///
    /// デコードできなかったコマンドプレフィクス以降のデータは内部バッファに保持し、
    /// 次回の呼び出し時に結合してデコードを再試行する。
    public mutating func decode(_ newData: Data) -> [StarPRNTCommand] {
        let data: Data
        if pendingBuffer.isEmpty {
            data = newData
        } else {
            var combined = pendingBuffer
            combined.append(newData)
            data = combined
            pendingBuffer = Data()
        }

        var commands: [StarPRNTCommand] = []
        var index = 0
        var textBuffer = Data()

        func flushTextBuffer() {
            if !textBuffer.isEmpty {
                commands.append(.text(textBuffer))
                textBuffer = Data()
            }
        }

        while index < data.count {
            let byte = data[index]

            switch byte {
            case Self.LF:
                flushTextBuffer()
                commands.append(.lineFeed)
                index += 1

            case Self.FF:
                flushTextBuffer()
                commands.append(.formFeed)
                index += 1

            case Self.HT:
                flushTextBuffer()
                commands.append(.horizontalTab)
                index += 1

            case Self.SI:
                flushTextBuffer()
                commands.append(.upsideDownOn)
                index += 1

            case Self.DC2:
                flushTextBuffer()
                commands.append(.upsideDownOff)
                index += 1

            case Self.BEL:
                flushTextBuffer()
                commands.append(.externalDevice1A)
                index += 1

            case Self.FS:
                flushTextBuffer()
                commands.append(.externalDevice1B)
                index += 1

            case Self.SUB:
                flushTextBuffer()
                commands.append(.externalDevice2A)
                index += 1

            case Self.EM:
                flushTextBuffer()
                commands.append(.externalDevice2B)
                index += 1

            case Self.ESC:
                flushTextBuffer()
                if let (command, consumed) = decodeESC(data, from: index) {
                    commands.append(command)
                    index += consumed
                } else {
                    // データ不足の可能性 — 残りをバッファに保持
                    pendingBuffer = Data(data[index...])
                    return commands
                }

            default:
                // 印刷可能な文字または不明なバイトはテキストとして扱う
                textBuffer.append(byte)
                index += 1
            }
        }

        flushTextBuffer()
        return commands
    }

    // MARK: - ESC Commands (0x1B)

    private func decodeESC(_ data: Data, from index: Int) -> (StarPRNTCommand, Int)? {
        guard index + 1 < data.count else { return nil }

        let cmd = data[index + 1]

        switch cmd {
        // ESC @ - 初期化
        case 0x40:
            return (.initialize, 2)

        // ESC E - 太字開始
        case 0x45:
            return (.boldOn, 2)

        // ESC F - 太字終了
        case 0x46:
            return (.boldOff, 2)

        // ESC 4 - 反転開始
        case 0x34:
            return (.reverseOn, 2)

        // ESC 5 - 反転終了
        case 0x35:
            return (.reverseOff, 2)

        // ESC p - JIS漢字モード
        case 0x70:
            return (.jisKanjiMode, 2)

        // ESC q - JIS漢字モード終了
        case 0x71:
            return (.jisKanjiModeCancel, 2)

        // ESC 0 - 行間隔3mm
        case 0x30:
            return (.lineSpacing3mm, 2)

        // ESC - n - アンダーライン
        case 0x2D:
            guard index + 2 < data.count else { return nil }
            let n = data[index + 2]
            return (.underline(enabled: n != 0), 3)

        // ESC _ n - アッパーライン
        case 0x5F:
            guard index + 2 < data.count else { return nil }
            let n = data[index + 2]
            return (.upperline(enabled: n != 0), 3)

        // ESC / n - スラッシュゼロ
        case 0x2F:
            guard index + 2 < data.count else { return nil }
            let n = data[index + 2]
            return (.slashZero(enabled: n != 0), 3)

        // ESC SP n - ANK文字右スペース
        case 0x20:
            guard index + 2 < data.count else { return nil }
            let n = data[index + 2]
            return (.ankRightSpace(dots: n), 3)

        // ESC % n - ダウンロード文字セット
        case 0x25:
            guard index + 2 < data.count else { return nil }
            let n = data[index + 2]
            return (.downloadCharacterEnabled(n != 0), 3)

        // ESC $ n - Shift JIS漢字モード
        case 0x24:
            guard index + 2 < data.count else { return nil }
            let n = data[index + 2]
            return (.shiftJISKanjiMode(enabled: n != 0), 3)

        // ESC R n - 国際文字セット
        case 0x52:
            guard index + 2 < data.count else { return nil }
            let n = data[index + 2]
            return (.selectInternationalCharacter(n), 3)

        // ESC W n - 横倍拡大
        case 0x57:
            guard index + 2 < data.count else { return nil }
            let n = data[index + 2]
            return (.horizontalExpansion(n), 3)

        // ESC h n - 縦倍拡大
        case 0x68:
            guard index + 2 < data.count else { return nil }
            let n = data[index + 2]
            return (.verticalExpansion(n), 3)

        // ESC i n1 n2 - 文字拡大
        case 0x69:
            guard index + 3 < data.count else { return nil }
            let n1 = data[index + 2]
            let n2 = data[index + 3]
            return (.expansion(vertical: n1, horizontal: n2), 4)

        // ESC l n - 左マージン
        case 0x6C:
            guard index + 2 < data.count else { return nil }
            let n = data[index + 2]
            return (.leftMargin(n), 3)

        // ESC Q n - 右マージン
        case 0x51:
            guard index + 2 < data.count else { return nil }
            let n = data[index + 2]
            return (.rightMargin(n), 3)

        // ESC a n - n行フィード
        case 0x61:
            guard index + 2 < data.count else { return nil }
            let n = data[index + 2]
            return (.feedLines(n), 3)

        // ESC z n - 行間隔モード
        case 0x7A:
            guard index + 2 < data.count else { return nil }
            let n = data[index + 2]
            return (.lineSpacingMode(n), 3)

        // ESC J n - 1/4mmフィード
        case 0x4A:
            guard index + 2 < data.count else { return nil }
            let n = data[index + 2]
            return (.feedQuarterMM(n), 3)

        // ESC I n - 1/8mmフィード
        case 0x49:
            guard index + 2 < data.count else { return nil }
            let n = data[index + 2]
            return (.feedEighthMM(n), 3)

        // ESC C n - ページ長
        case 0x43:
            guard index + 2 < data.count else { return nil }
            let n = data[index + 2]
            return (.pageLength(lines: n), 3)

        // ESC d n - カット
        case 0x64:
            guard index + 2 < data.count else { return nil }
            let n = data[index + 2]
            if let mode = StarPRNTCommand.CutMode(rawValue: n) {
                return (.cut(mode), 3)
            }
            return (.unknown(Data(data[index..<index + 3])), 3)

        // ESC D ... NUL - 水平タブ位置
        case 0x44:
            return decodeHorizontalTab(data, from: index)

        // ESC K n1 n2 d... - ビットイメージ（通常密度）
        case 0x4B:
            return decodeBitImage(data, from: index, command: { .bitImageNormal(width: $0, data: $1) })

        // ESC L n1 n2 d... - ビットイメージ（高密度）
        case 0x4C:
            return decodeBitImage(data, from: index, command: { .bitImageHigh(width: $0, data: $1) })

        // ESC k n1 n2 d... - ビットイメージ（精細）
        case 0x6B:
            return decodeBitImage(data, from: index, command: { .bitImageFine(width: $0, data: $1) })

        // ESC b n1 n2 n3 n4 d... RS - バーコード
        case 0x62:
            return decodeBarcode(data, from: index)

        // ESC ACK - リセット/ステータス
        case Self.ACK:
            guard index + 2 < data.count else { return nil }
            let sub = data[index + 2]
            switch sub {
            case Self.CAN:  // ESC ACK CAN - リアルタイムリセット
                return (.realtimeReset, 3)
            case Self.SOH:  // ESC ACK SOH - リアルタイムステータス
                return (.realtimeStatus, 3)
            default:
                return (.unknown(Data(data[index..<min(index + 3, data.count)])), 3)
            }

        // ESC ? LF NUL - プリンターリセット
        case 0x3F:
            guard index + 3 < data.count else { return nil }
            let b2 = data[index + 2]
            let b3 = data[index + 3]
            if b2 == Self.LF && b3 == Self.NUL {
                return (.printerReset, 4)
            }
            return (.unknown(Data(data[index..<min(index + 4, data.count)])), 4)

        // ESC BEL n1 n2 - ブザー
        case Self.BEL:
            guard index + 3 < data.count else { return nil }
            let n1 = data[index + 2]
            let n2 = data[index + 3]
            return (.buzzer(n1: n1, n2: n2), 4)

        // ESC RS - 2バイトプレフィクスコマンド
        case Self.RS:
            return decodeESCRS(data, from: index)

        // ESC GS - 2バイトプレフィクスコマンド
        case Self.GS:
            return decodeESCGS(data, from: index)

        default:
            return (.unknown(Data(data[index..<min(index + 2, data.count)])), 2)
        }
    }

    // MARK: - ESC RS Commands (1B 1E)

    private func decodeESCRS(_ data: Data, from index: Int) -> (StarPRNTCommand, Int)? {
        // ESC RS の後に少なくとも1バイト必要
        guard index + 2 < data.count else { return nil }

        let cmd = data[index + 2]

        switch cmd {
        // ESC RS F n - フォント選択
        case 0x46:
            guard index + 3 < data.count else { return nil }
            let n = data[index + 3]
            if let font = StarPRNTCommand.Font(rawValue: n) {
                return (.selectFont(font), 4)
            }
            return (.unknown(Data(data[index..<index + 4])), 4)

        // ESC RS T n - トップマージン
        case 0x54:
            guard index + 3 < data.count else { return nil }
            let n = data[index + 3]
            return (.topMargin(n), 4)

        // ESC RS a n - 自動ステータス
        case 0x61:
            guard index + 3 < data.count else { return nil }
            let n = data[index + 3]
            return (.autoStatusSetting(n), 4)

        // ESC RS A n - 印字エリア
        case 0x41:
            guard index + 3 < data.count else { return nil }
            let n = data[index + 3]
            return (.printArea(n), 4)

        // ESC RS d n - 印字濃度
        case 0x64:
            guard index + 3 < data.count else { return nil }
            let n = data[index + 3]
            return (.printDensity(n), 4)

        // ESC RS r n - 印字速度
        case 0x72:
            guard index + 3 < data.count else { return nil }
            let n = data[index + 3]
            return (.printSpeed(n), 4)

        // ESC RS c n - 2色印字カラー
        case 0x63:
            guard index + 3 < data.count else { return nil }
            let n = data[index + 3]
            return (.twoColorPrintColor(n), 4)

        // ESC RS C n - 2色モード
        case 0x43:
            guard index + 3 < data.count else { return nil }
            let n = data[index + 3]
            return (.twoColorMode(enabled: n != 0), 4)

        default:
            return (.unknown(Data(data[index..<min(index + 3, data.count)])), 3)
        }
    }

    // MARK: - ESC GS Commands (1B 1D)

    private func decodeESCGS(_ data: Data, from index: Int) -> (StarPRNTCommand, Int)? {
        // ESC GS の後に少なくとも1バイト必要
        guard index + 2 < data.count else { return nil }

        let cmd = data[index + 2]

        switch cmd {
        // ESC GS t n - コードページ選択
        case 0x74:
            guard index + 3 < data.count else { return nil }
            let n = data[index + 3]
            return (.selectCodePage(n), 4)

        // ESC GS b n - スムージング
        case 0x62:
            guard index + 3 < data.count else { return nil }
            let n = data[index + 3]
            return (.smoothing(enabled: n != 0), 4)

        // ESC GS A n1 n2 - 絶対位置
        case 0x41:
            guard index + 4 < data.count else { return nil }
            let n1 = data[index + 3]
            let n2 = data[index + 4]
            let pos = UInt16(n1) | (UInt16(n2) << 8)
            return (.absolutePosition(pos), 5)

        // ESC GS R n1 n2 - 相対位置
        case 0x52:
            guard index + 4 < data.count else { return nil }
            let n1 = data[index + 3]
            let n2 = data[index + 4]
            let pos = Int16(bitPattern: UInt16(n1) | (UInt16(n2) << 8))
            return (.relativePosition(pos), 5)

        // ESC GS a n - 配置
        case 0x61:
            guard index + 3 < data.count else { return nil }
            let n = data[index + 3]
            if let alignment = StarPRNTCommand.Alignment(rawValue: n) {
                return (.alignment(alignment), 4)
            }
            return (.unknown(Data(data[index..<index + 4])), 4)

        // ESC GS P - ページモード
        case 0x50:
            return decodePageMode(data, from: index)

        // ESC GS S - ラスターグラフィックス
        case 0x53:
            return decodeRasterGraphics(data, from: index)

        // ESC GS y - QRコード
        case 0x79:
            return decodeQRCode(data, from: index)

        // ESC GS x - PDF417
        case 0x78:
            return decodePDF417(data, from: index)

        default:
            return (.unknown(Data(data[index..<min(index + 3, data.count)])), 3)
        }
    }

    // MARK: - Page Mode (ESC GS P)

    private func decodePageMode(_ data: Data, from index: Int) -> (StarPRNTCommand, Int)? {
        // ESC GS P の後に少なくとも1バイト必要
        guard index + 3 < data.count else { return nil }

        let sub = data[index + 3]

        switch sub {
        case 0x30:  // ESC GS P 0 - ページモード開始
            return (.pageModeOn, 4)

        case 0x31:  // ESC GS P 1 - ページモード終了
            return (.pageModeOff, 4)

        case 0x32:  // ESC GS P 2 n - 印字方向
            guard index + 4 < data.count else { return nil }
            let n = data[index + 4]
            return (.pageModeDirection(n), 5)

        case 0x33:  // ESC GS P 3 xL xH yL yH dxL dxH dyL dyH
            guard index + 11 < data.count else { return nil }
            let xL = data[index + 4]
            let xH = data[index + 5]
            let yL = data[index + 6]
            let yH = data[index + 7]
            let dxL = data[index + 8]
            let dxH = data[index + 9]
            let dyL = data[index + 10]
            let dyH = data[index + 11]
            let x = UInt16(xL) | (UInt16(xH) << 8)
            let y = UInt16(yL) | (UInt16(yH) << 8)
            let dx = UInt16(dxL) | (UInt16(dxH) << 8)
            let dy = UInt16(dyL) | (UInt16(dyH) << 8)
            return (.pageModePrintArea(x: x, y: y, dx: dx, dy: dy), 12)

        case 0x36:  // ESC GS P 6 - ページモード印字
            return (.pageModePrint, 4)

        case 0x37:  // ESC GS P 7 - ページモード印字して終了
            return (.pageModePrintAndExit, 4)

        case 0x38:  // ESC GS P 8 - ページモードキャンセル
            return (.pageModeCancel, 4)

        default:
            return (.unknown(Data(data[index..<min(index + 4, data.count)])), 4)
        }
    }

    // MARK: - Horizontal Tab (ESC D)

    private func decodeHorizontalTab(_ data: Data, from index: Int) -> (StarPRNTCommand, Int)? {
        // ESC D の後のバイト列を読む（NUL終端）
        guard index + 2 < data.count else { return nil }

        // 最初のバイトがNULならクリア
        if data[index + 2] == Self.NUL {
            return (.clearHorizontalTab, 3)
        }

        var tabs: [UInt8] = []
        var i = index + 2
        while i < data.count && data[i] != Self.NUL {
            tabs.append(data[i])
            i += 1
        }

        // NUL終端が見つからなかった場合はデータ不足
        guard i < data.count else { return nil }

        let consumed = i - index + 1  // +1 for NUL
        return (.setHorizontalTab(tabs), consumed)
    }

    // MARK: - Bit Image Decoding

    private func decodeBitImage(
        _ data: Data,
        from index: Int,
        command: (UInt16, Data) -> StarPRNTCommand
    ) -> (StarPRNTCommand, Int)? {
        // ESC K/L/k n1 n2 d...
        guard index + 3 < data.count else { return nil }

        let n1 = data[index + 2]
        let n2 = data[index + 3]
        let width = UInt16(n1) | (UInt16(n2) << 8)
        let dataLength = Int(width)

        guard index + 4 + dataLength <= data.count else { return nil }

        let imageData = Data(data[(index + 4)..<(index + 4 + dataLength)])
        return (command(width, imageData), 4 + dataLength)
    }

    // MARK: - Barcode Decoding (ESC b)

    private func decodeBarcode(_ data: Data, from index: Int) -> (StarPRNTCommand, Int)? {
        // ESC b n1 n2 n3 n4 d1...dk RS
        guard index + 5 < data.count else { return nil }

        let n1 = data[index + 2]  // barcode type
        let n2 = data[index + 3]  // mode
        let n3 = data[index + 4]  // width
        let n4 = data[index + 5]  // height

        // RS(0x1E)終端のデータを読む
        var barcodeData = Data()
        var i = index + 6
        while i < data.count && data[i] != Self.RS {
            barcodeData.append(data[i])
            i += 1
        }

        // RS終端が見つからなかった場合はデータ不足
        guard i < data.count else { return nil }

        let consumed = i - index + 1  // +1 for RS

        guard let barcodeType = StarPRNTCommand.BarcodeType(rawValue: n1) else {
            return (.unknown(Data(data[index..<(index + consumed)])), consumed)
        }

        return (.barcode(type: barcodeType, mode: n2, width: n3, height: n4, data: barcodeData), consumed)
    }

    // MARK: - Raster Graphics (ESC GS S)

    private func decodeRasterGraphics(_ data: Data, from index: Int) -> (StarPRNTCommand, Int)? {
        // ESC GS S m xL xH yL yH d...
        guard index + 7 < data.count else { return nil }

        let m = data[index + 3]
        let xL = data[index + 4]
        let xH = data[index + 5]
        let yL = data[index + 6]
        let yH = data[index + 7]

        let width = UInt16(xL) | (UInt16(xH) << 8)
        let height = UInt16(yL) | (UInt16(yH) << 8)
        let dataLength = Int(width) * Int(height)

        guard index + 8 + dataLength <= data.count else { return nil }

        let imageData = Data(data[(index + 8)..<(index + 8 + dataLength)])
        return (.rasterGraphics(mode: m, width: width, height: height, data: imageData), 8 + dataLength)
    }

    // MARK: - QR Code (ESC GS y)

    private func decodeQRCode(_ data: Data, from index: Int) -> (StarPRNTCommand, Int)? {
        // ESC GS y の後に少なくとも1バイト必要
        guard index + 3 < data.count else { return nil }

        let sub = data[index + 3]

        switch sub {
        case 0x53:  // ESC GS y S - 設定
            guard index + 5 < data.count else { return nil }
            let fn = data[index + 4]
            let n = data[index + 5]
            switch fn {
            case 0:  // モデル
                return (.qrCodeModel(n), 6)
            case 1:  // エラー訂正
                return (.qrCodeErrorCorrection(n), 6)
            case 2:  // セルサイズ
                return (.qrCodeCellSize(n), 6)
            default:
                return (.unknown(Data(data[index..<index + 6])), 6)
            }

        case 0x44:  // ESC GS y D - データ格納
            guard index + 7 < data.count else { return nil }
            let fn = data[index + 4]
            guard fn == 1 else {
                return (.unknown(Data(data[index..<min(index + 5, data.count)])), 5)
            }
            let m = data[index + 5]
            _ = m  // m は予約
            let nL = data[index + 6]
            let nH = data[index + 7]
            let dataLength = Int(nL) | (Int(nH) << 8)
            guard index + 8 + dataLength <= data.count else { return nil }
            let qrData = Data(data[(index + 8)..<(index + 8 + dataLength)])
            return (.qrCodeStore(data: qrData), 8 + dataLength)

        case 0x50:  // ESC GS y P - 印刷
            return (.qrCodePrint, 4)

        default:
            return (.unknown(Data(data[index..<min(index + 4, data.count)])), 4)
        }
    }

    // MARK: - PDF417 (ESC GS x)

    private func decodePDF417(_ data: Data, from index: Int) -> (StarPRNTCommand, Int)? {
        // ESC GS x の後に少なくとも1バイト必要
        guard index + 3 < data.count else { return nil }

        let sub = data[index + 3]

        switch sub {
        case 0x53:  // ESC GS x S - 設定
            guard index + 4 < data.count else { return nil }
            let fn = data[index + 4]
            switch fn {
            case 0:  // サイズ (n, p1, p2)
                guard index + 7 < data.count else { return nil }
                let n = data[index + 5]
                let p1 = data[index + 6]
                let p2 = data[index + 7]
                return (.pdf417Size(n, p1: p1, p2: p2), 8)
            case 1:  // ECC
                guard index + 5 < data.count else { return nil }
                let n = data[index + 5]
                return (.pdf417ECC(n), 6)
            case 2:  // モジュール幅
                guard index + 5 < data.count else { return nil }
                let n = data[index + 5]
                return (.pdf417ModuleWidth(n), 6)
            case 3:  // アスペクト比
                guard index + 5 < data.count else { return nil }
                let n = data[index + 5]
                return (.pdf417AspectRatio(n), 6)
            default:
                return (.unknown(Data(data[index..<min(index + 5, data.count)])), 5)
            }

        case 0x44:  // ESC GS x D - データ格納
            guard index + 5 < data.count else { return nil }
            let nL = data[index + 4]
            let nH = data[index + 5]
            let dataLength = Int(nL) | (Int(nH) << 8)
            guard index + 6 + dataLength <= data.count else { return nil }
            let pdfData = Data(data[(index + 6)..<(index + 6 + dataLength)])
            return (.pdf417Store(data: pdfData), 6 + dataLength)

        case 0x50:  // ESC GS x P - 印刷
            return (.pdf417Print, 4)

        default:
            return (.unknown(Data(data[index..<min(index + 4, data.count)])), 4)
        }
    }
}
