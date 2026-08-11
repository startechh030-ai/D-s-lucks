package io.dsluck.hub.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Circle
import androidx.compose.material3.ElevatedCard
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp

private data class Spec(val done: Boolean, val text: String)

private val specs = listOf(
    Spec(true,  "Engine core in D (betterC): no GC, manual memory, .so output"),
    Spec(true,  "Stable C ABI (v1) — the replaceable-core seam"),
    Spec(true,  "Hub: project launcher, Unreal-style (this app)"),
    Spec(false, "JNI bridge: hub talks to libdsluck.so directly"),
    Spec(false, "Editor: left file tree, bottom asset shelf, 2D UI canvas"),
    Spec(false, "Viewport: Filament backend via C shim, skybox + HDR"),
    Spec(false, "Primitives: cone / capsule / box, orbit camera, input"),
    Spec(false, "Physics: Box3D / Box2D modules (swappable with Jolt)"),
    Spec(false, "Scripting: Wren first — LuckScript/D later, same API"),
    Spec(false, "Sound, procedural cloud gen, .anim read/write"),
)

@Composable
fun AboutScreen() {
    LazyColumn(
        Modifier.fillMaxSize().padding(horizontal = 16.dp),
        contentPadding = PaddingValues(top = 20.dp, bottom = 24.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        item {
            Text("D's Luck", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
            Text(
                "A modular, low-power game engine where every part of the architecture — " +
                    "renderer, physics, scripting, even the core itself — can be replaced " +
                    "without breaking the rest.",
                style = MaterialTheme.typography.bodyLarge,
            )
            Spacer(Modifier.height(8.dp))
            Text(
                "Not built to beat other engines. Built to prove that a fully customizable, " +
                    "high-performance engine can run, compile, and edit directly on mobile devices.",
                style = MaterialTheme.typography.bodyMedium,
                fontStyle = FontStyle.Italic,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }

        item {
            ElevatedCard {
                Column(Modifier.padding(16.dp)) {
                    Text("Spec tracker", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                    Spacer(Modifier.height(8.dp))
                    specs.forEach { SpecRow(it) }
                }
            }
        }

        item {
            Text(
                "Platforms: Android (first) · Windows · macOS · Linux",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun SpecRow(spec: Spec) {
    Row(Modifier.padding(vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
        Icon(
            imageVector = if (spec.done) Icons.Filled.CheckCircle else Icons.Filled.Circle,
            contentDescription = null,
            tint = if (spec.done) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(Modifier.width(12.dp))
        Text(
            spec.text,
            style = MaterialTheme.typography.bodyMedium,
            color = if (spec.done) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}
