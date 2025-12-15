import RPi.GPIO as GPIO  
from time import sleep  
import spidev  

MyARM_ResetPin = 19  # Pin 4 of the connector = BCM19 = GPIO[1]

# Initialize the SPI device for communication with the FPGA
MySPI_FPGA = spidev.SpiDev()  
MySPI_FPGA.open(0, 0)  # Open SPI bus 
MySPI_FPGA.max_speed_hz = 500000  # Set SPI communication speed 

# Configure GPIO settings
GPIO.setmode(GPIO.BCM) 
GPIO.setwarnings(False)  
GPIO.setup(MyARM_ResetPin, GPIO.OUT)  

# Reset the FPGA
GPIO.output(MyARM_ResetPin, GPIO.HIGH) 
sleep(0.1)  
GPIO.output(MyARM_ResetPin, GPIO.LOW)  
sleep(0.1) 

# Send the first SPI packet: Writing integer A at address 0x400
ToSPI = [0x00, 0x00, 0x00, 0x00, 0x00]  # YOU NEED TO MODIFY THIS LINE
FromSPI = MySPI_FPGA.xfer2(ToSPI) 
sleep(0.1)  

# Send the second SPI packet: Writing integer B at address 0x404
ToSPI = [0x00, 0x00, 0x00, 0x00, 0x00]  # YOU NEED TO MODIFY THIS LINE 
FromSPI = MySPI_FPGA.xfer2(ToSPI)  
sleep(0.1)  


GPIO.output(MyARM_ResetPin, GPIO.HIGH)  
sleep(0.1)  
GPIO.output(MyARM_ResetPin, GPIO.LOW)  


# Send SPI packet to request the GCD result from FPGA (address 0x408)
ToSPI = [0x00, 0x00, 0x00, 0x00, 0x00]  # YOU NEED TO MODIFY THIS LINE
FromSPI = MySPI_FPGA.xfer2(ToSPI)  
print("Greatest common divisor is", FromSPI)  # Print the GCD result

# Final reset sequence for the FPGA
GPIO.output(MyARM_ResetPin, GPIO.HIGH) 
sleep(0.1)  
GPIO.output(MyARM_ResetPin, GPIO.LOW)
