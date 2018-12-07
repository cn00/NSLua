//
//  LuaBridgedFunctions.m
//  Pods
//
//  Created by David Holtkamp on 4/1/15.
//
//

#import "LuaBridgedFunctions.h"
#import <CoreGraphics/CoreGraphics.h>
#import <objc/runtime.h>
#import <Foundation/Foundation.h>


#define CNVBUF(type) type x = *(type*)buffer

#define DEBUG_LUA_BRIDGE 1
#if DEBUG_LUA_BRIDGE
#define DebugLog(...) NSLog(__VA_ARGS__)
#else
#define DebugLog(...)
#endif

#define IsNSValueType(o,t) (strcmp([o objCType], @encode(t)) == 0)

#pragma mark - Helper Functions


bool to_lua(lua_State *L, id obj, bool dowrap)
{
    //DebugLog(@"[App][LUA][ObjC] pass [%@] class:[%@] to Lua", obj, [obj class]);
    if (obj == nil)
    {
        lua_pushnil(L);
    }
    else if ([obj isKindOfClass:[NSString class]])
    {
        lua_pushstring(L, [obj cStringUsingEncoding:NSUTF8StringEncoding]);
    }
    else if ([obj isKindOfClass:[NSNumber class]])
    {
        if(strcmp([obj objCType], [@"c" UTF8String]) == 0)
        {
            lua_pushboolean(L, [obj intValue]);
        }
        else
        {
            lua_pushnumber(L, [obj doubleValue]);
        }
    }
    else if ([obj isKindOfClass:[NSNull class]])
    {
        lua_pushnil(L);
    }
    else if ([obj isKindOfClass:[NSArray class]])
    {
        lua_newtable(L);
        [obj enumerateObjectsUsingBlock:^(id object, NSUInteger idx, BOOL *stop) {
            to_lua(L, object, true);
            lua_rawseti(L,-2,(int)idx + 1);
        }];
    }
    else if ([obj isKindOfClass:[NSDictionary class]])
    {
        lua_newtable(L);
        [obj enumerateKeysAndObjectsUsingBlock: ^(id key, id obj, BOOL *stop) {
            to_lua(L, key, false);
            to_lua(L, obj, true);
            lua_settable(L, -3);
        }];
    }
    else if ([obj isKindOfClass:[NSValue class]])
    {
        lua_getglobal(L, "wrap");
        lua_pushlightuserdata(L, (__bridge void*)obj);
        lua_pcall(L, 1, 1, 0); /* The thing is now on the stack */
        if (IsNSValueType(obj, CGPoint)) {
            lua_pushstring(L, "x");
            lua_pushnumber(L, [obj CGPointValue].x);
            lua_settable(L, -3);
            lua_pushstring(L, "y");
            lua_pushnumber(L, [obj CGPointValue].y);
            lua_settable(L, -3);
            lua_pushstring(L, "Class");
            lua_pushstring(L, "CGPoint");
            lua_settable(L, -3);
        } else if (IsNSValueType(obj, CGRect)) {
            lua_pushstring(L, "origin");
            lua_newtable(L);
            {
                lua_pushstring(L, "x");
                lua_pushnumber(L, [obj CGRectValue].origin.x);
                lua_settable(L, -3);
                lua_pushstring(L, "y");
                lua_pushnumber(L, [obj CGRectValue].origin.y);
                lua_settable(L, -3);
            }
            lua_settable(L, -3);
            lua_pushstring(L, "size");
            lua_newtable(L);
            {
                lua_pushstring(L, "width");
                lua_pushnumber(L, [obj CGRectValue].size.width);
                lua_settable(L, -3);
                lua_pushstring(L, "height");
                lua_pushnumber(L, [obj CGRectValue].size.height);
                lua_settable(L, -3);
            }
            lua_settable(L, -3);
            lua_pushstring(L, "Class");
            lua_pushstring(L, "CGRect");
            lua_settable(L, -3);
        }
    }
    else
    {
        // We need to wrap this value before pushing
        if(dowrap)
        {
            lua_getglobal(L, "wrap");
            lua_pushlightuserdata(L, (__bridge void*)obj);
            if(lua_pcall(L, 1, 1, 0) != LUA_OK)
            {
                DebugLog(@"[App][LUA][ObjC] Error running specified lua function wrap");
            }
            
            // We don't pop the data! We simply leave it there for the function to read as its param
        }
        
        else
        {
            lua_pushlightuserdata(L, (__bridge void*)obj);
        }
    }

	return true;
}


