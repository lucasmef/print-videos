import Foundation
import AVFoundation
import AppKit
guard CommandLine.arguments.count == 3 else {
    fatalError("Uso: inspect PASTA-DE-SAIDA PASTA-DOS-VIDEOS")
}
let base = URL(fileURLWithPath: CommandLine.arguments[2])
let out = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
for name in ["49.mp4", "120.mov", "125.mov", "139.mov", "152.mov", "122-mexido.mov"] {
    let asset = AVURLAsset(url: base.appendingPathComponent(name))
    let duration = CMTimeGetSeconds(asset.duration)
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.maximumSize = CGSize(width: 240, height: 360)
    let dir = out.appendingPathComponent(name)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    print("\(name): \(duration)s \(asset.tracks(withMediaType: .video).first!.naturalSize)")
    for i in 0..<48 {
        let time = duration * (Double(i) + 0.5) / 48
        let img = try generator.copyCGImage(at: CMTime(seconds: time, preferredTimescale: 600), actualTime: nil)
        let rep = NSBitmapImageRep(cgImage: img)
        try rep.representation(using: .jpeg, properties: [.compressionFactor: 0.75])!.write(to: dir.appendingPathComponent(String(format: "%02d_%.2f.jpg", i, time)))
    }
}
