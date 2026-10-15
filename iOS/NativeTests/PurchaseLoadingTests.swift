import XCTest
import StoreKit
import StoreKitTest
@testable import TapLead

@MainActor final class PurchaseLoadingTests:XCTestCase {
    private var session:SKTestSession!
    override func setUpWithError() throws {
        let url=try XCTUnwrap(Bundle(for:Self.self).url(forResource:"TapLead",withExtension:"storekit"))
        session=try SKTestSession(contentsOf:url)
        session.disableDialogs=true
        session.clearTransactions()
    }
    override func tearDownWithError() throws {session=nil}
    private var freePlan:PlanResponse {PlanResponse(pro:false,cardLimit:1,leadLimit:50,purchasesEnabled:true)}

    func testExpiredSessionStillLoadsBothStoreKitPlans() async {
        let service=PurchaseService(fetchPlan:{throw ServiceError.response(status:401,message:"Sign in again to continue.")})
        await service.load()
        XCTAssertEqual(service.products.map(\.id),["com.taplead.pro.monthly","com.taplead.pro.yearly"])
        XCTAssertTrue(service.products.allSatisfy{!$0.displayPrice.isEmpty})
        XCTAssertTrue(service.requiresSignIn)
        XCTAssertFalse(service.purchasesEnabled)
        XCTAssertFalse(service.pro)
        XCTAssertNil(service.productError)
        XCTAssertFalse(service.loadingProducts)
    }
    func testBackendFailureDoesNotHideStoreKitPlans() async {
        let service=PurchaseService(fetchPlan:{throw URLError(.cannotConnectToHost)})
        await service.load()
        XCTAssertEqual(service.products.count,2)
        XCTAssertNotNil(service.accountError)
        XCTAssertNil(service.productError)
        XCTAssertFalse(service.purchasesEnabled)
        XCTAssertFalse(service.pro)
    }
    func testEmptyCatalogCanBeRetried() async {
        var calls=0
        let service=PurchaseService(fetchProducts:{ids in calls += 1;return calls==1 ? [] : try await Product.products(for:ids)},fetchPlan:{self.freePlan})
        await service.load()
        XCTAssertTrue(service.products.isEmpty)
        XCTAssertNotNil(service.productError)
        await service.loadProducts()
        XCTAssertEqual(service.products.count,2)
        XCTAssertNil(service.productError)
    }
    func testStoreKitErrorCanBeRetried() async {
        var calls=0
        let service=PurchaseService(fetchProducts:{ids in
            calls += 1
            if calls==1 {throw URLError(.notConnectedToInternet)}
            return try await Product.products(for:ids)
        },fetchPlan:{self.freePlan})
        await service.load()
        XCTAssertNotNil(service.productError)
        XCTAssertFalse(service.loadingProducts)
        await service.loadProducts()
        XCTAssertEqual(service.products.count,2)
        XCTAssertNil(service.productError)
    }
    func testSignInRefreshClearsExpiredSessionState() async {
        var signedIn=false
        let service=PurchaseService(fetchPlan:{
            guard signedIn else{throw ServiceError.response(status:401,message:"Sign in required")}
            return self.freePlan
        })
        await service.load()
        XCTAssertTrue(service.requiresSignIn)
        signedIn=true
        await service.load()
        XCTAssertFalse(service.requiresSignIn)
        XCTAssertTrue(service.purchasesEnabled)
        XCTAssertNil(service.accountError)
        XCTAssertEqual(service.products.count,2)
        XCTAssertFalse(service.pro,"Catalog availability alone never grants Pro")
    }
    func testLateExpiredSessionResponseCannotOverwriteSuccessfulSignIn() async {
        var pending:CheckedContinuation<PlanResponse,Error>?
        var calls=0
        let service=PurchaseService(fetchPlan:{
            calls += 1
            if calls==1 {return try await withCheckedThrowingContinuation{pending=$0}}
            return self.freePlan
        })
        let oldRequest=Task{await service.refresh()}
        while pending==nil {await Task.yield()}
        await service.refresh()
        pending?.resume(throwing:ServiceError.response(status:401,message:"Old session"))
        await oldRequest.value
        XCTAssertTrue(service.purchasesEnabled)
        XCTAssertFalse(service.requiresSignIn)
        XCTAssertNil(service.accountError)
    }
}
