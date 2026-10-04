import SwiftUI
import TapLeadCore

struct HomeView: View {
    @Environment(AppStore.self) private var store
    @State private var newLead = false
    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:24) {
                if store.demo { DemoBanner() }
                HStack(alignment:.top) { VStack(alignment:.leading,spacing:8) { Text("MAKE IT COUNT").font(.caption.weight(.semibold)).tracking(2).foregroundStyle(Palette.accent); Text("Good connections.\nBetter possibilities.").font(.system(.largeTitle,design:.rounded,weight:.bold)); Text("A little follow-up goes a long way.").font(.subheadline).foregroundStyle(.secondary) }; Spacer(); Avatar(name:store.selectedCard?.name ?? "",data:store.selectedCard?.photoData,size:44) }
                if let card=store.selectedCard { CardPreview(card:card) }
                HStack(spacing:12) { PrimaryButton(title:"Share my card",icon:"qrcode") { store.showEvent=true }; Button { newLead=true } label:{ Image(systemName:"person.badge.plus").font(.title3).frame(width:56,height:56).background(Color(uiColor:.secondarySystemGroupedBackground),in:RoundedRectangle(cornerRadius:18)) }.accessibilityLabel("Add connection") }
                HStack(spacing:12) { MetricTile(title:"Connections",value:store.leads.count,icon:"person.2"); MetricTile(title:"Follow-ups due",value:store.dueLeads.count,icon:"clock") }
                Button{store.showVoiceCommand=true}label:{Label("Tell TapLead your next move",systemImage:"mic.fill").font(.headline).frame(maxWidth:.infinity,minHeight:48,alignment:.leading)}
                HStack { Text("Your next move").font(.title2.bold()); Spacer(); Button("See all") {store.tab=2}.font(.subheadline) }
                if store.dueLeads.isEmpty { ContentUnavailableView("All caught up",systemImage:"checkmark.circle",description:Text("Add a follow-up to keep a good conversation going.")) }
                else { VStack { ForEach(store.dueLeads.prefix(3)) { lead in NavigationLink { LeadDetailView(leadID:lead.id) } label:{LeadRow(lead:lead)}.buttonStyle(.plain); if lead.id != store.dueLeads.prefix(3).last?.id { Divider() } } }.padding(16).background(Color(uiColor:.secondarySystemGroupedBackground),in:RoundedRectangle(cornerRadius:22)) }
                if !store.syncMessage.isEmpty { Text(verbatim:store.syncMessage).font(.caption).foregroundStyle(.secondary) }
            }.padding(22)
        }.background(Palette.canvas).navigationTitle("TapLead").navigationBarTitleDisplayMode(.inline).refreshable {await store.synchronize()}.sheet(isPresented:$newLead) { LeadEditor() }
    }
}
