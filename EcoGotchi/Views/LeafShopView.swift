import SwiftUI

struct LeafShopView: View {
    @State private var selectedPack: Int?
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("A few more leaves for your little world.").font(.subheadline)
            ForEach([100, 500, 1_200], id: \.self) { amount in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        PixelSprite(sprite: .leaf, size: 40)
                        Text("\(amount) leaves").font(.headline)
                        Spacer()
                        Button("Buy") { selectedPack = amount }.buttonStyle(PixelButtonStyle())
                    }
                    if selectedPack == amount {
                        Text("Coming soon. No purchase is available and no leaves have been added.")
                            .font(.caption).accessibilityAddTraits(.updatesFrequently)
                    }
                }.padding(14).pixelPanel(Palette.paper, shadow: false)
            }
            Text("Our future plan is to direct 80% of each leaf purchase to organizations supporting preservation, conservation and wildlife reserves. Purchases and donations are coming soon.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
