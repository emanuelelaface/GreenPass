/*
 Copyright (c) 2017-2020 ApolloZhu <public-apollonian@outlook.com>
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
 */


import Foundation
import SwiftUI

enum BCH {
    private static let g15      =     0b10100110111
    private static let g18      =   0b1111100100101
    private static let g15Mask  = 0b101010000010010
    private static let g15Digit = digit(of: g15)
    private static let g18Digit = digit(of: g18)

    static func typeInfo(of data: Int) -> Int {
        var d = data << 10
        while digit(of: d) - g15Digit >= 0 {
            d ^= (g15 << (digit(of: d) - g15Digit))
        }
        return ((data << 10) | d) ^ g15Mask
    }

    static func typeNumber(of data: Int) -> Int {
        var d = data << 12
        while digit(of: d) - g18Digit >= 0 {
            d ^= (g18 << (digit(of: d) - g18Digit))
        }
        return (data << 12) | d
    }

    private static func digit(of data: Int) -> Int {
        var digit = 0
        var data = UInt(data) // unsigned shift
        while data != 0 {
            digit += 1
            data >>= 1
        }
        return digit
    }
}

struct QR8bitByte {
    let mode: QRMode = .bitByte8
    let parsedData: Data
    
    var count: Int {
        return parsedData.count
    }
    
    func write(to buffer: inout QRBitBuffer) {
        for datium in parsedData {
            buffer.put(UInt(datium), length: 8)
        }
    }
}

struct QRBitBuffer {
    var buffer = [UInt]()
    private(set) var bitCount = 0
    
    func get(index: Int) -> Bool {
        let bufIndex = index / 8
        return ((buffer[bufIndex] >> (7 - index % 8)) & 1) == 1
    }
    
    subscript(index: Int) -> Bool {
        return get(index: index)
    }
    
    mutating func put(_ num: UInt, length: Int) {
        for i in 0..<length {
            put(((num >> (length - i - 1)) & 1) == 1)
        }
    }
    
    mutating func put(_ bit: Bool) {
        let bufIndex = bitCount / 8
        if buffer.count <= bufIndex {
            buffer.append(0)
        }
        if bit {
            buffer[bufIndex] |= (UInt(0x80) >> (bitCount % 8))
        }
        bitCount += 1
    }
}

open class QRCode {
    /// Error correct level.
    public let correctLevel: QRErrorCorrectLevel
    /// If the image codes has a border around its content.
    public let hasBorder: Bool
    private let model: QRCodeModel

    /// Construct a QRCode instance.
    /// - Parameters:
    ///   - text: content of the QRCode.
    ///   - encoding: encoding used for generating data from text.
    ///   - errorCorrectLevel: error correct level, defaults to high.
    ///   - hasBorder: if the image codes has a border around, defaults and suggests to be true.
    /// - Throws: see `QRCodeError`
    /// - Warning: Is computationally intensive.
    public convenience init(
        _ text: String,
        encoding: String.Encoding = .utf8,
        errorCorrectLevel: QRErrorCorrectLevel = .H,
        withBorder hasBorder: Bool = true
    ) throws {
        guard let data = text.data(using: encoding) else {
            throw QRCodeError.text(text, incompatibleWithEncoding: encoding)
        }
        try self.init(data, errorCorrectLevel: errorCorrectLevel,
                      withBorder: hasBorder)
    }

    /// Construct a QRCode instance.
    /// - Parameters:
    ///   - data: raw content of the QRCode.
    ///   - errorCorrectLevel: error correct level, defaults to high.
    ///   - hasBorder: if the image codes has a border around, defaults and suggests to be true.
    /// - Throws: see `QRCodeError`
    public init(
        _ data: Data,
        errorCorrectLevel: QRErrorCorrectLevel = .H,
        withBorder hasBorder: Bool = true
    ) throws {
        self.model = try QRCodeModel(data: data,
                                     errorCorrectLevel: errorCorrectLevel)
        self.correctLevel = errorCorrectLevel
        self.hasBorder = hasBorder
    }

    /// QRCode in binary form.
    open private(set) lazy var imageCodes: [[Bool]] = {
        if hasBorder {
            let line = [[Bool](repeating: false, count: model.moduleCount + 2)]
            return line + (0..<model.moduleCount).map { r in
                return [false] + (0..<model.moduleCount).map { c in
                    return model.isDark(r, c)
                } + [false]
            } + line
        } else {
            return (0..<model.moduleCount).map { r in
                (0..<model.moduleCount).map { c in
                    return model.isDark(r, c)
                }
            }
        }
    }()

