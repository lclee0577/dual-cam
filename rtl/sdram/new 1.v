//****************************************Copyright (c)***********************************//
//技术支持：www.openedv.com
//淘宝店铺：http://openedv.taobao.com 
//关注微信公众平台微信号："正点原子"，免费获取FPGA & STM32资料。
//版权所有，盗版必究。
//Copyright(C) 正点原子 2018-2028
//All rights reserved                               
//----------------------------------------------------------------------------------------
// File name:           sdram_fifo_ctrl
// Last modified Date:  2018/3/18 8:41:06
// Last Version:        V1.0
// Descriptions:        SDRAM 读写端口FIFO控制模块
//----------------------------------------------------------------------------------------
// Created by:          正点原子
// Created date:        2018/3/18 8:41:06
// Version:             V1.0
// Descriptions:        The original version
//
//----------------------------------------------------------------------------------------
//****************************************************************************************//
module sdram_fifo_ctrl(
    input             clk_ref,           //SDRAM控制器时钟
    input             rst_n,             //系统复位 
    
    //用户写端口    
    input             clk_write0,        //写端口FIFO: 写时钟 
    input             wrf_wrreq0,        //写端口FIFO: 写请求 
    input      [15:0] wrf_din0,          //写端口FIFO: 写数据 
    input      [23:0] wr_min_addr,       //写SDRAM的起始地址
    input      [23:0] wr_max_addr,       //写SDRAM的结束地址
    input      [ 9:0] wr_length,         //写SDRAM时的数据突发长度
    input             wr_load,           //写端口复位: 复位写地址,清空写FIFO     
    input             clk_write1,        //写端口FIFO: 写时钟 
    input             wrf_wrreq1,        //写端口FIFO: 写请求 
    input      [15:0] wrf_din1,          //写端口FIFO: 写数据 
    
    //用户读端口                         
    input             clk_read,          //读端口FIFO0: 读时钟
    input             rdf_req0,          //读端口FIFO: 读请求
    input             rdf_req1,          //读端口FIFO: 读请求
    output     [15:0] rdf_dout0,         //读端口FIFO: 读数据
    output     [15:0] rdf_dout1,         //读端口FIFO: 读数据 
    input      [23:0] rd_min_addr,       //读SDRAM的起始地址
    input      [23:0] rd_max_addr,       //读SDRAM的结束地址
    input      [ 9:0] rd_length,         //从SDRAM中读数据时的突发长度 
    input             rd_load,           //读端口复位: 复位读地址,清空读FIFO
     
    //用户控制端口                         
    input             sdram_read_valid,  //SDRAM 读使能
    input             sdram_init_done,   //SDRAM 初始化完成标志
    input             sdram_pingpang_en, //SDRAM 乒乓操作使能
                                         
    //SDRAM 控制器写端口                 
    output reg        sdram_wr_req,      //sdram 写请求
    input             sdram_wr_ack,      //sdram 写响应
    output reg [23:0] sdram_wr_addr,     //sdram 写地址
    output     [15:0] sdram_din,         //写入SDRAM中的数据 
                                         
    //SDRAM 控制器读端口                 
    output reg        sdram_rd_req,      //sdram 读请求
    input             sdram_rd_ack,      //sdram 读响应
    output reg [23:0] sdram_rd_addr,     //sdram 读地址 
    input      [15:0] sdram_dout         //从SDRAM中读出的数据 
    );

//parameter define                      
localparam idle       = 4'd0;           //空闲状态
localparam sdram_done = 4'd1;           //sdram初始化完成状态
localparam wr_keep    = 4'd2;           //读FIFO保持状态 
localparam rd_keep    = 4'd3;           //写FIFO保持状态
                             

//reg define
reg        wr_ack_r1;                    //sdram写响应寄存器      
reg        wr_ack_r2;                    
reg        rd_ack_r1;                    //sdram读响应寄存器      
reg        rd_ack_r2;                    
reg        wr_load_r1;                   //写端口复位寄存器      
reg        wr_load_r2;                   
reg        rd_load_r1;                   //读端口复位寄存器      
reg        rd_load_r2;                   
reg        read_valid_r1;                //sdram读使能寄存器      
reg        read_valid_r2;                
reg        sw_bank_en0;                  //切换BANK使能信号
reg        rw_bank_flag0;                //读写bank的标志
reg        sw_bank_en1;                  //切换BANK使能信号
reg        rw_bank_flag1;                //读写bank的标志
reg        wr_fifo_flag;                 //写FIFO切换信号
reg        rd_fifo_flag;                 //读FIFO切换信号

