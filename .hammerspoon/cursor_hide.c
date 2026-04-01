#include <lua.h>
#include <lauxlib.h>
#include <CoreGraphics/CoreGraphics.h>

static int lua_hide_cursor(lua_State *L) {
    CGDisplayHideCursor(kCGNullDirectDisplay);
    return 0;
}

static int lua_show_cursor(lua_State *L) {
    CGDisplayShowCursor(kCGNullDirectDisplay);
    return 0;
}

static const luaL_Reg cursor_lib[] = {
    {"hide", lua_hide_cursor},
    {"show", lua_show_cursor},
    {NULL, NULL}
};

int luaopen_cursor_hide(lua_State *L) {
    luaL_newlib(L, cursor_lib);
    return 1;
}
