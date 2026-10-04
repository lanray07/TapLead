import UIKit
import TapLeadCore

enum QRExport {
    @MainActor static func image(card:Card,url:URL,photo:UIImage? = nil)->UIImage? {
        guard let symbol=QRCode.image(url.absoluteString,scale:1)?.cgImage else{return nil}
        let size=CGSize(width:1024,height:1280)
        let format=UIGraphicsImageRendererFormat();format.scale=1;format.opaque=true
        return UIGraphicsImageRenderer(size:size,format:format).image { context in
            let cg=context.cgContext;cg.interpolationQuality = .none
            UIColor.white.setFill();cg.fill(CGRect(origin:.zero,size:size))
            if let photo {
                let scale=max(size.width/photo.size.width,620/photo.size.height)
                let rect=CGRect(x:(size.width-photo.size.width*scale)/2,y:(620-photo.size.height*scale)/2,width:photo.size.width*scale,height:photo.size.height*scale)
                cg.saveGState();cg.clip(to:CGRect(x:0,y:0,width:1024,height:620));photo.draw(in:rect);cg.restoreGState()
            } else {
                UIColor(ColorHex:card.customBackground ?? card.accent).setFill();cg.fill(CGRect(x:0,y:0,width:1024,height:620))
                let ink:UIColor=Validation.prefersDarkText(on:card.customBackground ?? card.accent) ? .black : .white
                draw(card.name,rect:CGRect(x:64,y:100,width:800,height:180),size:64,colour:ink)
                draw(card.title,rect:CGRect(x:64,y:300,width:800,height:140),size:38,colour:ink)
            }
            // Keep the symbol and its quiet zone untouched; branding sits outside it.
            let panel=CGRect(x:254,y:470,width:516,height:516)
            UIColor.white.setFill();cg.fill(panel)
            let available=panel.insetBy(dx:64,dy:64)
            let moduleScale=floor(available.width/CGFloat(symbol.width))
            let edge=CGFloat(symbol.width)*moduleScale
            let rect=CGRect(x:floor(panel.midX-edge/2),y:floor(panel.midY-edge/2),width:edge,height:edge)
            cg.saveGState();cg.interpolationQuality = .none;cg.setShouldAntialias(false)
            cg.translateBy(x:rect.minX,y:rect.maxY);cg.scaleBy(x:1,y:-1)
            cg.draw(symbol,in:CGRect(x:0,y:0,width:edge,height:edge));cg.restoreGState()
            draw(card.name,rect:CGRect(x:64,y:1020,width:896,height:90),size:44,colour:.black)
            draw(String(localized:"Scan to connect"),rect:CGRect(x:64,y:1130,width:896,height:70),size:32,colour:.darkGray)
        }
    }
    @MainActor static func pdf(image:UIImage)->Data {
        let bounds=CGRect(x:0,y:0,width:612,height:792)
        return UIGraphicsPDFRenderer(bounds:bounds).pdfData { context in
            context.beginPage();context.cgContext.interpolationQuality = .none
            image.draw(in:CGRect(x:42,y:66,width:528,height:660))
        }
    }
    private static func draw(_ text:String,rect:CGRect,size:CGFloat,colour:UIColor) {
        let paragraph=NSMutableParagraphStyle();paragraph.lineBreakMode = .byTruncatingTail
        (text as NSString).draw(in:rect,withAttributes:[.font:UIFont.systemFont(ofSize:size,weight:.semibold),.foregroundColor:colour,.paragraphStyle:paragraph])
    }
}
private extension UIColor {
    convenience init(ColorHex hex:String) {
        let n=UInt32(hex,radix:16) ?? 0x6654D9
        self.init(red:CGFloat((n>>16)&255)/255,green:CGFloat((n>>8)&255)/255,blue:CGFloat(n&255)/255,alpha:1)
    }
}
