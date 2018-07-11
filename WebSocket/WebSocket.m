//
//  WebSocket.m
//  WebSocket
//
//  Created by jefferson on 2018/7/9.
//  Copyright © 2018年 jefferson. All rights reserved.
//

#import "WebSocket.h"
#import <SRWebSocket.h>

#define dispatch_main_async_safe(block)\
if ([NSThread isMainThread]) {\
block();\
} else {\
dispatch_async(dispatch_get_main_queue(), block);\
}

#define WS(weakSelf)  __weak __typeof(&*self)weakSelf = self;

@interface WebSocket()<SRWebSocketDelegate>

@property (nonatomic, retain) SRWebSocket *socket;
@property (nonatomic, assign) BOOL isErrorLink;  // 链接错误
@property (nonatomic, assign) BOOL isDisconnect; // 断开状态
@property (nonatomic, strong) NSDictionary *responseDict;

@property (nonatomic, assign) NSTimeInterval reConnectTime;;

/// 连接的URL
@property (nonatomic, copy)   NSString * _Nullable url;

/// 连接状态
@property (nonatomic, assign) BOOL isConnect;

@property (nonatomic, strong) NSTimer * heartBeat;

// 连接成功
@property (nonatomic, copy) void(^ _Nullable connected)(BOOL connectSuccess);

@end


@implementation WebSocket

static WebSocket * webSocket;

+(WebSocket *)shareWebSocketManage
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (webSocket == nil) {
            webSocket = [[self alloc] init];
        }
    });
    return webSocket;
}

+ (instancetype)allocWithZone:(struct _NSZone *)zone{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (webSocket == nil) {
            webSocket = [super allocWithZone:zone];
        }
    });
    return webSocket;
}

- (id)copy{
    return self;
}

- (id)mutableCopy{
    return self;
}

- (void)connectWebServiceWithURL:(NSString *)url
{
    if (self.socket) {
        return;
    }
    if (url.length == 0) {
        return;
    }
    self.url = url;
    // 重新连接websocket
    self.socket = [[SRWebSocket alloc] initWithURLRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:_url]]];
    self.socket.delegate = self;
    [self.socket open];
    
}


-(void)sentheart{
    //发送心跳 和后台可以约定发送什么内容  一般可以调用ping  我这里根据后台的要求 发送了data给他
    NSDictionary *dict = @{
                           @"t" : @14
                           };
    [self sendMessage:dict chartPeriod:0 description:@"WebSocket心跳包数据"];
}


#pragma mark ---------------------------------------------------发送数据
- (void)sendMessage:(NSDictionary *)message
        chartPeriod:(NSInteger)chartPeriod
        description:(NSString *)description {
    WS(weakSelf);
    dispatch_queue_t queue =  dispatch_queue_create("zy", NULL);
    
    dispatch_async(queue, ^{
        if (weakSelf.socket != nil) {
            // 只有 SR_OPEN 开启状态才能调 send 方法啊，不然要崩
            if (weakSelf.socket.readyState == SR_OPEN) {
                NSError *error;
                NSMutableDictionary *dic = [NSMutableDictionary dictionaryWithDictionary:message];
                
                
                NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dic options:NSJSONWritingPrettyPrinted error:&error];
                NSString *jsonString = [[NSString alloc]initWithData:jsonData encoding:NSUTF8StringEncoding];
                //                [_webSocket send:jsonString];
                [weakSelf.socket send:jsonString];    // 发送数据
                
            } else if (weakSelf.socket.readyState == SR_CONNECTING) {
                NSLog(@"正在连接中，重连后其他方法会去自动同步数据");
                // 每隔2秒检测一次 socket.readyState 状态，检测 10 次左右
                // 只要有一次状态是 SR_OPEN 的就调用 [ws.socket send:data] 发送数据
                // 如果 10 次都还是没连上的，那这个发送请求就丢失了，这种情况是服务器的问题了，小概率的
                // 代码有点长，我就写个逻辑在这里好了
                [self reConnect];
                
            } else if (weakSelf.socket.readyState == SR_CLOSING || weakSelf.socket.readyState == SR_CLOSED) {
                // websocket 断开了，调用 reConnect 方法重连
                
                NSLog(@"重连");
                
                [self reConnect];
            }
        } else {
            NSLog(@"没网络，发送失败，一旦断网 socket 会被我设置 nil 的");
            NSLog(@"其实最好是发送前判断一下网络状态比较好，我写的有点晦涩，socket==nil来表示断网");
        }
    });
}



//初始化心跳
- (void)initHeartBeat
{
    dispatch_main_async_safe(^{
        [self destoryHeartBeat];
        //心跳设置为3分钟，NAT超时一般为5分钟
        _heartBeat = [NSTimer timerWithTimeInterval:3 target:self selector:@selector(sentheart) userInfo:nil repeats:YES];
        //和服务端约定好发送什么作为心跳标识，尽可能的减小心跳包大小
        [[NSRunLoop currentRunLoop] addTimer:_heartBeat forMode:NSRunLoopCommonModes];
    })
}

//取消心跳
- (void)destoryHeartBeat
{
    dispatch_main_async_safe(^{
        if (_heartBeat) {
            if ([_heartBeat respondsToSelector:@selector(isValid)]){
                if ([_heartBeat isValid]){
                    [_heartBeat invalidate];
                    _heartBeat = nil;
                }
            }
        }
    })
}

//pingPong
- (void)ping{
    if (self.socket.readyState == SR_OPEN) {
        [self.socket sendPing:nil];
    }
}

