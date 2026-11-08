import AVFoundation
import Foundation

let manager = FileManager.default
let root = manager.temporaryDirectory.appendingPathComponent("QingChangTests-" + UUID().uuidString)
try manager.createDirectory(at: root, withIntermediateDirectories: true)
defer { try? manager.removeItem(at: root) }

let song = root.appendingPathComponent("Demo")
try manager.createDirectory(at: song, withIntermediateDirectories: true)
let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44100)!
buffer.frameLength = 44100
for i in 0..<Int(buffer.frameLength) {
 buffer.floatChannelData![0][i] = Float(sin(Double(i) * 2 * .pi * 261.625 / 44100)) * 0.04
}
let audio = song.appendingPathComponent("audio.wav")
try AVAudioFile(forWriting: audio, settings: format.settings).write(from: buffer)
try manager.copyItem(at: audio, to: song.appendingPathComponent("backing.wav"))
try "Read me".write(to: song.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
let chart = song.appendingPathComponent("chart.txt")
let valid = """
#TITLE:试唱
#ARTIST:原创测试
#AUDIO:audio.wav
#INSTRUMENTAL:backing.wav
#BPM:120
#GAP:0
: 0 4 0 啦
- 4
F 4 4 2 哦
E
"""
try valid.write(to: chart, atomically: true, encoding: .utf8)
let imported = LibraryReader.load(root)
precondition(imported.count == 1)
let demo = imported[0]
precondition(demo.searchable.contains("shichang"))
precondition(demo.instrumental?.lastPathComponent == "backing.wav")
precondition(demo.notes[0].midi == 60 && demo.notes[0].end == 0.5)
precondition(demo.lines.count == 2 && !demo.notes[1].scored)
try valid.replacingOccurrences(of: "audio.wav", with: "../external.wav").write(to: chart, atomically: true, encoding: .utf8)
try manager.copyItem(at: audio, to: root.appendingPathComponent("external.wav"))
precondition(LibraryReader.load(root).isEmpty)
try valid.replacingOccurrences(of: "#BPM:120", with: "#BPM:inf").write(to: chart, atomically: true, encoding: .utf8)
precondition(LibraryReader.load(root).isEmpty)
print("PASS: UTF-8 song pack, playback and backing references, lyrics, pitch, path containment")
