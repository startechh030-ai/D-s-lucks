package io.dsluck.hub

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Folder
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Memory
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import io.dsluck.hub.theme.DsluckTheme
import io.dsluck.hub.ui.AboutScreen
import io.dsluck.hub.ui.EnginesScreen
import io.dsluck.hub.ui.ProjectsScreen

enum class HubTab(val label: String, val icon: ImageVector) {
    Projects("Projects", Icons.Filled.Folder),
    Engines("Cores", Icons.Filled.Memory),
    About("About", Icons.Filled.Info),
}

@Composable
fun App() {
    DsluckTheme {
        var tab by rememberSaveable { mutableStateOf(HubTab.Projects.name) }
        val current = HubTab.valueOf(tab)

        Scaffold(
            containerColor = MaterialTheme.colorScheme.background,
            bottomBar = {
                NavigationBar {
                    HubTab.entries.forEach { entry ->
                        NavigationBarItem(
                            selected = entry == current,
                            onClick = { tab = entry.name },
                            icon = { Icon(entry.icon, contentDescription = entry.label) },
                            label = { Text(entry.label) },
                        )
                    }
                }
            },
        ) { padding ->
            Box(Modifier.fillMaxSize().padding(padding)) {
                when (current) {
                    HubTab.Projects -> ProjectsScreen()
                    HubTab.Engines -> EnginesScreen()
                    HubTab.About -> AboutScreen()
                }
            }
        }
    }
}
