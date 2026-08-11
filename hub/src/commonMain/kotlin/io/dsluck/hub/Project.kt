package io.dsluck.hub

data class DslProject(
    val name: String,
    val template: String,
    val engineVersion: String,
    val location: String,
    val lastOpened: String,
)

enum class ProjectTemplate(val label: String, val blurb: String) {
    EMPTY_3D("Empty 3D", "A sky, a camera, a clean slate."),
    PRIMITIVE_PLAYGROUND(
        "Primitive Playground",
        "Cone, capsule & box on a grid — the first-stage sandbox from the spec."
    ),
    UI_SANDBOX("2D UI Sandbox", "Perfect-2D-UI kit: panels, buttons, HUD wiring."),
}

fun slugify(name: String): String =
    name.lowercase()
        .replace(Regex("[^a-z0-9]+"), "-")
        .trim('-')
        .ifBlank { "untitled-project" }
