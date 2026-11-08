import SwiftUI
import AVFoundation

enum Theme {
 static let bg=Color(red:0.965,green:0.963,blue:0.942),ink=Color(red:0.09,green:0.18,blue:0.17),accent=Color(red:0.07,green:0.40,blue:0.34),muted=Color(red:0.44,green:0.48,blue:0.46),mint=Color(red:0.48,green:0.94,blue:0.77)
}
struct CapsuleButton:View {
 let title:String;var selected=false;var action:()->Void
 var body:some View{Button(action:action){Text(title).font(.system(size:13,weight:selected ? .semibold:.medium)).foregroundStyle(selected ? Color.white:Theme.muted).padding(.horizontal,17).padding(.vertical,10).background(selected ? Theme.ink:Color.white,in:Capsule())}.buttonStyle(.plain)}
}
struct Artwork:View {
 let song:Song?;var radius:CGFloat=10
 var body:some View{GeometryReader{g in ZStack{Theme.ink.opacity(0.08);if let image=LibraryReader.image(song?.cover){Image(nsImage:image).resizable().scaledToFill().frame(width:g.size.width,height:g.size.height).clipped()}else{Image(systemName:"music.mic").font(.system(size:30)).foregroundStyle(Theme.accent.opacity(0.45))}}}.clipShape(RoundedRectangle(cornerRadius:radius))}
}
struct RootView:View {
 @StateObject var store=KTVStore()
 var body:some View{
  ZStack(alignment:.bottom){
   Theme.bg.ignoresSafeArea()
   if store.stage {StageView(store:store,audio:store.audio)}else{
    DiscoveryView(store:store)
   }
   if !store.toast.isEmpty{Text(store.toast).font(.system(size:14,weight:.medium)).padding(.horizontal,22).padding(.vertical,12).foregroundStyle(.white).background(Theme.ink,in:Capsule()).shadow(color:.black.opacity(0.12),radius:15,y:4).padding(.bottom,115).transition(.move(edge:.bottom).combined(with:.opacity))}
  }.animation(.easeInOut(duration:0.18),value:store.toast.isEmpty).frame(minWidth:1050,minHeight:700).preferredColorScheme(store.stage ? .light:.dark)
   .sheet(item:$store.singingResult){result in SingingResultView(result:result,store:store)}
   .onReceive(NotificationCenter.default.publisher(for:NSApplication.willTerminateNotification)){_ in store.audio.shutdown()}
 }
}

