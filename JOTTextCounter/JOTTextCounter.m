#import "JOTTextCounter.h"

#pragma mark - NSNotification (Name)
NSString* const JTPTextCounterDidUpdateCountNotification = @"JTPTextCounterDidUpdateCountNotification";

#pragma mark - NSNotification (User Info)
NSString* const JTPTextCounterComposedCharacterSequencesCountKey = @"JTPTextCounterComposedCharacterSequencesCountKey";
NSString* const JTPTextCounterWordCountKey = @"JTPTextCounterWordCountKey";
NSString* const JTPTextCounterLineCountKey = @"JTPTextCounterLineCountKey";
NSString* const JTPTextCounterSentenceCountKey = @"JTPTextCounterSentenceCountKey";
NSString* const JTPTextCounterParagraphCountKey = @"JTPTextCounterParagraphCountKey";

#pragma mark - PRIVATE KEYS
static NSString* const JTPTextCounterTextViewKey = @"PRIVATE_JTPTextCounterTextViewKey";
static NSString* const JTPTextCounterTextStorageKey = @"PRIVATE_JTPTextCounterTextStorageKey";

typedef void (^JTPStringMetadataCompletionHandler)(NSUInteger count);

@interface JOTTextCounter ()

@property (nonatomic, strong) dispatch_group_t textCounterConcurrentGroup;
@property (nonatomic, strong) dispatch_queue_t textCounterConcurrentQueue;
@property (nonatomic, assign, getter = isCounterRunning) BOOL counterRunning;

@property (nonatomic, strong) NSTimer* delayCountTimer;
/**
 Text that requires counting, but request was received while counter was running. This text is enqueued for later counting, thus 'queued' text.
 */
@property (nonatomic, strong) NSString* queuedText;
@property (nonatomic, assign, getter = didReceiveCountRequestWhileCounterWasRunning) BOOL receivedCountRequestWhileCounterWasRunning;

/**
 YES after -startCountingWithText: is called
 NO after -endCounting is called.
 */
@property (nonatomic, assign, getter = shouldAllowCount) BOOL allowCount;

@property (nonatomic, strong) NSCharacterSet* newlineWhitespace;

#pragma mark - Count (Values)
@property (nonatomic, assign, readwrite) NSUInteger countOfComposedCharacterSequences;
@property (nonatomic, assign, readwrite) NSUInteger countOfWords;
@property (nonatomic, assign, readwrite) NSUInteger countOfLines;
@property (nonatomic, assign, readwrite) NSUInteger countOfSentences;
@property (nonatomic, assign, readwrite) NSUInteger countOfParagraphs;

@end

@implementation JOTTextCounter

#pragma mark - Object Lifecycle
- (instancetype)init
{
    if (!(self = [self initWithOptions:JOTTextCounterOptionsCountWords|JOTTextCounterOptionsCountSentences|JOTTextCounterOptionsCountParagraphs])) return nil;
    return self;
}

- (instancetype)initWithOptions:(JOTTextCounterOptions)textCounterOptions
{
    if (!(self = [super init])) return nil;
    
    _textCountingOptions = (textCounterOptions == 0) ? JOTTextCounterOptionsCountWords|JOTTextCounterOptionsCountSentences|JOTTextCounterOptionsCountParagraphs : textCounterOptions;
    
    _allowCount = NO;
    _counterRunning = NO;
    _receivedCountRequestWhileCounterWasRunning = NO;
    
    return self;
}

- (void)dealloc
{
    [self.delayCountTimer invalidate];
}

#pragma mark - Count
- (void)startCountingWithText:(NSString *)text
{
    if (!self.shouldAllowCount)
    {
        self.allowCount = YES;
        [self _performCountWithText:[[NSString alloc] initWithString:text] forceCount:NO];
    }
}

- (void)endCounting
{
    self.allowCount = NO;
}

- (void)forceCountWithText:(NSString *)text
{
    [self _performCountWithText:[[NSString alloc] initWithString:text] forceCount:YES];
}

