import SwiftUI
struct NFCSetupView:View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var nfc=NFCService()
    var body:some View {if !store.pro && !store.demo {PaywallView()} else {NavigationStack{VStack(alignment:.leading,spacing:24){Image(systemName:"wave.3.right").font(.system(size:52)).foregroundStyle(Palette.accent);Text("A small tap.\nA lasting connection.").font(.largeTitle.bold());Text("1. Select the card you want to share.\n2. Prepare a compatible writable NDEF tag.\n3. Hold the top of your iPhone near the tag.\n4. Keep it in place while TapLead writes and verifies the link.\n5. Test your card with another phone.").lineSpacing(8);if !nfc.message.isEmpty{Text(verbatim:nfc.message).font(.subheadline)};if let card=store.selectedCard,card.published,let base=store.api.base{PrimaryButton(title:"Write my profile link",icon:"wave.3.right"){nfc.write(card.profileURL(base:base,source:"nfc"))}.disabled(!nfc.available || nfc.writing)}else{Text("Publish a card before setting up NFC.").foregroundStyle(.secondary)};Text("This writes a URL to a physical tag. Your QR code remains available on every supported iPhone.").font(.caption).foregroundStyle(.secondary);Spacer()}.padding(28).navigationTitle("Set up NFC card").toolbar{ToolbarItem(placement:.cancellationAction){Button("Done"){dismiss()}}}}}}
}
