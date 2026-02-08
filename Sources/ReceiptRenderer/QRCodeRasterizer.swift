import Foundation

struct QRCodeRasterizer {

    struct QRImage {
        let data: Data
        let widthBytes: Int
        let height: Int
    }

    // MARK: - Public API

    static func rasterize(
        data: Data,
        ecLevel: Int,
        moduleSize: Int
    ) -> QRImage? {
        guard !data.isEmpty else { return nil }
        let ec = min(max(ecLevel, 0), 3)

        guard let version = selectVersion(dataLength: data.count, ecLevel: ec) else {
            return nil
        }
        let dataCodewords = encodeData(data, version: version, ecLevel: ec)
        let finalMessage = addErrorCorrection(dataCodewords, version: version, ecLevel: ec)
        guard let matrix = buildMatrix(finalMessage, version: version, ecLevel: ec) else {
            return nil
        }
        return renderBitmap(matrix: matrix, moduleSize: moduleSize)
    }

    // MARK: - Version Selection

    private static func selectVersion(dataLength: Int, ecLevel: Int) -> Int? {
        for v in 1...40 {
            let capacity = dataCapacity(version: v, ecLevel: ecLevel)
            let countBits = v <= 9 ? 8 : 16
            let totalBits = 4 + countBits + dataLength * 8
            let totalCodewords = (totalBits + 7) / 8
            if totalCodewords <= capacity {
                return v
            }
        }
        return nil
    }

    private static func dataCapacity(version: Int, ecLevel: Int) -> Int {
        let info = ecBlockInfo[(version - 1) * 4 + ecLevel]
        return info.0 * info.2 + info.3 * info.4
    }

    // MARK: - Data Encoding (Byte mode)

    private static func encodeData(_ data: Data, version: Int, ecLevel: Int) -> [UInt8] {
        let capacity = dataCapacity(version: version, ecLevel: ecLevel)
        let countBits = version <= 9 ? 8 : 16

        var bits: [Bool] = []
        // Mode indicator: 0100 (byte mode)
        bits.append(contentsOf: [false, true, false, false])
        // Character count
        for i in (0..<countBits).reversed() {
            bits.append((data.count >> i) & 1 == 1)
        }
        // Data bytes
        for byte in data {
            for i in (0..<8).reversed() {
                bits.append((byte >> i) & 1 == 1)
            }
        }
        // Terminator
        let terminatorLen = min(4, capacity * 8 - bits.count)
        for _ in 0..<terminatorLen { bits.append(false) }
        // Pad to byte boundary
        while bits.count % 8 != 0 { bits.append(false) }
        // Convert to bytes
        var codewords: [UInt8] = []
        for i in stride(from: 0, to: bits.count, by: 8) {
            var byte: UInt8 = 0
            for j in 0..<8 { if bits[i + j] { byte |= 1 << (7 - j) } }
            codewords.append(byte)
        }
        // Pad codewords
        var padByte: UInt8 = 0xEC
        while codewords.count < capacity {
            codewords.append(padByte)
            padByte = padByte == 0xEC ? 0x11 : 0xEC
        }
        return codewords
    }

    // MARK: - Error Correction (Reed-Solomon over GF(256))

    private static let gfTables: (exp: [Int], log: [Int]) = {
        var exp = [Int](repeating: 0, count: 256)
        var log = [Int](repeating: 0, count: 256)
        var v = 1
        for i in 0..<255 {
            exp[i] = v
            log[v] = i
            v <<= 1
            if v >= 256 { v ^= 0x11D }
        }
        exp[255] = exp[0]
        return (exp, log)
    }()

    private static func gfMul(_ a: Int, _ b: Int) -> Int {
        guard a != 0, b != 0 else { return 0 }
        return gfTables.exp[(gfTables.log[a] + gfTables.log[b]) % 255]
    }

