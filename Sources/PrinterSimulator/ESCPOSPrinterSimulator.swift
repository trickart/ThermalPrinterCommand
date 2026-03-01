import Foundation
import ThermalPrinterCommand

/// ESC/POSプリンターシミュレーター
///
/// プリンターの状態管理、レスポンス生成、TextReceiptRendererへの描画委譲を一括で担う。
public struct ESCPOSPrinterSimulator {
    // MARK: - Status

    public var status: PrinterStatus = .normal

    // MARK: - Renderer

    public var renderer: TextReceiptRenderer

    // MARK: - Initializer

    public init(renderer: TextReceiptRenderer) {
        self.renderer = renderer
    }

    // MARK: - Processing

    /// コマンド配列を処理し、レスポンスデータの配列を返す
    public mutating func process(_ commands: [ESCPOSCommand]) -> [Data] {
        var responses: [Data] = []

        for command in commands {
            // 状態更新
            updateState(command)

            // 描画委譲
            renderer.render(command, status: status)

            // 描画後のクリーンアップ
            if case .qrCodePrint = command {
                status.qrCodeStoredData = nil
            }

            // レスポンス生成
            if let response = generateResponse(for: command) {
                responses.append(response)
            }
        }

        return responses
    }

    // MARK: - State Management

    private mutating func updateState(_ command: ESCPOSCommand) {
        switch command {
        case .initialize:
            status.resetRenderingState()
        case .boldOn:
            status.bold = true
        case .boldOff:
            status.bold = false
        case .underline(let mode):
            status.underlineMode = mode
        case .reverseMode(let enabled):
            status.reverse = enabled
        case .justification(let j):
            status.justification = j
        case .characterSize(let width, let height):
            status.widthMultiplier = width
            status.heightMultiplier = height
        case .barcodeHeight(let dots):
            status.barcodeHeight = dots
        case .barcodeWidth(let multiplier):
            status.barcodeWidthMultiplier = multiplier
        case .barcodeHRIPosition(let position):
            status.barcodeHRIPosition = position
        case .qrCodeSize(let size):
            status.qrCodeModuleSize = size
        case .qrCodeErrorCorrection(let level):
            status.qrCodeErrorCorrection = level
        case .qrCodeStore(let data):
            status.qrCodeStoredData = data
        default:
            break
        }
    }

    // MARK: - Response Generation

    private func generateResponse(for command: ESCPOSCommand) -> Data? {
        switch command {
        case .realtimeStatusRequest:
            // 基本値 0x12 (byte & 0x93 == 0x12 を満たす)
            return Data([0x12])

        case .printerInfoRequest:
            // GS I n: プリンター情報レスポンス
            // receiptio互換: 0x5f + モデル名 + NUL
            var response = Data([0x5f])
            response.append(contentsOf: "tpsim".utf8)
            response.append(0x00)
            return response

        case .enableAutomaticStatus:
            // receiptio互換: 4バイトのステータスレスポンス
            return Data([0x10, 0x00, 0x00, 0x00])

        case .requestProcessIdResponse(let d1, let d2, let d3, let d4):
            // Header(37H 25H) + fn(30H) + status(00H) + d1-d4 + NUL(00H)
            return Data([0x37, 0x25, 0x30, 0x00, d1, d2, d3, d4, 0x00])

        default:
            return nil
        }
    }
}
