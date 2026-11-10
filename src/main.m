#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>
#import <QuartzCore/QuartzCore.h>
#import <AudioToolbox/AudioToolbox.h>
#import "WheelMath.h"
static UIColor *RGB(float r,float g,float b){return [UIColor colorWithRed:r green:g blue:b alpha:1];}
static void Gradient(CGContextRef c,CGRect r,UIColor *a,UIColor *b){CGColorSpaceRef s=CGColorSpaceCreateDeviceRGB();NSArray *colors=[NSArray arrayWithObjects:(id)a.CGColor,(id)b.CGColor,nil];CGGradientRef g=CGGradientCreateWithColors(s,(CFArrayRef)colors,NULL);CGContextSaveGState(c);CGContextClipToRect(c,r);CGContextDrawLinearGradient(c,g,CGPointMake(CGRectGetMidX(r),r.origin.y),CGPointMake(CGRectGetMidX(r),CGRectGetMaxY(r)),0);CGContextRestoreGState(c);CGGradientRelease(g);CGColorSpaceRelease(s);}

@interface LCDBar : UIView {BOOL selected,mono;}
@property(nonatomic) BOOL selected,mono;
@end
@implementation LCDBar
@synthesize selected,mono;
- (void)drawRect:(CGRect)r {if(mono){[(selected?RGB(.12,.18,.09):RGB(.65,.72,.52)) setFill];UIRectFill(r);}else Gradient(UIGraphicsGetCurrentContext(),r,selected?RGB(.24,.73,.98):RGB(1,1,1),selected?RGB(.02,.42,.79):RGB(.76,.79,.81));}
@end
@interface Battery : UIView
@end
@implementation Battery
- (void)drawRect:(CGRect)r {CGContextRef c=UIGraphicsGetCurrentContext();CGContextSetStrokeColorWithColor(c,RGB(.38,.42,.42).CGColor);CGContextStrokeRect(c,CGRectMake(1,3,23,10));CGContextSetFillColorWithColor(c,RGB(.5,.53,.53).CGColor);CGContextFillRect(c,CGRectMake(24,6,2,4));float v=[UIDevice currentDevice].batteryLevel;if(v<0)v=1;Gradient(c,CGRectMake(3,5,19*v,6),RGB(.65,.91,.36),RGB(.28,.62,.06));}
@end