    private static func rsGeneratorPoly(ecCount: Int) -> [Int] {
        var gen = [1]
        for i in 0..<ecCount {
            var newGen = [Int](repeating: 0, count: gen.count + 1)
            for j in 0..<gen.count {
                newGen[j] ^= gen[j]
                newGen[j + 1] ^= gfMul(gen[j], gfTables.exp[i])
            }
            gen = newGen
        }
        return gen
    }

    private static func rsEncode(data: [UInt8], gen: [Int]) -> [UInt8] {
        let ecCount = gen.count - 1
        var remainder = [Int](repeating: 0, count: ecCount)
        for byte in data {
            let factor = Int(byte) ^ remainder[0]
            remainder.removeFirst()
            remainder.append(0)
            if factor != 0 {
                for i in 0..<ecCount {
                    remainder[i] ^= gfMul(factor, gen[i + 1])
                }
            }
        }
        return remainder.map { UInt8($0) }
    }

    private static func addErrorCorrection(_ data: [UInt8], version: Int, ecLevel: Int) -> [UInt8] {
        let info = ecBlockInfo[(version - 1) * 4 + ecLevel]
        let ecPerBlock = info.1
        let g1Blocks = info.0, g1Data = info.2
        let g2Blocks = info.3, g2Data = info.4
        let gen = rsGeneratorPoly(ecCount: ecPerBlock)

        var dataBlocks: [[UInt8]] = []
        var ecBlocks: [[UInt8]] = []
        var offset = 0
        for _ in 0..<g1Blocks {
            let block = Array(data[offset..<offset + g1Data])
            dataBlocks.append(block)
            ecBlocks.append(rsEncode(data: block, gen: gen))
            offset += g1Data
        }
        for _ in 0..<g2Blocks {
            let block = Array(data[offset..<offset + g2Data])
            dataBlocks.append(block)
            ecBlocks.append(rsEncode(data: block, gen: gen))
            offset += g2Data
        }

        // Interleave data
        var result: [UInt8] = []
        let maxDataLen = max(g1Data, g2Data)
        for i in 0..<maxDataLen {
            for block in dataBlocks {
                if i < block.count { result.append(block[i]) }
            }
        }
        // Interleave EC
        for i in 0..<ecPerBlock {
            for block in ecBlocks {
                if i < block.count { result.append(block[i]) }
            }
        }
        return result
    }

    // MARK: - Matrix Construction

    private static func buildMatrix(_ message: [UInt8], version: Int, ecLevel: Int) -> [[Bool]]? {
        let size = 4 * version + 17
        var matrix = [[Bool?]](repeating: [Bool?](repeating: nil, count: size), count: size)
        var reserved = [[Bool]](repeating: [Bool](repeating: false, count: size), count: size)

        addFinderPatterns(&matrix, &reserved, size)
        addAlignmentPatterns(&matrix, &reserved, version, size)
        addTimingPatterns(&matrix, &reserved, size)

        // Dark module
        matrix[4 * version + 9][8] = true
        reserved[4 * version + 9][8] = true

        reserveFormatArea(&reserved, size)
        if version >= 7 { reserveVersionArea(&reserved, size) }

        placeDataBits(&matrix, reserved, message, size)

        // Evaluate all 8 masks to find best
        var bestMask = 0
        var bestScore = Int.max
        for mask in 0..<8 {
            var candidate = matrix
            applyMask(&candidate, reserved, mask, size)
            addFormatInfo(&candidate, ecLevel, mask, size)
            if version >= 7 { addVersionInfo(&candidate, version, size) }
            let score = evaluatePenalty(candidate, size)
            if score < bestScore { bestScore = score; bestMask = mask }
        }

        applyMask(&matrix, reserved, bestMask, size)
        addFormatInfo(&matrix, ecLevel, bestMask, size)
        if version >= 7 { addVersionInfo(&matrix, version, size) }

        return matrix.map { $0.map { $0 ?? false } }
    }

