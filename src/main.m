#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>
#import <QuartzCore/QuartzCore.h>
#import <AudioToolbox/AudioToolbox.h>
#import "WheelMath.h"
#import "ClickSounds.h"
static UIColor *RGB(float r,float g,float b){return [UIColor colorWithRed:r green:g blue:b alpha:1];}
static void Gradient(CGContextRef c,CGRect r,UIColor *a,UIColor *b){CGColorSpaceRef s=CGColorSpaceCreateDeviceRGB();NSArray *colors=[NSArray arrayWithObjects:(id)a.CGColor,(id)b.CGColor,nil];CGGradientRef g=CGGradientCreateWithColors(s,(CFArrayRef)colors,NULL);CGContextSaveGState(c);CGContextClipToRect(c,r);CGContextDrawLinearGradient(c,g,CGPointMake(CGRectGetMidX(r),r.origin.y),CGPointMake(CGRectGetMidX(r),CGRectGetMaxY(r)),0);CGContextRestoreGState(c);CGGradientRelease(g);CGColorSpaceRelease(s);}

// Overflowing text is drawn once into a strip; Core Animation scrolls it on the
// render server at display rate. No timer, no per-frame redraw, no CPU work.
#import "ScrollMath.h"
@interface ScrollLabel : UILabel { BOOL scrolling; CALayer *strip; NSString *stripKey; CGFloat stripDistance; }
@property(nonatomic,assign) BOOL scrolling;
- (void)restart;
- (void)purge;
- (void)freeze:(BOOL)value;
@end
@implementation ScrollLabel
@synthesize scrolling;
- (id)initWithFrame:(CGRect)frame {if((self=[super initWithFrame:frame])){scrolling=YES;self.clipsToBounds=YES;}return self;}
- (BOOL)overflows {return scrolling&&self.window&&!self.hidden&&self.numberOfLines==1&&self.text.length&&self.bounds.size.width>0&&[self.text sizeWithFont:self.font].width>self.bounds.size.width;}
- (void)purge {if(!strip)return;[strip removeFromSuperlayer];[strip release];strip=nil;[stripKey release];stripKey=nil;[self setNeedsDisplay];}
- (void)restart {
    if(!strip){[self refresh];return;}
    [strip removeAnimationForKey:@"marquee"];
    double travel=stripDistance/24.0,total=RW_SCROLL_PAUSE+travel;
    CAKeyframeAnimation *a=[CAKeyframeAnimation animationWithKeyPath:@"position.x"];
    a.values=[NSArray arrayWithObjects:[NSNumber numberWithDouble:0],[NSNumber numberWithDouble:0],[NSNumber numberWithDouble:-stripDistance],nil];
    a.keyTimes=[NSArray arrayWithObjects:[NSNumber numberWithDouble:0],[NSNumber numberWithDouble:RW_SCROLL_PAUSE/total],[NSNumber numberWithDouble:1],nil];
    a.duration=total;a.repeatCount=HUGE_VALF;a.removedOnCompletion=NO;
    [strip addAnimation:a forKey:@"marquee"];
}
- (void)refresh {
    if(![self overflows]){[self purge];return;}
    UIColor *color=(self.highlighted&&self.highlightedTextColor)?self.highlightedTextColor:self.textColor;
    CGSize box=self.bounds.size;
    NSString *key=[NSString stringWithFormat:@"%@|%@|%.2f|%@|%.1f|%.1f",self.text,self.font.fontName,self.font.pointSize,color,box.width,box.height];
    if(strip&&[key isEqualToString:stripKey])return;
    CGSize size=[self.text sizeWithFont:self.font];stripDistance=ceil(size.width)+RW_SCROLL_GAP;
    CGFloat scale=self.contentScaleFactor;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(stripDistance+ceil(size.width),box.height),NO,scale);
    [color setFill];CGFloat y=floor((box.height-size.height)/2);
    [self.text drawAtPoint:CGPointMake(0,y) withFont:self.font];[self.text drawAtPoint:CGPointMake(stripDistance,y) withFont:self.font];
    UIImage *image=UIGraphicsGetImageFromCurrentImageContext();UIGraphicsEndImageContext();
    [CATransaction begin];[CATransaction setDisableActions:YES];
    if(!strip){strip=[[CALayer alloc] init];strip.anchorPoint=CGPointZero;[self.layer addSublayer:strip];[self setNeedsDisplay];}
    strip.contents=(id)image.CGImage;strip.contentsScale=scale;strip.frame=CGRectMake(0,0,image.size.width,box.height);
    [CATransaction commit];
    BOOL sameText=stripKey&&[[[stripKey componentsSeparatedByString:@"|"] objectAtIndex:0] isEqualToString:self.text];
    [stripKey release];stripKey=[key copy];
    if(!sameText||![strip animationForKey:@"marquee"])[self restart];
}
// Snapshots render the model tree, so pin the strip where it is on screen.
- (void)freeze:(BOOL)value {if(!strip)return;[CATransaction begin];[CATransaction setDisableActions:YES];CALayer *shown=(CALayer *)strip.presentationLayer;strip.position=value&&shown?shown.position:CGPointZero;[CATransaction commit];}
- (void)drawTextInRect:(CGRect)rect {if(!strip)[super drawTextInRect:rect];}
- (void)setText:(NSString *)text {if([self.text isEqualToString:text])return;[super setText:text];[self refresh];}
- (void)setFont:(UIFont *)font {[super setFont:font];[self refresh];}
- (void)setTextColor:(UIColor *)color {[super setTextColor:color];[self refresh];}
- (void)setHighlighted:(BOOL)value {if(value==self.highlighted)return;[super setHighlighted:value];[self refresh];}
- (void)setHidden:(BOOL)value {if(value==self.hidden)return;[super setHidden:value];[self refresh];}
- (void)setScrolling:(BOOL)value {if(scrolling!=value){scrolling=value;[self refresh];}}
- (void)layoutSubviews {[super layoutSubviews];[self refresh];}
- (void)didMoveToWindow {[super didMoveToWindow];[self refresh];}
- (void)dealloc {[strip release];[stripKey release];[super dealloc];}
@end
static void FreezeLabels(UIView *view,BOOL value) {if([view isKindOfClass:[ScrollLabel class]])[(ScrollLabel *)view freeze:value];for(UIView *child in view.subviews)FreezeLabels(child,value);}
// restart: begin every marquee again from its pause. Otherwise release the strips.
static void PulseLabels(UIView *view,BOOL restart) {
    if([view isKindOfClass:[ScrollLabel class]]){if(restart)[(ScrollLabel *)view restart];else [(ScrollLabel *)view purge];}
    for(UIView *child in view.subviews)PulseLabels(child,restart);
}

static UIColor *Shade(UIColor *color,CGFloat factor){const CGFloat *v=CGColorGetComponents(color.CGColor);return RGB(MIN(1,v[0]*factor),MIN(1,v[1]*factor),MIN(1,v[2]*factor));}
static NSArray *ColorNames(NSInteger skin){
    if(skin==0)return @[@"Black",@"Silver",@"Blue",@"Green",@"Red",@"Pink"];
    if(skin==2)return @[@"Silver",@"Blue",@"Green",@"Pink",@"Gold"];
    if(skin==3)return @[@"Silver",@"Black"];
    return @[@"White"];
}
static NSInteger ColorChoice(NSInteger skin){NSString *key=[NSString stringWithFormat:@"Color%ld",(long)skin];id saved=[[NSUserDefaults standardUserDefaults] objectForKey:key];NSInteger choice=saved?[saved integerValue]:(skin==2?1:0);return MAX(0,MIN((NSInteger)ColorNames(skin).count-1,choice));}
static UIColor *BodyTint(NSInteger skin){
    NSArray *colors=skin==0?@[RGB(.19,.21,.24),RGB(.78,.80,.81),RGB(.43,.72,.75),RGB(.65,.78,.53),RGB(.68,.13,.27),RGB(.84,.32,.58)]:skin==2?@[RGB(.79,.81,.81),RGB(.43,.66,.79),RGB(.67,.80,.39),RGB(.85,.50,.66),RGB(.76,.64,.37)]:skin==3?@[RGB(.79,.81,.83),RGB(.23,.24,.26)]:@[RGB(.96,.97,.97)];return [colors objectAtIndex:ColorChoice(skin)];
}
@interface LCDBar : UIView {BOOL selected,mono;}
@property(nonatomic) BOOL selected,mono;
@end
@implementation LCDBar
@synthesize selected,mono;
- (void)drawRect:(CGRect)r {if(mono){[(selected?RGB(.12,.18,.09):RGB(.65,.72,.52)) setFill];UIRectFill(r);}else Gradient(UIGraphicsGetCurrentContext(),r,selected?RGB(.24,.73,.98):RGB(1,1,1),selected?RGB(.02,.42,.79):RGB(.76,.79,.81));}
@end
@interface Battery : UIView {BOOL playing,hasItem;}
@property(nonatomic) BOOL playing,hasItem;
@end
@implementation Battery
@synthesize playing,hasItem;
- (void)drawRect:(CGRect)r {CGContextRef c=UIGraphicsGetCurrentContext();
CGContextSetFillColorWithColor(c,RGB(.32,.37,.40).CGColor);
if(hasItem){if(playing){CGContextMoveToPoint(c,2,4);CGContextAddLineToPoint(c,2,13);CGContextAddLineToPoint(c,10,8.5);CGContextClosePath(c);CGContextFillPath(c);}else{CGContextFillRect(c,CGRectMake(2,4,3,9));CGContextFillRect(c,CGRectMake(7,4,3,9));}}
CGContextTranslateCTM(c,18,0);CGContextSetStrokeColorWithColor(c,RGB(.38,.42,.42).CGColor);CGContextStrokeRect(c,CGRectMake(1,3,23,10));CGContextSetFillColorWithColor(c,RGB(.5,.53,.53).CGColor);CGContextFillRect(c,CGRectMake(24,6,2,4));float v=[UIDevice currentDevice].batteryLevel;if(v<0)v=1;Gradient(c,CGRectMake(3,5,19*v,6),RGB(.65,.91,.36),RGB(.28,.62,.06));}
@end

