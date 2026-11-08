import Foundation

struct PitchTracePoint:Identifiable {
 let id:Int
 let time:Double
 let midi:Double?
 let target:Double?
 let quality:Double
}
struct SingingResult:Identifiable {
 let id=UUID()
 let title:String
 let artist:String
 let score:Int?
 let accuracy:Int
 let coverage:Int
 let capturedPercent:Int
 let bestLine:String?
 let bestLineScore:Int?
 let lineScores:[(String,Int)]
}
struct SingingTracker {
 private(set) var trace=[PitchTracePoint]()
 private var frames=[Int:PitchTracePoint]()
 private var expected=[Int:Double]()
 private var lineSlots=[[Int]]()
 private var lines=[String]()
 private var lastTraceTime = -Double.infinity
 static let rate=20.0
 static func difference(_ sung:Double,_ target:Double)->Double {
  // Accept the same melody in another octave, as common in home karaoke.
  (sung-target).remainder(dividingBy:12)
 }
 mutating func reset(notes:[Note],lines:[LyricLine]) {
  self=Self();self.lines=lines.map(\.text)
  for note in notes where note.scored {
   let start=Int(ceil(note.start*Self.rate)),end=Int(ceil(note.end*Self.rate))
   if end>start {for slot in start..<end{expected[slot]=note.midi}}
  }
  lineSlots=lines.map{line in line.notes.filter(\.scored).flatMap{note->[Int] in
   let start=Int(ceil(note.start*Self.rate)),end=Int(ceil(note.end*Self.rate));return end>start ? Array(start..<end):[]
  }}
 }
 mutating func observe(time:Double,midi:Double?) {
  guard time.isFinite,time>=0 else{return}
  let slot=Int(floor(time*Self.rate)),target=expected[slot]
  let valid=midi.flatMap{$0.isFinite ? $0:nil}
  let quality:Double
  if let target,let valid{quality=max(0,1-abs(Self.difference(valid,target))/2)}else{quality=0}
  let point=PitchTracePoint(id:slot,time:Double(slot)/Self.rate,midi:valid,target:target,quality:quality)
  // A replayed time slot replaces its earlier attempt; seeking cannot multiply scores.
  if target != nil{frames[slot]=point}
  if time<lastTraceTime-0.2{trace=[]}
  if trace.last?.id==slot{trace[trace.count-1]=point}else{trace.append(point)}
  lastTraceTime=time;trace.removeAll{$0.time<time-12 || $0.time>time+0.2}
 }
 var evaluated:Int{frames.count}
 var voiced:Int{frames.values.filter{$0.midi != nil}.count}
 var accuracy:Int{voiced>0 ? Int((frames.values.reduce(0){$0+$1.quality}/Double(voiced)*100).rounded()):0}
 var coverage:Int{evaluated>0 ? Int((Double(voiced)/Double(evaluated)*100).rounded()):0}
 var score:Int?{expected.isEmpty || evaluated==0 ? nil:Int((frames.values.reduce(0){$0+$1.quality}/Double(expected.count)*100).rounded())}
 var capturedPercent:Int{expected.isEmpty ? 0:Int((Double(evaluated)/Double(expected.count)*100).rounded())}
 func lineScore(_ index:Int)->Int? {
  guard lineSlots.indices.contains(index),!lineSlots[index].isEmpty,lineSlots[index].contains(where:{frames[$0] != nil}) else{return nil}
  return Int((lineSlots[index].reduce(0){$0+(frames[$1]?.quality ?? 0)}/Double(lineSlots[index].count)*100).rounded())
 }
 func result(title:String,artist:String)->SingingResult {
  let scores=lines.indices.compactMap{index->(String,Int)? in guard let score=lineScore(index) else{return nil};return(lines[index],score)}
  let best=scores.max{$0.1<$1.1}
  return SingingResult(title:title,artist:artist,score:score,accuracy:accuracy,coverage:coverage,capturedPercent:capturedPercent,bestLine:best?.0,bestLineScore:best?.1,lineScores:scores)
 }
}
