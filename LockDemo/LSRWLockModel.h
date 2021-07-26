//
//  LSRWLockModel.h
//  LockDemo
//
//  Created by Marshal on 2021/7/26.
//  读写锁的另一种实现方式，通过phread和GCD barrier实现

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LSRWLockModel : NSObject

@property (nonatomic, strong) NSString *lock1;

@property (nonatomic, strong) NSString *lock2;

- (void)getLock2WithBlock:(void(^)(NSString *))block;

@end

NS_ASSUME_NONNULL_END
