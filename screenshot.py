import time
import ctypes
import sys

# Wait for the app to fully load
time.sleep(2)

# Take screenshot using Windows API
user32 = ctypes.windll.user32
gdi32 = ctypes.windll.gdi32

# Get screen dimensions
width = user32.GetSystemMetrics(0)
height = user32.GetSystemMetrics(1)

# Create device context
dc = user32.GetDC(0)
cdc = gdi32.CreateCompatibleDC(dc)
bmp = gdi32.CreateCompatibleBitmap(dc, width, height)
gdi32.SelectObject(cdc, bmp)
gdi32.BitBlt(cdc, 0, 0, width, height, dc, 0, 0, 0x00CC0020)

# Save to file
import struct

# BMP header
bmp_header = struct.pack('<2sIHHI', b'BM', 54 + width * height * 4, 0, 0, 54)
# DIB header
dib_header = struct.pack('<IiiHHIIiiII', 40, width, -height, 1, 32, 0, 0, 0, 0, 0, 0)

# Get pixel data
buffer = ctypes.create_string_buffer(width * height * 4)
gdi32.GetDIBits(cdc, bmp, 0, height, buffer, ctypes.byref(struct.unpack('32x' + 'I' * 8 + 'x' * 8, dib_header)), 0)

with open(r'D:\PGitCode\cat_sleep\screenshot.bmp', 'wb') as f:
    f.write(bmp_header)
    f.write(dib_header)
    f.write(buffer.raw)

print(f"Screenshot saved: {width}x{height}")

# Cleanup
gdi32.DeleteObject(bmp)
gdi32.DeleteDC(cdc)
user32.ReleaseDC(0, dc)