    /// Convert QRCode to String.
    ///
    /// - Parameters:
    ///   - black: recommend to be "\u{1B}[7m  " or "##".
    ///   - white: recommend to be "\u{1B}[0m  " or "  ".
    /// - Returns: a matrix of characters that is scannable.
    open func toString(filledWith black: Any,
                       patchedWith white: Any) -> String {
        return String(imageCodes.reduce("") { $0 +
            "\($1.reduce("") { "\($0)\($1 ? black : white)" })\n"
        }.dropLast())
    }
}

public enum QRCodeError: Error {
    /// The thing you want to save is too large for `QRCode`.
    case dataLengthExceedsCapacityLimit
    /// Can not encode the given string using the specified encoding.
    case text(String, incompatibleWithEncoding: String.Encoding)
    /// Fill a new issue on GitHub with swift_qrcodejs, or submit a pull request.
    case internalError(ImplmentationError)

    /// Should probably contact developer is you ever see any of these.
    public enum ImplmentationError {
        /// swift_qrcodejs fail to determine how large is the data.
        case dataLengthIndeterminable
        /// swift_qrcodejs fail to find appropriate container for your data.
        case dataLength(Int, exceedsCapacityLimit: Int)
    }
}

struct QRCodeModel {
    let typeNumber: Int
    let errorCorrectLevel: QRErrorCorrectLevel
    private var modules: [[Bool?]]! = nil
    private(set) var moduleCount = 0
    private let encodedText: QR8bitByte
    private var dataCache: [Int]
    
    init(data: Data,
         errorCorrectLevel: QRErrorCorrectLevel) throws {
        self.encodedText = QR8bitByte(parsedData: data)

        self.typeNumber = try QRCodeType
            .typeNumber(forLength: encodedText.count,
                        errorCorrectLevel: errorCorrectLevel)
        self.errorCorrectLevel = errorCorrectLevel
        self.dataCache = try QRCodeModel.createData(
            typeNumber: typeNumber,
            errorCorrectLevel: errorCorrectLevel,
            data: encodedText
        )
        makeImpl(isTest: false, maskPattern: getBestMaskPattern())
    }

    /// Please be aware of index out of bounds error yourself.
    public func isDark(_ row: Int, _ col: Int) -> Bool {
        return modules?[row][col] == true
    }

    public func isLight(_ row: Int, _ col: Int) -> Bool {
        return !isDark(row, col)
    }

    private mutating func makeImpl(isTest test: Bool, maskPattern: QRMaskPattern) {
        moduleCount = typeNumber * 4 + 17
        modules = [[Bool?]](repeating:[Bool?](repeating: nil, count: moduleCount), count: moduleCount)
        setupPositionProbePattern(0, 0)
        setupPositionProbePattern(moduleCount - 7, 0)
        setupPositionProbePattern(0, moduleCount - 7)
        setupPositionAdjustPattern()
        setupTimingPattern()
        setupTypeInfo(isTest: test, maskPattern: maskPattern.rawValue)
        if typeNumber >= 7 {
            setupTypeNumber(isTest: test)
        }
        mapData(dataCache, maskPattern: maskPattern)
    }

    private mutating func setupPositionProbePattern(_ row: Int, _ col: Int) {
        for r in -1...7 {
            if row + r <= -1 || moduleCount <= row + r {
                continue
            }
            for c in -1...7 {
                if col + c <= -1 || moduleCount <= col + c {
                    continue
                }
                if (0 <= r && r <= 6 && (c == 0 || c == 6))
                    || (0 <= c && c <= 6 && (r == 0 || r == 6))
                    || (2 <= r && r <= 4 && 2 <= c && c <= 4) {
                    modules[row + r][col + c] = true
                } else {
                    modules[row + r][col + c] = false
                }
            }
        }
    }

    private mutating func setupTimingPattern() {
        for i in 8..<moduleCount - 8 {
            if modules[i][6] == nil {
                modules[i][6] = (i % 2 == 0)
            }
            if modules[6][i] == nil {
                modules[6][i] = (i % 2 == 0)
            }
        }
    }

    private mutating func setupPositionAdjustPattern() {
        #if swift(<5.1)
        let pos = QRPatternLocator.getPatternPosition(ofType: typeNumber)
        #else
        let pos = QRPatternLocator[typeNumber]
        #endif
        for i in pos.indices {
            for j in pos.indices {
                let row = pos[i]
                let col = pos[j]
                if modules[row][col] != nil {
                    continue
                }
                for r in -2...2 {
                    for c in -2...2 {
                        if r == -2 || r == 2 || c == -2 || c == 2 || r == 0 && c == 0 {
                            modules[row + r][col + c] = true
                        } else {
                            modules[row + r][col + c] = false
                        }
                    }
                }
            }
        }
    }

