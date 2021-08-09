//
//  ContentView.swift
//  C19 Green Card
//
//  Created by Emanuele Laface on 2021-07-01.
//

import SwiftUI

struct ContentView: View {
    @State private var isShowingScanner = false
    @State private var isLoadingScanner = false
    @State private var loadedPass = false
    @State private var qrdetails = false
    @State private var sendToWatch = true
    @State private var invalidQR = false
    @State private var showAlert = false
    @State private var fontsize: CGFloat = UIScreen.main.bounds.size.width/320*14
    @State private var greenPass = GreenPass()
    @State private var passColor = myGreen
    @State private var signatureColor = Color.black
    @State private var expirationColor = Color.black
    @StateObject var connectivity = Connectivity()
    
    let timer = Timer.publish(every: 1, on: .main, in: .default).autoconnect()

    var body: some View {
        VStack {
            HStack{
                Spacer()
                Text("Digital Green Pass")
                    .font(.custom("Arial-BoldMT", size: 26)).padding(5)
                Spacer()
            }.frame(minWidth:0, maxWidth: .infinity, minHeight:0, maxHeight: 40, alignment: .topLeading)
            .background(passColor)
            Spacer()
            ZStack {
                if loadedPass {
                    VStack{
                        Button(action: {
                            self.qrdetails = true
                        }) {
                            Image(uiImage: generateQRCode(from: greenPass.rawData))
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .padding()
                                .frame(maxWidth: 300, alignment: .center)
                        }
                        .sheet(isPresented: $qrdetails) {
                            VStack {
                                HStack{
                                    Spacer()
                                    Text("Pass Details")
                                        .font(.custom("Arial-BoldMT", size: 26))
                                        .padding(5)
                                    Spacer()
                                }.frame(minWidth:0, maxWidth: .infinity, minHeight:0, maxHeight: 40, alignment: .topLeading)
                                .background(passColor)
                                Spacer()
                                HStack{
                                    Text("Type of Pass:").padding(.horizontal).padding(.vertical,5)
                                        .font(.system(size: fontsize)).padding(5)
                                    Spacer()
                                    Text(greenPass.type).padding(.horizontal).font(.system(size: fontsize)).padding(.vertical,5)
                                }
                                if greenPass.type == "Vaccine" {
                                    HStack{
                                        Text("Agent Targetted:").font(.system(size: fontsize)).padding(.horizontal).padding(.vertical,5)
                                        Spacer()
                                        Text(greenPass.vaccination.agentTargetted).font(.system(size: fontsize)).padding(.horizontal).padding(.vertical,5)
                                    }
                                    HStack{
                                        Text("Vaccine:").font(.system(size: fontsize)).padding(.horizontal).padding(.vertical,5)
                                        Spacer()
                                        Text(greenPass.vaccination.vaccine).font(.system(size: fontsize)).padding(.horizontal).padding(.vertical,5)
                                    }
                                    HStack{
                                        Text("Vaccine ID:").font(.system(size: fontsize)).padding(.horizontal).padding(.vertical,5)
                                        Spacer()
                                        Text(greenPass.vaccination.medicinalProduct).font(.system(size: fontsize)).padding(.horizontal).padding(.vertical,5)
                                    }
                                    HStack{
                                        Text("Manufacturer:").font(.system(size: fontsize)).padding(.horizontal).padding(.vertical,5)
                                        Spacer()
                                        Text(greenPass.vaccination.manufacturer).font(.system(size: fontsize)).padding(.horizontal).padding(.vertical,5)
                                    }
                                    HStack{
                                        Text("Doses received:").font(.system(size: fontsize)).padding(.horizontal).padding(.vertical,5)
                                        Spacer()
                                        Text("\(greenPass.vaccination.dosesReceived) of \(greenPass.vaccination.dosesTotal)").font(.system(size: fontsize)).padding(.horizontal).padding(.vertical,5)
                                    }
                                    HStack{
                                        Text("Date of Vaccination:").font(.system(size: fontsize)).padding(.horizontal).padding(.vertical,5)
                                        Spacer()
                                        Text(greenPass.vaccination.date).font(.system(size: fontsize)).padding(.horizontal).padding(.vertical,5)
                                    }
                                    HStack{
                                        Text("Country of Vaccination:").font(.system(size: fontsize)).padding(.horizontal).padding(.vertical,5)
                                        Spacer()
                                        Text(greenPass.vaccination.country).font(.system(size: fontsize)).padding(.horizontal).padding(.vertical,5)
                                    }
                                    HStack{
                                        Text("Certificate Issuer:").font(.system(size: fontsize)).padding(.horizontal).padding(.vertical,5)
                                        Spacer()
                                        Text(greenPass.vaccination.certificateIssuer).font(.system(size: fontsize)).padding(.horizontal).padding(.vertical,5)
                                    }
                                    HStack{
                                        Text("Certificate Identifier:").font(.system(size: fontsize)).padding(.horizontal).padding(.vertical,5)
                                        Spacer()
                                        Text(greenPass.vaccination.certificateIdentifier).font(.system(size: fontsize)).padding(.horizontal).padding(.vertical,5)
                                    }
                                    Spacer()
                                }
                                if greenPass.type == "Recovery" {
                                    HStack{
                                        Text("Agent Targetted:").font(.system(size: fontsize)).padding(.horizontal).padding(.vertical,5)
                                        Spacer()
                                        Text(greenPass.recovery.agentTargetted).font(.system(size: fontsize)).padding(.horizontal).padding(.vertical,5)
                                    }
                                    HStack{
                                        Text("Date of Positive:").font(.system(size: fontsize)).padding(.horizontal).padding(.vertical,5)
                                        Spacer()
                                        Text(greenPass.recovery.dateFirstPositive).font(.system(size: fontsize)).padding(.horizontal).padding(.vertical,5)
                                    }
                                    HStack{
                                        Text("Country:").font(.system(size: fontsize)).padding(.horizontal).padding(.vertical,5)
                                        Spacer()
                                        Text(greenPass.recovery.country).font(.system(size: fontsize)).padding(.horizontal).padding(.vertical,5)
                                    }
                                    HStack{
                                        Text("Valid From:").font(.system(size: fontsize)).padding(.horizontal).padding(.vertical,5)
                                        Spacer()
                                        Text(greenPass.recovery.certificateValidFrom).font(.system(size: fontsize)).padding(.horizontal).padding(.vertical,5)
                                    }
                                    HStack{
                                        Text("Valid Until:").font(.system(size: fontsize)).padding(.horizontal).padding(.vertical,5)
                                        Spacer()
                                        Text(greenPass.recovery.certificateValidUntil).font(.system(size: fontsize)).padding(.horizontal).padding(.vertical,5)
                                    }
                                    HStack{
                                        Text("Certificate Issuer:").font(.system(size: fontsize)).padding(.horizontal).padding(.vertical,5)
                                        Spacer()
                                        Text(greenPass.recovery.certificateIssuer).font(.system(size: fontsize)).padding(.horizontal).padding(.vertical,5)
                                    }
                                    HStack{
                                        Text("Certificate Identifier:").padding(.horizontal).font(.system(size: fontsize)).padding(.vertical,5)
                                        Spacer()
                                        Text(greenPass.recovery.certificateIdentifier).font(.system(size: fontsize)).padding(.horizontal).padding(.vertical,5)
                                    }
                                    Spacer()
                                }
                                if greenPass.type == "Test" {
                                    VStack {
                                        HStack{
                                            Text("Agent Targetted:").font(.system(size: fontsize)).padding(.horizontal).padding(.vertical,5)
                                            Spacer()
                                            Text(greenPass.test.agentTargetted).font(.system(size: fontsize)).padding(.horizontal).padding(.vertical,5)
                                        }
                                        HStack{
                                            Text("Type of Test:").font(.system(size: fontsize)).padding(.horizontal).padding(.vertical,5)
                                            Spacer()
                                            Text(greenPass.test.type).font(.system(size: fontsize)).padding(.horizontal).padding(.vertical,5)
                                        }
                                        if greenPass.test.testName != "" {
                                            HStack{
                                                Text("Test Name:").font(.system(size: fontsize)).padding(.horizontal).padding(.vertical,5)
                                                Spacer()
                                                Text(greenPass.test.testName).font(.system(size: fontsize)).padding(.horizontal).padding(.vertical,5)
                                            }
                                        }
                                        if greenPass.test.testDevice != "" {
                                            HStack{
                                                Text("Test Device:").font(.system(size: fontsize)).padding(.horizontal).padding(.vertical,5)
                                                Spacer()
                                                Text(greenPass.test.testDevice).font(.system(size: fontsize)).padding(.horizontal).padding(.vertical,5)
                                            }
                                        }
                                        HStack{
                                            Text("Date:").padding(.horizontal).font(.system(size: fontsize)).padding(.vertical,5)
                                            Spacer()
                                            Text(greenPass.test.dateOfCollection).font(.system(size: fontsize)).padding(.horizontal).padding(.vertical,5)
                                        }
                                        HStack{
                                            Text("Result:").font(.system(size: fontsize)).padding(.horizontal).padding(.vertical,5)
                                            Spacer()
                                            Text(greenPass.test.result).font(.system(size: fontsize)).padding(.horizontal).padding(.vertical,5)
                                        }
                                        HStack{
                                            Text("Laboratory:").font(.system(size: fontsize)).padding(.horizontal).padding(.vertical,5)
                                            Spacer()
                                            Text(greenPass.test.facility).font(.system(size: fontsize)).padding(.horizontal).padding(.vertical,5)
                                        }
                                        HStack{
                                            Text("Country:").font(.system(size: fontsize)).padding(.horizontal).padding(.vertical,5)
                                            Spacer()
                                            Text(greenPass.test.country).font(.system(size: fontsize)).padding(.horizontal).padding(.vertical,5)
                                        }
                                        HStack{
                                            Text("Certificate Issuer:").font(.system(size: fontsize)).padding(.horizontal).padding(.vertical,5)
                                            Spacer()
                                            Text(greenPass.test.certificateIssuer).font(.system(size: fontsize)).padding(.horizontal).padding(.vertical,5)
                                        }
                                        HStack{
                                            Text("Certificate Identifier:").font(.system(size: fontsize)).padding(.horizontal).padding(.vertical,5)
                                            Spacer()
                                            Text(greenPass.test.certificateIdentifier).font(.system(size: fontsize)).padding(.horizontal).padding(.vertical,5)
                                        }
                                    }
                                    Spacer()
                                }
                            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                            .background(Color(red: 210/255, green: 210/255, blue: 210/255))
                            .preferredColorScheme(.light)
                        }
                        Spacer()
                        VStack {
                            HStack{
                                Text("Issuer:").font(.system(size: fontsize)).padding(.horizontal).padding(.top,5)
                                Spacer()
                                Text(String(greenPass.issuer)).font(.system(size: fontsize)).padding(.horizontal).padding(.top,5)
                            }
                            HStack{
                                Text("Generated:").font(.system(size: fontsize)).padding(.horizontal).padding(.vertical,2)
                                Spacer()
                                Text(String(epochToDate(timestamp: greenPass.generated))).font(.system(size: fontsize)).padding(.horizontal).padding(.vertical,2)
                            }
                            HStack{
                                Text("Expiration:").font(.system(size: fontsize)).foregroundColor(expirationColor).padding(.horizontal).padding(.bottom,5)
                                Spacer()
                                Text(String(epochToDate(timestamp: greenPass.expiration))).font(.system(size: fontsize)).foregroundColor(expirationColor).padding(.horizontal).padding(.bottom,5)
                            }
                            HStack{
                                Text("Signature:")
                                    .font(.system(size: fontsize)).foregroundColor(signatureColor).padding(.horizontal).padding(.bottom,5)
                                    Spacer()
                                if greenPass.signatureValidity {
                                    Text(String("Valid")).foregroundColor(signatureColor).font(.system(size: fontsize)).padding(.horizontal).padding(.bottom,5)
                                }
                                else {
                                    Text(String("Invalid")).foregroundColor(signatureColor).font(.system(size: fontsize)).padding(.horizontal).padding(.bottom,5)
                                }
                            }
                            Divider()
                            HStack{
                                Text("Surname:").font(.system(size: fontsize)).padding(.horizontal).padding(.top,5)
                                Spacer()
                                Text(greenPass.person.familyNames).font(.system(size: fontsize)).padding(.horizontal).padding(.top,5)
                            }
                            HStack{
                                Text("Name:").padding(.horizontal).font(.system(size: fontsize)).padding(.vertical,2)
                                Spacer()
                                Text(greenPass.person.givenNames).font(.system(size: fontsize)).padding(.horizontal).padding(.vertical,2)
                            }
                            HStack{
                                Text("Date of Birth:").font(.system(size: fontsize)).padding(.horizontal).padding(.bottom,5)
                                Spacer()
                                Text(greenPass.dateOfBirth).font(.system(size: fontsize)).padding(.horizontal).padding(.bottom,5)
                            }
                        }.frame(maxWidth: .infinity, alignment: .center)
                        .background(Color(red: 210/255, green: 210/255, blue: 210/255))
                        .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 0)
                        .padding(.all, 5)
                    }
                }
                else {
                    Image("europe")
                        .resizable()
                        .scaledToFit()
                        .opacity(0.2)
                    Text("Scan your Green Pass")
                }
            }

            Spacer()
            HStack{
                Spacer()
                Button(action: {
                    self.isShowingScanner = true
                }) {
                    Image(systemName: "qrcode.viewfinder")
                        .resizable()
                        .scaledToFit()
                        .padding(5)
                        .foregroundColor(.black)
                }
                .sheet(isPresented: $isShowingScanner,
                       onDismiss: {
                        if self.invalidQR {
                            self.showAlert = true
                            self.invalidQR = false
                        }
                        }) {
                    CodeScannerView(codeTypes: [.qr], simulatedData: simulatedDataTestRapid, completion: self.handleScanQR)
                }
                .alert(isPresented: $showAlert) {
                    Alert( title: Text("Invalid QR Code"),
                           message: Text("The scanned QR Code is not a valid Green Pass."))
                }
                Button(action: {
                    self.isLoadingScanner = true
                }) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .resizable()
                        .scaledToFit()
                        .padding(5)
                        .foregroundColor(.black)
                }
                .sheet(isPresented: $isLoadingScanner,
                       onDismiss: {
                        if self.invalidQR {
                            self.showAlert = true
                            self.invalidQR = false
                        }
                        }) {
                    CodeLoaderView(codeTypes: [.qr], simulatedData: simulatedDataTestRapid, completion: self.handleLoadQR)
                }
                Spacer()
            }.frame(minWidth:0, maxWidth: .infinity, minHeight:0, maxHeight: 40, alignment: .topLeading)
            .background(passColor)
            .onAppear(){
                greenPass = loadPass()
                if greenPass.rawData != "" {
                    loadedPass = true
                }
            }
            .onReceive(timer) { newTime in
                if loadedPass {
                    if (Double(greenPass.expiration)-newTime.timeIntervalSince1970 < 604800) && (Double(greenPass.expiration)-newTime.timeIntervalSince1970 > 0) {
                        expirationColor = myYellow
                        if greenPass.signatureValidity {
                            passColor = myYellow
                            signatureColor = .black
                        }
                        else {
                            signatureColor = myRed
                            passColor = myRed
                        }
                    }
                    if ((Double(greenPass.expiration)-newTime.timeIntervalSince1970) < 0 ) {
                        expirationColor = myRed
                        passColor = myRed
                        if greenPass.signatureValidity {
                            signatureColor = .black
                        }
                        else {
                            signatureColor = myRed
                        }
                    }
                    if ((Double(greenPass.expiration)-newTime.timeIntervalSince1970) > 604800 ) {
                        expirationColor = .black
                        if greenPass.signatureValidity {
                            signatureColor = .black
                            passColor = myGreen
                        }
                        else {
                            signatureColor = myRed
                            passColor = myRed
                        }
                    }
                }
                
                if self.sendToWatch {
                    do {
                        let jsonData = try JSONEncoder().encode(greenPass)
                        let jsonString = String(data: jsonData, encoding: .utf8)!
                        let msg = ["text": jsonString]
                        connectivity.sendMessage(msg)
                    }
                    catch {
                        print("Error")
                    }
                }
                if connectivity.receivedText == "data received" {
                    self.sendToWatch = false
                }
            }
        }.frame(
            minWidth: 0,
            maxWidth: .infinity,
            minHeight: 0,
            maxHeight: .infinity,
            alignment: .topLeading
        )
        .preferredColorScheme(.light)
    }

    private func handleScanQR(result: Result<String, CodeScannerView.ScanError>) {
        self.loadedPass = false
        self.isShowingScanner = false
        switch result {
        case .success(let data):
            if processData(data: data).version != "" {
                savePass(pass: processData(data: data))
                greenPass = loadPass()
                self.loadedPass = true
                connectivity.receivedText = ""
                self.sendToWatch = true
            }
            else {
                if greenPass.rawData != "" {
                    self.invalidQR = true
                    self.loadedPass = true
                }
            }
       case .failure(let error):
           self.invalidQR = true
           self.loadedPass = true
           print("Scanning failed \(error)")
       }
    }
    private func handleLoadQR(result: Result<String, CodeLoaderView.ScanError>) {
        self.loadedPass = false
        self.isLoadingScanner = false
        switch result {
        case .success(let data):
            if processData(data: data).version != "" {
                savePass(pass: processData(data: data))
                greenPass = loadPass()
                self.loadedPass = true
                connectivity.receivedText = ""
                self.sendToWatch = true
            }
            else {
                if greenPass.rawData != "" {
                    self.invalidQR = true
                    self.loadedPass = true
                }
            }
       case .failure(let error):
            self.invalidQR = true
            self.loadedPass = true
           print("Scanning failed \(error)")
       }
    }
}
