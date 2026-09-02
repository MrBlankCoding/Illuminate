//
//  FindViewModelStateTests.swift
//  IlluminateTests
//
//  Created by MrBlankCoding on 9/2/26.
//

import Testing
@testable import Illuminate

@MainActor
struct FindViewModelStateTests {
    @Test func findNextAndPreviousWithoutWebViewRemainSafe() {
        let viewModel = FindViewModel()
        viewModel.searchText = "needle"

        viewModel.findNext()
        viewModel.findPrevious()

        #expect(viewModel.totalMatches == 0)
        #expect(viewModel.currentMatchIndex == 0)
    }

    @Test func dismissResetsPresentationAndMatchState() {
        let viewModel = FindViewModel()
        viewModel.isPresented = true
        viewModel.searchText = "needle"
        viewModel.matchFound = true

        viewModel.dismiss()

        #expect(!viewModel.isPresented)
        #expect(viewModel.searchText.isEmpty)
        #expect(!viewModel.matchFound)
        #expect(viewModel.totalMatches == 0)
        #expect(viewModel.currentMatchIndex == 0)
    }

    @Test func settingWebViewToNilClearsTheSearchTargetWithoutChangingQuery() {
        let viewModel = FindViewModel()
        viewModel.searchText = "needle"

        viewModel.setWebView(nil)

        #expect(viewModel.searchText == "needle")
        #expect(viewModel.totalMatches == 0)
    }
}
