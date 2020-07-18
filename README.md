# <center> dual-cam </center>

![image](img/dual-cam.jpg#pic_center=400x400)

## requirement

### FT601 驱动

1. [FT601 驱动下载](http://www.ftdichip.cn/Drivers/D3XX.htm)

    连接 FT601 在设备管理器更新驱动
2. [FT60x dll等资料](https://www.ftdichip.cn/Support/SoftwareExamples/FT60X.htm)

3. [FT601 python lib 下载](https://www.ftdichip.cn/Support/SoftwareExamples/SuperSpeed/D3XXPython_Release1.0.zip)

   下载后解压 在终端输入 `setup.py install` 再将ftd3xx.dll 复制到python的路径中(若不成功请仔细阅读里面的`readme.rst`文件)

### 测试程序 `f601Conm.py`

1. 传输数据大小需为1k
2. 帧头 0xa5,0x6b  帧尾 0x7c,0xd8，中间的4位是传输数据
3. 配合FPGA程序 回传的数据为 写入的 `buffer[0][3]`
4. 现象：一幅由黑变白的图片
5. 每收到到一张图 控制台输出传输时间和收发数据
6. 运行结束时输出平均帧率
7. 主函数中接收FT601回传数据写入队列，子线程中获取队列数据并显示
