//
//  ContentView.swift
//  Shared
//
//  Created by Til Blechschmidt on 18.12.20.
//

import SwiftUI

import Metal

let tracer = try! LightTracer()
let renderer = try! LightRenderer(commandQueue: tracer.commandQueue)

struct ContentView: View {
    var body: some View {
        Text("Hello world!")
            .padding()
            .onAppear(perform: testing)
//        Renderer()
//            .edgesIgnoringSafeArea(.all)
    }

    func testing() {
        print("Hello world!")

        let captureManager = MTLCaptureManager.shared()
        let captureDescriptor = MTLCaptureDescriptor()
        captureDescriptor.captureObject = MTLCreateSystemDefaultDevice()!
        try! captureManager.startCapture(with: captureDescriptor)

        try! tracer.run()
        renderer.run(data: tracer.rayData)
        
        captureManager.stopCapture()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