    private static func addFinderPatterns(
        _ matrix: inout [[Bool?]], _ reserved: inout [[Bool]], _ size: Int
    ) {
        func place(row: Int, col: Int) {
            for r in -1...7 {
                for c in -1...7 {
                    let mr = row + r, mc = col + c
                    guard mr >= 0, mr < size, mc >= 0, mc < size else { continue }
                    let isDark: Bool
                    if r == -1 || r == 7 || c == -1 || c == 7 {
                        isDark = false // separator
                    } else if r == 0 || r == 6 || c == 0 || c == 6
                                || (r >= 2 && r <= 4 && c >= 2 && c <= 4) {
                        isDark = true
                    } else {
                        isDark = false
                    }
                    matrix[mr][mc] = isDark
                    reserved[mr][mc] = true
                }
            }
        }
        place(row: 0, col: 0)
        place(row: 0, col: size - 7)
        place(row: size - 7, col: 0)
    }

    private static func addAlignmentPatterns(
        _ matrix: inout [[Bool?]], _ reserved: inout [[Bool]], _ version: Int, _ size: Int
    ) {
        guard version >= 2 else { return }
        let positions = alignmentPositions[version - 2]
        for row in positions {
            for col in positions {
                // Skip if near a finder pattern
                if (row <= 8 && col <= 8)
                    || (row <= 8 && col >= size - 8)
                    || (row >= size - 8 && col <= 8) { continue }
                for r in -2...2 {
                    for c in -2...2 {
                        let isDark = r == -2 || r == 2 || c == -2 || c == 2 || (r == 0 && c == 0)
                        matrix[row + r][col + c] = isDark
                        reserved[row + r][col + c] = true
                    }
                }
            }
        }
    }

    private static func addTimingPatterns(
        _ matrix: inout [[Bool?]], _ reserved: inout [[Bool]], _ size: Int
    ) {
        for i in 8..<(size - 8) {
            let isDark = i % 2 == 0
            if matrix[6][i] == nil {
                matrix[6][i] = isDark
                reserved[6][i] = true
            }
            if matrix[i][6] == nil {
                matrix[i][6] = isDark
                reserved[i][6] = true
            }
        }
    }

    private static func reserveFormatArea(_ reserved: inout [[Bool]], _ size: Int) {
        for i in 0...8 {
            reserved[8][i] = true
            reserved[i][8] = true
        }
        for i in 0...7 { reserved[8][size - 1 - i] = true }
        for i in 0...6 { reserved[size - 1 - i][8] = true }
    }

    private static func reserveVersionArea(_ reserved: inout [[Bool]], _ size: Int) {
        for i in 0..<18 {
            reserved[size - 11 + (i % 3)][i / 3] = true
            reserved[i / 3][size - 11 + (i % 3)] = true
        }
    }

    private static func placeDataBits(
        _ matrix: inout [[Bool?]], _ reserved: [[Bool]], _ message: [UInt8], _ size: Int
    ) {
        var bits: [Bool] = []
        for byte in message {
            for i in (0..<8).reversed() { bits.append((byte >> i) & 1 == 1) }
        }
        var bitIndex = 0
        var upward = true
        var col = size - 1
        while col >= 0 {
            if col == 6 { col -= 1 }
            for step in 0..<size {
                let row = upward ? (size - 1 - step) : step
                for dc in 0...1 {
                    let c = col - dc
                    guard c >= 0, !reserved[row][c] else { continue }
                    matrix[row][c] = bitIndex < bits.count ? bits[bitIndex] : false
                    bitIndex += 1
                }
            }
            upward = !upward
            col -= 2
        }
    }

