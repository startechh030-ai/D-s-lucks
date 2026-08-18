package io.dsluck.hub.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

val LuckBlack = Color(0xFF0B0E11)
val LuckSurface = Color(0xFF141A20)
val LuckSurfaceVariant = Color(0xFF1C242D)
val LuckEmerald = Color(0xFF3DDC84)   // clover green
val LuckGold = Color(0xFFE3B341)      // a little bit of luck
val LuckText = Color(0xFFE8EEF2)
val LuckTextDim = Color(0xFF9AA7B0)

private val LuckDark = darkColorScheme(
    primary = LuckEmerald,
    onPrimary = Color(0xFF06281A),
    secondary = LuckGold,
    onSecondary = Color(0xFF2B1F04),
    background = LuckBlack,
    onBackground = LuckText,
    surface = LuckSurface,
    onSurface = LuckText,
    surfaceVariant = LuckSurfaceVariant,
    onSurfaceVariant = LuckTextDim,
)

@Composable
fun DsluckTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = LuckDark, content = content)
}