@protocol WheelDelegate
- (void)wheelTurn:(int)steps;
- (void)wheelButton:(int)button;
@end
// The wheel is drawn once per skin/color. A press only toggles a small shape
// layer; it never redraws the full-resolution wheel bitmap.
@interface Wheel : UIView {id<WheelDelegate> delegate;BOOL dark,ring,rotated,angleValid,original;CGPoint start;double angle,travel,accum;NSTimeInterval last;CGFloat centerFraction;NSInteger style;UIColor *bodyTint;CAShapeLayer *press;}
@property(nonatomic,assign) id<WheelDelegate> delegate;
@property(nonatomic) BOOL dark,original;
@property(nonatomic) CGFloat centerFraction;
@property(nonatomic) NSInteger style;
@property(nonatomic,retain) UIColor *bodyTint;
@end
@implementation Wheel
@synthesize delegate,dark,original,centerFraction,style,bodyTint;
- (void)setDark:(BOOL)v {dark=v;[self setNeedsDisplay];}
- (void)setPressed:(BOOL)v {
    if(!press){press=[[CAShapeLayer alloc] init];press.fillColor=[UIColor colorWithWhite:0 alpha:.10].CGColor;[self.layer addSublayer:press];}
    CGFloat w=self.bounds.size.width,d=w*centerFraction;
    [CATransaction begin];[CATransaction setDisableActions:YES];
    CGMutablePathRef path=CGPathCreateMutable();CGPathAddEllipseInRect(path,NULL,CGRectMake((w-d)/2,(w-d)/2,d,d));press.path=path;CGPathRelease(path);press.hidden=!v;
    [CATransaction commit];
}
- (void)drawRect:(CGRect)rect {
    CGContextRef c=UIGraphicsGetCurrentContext();CGFloat w=self.bounds.size.width,m=w/2;
    CGRect outer=CGRectInset(self.bounds,.7,.7);
    // Printed labels: bold, gray-blue on white wheels, pale gray on dark wheels.
    UIColor *ink=dark?RGB(.80,.82,.84):original?RGB(.50,.55,.57):RGB(.55,.60,.66);
    CGContextSaveGState(c);CGContextAddEllipseInRect(c,outer);CGContextClip(c);
    Gradient(c,outer,dark?RGB(.14,.16,.18):RGB(.99,.995,1),dark?RGB(.10,.12,.14):RGB(.94,.95,.95));CGContextRestoreGState(c);
    CGContextSetLineWidth(c,.65);CGContextSetStrokeColorWithColor(c,(dark?RGB(.08,.09,.10):RGB(.64,.67,.68)).CGColor);CGContextStrokeEllipseInRect(c,outer);
    if(original){
        // Four independent buttons surround the mechanical scroll wheel.
        for(int i=0;i<4;i++){double a=M_PI/4+i*M_PI/2;CGContextMoveToPoint(c,m+cos(a)*m*.79,m+sin(a)*m*.79);CGContextAddLineToPoint(c,m+cos(a)*(m-1),m+sin(a)*(m-1));CGContextStrokePath(c);}
        CGRect inner=CGRectInset(self.bounds,w*.105,w*.105);
        CGContextSetStrokeColorWithColor(c,RGB(.32,.35,.36).CGColor);CGContextSetLineWidth(c,1.3);CGContextStrokeEllipseInRect(c,inner);
        CGContextSaveGState(c);CGContextAddEllipseInRect(c,CGRectInset(inner,1,1));CGContextClip(c);Gradient(c,inner,RGB(.98,.985,.99),RGB(.88,.90,.91));CGContextRestoreGState(c);
    }
    CGFloat diameter=w*centerFraction;CGRect center=CGRectMake((w-diameter)/2,(w-diameter)/2,diameter,diameter);
    CGContextSaveGState(c);CGContextAddEllipseInRect(c,center);CGContextClip(c);
    UIColor *centerTop=(style==0||style==3)?bodyTint:RGB(.97,.98,.98);
    Gradient(c,center,Shade(centerTop,1.04),(style==0||style==3)?Shade(centerTop,.95):RGB(.89,.91,.92));
    CGContextRestoreGState(c);CGContextSetLineWidth(c,.6);CGContextSetStrokeColorWithColor(c,(dark?RGB(.07,.09,.11):RGB(.62,.66,.68)).CGColor);CGContextStrokeEllipseInRect(c,center);
    [ink setFill];CGFloat fs=w*(original?.061:.072);
    UIFont *font=[UIFont fontWithName:@"Helvetica-Bold" size:fs];
    [(original?@"menu":@"MENU") drawInRect:CGRectMake(0,w*(original?.022:.058),w,fs*1.3) withFont:font lineBreakMode:UILineBreakModeClip alignment:UITextAlignmentCenter];
    // Skip glyphs: two touching triangles with the bar on the outer side (|<< and >>|).
    CGFloat radius=m*(original?.88:.74),gh=w*(original?.018:.022),gw=w*(original?.019:.034),bar=w*(original?.010:.012);
    for(int side=-1;side<=1;side+=2){CGFloat x=m+side*radius;for(int i=0;i<2;i++){CGFloat tip=x+side*(i*gw-gw*.35);CGContextMoveToPoint(c,tip,m);CGContextAddLineToPoint(c,tip-side*gw,m-gh);CGContextAddLineToPoint(c,tip-side*gw,m+gh);CGContextClosePath(c);CGContextFillPath(c);}CGContextFillRect(c,CGRectMake(side>0?x+gw*.65:x-gw*.65-bar,m-gh,bar,gh*2));}
    CGFloat y=m+radius,pw=gw*1.05;CGContextMoveToPoint(c,m-pw*1.1,y-gh);CGContextAddLineToPoint(c,m-pw*1.1,y+gh);CGContextAddLineToPoint(c,m-pw*.1+gw*.05,y);CGContextClosePath(c);CGContextFillPath(c);CGContextFillRect(c,CGRectMake(m+pw*.25,y-gh,bar*1.05,gh*2));CGContextFillRect(c,CGRectMake(m+pw*.25+bar*2.1,y-gh,bar*1.05,gh*2));
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)e {UITouch *t=[touches anyObject];start=[t locationInView:self];CGFloat h=self.bounds.size.width/2;double x=start.x-h,y=start.y-h;double radius=hypot(x,y);ring=radius>h*centerFraction&&(!original||radius<h*.79);angle=atan2(y,x);travel=accum=0;rotated=NO;angleValid=YES;[self setPressed:!ring];last=t.timestamp;}
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)e {if(!ring)return;UITouch *t=[touches anyObject];CGPoint p=[t locationInView:self];CGFloat h=self.bounds.size.width/2;if(hypot(p.x-h,p.y-h)<h*(centerFraction-.03)){angleValid=NO;accum=0;return;}double next=atan2(p.y-h,p.x-h);if(!angleValid){angleValid=YES;angle=next;last=t.timestamp;return;}double d=RWAngleDelta(next,angle);angle=next;last=t.timestamp;travel+=fabs(d);if(travel>.12)rotated=YES;int n=RWConsumeWheelSteps(&accum,d);if(n)[delegate wheelTurn:n];}
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)e {[self setPressed:NO];if(rotated)return;CGPoint p=[[touches anyObject] locationInView:self];if(hypot(p.x-start.x,p.y-start.y)>18)return;CGFloat h=self.bounds.size.width/2;double x=p.x-h,y=p.y-h;if(hypot(x,y)<h*centerFraction){[delegate wheelButton:0];return;}if(original&&hypot(x,y)<h*.79)return;if(fabs(y)>fabs(x))[delegate wheelButton:y<0?1:2];else [delegate wheelButton:x<0?3:4];}
- (void)touchesCancelled:(NSSet *)t withEvent:(UIEvent *)e {rotated=YES;accum=0;[self setPressed:NO];}
- (void)dealloc {[press release];[bodyTint release];[super dealloc];}
@end
// The body is two Core Animation layers (gradient + edge line). No full-screen
// drawRect bitmap: that alone was ~2.4 MB of backing store on a Retina iPod.
@interface Shell : UIView {NSInteger skin;CGRect displayRect,wheelRect;CAGradientLayer *lower;CALayer *edge;}
@property(nonatomic) NSInteger skin;
@property(nonatomic,readonly) CGRect displayRect,wheelRect;
@end
@implementation Shell
@synthesize skin,displayRect,wheelRect;
- (id)initWithFrame:(CGRect)frame {
    if((self=[super initWithFrame:frame])){lower=[[CAGradientLayer alloc] init];edge=[[CALayer alloc] init];edge.backgroundColor=RGB(.12,.13,.14).CGColor;[self.layer addSublayer:lower];[self.layer addSublayer:edge];}
    return self;
}
- (void)setSkin:(NSInteger)v {
    skin=v;UIColor *base=BodyTint(skin);self.backgroundColor=base;
    [CATransaction begin];[CATransaction setDisableActions:YES];
    lower.colors=[NSArray arrayWithObjects:(id)Shade(base,1.06).CGColor,(id)Shade(base,.90).CGColor,nil];
    [CATransaction commit];[self setNeedsLayout];
}
- (void)layoutSubviews {
    // The host iPod touch is the enclosure: LCD above, full-size wheel below.
    CGFloat width=self.bounds.size.width,height=self.bounds.size.height;
    CGFloat displayHeight=width*((skin==1)?128.0/160:(skin==2)?110.0/138:240.0/320);
    displayRect=CGRectMake(0,0,width,displayHeight);
    CGFloat diameter=MIN(width-36,height-displayHeight-24);
    wheelRect=CGRectMake((width-diameter)/2,displayHeight+(height-displayHeight-diameter)/2,diameter,diameter);
    [CATransaction begin];[CATransaction setDisableActions:YES];
    lower.frame=CGRectMake(0,displayHeight,width,height-displayHeight);edge.frame=CGRectMake(0,displayHeight,width,1);
    [CATransaction commit];
}
- (void)dealloc {[lower release];[edge release];[super dealloc];}
@end
// Monochrome models use their real pixel canvases, not a scaled color interface.
// Marquee speed in logical LCD pixels per second. The Player's display link
// fires every third frame (20 Hz), so each redraw moves exactly one pixel.
#define RW_MONO_SCROLL_SPEED 20.0
@interface MonoLCD : UIView {
    NSDictionary *model;
    NSString *scrollIdentity;NSTimeInterval scrollBegan;BOOL wantsScroll;
}
@property(nonatomic,copy) NSDictionary *model;
@property(nonatomic,readonly) BOOL wantsScroll;
@end
@implementation MonoLCD
@synthesize model,wantsScroll;
- (UIFont *)lcdFont {return [UIFont fontWithName:@"Chicago" size:12]?:[UIFont boldSystemFontOfSize:12];}
- (NSInteger)capacity {return (NSInteger)((self.bounds.size.height-17)/16);}
- (BOOL)showsScrollBar {return ![[model objectForKey:@"now"] boolValue]&&(NSInteger)[[model objectForKey:@"rows"] count]>[self capacity];}
- (void)setModel:(NSDictionary *)v {
    NSString *identity=[NSString stringWithFormat:@"%@/%@/%@/%@",[v objectForKey:@"title"],[v objectForKey:@"selection"],[v objectForKey:@"now"],[v objectForKey:@"lines"]];
    if(![identity isEqualToString:scrollIdentity]){[scrollIdentity release];scrollIdentity=[identity copy];scrollBegan=CACurrentMediaTime();}
    if(model!=v){[model release];model=[v copy];}
    // Work out once whether anything overflows, so the display link only runs then.
    UIFont *font=[self lcdFont];CGFloat w=self.bounds.size.width;BOOL overflow=[[model objectForKey:@"title"] sizeWithFont:font].width>w-46;
    if([[model objectForKey:@"now"] boolValue]){for(NSString *line in [model objectForKey:@"lines"])overflow=overflow||[line sizeWithFont:font].width>w-6;}
    else {NSArray *items=[model objectForKey:@"rows"];NSInteger selected=[[model objectForKey:@"selection"] integerValue];if(selected>=0&&selected<(NSInteger)items.count)overflow=overflow||[[[items objectAtIndex:selected] objectForKey:@"title"] sizeWithFont:font].width>w-([self showsScrollBar]?23:15);}
    wantsScroll=overflow;[self setNeedsDisplay];
}
- (void)text:(NSString *)text rect:(CGRect)rect font:(UIFont *)font centered:(BOOL)centered scroll:(BOOL)scroll {
    CGFloat width=[text sizeWithFont:font].width;
    if(!scroll||width<=rect.size.width){[text drawInRect:rect withFont:font lineBreakMode:UILineBreakModeTailTruncation alignment:centered?UITextAlignmentCenter:UITextAlignmentLeft];return;}
    CGFloat offset=RWScrollOffsetAt(width,rect.size.width,CACurrentMediaTime()-scrollBegan,RW_MONO_SCROLL_SPEED);
    CGContextRef c=UIGraphicsGetCurrentContext();CGContextSaveGState(c);CGContextClipToRect(c,rect);
    [text drawAtPoint:CGPointMake(rect.origin.x-offset,rect.origin.y) withFont:font];
    if(offset>0)[text drawAtPoint:CGPointMake(rect.origin.x-offset+width+28,rect.origin.y) withFont:font];
    CGContextRestoreGState(c);
}
- (void)drawRect:(CGRect)rect {
    CGContextRef c=UIGraphicsGetCurrentContext();CGContextSetShouldAntialias(c,NO);
    BOOL mini=[[model objectForKey:@"mini"] boolValue];
    UIColor *paper=mini?RGB(.77,.83,.87):RGB(.80,.81,.75);
    UIColor *ink=mini?RGB(.15,.19,.32):RGB(.17,.18,.16);
    [paper setFill];UIRectFill(self.bounds);[ink setFill];
    CGFloat w=self.bounds.size.width,h=self.bounds.size.height;
    UIFont *font=[self lcdFont];
    NSString *title=[model objectForKey:@"title"];
    [self text:title rect:CGRectMake(23,0,w-46,15) font:font centered:YES scroll:YES];
    if([[model objectForKey:@"playing"] boolValue]){CGContextMoveToPoint(c,3,3);CGContextAddLineToPoint(c,3,11);CGContextAddLineToPoint(c,10,7);CGContextClosePath(c);CGContextFillPath(c);}
    CGContextSetStrokeColorWithColor(c,ink.CGColor);CGContextStrokeRect(c,CGRectMake(w-20,3,16,8));CGContextFillRect(c,CGRectMake(w-3,5,2,4));
    float batteryLevel=[UIDevice currentDevice].batteryLevel;if(batteryLevel<0)batteryLevel=1;
    for(int i=0;i<4;i++)if(batteryLevel>(float)i/4)CGContextFillRect(c,CGRectMake(w-18+i*3,5,2,4));
    CGContextFillRect(c,CGRectMake(0,15,w,1));
    if([[model objectForKey:@"now"] boolValue]) {
        NSArray *lines=[model objectForKey:@"lines"];
        for(NSUInteger i=0;i<lines.count;i++)[self text:[lines objectAtIndex:i] rect:CGRectMake(3,24+i*15,w-6,15) font:font centered:YES scroll:YES];
        CGRect bar=CGRectMake(6,h-30,w-12,8);CGContextStrokeRect(c,bar);
        CGFloat value=fmax(0,fmin(1,[[model objectForKey:@"progress"] doubleValue]));CGContextFillRect(c,CGRectMake(8,h-28,(w-16)*value,4));
        [[model objectForKey:@"elapsed"] drawInRect:CGRectMake(5,h-18,60,16) withFont:font];
        [[model objectForKey:@"remaining"] drawInRect:CGRectMake(w-65,h-18,60,16) withFont:font lineBreakMode:UILineBreakModeClip alignment:UITextAlignmentRight];
    } else {
        NSArray *items=[model objectForKey:@"rows"];NSInteger selected=[[model objectForKey:@"selection"] integerValue];
        NSInteger capacity=[self capacity],first=MAX(0,selected-capacity+1);
        // Long lists get the period scroll bar: an outlined trough with a solid thumb.
        BOOL bar=[self showsScrollBar];CGFloat rowWidth=bar?w-8:w;
        if(bar){CGRect trough=CGRectMake(w-7,17,6,h-18);CGContextSetStrokeColorWithColor(c,ink.CGColor);CGContextSetLineWidth(c,1);CGContextStrokeRect(c,CGRectInset(trough,.5,.5));
            CGFloat track=trough.size.height-4,thumb=MAX(4,floor(track*capacity/items.count)),top=floor((track-thumb)*first/MAX(1,(NSInteger)items.count-capacity));
            CGContextFillRect(c,CGRectMake(trough.origin.x+2,trough.origin.y+2+top,2,thumb));}
        for(NSInteger i=first;i<MIN((NSInteger)items.count,first+capacity);i++){
            CGFloat y=17+(i-first)*16;BOOL highlight=i==selected;
            [ink setFill];if(highlight)CGContextFillRect(c,CGRectMake(0,y,rowWidth,16));
            [(highlight?paper:ink) setFill];NSDictionary *row=[items objectAtIndex:i];
            [self text:[row objectForKey:@"title"] rect:CGRectMake(3,y,rowWidth-15,16) font:font centered:NO scroll:highlight];
            NSString *kind=[row objectForKey:@"kind"];
            if(![kind isEqual:@"song"]&&![kind isEqual:@"skin"]&&![kind isEqual:@"empty"]&&![kind isEqual:@"color"]){
                CGContextSetStrokeColorWithColor(c,(highlight?paper:ink).CGColor);CGContextSetLineWidth(c,1.5);
                CGContextMoveToPoint(c,rowWidth-9,y+4);CGContextAddLineToPoint(c,rowWidth-6,y+7);CGContextAddLineToPoint(c,rowWidth-9,y+10);CGContextStrokePath(c);
            }
        }
    }
}
- (void)dealloc {[model release];[scrollIdentity release];[super dealloc];}
@end

