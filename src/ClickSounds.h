#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

// Skin order matches Settings: Nano, Original, Mini, Classic.
// Cache the tiny PCM resources; never decode or allocate on each wheel step.
static SystemSoundID RWClickSounds[4] = {0, 0, 0, 0};
static BOOL RWClickAttempted[4] = {NO, NO, NO, NO};

static void RWPlayClick(NSInteger skin) {
    if (skin < 0 || skin >= 4) return;
    if (!RWClickAttempted[skin]) {
        RWClickAttempted[skin] = YES;
        NSString *name = [@[@"ClickNano", @"ClickOriginal", @"ClickMini", @"ClickClassic"] objectAtIndex:skin];
        NSURL *url = [[NSBundle mainBundle] URLForResource:name withExtension:@"wav"];
        if (url) AudioServicesCreateSystemSoundID((CFURLRef)url, &RWClickSounds[skin]);
    }
    if (RWClickSounds[skin]) AudioServicesPlaySystemSound(RWClickSounds[skin]);
}

static void RWDisposeClicks(void) {
    for (NSUInteger i = 0; i < 4; i++) {
        if (RWClickSounds[i]) AudioServicesDisposeSystemSoundID(RWClickSounds[i]);
        RWClickSounds[i] = 0;
        RWClickAttempted[i] = NO;
    }
}
