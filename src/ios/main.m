// Minimal UIKit app for the iOS demo build: one screen showing the engine version.
#import <UIKit/UIKit.h>
#include "../engine.h"

@interface DemoViewController : UIViewController
@end

@implementation DemoViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    World world;
    world_init(&world);
    for (int i = 0; i < 12; i++) world_spawn(&world, i, 0);
    for (int i = 0; i < 300; i++) world_step(&world, 0.05f);
    UILabel *label = [[UILabel alloc] initWithFrame:self.view.bounds];
    label.numberOfLines = 0;
    label.textAlignment = NSTextAlignmentCenter;
    label.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    label.text = [NSString stringWithFormat:@"%s\n%d alive", engine_version(), world_alive(&world)];
    [self.view addSubview:label];
}
@end

@interface DemoAppDelegate : UIResponder <UIApplicationDelegate>
@property (strong, nonatomic) UIWindow *window;
@end

@implementation DemoAppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [DemoViewController new];
    [self.window makeKeyAndVisible];
    return YES;
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([DemoAppDelegate class]));
    }
}
