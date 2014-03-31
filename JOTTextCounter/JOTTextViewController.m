//
//  JOTTextViewController.m
//  JOTTextCounter
//
//  Created by BozBook Air on 2014-03-28.
//  Copyright (c) 2014 J.w. Bosco Ho. All rights reserved.
//

#import "JOTTextViewController.h"
#import "JOTTextCounter.h"

@interface JOTTextViewController ()

@property (nonatomic, strong) JOTTextCounter* textCounter;
@property (weak, nonatomic) IBOutlet UILabel *textCounterLabel;

@end

@implementation JOTTextViewController

#pragma mark - Object Lifecycle
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - View Lifecycle
- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.textView.textStorage.delegate = self;
    [self _registerForTextCounterNotifications];
    [self _registerForKeyboardNotifications];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self.textCounter startCountingWithText:self.textView.text];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [self.textCounter endCounting];
}

#pragma mark - NSNotification
- (void)_registerForTextCounterNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_receiveTextCounterNotification:) name:JTPTextCounterDidUpdateCountNotification object:self.textCounter];
}

- (void)_registerForKeyboardNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_receiveKeyboardNotificaton:) name:UIKeyboardDidShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_receiveKeyboardNotificaton:) name:UIKeyboardDidHideNotification object:nil];
}

- (void)_receiveTextCounterNotification:(NSNotification*)aTextCounterNotification
{
    if ([aTextCounterNotification.name isEqualToString:JTPTextCounterDidUpdateCountNotification])
    {
        [self _textCounterDidUpdateCountWithUserInfo:aTextCounterNotification.userInfo];
    }
}

- (void)_receiveKeyboardNotificaton:(NSNotification*)aKeyboardNotification
{
    CGRect keyboardBeginFrame = [aKeyboardNotification.userInfo[UIKeyboardFrameBeginUserInfoKey] CGRectValue];
    CGRect keyboardEndFrame = [aKeyboardNotification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    double animationDuration = [aKeyboardNotification.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationCurve animationCurve = [aKeyboardNotification.userInfo[UIKeyboardAnimationCurveUserInfoKey] unsignedIntegerValue];
    
    if ([aKeyboardNotification.name isEqualToString:UIKeyboardDidShowNotification])
    {
        [self _adjustScrollViewContentInsets:self.textView keyboardVisible:YES withKeyboardBeginFrame:keyboardBeginFrame keyboardEndFrame:keyboardEndFrame animationDuration:animationDuration animationCurve:animationCurve delay:0.0f];
    }
    else if ([aKeyboardNotification.name isEqualToString:UIKeyboardDidHideNotification])
    {
        [self _adjustScrollViewContentInsets:self.textView keyboardVisible:NO withKeyboardBeginFrame:keyboardBeginFrame keyboardEndFrame:keyboardEndFrame animationDuration:animationDuration animationCurve:animationCurve delay:0.0f];
    }
}

#pragma mark - UINavigationBar
- (IBAction)navigationBarRightBarButtonItemDidPress:(id)sender {
    (self.textView.isFirstResponder) ? [self.textView resignFirstResponder] : [self.textView becomeFirstResponder];
}

#pragma mark - UIScrollView
static inline UIViewAnimationOptions animationOptionsWithCurve(UIViewAnimationCurve curve)
{
    switch (curve) {
        case UIViewAnimationCurveEaseInOut:
            return UIViewAnimationOptionCurveEaseInOut;
        case UIViewAnimationCurveEaseIn:
            return UIViewAnimationOptionCurveEaseIn;
        case UIViewAnimationCurveEaseOut:
            return UIViewAnimationOptionCurveEaseOut;
        case UIViewAnimationCurveLinear:
            return UIViewAnimationOptionCurveLinear;
        default:
            return 0;
    }
}

- (void)_adjustScrollViewContentInsets:(UIScrollView*)scrollView keyboardVisible:(BOOL)isKeyboardVisible withKeyboardBeginFrame:(CGRect)keyboardBeginFrame keyboardEndFrame:(CGRect)keyboardEndFrame animationDuration:(double)animationDuration animationCurve:(UIViewAnimationCurve)animationCurve delay:(NSTimeInterval)delay
{
    UIViewAnimationOptions animationCurveOption = animationOptionsWithCurve(animationCurve);
    CGFloat bottomInset = (isKeyboardVisible) ? CGRectGetHeight(keyboardEndFrame) : 0;
    UIEdgeInsets edgeInsets = UIEdgeInsetsMake(0, 0, bottomInset, 0);
    
    [UIView animateWithDuration:animationDuration delay:delay options:animationCurveOption animations:^{
        self.textView.contentInset = edgeInsets;
        self.textView.scrollIndicatorInsets = edgeInsets;
    } completion:NULL];
}

#pragma mark - NSTextStorageDelegate
- (void)textStorage:(NSTextStorage *)textStorage didProcessEditing:(NSTextStorageEditActions)editedMask range:(NSRange)editedRange changeInLength:(NSInteger)delta
{
    [self.textCounter textStorage:textStorage didProcessEditing:editedMask range:editedRange changeInLength:delta];
}

#pragma mark - JTPTextCounter
- (JOTTextCounter *)textCounter {
    if (!_textCounter) {
        _textCounter = [[JOTTextCounter alloc] init];
    }
    return _textCounter;
}

- (void)_textCounterDidUpdateCountWithUserInfo:(NSDictionary*)userInfo
{
    NSInteger composedCharacterCount = [userInfo[JTPTextCounterComposedCharacterSequencesCountKey] integerValue];
    NSInteger wordCount = [userInfo[JTPTextCounterWordCountKey] integerValue];
    NSInteger lineCount = [userInfo[JTPTextCounterLineCountKey] integerValue];
    NSInteger sentenceCount = [userInfo[JTPTextCounterSentenceCountKey] integerValue];
    NSInteger paragraphCount = [userInfo[JTPTextCounterParagraphCountKey] integerValue];
    
    NSString* textCounterLabelText = [NSString stringWithFormat:@"C:%ld W:%ld L:%ld S:%ld P:%ld", (long)composedCharacterCount, (long)wordCount, (long)lineCount, (long)sentenceCount, (long)paragraphCount];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.textCounterLabel.text = textCounterLabelText;
    });
}

@end
