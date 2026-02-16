import Foundation

/// StarPRNTコマンドを表す列挙型
public enum StarPRNTCommand: Equatable, Sendable {
    // MARK: - 制御コマンド
    /// プリンター初期化 (ESC @: 1B 40)
    case initialize
    /// 改行 (LF: 0A)
    case lineFeed
    /// フォームフィード (FF: 0C)
    case formFeed
    /// 水平タブ (HT: 09)
    case horizontalTab

    // MARK: - フォントスタイル・キャラクタセット
    /// フォント選択 (ESC RS F n: 1B 1E 46 n)
    case selectFont(Font)
    /// コードページ選択 (ESC GS t n: 1B 1D 74 n)
    case selectCodePage(UInt8)
    /// 国際文字セット選択 (ESC R n: 1B 52 n)
    case selectInternationalCharacter(UInt8)
    /// スラッシュゼロ (ESC / n: 1B 2F n)
    case slashZero(enabled: Bool)
    /// ANK文字右スペース (ESC SP n: 1B 20 n)
    case ankRightSpace(dots: UInt8)
    /// ダウンロード文字セット有効/無効 (ESC % n: 1B 25 n)
    case downloadCharacterEnabled(Bool)

    // MARK: - 漢字
    /// JIS漢字モード開始 (ESC p: 1B 70)
    case jisKanjiMode
    /// JIS漢字モード終了 (ESC q: 1B 71)
    case jisKanjiModeCancel
    /// Shift JIS漢字モード (ESC $ n: 1B 24 n)
    case shiftJISKanjiMode(enabled: Bool)

    // MARK: - プリントモード
    /// 文字拡大 (ESC i n1 n2: 1B 69 n1 n2)
    case expansion(vertical: UInt8, horizontal: UInt8)
    /// 横倍拡大 (ESC W n: 1B 57 n)
    case horizontalExpansion(UInt8)
    /// 縦倍拡大 (ESC h n: 1B 68 n)
    case verticalExpansion(UInt8)
    /// 太字開始 (ESC E: 1B 45)
    case boldOn
    /// 太字終了 (ESC F: 1B 46)
    case boldOff
    /// アンダーライン (ESC - n: 1B 2D n)
    case underline(enabled: Bool)
    /// アッパーライン (ESC _ n: 1B 5F n)
    case upperline(enabled: Bool)
    /// 反転印字開始 (ESC 4: 1B 34)
    case reverseOn
    /// 反転印字終了 (ESC 5: 1B 35)
    case reverseOff
    /// 上下逆転開始 (SI: 0F)
    case upsideDownOn
    /// 上下逆転終了 (DC2: 12)
    case upsideDownOff
    /// スムージング (ESC GS b n: 1B 1D 62 n)
    case smoothing(enabled: Bool)

    // MARK: - 水平方向位置
    /// 左マージン (ESC l n: 1B 6C n)
    case leftMargin(UInt8)
    /// 右マージン (ESC Q n: 1B 51 n)
    case rightMargin(UInt8)
    /// 絶対位置指定 (ESC GS A n1 n2: 1B 1D 41 n1 n2)
    case absolutePosition(UInt16)
    /// 相対位置指定 (ESC GS R n1 n2: 1B 1D 52 n1 n2)
    case relativePosition(Int16)
    /// 配置 (ESC GS a n: 1B 1D 61 n)
    case alignment(Alignment)
    /// 水平タブ位置設定 (ESC D n1...nk NUL: 1B 44 ... 00)
    case setHorizontalTab([UInt8])
    /// 水平タブ位置クリア (ESC D NUL: 1B 44 00)
    case clearHorizontalTab

    // MARK: - 行間隔
    /// n行フィード (ESC a n: 1B 61 n) ※StarPRNTのfeedLinesはESC a
    case feedLines(UInt8)
    /// 行間隔モード (ESC z n: 1B 7A n)
    case lineSpacingMode(UInt8)
    /// 行間隔3mm (ESC 0: 1B 30)
    case lineSpacing3mm
    /// 1/4mm単位フィード (ESC J n: 1B 4A n)
    case feedQuarterMM(UInt8)
    /// 1/8mm単位フィード (ESC I n: 1B 49 n)
    case feedEighthMM(UInt8)

    // MARK: - ページ管理
    /// ページ長 (ESC C n: 1B 43 n)
    case pageLength(lines: UInt8)

    // MARK: - トップマージン
    /// トップマージン (ESC RS T n: 1B 1E 54 n)
    case topMargin(UInt8)

    // MARK: - カッター
    /// カット (ESC d n: 1B 64 n)
    case cut(CutMode)

    // MARK: - ページモード
    /// ページモード開始 (ESC GS P 0: 1B 1D 50 30)
    case pageModeOn
    /// ページモード終了 (ESC GS P 1: 1B 1D 50 31)
    case pageModeOff
    /// ページモード印字方向 (ESC GS P 2 n: 1B 1D 50 32 n)
    case pageModeDirection(UInt8)
    /// ページモード印字領域 (ESC GS P 3 xL xH yL yH dxL dxH dyL dyH)
    case pageModePrintArea(x: UInt16, y: UInt16, dx: UInt16, dy: UInt16)
    /// ページモード印字 (ESC GS P 6: 1B 1D 50 36)
    case pageModePrint
    /// ページモード印字して終了 (ESC GS P 7: 1B 1D 50 37)
    case pageModePrintAndExit
    /// ページモードキャンセル (ESC GS P 8: 1B 1D 50 38)
    case pageModeCancel

