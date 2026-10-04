import WidgetKit
import SwiftUI

struct CardEntry:TimelineEntry {let date:Date;let name:String;let title:String;let url:String}
struct CardProvider:TimelineProvider {
    func placeholder(in context:Context)->CardEntry{CardEntry(date:Date(),name:"TapLead",title:"",url:"")}
    func getSnapshot(in context:Context,completion:@escaping(CardEntry)->Void){completion(read())}
    func getTimeline(in context:Context,completion:@escaping(Timeline<CardEntry>)->Void){completion(Timeline(entries:[read()],policy:.after(Date().addingTimeInterval(3600))))}
    func read()->CardEntry{let defaults=UserDefaults(suiteName:"group.com.taplead.shared");return CardEntry(date:Date(),name:defaults?.string(forKey:"name") ?? "TapLead",title:defaults?.string(forKey:"title") ?? "",url:defaults?.string(forKey:"url") ?? "")}
}
struct CardWidgetView:View {
    var entry:CardEntry
    @Environment(\.widgetFamily) private var family
    var body:some View {HStack(spacing:16){if family != .systemSmall{VStack(alignment:.leading,spacing:8){Text("TapLead").font(.caption.bold()).foregroundStyle(.secondary);Text(verbatim:entry.name).font(.headline);Text(verbatim:entry.title).font(.caption);Text("Tap to connect").font(.caption).foregroundStyle(.secondary)}.privacySensitive();Spacer()};if !entry.url.isEmpty{QRView(value:entry.url).privacySensitive()}else{VStack{Image(systemName:"qrcode").font(.largeTitle);Text("Open my card").font(.caption)}}}.containerBackground(.background,for:.widget).widgetURL(URL(string:"taplead://qr"))}
}
@main struct TapLeadWidget:Widget {
    let kind="TapLeadCard"
    var body:some WidgetConfiguration{StaticConfiguration(kind:kind,provider:CardProvider()){CardWidgetView(entry:$0)}.configurationDisplayName("Your TapLead card").description("Keep your networking QR close at hand.").supportedFamilies([.systemSmall,.systemMedium,.systemLarge])}
}
