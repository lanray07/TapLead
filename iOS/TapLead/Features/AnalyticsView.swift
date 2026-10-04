import SwiftUI
import Charts

struct AnalyticsView:View {
    @Environment(AppStore.self) private var store
    @State private var days=30
    @State private var response:AnalyticsResponse?
    @State private var failure:String?
    @State private var loading=false
    var events:[AnalyticsResponse.Event]{response?.events ?? []}
    var viewCount:Int{events.filter{$0.kind=="profile_view"}.count}
    var leadCount:Int{events.filter{$0.kind=="lead_submission"}.count}
    var body:some View {
        ScrollView {
            VStack(alignment:.leading,spacing:24) {
                if store.demo{DemoBanner()}
                Text("Know what\nopens doors.").font(.system(.largeTitle,design:.rounded,weight:.bold))
                Text("A clearer picture of your introductions.").foregroundStyle(.secondary)
                Picker("Date range",selection:$days){Text("7 days").tag(7);Text("30 days").tag(30);Text("90 days").tag(90);Text("All time").tag(0)}.pickerStyle(.segmented)
                if loading{ProgressView()}
                if let failure{ContentUnavailableView("Insights aren’t available yet",systemImage:"chart.xyaxis.line",description:Text(failure));Button("Retry"){Task{await load()}}}
                else if response != nil {
                    HStack{MetricTile(title:"Profile requests",value:viewCount,icon:"eye");MetricTile(title:"Lead submissions",value:leadCount,icon:"person.badge.plus")}
                    HStack{MetricTile(title:"vCard downloads",value:events.filter{$0.kind=="vcard_download"}.count,icon:"person.crop.rectangle");MetricTile(title:"Booking clicks",value:events.filter{$0.kind=="booking_click"}.count,icon:"calendar")}
                    HStack{MetricTile(title:"CTA clicks",value:events.filter{$0.kind=="cta_click"}.count,icon:"arrow.up.right");MetricTile(title:"QR requests",value:events.filter{$0.kind=="profile_view" && $0.source=="qr"}.count,icon:"qrcode")}
                    if viewCount>0 {VStack(alignment:.leading,spacing:8){Text("Lead conversion").font(.headline);Text(Double(leadCount)/Double(viewCount),format:.percent.precision(.fractionLength(1))).font(.title2.bold());Text("Lead submissions divided by measured profile requests. Requests are not unique people; repeated submissions can exceed 100%.").font(.caption).foregroundStyle(.secondary)}}
                    if events.isEmpty{ContentUnavailableView("Your story starts here",systemImage:"chart.bar",description:Text("Enable anonymous activity measurement on your published card. Events will appear as people interact."))}
                    else {Text("Profile activity").font(.title2.bold());Chart{ForEach(dailyCounts,id:\.date){point in BarMark(x:.value("Date",point.date,unit:.day),y:.value("Requests",point.count)).foregroundStyle(Palette.accent)}}.frame(height:180).accessibilityLabel("Measured profile requests by day");Text("Where connections begin").font(.title2.bold());ForEach(sourceCounts,id:\.source){point in HStack{Text(verbatim:point.source);Spacer();Text(point.count,format:.number)}}}
                    Text(response?.notice ?? "").font(.caption).foregroundStyle(.secondary)
                }
            }.padding(22)
        }.background(Palette.canvas).navigationTitle("Insights").navigationBarTitleDisplayMode(.inline).task(id:days){await load()}.refreshable{await load()}
    }
    var dailyCounts:[(date:Date,count:Int)]{Dictionary(grouping:events.filter{$0.kind=="profile_view"},by:{Calendar.current.startOfDay(for:$0.date)}).map{(date:$0.key,count:$0.value.count)}.sorted{$0.date<$1.date}}
    var sourceCounts:[(source:String,count:Int)]{Dictionary(grouping:events.filter{$0.kind=="profile_view"},by:{$0.source}).map{(source:$0.key,count:$0.value.count)}.sorted{$0.count>$1.count}}
    func load() async {guard store.authenticated,!store.demo else{failure=String(localized:"Sign in and publish a card to measure real profile activity.");return};loading=true;defer{loading=false};do{response=try await store.api.request("api/analytics?days=\(days)");failure=nil}catch{failure=error.localizedDescription}}
}