reg  [23:0] sdram_rd_addr0;              //读FIFO0地址
reg  [23:0] sdram_rd_addr1;              //读FIFO1地址
reg  [23:0] sdram_wr_addr0;              //写FIFO0地址
reg  [23:0] sdram_wr_addr1;              //写FIFO1地址
reg  [3:0]  state;                       //读写FIFO控制状态
//wire define                                          
wire       write_done_flag;              //sdram_wr_ack 下降沿标志位      
wire       read_done_flag;               //sdram_rd_ack 下降沿标志位      
wire       wr_load_flag;                 //wr_load      上升沿标志位          
wire       rd_load_flag;                 //rd_load      上升沿标志位  

wire [10:0] wrf_use0;                    //写端口FIFO中的数据量
wire [10:0] wrf_use1;                    //写端口FIFO中的数据量
wire [10:0] rdf_use0;                    //读端口FIFO中的数据量
wire [10:0] rdf_use1;                    //读端口FIFO中的数据量
wire [15:0] sdram_dout0;
wire [15:0] sdram_dout1;

wire [15:0] sdram_din0;
wire [15:0] sdram_din1;

wire        sdram_wr_ack0;               //sdram 写响应，连接到写FIFO0
wire        sdram_wr_ack1;               //sdram 写响应，连接到写FIFO1
wire        sdram_rd_ack0;               //sdram 读响应，连接到读FIFO0
wire        sdram_rd_ack1;               //sdram 读响应，连接到读FIFO1

//*****************************************************
//**                    main code
//***************************************************** 

//检测下降沿
assign write_done_flag = wr_ack_r2   & ~wr_ack_r1;  
assign read_done_flag  = rd_ack_r2   & ~rd_ack_r1;
//检测上升沿
assign wr_load_flag   = ~wr_load_r2 & wr_load_r1;
assign rd_load_flag    = ~rd_load_r2 & rd_load_r1;

//写端口FIFO0中读请求切换
assign sdram_wr_ack0       = wr_fifo_flag ? 1'b0:sdram_wr_ack ;
//写端口FIFO1中读请求切换
assign sdram_wr_ack1       = wr_fifo_flag ? sdram_wr_ack :1'b0 ;
//读端口FIFO0中写请求切换
assign sdram_rd_ack0       = rd_fifo_flag ? 1'b0:sdram_rd_ack ;
//读端口FIFO1中写请求切换
assign sdram_rd_ack1       = rd_fifo_flag ? sdram_rd_ack :1'b0 ;
//写端口FIFO中写数据切换，即选择哪个数据写到SDRAM中
assign sdram_din           = wr_fifo_flag ? sdram_din1:sdram_din0;
//读端口FIFO中写数据切换，即是否选择读FIFO1来接收SDRAM中数据
assign sdram_dout0         = rd_fifo_flag ? 1'b0:sdram_dout  ;
//读端口FIFO中写数据切换，即是否选择读FIFO0来接收SDRAM中数据
assign sdram_dout1         = rd_fifo_flag ? sdram_dout : 1'b0;

//寄存sdram写响应信号,用于捕获sdram_wr_ack下降沿
always @(posedge clk_ref or negedge rst_n) begin
    if(!rst_n) begin
        wr_ack_r1 <= 1'b0;
        wr_ack_r2 <= 1'b0;
    end
    else begin
        wr_ack_r1 <= sdram_wr_ack;
        wr_ack_r2 <= wr_ack_r1;     
    end
end 

//寄存sdram读响应信号,用于捕获sdram_rd_ack下降沿
always @(posedge clk_ref or negedge rst_n) begin
    if(!rst_n) begin
        rd_ack_r1 <= 1'b0;
        rd_ack_r2 <= 1'b0;
    end
    else begin
        rd_ack_r1 <= sdram_rd_ack;
        rd_ack_r2 <= rd_ack_r1;
    end
end 

//同步写端口复位信号，用于捕获wr_load上升沿
always @(posedge clk_ref or negedge rst_n) begin
    if(!rst_n) begin
        wr_load_r1 <= 1'b0;
        wr_load_r2 <= 1'b0;
    end
    else begin
        wr_load_r1 <= wr_load;
        wr_load_r2 <= wr_load_r1;
    end
end

