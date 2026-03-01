import Foundation
import ThermalPrinterCommand

struct BarcodeRasterizer {

    struct BarcodeImage {
        let data: Data
        let widthBytes: Int
        let height: Int
    }

    // MARK: - Public API

    static func rasterize(
        type: ESCPOSCommand.BarcodeType,
        data: Data,
        moduleWidth: Int,
        height: Int
    ) -> BarcodeImage? {
        guard let modules = encodeModules(type: type, data: data) else {
            return nil
        }
        return renderBitmap(modules: modules, moduleWidth: moduleWidth, height: height)
    }

    // MARK: - Module Encoding Dispatch

    private static func encodeModules(type: ESCPOSCommand.BarcodeType, data: Data) -> [Bool]? {
        switch type {
        case .code128: return encodeCode128(data)
        case .ean13:   return encodeEAN13(data)
        case .ean8:    return encodeEAN8(data)
        case .upcA:    return encodeUPCA(data)
        case .upcE:    return encodeUPCE(data)
        case .code39:  return encodeCode39(data)
        case .itf:     return encodeITF(data)
        case .codabar: return encodeCodabar(data)
        case .code93:  return encodeCode93(data)
        }
    }

    // MARK: - Bitmap Rendering

    private static func renderBitmap(modules: [Bool], moduleWidth: Int, height: Int) -> BarcodeImage {
        let pixelWidth = modules.count * moduleWidth
        let widthBytes = (pixelWidth + 7) / 8
        var bitmap = Data(repeating: 0, count: widthBytes * height)

        // Build one row
        for (moduleIndex, isBar) in modules.enumerated() {
            guard isBar else { continue }
            for sub in 0..<moduleWidth {
                let x = moduleIndex * moduleWidth + sub
                let byteIndex = x / 8
                let bitIndex = 7 - (x % 8)
                bitmap[byteIndex] |= UInt8(1 << bitIndex)
            }
        }

        // Copy first row to all subsequent rows
        if height > 1 {
            let row = Data(bitmap[0..<widthBytes])
            for r in 1..<height {
                let offset = r * widthBytes
                bitmap.replaceSubrange(offset..<offset + widthBytes, with: row)
            }
        }

        return BarcodeImage(data: bitmap, widthBytes: widthBytes, height: height)
    }

    // MARK: - Helpers

    /// Convert alternating bar/space widths to module array (true=bar, false=space)
    private static func widthsToModules(_ widths: [UInt8]) -> [Bool] {
        var modules: [Bool] = []
        var isBar = true
        for w in widths {
            for _ in 0..<w {
                modules.append(isBar)
            }
            isBar = !isBar
        }
        return modules
    }

    /// Convert a bit-pattern string ("0001101") to module array (1=bar)
    private static func bitsToModules(_ bits: String) -> [Bool] {
        bits.map { $0 == "1" }
    }

    /// Extract ASCII digits from data
    private static func asciiDigits(_ data: Data) -> [Int]? {
        var digits: [Int] = []
        for b in data {
            guard b >= 0x30, b <= 0x39 else { return nil }
            digits.append(Int(b - 0x30))
        }
        return digits
    }

    /// Parse a compact pattern string "212222" into [UInt8]
    private static func parseWidths(_ s: String) -> [UInt8] {
        s.map { UInt8(String($0))! }
    }
}

// MARK: - CODE128

extension BarcodeRasterizer {

