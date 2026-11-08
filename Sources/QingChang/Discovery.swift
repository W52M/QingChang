import SwiftUI

private enum Lounge {
 static let background=Color(red:0.065,green:0.075,blue:0.075),surface=Color(red:0.12,green:0.135,blue:0.13),lime=Color(red:0.83,green:0.95,blue:0.34),orange=Color(red:0.98,green:0.57,blue:0.35),teal=Color(red:0.24,green:0.64,blue:0.58)
}
struct PopularSnapshot:Decodable {
 struct Entry:Decodable {let rank:Int;let title:String}
 struct Artist:Decodable {let artist:String;let source:String;let songs:[Entry]}
 let fetchedAt:String;let artists:[Artist]
 static func load()->PopularSnapshot?{let url=FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("轻唱/hot-songs.json");guard let data=try? Data(contentsOf:url) else{return nil};return try? JSONDecoder().decode(Self.self,from:data)}
}
enum DiscoverySelection {
 static let classics=["七里香","晴天","稻香","江南","修炼爱情","小幸运","遇见","后来","勇气","童话","泡沫","光年之外","爱人错过","倔强","突然好想你","十年","爱情转移","说谎","月牙湾","爱你","一眼万年","安静","彩虹","枫","夜曲","红豆","暖暖","那些你很冒险的梦","我们的爱","小酒窝","素颜","成都","消愁"]
 static let ballads=["安静","枫","搁浅","彩虹","修炼爱情","她说","那些你很冒险的梦","后来","成全","可惜不是你","说谎","心酸","寂寞寂寞就好","洋葱","猜不透","尘埃","命运","我怀念的","天黑黑","遇见","不要说话","十年","爱情转移"]
 static let party=["爱人错过","倔强","恋爱ing","离开地球表面","干杯","朋友","突然的自我","Super Star","中国话","波斯猫","不想长大","稻香","简单爱","你是我的花朵","伤心的人别听慢歌"]
 static let duets=["小酒窝","珊瑚海","屋顶","今天你要嫁给我","因为爱情","分开旅行","只对你有感觉","新窝","花好月圆夜","心之火","外滩十八号","广岛之恋","有一点动心"]
 static func key(_ text:String)->String{text.replacingOccurrences(of:"[（(][^）)]*[）)]",with:"",options:.regularExpression).folding(options:[.caseInsensitive,.diacriticInsensitive],locale:.current).replacingOccurrences(of:"[^a-zA-Z0-9\\p{Han}]",with:"",options:.regularExpression)}
 static func curated(_ songs:[Song],titles:[String])->[Song]{let keys=titles.map(key);return songs.filter{keys.contains(key($0.title))}.sorted{(keys.firstIndex(of:key($0.title)) ?? 999)<(keys.firstIndex(of:key($1.title)) ?? 999)}}
}
struct DiscoveryView:View {
 @ObservedObject var store:KTVStore
 @State private var page="推荐点歌"
 @State private var collection="经典必唱"
 @State private var chartArtist: String?
 @State private var queueOpen=false
 @State private var snapshot=PopularSnapshot.load()
 @State private var additions=[Song]()
 var body:some View{
  VStack(spacing:0){header;navigation
   ScrollView{VStack(alignment:.leading,spacing:26){
    if store.loading{ProgressView("正在整理歌库").frame(maxWidth:.infinity).padding(60)}
    else if store.songs.isEmpty {
     VStack(spacing: 16) {
      Image(systemName: "music.note.list").font(.largeTitle)
      Text("导入你的第一首歌").font(.title2.bold())
      Button("选择歌库文件夹") { store.chooseLibrary() }.buttonStyle(.borderedProminent).tint(Lounge.teal)
     }.frame(maxWidth: .infinity).padding(80)
    }
    else if page=="推荐点歌"{board;section("开口就会唱",subtitle:"熟悉的旋律，今天就从这里开始",action:"全部歌曲"){route("全部歌曲")};songGrid(Array(DiscoverySelection.curated(store.songs,titles:DiscoverySelection.classics).prefix(12)));section("新入歌库",subtitle:"按本地导入时间排列",action:"查看全部"){route("新加入")};songGrid(Array(additions.prefix(6)))}
    else if page=="歌手选歌"{singers}
    else if page=="热歌榜"{charts}
    else {catalog}
   }.padding(26).frame(maxWidth:1800).frame(maxWidth:.infinity)}.scrollIndicators(.hidden)
   LoungePlayer(store:store,audio:store.audio,queueOpen:$queueOpen)
  }.background(Lounge.background).foregroundStyle(.white).preferredColorScheme(.dark)
   .sheet(isPresented:$queueOpen){VStack(spacing:0){HStack{Spacer();Button("完成"){queueOpen=false}.keyboardShortcut(.cancelAction)}.padding(18);QueueView(store:store)}.frame(width:420,height:560).foregroundStyle(Theme.ink).background(Theme.bg).preferredColorScheme(.light)}
   .onAppear{loadAdditions()}.onChange(of:store.songs.count){_ in loadAdditions()}
   .onChange(of:store.query){query in if !query.isEmpty{page="搜索结果";store.artist="全部歌手";store.category="全部歌曲"}}
 }
 private func route(_ destination:String){store.query="";store.artist="全部歌手";store.category=destination=="我的收藏" || destination=="最近唱过" ? destination:"全部歌曲";page=destination}
 private func artist(_ name:String){route("全部歌曲");store.artist=name}
 private func loadAdditions(){let dates=Dictionary(uniqueKeysWithValues:store.songs.map{s in(s.id,(try? s.folder.resourceValues(forKeys:[.creationDateKey]).creationDate) ?? .distantPast)});additions=store.songs.sorted{dates[$0.id,default:.distantPast]>dates[$1.id,default:.distantPast]}}
 private var header:some View{
  HStack(spacing:22){HStack(spacing:10){Image(systemName:"waveform").font(.system(size:25,weight:.bold)).foregroundStyle(Lounge.lime);Text("轻唱").font(.system(size:27,weight:.heavy));Text("KTV 点歌台").font(.system(size:12)).foregroundStyle(.white.opacity(0.5))};Spacer()
   HStack{Image(systemName:"magnifyingglass");TextField("搜歌名、歌手或拼音",text:$store.query).textFieldStyle(.plain).onSubmit{if let song=store.filtered.first{store.play(song)}};if !store.query.isEmpty{Button{store.query=""}label:{Image(systemName:"xmark.circle.fill")}.buttonStyle(.plain)}}.font(.system(size:14)).padding(.horizontal,16).frame(width:310,height:44).background(Lounge.surface,in:RoundedRectangle(cornerRadius:12))
   AudioButton(audio:store.audio,dark:true)
   Menu{Button("选择歌库文件夹"){store.chooseLibrary()};Button("重新扫描歌库"){store.reload()}}label:{Image(systemName:"folder.badge.gearshape").font(.system(size:18))}.menuStyle(.borderlessButton).fixedSize().help("歌库管理")
  }.padding(.horizontal,28).padding(.top,25).padding(.bottom,21)
 }
 private var navigation:some View{HStack(spacing:8){ForEach(["推荐点歌","歌手选歌","热歌榜","华语流行","全部歌曲","我的收藏"],id:\.self){title in Button{route(title)}label:{Text(title).font(.system(size:14,weight:.semibold)).padding(.horizontal,19).padding(.vertical,11).background(page==title ? Lounge.lime:Lounge.surface,in:RoundedRectangle(cornerRadius:9)).foregroundStyle(page==title ? Lounge.background:.white.opacity(0.75))}.buttonStyle(.plain)};Spacer();Text("\(store.songs.count) 首 · \(max(0,store.artists.count-1)) 位歌手").font(.system(size:11,design:.monospaced)).foregroundStyle(.white.opacity(0.4))}.padding(.horizontal,28).padding(.bottom,4)}
 private var board:some View{
  GeometryReader{g in HStack(spacing:14){hero.frame(width:(g.size.width-28)*0.43)
   VStack(spacing:14){tile("热歌榜",subtitle:"人气曲目，优先开唱",symbol:"flame.fill",color:Lounge.orange){route("热歌榜")};tile("歌手选歌",subtitle:"找到你心里的那位",symbol:"person.2.fill",color:Lounge.teal){route("歌手选歌")}}.frame(width:(g.size.width-28)*0.26)
   VStack(spacing:14){tile("华语流行",subtitle:"经典 / 抒情 / 聚会 / 合唱",symbol:"music.note",color:Lounge.lime){route("华语流行")};HStack(spacing:14){tile("最近唱过",subtitle:"接着上一首的心情",symbol:"clock.arrow.circlepath",color:Color(red:0.32,green:0.36,blue:0.56)){route("最近唱过")};tile("我的收藏",subtitle:"每次都想唱",symbol:"heart.fill",color:Color(red:0.61,green:0.30,blue:0.37)){route("我的收藏")}}}
  }}.frame(height:322)
 }
 private var hero:some View{
  let song=store.songs.first{$0.artist=="周杰伦" && $0.title=="七里香"} ?? store.songs.first
  let titles = store.songs.filter { $0.artist == song?.artist }.prefix(3).map(\.title).joined(separator: " · ")
  return Button{if let song{artist(song.artist)}}label:{ZStack(alignment:.bottomLeading){Artwork(song:song,radius:18);LinearGradient(colors:[.black.opacity(0.08),.black.opacity(0.88)],startPoint:.top,endPoint:.bottom);VStack(alignment:.leading,spacing:10){Text("今晚，唱个尽兴。").font(.system(size:13,weight:.semibold)).padding(.horizontal,12).padding(.vertical,7).background(.black.opacity(0.35),in:Capsule());Spacer();Text("\(song?.artist ?? "华语")专场").font(.system(size:35,weight:.heavy));Text(titles).font(.system(size:13)).foregroundStyle(.white.opacity(0.8));HStack{Text("进入歌手专场");Image(systemName:"arrow.up.right")}.font(.system(size:12,weight:.semibold)).foregroundStyle(Lounge.lime).padding(.top,6)}.padding(24)}}.buttonStyle(.plain).clipShape(RoundedRectangle(cornerRadius:18)).accessibilityLabel("进入\(song?.artist ?? "歌手")专场")
 }
 private func tile(_ title:String,subtitle:String,symbol:String,color:Color,action:@escaping()->Void)->some View{Button(action:action){VStack(alignment:.leading,spacing:9){HStack{Image(systemName:symbol).font(.system(size:27,weight:.medium));Spacer();Image(systemName:"arrow.up.right").font(.system(size:15))};Spacer(minLength:4);Text(title).font(.system(size:title.count>3 ? 20:25,weight:.heavy));Text(subtitle).font(.system(size:11)).opacity(0.7).lineLimit(2)}.padding(20).frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.leading).foregroundStyle(color==Lounge.lime || color==Lounge.orange ? Lounge.background:.white).background(color,in:RoundedRectangle(cornerRadius:17))}.buttonStyle(.plain)}
 private func section(_ title:String,subtitle:String,action:String?=nil,onTap:@escaping()->Void={})->some View{HStack(alignment:.bottom){VStack(alignment:.leading,spacing:7){Text(title).font(.system(size:25,weight:.bold));Text(subtitle).font(.system(size:12)).foregroundStyle(.white.opacity(0.46))};Spacer();if let action{Button{onTap()}label:{Label(action,systemImage:"arrow.right").font(.system(size:12)).foregroundStyle(Lounge.lime)}.buttonStyle(.plain)}}}
 private func songGrid(_ songs:[Song])->some View{Group{if songs.isEmpty{empty("这里还没有歌曲",subtitle:"试试其他分类，或先收藏几首喜欢的歌")}else{LazyVGrid(columns:[GridItem(.adaptive(minimum:180,maximum:300),spacing:16)],spacing:19){ForEach(songs){song in LoungeSongTile(song:song,store:store)}}}}}
 private var singers:some View{VStack(alignment:.leading,spacing:22){section("按歌手点歌",subtitle:"点进专场，挑一首最想唱的");LazyVGrid(columns:[GridItem(.adaptive(minimum:210,maximum:310),spacing:16)],spacing:16){ForEach(store.artists.filter{$0 != "全部歌手"},id:\.self){name in Button{artist(name)}label:{ZStack(alignment:.bottomLeading){Artwork(song:store.songs.first{$0.artist==name},radius:15);LinearGradient(colors:[.clear,.black.opacity(0.88)],startPoint:.top,endPoint:.bottom);VStack(alignment:.leading,spacing:6){Text(name).font(.system(size:24,weight:.bold));Text("\(store.songs.filter{$0.artist==name}.count) 首可唱 · 进入专场 ↗").font(.system(size:11)).foregroundStyle(.white.opacity(0.65))}.padding(20)}.frame(height:180).clipShape(RoundedRectangle(cornerRadius:15))}.buttonStyle(.plain)}}}}
 private var catalog:some View{VStack(alignment:.leading,spacing:22){
  section(store.artist=="全部歌手" ? page:store.artist+"专场",subtitle:page=="华语流行" ? "按心情选一组，下一首就有了":"点击封面开唱，＋ 加入已点歌曲")
  if page=="华语流行"{HStack(spacing:10){ForEach(["经典必唱","抒情慢歌","朋友聚会","合唱时刻"],id:\.self){name in Button{collection=name}label:{Text(name).font(.system(size:13,weight:.semibold)).padding(14).frame(maxWidth:.infinity).background(collection==name ? Lounge.lime:Lounge.surface,in:RoundedRectangle(cornerRadius:12)).foregroundStyle(collection==name ? Lounge.background:.white)}.buttonStyle(.plain)}}}
  songGrid(catalogSongs)
 }}
 private var catalogSongs:[Song]{if page=="华语流行"{let names=collection=="抒情慢歌" ? DiscoverySelection.ballads:(collection=="朋友聚会" ? DiscoverySelection.party:(collection=="合唱时刻" ? DiscoverySelection.duets:DiscoverySelection.classics));return DiscoverySelection.curated(store.filtered,titles:names)};if page=="新加入"{return additions};return store.filtered}
 private var charts:some View{VStack(alignment:.leading,spacing:24){
  section("华语热唱精选",subtitle:"编辑精选顺序 · 从本地已入库的熟歌开始，不是实时播放总榜")
  ForEach(Array(DiscoverySelection.curated(store.songs,titles:DiscoverySelection.classics).prefix(10).enumerated()),id:\.element.id){index,song in chartRow(song,rank:index+1)}
  if let snapshot, !snapshot.artists.isEmpty {
   let names = snapshot.artists.map(\.artist).sorted()
   Divider().overlay(.white.opacity(0.1))
   HStack {
    section("歌手热门榜", subtitle: "本地榜单快照")
    Spacer()
    Picker("歌手", selection: Binding(get: { chartArtist ?? names[0] }, set: { chartArtist = $0 })) {
     ForEach(names, id: \.self) { Text($0).tag($0) }
    }.labelsHidden().frame(width: 180)
   }
  }
  if let profile=snapshot?.artists.first(where:{$0.artist==(chartArtist ?? snapshot?.artists.map(\.artist).sorted().first)}){
   let matches=profile.songs.compactMap{entry->(Song,Int)? in guard let song=store.songs.first(where:{$0.artist==profile.artist && DiscoverySelection.key($0.title)==DiscoverySelection.key(entry.title)})else{return nil};return(song,entry.rank)}
   if matches.isEmpty{empty("热门曲目还在补齐",subtitle:"这个歌手的榜单曲目暂时没有完整可唱包")}else{ForEach(matches,id:\.0.id){song,rank in chartRow(song,rank:rank)}}
   if let url = URL(string: profile.source), url.scheme == "https" {
    Link("查看榜单来源 ↗", destination: url).font(.system(size:11)).foregroundStyle(Lounge.lime)
   }
  }
 }}
 private func chartRow(_ song:Song,rank:Int)->some View{HStack(spacing:17){Text(String(format:"%02d",rank)).font(.system(size:23,weight:.bold,design:.rounded)).foregroundStyle(rank<4 ? Lounge.lime:.white.opacity(0.35)).frame(width:40);Button{store.play(song)}label:{HStack(spacing:15){Artwork(song:song,radius:8).frame(width:75,height:52);VStack(alignment:.leading,spacing:6){Text(song.title).font(.system(size:16,weight:.semibold));Text(song.artist).font(.system(size:12)).foregroundStyle(.white.opacity(0.5))};Spacer();Text(song.timeLabel).font(.system(size:12,design:.monospaced)).foregroundStyle(.white.opacity(0.5));Image(systemName:"play.fill").foregroundStyle(Lounge.lime)}}.buttonStyle(.plain);Button{store.add(song)}label:{Image(systemName:store.queue.contains(where:{$0.id==song.id}) ? "checkmark":"plus").frame(width:40,height:40).background(.white.opacity(0.08),in:RoundedRectangle(cornerRadius:10))}.buttonStyle(.plain).accessibilityLabel("点歌 "+song.title)}.padding(14).background(Lounge.surface,in:RoundedRectangle(cornerRadius:13))}
 private func empty(_ title:String,subtitle:String)->some View{VStack(spacing:14){Image(systemName:"music.note.list").font(.system(size:34));Text(title).font(.system(size:20,weight:.semibold));Text(subtitle).font(.system(size:13)).foregroundStyle(.white.opacity(0.5))}.frame(maxWidth:.infinity).padding(65).background(Lounge.surface,in:RoundedRectangle(cornerRadius:18))}
}
struct LoungeSongTile:View {
 let song:Song;@ObservedObject var store:KTVStore
 var body:some View{
  VStack(alignment:.leading,spacing:0){
   ZStack(alignment:.topTrailing){
    Button{store.play(song)}label:{ZStack(alignment:.bottomTrailing){Artwork(song:song,radius:0).aspectRatio(1.5,contentMode:.fit);Image(systemName:"play.fill").font(.system(size:14)).foregroundStyle(.white).padding(12).background(.black.opacity(0.5),in:Circle()).padding(11)}}.buttonStyle(.plain).accessibilityLabel("开唱 "+song.title)
    Button{store.favorite(song)}label:{Image(systemName:store.favorites.contains(song.id) ? "heart.fill":"heart").font(.system(size:13,weight:.semibold)).foregroundStyle(store.favorites.contains(song.id) ? Lounge.orange:.white).padding(9).background(.black.opacity(0.5),in:Circle())}.buttonStyle(.plain).padding(10).accessibilityLabel((store.favorites.contains(song.id) ? "取消收藏 ":"收藏 ")+song.title)
   }
   HStack{VStack(alignment:.leading,spacing:6){Text(song.title).font(.system(size:15,weight:.semibold)).lineLimit(1);Text(song.artist).font(.system(size:11)).foregroundStyle(.white.opacity(0.45)).lineLimit(1)};Spacer(minLength:4);Button{store.add(song)}label:{Image(systemName:store.queue.contains(where:{$0.id==song.id}) ? "checkmark":"plus").font(.system(size:15,weight:.semibold)).foregroundStyle(Lounge.lime).frame(width:31,height:31).background(.white.opacity(0.07),in:RoundedRectangle(cornerRadius:8))}.buttonStyle(.plain).accessibilityLabel("点歌 "+song.title)}.padding(14)
  }.background(Lounge.surface,in:RoundedRectangle(cornerRadius:14)).clipShape(RoundedRectangle(cornerRadius:14)).contextMenu{Button("立即开唱"){store.play(song)};Button("加入已点"){store.add(song)};Button(store.favorites.contains(song.id) ? "取消收藏":"收藏"){store.favorite(song)}}
 }
}
struct LoungePlayer:View {
 @ObservedObject var store:KTVStore;@ObservedObject var audio:AudioController;@Binding var queueOpen:Bool
 var body:some View{HStack(spacing:20){Button{if audio.current != nil{store.stage=true}}label:{HStack(spacing:13){Artwork(song:audio.current,radius:8).frame(width:56,height:48);VStack(alignment:.leading,spacing:5){Text(audio.current?.title ?? "点一首，开始今天的演唱").font(.system(size:13,weight:.semibold));Text(audio.current?.artist ?? "你的私人 KTV").font(.system(size:11)).foregroundStyle(.white.opacity(0.4))}}}.buttonStyle(.plain).frame(width:270,alignment:.leading);Button{if audio.current==nil{store.next()}else{audio.togglePlay()}}label:{Image(systemName:audio.isPlaying ? "pause.fill":"play.fill").font(.system(size:18)).foregroundStyle(Lounge.background).frame(width:44,height:44).background(Lounge.lime,in:Circle())}.buttonStyle(.plain).disabled(audio.current==nil && store.queue.isEmpty);Button{store.next()}label:{Image(systemName:"forward.end.fill")}.buttonStyle(.plain).disabled(store.queue.isEmpty);SeekBar(audio:audio,dark:true);Button{queueOpen=true}label:{Label("已点 \(store.queue.count)",systemImage:"music.note.list").font(.system(size:13,weight:.semibold)).padding(.horizontal,18).padding(.vertical,13).background(.white.opacity(0.08),in:RoundedRectangle(cornerRadius:10))}.buttonStyle(.plain)}.padding(.horizontal,28).padding(.vertical,17).background(Color(red:0.09,green:0.10,blue:0.10)).foregroundStyle(.white)}
}
