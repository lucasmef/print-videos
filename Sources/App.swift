import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ResultItem: Identifiable {
    let id = UUID()
    let name: String
    let folder: URL?
    let count: Int
    let seconds: Double
    let error: String?
}
@MainActor final class AppModel: ObservableObject {
    static let shared = AppModel()
    @Published var busy = false
    @Published var fraction = 0.0
    @Published var status = "Pronto para o próximo vídeo."
    @Published var results = [ResultItem]()
    @Published var layout = "auto"
    @Published var hovering = false
    private var cancellation = Cancellation()
    private var pending = [URL]()
    let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
    func choose() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie,.video,.mpeg4Movie,.quickTimeMovie]
        panel.allowsMultipleSelection = true; panel.canChooseDirectories = false
        panel.prompt = "Extrair looks"
        if panel.runModal() == .OK { enqueue(panel.urls) }
    }
    func enqueue(_ urls: [URL]) {
        let videos = urls.filter { ["mov","mp4","m4v","avi","mkv"].contains($0.pathExtension.lowercased()) }
        guard !videos.isEmpty else { status = "Selecione um vídeo MOV ou MP4."; return }
        pending.append(contentsOf: videos)
        if !busy { next() }
    }
    private func next() {
        guard !pending.isEmpty else { busy = false; fraction = 1; status = results.first?.error == nil ? "Concluído. Seus prints estão em Downloads." : "Não foi possível concluir este vídeo. Veja o detalhe abaixo."; return }
        let url = pending.removeFirst()
        busy = true; fraction = 0; cancellation = Cancellation()
        status = "Abrindo \(url.lastPathComponent)…"
        let token = cancellation, output = downloads, region = layout
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let (folder, report) = try LookEngine.extract(url: url, destination: output, layout: region, cancel: token) { value, message in
                    DispatchQueue.main.async { self.fraction = value; self.status = message }
                }
                DispatchQueue.main.async {
                    self.results.insert(ResultItem(name:url.lastPathComponent,folder:folder,count:report.frames.count,seconds:report.elapsedSeconds,error:nil),at:0)
                    self.next()
                }
            } catch {
                let cancelled = (error as? LookError).map { if case .cancelled = $0 { return true }; return false } ?? false
                DispatchQueue.main.async {
                    self.results.insert(ResultItem(name:url.lastPathComponent,folder:nil,count:0,seconds:0,error:error.localizedDescription),at:0)
                    if cancelled { self.busy=false;self.status="Extração cancelada.";self.fraction=0 } else { self.next() }
                }
            }
        }
    }
    func cancel() { pending.removeAll(); cancellation.cancel(); status = "Cancelando…" }
    func reveal(_ folder: URL) { NSWorkspace.shared.open(folder) }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.servicesProvider = self
        NSUpdateDynamicServices()
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    func application(_ sender: NSApplication, open urls: [URL]) {
        Task { @MainActor in AppModel.shared.enqueue(urls); show() }
    }
    @MainActor private func show() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        NSApplication.shared.windows.first(where: { $0.canBecomeMain })?.makeKeyAndOrderFront(nil)
    }
    @objc func extractLooks(_ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        var urls = (pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly:true]) as? [URL]) ?? []
        if urls.isEmpty, let files = pasteboard.propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String] { urls = files.map { URL(fileURLWithPath: $0) } }
        guard !urls.isEmpty else { error.pointee = "Selecione um ou mais vídeos no Finder."; return }
        let files = urls
        Task { @MainActor in AppModel.shared.enqueue(files); show() }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { Task { @MainActor in show() } }; return true
    }
}
struct MainView: View {
    @ObservedObject var model = AppModel.shared
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 14) {
                Image(systemName:"viewfinder").font(.system(size:34,weight:.medium)).foregroundStyle(Color(red:0.73,green:0.35,blue:0.28))
                VStack(alignment:.leading,spacing:4) {
                    Text("LookPrint").font(.system(size:28,weight:.semibold,design:.rounded))
                    Text("O look pronto. No momento certo.").foregroundStyle(.secondary)
                }
                Spacer()
                Text("LOCAL").font(.system(size:10,weight:.semibold)).padding(.horizontal,9).padding(.vertical,5).background(.quaternary,in:Capsule())
            }
            VStack(spacing: 12) {
                Image(systemName: "film.stack").font(.system(size:30,weight:.light)).foregroundStyle(.secondary)
                Text("Arraste seus vídeos aqui").font(.title3.weight(.medium))
                Text("Uma foto por composição completa, com os acessórios.").font(.callout).foregroundStyle(.secondary)
                Button("Escolher vídeos…") { model.choose() }.controlSize(.large).buttonStyle(.borderedProminent).tint(Color(red:0.64,green:0.30,blue:0.24))
                Text("MOV e MP4 • JPG em resolução original • até 2 minutos").font(.caption).foregroundStyle(.secondary)
            }.frame(maxWidth:.infinity).padding(26)
                .background(model.hovering ? Color.accentColor.opacity(0.1) : Color.primary.opacity(0.025),in:RoundedRectangle(cornerRadius:16))
                .overlay(RoundedRectangle(cornerRadius:16).strokeBorder(.secondary.opacity(0.3),style:StrokeStyle(lineWidth:1,dash:[5])))
                .onDrop(of:[UTType.fileURL.identifier],isTargeted:$model.hovering) { providers in
                    for p in providers { _ = p.loadObject(ofClass: URL.self) { url, _ in if let url { Task { @MainActor in model.enqueue([url]) } } } }
                    return true
                }
            HStack {
                Text("Área dos looks").foregroundStyle(.secondary)
                Picker("Área dos looks",selection:$model.layout) {
                    Text("Automático").tag("auto")
                    Text("À esquerda").tag("left")
                    Text("No alto / dois lados").tag("top")
                }.labelsHidden().frame(width:205).disabled(model.busy)
                Spacer()
            }
            if model.busy {
                VStack(alignment:.leading,spacing:9) {
                    ProgressView(value:model.fraction)
                    HStack { Text(model.status).font(.callout);Spacer();Button("Cancelar"){model.cancel()} }
                }
            } else { Text(model.status).font(.callout).foregroundStyle(.secondary) }
            if !model.results.isEmpty {
                ScrollView {
                    LazyVStack(spacing:10) {
                        ForEach(model.results) { result in
                            HStack {
                                Image(systemName:result.error == nil ? "checkmark.circle.fill" : "exclamationmark.circle").foregroundStyle(result.error == nil ? Color.green : Color.orange)
                                VStack(alignment:.leading,spacing:3) {
                                    Text(result.name).fontWeight(.medium)
                                    if let error = result.error { Text(error).foregroundStyle(.secondary).font(.caption).textSelection(.enabled) }
                                    else { Text("\(result.count) prints • \(String(format:"%.1f",result.seconds)) s").font(.caption).foregroundStyle(.secondary) }
                                }
                                Spacer()
                                if let folder = result.folder { Button("Ver prints") { model.reveal(folder) } }
                            }.padding(12).background(.quaternary.opacity(0.5),in:RoundedRectangle(cornerRadius:10))
                        }
                    }
                }.frame(maxHeight:180)
            }
            Spacer(minLength:0)
            VStack(alignment:.leading,spacing:6) {
                Text("No Finder: botão direito → Serviços → Extrair looks completos").font(.callout)
                Text("Feito para vídeos com peças sobrepostas, como os seus exemplos. A seleção é automática; confira o resultado em edições diferentes. O quadro inteiro é preservado, incluindo a apresentadora e as legendas.").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
            }
        }.padding(28).frame(minWidth:560,idealWidth:610,minHeight:590)
    }
}
@main struct LookPrintApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene {
        Window("LookPrint",id:"main") { MainView() }.defaultSize(width:610,height:650)
            .commands { CommandGroup(replacing:.newItem) { Button("Escolher vídeos…") { AppModel.shared.choose() }.keyboardShortcut("o") } }
    }
}
