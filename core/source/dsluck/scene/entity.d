/**
 * D's Luck — entities.
 *
 * Fixed-capacity pool, no heap churn on mobile. An entity is a slot id;
 * components (Transform, and later Light/Collision/Material overlays)
 * attach per slot. Composition over inheritance, per spec.
 *
 * M0 note: these are placeholder primitive carriers (cone/capsule/box
 * from the first-stage spec). Meshes arrive with the asset milestone.
 */
module dsluck.scene.entity;

enum uint DSL_MAX_ENTITIES = 4096;

struct Transform
{
    float[3] position = [0f, 0f, 0f];
    float[4] rotation = [0f, 0f, 0f, 1f];  /// quaternion xyzw
    float[3] scale    = [1f, 1f, 1f];
}

enum EntityKind : ubyte
{
    empty = 0,
    box,
    capsule,
    cone,
    importedModel,   // glb/gltf, arrives with asset milestone
}

struct Entity
{
    bool alive;
    EntityKind kind;
    Transform transform;
}

struct EntityPool
{
    private Entity[DSL_MAX_ENTITIES] _slots;
    private uint _alive;

    /// Spawn an entity; returns slot id or -1 when the pool is full.
    int spawn(EntityKind kind, float x, float y, float z) @nogc nothrow
    {
        foreach (i, ref e; _slots)
        {
            if (!e.alive)
            {
                e = Entity.init;
                e.alive = true;
                e.kind = kind;
                e.transform.position = [x, y, z];
                _alive++;
                return cast(int)i;
            }
        }
        return -1;
    }

    bool kill(int id) @nogc nothrow
    {
        if (id < 0 || id >= DSL_MAX_ENTITIES)
            return false;
        if (!_slots[id].alive)
            return false;
        _slots[id].alive = false;
        _alive--;
        return true;
    }

    uint aliveCount() const @nogc nothrow { return _alive; }
    uint capacity()   const @nogc nothrow { return DSL_MAX_ENTITIES; }
}
