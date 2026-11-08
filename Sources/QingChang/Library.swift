import Foundation
import AppKit
import ImageIO

struct Note: Identifiable {
 let id: Int; let start: Double; let end: Double; let midi: Double; let text: String; let scored: Bool
}
struct LyricLine: Identifiable { let id: Int; let notes: [Note]; var start: Double { notes.first?.start ?? 0 }; var end: Double { notes.last?.end ?? 0 }; var text: String { notes.map(\.text).joined() } }
struct Song: Identifiable {
 let id: String; let folder: URL; let title: String; let artist: String; let audio: URL; let instrumental: URL?; let video: URL?; let cover: URL?; let videoGap: Double; let duration: Double; let notes: [Note]; let lines: [LyricLine]
 let searchable: String
 var timeLabel: String { clock(duration) }
}
func clock(_ seconds: Double) -> String { guard seconds.isFinite else { return "0:00" }; let n=max(0,Int(seconds)); return String(format:"%d:%02d",n/60,n%60) }

enum LibraryReader {
 static func load(_ root: URL) -> [Song] {
  guard let folders=try? FileManager.default.contentsOfDirectory(at:root,includingPropertiesForKeys:[.isDirectoryKey],options:.skipsHiddenFiles) else { return [] }
  return folders.compactMap(read).sorted { if $0.artist == $1.artist { return $0.title.localizedStandardCompare($1.title) == .orderedAscending }; if $0.artist == "周杰伦" { return true }; if $1.artist == "周杰伦" { return false }; return $0.artist.localizedStandardCompare($1.artist) == .orderedAscending }
 }
 static func read(_ folder: URL) -> Song? {
  guard let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) else { return nil }
  let charts = files.filter { $0.pathExtension.lowercased() == "txt" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
  if let preferred = charts.first(where: { $0.lastPathComponent == "chart.txt" }), let song = read(folder, chart: preferred) { return song }
  return charts.lazy.compactMap { read(folder, chart: $0) }.first
 }
 private static func read(_ folder: URL, chart: URL) -> Song? {
  guard let data = try? Data(contentsOf: chart), let raw = String(data: data, encoding: .utf8) else { return nil }
  let rawLines=raw.replacingOccurrences(of:"\u{feff}",with:"").components(separatedBy:.newlines)
  var h=[String:String]()
  for row in rawLines where row.hasPrefix("#") { if let colon=row.firstIndex(of:":") { h[String(row[row.index(after:row.startIndex)..<colon]).uppercased()]=String(row[row.index(after:colon)...]).trimmingCharacters(in:.whitespacesAndNewlines) } }
  func media(_ keys: [String]) -> URL? {
   let base = folder.resolvingSymlinksInPath().standardizedFileURL.path
   for key in keys {
    guard let path = h[key], !path.isEmpty, !path.hasPrefix("/") else { continue }
    let url = folder.appendingPathComponent(path)
    let resolved = url.resolvingSymlinksInPath().standardizedFileURL
    guard resolved.path.hasPrefix(base + "/"),
          (try? resolved.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { continue }
    return url
   }
   return nil
  }
  guard let audio = media(["AUDIO", "MP3"]),
        let bpm = Double((h["BPM"] ?? "").replacingOccurrences(of: ",", with: ".")), bpm.isFinite, bpm > 0 else { return nil }
  let tick = 60 / bpm / 4
  let gap = (Double(h["GAP"] ?? "0") ?? 0) / 1000
  guard tick.isFinite, gap.isFinite else { return nil }
  var notes=[Note](),groups=[[Note]](),group=[Note]()
  for row in rawLines {
   if row.hasPrefix("-") { if !group.isEmpty { groups.append(group);group=[] };continue }
   guard let kind=row.first,[":","*","F","R","G"].contains(String(kind)) else { continue }
   let values=row.split(separator:" ",maxSplits:4,omittingEmptySubsequences:true)
   guard values.count==5,let start=Double(values[1]),let length=Double(values[2]),let pitch=Double(values[3]),length>0 else { continue }
   let n=Note(id:notes.count,start:start*tick+gap,end:(start+length)*tick+gap,midi:pitch+60,text:String(values[4]),scored:kind != "F")
   guard n.start.isFinite, n.end.isFinite, n.end > n.start, n.end <= 86400,
         n.midi.isFinite, (0...127).contains(n.midi) else { continue }
   notes.append(n);group.append(n)
  }
  if !group.isEmpty { groups.append(group) }
  var title=h["TITLE"] ?? folder.lastPathComponent,artist=h["ARTIST"] ?? "未知歌手",duration=notes.last?.end ?? 0
  if let a=try? Data(contentsOf:folder.appendingPathComponent("analysis.json")),let metadata=(try? JSONSerialization.jsonObject(with:a)) as? [String:Any] { title=metadata["title"] as? String ?? title;artist=metadata["artist"] as? String ?? artist;duration=(metadata["audio_seconds"] as? Double) ?? duration }
  guard !notes.isEmpty, !title.contains("伴奏练习") else { return nil }
  if !duration.isFinite || duration < 0 || duration > 86400 { duration = max(0, notes.last?.end ?? 0) }
  let videoGap = Double(h["VIDEOGAP"] ?? "0") ?? 0
  return Song(id:folder.path,folder:folder,title:title,artist:artist,audio:audio,instrumental:media(["INSTRUMENTAL"]),video:media(["VIDEO"]),cover:media(["COVER"]),videoGap:videoGap.isFinite ? videoGap : 0,duration:duration,notes:notes,lines:groups.enumerated().map{LyricLine(id:$0.offset,notes:$0.element)},searchable:[title,artist,title.applyingTransform(.toLatin,reverse:false) ?? "",artist.applyingTransform(.toLatin,reverse:false) ?? ""].joined(separator:" ").folding(options:[.diacriticInsensitive,.caseInsensitive],locale:.current).replacingOccurrences(of:" ",with:""))
 }
 static let imageCache=NSCache<NSString,NSImage>()
 static func image(_ url: URL?) -> NSImage? {
  guard let url else { return nil };if let i=imageCache.object(forKey:url.path as NSString) { return i }
  guard let src=CGImageSourceCreateWithURL(url as CFURL,nil),let cg=CGImageSourceCreateThumbnailAtIndex(src,0,[kCGImageSourceCreateThumbnailFromImageAlways:true,kCGImageSourceThumbnailMaxPixelSize:500,kCGImageSourceCreateThumbnailWithTransform:true] as CFDictionary) else { return nil }
  let image=NSImage(cgImage:cg,size:NSSize(width:cg.width,height:cg.height));imageCache.countLimit=120;imageCache.setObject(image,forKey:url.path as NSString);return image
 }
}