    private mutating func setupTypeNumber(isTest test: Bool) {
        let bits: Int = BCH.typeNumber(of: typeNumber)
        for i in 0..<18 {
            let mod = (!test && ((bits >> i) & 1) == 1)
            modules[i / 3][i % 3 + moduleCount - 8 - 3] = mod
            modules[i % 3 + moduleCount - 8 - 3][i / 3] = mod
        }
    }

    private mutating func setupTypeInfo(isTest test: Bool, maskPattern: Int) {
        let data = (errorCorrectLevel.pattern << 3) | maskPattern
        let bits: Int = BCH.typeInfo(of: data) // to enforce signed shift
        for i in 0..<15 {
            let mod = !test && ((bits >> i) & 1) == 1

            if i < 6 {
                modules[i][8] = mod
            } else if i < 8 {
                modules[i + 1][8] = mod
            } else {
                modules[moduleCount - 15 + i][8] = mod
            }

            if i < 8 {
                modules[8][moduleCount - i - 1] = mod
            } else if i < 9 {
                modules[8][15 - i - 1 + 1] = mod
            } else {
                modules[8][15 - i - 1] = mod
            }
        }
        modules[moduleCount - 8][8] = !test
    }

    private mutating func mapData(_ data: [Int], maskPattern: QRMaskPattern) {
        var inc = -1
        var row = moduleCount - 1
        var bitIndex = 7
        var byteIndex = 0

        var col: Int = moduleCount - 1
        while col > 0 {
            if col == 6 {
                col -= 1
            }
            while true {
                for c in 0..<2 {
                    if modules[row][col - c] == nil {
                        var dark = false
                        if byteIndex < data.count {
                            dark = ((UInt(data[byteIndex]) >> bitIndex) & 1) == 1
                        }
                        let mask = maskPattern.getMask(row, col - c)
                        if mask {
                            dark = !dark
                        }
                        modules[row][col - c] = dark
                        bitIndex -= 1
                        if bitIndex == -1 {
                            byteIndex += 1
                            bitIndex = 7
                        }
                    }
                }
                row += inc
                if row < 0 || moduleCount <= row {
                    row -= inc
                    inc = -inc
                    break
                }
            }
            col -= 2
        }
    }

    private static let PAD0: UInt = 0xEC
    private static let PAD1: UInt = 0x11

    private static func createData(
        typeNumber: Int, errorCorrectLevel: QRErrorCorrectLevel, data: QR8bitByte
    ) throws -> [Int] {
        let rsBlocks = errorCorrectLevel.getRSBlocks(ofType: typeNumber)
        var buffer = QRBitBuffer()

        buffer.put(data.mode.rawValue, length: 4)
        guard let length = data.mode.bitCount(ofType: typeNumber) else {
            throw QRCodeError.internalError(.dataLengthIndeterminable)
        }
        buffer.put(UInt(data.count), length: length)
        data.write(to: &buffer)

        let totalBitCount = 8 * rsBlocks.reduce(0) { $0 + $1.dataCount }
        if buffer.bitCount > totalBitCount {
            throw QRCodeError.internalError(
                .dataLength(buffer.bitCount,
                            exceedsCapacityLimit: totalBitCount)
            )
        }
        if buffer.bitCount + 4 <= totalBitCount {
            buffer.put(0, length: 4)
        }
        while buffer.bitCount % 8 != 0 {
            buffer.put(false)
        }
        while true {
            if buffer.bitCount >= totalBitCount {
                break
            }
            buffer.put(QRCodeModel.PAD0, length: 8)
            if buffer.bitCount >= totalBitCount {
                break
            }
            buffer.put(QRCodeModel.PAD1, length: 8)
        }
        return try QRCodeModel.createBytes(fromBuffer: buffer, rsBlocks: rsBlocks)
    }

