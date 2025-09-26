# Pin and bus configuration for Raspberry Pi Pico 2W board
# Based on hardware/main.ato

I2C_ID = 1
I2C_SDA_PIN = 26  # GP26
I2C_SCL_PIN = 27  # GP27
I2C_FREQ = 400000

IMU_INT_PIN = 16  # GP16

LED_RED_PIN = 14  # GP14
LED_GREEN_PIN = 15  # GP15

# Arm/kill button input (power button pin GP13 reused as arm if desired)
BUTTON_ARM_PIN = 13  # GP13

# UART debug/GPS (choose non-conflicting pins)
# On Pico, UART1 can map to GP20 (TX) / GP21 (RX)
UART_ID = 1
UART_TX_PIN = 20  # GP20
UART_RX_PIN = 21  # GP21
UART_BAUD = 115200

# DRV8833 motor control pins (from hardware/main.ato)
# Left driver control (motors L1, L2)
DRV_LEFT_AIN1 = 0   # GP0
DRV_LEFT_AIN2 = 1   # GP1
DRV_LEFT_BIN1 = 2   # GP2
DRV_LEFT_BIN2 = 3   # GP3
DRV_LEFT_SLEEP = 8  # GP8

# Right driver control (motors R1, R2)
DRV_RIGHT_AIN1 = 4  # GP4
DRV_RIGHT_AIN2 = 5  # GP5
DRV_RIGHT_BIN1 = 6  # GP6
DRV_RIGHT_BIN2 = 7  # GP7
DRV_RIGHT_SLEEP = 9 # GP9

# PWM defaults for brushed motors
MOTOR_PWM_FREQ_HZ = 20000  # 20 kHz to reduce audible noise
MOTOR_DEADTIME_US = 0      # DRV8833 generally doesn't require added deadtime