    private static func encodeCode128(_ data: Data) -> [Bool]? {
        guard !data.isEmpty else { return nil }

        let bytes = Array(data)
        var values: [Int] = []
        var codeSet = 1  // 0=A, 1=B, 2=C
        var index = 0

        // Check for initial code set selection via {A, {B, {C
        if bytes.count >= 2, bytes[0] == 0x7B {
            switch bytes[1] {
            case 0x41: codeSet = 0; index = 2  // {A
            case 0x42: codeSet = 1; index = 2  // {B
            case 0x43: codeSet = 2; index = 2  // {C
            default: break
            }
        }

        // Start code
        values.append(103 + codeSet)

        while index < bytes.count {
            // Check for code set switch
            if bytes[index] == 0x7B, index + 1 < bytes.count {
                switch bytes[index + 1] {
                case 0x41: // {A
                    values.append(101); codeSet = 0; index += 2; continue
                case 0x42: // {B
                    values.append(100); codeSet = 1; index += 2; continue
                case 0x43: // {C
                    values.append(99); codeSet = 2; index += 2; continue
                case 0x7B: // {{ → literal {
                    index += 1 // skip first {, encode second as normal
                default:
                    break
                }
            }

            switch codeSet {
            case 0: // Code A: ASCII 0-95
                let b = bytes[index]
                if b < 32 { values.append(Int(b) + 64) }
                else if b < 96 { values.append(Int(b) - 32) }
                else { return nil }
                index += 1
            case 1: // Code B: ASCII 32-127
                let b = bytes[index]
                guard b >= 32, b < 128 else { return nil }
                values.append(Int(b) - 32)
                index += 1
            case 2: // Code C: digit pairs
                guard index + 1 < bytes.count else { return nil }
                let d1 = bytes[index], d2 = bytes[index + 1]
                guard d1 >= 0x30, d1 <= 0x39, d2 >= 0x30, d2 <= 0x39 else { return nil }
                values.append(Int(d1 - 0x30) * 10 + Int(d2 - 0x30))
                index += 2
            default:
                return nil
            }
        }

        // Checksum
        var checksum = values[0]
        for i in 1..<values.count {
            checksum += values[i] * i
        }
        checksum %= 103
        values.append(checksum)

        // Convert to modules
        var modules: [Bool] = []
        for value in values {
            guard value < code128Patterns.count else { return nil }
            modules.append(contentsOf: widthsToModules(parseWidths(code128Patterns[value])))
        }
        // Stop pattern (7 elements)
        modules.append(contentsOf: widthsToModules(parseWidths("2331112")))

        return modules
    }

    private static let code128Patterns: [String] = [
        "212222", "222122", "222221", "121223", "121322",  //   0-4
        "131222", "122213", "122312", "132212", "221213",  //   5-9
        "221312", "231212", "112232", "122132", "122231",  //  10-14
        "113222", "123122", "123221", "223211", "221132",  //  15-19
        "221231", "213212", "223112", "312131", "311222",  //  20-24
        "321122", "321221", "312212", "322112", "322211",  //  25-29
        "212123", "212321", "232121", "111323", "131123",  //  30-34
        "131321", "112313", "132113", "132311", "211313",  //  35-39
        "231113", "231311", "112133", "112331", "132131",  //  40-44
        "113123", "113321", "133121", "313121", "211331",  //  45-49
        "231131", "213113", "213311", "213131", "311123",  //  50-54
        "311321", "331121", "312113", "312311", "332111",  //  55-59
        "314111", "221411", "431111", "111224", "111422",  //  60-64
        "121124", "121421", "141122", "141221", "112214",  //  65-69
        "112412", "122114", "122411", "142112", "142211",  //  70-74
        "241211", "221114", "413111", "241112", "134111",  //  75-79
        "111242", "121142", "121241", "114212", "124112",  //  80-84
        "124211", "411212", "421112", "421211", "212141",  //  85-89
        "214121", "412121", "111143", "111341", "131141",  //  90-94
        "114113", "114311", "411113", "411311", "113141",  //  95-99
        "114131", "311141", "411131", "211412", "211214",  // 100-104
        "211232",                                           // 105
    ]
}

// MARK: - EAN-13

extension BarcodeRasterizer {