    // MARK: - ビットイメージ
    /// ビットイメージ（通常密度）(ESC K n1 n2 d...: 1B 4B)
    case bitImageNormal(width: UInt16, data: Data)
    /// ビットイメージ（高密度）(ESC L n1 n2 d...: 1B 4C)
    case bitImageHigh(width: UInt16, data: Data)
    /// ビットイメージ（精細）(ESC k n1 n2 d...: 1B 6B)
    case bitImageFine(width: UInt16, data: Data)
    /// ラスターグラフィックス (ESC GS S m xL xH yL yH d...)
    case rasterGraphics(mode: UInt8, width: UInt16, height: UInt16, data: Data)

    // MARK: - バーコード
    /// バーコード (ESC b n1 n2 n3 n4 d... RS: 1B 62 ...)
    case barcode(type: BarcodeType, mode: UInt8, width: UInt8, height: UInt8, data: Data)

    // MARK: - QRコード
    /// QRコードモデル (ESC GS y S 0 n)
    case qrCodeModel(UInt8)
    /// QRコードエラー訂正レベル (ESC GS y S 1 n)
    case qrCodeErrorCorrection(UInt8)
    /// QRコードセルサイズ (ESC GS y S 2 n)
    case qrCodeCellSize(UInt8)
    /// QRコードデータ格納 (ESC GS y D 1 m nL nH d...)
    case qrCodeStore(data: Data)
    /// QRコード印刷 (ESC GS y P)
    case qrCodePrint

    // MARK: - PDF417
    /// PDF417サイズ (ESC GS x S 0 n p1 p2)
    case pdf417Size(UInt8, p1: UInt8, p2: UInt8)
    /// PDF417エラー訂正レベル (ESC GS x S 1 n)
    case pdf417ECC(UInt8)
    /// PDF417モジュール幅 (ESC GS x S 2 n)
    case pdf417ModuleWidth(UInt8)
    /// PDF417アスペクト比 (ESC GS x S 3 n)
    case pdf417AspectRatio(UInt8)
    /// PDF417データ格納 (ESC GS x D nL nH d...)
    case pdf417Store(data: Data)
    /// PDF417印刷 (ESC GS x P)
    case pdf417Print

    // MARK: - 初期化
    /// リアルタイムリセット (ESC ACK CAN: 1B 06 18)
    case realtimeReset
    /// プリンターリセット (ESC ? LF NUL: 1B 3F 0A 00)
    case printerReset

    // MARK: - ステータス
    /// 自動ステータス設定 (ESC RS a n: 1B 1E 61 n)
    case autoStatusSetting(UInt8)
    /// リアルタイムステータス (ESC ACK SOH: 1B 06 01)
    case realtimeStatus

    // MARK: - 外部機器
    /// ブザー (ESC BEL n1 n2: 1B 07 n1 n2)
    case buzzer(n1: UInt8, n2: UInt8)
    /// 外部デバイス1A (BEL: 07)
    case externalDevice1A
    /// 外部デバイス1B (FS: 1C)
    case externalDevice1B
    /// 外部デバイス2A (SUB: 1A)
    case externalDevice2A
    /// 外部デバイス2B (EM: 19)
    case externalDevice2B

    // MARK: - 印字設定
    /// 印字エリア (ESC RS A n: 1B 1E 41 n)
    case printArea(UInt8)
    /// 印字濃度 (ESC RS d n: 1B 1E 64 n)
    case printDensity(UInt8)
    /// 印字速度 (ESC RS r n: 1B 1E 72 n)
    case printSpeed(UInt8)

    // MARK: - 2色印字
    /// 2色印字カラー (ESC RS c n: 1B 1E 63 n)
    case twoColorPrintColor(UInt8)
    /// 2色モード (ESC RS C n: 1B 1E 43 n)
    case twoColorMode(enabled: Bool)

    // MARK: - テキスト
    /// テキストデータ
    case text(Data)

    // MARK: - その他
    /// 不明なコマンド
    case unknown(Data)
}

// MARK: - Supporting Types

public extension StarPRNTCommand {
    enum Font: UInt8, Sendable {
        case fontA = 0
        case fontB = 1
        case fontC = 2
    }

    enum CutMode: UInt8, Sendable {
        case fullCut = 0
        case partialCut = 1
        case tearBar = 2
    }

    enum Alignment: UInt8, Sendable {
        case left = 0
        case center = 1
        case right = 2
    }

    enum BarcodeType: UInt8, Sendable {
        case code39 = 0
        case itf = 2
        case jan_ean = 3
        case code128 = 4
        case code93 = 5
        case nw7 = 6
        case gs1_128 = 10
        case gs1DatabarOmnidirectional = 11
        case gs1DatabarTruncated = 12
        case gs1DatabarLimited = 13
        case gs1DatabarExpanded = 14
    }
}
