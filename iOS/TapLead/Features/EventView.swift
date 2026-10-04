import SwiftUI

struct EventView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var exchange=false
    @State private var exports=false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing:22) {
                    if store.demo {DemoBanner()}
                    if let card=store.selectedCard {
                        if store.cards.count>1 {Picker("Card persona",selection:Binding(get:{card.id},set:{id in if let selected=store.cards.first(where:{$0.id==id}){store.select(selected)}})){ForEach(store.cards){Text(verbatim:$0.persona).tag($0.id)}}}
                        Avatar(name:card.name,data:card.photoData,size:86)
                        Text(card.name.isEmpty ? String(localized:"Your TapLead") : card.name).font(.system(.largeTitle,design:.rounded,weight:.bold))
                        Text(verbatim:card.headline).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        if card.published,let base=store.api.base {
                            let url=card.profileURL(base:base,source:"qr")
                            QRView(value:url.absoluteString).frame(maxWidth:300)
                            Text("Scan to connect").font(.title2.bold())
                            Text("No app needed. Just a good introduction.").font(.caption).foregroundStyle(.secondary)
                            ShareLink(item:url){Label("Share link",systemImage:"square.and.arrow.up")}
                            if let image=QRCode.image(url.absoluteString) { ShareLink(item:Image(uiImage:image),preview:SharePreview("TapLead QR",image:Image(uiImage:image))){Label("Share or save QR image",systemImage:"photo")} }
                            if store.pro || store.demo {Button{exports=true}label:{Label("Branded QR & printable exports",systemImage:"printer")}}
                        } else {
                            Image(systemName:"qrcode").font(.system(size:100,weight:.light)).foregroundStyle(.tertiary).padding(30)
                            Text("Publish your card to share a live QR").font(.title2.bold()).multilineTextAlignment(.center)
                            Text("Your profile is still private. You can capture a connection on this iPhone below.").font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        }
                        PrimaryButton(title:"Exchange Details",icon:"person.badge.plus"){exchange=true}
                        Text("Tip: raise your screen brightness for easier scanning.").font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(28)
            }.background(Palette.canvas).navigationTitle("Networking mode").navigationBarTitleDisplayMode(.inline).toolbar{ToolbarItem(placement:.cancellationAction){Button("Done"){dismiss()}}}.sheet(isPresented:$exchange){LeadEditor()}
        }
        .sheet(isPresented:$exports){if let card=store.selectedCard,let base=store.api.base,card.published{QRExportView(card:card,url:card.profileURL(base:base,source:"qr"))}}
    }
}
