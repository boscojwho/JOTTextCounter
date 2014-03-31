JOTTextCounter
==============
JOTTextCounter is an NSString-based text counter designed for use with UITextView/NSTextStorage on iOS that lets you count composed characters, words, lines, sentences, and paragraphs in an NSString.

This is an open-source version of a text counter used in 'Jot – Refined Text Editor' for iPhone, iPod touch (www.jot-app.com, @jot_app).

Installation
==============
Add JOTTextCounter.h,m to your project.
[CocoaPods currently not available]

Example
==============
Download and run project to see JOTTextCounter in action, and how to set it up in code. 

Setup
==============
Note: Please use the designated initializer.

1 Setup your UITextView's NSTextStorageDelegate class.

2 Call -startCountingWithText: when you initially load a text document to establish initial count values.

3 Forward calls on - (void)textStorage:(NSTextStorage *)textStorage didProcessEditing:(NSTextStorageEditActions)editedMask range:(NSRange)editedRange changeInLength:(NSInteger)delta to JOTTextCounter (JOTTextCounter relies on this to automatically count text in the background when changes are made).

4 Call -endCounting when you want to end/pause counting. 

See header file for detailed documentation.

Usage
==============
Counting
- JOTTextCounter will defer all count requests that it receives if it is currently performing a count.  All deferred requests will be treated as a single deferred request (i.e. If JOTTextCounter defers 10 count requests, it will actually only perform 1 deferred count once it finishes its current count).
- Count values for deferred counts are based on the last NSString received when the deferred count request(s) were originally received.

Options
- JOTTextCounter lets clients choose what text granularity to count (composed characters, words, lines, sentences, paragraphs). Simply set the bitmask JOTTextCounterOptions textCountingOptions.

Notifications
- JOTTextCounter will post a notification for each request once all text counting options return a count value.
- Use the user info key constants defined in JOTTextCounter.h to access count values (these values are also accessible via public properties).
