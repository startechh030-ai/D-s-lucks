package io.dsluck.hub.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material3.AssistChip
import androidx.compose.material3.Button
import androidx.compose.material3.ElevatedCard
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import io.dsluck.hub.CoreProbeHandle
import io.dsluck.hub.ProbeSnapshot
import io.dsluck.hub.deviceAbis
import io.dsluck.hub.nativeCoreStatus
import io.dsluck.hub.platformName
import kotlinx.coroutines.delay
import kotlin.time.TimeSource

private data class ModuleSlot(val name: String, val current: String, val swapNote: String)

private val moduleSlots = listOf(
    ModuleSlot("Renderer", "Filament (planned) — via C shim librenderer_filament.so", "swap: any .so exporting dsl_renderer_*"),
    ModuleSlot("Physics 3D", "Box3D (planned)", "swap: Jolt, or your own physics core"),
    ModuleSlot("Physics 2D", "Box2D (planned)", "swap: custom 2D logic in scripts"),
    ModuleSlot("Scripting", "Wren (first)", "swap: LuckScript / D, same API surface"),
    ModuleSlot("Assets", "glTF / GLB + .mat shaders", "runtime converters, renamed .glb still reads"),
)

@Composable
fun EnginesScreen() {
    LazyColumn(
        Modifier.fillMaxSize().padding(horizontal = 16.dp),
        contentPadding = PaddingValues(top = 20.dp, bottom = 24.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        item {
            Text("Engine cores", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
            Text(
                "A core is just a conforming .so at ABI v1. Install many, pin per project.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(Modifier.height(8.dp))
        }

        item {
            ElevatedCard(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(16.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Filled.CheckCircle, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                        Spacer(Modifier.width(16.dp))
                        Column(Modifier.weight(1f)) {
                            Text("D's Luck Core", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                            Text("0.0.1-alpha · ABI v1", style = MaterialTheme.typography.bodyMedium)
                        }
                    }
                    Spacer(Modifier.height(4.dp))
                    Text(
                        nativeCoreStatus(),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Spacer(Modifier.height(8.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        AssistChip(onClick = {}, label = { Text("D · betterC") })
                        AssistChip(onClick = {}, label = { Text("manual memory") })
                        AssistChip(onClick = {}, label = { Text("no default GC") })
                    }

                    Spacer(Modifier.height(12.dp))
                    LiveProbeSection()
                }
            }
        }

        item {
            Spacer(Modifier.height(8.dp))
            Text("Module slots", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
            Text(
                "The replaceable-core promise: each slot is a contract, not a prison.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }

        items(moduleSlots.size) { i ->
            val slot = moduleSlots[i]
            ElevatedCard(Modifier.fillMaxWidth()) {
                Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Filled.Tune, contentDescription = null, tint = MaterialTheme.colorScheme.secondary)
                    Spacer(Modifier.width(16.dp))
                    Column {
                        Text(slot.name, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
                        Text(slot.current, style = MaterialTheme.typography.bodyMedium)
                        Text(slot.swapNote, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }
        }

        item {
            Spacer(Modifier.height(8.dp))
            Text(
                "Running on: ${platformName()}",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Text(
                "Device CPU ABIs: ${deviceAbis()}",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

/**
 * A real DslCore instance, created on-device through the JNI bridge and
 * ticked in real time. This is the smoke test, alive, on your screen.
 */
@Composable
private fun LiveProbeSection() {
    val probe = remember { CoreProbeHandle() }
    val available = remember { probe.available() }
    var running by remember { mutableStateOf(false) }
    var snap by remember { mutableStateOf(ProbeSnapshot(0, 0f, 0, 0)) }

    LaunchedEffect(running) {
        if (!running) return@LaunchedEffect
        if (!probe.start()) {
            running = false
            return@LaunchedEffect
        }
        var last = TimeSource.Monotonic.markNow()
        while (true) {
            delay(16)
            val now = TimeSource.Monotonic.markNow()
            val dt = (now - last).inWholeNanoseconds / 1_000_000_000.0
            last = now
            probe.tick(dt)
            snap = probe.snapshot()
        }
    }

    DisposableEffect(Unit) {
        onDispose { probe.stop() }
    }

    Text("Live core probe", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
    Spacer(Modifier.height(4.dp))

    if (!available) {
        Text(
            "Install a CI-built APK to tick the real core on this device.",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        return
    }

    Row(verticalAlignment = Alignment.CenterVertically) {
        Button(
            onClick = { running = !running },
        ) {
            Icon(
                if (running) Icons.Filled.Stop else Icons.Filled.PlayArrow,
                contentDescription = null,
            )
            Spacer(Modifier.width(6.dp))
            Text(if (running) "Stop" else "Tick the core")
        }
        Spacer(Modifier.width(16.dp))
        if (running) {
            val fpsText = ((snap.fps * 10).toInt() / 10f).toString()
            Column {
                Text("$fpsText fps", style = MaterialTheme.typography.titleLarge, color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Bold)
                Text(
                    "frame ${snap.frame} · ${snap.entities} entities · ${snap.memBytes / 1024} KB live",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        } else {
            Text(
                "creates a core, spawns box+capsule, ticks in real time",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}