id from_lua(lua_State *L, int i)
{
    int t = lua_type(L, i);
    switch (t)
    {
        case LUA_TNIL:
            return [NSNull null];
            break;
        case LUA_TNUMBER:
            return [NSNumber numberWithDouble:lua_tonumber(L, i)];
            break;
        case LUA_TBOOLEAN:
            return [NSNumber numberWithBool:lua_toboolean(L, i)];
            break;
        case LUA_TSTRING:
            return [NSString stringWithCString:lua_tostring(L, i) encoding:NSUTF8StringEncoding];
            break;
        case LUA_TLIGHTUSERDATA:
            return (__bridge id)lua_topointer(L, i);
            break;
        case LUA_TUSERDATA:
        {
            void *p = lua_touserdata(L, i);
            void **ptr = (void **)p;
            return (__bridge id)*ptr;
        }
            break;
        case LUA_TTABLE:
            

            lua_pushvalue(L, i);
            lua_pushnil(L);
            
            bool is_dictionary = false;
            while (lua_next(L, -2))
            {
                if(lua_type(L, -2) != LUA_TNUMBER)
                {
                    is_dictionary = true;
                    lua_pop(L, 2);
                    break;
                }
                else
                {
                    lua_pop(L, 1);
                }
            }
            
            if (is_dictionary == true)
            {
                NSMutableDictionary* dict = [NSMutableDictionary dictionary];
                lua_pushnil(L);
                
                while (lua_next(L, -2))
                {
                    id key = from_lua(L, -2);
                    id val = from_lua(L, -1);
                    lua_pop(L, 1);
                    
                    if (key == nil)
                    {
                        continue;
                    }
                    if (val == nil)
                    {
                        val = [NSNull null];
                    }
                    
                    dict[key] = val;
                }
                lua_pop(L, 1);
                return dict;
            }
            else
            {
                // must be an array
                NSMutableArray* array = [NSMutableArray array];
                lua_pushnil(L);
                
                while (lua_next(L, -2))
                {
                    int current_index = lua_tonumber(L, -2) - 1;
                    id val = from_lua(L, -1);
                    lua_pop(L, 1);
                    
                    if (val == nil)
                    {
                        val = [NSNull null];
                    }
                    
                    array[current_index] = val;
                }
                lua_pop(L, 1);
                return array;
            }
            
            
            
        case LUA_TFUNCTION:
        case LUA_TTHREAD:
        case LUA_TNONE:
        default:
           return nil;
        
        break;
    }
}

#pragma mark - Lua Registerd Functions

int luafunc_getclass(lua_State *L)
{
    const char *classname = lua_tostring(L, -1);
    id cls = NSClassFromString([NSString stringWithUTF8String:classname]);
    int n = 0;
    if (cls) {
        lua_pushlightuserdata(L, (__bridge void *)(cls));
        n = 1;
    } else {
        n = 0;
    }
    DebugLog(@"[App][LUA][ObjC] Class: %s = %@", classname, cls);
    return n;
}

int luafunc_hasmethod(lua_State *L)
{
    id target = from_lua(L, 1);
    const char* message = luaL_checkstring(L, 2);
    SEL sel = NSSelectorFromString([NSString stringWithUTF8String:message]);

    NSMethodSignature *sig = [target methodSignatureForSelector:sel];
    DebugLog(@"[App][LUA][ObjC] %@: method:[%s] sign:[%@] in [%@]", (sig ? @"Yes" : @"No"), message, sig, target);
    lua_pushboolean(L, sig ? TRUE : FALSE);
    return 1;
}

int luafunc_getproperty(lua_State *L)
{
    id target = from_lua(L, 1);
    const char* propname = luaL_checkstring(L, 2);
    id r;
    int lr = 0;
    //DebugLog(@"[App][LUA][ObjC] Does %@  have a property called %s?", target, propname);
    @try {
        r = [target valueForKey:[NSString stringWithUTF8String:propname]];
        lr = 1;
    }
    @catch (NSException *exception) {
        //DebugLog(@"[App][LUA][ObjC] %@ doesn't have a property called %s", target, propname);
        lr = 0;
    }
    DebugLog(@"[App][LUA][ObjC] %@: property:[%s] id:[%@] in [%@]", (r ? @"Yes" : @"No"), propname, r, target);
    if(lr == 1)
        to_lua(L, r, true);
    return lr;
}

int luafunc_classof(lua_State *L)
{
    id target = from_lua(L, 1);
    to_lua(L, NSStringFromClass([target class]), false);
    return 1;
}


