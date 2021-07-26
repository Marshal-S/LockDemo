//
//  ViewController.m
//  LockDemo
//
//  Created by Marshal on 2021/7/23.
//  常用的几种锁

#import "ViewController.h"
#import <pthread/pthread.h>

@interface ViewController ()
{
    dispatch_semaphore_t _semaphore; //信号量
    pthread_mutex_t _pMutexLock; //互斥锁、递归锁
    NSLock *_lock; //锁
    NSCondition *_condition; //情景锁
    NSConditionLock *_conditionLock;//条件锁
    NSRecursiveLock *_recursive; //递归锁
}

@property (nonatomic, assign) double money; //可用于读写锁的使用

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self semaphore];
    [self pthreadMutex];
    [self NSLock];
    [self NSCondition];
    [self NSConditionLock];
    [self pthreadMutexRecursive];
    [self NSRecursiveLock];
    [self synchronized];
    
    [self NSConditionLockUpdate];
}

#pragma mark --semaphore信号量
- (void)semaphore {
    _semaphore = dispatch_semaphore_create(1);
}

//wait操作可以使得信号量值减少1，signal使得信号量值增加1
//当信号量值小于0时，则所在线程阻塞休眠，使用signal使得信号量增加时，会顺序唤醒阻塞线程
- (void)semaphoreUpdate {
    //wait 可以理解为加锁操作，信号值小于0会休眠当前wait所在线程
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    _money++;
    //signal 可以解锁
    dispatch_semaphore_signal(_semaphore);
}

#pragma mark --pthread互斥锁
- (void)pthreadMutex {
    pthread_mutex_init(&_pMutexLock, NULL);
    //使用完毕后在合适的地方销毁，例如dealloc
//    pthread_mutex_destroy(&_pMutexLock);
}

- (void)pthreadMutexUpdate {
    //加锁代码区间操作，避免多线程同时访问
    pthread_mutex_lock(&_pMutexLock);
    _money++;
    //解锁代码区间操作
    pthread_mutex_unlock(&_pMutexLock);
}

- (void)pthreadMutexSub {
    //减少数值
    [NSThread detachNewThreadWithBlock:^{
        //数量大于100开始减少，假设是需要清理东西，这里减少数值
        while (self->_money > 10000) {
            //尝试加锁，如果能加锁，则加锁，返回零，否则返回不为零的数字,加锁失败休眠在执行，避免抢夺资源，此任务优先级间接降低
            //其他的一些锁也有这功能,例如NSLock、NSRecursiveLock、NSConditionLock
            if (pthread_mutex_trylock(&self->_pMutexLock) == 0) {
                self->_money--;
                //解锁
                pthread_mutex_unlock(&self->_pMutexLock);
            }else {
                [NSThread sleepForTimeInterval:1];
            }
        }
    }];
}

#pragma mark --NSLock互斥锁
- (void)NSLock {
    _lock = [[NSLock alloc] init];
}

- (void)NSLockUpdate {
    //加锁代码区间，避免多线程同时访问
    [_lock lock];
    _money++;
    //解锁代码区间
    [_lock unlock];
}

#pragma mark --情景锁NSCondition实现了NSLocking协议，支持默认的互斥锁lock、unlock
- (void)NSCondition {
    _condition = [[NSCondition alloc] init];
}

//情景锁还加入了信号量机制,wait和signal，可以利用其完成生产消费者模式的功能
//生产者: 妈爸挣了一天的钱，储蓄值增加
- (void)conditionPlusMoney {
    [_condition lock];
    //信号量增加，有储蓄了，可以开放花钱功能了
    if (_money++ < 0) {
        [_condition signal];
    }
    [_condition unlock];
}
//消费者，服务有储蓄，拿到钱时立即解锁花钱技能(money--)
- (void)conditionSubMoney {
    [_condition lock];
    if (_money == 0) {
        //信号量减少阻塞，打算买东西，却没钱了，停止花钱，等发工资再买东西
        [_condition wait];
    }
    //由于之前的wait，当signal解锁后，会走到这里，开始购买想买的东西，储蓄值--
    _money--;
    [_condition unlock];
}

#pragma mark --条件锁NSConditionLock,实现了NSLocking协议，支持默认的互斥锁lock、unlock
- (void)NSConditionLock {
    _conditionLock = [[NSConditionLock alloc] initWithCondition:1]; //可以更改值测试为0测试结果
    //加锁，当条件condition为传入的condition时，方能解锁
    //lockWhenCondition:(NSInteger)condition
    //更新condition的值，并解锁指定condition的锁
    //unlockWithCondition:(NSInteger)condition
}

