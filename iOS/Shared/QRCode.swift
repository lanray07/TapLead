import SwiftUI
import UIKit
import CoreImage.CIFilterBuiltins

enum QRCode {
    static func image(_ value: String, scale: Int = 12) -> UIImage? {
        let filter=CIFilter.qrCodeGenerator();filter.message=Data(value.utf8);filter.correctionLevel="M"
        guard let output=filter.outputImage,let cg=CIContext().createCGImage(output.transformed(by:CGAffineTransform(scaleX:CGFloat(scale),y:CGFloat(scale))),from:output.extent.applying(CGAffineTransform(scaleX:CGFloat(scale),y:CGFloat(scale)))) else{return nil}
        return UIImage(cgImage:cg)
    }
}
struct QRView: View {
    var value: String
    var body: some View { Group {if let image=QRCode.image(value){Image(uiImage:image).interpolation(.none).resizable().scaledToFit().padding(20).background(.white,in:RoundedRectangle(cornerRadius:22))}else{Image(systemName:"qrcode").font(.largeTitle)}}.accessibilityLabel("Scan this QR code to open the selected card") }
}
