import SwiftUI
import AppKit

final class AppDelegate:NSObject,NSApplicationDelegate {
 func applicationDidFinishLaunching(_ notification:Notification){
  NSApp.setActivationPolicy(.regular)
  NSApp.applicationIconImage=NSImage(size:NSSize(width:512,height:512),flipped:false){r in
   NSColor(calibratedRed:0.08,green:0.2,blue:0.18,alpha:1).setFill();NSBezierPath(roundedRect:r.insetBy(dx:12,dy:12),xRadius:110,yRadius:110).fill()
   NSColor(calibratedRed:0.5,green:0.94,blue:0.78,alpha:1).setStroke()
   for (i,height) in [90.0,170,270,190,110].enumerated(){let x=144+Double(i)*56;let p=NSBezierPath();p.lineWidth=25;p.lineCapStyle = .round;p.move(to:NSPoint(x:x,y:256-height/2));p.line(to:NSPoint(x:x,y:256+height/2));p.stroke()};return true
  }
  NSApp.activate(ignoringOtherApps:true)
 }
 func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication)->Bool{true}
}
@main struct QingChangApp:App {
 @NSApplicationDelegateAdaptor(AppDelegate.self)var delegate
 var body:some Scene{WindowGroup("轻唱 · 私人点歌台"){RootView()}.defaultSize(width:1280,height:820).windowStyle(.hiddenTitleBar).commands{CommandGroup(replacing:.newItem){};CommandGroup(replacing:.help){Button("关于轻唱"){NSApp.orderFrontStandardAboutPanel(options:[.applicationName:"轻唱",.applicationVersion:"0.6.0",.credits:NSAttributedString(string:"本地歌库 · 原生音频 · 简单点歌\n音准仅供娱乐参考")])}}}}
}
