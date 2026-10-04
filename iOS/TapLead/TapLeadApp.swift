import SwiftUI
import TapLeadCore
import CoreSpotlight

@main struct TapLeadApp: App {
    @State private var store=AppStore()
    @State private var connectivity:Connectivity?
    var body: some Scene { WindowGroup { RootView().environment(store).tint(Palette.accent).task{if connectivity==nil{connectivity=Connectivity(store:store)}} } }
}
struct RootView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.scenePhase) private var phase
    var body: some View {
        @Bindable var store=store
        Group {
            if store.cards.isEmpty && !store.authenticated { OnboardingView() }
            else {
                TabView(selection:$store.tab) {
                    NavigationStack { HomeView() }.tabItem { Label("Today",systemImage:"square.grid.2x2") }.tag(0)
                    NavigationStack { CardsView() }.tabItem { Label("My card",systemImage:"person.crop.rectangle") }.tag(1)
                    NavigationStack { LeadsView() }.tabItem { Label("Connections",systemImage:"person.2") }.tag(2)
                    NavigationStack { AnalyticsView() }.tabItem { Label("Insights",systemImage:"chart.xyaxis.line") }.tag(3)
                    NavigationStack { SettingsView() }.tabItem { Label("Settings",systemImage:"slider.horizontal.3") }.tag(4)
                }
                .sheet(isPresented:$store.showEvent) { EventView() }
                .sheet(isPresented:$store.showVoiceCommand) {VoiceCommandView()}
            }
        }
        .alert("Something needs attention",isPresented:Binding(get:{store.error != nil},set:{if !$0 {store.error=nil}})) { Button("OK") { store.error=nil } } message: { Text(store.error ?? "") }
        .onOpenURL { url in
            if url.host=="qr" { store.showEvent=true }
            if url.host=="followups" { store.tab=0 }
            if url.host=="card" { store.tab=1 }
        }
        .onContinueUserActivity(CSSearchableItemActionType) {activity in if let raw=activity.userInfo?[CSSearchableItemActivityIdentifier] as? String,let url=URL(string:raw){if let id=UUID(uuidString:url.lastPathComponent),let card=store.cards.first(where:{$0.id==id}){store.select(card)};store.tab=1}}
        .onChange(of:phase) { _,value in if value == .active { Task { await store.synchronize() } } }
        .onChange(of:IntentRouter.shared.destination) { _,value in if let value { if value == "qr" {store.showEvent=true} else if value == "voice" {store.showVoiceCommand=true} else if value == "followups" {store.tab=0} else {store.tab=1}; IntentRouter.shared.destination=nil } }
        .task { await store.synchronize() }
    }
}
