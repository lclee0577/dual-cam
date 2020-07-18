//****************************************Copyright (c)***********************************//
//?????www.openedv.com
//?????http://openedv.taobao.com 
//????????????"????"?????FPGA & STM32???
//??????????
//Copyright(C) ???? 2018-2028
//All rights reserved                               
//----------------------------------------------------------------------------------------
// File name:           sdram_tb
// Last modified Date:  2018/3/18 8:41:06
// Last Version:        V1.0
// Descriptions:        SDRAM????
//----------------------------------------------------------------------------------------
// Created by:          ????
// Created date:        2018/3/18 8:41:06
// Version:             V1.0
// Descriptions:        The original version
//
//----------------------------------------------------------------------------------------
//****************************************************************************************//
`timescale 1ns/1ns

module sdram_tb;

//reg define
reg         clock_50m;                    //50Mhz????
reg         clock_25m;
reg         rst_n;                        //????????
                                          
//wire define                             
wire        sdram_clk;                    //SDRAM ????    
wire        sdram_cke;                    //SDRAM ????    
wire        sdram_cs_n;                   //SDRAM ??    
wire        sdram_ras_n;                  //SDRAM ???    
wire        sdram_cas_n;                  //SDRAM ???    
wire        sdram_we_n;                   //SDRAM ???    
wire [ 1:0] sdram_ba;                     //SDRAM Bank??    
wire [12:0] sdram_addr;                   //SDRAM ?/???    
wire [15:0] sdram_data;                   //SDRAM ??    
wire [ 1:0] sdram_dqm;                    //SDRAM ????    
                                          
//wire define
wire        clk_100m       ;  //100mhz时钟,SDRAM操作时钟
wire        clk_100m_shift ;  //100mhz时钟,SDRAM相位偏移时钟
wire        clk_100m_lcd   ;  //100mhz时钟,LCD顶层模块时钟
wire        clk_lcd        ;  
wire        locked         ;
wire        sdram_init_done;


reg        wr0_en         ;  //sdram_ctrl模块写使能
reg [15:0] wr0_data       ;  //sdram_ctrl模块写数据
wire        wr1_en         ;  //sdram_ctrl模块写使能
wire [15:0] wr1_data       ;  //sdram_ctrl模块写数据
wire        rd_en          ;  //sdram_ctrl模块读使能
wire [15:0] rd_data        ;  //sdram_ctrl模块读数据

//*****************************************************
//**                    main code
//***************************************************** 

//??????????
initial begin
  clock_50m = 0;
  clock_25m = 0;
  rst_n     = 0;                      
  #100                                    //????100ns
  rst_n     = 1;
end

//??50Mhz??,????20ns
always #10 clock_50m = ~clock_50m; 
always #20 clock_25m = ~clock_25m; 

assign cam0_pclk = clock_50m;

reg  [8:0]  v_cnt;
reg  [9:0]  h_cnt;

always @(posedge cam0_pclk or negedge rst_n) begin
    if(!rst_n)
        h_cnt <= 'd0;
    else if(sdram_init_done)
        h_cnt <= h_cnt + 1'b1;
end        

always @(posedge cam0_pclk or negedge rst_n) begin
    if(!rst_n)
        v_cnt <= 'd0;
    else if(h_cnt == 'd1023)
        v_cnt <= v_cnt + 1'b1;
end 

always @(posedge cam0_pclk or negedge rst_n) begin
    if(!rst_n) begin
        wr0_en <= 'd0;
        wr0_data <= 'd0;
    end
    else begin
        if(v_cnt >= 'd1 && v_cnt<= 'd480) begin
            if(h_cnt >= 'd1 && h_cnt <= 'd400) begin
                wr0_en <= 1'b1;
                wr0_data <= wr0_data+ 1;
            end    
            else begin
                wr0_en <= 1'b0;
                wr0_data <= 'd0;
            end    
        end
    end
end


//锁相环
pll u_pll(
    .areset             (~rst_n),
    .inclk0             (clock_50m),
            
    .c0                 (clk_100m),
    .c1                 (clk_100m_shift),
    .c2                 (clk_100m_lcd),
    .locked             (locked)
    );

//例化LCD顶层模块
lcd u_lcd(
    .clk                (clock_25m),
    .rst_n              (rst_n),
                        
    .lcd_hs             (lcd_hs),
    .lcd_vs             (lcd_vs),
    .lcd_de             (lcd_de),
    .lcd_rgb            (lcd_rgb),
    .lcd_bl             (lcd_bl),
    .lcd_rst            (lcd_rst),
    .lcd_pclk           (lcd_pclk),
            
    .pixel_data         (rd_data),
    .rd_en              (rd_en),
    .clk_lcd            (clk_lcd),          //LCD驱动时钟

    .ID_lcd             (ID_lcd)            //LCD ID
    );

sdram_top u_sdram_top(
    .ref_clk            (clk_100m),         //sdram 控制器参考时钟
    .out_clk            (clk_100m_shift),   //用于输出的相位偏移时钟
    .rst_n              (rst_n),            //系统复位
                                            
    //用户写端口    
    .wr_len             (10'd512),          //写SDRAM时的数据突发长度
    .wr_load            (~rst_n),           //写端口复位: 复位写地址,清空写FIFO    
    .wr_min_addr        (24'd0),            //写SDRAM的起始地址
    .wr_max_addr        (800*480),   //写SDRAM的结束地址
    
    .wr0_clk            (cam0_pclk),        //写端口FIFO: 写时钟
    .wr0_en             (wr0_en),           //写端口FIFO: 写使能
    .wr0_data           (wr0_data),         //写端口FIFO: 写数据

    .wr1_clk            (cam0_pclk),        //写端口FIFO: 写时钟
    .wr1_en             (wr0_en),           //写端口FIFO: 写使能
    .wr1_data           (wr0_data),         //写端口FIFO: 写数据
    
    //用户读端口                              
    .rd_clk             (clk_lcd),          //读端口FIFO: 读时钟
    .rd_en              (rd_en),            //读端口FIFO: 读使能
    .rd_data            (rd_data),          //读端口FIFO: 读数据
    .rd_min_addr        (24'd0),            //读SDRAM的起始地址
    .rd_max_addr        (800*480),   //读SDRAM的结束地址
    .rd_len             (10'd512),          //从SDRAM中读数据时的突发长度
    .rd_load            (~rst_n),           //读端口复位: 复位读地址,清空读FIFO
    .rd_h_pixel         (800),    
    
    //用户控制端口                                
    .sdram_read_valid   (1'b1),             //SDRAM 读使能
    .sdram_pingpang_en  (1'b0),             //SDRAM 乒乓操作使能
    .sdram_init_done    (sdram_init_done),  //SDRAM 初始化完成标志
                                            
    //SDRAM 芯片接口                                
    .sdram_clk          (sdram_clk),        //SDRAM 芯片时钟
    .sdram_cke          (sdram_cke),        //SDRAM 时钟有效
    .sdram_cs_n         (sdram_cs_n),       //SDRAM 片选
    .sdram_ras_n        (sdram_ras_n),      //SDRAM 行有效
    .sdram_cas_n        (sdram_cas_n),      //SDRAM 列有效
    .sdram_we_n         (sdram_we_n),       //SDRAM 写有效
    .sdram_ba           (sdram_ba),         //SDRAM Bank地址
    .sdram_addr         (sdram_addr),       //SDRAM 行/列地址
    .sdram_data         (sdram_data),       //SDRAM 数据
    .sdram_dqm          (sdram_dqm)         //SDRAM 数据掩码
    );  
    
//??SDRAM????    
sdr u_sdram(    
    .Clk            (sdram_clk),          //SDRAM ????
    .Cke            (sdram_cke),          //SDRAM ????
    .Cs_n           (sdram_cs_n),         //SDRAM ??
    .Ras_n          (sdram_ras_n),        //SDRAM ???
    .Cas_n          (sdram_cas_n),        //SDRAM ???
    .We_n           (sdram_we_n),         //SDRAM ???
    .Ba             (sdram_ba),           //SDRAM Bank??
    .Addr           (sdram_addr),         //SDRAM ?/???
    .Dq             (sdram_data),         //SDRAM ??
    .Dqm            (sdram_dqm)           //SDRAM ????
    );
    
endmodule 