//
//  ViewController.m
//  WebSocket
//
//  Created by jefferson on 2018/7/9.
//  Copyright © 2018年 jefferson. All rights reserved.
//

#import "ViewController.h"
#import "WebSocket.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    


    [[WebSocket shareWebSocketManage] connectWebServiceWithURL:@""];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
