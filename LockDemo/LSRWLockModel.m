//
//  LSRWLockModel.m
//  LockDemo
//
//  Created by Marshal on 2021/7/26.
//

#import "LSRWLockModel.h"
#import <pthread/pthread.h>

@interface LSRWLockModel ()
{
    //当同时重写set和geter方法时，则不会初始化字段
    NSString *_lock1;
    NSString *_lock2;
    NSString *_lock3;
    
    pthread_rwlock_t _lock;
    dispatch_queue_t _queue;
}

@end

@implementation LSRWLockModel

- (instancetype)init
{
    self = [super init];
    if (self) {
        //初始化读写锁资源
        [self setupPhreadRW];
        [self setupGCDRW];
    }
    return self;
}

//初始化pthread读写锁
- (void)setupPhreadRW {
    pthread_rwlock_init(&_lock, NULL);
    //使用完毕销毁读写锁
    //pthread_rwlock_destroy(&_lock);
}

- (void)setupGCDRW {
    _queue = dispatch_queue_create("RWLockQueue", DISPATCH_QUEUE_CONCURRENT);
}

#pragma mark --通过pthread读写锁来设置
- (void)setLock1:(NSString *)lock1 {
    pthread_rwlock_wrlock(&_lock);
    _lock1 = lock1;
    pthread_rwlock_unlock(&_lock);
    
}
- (NSString *)lock1 {
    NSString *lock1 = nil;
    pthread_rwlock_rdlock(&_lock);
    lock1 = [_lock1 copy];//copy到新的地址,避免解锁后拿到旧值
    pthread_rwlock_unlock(&_lock);
    return lock1;
}

#pragma mark --通过GCD的barrier栅栏功能实现
//通过GCD的barrier栅栏功能实现，缺点是需要借助自定义队列实现，且get方法无法重写系统的，只能以回调的方式获取值
//barrier功能使用global队列会失效，全局队列是无法阻塞的，里面有系统的一些任务执行
- (void)setLock2:(NSString *)lock2 {
    dispatch_barrier_async(_queue, ^{
        self->_lock2 = lock2;
    });
}
- (void)getLock2WithBlock:(void(^)(NSString *))block {
    dispatch_async(_queue, ^{
        block(self->_lock2);
    });
}


@end
