// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CardioLogKit",
    platforms: [.iOS("26.0"), .macOS(.v15)],
    products: [
        .library(name: "CardioLogCore", targets: ["CardioLogCore"]),
        .library(name: "CardioLogPersistence", targets: ["CardioLogPersistence"])
    ],
    dependencies: [.package(url: "https://github.com/groue/GRDB.swift.git", exact: "7.11.1")],
    targets: [
        .target(name: "CardioLogCore", resources: [.process("Resources")]),
        .target(name: "CardioLogPersistence", dependencies: ["CardioLogCore", .product(name: "GRDB", package: "GRDB.swift")]),
        .testTarget(name: "CardioLogCoreTests", dependencies: ["CardioLogCore"]),
        .testTarget(name: "CardioLogPersistenceTests", dependencies: ["CardioLogPersistence"])
    ]
)
