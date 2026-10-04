import SwiftUI
import TapLeadCore

struct IntroductionDraftView:View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    var leadID:UUID
    @State private var subject=""
    @State private var draft=""
    @State private var failure:String?
    var lead:Lead?{store.leads.first{$0.id==leadID}}
    var body:some View {
        NavigationStack {Form {
            Section("Review your introduction") {
                TextField("Subject",text:$subject)
                TextEditor(text:$draft).frame(minHeight:180).accessibilityLabel("Introduction draft")
                Text("Edit this starter in your own words. TapLead does not send messages or assume the connection has been contacted.").font(.caption).foregroundStyle(.secondary)
            }
            Section {
                if let lead, Validation.email(lead.email) {
                    Button("Open email draft") {
                        var parts=URLComponents();parts.scheme="mailto";parts.path=lead.email
                        parts.queryItems=[URLQueryItem(name:"subject",value:subject),URLQueryItem(name:"body",value:draft)]
                        if let url=parts.url {openURL(url){accepted in if !accepted{failure=String(localized:"No email app is available. Share or copy the draft instead.")}}}
                    }.disabled(draft.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
                }
                ShareLink(item:draft){Label("Share draft",systemImage:"square.and.arrow.up")}.disabled(draft.isEmpty)
                Button("Save draft to timeline") {guard var copy=lead else{return};copy.timeline.append(TimelineEntry(kind:"follow_up_drafted",text:draft));store.saveLead(copy);dismiss()}.disabled(draft.isEmpty)
                if let failure {Text(verbatim:failure).foregroundStyle(.secondary)}
            }
        }.navigationTitle("Introduction draft").toolbar{ToolbarItem(placement:.cancellationAction){Button("Close"){dismiss()}}}.onAppear{
            guard draft.isEmpty, let lead else{return}
            subject=String(localized:"Good to connect")
            draft=String(localized:"Hi") + " " + lead.name + ",\n\n" + String(localized:"It was good to meet you. I’d be glad to continue our conversation.")
        }}
    }
}
