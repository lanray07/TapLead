import SwiftUI
import UIKit
import PhotosUI
import UniformTypeIdentifiers
import TapLeadCore

struct CardSelection: Identifiable { var card: Card; var id: UUID {card.id} }
struct CardsView: View {
    @Environment(AppStore.self) private var store
    @State private var editing: CardSelection?
    @State private var busy=false
    @State private var nfc=false
    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:24) {
                if store.demo {DemoBanner()}
                Text("One introduction.\nMake it yours.").font(.system(.largeTitle,design:.rounded,weight:.bold))
                if store.cards.count>1 { Picker("Card persona",selection:Binding(get:{store.selectedCard?.id ?? UUID()},set:{id in if let c=store.cards.first(where:{$0.id==id}){store.select(c)}})) {ForEach(store.cards){c in Text(verbatim:c.persona).tag(c.id)}}.pickerStyle(.menu) }
                if let card=store.selectedCard {
                    CardPreview(card:card)
                    HStack { Label(card.published ? "Published" : "On this iPhone",systemImage:card.published ? "globe":"iphone").font(.caption).foregroundStyle(.secondary); Spacer(); Button("Edit card"){editing=CardSelection(card:card)} }
                    PrimaryButton(title:"Show networking QR",icon:"qrcode"){store.showEvent=true}
                    if card.published,let base=store.api.base { ShareLink(item:card.profileURL(base:base)){Label("Share profile link",systemImage:"square.and.arrow.up")}.frame(minHeight:44) }
                    Button {Task {busy=true;defer{busy=false};do{try await store.publish(card)}catch{store.error=error.localizedDescription}} } label:{ Label(card.published ? "Update published card":"Publish my card",systemImage:"globe") }.disabled(busy || card.name.trimmingCharacters(in:.whitespaces).isEmpty)
                    if card.published { Button("Make card private",role:.destructive){Task{do{try await store.unpublish(card)}catch{store.error=error.localizedDescription}}} }
                    Divider()
                    Button {nfc=true} label:{Label("Set up NFC card",systemImage:"wave.3.right")}.frame(minHeight:44)
                    Text("QR codes and NFC tags open your published profile. Recipients don’t need the app. Cached QR codes work offline; opening the website needs internet.").font(.caption).foregroundStyle(.secondary)
                    Label("Apple Wallet needs a signed pass service",systemImage:"wallet.pass").font(.caption).foregroundStyle(.secondary)
                    Text("Publishing includes your selected logo or photo. Choose None to publish without an image.").font(.caption).foregroundStyle(.secondary)
                }
                if store.demo || store.pro { Button("Add card persona"){var c=store.selectedCard ?? Card();c.id=UUID();c.published=false;c.persona="Conference";c.theme = .creator;store.saveCard(c);editing=CardSelection(card:c)} }
            }.padding(22)
        }.background(Palette.canvas).navigationTitle("My card").navigationBarTitleDisplayMode(.inline)
        .sheet(item:$editing){selection in CardEditor(card:selection.card)}.sheet(isPresented:$nfc){NFCSetupView()}
    }
}
struct CardEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var card: Card
    @State private var imageLoading = false
    @State private var socialService="LinkedIn"
    @State private var socialURL=""
    var body: some View {
        NavigationStack {
            Form {
                Section { CardPreview(card:card).listRowInsets(EdgeInsets()) }
                CardImageEditor(card:$card,loading:$imageLoading)
                Section("Identity") {TextField("Card persona",text:$card.persona);TextField("Full name",text:$card.name);TextField("Preferred name",text:$card.preferredName);TextField("Job title",text:$card.title);TextField("Company",text:$card.company);TextField("Professional headline",text:$card.headline);TextField("Short biography",text:$card.bio,axis:.vertical).lineLimit(3...6)}
                Section("Contact details") {TextField("Email",text:$card.email).keyboardType(.emailAddress).textInputAutocapitalization(.never);TextField("Phone",text:$card.phone).keyboardType(.phonePad);TextField("Location",text:$card.location);urlField("Website",value:$card.website);urlField("Portfolio URL",value:$card.portfolio);urlField("Booking URL",value:$card.booking)}
                Section("Social links") { ForEach(card.socials) {link in HStack{Text(verbatim:link.service);Spacer();Text(verbatim:link.url).lineLimit(1).foregroundStyle(.secondary)} }.onDelete{card.socials.remove(atOffsets:$0)}.onMove{card.socials.move(fromOffsets:$0,toOffset:$1)};Picker("Service",selection:$socialService){ForEach(["LinkedIn","Instagram","X","TikTok","YouTube","GitHub","Facebook","Threads"],id:\.self){Text(verbatim:$0)}};urlField("Social URL",value:$socialURL);Button("Add social link"){card.socials.append(SocialLink(service:socialService,url:socialURL));socialURL=""}.disabled(Validation.webURL(socialURL)==nil) }
                Section("Appearance") { Picker("Theme",selection:$card.theme){ForEach(CardTheme.allCases,id:\.self){Text(LocalizedStringKey($0.rawValue)).tag($0)}};TextField("Accent colour (hex)",text:$card.accent).textInputAutocapitalization(.characters).autocorrectionDisabled() }
                Section("Networking mode") {
                    Picker("Mode",selection:Binding(get:{card.mode},set:{card.networkingMode=$0})) { ForEach(NetworkingMode.allCases,id:\.self){Text(LocalizedStringKey($0.rawValue)).tag($0)} }
                    Text("Choose the context yourself. Your mode never changes from inferred personal information.").font(.caption).foregroundStyle(.secondary)
                    if card.mode == .recruiting { urlField("CV URL",value:Binding(get:{card.cv ?? ""},set:{card.cv=$0}));Toggle("Share CV publicly",isOn:Binding(get:{card.isPublic("cv")},set:{enabled in card.publicFields.removeAll{$0=="cv"};if enabled{card.publicFields.append("cv")}})) }
                    if card.mode == .sales { Text("Use a booking or portfolio link for your next conversation.").font(.caption) }
                    if card.mode == .event { Text("Your event card opens in the large QR view for quick introductions.").font(.caption) }
                }
                Section("Advanced appearance · Pro") {
                    if store.pro || store.demo {
                        TextField("Background colour (hex, optional)",text:Binding(get:{card.customBackground ?? ""},set:{card.customBackground=$0.isEmpty ? nil : $0})).textInputAutocapitalization(.characters).autocorrectionDisabled()
                        Picker("Typography",selection:Binding(get:{card.typography ?? .standard},set:{card.typography=$0})) {ForEach(CardTypography.allCases,id:\.self){Text(LocalizedStringKey($0.rawValue)).tag($0)}}
                        Picker("Primary action",selection:Binding(get:{card.action},set:{card.primaryAction=$0})) {ForEach(CardAction.allCases,id:\.self){Text(LocalizedStringKey($0.rawValue)).tag($0)}}
                        TextField("Action label (optional)",text:Binding(get:{card.primaryActionLabel ?? ""},set:{card.primaryActionLabel=$0.isEmpty ? nil : $0})).onChange(of:card.primaryActionLabel){_,value in card.primaryActionLabel=value.map{String($0.prefix(60))}}
                        Text("The public action appears only when its link is valid and shared publicly. Text contrast adjusts to your background.").font(.caption).foregroundStyle(.secondary)
                    } else {Text("Custom backgrounds, typography and primary actions are included with TapLead Pro.").foregroundStyle(.secondary)}
                    Button("Use theme defaults"){card.customBackground=nil;card.typography=nil;card.primaryAction=nil;card.primaryActionLabel=nil}
                }
                Section("Public details") { Text("Your name, company, headline and biography are public when published. Choose which contact details to include.").font(.caption);ForEach(["email","phone","website","location","portfolio","booking","socials"],id:\.self){key in Toggle(LocalizedStringKey(key),isOn:Binding(get:{card.publicFields.contains(key)},set:{enabled in if enabled {card.publicFields.append(key)}else{card.publicFields.removeAll{$0==key}}}))};Toggle("Measure anonymous profile activity",isOn:$card.analyticsEnabled) }
                Section("Section order") {ForEach(card.sectionOrder,id:\.self){Text(LocalizedStringKey($0))}.onMove{card.sectionOrder.move(fromOffsets:$0,toOffset:$1)};Text("Use Edit to reorder sections and social links.").font(.caption).foregroundStyle(.secondary)}
            }.navigationTitle("Edit card").toolbar {ToolbarItem(placement:.cancellationAction){Button("Cancel"){dismiss()}};ToolbarItem(placement:.primaryAction){Button("Save"){store.saveCard(card);dismiss()}.disabled(!valid || imageLoading)};ToolbarItem(placement:.bottomBar){EditButton()}}
        }
    }
    var valid: Bool { !card.name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty && (card.email.isEmpty || Validation.email(card.email)) && [card.website,card.portfolio,card.booking,card.cv ?? ""].allSatisfy{$0.isEmpty || Validation.webURL($0) != nil} && Validation.hexColour(card.accent) && (card.customBackground.map{Validation.hexColour($0)} ?? true) }
    func urlField(_ title: LocalizedStringKey,value:Binding<String>) -> some View { TextField(title,text:value).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled() }
}

