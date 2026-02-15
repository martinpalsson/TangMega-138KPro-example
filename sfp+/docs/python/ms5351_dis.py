import os, serial, time
import argparse

def test():
    try:  
        parser = argparse.ArgumentParser()
        parser.add_argument('--com', type=str, default=None)
        print("Disable MS5351 ")
        s = parser.parse_args().com
        ser=serial.Serial("COM"+s,115200)
        time.sleep(.500)
        ser.write((b'\x18')) # Ctrl + x
        ser.write((b'\x03')) # Ctrl + c
        ser.write((b'\n')) # Ctrl + c
        (ser.write((b"pll_clk O0\n")))
        (ser.write((b"pll_clk O1\n")))
        (ser.write((b"pll_clk O2\n")))
        (ser.write((b"pll_clk -s\n")))
        time.sleep(.500)
        print("Operation successful, switch to the next board to start testing")
    except:
        ser.close()
        print("Failed to disable MS5351\r\n")

test()   