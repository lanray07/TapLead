import PassKit
import SwiftUI

enum WalletService {
    static func loadSignedPass(from url:URL,token:String) async throws -> PKPass {
        guard url.scheme=="https",PKAddPassesViewController.canAddPasses() else{throw ServiceError.message(String(localized:"Apple Wallet is unavailable."))}
        var request=URLRequest(url:url);request.setValue("Bearer \(token)",forHTTPHeaderField:"Authorization")
        let (data,response)=try await URLSession.shared.data(for:request)
        guard let response=response as? HTTPURLResponse,response.statusCode==200,response.mimeType=="application/vnd.apple.pkpass",data.count<2_000_000 else{throw ServiceError.message(String(localized:"A signed Wallet pass could not be downloaded."))}
        return try PKPass(data:data)
    }
}
struct WalletPassSheet:UIViewControllerRepresentable {
    let pass:PKPass
    func makeUIViewController(context:Context)->UIViewController{PKAddPassesViewController(pass:pass) ?? UIViewController()}
    func updateUIViewController(_ controller:UIViewController,context:Context){}
}
