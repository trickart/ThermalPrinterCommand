import Testing
import Foundation
@testable import PrinterSimulator
import ThermalPrinterCommand

@Suite("ESCPOSPrinterSimulator Tests")
struct ESCPOSPrinterSimulatorTests {

    private func makeSimulator() -> ESCPOSPrinterSimulator {
        var renderer = TextReceiptRenderer(ansiStyleEnabled: false, sixelEnabled: false)
        renderer.outputLine = { _ in }  // 出力を無視
        return ESCPOSPrinterSimulator(renderer: renderer)
    }

    // MARK: - レスポンス生成テスト

    @Test("realtimeStatusRequest はステータスバイトを返す")
    func realtimeStatusResponse() {
        var simulator = makeSimulator()
        let responses = simulator.process([.realtimeStatusRequest(type: 1)])
        #expect(responses.count == 1)
        #expect(responses[0] == Data([0x12]))
        // byte & 0x93 == 0x12 を確認
        #expect(responses[0][0] & 0x93 == 0x12)
    }

    @Test("realtimeStatusRequest type=2 も同じレスポンスを返す")
    func realtimeStatusResponseType2() {
        var simulator = makeSimulator()
        let responses = simulator.process([.realtimeStatusRequest(type: 2)])
        #expect(responses.count == 1)
        #expect(responses[0] == Data([0x12]))
    }

    @Test("enableAutomaticStatus は4バイトのレスポンスを返す")
    func enableAutomaticStatusResponse() {
        var simulator = makeSimulator()
        let responses = simulator.process([.enableAutomaticStatus(flags: 0xFF)])
        #expect(responses.count == 1)
        #expect(responses[0] == Data([0x10, 0x00, 0x00, 0x00]))
    }

    @Test("requestProcessIdResponse は9バイトのレスポンスを返す")
    func processIdResponse() {
        var simulator = makeSimulator()
        let responses = simulator.process([
            .requestProcessIdResponse(d1: 0x30, d2: 0x30, d3: 0x30, d4: 0x31)
        ])
        #expect(responses.count == 1)
        #expect(responses[0] == Data([0x37, 0x25, 0x30, 0x00, 0x30, 0x30, 0x30, 0x31, 0x00]))
    }

    @Test("printerInfoRequest はモデル情報を返す")
    func printerInfoResponse() {
        var simulator = makeSimulator()
        let responses = simulator.process([.printerInfoRequest(type: 0x42)])
        #expect(responses.count == 1)
        // 0x5f + "tpsim" + 0x00
        #expect(responses[0][0] == 0x5f)
        #expect(responses[0].last == 0x00)
        let modelName = String(data: responses[0][1..<responses[0].count - 1], encoding: .utf8)
        #expect(modelName == "tpsim")
    }

    @Test("レスポンスが不要なコマンドでは空の配列を返す")
    func noResponseForNonStatusCommands() {
        var simulator = makeSimulator()
        let responses = simulator.process([
            .initialize,
            .text(Data("Hello".utf8)),
            .lineFeed,
            .boldOn,
            .cut(.full),
        ])
        #expect(responses.isEmpty)
    }

    @Test("複数のステータスコマンドで複数のレスポンスを返す")
    func multipleResponses() {
        var simulator = makeSimulator()
        let responses = simulator.process([
            .realtimeStatusRequest(type: 1),
            .enableAutomaticStatus(flags: 0xFF),
            .requestProcessIdResponse(d1: 0x41, d2: 0x42, d3: 0x43, d4: 0x44),
        ])
        #expect(responses.count == 3)
        #expect(responses[0] == Data([0x12]))
        #expect(responses[1] == Data([0x10, 0x00, 0x00, 0x00]))
        #expect(responses[2] == Data([0x37, 0x25, 0x30, 0x00, 0x41, 0x42, 0x43, 0x44, 0x00]))
    }

    // MARK: - 状態管理テスト

