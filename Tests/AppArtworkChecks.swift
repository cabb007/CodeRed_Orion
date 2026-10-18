import Foundation
import UIKit
import SwiftUI

@main
struct AppArtworkChecks: App {
    var body: some Scene {
        WindowGroup {
            Text("Checking habitat artwork…").onAppear {
                DispatchQueue.main.async {
                    Self.checkArtwork()
                    exit(0)
                }
            }
        }
    }

    static func checkArtwork() {
        let bundle = Bundle.main
        guard let emptyURL = bundle.url(forResource: "EmptyFixture", withExtension: "bundle"),
              let emptyBundle = Bundle(url: emptyURL) else {
            preconditionFailure("Artwork fixture bundles could not be opened")
        }
        var checked = Set<String>()
        for habitat in HabitatKind.allCases {
            for condition in HabitatCondition.allCases {
                let name = habitat.asset(for: condition)
                guard let image = GameArtwork.image(named: name, in: bundle),
                      let pixels = image.cgImage else {
                    preconditionFailure("Missing background: \(habitat.title) / \(condition.title): \(name)")
                }
                precondition(pixels.width > 100 && pixels.height > 100)
                precondition(bundle.url(forResource: name, withExtension: "png") != nil)
                checked.insert(name)
            }
            precondition(GameArtwork.image(named: habitat.cleanAsset, in: bundle) != nil,
                         "Habitat shop thumbnail must load")
        }
        for name in ["EcoSpritesPixel", "FriendsAndFood", "HabitatDecor",
                     "GroveExpressions", "OceanExpressions", "SnowExpressions"] {
            precondition(GameArtwork.image(named: name, in: bundle)?.cgImage != nil,
                         "Sprite atlas must load: \(name)")
        }
        let first = GameArtwork.image(named: "GroveThriving", in: bundle)!
        precondition(GameArtwork.image(named: "GroveThriving", in: bundle) === first,
                     "Scene updates should reuse the loaded artwork")
        precondition(GameArtwork.image(named: "GroveThriving", in: emptyBundle) == nil,
                     "Artwork cached for one bundle must not mask another bundle's missing file")
        print("Artwork runtime checks passed: all 12 habitat/condition combinations, \(checked.count) backgrounds, thumbnails, six sprite atlases and bundle-scoped caching.")
        fflush(stdout)
    }
}
