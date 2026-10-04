import CoreSpotlight
import UniformTypeIdentifiers
import TapLeadCore

enum SpotlightService {
    static func update(_ cards:[Card]) {
        // Index only public identity information, never leads or private notes.
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers:["com.taplead.cards"]) {error in
            guard error==nil else{return}
            let items=cards.filter(\.published).map{card in
                let attributes=CSSearchableItemAttributeSet(contentType:.url);attributes.title=card.name;attributes.contentDescription=[card.title,card.company].filter{!$0.isEmpty}.joined(separator:" · ")
                return CSSearchableItem(uniqueIdentifier:"taplead://card/\(card.id.uuidString)",domainIdentifier:"com.taplead.cards",attributeSet:attributes)
            }
            CSSearchableIndex.default().indexSearchableItems(items)
        }
    }
}