//同步读端口复位信号，同时用于捕获rd_load上升沿
always @(posedge clk_ref or negedge rst_n) begin
    if(!rst_n) begin
        rd_load_r1 <= 1'b0;
        rd_load_r2 <= 1'b0;
    end
    else begin
        rd_load_r1 <= rd_load;
        rd_load_r2 <= rd_load_r1;
    end
end

//同步sdram读使能信号
always @(posedge clk_ref or negedge rst_n) begin
    if(!rst_n) begin
        read_valid_r1 <= 1'b0;
        read_valid_r2 <= 1'b0;
    end
    else begin
        read_valid_r1 <= sdram_read_valid;
        read_valid_r2 <= read_valid_r1;
    end
end

//sdram写地址0产生模块
always @(posedge clk_ref or negedge rst_n) begin
    if (!rst_n) begin
        sdram_wr_addr0 <= 24'd0;
        sw_bank_en0 <= 1'b0;
        rw_bank_flag0 <= 1'b0;
    end
    else if(wr_load_flag) begin          //检测到写端口复位信号时，写地址复位
        sdram_wr_addr0 <= wr_min_addr;   
        sw_bank_en0 <= 1'b0;
        rw_bank_flag0 <= 1'b0;
    end                                //若突发写SDRAM结束，更改写地址
    else if(write_done_flag && wr_fifo_flag == 1'b0) begin
                                       //若未到达写SDRAM的结束地址，则写地址累加                                  
        if(sdram_pingpang_en) begin    //SDRAM 读写乒乓使能
            if(sdram_wr_addr0[21:0] < wr_max_addr - wr_length)
                sdram_wr_addr0 <= sdram_wr_addr0 + wr_length;
            else begin                        //切换BANK
                rw_bank_flag0 <= ~rw_bank_flag0;   
                sw_bank_en0 <= 1'b1;          //拉高切换BANK使能信号
            end            
        end       
                                             //若突发写SDRAM结束，更改写地址
        else if(sdram_wr_addr0 < wr_max_addr[23:1] - wr_length)
            sdram_wr_addr0 <= sdram_wr_addr0 + wr_length;
        else                             //到达写SDRAM的结束地址，回到写起始地址
            sdram_wr_addr0 <= wr_min_addr;
    end
    else if(sw_bank_en0) begin           //到达写SDRAM的结束地址，回到写起始地址
        sw_bank_en0 <= 1'b0;
        if(rw_bank_flag0 == 1'b0)        //切换BANK
            sdram_wr_addr0 <= {2'b00,wr_min_addr[21:0]};
        else
            sdram_wr_addr0 <= {2'b01,wr_min_addr[21:0]};     
    end
end

//sdram写地址1产生模块
always @(posedge clk_ref or negedge rst_n) begin
    if (!rst_n) begin
        sdram_wr_addr1 <= 24'd0;
        sw_bank_en1 <= 1'b0;
        rw_bank_flag1 <= 1'b0;
    end
    else if(wr_load_flag) begin            //检测到写端口复位信号时，写地址复位
        sdram_wr_addr1 <= wr_max_addr[23:1];
        sw_bank_en1 <= 1'b0;
        rw_bank_flag1 <= 1'b0;
    end
    else if(write_done_flag && wr_fifo_flag) begin//若突发写SDRAM结束，更改写地址
                                       //若未到达写SDRAM的结束地址，则写地址累加                                 
        if(sdram_pingpang_en) begin    //SDRAM 读写乒乓使能
            if(sdram_wr_addr1[21:0] < wr_max_addr - wr_length)
                sdram_wr_addr1 <= sdram_wr_addr1 + wr_length;
            else begin                //切换BANK
                rw_bank_flag1 <= ~rw_bank_flag1;   
                sw_bank_en1 <= 1'b1; //拉高切换BANK使能信号
            end            
        end       
                                             //若突发写SDRAM结束，更改写地址
        else if(sdram_wr_addr1 < wr_max_addr - wr_length)
            sdram_wr_addr1 <= sdram_wr_addr1 + wr_length;
        else                            //到达写SDRAM的结束地址，回到写起始地址
            sdram_wr_addr1 <= wr_max_addr[23:1];
    end
    else if(sw_bank_en1) begin          //到达写SDRAM的结束地址，回到写起始地址
        sw_bank_en1 <= 1'b0;
        if(rw_bank_flag1 == 1'b0)      //切换BANK
            sdram_wr_addr1 <= {2'b10,wr_max_addr[22:1]};
        else
            sdram_wr_addr1 <= {2'b11,wr_max_addr[22:1]};     
    end
end

//sdram读地址0产生模块
always @(posedge clk_ref or negedge rst_n) begin
    if(!rst_n) begin
        sdram_rd_addr0 <= 24'd0;
    end 
    else if(rd_load_flag)                    //检测到读端口复位信号时，读地址复位
        sdram_rd_addr0 <= rd_min_addr;       //突发读SDRAM结束，更改读地址
    else if(read_done_flag && rd_fifo_flag == 1'b0) begin 
                                       //若未到达读SDRAM的结束地址，则读地址累加                 
        if(sdram_pingpang_en) begin    //SDRAM 读写乒乓使能  
            if(sdram_rd_addr0[21:0] < rd_max_addr[23:1] - rd_length)
                sdram_rd_addr0 <= sdram_rd_addr0 + rd_length;
            else begin                   //到达读SDRAM的结束地址，回到读起始地址
                                         //读取没有在写数据的bank地址
                if(rw_bank_flag0 == 1'b0)//根据rw_bank_flag的值切换读BANK地址
                    sdram_rd_addr0 <= {2'b01,rd_min_addr[21:0]};
                else
                    sdram_rd_addr0 <= {2'b00,rd_min_addr[21:0]};    
            end    
        end
                                                //若突发写SDRAM结束，更改写地址
        else if(sdram_rd_addr0 < rd_max_addr[23:1] - rd_length)  
            sdram_rd_addr0 <= sdram_rd_addr0 + rd_length;
        else                            //到达写SDRAM的结束地址，回到写起始地址
            sdram_rd_addr0 <= rd_min_addr;
    end
end

//sdram读地址1产生模块
always @(posedge clk_ref or negedge rst_n) begin
    if(!rst_n) begin
        sdram_rd_addr1 <= 24'd0;
    end 
    else if(rd_load_flag)                    //检测到读端口复位信号时，读地址复位
        sdram_rd_addr1 <= rd_max_addr[23:1];
    else if(read_done_flag && rd_fifo_flag) begin  //突发读SDRAM结束，更改读地址
                                       //若未到达读SDRAM的结束地址，则读地址累加                 
        if(sdram_pingpang_en) begin    //SDRAM 读写乒乓使能  
            if(sdram_rd_addr1[21:0] < rd_max_addr - rd_length)
                sdram_rd_addr1 <= sdram_rd_addr1 + rd_length;
            else begin                  //到达读SDRAM的结束地址，回到读起始地址
                                        //读取没有在写数据的bank地址
                if(rw_bank_flag1 == 1'b0)   //根据rw_bank_flag的值切换读BANK地址
                    sdram_rd_addr1 <= {2'b11,rd_max_addr[22:1]};
                else
                    sdram_rd_addr1 <= {2'b10,rd_max_addr[22:1]};    
            end    
        end
                                             //若突发写SDRAM结束，更改写地址
        else if(sdram_rd_addr1 < rd_max_addr - rd_length)  
            sdram_rd_addr1 <= sdram_rd_addr1 + rd_length;
        else                             //到达写SDRAM的结束地址，回到写起始地址
            sdram_rd_addr1 <= rd_max_addr[23:1];
    end
end

//SDRAM读写流程控制
always@(posedge clk_ref or negedge rst_n) begin
    if(!rst_n) begin
        sdram_wr_req  <= 0;               
        sdram_wr_addr <= sdram_wr_addr0; 
        wr_fifo_flag  <= 0;
        
        sdram_rd_req  <= 0;
        rd_fifo_flag  <= 0;
        sdram_rd_addr <= sdram_rd_addr0;
        state         <= idle;           //复位处于空闲状态，不操作任何FIFO
    end
    else begin
        case(state)
            idle : begin
                if(sdram_init_done)
                    state <= sdram_done; //SDRAM初始化完成进入sdram_done状态
            end
            sdram_done : begin    //在sdram_done状态对四个FIFO的读写操作进行判断
                if(wrf_use0 >= wr_length*2) begin//满足进入写端FIFO0的读状态
                    sdram_wr_req  <= 1;
                    sdram_wr_addr <= sdram_wr_addr0;
                    wr_fifo_flag  <= 0;
                    
                    sdram_rd_req  <= 0;
                    sdram_rd_addr <= sdram_rd_addr0;
                    rd_fifo_flag  <= 0;
                    state <= wr_keep;
                end                              //满足进入写端FIFO1的读状态
                else if(wrf_use1 >= wr_length*2) begin
                    sdram_wr_req  <= 1;
                    sdram_wr_addr <= sdram_wr_addr1;
                    wr_fifo_flag  <= 1;
                    
                    sdram_rd_req  <= 0;
                    sdram_rd_addr <= sdram_rd_addr0;
                    rd_fifo_flag  <= 0;
                    state <= wr_keep;
                end
                else if(rdf_use0 < rd_length*2 ) begin//进入读端FIFO0的写状态状态
                    sdram_wr_req  <= 0;
                     sdram_wr_addr <= sdram_wr_addr0;
                     wr_fifo_flag  <= 0;
                  
                     sdram_rd_req  <= 1;
                     sdram_rd_addr <= sdram_rd_addr0;
                     rd_fifo_flag  <= 0;
                     state <= rd_keep;
                end
                else if(rdf_use1 < rd_length*2) begin//进入读端FIFO1的写状态状态
                    sdram_wr_req  <= 0;
                    sdram_wr_addr <= sdram_wr_addr0;
                    wr_fifo_flag  <= 0;
                   
                    sdram_rd_req  <= 1;
                    sdram_rd_addr <= sdram_rd_addr1;
                    rd_fifo_flag  <= 1;
                    state <= rd_keep;
                end                
            end
            wr_keep : begin
                if(write_done_flag) begin     //除非突发写结束，否则维持在写状态
                    sdram_wr_req  <= 0;
                    sdram_wr_addr <= sdram_wr_addr0;
                    wr_fifo_flag  <= 0;
                    state <= sdram_done;
                end    
            end
            rd_keep : begin
                if(read_done_flag) begin      //除非突发读结束，否则维持在读状态
                     sdram_rd_req  <= 0;
                    sdram_rd_addr <= sdram_rd_addr0;
                    rd_fifo_flag  <= 0;
                    state <= sdram_done;
                end
            end
            default : state <= idle;          //默认停在空闲状态
        endcase    
    end
end    

//例化写端口FIFO 0
wrfifo  u_wrfifo0(
    //用户接口
    .wrclk      (clk_write0),            //写时钟
    .wrreq      (wrf_wrreq0),            //写请求
    .data       (wrf_din0),              //写数据
    
    //sdram接口
    .rdclk      (clk_ref),               //读时钟
    .rdreq      (sdram_wr_ack0),         //读请求
    .q          (sdram_din0),            //读数据

    .rdusedw    (wrf_use0),              //FIFO中的数据量
    .aclr       (~rst_n | wr_load_flag)  //异步清零信号
    );  

//例化写端口FIFO 1
wrfifo  u_wrfifo1(
    //用户接口
    .wrclk      (clk_write1),            //写时钟
    .wrreq      (wrf_wrreq1),            //写请求
    .data       (wrf_din1),              //写数据  
    
    //sdram接口
    .rdclk      (clk_ref),               //读时钟
    .rdreq      (sdram_wr_ack1),         //读请求
    .q          (sdram_din1),            //读数据

    .rdusedw    (wrf_use1),              //FIFO中的数据量
    .aclr       (~rst_n | wr_load_flag)  //异步清零信号
    );      

//例化读端口FIFO
rdfifo  u_rdfifo0(
    //sdram接口
    .wrclk      (clk_ref),               //写时钟
    .wrreq      (sdram_rd_ack0),         //写请求
    .data       (sdram_dout0),           //写数据
    
    //用户接口
    .rdclk      (clk_read),              //读时钟
    .rdreq      (rdf_req0),              //读请求
    .q          (rdf_dout0),             //读数据

    .wrusedw    (rdf_use0),              //FIFO中的数据量
    .aclr       (~rst_n | rd_load_flag)  //异步清零信号   
    );

//例化读端口FIFO
rdfifo  u_rdfifo1(
    //sdram接口
    .wrclk      (clk_ref),               //写时钟
    .wrreq      (sdram_rd_ack1),         //写请求
    .data       (sdram_dout1),           //写数据  sdram_dout
    
    //用户接口
    .rdclk      (clk_read),              //读时钟
    .rdreq      (rdf_req1),              //读请求
    .q          (rdf_dout1),             //读数据

    .wrusedw    (rdf_use1),              //FIFO中的数据量
    .aclr       (~rst_n | rd_load_flag)  //异步清零信号   
    );
   
endmodule 