    private static func createBytes(fromBuffer buffer: QRBitBuffer, rsBlocks: [QRRSBlock]) throws -> [Int] {
        var offset = 0
        var maxDcCount = 0
        var maxEcCount = 0
        // Actual contents will be assigned later
        var dcdata = [[Int]]()
        dcdata.reserveCapacity(rsBlocks.count)
        var ecdata = [[Int]]()
        ecdata.reserveCapacity(rsBlocks.count)
        for r in rsBlocks.indices {
            let dcCount = rsBlocks[r].dataCount
            let ecCount = rsBlocks[r].totalCount - dcCount
            maxDcCount = max(maxDcCount, dcCount)
            maxEcCount = max(maxEcCount, ecCount)
            // Here for `dcdata`
            dcdata.append((0..<dcCount).map {
                Int(0xff & buffer.buffer[$0 + offset])
            })
            offset += dcCount
            let rsPoly = QRPolynomial.errorCorrectPolynomial(ofLength: ecCount)
            let rawPoly = QRPolynomial(dcdata[r], shift: rsPoly.count - 1)
            let modPoly = rawPoly.moded(by: rsPoly)
            // And here for `ecdata`
            let ecdataCount = rsPoly.count - 1
            ecdata.append((0..<ecdataCount).map {
                let modIndex = $0 + modPoly.count - ecdataCount
                return (modIndex >= 0) ? modPoly[modIndex] : 0
            })
        }
        var totalCodeCount = 0
        for i in rsBlocks.indices {
            totalCodeCount += rsBlocks[i].totalCount
        }
        var data = [Int](repeating: 0, count: totalCodeCount)
        var index = 0
        for i in 0..<maxDcCount {
            for r in rsBlocks.indices {
                if i < dcdata[r].count {
                    data[index] = dcdata[r][i]
                    index += 1
                }
            }
        }
        for i in 0..<maxEcCount {
            for r in rsBlocks.indices {
                if i < ecdata[r].count {
                    data[index] = ecdata[r][i]
                    index += 1
                }
            }
        }
        return data
    }
}

extension QRCodeModel {
    private mutating func getBestMaskPattern() -> QRMaskPattern {
        var minLostPoint = 0
        var pattern = 0
        for i in 0..<8 {
            makeImpl(isTest: true, maskPattern: QRMaskPattern(rawValue: i)!)
            let lostPoint = self.lostPoint
            if i == 0 || minLostPoint > lostPoint {
                minLostPoint = lostPoint
                pattern = i
            }
        }
        return QRMaskPattern(rawValue: pattern)!
    }

    var lostPoint: Int {
        // TODO: Remove if needed
        // let moduleCount = self.moduleCount
        var lostPoint = 0
        for row in 0..<moduleCount {
            for col in 0..<moduleCount {
                var sameCount = 0
                let dark = isDark(row, col)
                for r in -1...1 {
                    if row + r < 0 || moduleCount <= row + r {
                        continue
                    }
                    for c in -1...1 {
                        if col + c < 0 || moduleCount <= col + c {
                            continue
                        }
                        if r == 0 && c == 0 {
                            continue
                        }
                        if dark == isDark(row + r, col + c) {
                            sameCount += 1
                        }
                    }
                }
                if sameCount > 5 {
                    lostPoint += (3 + sameCount - 5)
                }
            }
        }
        for row in 0..<moduleCount - 1 {
            for col in 0..<moduleCount - 1 {
                var count = 0
                if isDark(row, col) {
                    count += 1
                }
                if isDark(row + 1, col) {
                    count += 1
                }
                if isDark(row, col + 1) {
                    count += 1
                }
                if isDark(row + 1, col + 1) {
                    count += 1
                }
                if count == 0 || count == 4 {
                    lostPoint += 3
                }
            }
        }
        for row in 0..<moduleCount {
            for col in 0..<moduleCount - 6 {
                if isDark(row, col)
                    && isLight(row, col + 1)
                    && isDark(row, col + 2)
                    && isDark(row, col + 3)
                    && isDark(row, col + 4)
                    && isLight(row, col + 5)
                    && isDark(row, col + 6) {
                    lostPoint += 40
                }
                if isDark(col, row)
                    && isLight(col + 1, row)
                    && isDark(col + 2, row)
                    && isDark(col + 3, row)
                    && isDark(col + 4, row)
                    && isLight(col + 5, row)
                    && isDark(col + 6, row) {
                    lostPoint += 40
                }
            }
        }
        var darkCount = 0
        for col in 0..<moduleCount {
            for row in 0..<moduleCount {
                if isDark(row, col) {
                    darkCount += 1
                }
            }
        }
        let ratio = abs(100 * darkCount / moduleCount / moduleCount - 50) / 5
        lostPoint += ratio * 10
        return lostPoint
    }
}

