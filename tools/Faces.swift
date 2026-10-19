import AppKit
import Vision
import Foundation
for p in CommandLine.arguments.dropFirst() {
 let im=NSImage(contentsOfFile:p)!.cgImage(forProposedRect:nil,context:nil,hints:nil)!
 let req=VNDetectFaceRectanglesRequest()
 try VNImageRequestHandler(cgImage:im).perform([req])
 print(p, req.results!.map{String(describing:$0.boundingBox)})
}
