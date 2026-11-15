#import <Foundation/Foundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import "ScrobbleMath.h"

// Play log for Last.fm. Each play that passes the scrobble threshold while Rewind
// is watching adds one line to Documents/scrobbles.tsv:
//   1 <tab> start (Unix seconds) <tab> persistent ID (signed, as in MediaLibrary.sqlitedb)
//     <tab> artist <tab> title <tab> album <tab> album artist <tab> duration (seconds)
// Nothing is sent from the iPod. tools/scrobble.py pulls the file, fills in plays
// Rewind missed while suspended from the library's play counts, and submits them.
// Post around a seek: before it, so listening up to the seek is credited; after it,
// so the jump itself is neither credited nor taken for a restart.
static NSString *const RWScrobbleWillSeekNotification = @"RWScrobbleWillSeek";
static NSString *const RWScrobbleDidSeekNotification = @"RWScrobbleDidSeek";

@interface RWScrobbler : NSObject {
    MPMusicPlayerController *music;
    NSString *path;
    NSTimer *timer;
    MPMediaItem *item;
    unsigned long long itemID;
    double started, listened, threshold, lastPosition, lastWall;
    BOOL logged;
}
- (void)sync;
@end

@implementation RWScrobbler
- (id)init {
    if ((self = [super init])) {
        NSString *docs = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
        path = [[docs stringByAppendingPathComponent:@"scrobbles.tsv"] retain];
        music = [[MPMusicPlayerController iPodMusicPlayer] retain];
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc addObserver:self selector:@selector(changed:) name:MPMusicPlayerControllerNowPlayingItemDidChangeNotification object:music];
        [nc addObserver:self selector:@selector(changed:) name:MPMusicPlayerControllerPlaybackStateDidChangeNotification object:music];
        [nc addObserver:self selector:@selector(changed:) name:RWScrobbleWillSeekNotification object:nil];
        [nc addObserver:self selector:@selector(seeked:) name:RWScrobbleDidSeekNotification object:nil];
        [music beginGeneratingPlaybackNotifications];
        [self sync];
    }
    return self;
}
- (void)changed:(NSNotification *)n {[self sync];}
- (void)seeked:(NSNotification *)n {
    MPMediaItem *current = music.nowPlayingItem;
    unsigned long long identity = current ? [[current valueForProperty:MPMediaItemPropertyPersistentID] unsignedLongLongValue] : 0;
    if (identity != itemID) {[self sync];return;}
    double position = music.currentPlaybackTime;
    lastPosition = isfinite(position) && position >= 0 ? position : 0;lastWall = CFAbsoluteTimeGetCurrent();
    [self sync];
}

// A play first seen part-way through earns credit only from here on, so a track
// already playing at launch is logged only if the rest of it passes the threshold.
- (void)begin:(MPMediaItem *)next identity:(unsigned long long)identity position:(double)position now:(double)now {
    [item release];item = [next retain];itemID = identity;
    started = now - position;listened = 0;lastPosition = position;lastWall = now;logged = NO;threshold = -1;
    if (!next) return;
    NSInteger type = [[next valueForProperty:MPMediaItemPropertyMediaType] integerValue];
    if (type & MPMediaTypeMusic) threshold = RWScrobbleThreshold([[next valueForProperty:MPMediaItemPropertyPlaybackDuration] doubleValue]);
}

- (void)sync {
    double now = CFAbsoluteTimeGetCurrent(), position = music.currentPlaybackTime;
    if (!isfinite(position) || position < 0) position = 0;
    MPMediaItem *current = music.nowPlayingItem;
    unsigned long long identity = current ? [[current valueForProperty:MPMediaItemPropertyPersistentID] unsignedLongLongValue] : 0;
    if (identity != itemID || RWScrobbleRestarted(lastPosition, position)) [self begin:current identity:identity position:position now:now];
    else {listened += RWScrobbleCredit(lastPosition, position, now - lastWall);lastPosition = position;lastWall = now;}
    if (item && !logged && threshold > 0 && listened >= threshold) {logged = YES;[self write];}
    [timer invalidate];[timer release];timer = nil;
    // One wake-up when the threshold should be crossed; nothing runs while paused.
    if (item && !logged && threshold > 0 && music.playbackState == MPMusicPlaybackStatePlaying)
        timer = [[NSTimer scheduledTimerWithTimeInterval:fmax(1, threshold - listened + .5) target:self selector:@selector(sync) userInfo:nil repeats:NO] retain];
}

static NSString *RWField(MPMediaItem *item, NSString *property) {
    NSString *value = [item valueForProperty:property];
    if (![value isKindOfClass:[NSString class]]) return @"";
    NSMutableString *clean = [[value mutableCopy] autorelease];
    for (NSString *bad in @[@"\t", @"\r", @"\n"]) [clean replaceOccurrencesOfString:bad withString:@" " options:0 range:NSMakeRange(0, clean.length)];
    return clean;
}

- (void)write {
    NSString *line = [NSString stringWithFormat:@"1\t%lld\t%lld\t%@\t%@\t%@\t%@\t%d\n",
        (long long)llround(started + kCFAbsoluteTimeIntervalSince1970), (long long)itemID,
        RWField(item, MPMediaItemPropertyArtist), RWField(item, MPMediaItemPropertyTitle),
        RWField(item, MPMediaItemPropertyAlbumTitle), RWField(item, MPMediaItemPropertyAlbumArtist),
        (int)llround([[item valueForProperty:MPMediaItemPropertyPlaybackDuration] doubleValue])];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:path]) [fm createFileAtPath:path contents:nil attributes:nil];
    NSFileHandle *file = [NSFileHandle fileHandleForWritingAtPath:path];
    if (!file) return;
    @try {[file seekToEndOfFile];[file writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];}
    @catch (NSException *e) {}
    [file closeFile];
}

- (void)dealloc {
    [timer invalidate];[timer release];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [music release];[item release];[path release];
    [super dealloc];
}
@end
