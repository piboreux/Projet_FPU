# -*- coding: utf-8 -*-


import RPi.GPIO as GPIO
from time import sleep
import spidev
import struct

MyARM_ResetPin = 19

# ---------------- SPI init ----------------
MySPI_FPGA = spidev.SpiDev()
MySPI_FPGA.open(0, 0)
MySPI_FPGA.max_speed_hz = 500000

# ---------------- GPIO init ----------------
GPIO.setmode(GPIO.BCM)
GPIO.setwarnings(False)
GPIO.setup(MyARM_ResetPin, GPIO.OUT)

# ---------------- Operandes ----------------
A_float = 1.1
B_float = 2.3
CMD_ADD = 1   # 1=ADD, 2=SUB, 3=MUL

# ======================================================
# CONVERSION BIG-ENDIAN (CONFORME AU PROJET)
# ======================================================
A_bytes   = struct.pack('>f', A_float)
B_bytes   = struct.pack('>f', B_float)
CMD_bytes = struct.pack('>I', CMD_ADD)

# ---------------- Reset FPGA ----------------
GPIO.output(MyARM_ResetPin, GPIO.HIGH)
sleep(0.1)
GPIO.output(MyARM_ResetPin, GPIO.LOW)
sleep(0.1)

# ======================================================
# 1) ecriture de A (SPI index 0 ? 0x400)
# ======================================================
ToSPI_A = [0x80 | 0] + list(A_bytes)
print(f"ecriture de A ({A_float}) : {ToSPI_A}")
MySPI_FPGA.xfer2(ToSPI_A)
sleep(0.05)

# ======================================================
# 2) ecriture de B (SPI index 1 ? 0x404)
# ======================================================
ToSPI_B = [0x80 | 1] + list(B_bytes)
print(f"ecriture de B ({B_float}) : {ToSPI_B}")
MySPI_FPGA.xfer2(ToSPI_B)
sleep(0.05)

# ======================================================
# 3) ecriture de la commande ADD (SPI index 2 ? 0x408)
# ======================================================
ToSPI_CMD = [0x80 | 2] + list(CMD_bytes)
print(f"Envoi Commande ADD : {ToSPI_CMD}")
MySPI_FPGA.xfer2(ToSPI_CMD)
sleep(0.1)

# ======================================================
# 4) Lecture du Résultat (SPI index 3 ? 0x40C)
# ======================================================
ToSPI_READ = [0x03, 0x00, 0x00, 0x00, 0x00]
FromSPI = MySPI_FPGA.xfer2(ToSPI_READ)

Result_bytes = bytes(FromSPI[1:5])
Result_float = struct.unpack('>f', Result_bytes)[0]


if CMD_ADD == 1:
  op_str = "+"
  expected = A_float + B_float
elif CMD_ADD == 2:
  op_str = "-"
  expected = A_float - B_float
elif CMD_ADD == 3:
  op_str = "*"
  expected = A_float * B_float
    
    
    
print("\n resultat recu (octets) :", FromSPI)
print(f" resultat FPU ({A_float} + {B_float}) : {Result_float}")
print(f" Attendu : {expected}")


# ---------------- Final reset ----------------
GPIO.output(MyARM_ResetPin, GPIO.HIGH)
sleep(0.1)
GPIO.output(MyARM_ResetPin, GPIO.LOW)
