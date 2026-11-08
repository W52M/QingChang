import Foundation
import AppKit
import CryptoKit

@MainActor final class KTVStore:ObservableObject {
 let audio=AudioController()
 @Published var songs=[Song]()
 @Published var queue=[Song]() { didSet { if queueReady { UserDefaults.standard.set(queue.map(\.id),forKey:"queuedSongs") } } }
 @Published var query=""
 @Published var category="全部歌曲"
 @Published var artist="全部歌手"
 @Published var stage=false
 @Published var singingResult:SingingResult?
 @Published var loading=true
 @Published var toast=""
 @Published var favorites:Set<String>=Set(UserDefaults.standard.stringArray(forKey:"favorites") ?? [])
 @Published var recent:[String]=UserDefaults.standard.stringArray(forKey:"recent") ?? []
 @Published var originalVocal=true
 @Published var preparing=false
 @Published var preparationMessage=""
 @Published var libraryURL=URL(fileURLWithPath:UserDefaults.standard.string(forKey:"libraryPath") ?? NSHomeDirectory()+"/Music/UltraStar Deluxe")
 private var toastID=UUID()
 private var queueReady=false
 private var scanID=UUID()
 init(){audio.onEnded={[weak self] in self?.finishSinging()};reload()}
 var artists:[String]{["全部歌手"]+Set(songs.map(\.artist)).sorted{$0.localizedStandardCompare($1) == .orderedAscending}}
 var filtered:[Song]{
  let needle=query.folding(options:[.diacriticInsensitive,.caseInsensitive],locale:.current).replacingOccurrences(of:" ",with:"")
  let result=songs.filter { s in (needle.isEmpty || s.searchable.contains(needle)) && (artist=="全部歌手" || s.artist==artist) && (category != "我的收藏" || favorites.contains(s.id)) && (category != "最近唱过" || recent.contains(s.id)) }
  if category=="最近唱过" {return result.sorted{(recent.firstIndex(of:$0.id) ?? 999)<(recent.firstIndex(of:$1.id) ?? 999)}}
  return result
 }
 func reload(){
  loading=true;let url=libraryURL;let token=UUID();scanID=token
  Task{
   let result=await Task.detached{LibraryReader.load(url)}.value
   guard scanID==token else{return}
   let ids=queueReady ? queue.map(\.id):(UserDefaults.standard.stringArray(forKey:"queuedSongs") ?? [])
   let byID=Dictionary(uniqueKeysWithValues:result.map{($0.id,$0)})
   var seen=Set<String>()
   songs=result;queueReady=true;queue=ids.compactMap{seen.insert($0).inserted ? byID[$0]:nil};loading=false
  }
 }
 func chooseLibrary(){let p=NSOpenPanel();p.canChooseDirectories=true;p.canChooseFiles=false;p.allowsMultipleSelection=false;p.message="选择歌曲文件夹，可直接选择 UltraStar Deluxe 歌库";if p.runModal() == .OK,let u=p.url{libraryURL=u;UserDefaults.standard.set(u.path,forKey:"libraryPath");reload()}}
 func notify(_ text:String){let id=UUID();toastID=id;toast=text;Task{try? await Task.sleep(nanoseconds:2_500_000_000);if toastID==id{toast=""}}}
 func favorite(_ song:Song){if favorites.contains(song.id){favorites.remove(song.id)}else{favorites.insert(song.id)};UserDefaults.standard.set(Array(favorites),forKey:"favorites")}
 func add(_ song:Song){guard !queue.contains(where:{$0.id==song.id})else{notify("这首歌已经点过了");return};queue.append(song);notify("已点 · "+song.title)}
 func finishSinging(){guard let song=audio.current else{return};singingResult=audio.tracker.result(title:song.title,artist:song.artist)}
 func play(_ song:Song){singingResult=nil;queue.removeAll{$0.id==song.id};recent.removeAll{$0==song.id};recent.insert(song.id,at:0);recent=Array(recent.prefix(40));UserDefaults.standard.set(recent,forKey:"recent");let backing=availableBacking(song);originalVocal = backing == nil;audio.load(song,audioURL:backing);stage=true}
 func next(){if let s=queue.first{play(s)}else{notify("唱完啦，再点一首吧");stage=false}}
 func moveFirst(_ song:Song){queue.removeAll{$0.id==song.id};queue.insert(song,at:0)}
 func instrumentalURL(_ song:Song)->URL{let key=SHA256.hash(data:Data(song.id.utf8)).prefix(10).map{String(format:"%02x",$0)}.joined();return FileManager.default.urls(for:.cachesDirectory,in:.userDomainMask)[0].appendingPathComponent("cn.qingchang.karaoke/Backing/"+key+"/instrumental.wav")}
 private func availableBacking(_ song: Song) -> URL? {
  let cached = instrumentalURL(song)
  return song.instrumental ?? (FileManager.default.fileExists(atPath: cached.path) ? cached : nil)
 }
 private var separationPython: String? {
  let path = UserDefaults.standard.string(forKey: "separationPython") ?? ProcessInfo.processInfo.environment["QINGCHANG_DEMUCS_PYTHON"]
  guard let path, path.hasPrefix("/"), FileManager.default.isExecutableFile(atPath: path) else { return nil }
  return path
 }
 func toggleOriginal(){
  guard let song=audio.current else{return}
  if !originalVocal{originalVocal=true;audio.load(song,at:audio.elapsed,resetScore:false,play:audio.isPlaying);return}
  let target=instrumentalURL(song)
  if let backing = availableBacking(song) { originalVocal=false;audio.load(song,audioURL:backing,at:audio.elapsed,resetScore:false,play:audio.isPlaying);return }
  guard let python = separationPython else { notify("这首歌没有伴奏文件，可在歌包里添加 #INSTRUMENTAL"); return }
  guard !preparing else{return};preparing=true;preparationMessage="正在准备伴奏，可以继续点歌"
  Task {
   let result:String?=await Task.detached{
    guard FileManager.default.isExecutableFile(atPath:python)else{return "伴奏工具未就绪，本地原唱播放不受影响"}
    do {
     let dir=target.deletingLastPathComponent();try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true)
     let log=dir.appendingPathComponent("preparation.log");FileManager.default.createFile(atPath:log.path,contents:nil);let handle=try FileHandle(forWritingTo:log);defer{try? handle.close()}
     let process=Process();process.executableURL=URL(fileURLWithPath:python);process.arguments=["-m","demucs","-n","htdemucs","-d","cpu","--shifts","0","--two-stems","vocals","--segment","7","-o",dir.path,song.audio.path];var env=ProcessInfo.processInfo.environment;env["PATH"]="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin";process.environment=env;process.standardOutput=handle;process.standardError=handle;try process.run();process.waitUntilExit()
     guard process.terminationStatus==0 else{return "这首伴奏暂时没准备好，仍可用原唱跟唱"}
     let stem=dir.appendingPathComponent("htdemucs/"+song.audio.deletingPathExtension().lastPathComponent+"/no_vocals.wav");try FileManager.default.moveItem(at:stem,to:target);try? FileManager.default.removeItem(at:dir.appendingPathComponent("htdemucs"));return nil
    }catch{return "伴奏准备失败："+error.localizedDescription}
   }.value
   preparing=false;preparationMessage=""
   if let result {notify(result)}else if audio.current?.id==song.id{originalVocal=false;audio.load(song,audioURL:target,at:audio.elapsed,resetScore:false,play:audio.isPlaying);notify("伴奏已准备好，已切换")}else{notify("《"+song.title+"》的伴奏已准备好")}
  }
 }
}
