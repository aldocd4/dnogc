module dnogc.Utils;

T nogcNew(T, Args...) (Args args) @trusted @nogc
{
    import std.conv : emplace;
    import core.stdc.stdlib : malloc;

    auto size = __traits(classInstanceSize, T);

    auto memory = malloc(size)[0..size];
    if(!memory)
    {
        import core.exception : onOutOfMemoryError;
        onOutOfMemoryError();
    }

    // call T's constructor and emplace instance on
    // newly allocated memory
    return emplace!(T, Args)(memory, args);
}

void nogcDel(T)(T obj) @trusted
{
    import core.stdc.stdlib : free;

    destroy(obj);

    // free memory occupied by object
    free(cast(void*)obj);
}

/**
 * Thanks to http://forum.dlang.org/post/nq4eol$2h34$1@digitalmars.com
 */
void assumeNogc(alias Func, T...)(T xs) @nogc
{
    import std.traits : isFunctionPointer, isDelegate, functionAttributes,
        FunctionAttribute, SetFunctionAttributes, functionLinkage;

    static auto assumeNogcPtr(T)(T f) if (isFunctionPointer!T || isDelegate!T)
    {
        enum attrs = functionAttributes!T | FunctionAttribute.nogc;
        return cast(SetFunctionAttributes!(T, functionLinkage!T, attrs)) f;
    }
    
    assumeNogcPtr(&Func!T)(xs);
}

void dln(string file = __FILE__, uint line = __LINE__, string fun = __FUNCTION__, Args...)(Args args) pure nothrow @trusted
{
    try
    {
        import std.stdio : writeln;

        debug assumeNogc!writeln(file, ":", line, ":", " debug: ", args);
    }
    catch (Exception)
    {
    }
}

