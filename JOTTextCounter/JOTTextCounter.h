#import <Foundation/Foundation.h>

#pragma mark - NSNotification (Name)
FOUNDATION_EXPORT NSString* const JOTTextCounterDidUpdateCountNotification; // Posted whenever text counter completes counting using client-defined text counting options.

#pragma mark - NSNotification (User Info)
FOUNDATION_EXPORT NSString* const JOTTextCounterComposedCharacterSequencesCountKey; // NSUInteger wrapped in NSNumber.
FOUNDATION_EXPORT NSString* const JOTTextCounterWordCountKey; // NSUInteger wrapped in NSNumber.
FOUNDATION_EXPORT NSString* const JOTTextCounterLineCountKey; // NSUInteger wrapped in NSNumber.
FOUNDATION_EXPORT NSString* const JOTTextCounterSentenceCountKey; // NSUInteger wrapped in NSNumber.
FOUNDATION_EXPORT NSString* const JOTTextCounterParagraphCountKey; // NSUInteger wrapped in NSNumber.

typedef NS_OPTIONS(NSUInteger, JOTTextCounterOptions)
{
    JOTTextCounterOptionsCountComposedCharacterSequences    = 1 << 0,
    JOTTextCounterOptionsCountWords                         = 1 << 1,
    JOTTextCounterOptionsCountLines                         = 1 << 2,
    JOTTextCounterOptionsCountSentences                     = 1 << 3,
    JOTTextCounterOptionsCountParagraphs                    = 1 << 4
};

#warning To-do: Perform delta calculations after performing initial count.
#warning Consider using class cluster to implement optimization algorithms for when character option is disabled (i.e. text counter only needs to run when spacebar is tapped, selection is non-empty, etc.).
/**
 JTPTextCounter counts the number of text tokens of a given granularity in a given text document instance stored as an NSString.
 
 @discussion Currently, clients are only required to forward delegate calls on NSTextStorage's -textStorage:didProcessEditing:range:changeInLength:. In future versions (especially if delta updates is implemented), you may be required to forward additional UITextViewDelegate/NSTextStorageDelegate delegate calls.
 
 @discussion Although JTPTextCounter conforms to UITextViewDelegate, it is NOT recommended that you set JTPTextCounter as your UITextViewDelegate/NSTextStorage object: UITextViewDelegate/NSTextStorage conformance primarily allows clients to easily forward delegate calls.
 
 @warning NOTE: Currently, JTPTextCounter only supports NSString. Do not use with NSAttributedString, or subclasses thereof.
 */
@interface JOTTextCounter : NSObject <UITextViewDelegate, NSTextStorageDelegate>

#pragma mark - Initializers
/**
 Designated initializer.
 */
- (instancetype)initWithOptions:(JOTTextCounterOptions)textCounterOptions;

#pragma mark - NSTextStorageDelegate (Call Forwarding - REQUIRED)
/**
 REQUIRED: You must forward calls on this delegate method to JTPTextCounter.
 */
- (void)textStorage:(NSTextStorage *)textStorage didProcessEditing:(NSTextStorageEditActions)editedMask range:(NSRange)editedRange changeInLength:(NSInteger)delta;

#pragma mark - Count (Methods)
/**
 Provides an initial count of your text: Use this method when you first load a text document.
 @discussion Call this method once you have loaded a string into your UITextView or similar class, and setup its UITextViewDelegate/NSTextStorageDelegate references.
 */
- (void)startCountingWithText:(NSString*)text;

/**
 Prevents internal counter algorithm from running. Call this method if and when you don't need counting to occur, and want to save CPU cycles.
 @discussion You can also think of this method as '-pauseCounting', since you can easily restart counting by calling -startCountingWithText:.
 */
- (void)endCounting;

/**
 Force a count, regardless of whether you have called -startCountingWithText: or -endCounting.
 @discussion This method will force a count and result in JTPTextCounterDidUpdateCountNotification being posted once.
 */
- (void)forceCountWithText:(NSString*)text;

#pragma mark - Count (Options)
/**
 Default: Words, Sentences, Paragraphs.
 */
@property (nonatomic) JOTTextCounterOptions textCountingOptions;

#pragma mark - Count (Values)
@property (nonatomic, assign, readonly) NSUInteger countOfComposedCharacterSequences;
@property (nonatomic, assign, readonly) NSUInteger countOfWords;
@property (nonatomic, assign, readonly) NSUInteger countOfLines;
/**
 @warning New lines that do not contain whitespaces are not considered as sentences.
 */
@property (nonatomic, assign, readonly) NSUInteger countOfSentences;
/**
 @warning New lines that do not contain whitespaces are not considered as paragraphs.
 */
@property (nonatomic, assign, readonly) NSUInteger countOfParagraphs;

@end
