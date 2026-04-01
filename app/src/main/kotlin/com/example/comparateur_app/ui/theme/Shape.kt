package com.example.comparateur_app.ui.theme

import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Shapes
import androidx.compose.ui.unit.dp

// MD3 organic shapes - asymmetric corners for a more natural, dynamic feel
val Shapes = Shapes(
    extraSmall = RoundedCornerShape(8.dp),
    small = RoundedCornerShape(12.dp),
    medium = RoundedCornerShape(16.dp),
    large = RoundedCornerShape(
        topStart = 28.dp,
        topEnd = 28.dp,
        bottomStart = 28.dp,
        bottomEnd = 28.dp
    ),
    extraLarge = RoundedCornerShape(
        topStart = 32.dp,
        topEnd = 32.dp,
        bottomStart = 32.dp,
        bottomEnd = 32.dp
    )
)

// Custom organic shapes for special components
val BottomSheetShape = RoundedCornerShape(
    topStart = 28.dp,
    topEnd = 28.dp,
    bottomStart = 0.dp,
    bottomEnd = 0.dp
)

val BlobCardShape = RoundedCornerShape(
    topStart = 24.dp,
    topEnd = 16.dp,
    bottomStart = 16.dp,
    bottomEnd = 24.dp
)

val FabShape = RoundedCornerShape(
    topStart = 16.dp,
    topEnd = 28.dp,
    bottomStart = 28.dp,
    bottomEnd = 16.dp
)

val ChipShape = RoundedCornerShape(
    topStart = 8.dp,
    topEnd = 16.dp,
    bottomStart = 16.dp,
    bottomEnd = 8.dp
)

val DialogShape = RoundedCornerShape(28.dp)
