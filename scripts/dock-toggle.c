#include <stdbool.h>
#include <string.h>

extern bool CoreDockGetAutoHideEnabled(void);
extern void CoreDockSetAutoHideEnabled(bool flag);

int main(int argc, char *argv[]) {
    if (argc < 2) return 1;
    if (strcmp(argv[1], "show") == 0)
        CoreDockSetAutoHideEnabled(false);
    else if (strcmp(argv[1], "hide") == 0)
        CoreDockSetAutoHideEnabled(true);
    else if (strcmp(argv[1], "toggle") == 0)
        CoreDockSetAutoHideEnabled(!CoreDockGetAutoHideEnabled());
    return 0;
}
