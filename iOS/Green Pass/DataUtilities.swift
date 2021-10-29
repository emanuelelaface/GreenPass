//
//  DataUtilities.swift
//  C19 Green Card
//
//  Created by Emanuele Laface on 2021-07-02.
//

import Foundation
import Gzip
import SwiftCBOR
import SwiftyJSON
import CryptoKit

func convertData(schema: String, value: String)->String {
    var filename = ""
    switch schema {
    case "tg":
        filename = "ehn-dcc-valuesets-main/disease-agent-targeted"
    case "v/vp":
        filename = "ehn-dcc-valuesets-main/vaccine-prophylaxis"
    case "v/mp":
        filename = "ehn-dcc-valuesets-main/vaccine-medicinal-product"
    case "v/ma":
        filename = "ehn-dcc-valuesets-main/vaccine-mah-manf"
    case "t/ma":
        filename = "ehn-dcc-valuesets-main/test-manf"
    case "co":
        filename = "ehn-dcc-valuesets-main/country-2-codes"
    case "t/tt":
        filename = "ehn-dcc-valuesets-main/test-type"
    case "t/tr":
        filename = "ehn-dcc-valuesets-main/test-result"
    default:
        return value
    }
    if let file = Bundle.main.path(forResource: filename, ofType: "json") {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: file))
            let json = try JSON(data: data)
            return json["valueSetValues"][value]["display"].rawValue as? String ?? value
        } catch {
            return value
        }
    } else {
    return value
    }
}

extension String {
    enum Base45Error: Error {
        case Base64InvalidCharacter
        case Base64InvalidLength
        case DataOverflow
    }
    
    public func fromBase45() throws ->Data  {
        let BASE45_CHARSET = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:"
        var d = Data()
        var o = Data()
        
        for c in self.uppercased() {
            if let at = BASE45_CHARSET.firstIndex(of: c) {
                let idx  = BASE45_CHARSET.distance(from: BASE45_CHARSET.startIndex, to: at)
                d.append(UInt8(idx))
            } else {
                throw Base45Error.Base64InvalidCharacter
            }
        }
        for i in stride(from:0, to:d.count, by: 3) {
            if (d.count - i < 2) {
                throw Base45Error.Base64InvalidLength
            }
            var x : UInt32 = UInt32(d[i]) + UInt32(d[i+1])*45
            if (d.count - i >= 3) {
                x += 45 * 45 * UInt32(d[i+2])
                
                guard x / 256 <= UInt8.max else {
                    throw Base45Error.DataOverflow
                }
                
                o.append(UInt8(x / 256))
            }
            o.append(UInt8(x % 256))
        }
        return o
    }
}

extension String {
    subscript(i: Int) -> String {
        return String(self[index(startIndex, offsetBy: i)])
    }
}

extension String: Error {}

extension StringProtocol {
    var hexaData: Data { .init(hexa) }
    var hexaBytes: [UInt8] { .init(hexa) }
    private var hexa: UnfoldSequence<UInt8, Index> {
        sequence(state: startIndex) { startIndex in
            guard startIndex < self.endIndex else { return nil }
            let endIndex = self.index(startIndex, offsetBy: 2, limitedBy: self.endIndex) ?? self.endIndex
            defer { startIndex = endIndex }
            return UInt8(self[startIndex..<endIndex], radix: 16)
        }
    }
}

extension Data {
    public func toBase45()->String {
        let BASE45_CHARSET = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:"
        var o = String()
        for i in stride(from:0, to:self.count, by: 2) {
            if (self.count - i > 1) {
                let x : Int = (Int(self[i])<<8) + Int(self[i+1])
                let e : Int = x / (45*45)
                let x2 : Int = x % (45*45)
                let d : Int = x2 / 45
                let c : Int = x2 % 45
                o.append(BASE45_CHARSET[c])
                o.append(BASE45_CHARSET[d])
                o.append(BASE45_CHARSET[e])
            } else {
                let x2 : Int = Int(self[i])
                let d : Int = x2 / 45
                let c : Int = x2 % 45
                o.append(BASE45_CHARSET[c])
                o.append(BASE45_CHARSET[d])
            }
        }
        return o
    }
}

