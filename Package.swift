// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "QingChang", platforms: [.macOS(.v13)], products: [.executable(name: "QingChang", targets: ["QingChang"])], targets: [.target(name: "RealtimeAudio", publicHeadersPath: "include"), .executableTarget(name: "QingChang", dependencies: ["RealtimeAudio"])])
