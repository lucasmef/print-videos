import Foundation
import AppKit
import AVFoundation
import Vision
import ImageIO
import UniformTypeIdentifiers

struct ExtractionReport: Codable {
    let source: String
    let duration: Double
    let elapsedSeconds: Double
    let layout: String
    let frames: [SavedFrame]
    let method = "Detecção visual local de composições estáveis; conferir vídeos com outro formato."
}
struct SavedFrame: Codable { let file: String; let seconds: Double; let width: Int; let height: Int }
enum LookError: LocalizedError {
    case invalid(String), cancelled
    var errorDescription: String? {
        switch self { case .invalid(let s): return s; case .cancelled: return "Extração cancelada." }
    }
}
final class Cancellation: @unchecked Sendable {
    private let lock = NSLock(); private var value = false
    func cancel() { lock.lock(); value = true; lock.unlock() }
    func check() throws { lock.lock(); let v = value; lock.unlock(); if v { throw LookError.cancelled } }
}
struct Sample { let time: Double; let pixels: [UInt8] }
struct LookEngine {
    static let width = 180, height = 320, fps = 8.0
    static let pixels = width * height
    static func difference(_ a: [UInt8], _ b: [UInt8], _ p: Int) -> Int {
        let k = p * 4
        return max(abs(Int(a[k])-Int(b[k])), abs(Int(a[k+1])-Int(b[k+1])), abs(Int(a[k+2])-Int(b[k+2])))
    }
    static func bitmap(_ image: CGImage) throws -> [UInt8] {
        var data = [UInt8](repeating: 0, count: pixels * 4)
        let ok = data.withUnsafeMutableBytes { ptr -> Bool in
            guard let c = CGContext(data: ptr.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width*4, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            c.interpolationQuality = .low
            c.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard ok else { throw LookError.invalid("Não foi possível analisar a imagem.") }
        return data
    }
    static func region(face: CGRect?, layout: String) -> ([Bool], String) {
        let isSide = layout == "left" || (layout == "auto" && (face?.midX ?? 0.5) > 0.64)
        let limit = (face?.minX ?? 0.55) > 0.60 ? 0.59 : 0.49
        let mask = (0..<pixels).map { p -> Bool in
            let x = Double(p % width)/Double(width), y = Double(p / width)/Double(height)
            let outer = x > 0.03 && x < 0.97 && y > 0.04 && y < 0.84
            if isSide { return outer && x < limit }
            return outer && y < 0.63 && (y < 0.37 || x < 0.31 || x > 0.73)
        }
        return (mask, isSide ? "looks à esquerda" : "looks no alto e nas laterais")
    }
    static func select(_ samples: [Sample], face: CGRect?, layout: String, cancel: Cancellation) throws -> ([Int], String) {
        let n = samples.count
        guard n >= 12 else { throw LookError.invalid("Vídeo muito curto para identificar a montagem dos looks (mínimo: 1,5 s).") }
        var (mask, description) = region(face: face, layout: layout)
        for p in 0..<pixels where mask[p] {
            var stableCount = 0
            for i in 1..<n { if difference(samples[i].pixels, samples[i-1].pixels, p) < 12 { stableCount += 1 } }
            mask[p] = Double(stableCount)/Double(n-1) > 0.65
        }
        let active = (0..<pixels).filter { mask[$0] }
        guard active.count > 500 else { throw LookError.invalid("Não encontrei uma área estável de looks. Tente outro enquadramento no app.") }
        var scores = [Int](repeating: 0, count: n)
        for i in 4..<(n-4) {
            try cancel.check()
            let a = samples[i-4].pixels, b = samples[i-3].pixels, c = samples[i+3].pixels, d = samples[i+4].pixels
            for p in active {
                if difference(a,b,p) >= 14 || difference(c,d,p) >= 14 { continue }
                let k = p*4
                var diff = 0
                for ch in 0..<3 { diff = max(diff, abs(Int(a[k+ch])+Int(b[k+ch])-Int(c[k+ch])-Int(d[k+ch]))) }
                if diff > 56 { scores[i] += 1 }
            }
        }
        var peaks = [Int]()
        for i in 5..<(n-5) where scores[i] >= 400 && scores[i] >= scores[i-1] && scores[i] >= scores[i+1] {
            let lowLeft = scores[max(4,i-6)..<i].min() ?? 0
            let lowRight = scores[(i+1)..<min(n-4,i+7)].min() ?? 0
            if scores[i] - max(lowLeft,lowRight) > 250 { peaks.append(i) }
        }
        var boundaries = [Int]()
        for i in peaks.sorted(by: { scores[$0] == scores[$1] ? $0 < $1 : scores[$0] > scores[$1] }) {
            if boundaries.allSatisfy({ abs($0-i) >= 6 }) { boundaries.append(i) }
        }
        boundaries.sort(); boundaries.append(n-1)
        // Temporal stability suppresses the presenter, gestures, captions, and moving transitions.
        var stable = [[Bool]](), edges = [[UInt8]](), richness = [Int]()
        for i in 0..<n {
            try cancel.check()
            var s = [Bool](repeating:false,count:pixels), e = [UInt8](repeating:0,count:pixels), rich = 0
            let a = samples[i].pixels
            for p in active {
                var spread = 0
                for ch in 0..<3 {
                    var low = 255, high = 0
                    for j in max(0,i-2)..<min(n,i+3) { let v = Int(samples[j].pixels[p*4+ch]); low = min(low,v); high = max(high,v) }
                    spread = max(spread, high-low)
                }
                s[p] = spread < 20
                let x = p % width, y = p / width
                let up = ((y+height-2)%height)*width+x, left = y*width+(x+width-2)%width
                e[p] = UInt8(max(maxChannel(a,p,up), maxChannel(a,p,left)))
                if s[p] && e[p] > 35 { rich += 1 }
            }
            stable.append(s); edges.append(e); richness.append(rich)
        }
        var candidates = [Int]()
        for b in boundaries {
            let lo = max(0,b-9), hi = max(lo+1,b-1)
            let mx = richness[lo..<hi].max() ?? 0
            if let idx = (lo..<hi).last(where: { Double(richness[$0]) >= Double(mx)*0.96 }), !candidates.contains(idx) { candidates.append(idx) }
        }
        var selected = [Int]()
        for i in candidates {
            try cancel.check()
            var redundant = false
            for j in candidates where i != j && abs(j-i) < 24 {
                var changed=0, loss=0, gain=0, right=0
                for p in active where stable[i][p] && stable[j][p] && difference(samples[i].pixels,samples[j].pixels,p) > 28 {
                    changed += 1
                    if p % width >= Int(Double(width)*0.34) { right += 1 }
                    let e1 = Double(edges[i][p]), e2 = Double(edges[j][p])
                    if e1 > 35 && e2 < e1*0.55 { loss += 1 }
                    if e2 > 35 && e1 < e2*0.55 { gain += 1 }
                }
                let ratio = Double(loss)/Double(max(1,gain))
                let accessoryReplacement = Double(right)/Double(max(1,changed)) > 0.8 && loss > 150 && ratio > 0.2
                let duplicate = changed < 1100 && abs(j-i) < 20 && j > i
                let incomplete = j > i && gain > 180 && ratio < 0.46 && !accessoryReplacement
                if duplicate || incomplete { redundant = true; break }
            }
            if !redundant { selected.append(i) }
        }
        guard !selected.isEmpty else { throw LookError.invalid("Não foi possível separar looks neste vídeo. Tente mudar a área de análise.") }
        return (selected, description)
    }
    static func maxChannel(_ a: [UInt8], _ p: Int, _ q: Int) -> Int {
        max(abs(Int(a[p*4])-Int(a[q*4])),abs(Int(a[p*4+1])-Int(a[q*4+1])),abs(Int(a[p*4+2])-Int(a[q*4+2])))
    }
    static func extract(url: URL, destination: URL, layout: String = "auto", cancel: Cancellation = Cancellation(), progress: @escaping (Double,String)->Void = {_,_ in}) throws -> (URL, ExtractionReport) {
        let started = Date()
        try cancel.check()
        let asset = AVURLAsset(url: url)
        let duration = CMTimeGetSeconds(asset.duration)
        guard duration.isFinite && duration >= 1.5, !asset.tracks(withMediaType: .video).isEmpty else { throw LookError.invalid("O arquivo não contém um vídeo legível de pelo menos 1,5 segundo.") }
        guard duration <= 120 else { throw LookError.invalid("Esta versão aceita vídeos de até 2 minutos. Divida vídeos mais longos para manter a análise leve.") }
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: width, height: height)
        gen.requestedTimeToleranceBefore = .zero; gen.requestedTimeToleranceAfter = .zero
        // SDR avoids washed-out JPEGs from HDR footage; original spatial resolution is retained on export.
        if #available(macOS 15.0, *) { gen.dynamicRangePolicy = .forceSDR }
        var samples = [Sample]()
        let count = Int(duration * fps)
        var faces = [CGRect]()
        for i in 0..<count {
            try cancel.check()
            try autoreleasepool {
                var actual = CMTime.zero
                let im = try gen.copyCGImage(at: CMTime(seconds: Double(i)/fps, preferredTimescale: 600), actualTime: &actual)
                samples.append(Sample(time: CMTimeGetSeconds(actual), pixels: try bitmap(im)))
                if [count/4, count/2, count*3/4].contains(i) {
                    let request = VNDetectFaceRectanglesRequest()
                    try? VNImageRequestHandler(cgImage: im).perform([request])
                    if let box = request.results?.max(by: { $0.boundingBox.width*$0.boundingBox.height < $1.boundingBox.width*$1.boundingBox.height })?.boundingBox { faces.append(box) }
                }
            }
            if i % 8 == 0 { progress(Double(i)/Double(count)*0.75,"Analisando \(url.lastPathComponent)…") }
        }
        progress(0.76,"Separando as composições completas…")
        let detectedFace = faces.sorted(by: { $0.minX < $1.minX }).first
        let (selected, chosenLayout) = try select(samples, face: detectedFace, layout: layout, cancel: cancel)
        try cancel.check()
        let stamp = DateFormatter(); stamp.dateFormat = "yyyy-MM-dd HH-mm-ss"
        let folder = destination.appendingPathComponent("\(url.deletingPathExtension().lastPathComponent) — Looks — \(stamp.string(from: Date())) — \(UUID().uuidString.prefix(4))", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var finished = false
        defer { if !finished { try? FileManager.default.removeItem(at: folder) } }
        gen.maximumSize = .zero
        var frames = [SavedFrame]()
        for (index, s) in selected.enumerated() {
            try cancel.check()
            try autoreleasepool {
                var actual = CMTime.zero
                let im = try gen.copyCGImage(at: CMTime(seconds: samples[s].time, preferredTimescale: 600), actualTime: &actual)
                let seconds = CMTimeGetSeconds(actual)
                let filename = String(format: "look-%02d_%06.2fs.jpg", index+1,seconds)
                guard let writer = CGImageDestinationCreateWithURL(folder.appendingPathComponent(filename) as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else { throw LookError.invalid("Não foi possível criar o JPG em Downloads.") }
                CGImageDestinationAddImage(writer, im, [kCGImageDestinationLossyCompressionQuality:0.95] as CFDictionary)
                guard CGImageDestinationFinalize(writer) else { throw LookError.invalid("Não foi possível salvar a imagem. Verifique o espaço livre e as permissões da pasta.") }
                frames.append(SavedFrame(file: filename, seconds: seconds, width: im.width, height: im.height))
            }
            progress(0.8+Double(index+1)/Double(selected.count)*0.2,"Salvando look \(index+1) de \(selected.count)…")
        }
        let report = ExtractionReport(source: url.path, duration: duration, elapsedSeconds: Date().timeIntervalSince(started), layout: chosenLayout, frames: frames)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted,.sortedKeys]
        try encoder.encode(report).write(to: folder.appendingPathComponent("extracao.json"), options: .atomic)
        finished = true
        return (folder,report)
    }
}