    private static func applyMask(
        _ matrix: inout [[Bool?]], _ reserved: [[Bool]], _ mask: Int, _ size: Int
    ) {
        for row in 0..<size {
            for col in 0..<size {
                guard !reserved[row][col] else { continue }
                let flip: Bool
                switch mask {
                case 0: flip = (row + col) % 2 == 0
                case 1: flip = row % 2 == 0
                case 2: flip = col % 3 == 0
                case 3: flip = (row + col) % 3 == 0
                case 4: flip = (row / 2 + col / 3) % 2 == 0
                case 5: flip = (row * col) % 2 + (row * col) % 3 == 0
                case 6: flip = ((row * col) % 2 + (row * col) % 3) % 2 == 0
                case 7: flip = ((row + col) % 2 + (row * col) % 3) % 2 == 0
                default: flip = false
                }
                if flip { matrix[row][col] = !(matrix[row][col] ?? false) }
            }
        }
    }

    private static func encodeFormatInfo(_ ecLevel: Int, _ mask: Int) -> UInt16 {
        let ecBits = [0b01, 0b00, 0b11, 0b10] // L, M, Q, H
        let data = (ecBits[ecLevel] << 3) | mask
        var bits = data << 10
        for i in stride(from: 14, through: 10, by: -1) {
            if bits & (1 << i) != 0 { bits ^= 0x537 << (i - 10) }
        }
        return UInt16((data << 10 | bits) ^ 0x5412)
    }

    private static func addFormatInfo(
        _ matrix: inout [[Bool?]], _ ecLevel: Int, _ mask: Int, _ size: Int
    ) {
        let info = encodeFormatInfo(ecLevel, mask)
        // Copy 1: around top-left finder
        let pos1: [(Int, Int)] = [
            (8,0),(8,1),(8,2),(8,3),(8,4),(8,5),(8,7),(8,8),
            (7,8),(5,8),(4,8),(3,8),(2,8),(1,8),(0,8),
        ]
        // Copy 2: other finders
        let pos2: [(Int, Int)] = [
            (size-1,8),(size-2,8),(size-3,8),(size-4,8),(size-5,8),(size-6,8),(size-7,8),
            (8,size-8),(8,size-7),(8,size-6),(8,size-5),(8,size-4),(8,size-3),(8,size-2),(8,size-1),
        ]
        for (index, (r, c)) in pos1.enumerated() {
            matrix[r][c] = (info >> (14 - index)) & 1 == 1
        }
        for (index, (r, c)) in pos2.enumerated() {
            matrix[r][c] = (info >> (14 - index)) & 1 == 1
        }
    }

    private static func encodeVersionInfo(_ version: Int) -> UInt32 {
        var bits = version << 12
        for i in stride(from: 17, through: 12, by: -1) {
            if bits & (1 << i) != 0 { bits ^= 0x1F25 << (i - 12) }
        }
        return UInt32((version << 12) | bits)
    }

    private static func addVersionInfo(
        _ matrix: inout [[Bool?]], _ version: Int, _ size: Int
    ) {
        let info = encodeVersionInfo(version)
        for i in 0..<18 {
            let bit = (info >> i) & 1 == 1
            matrix[size - 11 + (i % 3)][i / 3] = bit
            matrix[i / 3][size - 11 + (i % 3)] = bit
        }
    }

