import Foundation

#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// ESC/POSコマンドをバイト列にエンコードするエンコーダー
public struct ESCPOSEncoder: Sendable {
    // 制御コード
    private static let NUL: UInt8 = 0x00
    private static let LF: UInt8 = 0x0A
    private static let CR: UInt8 = 0x0D
    private static let HT: UInt8 = 0x09
    private static let DLE: UInt8 = 0x10
    private static let ESC: UInt8 = 0x1B
    private static let FS: UInt8 = 0x1C
    private static let GS: UInt8 = 0x1D

    public init() {}

    /// 単一のESC/POSコマンドをバイト列にエンコード
    public func encode(_ command: ESCPOSCommand) -> Data {
        switch command {
        // MARK: - 制御コマンド
        case .initialize:
            return Data([Self.ESC, 0x40])

        case .lineFeed:
            return Data([Self.LF])

        case .carriageReturn:
            return Data([Self.CR])

        case .horizontalTab:
            return Data([Self.HT])

        case .printAndFeed(let dots):
            return Data([Self.ESC, 0x4A, dots])

        case .printAndReverseFeed(let dots):
            return Data([Self.ESC, 0x4B, dots])

        case .feedLines(let count):
            return Data([Self.ESC, 0x64, count])

        // MARK: - テキストフォーマット
        case .text(let data):
            return data

        case .selectFont(let font):
            return Data([Self.ESC, 0x4D, font.rawValue])

        case .boldOn:
            return Data([Self.ESC, 0x45, 0x01])

        case .boldOff:
            return Data([Self.ESC, 0x45, 0x00])

        case .underline(let mode):
            return Data([Self.ESC, 0x2D, mode.rawValue])

        case .characterSize(let width, let height):
            let w = min(width, 8) - 1
            let h = min(height, 8) - 1
            let n = (w << 4) | h
            return Data([Self.GS, 0x21, n])

        case .reverseMode(let enabled):
            return Data([Self.GS, 0x42, enabled ? 0x01 : 0x00])

        case .rotate90(let enabled):
            return Data([Self.ESC, 0x56, enabled ? 0x01 : 0x00])

        case .upsideDown(let enabled):
            return Data([Self.ESC, 0x7B, enabled ? 0x01 : 0x00])

        // MARK: - 配置
        case .justification(let justification):
            return Data([Self.ESC, 0x61, justification.rawValue])

        case .leftMargin(let dots):
            let nL = UInt8(dots & 0xFF)
            let nH = UInt8((dots >> 8) & 0xFF)
            return Data([Self.GS, 0x4C, nL, nH])

        case .printingWidth(let dots):
            let nL = UInt8(dots & 0xFF)
            let nH = UInt8((dots >> 8) & 0xFF)
            return Data([Self.GS, 0x57, nL, nH])

        // MARK: - 行間隔
        case .defaultLineSpacing:
            return Data([Self.ESC, 0x32])

        case .lineSpacing(let dots):
            return Data([Self.ESC, 0x33, dots])

        // MARK: - カット
        case .cut(let mode):
            return Data([Self.GS, 0x56, mode.rawValue])

        case .cutWithFeed(let mode, let feed):
            return Data([Self.GS, 0x56, mode.rawValue, feed])

        // MARK: - キャッシュドロワー
        case .openCashDrawer(let pin, let onTime, let offTime):
            return Data([Self.ESC, 0x70, pin, onTime, offTime])

        // MARK: - バーコード
        case .barcodeHeight(let dots):
            return Data([Self.GS, 0x68, dots])

        case .barcodeWidth(let multiplier):
            return Data([Self.GS, 0x77, multiplier])

        case .barcodeHRIPosition(let position):
            return Data([Self.GS, 0x48, position.rawValue])

        case .barcodeHRIFont(let font):
            return Data([Self.GS, 0x66, font.rawValue])

        case .barcode(let type, let data):
            return encodeBarcode(type: type, data: data)

        // MARK: - QRコード
        case .qrCodeModel(let model):
            // GS ( k pL pH cn fn n1 n2
            return Data([Self.GS, 0x28, 0x6B, 0x04, 0x00, 0x31, 0x41, model, 0x00])

        case .qrCodeSize(let moduleSize):
            // GS ( k pL pH cn fn n
            return Data([Self.GS, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, moduleSize])

        case .qrCodeErrorCorrection(let level):
            // GS ( k pL pH cn fn n
            return Data([Self.GS, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, level.rawValue])

        case .qrCodeStore(let data):
            return encodeQRCodeStore(data: data)

        case .qrCodePrint:
            // GS ( k pL pH cn fn m
            return Data([Self.GS, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30])

        // MARK: - 画像
        case .rasterImage(let mode, let width, let height, let data):
            return encodeRasterImage(mode: mode, width: width, height: height, data: data)

        // MARK: - グラフィックス (GS ( L)
        case .graphicsStore(let tone, let scaleX, let scaleY, let color, let width, let height, let data):
            return encodeGraphicsStore(tone: tone, scaleX: scaleX, scaleY: scaleY, color: color, width: width, height: height, data: data)

        case .graphicsPrint:
            // GS ( L pL pH m fn
            // pL=2, pH=0, m=48, fn=50
            return Data([Self.GS, 0x28, 0x4C, 0x02, 0x00, 0x30, 0x32])

        case .nvGraphicsPrint(let kc1, let kc2, let x, let y):
            // GS ( L pL pH m fn kc1 kc2 x y
            // pL=6, pH=0, m=48, fn=69
            return Data([Self.GS, 0x28, 0x4C, 0x06, 0x00, 0x30, 0x45, kc1, kc2, x, y])

        // MARK: - ステータス
        case .realtimeStatusRequest(let type):
            return Data([Self.DLE, 0x04, type])

        case .requestProcessIdResponse(let d1, let d2, let d3, let d4):
            // GS ( H pL pH fn m d1 d2 d3 d4
            // pL=6, pH=0, fn=48(0x30), m=48(0x30)
            return Data([Self.GS, 0x28, 0x48, 0x06, 0x00, 0x30, 0x30, d1, d2, d3, d4])

        // MARK: - 漢字関連 (FS)
        case .selectKanjiCodeSystem(let codeSystem):
            return Data([Self.FS, 0x43, codeSystem.rawValue])

        // MARK: - その他
        case .unknown(let data):
            return data

        case .rawData(let data):
            return data
        }
    }