// Cover Flow on black, as on iPod classic and nano 3G. Each card is two opaque
// layers: the cover, and a 1x reflection with its fade baked in. A few recent
// covers are kept so turning back and forth does not decode artwork again.
#define RW_COVER 130.0
#define RW_REFLECT 44.0
static CGFloat CoverX(NSInteger delta){return 160+(delta==0?0:(delta>0?1:-1)*(104+(labs(delta)-1)*39));}
@interface CoverDeck : UIView {
    NSArray *items;NSMutableDictionary *cards,*covers;NSMutableArray *coverOrder;UILabel *albumName,*artistName;
}
- (void)setItems:(NSArray *)rows;
- (void)showSelection:(NSInteger)index animated:(BOOL)animated;
- (void)purge;
- (void)trim;
@end
@implementation CoverDeck
- (id)initWithFrame:(CGRect)frame {
    if((self=[super initWithFrame:frame])){self.clipsToBounds=YES;self.backgroundColor=[UIColor blackColor];self.opaque=YES;cards=[[NSMutableDictionary alloc] init];covers=[[NSMutableDictionary alloc] init];coverOrder=[[NSMutableArray alloc] init];
        albumName=[[ScrollLabel alloc] initWithFrame:CGRectMake(5,180,310,19)];artistName=[[ScrollLabel alloc] initWithFrame:CGRectMake(5,198,310,17)];
        albumName.font=[UIFont fontWithName:@"Helvetica-Bold" size:15];albumName.textColor=[UIColor whiteColor];
        artistName.font=[UIFont fontWithName:@"Helvetica-Bold" size:13];artistName.textColor=RGB(.62,.64,.66);
        for(UILabel *label in [NSArray arrayWithObjects:albumName,artistName,nil]){label.backgroundColor=[UIColor clearColor];label.textAlignment=UITextAlignmentCenter;label.layer.zPosition=20;[self addSubview:label];}
    }return self;
}
- (void)removeCards {for(UIView *card in cards.allValues)[card removeFromSuperview];[cards removeAllObjects];}
- (void)purge {[self removeCards];[covers removeAllObjects];[coverOrder removeAllObjects];[items release];items=nil;}
- (void)trim {for(NSNumber *key in [[coverOrder copy] autorelease])if(![cards objectForKey:key]){[covers removeObjectForKey:key];[coverOrder removeObject:key];}}
- (void)setItems:(NSArray *)rows {if(items==rows)return;[self purge];items=[rows retain];}
- (NSArray *)coverFor:(NSInteger)i {
    NSNumber *key=[NSNumber numberWithInteger:i];NSArray *pair=[covers objectForKey:key];
    if(pair){[coverOrder removeObject:key];[coverOrder addObject:key];return pair;}
    NSAutoreleasePool *pool=[[NSAutoreleasePool alloc] init];
    MPMediaItemCollection *collection=[[items objectAtIndex:i] objectForKey:@"value"];
    UIImage *cover=nil;if([collection isKindOfClass:[MPMediaItemCollection class]])cover=[[collection.representativeItem valueForProperty:MPMediaItemPropertyArtwork] imageWithSize:CGSizeMake(RW_COVER,RW_COVER)];
    CGRect square=CGRectMake(0,0,RW_COVER,RW_COVER);
    // Draw at screen scale into an opaque square: covers that are not square, or
    // missing, never leave transparent edges that cost blending on the A4.
    UIGraphicsBeginImageContextWithOptions(square.size,YES,0);CGContextRef c=UIGraphicsGetCurrentContext();
    if(cover){[[UIColor blackColor] setFill];UIRectFill(square);CGSize s=cover.size;CGFloat k=MIN(RW_COVER/s.width,RW_COVER/s.height);[cover drawInRect:CGRectMake((RW_COVER-s.width*k)/2,(RW_COVER-s.height*k)/2,s.width*k,s.height*k)];}
    else {Gradient(c,square,RGB(.30,.31,.33),RGB(.12,.13,.14));[RGB(.55,.57,.60) setFill];[@"♫" drawInRect:CGRectMake(0,26,RW_COVER,80) withFont:[UIFont fontWithName:@"Helvetica" size:65] lineBreakMode:UILineBreakModeClip alignment:UITextAlignmentCenter];}
    UIImage *front=UIGraphicsGetImageFromCurrentImageContext();UIGraphicsEndImageContext();
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(RW_COVER,RW_REFLECT),YES,1);c=UIGraphicsGetCurrentContext();
    [[UIColor blackColor] setFill];UIRectFill(CGRectMake(0,0,RW_COVER,RW_REFLECT));
    CGContextSaveGState(c);CGContextTranslateCTM(c,0,RW_COVER);CGContextScaleCTM(c,1,-1);CGContextSetAlpha(c,.32);[front drawInRect:square];CGContextRestoreGState(c);
    Gradient(c,CGRectMake(0,0,RW_COVER,RW_REFLECT),[UIColor colorWithWhite:0 alpha:0],[UIColor blackColor]);
    UIImage *reflection=UIGraphicsGetImageFromCurrentImageContext();UIGraphicsEndImageContext();
    pair=[[NSArray alloc] initWithObjects:front,reflection,nil];
    [pool release];[pair autorelease];
    [covers setObject:pair forKey:key];[coverOrder addObject:key];
    while(coverOrder.count>11){[covers removeObjectForKey:[coverOrder objectAtIndex:0]];[coverOrder removeObjectAtIndex:0];}
    return pair;
}
- (UIView *)cardFor:(NSInteger)i {
    NSArray *pair=[self coverFor:i];
    UIView *card=[[[UIView alloc] initWithFrame:CGRectMake(0,0,RW_COVER,RW_COVER+1+RW_REFLECT)] autorelease];card.userInteractionEnabled=NO;card.backgroundColor=[UIColor blackColor];card.opaque=YES;
    CALayer *front=[CALayer layer],*mirror=[CALayer layer];
    front.frame=CGRectMake(0,0,RW_COVER,RW_COVER);front.contents=(id)[[pair objectAtIndex:0] CGImage];front.opaque=YES;
    mirror.frame=CGRectMake(0,RW_COVER+1,RW_COVER,RW_REFLECT);mirror.contents=(id)[[pair objectAtIndex:1] CGImage];mirror.opaque=YES;
    [card.layer addSublayer:front];[card.layer addSublayer:mirror];return card;
}
- (void)place:(UIView *)card delta:(NSInteger)delta {
    card.center=CGPointMake(CoverX(delta),92);
    CATransform3D t=CATransform3DIdentity;t.m34=-1.0/420;
    if(delta!=0){t=CATransform3DRotate(t,delta<0?1.05:-1.05,0,1,0);t=CATransform3DScale(t,.89,.89,1);}
    card.layer.transform=t;card.layer.zPosition=10-labs(delta);
}
- (void)showSelection:(NSInteger)index animated:(BOOL)animated {
    if(!items.count||![[[items objectAtIndex:0] objectForKey:@"kind"] isEqual:@"coveralbum"]){[self removeCards];albumName.text=@"No albums synced";artistName.text=@"";return;}
    for(NSNumber *key in [[cards.allKeys copy] autorelease])if(labs([key integerValue]-index)>3){[[cards objectForKey:key] removeFromSuperview];[cards removeObjectForKey:key];}
    [CATransaction begin];[CATransaction setDisableActions:YES];
    for(NSInteger i=MAX(0,index-3);i<MIN((NSInteger)items.count,index+4);i++){
        NSNumber *key=[NSNumber numberWithInteger:i];if([cards objectForKey:key])continue;
        // New cards enter where the previous selection would have placed them.
        UIView *card=[self cardFor:i];NSInteger before=animated?i-(index+(i>index?-1:1)):i-index;[self place:card delta:labs(before)>3?(before>0?3:-3):before];
        [self insertSubview:card atIndex:0];[cards setObject:card forKey:key];
    }
    [CATransaction commit];
    if(animated){[UIView beginAnimations:@"coverFlow" context:NULL];[UIView setAnimationDuration:.26];[UIView setAnimationBeginsFromCurrentState:YES];[UIView setAnimationCurve:UIViewAnimationCurveEaseOut];}
    for(NSNumber *key in cards)[self place:[cards objectForKey:key] delta:[key integerValue]-index];
    if(animated)[UIView commitAnimations];
    MPMediaItem *item=[(MPMediaItemCollection *)[[items objectAtIndex:index] objectForKey:@"value"] representativeItem];
    albumName.text=[item valueForProperty:MPMediaItemPropertyAlbumTitle]?:@"Unknown Album";artistName.text=[item valueForProperty:MPMediaItemPropertyAlbumArtist]?:[item valueForProperty:MPMediaItemPropertyArtist]?:@"Unknown Artist";
}
- (void)dealloc {[items release];[cards release];[covers release];[coverOrder release];[albumName release];[artistName release];[super dealloc];}
@end

