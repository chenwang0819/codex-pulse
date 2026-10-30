import Cocoa

let green = NSColor(calibratedRed:0.70,green:1,blue:0.39,alpha:1)
let cyan = NSColor(calibratedRed:0.37,green:0.85,blue:0.94,alpha:1)
class FloatingView: NSView {
 var detail = false
 var remaining: Double?; var weekly: Double?
 var working = 0; var unknown = 0; var connected = false
 var quotaTime = "等待额度数据"; var reset1: Double?; var reset2: Double?
 var dragOrigin = NSPoint.zero; var windowOrigin = NSPoint.zero; var dragged = false
 var animationTimer: Timer?
 var timer: Timer?; var pending = false; var phase: CGFloat = 0
 override var acceptsFirstResponder: Bool { true }
 override func viewDidMoveToWindow() {
  if timer == nil { poll(); timer = Timer.scheduledTimer(withTimeInterval:3,repeats:true){[weak self] _ in self?.poll()} }
  if animationTimer == nil {
   animationTimer=Timer.scheduledTimer(withTimeInterval:0.06,repeats:true){[weak self] _ in
    guard let self=self, self.connected, self.working>0, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {return}
    self.needsDisplay=true
   }
  }
 }
 func poll() {
  guard !pending else {return}; pending = true
  var request = URLRequest(url:URL(string:"http://127.0.0.1:8765/api/status")!);request.timeoutInterval=5
  URLSession.shared.dataTask(with:request){[weak self] data,response,error in
   DispatchQueue.main.async {
    guard let self = self else {return};self.pending=false
    guard error == nil, let data = data, let d = try? JSONSerialization.jsonObject(with:data) as? [String:Any] else {self.connected=false;self.needsDisplay=true;return}
    self.connected=true;self.working=d["working"] as? Int ?? 0;self.unknown=d["unknown"] as? Int ?? 0
    let limits=d["limits"] as? [String:Any];let value=limits?["value"] as? [String:Any]
    let p=value?["primary"] as? [String:Any];let s=value?["secondary"] as? [String:Any]
    self.remaining=(p?["used_percent"] as? Double).map{max(0,min(100,100-$0))}
    self.weekly=(s?["used_percent"] as? Double).map{max(0,min(100,100-$0))}
    self.reset1=p?["resets_at"] as? Double;self.reset2=s?["resets_at"] as? Double
    if let at=limits?["at"] as? String {self.quotaTime="采样 "+at.replacingOccurrences(of:"T",with:" ").prefix(19)+" UTC"}
    self.needsDisplay=true
   }
  }.resume()
 }
 func text(_ str:String,_ rect:NSRect,_ size:CGFloat,_ color:NSColor,_ weight:NSFont.Weight = .regular, center:Bool=false) {
  let style=NSMutableParagraphStyle();style.alignment=center ? .center : .left
  (str as NSString).draw(in:rect,withAttributes:[.font:NSFont.monospacedDigitSystemFont(ofSize:size,weight:weight),.foregroundColor:color,.paragraphStyle:style])
 }
 func countdown(_ value:Double?) -> String {
  guard let value=value else{return "等待数据"};let n=Int(value-Date().timeIntervalSince1970)
  if n<=0 {return "待新采样"};return "\(n/3600)h \((n%3600)/60)m 后重置"
 }
 override func draw(_ dirtyRect:NSRect) {
  NSColor.clear.setFill();bounds.fill()
  if detail {
   let bg=NSBezierPath(roundedRect:NSRect(x:0,y:0,width:280,height:242),xRadius:20,yRadius:20)
   NSColor(calibratedRed:0.055,green:0.075,blue:0.10,alpha:0.97).setFill();bg.fill()
   NSColor.white.withAlphaComponent(0.13).setStroke();bg.lineWidth=1;bg.stroke()
   text("CODEX PULSE",NSRect(x:20,y:198,width:210,height:22),14,green,.bold)
   text("点击小球收起 · 拖动移动",NSRect(x:20,y:174,width:240,height:17),10,.gray)
   text("5 小时剩余",NSRect(x:20,y:140,width:110,height:18),11,.lightGray)
   text("周额度剩余",NSRect(x:155,y:140,width:110,height:18),11,.lightGray)
   text(remaining.map{String(format:"%.0f%%",$0)} ?? "—",NSRect(x:20,y:99,width:115,height:39),30,green,.semibold)
   text(weekly.map{String(format:"%.0f%%",$0)} ?? "—",NSRect(x:155,y:99,width:115,height:39),30,cyan,.semibold)
   text(countdown(reset1),NSRect(x:20,y:80,width:130,height:17),10,.gray)
   text(countdown(reset2),NSRect(x:155,y:80,width:120,height:17),10,.gray)
   text(!connected ? "● 连接断开" : working>0 ? "● Codex 正在工作 · \(working)" : unknown>0 ? "◌ 运行状态待确认" : "○ Codex 空闲",NSRect(x:20,y:44,width:240,height:22),12,connected ? green : .orange)
   text(quotaTime,NSRect(x:20,y:18,width:245,height:17),9,.gray)
  }
  NSGraphicsContext.saveGraphicsState()
  let transform=NSAffineTransform()
  transform.translateX(by:detail ? 182 : 8,yBy:detail ? 248 : 8)
  transform.scale(by:5.0/6.0);transform.concat()
  let shell=NSRect(x:0,y:0,width:108,height:108)
  let center=NSPoint(x:shell.midX,y:shell.midY)
  let ice=NSColor(calibratedRed:0.38,green:0.85,blue:1,alpha:1)
  let violet=NSColor(calibratedRed:0.63,green:0.59,blue:1,alpha:1)
  let active=connected && working>0
  let breath:CGFloat = active && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0.5+0.5*sin(Date.timeIntervalSinceReferenceDate*(2 * .pi / 3)) : 0
  let body=NSBezierPath(ovalIn:shell)
  NSColor(calibratedRed:0.035,green:0.05,blue:0.08,alpha:0.98).setFill();body.fill()
  if active {
   // Illuminate the whole face, while keeping the quota text at constant brightness.
   let haze=NSGradient(starting:ice.withAlphaComponent(0.05+breath*0.24),ending:violet.withAlphaComponent(0.015+breath*0.07))!
   haze.draw(in:body,relativeCenterPosition:NSPoint(x:0,y:0.25))
   let halo=NSBezierPath(ovalIn:shell.insetBy(dx:0.9,dy:0.9));halo.lineWidth=1.2
   let glow=NSShadow();glow.shadowColor=ice.withAlphaComponent(0.10+breath*0.65);glow.shadowBlurRadius=2+breath*7
   NSGraphicsContext.saveGraphicsState();glow.set();ice.withAlphaComponent(0.08+breath*0.52).setStroke();halo.stroke();NSGraphicsContext.restoreGraphicsState()
  }
  let rim=NSBezierPath(ovalIn:shell.insetBy(dx:0.5,dy:0.5));rim.lineWidth=0.6;NSColor.white.withAlphaComponent(0.14).setStroke();rim.stroke()
  func arc(_ radius:CGFloat,_ start:CGFloat,_ end:CGFloat) -> NSBezierPath {
   let p=NSBezierPath();p.appendArc(withCenter:center,radius:radius,startAngle:start,endAngle:end,clockwise:true);p.lineCapStyle = .round;return p
  }
  // A shared opening at the bottom gives both gauges the same visual origin.
  for (radius,value,color) in [(CGFloat(49),remaining,ice),(CGFloat(44),weekly,violet)] {
   let track=arc(radius,240,-60);track.lineWidth=1.8;color.withAlphaComponent(0.12).setStroke();track.stroke()
   if let value=value {
    let progress=arc(radius,240,240-CGFloat(value)*3)
    progress.lineWidth=1.9
    let glow=NSShadow();glow.shadowColor=color.withAlphaComponent(active ? 0.15+breath*0.65 : 0.15);glow.shadowBlurRadius=active ? 2+breath*7 : 2
    NSGraphicsContext.saveGraphicsState();glow.set();(connected ? color.withAlphaComponent(active ? 0.45+breath*0.55 : 1) : NSColor.gray).setStroke();progress.stroke();NSGraphicsContext.restoreGraphicsState()
   }
  }
  let muted=NSColor(calibratedRed:0.50,green:0.58,blue:0.67,alpha:1)
  text("5小时",NSRect(x:shell.minX+17,y:shell.minY+66,width:37,height:13),8,ice,.medium,center:true)
  text("本周",NSRect(x:shell.minX+54,y:shell.minY+66,width:37,height:13),8,violet,.medium,center:true)
  func value(_ value:Double?,_ rect:NSRect) {
   let color: NSColor=connected ? .white : muted
   let str=NSMutableAttributedString(string:value.map{String(format:"%.0f",$0)} ?? "—",attributes:[.font:NSFont.monospacedDigitSystemFont(ofSize:17,weight:.medium),.foregroundColor:color])
   if value != nil {str.append(NSAttributedString(string:"%",attributes:[.font:NSFont.systemFont(ofSize:10,weight:.medium),.foregroundColor:color.withAlphaComponent(0.65)]))}
   let size=str.size();str.draw(at:NSPoint(x:rect.midX-size.width/2,y:rect.minY))
  }
  value(remaining,NSRect(x:shell.minX+15,y:shell.minY+45,width:41,height:24))
  value(weekly,NSRect(x:shell.minX+52,y:shell.minY+45,width:41,height:24))
  let statusColor: NSColor = !connected ? .orange : active ? ice : unknown>0 ? .orange : muted
  let label = !connected ? "离线" : active ? "工作中" : unknown>0 ? "待确认" : "空闲"
  if active {
   let badge=NSBezierPath(roundedRect:NSRect(x:29,y:23,width:50,height:18),xRadius:6,yRadius:6)
   ice.withAlphaComponent(0.84+breath*0.16).setFill();badge.fill()
   text(label,NSRect(x:29,y:25,width:50,height:14),10,NSColor(calibratedRed:0.025,green:0.10,blue:0.15,alpha:1),.bold,center:true)
  } else {
   let badge=NSBezierPath(roundedRect:NSRect(x:29,y:23,width:50,height:18),xRadius:6,yRadius:6)
   statusColor.withAlphaComponent(0.12).setFill();badge.fill()
   text(label,NSRect(x:29,y:25,width:50,height:14),9.5,statusColor,.semibold,center:true)
  }
  NSGraphicsContext.restoreGraphicsState()
 }
 override func mouseDown(with event:NSEvent) {dragOrigin=NSEvent.mouseLocation;windowOrigin=window!.frame.origin;dragged=false}
 override func mouseDragged(with event:NSEvent) {
  let now=NSEvent.mouseLocation;let dx=now.x-dragOrigin.x,dy=now.y-dragOrigin.y
  if abs(dx)+abs(dy)>3 {dragged=true}
  if dragged {window?.setFrameOrigin(NSPoint(x:windowOrigin.x+dx,y:windowOrigin.y+dy))}
 }
 override func mouseUp(with event:NSEvent) {
  guard !dragged,let window=window else {return}
  let point=convert(event.locationInWindow,from:nil)
  if detail && point.y<242 {return}
  let old=window.frame;detail.toggle()
  var next = detail ? NSRect(x:old.minX-174,y:old.minY-240,width:280,height:346) : NSRect(x:old.minX+174,y:old.minY+240,width:106,height:106)
  if let screen=window.screen {let v=screen.visibleFrame;next.origin.x=max(v.minX,min(v.maxX-next.width,next.minX));next.origin.y=max(v.minY,min(v.maxY-next.height,next.minY))}
  window.setFrame(next,display:true);needsDisplay=true
 }
 override func rightMouseDown(with event:NSEvent) {
  let menu=NSMenu();let refresh=menu.addItem(withTitle:"刷新额度",action:#selector(refreshNow),keyEquivalent:"");refresh.target=self
  menu.addItem(NSMenuItem.separator());let quit=menu.addItem(withTitle:"退出悬浮球",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"q");quit.target=NSApp
  NSMenu.popUpContextMenu(menu,with:event,for:self)
 }
 @objc func refreshNow(){poll()}
}
class Delegate:NSObject,NSApplicationDelegate {
 func applicationWillTerminate(_ notification:Notification){if backend?.isRunning == true {backend?.terminate()}}
 var panel:NSPanel!
 var backend:Process?
 func applicationDidFinishLaunching(_ notification:Notification) {
  NSApp.setActivationPolicy(.accessory)
  let server=Bundle.main.resourceURL!.appendingPathComponent("server.py")
  let process=Process();process.executableURL=URL(fileURLWithPath:"/usr/bin/env");process.arguments=["python3",server.path];process.standardOutput=FileHandle.nullDevice;process.standardError=FileHandle.nullDevice
  try? process.run();backend=process
  let frame=NSScreen.main?.visibleFrame ?? NSRect(x:0,y:0,width:1200,height:800)
  panel=NSPanel(contentRect:NSRect(x:frame.maxX-128,y:frame.maxY-185,width:106,height:106),styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
  panel.level = .floating;panel.isOpaque=false;panel.backgroundColor = .clear;panel.hasShadow=false
  panel.collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary];panel.isMovableByWindowBackground=false
  panel.contentView=FloatingView(frame:NSRect(x:0,y:0,width:106,height:106));panel.orderFrontRegardless()
 }
}
let app=NSApplication.shared;let delegate=Delegate();app.delegate=delegate;app.run()
