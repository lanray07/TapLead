import SwiftUI
import AuthenticationServices
import CryptoKit
import TapLeadCore

struct OnboardingView: View {
    @Environment(AppStore.self) private var store
    @State private var page=0
    @State private var accountAuth=false
    var body: some View {
        VStack(spacing:24) {
            HStack { Label("TapLead",systemImage:"square.on.square").font(.title3.bold()); Spacer(); Button("Explore demo") {store.startDemo()}.font(.subheadline) }.padding(.horizontal,24)
            TabView(selection:$page) {
                OnboardingPage(icon:"person.crop.rectangle",title:"Never lose a connection again",copy:"Create and share your professional identity instantly.").tag(0)
                OnboardingPage(icon:"qrcode",title:"Scan to connect",copy:"Share using QR or a simple link.").tag(1)
                OnboardingPage(icon:"waveform",title:"Remember every conversation",copy:"Capture notes using text or your voice.").tag(2)
                OnboardingPage(icon:"arrow.up.forward.circle",title:"Follow up while you’re still remembered",copy:"Turn new contacts into actionable opportunities.").tag(3)
            }.tabViewStyle(.page(indexDisplayMode:.always))
            VStack(spacing:14) {
                PrimaryButton(title:"Create My TapLead") {store.beginLocal()}
                Button("Sign in or create an account") {accountAuth=true}
                Text("Start on this iPhone. Publish when you’re ready.").font(.caption).foregroundStyle(.secondary)
            }.padding(24)
        }.padding(.top,16).background(Palette.canvas).sheet(isPresented:$accountAuth) {AuthView()}
    }
}
struct OnboardingPage: View {
    var icon: String; var title: LocalizedStringKey; var copy: LocalizedStringKey
    var body: some View { VStack(spacing:28) { Spacer(); Image(systemName:icon).font(.system(size:76,weight:.light)).foregroundStyle(Palette.accent).frame(width:180,height:180).background(Palette.accent.opacity(0.08),in:RoundedRectangle(cornerRadius:50)).accessibilityHidden(true); VStack(spacing:16) {Text(title).font(.system(.largeTitle,design:.rounded,weight:.bold)); Text(copy).font(.body).foregroundStyle(.secondary)}.multilineTextAlignment(.center); Spacer() }.padding(32) }
}
struct AuthView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var busy=false
    @State private var nonce=""
    @State private var accountNotice=""
    var body: some View {
        NavigationStack {
            Form {
                Section { Text("Your connections, wherever you go.").font(.title2.bold()); Text("Sign in with Apple to publish your card and sync your connections.").foregroundStyle(.secondary) }
                Section {
                    SignInWithAppleButton(.continue) { request in
                        request.requestedScopes=[]
                        request.nonce=SHA256.hash(data:Data(nonce.utf8)).map {String(format:"%02x",$0)}.joined()
                        busy=true
                    } onCompletion: { result in
                        Task {
                            defer {busy=false}
                            do {
                                let authorization=try result.get()
                                guard let credential=authorization.credential as? ASAuthorizationAppleIDCredential,let data=credential.identityToken,let token=String(data:data,encoding:.utf8),let codeData=credential.authorizationCode,let code=String(data:codeData,encoding:.utf8) else {throw ServiceError.message(String(localized:"Apple sign-in did not return a token."))}
                                let response: AuthResponse=try await store.api.send("api/auth/apple",method:"POST",value:["identityToken":token,"nonce":nonce,"authorizationCode":code])
                                try await store.signedIn(response);dismiss()
                            } catch {
                                accountNotice=error.localizedDescription
                                nonce=""
                            }
                        }
                    }.signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black).frame(height:48).disabled(nonce.isEmpty || busy)
                    if busy {ProgressView()}
                    if !accountNotice.isEmpty {Text(verbatim:accountNotice).font(.subheadline).accessibilityAddTraits(.updatesFrequently)}
                    if nonce.isEmpty {Button("Try again"){Task{await loadChallenge()}}.disabled(busy)}
                }
                Section {
                    Button("Continue on this iPhone") {store.beginLocal();dismiss()}
                    Text("Guest cards and notes stay on this iPhone. Sign in with Apple when you’re ready to publish and sync.").font(.caption).foregroundStyle(.secondary)
                }
            }.navigationTitle("Welcome to TapLead").toolbar {ToolbarItem(placement:.cancellationAction){Button("Close"){dismiss()}}}
            .task {await loadChallenge()}
        }
    }
    func loadChallenge() async {
        busy=true;defer{busy=false}
        do {
            struct Challenge:Decodable {var nonce:String}
            let challenge:Challenge=try await store.api.request("api/auth/apple/challenge",method:"POST")
            nonce=challenge.nonce;accountNotice=""
        } catch {nonce="";accountNotice=error.localizedDescription}
    }
}