    /// 複数のESC/POSコマンドをバイト列にエンコード
    public func encode(_ commands: [ESCPOSCommand]) -> Data {
        var result = Data()
        for command in commands {
            result.append(encode(command))
        }
        return result
    }

    // MARK: - Private Methods

    private func encodeBarcode(type: ESCPOSCommand.BarcodeType, data: Data) -> Data {
        var result = Data()
        result.append(Self.GS)
        result.append(0x6B)

        // Format B (長さ指定方式) を使用
        let m: UInt8
        switch type {
        case .upcA: m = 65
        case .upcE: m = 66
        case .ean13: m = 67
        case .ean8: m = 68
        case .code39: m = 69
        case .itf: m = 70
        case .codabar: m = 71
        case .code93: m = 72
        case .code128: m = 73
        }

        result.append(m)
        result.append(UInt8(data.count))
        result.append(data)

        return result
    }

    private func encodeQRCodeStore(data: Data) -> Data {
        // GS ( k pL pH cn fn m d1...dk
        // pL pH = length of (cn fn m d1...dk) = 3 + data.count
        let length = 3 + data.count
        let pL = UInt8(length & 0xFF)
        let pH = UInt8((length >> 8) & 0xFF)

        var result = Data()
        result.append(Self.GS)
        result.append(0x28)
        result.append(0x6B)
        result.append(pL)
        result.append(pH)
        result.append(0x31)  // cn
        result.append(0x50)  // fn (store)
        result.append(0x30)  // m
        result.append(data)

        return result
    }

