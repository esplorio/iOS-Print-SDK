//
//  Modified MIT License
//
//  Copyright (c) 2010-2015 Kite Tech Ltd. https://www.kite.ly
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

#import "OLPhotobookPrintJob.h"
#import "OLProductTemplate.h"
#import "OLAsset.h"
#import "OLAddress.h"

static NSString *const kKeyPhotobookProductTemplateId = @"co.oceanlabs.pssdk.kKeyPhotobookProductTemplateId";
static NSString *const kKeyPhotobookImages = @"co.oceanlabs.pssdk.kKeyPhotobookImages";
static NSString *const kKeyFrontAsset = @"co.oceanlabs.pssdk.kKeyFrontAsset";
static NSString *const kKeyBackAsset = @"co.oceanlabs.pssdk.kKeyBackAsset";
static NSString *const kKeyPhotobookAddress = @"co.oceanlabs.pssdk.kKeyPhotobookAddress";
static NSString *const kKeyPhotobookUuid = @"co.oceanlabs.pssdk.kKeyPhotobookUuid";
static NSString *const kKeyPhotobookExtraCopies = @"co.oceanlabs.pssdk.kKeyPhotobookExtraCopies";
static NSString *const kKeyPhotobookPrintJobOptions = @"co.oceanlabs.pssdk.kKeyPhotobookPrintJobOptions";

@interface OLPhotobookPrintJob ()
@property (nonatomic, strong) NSString *templateId;
@property (nonatomic, strong) NSArray *assets;
@property (strong, nonatomic) NSMutableDictionary *options;
@end

@implementation OLPhotobookPrintJob

@synthesize address;
@synthesize uuid;
@synthesize extraCopies;

-(NSMutableDictionary *) options{
    if (!_options){
        _options = [[NSMutableDictionary alloc] init];
        _options[@"spine_color"] = @"#FFFFFF";
    }
    return _options;
}

- (void)setValue:(NSString *)value forOption:(NSString *)option{
    self.options[option] = value;
}

- (id)initWithTemplateId:(NSString *)templateId OLAssets:(NSArray<OLAsset *> *)assets{
    if (self = [super init]){
#ifdef DEBUG
        for (id asset in assets) {
            NSAssert([asset isKindOfClass:[OLAsset class]], @"initWithTemplateId:OLAssets: requires an NSArray of OLAsset not: %@", [asset class]);
        }
#endif
        self.uuid = [[NSUUID UUID] UUIDString];
        self.assets = assets;
        self.templateId = templateId;
    }
    
    return self;
}

#pragma mark - OLPrintJob Protocol

- (NSDictionary *)jsonRepresentation {
    NSMutableArray *pages = [[NSMutableArray alloc] init];
    for (OLAsset *asset in self.assets) {
        [pages addObject:@{
                           @"layout" : @"single_centered",
                           @"asset" : [NSString stringWithFormat:@"%lld", asset.assetId]
                           }];
    }
    
    NSMutableDictionary *json = [[NSMutableDictionary alloc] init];
    json[@"template_id"] = [OLProductTemplate templateWithId:self.templateId].identifier;
    json[@"assets"] = @{
                        @"front_cover" : self.frontCover ? [NSString stringWithFormat:@"%lld", self.frontCover.assetId] : @"",
                        @"back_cover" : self.backCover ? [NSString stringWithFormat:@"%lld", self.backCover.assetId] : @"",
                        @"pages" : pages
                        };
    json[@"options"] = self.options;
    
    return json;
}

- (NSUInteger)quantity {
    return self.assets.count;
}

- (NSDecimalNumber *)costInCurrency:(NSString *)currencyCode {
    OLProductTemplate *productTemplate = [OLProductTemplate templateWithId:self.templateId];
    NSUInteger expectedQuantity = productTemplate.quantityPerSheet;
    NSDecimalNumber *cost = [productTemplate costPerSheetInCurrencyCode:currencyCode];
    NSUInteger numOrders = (NSUInteger) floorf((self.quantity + expectedQuantity - 1)  / expectedQuantity);
    return (NSDecimalNumber *) [cost decimalNumberByMultiplyingBy:(NSDecimalNumber *) [NSDecimalNumber numberWithUnsignedInteger:numOrders]];
}