    private static func encodeEAN13(_ data: Data) -> [Bool]? {
        guard let digits = asciiDigits(data), digits.count == 13 else { return nil }

        var modules: [Bool] = []

        // Start guard: 101
        modules.append(contentsOf: [true, false, true])

        // Left 6 digits (digits[1]...digits[6]) using L/G patterns based on first digit
        let parityPattern = ean13Parity[digits[0]]
        for i in 0..<6 {
            let digit = digits[i + 1]
            let pattern = parityPattern[i] == "L" ? eanLPatterns[digit] : eanGPatterns[digit]
            modules.append(contentsOf: bitsToModules(pattern))
        }

        // Middle guard: 01010
        modules.append(contentsOf: [false, true, false, true, false])

        // Right 6 digits (digits[7]...digits[12]) using R patterns
        for i in 7...12 {
            modules.append(contentsOf: bitsToModules(eanRPatterns[digits[i]]))
        }

        // End guard: 101
        modules.append(contentsOf: [true, false, true])

        return modules
    }

    // L-codes (odd parity)
    private static let eanLPatterns = [
        "0001101", "0011001", "0010011", "0111101", "0100011",
        "0110001", "0101111", "0111011", "0110111", "0001011",
    ]

    // G-codes (even parity = reversed R-codes)
    private static let eanGPatterns = [
        "0100111", "0110011", "0011011", "0100001", "0011101",
        "0111001", "0000101", "0010001", "0001001", "0010111",
    ]

    // R-codes
    private static let eanRPatterns = [
        "1110010", "1100110", "1101100", "1000010", "1011100",
        "1001110", "1010000", "1000100", "1001000", "1110100",
    ]

    // First digit → L/G pattern for left 6 digits
    private static let ean13Parity: [[Character]] = [
        ["L","L","L","L","L","L"],  // 0
        ["L","L","G","L","G","G"],  // 1
        ["L","L","G","G","L","G"],  // 2
        ["L","L","G","G","G","L"],  // 3
        ["L","G","L","L","G","G"],  // 4
        ["L","G","G","L","L","G"],  // 5
        ["L","G","G","G","L","L"],  // 6
        ["L","G","L","G","L","G"],  // 7
        ["L","G","L","G","G","L"],  // 8
        ["L","G","G","L","G","L"],  // 9
    ]
}

// MARK: - EAN-8

extension BarcodeRasterizer {

    private static func encodeEAN8(_ data: Data) -> [Bool]? {
        guard let digits = asciiDigits(data), digits.count == 8 else { return nil }

        var modules: [Bool] = []

        // Start guard
        modules.append(contentsOf: [true, false, true])

        // Left 4 digits using L patterns
        for i in 0..<4 {
            modules.append(contentsOf: bitsToModules(eanLPatterns[digits[i]]))
        }

        // Middle guard
        modules.append(contentsOf: [false, true, false, true, false])

        // Right 4 digits using R patterns
        for i in 4..<8 {
            modules.append(contentsOf: bitsToModules(eanRPatterns[digits[i]]))
        }

        // End guard
        modules.append(contentsOf: [true, false, true])

        return modules
    }
}

// MARK: - UPC-A

extension BarcodeRasterizer {

    private static func encodeUPCA(_ data: Data) -> [Bool]? {
        guard let digits = asciiDigits(data), digits.count == 12 else { return nil }

        var modules: [Bool] = []

        // Start guard
        modules.append(contentsOf: [true, false, true])

        // Left 6 digits using L patterns
        for i in 0..<6 {
            modules.append(contentsOf: bitsToModules(eanLPatterns[digits[i]]))
        }

        // Middle guard
        modules.append(contentsOf: [false, true, false, true, false])

        // Right 6 digits using R patterns
        for i in 6..<12 {
            modules.append(contentsOf: bitsToModules(eanRPatterns[digits[i]]))
        }

        // End guard
        modules.append(contentsOf: [true, false, true])

        return modules
    }
}

// MARK: - UPC-E

extension BarcodeRasterizer {

