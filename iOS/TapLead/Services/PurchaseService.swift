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
    var requiresSignIn=false
    var loadingProducts=false
    var checkingAccount=false
    var busy=false
    var productError:String?
    var accountError:String?
    var error:String?
    @ObservationIgnored private let observer=TransactionObserver()
    @ObservationIgnored private let fetchProducts:([String]) async throws -> [Product]
    @ObservationIgnored private let fetchPlan:() async throws -> PlanResponse
    @ObservationIgnored private var planGeneration=0
    private let ids=["com.taplead.pro.monthly","com.taplead.pro.yearly"]
    init(fetchProducts:@escaping ([String]) async throws -> [Product] = {try await Product.products(for:$0)},
         fetchPlan:@escaping () async throws -> PlanResponse = {try await APIClient().request("api/plan")}) {
        self.fetchProducts=fetchProducts
        self.fetchPlan=fetchPlan
        observer.task=Task{[weak self] in for await update in Transaction.updates{guard let self else{return};if case .verified(let transaction)=update{do{let _:PlanResponse=try await APIClient().send("api/subscription",method:"POST",value:["signedTransaction":update.jwsRepresentation]);await self.refresh();await transaction.finish()}catch{self.error=error.localizedDescription}}}}
    }
    func load() async {
        // StoreKit's public catalog must not depend on a TapLead account/session.
        async let account:Void=refresh()
        await loadProducts()
        await account
    }
    func loadProducts() async {
        guard !loadingProducts else{return}
        loadingProducts=true;productError=nil
        defer{loadingProducts=false}
        do {
            let loaded=try await fetchProducts(ids)
            products=ids.compactMap{id in loaded.first{$0.id==id}}
            if products.isEmpty {productError=String(localized:"Subscription plans could not be loaded. Check your connection and try again.")}
            else if products.count != ids.count {productError=String(localized:"Some subscription plans are unavailable. Try again shortly.")}
        } catch is CancellationError {
            // A dismissed sheet cancels its request; reopening starts a fresh load.
        } catch {
            productError=String(localized:"Subscription plans could not be loaded. Check your connection and try again.")
        }
    }
    func refresh() async {
        planGeneration += 1
        let generation=planGeneration
        checkingAccount=true
        defer{if generation==planGeneration{checkingAccount=false}}
        do {
            let plan=try await fetchPlan()
            guard generation==planGeneration else{return}
            pro=plan.pro;purchasesEnabled=plan.purchasesEnabled ?? false
            requiresSignIn=false;accountError=nil
        } catch is CancellationError {
        } catch {
            guard generation==planGeneration else{return}
            // Fail closed for buying/entitlements, while keeping the catalog visible.
            purchasesEnabled=false;pro=false
            if case ServiceError.response(status:401,message:_) = error {
                requiresSignIn=true
                accountError=String(localized:"Sign in with Apple again to continue.")
            } else {
                accountError=String(localized:"The service is temporarily unavailable. Try again shortly.")
            }
        }
    }
    func buy(_ product:Product) async {
        guard !busy else{return}
        guard !requiresSignIn,purchasesEnabled,let id=UserDefaults.standard.string(forKey:"TapLeadUserID"),let accountToken=UUID(uuidString:id) else{error=String(localized:"Sign in before purchasing TapLead Pro.");return}
        busy=true;error=nil;defer{busy=false}
        do{switch try await product.purchase(options:[.appAccountToken(accountToken)]){case .success(let result):guard case .verified(let transaction)=result else{throw ServiceError.message(String(localized:"This purchase could not be verified."))};let _:PlanResponse=try await APIClient().send("api/subscription",method:"POST",value:["signedTransaction":result.jwsRepresentation]);await refresh();await transaction.finish();case .pending:error=String(localized:"Your purchase is awaiting approval.");case .userCancelled:break;@unknown default:break}}catch{self.error=error.localizedDescription}
    }
    func restore() async {
        guard !busy else{return}
        guard !requiresSignIn,Keychain.token() != nil else{error=String(localized:"Sign in before purchasing TapLead Pro.");return}
        busy=true;error=nil;defer{busy=false}
        do{try await StoreKit.AppStore.sync();for await result in Transaction.currentEntitlements{if case .verified(let transaction)=result,ids.contains(transaction.productID){let _:PlanResponse=try await APIClient().send("api/subscription",method:"POST",value:["signedTransaction":result.jwsRepresentation])}};await refresh()}catch{self.error=error.localizedDescription}
    }
}
