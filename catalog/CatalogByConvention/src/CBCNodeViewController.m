/*
 Copyright 2016-present Google Inc. All Rights Reserved.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import "CBCNodeViewController.h"

#import "CBCCatalogExample.h"
#import "CBCRuntime.h"

@implementation CBCNode {
  NSMutableDictionary *_map;
  NSMutableArray *_children;
  Class _exampleClass;
}

- (instancetype)initWithTitle:(NSString *)title {
  self = [super init];
  if (self) {
    _title = [title copy];
    _map = [NSMutableDictionary dictionary];
    _children = [NSMutableArray array];
  }
  return self;
}

- (instancetype)init {
  [self doesNotRecognizeSelector:_cmd];
  return nil;
}

- (NSComparisonResult)compare:(CBCNode *)otherObject {
  return [self.title compare:otherObject.title];
}

- (void)addChild:(CBCNode *)child {
  _map[child.title] = child;
  [_children addObject:child];
}

- (NSDictionary *)map {
  return _map;
}

- (void)setExampleClass:(Class)exampleClass {
  _exampleClass = exampleClass;
}

- (void)finalize {
  _children = [[_children sortedArrayUsingSelector:@selector(compare:)] mutableCopy];
}

#pragma mark Public

- (BOOL)isExample {
  return _exampleClass != nil;
}

- (UIViewController *)createExampleViewController {
  NSAssert(_exampleClass != nil, @"This node has no associated example.");
  return CBCViewControllerFromClass(_exampleClass);
}

- (NSString *)createExampleDescription {
  NSAssert(_exampleClass != nil, @"This node has no associated example.");
  return CBCDescriptionFromClass(_exampleClass);
}

@end

@implementation CBCNodeListViewController

- (instancetype)initWithNode:(CBCNode *)node {
  NSAssert(!_node.isExample,
           @"%@ cannot represent example nodes.", NSStringFromClass([self class]));

  self = [super initWithStyle:UITableViewStyleGrouped];
  if (self) {
    _node = node;

    self.title = _node.title;
  }
  return self;
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
  [self doesNotRecognizeSelector:_cmd];
  return nil;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
  [self doesNotRecognizeSelector:_cmd];
  return nil;
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  return [_node.children count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
  if (!cell) {
    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                  reuseIdentifier:@"cell"];
  }
  cell.textLabel.text = [_node.children[indexPath.row] title];
  cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
  return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  CBCNode *node = _node.children[indexPath.row];
  UIViewController *viewController = nil;
  if ([node isExample]) {
    viewController = [node createExampleViewController];
  } else {
    viewController = [[[self class] alloc] initWithNode:node];
  }
  [self.navigationController pushViewController:viewController animated:YES];
}

@end

CBCNode *CBCCreateNavigationTree(void) {
  NSArray *allClasses = CBCGetAllClasses();
  NSArray *classes = CBCClassesRespondingToSelector(allClasses, @selector(catalogBreadcrumbs));

  CBCNode *tree = [[CBCNode alloc] initWithTitle:@"Root"];
  for (Class aClass in classes) {
    // Each example view controller defines its own "breadcrumbs".

    NSArray *breadCrumbs = CBCCatalogBreadcrumbsFromClass(aClass);

    // Walk down the navigation tree one breadcrumb at a time, creating nodes along the way.

    CBCNode *node = tree;
    for (NSInteger ix = 0; ix < [breadCrumbs count]; ++ix) {
      NSString *title = breadCrumbs[ix];
      BOOL isLastCrumb = ix == [breadCrumbs count] - 1;

      // Don't walk the last crumb

      if (node.map[title] && !isLastCrumb) {
        node = node.map[title];
        continue;
      }

      CBCNode *child = [[CBCNode alloc] initWithTitle:title];
      [node addChild:child];
      node = child;
    }

    node.exampleClass = aClass;
  }

  // Perform final post-processing on the nodes.
  NSMutableArray *queue = [NSMutableArray arrayWithObject:tree];
  while ([queue count] > 0) {
    CBCNode *node = [queue firstObject];
    [queue removeObjectAtIndex:0];
    [queue addObjectsFromArray:node.children];

    [node finalize];
  }

  return tree;
}
