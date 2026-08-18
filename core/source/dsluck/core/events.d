/**
 * D's Luck — event bus (ring buffer).
 *
 * Core systems and plugins communicate via small integer events.
 * Modules (physics, scripting, UI) poll once per frame. Zero allocation.
 */
module dsluck.core.events;

enum DslEvent : int
{
    none            = 0,
    coreStarted     = 1,
    coreShutdown    = 2,
    entitySpawned   = 10,
    entityKilled    = 11,
    // 1000+ reserved for plugin/vendor events
    vendorStart     = 1000,
}

struct EventBus
{
    enum capacity = 256;
    private int[capacity] _ring;
    private uint _head;   // next write
    private uint _tail;   // next read

    void push(int code) @nogc nothrow
    {
        _ring[_head % capacity] = code;
        _head++;
        // Overrun: drop oldest (mobile-safe: never block, never alloc).
        if (_head - _tail > capacity)
            _tail = _head - capacity;
    }

    /// Returns event code, or 0 (DslEvent.none) when empty.
    int poll() @nogc nothrow
    {
        if (_tail == _head)
            return 0;
        auto code = _ring[_tail % capacity];
        _tail++;
        return code;
    }
}