    private static func evaluatePenalty(_ matrix: [[Bool?]], _ size: Int) -> Int {
        var penalty = 0

        // Rule 1: runs of 5+ same color in row/column
        for row in 0..<size {
            var count = 1
            for col in 1..<size {
                if matrix[row][col] == matrix[row][col - 1] { count += 1 }
                else { if count >= 5 { penalty += count - 2 }; count = 1 }
            }
            if count >= 5 { penalty += count - 2 }
        }
        for col in 0..<size {
            var count = 1
            for row in 1..<size {
                if matrix[row][col] == matrix[row - 1][col] { count += 1 }
                else { if count >= 5 { penalty += count - 2 }; count = 1 }
            }
            if count >= 5 { penalty += count - 2 }
        }

        // Rule 2: 2x2 blocks of same color
        for row in 0..<(size - 1) {
            for col in 0..<(size - 1) {
                let v = matrix[row][col]
                if v == matrix[row][col+1] && v == matrix[row+1][col] && v == matrix[row+1][col+1] {
                    penalty += 3
                }
            }
        }

        // Rule 3: finder-like patterns
        let p1: [Bool] = [true,false,true,true,true,false,true,false,false,false,false]
        let p2: [Bool] = [false,false,false,false,true,false,true,true,true,false,true]
        for row in 0..<size {
            for col in 0...(size - 11) {
                var m1 = true, m2 = true
                for i in 0..<11 {
                    let v = matrix[row][col + i] ?? false
                    if v != p1[i] { m1 = false }
                    if v != p2[i] { m2 = false }
                }
                if m1 || m2 { penalty += 40 }
            }
        }
        for col in 0..<size {
            for row in 0...(size - 11) {
                var m1 = true, m2 = true
                for i in 0..<11 {
                    let v = matrix[row + i][col] ?? false
                    if v != p1[i] { m1 = false }
                    if v != p2[i] { m2 = false }
                }
                if m1 || m2 { penalty += 40 }
            }
        }

        // Rule 4: dark module proportion
        var dark = 0
        for row in 0..<size { for col in 0..<size { if matrix[row][col] == true { dark += 1 } } }
        let percent = dark * 100 / (size * size)
        let prev5 = abs(percent / 5 * 5 - 50) / 5
        let next5 = abs((percent / 5 + 1) * 5 - 50) / 5
        penalty += min(prev5, next5) * 10

        return penalty
    }

    // MARK: - Bitmap Rendering

    private static func renderBitmap(matrix: [[Bool]], moduleSize: Int) -> QRImage {
        let qrSize = matrix.count
        let quietZone = 4
        let totalModules = qrSize + 2 * quietZone
        let pixelSize = totalModules * moduleSize
        let widthBytes = (pixelSize + 7) / 8
        var bitmap = Data(repeating: 0, count: widthBytes * pixelSize)

        for row in 0..<qrSize {
            for col in 0..<qrSize {
                guard matrix[row][col] else { continue }
                let baseX = (quietZone + col) * moduleSize
                let baseY = (quietZone + row) * moduleSize
                for dy in 0..<moduleSize {
                    for dx in 0..<moduleSize {
                        let x = baseX + dx, y = baseY + dy
                        bitmap[y * widthBytes + x / 8] |= UInt8(1 << (7 - x % 8))
                    }
                }
            }
        }
        return QRImage(data: bitmap, widthBytes: widthBytes, height: pixelSize)
    }

    // MARK: - Tables

