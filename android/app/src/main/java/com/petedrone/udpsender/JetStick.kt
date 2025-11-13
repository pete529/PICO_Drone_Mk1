package com.petedrone.udpsender

import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.input.pointer.consumeAllChanges
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.shape.CircleShape
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.roundToInt

@Composable
fun JetStickPair(
    modifier: Modifier = Modifier,
    size: Dp = 180.dp,
    onLeft: (Float, Float) -> Unit,
    onRight: (Float, Float) -> Unit
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        JetStick(
            modifier = Modifier
                .weight(1f)
                .height(size)
                .padding(4.dp),
            onMove = onLeft
        )
        JetStick(
            modifier = Modifier
                .weight(1f)
                .height(size)
                .padding(4.dp),
            onMove = onRight
        )
    }
}

@Composable
fun JetStick(
    modifier: Modifier = Modifier,
    onMove: (Float, Float) -> Unit
) {
    val position = remember { mutableStateOf(Offset.Zero) }

    Box(
        modifier = modifier
            .background(MaterialTheme.colorScheme.surfaceVariant)
            .pointerInput(Unit) {
                detectDragGestures(
                    onDragEnd = {
                        position.value = Offset.Zero
                        onMove(0f, 0f)
                    }
                ) { change, dragAmount ->
                    change.consumeAllChanges()
                    val updated = position.value + dragAmount
                    val clamped = clampOffset(updated, 200f)
                    position.value = clamped
                    // normalise to -1..1 range
                    val normX = (clamped.x / 100f).coerceIn(-1f, 1f)
                    val normY = (-clamped.y / 100f).coerceIn(-1f, 1f)
                    onMove(normX, normY)
                }
            },
        contentAlignment = Alignment.Center
    ) {
        JoystickCanvas(position.value)
    }
}

private fun clampOffset(offset: Offset, radius: Float): Offset {
    if (offset == Offset.Zero) return Offset.Zero
    val dist = max(abs(offset.x), abs(offset.y))
    return if (dist <= radius) offset else Offset(
        x = offset.x / dist * radius,
        y = offset.y / dist * radius
    )
}

@Composable
private fun JoystickCanvas(position: Offset) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .padding(12.dp)
            .clip(CircleShape)
            .background(MaterialTheme.colorScheme.surfaceVariant),
        contentAlignment = Alignment.Center
    ) {
        Box(
            modifier = Modifier
                .size(52.dp)
                .align(Alignment.Center)
                .offset { IntOffset(position.x.roundToInt(), position.y.roundToInt()) }
                .clip(CircleShape)
                .background(MaterialTheme.colorScheme.primaryContainer),
            contentAlignment = Alignment.Center
        ) {
            Box(
                modifier = Modifier
                    .size(24.dp)
                    .clip(CircleShape)
                    .background(MaterialTheme.colorScheme.primary)
            )
        }
    }
}