@protocol WheelDelegate
- (void)wheelTurn:(int)steps;
- (void)wheelButton:(int)button;
@end
@interface Wheel : UIView {id<WheelDelegate> delegate;BOOL dark,ring,rotated,angleValid,pressed,photographic,original;CGPoint start;double angle,travel,accum;NSTimeInterval last;}
@property(nonatomic,assign) id<WheelDelegate> delegate;
@property(nonatomic) BOOL dark,photographic,original;
@end
@implementation Wheel
@synthesize delegate,dark,photographic,original;
- (void)setDark:(BOOL)v {dark=v;[self setNeedsDisplay];}
- (void)drawRect:(CGRect)r {if(photographic)return;CGContextRef c=UIGraphicsGetCurrentContext();CGRect b=CGRectInset(self.bounds,2,2);CGContextSaveGState(c);CGContextAddEllipseInRect(c,b);CGContextClip(c);Gradient(c,b,dark?RGB(.19,.19,.20):RGB(.98,.98,.97),dark?RGB(.06,.06,.07):RGB(.83,.84,.83));CGContextRestoreGState(c);CGContextSetStrokeColorWithColor(c,(dark?RGB(.03,.03,.03):RGB(.65,.65,.65)).CGColor);CGContextStrokeEllipseInRect(c,b);CGFloat w=r.size.width;CGRect center=CGRectMake(w*.32,w*.32,w*.36,w*.36);CGContextSaveGState(c);CGContextAddEllipseInRect(c,center);CGContextClip(c);Gradient(c,center,dark?RGB(.25,.25,.26):RGB(.92,.92,.92),dark?RGB(.09,.09,.1):RGB(.73,.74,.75));CGContextRestoreGState(c);CGContextSetStrokeColorWithColor(c,RGB(.55,.55,.55).CGColor);CGContextStrokeEllipseInRect(c,center);if(pressed&&!ring){CGContextSetFillColorWithColor(c,[UIColor colorWithWhite:0 alpha:.16].CGColor);CGContextFillEllipseInRect(c,center);}[(dark?[UIColor whiteColor]:RGB(.38,.39,.40)) set];UIFont *f=[UIFont boldSystemFontOfSize:12];[@"MENU" drawInRect:CGRectMake(0,17,w,18) withFont:f lineBreakMode:UILineBreakModeClip alignment:UITextAlignmentCenter];CGContextSetFillColorWithColor(c,(dark?[UIColor whiteColor]:RGB(.38,.39,.40)).CGColor);
CGFloat mid=w/2;
// Monochrome transport glyphs, avoiding Unicode emoji substitution.
for(int side=-1;side<=1;side+=2){CGFloat x=mid+side*(mid-25);for(int n=0;n<2;n++){CGFloat tip=x+side*(n*7+5);CGContextMoveToPoint(c,tip,mid);CGContextAddLineToPoint(c,tip-side*6,mid-4);CGContextAddLineToPoint(c,tip-side*6,mid+4);CGContextClosePath(c);CGContextFillPath(c);}CGContextFillRect(c,CGRectMake(x+side*14-(side<0?2:0),mid-4,2,8));}
CGContextMoveToPoint(c,mid-8,w-27);CGContextAddLineToPoint(c,mid-8,w-19);CGContextAddLineToPoint(c,mid-1,w-23);CGContextClosePath(c);CGContextFillPath(c);CGContextFillRect(c,CGRectMake(mid+3,w-27,2,8));CGContextFillRect(c,CGRectMake(mid+7,w-27,2,8));}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)e {UITouch *t=[touches anyObject];start=[t locationInView:self];CGFloat h=self.bounds.size.width/2;double x=start.x-h,y=start.y-h;double radius=hypot(x,y);ring=radius>h*(original?.28:.38)&&(!original||radius<h*.79);angle=atan2(y,x);travel=accum=0;rotated=NO;angleValid=YES;pressed=YES;[self setNeedsDisplay];last=t.timestamp;}
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)e {if(!ring)return;UITouch *t=[touches anyObject];CGPoint p=[t locationInView:self];CGFloat h=self.bounds.size.width/2;if(hypot(p.x-h,p.y-h)<h*(original?.25:.32)){angleValid=NO;accum=0;return;}double next=atan2(p.y-h,p.x-h);if(!angleValid){angleValid=YES;angle=next;last=t.timestamp;return;}double d=RWAngleDelta(next,angle);angle=next;double dt=t.timestamp-last;last=t.timestamp;travel+=fabs(d);if(travel>.12)rotated=YES;accum+=d;int n=(int)(accum/.15);if(n){accum-=n*.15;double speed=dt>.001?fabs(d)/dt:0;int gain=speed>9?3:speed>5?2:1;[delegate wheelTurn:n*gain];}}
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)e {pressed=NO;[self setNeedsDisplay];if(rotated)return;CGPoint p=[[touches anyObject] locationInView:self];if(hypot(p.x-start.x,p.y-start.y)>18)return;CGFloat h=self.bounds.size.width/2;double x=p.x-h,y=p.y-h;if(hypot(x,y)<h*(original?.28:.38)){[delegate wheelButton:0];return;}if(original&&hypot(x,y)<h*.79)return;if(fabs(y)>fabs(x))[delegate wheelButton:y<0?1:2];else [delegate wheelButton:x<0?3:4];}
- (void)touchesCancelled:(NSSet *)t withEvent:(UIEvent *)e {rotated=YES;accum=0;pressed=NO;[self setNeedsDisplay];}
@end
@interface Shell : UIView {NSInteger skin;CGRect displayRect,wheelRect,bodyRect;}
@property(nonatomic) NSInteger skin;
@property(nonatomic,readonly) CGRect displayRect,wheelRect;
@end
@implementation Shell
@synthesize skin,displayRect,wheelRect;
- (void)setSkin:(NSInteger)v {skin=v;[self setNeedsDisplay];}
- (NSString *)asset {return [@[@"ShellNano.png",@"ShellOriginal.png",@"ShellMini.png",@"ShellClassic.png"] objectAtIndex:skin];}
- (void)layoutSubviews {
    // Measurements are in the supplied Apple front-view photographs, not stretched templates.
    CGSize size=skin==0?CGSizeMake(272,360):skin==1?CGSizeMake(400,664):skin==2?CGSizeMake(200,360):CGSizeMake(375,631);
    CGFloat scale=MIN((self.bounds.size.width-16)/size.width,(self.bounds.size.height-20)/size.height);
    bodyRect=CGRectMake((self.bounds.size.width-size.width*scale)/2,(self.bounds.size.height-size.height*scale)/2,size.width*scale,size.height*scale);
    CGRect d=skin==0?CGRectMake(23,23,224,168):skin==1?CGRectMake(68,35,264,211.2):skin==2?CGRectMake(36,27,124,98.84):CGRectMake(33,34,307,230.25);
    CGRect w=skin==0?CGRectMake(66,199,138,138):skin==1?CGRectMake(30,286,340,340):skin==2?CGRectMake(24,171,154,154):CGRectMake(70,327,234,234);
    displayRect=CGRectMake(bodyRect.origin.x+d.origin.x*scale,bodyRect.origin.y+d.origin.y*scale,d.size.width*scale,d.size.height*scale);
    wheelRect=CGRectMake(bodyRect.origin.x+w.origin.x*scale,bodyRect.origin.y+w.origin.y*scale,w.size.width*scale,w.size.height*scale);
}
- (void)drawRect:(CGRect)r {
    [self layoutSubviews];[[UIColor whiteColor] setFill];UIRectFill(r);
    [[UIImage imageNamed:[self asset]] drawInRect:bodyRect];
}
@end
// Monochrome models use their real pixel canvases, not a scaled color interface.
@interface MonoLCD : UIView {
    NSDictionary *model;
}
@property(nonatomic,copy) NSDictionary *model;
@end
@implementation MonoLCD
@synthesize model;
- (void)setModel:(NSDictionary *)v {if(model!=v){[model release];model=[v copy];}[self setNeedsDisplay];}
- (void)drawRect:(CGRect)rect {
    CGContextRef c=UIGraphicsGetCurrentContext();CGContextSetShouldAntialias(c,NO);
    BOOL mini=[[model objectForKey:@"mini"] boolValue];
    UIColor *paper=mini?RGB(.77,.83,.87):RGB(.80,.81,.75);
    UIColor *ink=mini?RGB(.15,.19,.32):RGB(.17,.18,.16);
    [paper setFill];UIRectFill(self.bounds);[ink setFill];
    CGFloat w=self.bounds.size.width,h=self.bounds.size.height;
    UIFont *font=[UIFont fontWithName:@"Chicago" size:12]?:[UIFont boldSystemFontOfSize:12];
    NSString *title=[model objectForKey:@"title"];
    [title drawInRect:CGRectMake(14,0,w-38,15) withFont:font lineBreakMode:UILineBreakModeTailTruncation alignment:UITextAlignmentCenter];
    if([[model objectForKey:@"playing"] boolValue]){CGContextMoveToPoint(c,3,3);CGContextAddLineToPoint(c,3,11);CGContextAddLineToPoint(c,10,7);CGContextClosePath(c);CGContextFillPath(c);}
    CGContextSetStrokeColorWithColor(c,ink.CGColor);CGContextStrokeRect(c,CGRectMake(w-20,3,16,8));CGContextFillRect(c,CGRectMake(w-3,5,2,4));
    float batteryLevel=[UIDevice currentDevice].batteryLevel;if(batteryLevel<0)batteryLevel=1;
    for(int i=0;i<4;i++)if(batteryLevel>(float)i/4)CGContextFillRect(c,CGRectMake(w-18+i*3,5,2,4));
    CGContextFillRect(c,CGRectMake(0,15,w,1));
    if([[model objectForKey:@"now"] boolValue]) {
        NSArray *lines=[model objectForKey:@"lines"];
        for(NSUInteger i=0;i<lines.count;i++)[[lines objectAtIndex:i] drawInRect:CGRectMake(3,24+i*15,w-6,15) withFont:font lineBreakMode:UILineBreakModeTailTruncation alignment:UITextAlignmentCenter];
        CGRect bar=CGRectMake(6,h-30,w-12,8);CGContextStrokeRect(c,bar);
        CGFloat value=fmax(0,fmin(1,[[model objectForKey:@"progress"] doubleValue]));CGContextFillRect(c,CGRectMake(8,h-28,(w-16)*value,4));
        [[model objectForKey:@"elapsed"] drawInRect:CGRectMake(5,h-18,60,16) withFont:font];
        [[model objectForKey:@"remaining"] drawInRect:CGRectMake(w-65,h-18,60,16) withFont:font lineBreakMode:UILineBreakModeClip alignment:UITextAlignmentRight];
    } else {
        NSArray *items=[model objectForKey:@"rows"];NSInteger selected=[[model objectForKey:@"selection"] integerValue];
        NSInteger capacity=(h-17)/16,first=MAX(0,selected-capacity+1);
        for(NSInteger i=first;i<MIN((NSInteger)items.count,first+capacity);i++){
            CGFloat y=17+(i-first)*16;BOOL highlight=i==selected;
            [ink setFill];if(highlight)CGContextFillRect(c,CGRectMake(0,y,w,16));
            [(highlight?paper:ink) setFill];NSDictionary *row=[items objectAtIndex:i];
            [[row objectForKey:@"title"] drawInRect:CGRectMake(3,y,w-15,16) withFont:font lineBreakMode:UILineBreakModeTailTruncation];
            NSString *kind=[row objectForKey:@"kind"];
            if(![kind isEqual:@"song"]&&![kind isEqual:@"skin"]&&![kind isEqual:@"empty"]){
                CGContextSetStrokeColorWithColor(c,(highlight?paper:ink).CGColor);CGContextSetLineWidth(c,1.5);
                CGContextMoveToPoint(c,w-9,y+4);CGContextAddLineToPoint(c,w-6,y+7);CGContextAddLineToPoint(c,w-9,y+10);CGContextStrokePath(c);
            }
        }
    }
}
- (void)dealloc {[model release];[super dealloc];}
@end

