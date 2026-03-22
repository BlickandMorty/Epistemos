#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Sets the NSTextContentManagerDelegate on an NSTextContentStorage instance.
/// NSTextContentStorage overrides the `delegate` property with NSTextContentStorageDelegate,
/// shadowing the parent NSTextContentManager.delegate (NSTextContentManagerDelegate).
/// This helper calls the superclass setter to target the parent's delegate slot,
/// enabling shouldEnumerate callbacks for non-destructive fold filtering.
void EpistemosSetContentManagerDelegate(NSTextContentStorage *contentStorage,
                                        id<NSTextContentManagerDelegate> delegate);

NS_ASSUME_NONNULL_END