#pragma mark - NSTextStorageDelegate (Call Forwarding)
- (void)textStorage:(NSTextStorage *)textStorage didProcessEditing:(NSTextStorageEditActions)editedMask range:(NSRange)editedRange changeInLength:(NSInteger)delta
{
    // Crude optimization.
    if (textStorage.string.length > 1000) {
        // Defer running counter if it's currently active and
        if (self.isCounterRunning) {
            // If we keep rescheduling timer, there's a chance that delayCountTimer may never fire.
            // Plus, it's a bit of a waste of CPU time to needlessly reschedule.
            if (!self.delayCountTimer.isValid) {
                self.delayCountTimer = [NSTimer scheduledTimerWithTimeInterval:3.0 target:self selector:@selector(_handleDelayCountTimer:) userInfo:@{JTPTextCounterTextStorageKey: textStorage} repeats:NO];
            }
            // Else, let currently valid delayCountTimer handle counting.
            else {
                return;
            }
        }
        // Immediately perform count if counter isn't currently active.
        else {
            [self.delayCountTimer invalidate];
            [self _performCountWithText:[[NSString alloc] initWithString:textStorage.string] forceCount:NO];
        }
    }
    else {
        [self.delayCountTimer invalidate];
        [self _performCountWithText:[[NSString alloc] initWithString:textStorage.string] forceCount:NO];
    }
}

#pragma mark - PRIVATE LOGIC
#pragma mark - Timer
- (void)_handleDelayCountTimer:(NSTimer*)aTimer
{
    UITextView* textView = aTimer.userInfo[JTPTextCounterTextViewKey];
    NSTextStorage* textStorage = aTimer.userInfo[JTPTextCounterTextStorageKey];
    if (textStorage)
    {
        NSString* text = [[NSString alloc] initWithString:textStorage.string];
        [self _performCountWithText:text forceCount:NO];
    }
    else if (textView)
    {
        NSString* text = [[NSString alloc] initWithString:textView.text];
        [self _performCountWithText:text forceCount:NO];
    }
}

#pragma mark - Count Logic
/**
 Performs count within a dispatch group, and waits for all counts to finish before posting update notification.
 @discussion For example, if word count finishes, but paragraph count is still completing, the dispatch group in this method will wait until paragraph count finishes before posting an update notification.
 */
- (void)_performCountWithText:(NSString*)text forceCount:(BOOL)shouldForceCount
{
    if (!self.shouldAllowCount && !shouldForceCount) {
        return;
    }
    
    if (self.counterRunning) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.queuedText = text;
            self.receivedCountRequestWhileCounterWasRunning = YES;
        });
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.counterRunning = YES;
        self.receivedCountRequestWhileCounterWasRunning = NO;
    });
    
    __weak JOTTextCounter* weakSelf = self;
    dispatch_async(self.textCounterConcurrentQueue, ^{
        
        if (self.textCountingOptions & JOTTextCounterOptionsCountComposedCharacterSequences)
        {
            dispatch_group_enter(self.textCounterConcurrentGroup);
            [self _composedCharacterCountForString:text withOptions:NSStringEnumerationByComposedCharacterSequences|NSStringEnumerationSubstringNotRequired completion:^(NSUInteger count) {
                weakSelf.countOfComposedCharacterSequences = count;
                dispatch_group_leave(self.textCounterConcurrentGroup);
            }];
        }
        if (self.textCountingOptions & JOTTextCounterOptionsCountWords)
        {
            dispatch_group_enter(self.textCounterConcurrentGroup);
            [self _wordCountForString:text withOptions:NSStringEnumerationByWords|NSStringEnumerationLocalized|NSStringEnumerationSubstringNotRequired completion:^(NSUInteger count) {
                weakSelf.countOfWords = count;
                dispatch_group_leave(self.textCounterConcurrentGroup);
            }];
        }
        if (self.textCountingOptions & JOTTextCounterOptionsCountLines)
        {
            dispatch_group_enter(self.textCounterConcurrentGroup);
            [self _lineCountForString:text withOptions:NSStringEnumerationByLines|NSStringEnumerationSubstringNotRequired completion:^(NSUInteger count) {
                weakSelf.countOfLines = count;
                dispatch_group_leave(self.textCounterConcurrentGroup);
            }];
        }
        if (self.textCountingOptions & JOTTextCounterOptionsCountSentences)
        {
            dispatch_group_enter(self.textCounterConcurrentGroup);
            [self _sentenceCountForString:text withOptions:NSStringEnumerationBySentences|NSStringEnumerationLocalized completion:^(NSUInteger count) {
                weakSelf.countOfSentences = count;
                dispatch_group_leave(self.textCounterConcurrentGroup);
            }];
        }
        if (self.textCountingOptions & JOTTextCounterOptionsCountParagraphs)
        {
            dispatch_group_enter(self.textCounterConcurrentGroup);
            [self _paragraphCountForString:text withOptions:NSStringEnumerationByParagraphs completion:^(NSUInteger count) {
                weakSelf.countOfParagraphs = count;
                dispatch_group_leave(self.textCounterConcurrentGroup);
            }];
        }
        
        dispatch_group_notify(self.textCounterConcurrentGroup, self.textCounterConcurrentQueue, ^{
            dispatch_async(dispatch_get_main_queue(), ^{
                self.counterRunning = NO;
            });
            if (self.didReceiveCountRequestWhileCounterWasRunning) {
                [self _performCountWithText:self.queuedText forceCount:NO];
            }
            [self _postUpdateNotification];
        });
    });
}

