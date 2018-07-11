//
//  WebSocket.h
//  WebSocket
//
//  Created by jefferson on 2018/7/9.
//  Copyright © 2018年 jefferson. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface WebSocket : NSObject


+(WebSocket *)shareWebSocketManage;
/**
 * 连接webscoket
 */
- (void)connectWebServiceWithURL:(NSString *)url;

/**
 * 重连
 */
- (void)reConnect;

/**
 * 断开
 */
-(void)SocketClose;

/**
 * 发送信息(socket接口请求，发送的内容跟后台协商)
 */
- (void)sendMessage:(NSDictionary *)message
        chartPeriod:(NSInteger)chartPeriod
        description:(NSString *)description;

@end
