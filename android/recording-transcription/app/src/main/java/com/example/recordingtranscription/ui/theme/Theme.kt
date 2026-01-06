package com.example.recordingtranscription.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val LightColors = lightColorScheme(
  primary = Color(0xFF004E92),
  onPrimary = Color.White,
  secondary = Color(0xFF3478F6),
  onSecondary = Color.White,
  surface = Color(0xFFF5F5F5),
  onSurface = Color(0xFF101010),
)

private val DarkColors = darkColorScheme(
  primary = Color(0xFF82B1FF),
  onPrimary = Color(0xFF001F3F),
  secondary = Color(0xFF5E92F3),
  onSecondary = Color(0xFF001A33),
  surface = Color(0xFF16181C),
  onSurface = Color(0xFFE6E6E6),
)

@Composable
fun RecorderTheme(
  useDarkTheme: Boolean,
  content: @Composable () -> Unit,
) {
  val colors = if (useDarkTheme) DarkColors else LightColors
  MaterialTheme(
    colorScheme = colors,
    typography = MaterialTheme.typography,
    content = content,
  )
}
