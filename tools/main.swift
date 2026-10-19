import Foundation
let args = Array(CommandLine.arguments.dropFirst())
if args.count < 2 { fputs("Uso: look-cli PASTA-DE-SAIDA VIDEO...\n",stderr); exit(2) }
for path in args.dropFirst() {
 do {
  let (folder,report) = try LookEngine.extract(url:URL(fileURLWithPath:path),destination:URL(fileURLWithPath:args[0]))
  print("\(URL(fileURLWithPath:path).lastPathComponent): \(report.frames.count) imagens em \(String(format:"%.2f",report.elapsedSeconds)) s — \(report.layout)\n\(folder.path)")
  print(report.frames.map{String(format:"%.3f",$0.seconds)}.joined(separator:", "))
 } catch { fputs("\(path): \(error.localizedDescription)\n",stderr);exit(1) }
}