/**
 Performs a count with an enumeration block that only increments count, and does not test substrings for additional accuracy inside enumeration block.
 */
- (void)_vanillaCountForString:(NSString*)string withOptions:(NSStringEnumerationOptions)options completion:(JTPStringMetadataCompletionHandler)completion
{
    __block NSUInteger count = 0;
    dispatch_async(self.textCounterConcurrentQueue, ^{
        [string enumerateSubstringsInRange:NSMakeRange(0, string.length)
                                   options:options
                                usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
                                    count++;
                                }];
        completion(count);
    });
}

- (void)_composedCharacterCountForString:(NSString*)string withOptions:(NSStringEnumerationOptions)options completion:(JTPStringMetadataCompletionHandler)completion
{
    [self _vanillaCountForString:string withOptions:options completion:completion];
}

- (void)_wordCountForString:(NSString*)string withOptions:(NSStringEnumerationOptions)options completion:(JTPStringMetadataCompletionHandler)completion
{
    [self _vanillaCountForString:string withOptions:options completion:completion];
}

- (void)_lineCountForString:(NSString*)string withOptions:(NSStringEnumerationOptions)options completion:(JTPStringMetadataCompletionHandler)completion
{
    [self _vanillaCountForString:string withOptions:options completion:completion];
}

- (void)_sentenceCountForString:(NSString*)string withOptions:(NSStringEnumerationOptions)options completion:(JTPStringMetadataCompletionHandler)completion
{
    __block NSUInteger count = 0;
    dispatch_async(self.textCounterConcurrentQueue, ^{
        [string enumerateSubstringsInRange:NSMakeRange(0, string.length)
                                   options:options
                                usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
                                    NSString* trim = [substring stringByTrimmingCharactersInSet:self.newlineWhitespace];
                                    if (trim.length != 0) {
                                        count++;
                                    }
                                }];
        completion(count);
    });
}

- (void)_paragraphCountForString:(NSString*)string withOptions:(NSStringEnumerationOptions)options completion:(JTPStringMetadataCompletionHandler)completion
{
    __block NSUInteger count = 0;
    dispatch_async(self.textCounterConcurrentQueue, ^{
        [string enumerateSubstringsInRange:NSMakeRange(0, string.length)
                                   options:options
                                usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
                                    NSString* trim = [substring stringByTrimmingCharactersInSet:self.newlineWhitespace];
                                    if (trim.length != 0) {
                                        count++;
                                    }
                                }];
        completion(count);
    });
}

#pragma mark - NSNotification
- (void)_postUpdateNotification
{
    NSDictionary* userInfo = @{JTPTextCounterComposedCharacterSequencesCountKey: @(self.countOfComposedCharacterSequences),
                               JTPTextCounterWordCountKey: @(self.countOfWords),
                               JTPTextCounterLineCountKey: @(self.countOfLines),
                               JTPTextCounterSentenceCountKey: @(self.countOfSentences),
                               JTPTextCounterParagraphCountKey: @(self.countOfParagraphs)};
    NSNotification* notification = [NSNotification notificationWithName:JTPTextCounterDidUpdateCountNotification object:self userInfo:userInfo];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationQueue defaultQueue] enqueueNotification:notification postingStyle:NSPostNow coalesceMask:NSNotificationCoalescingOnName|NSNotificationCoalescingOnSender forModes:@[[NSRunLoop mainRunLoop]]];
    });
}

#pragma mark - NSCharacterSet
- (NSCharacterSet *)newlineWhitespace {
    if (!_newlineWhitespace) {
        _newlineWhitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    }
    return _newlineWhitespace;
}

#pragma mark - Grand Central Dispatch
- (dispatch_group_t)textCounterConcurrentGroup {
    if (!_textCounterConcurrentGroup) {
        _textCounterConcurrentGroup = dispatch_group_create();
    }
    return _textCounterConcurrentGroup;
}

- (dispatch_queue_t)textCounterConcurrentQueue {
    if (!_textCounterConcurrentQueue) {
        _textCounterConcurrentQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    }
    return _textCounterConcurrentQueue;
}

@end