// Now Playing bar as drawn by the nano 3G / classic firmware: a thin rounded
// trough with a blue fill; a diamond while scrubbing; speakers while setting volume.
// It redraws only when the fill moves by a whole pixel or the mode changes.
@interface PodProgress : UIView {float value;NSInteger mode;NSInteger drawnStep;}
- (void)setValue:(float)v mode:(NSInteger)m;
@end
@implementation PodProgress
- (void)setValue:(float)v mode:(NSInteger)m {
    v=fmaxf(0,fminf(1,isfinite(v)?v:0));NSInteger step=(NSInteger)lroundf(v*(self.bounds.size.width-32)*2);
    value=v;if(m==mode&&step==drawnStep)return;mode=m;drawnStep=step;[self setNeedsDisplay];
}
- (void)drawRect:(CGRect)r {
    CGContextRef c=UIGraphicsGetCurrentContext();CGFloat w=self.bounds.size.width,h=self.bounds.size.height,bh=9;
    CGRect trough=CGRectMake(16,floor((h-bh)/2),w-32,bh);
    UIBezierPath *pill=[UIBezierPath bezierPathWithRoundedRect:trough cornerRadius:bh/2];
    CGContextSaveGState(c);[pill addClip];Gradient(c,trough,RGB(.80,.82,.84),RGB(.97,.97,.98));
    CGRect fill=trough;fill.size.width=round(trough.size.width*value);
    if(fill.size.width>0){Gradient(c,fill,RGB(.47,.76,.98),RGB(.07,.42,.82));}
    CGContextRestoreGState(c);[RGB(.52,.56,.60) setStroke];pill.lineWidth=.6;[pill stroke];
    if(mode==1){CGFloat x=trough.origin.x+trough.size.width*value,y=CGRectGetMidY(trough),d=6.5;
        CGContextMoveToPoint(c,x,y-d);CGContextAddLineToPoint(c,x+d,y);CGContextAddLineToPoint(c,x,y+d);CGContextAddLineToPoint(c,x-d,y);CGContextClosePath(c);
        CGContextSetFillColorWithColor(c,RGB(.16,.40,.76).CGColor);CGContextSetStrokeColorWithColor(c,[UIColor whiteColor].CGColor);CGContextSetLineWidth(c,1);CGContextDrawPath(c,kCGPathFillStroke);}
    if(mode==2){CGFloat y=CGRectGetMidY(trough);[RGB(.30,.33,.36) setFill];
        for(int side=0;side<2;side++){CGFloat x=side?w-13:2;CGContextFillRect(c,CGRectMake(x,y-2,3,4));CGContextMoveToPoint(c,x+2,y-2);CGContextAddLineToPoint(c,x+6,y-5);CGContextAddLineToPoint(c,x+6,y+5);CGContextAddLineToPoint(c,x+2,y+2);CGContextClosePath(c);CGContextFillPath(c);
            if(side){CGContextSetStrokeColorWithColor(c,RGB(.30,.33,.36).CGColor);CGContextSetLineWidth(c,1);CGContextAddArc(c,x+6,y,3.5,-.9,.9,0);CGContextStrokePath(c);CGContextAddArc(c,x+6,y,6,-.9,.9,0);CGContextStrokePath(c);}}}
}
@end
@interface PodArrow : UIView {BOOL highlighted;}
@property(nonatomic) BOOL highlighted;
@end
@implementation PodArrow
@synthesize highlighted;
- (void)setHighlighted:(BOOL)value {highlighted=value;[self setNeedsDisplay];}
- (void)drawRect:(CGRect)rect {CGContextRef c=UIGraphicsGetCurrentContext();CGContextSetStrokeColorWithColor(c,(highlighted?[UIColor whiteColor]:RGB(.22,.26,.28)).CGColor);CGContextSetLineWidth(c,1.8);CGContextMoveToPoint(c,2,4);CGContextAddLineToPoint(c,6,8);CGContextAddLineToPoint(c,2,12);CGContextStrokePath(c);}
@end
@interface PodRow : UITableViewCell { ScrollLabel *scrollTitle,*scrollDetail; }
@end
@implementation PodRow
- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier {
    if((self=[super initWithStyle:style reuseIdentifier:identifier])){scrollTitle=[[ScrollLabel alloc] initWithFrame:CGRectZero];scrollDetail=[[ScrollLabel alloc] initWithFrame:CGRectZero];for(ScrollLabel *label in @[scrollTitle,scrollDetail]){label.backgroundColor=[UIColor clearColor];label.highlightedTextColor=[UIColor whiteColor];[self.contentView addSubview:label];}}return self;
}
- (void)dealloc {[scrollTitle release];[scrollDetail release];[super dealloc];}
- (void)setSelected:(BOOL)value animated:(BOOL)animated {[super setSelected:value animated:animated];scrollTitle.scrolling=scrollDetail.scrolling=value;scrollTitle.highlighted=scrollDetail.highlighted=value;[self setNeedsLayout];if([self.accessoryView isKindOfClass:[PodArrow class]])[(PodArrow *)self.accessoryView setHighlighted:value];}
- (void)layoutSubviews {
    [super layoutSubviews];BOOL subtitle=self.detailTextLabel.text.length>0;
    // UIKit already removes the accessory from contentView. Keep both labels inside it.
    CGFloat width=MAX(0,self.contentView.bounds.size.width-10);
    self.textLabel.frame=CGRectMake(5,0,width,subtitle?21:self.contentView.bounds.size.height);
    self.detailTextLabel.frame=CGRectMake(5,19,width,17);
    self.textLabel.lineBreakMode=UILineBreakModeTailTruncation;
    self.detailTextLabel.lineBreakMode=UILineBreakModeTailTruncation;
    self.contentView.clipsToBounds=YES;
    NSArray *originals=@[self.textLabel,self.detailTextLabel],*copies=@[scrollTitle,scrollDetail];
    for(NSUInteger i=0;i<2;i++){UILabel *source=[originals objectAtIndex:i];ScrollLabel *dest=[copies objectAtIndex:i];dest.frame=source.frame;dest.font=source.font;dest.textColor=source.textColor;dest.text=source.text;dest.highlighted=self.selected;dest.scrolling=self.selected;source.hidden=YES;}

}
@end

