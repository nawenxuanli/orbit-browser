import AppKit
let root = CommandLine.arguments[1]
try! FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)
for size in [16,32,128,256,512] {
 for scale in [1,2] {
  let pixels = size * scale
  let rep = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:pixels,pixelsHigh:pixels,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
  NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep:rep)
  let p = CGFloat(pixels)
  let rect = NSRect(x:p*0.06,y:p*0.06,width:p*0.88,height:p*0.88)
  let shape = NSBezierPath(roundedRect:rect,xRadius:p*0.21,yRadius:p*0.21)
  NSGradient(starting:NSColor(calibratedRed:0.1,green:0.3,blue:0.38,alpha:1),ending:NSColor(calibratedRed:0.05,green:0.12,blue:0.18,alpha:1))!.draw(in:shape,angle:90)
  NSColor(calibratedRed:0.4,green:0.87,blue:0.94,alpha:1).setStroke()
  for offset in [0.36,0.5,0.64] {
   let path = NSBezierPath(); path.lineWidth=p*0.047; path.lineCapStyle = .round
   path.move(to:NSPoint(x:p*0.25,y:p*offset))
   path.curve(to:NSPoint(x:p*0.5,y:p*offset),controlPoint1:NSPoint(x:p*0.34,y:p*(offset+0.13)),controlPoint2:NSPoint(x:p*0.41,y:p*(offset-0.13)))
   path.curve(to:NSPoint(x:p*0.75,y:p*offset),controlPoint1:NSPoint(x:p*0.59,y:p*(offset+0.13)),controlPoint2:NSPoint(x:p*0.66,y:p*(offset-0.13)))
   path.stroke()
  }
  NSGraphicsContext.restoreGraphicsState()
  let suffix = scale == 2 ? "@2x" : ""
  try! rep.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:root+"/icon_\(size)x\(size)\(suffix).png"))
 }
}

func bigEndian(_ number: Int) -> Data {
    var value = UInt32(number).bigEndian
    return withUnsafeBytes(of: &value) { Data($0) }
}
var chunks = Data()
for (code, name) in [("icp4","16x16"),("icp5","32x32"),("icp6","32x32@2x"),("ic07","128x128"),("ic08","256x256"),("ic09","512x512"),("ic10","512x512@2x")] {
    let png = try Data(contentsOf: URL(fileURLWithPath: root + "/icon_" + name + ".png"))
    chunks.append(Data(code.utf8)); chunks.append(bigEndian(png.count + 8)); chunks.append(png)
}
var output = Data("icns".utf8); output.append(bigEndian(chunks.count + 8)); output.append(chunks)
try output.write(to: URL(fileURLWithPath: CommandLine.arguments[2]), options: .atomic)
