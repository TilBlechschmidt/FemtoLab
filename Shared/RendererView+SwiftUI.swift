//
//  RendererView+SwiftUI.swift
//  FemtoPhoto
//
//  Created by Til Blechschmidt on 18.12.20.
//

import Foundation
import SwiftUI

#if os(macOS)
import Cocoa

typealias ViewRepresentable = NSViewRepresentable
#elseif os(iOS)
import UIKit

typealias ViewRepresentable = UIViewRepresentable
#endif

final class Renderer: ViewRepresentable {
#if os(macOS)
    typealias NSViewType = RendererView

    func makeNSView(context: Context) -> RendererView {
        makeView(context: context)
    }

    func updateNSView(_ view: RendererView, context: Context) {
        // Nothing here yet.
    }
#elseif os(iOS)
    typealias UIViewType = RendererView

    func makeUIView(context: Context) -> RendererView {
        makeView(context: context)
    }

    func updateUIView(_ uiView: RendererView, context: Context) {
        // Nothing here yet.
    }
#endif

    func makeView(context: Context) -> RendererView {
        RendererView()
    }
}
