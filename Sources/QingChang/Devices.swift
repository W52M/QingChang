import Foundation
import CoreAudio
import AudioToolbox

struct AudioDevice: Identifiable,Hashable { let id: AudioDeviceID; let uid: String; let name: String; let inputs: Int; let outputs: Int; let rate: Double }
struct OutputRoute: Equatable {
 let uid: String
 let name: String
 let transport: UInt32
 let dataSource: UInt32
 let jack: UInt32
 let rate: Double

 var allowsHeadphones: Bool {
  let label = name.lowercased()
  guard !["studio display", "speaker", "扬声器", "音箱", "gx30"].contains(where: { label.contains($0) }) else { return false }
  if transport == kAudioDeviceTransportTypeBuiltIn { return dataSource == kAudioStreamTerminalTypeHeadphones || jack == 1 }
  return transport == kAudioDeviceTransportTypeUSB || transport == kAudioDeviceTransportTypeThunderbolt
 }
}

enum Devices {
 static func route(_ id: AudioDeviceID) -> OutputRoute? {
  let uid = string(id, kAudioDevicePropertyDeviceUID)
  guard id != 0, !uid.isEmpty else { return nil }
  return OutputRoute(uid: uid, name: string(id, kAudioObjectPropertyName),
                     transport: scalar(id, kAudioDevicePropertyTransportType, UInt32(0)),
                     dataSource: scalar(id, kAudioDevicePropertyDataSource, UInt32(0), kAudioDevicePropertyScopeOutput),
                     jack: scalar(id, kAudioDevicePropertyJackIsConnected, UInt32(0), kAudioDevicePropertyScopeOutput),
                     rate: scalar(id, kAudioDevicePropertyNominalSampleRate, Double(0)))
 }
 static func currentDevice(_ unit: AudioUnit?) -> AudioDeviceID {
  guard let unit else { return 0 }
  var device: AudioDeviceID = 0
  var size = UInt32(MemoryLayout<AudioDeviceID>.size)
  return AudioUnitGetProperty(unit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0, &device, &size) == noErr ? device : 0
 }

 static func address(_ selector: AudioObjectPropertySelector,_ scope: AudioObjectPropertyScope=kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress { AudioObjectPropertyAddress(mSelector:selector,mScope:scope,mElement:kAudioObjectPropertyElementMain) }
 static func scalar<T:BitwiseCopyable>(_ id: AudioObjectID,_ selector: AudioObjectPropertySelector,_ initial:T,_ scope:AudioObjectPropertyScope=kAudioObjectPropertyScopeGlobal) -> T { guard id != 0 else { return initial }; var a=address(selector,scope),v=initial,size=UInt32(MemoryLayout<T>.size);withUnsafeMutableBytes(of:&v){bytes in _=AudioObjectGetPropertyData(id,&a,0,nil,&size,bytes.baseAddress!)};return v }
 static func string(_ id: AudioObjectID,_ selector: AudioObjectPropertySelector) -> String { var a=address(selector),v:Unmanaged<CFString>?,size=UInt32(MemoryLayout<Unmanaged<CFString>?>.size);guard AudioObjectGetPropertyData(id,&a,0,nil,&size,&v)==noErr,let v else{return ""};return v.takeRetainedValue() as String }
 static func channels(_ id: AudioDeviceID,_ scope: AudioObjectPropertyScope) -> Int {
  var a=address(kAudioDevicePropertyStreamConfiguration,scope),size:UInt32=0
  guard AudioObjectGetPropertyDataSize(id,&a,0,nil,&size)==noErr,size>0 else{return 0}
  let p=UnsafeMutableRawPointer.allocate(byteCount:Int(size),alignment:MemoryLayout<AudioBufferList>.alignment);defer{p.deallocate()}
  guard AudioObjectGetPropertyData(id,&a,0,nil,&size,p)==noErr else{return 0}
  return UnsafeMutableAudioBufferListPointer(p.assumingMemoryBound(to:AudioBufferList.self)).reduce(0){$0+Int($1.mNumberChannels)}
 }
 static func list() -> [AudioDevice] {
  let system = AudioObjectID(kAudioObjectSystemObject)
  var a = address(kAudioHardwarePropertyDevices), size: UInt32 = 0
  guard AudioObjectGetPropertyDataSize(system, &a, 0, nil, &size) == noErr, size > 0 else { return [] }
  var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
  guard ids.withUnsafeMutableBytes({ AudioObjectGetPropertyData(system, &a, 0, nil, &size, $0.baseAddress!) }) == noErr else { return [] }
  return ids.compactMap{id in let name=string(id,kAudioObjectPropertyName);let uid=string(id,kAudioDevicePropertyDeviceUID);guard !uid.isEmpty,!name.isEmpty, !name.hasPrefix("CADefaultDeviceAggregate-") else{return nil};return AudioDevice(id:id,uid:uid,name:name,inputs:channels(id,kAudioDevicePropertyScopeInput),outputs:channels(id,kAudioDevicePropertyScopeOutput),rate:scalar(id,kAudioDevicePropertyNominalSampleRate,Double(48000)))}
 }
 static func defaultInput() -> AudioDeviceID { scalar(AudioObjectID(kAudioObjectSystemObject),kAudioHardwarePropertyDefaultInputDevice,AudioDeviceID(0)) }
 static func defaultOutput() -> AudioDeviceID { scalar(AudioObjectID(kAudioObjectSystemObject),kAudioHardwarePropertyDefaultOutputDevice,AudioDeviceID(0)) }
 static func setBuffer(_ id:AudioDeviceID,_ frames:UInt32) -> UInt32? {
  var a=address(kAudioDevicePropertyBufferFrameSize);guard AudioObjectIsPropertySettableValue(id,&a) else{return nil}
  let old=scalar(id,kAudioDevicePropertyBufferFrameSize,UInt32(512));let range=scalar(id,kAudioDevicePropertyBufferFrameSizeRange,AudioValueRange(mMinimum:32,mMaximum:4096));var n=UInt32(min(range.mMaximum,max(range.mMinimum,Double(frames))))
  return AudioObjectSetPropertyData(id,&a,0,nil,UInt32(MemoryLayout<UInt32>.size),&n)==noErr ? old:nil
 }
 static func restoreBuffer(_ id:AudioDeviceID,_ frames:UInt32) { var a=address(kAudioDevicePropertyBufferFrameSize),v=frames;AudioObjectSetPropertyData(id,&a,0,nil,4,&v) }
 private static func AudioObjectIsPropertySettableValue(_ id:AudioDeviceID,_ a:inout AudioObjectPropertyAddress)->Bool { var yes=DarwinBoolean(false);return AudioObjectIsPropertySettable(id,&a,&yes)==noErr && yes.boolValue }
}