struct QRCodeType {
    static let QRCodeLimitLength: [[Int]] = [
        [17, 14, 11, 7],
        [32, 26, 20, 14],
        [53, 42, 32, 24],
        [78, 62, 46, 34],
        [106, 84, 60, 44],
        [134, 106, 74, 58],
        [154, 122, 86, 64],
        [192, 152, 108, 84],
        [230, 180, 130, 98],
        [271, 213, 151, 119],
        [321, 251, 177, 137],
        [367, 287, 203, 155],
        [425, 331, 241, 177],
        [458, 362, 258, 194],
        [520, 412, 292, 220],
        [586, 450, 322, 250],
        [644, 504, 364, 280],
        [718, 560, 394, 310],
        [792, 624, 442, 338],
        [858, 666, 482, 382],
        [929, 711, 509, 403],
        [1003, 779, 565, 439],
        [1091, 857, 611, 461],
        [1171, 911, 661, 511],
        [1273, 997, 715, 535],
        [1367, 1059, 751, 593],
        [1465, 1125, 805, 625],
        [1528, 1190, 868, 658],
        [1628, 1264, 908, 698],
        [1732, 1370, 982, 742],
        [1840, 1452, 1030, 790],
        [1952, 1538, 1112, 842],
        [2068, 1628, 1168, 898],
        [2188, 1722, 1228, 958],
        [2303, 1809, 1283, 983],
        [2431, 1911, 1351, 1051],
        [2563, 1989, 1423, 1093],
        [2699, 2099, 1499, 1139],
        [2809, 2213, 1579, 1219],
        [2953, 2331, 1663, 1273]
    ]
}

extension QRCodeType {
    /// Get the type by string length
    static func typeNumber(forLength length: Int,
                           errorCorrectLevel: QRErrorCorrectLevel
    ) throws -> Int {
        for i in QRCodeLimitLength.indices {
            if length <= QRCodeLimitLength[i][errorCorrectLevel.offset] {
                return i + 1
            }
        }

        throw QRCodeError.dataLengthExceedsCapacityLimit
    }
}

public enum QRErrorCorrectLevel: CaseIterable {
    /// Error resilience level:  7%.
    case L
    /// Error resilience level: 15%.
    case M
    /// Error resilience level: 25%.
    case Q
    /// Error resilience level: 30%.
    case H
}

extension QRErrorCorrectLevel {
    var pattern: Int {
        switch self {
        case .L: return 1
        case .M: return 0
        case .Q: return 3
        case .H: return 2
        }
    }

    var offset: Int {
        switch self {
        case .L: return 0
        case .M: return 1
        case .Q: return 2
        case .H: return 3
        }
    }
}

#if canImport(CoreImage)
extension QRErrorCorrectLevel {
    /// Input value for CIFilter.
    public var ciQRCodeGeneratorInputCorrectionLevel: String {
        switch self {
        case .L: return "l"
        case .M: return "m"
        case .Q: return "q"
        case .H: return "h"
        }
    }
}
#endif

enum QRMaskPattern: Int {
    case _000, _001, _010, _011, _100, _101, _110, _111
}

extension QRMaskPattern {
    func getMask(_ i: Int, _ j: Int) -> Bool {
        switch self {
        case ._000:
            return (i + j) % 2 == 0
        case ._001:
            return i % 2 == 0
        case ._010:
            return j % 3 == 0
        case ._011:
            return (i + j) % 3 == 0
        case ._100:
            return (i / 2 + j / 3) % 2 == 0
        case ._101:
            return (i * j) % 2 + (i * j) % 3 == 0
        case ._110:
            return ((i * j) % 2 + (i * j) % 3) % 2 == 0
        case ._111:
            return ((i * j) % 3 + (i + j) % 2) % 2 == 0
        }
    }
}

struct QRMath {
    /// glog
    ///
    /// - Parameter n: n | n >= 1.
    /// - Returns: glog(n), or a fatal error if n < 1.
    static func glog(_ n: Int) -> Int {
        precondition(n > 0, "glog only works with n > 0, not \(n)")
        return QRMath.instance.LOG_TABLE[n]
    }

    static func gexp(_ n: Int) -> Int {
        var n = n
        while n < 0 {
            n += 255
        }
        while n >= 256 {
            n -= 255
        }
        return QRMath.instance.EXP_TABLE[n]
    }

    private var EXP_TABLE: [Int]
    private var LOG_TABLE: [Int]

    private static let instance = QRMath()
    private init() {
        EXP_TABLE = [Int](repeating: 0, count: 256)
        LOG_TABLE = [Int](repeating: 0, count: 256)
        for i in 0..<8 {
            EXP_TABLE[i] = 1 << i
        }
        for i in 8..<256 {
            EXP_TABLE[i] = EXP_TABLE[i - 4] ^ EXP_TABLE[i - 5] ^ EXP_TABLE[i - 6] ^ EXP_TABLE[i - 8]
        }
        for i in 0..<255 {
            LOG_TABLE[EXP_TABLE[i]] = i
        }
    }
}

enum QRMode: UInt {
    /// 1 << 0
    case number      = 0b0001
    /// 1 << 1
    case alphaNumber = 0b0010
    /// 1 << 2
    case bitByte8    = 0b0100
    /// 1 << 3
    case kanji       = 0b1000
}