struct CardImageEditor: View {
    @Binding var card: Card
    @State private var selection: PhotosPickerItem?
    @State private var importingFile = false
    @Binding var loading: Bool
    @State private var error: String?
    private var hasImage: Bool { card.imageKind == .logo ? card.logoData != nil : card.photoData != nil }

    var body: some View {
        Section("Card image") {
            Picker("Image type",selection:$card.imageKind) {
                ForEach(CardImageKind.allCases,id:\.self) { Text(LocalizedStringKey($0.rawValue)).tag($0) }
            }.pickerStyle(.segmented)
            if card.imageKind != .none {
                PhotosPicker(selection:$selection,matching:.images) {
                    Label(card.imageKind == .logo ? "Choose logo" : "Choose photo",systemImage:card.imageKind == .logo ? "building.2.crop.circle" : "photo")
                }.disabled(loading)
                Button { importingFile = true } label: { Label("Import image from Files",systemImage:"folder") }.disabled(loading)
                Picker("Image corner",selection:$card.imageCorner) {
                    ForEach(CardImageCorner.allCases,id:\.self) { Text(LocalizedStringKey($0.rawValue)).tag($0) }
                }
                if loading { ProgressView("Loading image…") }
                if hasImage {
                    Text(card.imageKind == .logo ? "Logo added" : "Photo added").font(.caption).foregroundStyle(.secondary)
                    Button("Remove image",role:.destructive) {
                        selection=nil
                        if card.imageKind == .logo { card.logoData=nil } else { card.photoData=nil }
                        error=nil
                    }.disabled(loading)
                }
            }
            if let error { Text(verbatim:error).font(.caption).foregroundStyle(.red) }
            Text("Show one logo or photo in your chosen corner. The selected image is uploaded when you publish; other images remain on this iPhone.").font(.caption).foregroundStyle(.secondary)
        }
        .onChange(of:card.imageKind) { _,_ in selection=nil;error=nil }
        .task(id:selection) { await loadPhoto() }
        .fileImporter(isPresented:$importingFile,allowedContentTypes:[.image]) { result in
            do {
                let url=try result.get()
                let access=url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                let size=try url.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0
                guard size <= 20 * 1024 * 1024 else { throw ImageImportError.tooLarge }
                try saveImage(Data(contentsOf:url,options:.mappedIfSafe),kind:card.imageKind)
            } catch { self.error=error.localizedDescription }
        }
    }

