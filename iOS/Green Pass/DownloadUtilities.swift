//
//  DownloadUtilities.swift
//  Green Pass
//
//  Created by Emanuele Laface on 2021-08-23.
//

import Foundation
import SwiftyJSON

let base_url_conversion_tables = "https://raw.githubusercontent.com/ehn-dcc-development/ehn-dcc-valuesets/release/2.0.0/"
let conversion_tables = [ "country-2-codes", "disease-agent-targeted", "vaccine-prophylaxis", "vaccine-medicinal-product", "vaccine-mah-manf", "country-2-codes", "test-type", "test-result", "test-manf" ]
let eu_keys = "https://verifier-api.coronacheck.nl/v4/verifier/public_keys"
let uk_keys = "https://covid-status.service.nhsx.nhs.uk/pubkeys/keys.json"
let revoke_list = "https://raw.githubusercontent.com/rgrunbla/TAC-Files/main/blacklist_qrcode.json"

func requests(address: String, completion: @escaping (Data, Int) -> ())
{
    do {
        let url = URL(string: address)!
        let headers = ["Accept": "application/json"]
        var request = URLRequest(url: url)
        for field in headers.keys {
            request.addValue(headers[field] ?? "", forHTTPHeaderField: field)
        }
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, let response = response as? HTTPURLResponse, error == nil else {
                return
            }
            completion(data, response.statusCode)
        }
        task.resume()
    }
}

func download_conversion_tables() {
    var url = ""
    for table in conversion_tables {
        url = base_url_conversion_tables+table+".json"
        requests(address: url) { data, response in
            if response == 200 {
                do {
                    let jsonData = try JSON(data: data).rawData()
                    let file = Bundle.main.path(forResource: "ehn-dcc-valuesets-main/"+table, ofType: "json")
                    try jsonData.write(to: URL(fileURLWithPath: file!))
                }
                catch {
                    print("Error Downloading File")
                }
            }
            else {
                print("Error Downloading File")
            }
        }
    }
}

func download_revoke_list() {
    requests(address: revoke_list) { data, response in
        if response == 200 {
            do {
                let jsonData = try JSON(data: data).rawData()
                let gzippedData = try jsonData.gzipped()
                let file = Bundle.main.path(forResource: "ehn-dcc-valuesets-main/blacklist_qrcode.json", ofType: "gz")
                try gzippedData.write(to: URL(fileURLWithPath: file!))
            }
            catch {
                print("Error Downloading File")
            }
        }
        else {
            print("Error Downloading File")
        }
    }
}

func download_keys() {
    struct KeyData: Codable {
        var kid: String
        var algo: String
        var usage: [String]
        var country: String
        var x: [Int]? = nil
        var y: [Int]? = nil
        var e: [Int]? = nil
        var n: [Int]? = nil
    }
    
    var keys = [KeyData]()
    
    let group_tasks = DispatchGroup()
    
    group_tasks.enter()
    requests(address: eu_keys) { data, response in
        if response == 200 {
            do {
                let payload = try JSON(data: data)["payload"]
                let eu_keys = try JSON(data: Data(base64Encoded: payload.string!)!)["eu_keys"]
                for key in eu_keys {
                    let kid = key.0
                    let pk = Data(base64Encoded: key.1[0]["subjectPk"].string!)!
                    var usage = key.1[0]["keyUsage"].rawValue as! [String]
                    if usage.count == 0 {
                        usage = ["v", "t", "r"]
                    }
                    let country = key.1[0]["ian"].string!
                    var x = [Int]()
                    var y = [Int]()
                    var e = [Int]()
                    var n = [Int]()
                    var algo = ""
                    if pk.count == 91 {
                        for i in Data(pk[pk.count-64..<pk.count-32]) {
                            x.append(Int(i))
                        }
                        for i in Data(pk[pk.count-32..<pk.count]) {
                            y.append(Int(i))
                        }
                        algo = "EC"
                        keys.append(KeyData(kid: kid, algo: algo, usage: usage, country: country, x: x, y: y))
                    }
                    else {
                        let key_length = pk.count-38
                        for i in Data(pk[pk.count-key_length-5..<pk.count-5]) {
                            n.append(Int(i))
                        }
                        algo = "RSA"
                        e = [1,0,1]
                        keys.append(KeyData(kid: kid, algo: algo, usage: usage, country: country, e: e, n: n))
                    }
                }
            }
            catch {
                print("Error Downloading EU File")
            }
        }
        else {
            print("Error Downloading EU File")
        }
        group_tasks.leave()
    }
    
    group_tasks.enter()
    requests(address: uk_keys) { data, response in
        if response == 200 {
            do {
                let uk_keys = try JSON(data: data)
                for key in uk_keys {
                    let kid = (key.1["kid"]).string!
                    let pk = Data(base64Encoded: key.1["publicKey"].string!)!
                    let usage = ["v", "t", "r"]
                    var x = [Int]()
                    var y = [Int]()
                    var e = [Int]()
                    var n = [Int]()
                    var algo = ""
                    if pk.count == 91 {
                        for i in Data(pk[pk.count-64..<pk.count-32]) {
                            x.append(Int(i))
                        }
                        for i in Data(pk[pk.count-32..<pk.count]) {
                            y.append(Int(i))
                        }
                        algo = "EC"
                        keys.append(KeyData(kid: kid, algo: algo, usage: usage, country: "UK", x: x, y: y))
                    }
                    else {
                        let key_length = pk.count-38
                        for i in Data(pk[pk.count-key_length-5..<pk.count-5]) {
                            n.append(Int(i))
                        }
                        algo = "RSA"
                        e = [1,0,1]
                        keys.append(KeyData(kid: kid, algo: algo, usage: usage, country: "UK", e: e, n: n))
                    }
                }
            }
            catch {
                print("Error Downloading UK File")
            }
        }
        else {
            print("Error Downloading UK File")
        }
        group_tasks.leave()
    }
    
    group_tasks.wait()
    do {
        let jsonData = try JSONEncoder().encode(keys)
        let gzippedData = try jsonData.gzipped()
        let file = Bundle.main.path(forResource: "ehn-dcc-valuesets-main/pub_keys.json", ofType: "gz")
        try gzippedData.write(to: URL(fileURLWithPath: file!))
    }
    catch {
        print("Error convertig keys")
    }
}
