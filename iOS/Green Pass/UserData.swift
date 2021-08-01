//
//  UserData.swift
//  C19 Green Card
//
//  Created by Emanuele Laface on 2021-07-02.
//

// Schema from https://ec.europa.eu/health/sites/default/files/ehealth/docs/covid-certificate_json_specification_en.pdf
// and from https://raw.githubusercontent.com/ehn-dcc-development/ehn-dcc-schema/release/1.3.0/DCC.combined-schema.json

// Json support files:
// https://github.com/ehn-dcc-development/ehn-dcc-valuesets


import Foundation

struct Vaccination: Codable {
    var agentTargetted: String = ""
    var vaccine: String = ""
    var medicinalProduct: String = ""
    var manufacturer: String = ""
    var dosesReceived: UInt64 = 0
    var dosesTotal: UInt64 = 0
    var date: String = ""
    var country: String = ""
    var certificateIssuer: String = ""
    var certificateIdentifier: String = ""
}

struct Test: Codable {
    var agentTargetted: String = ""
    var type: String = ""
    var testName: String = ""
    var testDevice: String = ""
    var dateOfCollection: String = ""
    var result: String = ""
    var facility: String = ""
    var country: String = ""
    var certificateIssuer: String = ""
    var certificateIdentifier: String = ""
}

struct Recovery: Codable {
    var agentTargetted: String = ""
    var dateFirstPositive: String = ""
    var country: String = ""
    var certificateIssuer: String = ""
    var certificateValidFrom: String = ""
    var certificateValidUntil: String = ""
    var certificateIdentifier: String = ""
}

struct Person: Codable {
    var familyNames: String = ""
    var familyNamesICAO: String = ""
    var givenNames: String = ""
    var givenNamesICAO: String = ""
}

struct GreenPass: Codable {
    var rawData: String = ""
    var tag: UInt64 = 0
    var issuer: String = ""
    var expiration: UInt64 = 0
    var generated: UInt64 = 0
    var version: String = ""
    var type: String = ""
    var dateOfBirth: String = ""
    var kid: String = ""
    var signature: [UInt8] = []
    var signatureValidity: Bool = false
    var person: Person = Person()
    var vaccination: Vaccination = Vaccination()
    var test: Test = Test()
    var recovery: Recovery = Recovery()
}