struct SongCard:View {
 let song:Song;@ObservedObject var store:KTVStore;@State private var hover=false
 var body:some View{
  VStack(alignment:.leading,spacing:10){
   Button{store.play(song)}label:{ZStack(alignment:.bottomLeading){Artwork(song:song).aspectRatio(1.55,contentMode:.fit);LinearGradient(colors:[.clear,.black.opacity(0.48)],startPoint:.center,endPoint:.bottom).clipShape(RoundedRectangle(cornerRadius:10));HStack{Label("开唱",systemImage:"play.fill").font(.system(size:12,weight:.semibold));Spacer();Text(song.timeLabel).font(.system(size:11,design:.monospaced))}.foregroundStyle(.white).padding(12);if hover{Circle().fill(.white.opacity(0.94)).frame(width:42,height:42).overlay(Image(systemName:"play.fill").font(.system(size:16)).foregroundStyle(Theme.ink)).frame(maxWidth:.infinity,maxHeight:.infinity)}}}.buttonStyle(.plain).onHover{hover=$0}
   HStack(alignment:.top,spacing:6){VStack(alignment:.leading,spacing:5){Text(song.title).font(.system(size:15,weight:.semibold)).foregroundStyle(Theme.ink).lineLimit(1);Text(song.artist).font(.system(size:12)).foregroundStyle(Theme.muted).lineLimit(1)};Spacer(minLength:0);Button{store.add(song)}label:{Image(systemName:store.queue.contains(where:{$0.id==song.id}) ? "checkmark":"plus").font(.system(size:14,weight:.semibold)).foregroundStyle(Theme.accent).frame(width:29,height:29).background(Theme.accent.opacity(0.07),in:Circle())}.help("加入已点歌曲")}
  }.contextMenu{Button("立即开唱"){store.play(song)};Button("加入已点"){store.add(song)};Button(store.favorites.contains(song.id) ? "取消收藏":"收藏歌曲"){store.favorite(song)}}
 }
}
struct QueueView:View {
 @ObservedObject var store:KTVStore
 var body:some View{
  VStack(alignment:.leading,spacing:20){HStack{Text("已点歌曲").font(.system(size:18,weight:.bold));Text("\(store.queue.count)").font(.system(size:12,weight:.semibold)).foregroundStyle(Theme.accent).padding(.horizontal,8).padding(.vertical,4).background(Theme.accent.opacity(0.08),in:Capsule());Spacer();if !store.queue.isEmpty{Button("清空"){store.queue=[]}.font(.system(size:12)).foregroundStyle(Theme.muted)}}
   if store.queue.isEmpty {Spacer();VStack(spacing:14){Image(systemName:"music.note.list").font(.system(size:37,weight:.ultraLight)).foregroundStyle(Theme.accent.opacity(0.6));Text("点几首喜欢的歌").font(.system(size:15,weight:.medium));Text("点击歌曲旁的 ＋ 加入这里").font(.system(size:12)).foregroundStyle(Theme.muted)}.frame(maxWidth:.infinity);Spacer()}
   else {ScrollView{LazyVStack(spacing:18){ForEach(Array(store.queue.enumerated()),id:\.element.id){index,song in HStack(spacing:10){Text(String(format:"%02d",index+1)).font(.system(size:11,design:.monospaced)).foregroundStyle(Theme.muted);Artwork(song:song,radius:6).frame(width:48,height:42);VStack(alignment:.leading,spacing:4){Text(song.title).font(.system(size:13,weight:.semibold)).lineLimit(1);Text(song.artist).font(.system(size:11)).foregroundStyle(Theme.muted)};Spacer(minLength:0);Menu{Button("现在唱"){store.play(song)};Button("置顶"){store.moveFirst(song)};Button("移除"){store.queue.removeAll{$0.id==song.id}}}label:{Image(systemName:"ellipsis").foregroundStyle(Theme.muted)}.menuStyle(.borderlessButton).fixedSize()}}}}.scrollIndicators(.hidden)
    Button{store.next()}label:{Label(store.audio.current==nil ? "开始欢唱":"切到下一首",systemImage:"play.fill").font(.system(size:14,weight:.semibold)).foregroundStyle(.white).frame(maxWidth:.infinity).padding(.vertical,14).background(Theme.accent,in:RoundedRectangle(cornerRadius:11))}.buttonStyle(.plain)
   }
  }.foregroundStyle(Theme.ink).padding(23)
 }
}
struct AudioButton:View {
 @ObservedObject var audio:AudioController;var dark=false;@State private var show=false
 var body:some View{Button{show.toggle()}label:{HStack(spacing:8){Image(systemName:audio.microphoneOn ? "mic.fill":"slider.horizontal.3");Text(audio.microphoneOn ? "麦克风已开":"声音设置");Circle().fill(audio.microphoneOn ? Theme.mint:Theme.muted.opacity(0.35)).frame(width:6,height:6)}.font(.system(size:13,weight:.medium)).padding(.horizontal,15).frame(height:42).foregroundStyle(dark ? .white:Theme.ink).background(dark ? .white.opacity(0.12):Theme.ink.opacity(0.05),in:Capsule())}.buttonStyle(.plain).sheet(isPresented:$show){VStack(spacing:0){AudioPanel(audio:audio);Button("完成"){show=false}.keyboardShortcut(.defaultAction).padding(.bottom,24)}.foregroundStyle(Theme.ink).background(Theme.bg).preferredColorScheme(.light)}}
}
struct AudioPanel: View {
 @ObservedObject var audio: AudioController
 @State private var confirmHeadphones = false
 @State private var confirmedRoute: OutputRoute?
 @State private var showEffects = false

