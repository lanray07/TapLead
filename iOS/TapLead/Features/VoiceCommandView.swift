import SwiftUI
import TapLeadCore

struct VoiceCommandView:View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var command=""
    @State private var recording=false
    @State private var selectedID:UUID?
    @State private var date=Date().addingTimeInterval(86400)
    @State private var ai=false
    @State private var confirm=false
    @State private var resultMessage=""
    var matchedLead:Lead?{store.leads.first{$0.id==selectedID}}
    var body:some View {NavigationStack{Form{Section{Text("Tell TapLead your next move.").font(.title2.bold());Text("Try ‘Create a follow-up for Sarah next Tuesday’, ‘Summarise my notes about James’, ‘Draft an introduction email’, or ‘Show leads I haven’t contacted’.").foregroundStyle(.secondary);Button{recording=true}label:{Label("Speak a command",systemImage:"mic.fill")};TextField("Review your command",text:$command,axis:.vertical)};Section("Confirm the connection and action"){Picker("Connection",selection:$selectedID){Text("Choose a connection").tag(UUID?.none);ForEach(store.leads){Text(verbatim:$0.name).tag(Optional($0.id))}};DatePicker("Follow-up date",selection:$date,in:Date()...);Button("Review follow-up"){confirm=true}.disabled(selectedID==nil);Button("Summarise or draft with AI"){ai=true}.disabled(selectedID==nil);Button("Show uncontacted leads"){store.leadFilter = .new;store.tab=2;dismiss()};if !resultMessage.isEmpty{Text(verbatim:resultMessage)}}}.navigationTitle("Voice assistant").toolbar{ToolbarItem(placement:.cancellationAction){Button("Close"){dismiss()}}}.sheet(isPresented:$recording){VoiceNoteView{text in command=text;interpret()}}.sheet(isPresented:$ai){if let lead=matchedLead{AIView(lead:lead)}}.confirmationDialog("Create this follow-up?",isPresented:$confirm,titleVisibility:.visible){Button("Confirm follow-up"){Task{await saveFollowUp()}}}message:{if let lead=matchedLead{Text("\(lead.name) · \(date.formatted(date:.abbreviated,time:.shortened))")}}}}
    func interpret(){
        let full=store.leads.filter{!$0.name.isEmpty && command.localizedCaseInsensitiveContains($0.name)}
        let matches=full.isEmpty ? store.leads.filter { lead in guard let first=lead.name.split(separator:" ").first else{return false};return command.localizedCaseInsensitiveContains(String(first)) } : full
        selectedID=matches.count == 1 ? matches.first?.id : nil
        if let detector=try? NSDataDetector(types:NSTextCheckingResult.CheckingType.date.rawValue),let found=detector.firstMatch(in:command,range:NSRange(command.startIndex...,in:command))?.date,found>Date(){date=found}
        resultMessage=matches.count > 1 ? String(localized:"More than one connection matches. Choose the right person and review the date. No action has been taken.") : String(localized:"Review the connection and date before confirming. No action has been taken.")
    }
    func saveFollowUp() async {guard var lead=matchedLead else{return};lead.followUp=date;lead.status = .followUp;lead.timeline.append(TimelineEntry(kind:"follow_up_scheduled",text:""));store.saveLead(lead);do{try await NotificationService.schedule(id:lead.id,date:date);resultMessage=String(localized:"Follow-up saved.")}catch{store.error=error.localizedDescription}}
}
