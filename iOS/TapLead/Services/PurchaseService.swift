import StoreKit
import Observation

private final class TransactionObserver {
    var task:Task<Void,Never>?
    deinit{task?.cancel()}
}

@MainActor @Observable final class PurchaseService {
    var products:[Product]=[]
    var pro=false
    var purchasesEnabled=false
    var error:String?
    @ObservationIgnored private let observer=TransactionObserver()
    private let ids=["com.taplead.pro.monthly","com.taplead.pro.yearly"]
    init(){observer.task=Task{[weak self] in for await update in Transaction.updates{guard let self else{return};if case .verified(let transaction)=update{do{let _:PlanResponse=try await APIClient().send("api/subscription",method:"POST",value:["signedTransaction":update.jwsRepresentation]);await self.refresh();await transaction.finish()}catch{self.error=error.localizedDescription}}}}}
    func load() async {do{let plan:PlanResponse=try await APIClient().request("api/plan");purchasesEnabled=plan.purchasesEnabled ?? false;pro=plan.pro;products=try await Product.products(for:ids)}catch{self.error=error.localizedDescription}}
    func refresh() async {do{let plan:PlanResponse=try await APIClient().request("api/plan");pro=plan.pro;purchasesEnabled=plan.purchasesEnabled ?? false}catch{self.error=error.localizedDescription}}
    func buy(_ product:Product) async {
        guard purchasesEnabled,let id=UserDefaults.standard.string(forKey:"TapLeadUserID"),let accountToken=UUID(uuidString:id) else{error=String(localized:"Sign in before purchasing TapLead Pro.");return}
        do{switch try await product.purchase(options:[.appAccountToken(accountToken)]){case .success(let result):guard case .verified(let transaction)=result else{throw ServiceError.message(String(localized:"This purchase could not be verified."))};let _:PlanResponse=try await APIClient().send("api/subscription",method:"POST",value:["signedTransaction":result.jwsRepresentation]);await refresh();await transaction.finish();case .pending:error=String(localized:"Your purchase is awaiting approval.");case .userCancelled:break;@unknown default:break}}catch{self.error=error.localizedDescription}
    }
    func restore() async {do{try await StoreKit.AppStore.sync();for await result in Transaction.currentEntitlements{if case .verified(let transaction)=result,ids.contains(transaction.productID){let _:PlanResponse=try await APIClient().send("api/subscription",method:"POST",value:["signedTransaction":result.jwsRepresentation])}};await refresh()}catch{self.error=error.localizedDescription}}
}
