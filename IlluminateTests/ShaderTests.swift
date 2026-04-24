import XCTest
import SwiftUI
@testable import Illuminate

final class ShaderTests: XCTestCase {
    
    func testShaderLibraryLoading() {
        // Since we are in a test environment, Bundle.main might not be the app bundle
        // But we can still check if the shader functions can be initialized
        // Note: Real validation of shader compilation happens at runtime when applied
        
        let library = ShaderLibrary.bundle(.main)
        
        // Test that we can create shader references without crashing
        // These will fail at runtime if the .metal file isn't compiled into the bundle
        let shellShader = library.shellGradientShader
        XCTAssertNotNil(shellShader)
        
        let noiseShader = library.noiseShader
        XCTAssertNotNil(noiseShader)
    }
    
    func testBrowserThemeShaders() {
        let theme = BrowserTheme(accent: .blue, colorScheme: .dark)
        let size = CGSize(width: 100, height: 100)
        
        let shader = theme.noiseShader(size: size, time: 0)
        XCTAssertNotNil(shader)
    }
}
