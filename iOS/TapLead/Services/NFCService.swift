import CoreNFC
import Observation
import Foundation

@MainActor @Observable final class NFCService:NSObject,NFCNDEFReaderSessionDelegate {
    var message=""
    var writing=false
    var available:Bool{NFCNDEFReaderSession.readingAvailable}
    private var session:NFCNDEFReaderSession?
    private var url:URL?
    func write(_ url:URL) {
        guard available else{message=String(localized:"NFC writing is unavailable on this device. Use your QR code instead.");return}
        self.url=url;writing=true
        session=NFCNDEFReaderSession(delegate:self,queue:nil,invalidateAfterFirstRead:false)
        session?.alertMessage=String(localized:"Hold the top of your iPhone near your writable NFC card.");session?.begin()
    }
    nonisolated func readerSession(_ session:NFCNDEFReaderSession,didInvalidateWithError error:Error){Task{@MainActor in self.writing=false;self.session=nil;if (error as? NFCReaderError)?.code != .readerSessionInvalidationErrorUserCanceled{self.message=error.localizedDescription}}}
    nonisolated func readerSession(_ session:NFCNDEFReaderSession,didDetectNDEFs messages:[NFCNDEFMessage]){}
    nonisolated func readerSession(_ session:NFCNDEFReaderSession,didDetect tags:[NFCNDEFTag]) {
        guard tags.count==1,let tag=tags.first else{session.alertMessage=String(localized:"Present one NFC tag at a time.");session.restartPolling();return}
        Task{@MainActor in
            guard let url=self.url,let payload=NFCNDEFPayload.wellKnownTypeURIPayload(url:url) else{session.invalidate(errorMessage:String(localized:"The profile link is invalid."));return}
            do {
                try await session.connect(to:tag)
                let (status,capacity)=try await tag.queryNDEFStatus()
                let ndef=NFCNDEFMessage(records:[payload])
                guard status == .readWrite,capacity>=ndef.length else{session.invalidate(errorMessage:String(localized:"This NFC tag is locked, unsupported or too small."));return}
                try await tag.writeNDEF(ndef)
                let readBack=try await tag.readNDEF()
                guard readBack.records.first?.wellKnownTypeURIPayload()==url else{session.invalidate(errorMessage:String(localized:"The NFC write could not be verified."));return}
                self.message=String(localized:"Your NFC card is ready. Test it with another compatible phone.");session.alertMessage=self.message;session.invalidate()
            }catch{session.invalidate(errorMessage:error.localizedDescription)}
        }
    }
}
