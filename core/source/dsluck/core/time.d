/**
 * D's Luck — frame clock.
 *
 * Fixed-step friendly: the game loop decides fixed vs variable dt;
 * here we only track truth: frame count, elapsed time, measured FPS.
 */
module dsluck.core.time;

struct FrameClock
{
    double time = 0;  /// seconds since core start
    double delta = 0; /// last tick dt (seconds)
    ulong  frame;     /// ticks since start

    float  fps = 0;   /// measured frames/second (1s window)
    private double _fpsAccum = 0;
    private uint   _fpsFrames;

    void tick(double dt) @nogc nothrow
    {
        delta = dt;
        time += dt;
        frame++;

        _fpsAccum += dt;
        _fpsFrames++;
        if (_fpsAccum >= 1.0)
        {
            fps = _fpsFrames / cast(float)_fpsAccum;
            _fpsAccum = 0;
            _fpsFrames = 0;
        }
    }
}
