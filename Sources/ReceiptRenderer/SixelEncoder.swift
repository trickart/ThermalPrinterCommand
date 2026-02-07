import Foundation

struct SixelEncoder {
    /// 1bitラスターデータをSixel文字列に変換
    /// - Parameters:
    ///   - data: ビットマップデータ（8ピクセル/バイト、MSBが左端、1=黒）
    ///   - widthBytes: 1行あたりのバイト数
    ///   - height: 行数
    /// - Returns: DCS〜STで囲まれたSixel文字列
    static func encode(data: Data, widthBytes: Int, height: Int) -> String {
        let pixelWidth = widthBytes * 8

        var result = "\u{1B}P0;1;q"
        // ラスター属性: 1:1アスペクト比
        result += "\"1;1;\(pixelWidth);\(height)"
        // 色定義: #0 = 白 (背景色、P2=1により背景に適用)
        result += "#0;2;100;100;100"
        // 色定義: #1 = 黒 (前景色)
        result += "#1;2;0;0;0"

        // 6行ずつバンドに分割
        let bandCount = (height + 5) / 6
        for band in 0..<bandCount {
            // バンド内の有効行数からマスクを計算
            let validRows = min(6, height - band * 6)
            let mask: UInt8 = (1 << validRows) - 1

            // バンド内の各列の前景Sixel値を計算
            var fgValues: [UInt8] = []
            fgValues.reserveCapacity(pixelWidth)
            for col in 0..<pixelWidth {
                var sixelValue: UInt8 = 0
                for row in 0..<validRows {
                    let y = band * 6 + row
                    let byteIndex = y * widthBytes + col / 8
                    let bitIndex = 7 - (col % 8)
                    if byteIndex < data.count {
                        let bit = (data[byteIndex] >> bitIndex) & 1
                        if bit == 1 {
                            sixelValue |= 1 << row
                        }
                    }
                }
                fgValues.append(sixelValue)
            }

            // 背景色（白）を書き込み
            result += "#0"
            appendRLE(values: fgValues, mask: mask, invert: true, to: &result)

            // グラフィックスCRで行頭に戻る
            result += "$"

            // 前景色（黒）を書き込み
            result += "#1"
            appendRLE(values: fgValues, mask: mask, invert: false, to: &result)

            // バンド間の区切り（最終バンド以外）
            if band < bandCount - 1 {
                result += "$-"
            }
        }

        // ST (String Terminator)
        result += "\u{1B}\\"
        return result
    }

    /// Sixel値の配列をRLE圧縮して書き込む
    /// - Parameters:
    ///   - values: 各列の前景Sixel値
    ///   - mask: 有効ビットマスク
    ///   - invert: trueなら背景色用（ビット反転）
    private static func appendRLE(values: [UInt8], mask: UInt8, invert: Bool, to result: inout String) {
        var runChar: Character = "\0"
        var runCount = 0
        for value in values {
            let sixel = invert ? (mask & ~value) : value
            let ch = Character(UnicodeScalar(0x3F + sixel))
            if ch == runChar {
                runCount += 1
            } else {
                flushRun(char: runChar, count: runCount, to: &result)
                runChar = ch
                runCount = 1
            }
        }
        flushRun(char: runChar, count: runCount, to: &result)
    }

    private static func flushRun(char: Character, count: Int, to result: inout String) {
        guard count > 0, char != "\0" else { return }
        if count >= 4 {
            result += "!\(count)\(char)"
        } else {
            result += String(repeating: String(char), count: count)
        }
    }
}