#pragma mark ---------------------------------------------------重连webSocket
- (void)reConnect
{
    [self SocketClose];
    
    //超过一分钟就不再重连 所以只会重连5次 2^5 = 64
    if (self.reConnectTime > 64) {
        //您的网络状况不是很好，请检查网络后重试
        return;
    }
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.reConnectTime * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.socket = nil;
        [self connectWebServiceWithURL:self.url];
        NSLog(@"重连");
    });
    
    //重连时间2的指数级增长
    if (self.reConnectTime == 0) {
        self.reConnectTime = 2;
    }else{
        self.reConnectTime *= 2;
    }
}

#pragma mark ---------------------------------------------------切断webSocket
-(void)SocketClose{
    if (self.socket){
        [self.socket close];
        self.socket = nil;
        //断开连接时销毁心跳
        [self destoryHeartBeat];
    }
}

#pragma mark ---------------------------------------------------SRWebSocketDelegate


#pragma mark ---------------------------------------------------socket 连接成功
- (void)webSocketDidOpen:(SRWebSocket *)webSocket
{
    //每次正常连接的时候清零重连时间
    self.reConnectTime = 0;
    //开启心跳
    [self initHeartBeat];
    if (webSocket == self.socket) {
        NSLog(@"************************** socket 连接成功************************** ");
    }
}

#pragma mark ---------------------------------------------------socket 连接失败
- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error
{
    if (webSocket == self.socket) {
        NSLog(@"************************** socket 连接失败************************** ");
        self.socket = nil;
        //连接失败就重连
        [self reConnect];
    }
}

#pragma mark ---------------------------------------------------socket连接断开
- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean
{
    if (webSocket == self.socket) {
        NSLog(@"************************** socket连接断开************************** ");
        NSLog(@"断开连接，code:%ld,reason:%@,wasClean:%d",(long)code,reason,wasClean);
        [self SocketClose];
    }
   
}

#pragma mark ---------------------------------------------------该函数是接收服务器发送的pong消息，其中最后一个是接受pong消息的，在这里就要提一下心跳包，一般情况下建立长连接都会建立一个心跳包，用于每隔一段时间通知一次服务端，客户端还是在线，这个心跳包其实就是一个ping消息，我的理解就是建立一个定时器，每隔十秒或者十五秒向服务端发送一个ping消息，这个消息可是是空的
-(void)webSocket:(SRWebSocket *)webSocket didReceivePong:(NSData *)pongPayload{
    NSString *reply = [[NSString alloc] initWithData:pongPayload encoding:NSUTF8StringEncoding];
    NSLog(@"reply===%@",reply);
}

#pragma mark ---------------------------------------------------返回信息
- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message
{
    if (webSocket == self.socket) {
        
        self.responseDict = [WebSocket dictionaryWithJsonString:message];
        
        NSNumber *result = self.responseDict[@"r"];
        if ([result integerValue] == 0) {
            if ([self.responseDict[@"t"] integerValue] == 0) {
                self.responseDict = [WebSocket type0WithDictionary:self.responseDict];
            }
            NSLog(@"message:%@",self.responseDict);
        }
    }
}

- (SRReadyState)socketReadyState{
    return self.socket.readyState;
}

+ (NSDictionary *)dictionaryWithJsonString:(NSString *)jsonString {
    if (!jsonString) {
        return nil;
    }
    
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSError *err;
    NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:jsonData
                                                        options:NSJSONReadingAllowFragments
                                                          error:&err];
    if (err) {
        //        NSLog(@"json解析失败：%@",err);
        return nil;
    }
    return dic;
}

+(NSDictionary *)type0WithDictionary:(NSDictionary *)dic
{
    NSMutableArray *array = [NSMutableArray new];
    for (NSDictionary *dicc in dic[@"d"]) {
        NSData *data = [[NSData alloc] initWithBase64EncodedString:dicc[@"q"] options:0];
        uint8_t *buf = (uint8_t*)[data bytes];
        NSData *dd = [[NSData alloc]initWithBytes:buf length:12];
        NSString *symbl = [[NSString alloc] initWithData:dd encoding:NSUTF8StringEncoding];
        NSString *sys = [symbl stringByReplacingOccurrencesOfString:@"\0" withString:@""];
        NSData *dddd = [[NSData alloc]initWithBytes:buf+12 length:4];
        float bid =  *(float *)([dddd bytes]);
        NSData *sddd = [[NSData alloc]initWithBytes:buf+16 length:4];
        float ask =  *(float *)([sddd bytes]);
        NSData *ddtime = [[NSData alloc]initWithBytes:buf+20 length:4];
        long time =  *(long *)([ddtime bytes]);
        
        NSDate *date = [NSDate dateWithTimeIntervalSince1970:time];
        NSDateFormatter *format = [[NSDateFormatter alloc] init];
        [format setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
        //        if (WX_SeverPortApi) {
        format.timeZone = [NSTimeZone timeZoneWithName:@"GMT"];
        //        }
        
        NSString *currentDateString = [format stringFromDate:date];
        
        NSDictionary *dic = @{@"Symbol":sys,
                              @"Ask":[NSString stringWithFormat:@"%f",ask],
                              @"Bid":[NSString stringWithFormat:@"%f",bid],
                              @"TickTime":[currentDateString stringByReplacingOccurrencesOfString:@" " withString:@"T"]
                              };
        [array addObject:dic];
    }
    if (dic[@"r"]) {
        return @{
                 @"Result":dic[@"r"],
                 @"Type":@0,
                 @"Data":array
                 };
    }else{
        return @{
                 @"Type":@0,
                 @"Data":array
                 };
    }
    
}

-(void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
