'''
@Author       : lclee
@Date         : 2020-07-15 10:22:59
@LastEditTime : 2020-07-18 14:10:04
@LastEditors  : lclee
@Description  : 
'''
#%%

import time
import threading
from queue import Queue
import ftd3xx
import sys
if sys.platform == 'win32':
    import ftd3xx._ftd3xx_win32 as _ft

import numpy as np
import cv2


def FT_init() -> ftd3xx.FTD3XX:
    numDevices = ftd3xx.createDeviceInfoList()
    if numDevices == 0:
        print("no dev")
    else:
        devList = ftd3xx.getDeviceInfoList()
        devIndex = 0
        for i in range(numDevices):
            if devList[i].ID == 0x403601f:
                devIndex = i
            else:
                print("not find our dev")
                sys.exit()


        D3XX = ftd3xx.create(devIndex, _ft.FT_OPEN_BY_INDEX)
        devDesc = D3XX.getDeviceDescriptor()
        bUSB3 = devDesc.bcdUSB >= 0x300
        if (bUSB3 == False):
            print("Warning: Device is connected using USB2 cable or through USB2 host controller!")
        cfg = D3XX.getChipConfiguration()

        channelConfig = ["4 Channels", "2 Channels", "1 Channel", "1 OUT Pipe", "1 IN Pipe"]
        print("\tChannelConfig = %#04x (%s)" % (cfg.ChannelConfig, channelConfig[cfg.ChannelConfig]))

        return D3XX


imgQue = Queue()
def imgshowThread():
    cv2.namedWindow('img', cv2.WINDOW_NORMAL | cv2.WINDOW_KEEPRATIO)
    img = np.zeros((1920,5120),np.uint16)
    RGB565_MASK_RED =0xF800
    RGB565_MASK_GREEN =0x07E0
    RGB565_MASK_BLUE =0x001F
    while True:
        if not imgQue.empty():

            # img = imgQue.get().byteswap(True)
            # r = ((img & RGB565_MASK_RED)   >> 8 ).astype(np.uint8) # >>11  <<3
            # g = ((img & RGB565_MASK_GREEN) >> 3 ).astype(np.uint8) # >>5   <<2
            # b = ((img & RGB565_MASK_BLUE)  << 3 ).astype(np.uint8) #       <<3
            # img1 = cv2.merge([b,g,r])
            
            img = imgQue.get()
            cv2.imshow("img",img)
        
        key = cv2.waitKey(1)
        if (key == ord('q')):
            break

if __name__ == "__main__":
    
#%%
        D3XX = FT_init() 
        wrSize = 1024
        buffer = np.zeros((int(wrSize/8),8),np.uint8)
        buffer[0] = [0xa5,0x6b,0x36,0xff,0x54,0x00,0x7c,0xd8]
        # buffer[1] = [0xa5,0x6b,0x36,0x00,0x54,0x00,0x7c,0xd8]
        bufferString = buffer.flatten().tostring()
        
        rdSize = 2560*1920*2
        readBuffer = np.zeros((1,rdSize),np.uint8).flatten().tostring()
    
        
        
        timeList = []
        currentTime = time.perf_counter()
        threading.Thread(target=imgshowThread,name="imgshowThread",daemon = True).start() #deamon 守护 主程序结束，子线程也结束
        ret = D3XX.writePipe(0x02, bufferString, wrSize)
#%%
        for i in range(256):

            
            buffer[0][3] = i&0xff
            bufferString = buffer.flatten().tostring()
            ret = D3XX.writePipe(0x02, bufferString, wrSize)
            readRet = D3XX.readPipe(0x82, readBuffer,rdSize)
            

            rd_data = np.frombuffer(readBuffer,np.uint8).copy().reshape((1920,2560*2))
            imgQue.put(rd_data)



            timeUse = time.perf_counter()-currentTime
            currentTime = time.perf_counter()
            timeList.append(timeUse)
            print(f'{1/(timeUse):3.2f}  wr_data:{buffer[0][3]}  rd_data {rd_data[0][0]}')
        
#%%
        print(f'average frame : {1/np.mean(timeList)}')
                    
        # buffer[0][3] = 0x00
        # bufferString = buffer.flatten().tostring()
        # ret = D3XX.writePipe(0x02, bufferString, wrSize)
        D3XX.clearStreamPipe(0x02)
        D3XX.clearStreamPipe(0x82)
        D3XX.close()



# %%
