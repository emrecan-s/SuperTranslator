// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SuperTranslator",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "SuperTranslator", targets: ["SuperTranslator"])
    ],
    dependencies: [
        .package(url: "https://github.com/google/generative-ai-swift", from: "0.5.0")
    ],
    targets: [
        .executableTarget(
            name: "SuperTranslator",
            dependencies: [
                .product(name: "GoogleGenerativeAI", package: "generative-ai-swift")
            ],
            path: "Sources/QuickTranslator",
            exclude: [
                "App-Info.plist",
                "App-Entitlements.entitlements"
            ]
        )
    ]
)
