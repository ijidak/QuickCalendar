import Foundation

private func bigEndianBytes(_ value: UInt32) -> [UInt8] {
    let value = value.bigEndian
    return withUnsafeBytes(of: value) { Array($0) }
}

private func appendChunk(type: String, pngPath: String, to output: inout Data) throws {
    let png = try Data(contentsOf: URL(fileURLWithPath: pngPath))
    output.append(type.data(using: .ascii)!)
    output.append(contentsOf: bigEndianBytes(UInt32(png.count + 8)))
    output.append(png)
}

let iconsetDirectory = CommandLine.arguments[1]
let outputPath = CommandLine.arguments[2]
let chunks = [
    ("icp4", "icon_16x16.png"),
    ("icp5", "icon_32x32.png"),
    ("icp6", "icon_32x32@2x.png"),
    ("ic07", "icon_128x128.png"),
    ("ic08", "icon_256x256.png"),
    ("ic09", "icon_512x512.png"),
    ("ic10", "icon_512x512@2x.png")
]

var body = Data()
for (type, filename) in chunks {
    try appendChunk(type: type, pngPath: iconsetDirectory + "/" + filename, to: &body)
}

var file = Data("icns".utf8)
file.append(contentsOf: bigEndianBytes(UInt32(body.count + 8)))
file.append(body)
try file.write(to: URL(fileURLWithPath: outputPath))
