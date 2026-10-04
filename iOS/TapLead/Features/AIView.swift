import SwiftUI
import TapLeadCore

struct AIView:View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var lead:Lead
    @State private var consent=false
    @State private var tone="Professional"
    @State private var channel="Email"
    @State private var busy=false
    @State private var result:AIResult?
    @State private var draft=""
    @State private var summary=""
    @State private var failure:String?
    @State private var generation:Task<Void,Never>?
    var body:some View {
        NavigationStack {
            Form {
                Section("Use the context you already have") {Text(verbatim:lead.notes.isEmpty ? lead.context:lead.notes);Toggle("Allow AI processing of these notes",isOn:$consent);Text("These notes and the contact name are processed on this iPhone using Apple’s on-device model only when you choose an action. TapLead does not send them to an external AI service.").font(.caption).foregroundStyle(.secondary)}
                Section {
                    Picker("Tone",selection:$tone){ForEach(["Friendly","Professional","Concise","Sales","Casual"],id:\.self){Text(LocalizedStringKey($0))}}
                    Picker("Message format",selection:$channel){ForEach(["Email","SMS","LinkedIn","WhatsApp"],id:\.self){Text(verbatim:$0)}}
                    Button("Create Smart Notes"){start("smart_notes")}.disabled(!canGenerate)
                    Button("Draft Follow-Up"){start("follow_up")}.disabled(!canGenerate)
                    if !store.pro && !store.demo {Text("Smart Notes and AI drafts are included with TapLead Pro.").font(.caption)}
                    if !LocalAIService.available {Text("On-device AI needs iOS 26, Apple Intelligence enabled, and a supported device and language. Your notes and manual introduction drafts remain available.").font(.caption).foregroundStyle(.secondary)}
                    NavigationLink("Write an introduction yourself"){IntroductionDraftView(leadID:lead.id)}
                }
                if busy {ProgressView("Preparing your draft…")}
                if let failure {Section{Text(verbatim:failure).foregroundStyle(.secondary)}}
                if let result {
                    Section("Facts from your notes") {ForEach(Array(result.facts.enumerated()),id:\.offset){_,fact in VStack(alignment:.leading,spacing:4){Text(verbatim:fact.field).font(.caption.bold());Text(verbatim:fact.value);Text(verbatim:fact.evidence).font(.caption).foregroundStyle(.secondary)}}}
                    Section("AI suggestions · review first") {ForEach(result.suggestions,id:\.self){Text(verbatim:$0)}}
                    if result.draft == nil {
                        Section("Review and edit summary") {
                            TextEditor(text:$summary).frame(minHeight:160).accessibilityLabel("Smart Notes summary")
                            Button("Save reviewed Smart Notes") {guard var updated=store.leads.first(where:{$0.id==lead.id}) else{return};updated.timeline.append(TimelineEntry(kind:"smart_notes",text:summary));store.saveLead(updated);dismiss()}.disabled(summary.isEmpty || summary.count>4000)
                            if summary.count>4000 {Text("Shorten the summary to 4,000 characters before saving.").font(.caption)}
                        }
                    }
                    if result.draft != nil {Section("Review and edit your draft") {TextEditor(text:$draft).frame(minHeight:160);ShareLink(item:draft){Label("Share reviewed draft",systemImage:"square.and.arrow.up")};Button("Save draft to timeline"){guard var updated=store.leads.first(where:{$0.id==lead.id}) else{return};updated.timeline.append(TimelineEntry(kind:"follow_up_drafted",text:draft));store.saveLead(updated);dismiss()};Text("TapLead does not send messages. Choose a destination in the Share Sheet and confirm there.").font(.caption).foregroundStyle(.secondary)}}
                }
            }.navigationTitle("A thoughtful next step").toolbar{ToolbarItem(placement:.cancellationAction){Button("Close"){dismiss()}}}
        }
        .onDisappear{generation?.cancel()}
        .onChange(of:consent){_,enabled in if !enabled{generation?.cancel();result=nil;draft="";summary=""}}
    }
    var canGenerate:Bool{consent && !busy && LocalAIService.available && (store.pro || store.demo)}
    func start(_ kind:String){generation=Task{await generate(kind)}}
    func generate(_ kind:String) async {
        busy=true;failure=nil;defer{busy=false}
        guard consent,store.pro || store.demo else{return}
        do {
            let response=try await LocalAIService.generate(kind:kind,notes:lead.notes.isEmpty ? lead.context:lead.notes,name:lead.name,tone:tone,channel:channel)
            guard consent,!Task.isCancelled else{return};result=response;draft=response.draft ?? ""
            summary=String(localized:"Facts from your notes") + "\n" + response.facts.map{"\($0.field): \($0.value)"}.joined(separator:"\n") + "\n\n" + String(localized:"AI suggestions · review first") + "\n" + response.suggestions.joined(separator:"\n")
        } catch {guard !Task.isCancelled else{return};failure=error.localizedDescription}
    }
}
