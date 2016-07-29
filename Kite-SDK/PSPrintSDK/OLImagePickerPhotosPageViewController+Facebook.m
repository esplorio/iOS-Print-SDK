//
//  Modified MIT License
//
//  Copyright (c) 2010-2016 Kite Tech Ltd. https://www.kite.ly
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The software MAY ONLY be used with the Kite Tech Ltd platform and MAY NOT be modified
//  to be used with any competitor platforms. This means the software MAY NOT be modified
//  to place orders with any competitors to Kite Tech Ltd, all orders MUST go through the
//  Kite Tech Ltd platform servers.
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import "OLImagePickerPhotosPageViewController+Facebook.h"

@interface OLImagePickerProviderCollection ()
@property (strong, nonatomic) NSMutableArray<OLAsset *> *array;
@end

@implementation OLImagePickerPhotosPageViewController (Facebook)

- (void)loadFacebookAlbums{
    self.albums = [[NSMutableArray alloc] init];
    self.albumRequestForNextPage = [[OLFacebookAlbumRequest alloc] init];
    [self loadNextAlbumPage];
    
    UIView *loadingFooter = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
    UIActivityIndicatorView *activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    activityIndicator.frame = CGRectMake((320 - activityIndicator.frame.size.width) / 2, (44 - activityIndicator.frame.size.height) / 2, activityIndicator.frame.size.width, activityIndicator.frame.size.height);
    [activityIndicator startAnimating];
    [loadingFooter addSubview:activityIndicator];
    self.loadingFooter = loadingFooter;
}

- (void)loadNextAlbumPage {
    if (self.inProgressRequest){
        [self.inProgressRequest cancel];
    }
    self.inProgressRequest = self.albumRequestForNextPage;
    self.albumRequestForNextPage = nil;
    __weak OLImagePickerPhotosPageViewController *welf = self;
    [self.inProgressRequest getAlbums:^(NSArray<OLFacebookAlbum *> *albums, NSError *error, OLFacebookAlbumRequest *nextPageRequest) {
        welf.inProgressRequest = nil;
        welf.loadingIndicator.hidden = YES;
        welf.albumRequestForNextPage = nextPageRequest;
        
        if (error) {
            if (welf.parentViewController.isBeingPresented) {
                welf.loadingIndicator.hidden = NO;
                welf.getAlbumError = error; // delay notification so that delegate can dismiss view controller safely if desired.
            } else {
                //TODO error
            }
            return;
        }
        
        NSMutableArray *paths = [[NSMutableArray alloc] init];
        for (NSUInteger i = 0; i < albums.count; ++i) {
            [paths addObject:[NSIndexPath indexPathForRow:welf.albums.count + i inSection:0]];
        }
        
        [welf.albums addObjectsFromArray:albums];
//        if (welf.albums.count == albums.count) {
//            // first insert request
//            [welf.collectionView reloadData];
//        } else {
//            [welf.collectionView insertItemsAtIndexPaths:paths];
//        }
        
        if (nextPageRequest) {
            //            welf.tableView.tableFooterView = welf.loadingFooter;
        } else {
            welf.albumLabel.text = welf.albums.firstObject.name;
            for (OLFacebookAlbum *album in welf.albums){
                [welf.provider.collections addObject:[[OLImagePickerProviderCollection alloc] initWithArray:[[NSMutableArray alloc] init] name:album.name]];
            }
            [self.albumsCollectionView reloadData];
            
            welf.photos = [[NSMutableArray alloc] init];
            
            
            welf.nextPageRequest = [[OLFacebookPhotosForAlbumRequest alloc] initWithAlbum:welf.albums.firstObject];
            [welf loadNextFacebookPage];
            //            welf.tableView.tableFooterView = nil;
        }
        
    }];
}

- (void)loadNextFacebookPage {
    if (self.inProgressRequest){
        [self.inProgressRequest cancel];
    }
    self.inProgressPhotosRequest = self.nextPageRequest;
    self.nextPageRequest = nil;
    __weak OLImagePickerPhotosPageViewController *welf = self;
    [self.inProgressPhotosRequest getPhotos:^(NSArray *photos, NSError *error, OLFacebookPhotosForAlbumRequest *nextPageRequest) {
        welf.inProgressRequest = nil;
        welf.nextPageRequest = nextPageRequest;
        welf.loadingIndicator.hidden = YES;
        
        if (error) {
            //TODO error
            return;
        }
        
        NSUInteger photosStartCount = welf.photos.count;
        for (OLFacebookImage *image in welf.overflowPhotos){
            [welf.provider.collections[self.showingCollectionIndex].array addObject:[OLAsset assetWithURL:image.fullURL]];
        }
        [welf.photos addObjectsFromArray:welf.overflowPhotos];
        if (nextPageRequest != nil) {
            // only insert multiple of numberOfCellsPerRow images so we fill complete rows
            NSInteger overflowCount = (welf.photos.count + photos.count) % [welf numberOfCellsPerRow];
            for (OLFacebookImage *image in [photos subarrayWithRange:NSMakeRange(0, photos.count - overflowCount)]){
                [welf.provider.collections[self.showingCollectionIndex].array addObject:[OLAsset assetWithURL:image.fullURL]];
            }
            [welf.photos addObjectsFromArray:[photos subarrayWithRange:NSMakeRange(0, photos.count - overflowCount)]];
            welf.overflowPhotos = [photos subarrayWithRange:NSMakeRange(photos.count - overflowCount, overflowCount)];
        } else {
            // we've exhausted all the users images so show the remainder
            for (OLFacebookImage *image in photos){
                [welf.provider.collections[self.showingCollectionIndex].array addObject:[OLAsset assetWithURL:image.fullURL]];
            }
            [welf.photos addObjectsFromArray:photos];
            welf.overflowPhotos = @[];
        }
        
        // Insert new items
        NSMutableArray *addedItemPaths = [[NSMutableArray alloc] init];
        for (NSUInteger itemIndex = photosStartCount; itemIndex < welf.photos.count; ++itemIndex) {
            [addedItemPaths addObject:[NSIndexPath indexPathForItem:itemIndex inSection:0]];
        }
        
        if (welf.view.superview){
            [welf.collectionView insertItemsAtIndexPaths:addedItemPaths];
            ((UICollectionViewFlowLayout *) welf.collectionView.collectionViewLayout).footerReferenceSize = CGSizeMake(0, nextPageRequest == nil ? 0 : 44);
        }
        else{
            [welf.collectionView reloadData];
        }
    }];
    
}

@end
