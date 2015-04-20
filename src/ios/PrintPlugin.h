//
//  PrintPlugin.h
//  Print Plugin
//
//  Created by Ian Tipton (github.com/itip) on 02/07/2011.
//  Copyright 2011 Ian Tipton. All rights reserved.
//  MIT licensed
//

#import <Foundation/Foundation.h>
@import CoreText;


#import <Cordova/CDVPlugin.h>


@interface PrintPlugin : CDVPlugin <UIPrintInteractionControllerDelegate>{
	NSString* successCallback;
	NSString* failCallback;
	NSString* printHTML;

    //Options
	NSInteger dialogLeftPos;
	NSInteger dialogTopPos;

    UISimpleTextPrintFormatter *_textFormatter;
}

@property (nonatomic, copy) NSString* successCallback;
@property (nonatomic, copy) NSString* failCallback;
@property (nonatomic, copy) NSString* printText;

//Print Settings
@property NSInteger dialogLeftPos;
@property NSInteger dialogTopPos;

- (void)isPrintingAvailable: (CDVInvokedUrlCommand*)command;
- (void)print:(CDVInvokedUrlCommand*)command;

@end