extension QRMode {
    func bitCount(ofType type: Int) -> Int? {
        if 1 <= type && type < 10 {
            switch self {
            case .number:
                return 10
            case .alphaNumber:
                return 9
            case .bitByte8, .kanji:
                return 8
            }
        } else if type < 27 {
            switch self {
            case .number:
                return 12
            case .alphaNumber:
                return 11
            case .bitByte8:
                return 16
            case .kanji:
                return 10
            }
        } else if type < 41 {
            switch self {
            case .number:
                return 14
            case .alphaNumber:
                return 13
            case .bitByte8:
                return 16
            case .kanji:
                return 12
            }
        } else {
            return nil
        }
    }
}

struct QRPatternLocator {
    private static let PATTERN_POSITION_TABLE: [[Int]] = [
        [],
        [6, 18],
        [6, 22],
        [6, 26],
        [6, 30],
        [6, 34],
        [6, 22, 38],
        [6, 24, 42],
        [6, 26, 46],
        [6, 28, 50],
        [6, 30, 54],
        [6, 32, 58],
        [6, 34, 62],
        [6, 26, 46, 66],
        [6, 26, 48, 70],
        [6, 26, 50, 74],
        [6, 30, 54, 78],
        [6, 30, 56, 82],
        [6, 30, 58, 86],
        [6, 34, 62, 90],
        [6, 28, 50, 72, 94],
        [6, 26, 50, 74, 98],
        [6, 30, 54, 78, 102],
        [6, 28, 54, 80, 106],
        [6, 32, 58, 84, 110],
        [6, 30, 58, 86, 114],
        [6, 34, 62, 90, 118],
        [6, 26, 50, 74, 98, 122],
        [6, 30, 54, 78, 102, 126],
        [6, 26, 52, 78, 104, 130],
        [6, 30, 56, 82, 108, 134],
        [6, 34, 60, 86, 112, 138],
        [6, 30, 58, 86, 114, 142],
        [6, 34, 62, 90, 118, 146],
        [6, 30, 54, 78, 102, 126, 150],
        [6, 24, 50, 76, 102, 128, 154],
        [6, 28, 54, 80, 106, 132, 158],
        [6, 32, 58, 84, 110, 136, 162],
        [6, 26, 54, 82, 110, 138, 166],
        [6, 30, 58, 86, 114, 142, 170]
    ]

    #if swift(<5.1)
    static func getPatternPosition(ofType typeNumber: Int) -> [Int] {
        return PATTERN_POSITION_TABLE[typeNumber - 1]
    }
    #else
    static subscript(typeNumber: Int) -> [Int] {
        return PATTERN_POSITION_TABLE[typeNumber - 1]
    }
    #endif
}

struct QRPolynomial {
    private var numbers: [Int]
    
    init(_ nums: Int..., shift: Int = 0) {
        self.init(nums, shift: shift)
    }
    
    init(_ nums: [Int], shift: Int = 0) {
        precondition(!nums.isEmpty, "polynomial should have at least 1 term")
        var offset = 0
        while offset < nums.count && nums[offset] == 0 {
            offset += 1
        }
        self.numbers = [Int](repeating: 0, count: nums.count - offset + shift)
        for i in 0..<nums.count - offset {
            self.numbers[i] = nums[i + offset]
        }
    }

    subscript(index: Int) -> Int {
        return numbers[index]
    }
    
    var count: Int {
        return numbers.count
    }
    
    func multiplying(_ e: QRPolynomial) -> QRPolynomial {
        var nums = [Int](repeating: 0, count: count + e.count - 1)
        for i in 0..<count {
            for j in 0..<e.count {
                nums[i + j] ^= QRMath.gexp(QRMath.glog(self[i]) + QRMath.glog(e[j]))
            }
        }
        return QRPolynomial(nums)
    }
    
    func moded(by e: QRPolynomial) -> QRPolynomial {
        if count - e.count < 0 {
            return self
        }
        let ratio = QRMath.glog(self[0]) - QRMath.glog(e[0])
        var num = [Int](repeating: 0, count: count)
        for i in 0..<count {
            num[i] = self[i]
        }
        for i in 0..<e.count {
            num[i] ^= QRMath.gexp(QRMath.glog(e[i]) + ratio)
        }
        return QRPolynomial(num).moded(by: e)
    }
    
    static func errorCorrectPolynomial(ofLength errorCorrectLength: Int) -> QRPolynomial {
        var a = QRPolynomial(1)
        for i in 0..<errorCorrectLength {
            a = a.multiplying(QRPolynomial(1, QRMath.gexp(i)))
        }
        return a
    }
}

struct QRRSBlock {
    let totalCount: Int
    let dataCount: Int
}

