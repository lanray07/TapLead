import Network
import Observation

@MainActor @Observable final class Connectivity {
    var online=true
    private let monitor=NWPathMonitor()
    init(store:AppStore){monitor.pathUpdateHandler={[weak store,weak self] path in let online=path.status == .satisfied;Task{@MainActor in self?.online=online;if online{await store?.synchronize()}}};monitor.start(queue:DispatchQueue(label:"com.taplead.connectivity"))}
    deinit{monitor.cancel()}
}