    private static func encodeUPCE(_ data: Data) -> [Bool]? {
        guard let digits = asciiDigits(data) else { return nil }

        // Accept 6, 7, or 8 digits
        let coreDigits: [Int]
        let checkDigit: Int

        switch digits.count {
        case 6:
            // Compute check digit from expanded UPC-A
            let expanded = expandUPCE(digits)
            checkDigit = upcCheckDigit(expanded)
            coreDigits = digits
        case 7:
            // number system + 6 digits
            let expanded = expandUPCE(Array(digits[1...6]))
            checkDigit = upcCheckDigit(expanded)
            coreDigits = Array(digits[1...6])
        case 8:
            // number system + 6 digits + check
            coreDigits = Array(digits[1...6])
            checkDigit = digits[7]
        default:
            return nil
        }

        var modules: [Bool] = []

        // Start guard: 101
        modules.append(contentsOf: [true, false, true])

        // 6 digits with parity based on check digit
        let parity = upceParity[checkDigit]
        for i in 0..<6 {
            let digit = coreDigits[i]
            let pattern = parity[i] == "O" ? eanLPatterns[digit] : eanGPatterns[digit]
            modules.append(contentsOf: bitsToModules(pattern))
        }

        // End guard: 010101
        modules.append(contentsOf: [false, true, false, true, false, true])

        return modules
    }

    /// Expand UPC-E 6 digits to UPC-A 11 digits (without check digit)
    private static func expandUPCE(_ d: [Int]) -> [Int] {
        switch d[5] {
        case 0, 1, 2:
            return [0, d[0], d[1], d[5], 0, 0, 0, 0, d[2], d[3], d[4]]
        case 3:
            return [0, d[0], d[1], d[2], 0, 0, 0, 0, 0, d[3], d[4]]
        case 4:
            return [0, d[0], d[1], d[2], d[3], 0, 0, 0, 0, 0, d[4]]
        default: // 5-9
            return [0, d[0], d[1], d[2], d[3], d[4], 0, 0, 0, 0, d[5]]
        }
    }

    /// Calculate UPC/EAN check digit from 11 digits
    private static func upcCheckDigit(_ digits: [Int]) -> Int {
        var sum = 0
        for (i, d) in digits.enumerated() {
            sum += d * (i.isMultiple(of: 2) ? 3 : 1)
        }
        return (10 - (sum % 10)) % 10
    }

    // Parity patterns for UPC-E based on check digit (O=L-code, E=G-code)
    private static let upceParity: [[Character]] = [
        ["E","E","E","O","O","O"],  // 0
        ["E","E","O","E","O","O"],  // 1
        ["E","E","O","O","E","O"],  // 2
        ["E","E","O","O","O","E"],  // 3
        ["E","O","E","E","O","O"],  // 4
        ["E","O","O","E","E","O"],  // 5
        ["E","O","O","O","E","E"],  // 6
        ["E","O","E","O","E","O"],  // 7
        ["E","O","E","O","O","E"],  // 8
        ["E","O","O","E","O","E"],  // 9
    ]
}

// MARK: - CODE39

extension BarcodeRasterizer {

    private static func encodeCode39(_ data: Data) -> [Bool]? {
        guard let text = String(data: data, encoding: .ascii) else { return nil }

        var modules: [Bool] = []

        // Start: '*'
        guard let startPattern = code39Patterns[Character("*")] else { return nil }
        modules.append(contentsOf: widthsToModules(startPattern))

        for ch in text.uppercased() {
            // Inter-character gap (1 narrow space)
            modules.append(false)
            guard let pattern = code39Patterns[ch] else { return nil }
            modules.append(contentsOf: widthsToModules(pattern))
        }

        // Inter-character gap + Stop: '*'
        modules.append(false)
        modules.append(contentsOf: widthsToModules(startPattern))

        return modules
    }

