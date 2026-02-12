import Testing
import Foundation
@testable import ReceiptRenderer

@Suite("SixelEncoder Tests")
struct SixelEncoderTests {

    @Test("DCSヘッダで始まりSTで終わる")
    func headerAndTerminator() {
        let data = Data(repeating: 0x00, count: 2)
        let result = SixelEncoder.encode(data: data, widthBytes: 2, height: 1)
        #expect(result.hasPrefix("\u{1B}P0;1;q"))
        #expect(result.hasSuffix("\u{1B}\\"))
    }

    @Test("ラスター属性に正しい幅と高さが含まれる")
    func rasterAttributes() {
        let data = Data(repeating: 0x00, count: 6)
        let result = SixelEncoder.encode(data: data, widthBytes: 3, height: 2)
        #expect(result.contains("\"1;1;24;2"))
    }

    @Test("全白画像: 全ビット0 → 各列が?")
    func allWhiteImage() {
        // 1バイト幅(8ピクセル) x 1行 の全白画像
        let data = Data(repeating: 0x00, count: 1)
        let result = SixelEncoder.encode(data: data, widthBytes: 1, height: 1)
        // 8列すべて '?' (0x3F + 0 = 0x3F = '?')
        // RLE: 4以上なので "!8?"
        #expect(result.contains("!8?"))
    }

    @Test("全黒画像: 全ビット1 → 6行で各列が~")
    func allBlackImage6Rows() {
        // 1バイト幅(8ピクセル) x 6行 の全黒画像
        let data = Data(repeating: 0xFF, count: 6)
        let result = SixelEncoder.encode(data: data, widthBytes: 1, height: 6)
        // 各列の縦6ビット全て1 → 値63 → 0x3F+63 = 0x7E = '~'
        // 8列連続 → "!8~"
        #expect(result.contains("!8~"))
    }

    @Test("全黒画像: 1行のみ → 各列のbit0のみセット")
    func allBlack1Row() {
        // 1バイト幅(8ピクセル) x 1行 の全黒画像
        let data = Data([0xFF])
        let result = SixelEncoder.encode(data: data, widthBytes: 1, height: 1)
        // 各列のbit0のみ1 → 値1 → 0x3F+1 = 0x40 = '@'
        // 8列連続 → "!8@"
        #expect(result.contains("!8@"))
    }

    @Test("RLE圧縮: 同一文字4個以上で!N<char>形式")
    func rleCompression() {
        // 2バイト幅 x 1行: 0xFF 0x00
        // 左8列: bit0=1 → '@' が8個 → "!8@"
        // 右8列: bit0=0 → '?' が8個 → "!8?"
        let data = Data([0xFF, 0x00])
        let result = SixelEncoder.encode(data: data, widthBytes: 2, height: 1)
        #expect(result.contains("!8@"))
        #expect(result.contains("!8?"))
    }

    @Test("RLE圧縮: 3文字以下は繰り返しそのまま")
    func noRleForShortRuns() {
        // 3ピクセル幅で検証するため、特殊なパターンを使う
        // 交互パターン: 0xAA = 10101010 → 列0,2,4,6が黒(bit=1)、列1,3,5,7が白(bit=0)
        let data = Data([0xAA])
        let result = SixelEncoder.encode(data: data, widthBytes: 1, height: 1)
        // '@'と'?'が交互に出る → 各1文字ずつ → RLEなし
        // '@'=0x40, '?'=0x3F
        #expect(result.contains("@?@?@?@?"))
    }

    @Test("複数バンド: 高さ7で2バンドに分割される")
    func multipleBands() {
        // 1バイト幅 x 7行
        let data = Data(repeating: 0xFF, count: 7)
        let result = SixelEncoder.encode(data: data, widthBytes: 1, height: 7)
        // バンド区切り "$-" が1つ含まれる
        #expect(result.contains("$-"))
    }

    @Test("既知パターン: 1バイト幅x6行の縦ストライプ")
    func knownPattern() {
        // 各行のデータ: 0x80 = 10000000 (左端1ピクセルのみ黒)
        let data = Data(repeating: 0x80, count: 6)
        let result = SixelEncoder.encode(data: data, widthBytes: 1, height: 6)
        // 列0: 全6行黒 → 0x3F (全ビット1) → '~'
        // 列1-7: 全6行白 → 0x3F (全ビット0) → '?' x 7 → "!7?"
        #expect(result.contains("~"))
        #expect(result.contains("!7?"))
    }

    @Test("色定義が含まれる")
    func colorDefinition() {
        let data = Data(repeating: 0x00, count: 1)
        let result = SixelEncoder.encode(data: data, widthBytes: 1, height: 1)
        #expect(result.contains("#0;2;100;100;100"))
        #expect(result.contains("#1;2;0;0;0"))
    }

    @Test("空データ")
    func emptyData() {
        let result = SixelEncoder.encode(data: Data(), widthBytes: 0, height: 0)
        #expect(result.hasPrefix("\u{1B}P0;1;q"))
        #expect(result.hasSuffix("\u{1B}\\"))
    }

    // MARK: - HiDPIスケーリング

    @Test("scale=2: ラスター属性の幅と高さが2倍になる")
    func scaleDoublesDimensions() {
        let data = Data(repeating: 0x00, count: 6)
        let result = SixelEncoder.encode(data: data, widthBytes: 3, height: 2, scale: 2)
        // 幅: 3*8*2=48, 高さ: 2*2=4
        #expect(result.contains("\"1;1;48;4"))
    }

    @Test("scale=1: デフォルトと同じ出力")
    func scaleOneIsIdentity() {
        let data = Data(repeating: 0xFF, count: 6)
        let noScale = SixelEncoder.encode(data: data, widthBytes: 1, height: 6)
        let scale1 = SixelEncoder.encode(data: data, widthBytes: 1, height: 6, scale: 1)
        #expect(noScale == scale1)
    }

    @Test("scale=2: 全黒1行が2行分のバンドデータになる")
    func scaleBlackRow() {
        // 1バイト幅 x 1行の全黒画像
        let data = Data([0xFF])
        let result = SixelEncoder.encode(data: data, widthBytes: 1, height: 1, scale: 2)
        // scale=2: 高さ2行、幅16列
        #expect(result.contains("\"1;1;16;2"))
        // 各列のbit0,bit1が1（2行分）→ 値3 → 0x3F+3 = 0x42 = 'B'
        // 16列連続 → "!16B"
        #expect(result.contains("!16B"))
    }

    @Test("scale=2: 全黒6行が12行・2バンドになる")
    func scaleBlack6Rows() {
        let data = Data(repeating: 0xFF, count: 6)
        let result = SixelEncoder.encode(data: data, widthBytes: 1, height: 6, scale: 2)
        // scale=2: 高さ12行、幅16列
        #expect(result.contains("\"1;1;16;12"))
        // 12行 → 2バンド → バンド区切り "$-" が含まれる
        #expect(result.contains("$-"))
        // 全バンド全列が '~'（全ビット1）→ "!16~"
        #expect(result.contains("!16~"))
    }

    @Test("scale=2: Sixel出力がscale=1より大きい")
    func scaledOutputIsLarger() {
        let data = Data(repeating: 0xAA, count: 12)
        let normal = SixelEncoder.encode(data: data, widthBytes: 2, height: 6)
        let scaled = SixelEncoder.encode(data: data, widthBytes: 2, height: 6, scale: 2)
        #expect(scaled.count > normal.count)
    }
}