//多个队列执行条件锁
//通过案例可以看出，通过条件锁conditionLock可以设置线程依赖关系
//可以通过GCD设置一个具有依赖关系的任务队列么
- (void)NSConditionLockUpdate {
    //创建并发队列
    dispatch_queue_t queue = dispatch_queue_create("测试NSConditionLock", DISPATCH_QUEUE_CONCURRENT);
    dispatch_async(queue, ^{
        if ([self->_conditionLock tryLockWhenCondition:1]) {
            NSLog(@"第一个");
            //默认初始conditon位1，所有能走到这里
            //然后解锁后，并设置初始值为4，解锁condition设定为4的线程
            [self->_conditionLock unlockWithCondition:4];
        }else {
            [self->_conditionLock lockWhenCondition:0];
            NSLog(@"第一个other");
            [self->_conditionLock unlockWithCondition:4];
        }
    });
    //由于开始初始化的conditon值为1，所以后面三个线程都不满足条件
    //锁定后直到condition调整为当前线程的condition时方解锁
    dispatch_async(queue, ^{
        //condition设置为3后解锁当前线程
        [self->_conditionLock lockWhenCondition:2];
        NSLog(@"第二个");
        //执行完毕后解锁，并设置condition为1，设置初始化默认值，以便于下次使用
        [self->_conditionLock unlockWithCondition:1];
    });
    dispatch_async(queue, ^{
        //condition设置为3后解锁当前线程
        [self->_conditionLock lockWhenCondition:3];
        NSLog(@"第三个");
        //执行完毕后解锁，并设置condition为3，解锁3
        [self->_conditionLock unlockWithCondition:2];
    });
    dispatch_async(queue, ^{
        //condition设置为4后解锁当前线程
        [self->_conditionLock lockWhenCondition:4];
        NSLog(@"第四个");
        //执行完毕后解锁，并设置condition为3，解锁3
        [self->_conditionLock unlockWithCondition:3];
    });
}

#pragma mark --pthread递归锁
- (void)pthreadMutexRecursive {
    //初始化锁的递归功能
    pthread_mutexattr_t attr;
    pthread_mutexattr_init(&attr);
    pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE);
    //互斥锁初始化时，绑定递归锁功能模块
    pthread_mutex_init(&_pMutexLock, &attr);
    
    //使用完毕后在合适的地方销毁，例如dealloc
//    pthread_mutexattr_destroy(&attr);
//    pthread_mutex_destroy(&_pMutexLock);
}

//使用递归锁，递归地时候回不停加锁，如果使用普通的锁早已经形成死锁，无法解脱
//递归锁的存在就是在同一个线程中的锁，不会互斥，只会互斥其他线程的锁，从而避免死锁
- (void)pthreadMutexRecursiveUpdate {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        static void (^recursiveBlock)(double count);
        recursiveBlock = ^(double count){
            pthread_mutex_lock(&self->_pMutexLock);
            if (count-- > 0) {
                self->_money++;
                recursiveBlock(count);
            }
            pthread_mutex_unlock(&self->_pMutexLock);
        };
        recursiveBlock(1000);
    });
}

#pragma mark --递归锁NSRecursiveLock，实现了NSLocking协议，支持默认的互斥锁lock、unlock
- (void)NSRecursiveLock {
    _recursive = [[NSRecursiveLock alloc] init];
}

//使用递归锁，递归地时候回不停加锁，如果使用普通的锁早已经形成死锁，无法解脱
//递归锁的存在就是在同一个线程中的锁，不会互斥，只会互斥其他线程的锁，从而避免死锁
- (void)NSRecursiveLockUpdate {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        static void (^recursiveBlock)(double count);
        recursiveBlock = ^(double count){
            [self->_recursive lock];
            //tryLock就不多介绍了，和Pthread的类似，注意返回值即可
            //[self->_recursive tryLock];
            if (count-- > 0) {
                self->_money++;
                recursiveBlock(count);
            }
            [self->_recursive unlock];
        };
        recursiveBlock(1000);
    });
}

#pragma mark --同步锁synchronized
- (void)synchronized {
    //使用简单，直接对代码块加同步锁，此代码不会被多个线程直接执行
    //可以间接理解为里面的任务被放到了一个同步队列依次执行（实际实现未知）
    @synchronized (self) {
        self->_money++;
    }
}


@end
