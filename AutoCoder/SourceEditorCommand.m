//
//  SourceEditorCommand.m
//  createGetter
//
//  Created by 陈越东 on 2018/1/25.
//  Copyright © 2018年 microfastup. All rights reserved.
//

#import "SourceEditorCommand.h"
#import <Cocoa/Cocoa.h>

@interface SourceEditorCommand ()

@property (nonatomic, assign) NSInteger predicate;
@property (nonatomic, strong) NSMutableArray *indexsArray;

@property (nonatomic, strong) NSMutableArray *cellsArray;
@property (nonatomic, strong) NSMutableArray *headersArray;
@property (nonatomic, strong) NSMutableArray *footersArray;

@property (nonatomic, assign) BOOL isVc;

@end

@implementation SourceEditorCommand

- (void)performCommandWithInvocation:(XCSourceEditorCommandInvocation *)invocation completionHandler:(void (^)(NSError * _Nullable nilOrError))completionHandler
{
    self.predicate = NO;
    NSArray *stringArray = [NSArray arrayWithArray:invocation.buffer.lines];
    
    for (int i = 0; i < stringArray.count; i++) {
        
        if (!self.predicate) {
            [self predicateForImports:stringArray[i]];
            [self beginPredicate:stringArray[i]];
        } else {
            if ([self endPredicate:stringArray[i]]) {
                NSMutableArray *resultArray = [self makeResultStringArray];
                
                for (int i = (int)invocation.buffer.lines.count - 1; i > 0 ; i--) {
                    
                    NSString *stringend = stringArray[i];
                    
                    if ([stringend containsString:@"@end"]) {
                        
                        for (int j = (int)resultArray.count - 1; j >= 0; j--) {
                            NSArray *array = resultArray[j];
                            for (int x = (int)(array.count - 1); x >= 0; x--) {
                                [invocation.buffer.lines insertObject:array[x] atIndex:i - 1];
                            }
                        }

                    } else if ([stringend hasPrefix:@"class"]) {
                        if (completionHandler) {
                            completionHandler(nil);
                        }
                        return;
                    }
                }
                
                if (completionHandler) {
                    completionHandler(nil);
                }
                return;
                
            } else {
                //没有匹配到 end  需要匹配property
                [self predicateForProperty:stringArray[i]];
                
            }
        }
    }
    completionHandler(nil);
}

#pragma mark -- Analyse Codes

- (void)predicateForImports:(NSString *)string
{
    if ([string containsString:@"import"]) {

        if ([string containsString:@"Cell"]) {
            NSString *cellName = [string substringWithRange:NSMakeRange(7, string.length - 7)];
            [self.cellsArray addObject:[cellName stringByReplacingOccurrencesOfString:@"\n" withString:@""]];
        } else if ([string containsString:@"Header"]) {
            NSString *headerName = [string substringWithRange:NSMakeRange(7, string.length - 7)];
            [self.headersArray addObject:[headerName stringByReplacingOccurrencesOfString:@"\n" withString:@""]];
        } else if ([string containsString:@"Footer"]) {
            NSString *footerName = [string substringWithRange:NSMakeRange(7, string.length - 7)];
            [self.footersArray addObject:[footerName stringByReplacingOccurrencesOfString:@"\n" withString:@""]];
        }

    }
}

- (void)predicateForProperty:(NSString *)string
{
    if ([string hasPrefix:@"@property"]) {
        NSArray *stringArray = [string componentsSeparatedByString:@":"];
        NSString *category = stringArray[2];
        category = [category stringByReplacingOccurrencesOfString:@"\n" withString:@""];
        NSDictionary *dic = @{@"category" : category, @"name" : stringArray[1]};
        [self.indexsArray addObject:dic];
    }
}


- (void)beginPredicate:(NSString *)string
{
    NSString *str = string;
    if ([str containsString:@"@start"]) {
        self.predicate = YES;
    }
}

- (BOOL)endPredicate:(NSString *)string
{
    if ([string hasPrefix:@"class"]) {
        self.predicate = NO;
        
        // 简单判断是 vc 还是 view
        if ([string containsString:@"ViewController"]) {
            self.isVc = YES;
        } else {
            self.isVc = NO;
        }
        
        return YES;
    }
    return NO;
}


#pragma mark -- Add Codes

- (NSMutableArray *)makeResultStringArray
{
    NSMutableArray *itemsArray = [[NSMutableArray alloc] init];
    
    if (!self.isVc) {
        [itemsArray addObjectsFromArray:[self makeInitStringArray]];
    }
    [itemsArray addObjectsFromArray:[self makeConfigStringArray]];
    [itemsArray addObjectsFromArray:[self makeActionsStringArray]];
    [itemsArray addObjectsFromArray:[self makeGettersStringArray]];
    
    return itemsArray;
}

