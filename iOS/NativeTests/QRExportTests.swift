import XCTest
import Vision
import UIKit
@testable import TapLead
import TapLeadCore

final class QRExportTests:XCTestCase {
    @MainActor func testBrandedAndPhotoQRRemainScannableAndPrintable() throws {
        let url=URL(string:"https://example.com/p/00000000-0000-4000-8000-000000000002?source=qr")!
        var card=Card();card.name="Alex — fictional QR test";card.customBackground="FFFFFF"
        let photo=UIGraphicsImageRenderer(size:CGSize(width:320,height:180)).image {context in
            UIColor.systemPurple.setFill();context.fill(CGRect(x:0,y:0,width:320,height:180))
        }
        for background in [nil,Optional(photo)] {
            let image=try XCTUnwrap(QRExport.image(card:card,url:url,photo:background))
            let request=VNDetectBarcodesRequest();request.symbologies=[.qr]
            try VNImageRequestHandler(cgImage:try XCTUnwrap(image.cgImage),options:[:]).perform([request])
            XCTAssertEqual(request.results?.first?.payloadStringValue,url.absoluteString)
            let pdf=QRExport.pdf(image:image)
            XCTAssertTrue(pdf.starts(with:Data("%PDF".utf8)))
            let document=try XCTUnwrap(CGPDFDocument(CGDataProvider(data:pdf as CFData)!))
            XCTAssertEqual(document.numberOfPages,1)
        }
    }
}
