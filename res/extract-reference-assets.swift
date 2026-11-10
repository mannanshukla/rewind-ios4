import AppKit
import ImageIO
func crop(_ input:String,_ rect:CGRect,_ output:String,_ scale:Int=1) throws {
 let src=CGImageSourceCreateWithURL(URL(fileURLWithPath:input) as CFURL,nil)!
 let full=CGImageSourceCreateImageAtIndex(src,0,nil)!
 let im=full.cropping(to:rect)!
 let w=im.width*scale,h=im.height*scale
 let c=CGContext(data:nil,width:w,height:h,bitsPerComponent:8,bytesPerRow:w*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
 c.interpolationQuality = .none
 if output.contains("Icon") {c.addPath(CGPath(roundedRect:CGRect(x:0,y:0,width:w,height:h),cornerWidth:CGFloat(10*scale),cornerHeight:CGFloat(10*scale),transform:nil));c.clip()}
 c.draw(im,in:CGRect(x:0,y:0,width:w,height:h))
 let dst=CGImageDestinationCreateWithURL(URL(fileURLWithPath:output) as CFURL,"public.png" as CFString,1,nil)!
 CGImageDestinationAddImage(dst,c.makeImage()!,nil);CGImageDestinationFinalize(dst)
 print(output, im.width, im.height, full.alphaInfo.rawValue)
}
try crop("docs/reference/nano-3.png",CGRect(x:1198,y:20,width:272,height:360),"res/ShellNano.png")
try crop("docs/reference/mini-1.png",CGRect(x:434,y:18,width:200,height:360),"res/ShellMini.png")
try crop("docs/reference/classic-6.png",CGRect(x:0,y:18,width:375,height:631),"res/ShellClassic.png")
try crop("docs/reference/scroll-wheel.png",CGRect(x:0,y:18,width:400,height:664),"res/ShellOriginal.png")
try crop("docs/reference/iphone-os1-home.png",CGRect(x:246,y:398,width:57,height:57),"res/Icon.png")
try crop("docs/reference/iphone-os1-home.png",CGRect(x:246,y:398,width:57,height:57),"res/Icon@2x.png",2)
