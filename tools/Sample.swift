import Foundation
import AVFoundation
import AppKit
let url = URL(fileURLWithPath: CommandLine.arguments[1])
let out = URL(fileURLWithPath: CommandLine.arguments[2])
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
let asset = AVURLAsset(url: url)
let duration = CMTimeGetSeconds(asset.duration)
let generator = AVAssetImageGenerator(asset: asset)
generator.appliesPreferredTrackTransform = true
generator.maximumSize = CGSize(width: 180, height: 320)
generator.requestedTimeToleranceBefore = .zero
generator.requestedTimeToleranceAfter = .zero
for i in 0..<Int(duration * 8) {
 let img = try generator.copyCGImage(at: CMTime(seconds: Double(i)/8, preferredTimescale: 600), actualTime: nil)
 let rep = NSBitmapImageRep(cgImage: img)
 try rep.representation(using: .png, properties: [:])!.write(to: out.appendingPathComponent(String(format: "%04d.png",i)))
}
