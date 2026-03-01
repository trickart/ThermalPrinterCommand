import Foundation

/// ESC/POSバイト列をコマンドにデコードするデコーダー
public struct ESCPOSDecoder: Sendable {
    // 制御コード
    private static let NUL: UInt8 = 0x00
    private static let LF: UInt8 = 0x0A
    private static let CR: UInt8 = 0x0D
    private static let HT: UInt8 = 0x09
    private static let DLE: UInt8 = 0x10
    private static let ESC: UInt8 = 0x1B
    private static let FS: UInt8 = 0x1C
    private static let GS: UInt8 = 0x1D

    /// 不完全なコマンドを保持するバッファ
    private(set) var pendingBuffer = Data()

    public init() {}

    /// バイト列をESC/POSコマンドの配列にデコード
    ///
    /// デコードできなかったコマンドプレフィクス以降のデータは内部バッファに保持し、
    /// 次回の呼び出し時に結合してデコードを再試行する。
    public mutating func decode(_ newData: Data) -> [ESCPOSCommand] {
        let data: Data
        if pendingBuffer.isEmpty {
            data = newData
        } else {
            var combined = pendingBuffer
            combined.append(newData)
            data = combined
            pendingBuffer = Data()
        }

        var commands: [ESCPOSCommand] = []
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

            case Self.CR:
                flushTextBuffer()
                commands.append(.carriageReturn)
                index += 1

            case Self.HT:
                flushTextBuffer()
                commands.append(.horizontalTab)
                index += 1

            case Self.DLE:
                flushTextBuffer()
                if let (command, consumed) = decodeDLE(data, from: index) {
                    commands.append(command)
                    index += consumed
                } else {
                    // データ不足の可能性 — 残りをバッファに保持
                    pendingBuffer = Data(data[index...])
                    return commands
                }

            case Self.ESC:
                flushTextBuffer()
                if let (command, consumed) = decodeESC(data, from: index) {
                    commands.append(command)
                    index += consumed
                } else {
                    pendingBuffer = Data(data[index...])
                    return commands
                }

            case Self.GS:
                flushTextBuffer()
                if let (command, consumed) = decodeGS(data, from: index) {
                    commands.append(command)
                    index += consumed
                } else {
                    pendingBuffer = Data(data[index...])
                    return commands
                }

            case Self.FS:
                flushTextBuffer()
                if let (command, consumed) = decodeFS(data, from: index) {
                    commands.append(command)
                    index += consumed
                } else {
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

    // MARK: - DLE Commands (0x10)

    private func decodeDLE(_ data: Data, from index: Int) -> (ESCPOSCommand, Int)? {
        guard index + 1 < data.count else { return nil }

        let cmd = data[index + 1]

        switch cmd {
        case 0x04:  // DLE EOT n - リアルタイムステータス要求
            guard index + 2 < data.count else { return nil }
            let n = data[index + 2]
            return (.realtimeStatusRequest(type: n), 3)

        default:
            return (.unknown(Data(data[index..<min(index + 2, data.count)])), 2)
        }
    }

    // MARK: - ESC Commands (0x1B)

    private func decodeESC(_ data: Data, from index: Int) -> (ESCPOSCommand, Int)? {
        guard index + 1 < data.count else { return nil }

        let cmd = data[index + 1]

        switch cmd {
        case 0x40:  // ESC @ - 初期化
            return (.initialize, 2)

        case 0x4D:  // ESC M n - フォント選択
            guard index + 2 < data.count else { return nil }
            let n = data[index + 2]
            if let font = ESCPOSCommand.Font(rawValue: n) {
                return (.selectFont(font), 3)
            }
            return (.unknown(Data(data[index..<index + 3])), 3)

        case 0x45:  // ESC E n - 太字
            guard index + 2 < data.count else { return nil }
            let n = data[index + 2]
            return (n == 0 ? .boldOff : .boldOn, 3)

        case 0x2D:  // ESC - n - アンダーライン
            guard index + 2 < data.count else { return nil }
            let n = data[index + 2]
            if let mode = ESCPOSCommand.UnderlineMode(rawValue: n) {
                return (.underline(mode), 3)
            }
            return (.unknown(Data(data[index..<index + 3])), 3)

        case 0x61:  // ESC a n - 配置
            guard index + 2 < data.count else { return nil }
            let n = data[index + 2]
            if let justification = ESCPOSCommand.Justification(rawValue: n) {
                return (.justification(justification), 3)
            }
            return (.unknown(Data(data[index..<index + 3])), 3)

        case 0x4A:  // ESC J n - 印刷とフィード
            guard index + 2 < data.count else { return nil }
            let n = data[index + 2]
            return (.printAndFeed(dots: n), 3)

        case 0x4B:  // ESC K n - 印刷と逆フィード
            guard index + 2 < data.count else { return nil }
            let n = data[index + 2]
            return (.printAndReverseFeed(dots: n), 3)

        case 0x64:  // ESC d n - n行フィード
            guard index + 2 < data.count else { return nil }
            let n = data[index + 2]
            return (.feedLines(count: n), 3)

        case 0x32:  // ESC 2 - デフォルト行間隔
            return (.defaultLineSpacing, 2)

        case 0x33:  // ESC 3 n - 行間隔設定
            guard index + 2 < data.count else { return nil }
            let n = data[index + 2]
            return (.lineSpacing(dots: n), 3)

        case 0x56:  // ESC V n - 90度回転
            guard index + 2 < data.count else { return nil }
            let n = data[index + 2]
            return (.rotate90(enabled: n != 0), 3)

        case 0x7B:  // ESC { n - 上下逆
            guard index + 2 < data.count else { return nil }
            let n = data[index + 2]
            return (.upsideDown(enabled: n != 0), 3)

        case 0x70:  // ESC p m t1 t2 - キャッシュドロワー
            guard index + 4 < data.count else { return nil }
            let m = data[index + 2]
            let t1 = data[index + 3]
            let t2 = data[index + 4]
            return (.openCashDrawer(pin: m, onTime: t1, offTime: t2), 5)

        default:
            return (.unknown(Data(data[index..<min(index + 2, data.count)])), 2)
        }
    }

    // MARK: - GS Commands (0x1D)

    private func decodeGS(_ data: Data, from index: Int) -> (ESCPOSCommand, Int)? {
        guard index + 1 < data.count else { return nil }

        let cmd = data[index + 1]

        switch cmd {
        case 0x21:  // GS ! n - 文字サイズ
            guard index + 2 < data.count else { return nil }
            let n = data[index + 2]
            let width = ((n >> 4) & 0x0F) + 1
            let height = (n & 0x0F) + 1
            return (.characterSize(width: width, height: height), 3)

        case 0x42:  // GS B n - 反転
            guard index + 2 < data.count else { return nil }
            let n = data[index + 2]
            return (.reverseMode(enabled: n != 0), 3)

        case 0x4C:  // GS L nL nH - 左マージン
            guard index + 3 < data.count else { return nil }
            let nL = data[index + 2]
            let nH = data[index + 3]
            let dots = UInt16(nL) | (UInt16(nH) << 8)
            return (.leftMargin(dots: dots), 4)

        case 0x57:  // GS W nL nH - 印刷幅
            guard index + 3 < data.count else { return nil }
            let nL = data[index + 2]
            let nH = data[index + 3]
            let dots = UInt16(nL) | (UInt16(nH) << 8)
            return (.printingWidth(dots: dots), 4)

        case 0x56:  // GS V - カット
            guard index + 2 < data.count else { return nil }
            let m = data[index + 2]
            if m == 65 || m == 66 {  // 'A' or 'B' with feed
                guard index + 3 < data.count else { return nil }
                let n = data[index + 3]
                if let mode = ESCPOSCommand.CutMode(rawValue: m) {
                    return (.cutWithFeed(mode: mode, feed: n), 4)
                }
            }
            if let mode = ESCPOSCommand.CutMode(rawValue: m) {
                return (.cut(mode), 3)
            }
            return (.unknown(Data(data[index..<index + 3])), 3)

        case 0x68:  // GS h n - バーコード高さ
            guard index + 2 < data.count else { return nil }
            let n = data[index + 2]
            return (.barcodeHeight(dots: n), 3)

        case 0x77:  // GS w n - バーコード幅
            guard index + 2 < data.count else { return nil }
            let n = data[index + 2]
            return (.barcodeWidth(multiplier: n), 3)

        case 0x48:  // GS H n - HRI位置
            guard index + 2 < data.count else { return nil }
            let n = data[index + 2]
            if let position = ESCPOSCommand.HRIPosition(rawValue: n) {
                return (.barcodeHRIPosition(position), 3)
            }
            return (.unknown(Data(data[index..<index + 3])), 3)

        case 0x66:  // GS f n - HRIフォント
            guard index + 2 < data.count else { return nil }
            let n = data[index + 2]
            if let font = ESCPOSCommand.Font(rawValue: n) {
                return (.barcodeHRIFont(font), 3)
            }
            return (.unknown(Data(data[index..<index + 3])), 3)

        case 0x6B:  // GS k - バーコード印刷
            return decodeBarcode(data, from: index)

        case 0x28:  // GS ( - 拡張コマンド
            guard index + 2 < data.count else { return nil }
            let subCmd = data[index + 2]
            if subCmd == 0x6B {  // GS ( k - QRコード等
                return decodeGSParenK(data, from: index)
            }
            if subCmd == 0x4C {  // GS ( L - グラフィックス
                return decodeGSParenL(data, from: index)
            }
            if subCmd == 0x48 {  // GS ( H - レスポンス/状態通知
                return decodeGSParenH(data, from: index)
            }
            return (.unknown(Data(data[index..<min(index + 3, data.count)])), 3)

        case 0x76:  // GS v 0 - ラスター画像
            return decodeRasterImage(data, from: index)

        default:
            return (.unknown(Data(data[index..<min(index + 2, data.count)])), 2)
        }
    }

    // MARK: - FS Commands (0x1C)

    private func decodeFS(_ data: Data, from index: Int) -> (ESCPOSCommand, Int)? {
        guard index + 1 < data.count else { return nil }

        let cmd = data[index + 1]

        switch cmd {
        case 0x43:  // FS C n - 漢字コード体系の選択
            guard index + 2 < data.count else { return nil }
            let n = data[index + 2]
            if let codeSystem = ESCPOSCommand.KanjiCodeSystem(rawValue: n) {
                return (.selectKanjiCodeSystem(codeSystem), 3)
            }
            return (.unknown(Data(data[index..<index + 3])), 3)

        default:
            return (.unknown(Data(data[index..<min(index + 2, data.count)])), 2)
        }
    }

    // MARK: - Barcode Decoding

    private func decodeBarcode(_ data: Data, from index: Int) -> (ESCPOSCommand, Int)? {
        guard index + 2 < data.count else { return nil }

        let m = data[index + 2]

        // Format A (m = 0-6): NUL終端
        if m <= 6 {
            guard let type = ESCPOSCommand.BarcodeType(rawValue: m) else {
                return (.unknown(Data(data[index..<index + 3])), 3)
            }

            var barcodeData = Data()
            var i = index + 3
            while i < data.count && data[i] != 0x00 {
                barcodeData.append(data[i])
                i += 1
            }
            let consumed = i - index + (i < data.count ? 1 : 0)  // +1 for NUL
            return (.barcode(type: type, data: barcodeData), consumed)
        }

        // Format B (m = 65-77): 長さ指定
        if m >= 65 {
            guard index + 3 < data.count else { return nil }
            let n = Int(data[index + 3])
            guard index + 3 + n < data.count else { return nil }

            // Map extended format codes to BarcodeType
            let type: ESCPOSCommand.BarcodeType?
            switch m {
            case 65: type = .upcA
            case 66: type = .upcE
            case 67: type = .ean13
            case 68: type = .ean8
            case 69: type = .code39
            case 70: type = .itf
            case 71: type = .codabar
            case 72: type = .code93
            case 73: type = .code128
            default: type = nil
            }

            guard let barcodeType = type else {
                return (.unknown(Data(data[index..<index + 4 + n])), 4 + n)
            }

            let barcodeData = Data(data[(index + 4)..<(index + 4 + n)])
            return (.barcode(type: barcodeType, data: barcodeData), 4 + n)
        }

        return (.unknown(Data(data[index..<min(index + 3, data.count)])), 3)
    }

    // MARK: - QR Code Decoding (GS ( k)

    private func decodeGSParenK(_ data: Data, from index: Int) -> (ESCPOSCommand, Int)? {
        // GS ( k pL pH cn fn [parameters]
        guard index + 5 < data.count else { return nil }

        let pL = data[index + 3]
        let pH = data[index + 4]
        let length = Int(pL) | (Int(pH) << 8)

        guard index + 5 + length <= data.count else { return nil }

        let cn = data[index + 5]
        let fn = data[index + 6]

        // QRコードコマンド (cn = 49)
        if cn == 49 {
            switch fn {
            case 65:  // モデル選択
                guard index + 7 < data.count else { return nil }
                let model = data[index + 7]
                return (.qrCodeModel(model: model), 3 + 2 + length)

            case 67:  // サイズ設定
                guard index + 7 < data.count else { return nil }
                let size = data[index + 7]
                return (.qrCodeSize(moduleSize: size), 3 + 2 + length)

            case 69:  // エラー訂正レベル
                guard index + 7 < data.count else { return nil }
                let level = data[index + 7]
                if let ecLevel = ESCPOSCommand.QRErrorCorrectionLevel(rawValue: level) {
                    return (.qrCodeErrorCorrection(level: ecLevel), 3 + 2 + length)
                }

            case 80:  // データ格納
                let dataStart = index + 8
                let dataLength = length - 3  // cn, fn, m を除く
                guard dataStart + dataLength <= data.count else { return nil }
                let qrData = Data(data[dataStart..<(dataStart + dataLength)])
                return (.qrCodeStore(data: qrData), 3 + 2 + length)

            case 81:  // 印刷
                return (.qrCodePrint, 3 + 2 + length)

            default:
                break
            }
        }

        return (.unknown(Data(data[index..<(index + 3 + 2 + length)])), 3 + 2 + length)
    }

    // MARK: - Response/Status Decoding (GS ( H)

    private func decodeGSParenH(_ data: Data, from index: Int) -> (ESCPOSCommand, Int)? {
        // GS ( H pL pH fn m d1 d2 d3 d4
        guard index + 4 < data.count else { return nil }

        let pL = data[index + 3]
        let pH = data[index + 4]
        let length = Int(pL) | (Int(pH) << 8)

        guard index + 5 + length <= data.count else { return nil }

        let fn = data[index + 5]

        if fn == 0x30 {  // fn=48 - プロセスIDレスポンスの指定
            guard length == 6 && index + 10 < data.count else {
                return (.unknown(Data(data[index..<(index + 3 + 2 + length)])), 3 + 2 + length)
            }
            let m = data[index + 6]
            guard m == 0x30 else {
                return (.unknown(Data(data[index..<(index + 3 + 2 + length)])), 3 + 2 + length)
            }
            let d1 = data[index + 7]
            let d2 = data[index + 8]
            let d3 = data[index + 9]
            let d4 = data[index + 10]
            return (.requestProcessIdResponse(d1: d1, d2: d2, d3: d3, d4: d4), 3 + 2 + length)
        }

        return (.unknown(Data(data[index..<(index + 3 + 2 + length)])), 3 + 2 + length)
    }

    // MARK: - Graphics Decoding (GS ( L)

    private func decodeGSParenL(_ data: Data, from index: Int) -> (ESCPOSCommand, Int)? {
        // GS ( L pL pH m fn [parameters]
        guard index + 5 < data.count else { return nil }

        let pL = data[index + 3]
        let pH = data[index + 4]
        let length = Int(pL) | (Int(pH) << 8)

        guard index + 5 + length <= data.count else { return nil }

        let m = data[index + 5]
        let fn = data[index + 6]

        // グラフィックスコマンド (m = 48)
        if m == 0x30 {
            switch fn {
            case 0x32, 0x02:  // fn=50 or fn=2 - グラフィックス印刷
                return (.graphicsPrint, 3 + 2 + length)

            case 0x45:  // fn=69 - 指定されたNVグラフィックスの印字
                guard length == 6 else { break }  // フォーマット不一致 → .unknownへ
                let kc1 = data[index + 7]
                let kc2 = data[index + 8]
                let x = data[index + 9]
                let y = data[index + 10]
                return (.nvGraphicsPrint(keyCode1: kc1, keyCode2: kc2, scaleX: x, scaleY: y), 3 + 2 + length)

            case 0x70:  // fn=112 - グラフィックスデータ格納
                // GS ( L pL pH m fn a bx by c xL xH yL yH d1...dk
                guard index + 14 < data.count else { return nil }
                let a = data[index + 7]
                let bx = data[index + 8]
                let by = data[index + 9]
                let c = data[index + 10]
                let xL = data[index + 11]
                let xH = data[index + 12]
                let yL = data[index + 13]
                let yH = data[index + 14]

                let width = UInt16(xL) | (UInt16(xH) << 8)
                let height = UInt16(yL) | (UInt16(yH) << 8)
                let dataLength = length - 10  // m, fn, a, bx, by, c, xL, xH, yL, yH を除く

                guard dataLength >= 0 && index + 15 + dataLength <= data.count else { return nil }

                let imageData = Data(data[(index + 15)..<(index + 15 + dataLength)])
                let tone = ESCPOSCommand.GraphicsTone(rawValue: a) ?? .monochrome
                let color = ESCPOSCommand.GraphicsColor(rawValue: c) ?? .color1

                return (.graphicsStore(
                    tone: tone,
                    scaleX: bx,
                    scaleY: by,
                    color: color,
                    width: width,
                    height: height,
                    data: imageData
                ), 3 + 2 + length)

            default:
                break
            }
        }

        return (.unknown(Data(data[index..<(index + 3 + 2 + length)])), 3 + 2 + length)
    }

    // MARK: - Raster Image Decoding

    private func decodeRasterImage(_ data: Data, from index: Int) -> (ESCPOSCommand, Int)? {
        // GS v 0 m xL xH yL yH d1...dk
        guard index + 7 < data.count else { return nil }

        let subCmd = data[index + 2]
        guard subCmd == 0x30 else {  // '0'
            return (.unknown(Data(data[index..<min(index + 3, data.count)])), 3)
        }

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
        let mode = ESCPOSCommand.RasterMode(rawValue: m) ?? .normal

        return (.rasterImage(mode: mode, width: width, height: height, data: imageData), 8 + dataLength)
    }
}
