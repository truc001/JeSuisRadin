package com.example.comparateur_app.ui.theme

import android.app.Activity
import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import androidx.core.view.WindowCompat

private val DarkColorScheme = darkColorScheme(
    primary = PinkPrimary,
    onPrimary = BackgroundLight,
    primaryContainer = PinkDark,
    onPrimaryContainer = BackgroundLight,
    secondary = CyanSecondary,
    onSecondary = BackgroundDark,
    secondaryContainer = CyanDark,
    onSecondaryContainer = BackgroundDark,
    background = BackgroundDark,
    surface = SurfaceDark,
    onBackground = BackgroundLight,
    onSurface = BackgroundLight
)

private val LightColorScheme = lightColorScheme(
    primary = PinkPrimary,
    onPrimary = BackgroundLight,
    primaryContainer = PinkPrimary.copy(alpha = 0.1f),
    onPrimaryContainer = PinkDark,
    secondary = CyanSecondary,
    onSecondary = BackgroundDark,
    secondaryContainer = CyanSecondary.copy(alpha = 0.1f),
    onSecondaryContainer = CyanDark,
    background = BackgroundLight,
    surface = SurfaceLight,
    onBackground = BackgroundDark,
    onSurface = BackgroundDark
)

val Typography = Typography(
    headlineLarge = TextStyle(
        fontWeight = FontWeight.Bold,
        fontSize = 32.sp,
        letterSpacing = (-0.5).sp
    ),
    titleLarge = TextStyle(
        fontWeight = FontWeight.Bold,
        fontSize = 22.sp,
        letterSpacing = 0.sp
    ),
    bodyLarge = TextStyle(
        fontWeight = FontWeight.Normal,
        fontSize = 16.sp,
        letterSpacing = 0.5.sp
    ),
    labelMedium = TextStyle(
        fontWeight = FontWeight.Medium,
        fontSize = 12.sp,
        letterSpacing = 0.5.sp
    )
)

@Composable
fun ComparateurTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    dynamicColor: Boolean = true, // Activé par défaut pour M3
    content: @Composable () -> Unit
) {
    val colorScheme = when {
        dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
            val context = LocalContext.current
            if (darkTheme) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)
        }
        darkTheme -> DarkColorScheme
        else -> LightColorScheme
    }
    val view = LocalView.current
    if (!view.isInEditMode) {
        SideEffect {
            val window = (view.context as Activity).window
            window.statusBarColor = colorScheme.background.toArgb() // Plus élégant en M3
            WindowCompat.getInsetsController(window, view).isAppearanceLightStatusBars = !darkTheme
        }
    }

    MaterialTheme(
        colorScheme = colorScheme,
        typography = Typography,
        shapes = Shapes,
        content = content
    )
}
