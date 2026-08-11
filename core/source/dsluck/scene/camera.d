/**
 * D's Luck — camera.
 *
 * Plain data. The renderer module (Filament or user-swapped) maps this
 * to its own camera objects each frame. Core owns truth; renderer owns GPU.
 */
module dsluck.scene.camera;

struct Camera
{
    float[3] position = [0f, 0f, 5f];
    float[3] target   = [0f, 0f, 0f];
    float[3] up       = [0f, 1f, 0f];

    float fovY   = 60f;     /// degrees, vertical
    float nearZ  = 0.1f;
    float farZ   = 1000f;

    float aperture      = 16f;   /// Filament-style physical camera defaults
    float shutterSpeed  = 1f / 60f;
    float sensitivity   = 100f;  /// ISO
}
