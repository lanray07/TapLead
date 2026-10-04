import SwiftUI
import TapLeadCore

struct LeadsView: View {
    @Environment(AppStore.self) private var store
    @State private var query=""
    @State private var newLead=false
    var filtered:[Lead] {store.leads.filter{($0.status==store.leadFilter || store.leadFilter==nil) && $0.matches(query)}}
    var body: some View {
        VStack(spacing:0) {
            if store.demo {DemoBanner().padding(.horizontal)}
            ScrollView(.horizontal,showsIndicators:false) { HStack {filterButton("All",value:nil);ForEach(LeadStatus.allCases,id:\.self){filterButton(LocalizedStringKey($0.rawValue),value:$0)}}.padding() }
            List {
                if filtered.isEmpty {ContentUnavailableView("Room for a new connection",systemImage:"person.2",description:Text("Add someone you’ve met, then choose your next move.")).listRowBackground(Color.clear)}
                ForEach(filtered){lead in NavigationLink{LeadDetailView(leadID:lead.id)}label:{LeadRow(lead:lead)}.swipeActions{Button("Archive"){var copy=lead;copy.status = .archived;copy.timeline.append(TimelineEntry(kind:"status",text:LeadStatus.archived.rawValue));store.saveLead(copy)}}}
            }.listStyle(.plain)
        }.background(Palette.canvas).navigationTitle("Connections").searchable(text:$query,prompt:"Search names, notes or tags").toolbar{Button{newLead=true}label:{Image(systemName:"plus")}.accessibilityLabel("Add connection")}.sheet(isPresented:$newLead){LeadEditor()}.refreshable{await store.synchronize()}
    }
    func filterButton(_ label:LocalizedStringKey,value:LeadStatus?) -> some View {Button{store.leadFilter=value}label:{Text(label).font(.subheadline.weight(.medium)).padding(.horizontal,16).padding(.vertical,11).foregroundStyle(store.leadFilter==value ? .white:Palette.accent).background(store.leadFilter==value ? Palette.accent:Palette.accent.opacity(0.08),in:Capsule())}.buttonStyle(.plain)}
}
struct LeadEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var lead=Lead()
    @State private var saved=false
    @State private var voice=false
    @State private var introduction=false
    var usedCard:Card? { store.cards.first{$0.id == lead.cardID} ?? store.selectedCard }
    var body: some View {
        NavigationStack {
            if saved {
                ScrollView {VStack(alignment:.leading,spacing:20) {
                    if store.demo {DemoBanner()}
                    Image(systemName:"checkmark.circle.fill").font(.system(size:48)).foregroundStyle(Palette.accent)
                    Text("A good start. What next?").font(.largeTitle.bold())
                    Text(verbatim:lead.name).font(.title3).foregroundStyle(.secondary)
                    Button{introduction=true}label:{Label("Send introduction",systemImage:"envelope")}.frame(minHeight:44)
                    NavigationLink{LeadDetailView(leadID:lead.id)}label:{Label("Book follow-up",systemImage:"calendar")}.frame(minHeight:44)
                    NavigationLink{LeadDetailView(leadID:lead.id)}label:{Label("Add reminder",systemImage:"bell")}.frame(minHeight:44)
                    Button{voice=true}label:{Label("Add voice note",systemImage:"mic")}.frame(minHeight:44)
                    if let url=usedCard.flatMap({Validation.webURL($0.portfolio)}) {ShareLink(item:url){Label("Share portfolio",systemImage:"square.and.arrow.up")}.frame(minHeight:44)}
                    else {Label("Add a portfolio link to your card to share it",systemImage:"link").font(.caption).foregroundStyle(.secondary)}
                    if let url=usedCard.flatMap({Validation.webURL($0.booking)}) {ShareLink(item:url){Label("Share booking link",systemImage:"calendar.badge.plus")}.frame(minHeight:44)}
                    else {Label("Add a booking link to your card to share it",systemImage:"calendar").font(.caption).foregroundStyle(.secondary)}
                    PrimaryButton(title:"Done",icon:"checkmark"){dismiss()}
                }.padding(28)}.navigationTitle("Connection saved")
            }
            else {
                Form {
                    if store.demo {Section{DemoBanner()}}
                    Section("Their details") {TextField("Name",text:$lead.name);TextField("Email",text:$lead.email).keyboardType(.emailAddress).textInputAutocapitalization(.never);TextField("Phone",text:$lead.phone).keyboardType(.phonePad);TextField("Company",text:$lead.company);TextField("Role",text:$lead.role);TextField("Interested in",text:$lead.interest)}
                    Section("Remember the conversation") {TextField("Where or how did you meet?",text:$lead.context,axis:.vertical);TextField("Notes",text:$lead.notes,axis:.vertical).lineLimit(3...8);Button{voice=true}label:{Label("Add voice note",systemImage:"mic.fill")};TextField("Tags, separated by commas",text:Binding(get:{lead.tags.joined(separator:", ")},set:{lead.tags=$0.split(separator:",").map{$0.trimmingCharacters(in:.whitespaces)}}))}
                    Section {Toggle("They agreed to share these details",isOn:$lead.consent);Text("Record contact details only with permission. Location and context are entered by you; TapLead does not track your location.").font(.caption).foregroundStyle(.secondary)}
                }.navigationTitle("New connection").toolbar{ToolbarItem(placement:.cancellationAction){Button("Cancel"){dismiss()}};ToolbarItem(placement:.confirmationAction){Button("Save"){lead.cardID=store.selectedCard?.id;lead.timeline.append(TimelineEntry(kind:"met",text:lead.context));store.saveLead(lead);saved=true}.disabled(lead.name.trimmingCharacters(in:.whitespaces).isEmpty || (!lead.email.isEmpty && !Validation.email(lead.email)) || !lead.consent)}}
            }
        }.sheet(isPresented:$voice){VoiceNoteView {text in lead.notes += (lead.notes.isEmpty ? "":"\n")+text;if saved{lead.timeline.append(TimelineEntry(kind:"voice",text:text));store.saveLead(lead)}}}
        .sheet(isPresented:$introduction){IntroductionDraftView(leadID:lead.id)}
    }
}
struct LeadDetailView: View {
    @Environment(AppStore.self) private var store
    var leadID: UUID
    @State private var voice=false
    @State private var ai=false
    @State private var deleting=false
    @State private var reminderDate=Date().addingTimeInterval(86400)
    @Environment(\.dismiss) private var dismiss
    var lead:Lead?{store.leads.first{$0.id==leadID}}
    var usedCard:Card?{store.cards.first{$0.id==lead?.cardID} ?? store.selectedCard}
    var body: some View {
        Group {
            if let lead {
                Form {
                    Section {HStack(spacing:16){Avatar(name:lead.name,size:64);VStack(alignment:.leading){Text(verbatim:lead.name).font(.title2.bold());Text(verbatim:lead.company).foregroundStyle(.secondary)}};if !lead.email.isEmpty{Text(verbatim:lead.email)};if !lead.phone.isEmpty{Text(verbatim:lead.phone)}}
                    Section("Relationship") {Picker("Status",selection:Binding(get:{self.lead?.status ?? .new},set:{value in mutate{l in l.status=value;l.timeline.append(TimelineEntry(kind:"status",text:value.rawValue))}})){ForEach(LeadStatus.allCases,id:\.self){Text(LocalizedStringKey($0.rawValue)).tag($0)}};Text(verbatim:lead.context);if !lead.interest.isEmpty{Text(verbatim:lead.interest)}}
                    Section("Meeting memory") {TextField("Notes",text:Binding(get:{self.lead?.notes ?? ""},set:{text in mutate{$0.notes=text}}),axis:.vertical).lineLimit(4...10);Button{voice=true}label:{Label("Add voice note",systemImage:"mic.fill")};Button{ai=true}label:{Label("Smart Notes & Draft Follow-Up",systemImage:"sparkles")}}
                    Section("Your next move") {DatePicker("Follow-up date",selection:$reminderDate,in:Date()...,displayedComponents:[.date,.hourAndMinute]);Button("Today"){reminderDate=Date().addingTimeInterval(60)}.disabled(!Calendar.current.isDateInToday(Date().addingTimeInterval(60)));HStack{Button("Tomorrow"){reminderDate=Calendar.current.date(byAdding:.day,value:1,to:Date())!};Spacer();Button("3 days"){reminderDate=Calendar.current.date(byAdding:.day,value:3,to:Date())!};Spacer();Button("Next week"){reminderDate=Calendar.current.date(byAdding:.day,value:7,to:Date())!}};Button("Save follow-up & reminder"){Task{await schedule()}};if let date=lead.followUp{Text(date,format:.dateTime.day().month().hour().minute());Button("Mark follow-up complete"){mutate{$0.followUp=nil;$0.status = .active;$0.timeline.append(TimelineEntry(kind:"follow_up_completed",text:""))};NotificationService.cancel(leadID)}};if let card=usedCard{if let url=Validation.webURL(card.portfolio){ShareLink(item:url){Label("Share portfolio",systemImage:"square.and.arrow.up")}};if let url=Validation.webURL(card.booking){ShareLink(item:url){Label("Share booking link",systemImage:"calendar")}}}}
                    Section("Timeline") {ForEach(lead.timeline.sorted{$0.date>$1.date}){event in VStack(alignment:.leading,spacing:6){Text(event.date,format:.dateTime.day().month().hour().minute()).font(.caption).foregroundStyle(.secondary);Text(LocalizedStringKey(event.kind)).font(.subheadline.bold());if !event.text.isEmpty{Text(verbatim:event.text).font(.subheadline)}}}}
                    Section{Button("Delete connection",role:.destructive){deleting=true}}
                }.navigationTitle(lead.name).navigationBarTitleDisplayMode(.inline)
            } else {ContentUnavailableView("Connection unavailable",systemImage:"person.crop.circle.badge.questionmark")}
        }.sheet(isPresented:$voice){VoiceNoteView{text in mutate{$0.notes += ($0.notes.isEmpty ? "":"\n")+text;$0.timeline.append(TimelineEntry(kind:"voice",text:text))}}}.sheet(isPresented:$ai){if let lead{AIView(lead:lead)}}
        .confirmationDialog("Delete this connection and its notes?",isPresented:$deleting,titleVisibility:.visible){Button("Delete connection",role:.destructive){store.deleteLead(leadID);dismiss()}}
    }
    func mutate(_ action:(inout Lead)->Void){guard var copy=lead else{return};action(&copy);store.saveLead(copy)}
    func schedule() async {
        guard let lead else{return}
        mutate{$0.followUp=reminderDate;$0.status = .followUp;$0.timeline.append(TimelineEntry(kind:"follow_up_scheduled",text:""))}
        do{try await NotificationService.schedule(id:lead.id,date:reminderDate)}catch{store.error=String(localized:"Follow-up saved. Notifications are unavailable; enable them in iPhone Settings.")}
    }
}