func verifySignature(greenpass : GreenPass, digest: SHA256Digest) -> Bool  {
    let revokeFilename = "ehn-dcc-valuesets-main/blacklist_qrcode.json"
    let filename = "ehn-dcc-valuesets-main/pub_keys.json"
    var isValid = false
    if let file = Bundle.main.path(forResource: filename, ofType: "gz") {
        do {
            let gzippedData = try Data(contentsOf: URL(fileURLWithPath: file))
            let data = try gzippedData.gunzipped()
            for case let elem  : Dictionary in try (JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]])! {
                let kid = (elem["kid"] as! String)
                let usage = (elem["usage"] as! [String])
                let algo = (elem["algo"] as! String)
                let country = (elem["country"] as! String)
                var passid = ""
                if (greenpass.kid == kid) && (usage.contains(greenpass.type[0].lowercased())) {
                    switch greenpass.type {
                    case "Vaccine":
                        passid = country+greenpass.vaccination.certificateIdentifier
                    case "Recovery":
                        passid = country+greenpass.recovery.certificateIdentifier
                    case "Test":
                        passid = country+greenpass.test.certificateIdentifier
                    default:
                        return false
                    }
                    let idHash = (SHA256.hash(data: passid.data(using: .utf8) ?? Data()))
                    let passHash = idHash.compactMap { String(format: "%02x", $0) }.joined()
                    
                    if let file = Bundle.main.path(forResource: revokeFilename, ofType: "gz") {
                        do {
                            let gzippedData = try Data(contentsOf: URL(fileURLWithPath: file))
                            let revokeListData = try gzippedData.gunzipped()
                            if let revokeList = try (JSONSerialization.jsonObject(with: revokeListData, options: []) as? [String]) {
                                for invalidPass in revokeList {
                                    if passHash == invalidPass {
                                        return false
                                    }
                                }
                            }
                        }
                        catch {
                            print("Revoke List Error")
                        }
                    }
                    
                    switch algo {
                    case "EC":
                        let x : [UInt8] = (elem["x"] as! [UInt8])
                        let y : [UInt8] = (elem["y"] as! [UInt8])
                        var rawk : [UInt8] = [ 04 ]
                        rawk.append(contentsOf: x)
                        rawk.append(contentsOf: y)
                        if (rawk.count != 1+32+32) {
                            continue;
                        }
                        let pk = try! P256.Signing.PublicKey(x963Representation: rawk)
                        let signatureForData = try! P256.Signing.ECDSASignature.init(rawRepresentation: greenpass.signature)
                        if pk.isValidSignature(signatureForData, for: digest) {
                            isValid = true
                        }
                    case "RSA":
                        isValid = verifyRSA(digest: digest, e: elem["e"] as! [UInt8], n: elem["n"] as! [UInt8], signature: greenpass.signature)
                    default:
                        print("Shouldn't be here")
                    }
                }
            }
        }
        catch {
            print("Pub Key File Error")
        }
    }
    return isValid
}