    // EC block info: (g1Blocks, ecPerBlock, g1Data, g2Blocks, g2Data)
    // Index: (version-1)*4 + ecLevel  where ecLevel: 0=L, 1=M, 2=Q, 3=H
    // swiftlint:disable:next large_tuple
    private static let ecBlockInfo: [(Int, Int, Int, Int, Int)] = [
        // V1: L, M, Q, H
        (1, 7,  19, 0, 0),  (1, 10, 16, 0, 0),  (1, 13, 13, 0, 0),  (1, 17, 9,  0, 0),
        // V2
        (1, 10, 34, 0, 0),  (1, 16, 28, 0, 0),  (1, 22, 22, 0, 0),  (1, 28, 16, 0, 0),
        // V3
        (1, 15, 55, 0, 0),  (1, 26, 44, 0, 0),  (2, 18, 17, 0, 0),  (2, 22, 13, 0, 0),
        // V4
        (1, 20, 80, 0, 0),  (2, 18, 32, 0, 0),  (2, 26, 24, 0, 0),  (4, 16, 9,  0, 0),
        // V5
        (1, 26, 108, 0, 0), (2, 24, 43, 0, 0),  (2, 18, 15, 2, 16), (2, 22, 11, 2, 12),
        // V6
        (2, 18, 68, 0, 0),  (4, 16, 27, 0, 0),  (4, 24, 19, 0, 0),  (4, 28, 15, 0, 0),
        // V7
        (2, 20, 78, 0, 0),  (4, 18, 31, 0, 0),  (2, 18, 14, 4, 15), (4, 26, 13, 1, 14),
        // V8
        (2, 24, 97, 0, 0),  (2, 22, 38, 2, 39), (4, 22, 18, 2, 19), (4, 26, 14, 2, 15),
        // V9
        (2, 30, 116, 0, 0), (3, 22, 36, 2, 37), (4, 20, 16, 4, 17), (4, 24, 12, 4, 13),
        // V10
        (2, 18, 68, 2, 69), (4, 26, 43, 1, 44), (6, 24, 19, 2, 20), (6, 28, 15, 2, 16),
        // V11
        (4, 20, 81, 0, 0),  (1, 30, 50, 4, 51), (4, 28, 22, 4, 23), (3, 24, 12, 8, 13),
        // V12
        (2, 24, 92, 2, 93), (6, 22, 36, 2, 37), (4, 26, 20, 6, 21), (7, 28, 14, 4, 15),
        // V13
        (4, 26, 107, 0, 0), (8, 22, 37, 1, 38), (8, 24, 20, 4, 21), (12, 22, 11, 4, 12),
        // V14
        (3, 30, 115, 1, 116), (4, 24, 40, 5, 41), (11, 20, 16, 5, 17), (11, 24, 12, 5, 13),
        // V15
        (5, 22, 87, 1, 88), (5, 24, 41, 5, 42), (5, 30, 24, 7, 25), (11, 24, 12, 7, 13),
        // V16
        (5, 24, 98, 1, 99), (7, 28, 45, 3, 46), (15, 24, 19, 2, 20), (3, 30, 15, 13, 16),
        // V17
        (1, 28, 107, 5, 108), (10, 28, 46, 1, 47), (1, 28, 22, 15, 23), (2, 28, 14, 17, 15),
        // V18
        (5, 30, 120, 1, 121), (9, 26, 43, 4, 44), (17, 28, 22, 1, 23), (2, 28, 14, 19, 15),
        // V19
        (3, 28, 113, 4, 114), (3, 26, 44, 11, 45), (17, 26, 21, 4, 22), (9, 26, 13, 16, 14),
        // V20
        (3, 28, 107, 5, 108), (3, 26, 41, 13, 42), (15, 28, 24, 5, 25), (15, 28, 15, 10, 16),
        // V21
        (4, 28, 116, 4, 117), (17, 26, 42, 0, 0), (17, 30, 22, 6, 23), (19, 28, 16, 6, 17),
        // V22
        (2, 28, 111, 7, 112), (17, 28, 46, 0, 0), (7, 24, 24, 16, 25), (34, 30, 13, 0, 0),
        // V23
        (4, 30, 121, 5, 122), (4, 28, 47, 14, 48), (11, 30, 24, 14, 25), (16, 30, 15, 14, 16),
        // V24
        (6, 30, 117, 4, 118), (6, 28, 45, 14, 46), (11, 30, 24, 16, 25), (30, 30, 16, 2, 17),
        // V25
        (8, 26, 106, 4, 107), (8, 28, 47, 13, 48), (7, 30, 24, 22, 25), (22, 30, 15, 13, 16),
        // V26
        (10, 28, 114, 2, 115), (19, 28, 46, 4, 47), (28, 28, 22, 6, 23), (33, 30, 16, 4, 17),
        // V27
        (8, 30, 122, 4, 123), (22, 28, 45, 3, 46), (8, 30, 23, 26, 24), (12, 30, 15, 28, 16),
        // V28
        (3, 30, 117, 10, 118), (3, 28, 45, 23, 46), (4, 30, 24, 31, 25), (11, 30, 15, 31, 16),
        // V29
        (7, 30, 116, 7, 117), (21, 28, 45, 7, 46), (1, 30, 23, 37, 24), (19, 30, 15, 26, 16),
        // V30
        (5, 30, 115, 10, 116), (19, 28, 47, 10, 48), (15, 30, 24, 25, 25), (23, 30, 15, 25, 16),
        // V31
        (13, 30, 115, 3, 116), (2, 28, 46, 29, 47), (42, 30, 24, 1, 25), (23, 30, 15, 28, 16),
        // V32
        (17, 30, 115, 0, 0), (10, 28, 46, 23, 47), (10, 30, 24, 35, 25), (19, 30, 15, 35, 16),
        // V33
        (17, 30, 115, 1, 116), (14, 28, 46, 21, 47), (29, 30, 24, 19, 25), (11, 30, 15, 46, 16),
        // V34
        (13, 30, 115, 6, 116), (14, 28, 46, 23, 47), (44, 30, 24, 7, 25), (59, 30, 16, 1, 17),
        // V35
        (12, 30, 121, 7, 122), (12, 28, 47, 26, 48), (39, 30, 24, 14, 25), (22, 30, 15, 41, 16),
        // V36
        (6, 30, 121, 14, 122), (6, 28, 47, 34, 48), (46, 30, 24, 10, 25), (2, 30, 15, 64, 16),
        // V37
        (17, 30, 122, 4, 123), (29, 28, 46, 14, 47), (49, 30, 24, 10, 25), (24, 30, 15, 46, 16),
        // V38
        (4, 30, 122, 18, 123), (13, 28, 46, 32, 47), (48, 30, 24, 14, 25), (42, 30, 15, 32, 16),
        // V39
        (20, 30, 117, 4, 118), (40, 28, 47, 7, 48), (43, 30, 24, 22, 25), (10, 30, 15, 67, 16),
        // V40
        (19, 30, 118, 6, 119), (18, 28, 47, 31, 48), (34, 30, 24, 34, 25), (20, 30, 15, 61, 16),
    ]

