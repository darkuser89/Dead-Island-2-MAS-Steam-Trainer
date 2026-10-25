// SPDX-License-Identifier: GPL-3.0-only
#import "GameEdition.h"
#import <mach-o/loader.h>
#import <mach/machine.h>

static NSString *makeApp(NSString *root, DI2GameEdition edition) {
    NSString *path=[root stringByAppendingPathComponent:[DI2EditionKey(edition) stringByAppendingString:@" game.app"]];
    NSString *mac=[path stringByAppendingPathComponent:@"Contents/MacOS"];
    NSCAssert([NSFileManager.defaultManager createDirectoryAtPath:mac withIntermediateDirectories:YES attributes:nil error:NULL],@"fixture directory");
    NSDictionary *info=@{@"CFBundleIdentifier":DI2EditionBundleID(edition),@"CFBundleExecutable":@"DeadIsland2",@"CFBundleShortVersionString":@"0.6.4"};
    NSCAssert([info writeToFile:[path stringByAppendingPathComponent:@"Contents/Info.plist"] atomically:YES],@"fixture metadata");
    struct mach_header_64 header={.magic=MH_MAGIC_64,.cputype=CPU_TYPE_ARM64,.filetype=MH_EXECUTE,.ncmds=1,.sizeofcmds=sizeof(struct uuid_command)};
    struct uuid_command uuid={.cmd=LC_UUID,.cmdsize=sizeof(struct uuid_command)};
    [[[NSUUID alloc]initWithUUIDString:DI2EditionUUID(edition)] getUUIDBytes:uuid.uuid];
    NSMutableData *bytes=[NSMutableData dataWithBytes:&header length:sizeof(header)];[bytes appendBytes:&uuid length:sizeof(uuid)];
    NSCAssert([bytes writeToFile:[mac stringByAppendingPathComponent:@"DeadIsland2"] atomically:YES],@"fixture header");
    if (edition==DI2EditionSteam) [[NSData data]writeToFile:[mac stringByAppendingPathComponent:@"libsteam_api.dylib"] atomically:YES];
    return path;
}
int main(void) {
    @autoreleasepool {
        NSString *root=[NSTemporaryDirectory() stringByAppendingPathComponent:[@"DI2ProfileTests-" stringByAppendingString:NSUUID.UUID.UUIDString]];
        @try {
            NSString *mas=makeApp(root,DI2EditionMAS),*steam=makeApp(root,DI2EditionSteam);
            NSString *steamRoot=[root stringByAppendingPathComponent:@"Steam"],*suffix=@"steamapps/common/Dead Island 2/DeadIsland2.app";
            NSString *standard=[steamRoot stringByAppendingPathComponent:suffix];
            NSCAssert([DI2SteamDefaultPathFromRoot(steamRoot) isEqual:standard],@"missing Steam config returns portable default");
            NSString *external=[root stringByAppendingPathComponent:@"External \"Library\""],*installed=[external stringByAppendingPathComponent:suffix];
            [NSFileManager.defaultManager createDirectoryAtPath:installed withIntermediateDirectories:YES attributes:nil error:NULL];
            NSString *config=[steamRoot stringByAppendingPathComponent:@"steamapps/libraryfolders.vdf"];
            [NSFileManager.defaultManager createDirectoryAtPath:config.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:NULL];
            NSString *escaped=[external stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
            NSString *vdf=[NSString stringWithFormat:@"\"libraryfolders\" { \"0\" { \"path\" \"relative\" } \"1\" { \"path\" \"%@\" } }",escaped];
            [vdf writeToFile:config atomically:YES encoding:NSUTF8StringEncoding error:NULL];
            NSCAssert([DI2SteamDefaultPathFromRoot(steamRoot) isEqual:installed],@"configured external libraries and escaped quotes resolve without machine paths");
            [NSFileManager.defaultManager createDirectoryAtPath:standard withIntermediateDirectories:YES attributes:nil error:NULL];
            NSCAssert([DI2SteamDefaultPathFromRoot(steamRoot) isEqual:standard],@"standard library has stable priority");
            [NSFileManager.defaultManager removeItemAtPath:standard error:NULL];
            [[NSMutableData dataWithLength:1024*1024+1] writeToFile:config atomically:YES];
            NSCAssert([DI2SteamDefaultPathFromRoot(steamRoot) isEqual:standard],@"oversized config ignored");
            NSCAssert(DI2InspectGame(mas,DI2EditionMAS,NULL)!=nil && DI2InspectGame(steam,DI2EditionSteam,NULL)!=nil,@"both exact build profiles accepted");
            NSCAssert(!DI2InspectGame(mas,DI2EditionSteam,NULL) && !DI2InspectGame(steam,DI2EditionMAS,NULL),@"store identity cannot be inferred from app filename");
            NSCAssert(!DI2InspectGame(@"relative.app",DI2EditionMAS,NULL),@"absolute installation path required");
            NSString *link=[root stringByAppendingPathComponent:@"Game alias.app"];
            [NSFileManager.defaultManager createSymbolicLinkAtPath:link withDestinationPath:steam error:NULL];
            NSCAssert([DI2InspectGame(link,DI2EditionSteam,NULL)[@"path"] isEqual:steam],@"symbolic path resolves to canonical installation");
            NSString *binary=[mas stringByAppendingPathComponent:@"Contents/MacOS/DeadIsland2"];
            NSData *original=[NSData dataWithContentsOfFile:binary];NSMutableData *bad=[original mutableCopy];
            ((struct uuid_command *)((uint8_t *)bad.mutableBytes+sizeof(struct mach_header_64)))->uuid[0]^=1;
            [bad writeToFile:binary atomically:YES];NSCAssert(!DI2InspectGame(mas,DI2EditionMAS,NULL),@"unknown UUID rejected");
            bad=[original mutableCopy];((struct mach_header_64 *)bad.mutableBytes)->cputype=CPU_TYPE_X86_64;
            [bad writeToFile:binary atomically:YES];NSCAssert(!DI2InspectGame(mas,DI2EditionMAS,NULL),@"unsupported architecture rejected");
            bad=[original mutableCopy];((struct mach_header_64 *)bad.mutableBytes)->ncmds=2;
            [bad writeToFile:binary atomically:YES];NSCAssert(!DI2InspectGame(mas,DI2EditionMAS,NULL),@"truncated command list rejected even after valid UUID");
            [original writeToFile:binary atomically:YES];
            NSString *library=[steam stringByAppendingPathComponent:@"Contents/MacOS/libsteam_api.dylib"];
            [NSFileManager.defaultManager removeItemAtPath:library error:NULL];NSCAssert(!DI2InspectGame(steam,DI2EditionSteam,NULL),@"Steam installation needs its platform library");
            for (DI2GameEdition edition=DI2EditionMAS;edition<=DI2EditionSteam;edition++) {
                NSCAssert(DI2EditionForKey(DI2EditionKey(edition))==edition,@"edition key round trip");
                NSCAssert(DI2EditionDefaultPath(edition).isAbsolutePath,@"default installation paths");
            }
            NSCAssert(DI2EditionForKey(@"other")==DI2EditionUnknown && DI2EditionForUUID(NULL)==DI2EditionUnknown,@"unknown profile remains unsupported");
            puts("Edition preflight checks passed: MAS/Steam identity, UUID/architecture gates, path aliases and malformed headers.");
        } @finally { [NSFileManager.defaultManager removeItemAtPath:root error:NULL]; }
    }
    return 0;
}
