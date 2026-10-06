// hsq: send Lua to Hammerspoon without the `hs` CLI.
//
//   hsq 'require("x").f()'      fire and forget
//   hsq -r 'return 1 + 1'       wait for and print the result
//
// `hs -c` registers a per-process reply port with Hammerspoon. If that process
// dies before Hammerspoon answers (crash, timeout, many in flight at once),
// Hammerspoon sends to the dead port and crashes in CFMessagePortIsValid.
// hsq uses hs.ipc's legacy message id (0), whose result travels back on the
// request's own reply channel, so there is no per-client port to go stale.
//
// When Hammerspoon isn't running, hsq relaunches it in the background
// (throttled) instead of `hs`'s "launch it now?" dialog, and drops the command.

#include <CoreFoundation/CoreFoundation.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>

static void relaunch(void) {
    // One relaunch per 10s no matter how many hotkeys fire meanwhile.
    const char *stamp = "/tmp/hsq-relaunch";
    struct stat st;
    if (stat(stamp, &st) == 0 && time(NULL) - st.st_mtime < 10) return;
    FILE *f = fopen(stamp, "w");
    if (f) fclose(f);
    if (fork() == 0) {
        execl("/usr/bin/open", "open", "-g", "-b", "org.hammerspoon.Hammerspoon", (char *)NULL);
        _exit(1);
    }
}

int main(int argc, char **argv) {
    int wantReply = argc == 3 && strcmp(argv[1], "-r") == 0;
    if (argc != 2 && !wantReply) {
        fprintf(stderr, "usage: hsq [-r] <lua>\n");
        return 2;
    }
    const char *code = argv[argc - 1];

    CFMessagePortRef port = CFMessagePortCreateRemote(NULL, CFSTR("Hammerspoon"));
    if (!port) {
        relaunch();
        return 1;
    }

    // The legacy handler skips the first byte (a raw-mode flag).
    size_t len = strlen(code);
    UInt8 *buf = malloc(len + 1);
    buf[0] = 'x';
    memcpy(buf + 1, code, len);
    CFDataRef data = CFDataCreateWithBytesNoCopy(NULL, buf, len + 1, kCFAllocatorMalloc);

    CFDataRef reply = NULL;
    SInt32 rc = CFMessagePortSendRequest(port, 0, data, 2.0, wantReply ? 4.0 : 0.0,
                                         wantReply ? kCFRunLoopDefaultMode : NULL, &reply);
    if (reply) {
        fwrite(CFDataGetBytePtr(reply), 1, CFDataGetLength(reply), stdout);
        fputc('\n', stdout);
        CFRelease(reply);
    }
    CFRelease(data);
    CFRelease(port);
    return rc == kCFMessagePortSuccess ? 0 : 1;
}
