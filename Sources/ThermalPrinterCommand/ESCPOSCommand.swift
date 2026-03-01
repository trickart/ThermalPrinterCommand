import Foundation

/// ESC/POSコマンドを表す列挙型
public enum ESCPOSCommand: Equatable, Sendable {
    // MARK: - 制御コマンド
    /// プリンター初期化 (ESC @)
    case initialize
    /// 改行 (LF)
    case lineFeed
    /// キャリッジリターン (CR)
    case carriageReturn
    /// 水平タブ (HT)
    case horizontalTab
    /// 印刷とフィード (ESC J n)
    case printAndFeed(dots: UInt8)
    /// 印刷と逆フィード (ESC K n)
    case printAndReverseFeed(dots: UInt8)
    /// n行フィード (ESC d n)
    case feedLines(count: UInt8)

    // MARK: - テキストフォーマット
    /// テキストデータ
    case text(Data)
    /// 文字フォント選択 (ESC M n)
    case selectFont(Font)
    /// 太字設定 (ESC E n)
    case boldOn
    case boldOff
    /// アンダーライン設定 (ESC - n)
    case underline(UnderlineMode)
    /// 文字サイズ設定 (GS ! n)
    case characterSize(width: UInt8, height: UInt8)
    /// 反転印刷 (GS B n)
    case reverseMode(enabled: Bool)
    /// 90度回転 (ESC V n)
    case rotate90(enabled: Bool)
    /// 上下逆印刷 (ESC { n)
    case upsideDown(enabled: Bool)

    // MARK: - 配置
    /// 配置設定 (ESC a n)
    case justification(Justification)
    /// 左マージン設定 (GS L nL nH)
    case leftMargin(dots: UInt16)
    /// 印刷幅設定 (GS W nL nH)
    case printingWidth(dots: UInt16)

    // MARK: - 行間隔
    /// デフォルト行間隔 (ESC 2)
    case defaultLineSpacing
    /// 行間隔設定 (ESC 3 n)
    case lineSpacing(dots: UInt8)

    // MARK: - カット
    /// 用紙カット (GS V)
    case cut(CutMode)
    /// 用紙カット（フィード付き）(GS V m n)
    case cutWithFeed(mode: CutMode, feed: UInt8)

    // MARK: - キャッシュドロワー
    /// キャッシュドロワーを開く (ESC p m t1 t2)
    case openCashDrawer(pin: UInt8, onTime: UInt8, offTime: UInt8)

    // MARK: - バーコード
    /// バーコード高さ設定 (GS h n)
    case barcodeHeight(dots: UInt8)
    /// バーコード幅設定 (GS w n)
    case barcodeWidth(multiplier: UInt8)
    /// バーコードHRI位置設定 (GS H n)
    case barcodeHRIPosition(HRIPosition)
    /// バーコードHRIフォント設定 (GS f n)
    case barcodeHRIFont(Font)
    /// バーコード印刷 (GS k m d1...dk NUL or GS k m n d1...dn)
    case barcode(type: BarcodeType, data: Data)

    // MARK: - QRコード (GS ( k)
    /// QRコードモデル選択
    case qrCodeModel(model: UInt8)
    /// QRコードサイズ設定
    case qrCodeSize(moduleSize: UInt8)
    /// QRコードエラー訂正レベル設定
    case qrCodeErrorCorrection(level: QRErrorCorrectionLevel)
    /// QRコードデータ格納
    case qrCodeStore(data: Data)
    /// QRコード印刷
    case qrCodePrint

    // MARK: - 画像
    /// ラスター画像印刷 (GS v 0) [旧コマンド]
    case rasterImage(mode: RasterMode, width: UInt16, height: UInt16, data: Data)

