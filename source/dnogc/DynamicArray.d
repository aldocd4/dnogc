module dnogc.DynamicArray;

import std.experimental.allocator.mallocator;

import dnogc.Utils;

debug
{
    public static size_t totalBytesAllocated;
    public static size_t totalBytesFreed;	
}

/**
 * Dynamic array struct extremely inspired by this one :
 * https://github.com/economicmodeling/containers/blob/master/src/containers/dynamicarray.d
 */
struct DynamicArray(T)
{
    private size_t m_length;
    private size_t m_capacity;

    private T[] m_array;

    alias opDollar = length;

    public this(in int capacity, string file = __FILE__, int line = __LINE__) @trusted nothrow @nogc
    {
        this.m_capacity = capacity;
        
        if(capacity != 0)
        {
            this.m_array = cast(T[])Mallocator.instance.allocate(T.sizeof * capacity);

            debug
            {
                totalBytesAllocated += T.sizeof * capacity;
                dln("Allocated " , T.sizeof * capacity , " bytes from ", file, " at ", line);
            }
        }
    }
    
    public void dispose()
    {
        if(this.m_array is null)
        {
            return;
        }
    
        foreach(ref element; this.m_array[0 .. this.m_length])
        {
            static if(is(T == class) || is(T == interface))
            {
                destroy(element);
            }
            else
            {
                typeid(T).destroy(&element);
            }
        }

        if(this.m_capacity != 0)
        {			
            Mallocator.instance.deallocate(this.m_array);

            debug 
            {
                totalBytesFreed += T.sizeof * m_capacity;
                dln("Freed " , T.sizeof * this.m_capacity , " bytes");
            }
        }
    }

    public typeof(this) copy() @trusted nothrow @nogc
    {
        auto ret = DynamicArray!T(this.m_capacity);
        ret.m_length = this.m_length;

        if(this.m_capacity != 0)
        {
            import core.stdc.string;

            memcpy(ret.m_array.ptr, this.m_array.ptr, T.sizeof * this.m_capacity);			
        }

        return ret;
    }

    /**
     * Inserts element at the end of array
     */
    public void insert(T element, string file = __FILE__, int line = __LINE__) nothrow @trusted @nogc
    {
        if(this.m_array is null || this.m_array.length == 0)
        {
            this.m_capacity = 4;
            this.m_array = cast(T[]) Mallocator.instance.allocate(T.sizeof * this.m_capacity);

            debug totalBytesAllocated += T.sizeof * m_capacity;
            debug dln("Allocated " , T.sizeof * this.m_capacity, " bytes from ", file, " at ", line);
        }
        else if(this.m_length >= this.m_array.length)
        {
            debug
            {
                auto alreadyAllocated = T.sizeof * m_capacity;
            }

            this.m_capacity = this.m_array.length > 512 ? this.m_array.length + 1024 : this.m_array.length << 1;

            auto ptr = cast(void[])this.m_array;

            debug totalBytesAllocated += (T.sizeof * m_capacity) - alreadyAllocated;

            Mallocator.instance.reallocate(ptr, T.sizeof * this.m_capacity);

            debug dln("Reallocated " , T.sizeof * this.m_capacity, " bytes from ", file, " at ", line);

            this.m_array = cast(T[])ptr;
        }

        this.m_array[this.m_length++] = element;
    }

    
    /**
     * Slice operator overload
     */
    pragma(inline, true)
    public auto opSlice(this This)() nothrow @safe @nogc
    {
        return opSlice!(This)(0, this.m_length);
    }

    pragma(inline, true)
    public auto opSlice(this This)(size_t a, size_t b) nothrow @safe @nogc
    {
        return this.m_array[a .. b];
    }

    /**
     * Index operator overload
     */
    pragma(inline, true)
    public auto opIndex(this This)(size_t i) nothrow @safe @nogc
    {
        return this.m_array[i];
    }

    /**
     * ~= operator overload
     */
    nothrow @safe @nogc
    public void opOpAssign(string op)(T value) if (op == "~")
    {
        this.insert(value);
    }

    /**
     * ~ operator overload
     */
    nothrow @safe @nogc
    public typeof(this) opBinary(string op)(ref typeof(this) other) if (op == "~")
    {
        typeof(this) ret;

        foreach(element; this.m_array[0 .. this.m_length])
        {
            ret.insert(element);
        }

        foreach(element; other.m_array[0 .. other.m_length])
        {
            ret.insert(element);
        }

        return ret;
    }

    nothrow @safe @nogc
    public typeof(this) opBinary(string op)(T[] elements) if (op == "~")
    {
        typeof(this) ret;

        foreach(element; this.m_array[0 .. this.m_length])
        {
            ret.insert(element);
        }

        foreach(element; elements)
        {
            ret.insert(element);
        }

        return ret;
    }

    /**
     * Removes the item at the given index from the array
     */
    public void remove(in size_t i)
    {
        if(i < this.m_length)
        {
            static if (is(T == class) || is(T == interface))
            {
                destroy(this.m_array[i]);
            }
            else
            {
                typeid(T).destroy(&this.m_array[i]);
            }

            auto next = i + 1;

            while(next < this.m_length)
            {
                this.m_array[next - 1] = this.m_array[next];
                ++next;
            }

            this.m_length -= 1;
        }
        else
        {
            import core.exception : RangeError;
            throw new RangeError("Out of range index used to remove element");
        }
    }

    /**
     * Removes the last element from the array
     */
    public void removeBack()
    {
        this.remove(this.m_length - 1);
    }

    /**
     * Index assignment support
     */
    public void opIndexAssign(T value, size_t i) nothrow @safe @nogc
    {
        this.m_array[i] = value;
    }

    /**
     * Slice assignment support
     */
    public void opSliceAssign(T value) nothrow @safe @nogc
    {
        this.m_array[0 .. this.m_length] = value;
    }

    public void opSliceAssign(T value, size_t i, size_t j) nothrow @safe @nogc
    {
        this.m_array[i .. j] = value;
    }

    @property
    {
        public size_t length() const pure nothrow @safe @nogc 
        {
            return this.m_length; 
        }

        /**
         * Use this property only if you use functions like fread
         */
        public void length(in size_t value) pure nothrow @safe @nogc
        {
            assert(value <= this.m_capacity);
            this.m_length = value;
        }

        public bool empty() const pure nothrow @safe @nogc 
        { 
            return this.m_length == 0; 
        }

        public void* ptr(this This)() nothrow @safe @nogc
        {
            return &this.m_array[0];
        }

        public auto ref T front() nothrow @safe @nogc
        {
            return this.m_array[0];
        }

        public auto ref T back() nothrow @safe @nogc
        {
            return this.m_array[this.m_length - 1];
        }
    }
}

