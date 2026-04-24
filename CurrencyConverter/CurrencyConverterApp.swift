import SwiftUI

@main
struct CurrencyConverterApp: App {
    @StateObject private var composition = AppComposition()

    var body: some Scene {
        MenuBarExtra("Currency Converter", systemImage: "dollarsign.arrow.circlepath") {
            MenuBarView(viewModel: composition.viewModel)
        }
        .menuBarExtraStyle(.window)
    }
}
