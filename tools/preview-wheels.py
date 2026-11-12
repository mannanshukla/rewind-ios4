"""Render the production wheel drawing on macOS for visual comparison."""
from pathlib import Path
import subprocess
source=Path('src/main.m').read_text()
a=source.index('- (void)drawRect:',source.index('@implementation Wheel'))
b=source.index('- (void)touchesBegan:',a)
drawing=source[a:b].replace('UIGraphicsGetCurrentContext()','NSGraphicsContext.currentContext.CGContext').replace('[ink setFill];','previewInk=ink;[ink setFill];')
line=lambda name:source[source.index(name):source.index('\n',source.index(name))+1]
gradient=line('static void Gradient')+line('static UIColor *Shade(')
head=r'''
#import <AppKit/AppKit.h>
#define UIColor NSColor
#define UIFont NSFont
#define UILineBreakModeClip NSLineBreakByClipping
#define UITextAlignmentCenter NSTextAlignmentCenter
static NSColor *previewInk;
static NSColor *RGB(float r,float g,float b){return [NSColor colorWithSRGBRed:r green:g blue:b alpha:1];}
@interface NSString (Draw)
- (void)drawInRect:(NSRect)r withFont:(NSFont *)f lineBreakMode:(NSLineBreakMode)m alignment:(NSTextAlignment)a;
@end
@implementation NSString (Draw)
- (void)drawInRect:(NSRect)r withFont:(NSFont *)f lineBreakMode:(NSLineBreakMode)m alignment:(NSTextAlignment)a {NSMutableParagraphStyle *p=[[[NSMutableParagraphStyle alloc] init] autorelease];p.alignment=a;p.lineBreakMode=m;[self drawInRect:r withAttributes:@{NSFontAttributeName:f,NSParagraphStyleAttributeName:p,NSForegroundColorAttributeName:previewInk?:[NSColor grayColor]}];}
@end
'''
body=r'''
@interface TestWheel:NSView { @public BOOL dark,original,pressed,ring;CGFloat centerFraction;NSInteger style;NSColor *bodyTint; }
@end
@implementation TestWheel
- (BOOL)isFlipped{return YES;}
'''
end=r'''
@end
int main(){@autoreleasepool{[NSApplication sharedApplication];
for(int skin=0;skin<4;skin++){
NSBitmapImageRep *bitmap=[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:432 pixelsHigh:432 bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
NSGraphicsContext.currentContext=[NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap];CGContextRef c=NSGraphicsContext.currentContext.CGContext;CGContextTranslateCTM(c,0,432);CGContextScaleCTM(c,2,-2);NSGraphicsContext.currentContext=[NSGraphicsContext graphicsContextWithCGContext:c flipped:YES];
TestWheel *wheel=[[TestWheel alloc] initWithFrame:NSMakeRect(0,0,216,216)];wheel->style=skin;wheel->dark=skin==0;wheel->original=skin==1;wheel->centerFraction=skin==0?.49:skin==1?.28:skin==2?.32:.36;wheel->bodyTint=skin==0?RGB(.19,.21,.24):RGB(.79,.81,.83);[wheel drawRect:wheel.bounds];
[[bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:[NSString stringWithFormat:@"build/wheel-%d.png",skin] atomically:YES];[wheel release];[bitmap release];
}}}
'''
Path('build/wheel-preview.m').write_text(head+gradient+body+drawing+end)
subprocess.run(['clang','build/wheel-preview.m','-framework','AppKit','-o','build/wheel-preview'],check=True)
subprocess.run(['build/wheel-preview'],check=True)