func processData(data: String)->GreenPass {
    var greenpass = GreenPass()
    greenpass.rawData = data
    let index = greenpass.rawData.index(greenpass.rawData.startIndex, offsetBy: 4)
    let base45Data = String(greenpass.rawData[index...])
    do {
        let gzippedData = try base45Data.fromBase45()
        let QRData = try gzippedData.gunzipped()
        switch try CBOR.decode([UInt8](QRData)) {
        case let .tagged(tag, data):
            greenpass.tag = tag.rawValue
            let protectedHeader = data[0]
            // let headers2 = data[1] // this is empty in all the example that I encountered, probably is the "Unprotected Header"
            let passData = data[2]
            let signature = data[3]
            
            let externalData = CBOR.byteString([])
            let signed_payload : [UInt8] = CBOR.encode(["Signature1", data[0]!, externalData, data[2]!])
            let digest = SHA256.hash(data:signed_payload)
            
            switch protectedHeader {
            case let .byteString(protectedHeaderArray):
                switch try CBOR.decode(protectedHeaderArray) {
                case let.map(protectedHeaderStruct):
                    for item in protectedHeaderStruct {
                        if item.key == 4 {
                            switch item.value {
                            case let .byteString(KID):
                                let data = NSData(bytes: KID, length: KID.count)
                                let base64Data = data.base64EncodedData(options: NSData.Base64EncodingOptions.endLineWithLineFeed)
                                greenpass.kid = String(bytes: base64Data, encoding: .ascii) ?? ""
                            default:
                                print("Shouldn't be here")
                            }
                        }
                    }
                default:
                    print("Shouldn't be here")
                }
            default:
                print("Shouldn't be here")
            }
            switch signature {
            case let .byteString(signatureArray):
                greenpass.signature = signatureArray
            default:
                print("Shouldn't be here")
            }

            switch passData {
            case let .byteString(passDataArray):
                switch try CBOR.decode(passDataArray) {
                case let .map(mainStruct):
                    for item in mainStruct {
                        if item.key == 1 {
                            switch item.value {
                            case let .utf8String(issuer):
                                greenpass.issuer = convertData(schema: "co", value: issuer)
                            default:
                                print("Shouldn't be here")
                            }
                            continue
                        }
                        if item.key == 4 {
                            switch item.value {
                            case let .unsignedInt(expiration):
                                greenpass.expiration = expiration
                            default:
                                print("Shouldn't be here")
                            }
                            continue
                        }
                        if item.key == 6 {
                            switch item.value {
                            case let .unsignedInt(generated):
                                greenpass.generated = generated
                            default:
                                print("Shouldn't be xshere")
                            }
                            continue
                        }
                        switch item.value {
                        case let .map(cards):
                            for card in cards{
                                switch card.value {
                                case let .map(cardData):
                                    for details in cardData{
                                        if details.key == "ver" {
                                            switch details.value {
                                            case let .utf8String(version):
                                                greenpass.version = version
                                            default:
                                                print("Shouldn't be here")
                                            }
                                            continue
                                        }
                                        if details.key == "dob" {
                                            switch details.value {
                                            case let .utf8String(birth):
                                                greenpass.dateOfBirth = birthdayToDate(timestamp: birth)
                                            default:
                                                print("Shouldn't be here")
                                            }
                                            continue
                                        }
                                        if details.key == "nam" {
                                            switch details.value {
                                            case let .map(userData):
                                                for userField in userData {
                                                    if userField.key == "fn" {
                                                        switch userField.value {
                                                        case let .utf8String(userfn):
                                                            greenpass.person.familyNames = userfn
                                                        default:
                                                            print("Shouldn't be here")
                                                        }
                                                        continue
                                                    }
                                                    if userField.key == "fnt" {
                                                        switch userField.value {
                                                        case let .utf8String(userfnt):
                                                            greenpass.person.familyNamesICAO = userfnt
                                                        default:
                                                            print("Shouldn't be here")
                                                        }
                                                        continue
                                                    }
                                                    if userField.key == "gn" {
                                                        switch userField.value {
                                                        case let .utf8String(usergn):
                                                            greenpass.person.givenNames = usergn
                                                        default:
                                                            print("Shouldn't be here")
                                                        }
                                                        continue
                                                    }
                                                    if userField.key == "gnt" {
                                                        switch userField.value {
                                                        case let .utf8String(usergnt):
                                                            greenpass.person.givenNamesICAO = usergnt
                                                        default:
                                                            print("Shouldn't be here")
                                                        }
                                                        continue
                                                    }
                                                }
                                            default:
                                                print("Shouldn't be here")
                                            }
                                            continue
                                        }
                                        if details.key == "v" {
                                            greenpass.type = "Vaccine"
                                            switch details.value {
                                            case let .array(vaccineList):
                                                switch vaccineList[0] {
                                                case let .map(vaccineData):
                                                    for vaccineField in vaccineData {
                                                        if vaccineField.key == "tg" {
                                                            switch vaccineField.value {
                                                            case let .utf8String(vaccinetg):
                                                                greenpass.vaccination.agentTargetted = convertData(schema: "tg", value: vaccinetg)
                                                            default:
                                                                print("Shouldn't be here")
                                                            }
                                                            continue
                                                        }
                                                        if vaccineField.key == "vp" {
                                                            switch vaccineField.value {
                                                            case let .utf8String(vaccinevp):
                                                                greenpass.vaccination.vaccine = convertData(schema: "v/vp", value: vaccinevp)
                                                            default:
                                                                print("Shouldn't be here")
                                                            }
                                                            continue
                                                        }
                                                        if vaccineField.key == "mp" {
                                                            switch vaccineField.value {
                                                            case let .utf8String(vaccinemp):
                                                                greenpass.vaccination.medicinalProduct = convertData(schema: "v/mp", value: vaccinemp)
                                                            default:
                                                                print("Shouldn't be here")
                                                            }
                                                            continue
                                                        }
                                                        if vaccineField.key == "ma" {
                                                            switch vaccineField.value {
                                                            case let .utf8String(vaccinema):
                                                                greenpass.vaccination.manufacturer = convertData(schema: "v/ma", value: vaccinema)
                                                            default:
                                                                print("Shouldn't be here")
                                                            }
                                                            continue
                                                        }
                                                        if vaccineField.key == "dn" {
                                                            switch vaccineField.value {
                                                            case let .unsignedInt(vaccinedn):
                                                                greenpass.vaccination.dosesReceived = vaccinedn
                                                            default:
                                                                print("Shouldn't be here")
                                                            }
                                                            continue
                                                        }
                                                        if vaccineField.key == "sd" {
                                                            switch vaccineField.value {
                                                            case let .unsignedInt(vaccinesd):
                                                                greenpass.vaccination.dosesTotal = vaccinesd
                                                            default:
                                                                print("Shouldn't be here")
                                                            }
                                                            continue
                                                        }
                                                        if vaccineField.key == "dt" {
                                                            switch vaccineField.value {
                                                            case let .utf8String(vaccinedt):
                                                                greenpass.vaccination.date = dateToDate(timestamp: vaccinedt)
                                                            default:
                                                                print("Shouldn't be here")
                                                            }
                                                            continue
                                                        }
                                                        if vaccineField.key == "co" {
                                                            switch vaccineField.value {
                                                            case let .utf8String(vaccineco):
                                                                greenpass.vaccination.country = convertData(schema: "co", value: vaccineco)
                                                            default:
                                                                print("Shouldn't be here")
                                                            }
                                                            continue
                                                        }
                                                        if vaccineField.key == "is" {
                                                            switch vaccineField.value {
                                                            case let .utf8String(vaccineis):
                                                                greenpass.vaccination.certificateIssuer = vaccineis
                                                            default:
                                                                print("Shouldn't be here")
                                                            }
                                                            continue
                                                        }
                                                        if vaccineField.key == "ci" {
                                                            switch vaccineField.value {
                                                            case let .utf8String(vaccineci):
                                                                greenpass.vaccination.certificateIdentifier = vaccineci
                                                            default:
                                                                print("Shouldn't be here")
                                                            }
                                                            continue
                                                        }
                                                    }
                                                default:
                                                    print("Shouldn't be here")
                                                }
                                            default:
                                                print("Shouldn't be here")
                                            }
                                            continue
                                        }
                                        if details.key == "t" {
                                            greenpass.type = "Test"
                                            switch details.value {
                                            case let .array(testList):
                                                switch testList[0] {
                                                case let .map(testData):
                                                    for testField in testData {
                                                        if testField.key == "tg" {
                                                            switch testField.value {
                                                            case let .utf8String(testtg):
                                                                greenpass.test.agentTargetted = convertData(schema: "tg", value: testtg)
                                                            default:
                                                                print("Shouldn't be here")
                                                            }
                                                            continue
                                                        }
                                                        if testField.key == "tt" {
                                                            switch testField.value {
                                                            case let .utf8String(testtt):
                                                                greenpass.test.type = convertData(schema: "t/tt", value: testtt)
                                                            default:
                                                                print("Shouldn't be here")
                                                            }
                                                            continue
                                                        }
                                                        if testField.key == "nm" {
                                                            switch testField.value {
                                                            case let .utf8String(testnm):
                                                                greenpass.test.testName = testnm
                                                            default:
                                                                print("Shouldn't be here")
                                                            }
                                                            continue
                                                        }
                                                        if testField.key == "ma" {
                                                            switch testField.value {
                                                            case let .utf8String(testma):
                                                                greenpass.test.testDevice = convertData(schema: "t/ma", value: testma)
                                                            default:
                                                                print("Shouldn't be here")
                                                            }
                                                            continue
                                                        }
                                                        if testField.key == "sc" {
                                                            switch testField.value {
                                                            case let .utf8String(testsc):
                                                                greenpass.test.dateOfCollection = isoDateToDate(timestamp: testsc)
                                                            default:
                                                                print("Shouldn't be here")
                                                            }
                                                            continue
                                                        }
                                                        if testField.key == "tr" {
                                                            switch testField.value {
                                                            case let .utf8String(testtr):
                                                                greenpass.test.result = convertData(schema: "t/tr", value: testtr)
                                                            default:
                                                                print("Shouldn't be here")
                                                            }
                                                            continue
                                                        }
                                                        if testField.key == "tc" {
                                                            switch testField.value {
                                                            case let .utf8String(testtc):
                                                                greenpass.test.facility = testtc
                                                            default:
                                                                print("Shouldn't be here")
                                                            }
                                                            continue
                                                        }
                                                        if testField.key == "co" {
                                                            switch testField.value {
                                                            case let .utf8String(testco):
                                                                greenpass.test.country = convertData(schema: "co", value: testco)
                                                            default:
                                                                print("Shouldn't be here")
                                                            }
                                                            continue
                                                        }
                                                        if testField.key == "is" {
                                                            switch testField.value {
                                                            case let .utf8String(testis):
                                                                greenpass.test.certificateIssuer = testis
                                                            default:
                                                                print("Shouldn't be here")
                                                            }
                                                            continue
                                                        }
                                                        if testField.key == "ci" {
                                                            switch testField.value {
                                                            case let .utf8String(testci):
                                                                greenpass.test.certificateIdentifier = testci
                                                            default:
                                                                print("Shouldn't be here")
                                                            }
                                                            continue
                                                        }
                                                    }
                                                default:
                                                    print("Shouldn't be here")
                                                }
                                            default:
                                                print("Shouldn't be here")
                                            }
                                            continue
                                        }
                                        if details.key == "r" {
                                            greenpass.type = "Recovery"
                                            switch details.value {
                                            case let .array(recoveryList):
                                                switch recoveryList[0] {
                                                case let .map(recoveryData):
                                                    for recoveryField in recoveryData {
                                                        if recoveryField.key == "tg" {
                                                            switch recoveryField.value {
                                                            case let .utf8String(recoverytg):
                                                                greenpass.recovery.agentTargetted = convertData(schema: "tg", value: recoverytg)
                                                            default:
                                                                print("Shouldn't be here")
                                                            }
                                                            continue
                                                        }
                                                        if recoveryField.key == "fr" {
                                                            switch recoveryField.value {
                                                            case let .utf8String(recoveryfr):
                                                                greenpass.recovery.dateFirstPositive = dateToDate(timestamp: recoveryfr)
                                                            default:
                                                                print("Shouldn't be here")
                                                            }
                                                            continue
                                                        }
                                                        if recoveryField.key == "co" {
                                                            switch recoveryField.value {
                                                            case let .utf8String(recoveryco):
                                                                greenpass.recovery.country = convertData(schema: "co", value: recoveryco)
                                                            default:
                                                                print("Shouldn't be here")
                                                            }
                                                            continue
                                                        }
                                                        if recoveryField.key == "is" {
                                                            switch recoveryField.value {
                                                            case let .utf8String(recoveryis):
                                                                greenpass.recovery.certificateIssuer = recoveryis
                                                            default:
                                                                print("Shouldn't be here")
                                                            }
                                                            continue
                                                        }
                                                        if recoveryField.key == "df" {
                                                            switch recoveryField.value {
                                                            case let .utf8String(recoverydf):
                                                                greenpass.recovery.certificateValidFrom = dateToDate(timestamp: recoverydf)
                                                            default:
                                                                print("Shouldn't be here")
                                                            }
                                                            continue
                                                        }
                                                        if recoveryField.key == "du" {
                                                            switch recoveryField.value {
                                                            case let .utf8String(recoverydu):
                                                                greenpass.recovery.certificateValidUntil = dateToDate(timestamp: recoverydu)
                                                            default:
                                                                print("Shouldn't be here")
                                                            }
                                                            continue
                                                        }
                                                        if recoveryField.key == "ci" {
                                                            switch recoveryField.value {
                                                            case let .utf8String(recoveryci):
                                                                greenpass.recovery.certificateIdentifier = recoveryci
                                                            default:
                                                                print("Shouldn't be here")
                                                            }
                                                            continue
                                                        }
                                                    }
                                                default:
                                                    print("Shouldn't be here")
                                                }
                                            default:
                                                print("Shouldn't be here")
                                            }
                                            continue
                                        }
                                    }
                                default:
                                    print("Shouldn't be here")
                                }
                            }
                        default:
                            print("Shouldn't be here")
                        }
                    }
                default:
                    print("Shouldn't be here")
                }
            greenpass.signatureValidity = verifySignature(greenpass: greenpass, digest: digest)
            default:
                print("Shouldn't be here")
            }
        default:
            print("Shouldn't be here")
        }
    } catch {
        print(error)
    }
    return greenpass
}
