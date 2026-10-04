import SwiftUI
import UIKit
import StoreKit

struct SettingsView:View {
    @Environment(AppStore.self) private var store
    @State private var auth=false
    @State private var paywall=false
    @State private var deleting=false
    @State private var exportURL:URL?
    var body:some View {
        Form {
            if store.demo{Section{DemoBanner()}}
            Section("Your account") {if store.authenticated{Button("Sign out"){Task{await store.signOut()}}}else{Button("Sign in or create an account"){auth=true}};Button("TapLead Pro"){paywall=true}}
            Section("Your data, your choice") {Text("Private contact fields stay out of public profiles and vCards. Anonymous views never identify visitors. Voice recognition runs on device; raw recordings are not retained.").font(.subheadline);Button("Export my data"){exportData()};if let exportURL{ShareLink(item:exportURL){Label("Share data export",systemImage:"square.and.arrow.up")}};if store.authenticated{Button("Delete account",role:.destructive){deleting=true}}}
            Section("Sync") {Text(store.authenticated ? store.syncMessage:String(localized:"Your cards and notes are saved on this iPhone."));Text("Native notes can be captured offline. Public profiles, publication, AI and cloud sync require internet.").font(.caption).foregroundStyle(.secondary);Button("Sync now"){Task{await store.synchronize()}}.disabled(!store.authenticated || store.syncing)}
            Section("About TapLead") {Text("Tap. Connect. Convert.");policyLink("Privacy policy",key:"TapLeadPrivacyURL");policyLink("Terms of use",key:"TapLeadTermsURL");Text("Version 1.0 · Business / Productivity").font(.caption).foregroundStyle(.secondary)}
        }.navigationTitle("Settings").sheet(isPresented:$auth){AuthView()}.sheet(isPresented:$paywall){PaywallView()}.confirmationDialog("Permanently delete your account, cards and leads?",isPresented:$deleting,titleVisibility:.visible){Button("Delete account",role:.destructive){Task{do{try await store.deleteAccount()}catch{store.error=error.localizedDescription}}}}message:{Text("Deleting your account does not cancel your App Store subscription. Manage subscriptions in your Apple account.")}
    }
    @ViewBuilder func policyLink(_ label:LocalizedStringKey,key:String)->some View {if let raw=Bundle.main.object(forInfoDictionaryKey:key) as? String,let url=URL(string:raw),url.scheme=="https"{Link(label,destination:url)}else{Text(label).foregroundStyle(.secondary)}}
    func exportData(){do{let url=URL.temporaryDirectory.appendingPathComponent("TapLead-export.json");try JSONEncoder().encode(store.snapshot).write(to:url,options:[.atomic,.completeFileProtection]);exportURL=url}catch{store.error=error.localizedDescription}}
}
struct PaywallView:View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var purchases=PurchaseService()
    var body:some View {NavigationStack{ScrollView{VStack(alignment:.leading,spacing:24){Label("TapLead Pro",systemImage:"sparkle").font(.title3.bold()).foregroundStyle(Palette.accent);Text("Make more of\nevery introduction.").font(.system(.largeTitle,design:.rounded,weight:.bold));Text("Choose more room for your next connection.").foregroundStyle(.secondary);ForEach(["Multiple card personas","Up to 20 published cards","Up to 10,000 synced leads","Advanced themes and card customisation","Voice notes with reviewed transcription","Branded QR, photo and printable exports","Measured activity insights","Optional on-device AI on eligible iOS 26 devices"],id:\.self){Label(LocalizedStringKey($0),systemImage:"checkmark.circle")};if purchases.pro{Text("A verified Pro entitlement is active.")};if purchases.purchasesEnabled && policiesConfigured{ForEach(purchases.products){product in Button{Task{await purchases.buy(product);await store.synchronize()}}label:{HStack{Text(verbatim:product.displayName);Spacer();Text(verbatim:product.displayPrice)}}};Text("Payment is charged to your Apple account. Subscriptions renew automatically unless cancelled at least 24 hours before the current period ends. Manage or cancel in your Apple account.").font(.caption);policyLink("Privacy policy",key:"TapLeadPrivacyURL");policyLink("Terms of use",key:"TapLeadTermsURL")}else{Text("Pro purchases are not yet available. Release configuration and sandbox verification are required.").font(.caption).foregroundStyle(.secondary)};Text("Free includes one digital card, QR sharing, public profile and up to 50 synced leads.").font(.subheadline);Button("Restore purchases"){Task{await purchases.restore();await store.synchronize()}};if let error=purchases.error{Text(verbatim:error).font(.caption).foregroundStyle(.secondary)};Button("Manage Apple subscriptions"){Task{if let scene=UIApplication.shared.connectedScenes.first as? UIWindowScene{try? await StoreKit.AppStore.showManageSubscriptions(in:scene)}}};Text("Teams architecture is planned for shared branding, roles and company templates.").font(.caption).foregroundStyle(.secondary)}.padding(28)}.navigationTitle("Your next chapter").toolbar{ToolbarItem(placement:.cancellationAction){Button("Close"){dismiss()}}}.task{await purchases.load()}}}
    var policiesConfigured:Bool{["TapLeadPrivacyURL","TapLeadTermsURL"].allSatisfy{key in guard let value=Bundle.main.object(forInfoDictionaryKey:key) as? String,let url=URL(string:value) else{return false};return url.scheme=="https"}}
    @ViewBuilder func policyLink(_ title:LocalizedStringKey,key:String)->some View{if let value=Bundle.main.object(forInfoDictionaryKey:key) as? String,let url=URL(string:value){Link(title,destination:url)}}
}
