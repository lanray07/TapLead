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
    @State private var failure:String?
    var body:some View {
        NavigationStack {
            Form {
                Section("Use the context you already have") {Text(verbatim:lead.notes.isEmpty ? lead.context:lead.notes);Toggle("Allow AI processing of these notes",isOn:$consent);Text("The selected notes and contact name are sent to your configured AI service only when you choose an action. Check its privacy terms first.").font(.caption).foregroundStyle(.secondary)}
                Section {Picker("Tone",selection:$tone){ForEach(["Friendly","Professional","Concise","Sales","Casual"],id:\.self){Text(LocalizedStringKey($0))}};Picker("Message format",selection:$channel){ForEach(["Email","SMS","LinkedIn","WhatsApp"],id:\.self){Text(verbatim:$0)}};Button("Create Smart Notes"){Task{await generate("smart_notes")}}.disabled(!consent || busy);Button("Draft Follow-Up"){Task{await generate("follow_up")}}.disabled(!consent || busy)}
                if busy {ProgressView("Preparing your draft…")}
                if let failure {Section{Text(verbatim:failure).foregroundStyle(.secondary)}}
                if let result {
                    Section("Facts from your notes") {ForEach(Array(result.facts.enumerated()),id:\.offset){_,fact in VStack(alignment:.leading,spacing:4){Text(verbatim:fact.field).font(.caption.bold());Text(verbatim:fact.value);Text(verbatim:fact.evidence).font(.caption).foregroundStyle(.secondary)}}}
                    Section("AI suggestions · review first") {ForEach(result.suggestions,id:\.self){Text(verbatim:$0)}}
                    if result.draft != nil {Section("Review and edit your draft") {TextEditor(text:$draft).frame(minHeight:160);ShareLink(item:draft){Label("Share reviewed draft",systemImage:"square.and.arrow.up")};Button("Save draft to timeline"){guard var updated=store.leads.first(where:{$0.id==lead.id}) else{return};updated.timeline.append(TimelineEntry(kind:"follow_up_drafted",text:draft));store.saveLead(updated);dismiss()};Text("TapLead does not send messages. Choose a destination in the Share Sheet and confirm there.").font(.caption).foregroundStyle(.secondary)}}
                }
            }.navigationTitle("A thoughtful next step").toolbar{ToolbarItem(placement:.cancellationAction){Button("Close"){dismiss()}}}
        }
    }
    func generate(_ kind:String) async {
        busy=true;failure=nil;defer{busy=false}
        do{struct Input:Encodable{var consent:Bool;var kind:String;var notes:String;var name:String;var tone:String;var channel:String};let response:AIResult=try await store.api.send("api/ai",method:"POST",value:Input(consent:consent,kind:kind,notes:lead.notes.isEmpty ? lead.context:lead.notes,name:lead.name,tone:tone,channel:channel));result=response;draft=response.draft ?? ""}catch{failure=error.localizedDescription}
    }
}