    // CODE39 patterns: 9 elements (B S B S B S B S B), N=1, W=3
    // Binary encoding: 1=wide for 9 positions
    private static let code39Patterns: [Character: [UInt8]] = {
        let table: [(Character, UInt16)] = [
            ("0", 0b000110100), ("1", 0b100100001), ("2", 0b001100001),
            ("3", 0b101100000), ("4", 0b000110001), ("5", 0b100110000),
            ("6", 0b001110000), ("7", 0b000100101), ("8", 0b100100100),
            ("9", 0b001100100),
            ("A", 0b100001001), ("B", 0b001001001), ("C", 0b101001000),
            ("D", 0b000011001), ("E", 0b100011000), ("F", 0b001011000),
            ("G", 0b000001101), ("H", 0b100001100), ("I", 0b001001100),
            ("J", 0b000011100),
            ("K", 0b100000011), ("L", 0b001000011), ("M", 0b101000010),
            ("N", 0b000010011), ("O", 0b100010010), ("P", 0b001010010),
            ("Q", 0b000000111), ("R", 0b100000110), ("S", 0b001000110),
            ("T", 0b000010110),
            ("U", 0b110000001), ("V", 0b011000001), ("W", 0b111000000),
            ("X", 0b010010001), ("Y", 0b110010000), ("Z", 0b011010000),
            ("-", 0b010000101), (".", 0b110000100), (" ", 0b011000100),
            ("$", 0b010101000), ("/", 0b010100010), ("+", 0b010001010),
            ("%", 0b000101010), ("*", 0b010010100),
        ]
        var dict: [Character: [UInt8]] = [:]
        for (ch, bits) in table {
            var widths: [UInt8] = []
            for pos in (0..<9).reversed() {
                let isWide = (bits >> pos) & 1 == 1
                widths.append(isWide ? 3 : 1)
            }
            dict[ch] = widths
        }
        return dict
    }()
}

// MARK: - ITF (Interleaved 2 of 5)

extension BarcodeRasterizer {

    private static func encodeITF(_ data: Data) -> [Bool]? {
        guard let digits = asciiDigits(data), digits.count.isMultiple(of: 2) else { return nil }

        var modules: [Bool] = []

        // Start pattern: narrow bar, narrow space, narrow bar, narrow space
        modules.append(contentsOf: [true, false, true, false])

        // Encode digit pairs
        for pairIndex in stride(from: 0, to: digits.count, by: 2) {
            let d1 = digits[pairIndex]
            let d2 = digits[pairIndex + 1]
            let barPattern = itfDigitPatterns[d1]
            let spacePattern = itfDigitPatterns[d2]

            // Interleave: bar[0] space[0] bar[1] space[1] ...
            for i in 0..<5 {
                let barWidth: Int = barPattern[i] == 1 ? 3 : 1
                let spaceWidth: Int = spacePattern[i] == 1 ? 3 : 1
                for _ in 0..<barWidth { modules.append(true) }
                for _ in 0..<spaceWidth { modules.append(false) }
            }
        }

        // Stop pattern: wide bar, narrow space, narrow bar
        for _ in 0..<3 { modules.append(true) }
        modules.append(false)
        modules.append(true)

        return modules
    }

    // ITF digit patterns: 5 elements, 0=narrow, 1=wide
    private static let itfDigitPatterns: [[UInt8]] = [
        [0, 0, 1, 1, 0],  // 0
        [1, 0, 0, 0, 1],  // 1
        [0, 1, 0, 0, 1],  // 2
        [1, 1, 0, 0, 0],  // 3
        [0, 0, 1, 0, 1],  // 4
        [1, 0, 1, 0, 0],  // 5
        [0, 1, 1, 0, 0],  // 6
        [0, 0, 0, 1, 1],  // 7
        [1, 0, 0, 1, 0],  // 8
        [0, 1, 0, 1, 0],  // 9
    ]
}

// MARK: - CODABAR

extension BarcodeRasterizer {

    private static func encodeCodabar(_ data: Data) -> [Bool]? {
        guard let text = String(data: data, encoding: .ascii), !text.isEmpty else { return nil }

        let chars = Array(text.uppercased())
        var modules: [Bool] = []

        for (i, ch) in chars.enumerated() {
            if i > 0 {
                // Inter-character gap
                modules.append(false)
            }
            guard let pattern = codabarPatterns[ch] else { return nil }
            modules.append(contentsOf: widthsToModules(pattern))
        }

        return modules
    }