extension QRRSBlock {
    fileprivate static let RS_BLOCK_TABLE: [[Int]] = [
        [1, 26, 19],
        [1, 26, 16],
        [1, 26, 13],
        [1, 26, 9],
        [1, 44, 34],
        [1, 44, 28],
        [1, 44, 22],
        [1, 44, 16],
        [1, 70, 55],
        [1, 70, 44],
        [2, 35, 17],
        [2, 35, 13],
        [1, 100, 80],
        [2, 50, 32],
        [2, 50, 24],
        [4, 25, 9],
        [1, 134, 108],
        [2, 67, 43],
        [2, 33, 15, 2, 34, 16],
        [2, 33, 11, 2, 34, 12],
        [2, 86, 68],
        [4, 43, 27],
        [4, 43, 19],
        [4, 43, 15],
        [2, 98, 78],
        [4, 49, 31],
        [2, 32, 14, 4, 33, 15],
        [4, 39, 13, 1, 40, 14],
        [2, 121, 97],
        [2, 60, 38, 2, 61, 39],
        [4, 40, 18, 2, 41, 19],
        [4, 40, 14, 2, 41, 15],
        [2, 146, 116],
        [3, 58, 36, 2, 59, 37],
        [4, 36, 16, 4, 37, 17],
        [4, 36, 12, 4, 37, 13],
        [2, 86, 68, 2, 87, 69],
        [4, 69, 43, 1, 70, 44],
        [6, 43, 19, 2, 44, 20],
        [6, 43, 15, 2, 44, 16],
        [4, 101, 81],
        [1, 80, 50, 4, 81, 51],
        [4, 50, 22, 4, 51, 23],
        [3, 36, 12, 8, 37, 13],
        [2, 116, 92, 2, 117, 93],
        [6, 58, 36, 2, 59, 37],
        [4, 46, 20, 6, 47, 21],
        [7, 42, 14, 4, 43, 15],
        [4, 133, 107],
        [8, 59, 37, 1, 60, 38],
        [8, 44, 20, 4, 45, 21],
        [12, 33, 11, 4, 34, 12],
        [3, 145, 115, 1, 146, 116],
        [4, 64, 40, 5, 65, 41],
        [11, 36, 16, 5, 37, 17],
        [11, 36, 12, 5, 37, 13],
        [5, 109, 87, 1, 110, 88],
        [5, 65, 41, 5, 66, 42],
        [5, 54, 24, 7, 55, 25],
        [11, 36, 12, 7, 37, 13],
        [5, 122, 98, 1, 123, 99],
        [7, 73, 45, 3, 74, 46],
        [15, 43, 19, 2, 44, 20],
        [3, 45, 15, 13, 46, 16],
        [1, 135, 107, 5, 136, 108],
        [10, 74, 46, 1, 75, 47],
        [1, 50, 22, 15, 51, 23],
        [2, 42, 14, 17, 43, 15],
        [5, 150, 120, 1, 151, 121],
        [9, 69, 43, 4, 70, 44],
        [17, 50, 22, 1, 51, 23],
        [2, 42, 14, 19, 43, 15],
        [3, 141, 113, 4, 142, 114],
        [3, 70, 44, 11, 71, 45],
        [17, 47, 21, 4, 48, 22],
        [9, 39, 13, 16, 40, 14],
        [3, 135, 107, 5, 136, 108],
        [3, 67, 41, 13, 68, 42],
        [15, 54, 24, 5, 55, 25],
        [15, 43, 15, 10, 44, 16],
        [4, 144, 116, 4, 145, 117],
        [17, 68, 42],
        [17, 50, 22, 6, 51, 23],
        [19, 46, 16, 6, 47, 17],
        [2, 139, 111, 7, 140, 112],
        [17, 74, 46],
        [7, 54, 24, 16, 55, 25],
        [34, 37, 13],
        [4, 151, 121, 5, 152, 122],
        [4, 75, 47, 14, 76, 48],
        [11, 54, 24, 14, 55, 25],
        [16, 45, 15, 14, 46, 16],
        [6, 147, 117, 4, 148, 118],
        [6, 73, 45, 14, 74, 46],
        [11, 54, 24, 16, 55, 25],
        [30, 46, 16, 2, 47, 17],
        [8, 132, 106, 4, 133, 107],
        [8, 75, 47, 13, 76, 48],
        [7, 54, 24, 22, 55, 25],
        [22, 45, 15, 13, 46, 16],
        [10, 142, 114, 2, 143, 115],
        [19, 74, 46, 4, 75, 47],
        [28, 50, 22, 6, 51, 23],
        [33, 46, 16, 4, 47, 17],
        [8, 152, 122, 4, 153, 123],
        [22, 73, 45, 3, 74, 46],
        [8, 53, 23, 26, 54, 24],
        [12, 45, 15, 28, 46, 16],
        [3, 147, 117, 10, 148, 118],
        [3, 73, 45, 23, 74, 46],
        [4, 54, 24, 31, 55, 25],
        [11, 45, 15, 31, 46, 16],
        [7, 146, 116, 7, 147, 117],
        [21, 73, 45, 7, 74, 46],
        [1, 53, 23, 37, 54, 24],
        [19, 45, 15, 26, 46, 16],
        [5, 145, 115, 10, 146, 116],
        [19, 75, 47, 10, 76, 48],
        [15, 54, 24, 25, 55, 25],
        [23, 45, 15, 25, 46, 16],
        [13, 145, 115, 3, 146, 116],
        [2, 74, 46, 29, 75, 47],
        [42, 54, 24, 1, 55, 25],
        [23, 45, 15, 28, 46, 16],
        [17, 145, 115],
        [10, 74, 46, 23, 75, 47],
        [10, 54, 24, 35, 55, 25],
        [19, 45, 15, 35, 46, 16],
        [17, 145, 115, 1, 146, 116],
        [14, 74, 46, 21, 75, 47],
        [29, 54, 24, 19, 55, 25],
        [11, 45, 15, 46, 46, 16],
        [13, 145, 115, 6, 146, 116],
        [14, 74, 46, 23, 75, 47],
        [44, 54, 24, 7, 55, 25],
        [59, 46, 16, 1, 47, 17],
        [12, 151, 121, 7, 152, 122],
        [12, 75, 47, 26, 76, 48],
        [39, 54, 24, 14, 55, 25],
        [22, 45, 15, 41, 46, 16],
        [6, 151, 121, 14, 152, 122],
        [6, 75, 47, 34, 76, 48],
        [46, 54, 24, 10, 55, 25],
        [2, 45, 15, 64, 46, 16],
        [17, 152, 122, 4, 153, 123],
        [29, 74, 46, 14, 75, 47],
        [49, 54, 24, 10, 55, 25],
        [24, 45, 15, 46, 46, 16],
        [4, 152, 122, 18, 153, 123],
        [13, 74, 46, 32, 75, 47],
        [48, 54, 24, 14, 55, 25],
        [42, 45, 15, 32, 46, 16],
        [20, 147, 117, 4, 148, 118],
        [40, 75, 47, 7, 76, 48],
        [43, 54, 24, 22, 55, 25],
        [10, 45, 15, 67, 46, 16],
        [19, 148, 118, 6, 149, 119],
        [18, 75, 47, 31, 76, 48],
        [34, 54, 24, 34, 55, 25],
        [20, 45, 15, 61, 46, 16]
    ]
}