    private func encodeRasterImage(mode: ESCPOSCommand.RasterMode, width: UInt16, height: UInt16, data: Data) -> Data {
        // GS v 0 m xL xH yL yH d1...dk
        var result = Data()
        result.append(Self.GS)
        result.append(0x76)
        result.append(0x30)  // '0'
        result.append(mode.rawValue)
        result.append(UInt8(width & 0xFF))
        result.append(UInt8((width >> 8) & 0xFF))
        result.append(UInt8(height & 0xFF))
        result.append(UInt8((height >> 8) & 0xFF))
        result.append(data)

        return result
    }

    private func encodeGraphicsStore(
        tone: ESCPOSCommand.GraphicsTone,
        scaleX: UInt8,
        scaleY: UInt8,
        color: ESCPOSCommand.GraphicsColor,
        width: UInt16,
        height: UInt16,
        data: Data
    ) -> Data {
        // GS ( L pL pH m fn a bx by c xL xH yL yH d1...dk
        // m = 48 (0x30), fn = 112 (0x70)
        // パラメータ長 = 11 + データ長
        // (m, fn, a, bx, by, c, xL, xH, yL, yH = 10バイト) + データ
        let paramLength = 10 + data.count
        let pL = UInt8(paramLength & 0xFF)
        let pH = UInt8((paramLength >> 8) & 0xFF)

        var result = Data()
        result.append(Self.GS)
        result.append(0x28)  // '('
        result.append(0x4C)  // 'L'
        result.append(pL)
        result.append(pH)
        result.append(0x30)  // m = 48
        result.append(0x70)  // fn = 112
        result.append(tone.rawValue)  // a
        result.append(scaleX)  // bx
        result.append(scaleY)  // by
        result.append(color.rawValue)  // c
        result.append(UInt8(width & 0xFF))   // xL
        result.append(UInt8((width >> 8) & 0xFF))  // xH
        result.append(UInt8(height & 0xFF))  // yL
        result.append(UInt8((height >> 8) & 0xFF))  // yH
        result.append(data)  // d1...dk

        return result
    }
}

// MARK: - ESCPOSCommand Extension for Encoding

public extension ESCPOSCommand {
    /// コマンドをバイト列にエンコード
    func encode() -> Data {
        ESCPOSEncoder().encode(self)
    }
}

// MARK: - Array Extension for Encoding

public extension Array where Element == ESCPOSCommand {
    /// コマンド配列をバイト列にエンコード
    func encode() -> Data {
        ESCPOSEncoder().encode(self)
    }
}

// MARK: - Convenience Builders

public extension ESCPOSEncoder {
    /// テキストを印刷するコマンドを生成（改行なし）
    static func text(_ text: String, encoding: String.Encoding = .shiftJIS) -> ESCPOSCommand? {
        guard let data = text.data(using: encoding) else { return nil }
        return .text(data)
    }

    /// QRコードを印刷する一連のコマンドを生成
    static func printQRCode(
        _ text: String,
        moduleSize: UInt8 = 4,
        errorCorrection: ESCPOSCommand.QRErrorCorrectionLevel = .m,
        encoding: String.Encoding = .utf8
    ) -> [ESCPOSCommand] {
        guard let data = text.data(using: encoding) else { return [] }
        return [
            .qrCodeModel(model: 2),
            .qrCodeSize(moduleSize: moduleSize),
            .qrCodeErrorCorrection(level: errorCorrection),
            .qrCodeStore(data: data),
            .qrCodePrint
        ]
    }

    /// バーコードを印刷する一連のコマンドを生成
    static func printBarcode(
        _ text: String,
        type: ESCPOSCommand.BarcodeType,
        height: UInt8 = 80,
        width: UInt8 = 2,
        hriPosition: ESCPOSCommand.HRIPosition = .below,
        encoding: String.Encoding = .utf8
    ) -> [ESCPOSCommand] {
        guard let data = text.data(using: encoding) else { return [] }
        return [
            .barcodeHeight(dots: height),
            .barcodeWidth(multiplier: width),
            .barcodeHRIPosition(hriPosition),
            .barcode(type: type, data: data)
        ]
    }

