//
//  CMLuaManager.m
//  CrimsonWars
//
//  Created by David Holtkamp on 8/13/14.
//  Copyright (c) 2014 Crimson Moon Entertainment LLC. All rights reserved.
//
#import "CMSynthesizeSingleton.h"
#import "LuaBridgedFunctions.h"
#import "NSLua.h"

#define ADDMETHOD(name) \
(lua_pushstring(L, #name), \
lua_pushcfunction(L, luafunc_ ## name), \
lua_settable(L, -3))


@implementation NSLua
{
    lua_State *L;
    NSString *errorBuffer;
}


SYNTHESIZE_SINGLETON_FOR_CLASS(NSLua,sharedLua)

#pragma mark - NSObject

- (id)init:(lua_State*)l
{
	if (self = [super init])
	{
        if(l == nil)
            l = luaL_newstate();
        L = l;
        luaL_openlibs(L);
        lua_newtable(L);

        ADDMETHOD(call);
        ADDMETHOD(hasmethod);
        ADDMETHOD(getproperty);
        ADDMETHOD(getclass);
        ADDMETHOD(classof);
		ADDMETHOD(CGPointMake);
		ADDMETHOD(CGRectMake);
		ADDMETHOD(CGRectContainsPoint);

        lua_setglobal(L, "objc");
        //NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        NSString *path = [[NSBundle mainBundle] pathForResource:@"LuaBridge" ofType:@"lua"];
        if (luaL_dofile(L, [path UTF8String]))
        {
            const char *err = lua_tostring(L, -1);
            NSLog(@"error while loading utils: %s", err);
        }
        
        lua_settop(L, 0);
	}
	NSLog(@"nslua init ok");

	return self;
}

#pragma mark - Run Lua Code


- (bool)runLuaBundleFile:(NSString *)fileName
{
	fileName = [fileName stringByReplacingOccurrencesOfString:@".lua" withString:@""];
	NSBundle *bundle = [NSBundle bundleForClass:[self class]];
	NSString *path = [bundle pathForResource:fileName ofType:@"lua"];
	return [self runLuaFileAtPath:path];
}

- (bool)runLuaFileAtPath:(NSString *)path
{
    errorBuffer = NULL;
	if (luaL_dofile(L, [path UTF8String]))
	{
		const char *err = lua_tostring(L, -1);
        errorBuffer = [NSString stringWithFormat:@"error while loading file %@: %s", path, err];
		NSLog(@"error while loading file %@: %s", path, err);
		return false;
	}

	return true;
}

- (bool)runLuaString:(NSString *)string
{
    errorBuffer = NULL;
    if (luaL_loadstring(L, [string UTF8String]))
	{
		const char *err = lua_tostring(L, -1);
        errorBuffer = [NSString stringWithFormat:@"error while compiling string %@: %s", string, err];
        [self getErrorBuffer];
		return false;
	}

	if (lua_pcall(L, 0, 0, 0))
	{
		const char *err = lua_tostring(L, -1);
        errorBuffer = [NSString stringWithFormat:@"error while running string %@: %s", string, err];
        [self getErrorBuffer];
        NSLog(@"error while running string %@: %s", string, err);
		return false;
	}

	return true;
}


#pragma mark - Call Loaded Function
- (id)callLuaFunction:(NSString *)functionName withArguments:(NSArray *)arguments
{
    lua_getglobal(L, "unwrap"); // We are unwrapping right after this next funciton, so I'm placing it here
                                // so it will be in the right place in the stack
    lua_getglobal(L, [functionName UTF8String]);
    
    if(lua_type(L, -1) != LUA_TFUNCTION)
    {
        NSLog(@"Attempted to call non-existing lua function %@", functionName);
        lua_pop(L, 2);
        return nil;
    }
    
    
    for(id item in arguments)
    {
	    to_lua(L, item, true);
    }
    
    if(lua_pcall(L, (int)[arguments count], LUA_MULTRET, 0) != LUA_OK)
    {
	    NSLog(@"Error running specified lua function %@", functionName);
    }

	int top = lua_gettop(L);

    if(top == 2)
    {
        if(lua_pcall(L, 1, 1, 0) != LUA_OK) // Call unwrap on what we had above
        {
            NSLog(@"Error unwarpping return value");
        }
        id object = from_lua(L, 1);
        lua_pop(L, 1);
        return object;
    }
    else
    {
        lua_pop(L, 1); // pop unused unwrap
        return nil;
    }
}

#pragma mark - Get and Set Global Variables
- (id)getLuaGlobalForKey:(NSString*)key
{
    lua_getglobal(L, [key UTF8String]);
    id value = from_lua(L, -1);
    lua_pop(L, 1);
    return value;
}


- (void)setLuaGlobalValue:(id)value forKey:(NSString*)key
{
    if(to_lua(L, value, true) == true)
    {
        lua_setglobal(L, [key UTF8String]);
    }
}


#pragma mark - Lua Access
- (lua_State *)getLuaState
{
    return L;
}

- (NSString *)getErrorBuffer
{
    NSLog(@"Checking error buffer: %@", errorBuffer);
    return errorBuffer;
}


#pragma mark 


@end

extern int luaopen_nslua(lua_State *L)
{
	NSURL*    url = [NSURL fileURLWithPath:@"LuaBridge.lua"];
	NSNumber*  num = [NSNumber numberWithFloat:(123.456)];
	NSPoint p = CGPointMake(1,2);
	NSLog(@"luaopen_nslua %@", url);
    id i = [[NSLua sharedLua] init:L];
    return 0;
}
