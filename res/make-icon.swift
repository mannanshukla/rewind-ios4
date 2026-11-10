import AppKit
let r=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:114,pixelsHigh:114,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:r)
let bg=NSBezierPath(roundedRect:NSRect(x:0,y:0,width:114,height:114),xRadius:19,yRadius:19)
NSGradient(starting:NSColor(calibratedWhite:0.92,alpha:1),ending:NSColor(calibratedWhite:0.54,alpha:1))!.draw(in:bg,angle:90)
NSColor.black.setFill();NSBezierPath(roundedRect:NSRect(x:15,y:58,width:84,height:44),xRadius:4,yRadius:4).fill()
NSGradient(starting:NSColor(calibratedRed:0.05,green:0.34,blue:0.65,alpha:1),ending:NSColor(calibratedRed:0.5,green:0.78,blue:0.95,alpha:1))!.draw(in:NSRect(x:19,y:62,width:76,height:36),angle:90)
NSColor.white.setFill();NSBezierPath(ovalIn:NSRect(x:32,y:7,width:50,height:50)).fill()
NSColor(calibratedWhite:0.67,alpha:1).setFill();NSBezierPath(ovalIn:NSRect(x:48,y:23,width:18,height:18)).fill()
try r.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:"res/Icon@2x.png"))