@interface Player : UIViewController <UITableViewDelegate,UITableViewDataSource,WheelDelegate> {Shell *shell;MonoLCD *monoLCD;CoverDeck *coverDeck;BOOL cover;Wheel *wheel;UIView *lcd,*preview;UILabel *header,*detail,*song,*artist,*clockLabel,*hint;UIImageView *art,*reflection;LCDBar *topBar;Battery *battery;CAGradientLayer *reflectionFade;UILabel *album;NSTimeInterval volumeUntil;UITableView *table;PodProgress *progress;CADisplayLink *link;CAGradientLayer *scrollTrack,*scrollThumb;NSNumber *artID;NSInteger artMode;BOOL purged;MPMusicPlayerController *music;NSMutableArray *stack;NSArray *rows;NSString *menuTitle;NSInteger selection,skin;BOOL now,seekMode,clicks,active;NSTimer *timer;NSTimeInterval lastClick,lastProgress;UIImage *navigationImage;CGFloat navigationShift;UIView *navigationOverlay;BOOL navigationBack;}
@end
@implementation Player
- (UIFont *)font:(CGFloat)size {return skin==1||skin==2?([UIFont fontWithName:@"Chicago" size:size]?:[UIFont boldSystemFontOfSize:size]):([UIFont fontWithName:@"Helvetica-Bold" size:size]?:[UIFont boldSystemFontOfSize:size]);}
- (UILabel *)label:(CGRect)r size:(CGFloat)s {UILabel *l=[[[ScrollLabel alloc] initWithFrame:r] autorelease];l.backgroundColor=[UIColor clearColor];l.font=[self font:s];l.lineBreakMode=UILineBreakModeTailTruncation;return l;}
- (void)loadView {shell=[[Shell alloc] initWithFrame:[[UIScreen mainScreen] bounds]];self.view=shell;skin=[[NSUserDefaults standardUserDefaults] integerForKey:@"Skin"];if(skin<0||skin>3)skin=0;shell.skin=skin;[shell layoutSubviews];lcd=[[UIView alloc] initWithFrame:shell.displayRect];lcd.clipsToBounds=YES;[shell addSubview:lcd];topBar=[[LCDBar alloc] initWithFrame:CGRectZero];[lcd addSubview:topBar];header=[[self label:CGRectZero size:17] retain];header.textAlignment=UITextAlignmentLeft;[lcd addSubview:header];battery=[[Battery alloc] initWithFrame:CGRectZero];battery.backgroundColor=[UIColor clearColor];battery.opaque=NO;[lcd addSubview:battery];[UIDevice currentDevice].batteryMonitoringEnabled=YES;table=[[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];table.delegate=self;table.dataSource=self;table.separatorStyle=UITableViewCellSeparatorStyleNone;table.rowHeight=24;table.showsVerticalScrollIndicator=NO;[lcd addSubview:table];preview=[[UIView alloc] initWithFrame:CGRectZero];[lcd addSubview:preview];art=[[UIImageView alloc] initWithFrame:CGRectZero];art.contentMode=UIViewContentModeScaleAspectFit;[preview addSubview:art];reflection=[[UIImageView alloc] initWithFrame:CGRectZero];reflection.contentMode=UIViewContentModeScaleAspectFit;reflection.alpha=.16;reflection.transform=CGAffineTransformMakeScale(1,-1);[preview addSubview:reflection];reflectionFade=[[CAGradientLayer layer] retain];reflectionFade.colors=@[(id)[UIColor colorWithWhite:1 alpha:0].CGColor,(id)[UIColor whiteColor].CGColor];[preview.layer addSublayer:reflectionFade];album=[[self label:CGRectZero size:15] retain];[lcd addSubview:album];detail=[[self label:CGRectZero size:11] retain];detail.numberOfLines=3;detail.textAlignment=UITextAlignmentCenter;[preview addSubview:detail];song=[[self label:CGRectZero size:13] retain];song.textAlignment=UITextAlignmentCenter;song.numberOfLines=1;[lcd addSubview:song];artist=[[self label:CGRectZero size:10] retain];artist.textAlignment=UITextAlignmentCenter;[lcd addSubview:artist];clockLabel=[[self label:CGRectZero size:10] retain];clockLabel.textAlignment=UITextAlignmentCenter;[lcd addSubview:clockLabel];hint=[[self label:CGRectZero size:9] retain];hint.textAlignment=UITextAlignmentCenter;[lcd addSubview:hint];progress=[[PodProgress alloc] initWithFrame:CGRectMake(40,207,240,17)];progress.backgroundColor=[UIColor clearColor];progress.opaque=NO;[lcd addSubview:progress];scrollTrack=[[CAGradientLayer alloc] init];scrollTrack.colors=[NSArray arrayWithObjects:(id)RGB(.86,.87,.88).CGColor,(id)RGB(.97,.97,.98).CGColor,nil];scrollTrack.startPoint=CGPointMake(0,.5);scrollTrack.endPoint=CGPointMake(1,.5);scrollTrack.hidden=YES;[lcd.layer addSublayer:scrollTrack];scrollThumb=[[CAGradientLayer alloc] init];scrollThumb.colors=[NSArray arrayWithObjects:(id)RGB(.42,.48,.54).CGColor,(id)RGB(.66,.71,.76).CGColor,nil];scrollThumb.startPoint=CGPointMake(0,.5);scrollThumb.endPoint=CGPointMake(1,.5);scrollThumb.cornerRadius=2;[scrollTrack addSublayer:scrollThumb];monoLCD=[[MonoLCD alloc] initWithFrame:CGRectZero];monoLCD.userInteractionEnabled=NO;monoLCD.contentScaleFactor=1;monoLCD.layer.magnificationFilter=kCAFilterNearest;[lcd addSubview:monoLCD];coverDeck=[[CoverDeck alloc] initWithFrame:CGRectMake(0,23,320,217)];[lcd addSubview:coverDeck];wheel=[[Wheel alloc] initWithFrame:shell.wheelRect];wheel.backgroundColor=[UIColor clearColor];wheel.opaque=NO;wheel.delegate=self;[shell addSubview:wheel];stack=[[NSMutableArray alloc] init];clicks=[[NSUserDefaults standardUserDefaults] objectForKey:@"Clicks"]?[[NSUserDefaults standardUserDefaults] boolForKey:@"Clicks"]:YES;music=[[MPMusicPlayerController iPodMusicPlayer] retain];NSNotificationCenter *nc=[NSNotificationCenter defaultCenter];[nc addObserver:self selector:@selector(playbackChanged:) name:MPMusicPlayerControllerNowPlayingItemDidChangeNotification object:music];[nc addObserver:self selector:@selector(playbackChanged:) name:MPMusicPlayerControllerPlaybackStateDidChangeNotification object:music];[nc addObserver:self selector:@selector(libraryChanged:) name:MPMediaLibraryDidChangeNotification object:nil];[[MPMediaLibrary defaultMediaLibrary] beginGeneratingLibraryChangeNotifications];[music beginGeneratingPlaybackNotifications];[self root];[self appearance];}
- (NSDictionary *)row:(NSString *)title kind:(NSString *)kind value:(id)value {return [NSDictionary dictionaryWithObjectsAndKeys:title,@"title",kind,@"kind",value?value:[NSNull null],@"value",nil];}
- (void)setRows:(NSArray *)r title:(NSString *)t { [rows release];rows=[r copy];selection=0;now=NO;cover=r.count&&[[[r objectAtIndex:0] objectForKey:@"kind"] isEqual:@"coveralbum"];[menuTitle release];menuTitle=[t copy];header.text=t;[self render];}
- (void)root { [stack removeAllObjects];
if(skin==1){[self setRows:[NSArray arrayWithObjects:[self row:@"Playlists" kind:@"playlists" value:nil],[self row:@"Artists" kind:@"artists" value:nil],[self row:@"Songs" kind:@"songs" value:nil],[self row:@"Settings" kind:@"settings" value:nil],[self row:@"Now Playing" kind:@"now" value:nil],nil] title:@"iPod"];return;}
if(skin==2){[self setRows:[NSArray arrayWithObjects:[self row:@"Playlists" kind:@"playlists" value:nil],[self row:@"Browse" kind:@"music" value:nil],[self row:@"Settings" kind:@"settings" value:nil],[self row:@"Shuffle Songs" kind:@"shuffle" value:nil],[self row:@"Now Playing" kind:@"now" value:nil],nil] title:@"iPod"];return;}
[self setRows:[NSArray arrayWithObjects:[self row:@"Music" kind:@"music" value:nil],[self row:@"Shuffle Songs" kind:@"shuffle" value:nil],[self row:@"Now Playing" kind:@"now" value:nil],[self row:@"Settings" kind:@"settings" value:nil],nil] title:@"iPod"];}
- (void)push { [stack addObject:[NSDictionary dictionaryWithObjectsAndKeys:rows,@"rows",menuTitle,@"title",[NSNumber numberWithInteger:selection],@"selection",[NSNumber numberWithInteger:skin],@"skin",nil]]; }
// A screen change animates the LCD only; the physical shell stays still.
// Duration is a tuning value until compared with captured original hardware.
- (UIImage *)screenImage {
    UIGraphicsBeginImageContextWithOptions(lcd.bounds.size,YES,1);FreezeLabels(lcd,YES);
    [lcd.layer renderInContext:UIGraphicsGetCurrentContext()];FreezeLabels(lcd,NO);UIImage *image=UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();return image;
}
- (void)clearTransition {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(clearTransition) object:nil];
    [lcd.layer removeAnimationForKey:@"slide"];
    [navigationOverlay removeFromSuperview];[navigationOverlay release];navigationOverlay=nil;
    [navigationImage release];navigationImage=nil;
}
// Capture the old screen before the menu changes...
- (void)transitionBack:(BOOL)backward {
    CALayer *shown=(CALayer *)lcd.layer.presentationLayer;navigationShift=([lcd.layer animationForKey:@"slide"]&&shown)?shown.position.x-lcd.layer.position.x:0;
    [self clearTransition];if(!active||!lcd.window)return;
    navigationBack=backward;navigationImage=[[self screenImage] retain];
}
// ...then, in the same run-loop turn, slide the old snapshot out and the live LCD
// in. Nothing is committed in between, so the new screen never flashes first,
// and only one snapshot is rendered. Both layers share one timing curve.
- (void)finishTransition {
    if(!navigationImage||!active){[self clearTransition];return;}
    CGRect frame=shell.displayRect;CGFloat direction=navigationBack?-1:1,width=frame.size.width;
    UIImageView *old=[[UIImageView alloc] initWithImage:navigationImage];old.frame=frame;old.userInteractionEnabled=NO;old.opaque=YES;
    old.layer.magnificationFilter=(skin==1||skin==2)?kCAFilterNearest:kCAFilterLinear;
    navigationOverlay=old;[shell insertSubview:old belowSubview:wheel];
    [navigationImage release];navigationImage=nil;
    CAMediaTimingFunction *curve=[CAMediaTimingFunction functionWithControlPoints:.25 :.1 :.25 :1];
    // After rapid input the old screen starts where it was being shown, not at rest.
    CGPoint home=old.layer.position,start=CGPointMake(home.x+navigationShift,home.y);navigationShift=0;
    [CATransaction begin];[CATransaction setDisableActions:YES];
    old.layer.position=CGPointMake(home.x-direction*width,home.y);
    [CATransaction commit];
    CABasicAnimation *out=[CABasicAnimation animationWithKeyPath:@"position"];out.fromValue=[NSValue valueWithCGPoint:start];out.duration=.22;out.timingFunction=curve;
    [old.layer addAnimation:out forKey:@"slide"];
    CGPoint live=lcd.layer.position;CABasicAnimation *in=[CABasicAnimation animationWithKeyPath:@"position"];
    in.fromValue=[NSValue valueWithCGPoint:CGPointMake(live.x+direction*width,live.y)];in.duration=.22;in.timingFunction=curve;
    [lcd.layer addAnimation:in forKey:@"slide"];
    [self performSelector:@selector(clearTransition) withObject:nil afterDelay:.24];PulseLabels(lcd,YES);
}
- (void)back {if(!now&&!stack.count)return;[self transitionBack:YES];[self backChange];[self finishTransition];}
- (void)backChange {if(now){now=NO;[self render];return;}if(!stack.count)return;NSDictionary *s=[[stack lastObject] retain];[stack removeLastObject];[self setRows:[s objectForKey:@"rows"] title:[s objectForKey:@"title"]];selection=[[s objectForKey:@"selection"] integerValue];BOOL changedSkin=[[s objectForKey:@"skin"] integerValue]!=skin;[s release];if(!stack.count&&changedSkin){[self root];return;}if([menuTitle isEqual:@"Settings"]){NSInteger restore=selection;[self settings];selection=restore;}[self render];}
- (void)appearance {shell.skin=skin;[shell layoutSubviews];lcd.transform=CGAffineTransformIdentity;CGSize logical=skin==1?CGSizeMake(160,128):skin==2?CGSizeMake(138,110):CGSizeMake(320,240);lcd.bounds=CGRectMake(0,0,logical.width,logical.height);lcd.center=CGPointMake(CGRectGetMidX(shell.displayRect),CGRectGetMidY(shell.displayRect));lcd.transform=CGAffineTransformMakeScale(shell.displayRect.size.width/logical.width,shell.displayRect.size.height/logical.height);wheel.frame=shell.wheelRect;wheel.style=skin;wheel.bodyTint=BodyTint(skin);wheel.dark=(skin==0&&ColorChoice(skin)==0)||(skin==3&&ColorChoice(skin)==1);wheel.original=skin==1;wheel.centerFraction=skin==0?.49:skin==1?.28:skin==2?.32:.36;BOOL mono=skin==1||skin==2;UIColor *bg=mono?RGB(.72,.78,.60):[UIColor whiteColor];lcd.backgroundColor=bg;table.backgroundColor=bg;header.font=[self font:17];detail.font=[self font:14];song.font=[self font:17];artist.font=[UIFont systemFontOfSize:15];album.font=[UIFont systemFontOfSize:15];[self render];}
- (void)renderMono {
    double total=[[music.nowPlayingItem valueForProperty:MPMediaItemPropertyPlaybackDuration] doubleValue],t=music.currentPlaybackTime;if(!isfinite(t)||t<0)t=0;
    BOOL volume=[NSDate timeIntervalSinceReferenceDate]<volumeUntil;
    NSArray *lines=[NSArray arrayWithObjects:[music.nowPlayingItem valueForProperty:MPMediaItemPropertyTitle]?:@"Nothing playing",[music.nowPlayingItem valueForProperty:MPMediaItemPropertyArtist]?:@"Choose a song",[music.nowPlayingItem valueForProperty:MPMediaItemPropertyAlbumTitle]?:@"",nil];
    int remaining=fmax(0,total-t);
    monoLCD.frame=lcd.bounds;
    monoLCD.model=[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:skin==2],@"mini",now?@"Now Playing":menuTitle,@"title",rows,@"rows",[NSNumber numberWithInteger:selection],@"selection",[NSNumber numberWithBool:now],@"now",[NSNumber numberWithBool:music.playbackState==MPMusicPlaybackStatePlaying],@"playing",lines,@"lines",[NSNumber numberWithDouble:volume?music.volume:total>0?t/total:0],@"progress",volume?@"Volume":[NSString stringWithFormat:@"%d:%02d",(int)t/60,(int)t%60],@"elapsed",volume?@"":[NSString stringWithFormat:@"-%d:%02d",remaining/60,remaining%60],@"remaining",nil];
    [self updatePulse];
}
- (void)render {if(!lcd)return;
battery.playing=music.playbackState==MPMusicPlaybackStatePlaying;battery.hasItem=music.nowPlayingItem!=nil;[battery setNeedsDisplay];
BOOL monochrome=skin==1||skin==2;
for(UIView *child in lcd.subviews)child.hidden=monochrome;
monoLCD.hidden=!monochrome;coverDeck.hidden=YES;scrollTrack.hidden=YES;
if(monochrome||!cover||now)[coverDeck purge];
if(monochrome){[self renderMono];return;}
if(cover&&!now){for(UIView *child in lcd.subviews)child.hidden=YES;topBar.hidden=header.hidden=battery.hidden=coverDeck.hidden=NO;topBar.frame=CGRectMake(0,0,320,23);topBar.mono=NO;[topBar setNeedsDisplay];header.text=@"Cover Flow";header.frame=CGRectMake(5,1,262,21);battery.frame=CGRectMake(271,3,45,16);[coverDeck setItems:rows];[coverDeck showSelection:selection animated:NO];return;}
header.text=now?@"Now Playing":menuTitle;CGFloat w=320,h=240;BOOL mono=skin==1||skin==2;NSString *kind=rows.count?[[rows objectAtIndex:0] objectForKey:@"kind"]:@"";BOOL split=!mono&&!now&&([kind isEqual:@"music"]||[kind isEqual:@"coverflow"]||[kind isEqual:@"artists"]);CGFloat tw=split?160:w;topBar.frame=CGRectMake(0,0,now?w:tw,23);topBar.mono=mono;[topBar setNeedsDisplay];header.frame=CGRectMake(5,1,(now?w:tw)-58,21);header.backgroundColor=[UIColor clearColor];battery.frame=CGRectMake((now?w:tw)-49,3,45,16);[battery setNeedsDisplay];table.hidden=now;table.rowHeight=([kind isEqual:@"song"]||[kind isEqual:@"albumcollection"])?36:24;BOOL bar=!now&&rows.count*table.rowHeight>h-23;table.frame=CGRectMake(0,23,bar?tw-8:tw,h-23);preview.hidden=!split&&!now;preview.frame=now?CGRectMake(8,43,126,154):CGRectMake(tw,0,w-tw,h);preview.clipsToBounds=YES;CATransform3D perspective=CATransform3DIdentity;perspective.m34=-1.0/500;preview.layer.transform=now?CATransform3DRotate(perspective,.20,0,1,0):CATransform3DIdentity;reflectionFade.hidden=!now;reflectionFade.frame=CGRectMake(0,124,124,30);art.transform=CGAffineTransformIdentity;art.frame=now?CGRectMake(0,0,124,124):CGRectMake(0,0,w-tw,h);art.contentMode=now?UIViewContentModeScaleAspectFit:UIViewContentModeScaleAspectFill;reflection.hidden=!now;reflection.frame=CGRectMake(0,124,124,124);detail.hidden=YES;song.hidden=artist.hidden=album.hidden=progress.hidden=clockLabel.hidden=hint.hidden=!now;if(now){song.frame=CGRectMake(mono?8:143,61,mono?w-16:171,44);song.textAlignment=UITextAlignmentLeft;artist.frame=CGRectMake(mono?8:143,109,mono?w-16:171,20);artist.textAlignment=UITextAlignmentLeft;album.frame=CGRectMake(mono?8:143,132,mono?w-16:171,20);if(mono)preview.hidden=YES;progress.frame=CGRectMake(40,207,240,17);clockLabel.frame=CGRectMake(5,205,48,20);clockLabel.font=[self font:12];clockLabel.textAlignment=UITextAlignmentLeft;hint.frame=CGRectMake(267,205,48,20);hint.font=[self font:12];hint.textAlignment=UITextAlignmentRight;[self updateSong];}else{[table reloadData];if(rows.count){NSIndexPath *p=[NSIndexPath indexPathForRow:selection inSection:0];[table selectRowAtIndexPath:p animated:NO scrollPosition:UITableViewScrollPositionNone];[table scrollToRowAtIndexPath:p atScrollPosition:UITableViewScrollPositionNone animated:NO];}scrollTrack.hidden=!bar;[self updateScrollBar];if(split)[self loadArt:240 mode:1];else {art.image=nil;[artID release];artID=nil;}detail.hidden=art.image!=nil;detail.frame=CGRectMake(4,80,152,90);detail.font=[UIFont boldSystemFontOfSize:24];detail.text=@"♪\nNo Artwork";} }
- (void)updateSong {MPMediaItem *item=music.nowPlayingItem;song.text=[item valueForProperty:MPMediaItemPropertyTitle]?:@"Nothing playing";artist.text=[item valueForProperty:MPMediaItemPropertyArtist]?:@"Choose a song";album.text=[item valueForProperty:MPMediaItemPropertyAlbumTitle]?:@"";[self loadArt:124 mode:2];reflection.image=art.image;[self tick];}
// Artwork is fetched only when the song or the size changes, not on every render.
- (void)loadArt:(CGFloat)size mode:(NSInteger)mode {
    MPMediaItem *item=music.nowPlayingItem;NSNumber *identity=[item valueForProperty:MPMediaItemPropertyPersistentID];
    if(art.image&&artMode==mode&&((!identity&&!artID)||[identity isEqual:artID]))return;
    art.image=[[item valueForProperty:MPMediaItemPropertyArtwork] imageWithSize:CGSizeMake(size,size)];
    [artID release];artID=[identity retain];artMode=mode;
}
// Color skins draw the list scroll bar with two layers; moving it costs no drawing.
- (void)updateScrollBar {
    if(scrollTrack.hidden)return;CGRect f=table.frame;NSInteger count=rows.count;CGFloat visible=f.size.height/table.rowHeight;
    CGRect track=CGRectMake(CGRectGetMaxX(f)+1,f.origin.y+2,6,f.size.height-4);
    CGFloat thumb=MAX(10,floor(track.size.height*visible/MAX(1,count))),travel=track.size.height-thumb;
    CGFloat top=table.contentSize.height>f.size.height?travel*table.contentOffset.y/(table.contentSize.height-f.size.height):0;
    [CATransaction begin];[CATransaction setDisableActions:YES];
    scrollTrack.frame=track;scrollTrack.cornerRadius=3;scrollThumb.frame=CGRectMake(.5,floor(fmax(0,fmin(travel,top))),5,thumb);
    [CATransaction commit];
}
- (void)tick {if(!now)return;if(skin==1||skin==2){[self renderMono];return;}double total=[[music.nowPlayingItem valueForProperty:MPMediaItemPropertyPlaybackDuration] doubleValue],t=music.currentPlaybackTime;if(!isfinite(t)||t<0)t=0;BOOL vol=[NSDate timeIntervalSinceReferenceDate]<volumeUntil;[progress setValue:vol?music.volume:(total>0?t/total:0) mode:vol?2:seekMode?1:0];int remain=fmax(0,total-t);clockLabel.hidden=hint.hidden=vol;clockLabel.text=[NSString stringWithFormat:@"%d:%02d",(int)t/60,(int)t%60];hint.text=[NSString stringWithFormat:@"-%d:%02d",remain/60,remain%60];}