- (NSArray *)currenciesSupported {
    return [OLProductTemplate templateWithId:self.templateId].currenciesSupported;
}

- (NSString *)productName {
    return [OLProductTemplate templateWithId:self.templateId].name;
}

- (NSArray *)assetsForUploading {
    NSMutableArray *assets = [[NSMutableArray alloc] init];
    [assets addObjectsFromArray:self.assets];
    if (self.frontCover){
        [assets addObject:self.frontCover];
    }
    if (self.backCover){
        [assets addObject:self.backCover];
    }
    return assets;
}

- (NSUInteger) hash {
    NSUInteger val = [self.templateId hash];
    val = 39 * val + [self.frontCover hash];
    val = 36 * val + [self.backCover hash];
    for (id asset in self.assets) {
        val = 37 * val + [asset hash];
    }
    
    val = 38 * val + self.extraCopies;
    val = 39 * val + [self.options hash];
    val = 40 * val + [self.address hash];
    
    return val;
}

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }
    
    if (![object isKindOfClass:[OLPhotobookPrintJob class]]) {
        return NO;
    }
    OLPhotobookPrintJob* printJob = (OLPhotobookPrintJob*)object;
    
    return [self.templateId isEqual:printJob.templateId] && [self.assets isEqualToArray:printJob.assets] && [self.frontCover isEqual:printJob.frontCover] && [self.backCover isEqual:printJob.backCover] && [self.options isEqualToDictionary:printJob.options] && ((!self.address && !printJob.address) || [self.address isEqual:printJob.address]);
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    OLPhotobookPrintJob *objectCopy = [[OLPhotobookPrintJob allocWithZone:zone] init];
    // Copy over all instance variables from self to objectCopy.
    // Use deep copies for all strong pointers, shallow copies for weak.
    objectCopy.assets = self.assets;
    objectCopy.templateId = self.templateId;
    objectCopy.frontCover = self.frontCover;
    objectCopy.backCover = self.backCover;
    objectCopy.options = self.options;
    objectCopy.uuid = self.uuid;
    objectCopy.extraCopies = self.extraCopies;
    return objectCopy;
}

#pragma mark - NSCoding protocol

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:self.templateId forKey:kKeyPhotobookProductTemplateId];
    [aCoder encodeObject:self.assets forKey:kKeyPhotobookImages];
    [aCoder encodeObject:self.frontCover forKey:kKeyFrontAsset];
    [aCoder encodeObject:self.backCover forKey:kKeyBackAsset];
    [aCoder encodeObject:self.uuid forKey:kKeyPhotobookUuid];
    [aCoder encodeInteger:self.extraCopies forKey:kKeyPhotobookExtraCopies];
    [aCoder encodeObject:self.address forKey:kKeyPhotobookAddress];
    [aCoder encodeObject:self.options forKey:kKeyPhotobookPrintJobOptions];
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    if (self = [super init]) {
        self.templateId = [aDecoder decodeObjectForKey:kKeyPhotobookProductTemplateId];
        self.assets = [aDecoder decodeObjectForKey:kKeyPhotobookImages];
        self.frontCover = [aDecoder decodeObjectForKey:kKeyFrontAsset];
        self.backCover = [aDecoder decodeObjectForKey:kKeyBackAsset];
        self.extraCopies = [aDecoder decodeIntegerForKey:kKeyPhotobookExtraCopies];
        self.uuid = [aDecoder decodeObjectForKey:kKeyPhotobookUuid];
        self.address = [aDecoder decodeObjectForKey:kKeyPhotobookAddress];
        self.options = [aDecoder decodeObjectForKey:kKeyPhotobookPrintJobOptions];
    }
    
    return self;
}

@end