    // CODABAR patterns: 7 elements (B S B S B S B), N=1, W=3
    private static let codabarPatterns: [Character: [UInt8]] = [
        "0": [1,1,1,1,1,3,3], "1": [1,1,1,1,3,3,1],
        "2": [1,1,1,3,1,1,3], "3": [3,3,1,1,1,1,1],
        "4": [1,1,3,1,1,3,1], "5": [3,1,1,1,1,3,1],
        "6": [1,3,1,1,3,1,1], "7": [1,3,1,3,1,1,1],
        "8": [1,3,3,1,1,1,1], "9": [3,1,1,3,1,1,1],
        "-": [1,1,1,1,3,1,3], "$": [1,1,3,1,3,1,1],
        ":": [3,1,1,1,3,1,3], "/": [3,1,3,1,1,1,3],
        ".": [3,1,3,1,3,1,1], "+": [1,1,3,1,3,1,3],
        "A": [1,1,3,3,1,3,1], "B": [1,3,1,1,3,1,3],
        "C": [1,1,3,1,1,3,3], "D": [1,1,3,1,3,3,1],
    ]
}

// MARK: - CODE93

extension BarcodeRasterizer {

    private static func encodeCode93(_ data: Data) -> [Bool]? {
        guard let text = String(data: data, encoding: .ascii), !text.isEmpty else { return nil }

        // Convert characters to values
        var values: [Int] = []
        for ch in text.uppercased() {
            guard let val = code93CharValue[ch] else { return nil }
            values.append(val)
        }

        // Check digit C (weight 1-20)
        var sum = 0
        for (i, v) in values.reversed().enumerated() {
            sum += v * ((i % 20) + 1)
        }
        let checkC = sum % 47
        values.append(checkC)

        // Check digit K (weight 1-15)
        sum = 0
        for (i, v) in values.reversed().enumerated() {
            sum += v * ((i % 15) + 1)
        }
        let checkK = sum % 47
        values.append(checkK)

        // Build modules
        var modules: [Bool] = []

        // Start: 111141
        modules.append(contentsOf: widthsToModules(parseWidths("111141")))

        for value in values {
            modules.append(contentsOf: widthsToModules(parseWidths(code93Patterns[value])))
        }

        // Stop: 111141 + termination bar (1)
        modules.append(contentsOf: widthsToModules(parseWidths("111141")))
        modules.append(true) // termination bar

        return modules
    }

    private static let code93Patterns: [String] = [
        "131112", "111213", "111312", "111411", "121113",  //  0-4
        "121212", "121311", "111114", "131211", "141111",  //  5-9
        "211113", "211212", "211311", "221112", "221211",  // 10-14 (A-E)
        "231111", "112113", "112212", "112311", "122112",  // 15-19 (F-J)
        "132111", "111123", "111222", "111321", "121122",  // 20-24 (K-O)
        "131121", "212112", "212211", "211122", "211221",  // 25-29 (P-T)
        "221121", "222111", "112122", "112221", "122121",  // 30-34 (U-Y)
        "123111", "121131", "311112", "311211", "321111",  // 35-39 (Z, -, ., space, $)
        "112131", "113121", "211131",                       // 40-42 (/, +, %)
    ]

    private static let code93CharValue: [Character: Int] = {
        var dict: [Character: Int] = [:]
        let chars: [Character] = [
            "0","1","2","3","4","5","6","7","8","9",
            "A","B","C","D","E","F","G","H","I","J",
            "K","L","M","N","O","P","Q","R","S","T",
            "U","V","W","X","Y","Z","-","."," ","$",
            "/","+","%",
        ]
        for (i, ch) in chars.enumerated() {
            dict[ch] = i
        }
        return dict
    }()
}
