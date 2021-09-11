//
//  RSAUtilities.swift
//  Green Pass
//
//  Created by Emanuele Laface on 2021-09-11.
//

import Foundation
import CryptoKit

func integer_ceil(a: Int, b: Int)->Int {
    var (quanta, mod) = a.quotientAndRemainder(dividingBy: b)
    if mod != 0 {
        quanta += 1
    }
    return quanta
}

func i2osp(x: BInt, x_len: Int)->[UInt8] {
    var chk = BInt(1)
    for _ in 0..<x_len { chk *= BInt(256) }
    if x > chk { return [] }
    let x_bytes = x.asMagnitudeBytes()
    let padding = [UInt8]( repeating: 0, count: x_len - x_bytes.count )
    return padding+x_bytes
}

func verifyRSA(digest: SHA256Digest, e: [UInt8], n: [UInt8], signature: [UInt8])->Bool {
    let mod_bits = MemoryLayout.size(ofValue: n)*n.count
    let m = BInt(magnitude: signature).expMod(BInt(magnitude: e), BInt(magnitude: n))
    let embits = mod_bits - 1
    let em_len = integer_ceil(a: embits, b: 8)
    let em = i2osp(x: m, x_len: em_len)
    let m_hash_class = digest
    var m_hash: [UInt8] = []
    for i in m_hash_class.makeIterator() {
        m_hash.append(i)
    }
    let h_len = m_hash.count
    if em_len < 2*h_len+2 {
        return false
    }
    if em[em.count-1] != 188 {
        return false
    }
    let masked_db = em[0 ..< em_len-h_len-1]
    let h = em[em_len-h_len-1 ..< em.count-1]
    let octets = (8 * em_len - embits) / 8
    let bits = (8*em_len-embits) % 8
    var zero = masked_db[0 ..< octets]
    zero.append(masked_db[octets] & ~(255 >> bits))
    for i in zero {
        if i != 0 {
            return false
        }
    }
    let mask_len = em_len - h_len - 1
    if mask_len > 65536 {
        return false
    }
    var T: [UInt8] = []
    for i in 0..<integer_ceil(a: mask_len, b: h_len) {
        let tmp_hash = SHA256.hash(data:h+i2osp(x:BInt(i), x_len: 4))
        for j in tmp_hash.makeIterator() {
            T.append(j)
        }
    }
    let db_mask = T[0 ..< mask_len]
    var tmp_db: [UInt8] = []
    for i in 0..<masked_db.count {
        tmp_db.append(masked_db[i]^db_mask[i])
    }
    let new_byte = [tmp_db[octets] & 255 >> bits]
    var db: [UInt8] = []
    for _ in 0..<octets {
        db.append(0)
    }
    db += new_byte
    db += tmp_db[octets+1..<tmp_db.count]
    for i in db[0..<em_len-2*h_len-2] {
        if i != 0 {
            return false
        }
    }
    if db[em_len-2*h_len-2] != 1 {
        return false
    }
    let salt = db[db.count-h_len..<db.count]
    let m_prime = [0,0,0,0,0,0,0,0]+m_hash+salt
    let h_prime_hash = SHA256.hash(data:m_prime)
    var h_prime: [UInt8] = []
    for i in h_prime_hash.makeIterator() {
        h_prime.append(i)
    }
    if Array(h) != h_prime {
        return false
    }
    return true
}
