#ifdef __cplusplus
  #include "lua.hpp"
#else
  #include "lua.h"
  #include "lualib.h"
  #include "lauxlib.h"
#endif

#include <stdio.h>
#include <sys/time.h>
#include <time.h>

#ifdef __cplusplus
extern "C"{
#endif


//微秒
static int getmicrosecond(lua_State *L) {
    struct timeval tv;
    gettimeofday(&tv,NULL);
    long microsecond = tv.tv_sec*1000000+tv.tv_usec;
    lua_pushnumber(L, microsecond);
    return 1;
}
 
//毫秒
static int getmillisecond(lua_State *L) {
    struct timeval tv;
    gettimeofday(&tv,NULL);
    long millisecond = (tv.tv_sec*1000000+tv.tv_usec)/1000;
    lua_pushnumber(L, millisecond);
 
    return 1;
}
 
 
int luaopen_usertime(lua_State *L) {
  // luaL_checkversion(L);
 
  luaL_Reg l[] = {
    {"getmillisecond", getmillisecond},
    {"getmicrosecond", getmicrosecond},
    { NULL, NULL },
  };
 
  // luaL_newlib(L, l);
  luaL_register(L, "usertime", l);
  return 1;
}


#ifdef __cplusplus
}
#endif