    /// グラフィックスを印刷する一連のコマンドを生成 (GS ( L fn=112, fn=50)
    /// - Parameters:
    ///   - data: ラスター形式のグラフィックスデータ
    ///   - width: 横方向のドット数
    ///   - height: 縦方向のドット数
    ///   - tone: データの階調（モノクロまたは多階調）
    ///   - scaleX: 横倍率（1または2）
    ///   - scaleY: 縦倍率（1または2）
    ///   - color: 印刷色
    static func printGraphics(
        data: Data,
        width: UInt16,
        height: UInt16,
        tone: ESCPOSCommand.GraphicsTone = .monochrome,
        scaleX: UInt8 = 1,
        scaleY: UInt8 = 1,
        color: ESCPOSCommand.GraphicsColor = .color1
    ) -> [ESCPOSCommand] {
        return [
            .graphicsStore(
                tone: tone,
                scaleX: scaleX,
                scaleY: scaleY,
                color: color,
                width: width,
                height: height,
                data: data
            ),
            .graphicsPrint
        ]
    }
}

// MARK: - CGImage Raster Image Helpers

#if canImport(CoreGraphics)

/// ラスター画像変換の結果
public struct RasterImageData: Sendable {
    /// ラスターデータ（各行を8ドット=1バイトにパック）
    public let data: Data
    /// 横方向のバイト数（幅を8で割って切り上げ）
    public let widthBytes: UInt16
    /// 縦方向のドット数
    public let height: UInt16

    /// 横方向のドット数（widthBytes × 8）
    public var widthDots: UInt16 {
        widthBytes * 8
    }
}

/// ディザリングアルゴリズム
public enum DitherAlgorithm: Sendable {
    /// ディザリングなし（単純閾値）
    case none
    /// Floyd-Steinbergディザリング
    case floydSteinberg
    /// Atkinsonディザリング
    case atkinson
}

public extension ESCPOSEncoder {

