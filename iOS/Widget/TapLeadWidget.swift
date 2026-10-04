import WidgetKit
import SwiftUI

struct CardEntry:TimelineEntry {let date:Date;let name:String;let title:String;let url:String;var counts:WidgetCountSnapshot? = nil}
struct CardProvider:TimelineProvider {
    func placeholder(in context:Context)->CardEntry{CardEntry(date:Date(),name:"TapLead",title:"",url:"")}
    func getSnapshot(in context:Context,completion:@escaping(CardEntry)->Void){completion(read())}
    func getTimeline(in context:Context,completion:@escaping(Timeline<CardEntry>)->Void){
        let now = Date()
        let midnight = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now))!
        completion(Timeline(entries:[read(now), read(midnight)],policy:.after(midnight.addingTimeInterval(3600))))
    }
    func read(_ date:Date = Date())->CardEntry{
        let defaults=UserDefaults(suiteName:"group.com.taplead.shared")
        let snapshots = defaults?.data(forKey:"connectionCounts").flatMap { try? JSONDecoder().decode([WidgetCountSnapshot].self, from: $0) } ?? []
        let counts = snapshots.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
        return CardEntry(date:date,name:defaults?.string(forKey:"name") ?? "TapLead",title:defaults?.string(forKey:"title") ?? "",url:defaults?.string(forKey:"url") ?? "",counts:counts)
    }
}
struct CardWidgetView:View {
    var entry:CardEntry
    @Environment(\.widgetFamily) private var family
    var body:some View {
        VStack(spacing:16) {
            HStack(spacing:16){if family != .systemSmall{VStack(alignment:.leading,spacing:8){Text("TapLead").font(.caption.bold()).foregroundStyle(.secondary);Text(verbatim:entry.name).font(.headline);Text(verbatim:entry.title).font(.caption);Text("Tap to connect").font(.caption).foregroundStyle(.secondary)}.privacySensitive();Spacer()};if !entry.url.isEmpty{QRView(value:entry.url).privacySensitive()}else{VStack{Image(systemName:"qrcode").font(.largeTitle);Text("Open my card").font(.caption)}}}
            if family == .systemLarge {
                Divider()
                if let counts = entry.counts {
                    HStack(alignment:.top, spacing:16) {
                        VStack(alignment:.leading) { Text(counts.recent, format:.number).font(.title2.bold()); Text("Connections in 7 days").font(.caption) }
                        Spacer()
                        VStack(alignment:.leading) { Text(counts.due, format:.number).font(.title2.bold()); Text("Due today or overdue").font(.caption) }
                    }.privacySensitive()
                } else { Text("Open TapLead to refresh counts").font(.caption).foregroundStyle(.secondary) }
            }
        }.containerBackground(.background,for:.widget).widgetURL(URL(string:"taplead://qr"))
    }
}
@main struct TapLeadWidget:Widget {
    let kind="TapLeadCard"
    var body:some WidgetConfiguration{StaticConfiguration(kind:kind,provider:CardProvider()){CardWidgetView(entry:$0)}.configurationDisplayName("Your TapLead card").description("Keep your networking QR close at hand.").supportedFamilies([.systemSmall,.systemMedium,.systemLarge])}
}
