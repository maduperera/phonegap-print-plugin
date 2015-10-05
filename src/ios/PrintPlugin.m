//
//  PrintPlugin.m
//  Print Plugin
//
//  Created by Ian Tipton (github.com/itip) on 02/07/2011.
//  Copyright 2011 Ian Tipton. All rights reserved.
//  MIT licensed
//

#import "PrintPlugin.h"


#define DefaultFontSize 10
#define PaddingFactor 0.1f

@interface PrintPlugin (Private)


-(void) doPrint;
-(void) callbackWithFuntion:(NSString *)function withData:(NSString *)value;
-(BOOL) isPrintServiceAvailable;
-(CGFloat)getHeightForAttributedString:(NSAttributedString *)attributedString;
@end

@implementation PrintPlugin

@synthesize successCallback, failCallback, printText, dialogTopPos, dialogLeftPos;

/*
 Is printing available. Callback returns true/false if printing is available/unavailable.
 */
- (void) isPrintingAvailable:(CDVInvokedUrlCommand*)command{
    NSUInteger argc = [command.arguments count];
    
    //    if (argc < 0) {
    //        return;
    //    }
    CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:([self isPrintServiceAvailable] ? YES : NO)];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) print:(CDVInvokedUrlCommand*)command{
    NSUInteger argc = [command.arguments count];
    NSLog(@"Array contents: %@", command.arguments);
    if (argc < 1) {
        return;
    }
    self.printText = [command.arguments objectAtIndex:0];
    
    if (![self isPrintServiceAvailable]){
        [self callbackWithFuntion:self.failCallback withData: @"{success: false, available: false}"];
        
        return;
    }
    
    UIPrintInteractionController *controller = [UIPrintInteractionController sharedPrintController];
    
    if (!controller){
        return;
    }
    
    
    /*
     Set this object as delegate so you can use
     the printInteractionController:cutLengthForPaper: delegate
     to cut the paper @ required height
     */
    controller.delegate = self;
    
    
    
    if ([UIPrintInteractionController isPrintingAvailable]){
        //Set the priner settings
        UIPrintInfo *printInfo = [UIPrintInfo printInfo];
        printInfo.outputType = UIPrintInfoOutputGeneral;
        if(argc >= 2 && (BOOL)[command.arguments objectAtIndex:1]) {
            printInfo.orientation = UIPrintInfoOrientationLandscape;
        }
        controller.printInfo = printInfo;
        
        /* Create the UISimpleTextPrintFormatter with the text supplied by the user in the text field */
        _textFormatter = [[UISimpleTextPrintFormatter alloc] initWithText:self.printText];
        
        /* Set the text formatter's color and font properties based on what the user chose */
        _textFormatter.color = [UIColor blackColor];
        _textFormatter.font = [UIFont fontWithName:@"ArialMT" size:DefaultFontSize];
        
        
        /* Set this UISimpleTextPrintFormatter on the controller */
        controller.printFormatter = _textFormatter;
        
        controller.showsPageRange = NO;
        
        
        void (^completionHandler)(UIPrintInteractionController *, BOOL, NSError *) =
        ^(UIPrintInteractionController *printController, BOOL completed, NSError *error) {
            CDVPluginResult* pluginResult = nil;
            if (!completed || error) {
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[NSString stringWithFormat:@"{success: false, available: true, error: \"%@\"}", error.localizedDescription]];
            }
            else{
                pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"{success: true}"];
                
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Air Print"
                                                                message:@"Run Ticket is printing!"
                                                               delegate:nil
                                                      cancelButtonTitle:@"OK"
                                                      otherButtonTitles:nil];
                
                [alert show];
                
            }
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
            
            
        };
        
        /*
         If iPad, and if button offsets passed, then show dilalog
         from offset
         */
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad &&
            dialogTopPos != 0 && dialogLeftPos != 0) {
            [controller presentFromRect:CGRectMake(self.dialogLeftPos, self.dialogTopPos, 0, 0) inView:self.webView animated:YES completionHandler:completionHandler];
        } else {
            if ([UIDevice currentDevice].userInterfaceIdiom  == UIUserInterfaceIdiomPad) {
                
                CGRect bounds = self.webView.bounds;
                self.dialogLeftPos = (bounds.size.width / 2) ;
                self.self.dialogTopPos = (bounds.size.height/2);
                
                [controller presentFromRect:CGRectMake(self.dialogLeftPos,self.dialogTopPos, 0, 0) inView:self.webView animated:YES completionHandler:
                 ^(UIPrintInteractionController *ctrl, BOOL ok, NSError *e) {
                     CDVPluginResult* pluginResult =
                     [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
                     
                 }];
                
            } else {
                [controller presentAnimated:YES completionHandler:completionHandler];
            }
        }
        
    }
    
}

-(BOOL) isPrintServiceAvailable{
    
    Class myClass = NSClassFromString(@"UIPrintInteractionController");
    if (myClass) {
        UIPrintInteractionController *controller = [UIPrintInteractionController sharedPrintController];
        return (controller != nil) && [UIPrintInteractionController isPrintingAvailable];
    }
    
    
    return NO;
}

/* calculate the height of an attributed string */
-(CGFloat)getHeightForAttributedString:(NSAttributedString *)attributedString{
    CTTypesetterRef typesetter = CTTypesetterCreateWithAttributedString((CFAttributedStringRef)attributedString);
    CGFloat width = 600;
    
    CFIndex offset = 0, length;
    CGFloat y = 0;
    do {
        length = CTTypesetterSuggestLineBreak(typesetter, offset, width);
        CTLineRef line = CTTypesetterCreateLine(typesetter, CFRangeMake(offset, length));
        
        CGFloat ascent, descent, leading;
        CTLineGetTypographicBounds(line, &ascent, &descent, &leading);
        
        CFRelease(line);
        
        offset += length;
        y += ascent + descent + leading;
    } while (offset < [attributedString length]);
    
    CFRelease(typesetter);
    
    return ceil(y);
}

/* cut the paper @ the end of content */
- (CGFloat)printInteractionController:(UIPrintInteractionController *)printInteractionController cutLengthForPaper:(UIPrintPaper *)paper {
    
    NSAttributedString *attributedString = [[NSAttributedString alloc] initWithString:self.printText];
    CGFloat printableWidth = paper.printableRect.size.width;
    
    CGRect attributedStringBoundingRect = [attributedString boundingRectWithSize:CGSizeMake(printableWidth, CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin context:nil];
    
    //offset value came from heaven
    CGFloat offset = 120;
    CGFloat cutLength = attributedStringBoundingRect.size.height - offset;
    NSLog(@"%f",attributedStringBoundingRect.size.height) ;
    return cutLength;
    
}

- (void)printInteractionControllerWillStartJob:(UIPrintInteractionController *)printInteractionController{
}

- (void)printInteractionControllerDidDismissPrinterOptions:(UIPrintInteractionController *)printInteractionController{
}

// ensures the page is genareated just before printing
-(void)printInteractionControllerDidFinishJob:(UIPrintInteractionController *)printInteractionController{
}



@end
