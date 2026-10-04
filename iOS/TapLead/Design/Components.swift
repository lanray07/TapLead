import SwiftUI
import UIKit
import TapLeadCore

enum Palette {
    static let accent = Color(red:0.36,green:0.28,blue:0.78)
    static let canvas = Color(uiColor:.systemGroupedBackground)
    static let ink = Color.primary
}
extension Color {
    init(hex:String){let n=UInt32(hex,radix:16) ?? 0x6654D9;self.init(red:Double((n>>16)&255)/255,green:Double((n>>8)&255)/255,blue:Double(n&255)/255)}
}
struct ThemeStyle {
    let background:Color
    let foreground:Color
    let design:Font.Design
    static func forCard(_ card:Card)->ThemeStyle{
        switch card.theme {
        case .minimal:return .init(background:Color(uiColor:.secondarySystemGroupedBackground),foreground:.primary,design:.default)
        case .executive:return .init(background:Color(hex:"292436"),foreground:.white,design:.default)
        case .creator:return .init(background:Color(hex:card.accent),foreground:.white,design:.rounded)
        case .bold:return .init(background:Color(hex:"EAD99A"),foreground:Color(hex:"282517"),design:.rounded)
        case .dark:return .init(background:Color(hex:"17191D"),foreground:.white,design:.monospaced)
        case .elegant:return .init(background:Color(hex:"EDE5DA"),foreground:Color(hex:"3A302A"),design:.serif)
        case .sales:return .init(background:Color(hex:"183D38"),foreground:.white,design:.default)
        case .consultant:return .init(background:Color(hex:"263C56"),foreground:.white,design:.default)
        }
    }
}
struct PrimaryButton: View {
    var title: LocalizedStringKey
    var icon: String = "arrow.right"
    var action: () -> Void
    var body: some View {
        Button(action:action) { HStack { Text(title); Spacer(); Image(systemName:icon) }.font(.headline).padding(18).frame(minHeight:52).foregroundStyle(.white).background(Palette.accent,in:RoundedRectangle(cornerRadius:18)) }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}
struct Avatar: View {
    var name: String; var data: Data? = nil; var size: CGFloat = 54
    var body: some View {
        Group {
            if let data, let image=UIImage(data:data) { Image(uiImage:image).resizable().scaledToFill() }
            else { Text(name.isEmpty ? "TL" : name.split(separator:" ").prefix(2).compactMap(\.first).map(String.init).joined()).font(.system(size:size*0.32,weight:.semibold)).foregroundStyle(Palette.accent).frame(maxWidth:.infinity,maxHeight:.infinity).background(Palette.accent.opacity(0.10)) }
        }.frame(width:size,height:size).clipShape(RoundedRectangle(cornerRadius:size*0.3)).accessibilityHidden(true)
    }
}
struct CardPreview: View {
    var card: Card
    var style:ThemeStyle{ThemeStyle.forCard(card)}
    var body: some View {
        VStack(alignment:.leading,spacing:24) {
            HStack(alignment:.top,spacing:16) {
                if card.imageCorner.isTop && card.imageCorner.isLeading { cornerImage }
                VStack(alignment:.leading,spacing:8) {
                    Label("TapLead",systemImage:"square.on.square").font(.headline)
                    Text(verbatim:card.persona).font(.caption).padding(.horizontal,12).padding(.vertical,7).background(style.foreground.opacity(0.13),in:Capsule())
                }.frame(maxWidth:.infinity,alignment:.leading)
                if card.imageCorner.isTop && !card.imageCorner.isLeading { cornerImage }
            }
            Spacer(minLength:12)
            VStack(alignment:.leading,spacing:6) {
                Text(card.name.isEmpty ? String(localized:"Your name") : card.name).font(.system(.title,design:style.design,weight:.bold))
                Text(card.title.isEmpty ? String(localized:"Your next introduction starts here.") : card.title).font(.subheadline).opacity(0.8)
                if !card.company.isEmpty { Text(verbatim:card.company).font(.caption).opacity(0.65) }
            }
            Divider().overlay(.white.opacity(0.15))
            HStack(alignment:.bottom,spacing:16) {
                if !card.imageCorner.isTop && card.imageCorner.isLeading { cornerImage }
                Text(card.headline.isEmpty ? String(localized:"Tap. Connect. Convert.") : card.headline).font(.caption).frame(maxWidth:.infinity,alignment:.leading)
                if !card.imageCorner.isTop && !card.imageCorner.isLeading { cornerImage }
                else { Image(systemName:"arrow.up.right").accessibilityHidden(true) }
            }
        }.padding(26).foregroundStyle(style.foreground).background(style.background,in:RoundedRectangle(cornerRadius:28))
        .accessibilityElement(children:.combine)
    }
    @ViewBuilder private var cornerImage: some View {
        switch card.imageKind {
        case .none: EmptyView()
        case .photo: Avatar(name:card.name,data:card.photoData,size:68)
        case .logo:
            if let data=card.logoData,let image=UIImage(data:data) {
                Image(uiImage:image).resizable().scaledToFit().padding(6)
                    .frame(width:68,height:68).background(.white,in:RoundedRectangle(cornerRadius:14))
                    .accessibilityHidden(true)
            }
        }
    }
}
struct MetricTile: View {
    var title: LocalizedStringKey; var value: Int; var icon: String
    var body: some View { VStack(alignment:.leading,spacing:14) { Image(systemName:icon).foregroundStyle(Palette.accent); Text(value,format:.number).font(.system(.largeTitle,design:.rounded,weight:.semibold)); Text(title).font(.caption).foregroundStyle(.secondary) }.frame(maxWidth:.infinity,alignment:.leading).padding(20).background(Color(uiColor:.secondarySystemGroupedBackground),in:RoundedRectangle(cornerRadius:22)).accessibilityElement(children:.combine) }
}
struct LeadRow: View {
    var lead: Lead
    var body: some View { HStack(spacing:14) { Avatar(name:lead.name); VStack(alignment:.leading,spacing:5) { Text(verbatim:lead.name).font(.headline); Text(verbatim:lead.company.isEmpty ? lead.context : lead.company).font(.caption).foregroundStyle(.secondary).lineLimit(2); if let date=lead.followUp { Label { Text(date,style:.date) } icon:{ Image(systemName:"clock") }.font(.caption).foregroundStyle(Palette.accent) } }; Spacer(); Image(systemName:"chevron.right").font(.caption).foregroundStyle(.tertiary) }.padding(.vertical,8).accessibilityElement(children:.combine) }
}
struct DemoBanner: View {
    var body: some View { Label("Demo · sample connections",systemImage:"sparkle").font(.caption.weight(.medium)).foregroundStyle(Palette.accent).padding(10).frame(maxWidth:.infinity).background(Palette.accent.opacity(0.08),in:RoundedRectangle(cornerRadius:12)) }
}
