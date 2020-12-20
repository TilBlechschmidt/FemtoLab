//
//  ContentView.swift
//  Shared
//
//  Created by Til Blechschmidt on 18.12.20.
//

import SwiftUI

import Metal
let tracer = (try! LightTracer())!

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
        tracer.run()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
