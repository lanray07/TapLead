import SwiftUI
import UIKit
import PhotosUI
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
                    Text("Photos and logos currently stay on this iPhone. Public image uploads require the configured storage service.").font(.caption).foregroundStyle(.secondary)
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
    @State private var photo: PhotosPickerItem?
    @State private var logo: PhotosPickerItem?
    @State private var socialService="LinkedIn"
    @State private var socialURL=""
    var body: some View {
        NavigationStack {
            Form {
                Section { CardPreview(card:card).listRowInsets(EdgeInsets()); PhotosPicker(selection:$photo,matching:.images){Label("Choose profile photo",systemImage:"person.crop.circle")}; PhotosPicker(selection:$logo,matching:.images){Label("Choose logo",systemImage:"building.2.crop.circle")} }
                Section("Identity") {TextField("Card persona",text:$card.persona);TextField("Full name",text:$card.name);TextField("Preferred name",text:$card.preferredName);TextField("Job title",text:$card.title);TextField("Company",text:$card.company);TextField("Professional headline",text:$card.headline);TextField("Short biography",text:$card.bio,axis:.vertical).lineLimit(3...6)}
                Section("Contact details") {TextField("Email",text:$card.email).keyboardType(.emailAddress).textInputAutocapitalization(.never);TextField("Phone",text:$card.phone).keyboardType(.phonePad);TextField("Location",text:$card.location);urlField("Website",value:$card.website);urlField("Portfolio URL",value:$card.portfolio);urlField("Booking URL",value:$card.booking)}
                Section("Social links") { ForEach(card.socials) {link in HStack{Text(verbatim:link.service);Spacer();Text(verbatim:link.url).lineLimit(1).foregroundStyle(.secondary)} }.onDelete{card.socials.remove(atOffsets:$0)}.onMove{card.socials.move(fromOffsets:$0,toOffset:$1)};Picker("Service",selection:$socialService){ForEach(["LinkedIn","Instagram","X","TikTok","YouTube","GitHub","Facebook","Threads"],id:\.self){Text(verbatim:$0)}};urlField("Social URL",value:$socialURL);Button("Add social link"){card.socials.append(SocialLink(service:socialService,url:socialURL));socialURL=""}.disabled(Validation.webURL(socialURL)==nil) }
                Section("Appearance") { Picker("Theme",selection:$card.theme){ForEach(CardTheme.allCases,id:\.self){Text(LocalizedStringKey($0.rawValue)).tag($0)}};TextField("Accent colour (hex)",text:$card.accent).textInputAutocapitalization(.characters).autocorrectionDisabled() }
                Section("Public details") { Text("Your name, company, headline and biography are public when published. Choose which contact details to include.").font(.caption);ForEach(["email","phone","website","location","portfolio","booking","socials"],id:\.self){key in Toggle(LocalizedStringKey(key),isOn:Binding(get:{card.publicFields.contains(key)},set:{enabled in if enabled {card.publicFields.append(key)}else{card.publicFields.removeAll{$0==key}}}))};Toggle("Measure anonymous profile activity",isOn:$card.analyticsEnabled) }
                Section("Section order") {ForEach(card.sectionOrder,id:\.self){Text(LocalizedStringKey($0))}.onMove{card.sectionOrder.move(fromOffsets:$0,toOffset:$1)};Text("Use Edit to reorder sections and social links.").font(.caption).foregroundStyle(.secondary)}
            }.navigationTitle("Edit card").toolbar {ToolbarItem(placement:.cancellationAction){Button("Cancel"){dismiss()}};ToolbarItem(placement:.primaryAction){Button("Save"){store.saveCard(card);dismiss()}.disabled(!valid)};ToolbarItem(placement:.bottomBar){EditButton()}}
            .onChange(of:photo){_,item in Task{if let data=try? await item?.loadTransferable(type:Data.self),let image=UIImage(data:data){card.photoData=image.preparingThumbnail(of:CGSize(width:512,height:512))?.jpegData(compressionQuality:0.8)}}}
            .onChange(of:logo){_,item in Task{if let data=try? await item?.loadTransferable(type:Data.self),let image=UIImage(data:data){card.logoData=image.preparingThumbnail(of:CGSize(width:256,height:256))?.pngData()}}}
        }
    }
    var valid: Bool { !card.name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty && (card.email.isEmpty || Validation.email(card.email)) && [card.website,card.portfolio,card.booking].allSatisfy{$0.isEmpty || Validation.webURL($0) != nil} && card.accent.range(of:"^[0-9A-Fa-f]{6}$",options:.regularExpression) != nil }
    func urlField(_ title: LocalizedStringKey,value:Binding<String>) -> some View { TextField(title,text:value).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled() }
}
