// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WordClipKit",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
    ],
    products: [
        .library(name: "WordClipKit", targets: ["WordClipKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", exact: "7.5.0"),
    ],
    targets: [
        .target(
            name: "WordClipKit",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            path: "Sources/WordClipKit",
            resources: [
                // Kit 自带字符串目录：Kit 里的错误文案要用 bundle: .module 取，
                // 否则 swift test 下没有 Bundle.main 的目录可查。
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "WordClipKitTests",
            dependencies: ["WordClipKit"],
            path: "Tests/WordClipKitTests"
        ),
    ]
)
