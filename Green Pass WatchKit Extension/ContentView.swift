//
//  ContentView.swift
//  Green Pass WatchKit Extension
//
//  Created by Emanuele Laface on 2021-07-04.
//

import SwiftUI
import SpriteKit

struct ContentView: View {
    @State private var greenPass = GreenPass()
    @StateObject var connectivity = Connectivity()
    @State private var scene = SKScene()
    
    var body: some View {
        if greenPass.rawData == "" {
            Text("Scan the Green Pass with the iPhone")
                .padding()
                .onReceive(connectivity.$receivedText) {msg in
                    do {
                        let newGreenPass = try JSONDecoder().decode(GreenPass.self, from: msg.data(using: .utf8)!)
                        if newGreenPass.rawData != greenPass.rawData {
                            savePass(pass: newGreenPass)
                            greenPass = loadPass()
                        }
                    }
                    catch {
                        print("Shouldn't be here")
                    }
                }
                .onAppear() {
                    greenPass = loadPass()
                }
        }
        else {
            TabView() {
                SpriteView(scene: scene)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .edgesIgnoringSafeArea(.all)
                    .navigationBarHidden(true)
                    .onAppear() {
                        createImage()
                    }
                VStack{
                    Text(greenPass.issuer)
                    Text(epochToDate(timestamp: greenPass.generated))
                    Text(epochToDate(timestamp: greenPass.expiration))
                    if greenPass.signatureValidity {
                        Text("Signature: Valid")
                    }
                    else {
                        Text("Signature: Invalid")
                    }
                    Divider()
                    Text(greenPass.person.givenNames)
                    Text(greenPass.person.familyNames)
                    Text(greenPass.dateOfBirth)
                }
                VStack {
                    Text(greenPass.type).font(.system(size: 11))
                    if greenPass.type == "Vaccine" {
                        Text(greenPass.vaccination.agentTargetted).font(.system(size: 11))
                        Text(greenPass.vaccination.vaccine).font(.system(size: 11))
                        Text(greenPass.vaccination.medicinalProduct).font(.system(size: 11))
                        Text(greenPass.vaccination.manufacturer).font(.system(size: 11))
                        Text("\(greenPass.vaccination.dosesReceived) of \(greenPass.vaccination.dosesTotal)").font(.system(size: 11))
                        Text(greenPass.vaccination.date).font(.system(size: 11))
                        Text(greenPass.vaccination.country).font(.system(size: 11))
                        Text(greenPass.vaccination.certificateIssuer).font(.system(size: 11))
                        Text(greenPass.vaccination.certificateIdentifier).font(.system(size: 11))
                    }
                    if greenPass.type == "Recovery" {
                        Text(greenPass.recovery.agentTargetted).font(.system(size: 11))
                        Text(greenPass.recovery.dateFirstPositive).font(.system(size: 11))
                        Text(greenPass.recovery.country).font(.system(size: 11))
                        Text(greenPass.recovery.certificateValidFrom).font(.system(size: 11))
                        Text(greenPass.recovery.certificateValidUntil).font(.system(size: 11))
                        Text(greenPass.recovery.certificateIssuer).font(.system(size: 11))
                        Text(greenPass.recovery.certificateIdentifier).font(.system(size: 11))
                    }
                    if greenPass.type == "Test" {
                        VStack {
                            Text(greenPass.test.agentTargetted).font(.system(size: 11))
                            Text(greenPass.test.type).font(.system(size: 11))
                            if greenPass.test.testName != "" {
                                Text(greenPass.test.testName).font(.system(size: 11))
                            }
                            if greenPass.test.testDevice != "" {
                                Text(greenPass.test.testDevice).font(.system(size: 11))
                            }
                            Text(greenPass.test.dateOfCollection).font(.system(size: 11))
                            Text(greenPass.test.result).font(.system(size: 11))
                            Text(greenPass.test.facility).font(.system(size: 11))
                            Text(greenPass.test.country).font(.system(size: 11))
                            Text(greenPass.test.certificateIssuer).font(.system(size: 11))
                            Text(greenPass.test.certificateIdentifier).font(.system(size: 11))
                        }
                    }
                }
            }.onReceive(connectivity.$receivedText) {msg in
                do {
                    let newGreenPass = try JSONDecoder().decode(GreenPass.self, from: msg.data(using: .utf8)!)
                    if newGreenPass.rawData != greenPass.rawData {
                        savePass(pass: newGreenPass)
                        greenPass = loadPass()
                        createImage()
                    }
                }
                catch {
                    print("Shouldn't be here")
                }
            }
        }
    }
    private func createImage() {
        let screenWidth = WKInterfaceDevice.current().screenBounds.size.width*2
        let screenHeight = WKInterfaceDevice.current().screenBounds.size.height*2
        let image = stringToQR(data: greenPass.rawData)
        let node = SKSpriteNode(texture: SKTexture(image: image))
        scene.size = CGSize(width: screenWidth, height: screenHeight)
        node.position = CGPoint(x: screenWidth/2, y: screenHeight/2-10)
        node.size = CGSize(width: screenWidth*0.95, height: screenWidth*0.95)
        scene.addChild(node)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
