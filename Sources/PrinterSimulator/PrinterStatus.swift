import Foundation
import ThermalPrinterCommand

/// プリンターの状態を表す構造体
public struct PrinterStatus: Sendable {
    // MARK: - Hardware Status

    public var isOnline: Bool = true
    public var isPaperEmpty: Bool = false
    public var isCoverOpen: Bool = false
    public var isPaperNearEnd: Bool = false
    public var hasError: Bool = false

    // MARK: - Rendering State

    public var bold = false
    public var underlineMode: ESCPOSCommand.UnderlineMode = .off
    public var kanjiMode = false
    public var kanjiUnderlineMode: ESCPOSCommand.UnderlineMode = .off
    public var reverse = false
    public var justification: ESCPOSCommand.Justification = .left
    public var widthMultiplier: UInt8 = 1
    public var heightMultiplier: UInt8 = 1
    public var barcodeHeight: UInt8 = 162
    public var barcodeWidthMultiplier: UInt8 = 3
    public var barcodeHRIPosition: ESCPOSCommand.HRIPosition = .notPrinted
    public var qrCodeModuleSize: UInt8 = 3
    public var qrCodeErrorCorrection: ESCPOSCommand.QRErrorCorrectionLevel = .l
    public var printingWidth: UInt16 = 504
    public var qrCodeStoredData: Data?
    public var internationalCharacterSet: ESCPOSCommand.InternationalCharacterSet = .japan
    public var characterCodeTable: UInt8 = 0
    public var kanjiFont: ESCPOSCommand.KanjiFont = .fontA
    public var characterEncodingType: ESCPOSCommand.CharacterEncodingType = .codePage
    public var printColor: ESCPOSCommand.PrintColor = .black
    /// 水平タブ位置（桁数）。初期値は8桁毎（8, 16, 24, ..., 248）。
    public var horizontalTabPositions: [UInt8] = stride(from: 8, through: 248, by: 8).map { UInt8($0) }

    public static let normal = PrinterStatus()

    public init(
        isOnline: Bool = true,
        isPaperEmpty: Bool = false,
        isCoverOpen: Bool = false,
        isPaperNearEnd: Bool = false,
        hasError: Bool = false
    ) {
        self.isOnline = isOnline
        self.isPaperEmpty = isPaperEmpty
        self.isCoverOpen = isCoverOpen
        self.isPaperNearEnd = isPaperNearEnd
        self.hasError = hasError
    }

    // MARK: - Reset

    public mutating func resetRenderingState() {
        bold = false
        underlineMode = .off
        kanjiMode = false
        kanjiUnderlineMode = .off
        reverse = false
        justification = .left
        widthMultiplier = 1
        heightMultiplier = 1
        barcodeHeight = 162
        barcodeWidthMultiplier = 3
        barcodeHRIPosition = .notPrinted
        printingWidth = 504
        qrCodeModuleSize = 3
        qrCodeErrorCorrection = .l
        qrCodeStoredData = nil
        internationalCharacterSet = .japan
        characterCodeTable = 0
        kanjiFont = .fontA
        characterEncodingType = .codePage
        printColor = .black
        horizontalTabPositions = stride(from: 8, through: 248, by: 8).map { UInt8($0) }
    }
}
