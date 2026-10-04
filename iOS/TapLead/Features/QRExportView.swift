import SwiftUI
import PhotosUI
import TapLeadCore

struct QRExportView:View {
    @Environment(\.dismiss) private var dismiss
    var card:Card
    var url:URL
    @State private var picker:PhotosPickerItem?
    @State private var image:UIImage?
    @State private var photo:UIImage?
    @State private var pdfURL:URL?
    @State private var error:String?
    @State private var loading=false
    var body:some View {
        NavigationStack {ScrollView {VStack(spacing:20) {
            if let image {Image(uiImage:image).resizable().scaledToFit().frame(maxHeight:440).accessibilityLabel("Branded QR preview")}
            PhotosPicker(selection:$picker,matching:.images){Label("Add QR to a picture",systemImage:"photo.badge.plus")}.disabled(loading)
            if photo != nil {Button("Use card colours"){photo=nil;picker=nil;render()}}
            if loading {ProgressView("Loading image…")}
            if let image {
                ShareLink(item:Image(uiImage:image),preview:SharePreview("TapLead branded QR",image:Image(uiImage:image))){Label("Share or save branded QR",systemImage:"square.and.arrow.up")}
                if let pdfURL {ShareLink(item:pdfURL){Label("Share printable PDF",systemImage:"printer")}}
            }
            Text("Scan the exported QR on another phone before printing. The profile needs internet; your saved QR image can be shown offline.").font(.caption).foregroundStyle(.secondary)
            if let error {Text(verbatim:error).foregroundStyle(.secondary)}
        }.padding(24)}.navigationTitle("QR exports").toolbar{ToolbarItem(placement:.cancellationAction){Button("Done"){dismiss()}}}.onAppear{render()}.task(id:picker){await loadPhoto()}}
    }
    @MainActor private func render() {
        guard let rendered=QRExport.image(card:card,url:url,photo:photo) else {error=String(localized:"The QR could not be created. Please try again.");return}
        image=rendered;error=nil
        do {
            let file=URL.temporaryDirectory.appendingPathComponent("TapLead-QR-\(UUID().uuidString).pdf")
            try QRExport.pdf(image:rendered).write(to:file,options:[.atomic,.completeFileProtection])
            pdfURL=file
        } catch {pdfURL=nil;self.error=error.localizedDescription}
    }
    @MainActor private func loadPhoto() async {
        guard let selection=picker else{return};loading=true;defer{loading=false}
        do {
            guard let data=try await selection.loadTransferable(type:Data.self), data.count <= 20*1024*1024,
                  let raw=UIImage(data:data),let thumbnail=raw.preparingThumbnail(of:CGSize(width:1400,height:1400)) else {
                error=String(localized:"Choose a readable image smaller than 20 MB.");return
            }
            guard !Task.isCancelled,selection == picker else{return}
            photo=thumbnail;render()
        } catch {guard !Task.isCancelled else{return};self.error=error.localizedDescription}
    }
}
