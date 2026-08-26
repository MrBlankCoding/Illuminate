//
//  ZoomViewModel.swift
//  Illuminate
//
//  Created by MrBlankCoding on 3/11/26.
//

import SwiftUI
import Combine

@MainActor
final class ZoomViewModel: ObservableObject {
    @Published var isPresented = false
    @Published var zoomLevel: Double = 1.0
    
    private var dismissTask: Task<Void, Never>?
    
    func updateZoom(_ level: Double) {
        zoomLevel = level
        show()
    }
    
    func show() {
        dismissTask?.cancel()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isPresented = true
        }
        
        dismissTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            if !Task.isCancelled {
                withAnimation(.easeIn(duration: 0.2)) {
                    isPresented = false
                }
            }
        }
    }
    
    func hide() {
        dismissTask?.cancel()
        withAnimation(.easeIn(duration: 0.2)) {
            isPresented = false
        }
    }
}
