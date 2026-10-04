import SwiftUI

struct VoiceNoteView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var voice=VoiceService()
    var onSave:(String)->Void
    var body: some View {
        @Bindable var voice=voice
        NavigationStack {
            VStack(alignment:.leading,spacing:24) {
                Text("Keep the conversation.").font(.system(.largeTitle,design:.rounded,weight:.bold))
                Text("Record what matters, then review and edit before saving. Audio stays on your device and is not retained.").foregroundStyle(.secondary)
                Button{if voice.recording{voice.stop()}else{Task{await voice.start()}}}label:{VStack(spacing:12){Image(systemName:voice.recording ? "stop.circle.fill":"mic.circle.fill").font(.system(size:72));Text(voice.recording ? "Stop recording":"Start voice note").font(.headline)}.frame(maxWidth:.infinity,minHeight:140)}.accessibilityLabel(voice.recording ? "Stop recording":"Start voice note")
                Text("REVIEW TRANSCRIPTION").font(.caption.weight(.semibold)).tracking(1.5).foregroundStyle(.secondary)
                TextEditor(text:$voice.transcript).frame(minHeight:160).padding(12).background(Color(uiColor:.secondarySystemGroupedBackground),in:RoundedRectangle(cornerRadius:18)).accessibilityLabel("Editable voice transcription")
                if let error=voice.error{Text(verbatim:error).font(.caption).foregroundStyle(.red)}
                PrimaryButton(title:"Save reviewed note",icon:"checkmark"){voice.stop();onSave(voice.transcript.trimmingCharacters(in:.whitespacesAndNewlines));dismiss()}.disabled(voice.recording || voice.transcript.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
            }.padding(24).background(Palette.canvas).navigationTitle("Voice note").navigationBarTitleDisplayMode(.inline).toolbar{ToolbarItem(placement:.cancellationAction){Button("Cancel"){voice.stop();dismiss()}}}.onDisappear{voice.stop()}
        }
    }
}
