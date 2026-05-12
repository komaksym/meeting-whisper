// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "meeting-whisper",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "meeting-whisper", targets: ["meeting-whisper"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/apple/swift-argument-parser.git",
            from: "1.3.0"
        ),
        .package(
            url: "https://github.com/argmaxinc/argmax-oss-swift.git",
            from: "0.9.0"
        ),
    ],
    targets: [
        .target(
            name: "MeetingWhisperCore",
            dependencies: []
        ),
        .executableTarget(
            name: "meeting-whisper",
            dependencies: [
                "MeetingWhisperCore",
                .product(
                    name: "ArgumentParser",
                    package: "swift-argument-parser"
                ),
                .product(name: "WhisperKit", package: "argmax-oss-swift"),
                .product(name: "SpeakerKit", package: "argmax-oss-swift"),
            ]
        ),
        .executableTarget(
            name: "meeting-whisper-core-tests",
            dependencies: ["MeetingWhisperCore"],
            path: "Sources/MeetingWhisperCoreTests"
        ),
    ]
)