// 自动打上 init 代码
- (NSMutableArray *)makeInitStringArray
{
    NSMutableArray *itemsArray = [[NSMutableArray alloc] init];
    
    NSString *line0 = [NSString stringWithFormat:@""];
    NSString *line1 = [NSString stringWithFormat:@"    override init(frame: CGRect) {"];
    NSString *line2 = [NSString stringWithFormat:@"        super.init(frame: frame)"];
    NSString *line3 = [NSString stringWithFormat:@"        self.configSubViews()"];
    NSString *line4 = [NSString stringWithFormat:@"    }"];
    NSString *line5 = [NSString stringWithFormat:@"    required init?(coder: NSCoder) {"];
    NSString *line6 = [NSString stringWithFormat:@"        fatalError(\"init(coder:) has not been implemented\")"];
    NSString *line7 = [NSString stringWithFormat:@"    }"];
    
    NSMutableArray *lineArrays = [[NSMutableArray alloc] initWithObjects:line0, line1, line2, line3, line4, line5, line6, line7, nil];
    
    [itemsArray addObject:lineArrays];
    
    return itemsArray;
}

// 自动打上 configSubViews 代码
- (NSMutableArray *)makeConfigStringArray
{
    NSMutableArray *itemsArray = [[NSMutableArray alloc] init];
    
    NSString *line0 = [NSString stringWithFormat:@""];
    NSString *line1 = [NSString stringWithFormat:@"    func configSubViews() {"];
    NSMutableArray *lineArrays0 = [[NSMutableArray alloc] initWithObjects:line0, line1, nil];
    [itemsArray addObject:lineArrays0];
    
    for (int i = 0; i < self.indexsArray.count; i++) {
        
        NSString *nameStr = self.indexsArray[i][@"name"];
        
        NSString *line0 = nil;
        if (self.isVc) {
            line0 = [NSString stringWithFormat:@"        self.view.addSubview(self.%@)", nameStr];
        } else {
            line0 = [NSString stringWithFormat:@"        self.addSubview(self.%@)", nameStr];
        }
        
        NSMutableArray *lineArrays = [[NSMutableArray alloc] initWithObjects:line0, nil];
        [itemsArray addObject:lineArrays];
    }
    
    for (int i = 0; i < self.indexsArray.count; i++) {
        
        NSString *nameStr = self.indexsArray[i][@"name"];
        
        NSString *line0 = [NSString stringWithFormat:@"        self.%@.snp.makeConstraints { (make) in", nameStr];
        NSString *line1 = [NSString stringWithFormat:@""];
        NSString *line2 = [NSString stringWithFormat:@"        }"];
        
        NSMutableArray *lineArrays = [[NSMutableArray alloc] initWithObjects:line0, line1, line2, nil];
        [itemsArray addObject:lineArrays];
    }
    
    NSString *line3 = [NSString stringWithFormat:@"    }"];
    NSMutableArray *lineArrays1 = [[NSMutableArray alloc] initWithObjects:line3, nil];
    [itemsArray addObject:lineArrays1];
    
    return itemsArray;
}

// 自动打上 actions 代码

- (NSMutableArray *)makeActionsStringArray
{
    NSMutableArray *itemsArray = [[NSMutableArray alloc] init];
    
    BOOL hasAddPragma = NO;
    
    for (int i = 0; i < self.indexsArray.count; i++) {
        
        NSString *categoryStr = self.indexsArray[i][@"category"];
        NSString *nameStr = self.indexsArray[i][@"name"];
        
        if ([categoryStr isEqualToString:[NSString stringWithFormat:@"UIButton"]]) {
            
            //添加方法
            NSString *actionf2 = [NSString stringWithFormat:@""];
            NSString *actionf1 = [NSString stringWithFormat:@"    //MARK: Actions"];
            NSString *action0 = [NSString stringWithFormat:@""];
            NSString *action1 = [NSString stringWithFormat:@"    @objc func %@Action() {", nameStr];
            NSString *action2 = [NSString stringWithFormat:@"    }"];
            
            if (hasAddPragma) {
                NSMutableArray *actionArrays = [[NSMutableArray alloc] initWithObjects:action0, action1, action2, nil];
                [itemsArray insertObject:actionArrays atIndex:1];
            } else {
                hasAddPragma = YES;
                NSMutableArray *actionArrays = [[NSMutableArray alloc] initWithObjects:actionf2, actionf1, action0, action1, action2, nil];
                [itemsArray insertObject:actionArrays atIndex:0];
            }
            
        }
    }
    return itemsArray;
}