extension QRErrorCorrectLevel {
    func getRSBlocks(ofType typeNumber: Int) -> [QRRSBlock] {
        let rsBlock = getRsBlockTable(ofType: typeNumber)
        let length = rsBlock.count / 3
        
        return (0..<length).flatMap { i -> [QRRSBlock] in
            let count = rsBlock[i * 3 + 0]
            let totalCount = rsBlock[i * 3 + 1]
            let dataCount = rsBlock[i * 3 + 2]
            let block = QRRSBlock(totalCount: totalCount, dataCount: dataCount)
            return [QRRSBlock](repeating: block, count: count)
        }
    }
    
    private func getRsBlockTable(ofType typeNumber: Int) -> [Int] {
        return QRRSBlock.RS_BLOCK_TABLE[(typeNumber - 1) * 4 + offset]
    }
}

// The following function is not part of the original library, it is just an addition to visualize the QRCode in a Image SwiftUI object, so it is not under the same license.

func binaryToImage(bitImage: [[Bool]]) -> UIImage {
    let scale = 4
    let size = CGSize(width: bitImage.count*scale, height: bitImage.count*scale)
    UIGraphicsBeginImageContextWithOptions(size, true, 0);
    for i in 0 ..< bitImage.count {
        for j in 0 ..< bitImage.count {
            if bitImage[i][j] {
                UIColor.white.set()
            }
            else {
                UIColor.black.set()
            }
            UIRectFill(CGRect(x: scale*i, y: scale*j, width: scale, height: scale))
        }
    }
    let imageFinal = UIGraphicsGetImageFromCurrentImageContext();
    return imageFinal!
}

func stringToQR(data: String)->UIImage {
    guard let qrCode = try? QRCode(data) else {
        fatalError("Failed to generate QRCode")
    }
    return binaryToImage(bitImage: qrCode.imageCodes)
}