 var body: some View {
  VStack(alignment: .leading, spacing: 18) {
   HStack {
    Text("声音设置").font(.system(size: 20, weight: .bold))
    Spacer()
    Button { audio.refreshDevices() } label: { Image(systemName: "arrow.clockwise") }
     .help("刷新设备").accessibilityLabel("刷新设备")
   }
   Picker("麦克风", selection: Binding(get: { audio.inputID }, set: audio.selectInput)) {
    if audio.inputID == 0 { Text(audio.inputName).tag(audio.inputID) }
    ForEach(audio.inputs) { Text($0.name).tag($0.id) }
   }
   Picker("播放设备", selection: Binding(get: { audio.outputSelection }, set: audio.selectOutput)) {
    Text("跟随系统 · " + audio.outputName).tag(UInt32(0))
    if audio.outputUnavailable { Text("已选设备未连接").tag(UInt32.max) }
    ForEach(audio.outputs) { Text($0.name).tag($0.id) }
   }
   HStack(spacing: 12) {
    Button(audio.micButtonTitle) { audio.toggleMicrophone() }
     .buttonStyle(.borderedProminent).tint(Theme.accent)
    ProgressView(value: Double(audio.level))
     .tint(audio.level >= 0.98 ? .orange : Theme.accent)
     .accessibilityLabel("麦克风输入电平")
   }
   if audio.permissionDenied {
    Button("打开麦克风权限设置", action: audio.openMicrophonePrivacy)
   }
   if !audio.message.isEmpty {
    Text(audio.message).font(.caption).foregroundStyle(Theme.accent)
   }

   Divider()
   HStack {
    Label("耳机监听", systemImage: "headphones").font(.headline)
    Spacer()
    Button(audio.monitorOn ? "关闭监听" : "开启监听") {
     if audio.monitorOn {
      audio.muteMonitor()
     } else {
      confirmedRoute = audio.monitorRoute
      confirmHeadphones = confirmedRoute != nil
     }
    }.disabled(!audio.headphoneMonitorAvailable || !audio.microphoneOn)
   }
   if !audio.headphoneMonitorAvailable {
    Text("当前输出只播音乐。人声监听请接有线耳机或 USB 耳机。")
     .font(.caption).foregroundStyle(Theme.muted)
   }
   if audio.monitorOn {
    LabeledContent("监听音量") {
     Slider(value: $audio.micVolume, in: 0...0.5).tint(Theme.accent)
      .accessibilityLabel("监听音量")
    }
    DisclosureGroup("回音与混响", isExpanded: $showEffects) {
     VStack(alignment: .leading, spacing: 12) {
      Picker("混响", selection: $audio.room) {
       ForEach(VocalRoom.allCases) { Text($0.rawValue).tag($0) }
      }.pickerStyle(.segmented)
      if audio.room != .dry {
       LabeledContent("混响量") {
        Slider(value: $audio.roomMix, in: 0...35).accessibilityLabel("混响量")
       }
      }
      LabeledContent("回音量") {
       Slider(value: $audio.echoMix, in: 0...30).accessibilityLabel("回音量")
      }
      if audio.echoMix > 0 {
       LabeledContent("回音间隔") {
        Slider(value: $audio.echoTime, in: 0.07...0.28).accessibilityLabel("回音间隔")
        Text("\(Int((audio.echoTime * 1000).rounded())) ms").monospacedDigit()
       }
      }
     }.padding(.top, 12).tint(Theme.accent)
    }
   }

   Divider()
   HStack {
    Picker("缓冲", selection: Binding(get: { audio.stableMode }, set: audio.selectStableMode)) {
     Text("低延迟").tag(false)
     Text("稳定").tag(true)
    }.pickerStyle(.segmented)
    if !audio.latencyText.isEmpty {
     Text(audio.latencyText).font(.caption).monospacedDigit().foregroundStyle(Theme.muted)
    }
   }
  }
  .padding(24).frame(width: 470).foregroundStyle(Theme.ink)
  .background(Theme.bg).preferredColorScheme(.light)
  .alert("确认耳机已接好", isPresented: $confirmHeadphones) {
   Button("取消", role: .cancel) {}
   Button("开启监听") { audio.enableMonitor(confirmedRoute: confirmedRoute) }
  } message: {
   Text("请确认 \(confirmedRoute?.name ?? "当前输出") 接的是耳机，避免人声从音箱播出。")
  }
 }
}
struct SeekBar:View {
 @ObservedObject var audio:AudioController;var dark=false;@State private var scrub:Double?
 var body:some View{HStack(spacing:10){Text(clock(scrub ?? audio.elapsed)).frame(width:dark ? 60:37);Slider(value:Binding(get:{scrub ?? audio.elapsed},set:{scrub=$0}),in:0...max(1,audio.duration),onEditingChanged:{editing in if !editing,let value=scrub{audio.seek(value);scrub=nil}}).tint(dark ? Theme.mint:Theme.accent);Text(clock(audio.duration)).frame(width:dark ? 60:37)}.font(.system(size:dark ? 15:10,design:.monospaced)).foregroundStyle(dark ? .white.opacity(0.85):Theme.muted)}
}
struct FooterView:View {
 @ObservedObject var store:KTVStore;@ObservedObject var audio:AudioController
 var body:some View{VStack(spacing:0){Divider();HStack(spacing:22){
  Button{if audio.current != nil{store.stage=true}}label:{HStack(spacing:12){Artwork(song:audio.current,radius:8).frame(width:57,height:53);VStack(alignment:.leading,spacing:5){Text(audio.current?.title ?? "选一首歌，开始今天的演唱").font(.system(size:14,weight:.semibold)).lineLimit(1);Text(audio.current?.artist ?? "你的私人 KTV，已经准备好").font(.system(size:12)).foregroundStyle(Theme.muted)}}.frame(width:270,alignment:.leading)}.buttonStyle(.plain)
  VStack(spacing:3){HStack(spacing:26){Button{audio.restart()}label:{Image(systemName:"backward.end.fill")}.disabled(audio.current==nil);Button{if audio.current==nil{store.next()}else{audio.togglePlay()}}label:{Image(systemName:audio.isPlaying ? "pause.fill":"play.fill").font(.system(size:17)).foregroundStyle(.white).frame(width:39,height:39).background(Theme.ink,in:Circle())}.disabled(audio.current==nil && store.queue.isEmpty);Button{store.next()}label:{Image(systemName:"forward.end.fill")}.disabled(store.queue.isEmpty)}.foregroundStyle(Theme.ink);SeekBar(audio:audio).frame(maxWidth:430)}.frame(maxWidth:.infinity)
  HStack(spacing:8){Image(systemName:"speaker.wave.2");Slider(value:$audio.musicVolume,in:0...1).tint(Theme.accent).frame(width:90)}.font(.system(size:13)).foregroundStyle(Theme.muted)
 }.padding(.horizontal,28).padding(.vertical,16).foregroundStyle(Theme.ink).background(Color.white.opacity(0.9))}}
}
final class MovieLayerView:NSView {var playerLayer=AVPlayerLayer();override init(frame:NSRect){super.init(frame:frame);wantsLayer=true;layer?.backgroundColor=NSColor.black.cgColor;playerLayer.videoGravity = .resizeAspect;layer?.addSublayer(playerLayer)};required init?(coder:NSCoder){fatalError()};override func layout(){super.layout();playerLayer.frame=bounds}}
struct MovieView:NSViewRepresentable {let player:AVPlayer;func makeNSView(context:Context)->MovieLayerView{let v=MovieLayerView(frame:.zero);v.playerLayer.player=player;return v};func updateNSView(_ v:MovieLayerView,context:Context){v.playerLayer.player=player}}
struct LyricText:View {
 let line:LyricLine;let time:Double
 private var units:Double{line.notes.reduce(0){value,n in value+n.text.unicodeScalars.reduce(0){$0+($1.value<128 ? 0.56:1)}}}
 var body:some View{GeometryReader{geometry in
  let fontSize=min(64,max(18,(geometry.size.width-24)/max(1,units)))
  HStack(spacing:0){ForEach(line.notes){note in
   let progress=min(1,max(0,(time-note.start)/max(0.01,note.end-note.start)))
   Text(note.text).foregroundStyle(.white).overlay{
    Text(note.text).foregroundStyle(Color.yellow).mask(alignment:.leading){GeometryReader{g in Rectangle().frame(width:g.size.width*progress)}}
   }.font(.system(size:fontSize,weight:.heavy)).fixedSize().shadow(color:.black,radius:2,x:2,y:2).shadow(color:.black,radius:4)
  }}.frame(width:geometry.size.width,height:geometry.size.height)
 }.frame(height:90).accessibilityElement(children:.ignore).accessibilityLabel(line.text)}
}
struct StageView:View {
 @ObservedObject var store:KTVStore;@ObservedObject var audio:AudioController
 @State private var showPitch=true
 var body:some View{ZStack{
  Color.black.ignoresSafeArea();MovieView(player:audio.video).ignoresSafeArea()
  LinearGradient(stops:[.init(color:.black.opacity(0.68),location:0),.init(color:.clear,location:0.28),.init(color:.black.opacity(0.2),location:0.5),.init(color:.black.opacity(0.92),location:1)],startPoint:.top,endPoint:.bottom).ignoresSafeArea()
  VStack(spacing:0){
   HStack{Button{store.stage=false}label:{Label("返回点歌台",systemImage:"chevron.left").font(.system(size:14,weight:.medium)).padding(12).background(.white.opacity(0.1),in:Capsule())}.keyboardShortcut(.escape,modifiers:[]);Spacer();VStack(spacing:5){Text(audio.current?.title ?? "").font(.system(size:20,weight:.semibold));Text(audio.current?.artist ?? "").font(.system(size:12)).foregroundStyle(.white.opacity(0.65))};Spacer();Button{NSApp.keyWindow?.toggleFullScreen(nil)}label:{Label("全屏",systemImage:"arrow.up.left.and.arrow.down.right").font(.system(size:13)).padding(12).background(.white.opacity(0.1),in:Capsule())}.buttonStyle(.plain);AudioButton(audio:audio,dark:true)}.padding(28)
   Spacer()
   if let song=audio.current {
    let index=song.lines.lastIndex(where:{$0.start<=audio.elapsed+0.15}) ?? 0
    if showPitch{LiveSingingPanel(audio:audio,song:song).padding(.horizontal,65).padding(.bottom,18)}
    if !song.lines.isEmpty {
     if audio.elapsed<song.lines[0].start{Text("前奏 · 还有 \(max(1,Int(song.lines[0].start-audio.elapsed))) 秒").font(.system(size:13,weight:.medium)).foregroundStyle(Theme.mint).padding(.bottom,16)}
     LyricText(line:song.lines[index],time:audio.elapsed).padding(.horizontal,50)
     if index+1<song.lines.count{Text(song.lines[index+1].text).font(.system(size:32,weight:.semibold)).foregroundStyle(.white.opacity(0.8)).multilineTextAlignment(.center).lineLimit(2).padding(.horizontal,60).padding(.top,16).frame(height:75)}
    }
   }
   Spacer().frame(height:35)
   VStack(spacing:18){SeekBar(audio:audio,dark:true);HStack(spacing:24){
    Button{audio.togglePlay()}label:{Image(systemName:audio.isPlaying ? "pause.fill":"play.fill").font(.system(size:18)).foregroundStyle(Theme.ink).frame(width:45,height:45).background(.white,in:Circle())}.keyboardShortcut(.space,modifiers:[])
    Button{audio.restart()}label:{Label("重唱",systemImage:"arrow.counterclockwise")};Button{store.next()}label:{Label("下一首",systemImage:"forward.end.fill")}.disabled(store.queue.isEmpty)
    Button{store.toggleOriginal()}label:{HStack(spacing:6){if store.preparing{ProgressView().controlSize(.small).tint(.white)}else{Image(systemName:store.originalVocal ? "person.wave.2.fill":"music.note")};Text(store.preparing ? "准备伴奏中":(store.originalVocal ? "原唱 开":"伴奏模式"))}.padding(.horizontal,14).padding(.vertical,10).background(.white.opacity(0.12),in:Capsule())}.disabled(store.preparing)
    Spacer()
    Button{showPitch.toggle()}label:{Label(showPitch ? "收起评分":"显示评分",systemImage:showPitch ? "waveform":"waveform.slash")}
    HStack(spacing:8){Button{audio.toggleMicrophone()}label:{Image(systemName:audio.microphoneOn ? "mic.fill":"mic.slash.fill").foregroundStyle(audio.microphoneOn ? Theme.mint:.white.opacity(0.5))}.help(audio.micButtonTitle);Text(audio.monitorOn ? "监听" : (audio.microphoneOn ? "只评分" : "麦克风"));Slider(value:$audio.micVolume,in:0...0.5).tint(Theme.mint).frame(width:90).disabled(!audio.monitorOn).accessibilityLabel("耳机人声音量");Text("\(Int(audio.micVolume*200))%").font(.system(size:10,design:.monospaced)).frame(width:30)}
    HStack(spacing:8){Image(systemName:"speaker.wave.2");Text("音乐");Slider(value:$audio.musicVolume,in:0...1).tint(Theme.mint).frame(width:80).accessibilityLabel("音乐音量")}
   }.font(.system(size:13,weight:.medium))}.padding(.horizontal,40).padding(.bottom,28)
  }.foregroundStyle(.white)
 }.onChange(of:audio.message){value in if !value.isEmpty{store.notify(value)}}}
}
