import Foundation
import AVFoundation
import AVKit
import AppKit
import CoreAudio
import AudioToolbox
import RealtimeAudio

enum VocalRoom: String, CaseIterable, Identifiable {
 case dry = "关闭", room = "小房间", hall = "大厅"
 var id: Self { self }
}

struct AudioFailure: LocalizedError { let message:String;var errorDescription:String?{message} }
@MainActor final class AudioController: ObservableObject {
 @Published var devices=[AudioDevice]()
 @Published private(set) var inputID: AudioDeviceID = 0
 @Published private(set) var outputID: AudioDeviceID = 0
 @Published private(set) var microphoneOn = false
 @Published private(set) var micRequested = false
 @Published private(set) var requestingPermission = false
 @Published private(set) var monitorOn = false
 @Published var micVolume: Float = 0.25 {
  didSet {
   updateMonitorLevel()
   UserDefaults.standard.set(micVolume, forKey: "micVolume")
  }
 }
 @Published var room: VocalRoom = .dry {
  didSet {
   if room != oldValue { updateRoom() }
   UserDefaults.standard.set(room.rawValue, forKey: "vocalRoom")
  }
 }
 @Published var roomMix: Float = 18 {
  didSet {
   reverb?.wetDryMix = room == .dry ? 0 : roomMix
   UserDefaults.standard.set(roomMix, forKey: "roomMix")
  }
 }
 @Published var echoMix: Float = 0 {
  didSet {
   delay?.wetDryMix = echoMix
   UserDefaults.standard.set(echoMix, forKey: "echoMix")
  }
 }
 @Published var echoTime: Double = 0.14 {
  didSet {
   delay?.delayTime = echoTime
   UserDefaults.standard.set(echoTime, forKey: "echoTime")
  }
 }
 @Published var musicVolume:Float=0.65 { didSet { player.volume=musicVolume;UserDefaults.standard.set(musicVolume,forKey:"musicVolume") } }
 @Published private(set) var stableMode = false
 @Published var isPlaying=false
 @Published var elapsed:Double=0
 @Published var duration:Double=0
 @Published var level:Float=0
 @Published var midi:Double?
 @Published var message=""
 @Published var score=0
 @Published var tracker=SingingTracker()
 @Published var singingHint="开启麦克风，显示你的演唱"
 @Published var latestLineScore:String?
 @Published var current:Song?
 let video=AVPlayer()
 var onEnded:(()->Void)?
 private var output=AVAudioEngine(),capture:AVAudioEngine?
 private var player=AVAudioPlayerNode(),voiceMixer:AVAudioMixerNode?
 private var ring:OpaquePointer=qc_create()!
 private var source:AVAudioSourceNode?
 private var file:AVAudioFile?
 private var offset:Double=0
 private var generation=0
 private var savedBuffers = [AudioDeviceID: (uid: String, original: UInt32, applied: UInt32)]()
 private var deviceListeners: [(AudioObjectID, AudioObjectPropertyAddress)] = []
 private var routeListener: AudioObjectPropertyListenerBlock?
 private var engineObserver: NSObjectProtocol?
 private var inputUID: String?
 private var outputUID: String?
 private var permissionRequest = UUID()
 private var outputRoute: OutputRoute?
 private var shuttingDown = false
 private var delay: AVAudioUnitDelay?
 private var reverb: AVAudioUnitReverb?
 private var timer:Timer?
 private var refreshCounter=0
 private var selectedAudioURL:URL?
 private var captureRate:Double=48000
 private func snapshot(){
  let dir=FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("轻唱")
  try? FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true)
  let state:[String:Any]=["song":current?.title ?? "","artist":current?.artist ?? "","playing":isPlaying,"elapsed":elapsed,"duration":duration,"input":inputName,"output":outputName,"microphone":microphoneOn,"monitorEnabled":monitorOn,"microphoneRequested":micRequested,"headphoneMonitorAvailable":headphoneMonitorAvailable,"vocalRoom":room.rawValue,"roomMix":roomMix,"echoMix":echoMix,"echoTime":echoTime,"inputEngineRunning":capture?.isRunning ?? false,"outputEngineRunning":output.isRunning,"inputFrames":Devices.scalar(inputID,kAudioDevicePropertyBufferFrameSize,UInt32(0)),"outputFrames":Devices.scalar(outputID,kAudioDevicePropertyBufferFrameSize,UInt32(0)),"microphoneLevel":level,"outputReportedLatency":output.isRunning ? output.outputNode.presentationLatency:0,"message":message,"pitchMIDI":midi as Any? ?? NSNull(),"singingHint":singingHint,"scoredFrames":tracker.evaluated,"voicedFrames":tracker.voiced,"tracePoints":tracker.trace.count,"lastLine":latestLineScore ?? "","liveAccuracy":tracker.accuracy,"singingCoverage":tracker.coverage,"totalScore":tracker.score as Any? ?? NSNull()]
  if let data=try? JSONSerialization.data(withJSONObject:state,options:[.prettyPrinted,.sortedKeys]){try? data.write(to:dir.appendingPathComponent("session.json"),options:.atomic)}
 }
 init() {
  devices = Devices.list()
  let prefs = UserDefaults.standard
  inputUID = prefs.string(forKey: "inputUID")
  outputUID = prefs.string(forKey: "outputUID")
  if let inputUID {
   inputID = inputs.first { $0.uid == inputUID }?.id ?? 0
  } else if let preferred = inputs.first(where: { $0.name.localizedCaseInsensitiveContains("DJI") }) ?? inputs.first(where: { $0.id == Devices.defaultInput() }) {
   rememberInput(preferred)
  }
  outputID = resolvedOutput()
  outputRoute = Devices.route(outputID)
  if prefs.object(forKey: "micVolume") != nil { micVolume = min(0.5, max(0, prefs.float(forKey: "micVolume"))) }
  if prefs.object(forKey: "musicVolume") != nil { musicVolume = min(1, max(0, prefs.float(forKey: "musicVolume"))) }
  stableMode = prefs.bool(forKey: "stableMode")
  room = VocalRoom(rawValue: prefs.string(forKey: "vocalRoom") ?? "") ?? .dry
  if prefs.object(forKey: "roomMix") != nil { roomMix = min(35, max(0, prefs.float(forKey: "roomMix"))) }
  echoMix = min(30, max(0, prefs.float(forKey: "echoMix")))
  if prefs.object(forKey: "echoTime") != nil { echoTime = min(0.28, max(0.07, prefs.double(forKey: "echoTime"))) }
  video.isMuted = true
  routeListener = { [weak self] _, _ in
   // Core Audio delivers this block on the main queue.
   MainActor.assumeIsolated {
    self?.muteMonitor()
    self?.refreshDevices()
   }
  }
  watchRoute()
  engineObserver = NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: nil, queue: nil) { [weak self] note in
   guard let engine = note.object as? AVAudioEngine else { return }
   Task { @MainActor in
    guard let self, !self.shuttingDown else { return }
    if engine === self.output {
     self.muteMonitor()
     self.refreshDevices()
    } else if engine === self.capture {
     self.muteMonitor()
     self.refreshDevices()
    }
   }
  }
  let tickTimer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in Task { @MainActor in self?.tick() } }
  RunLoop.main.add(tickTimer, forMode: .common)
  timer = tickTimer
 }
 var inputs: [AudioDevice] { devices.filter { $0.inputs > 0 } }
 var outputs: [AudioDevice] { devices.filter { $0.outputs > 0 } }
 var inputName: String {
  inputs.first { $0.id == inputID }?.name ?? ((UserDefaults.standard.string(forKey: "inputDeviceName") ?? "麦克风") + "（未连接）")
 }
 var outputName: String { outputs.first { $0.id == outputID }?.name ?? "无可用输出" }
 var permissionDenied: Bool {
  let status = AVCaptureDevice.authorizationStatus(for: .audio)
  return status == .denied || status == .restricted
 }
 var micButtonTitle: String {
  if requestingPermission { return "等待授权" }
  if microphoneOn { return "关闭收音" }
  if micRequested { return "取消等待" }
  return "开启收音"
 }
 var monitorRoute: OutputRoute? { headphoneMonitorAvailable ? outputRoute : nil }
 var headphoneMonitorAvailable: Bool { outputRoute?.allowsHeadphones == true && (outputUID == nil || outputs.first { $0.id == outputID }?.uid == outputUID) }
 var outputUnavailable: Bool { outputUID != nil && outputs.first { $0.id == outputID }?.uid != outputUID }
 var outputSelection: AudioDeviceID { outputUID == nil ? 0 : (outputUnavailable ? AudioObjectID.max : outputID) }
 var latencyText: String {
  let frames = Devices.scalar(outputID, kAudioDevicePropertyBufferFrameSize, UInt32(0))
  guard frames > 0 else { return "" }
  guard output.isRunning else { return "\(frames) 帧" }
  let latency = output.outputNode.presentationLatency
  return latency.isFinite ? "\(frames) 帧 · 输出设备报告 \(Int(max(0, latency) * 1000)) ms" : "\(frames) 帧"
 }
 private func resolvedOutput() -> AudioDeviceID {
  if let outputUID, let device = outputs.first(where: { $0.uid == outputUID }) { return device.id }
  return Devices.defaultOutput()
 }
 private func rememberInput(_ device: AudioDevice) {
  inputUID = device.uid
  inputID = device.id
  UserDefaults.standard.set(device.uid, forKey: "inputUID")
  UserDefaults.standard.set(device.name, forKey: "inputDeviceName")
 }
 func selectInput(_ id: AudioDeviceID) {
  guard let device = inputs.first(where: { $0.id == id }), device.uid != inputUID else { return }
  cancelPermissionRequest()
  muteMonitor()
  stopCapture()
  rememberInput(device)
  if micRequested { resumeCapture() } else { message = "" }
 }
 func selectOutput(_ id: AudioDeviceID) {
  guard id == 0 || outputs.contains(where: { $0.id == id }) else { return }
  outputUID = outputs.first { $0.id == id }?.uid
  UserDefaults.standard.set(outputUID, forKey: "outputUID")
  refreshDevices()
 }
 func selectStableMode(_ stable: Bool) {
  guard stable != stableMode else { return }
  stableMode = stable
  UserDefaults.standard.set(stable, forKey: "stableMode")
  rebuildOutput()
 }
 private func watchRoute() {
  guard let routeListener else { return }
  for (id, var address) in deviceListeners {
   AudioObjectRemovePropertyListenerBlock(id, &address, .main, routeListener)
  }
  deviceListeners.removeAll()
  guard !shuttingDown else { return }
  let system = AudioObjectID(kAudioObjectSystemObject)
  let selectors = [(system, Devices.address(kAudioHardwarePropertyDevices)),
                   (system, Devices.address(kAudioHardwarePropertyDefaultOutputDevice)),
                   (outputID, Devices.address(kAudioDevicePropertyDataSource, kAudioDevicePropertyScopeOutput)),
                   (outputID, Devices.address(kAudioDevicePropertyJackIsConnected, kAudioDevicePropertyScopeOutput)),
                   (outputID, Devices.address(kAudioDevicePropertyNominalSampleRate))]
  for (id, var address) in selectors where id != 0 && AudioObjectHasProperty(id, &address) {
   if AudioObjectAddPropertyListenerBlock(id, &address, .main, routeListener) == noErr {
    deviceListeners.append((id, address))
   }
  }
 }
 func refreshDevices() {
  guard !shuttingDown else { return }
  let next = Devices.list()
  if next != devices { devices = next }
  let input = inputs.first { $0.uid == inputUID }
  let nextInput = input?.id ?? 0
  let nextOutput = resolvedOutput()
  let nextRoute = Devices.route(nextOutput)
  let inputChanged = nextInput != inputID
  let outputChanged = nextOutput != outputID || nextRoute != outputRoute
  let captureStopped = microphoneOn && (capture?.isRunning != true || Devices.currentDevice(capture?.inputNode.audioUnit) != inputID)
  let playbackStopped = isPlaying && !output.isRunning
  if inputChanged || captureStopped {
   muteMonitor()
   stopCapture()
   cancelPermissionRequest()
   inputID = nextInput
   message = nextInput == 0 ? "麦克风已断开" : ""
  }
  if outputChanged {
   muteMonitor()
   outputID = nextOutput
   outputRoute = nextRoute
   watchRoute()
  }
  if outputChanged || playbackStopped {
   rebuildOutput()
  } else if (inputChanged || captureStopped) && micRequested && nextInput != 0 {
   resumeCapture()
  }
  if outputUnavailable { message = "所选输出已断开，音乐暂用系统输出" }
 }
 private func updateRoom() {
  guard let reverb else { return }
  if room == .dry { reverb.wetDryMix = 0; return }
  reverb.loadFactoryPreset(room == .room ? .smallRoom : .mediumHall)
  reverb.wetDryMix = roomMix
 }
 private func updateMonitorLevel() {
  voiceMixer?.outputVolume = microphoneOn && monitorOn && headphoneMonitorAvailable ? min(0.5, max(0, micVolume)) : 0
 }
 private func check(_ status:OSStatus,_ task:String)throws { if status != noErr {throw AudioFailure(message:task+"未能完成（\(status)），请重新选择设备")} }
 private func device(_ unit:AudioUnit?,_ id:AudioDeviceID)throws { guard let unit,id != 0 else{throw AudioFailure(message:"音频设备未连接")};var v=id;try check(AudioUnitSetProperty(unit,kAudioOutputUnitProperty_CurrentDevice,kAudioUnitScope_Global,0,&v,4),"切换音频设备") }
 private func lease(_ id: AudioDeviceID) {
  guard savedBuffers[id] == nil, let device = devices.first(where: { $0.id == id }),
        let original = Devices.setBuffer(id, stableMode ? 512 : 128) else { return }
  let applied = Devices.scalar(id, kAudioDevicePropertyBufferFrameSize, original)
  savedBuffers[id] = (device.uid, original, applied)
 }
 private func releaseBuffers() {
  for (id, buffer) in savedBuffers where Devices.string(id, kAudioDevicePropertyDeviceUID) == buffer.uid {
   if Devices.scalar(id, kAudioDevicePropertyBufferFrameSize, UInt32(0)) == buffer.applied {
    Devices.restoreBuffer(id, buffer.original)
   }
  }
  savedBuffers.removeAll()
 }
 private func makeOutput()throws {
  guard !output.isRunning else{return}
  if source != nil { destroyOutput() }
  let outDevice=outputs.first{$0.id==outputID};let rate=outDevice?.rate ?? 48000
  guard rate.isFinite, rate > 0 else { throw AudioFailure(message: "输出采样率不可用") }
  lease(outputID);try device(output.outputNode.audioUnit,outputID)
  // Apple's room reverb requires a stereo processing bus.
  let vocalFormat = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2)!
  let captureWasRunning = capture?.isRunning == true
  if captureWasRunning { capture?.pause() }
  qc_reset(ring, captureWasRunning ? captureRate : rate, rate)
  let ptr=ring
  let s=AVAudioSourceNode(format:vocalFormat){_,_,count,list in
   let buffers=UnsafeMutableAudioBufferListPointer(list)
   guard let first=buffers.first,let data=first.mData else{return noErr}
   qc_render(ptr,data.assumingMemoryBound(to:Float.self),count)
   for b in buffers.dropFirst(){if let dst=b.mData {memcpy(dst,data,Int(count)*MemoryLayout<Float>.size)}}
   return noErr
  }
  let mixer = AVAudioMixerNode()
  let echo = AVAudioUnitDelay()
  let ambience = AVAudioUnitReverb()
  voiceMixer = mixer
  delay = echo
  reverb = ambience
  source = s
  echo.delayTime = echoTime
  echo.feedback = 16
  echo.lowPassCutoff = 6000
  echo.wetDryMix = echoMix
  updateRoom()
  output.attach(s)
  output.attach(echo)
  output.attach(ambience)
  output.attach(mixer)
  output.attach(player)
  output.connect(s, to: echo, format: vocalFormat)
  output.connect(echo, to: ambience, format: vocalFormat)
  output.connect(ambience, to: mixer, format: vocalFormat)
  output.connect(mixer, to: output.mainMixerNode, format: vocalFormat)
  let fmt = file?.processingFormat ?? AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
  output.connect(player, to: output.mainMixerNode, format: fmt)
  updateMonitorLevel()
  player.volume = musicVolume
  output.prepare()
  do {
   try output.start()
   if captureWasRunning { try capture?.start() }
  } catch {
   destroyOutput()
   if captureWasRunning { stopCapture() }
   throw error
  }
 }
 private func destroyOutput() {
  player.stop()
  output.stop()
  output = AVAudioEngine()
  player = AVAudioPlayerNode()
  voiceMixer = nil
  delay = nil
  reverb = nil
  source = nil
 }
 private func rebuildOutput() {
  let position = currentTime()
  let resume = isPlaying
  isPlaying = false
  video.pause()
  muteMonitor()
  stopCapture()
  destroyOutput()
  releaseBuffers()
  do {
   if file != nil {
    try makeOutput()
    try schedule(at: position, play: resume)
   }
   if micRequested && inputID != 0 { resumeCapture() }
  } catch {
   message = error.localizedDescription
  }
 }
 private func cancelPermissionRequest() {
  permissionRequest = UUID()
  requestingPermission = false
 }
 func toggleMicrophone() {
  if micRequested || requestingPermission {
   cancelPermissionRequest()
   micRequested = false
   muteMonitor()
   stopCapture()
   if file == nil { destroyOutput(); releaseBuffers() }
   message = ""
   return
  }
  refreshDevices()
  guard inputID != 0 else { message = "请先连接或选择麦克风"; return }
  switch AVCaptureDevice.authorizationStatus(for: .audio) {
  case .authorized:
   micRequested = true
   resumeCapture()
  case .notDetermined:
   let request = UUID()
   permissionRequest = request
   requestingPermission = true
   AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
    Task { @MainActor in
     guard let self, self.permissionRequest == request else { return }
     self.refreshDevices()
     guard self.permissionRequest == request else { return }
     self.requestingPermission = false
     guard granted else { self.message = "请在系统设置中允许麦克风"; return }
     self.micRequested = true
     self.resumeCapture()
    }
   }
  default:
   message = "请在系统设置中允许麦克风"
  }
 }
 func openMicrophonePrivacy() {
  if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
   NSWorkspace.shared.open(url)
  }
 }
 func muteMonitor() {
  voiceMixer?.outputVolume = 0
  if monitorOn { monitorOn = false }
 }
 func enableMonitor(confirmedRoute: OutputRoute?) {
  refreshDevices()
  guard let confirmedRoute, confirmedRoute == monitorRoute, microphoneOn else {
   muteMonitor()
   message = "请连接耳机并开启收音"
   return
  }
  do { try makeOutput() }
  catch { message = error.localizedDescription; return }
  guard microphoneOn, Devices.currentDevice(output.outputNode.audioUnit) == outputID else {
   message = "耳机输出已切换，请重新选择"
   return
  }
  monitorOn = true
  updateMonitorLevel()
  message = ""
 }
 private func resumeCapture() {
  guard micRequested, inputID != 0, AVCaptureDevice.authorizationStatus(for: .audio) == .authorized else { return }
  do {
   try startCapture()
   microphoneOn = true
   message = ""
  } catch {
   stopCapture()
   micRequested = false
   message = error.localizedDescription
  }
 }
 private func startCapture()throws {
  guard capture == nil else { return }
  let e = AVAudioEngine()
  let node = e.inputNode
  try device(node.audioUnit, inputID)
  lease(inputID)
  let fmt=node.outputFormat(forBus:0);guard fmt.sampleRate>0,fmt.channelCount>0 else{throw AudioFailure(message:"麦克风暂时不可用，请重新选择")};captureRate=fmt.sampleRate
  let outputRate=outputs.first{$0.id==outputID}?.rate ?? 48000
  // Stop the output callback while resetting the single-producer/single-consumer ring.
  let wasRunning=output.isRunning;if wasRunning{output.pause()};qc_reset(ring,fmt.sampleRate,outputRate)
  let ptr=ring
  let sink=AVAudioSinkNode{_,count,list in let buffers=UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating:list));if let p=buffers.first?.mData {qc_write(ptr,p.assumingMemoryBound(to:Float.self),count)};return noErr}
  let mix=AVAudioMixerNode();e.attach(mix);e.attach(sink);e.connect(node,to:mix,format:fmt);e.connect(mix,to:sink,format:AVAudioFormat(standardFormatWithSampleRate:fmt.sampleRate,channels:1)!)
  e.prepare()
  do {
   try e.start()
   guard Devices.currentDevice(node.audioUnit) == inputID else { throw AudioFailure(message: "麦克风已切换，请重新选择") }
   if wasRunning { try output.start() }
   capture = e
  } catch {
   e.stop()
   if wasRunning { try? output.start() }
   throw error
  }
 }
 private func stopCapture() {
  capture?.stop()
  capture = nil
  microphoneOn = false
  level = 0
  midi = nil
 }
 func load(_ song:Song,audioURL:URL?=nil,at seconds:Double=0,resetScore:Bool=true,play:Bool=true) {
  let priorMonitorRoute = monitorOn ? monitorRoute : nil
  let resume=play;generation+=1;video.pause();isPlaying=false;muteMonitor();stopCapture();destroyOutput();current=song;selectedAudioURL=audioURL ?? song.audio;offset=seconds
  if resetScore{score=0;tracker.reset(notes:song.notes,lines:song.lines);latestLineScore=nil}
  do {
   file=try AVAudioFile(forReading:selectedAudioURL!);duration=Double(file!.length)/file!.processingFormat.sampleRate
   try makeOutput()
   video.replaceCurrentItem(with:song.video.map{AVPlayerItem(url:$0)});video.isMuted=true;try schedule(at:seconds,play:resume)
   message=""
   if micRequested { resumeCapture() }
   if let priorMonitorRoute { enableMonitor(confirmedRoute: priorMonitorRoute) }
  } catch {file=nil;isPlaying=false;message="播放失败："+error.localizedDescription}
 }
 private func schedule(at seconds:Double,play:Bool)throws {
  guard let file else{return};generation+=1;let token=generation
  player.stop();offset=min(max(0,seconds),max(0,duration-0.1));elapsed=offset
  let frame=AVAudioFramePosition(offset*file.processingFormat.sampleRate);let count=AVAudioFrameCount(min(Int64(UInt32.max),max(1,file.length-frame)))
  player.scheduleSegment(file,startingFrame:frame,frameCount:count,at:nil,completionCallbackType:.dataPlayedBack){[weak self] _ in Task{@MainActor in guard let self,self.generation==token,self.isPlaying else{return};self.isPlaying=false;self.video.pause();self.elapsed=self.duration;self.onEnded?()} }
  video.seek(to:CMTime(seconds:max(0,offset-(current?.videoGap ?? 0)),preferredTimescale:600),toleranceBefore:.zero,toleranceAfter:.zero)
  if play {try makeOutput();player.play();video.play();isPlaying=true}else{video.pause();isPlaying=false}
 }
 func currentTime()->Double { if isPlaying,let t=player.lastRenderTime,let p=player.playerTime(forNodeTime:t),p.sampleRate>0 {return min(duration,max(0,offset+Double(p.sampleTime)/p.sampleRate))};return elapsed }
 func togglePlay(){guard file != nil else{return};if isPlaying{elapsed=currentTime();player.pause();video.pause();isPlaying=false}else{do{if elapsed>=duration-0.2{try schedule(at:0,play:true)}else{try makeOutput();player.play();video.play();isPlaying=true}}catch{message=error.localizedDescription}}}
 func seek(_ seconds:Double){do{try schedule(at:seconds,play:isPlaying)}catch{message=error.localizedDescription}}
 func restart(){score=0;if let current{tracker.reset(notes:current.notes,lines:current.lines)};latestLineScore=nil;do{try schedule(at:0,play:true)}catch{message=error.localizedDescription}}
 private func tick(){
  refreshCounter += 1
  if refreshCounter % 10 == 0 { refreshDevices() }
  if monitorOn && (!output.isRunning || Devices.currentDevice(output.outputNode.audioUnit) != outputID) { muteMonitor() }
  if refreshCounter%20==0{snapshot()}
  if microphoneOn {level=min(1,qc_level(ring)*5);let hz=level > 0 ? qc_pitch(ring) : 0;midi=hz>0 ? 69+12*log2(Double(hz)/440):nil}
  if isPlaying {
   elapsed=currentTime()
   if let song=current,refreshCounter%20==0,song.video != nil {let actual=video.currentTime().seconds;let expected=max(0,elapsed-song.videoGap);if actual.isFinite && abs(actual-expected)>0.22 {video.seek(to:CMTime(seconds:expected,preferredTimescale:600),toleranceBefore:CMTime(seconds:0.08,preferredTimescale:600),toleranceAfter:CMTime(seconds:0.08,preferredTimescale:600))}}
   if microphoneOn,let song=current {
    // Score using playback time; pauses and route restarts do not add duplicate frames.
    let analysisTime=max(0,elapsed-min(0.3,max(0,output.outputNode.presentationLatency)+2048/captureRate))
    tracker.observe(time:analysisTime,midi:midi);score=tracker.score ?? 0
    if let note=song.notes.first(where:{$0.start<=analysisTime && $0.end>analysisTime}) {
     if !note.scored{singingHint="这一段自由唱"}
     else if let midi{let delta=SingingTracker.difference(midi,note.midi);singingHint=abs(delta)<=0.7 ? "唱准了":(delta>0 ? "偏高一点":"偏低一点")}
     else{singingHint=level>0.98 ? "声音过大，请降低麦克风增益":"等待你的歌声"}
    }else{singingHint="间奏 · 放松一下"}
    if let index=song.lines.lastIndex(where:{$0.end<analysisTime}),let value=tracker.lineScore(index){latestLineScore="上一句 \(value) 分"}
   }else{singingHint="开启麦克风，显示你的演唱"}

  }
 }
 func shutdown() {
  shuttingDown = true
  cancelPermissionRequest()
  muteMonitor()
  timer?.invalidate()
  watchRoute()
  if let engineObserver { NotificationCenter.default.removeObserver(engineObserver) }
  stopCapture()
  destroyOutput()
  releaseBuffers()
 }
}
