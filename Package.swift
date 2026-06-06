// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "wwdcnotes-mcp",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "wwdcnotes-mcp", targets: ["WWDCNotesMCP"]),
    ],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk", from: "0.11.0"),
    ],
    targets: [
        .executableTarget(
            name: "WWDCNotesMCP",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk"),
            ]
        ),
    ]
)