// 自动打上 getters 代码
- (NSMutableArray *)makeGettersStringArray
{
    NSMutableArray *itemsArray = [[NSMutableArray alloc] init];
    
    NSString *line0 = [NSString stringWithFormat:@""];
    NSString *line1 = [NSString stringWithFormat:@"    //MARK: Lazy"];
    NSMutableArray *lineArrays = [[NSMutableArray alloc] initWithObjects:line0, line1, nil];
    [itemsArray addObject:lineArrays];
    
    BOOL hasAddCollectionViewPragma = NO;
    
    for (int i = 0; i < self.indexsArray.count; i++) {
        
        NSString *categoryStr = self.indexsArray[i][@"category"];
        NSString *nameStr = self.indexsArray[i][@"name"];
        
        if ([categoryStr isEqualToString:[NSString stringWithFormat:@"UILabel"]]) {
            NSString *line0 = @"";
            NSString *line1 = [NSString stringWithFormat:@"    lazy var %@: %@ = {", nameStr, categoryStr];
            NSString *line2 = @"        let label = UILabel()";
            NSString *line3 = @"        label.font = UIFont.systemFont(ofSize: 18)";
            NSString *line4 = @"        label.textColor = .white";
            NSString *line5 = @"        return label";
            NSString *line6 = @"    }()";
            
            NSMutableArray *lineArrays = [[NSMutableArray alloc] initWithObjects:line0, line1, line2, line3, line4, line5, line6, nil];
            [itemsArray addObject:lineArrays];
        } else if ([categoryStr isEqualToString:[NSString stringWithFormat:@"UIButton"]]) {
            NSString *line0 = @"";
            NSString *line1 = [NSString stringWithFormat:@"    lazy var %@ : %@ = {", nameStr, categoryStr];
            NSString *line2 = @"        let button = UIButton()";
            NSString *line3 = @"        button.titleLabel?.font = UIFont.systemFont(ofSize: 18)";
            NSString *line4 = @"        button.setTitle(\"\", for: .normal)";
            NSString *line5 = @"        button.setTitleColor(.white, for: .normal)";
            NSString *line6 = @"        button.setImage(UIImage(), for: .normal)";
            NSString *line7 = [NSString stringWithFormat:@"        button.addTarget(self, action: #selector(%@Action), for: .touchUpInside)", nameStr];
            NSString *line8 = @"        return button";
            NSString *line9 = @"    }()";
            
            NSMutableArray *lineArrays = [[NSMutableArray alloc] initWithObjects:line0, line1, line2, line3, line4, line5, line6, line7, line8, line9, nil];
            [itemsArray addObject:lineArrays];
            
        } else if ([categoryStr isEqualToString:[NSString stringWithFormat:@"UICollectionView"]]) {
            NSString *line0 = [NSString stringWithFormat:@""];
            NSString *line1 = [NSString stringWithFormat:@"    lazy var %@ : %@ = {", nameStr, categoryStr];
            NSString *line2 = [NSString stringWithFormat:@"        let layout = UICollectionViewFlowLayout()"];
            NSString *line3 = [NSString stringWithFormat:@"        layout.itemSize = CGSize(width: 0, height: 0)"];
            NSString *line6 = [NSString stringWithFormat:@"        layout.minimumLineSpacing = 0"];
            NSString *line7 = [NSString stringWithFormat:@"        layout.minimumInteritemSpacing = 0"];
            NSString *line8 = [NSString stringWithFormat:@"        layout.sectionInset = UIEdgeInsets.zero"];
            NSString *line9 = [NSString stringWithFormat:@"        layout.scrollDirection = .horizontal"];
            NSString *line10 = [NSString stringWithFormat:@""];
            NSString *line11 = [NSString stringWithFormat:@"        let collectionView = UICollectionView.init(frame: CGRect.zero, collectionViewLayout: layout)"];
            NSString *line12 = [NSString stringWithFormat:@"        collectionView.dataSource = self"];
            NSString *line13 = [NSString stringWithFormat:@"        collectionView.dataSource = self"];
            NSString *line14 = [NSString stringWithFormat:@"        collectionView.backgroundColor = UIColor.clear"];
            NSMutableArray *line15Array = [NSMutableArray array];
            for (NSString *cellName in self.cellsArray) {
                NSString *line15 = [NSString stringWithFormat:@"        collectionView.register(%@.self, forCellWithReuseIdentifier: %@.reuseIdentifier())", cellName, cellName];
                [line15Array addObject:line15];
            }
            for (NSString *headerName in self.headersArray) {
                NSString *line15 = [NSString stringWithFormat:@"        collectionView.register(%@.self, forSupplementaryViewOfKind: .elementKindSectionHeader, withReuseIdentifier: %@.reuseIdentifier())", headerName, headerName];
                [line15Array addObject:line15];
            }
            for (NSString *footerName in self.footersArray) {
                NSString *line15 = [NSString stringWithFormat:@"        collectionView.register(%@.self, forSupplementaryViewOfKind: .elementKindSectionFooter, withReuseIdentifier: %@.reuseIdentifier())", footerName, footerName];
                [line15Array addObject:line15];
            }
            
            NSString *line16 = [NSString stringWithFormat:@""];
            NSString *line17 = [NSString stringWithFormat:@"        return collectionView"];
            NSString *line18 = [NSString stringWithFormat:@"    }()"];
            
            NSMutableArray *lineArrays = [[NSMutableArray alloc] initWithObjects:line0, line1, line2, line3, line6, line7, line8, line9, line10, line11, line12, line13, line14, nil];
            [lineArrays addObjectsFromArray:line15Array];
            [lineArrays addObjectsFromArray:@[line16, line17, line18]];
            [itemsArray addObject:lineArrays];
            
            //添加datasource，delegate方法
            if (hasAddCollectionViewPragma) {
                continue;
            }
            hasAddCollectionViewPragma = YES;
            
            //添加方法
            NSString *action0 = [NSString stringWithFormat:@""];
            NSString *action1 = [NSString stringWithFormat:@"    //MARK: UICollectionView"];
            NSString *action1to2 = [NSString stringWithFormat:@""];
            NSString *action2 = [NSString stringWithFormat:@"    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {"];
            NSString *action3 = [NSString stringWithFormat:@"        return 0"];
            NSString *action4 = [NSString stringWithFormat:@"    }"];
            NSString *action5 = [NSString stringWithFormat:@""];
            NSString *action6 = [NSString stringWithFormat:@"    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {"];
            NSString *action7 = [NSString stringWithFormat:@""];
            
            NSString *cellName = @"";
            if (self.cellsArray.count) {
                cellName = self.cellsArray.firstObject;
            }
            NSString *action9 = [NSString stringWithFormat:@"        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: %@.reuseIdentifier(), for: indexPath) as! %@", cellName, cellName];
            
            NSString *action10 = [NSString stringWithFormat:@"        return cell"];
            NSString *action11 = [NSString stringWithFormat:@"    }"];
            NSString *action12 = [NSString stringWithFormat:@""];
            NSString *action13 = [NSString stringWithFormat:@"    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {"];
            NSString *action14 = [NSString stringWithFormat:@""];
            NSString *action15 = [NSString stringWithFormat:@"    }"];
            
            NSMutableArray *actionArrays = [[NSMutableArray alloc] initWithObjects:action0, action1, action1to2, action2, action3, action4, action5, action6, action7, action9, action10, action11, action12, action13, action14, action15, nil];
            [itemsArray insertObject:actionArrays atIndex:0];
            
        } else {
            NSString *line0 = [NSString stringWithFormat:@""];
            NSString *line1 = [NSString stringWithFormat:@"    lazy var %@ : %@ = {", nameStr, categoryStr];
            NSString *line2 = [NSString stringWithFormat:@"        let %@ = UIView()", nameStr];
            NSString *line3 = [NSString stringWithFormat:@"        return %@", nameStr];
            NSString *line4 = [NSString stringWithFormat:@"    }()"];
            
            NSMutableArray *lineArrays = [[NSMutableArray alloc] initWithObjects:line0, line1, line2, line3, line4, nil];
            [itemsArray addObject:lineArrays];
        }
    }
    return itemsArray;
}

#pragma mark -- Getters

- (NSMutableArray *)indexsArray
{
    if (!_indexsArray) {
        _indexsArray = [[NSMutableArray alloc] init];
    }
    return _indexsArray;
}

- (NSMutableArray *)cellsArray
{
    if (!_cellsArray) {
        _cellsArray = [NSMutableArray array];
    }
    return _cellsArray;
}

- (NSMutableArray *)headersArray
{
    if (!_headersArray) {
        _headersArray = [NSMutableArray array];
    }
    return _headersArray;
}

- (NSMutableArray *)footersArray
{
    if (!_footersArray) {
        _footersArray = [NSMutableArray array];
    }
    return _footersArray;
}

@end
