/*
 * This file is part of the Canvas package.
 * (c) James Tang <jamz@jamztang.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "CSStickyHeaderFlowLayout.h"

NSString *const CSStickyHeaderParallaxHeader = @"CSStickyHeaderParallexHeader";

@implementation CSStickyHeaderFlowLayout

- (void)prepareLayout {
    [super prepareLayout];
}

- (NSArray *)layoutAttributesForElementsInRect:(CGRect)rect
{
    // The rect should compensate the header size
    CGRect adjustedRect = rect;
    adjustedRect.origin.y -= self.parallaxHeaderReferenceSize.height;

    NSMutableArray *allItems = [[super layoutAttributesForElementsInRect:adjustedRect] mutableCopy];

    NSMutableDictionary *headers = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *lastCells = [[NSMutableDictionary alloc] init];
    __block BOOL visibleParallexHeader;

    [allItems enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        UICollectionViewLayoutAttributes *attributes = obj;

        CGRect frame = attributes.frame;
        frame.origin.y += self.parallaxHeaderReferenceSize.height;
        attributes.frame = frame;

        NSIndexPath *indexPath = [(UICollectionViewLayoutAttributes *)obj indexPath];
        if ([[obj representedElementKind] isEqualToString:UICollectionElementKindSectionHeader]) {
            [headers setObject:obj forKey:@(indexPath.section)];
        } else if ([[obj representedElementKind] isEqualToString:UICollectionElementKindSectionFooter]) {
            // Not implemeneted
        } else {
            NSIndexPath *indexPath = [(UICollectionViewLayoutAttributes *)obj indexPath];

            UICollectionViewLayoutAttributes *currentAttribute = [lastCells objectForKey:@(indexPath.section)];

            // Get the bottom most cell of that section
            if ( ! currentAttribute || indexPath.row > currentAttribute.indexPath.row) {
                [lastCells setObject:obj forKey:@(indexPath.section)];
            }

            if ([indexPath item] == 0 && [indexPath section] == 0) {
                visibleParallexHeader = YES;
            }
        }
    }];

    // when the visible rect is at top of the screen, make sure we see
    // the parallex header
    if (CGRectGetMinY(rect) <= 0) {
        visibleParallexHeader = YES;
    }


    // This method may not be explicitly defined, default to 1
    // https://developer.apple.com/library/ios/documentation/uikit/reference/UICollectionViewDataSource_protocol/Reference/Reference.html#jumpTo_6
    NSUInteger numberOfSections = [self.collectionView.dataSource
                                   respondsToSelector:@selector(numberOfSectionsInCollectionView:)]
                                ? [self.collectionView.dataSource numberOfSectionsInCollectionView:self.collectionView]
                                : 1;

    // Create the attributes for the Parallex header
    if (visibleParallexHeader && ! CGSizeEqualToSize(CGSizeZero, self.parallaxHeaderReferenceSize) && numberOfSections > 0) {
        UICollectionViewLayoutAttributes *currentAttribute = [UICollectionViewLayoutAttributes layoutAttributesForSupplementaryViewOfKind:CSStickyHeaderParallaxHeader withIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]];
        CGRect frame = currentAttribute.frame;
        frame.size.width = self.parallaxHeaderReferenceSize.width;
        frame.size.height = self.parallaxHeaderReferenceSize.height;

        CGRect bounds = self.collectionView.bounds;
        CGFloat maxY = CGRectGetMaxY(frame);

        // make sure the frame won't be negative values
        CGFloat y = MIN(maxY - self.parallaxHeaderMinimumReferenceSize.height, bounds.origin.y + self.collectionView.contentInset.top);
        CGFloat height = MAX(1, -y + maxY);

        currentAttribute.frame = (CGRect){
            frame.origin.x,
            y,
            frame.size.width,
            height,
        };

        // if zIndex < 0 would prevents tap from recognized right under navigation bar
        currentAttribute.zIndex = 0;

        [allItems addObject:currentAttribute];
    }

    if ( ! self.disableStickyHeaders) {
        [lastCells enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            NSIndexPath *indexPath = [obj indexPath];
            NSNumber *indexPathKey = @(indexPath.section);

            UICollectionViewLayoutAttributes *header = headers[indexPathKey];
            // CollectionView automatically removes headers not in bounds
            if ( ! header) {
                header = [self layoutAttributesForSupplementaryViewOfKind:UICollectionElementKindSectionHeader
                                                              atIndexPath:[NSIndexPath indexPathForItem:0 inSection:indexPath.section]];

                if (header) {
                    [allItems addObject:header];
                }
            }
            [self updateHeaderAttributes:header lastCellAttributes:lastCells[indexPathKey]];
        }];
    }

    return allItems;
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewLayoutAttributes *attributes = [super layoutAttributesForItemAtIndexPath:indexPath];
    CGRect frame = attributes.frame;
    frame.origin.y += self.parallaxHeaderReferenceSize.height;
    attributes.frame = frame;
    return attributes;
}

- (CGSize)collectionViewContentSize {
    CGSize size = [super collectionViewContentSize];
    size.height += self.parallaxHeaderReferenceSize.height;
    return size;
}

- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBounds
{
    return YES;
}

#pragma mark Helper

- (void)updateHeaderAttributes:(UICollectionViewLayoutAttributes *)attributes lastCellAttributes:(UICollectionViewLayoutAttributes *)lastCellAttributes
{
    CGRect currentBounds = self.collectionView.bounds;
    attributes.zIndex = 1024;
    attributes.hidden = NO;

    CGPoint origin = attributes.frame.origin;

    CGFloat sectionMaxY = CGRectGetMaxY(lastCellAttributes.frame) - attributes.frame.size.height;
    CGFloat y = CGRectGetMaxY(currentBounds) - currentBounds.size.height + self.collectionView.contentInset.top;

    CGFloat maxY = MIN(MAX(y, attributes.frame.origin.y), sectionMaxY);

//    NSLog(@"%.2f, %.2f, %.2f", y, maxY, sectionMaxY);

    origin.y = maxY;

    attributes.frame = (CGRect){
        origin,
        attributes.frame.size
    };
}

@end
