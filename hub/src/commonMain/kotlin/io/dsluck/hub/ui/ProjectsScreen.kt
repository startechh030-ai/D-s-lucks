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
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.selection.selectable
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.SportsEsports
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.AssistChip
import androidx.compose.material3.ElevatedCard
import androidx.compose.material3.ExtendedFloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import io.dsluck.hub.DslProject
import io.dsluck.hub.ProjectTemplate
import io.dsluck.hub.slugify

@Composable
fun ProjectsScreen() {
    val projects = remember {
        mutableStateListOf(
            DslProject("nebula-run", ProjectTemplate.PRIMITIVE_PLAYGROUND.label, "0.0.1-alpha", "~/dsluck-projects/nebula-run", "opened 2 h ago"),
            DslProject("ui-kit-lab", ProjectTemplate.UI_SANDBOX.label, "0.0.1-alpha", "~/dsluck-projects/ui-kit-lab", "opened 3 d ago"),
        )
    }
    var showCreate by remember { mutableStateOf(false) }

    Scaffold(
        floatingActionButton = {
            ExtendedFloatingActionButton(
                onClick = { showCreate = true },
                icon = { Icon(Icons.Filled.Add, contentDescription = null) },
                text = { Text("New Project") },
            )
        },
        containerColor = MaterialTheme.colorScheme.background,
    ) { padding ->
        Column(
            Modifier.fillMaxSize().padding(padding).padding(horizontal = 16.dp)
        ) {
            Spacer(Modifier.height(20.dp))
            Text("Projects", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
            Text(
                "Each project pins an engine core — swap freely, nothing is welded.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(Modifier.height(16.dp))

            LazyColumn(verticalArrangement = Arrangement.spacedBy(12.dp), contentPadding = PaddingValues(bottom = 96.dp)) {
                items(projects, key = { it.name }) { project ->
                    ProjectCard(project)
                }
            }
        }
    }

    if (showCreate) {
        NewProjectDialog(
            onDismiss = { showCreate = false },
            onCreate = { name, template ->
                val slug = slugify(name)
                projects.add(
                    0,
                    DslProject(
                        name = slug,
                        template = template.label,
                        engineVersion = "0.0.1-alpha",
                        location = "~/dsluck-projects/$slug",
                        lastOpened = "never opened",
                    )
                )
                showCreate = false
            },
        )
    }
}

@Composable
private fun ProjectCard(project: DslProject) {
    ElevatedCard(Modifier.fillMaxWidth()) {
        Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
            Icon(
                Icons.Filled.SportsEsports,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary,
            )
            Spacer(Modifier.width(16.dp))
            Column(Modifier.weight(1f)) {
                Text(project.name, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                Text(project.location, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Spacer(Modifier.height(8.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    AssistChip(onClick = {}, label = { Text(project.template) })
                    AssistChip(onClick = {}, label = { Text("core ${project.engineVersion}") })
                }
            }
            Text(
                project.lastOpened,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun NewProjectDialog(onDismiss: () -> Unit, onCreate: (name: String, template: ProjectTemplate) -> Unit) {
    var name by remember { mutableStateOf("") }
    var template by remember { mutableStateOf(ProjectTemplate.PRIMITIVE_PLAYGROUND) }
    val valid = slugify(name) != "untitled-project" || name.isNotBlank()

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("New project") },
        text = {
            Column {
                OutlinedTextField(
                    value = name,
                    onValueChange = { name = it },
                    label = { Text("Project name") },
                    singleLine = true,
                    isError = !valid,
                    supportingText = {
                        Text(if (valid) "will live at ~/dsluck-projects/${slugify(name)}" else "name required")
                    },
                )
                Spacer(Modifier.height(12.dp))
                Text("Template", style = MaterialTheme.typography.titleSmall)
                ProjectTemplate.entries.forEach { option ->
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .selectable(selected = option == template, onClick = { template = option })
                            .padding(vertical = 6.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        RadioButton(selected = option == template, onClick = { template = option })
                        Spacer(Modifier.width(8.dp))
                        Column {
                            Text(option.label, style = MaterialTheme.typography.bodyLarge)
                            Text(option.blurb, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }
                }
            }
        },
        confirmButton = {
            TextButton(enabled = valid, onClick = { onCreate(name, template) }) { Text("Create") }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("Cancel") }
        },
    )
}