@interface Player : UIViewController <UITableViewDelegate,UITableViewDataSource,WheelDelegate> {Shell *shell;MonoLCD *monoLCD;Wheel *wheel;UIView *lcd,*preview;UILabel *header,*detail,*song,*artist,*clockLabel,*hint;UIImageView *art,*reflection;LCDBar *topBar;Battery *battery;UILabel *album;NSTimeInterval volumeUntil;UITableView *table;UIProgressView *progress;MPMusicPlayerController *music;NSMutableArray *stack;NSArray *rows;NSString *menuTitle;NSInteger selection,skin;BOOL now,seekMode,clicks,active;NSTimer *timer;NSTimeInterval lastClick;}
@end
@implementation Player
- (UIFont *)font:(CGFloat)size {return skin==1||skin==2?([UIFont fontWithName:@"Chicago" size:size]?:[UIFont boldSystemFontOfSize:size]):[UIFont boldSystemFontOfSize:size];}
- (UILabel *)label:(CGRect)r size:(CGFloat)s {UILabel *l=[[[UILabel alloc] initWithFrame:r] autorelease];l.backgroundColor=[UIColor clearColor];l.font=[self font:s];return l;}
- (void)loadView {shell=[[Shell alloc] initWithFrame:[[UIScreen mainScreen] bounds]];self.view=shell;skin=[[NSUserDefaults standardUserDefaults] integerForKey:@"Skin"];if(skin<0||skin>3)skin=0;shell.skin=skin;[shell layoutSubviews];lcd=[[UIView alloc] initWithFrame:shell.displayRect];lcd.clipsToBounds=YES;[shell addSubview:lcd];topBar=[[LCDBar alloc] initWithFrame:CGRectZero];[lcd addSubview:topBar];header=[[self label:CGRectZero size:17] retain];header.textAlignment=UITextAlignmentLeft;[lcd addSubview:header];battery=[[Battery alloc] initWithFrame:CGRectZero];battery.backgroundColor=[UIColor clearColor];battery.opaque=NO;[lcd addSubview:battery];[UIDevice currentDevice].batteryMonitoringEnabled=YES;table=[[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];table.delegate=self;table.dataSource=self;table.separatorStyle=UITableViewCellSeparatorStyleNone;table.rowHeight=24;table.showsVerticalScrollIndicator=NO;[lcd addSubview:table];preview=[[UIView alloc] initWithFrame:CGRectZero];[lcd addSubview:preview];art=[[UIImageView alloc] initWithFrame:CGRectZero];art.contentMode=UIViewContentModeScaleAspectFit;[preview addSubview:art];reflection=[[UIImageView alloc] initWithFrame:CGRectZero];reflection.contentMode=UIViewContentModeScaleAspectFit;reflection.alpha=.16;reflection.transform=CGAffineTransformMakeScale(1,-1);[preview addSubview:reflection];album=[[self label:CGRectZero size:15] retain];[lcd addSubview:album];detail=[[self label:CGRectZero size:11] retain];detail.numberOfLines=3;detail.textAlignment=UITextAlignmentCenter;[preview addSubview:detail];song=[[self label:CGRectZero size:13] retain];song.textAlignment=UITextAlignmentCenter;song.numberOfLines=2;[lcd addSubview:song];artist=[[self label:CGRectZero size:10] retain];artist.textAlignment=UITextAlignmentCenter;[lcd addSubview:artist];clockLabel=[[self label:CGRectZero size:10] retain];clockLabel.textAlignment=UITextAlignmentCenter;[lcd addSubview:clockLabel];hint=[[self label:CGRectZero size:9] retain];hint.textAlignment=UITextAlignmentCenter;[lcd addSubview:hint];progress=[[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];[lcd addSubview:progress];monoLCD=[[MonoLCD alloc] initWithFrame:CGRectZero];monoLCD.userInteractionEnabled=NO;monoLCD.contentScaleFactor=1;monoLCD.layer.magnificationFilter=kCAFilterNearest;[lcd addSubview:monoLCD];wheel=[[Wheel alloc] initWithFrame:shell.wheelRect];wheel.backgroundColor=[UIColor clearColor];wheel.opaque=NO;wheel.delegate=self;[shell addSubview:wheel];stack=[[NSMutableArray alloc] init];clicks=[[NSUserDefaults standardUserDefaults] objectForKey:@"Clicks"]?[[NSUserDefaults standardUserDefaults] boolForKey:@"Clicks"]:YES;music=[[MPMusicPlayerController iPodMusicPlayer] retain];NSNotificationCenter *nc=[NSNotificationCenter defaultCenter];[nc addObserver:self selector:@selector(playbackChanged:) name:MPMusicPlayerControllerNowPlayingItemDidChangeNotification object:music];[nc addObserver:self selector:@selector(playbackChanged:) name:MPMusicPlayerControllerPlaybackStateDidChangeNotification object:music];[nc addObserver:self selector:@selector(libraryChanged:) name:MPMediaLibraryDidChangeNotification object:nil];[[MPMediaLibrary defaultMediaLibrary] beginGeneratingLibraryChangeNotifications];[music beginGeneratingPlaybackNotifications];[self root];[self appearance];}
- (NSDictionary *)row:(NSString *)title kind:(NSString *)kind value:(id)value {return [NSDictionary dictionaryWithObjectsAndKeys:title,@"title",kind,@"kind",value?value:[NSNull null],@"value",nil];}
- (void)setRows:(NSArray *)r title:(NSString *)t { [rows release];rows=[r copy];selection=0;now=NO;[menuTitle release];menuTitle=[t copy];header.text=t;[self render];}
- (void)root { [stack removeAllObjects];
if(skin==1){[self setRows:[NSArray arrayWithObjects:[self row:@"Playlists" kind:@"playlists" value:nil],[self row:@"Artists" kind:@"artists" value:nil],[self row:@"Songs" kind:@"songs" value:nil],[self row:@"Settings" kind:@"settings" value:nil],[self row:@"Now Playing" kind:@"now" value:nil],nil] title:@"iPod"];return;}
if(skin==2){[self setRows:[NSArray arrayWithObjects:[self row:@"Playlists" kind:@"playlists" value:nil],[self row:@"Browse" kind:@"music" value:nil],[self row:@"Settings" kind:@"settings" value:nil],[self row:@"Shuffle Songs" kind:@"shuffle" value:nil],[self row:@"Now Playing" kind:@"now" value:nil],nil] title:@"iPod"];return;}
[self setRows:[NSArray arrayWithObjects:[self row:@"Music" kind:@"music" value:nil],[self row:@"Shuffle Songs" kind:@"shuffle" value:nil],[self row:@"Now Playing" kind:@"now" value:nil],[self row:@"Settings" kind:@"settings" value:nil],nil] title:@"iPod"];}
- (void)push { [stack addObject:[NSDictionary dictionaryWithObjectsAndKeys:rows,@"rows",menuTitle,@"title",[NSNumber numberWithInteger:selection],@"selection",nil]]; }
// A screen change animates the LCD only; the physical shell stays still.
// Duration is a tuning value until compared with captured original hardware.
- (void)transitionBack:(BOOL)backward {
    if(!active || !lcd.window)return;
    CATransition *transition=[CATransition animation];
    transition.type=kCATransitionPush;
    transition.subtype=backward?kCATransitionFromLeft:kCATransitionFromRight;
    transition.duration=.22;
    transition.timingFunction=[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [lcd.layer addAnimation:transition forKey:@"menuNavigation"];
}
- (void)back {if(!now&&!stack.count)return;[self transitionBack:YES];if(now){now=NO;[self render];return;}if(!stack.count)return;NSDictionary *s=[[stack lastObject] retain];[stack removeLastObject];[self setRows:[s objectForKey:@"rows"] title:[s objectForKey:@"title"]];selection=[[s objectForKey:@"selection"] integerValue];[s release];if(!stack.count){[self root];return;}[self render];}
- (void)appearance {shell.skin=skin;[shell layoutSubviews];lcd.transform=CGAffineTransformIdentity;CGSize logical=skin==1?CGSizeMake(160,128):skin==2?CGSizeMake(138,110):CGSizeMake(320,240);lcd.bounds=CGRectMake(0,0,logical.width,logical.height);lcd.center=CGPointMake(CGRectGetMidX(shell.displayRect),CGRectGetMidY(shell.displayRect));lcd.transform=CGAffineTransformMakeScale(shell.displayRect.size.width/logical.width,shell.displayRect.size.height/logical.height);wheel.frame=shell.wheelRect;wheel.dark=skin==0;wheel.photographic=YES;wheel.original=skin==1;BOOL mono=skin==1||skin==2;UIColor *bg=mono?RGB(.72,.78,.60):[UIColor whiteColor];lcd.backgroundColor=bg;table.backgroundColor=bg;header.font=[self font:17];detail.font=[self font:14];song.font=[self font:17];artist.font=[UIFont systemFontOfSize:15];album.font=[UIFont systemFontOfSize:15];[self render];}
- (void)renderMono {
    double total=[[music.nowPlayingItem valueForProperty:MPMediaItemPropertyPlaybackDuration] doubleValue],t=music.currentPlaybackTime;if(!isfinite(t)||t<0)t=0;
    BOOL volume=[NSDate timeIntervalSinceReferenceDate]<volumeUntil;
    NSArray *lines=[NSArray arrayWithObjects:[music.nowPlayingItem valueForProperty:MPMediaItemPropertyTitle]?:@"Nothing playing",[music.nowPlayingItem valueForProperty:MPMediaItemPropertyArtist]?:@"Choose a song",[music.nowPlayingItem valueForProperty:MPMediaItemPropertyAlbumTitle]?:@"",nil];
    int remaining=fmax(0,total-t);
    monoLCD.frame=lcd.bounds;
    monoLCD.model=[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:skin==2],@"mini",now?@"Now Playing":menuTitle,@"title",rows,@"rows",[NSNumber numberWithInteger:selection],@"selection",[NSNumber numberWithBool:now],@"now",[NSNumber numberWithBool:music.playbackState==MPMusicPlaybackStatePlaying],@"playing",lines,@"lines",[NSNumber numberWithDouble:volume?music.volume:total>0?t/total:0],@"progress",volume?@"Volume":[NSString stringWithFormat:@"%d:%02d",(int)t/60,(int)t%60],@"elapsed",volume?@"":[NSString stringWithFormat:@"-%d:%02d",remaining/60,remaining%60],@"remaining",nil];
}
- (void)render {if(!lcd)return;
BOOL monochrome=skin==1||skin==2;
for(UIView *child in lcd.subviews)child.hidden=monochrome;
monoLCD.hidden=!monochrome;
if(monochrome){[self renderMono];return;}
header.text=now?@"Now Playing":menuTitle;CGFloat w=320,h=240;BOOL mono=skin==1||skin==2;NSString *kind=rows.count?[[rows objectAtIndex:0] objectForKey:@"kind"]:@"";BOOL split=!mono&&!now&&([kind isEqual:@"music"]||[kind isEqual:@"artists"]);CGFloat tw=split?160:w;topBar.frame=CGRectMake(0,0,now?w:tw,23);topBar.mono=mono;[topBar setNeedsDisplay];header.frame=CGRectMake(5,1,(now?w:tw)-40,21);header.backgroundColor=[UIColor clearColor];battery.frame=CGRectMake((now?w:tw)-31,3,27,16);[battery setNeedsDisplay];table.hidden=now;table.rowHeight=([kind isEqual:@"song"]||[kind isEqual:@"collection"])?36:24;table.frame=CGRectMake(0,23,tw,h-23);preview.hidden=!split&&!now;preview.frame=now?CGRectMake(8,43,126,154):CGRectMake(tw,0,w-tw,h);preview.clipsToBounds=YES;art.transform=CGAffineTransformIdentity;art.frame=now?CGRectMake(0,0,124,124):CGRectMake(0,0,w-tw,h);art.contentMode=now?UIViewContentModeScaleAspectFit:UIViewContentModeScaleAspectFill;reflection.hidden=!now;reflection.frame=CGRectMake(0,124,124,124);detail.hidden=YES;song.hidden=artist.hidden=album.hidden=progress.hidden=clockLabel.hidden=hint.hidden=!now;if(now){song.frame=CGRectMake(mono?8:143,61,mono?w-16:171,44);song.textAlignment=UITextAlignmentLeft;artist.frame=CGRectMake(mono?8:143,109,mono?w-16:171,20);artist.textAlignment=UITextAlignmentLeft;album.frame=CGRectMake(mono?8:143,132,mono?w-16:171,20);if(mono)preview.hidden=YES;progress.frame=CGRectMake(48,211,224,9);clockLabel.frame=CGRectMake(5,205,42,20);clockLabel.font=[self font:13];clockLabel.textAlignment=UITextAlignmentLeft;hint.frame=CGRectMake(275,205,43,20);hint.font=[self font:13];hint.textAlignment=UITextAlignmentRight;[self updateSong];}else{[table reloadData];if(rows.count){NSIndexPath *p=[NSIndexPath indexPathForRow:selection inSection:0];[table selectRowAtIndexPath:p animated:NO scrollPosition:UITableViewScrollPositionNone];[table scrollToRowAtIndexPath:p atScrollPosition:UITableViewScrollPositionNone animated:NO];}art.image=[[music.nowPlayingItem valueForProperty:MPMediaItemPropertyArtwork] imageWithSize:CGSizeMake(240,240)];detail.hidden=art.image!=nil;detail.frame=CGRectMake(4,80,152,90);detail.font=[UIFont boldSystemFontOfSize:24];detail.text=@"♪\nNo Artwork";} }
- (void)updateSong {MPMediaItem *item=music.nowPlayingItem;song.text=[item valueForProperty:MPMediaItemPropertyTitle]?:@"Nothing playing";artist.text=[item valueForProperty:MPMediaItemPropertyArtist]?:@"Choose a song";album.text=[item valueForProperty:MPMediaItemPropertyAlbumTitle]?:@"";art.image=[[item valueForProperty:MPMediaItemPropertyArtwork] imageWithSize:CGSizeMake(124,124)];reflection.image=art.image;[self tick];}
- (void)tick {if(!now)return;if(skin==1||skin==2){[self renderMono];return;}double total=[[music.nowPlayingItem valueForProperty:MPMediaItemPropertyPlaybackDuration] doubleValue],t=music.currentPlaybackTime;if(!isfinite(t)||t<0)t=0;BOOL vol=[NSDate timeIntervalSinceReferenceDate]<volumeUntil;progress.progress=vol?music.volume:(total>0?t/total:0);int remain=fmax(0,total-t);clockLabel.text=vol?@"Vol.":[NSString stringWithFormat:@"%d:%02d",(int)t/60,(int)t%60];hint.text=vol?[NSString stringWithFormat:@"%d%%",(int)(music.volume*100)]:[NSString stringWithFormat:@"-%d:%02d",remain/60,remain%60];}

- (void)playbackChanged:(NSNotification *)n {if(now)[self updateSong];else [self render];}
- (void)libraryChanged:(NSNotification *)n {[self root];}
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s {return rows.count;}
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)p {UITableViewCell *c=[t dequeueReusableCellWithIdentifier:@"row"];if(!c){c=[[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"row"] autorelease];LCDBar *sel=[[[LCDBar alloc] init] autorelease];sel.selected=YES;c.selectedBackgroundView=sel;}NSDictionary *r=[rows objectAtIndex:p.row];NSString *k=[r objectForKey:@"kind"];BOOL mono=skin==1||skin==2;c.textLabel.text=[r objectForKey:@"title"];c.textLabel.font=[self font:17];c.textLabel.textColor=RGB(.05,.07,.08);c.textLabel.highlightedTextColor=mono?RGB(.75,.80,.63):[UIColor whiteColor];c.detailTextLabel.font=[UIFont systemFontOfSize:13];c.detailTextLabel.textColor=RGB(.35,.38,.4);c.detailTextLabel.highlightedTextColor=[UIColor whiteColor];c.detailTextLabel.text=nil;if([k isEqual:@"song"])c.detailTextLabel.text=[[r objectForKey:@"value"] valueForProperty:MPMediaItemPropertyArtist];else if([k isEqual:@"collection"])c.detailTextLabel.text=[[(MPMediaItemCollection *)[r objectForKey:@"value"] representativeItem] valueForProperty:MPMediaItemPropertyArtist];[(LCDBar *)c.selectedBackgroundView setMono:mono];[c.selectedBackgroundView setNeedsDisplay];c.backgroundColor=[UIColor clearColor];c.accessoryType=([k isEqual:@"song"]||[k isEqual:@"empty"]||[k isEqual:@"skin"])?UITableViewCellAccessoryNone:UITableViewCellAccessoryDisclosureIndicator;return c;}

- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)p {selection=p.row;[self choose];}
- (void)click {NSTimeInterval t=[NSDate timeIntervalSinceReferenceDate];if(clicks&&t-lastClick>.045){AudioServicesPlaySystemSound(1104);lastClick=t;}}
- (void)wheelTurn:(int)steps {if(now){if(seekMode){double total=[[music.nowPlayingItem valueForProperty:MPMediaItemPropertyPlaybackDuration] doubleValue];music.currentPlaybackTime=fmax(0,fmin(total,music.currentPlaybackTime+steps*3));}else {music.volume=fmax(0,fmin(1,music.volume+steps*.025));volumeUntil=[NSDate timeIntervalSinceReferenceDate]+2;}[self tick];return;}NSInteger next=RWClampSelection((int)selection,steps,(int)rows.count);if(next!=selection){selection=next;if(skin==1||skin==2){[self click];[self renderMono];return;}NSIndexPath *p=[NSIndexPath indexPathForRow:selection inSection:0];[table selectRowAtIndexPath:p animated:NO scrollPosition:UITableViewScrollPositionNone];[table scrollToRowAtIndexPath:p atScrollPosition:UITableViewScrollPositionNone animated:NO];[self click];if(skin==1||skin==2)[self renderMono];}}
- (void)wheelButton:(int)b {[self click];if(b==1){[self back];return;}if(b==2){if(music.playbackState==MPMusicPlaybackStatePlaying)[music pause];else [music play];return;}if(b==3){if(music.currentPlaybackTime>3)[music skipToBeginning];else [music skipToPreviousItem];return;}if(b==4){[music skipToNextItem];return;}if(now){seekMode=!seekMode;volumeUntil=0;[self tick];}else [self choose];}
- (void)showQuery:(MPMediaQuery *)q kind:(NSString *)kind title:(NSString *)title {NSMutableArray *r=[NSMutableArray array];if([kind isEqual:@"song"]){for(MPMediaItem *i in q.items)[r addObject:[self row:[i valueForProperty:MPMediaItemPropertyTitle]?:@"Untitled" kind:@"song" value:i]];}else for(MPMediaItemCollection *c in q.collections){NSString *t=[kind isEqual:@"artist"]?[c.representativeItem valueForProperty:MPMediaItemPropertyArtist]:[kind isEqual:@"album"]?[c.representativeItem valueForProperty:MPMediaItemPropertyAlbumTitle]:[(MPMediaPlaylist *)c valueForProperty:MPMediaPlaylistPropertyName];[r addObject:[self row:t?:@"Unknown" kind:@"collection" value:c]];}if(!r.count)[r addObject:[self row:@"No music synced" kind:@"empty" value:nil]];[self setRows:r title:title];}
- (void)settings {[self setRows:[NSArray arrayWithObjects:[self row:@"Skins" kind:@"skins" value:nil],[self row:clicks?@"Clicker: On":@"Clicker: Off" kind:@"clicks" value:nil],[self row:music.shuffleMode==MPMusicShuffleModeSongs?@"Shuffle: Songs":@"Shuffle: Off" kind:@"shuffleMode" value:nil],[self row:music.repeatMode==MPMusicRepeatModeOne?@"Repeat: One":music.repeatMode==MPMusicRepeatModeAll?@"Repeat: All":@"Repeat: Off" kind:@"repeat" value:nil],nil] title:@"Settings"];}
- (void)choose {if(selection<0||selection>=rows.count)return;NSDictionary *row=[[rows objectAtIndex:selection] retain];NSString *k=[row objectForKey:@"kind"],*title=[row objectForKey:@"title"];id v=[row objectForKey:@"value"];
BOOL navigation=[k isEqual:@"music"]||[k isEqual:@"artists"]||[k isEqual:@"albums"]||[k isEqual:@"songs"]||[k isEqual:@"playlists"]||[k isEqual:@"collection"]||[k isEqual:@"song"]||[k isEqual:@"now"]||[k isEqual:@"settings"]||[k isEqual:@"skins"];
if(navigation)[self transitionBack:NO];
if([k isEqual:@"music"]){[self push];[self setRows:[NSArray arrayWithObjects:[self row:@"Artists" kind:@"artists" value:nil],[self row:@"Albums" kind:@"albums" value:nil],[self row:@"Songs" kind:@"songs" value:nil],[self row:@"Playlists" kind:@"playlists" value:nil],nil] title:@"Music"];}
else if([k isEqual:@"artists"]||[k isEqual:@"albums"]||[k isEqual:@"songs"]||[k isEqual:@"playlists"]){[self push];MPMediaQuery *q=[k isEqual:@"artists"]?[MPMediaQuery artistsQuery]:[k isEqual:@"albums"]?[MPMediaQuery albumsQuery]:[k isEqual:@"songs"]?[MPMediaQuery songsQuery]:[MPMediaQuery playlistsQuery];[self showQuery:q kind:[k isEqual:@"artists"]?@"artist":[k isEqual:@"albums"]?@"album":[k isEqual:@"songs"]?@"song":@"playlist" title:title];}
else if([k isEqual:@"collection"]){[self push];NSMutableArray *r=[NSMutableArray array];for(MPMediaItem *i in [(MPMediaItemCollection *)v items])[r addObject:[self row:[i valueForProperty:MPMediaItemPropertyTitle]?:@"Untitled" kind:@"song" value:i]];if(!r.count)[r addObject:[self row:@"Empty playlist" kind:@"empty" value:nil]];[self setRows:r title:title];}
else if([k isEqual:@"song"]){NSMutableArray *items=[NSMutableArray array];for(NSDictionary *r in rows)if([[r objectForKey:@"kind"] isEqual:@"song"])[items addObject:[r objectForKey:@"value"]];[music setQueueWithItemCollection:[MPMediaItemCollection collectionWithItems:items]];music.nowPlayingItem=v;[music play];now=YES;seekMode=NO;[self render];}
else if([k isEqual:@"shuffle"]){MPMediaQuery *q=[MPMediaQuery songsQuery];if(q.items.count){[self transitionBack:NO];[music setQueueWithQuery:q];music.shuffleMode=MPMusicShuffleModeSongs;[music play];now=YES;[self render];}}
else if([k isEqual:@"now"]){now=YES;seekMode=NO;[self render];}
else if([k isEqual:@"settings"]){[self push];[self settings];}
else if([k isEqual:@"skins"]){[self push];NSArray *names=[NSArray arrayWithObjects:@"Nano · 3rd generation",@"Original iPod",@"iPod mini",@"iPod classic",nil];NSMutableArray *r=[NSMutableArray array];for(int i=0;i<4;i++)[r addObject:[self row:[names objectAtIndex:i] kind:@"skin" value:[NSNumber numberWithInt:i]]];[self setRows:r title:@"Skins"];}
else if([k isEqual:@"skin"]){skin=[v integerValue];[[NSUserDefaults standardUserDefaults] setInteger:skin forKey:@"Skin"];[self appearance];}
else if([k isEqual:@"clicks"]){clicks=!clicks;[[NSUserDefaults standardUserDefaults] setBool:clicks forKey:@"Clicks"];[self settings];selection=1;[self render];}
else if([k isEqual:@"shuffleMode"]){music.shuffleMode=music.shuffleMode==MPMusicShuffleModeSongs?MPMusicShuffleModeOff:MPMusicShuffleModeSongs;[self settings];selection=2;[self render];}
else if([k isEqual:@"repeat"]){music.repeatMode=music.repeatMode==MPMusicRepeatModeNone?MPMusicRepeatModeAll:music.repeatMode==MPMusicRepeatModeAll?MPMusicRepeatModeOne:MPMusicRepeatModeNone;[self settings];selection=3;[self render];}
[row release];}
- (void)setActive:(BOOL)v {active=v;if(!v)[lcd.layer removeAnimationForKey:@"menuNavigation"];[timer invalidate];[timer release];timer=nil;if(v)timer=[[NSTimer scheduledTimerWithTimeInterval:.5 target:self selector:@selector(tick) userInfo:nil repeats:YES] retain];}
- (void)dealloc {[self setActive:NO];[[NSNotificationCenter defaultCenter] removeObserver:self];[music endGeneratingPlaybackNotifications];[[MPMediaLibrary defaultMediaLibrary] endGeneratingLibraryChangeNotifications];table.delegate=nil;table.dataSource=nil;wheel.delegate=nil;[shell release];[monoLCD release];[wheel release];[lcd release];[preview release];[reflection release];[album release];[topBar release];[battery release];[header release];[detail release];[song release];[artist release];[clockLabel release];[hint release];[art release];[table release];[progress release];[music release];[stack release];[rows release];[menuTitle release];[super dealloc];}
@end
@interface App : NSObject <UIApplicationDelegate> {UIWindow *window;Player *player;}
@end
@implementation App
- (BOOL)application:(UIApplication *)a didFinishLaunchingWithOptions:(NSDictionary *)o {[a setStatusBarHidden:YES];window=[[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];player=[[Player alloc] init];[window addSubview:player.view];[window makeKeyAndVisible];return YES;}
- (void)applicationDidBecomeActive:(UIApplication *)a {[player setActive:YES];}
- (void)applicationWillResignActive:(UIApplication *)a {[player setActive:NO];}
- (void)dealloc {[player setActive:NO];[player release];[window release];[super dealloc];}
@end
int main(int argc,char **argv){NSAutoreleasePool *p=[[NSAutoreleasePool alloc] init];int r=UIApplicationMain(argc,argv,nil,@"App");[p release];return r;}
