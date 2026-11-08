import SwiftUI

struct LiveSingingPanel:View {
 @ObservedObject var audio:AudioController
 let song:Song
 var body:some View {
  VStack(spacing:10){
   HStack(spacing:18){
    Label("参考旋律",systemImage:"rectangle.fill").foregroundStyle(Theme.mint)
    Label("你的演唱",systemImage:"waveform.path").foregroundStyle(.white)
    Spacer()
    Text(audio.microphoneOn ? audio.singingHint:"麦克风未开启").fontWeight(.semibold).foregroundStyle(audio.singingHint=="唱准了" ? Theme.mint:.white)
    if let line=audio.latestLineScore{Text(line).foregroundStyle(.white.opacity(0.7))}
    VStack(alignment:.trailing,spacing:2){Text(audio.microphoneOn && audio.tracker.evaluated>0 ? "\(audio.score) 分":"— 分").font(.system(size:24,weight:.bold,design:.rounded)).foregroundStyle(Theme.mint);Text("累计得分 · 满分100").font(.system(size:9)).foregroundStyle(.white.opacity(0.55))}
   }.font(.system(size:12)).padding(.horizontal,16)
   LivePitchView(song:song,time:audio.elapsed,trace:audio.tracker.trace)
   HStack{Text(audio.microphoneOn && audio.tracker.evaluated>0 ? "实时音准 \(audio.tracker.accuracy)%  ·  发声覆盖 \(audio.tracker.coverage)%":"打开声音设置中的麦克风，轨迹和评分就会出现");Spacer();Text("娱乐评分 · 同旋律可低/高八度演唱")}.font(.system(size:10)).foregroundStyle(.white.opacity(0.55)).padding(.horizontal,16)
  }.padding(.vertical,13).background(.black.opacity(0.5),in:RoundedRectangle(cornerRadius:16))
 }
}
struct LivePitchView:View {
 let song:Song;let time:Double;let trace:[PitchTracePoint]
 private var bounds:(Double,Double){let pitches=song.notes.filter(\.scored).map(\.midi).sorted();let median=pitches.isEmpty ? 60:pitches[pitches.count/2];let low=pitches.isEmpty ? 54:pitches[Int(Double(pitches.count-1)*0.05)];let high=pitches.isEmpty ? 72:pitches[Int(Double(pitches.count-1)*0.95)];let span=max(18,min(36,high-low+8));return(median-span/2,median+span/2)}
 var body:some View{Canvas{context,size in
  let (low,high)=bounds
  func x(_ t:Double)->Double{(t-time+3)/7*Double(size.width)}
  func y(_ pitch:Double)->Double{Double(size.height)-8-(pitch-low)/(high-low)*(Double(size.height)-16)}
  for pitch in stride(from:ceil(low),through:floor(high),by:3){var line=Path();line.move(to:CGPoint(x:0,y:y(pitch)));line.addLine(to:CGPoint(x:size.width,y:y(pitch)));context.stroke(line,with:.color(.white.opacity(0.07)),lineWidth:1)}
  for note in song.notes where note.scored && note.end>=time-3 && note.start<=time+4 {
   let rect=CGRect(x:x(note.start),y:y(note.midi)-4,width:max(3,x(note.end)-x(note.start)),height:8)
   context.fill(Path(roundedRect:rect,cornerRadius:4),with:.color(Theme.mint.opacity(note.start<=time && note.end>time ? 0.9:0.38)))
  }
  var previous:CGPoint?;var priorTime:Double?
  for sample in trace where sample.time>=time-3 && sample.time<=time+0.08 {
   guard let pitch=sample.midi else{previous=nil;priorTime=nil;continue}
   let reference=sample.target ?? (low+high)/2
   let aligned=reference+SingingTracker.difference(pitch,reference)
   let point=CGPoint(x:x(sample.time),y:y(aligned))
   if let previous,let priorTime,sample.time-priorTime<0.16{var path=Path();path.move(to:previous);path.addLine(to:point);context.stroke(path,with:.color(sample.target==nil ? .white:(sample.quality>=0.65 ? Theme.mint:.orange)),style:StrokeStyle(lineWidth:3,lineCap:.round,lineJoin:.round))}
   if time-sample.time<0.12{context.fill(Path(ellipseIn:CGRect(x:point.x-5,y:point.y-5,width:10,height:10)),with:.color(.white))}
   previous=point;priorTime=sample.time
  }
  var cursor=Path();cursor.move(to:CGPoint(x:x(time),y:0));cursor.addLine(to:CGPoint(x:x(time),y:size.height));context.stroke(cursor,with:.color(.white.opacity(0.55)),style:StrokeStyle(lineWidth:1,dash:[3,3]))
 }.frame(height:105).clipped().padding(.horizontal,16)}
}
struct SingingResultView:View {
 let result:SingingResult
 @ObservedObject var store:KTVStore
 var body:some View {
  VStack(spacing:22){
   Text("这一首，唱完啦").font(.system(size:25,weight:.bold))
   Text(result.title+" · "+result.artist).font(.system(size:15)).foregroundStyle(Theme.muted)
   HStack(alignment:.firstTextBaseline,spacing:7){Text(result.score.map(String.init) ?? "—").font(.system(size:78,weight:.bold,design:.rounded));Text("分").font(.system(size:20))}.foregroundStyle(Theme.accent)
   if result.score != nil{
    HStack(spacing:34){metric("发声音准",result.accuracy);metric("发声覆盖",result.coverage);metric("全曲采集",result.capturedPercent)}
    if result.capturedPercent<90{Text("这次只采集了部分演唱；跳过或未采集的部分不加分。").font(.system(size:12)).foregroundStyle(Theme.muted)}
    if let best=result.bestLine,let value=result.bestLineScore{VStack(spacing:8){Text("最稳的一句 · \(value) 分").font(.system(size:12,weight:.semibold)).foregroundStyle(Theme.accent);Text(best).font(.system(size:17,weight:.medium)).multilineTextAlignment(.center).lineLimit(3)}.padding(18).frame(maxWidth:.infinity).background(Theme.accent.opacity(0.06),in:RoundedRectangle(cornerRadius:14))}
    ScrollView{VStack(spacing:10){ForEach(Array(result.lineScores.enumerated()),id:\.offset){_,entry in HStack{Text(entry.0).lineLimit(1);Spacer();Text("\(entry.1) 分").fontWeight(.semibold).foregroundStyle(Theme.accent)}}}.font(.system(size:12))}.frame(maxHeight:135)
   }else{Text("这次没有采集到可评分的演唱。\n开启麦克风，下一首就能看见轨迹和分数。").multilineTextAlignment(.center).foregroundStyle(Theme.muted)}
   Text("依据当前旋律谱的本机娱乐评分，不识别歌词对错。\n建议使用伴奏，避免原唱或音箱声音进入麦克风。").font(.system(size:11)).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
   HStack(spacing:15){Button("返回点歌台"){store.singingResult=nil;store.stage=false};Button("再唱一次"){store.singingResult=nil;store.audio.restart()};if !store.queue.isEmpty{Button("下一首"){store.singingResult=nil;store.next()}.buttonStyle(.borderedProminent).tint(Theme.accent)}}
  }.padding(32).frame(width:520).foregroundStyle(Theme.ink).background(Theme.bg).preferredColorScheme(.light)
 }
 private func metric(_ label:String,_ value:Int)->some View{VStack(spacing:7){Text("\(value)%").font(.system(size:23,weight:.semibold,design:.rounded));Text(label).font(.system(size:11)).foregroundStyle(Theme.muted)}}
}
