package com.petedrone.udpsender

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.*
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import kotlin.math.abs
import kotlin.math.min

@Composable
fun Joystick(
    size: Dp = 160.dp,
    deadzone: Float = 0.05f,
    onChange: (x: Float, y: Float) -> Unit
) {
    var knob by remember { mutableStateOf(Offset(0f, 0f)) }

    Box(
        modifier = Modifier
            .size(size)
            .background(MaterialTheme.colorScheme.surfaceVariant, shape = MaterialTheme.shapes.medium)
            .pointerInput(Unit) {
                detectDragGestures(onDragStart = { _ ->
                    knob = Offset(0f, 0f)
                }, onDragEnd = {
                    knob = Offset(0f, 0f)
                    onChange(0f, 0f)
                }) { change, drag ->
                    change.consume()
                    val w = this.size.width
                    val r = w / 2.0f
                    val nx = (knob.x + drag.x) / r
                    val ny = (knob.y + drag.y) / r
                    // Clamp to circle radius 1
                    val clx = nx.coerceIn(-1f, 1f)
                    val cly = ny.coerceIn(-1f, 1f)
                    knob = Offset(clx * r, cly * r)
                    var outX = clx
                    var outY = -cly // invert Y so up is +1
                    if (kotlin.math.abs(outX) < deadzone) outX = 0f
                    if (kotlin.math.abs(outY) < deadzone) outY = 0f
                    onChange(outX, outY)
                }
            },
        contentAlignment = Alignment.Center
    ) {
        Canvas(modifier = Modifier.fillMaxSize()) {
            val r = min(this.size.width, this.size.height) / 2f
            // Outer ring
            drawCircle(color = Color.DarkGray, radius = r)
            // Inner knob
            drawCircle(color = Color.Cyan, radius = r / 4f, center = center + knob)
        }
    }
}

@Composable
fun DualJoysticks(
    modifier: Modifier = Modifier,
    onLeft: (x: Float, y: Float) -> Unit,
    onRight: (x: Float, y: Float) -> Unit,
    deadzone: Float = 0.05f,
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Joystick(deadzone = deadzone, onChange = onLeft)
        Joystick(deadzone = deadzone, onChange = onRight)
    }
}