int luafunc_call(lua_State *L)
{
    NSMutableArray *stack = [[NSMutableArray alloc] init];
    
    lua_pushnil(L);
    while(lua_next(L, -2))
    {
        int index = lua_tonumber(L, -2) - 1;
        id object = from_lua(L, -1);
        if(object == nil)
        {
            object = [NSNull null];
        }
        stack[index] = object;
        lua_pop(L, 1);
    }
    lua_pop(L, 1);
    
    
    NSString *message = (NSString *)[stack lastObject];
    //DebugLog(@"[App][LUA][ObjC] message was %@", message);
    [stack removeLastObject];
    id target = [stack lastObject];
    DebugLog(@"[App][LUA][ObjC] msg:[%@] for target:[%@]", message, target);
    [stack removeLastObject];
    
    SEL sel = NSSelectorFromString(message);
    
    NSMethodSignature *sig = [target methodSignatureForSelector:sel];
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    [inv retainArguments];
    NSUInteger numarg = [sig numberOfArguments];
    //DebugLog(@"[App][LUA][ObjC] Number of arguments = %d", numarg);
    
    for (int i = 2; i < numarg; i++)
    {
        const char *t = [sig getArgumentTypeAtIndex:i];
        //DebugLog(@"[App][LUA][ObjC] arg %d: %s", i, t);
        id arg = [stack lastObject];
        [stack removeLastObject];
        
        switch (t[0])
        {
            case 'c': // A char
            {
                char x = [(NSNumber *)arg charValue];
                [inv setArgument:&x atIndex:i];
            }
                break;
            case 'i': // An int
            {
                int x = [(NSNumber *)arg intValue];
                [inv setArgument:&x atIndex:i];
            }
                break;
            case 's': // A short
            {
                short x = [(NSNumber *)arg shortValue];
                [inv setArgument:&x atIndex:i];
            }
                break;
            case 'l': // A long l is treated as a 32-bit quantity on 64-bit programs.
            {
                long x = [(NSNumber *)arg longValue];
                [inv setArgument:&x atIndex:i];
            }
                break;
            case 'q': // A long long
            {
                long long x = [(NSNumber *)arg longLongValue];
                [inv setArgument:&x atIndex:i];
            }
                break;
            case 'C': // An unsigned char
            {
                unsigned char x = [(NSNumber *)arg unsignedCharValue];
                [inv setArgument:&x atIndex:i];
            }
                break;
            case 'I': // An unsigned int
            {
                unsigned int x = [(NSNumber *)arg unsignedIntValue];
                [inv setArgument:&x atIndex:i];
            }
                break;
            case 'S': // An unsigned short
            {
                unsigned short x = [(NSNumber *)arg unsignedShortValue];
                [inv setArgument:&x atIndex:i];
            }
                break;
            case 'L': // An unsigned long
            {
                unsigned long x = [(NSNumber *)arg unsignedLongValue];
                [inv setArgument:&x atIndex:i];
            }
                break;
            case 'Q': // An unsigned long long
            {
                unsigned long long x = [(NSNumber *)arg unsignedLongLongValue];
                [inv setArgument:&x atIndex:i];
            }
                break;
            case 'f': // A float
            {
                float x = [(NSNumber *)arg floatValue];
                [inv setArgument:&x atIndex:i];
            }
                break;
            case 'd': // A double
            {
                double x = [(NSNumber *)arg doubleValue];
                [inv setArgument:&x atIndex:i];
            }
                break;
            case 'B': // A C++ bool or a C99 _Bool
            {
                bool x = [(NSNumber *)arg boolValue];
                [inv setArgument:&x atIndex:i];
            }
                break;
                
            case '*': // A character string (char *)
            {
                const char *x = [(NSString *)arg cStringUsingEncoding:NSUTF8StringEncoding];
                [inv setArgument:&x atIndex:i];
            }
                break;
            case '@': // An object (whether statically typed or typed id)
            case '#': // A class object (Class)
                [inv setArgument:&arg atIndex:i];
                break;
                
            case '^': // pointer
                if ([arg isKindOfClass:[NSValue class]])
                {
                    void *ptr = [(NSValue *)arg pointerValue];
                    [inv setArgument:&ptr atIndex:i];
                }
                else
                {
                    //[inv setArgument:&arg atIndex:i];
                    [NSError errorWithDomain:@"Passing wild pointer" code:1 userInfo:nil];
                }
                break;
                
            case '{': // {name=type...} A structure
            {
                NSString *t_str = [NSString stringWithUTF8String:t];
                if ([t_str hasPrefix:@"{CGRect"])
                {
                    CGRect rect = [(NSValue *)arg CGRectValue];
                    [inv setArgument:&rect atIndex:i];
                }
                else if ([t_str hasPrefix:@"{CGSize"])
                {
                    CGSize size = [(NSValue *)arg CGSizeValue];
                    [inv setArgument:&size atIndex:i];
                }
                else if ([t_str hasPrefix:@"{CGPoint"])
                {
                    CGPoint point = [(NSValue *)arg CGPointValue];
                    [inv setArgument:&point atIndex:i];
                }
            }
                break;
                
            case 'v': // A void
            case ':': // A method selector (SEL)
            default:
                DebugLog(@"[App][LUA][ObjC] %s: Not implemented", t);
                break;
        }
    }
    
    [inv setTarget:target];
    [inv setSelector:sel];
    [inv invoke];
    
    const char *rettype = [sig methodReturnType];
    //DebugLog(@"[App][LUA][ObjC] [%@ %@] ret type = %s", target, message, rettype);
    void *buffer = NULL;
    if (rettype[0] != 'v')
    {
        // don't get return value from void function
        NSUInteger len = [[inv methodSignature] methodReturnLength];
        buffer = malloc(len);
        [inv getReturnValue:buffer];
        //DebugLog(@"[App][LUA][ObjC] ret = %c", *(unichar*)buffer);
    }
    
    
    switch (rettype[0])
    {
        case 'c': // A char
        {
            CNVBUF(char);
            [stack addObject:[NSNumber numberWithChar:x]];
        }
            break;
        case 'i': // An int
        {
            CNVBUF(int);
            [stack addObject:[NSNumber numberWithInt:x]];
        }
            break;
        case 's': // A short
        {
            CNVBUF(short);
            [stack addObject:[NSNumber numberWithShort:x]];
        }
            break;
        case 'l': // A long l is treated as a 32-bit quantity on 64-bit programs.
        {
            CNVBUF(long);
            [stack addObject:[NSNumber numberWithLong:x]];
        }
            break;
        case 'q': // A long long
        {
            CNVBUF(long long);
            [stack addObject:[NSNumber numberWithLong:x]];
        }
            break;
        case 'C': // An unsigned char
        {
            CNVBUF(unsigned char);
            [stack addObject:[NSNumber numberWithUnsignedChar:x]];
        }
            break;
        case 'I': // An unsigned int
        {
            CNVBUF(unsigned int);
            [stack addObject:[NSNumber numberWithUnsignedInt:x]];
        }
            break;
        case 'S': // An unsigned short
        {
            CNVBUF(unsigned short);
            [stack addObject:[NSNumber numberWithUnsignedShort:x]];
        }
            break;
        case 'L': // An unsigned long
        {
            CNVBUF(unsigned long);
            [stack addObject:[NSNumber numberWithUnsignedLong:x]];
        }
            break;
        case 'Q': // An unsigned long long
        {
            CNVBUF(unsigned long long);
            [stack addObject:[NSNumber numberWithUnsignedLongLong:x]];
        }
            break;
        case 'f': // A float
        {
            CNVBUF(float);
            [stack addObject:[NSNumber numberWithFloat:x]];
        }
            break;
        case 'd': // A double
        {
            CNVBUF(double);
            [stack addObject:[NSNumber numberWithDouble:x]];
        }
            break;
        case 'B': // A C++ bool or a C99 _Bool
        {
            CNVBUF(bool);
            [stack addObject:[NSNumber numberWithBool:x]];
        }
            break;
            
        case '*': // A character string (char *)
        {
            NSString *x = [NSString stringWithCString:buffer encoding:NSUTF8StringEncoding];
            [stack addObject:x];
        }
            break;
        case '@': // An object (whether statically typed or typed id)
        case '#': // A class object (Class)
        {
            id x = (__bridge id)*((void **)buffer);
            //            DebugLog(@"[App][LUA][ObjC] stack %@", stack);
            if (x)
            {
                //                DebugLog(@"[App][LUA][ObjC] x %@", x);
                [stack addObject:x];
            }
            else
            {
                [stack addObject:[NSNull null]];
            }
        }
            break;
            
        case '^':
        {
            void *x = *(void **)buffer;
            //            [stack addObject:[PointerObject pointerWithVoidPtr:x]];
            [stack addObject:[NSValue valueWithPointer:x]];
        }
            break;
        case 'v': // A void
            [stack addObject:[NSNull null]];
            break;
            
        case '{': // {name=type...} A structure
        {
            NSString *t = [NSString stringWithUTF8String:rettype];
            
            if ([t hasPrefix:@"{CGRect"])
            {
                CGRect *rect = (CGRect *)buffer;
                [stack addObject:[NSValue valueWithCGRect:*rect]];
            }
            else if ([t hasPrefix:@"{CGSize"])
            {
                CGSize *size = (CGSize *)buffer;
                [stack addObject:[NSValue valueWithCGSize:*size]];
            }
            else if ([t hasPrefix:@"{CGPoint"])
            {
                CGPoint *size = (CGPoint *)buffer;
                [stack addObject:[NSValue valueWithCGPoint:*size]];
            }
        }
            break;
            
        case ':': // A method selector (SEL)
        default:
            DebugLog(@"[App][Lua][ObjC] %s: Not implemented", rettype);
            [stack addObject:[NSNull null]];
            break;
    }
    
    free(buffer);
    
    id obj = [stack lastObject];
    to_lua(L, obj, false);
    
    return 1;
}
