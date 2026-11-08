import Foundation
let note=Note(id:0,start:1,end:2,midi:60,text:"唱",scored:true)
let line=LyricLine(id:0,notes:[note])
func tracker()->SingingTracker{var t=SingingTracker();t.reset(notes:[note],lines:[line]);return t}
var perfect=tracker()
for slot in 20..<40{perfect.observe(time:(Double(slot)+0.1)/20,midi:60)}
precondition(perfect.score==100 && perfect.accuracy==100 && perfect.coverage==100)
precondition(perfect.lineScore(0)==100)
var octave=tracker()
for slot in 20..<40{octave.observe(time:(Double(slot)+0.1)/20,midi:48)}
precondition(octave.score==100)
var silence=tracker()
for slot in 20..<40{silence.observe(time:(Double(slot)+0.1)/20,midi:nil)}
precondition(silence.score==0 && silence.coverage==0)
var wrong=tracker()
for slot in 20..<40{wrong.observe(time:(Double(slot)+0.1)/20,midi:62)}
precondition(wrong.score==0)
var partial=tracker();partial.observe(time:1.005,midi:60)
precondition(partial.score==5 && partial.capturedPercent==5)
for _ in 0..<100{partial.observe(time:1.005,midi:60)}
precondition(partial.score==5 && partial.evaluated==1)
partial.observe(time:1.005,midi:62)
precondition(partial.score==0 && partial.evaluated==1)
partial.observe(time:.nan,midi:60);precondition(partial.evaluated==1)
var free=SingingTracker();let freeNote=Note(id:0,start:1,end:2,midi:60,text:"唱",scored:false);free.reset(notes:[freeNote],lines:[LyricLine(id:0,notes:[freeNote])]);free.observe(time:1.005,midi:60);precondition(free.score==nil)
let result=perfect.result(title:"测试",artist:"测试")
precondition(result.bestLine=="唱" && result.bestLineScore==100 && result.lineScores.count==1)
print("PASS: perfect melody, octave match, silence, wrong pitch, partial performance, seek/replay deduplication, free singing and sentence result")
