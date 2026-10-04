import SwiftUI
import Observation
import WidgetKit
import TapLeadCore

@MainActor @Observable final class AppStore {
    var snapshot = AppSnapshot()
    var error: String?
    var syncMessage = ""
    var syncing = false
    var authenticated = Keychain.token() != nil
    var tab = 0
    var showEvent = false
    var showVoiceCommand = false
    var leadFilter: LeadStatus?
    var pro=false
    let api = APIClient()
    private let storage: URL
    private var sessionEpoch=0
    private var indexedCardsSignature=""
    var cards: [Card] { snapshot.cards }
    var leads: [Lead] { snapshot.leads }
    var demo: Bool { snapshot.demo }
    var selectedCard: Card? { snapshot.cards.first { $0.id == snapshot.selectedCardID } ?? snapshot.cards.first }
    var dueLeads: [Lead] { leads.filter { $0.status != .won && $0.status != .archived && ($0.followUp.map { $0 < Calendar.current.date(byAdding:.day,value:1,to:Calendar.current.startOfDay(for:Date()))! } ?? false) }.sorted { ($0.followUp ?? .distantFuture) < ($1.followUp ?? .distantFuture) } }
    init() {
        storage = URL.documentsDirectory.appendingPathComponent("taplead-state.json")
        if FileManager.default.fileExists(atPath: storage.path) {
            do { snapshot = try JSONDecoder().decode(AppSnapshot.self, from: Data(contentsOf: storage)) }
            catch {let backup=storage.deletingLastPathComponent().appendingPathComponent("taplead-recovery-\(UUID().uuidString).json");try? FileManager.default.copyItem(at:storage,to:backup); self.error = String(localized: "Your saved data could not be opened. It has been preserved for recovery.") }
        }
        if ProcessInfo.processInfo.arguments.contains("--demo") { startDemo() }
        #if DEBUG
        // Deterministic marketing captures use the same card renderer and remain demo-only.
        let arguments=ProcessInfo.processInfo.arguments
        if snapshot.demo,let index=arguments.firstIndex(of:"--sample-theme"),arguments.indices.contains(index+1),
           let theme=CardTheme(rawValue:arguments[index+1]),var card=selectedCard {
            let samples:[CardTheme:(String,String,String,String,String)] = [
                .minimal:("Sam Taylor","Product designer","Northline Studio","Simple ideas. Thoughtful design.","Minimal"),
                .creator:("Maya Patel","Illustrator & designer","Studio Maya","Colour outside the ordinary.","Creator"),
                .bold:("Jordan Reed","Creative director","Form & Field","Ideas made to stand out.","Bold"),
                .dark:("Casey Brooks","Software consultant","Bridge Works","Clear thinking. Better systems.","Dark"),
                .elegant:("Avery Blake","Interior designer","Quiet Space","Considered spaces. Lasting impressions.","Elegant"),
                .sales:("Morgan Ellis","Business development","Summit Partners","Great relationships start here.","Sales"),
                .consultant:("Riley Park","Strategy consultant","Park Advisory","Your next chapter, with clarity.","Consultant")
            ]
            if let sample=samples[theme] {
                card.name=sample.0;card.preferredName=sample.0.components(separatedBy:" ")[0]
                card.title=sample.1;card.company=sample.2;card.headline=sample.3;card.persona=sample.4
                card.theme=theme;card.imageKind = .none;card.accent="7861D9"
                card.bio="Fictional sample profile for TapLead card style previews."
                card.email="sample@example.com";saveCard(card)
            }
        }
        #endif
    }
    func persist() {
        do { try JSONEncoder().encode(snapshot).write(to: storage, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]); updateWidget();let signature=cards.filter(\.published).map{"\($0.id)|\($0.name)|\($0.title)|\($0.company)"}.joined(separator:"\n");if signature != indexedCardsSignature{indexedCardsSignature=signature;SpotlightService.update(cards)} }
        catch { self.error = String(localized: "Your changes could not be saved. Please try again.") }
    }
    func select(_ card: Card) { snapshot.selectedCardID = card.id; persist() }
    func saveCard(_ card: Card, acknowledged:Bool=false) {
        if let i = snapshot.cards.firstIndex(where: { $0.id == card.id }) { snapshot.cards[i] = card } else { snapshot.cards.append(card) }
        var edits=snapshot.unpublishedCardEdits ?? []
        edits.removeAll{$0==card.id};if !acknowledged{edits.append(card.id)}
        snapshot.unpublishedCardEdits=edits
        snapshot.selectedCardID = card.id; persist()
    }
    func saveLead(_ lead: Lead) {
        if let i = snapshot.leads.firstIndex(where: { $0.id == lead.id }) { snapshot.leads[i] = lead } else { snapshot.leads.insert(lead, at: 0) }
        if !snapshot.pendingLeadIDs.contains(lead.id) { snapshot.pendingLeadIDs.append(lead.id) }
        persist()
    }
    func deleteLead(_ id: UUID) {
        snapshot.leads.removeAll { $0.id == id }; snapshot.pendingLeadIDs.removeAll { $0 == id }
        if !snapshot.deletedLeadIDs.contains(id) { snapshot.deletedLeadIDs.append(id) }
        NotificationService.cancel(id); persist()
    }
    func startDemo() {
        guard !authenticated else { return }
        snapshot = AppSnapshot(); snapshot.demo = true
        var c = Card(); c.name = "Alex Morgan"; c.preferredName = "Alex"; c.title = "Brand strategist"; c.company = "Morgan Studio"; c.headline = "Good conversations. Great possibilities."; c.bio = "I help ambitious businesses find their voice and build brands people remember."; c.email = "alex@example.com"; c.website = "https://example.com"; c.location = "London, United Kingdom"
        snapshot.cards = [c]; snapshot.selectedCardID = c.id
        for (name,company,context,offset,status) in [("Sarah Chen","Greenfield Properties","London property conference. Interested in a new brand for two commercial properties.",-1,LeadStatus.followUp),("James Wilson","Forma Architecture","Met at Design Week. Send portfolio and discuss the studio launch.",1,.new),("Amara Okafor","Bloom Collective","Coffee after the founders breakfast. Exploring a collaboration.",3,.active)] {
            var l = Lead(); l.name=name; l.company=company; l.context=context; l.notes=context; l.cardID=c.id; l.source="event"; l.status=status; l.followUp=Calendar.current.date(byAdding:.day,value:offset,to:Date()); l.tags=["Networking"]; l.timeline=[TimelineEntry(kind:"met",text:context)]; snapshot.leads.append(l)
        }
        persist()
    }
    func beginLocal() { snapshot = AppSnapshot(); snapshot.cards = [Card()]; snapshot.selectedCardID = snapshot.cards[0].id; persist() }
    func signedIn(_ response: AuthResponse) async throws {
        try Keychain.set(response.token); authenticated = true
        sessionEpoch += 1
        UserDefaults.standard.set(response.userID,forKey:"TapLeadUserID")
        // Never upload demo identities or sample leads into a real account.
        if snapshot.demo { snapshot = AppSnapshot() }
        await synchronize()
        if snapshot.cards.isEmpty { snapshot.cards = [Card()] }
        persist()
    }
    func publish(_ card: Card) async throws {
        guard authenticated, !demo else { throw ServiceError.message(String(localized: "Sign in to publish your card.")) }
        let epoch=sessionEpoch
        var live = card; live.published = true; live.photoData=nil; live.logoData=nil;live.imageKind=card.imageKind
        let response: Card = try await api.send("api/cards/\(card.id.uuidString.lowercased())", method:"PUT", value:live)
        guard epoch==sessionEpoch else{return}
        let image=card.imageKind == .logo ? card.logoData : card.imageKind == .photo ? card.photoData : nil
        if let image {
            let mime=image.starts(with:[137,80,78,71,13,10,26,10]) ? "image/png" : "image/jpeg"
            let _:EmptyResponse=try await api.request("api/cards/\(card.id.uuidString.lowercased())/image?kind=\(card.imageKind.rawValue)",method:"PUT",body:image,contentType:mime)
        } else {
            let _:EmptyResponse=try await api.request("api/cards/\(card.id.uuidString.lowercased())/image",method:"DELETE")
        }
        guard epoch==sessionEpoch else{return}
        var merged=response; merged.photoData=card.photoData; merged.logoData=card.logoData
        merged.cornerImageKind=card.cornerImageKind; merged.cornerImagePosition=card.cornerImagePosition
        if let current=cards.first(where:{$0.id==card.id}),current != card {
            var edited=current;edited.published=true;saveCard(edited)
        } else {saveCard(merged,acknowledged:true)}
    }
    func unpublish(_ card: Card) async throws {
        let epoch=sessionEpoch
        var privateCard=card; privateCard.published=false; privateCard.photoData=nil;privateCard.logoData=nil
        let _: Card = try await api.send("api/cards/\(card.id.uuidString.lowercased())",method:"PUT",value:privateCard)
        guard epoch==sessionEpoch else{return}
        var local=cards.first(where:{$0.id==card.id}) ?? card;let changed=local != card;local.published=false;saveCard(local,acknowledged:!changed)
    }
    func synchronize() async {
        guard authenticated, !demo, !syncing else { return }; syncing = true; defer { syncing = false }
        let epoch=sessionEpoch
        do {
            let plan:PlanResponse=try await api.request("api/plan")
            guard epoch==sessionEpoch else{return}
            pro=plan.pro
            for id in snapshot.deletedLeadIDs {
                let _: EmptyResponse = try await api.request("api/leads/\(id.uuidString.lowercased())",method:"DELETE")
                guard epoch==sessionEpoch else{return}
                snapshot.deletedLeadIDs.removeAll { $0 == id }; persist()
            }
            for id in snapshot.pendingLeadIDs {
                guard let lead = leads.first(where: { $0.id == id }) else { continue }
                var upload=lead
                if let cardID=lead.cardID, !cards.contains(where:{$0.id==cardID && $0.published}) { upload.cardID=nil }
                let _: Lead = try await api.send("api/leads/\(id.uuidString.lowercased())",method:"PUT",value:upload)
                guard epoch==sessionEpoch else{return}
                // Preserve edits made while an earlier version was in flight.
                if snapshot.leads.first(where:{$0.id==id}) == lead { snapshot.pendingLeadIDs.removeAll { $0 == id } }
            }
            let remote: [Lead] = try await api.request("api/leads")
            guard epoch==sessionEpoch else{return}
            snapshot.leads = remote.filter { !snapshot.pendingLeadIDs.contains($0.id) && !snapshot.deletedLeadIDs.contains($0.id) } + snapshot.leads.filter { snapshot.pendingLeadIDs.contains($0.id) }
            let remoteCards: [Card] = try await api.request("api/cards")
            guard epoch==sessionEpoch else{return}
            snapshot.cards=CardSync.merge(remote:remoteCards,local:snapshot.cards,editedIDs:snapshot.unpublishedCardEdits ?? [])
            syncMessage = String(localized: "Up to date"); persist()
        } catch {guard epoch==sessionEpoch else{return}; syncMessage = String(localized: "Changes saved on this iPhone. Pull to retry sync."); self.error = error.localizedDescription; persist() }
    }
    func signOut() async {
        do { let _: EmptyResponse = try await api.request("api/auth/logout",method:"POST");sessionEpoch += 1;for lead in leads{NotificationService.cancel(lead.id)}; try Keychain.set(nil); authenticated=false;pro=false;UserDefaults.standard.removeObject(forKey:"TapLeadUserID"); snapshot=AppSnapshot(); persist() }
        catch { self.error=error.localizedDescription }
    }
    func deleteAccount() async throws {
        let _: EmptyResponse = try await api.request("api/account",method:"DELETE")
        sessionEpoch += 1;for lead in leads{NotificationService.cancel(lead.id)}
        try Keychain.set(nil); authenticated=false;pro=false;UserDefaults.standard.removeObject(forKey:"TapLeadUserID"); snapshot=AppSnapshot(); persist()
    }
    func updateWidget() {
        let defaults=UserDefaults(suiteName:"group.com.taplead.shared")
        // Deliberately share no lead names, notes, or contact details with the extension.
        defaults?.set(selectedCard?.name ?? "TapLead",forKey:"name")
        defaults?.set(selectedCard?.title ?? "",forKey:"title")
        defaults?.set(selectedCard.flatMap { card in api.base.map { card.published ? card.profileURL(base:$0,source:"qr").absoluteString : "" } } ?? "",forKey:"url")
        // Refresh counts across midnight without storing any individual lead metadata.
        let today = Calendar.current.startOfDay(for: Date())
        let counts = (0...7).map { offset -> WidgetCountSnapshot in
            let date = Calendar.current.date(byAdding: .day, value: offset, to: today)!
            let now = offset == 0 ? Date() : date
            let value = ConnectionCounts(leads: leads, now: now)
            return WidgetCountSnapshot(date: date, recent: value.recent, due: value.due)
        }
        defaults?.set(try? JSONEncoder().encode(counts), forKey: "connectionCounts")
        WidgetCenter.shared.reloadAllTimelines()
    }
}