    // Alignment pattern center positions per version (version 2 = index 0)
    private static let alignmentPositions: [[Int]] = [
        [6, 18],                                    // V2
        [6, 22],                                    // V3
        [6, 26],                                    // V4
        [6, 30],                                    // V5
        [6, 34],                                    // V6
        [6, 22, 38],                                // V7
        [6, 24, 42],                                // V8
        [6, 26, 46],                                // V9
        [6, 28, 50],                                // V10
        [6, 30, 54],                                // V11
        [6, 32, 58],                                // V12
        [6, 34, 62],                                // V13
        [6, 26, 46, 66],                            // V14
        [6, 26, 48, 70],                            // V15
        [6, 26, 50, 74],                            // V16
        [6, 30, 54, 78],                            // V17
        [6, 30, 56, 82],                            // V18
        [6, 30, 58, 86],                            // V19
        [6, 34, 62, 90],                            // V20
        [6, 28, 50, 72, 94],                        // V21
        [6, 26, 50, 74, 98],                        // V22
        [6, 30, 54, 78, 102],                       // V23
        [6, 28, 54, 80, 106],                       // V24
        [6, 32, 58, 84, 110],                       // V25
        [6, 30, 58, 86, 114],                       // V26
        [6, 34, 62, 90, 118],                       // V27
        [6, 26, 50, 74, 98, 122],                   // V28
        [6, 30, 54, 78, 102, 126],                  // V29
        [6, 26, 52, 78, 104, 130],                  // V30
        [6, 30, 56, 82, 108, 134],                  // V31
        [6, 34, 60, 86, 112, 138],                  // V32
        [6, 30, 58, 86, 114, 142],                  // V33
        [6, 34, 62, 90, 118, 146],                  // V34
        [6, 30, 54, 78, 102, 126, 150],             // V35
        [6, 24, 50, 76, 102, 128, 154],             // V36
        [6, 28, 54, 80, 106, 132, 158],             // V37
        [6, 32, 58, 84, 110, 136, 162],             // V38
        [6, 26, 54, 82, 110, 138, 166],             // V39
        [6, 30, 58, 86, 114, 142, 170],             // V40
    ]
}
