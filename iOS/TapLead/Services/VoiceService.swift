import Foundation
import Speech
import AVFoundation
import Observation

@MainActor @Observable final class VoiceService {
    var transcript=""
    var recording=false
    var error: String?
    private let engine=AVAudioEngine()
    private var task:SFSpeechRecognitionTask?
    private var request:SFSpeechAudioBufferRecognitionRequest?
    private var tapInstalled=false
    func start() async {
        guard !recording else{return}
        let authorized=await withCheckedContinuation { continuation in SFSpeechRecognizer.requestAuthorization{continuation.resume(returning:$0 == .authorized)} }
        let microphone=await withCheckedContinuation { continuation in AVAudioSession.sharedInstance().requestRecordPermission{continuation.resume(returning:$0)} }
        guard authorized,microphone else{error=String(localized:"Allow microphone and speech access in iPhone Settings to record a voice note.");return}
        guard let recognizer=SFSpeechRecognizer(locale:.current),recognizer.isAvailable,recognizer.supportsOnDeviceRecognition else{error=String(localized:"On-device speech recognition is unavailable for this language or device. You can type your note instead.");return}
        do {
            stop();transcript=""
            let session=AVAudioSession.sharedInstance();try session.setCategory(.record,mode:.measurement,options:.duckOthers);try session.setActive(true)
            let request=SFSpeechAudioBufferRecognitionRequest();request.requiresOnDeviceRecognition=true;request.shouldReportPartialResults=true;self.request=request
            let input=engine.inputNode,format=input.outputFormat(forBus:0)
            guard format.sampleRate>0,format.channelCount>0 else{throw ServiceError.message(String(localized:"The microphone is unavailable."))}
            input.installTap(onBus:0,bufferSize:1024,format:format){buffer,_ in request.append(buffer)};tapInstalled=true
            task=recognizer.recognitionTask(with:request){[weak self] result,error in
                let text=result?.bestTranscription.formattedString,isFinal=result?.isFinal ?? false,errorText=error?.localizedDescription
                Task{@MainActor in guard let self else{return};if let text{self.transcript=text};if let errorText{self.error=errorText};if isFinal || errorText != nil{self.stop()}}
            }
            engine.prepare();try engine.start();recording=true
        }catch{stop();self.error=error.localizedDescription}
    }
    func stop() {
        engine.stop();if tapInstalled{engine.inputNode.removeTap(onBus:0);tapInstalled=false}
        request?.endAudio();task?.cancel();task=nil;request=nil;recording=false
        try? AVAudioSession.sharedInstance().setActive(false,options:.notifyOthersOnDeactivation)
    }
}
