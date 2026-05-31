import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ZStack {
            LiquidBackdrop()

            VStack(spacing: 14) {
                HeaderView()

                PathPanel(title: "Photo Path",
                          icon: "photo.on.rectangle",
                          path: model.photoPath,
                          action: model.choosePhotoDirectory)

                RunPanel()

                ResultsPanel()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, 14)
            .padding(.vertical, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