    // MARK: - グラフィックス (GS ( L)
    /// グラフィックスデータ(ラスター形式)のプリントバッファーへの格納 (GS ( L fn=112)
    case graphicsStore(
        tone: GraphicsTone,
        scaleX: UInt8,
        scaleY: UInt8,
        color: GraphicsColor,
        width: UInt16,
        height: UInt16,
        data: Data
    )
    /// プリントバッファーに格納されているグラフィックスデータの印字 (GS ( L fn=50)
    case graphicsPrint
    /// 指定されたNVグラフィックスの印字 (GS ( L fn=69)
    case nvGraphicsPrint(keyCode1: UInt8, keyCode2: UInt8, scaleX: UInt8, scaleY: UInt8)

    // MARK: - ステータス
    /// リアルタイムステータス送信要求 (DLE EOT n)
    case realtimeStatusRequest(type: UInt8)
    /// プロセスIDレスポンスの指定 (GS ( H fn=48)
    case requestProcessIdResponse(d1: UInt8, d2: UInt8, d3: UInt8, d4: UInt8)

    // MARK: - 漢字関連 (FS)
    /// 漢字コード体系の選択 (FS C n)
    case selectKanjiCodeSystem(KanjiCodeSystem)

    // MARK: - その他
    /// 不明なコマンド
    case unknown(Data)
    /// 生データ（解析できなかったバイト）
    case rawData(Data)
}

// MARK: - Properties

public extension ESCPOSCommand {
    /// プリンターからのレスポンスが期待されるコマンドかどうか
    var needsResponse: Bool {
        switch self {
        case .realtimeStatusRequest, .requestProcessIdResponse:
            return true
        default:
            return false
        }
    }
}

// MARK: - Supporting Types

public extension ESCPOSCommand {
    enum Font: UInt8, Sendable {
        case fontA = 0
        case fontB = 1
        case fontC = 2
    }

    enum UnderlineMode: UInt8, Sendable {
        case off = 0
        case single = 1
        case double = 2
    }

    enum Justification: UInt8, Sendable {
        case left = 0
        case center = 1
        case right = 2
    }

    enum CutMode: UInt8, Sendable {
        case full = 0
        case partial = 1
        case fullWithFeed = 65  // 'A'
        case partialWithFeed = 66  // 'B'
    }

    enum HRIPosition: UInt8, Sendable {
        case notPrinted = 0
        case above = 1
        case below = 2
        case both = 3
    }

    enum BarcodeType: UInt8, Sendable {
        case upcA = 0
        case upcE = 1
        case ean13 = 2
        case ean8 = 3
        case code39 = 4
        case itf = 5
        case codabar = 6
        case code93 = 72
        case code128 = 73
    }

    enum QRErrorCorrectionLevel: UInt8, Sendable {
        case l = 48  // 7%
        case m = 49  // 15%
        case q = 50  // 25%
        case h = 51  // 30%
    }

    enum RasterMode: UInt8, Sendable {
        case normal = 0
        case doubleWidth = 1
        case doubleHeight = 2
        case quadruple = 3
    }

    /// グラフィックスデータの階調 (GS ( L fn=112)
    enum GraphicsTone: UInt8, Sendable {
        /// モノクロ (2階調)
        case monochrome = 48  // '0'
        /// 多階調
        case multiTone = 52   // '4'
    }

    /// グラフィックスデータの色 (GS ( L fn=112)
    enum GraphicsColor: UInt8, Sendable {
        /// 第1色
        case color1 = 49  // '1'
        /// 第2色
        case color2 = 50  // '2'
        /// 第3色
        case color3 = 51  // '3'
        /// 第4色
        case color4 = 52  // '4'
    }

    /// 漢字コード体系 (FS C)
    enum KanjiCodeSystem: UInt8, Sendable {
        /// JISコード体系
        case jis = 0
        /// Shift JISコード体系
        case shiftJIS = 1
        /// Shift_JIS-2004コード体系
        case shiftJIS2004 = 2

        /// '0', '1', '2' の文字コードからも初期化可能
        public init?(rawValue: UInt8) {
            switch rawValue {
            case 0, 48:  // 0 or '0'
                self = .jis
            case 1, 49:  // 1 or '1'
                self = .shiftJIS
            case 2, 50:  // 2 or '2'
                self = .shiftJIS2004
            default:
                return nil
            }
        }
    }
}
