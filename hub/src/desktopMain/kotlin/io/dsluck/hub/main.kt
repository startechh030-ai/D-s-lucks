package io.dsluck.hub

import androidx.compose.ui.window.Window
import androidx.compose.ui.window.application

fun main() = application {
    Window(onCloseRequest = ::exitApplication, title = "D's Luck Hub") {
        App()
    }
}
