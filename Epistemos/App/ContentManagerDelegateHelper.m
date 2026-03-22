#import "ContentManagerDelegateHelper.h"
#import <objc/message.h>

void EpistemosSetContentManagerDelegate(NSTextContentStorage *contentStorage,
                                        id<NSTextContentManagerDelegate> delegate) {
    // Call NSTextContentManager's setDelegate: (the parent), not NSTextContentStorage's override.
    // This targets the NSTextContentManagerDelegate slot for shouldEnumerate callbacks.
    struct objc_super superInfo;
    superInfo.receiver = contentStorage;
    superInfo.super_class = [NSTextContentManager class];

    ((void (*)(struct objc_super *, SEL, id))objc_msgSendSuper)(
        &superInfo, @selector(setDelegate:), delegate
    );
}
