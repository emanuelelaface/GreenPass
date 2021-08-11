//
//  LoadSavePass.swift
//  C19 Green Card
//
//  Created by Emanuele Laface on 2021-07-03.
//

import Foundation

func loadPass()->GreenPass {
    do {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let url = paths[0].appendingPathComponent("greenpass")
        let data = try Data(contentsOf: url)
        let greenpass = try JSONDecoder().decode(GreenPass.self, from: data)
        return greenpass
    } catch {
        print("Load failed")
        return GreenPass()
    }
}

func savePass(pass: GreenPass) {
    do {
        let data = try JSONEncoder().encode(pass)
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let url = paths[0].appendingPathComponent("greenpass")
        try data.write(to: url)
    }
    catch {
        print("Save failed")
    }
}

func epochToDate(timestamp: UInt64) -> String {
    let inDate = Date(timeIntervalSince1970: Double(timestamp))

    let outFormat = DateFormatter()
    outFormat.dateFormat = "MMM d, yyyy" // 'at' HH:mm:ss"
    let outDate = outFormat.string(from: inDate)
    return outDate
}

func dateToDate(timestamp: String) -> String {
    let inFormat = DateFormatter()
    inFormat.dateFormat = "yyyy-MM-dd"
    guard let inDate = inFormat.date(from: timestamp)
    else {
        return ""
    }

    let outFormat = DateFormatter()
    outFormat.dateFormat = "MMM d, yyyy"
    let outDate = outFormat.string(from: inDate)
    return outDate
}

func isoDateToDate(timestamp: String) -> String {
    let inFormat = DateFormatter()
    inFormat.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
    guard let inDate = inFormat.date(from: timestamp)
    else {
        return ""
    }

    let outFormat = DateFormatter()
    outFormat.dateFormat = "MMM d, yyyy - HH:mm:ss"
    let outDate = outFormat.string(from: inDate)
    return outDate
}

func birthdayToDate(timestamp: String) -> String {
    let format = (timestamp.components(separatedBy:"-")).count - 1

    switch format {
    case 0:
        return timestamp
    case 1:
        let inFormat = DateFormatter()
        inFormat.dateFormat = "yyyy-MM"
        guard let inDate = inFormat.date(from: timestamp)
        else {
            return ""
        }

        let outFormat = DateFormatter()
        outFormat.dateFormat = "MMM, yyyy"
        let outDate = outFormat.string(from: inDate)
        return outDate
    default:
        let inFormat = DateFormatter()
        inFormat.dateFormat = "yyyy-MM-dd"
        guard let inDate = inFormat.date(from: timestamp)
        else {
            return ""
        }

        let outFormat = DateFormatter()
        outFormat.dateFormat = "MMM d, yyyy"
        let outDate = outFormat.string(from: inDate)
        return outDate
    }
    
}
