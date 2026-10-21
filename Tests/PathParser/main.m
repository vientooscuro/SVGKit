#import "SVGKPointsAndPathsParser.h"
#import <math.h>

static void countLines(void *info, const CGPathElement *element) {
    if (element->type == kCGPathElementAddLineToPoint) {
        NSUInteger *count = info;
        *count += 1;
        NSCAssert(isfinite(element->points[0].x) && isfinite(element->points[0].y), @"Non-finite path");
    }
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSString *mode = @(argv[1]);
        BOOL vertical = [mode hasPrefix:@"vertical"];
        BOOL relative = [mode hasSuffix:@"relative"];
        NSString *numbers = [mode containsString:@"malformed"] ? @"10?" :
                            [mode containsString:@"nonfinite"] ? @"1e999" :
                            [mode containsString:@"trailing"] ? @"10, " : @"10,20 -5.5e1";
        NSString *command = [NSString stringWithFormat:@"%@%@", vertical ? (relative ? @"v" : @"V") : (relative ? @"h" : @"H"), numbers];
        CGMutablePathRef path = CGPathCreateMutable();
        CGPathMoveToPoint(path, NULL, 3, 7);
        NSScanner *scanner = [NSScanner scannerWithString:command];
        SVGCurve result = vertical
            ? [SVGKPointsAndPathsParser readVerticalLinetoCommand:scanner path:path relativeTo:relative ? CGPointMake(3, 7) : CGPointZero isRelative:relative]
            : [SVGKPointsAndPathsParser readHorizontalLinetoCommand:scanner path:path relativeTo:relative ? CGPointMake(3, 7) : CGPointZero isRelative:relative];
        NSUInteger lines = 0;
        CGPathApply(path, &lines, countLines);
        NSUInteger expected = [mode containsString:@"nonfinite"] ? 0 :
                              ([mode containsString:@"malformed"] || [mode containsString:@"trailing"]) ? 1 : 3;
        BOOL valid = lines == expected && isfinite(result.p.x) && isfinite(result.p.y);
        if (expected == 3) {
            CGFloat expectedCoordinate = relative ? (vertical ? -18 : -22) : -55;
            valid = valid && fabs((vertical ? result.p.y : result.p.x) - expectedCoordinate) < 0.001;
        }
        CGPathRelease(path);
        if (!valid) {
            fprintf(stderr, "FAIL %s: lines %lu expected %lu, endpoint %.2f,%.2f\n", argv[1], (unsigned long)lines, (unsigned long)expected, result.p.x, result.p.y);
            return 1;
        }
        printf("PASS %s\n", argv[1]);
    }
    return 0;
}
