// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BackupCadence",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "BackupCadenceCore", targets: ["BackupCadenceCore"]),
        .executable(name: "backupcadence-agent", targets: ["backupcadence-agent"]),
        .executable(name: "BackupCadence", targets: ["BackupCadence"]),
    ],
    targets: [
        .target(name: "BackupCadenceCore"),
        .executableTarget(name: "backupcadence-agent", dependencies: ["BackupCadenceCore"]),
        .executableTarget(name: "BackupCadence", dependencies: ["BackupCadenceCore"]),
        .testTarget(name: "BackupCadenceCoreTests", dependencies: ["BackupCadenceCore"]),
    ]
)