- (void)playbackChanged:(NSNotification *)n {battery.playing=music.playbackState==MPMusicPlaybackStatePlaying;battery.hasItem=music.nowPlayingItem!=nil;[battery setNeedsDisplay];if(now)[self updateSong];else [self render];}
// Queries are refreshed when entering a library menu. A library notification can
// also be emitted while playback metadata is being refreshed; it must not pop navigation.
- (void)libraryChanged:(NSNotification *)n {if(now)[self updateSong];}
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s {return rows.count;}
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)p {UITableViewCell *c=[t dequeueReusableCellWithIdentifier:@"row"];if(!c){c=[[[PodRow alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"row"] autorelease];LCDBar *sel=[[[LCDBar alloc] init] autorelease];sel.selected=YES;c.selectedBackgroundView=sel;}NSDictionary *r=[rows objectAtIndex:p.row];NSString *k=[r objectForKey:@"kind"];BOOL mono=skin==1||skin==2;c.textLabel.text=[r objectForKey:@"title"];c.textLabel.font=[self font:17];c.textLabel.textColor=RGB(.05,.07,.08);c.textLabel.highlightedTextColor=mono?RGB(.75,.80,.63):[UIColor whiteColor];c.detailTextLabel.font=[UIFont systemFontOfSize:13];c.detailTextLabel.textColor=RGB(.35,.38,.4);c.detailTextLabel.highlightedTextColor=[UIColor whiteColor];c.detailTextLabel.text=nil;if([k isEqual:@"song"])c.detailTextLabel.text=[[r objectForKey:@"value"] valueForProperty:MPMediaItemPropertyArtist];else if([k isEqual:@"albumcollection"])c.detailTextLabel.text=[[(MPMediaItemCollection *)[r objectForKey:@"value"] representativeItem] valueForProperty:MPMediaItemPropertyArtist];[(LCDBar *)c.selectedBackgroundView setMono:mono];[c.selectedBackgroundView setNeedsDisplay];c.backgroundColor=[UIColor clearColor];BOOL disclosure=!([k isEqual:@"song"]||[k isEqual:@"empty"]||[k isEqual:@"skin"]||[k isEqual:@"color"]);c.accessoryType=UITableViewCellAccessoryNone;
if(disclosure){PodArrow *arrow=[[[PodArrow alloc] initWithFrame:CGRectMake(0,0,9,16)] autorelease];arrow.backgroundColor=[UIColor clearColor];arrow.opaque=NO;arrow.highlighted=c.selected;c.accessoryView=arrow;}else c.accessoryView=nil;return c;}

- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)p {selection=p.row;[self choose];}
- (void)click {NSTimeInterval t=[NSDate timeIntervalSinceReferenceDate];if(clicks&&t-lastClick>.045){RWPlayClick(skin);lastClick=t;}}
- (void)wheelTurn:(int)steps {if(now){if(seekMode){double total=[[music.nowPlayingItem valueForProperty:MPMediaItemPropertyPlaybackDuration] doubleValue];music.currentPlaybackTime=fmax(0,fmin(total,music.currentPlaybackTime+steps*3));}else {music.volume=fmax(0,fmin(1,music.volume+steps*.025));volumeUntil=[NSDate timeIntervalSinceReferenceDate]+2;}[self tick];return;}NSInteger next=RWClampSelection((int)selection,steps,(int)rows.count);if(next!=selection){selection=next;if(cover){[self click];[coverDeck showSelection:selection animated:YES];return;}if(skin==1||skin==2){[self click];[self renderMono];return;}NSIndexPath *p=[NSIndexPath indexPathForRow:selection inSection:0];[table selectRowAtIndexPath:p animated:NO scrollPosition:UITableViewScrollPositionNone];[table scrollToRowAtIndexPath:p atScrollPosition:UITableViewScrollPositionNone animated:NO];[self updateScrollBar];[self click];}}
- (void)wheelButton:(int)b {[self click];if(cover&&!now&&(b==3||b==4)){[self wheelTurn:b==3?-1:1];return;}if(b==1){[self back];return;}if(b==2){if(music.playbackState==MPMusicPlaybackStatePlaying)[music pause];else [music play];return;}if(b==3){if(music.currentPlaybackTime>3)[music skipToBeginning];else [music skipToPreviousItem];return;}if(b==4){[music skipToNextItem];return;}if(now){seekMode=!seekMode;volumeUntil=0;[self tick];}else [self choose];}
- (void)showQuery:(MPMediaQuery *)q kind:(NSString *)kind title:(NSString *)title {NSMutableArray *r=[NSMutableArray array];if([kind isEqual:@"song"]){for(MPMediaItem *i in q.items)[r addObject:[self row:[i valueForProperty:MPMediaItemPropertyTitle]?:@"Untitled" kind:@"song" value:i]];}else for(MPMediaItemCollection *c in q.collections){NSString *t=[kind isEqual:@"artist"]?[c.representativeItem valueForProperty:MPMediaItemPropertyArtist]:[kind isEqual:@"album"]?[c.representativeItem valueForProperty:MPMediaItemPropertyAlbumTitle]:[kind isEqual:@"genre"]?[c.representativeItem valueForProperty:MPMediaItemPropertyGenre]:[kind isEqual:@"composer"]?[c.representativeItem valueForProperty:MPMediaItemPropertyComposer]:[(MPMediaPlaylist *)c valueForProperty:MPMediaPlaylistPropertyName];[r addObject:[self row:t?:@"Unknown" kind:[kind isEqual:@"album"]?@"albumcollection":[kind isEqual:@"artist"]?@"artistcollection":@"collection" value:c]];}if(!r.count)[r addObject:[self row:@"No music synced" kind:@"empty" value:nil]];[self setRows:r title:title];}
- (void)settings {
    NSMutableArray *menu=[NSMutableArray arrayWithObject:[self row:@"Skins" kind:@"skins" value:nil]];
    if(skin!=1)[menu addObject:[self row:[@"Color: " stringByAppendingString:[ColorNames(skin) objectAtIndex:ColorChoice(skin)]] kind:@"colors" value:nil]];
    [menu addObjectsFromArray:@[[self row:clicks?@"Clicker: On":@"Clicker: Off" kind:@"clicks" value:nil],[self row:music.shuffleMode==MPMusicShuffleModeSongs?@"Shuffle: Songs":@"Shuffle: Off" kind:@"shuffleMode" value:nil],[self row:music.repeatMode==MPMusicRepeatModeOne?@"Repeat: One":music.repeatMode==MPMusicRepeatModeAll?@"Repeat: All":@"Repeat: Off" kind:@"repeat" value:nil]]];
    [self setRows:menu title:@"Settings"];
}
- (void)choose {if(selection<0||selection>=rows.count)return;NSDictionary *row=[[rows objectAtIndex:selection] retain];NSString *k=[row objectForKey:@"kind"],*title=[row objectForKey:@"title"];id v=[row objectForKey:@"value"];
BOOL navigation=[k isEqual:@"music"]||[k isEqual:@"artists"]||[k isEqual:@"albums"]||[k isEqual:@"songs"]||[k isEqual:@"playlists"]||[k isEqual:@"collection"]||[k isEqual:@"song"]||[k isEqual:@"now"]||[k isEqual:@"settings"]||[k isEqual:@"skins"]||[k isEqual:@"colors"]||[k isEqual:@"coverflow"]||[k isEqual:@"coveralbum"]||[k isEqual:@"albumcollection"]||[k isEqual:@"artistcollection"]||[@[@"compilations",@"genres",@"composers",@"audiobooks"] containsObject:k];
if(navigation)[self transitionBack:NO];
if([k isEqual:@"music"]){[self push];NSMutableArray *menu=[NSMutableArray array];if(skin==0||skin==3)[menu addObject:[self row:@"Cover Flow" kind:@"coverflow" value:nil]];[menu addObjectsFromArray:@[[self row:@"Playlists" kind:@"playlists" value:nil],[self row:@"Artists" kind:@"artists" value:nil],[self row:@"Albums" kind:@"albums" value:nil],[self row:@"Compilations" kind:@"compilations" value:nil],[self row:@"Songs" kind:@"songs" value:nil],[self row:@"Genres" kind:@"genres" value:nil],[self row:@"Composers" kind:@"composers" value:nil],[self row:@"Audiobooks" kind:@"audiobooks" value:nil]]];[self setRows:menu title:skin==2?@"Browse":@"Music"];}
else if([k isEqual:@"coverflow"]){[self push];NSMutableArray *albums=[NSMutableArray array];for(MPMediaItemCollection *collection in [MPMediaQuery albumsQuery].collections)[albums addObject:[self row:[collection.representativeItem valueForProperty:MPMediaItemPropertyAlbumTitle]?:@"Unknown Album" kind:@"coveralbum" value:collection]];if(!albums.count)[albums addObject:[self row:@"No albums synced" kind:@"empty" value:nil]];[self setRows:albums title:@"Cover Flow"];}
else if([@[@"artists",@"albums",@"songs",@"playlists",@"compilations",@"genres",@"composers",@"audiobooks"] containsObject:k]){
    [self push];MPMediaQuery *q=nil;NSString *group=nil;
    if([k isEqual:@"artists"]){q=[MPMediaQuery artistsQuery];group=@"artist";}
    else if([k isEqual:@"albums"]){q=[MPMediaQuery albumsQuery];group=@"album";}
    else if([k isEqual:@"playlists"]){q=[MPMediaQuery playlistsQuery];group=@"playlist";}
    else if([k isEqual:@"compilations"]){q=[MPMediaQuery compilationsQuery];group=@"album";}
    else if([k isEqual:@"genres"]){q=[MPMediaQuery genresQuery];group=@"genre";}
    else if([k isEqual:@"composers"]){q=[MPMediaQuery composersQuery];group=@"composer";}
    else {q=[k isEqual:@"audiobooks"]?[MPMediaQuery audiobooksQuery]:[MPMediaQuery songsQuery];group=@"song";}
    [self showQuery:q kind:group title:title];
}
else if([k isEqual:@"artistcollection"]){[self push];MPMediaQuery *query=[MPMediaQuery albumsQuery];[query addFilterPredicate:[MPMediaPropertyPredicate predicateWithValue:title forProperty:MPMediaItemPropertyArtist]];[self showQuery:query kind:@"album" title:title];}
else if([k isEqual:@"collection"]||[k isEqual:@"albumcollection"]||[k isEqual:@"coveralbum"]){[self push];NSMutableArray *r=[NSMutableArray array];for(MPMediaItem *i in [(MPMediaItemCollection *)v items])[r addObject:[self row:[i valueForProperty:MPMediaItemPropertyTitle]?:@"Untitled" kind:@"song" value:i]];if(!r.count)[r addObject:[self row:@"Empty playlist" kind:@"empty" value:nil]];[self setRows:r title:title];}
else if([k isEqual:@"song"]){NSMutableArray *items=[NSMutableArray array];for(NSDictionary *r in rows)if([[r objectForKey:@"kind"] isEqual:@"song"])[items addObject:[r objectForKey:@"value"]];[music setQueueWithItemCollection:[MPMediaItemCollection collectionWithItems:items]];music.nowPlayingItem=v;[music play];now=YES;seekMode=NO;[self render];}
else if([k isEqual:@"shuffle"]){MPMediaQuery *q=[MPMediaQuery songsQuery];if(q.items.count){[self transitionBack:NO];[music setQueueWithQuery:q];music.shuffleMode=MPMusicShuffleModeSongs;[music play];now=YES;[self render];[self finishTransition];}}
else if([k isEqual:@"now"]){now=YES;seekMode=NO;[self render];}
else if([k isEqual:@"settings"]){[self push];[self settings];}
else if([k isEqual:@"skins"]){[self push];NSArray *names=[NSArray arrayWithObjects:@"Nano (3rd gen)",@"Original iPod",@"iPod mini",@"iPod classic",nil];NSMutableArray *r=[NSMutableArray array];for(int i=0;i<4;i++)[r addObject:[self row:[names objectAtIndex:i] kind:@"skin" value:[NSNumber numberWithInt:i]]];[self setRows:r title:@"Skins"];selection=skin;[self render];}
else if([k isEqual:@"colors"]){[self push];NSMutableArray *r=[NSMutableArray array];NSArray *names=ColorNames(skin);for(NSUInteger i=0;i<names.count;i++)[r addObject:[self row:[names objectAtIndex:i] kind:@"color" value:[NSNumber numberWithUnsignedInteger:i]]];[self setRows:r title:@"Color"];selection=ColorChoice(skin);[self render];}
else if([k isEqual:@"color"]){[[NSUserDefaults standardUserDefaults] setInteger:[v integerValue] forKey:[NSString stringWithFormat:@"Color%ld",(long)skin]];[self appearance];}
else if([k isEqual:@"skin"]){skin=[v integerValue];[[NSUserDefaults standardUserDefaults] setInteger:skin forKey:@"Skin"];[self appearance];}
else if([k isEqual:@"clicks"]){clicks=!clicks;[[NSUserDefaults standardUserDefaults] setBool:clicks forKey:@"Clicks"];NSInteger restore=selection;[self settings];selection=MIN(restore,(NSInteger)rows.count-1);[self render];}
else if([k isEqual:@"shuffleMode"]){music.shuffleMode=music.shuffleMode==MPMusicShuffleModeSongs?MPMusicShuffleModeOff:MPMusicShuffleModeSongs;NSInteger restore=selection;[self settings];selection=MIN(restore,(NSInteger)rows.count-1);[self render];}
else if([k isEqual:@"repeat"]){music.repeatMode=music.repeatMode==MPMusicRepeatModeNone?MPMusicRepeatModeAll:music.repeatMode==MPMusicRepeatModeAll?MPMusicRepeatModeOne:MPMusicRepeatModeNone;NSInteger restore=selection;[self settings];selection=MIN(restore,(NSInteger)rows.count-1);[self render];}
if(navigation)[self finishTransition];
[row release];}
// Monochrome marquee: a display link every third frame (20 Hz), running only
// while some text overflows. Each tick moves the text exactly one LCD pixel.
- (void)monoStep {if(!monoLCD.hidden&&monoLCD.wantsScroll)[monoLCD setNeedsDisplay];else link.paused=YES;}
- (void)updatePulse {
    BOOL want=active&&!monoLCD.hidden&&monoLCD.wantsScroll;
    if(want&&!link){link=[[CADisplayLink displayLinkWithTarget:self selector:@selector(monoStep)] retain];link.frameInterval=3;[link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];}
    link.paused=!want;
}
// Playback time only needs a 2 Hz refresh; color marquees run on Core Animation.
- (void)setActive:(BOOL)v {
    active=v;[timer invalidate];[timer release];timer=nil;
    if(!v){[self clearTransition];[link invalidate];[link release];link=nil;return;}
    [self restoreMemory];PulseLabels(lcd,YES);timer=[[NSTimer scheduledTimerWithTimeInterval:.5 target:self selector:@selector(tick) userInfo:nil repeats:YES] retain];[self updatePulse];
}
// Suspended apps keep their memory on iOS 5, so drop everything that can be
// rebuilt: artwork, Cover Flow covers, marquee strips and the drawn wheel/bar
// bitmaps. Called after the app-switcher snapshot has been taken.
- (void)releaseMemory {
    [self clearTransition];[coverDeck purge];PulseLabels(lcd,NO);
    art.image=nil;reflection.image=nil;[artID release];artID=nil;
    wheel.layer.contents=nil;progress.layer.contents=nil;purged=YES;
}
- (void)restoreMemory {if(!purged)return;purged=NO;[wheel setNeedsDisplay];[progress setNeedsDisplay];[self render];}
- (void)didReceiveMemoryWarning {[super didReceiveMemoryWarning];if(!active)[self releaseMemory];else [coverDeck trim];}
- (void)dealloc {RWDisposeClicks();[self setActive:NO];[[NSNotificationCenter defaultCenter] removeObserver:self];[music endGeneratingPlaybackNotifications];[[MPMediaLibrary defaultMediaLibrary] endGeneratingLibraryChangeNotifications];table.delegate=nil;table.dataSource=nil;wheel.delegate=nil;[shell release];[coverDeck release];[monoLCD release];[wheel release];[lcd release];[preview release];[reflectionFade release];[reflection release];[album release];[topBar release];[battery release];[header release];[detail release];[song release];[artist release];[clockLabel release];[hint release];[art release];[table release];[progress release];[scrollTrack release];[scrollThumb release];[artID release];[music release];[stack release];[rows release];[menuTitle release];[super dealloc];}
@end
@interface App : NSObject <UIApplicationDelegate> {UIWindow *window;Player *player;UIBackgroundTaskIdentifier backgroundTask;BOOL background;NSUInteger session;}
@end
@implementation App
- (BOOL)application:(UIApplication *)a didFinishLaunchingWithOptions:(NSDictionary *)o {[a setStatusBarHidden:YES];backgroundTask=UIBackgroundTaskInvalid;window=[[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];player=[[Player alloc] init];[window addSubview:player.view];[window makeKeyAndVisible];return YES;}
- (void)applicationDidBecomeActive:(UIApplication *)a {[player setActive:YES];}
- (void)applicationWillResignActive:(UIApplication *)a {[player setActive:NO];}
- (void)endBackgroundTask {if(backgroundTask!=UIBackgroundTaskInvalid){[[UIApplication sharedApplication] endBackgroundTask:backgroundTask];backgroundTask=UIBackgroundTaskInvalid;}}
// Wait one second so the app-switcher snapshot shows the real screen, then release.
- (void)applicationDidEnterBackground:(UIApplication *)a {
    background=YES;[self endBackgroundTask];NSUInteger mine=++session;
    backgroundTask=[a beginBackgroundTaskWithExpirationHandler:^{[self endBackgroundTask];}];
    // Only the latest background session may purge or end its own task.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(NSEC_PER_SEC)),dispatch_get_main_queue(),^{if(mine!=session)return;if(background)[player releaseMemory];[self endBackgroundTask];});
}
- (void)applicationWillEnterForeground:(UIApplication *)a {background=NO;session++;[self endBackgroundTask];[player restoreMemory];}
- (void)dealloc {[player setActive:NO];[player release];[window release];[super dealloc];}
@end
int main(int argc,char **argv){NSAutoreleasePool *p=[[NSAutoreleasePool alloc] init];int r=UIApplicationMain(argc,argv,nil,@"App");[p release];return r;}
