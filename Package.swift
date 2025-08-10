// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CampusLink",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(name: "CampusLink", targets: ["CampusLink"])
    ],
    dependencies: [
        .package(url: "https://github.com/supabase-community/supabase-swift", from: "1.0.0"),
        .package(url: "https://github.com/stripe/stripe-ios", from: "23.0.0")
    ],
    targets: [
        .target(
            name: "CampusLink",
            dependencies: [
                .product(name: "Supabase", package: "supabase-swift"),
                .product(name: "StripePaymentSheet", package: "stripe-ios")
            ],
            path: "CampusLink"
        ),
        .testTarget(
            name: "CampusLinkTests",
            dependencies: ["CampusLink"],
            path: "Tests/CampusLinkTests"
        )
    ]
)