    @MainActor private func loadPhoto() async {
        guard let item=selection else { loading=false;return }
        let kind=card.imageKind
        loading=true;error=nil
        defer { if selection == item { loading=false;selection=nil } }
        do {
            guard let data=try await item.loadTransferable(type:Data.self) else { throw ImageImportError.invalid }
            guard !Task.isCancelled,selection == item,card.imageKind == kind else { return }
            try saveImage(data,kind:kind)
        } catch {
            guard !Task.isCancelled,selection == item else { return }
            self.error=error.localizedDescription
        }
    }

    private func saveImage(_ data:Data,kind:CardImageKind) throws {
        guard data.count <= 20 * 1024 * 1024 else { throw ImageImportError.tooLarge }
        guard let image=UIImage(data:data),let thumbnail=image.preparingThumbnail(of:CGSize(width:512,height:512)) else { throw ImageImportError.invalid }
        if kind == .logo {
            guard let encoded=thumbnail.pngData() else { throw ImageImportError.invalid }
            card.logoData=encoded
        } else if kind == .photo {
            guard let encoded=thumbnail.jpegData(compressionQuality:0.85) else { throw ImageImportError.invalid }
            card.photoData=encoded
        }
        error=nil
    }
}

private enum ImageImportError: LocalizedError {
    case invalid,tooLarge
    var errorDescription:String? {
        switch self {
        case .invalid: String(localized:"This image could not be opened. Choose another image.")
        case .tooLarge: String(localized:"Choose an image smaller than 20 MB.")
        }
    }
}