    @Test("initialize で状態がリセットされる")
    func initializeResetsState() {
        var simulator = makeSimulator()
        _ = simulator.process([
            .boldOn,
            .underline(.single),
            .reverseMode(enabled: true),
            .justification(.center),
            .characterSize(width: 3, height: 4),
            .barcodeHeight(dots: 50),
            .barcodeWidth(multiplier: 5),
            .barcodeHRIPosition(.both),
            .qrCodeSize(moduleSize: 10),
            .qrCodeErrorCorrection(level: .h),
        ])

        #expect(simulator.status.bold == true)
        #expect(simulator.status.justification == .center)
        #expect(simulator.status.barcodeHeight == 50)

        _ = simulator.process([.initialize])

        #expect(simulator.status.bold == false)
        #expect(simulator.status.underlineMode == .off)
        #expect(simulator.status.reverse == false)
        #expect(simulator.status.justification == .left)
        #expect(simulator.status.widthMultiplier == 1)
        #expect(simulator.status.heightMultiplier == 1)
        #expect(simulator.status.barcodeHeight == 162)
        #expect(simulator.status.barcodeWidthMultiplier == 3)
        #expect(simulator.status.barcodeHRIPosition == .notPrinted)
        #expect(simulator.status.qrCodeModuleSize == 3)
        #expect(simulator.status.qrCodeErrorCorrection == .l)
        #expect(simulator.status.qrCodeStoredData == nil)
    }

    @Test("状態更新コマンドが正しく反映される")
    func stateUpdates() {
        var simulator = makeSimulator()
        _ = simulator.process([.boldOn])
        #expect(simulator.status.bold == true)
        _ = simulator.process([.boldOff])
        #expect(simulator.status.bold == false)

        _ = simulator.process([.underline(.double)])
        #expect(simulator.status.underlineMode == .double)

        _ = simulator.process([.reverseMode(enabled: true)])
        #expect(simulator.status.reverse == true)

        _ = simulator.process([.justification(.right)])
        #expect(simulator.status.justification == .right)

        _ = simulator.process([.characterSize(width: 4, height: 3)])
        #expect(simulator.status.widthMultiplier == 4)
        #expect(simulator.status.heightMultiplier == 3)

        _ = simulator.process([.selectCharacterEncoding(.utf8)])
        #expect(simulator.status.characterEncodingType == .utf8)
    }

    @Test("qrCodePrint 後に qrCodeStoredData がクリアされる")
    func qrCodeDataClearedAfterPrint() {
        var simulator = makeSimulator()
        _ = simulator.process([.qrCodeStore(data: Data("TEST".utf8))])
        #expect(simulator.status.qrCodeStoredData != nil)
        _ = simulator.process([.qrCodePrint])
        #expect(simulator.status.qrCodeStoredData == nil)
    }

    // MARK: - receiptio ビットパターン検証

    @Test("realtimeStatusRequest レスポンスの receiptio 互換ビットパターン")
    func receiptioStatusBitPattern() {
        var simulator = makeSimulator()
        let responses = simulator.process([.realtimeStatusRequest(type: 1)])
        let statusByte = responses[0][0]
        // receiptio が期待するパターン: byte & 0x93 == 0x12
        #expect(statusByte & 0x93 == 0x12)
    }

    @Test("transmitPrintStatus レスポンスの receiptio 互換ビットパターン")
    func receiptioTransmitPrintStatusBitPattern() {
        var simulator = makeSimulator()
        let responses = simulator.process([.transmitPrintStatus(type: 1)])
        #expect(responses.count == 1)
        let statusByte = responses[0][0]
        // receiptio が期待するパターン: byte & 0x90 == 0x00
        #expect(statusByte & 0x90 == 0x00)
    }

    @Test("enableAutomaticStatus レスポンスの receiptio 互換フォーマット")
    func receiptioAutoStatusFormat() {
        var simulator = makeSimulator()
        let responses = simulator.process([.enableAutomaticStatus(flags: 0xFF)])
        #expect(responses[0].count == 4)
        // 最初のバイトの bit4 が 1 であること (0x10)
        #expect(responses[0][0] & 0x10 == 0x10)
    }
}