    /// CGImageからGS v 0用のラスターデータを生成
    /// - Parameters:
    ///   - image: 変換元のCGImage
    ///   - maxWidth: 最大幅（ドット数）。nilの場合は元画像の幅を使用
    ///   - threshold: 二値化の閾値（0-255）。デフォルトは128
    ///   - dither: ディザリングアルゴリズム
    ///   - invertColors: 色を反転するか（白黒を入れ替え）
    /// - Returns: ラスターデータ、またはnil（変換失敗時）
    static func rasterData(
        from image: CGImage,
        maxWidth: Int? = nil,
        threshold: UInt8 = 128,
        dither: DitherAlgorithm = .none,
        invertColors: Bool = false
    ) -> RasterImageData? {
        let sourceWidth = image.width
        let sourceHeight = image.height

        // リサイズが必要かチェック
        let targetWidth: Int
        let targetHeight: Int
        if let maxWidth = maxWidth, sourceWidth > maxWidth {
            let scale = Double(maxWidth) / Double(sourceWidth)
            targetWidth = maxWidth
            targetHeight = Int(Double(sourceHeight) * scale)
        } else {
            targetWidth = sourceWidth
            targetHeight = sourceHeight
        }

        // グレースケールのビットマップコンテキストを作成
        let bytesPerRow = targetWidth
        guard let context = CGContext(
            data: nil,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return nil
        }

        // 画像を描画（リサイズも含む）
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))

        guard let pixelData = context.data else {
            return nil
        }

        let pixels = pixelData.bindMemory(to: UInt8.self, capacity: targetWidth * targetHeight)

        // ディザリング処理用のバッファ
        var grayscaleBuffer: [Int16]
        if dither != .none {
            grayscaleBuffer = (0..<(targetWidth * targetHeight)).map { Int16(pixels[$0]) }
        } else {
            grayscaleBuffer = []
        }

        // ディザリング処理
        if dither == .floydSteinberg {
            applyFloydSteinbergDither(
                buffer: &grayscaleBuffer,
                width: targetWidth,
                height: targetHeight,
                threshold: Int16(threshold)
            )
        } else if dither == .atkinson {
            applyAtkinsonDither(
                buffer: &grayscaleBuffer,
                width: targetWidth,
                height: targetHeight,
                threshold: Int16(threshold)
            )
        }

        // ラスターデータに変換（8ピクセル = 1バイト）
        let widthBytes = (targetWidth + 7) / 8
        var rasterData = Data(count: widthBytes * targetHeight)

        for y in 0..<targetHeight {
            for x in 0..<targetWidth {
                let pixelIndex = y * targetWidth + x
                let grayscale: UInt8
                if dither != .none {
                    grayscale = grayscaleBuffer[pixelIndex] < Int16(threshold) ? 0 : 255
                } else {
                    grayscale = pixels[pixelIndex]
                }

                // 閾値より暗いピクセルは印字（ビット=1）
                var shouldPrint = grayscale < threshold
                if invertColors {
                    shouldPrint = !shouldPrint
                }

                if shouldPrint {
                    let byteIndex = y * widthBytes + (x / 8)
                    let bitPosition = 7 - (x % 8)  // MSBが左端
                    rasterData[byteIndex] |= (1 << bitPosition)
                }
            }
        }

        return RasterImageData(
            data: rasterData,
            widthBytes: UInt16(widthBytes),
            height: UInt16(targetHeight)
        )
    }

    /// CGImageからGS v 0のラスター画像印刷コマンドを生成
    /// - Parameters:
    ///   - image: 変換元のCGImage
    ///   - maxWidth: 最大幅（ドット数）
    ///   - mode: ラスターモード（通常、2倍幅、2倍高さ、4倍）
    ///   - threshold: 二値化の閾値（0-255）
    ///   - dither: ディザリングアルゴリズム
    ///   - invertColors: 色を反転するか
    /// - Returns: ラスター画像コマンド、またはnil
    static func rasterImage(
        from image: CGImage,
        maxWidth: Int? = nil,
        mode: ESCPOSCommand.RasterMode = .normal,
        threshold: UInt8 = 128,
        dither: DitherAlgorithm = .none,
        invertColors: Bool = false
    ) -> ESCPOSCommand? {
        guard let raster = rasterData(
            from: image,
            maxWidth: maxWidth,
            threshold: threshold,
            dither: dither,
            invertColors: invertColors
        ) else {
            return nil
        }

        return .rasterImage(
            mode: mode,
            width: raster.widthBytes,
            height: raster.height,
            data: raster.data
        )
    }

    // MARK: - GS ( L Graphics Helpers

    /// CGImageからGS ( L fn=112用のグラフィックスデータを生成
    /// - Parameters:
    ///   - image: 変換元のCGImage
    ///   - maxWidth: 最大幅（ドット数）。nilの場合は元画像の幅を使用
    ///   - threshold: 二値化の閾値（0-255）
    ///   - dither: ディザリングアルゴリズム
    ///   - invertColors: 色を反転するか
    /// - Returns: ラスターデータ、またはnil
    /// - Note: GS ( L fn=112では横幅はドット数で指定するため、RasterImageDataのwidthDotsを使用してください
    static func graphicsData(
        from image: CGImage,
        maxWidth: Int? = nil,
        threshold: UInt8 = 128,
        dither: DitherAlgorithm = .none,
        invertColors: Bool = false
    ) -> RasterImageData? {
        return rasterData(
            from: image,
            maxWidth: maxWidth,
            threshold: threshold,
            dither: dither,
            invertColors: invertColors
        )
    }

    /// CGImageからGS ( L fn=112のグラフィックス格納コマンドを生成
    /// - Parameters:
    ///   - image: 変換元のCGImage
    ///   - maxWidth: 最大幅（ドット数）
    ///   - tone: データの階調
    ///   - scaleX: 横倍率（1または2）
    ///   - scaleY: 縦倍率（1または2）
    ///   - color: 印刷色
    ///   - threshold: 二値化の閾値（0-255）
    ///   - dither: ディザリングアルゴリズム
    ///   - invertColors: 色を反転するか
    /// - Returns: グラフィックス格納コマンド、またはnil
    static func graphicsStore(
        from image: CGImage,
        maxWidth: Int? = nil,
        tone: ESCPOSCommand.GraphicsTone = .monochrome,
        scaleX: UInt8 = 1,
        scaleY: UInt8 = 1,
        color: ESCPOSCommand.GraphicsColor = .color1,
        threshold: UInt8 = 128,
        dither: DitherAlgorithm = .none,
        invertColors: Bool = false
    ) -> ESCPOSCommand? {
        guard let raster = graphicsData(
            from: image,
            maxWidth: maxWidth,
            threshold: threshold,
            dither: dither,
            invertColors: invertColors
        ) else {
            return nil
        }

        return .graphicsStore(
            tone: tone,
            scaleX: scaleX,
            scaleY: scaleY,
            color: color,
            width: raster.widthDots,
            height: raster.height,
            data: raster.data
        )
    }

    /// CGImageからGS ( Lのグラフィックス印刷コマンドを生成（格納+印字）
    /// - Parameters:
    ///   - image: 変換元のCGImage
    ///   - maxWidth: 最大幅（ドット数）
    ///   - tone: データの階調
    ///   - scaleX: 横倍率（1または2）
    ///   - scaleY: 縦倍率（1または2）
    ///   - color: 印刷色
    ///   - threshold: 二値化の閾値（0-255）
    ///   - dither: ディザリングアルゴリズム
    ///   - invertColors: 色を反転するか
    /// - Returns: グラフィックス格納+印刷コマンドの配列、または空配列
    static func printGraphics(
        from image: CGImage,
        maxWidth: Int? = nil,
        tone: ESCPOSCommand.GraphicsTone = .monochrome,
        scaleX: UInt8 = 1,
        scaleY: UInt8 = 1,
        color: ESCPOSCommand.GraphicsColor = .color1,
        threshold: UInt8 = 128,
        dither: DitherAlgorithm = .none,
        invertColors: Bool = false
    ) -> [ESCPOSCommand] {
        guard let storeCommand = graphicsStore(
            from: image,
            maxWidth: maxWidth,
            tone: tone,
            scaleX: scaleX,
            scaleY: scaleY,
            color: color,
            threshold: threshold,
            dither: dither,
            invertColors: invertColors
        ) else {
            return []
        }

        return [storeCommand, .graphicsPrint]
    }

    // MARK: - Private Dithering Methods

    private static func applyFloydSteinbergDither(
        buffer: inout [Int16],
        width: Int,
        height: Int,
        threshold: Int16
    ) {
        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                let oldPixel = buffer[index]
                let newPixel: Int16 = oldPixel < threshold ? 0 : 255
                let error = oldPixel - newPixel
                buffer[index] = newPixel

                // Floyd-Steinberg誤差拡散
                //     * 7/16
                // 3/16 5/16 1/16
                if x + 1 < width {
                    buffer[index + 1] += error * 7 / 16
                }
                if y + 1 < height {
                    if x > 0 {
                        buffer[index + width - 1] += error * 3 / 16
                    }
                    buffer[index + width] += error * 5 / 16
                    if x + 1 < width {
                        buffer[index + width + 1] += error * 1 / 16
                    }
                }
            }
        }
    }

    private static func applyAtkinsonDither(
        buffer: inout [Int16],
        width: Int,
        height: Int,
        threshold: Int16
    ) {
        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                let oldPixel = buffer[index]
                let newPixel: Int16 = oldPixel < threshold ? 0 : 255
                let error = oldPixel - newPixel
                buffer[index] = newPixel

                // Atkinsonディザリング（誤差の1/8を6箇所に拡散）
                //     * 1 1
                // 1 1 1
                //   1
                let diffusion = error / 8
                if x + 1 < width {
                    buffer[index + 1] += diffusion
                }
                if x + 2 < width {
                    buffer[index + 2] += diffusion
                }
                if y + 1 < height {
                    if x > 0 {
                        buffer[index + width - 1] += diffusion
                    }
                    buffer[index + width] += diffusion
                    if x + 1 < width {
                        buffer[index + width + 1] += diffusion
                    }
                }
                if y + 2 < height {
                    buffer[index + width * 2] += diffusion
                }
            }
        }
    }
}

#endif
