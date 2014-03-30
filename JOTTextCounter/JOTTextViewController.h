//
//  JOTTextViewController.h
//  JOTTextCounter
//
//  Created by BozBook Air on 2014-03-28.
//  Copyright (c) 2014 J.w. Bosco Ho. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface JOTTextViewController : UIViewController <UITextViewDelegate, NSTextStorageDelegate>

@property (strong, nonatomic) IBOutlet UITextView *textView;

@end
