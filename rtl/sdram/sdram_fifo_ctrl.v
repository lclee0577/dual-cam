//****************************************Copyright (c)***********************************//
//技术支持：www.openedv.com
//淘宝店铺：http://openedv.taobao.com 
//关注微信公众平台微信号："正点原子"，免费获取FPGA & STM32资料。
//版权所有，盗版必究。
//Copyright(C) 正点原子 2018-2028
//All rights reserved	                               
//----------------------------------------------------------------------------------------
// File name:           sdram_fifo_ctrl
// Last modified Date:  2018/1/30 11:12:36
// Last Version:        V1.1
// Descriptions:        读写FIFO控制
//----------------------------------------------------------------------------------------
// Created by:          正点原子
// Created date:        2018/1/29 10:55:56
// Version:             V1.0
// Descriptions:        The original version
//
//----------------------------------------------------------------------------------------
// Modified by:		    正点原子
// Modified date:	    2018/1/30 11:12:36
// Version:			    V1.1
// Descriptions:	    
//
//----------------------------------------------------------------------------------------
//****************************************************************************************//

module sdram_fifo_ctrl(
    input             clk_ref,           //SDRAM控制器时钟
    input             rst_n  ,           //系统复位 
                                         
    //用户写端口                         
    input             clk_write0,        //写端口FIFO0: 写时钟 
    input             wrf_wrreq0,        //写端口FIFO0: 写请求 
    input      [15:0] wrf_din0,          //写端口FIFO0: 写数据 
    input      [23:0] wr_min_addr,       //写SDRAM的起始地址
    input      [23:0] wr_max_addr,       //写SDRAM的结束地址
    input      [ 9:0] wr_length,         //写SDRAM时的数据突发长度 
    input             wr_load,           //写端口复位: 复位写地址,清空写FIFO 
    input      [12:0] rd_h_pixel,        //显示器的显示分辨率 
    //用户写端口                         
    input             clk_write1,        //写端口FIFO1: 写时钟 
    input             wrf_wrreq1,        //写端口FIFO1: 写请求 
    input      [15:0] wrf_din1,          //写端口FIFO1: 写数据 
   
    //用户读端口 
    input             clk_read ,         //读端口FIFO: 读时钟
	input             rdf_rdreq,         //读端口FIFO： 读请求
    output     [15:0] rd_data  ,         //读端口FIFO： 读数据
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
    
localparam idle       = 4'd0;            //空闲状态
localparam sdram_done = 4'd1;            //sdram初始化完成状态
localparam wr_keep    = 4'd2;            //读FIFO保持状态
localparam rd_keep    = 4'd3;            //写FIFO保持状态

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
reg        sw_bank_en0;                  //切换BANK0，1使能信号
reg        rw_bank_flag0;                //读写bank0，1的标志
reg        sw_bank_en1;                  //切换BANK2，3使能信号
reg        rw_bank_flag1;                //读写bank2，3的标志
reg        wr_fifo_flag;                 //写FIFO切换信号
reg        rd_fifo_flag;                 //读FIFO切换信号
 
reg [23:0] sdram_rd_addr0;               //读FIFO0地址
reg [23:0] sdram_rd_addr1;               //读FIFO1地址
reg [23:0] sdram_wr_addr0;               //写FIFO0地址
reg [23:0] sdram_wr_addr1;               //写FIFO1地址
reg  [3:0] state;                        //读写FIFO控制状态
reg [12:0] rd_cnt;
                                   
//wire define                            
wire         write_done_flag;            //sdram_wr_ack 下降沿标志位      
wire         read_done_flag;             //sdram_rd_ack 下降沿标志位    
wire         wr_load_flag;               //wr_load      上升沿标志位      
wire         rd_load_flag;               //rd_load      上升沿标志位      
wire [10:0]  wrf_use0;                   //写端口FIFO0中的数据量
wire [10:0]  rdf_use0;                   //读端口FIFO0中的数据量
wire [10:0]  wrf_use1;                   //写端口FIFO1中的数据量
wire [10:0]  rdf_use1;                   //读端口FIFO1中的数据量
wire [15:0]  sdram_dout0;                //读端口FIFO0中读出数据
wire [15:0]  sdram_dout1;                //读端口FIFO1中读出数据
wire         rdf_rdreq0;                 //读端口FIFO0中读请求信号
wire         rdf_rdreq1;                 //读端口FIFO1中读请求信号
wire  [15:0] rdf_dout0/*synthesis keep*/;
wire  [15:0] rdf_dout1/*synthesis keep*/;
wire  [15:0] sdram_din0/*synthesis keep*/;
wire  [15:0] sdram_din1/*synthesis keep*/;
wire         sdram_wr_ack0;
wire         sdram_wr_ack1;
wire         sdram_rd_ack0;
wire         sdram_rd_ack1;
//*****************************************************
//**                    main code
//***************************************************** 

//检测下降沿
assign write_done_flag     = wr_ack_r2   & ~wr_ack_r1;  
assign read_done_flag      = rd_ack_r2   & ~rd_ack_r1;
//写端口FIFO0中读请求切换
assign sdram_wr_ack0       = wr_fifo_flag ? 1'b0:sdram_wr_ack ;
//写端口FIFO1中读请求切换
assign sdram_wr_ack1       = wr_fifo_flag ? sdram_wr_ack :1'b0 ;
//读端口FIFO0中写请求切换
assign sdram_rd_ack0       = rd_fifo_flag ? 1'b0:sdram_rd_ack ;
//读端口FIFO1中写请求切换
assign sdram_rd_ack1       = rd_fifo_flag ? sdram_rd_ack :1'b0 ;
//写端口FIFO中写数据切换，即选择哪个数据写道SDRAM中
assign sdram_din           = wr_fifo_flag ? sdram_din1:sdram_din0;
//读端口FIFO中写数据切换，即选择读FIFO1来接收SDRAM中数据
assign sdram_dout0         = rd_fifo_flag ? 1'b0:sdram_dout  ;
//读端口FIFO中写数据切换，即选择读FIFO0来接收SDRAM中数据
assign sdram_dout1         = rd_fifo_flag ? sdram_dout : 1'b0;
//像素显示请求信号切换，即显示器左侧请求FIFO0显示，右侧请求FIFO1显示
assign rdf_rdreq1  = (rd_cnt <= rd_h_pixel-1) ? rdf_rdreq :1'b0;
assign rdf_rdreq0  = (rd_cnt <= rd_h_pixel-1) ? 1'b0 :rdf_rdreq;

//像素在显示器显示位置的切换，即显示器左侧显示FIFO0,右侧显示FIFO1
assign rd_data =     (rd_cnt <= rd_h_pixel) ? rdf_dout1:rdf_dout0;

//检测上升沿
assign wr_load_flag    = ~wr_load_r2 & wr_load_r1;
assign rd_load_flag    = ~rd_load_r2 & rd_load_r1;

always @(posedge clk_read or negedge rst_n) begin
    if(!rst_n)
        rd_cnt <= 13'd0;
    else if(rdf_rdreq)
        rd_cnt <= rd_cnt + 1'b1;
    else
        rd_cnt <= 13'd0;
end

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
	if(!rst_n)begin
		sdram_wr_addr0 <= 24'd0;
        rw_bank_flag0  <= 0;
        sw_bank_en0    <= 0;
    end 
    else if(wr_load_flag)begin              //检测到写端口复位信号时，写地址复位
		sdram_wr_addr0 <= wr_min_addr;
        rw_bank_flag0  <= 0;
        sw_bank_en0    <= 0;
    end                                     //若突发写SDRAM结束更改写地址
	else if(write_done_flag && !wr_fifo_flag) begin	
        if(sdram_pingpang_en) begin         //SDRAM 读写乒乓使能
                                            //若未到达写SDRAM的结束地址写地址累加 
            if(sdram_wr_addr0[21:0] < wr_max_addr - wr_length)
                sdram_wr_addr0 <= sdram_wr_addr0 + wr_length;
            else begin                      //切换BANK
                rw_bank_flag0 <= ~rw_bank_flag0;   
                sw_bank_en0 <= 1'b1;        //拉高切换BANK使能信号
            end            
        end                                 //乒乓操作不使能时
                                            //判断是否到达结束地址                     
		else if(sdram_wr_addr0 < wr_max_addr - wr_length)
                                            //没达结束地址，地址累加一个突发长度
			sdram_wr_addr0 <= sdram_wr_addr0 + wr_length;
        else                                //若已到达结束地址，则回到写起始地址
            sdram_wr_addr0 <= wr_min_addr;
    end    
    else if(sw_bank_en0) begin              //如果bank切换使能信号有效
        sw_bank_en0 <= 1'b0;                //将使能信号置0，方便下次使用
        if(rw_bank_flag0 == 1'b0)           //根据bank标志信号切换BANK
            sdram_wr_addr0 <= {2'b00,wr_min_addr[21:0]};
        else
            sdram_wr_addr0 <= {2'b01,wr_min_addr[21:0]};     
   end
end

//sdram写地址1产生模块
always @(posedge clk_ref or negedge rst_n) begin
	if(!rst_n)begin
		sdram_wr_addr1 <= 24'd0;
        rw_bank_flag1  <= 0;
        sw_bank_en1    <= 0;
    end 
    else if(wr_load_flag)begin              //检测到写端口复位信号时，写地址复位
        rw_bank_flag1  <= 0;
        sw_bank_en1    <= 0;
		sdram_wr_addr1 <= wr_max_addr;
    end                                     //若突发写SDRAM结束，更改写地址
	else if(write_done_flag && wr_fifo_flag) begin
        if(sdram_pingpang_en) begin         //判断若SDRAM 读写乒乓使能
                                            //若未到达写SDRAM的结束地址写地址累加 
        if(sdram_wr_addr1[21:0] < wr_max_addr*2 - wr_length)
                sdram_wr_addr1 <= sdram_wr_addr1 + wr_length;
            else begin                      //切换BANK
                rw_bank_flag1 <= ~rw_bank_flag1;   
                sw_bank_en1 <= 1'b1;        //拉高切换BANK使能信号
            end            
        end                                 //乒乓操作不使能
                                            //未到达写SDRAM的结束地址写地址累加
		else if(sdram_wr_addr1 < wr_max_addr*2 - wr_length)
			sdram_wr_addr1 <= sdram_wr_addr1 + wr_length;
            else                            //到达写SDRAM的结束地址回到写起始地址
            sdram_wr_addr1 <= wr_max_addr;
    end
    else if(sw_bank_en1) begin              //如果bank切换使能信号有效
        sw_bank_en1 <= 1'b0;                //将使能信号置0，方便下次使用
        if(rw_bank_flag1 == 1'b0)           //切换BANK
            sdram_wr_addr1 <= {2'b10,wr_max_addr[21:0]};
        else
            sdram_wr_addr1 <= {2'b11,wr_max_addr[21:0]};     
    end
end

//sdram读地址0产生模块
always @(posedge clk_ref or negedge rst_n) begin
	if(!rst_n)
		sdram_rd_addr0 <= 24'd0;	
    else if(rd_load_flag)                   //检测到写端口复位信号时，写地址复位
		sdram_rd_addr0 <= rd_min_addr;	    //若突发读SDRAM结束，更改读地址
	else if(read_done_flag && !rd_fifo_flag ) begin
        if(sdram_pingpang_en) begin         //判断若SDRAM 读写乒乓使能  
                                            //若未到达SDRAM的结束地址则地址累加 
            if(sdram_rd_addr0[21:0] < rd_max_addr - rd_length)
                sdram_rd_addr0 <= sdram_rd_addr0 + rd_length;                                                
            else begin                      //到达读SDRAM的结束地址，回到读起始                     
                if(rw_bank_flag0 == 1'b0)   //根据rw_bank_flag的值切换读BANK地址
                    sdram_rd_addr0 <= {2'b01,rd_min_addr[21:0]};
                else
                    sdram_rd_addr0 <= {2'b00,rd_min_addr[21:0]};    
            end    
        end                                  //若乒乓操作未使能
                                             //未到达SDRAM的结束地址地址累加
		else if(sdram_rd_addr0 < rd_max_addr - rd_length)
			sdram_rd_addr0 <= sdram_rd_addr0 + rd_length;
        else                                 //若到达SDRAM的结束地址回到起始地址
            sdram_rd_addr0 <= rd_min_addr;
    end
end

//sdram读地址1产生模块
always @(posedge clk_ref or negedge rst_n) begin
	if(!rst_n)
		sdram_rd_addr1 <= 24'd0;	
    else if(rd_load_flag)                    //检测到复位信号时地址复位
		sdram_rd_addr1 <= rd_max_addr;	
                                             //判断若突发读SDRAM结束
	else if(read_done_flag && rd_fifo_flag) begin
        if(sdram_pingpang_en) begin          //若SDRAM 读写乒乓使能 
                                             //若未到达SDRAM的结束地址则地址累加        
            if(sdram_rd_addr1[21:0] < rd_max_addr*2 - rd_length)
                sdram_rd_addr1 <= sdram_rd_addr1 + rd_length;                                                
            else begin                       //到达读SDRAM的结束地址                    
                if(rw_bank_flag1 == 1'b0)    //根据rw_bank_flag的值切换BANK地址
                    sdram_rd_addr1 <= {2'b11,rd_max_addr[21:0]};
                else
                    sdram_rd_addr1 <= {2'b10,rd_max_addr[21:0]};    
            end    
        end                                  //如果乒乓操作没有使能
                                             //未到达SDRAM的结束地址地址累加
		else if(sdram_rd_addr1 < rd_max_addr*2 - rd_length)
			sdram_rd_addr1 <= sdram_rd_addr1 + rd_length;
        else                                 //若已到达SDRAM的结束地址回到起始地址
            sdram_rd_addr1 <= rd_max_addr;
    end
end

//读写端四个FIFO的判断逻辑       
always@(posedge clk_ref or negedge rst_n) begin
    if(!rst_n) begin                     
        sdram_wr_req  <= 0;
        sdram_wr_addr <= sdram_wr_addr0;
        wr_fifo_flag  <= 0;
        
        sdram_rd_req  <= 0;
        rd_fifo_flag  <= 0;
        sdram_rd_addr <= sdram_rd_addr0;
        state         <= idle;          //复位处于空闲状态，不操作任何FIFO
    end
    else begin
        case(state)
            idle:begin
                if(sdram_init_done)
                      state <=  sdram_done;//SDRAM初始化完成进入sdram_done状态
             end
             sdram_done:begin              //在sdram_done状态对四个FIFO的读写操作进行判断
                if(wrf_use0 >= wr_length*2) begin //进入写端FIFO0的读状态状态
                    sdram_wr_req  <= 1;
                    sdram_wr_addr <= sdram_wr_addr0;
                    wr_fifo_flag  <= 0;
                    
                    sdram_rd_req  <= 0;
                    sdram_rd_addr <= sdram_rd_addr0;
                    rd_fifo_flag  <= 0;
                    state <= wr_keep;
                     
                 end
        
                 else if(wrf_use1 >= wr_length*2) begin//进入写端FIFO1的读状态状态
                    sdram_wr_req  <= 1;
                    sdram_wr_addr <= sdram_wr_addr1;
                    wr_fifo_flag  <= 1;
                    
                    sdram_rd_req  <= 0;
                    sdram_rd_addr <= sdram_rd_addr0;
                    rd_fifo_flag  <= 0;
                    
                    state <= wr_keep;
                end
                else if((rdf_use0 < rd_length*2)//进入读端FIFO0的写状态状态
                ) begin
                     sdram_wr_req  <= 0;
                     sdram_wr_addr <= sdram_wr_addr0;
                     wr_fifo_flag  <= 0;
                  
                     sdram_rd_req  <= 1;
                     sdram_rd_addr <= sdram_rd_addr0;
                     rd_fifo_flag  <= 0;
                     state <= rd_keep;
                end
                else if((rdf_use1 < rd_length*2)//进入读端FIFO1的写状态状态
                ) begin
                    sdram_wr_req  <= 0;
                    sdram_wr_addr <= sdram_wr_addr0;
                    wr_fifo_flag  <= 0;
                   
                    sdram_rd_req  <= 1;
                    sdram_rd_addr <= sdram_rd_addr1;
                    rd_fifo_flag  <= 1;
                    state <= rd_keep;
                end  
               end
                wr_keep:begin
                    if(write_done_flag) begin  //保持写状态
                    sdram_wr_req  <= 0;
                    sdram_wr_addr <= sdram_wr_addr0;
                    wr_fifo_flag  <= 0;
                    state <= sdram_done;
                   end    
                end
                 rd_keep:begin
                    if(read_done_flag) begin  //保持读状态
                    sdram_rd_req  <= 0;
                    sdram_rd_addr <= sdram_rd_addr0;
                    rd_fifo_flag  <= 0;
                    state <= sdram_done;
                   end    
                end   
                 default : state <= idle;    //默认停在空闲状态
        endcase    
    end
end
              
//例化写端口FIFO0
wrfifo  u_wrfifo0(
    //用户接口
    .wrclk      (clk_write0),             //写时钟
    .wrreq      (wrf_wrreq0),             //写请求
    .data       (wrf_din0),               //写数据
    //sdram接口
    .rdclk      (clk_ref),                //读时钟
    .rdreq      (sdram_wr_ack0),          //读请求
    .q          (sdram_din0),             //读数据
    
    .rdusedw    (wrf_use0),               //FIFO中的数据量
    .aclr       (~rst_n | wr_load_flag)   //异步清零信号
    ); 
	
//例化写端口FIFO1
wrfifo  u_wrfifo1(
    //用户接口
    .wrclk      (clk_write1),             //写时钟
    .wrreq      (wrf_wrreq1),             //写请求
    .data       (wrf_din1),               //写数据 
    //sdram接口
    .rdclk      (clk_ref),                //读时钟
    .rdreq      (sdram_wr_ack1),          //读请求
    .q          (sdram_din1),             //读数据

    .rdusedw    (wrf_use1),               //FIFO中的数据量
    .aclr       (~rst_n | wr_load_flag)   //异步清零信号
    );      
    
//例化读端口FIFO0
rdfifo  u_rdfifo1(
    //sdram接口
    .wrclk      (clk_ref),                //写时钟
    .wrreq      (sdram_rd_ack1),          //写请求
    .data       (sdram_dout1),            //写数据
    
    //用户接口
    .rdclk      (clk_read),              //读时钟
    .rdreq      (rdf_rdreq1),             //读请求
    .q          (rdf_dout1),              //读数据
    
    .wrusedw    (rdf_use1),               //FIFO中的数据量
    .aclr       (~rst_n | rd_load_flag)   //异步清零信号   
    );
//例化读端口FIFO1
rdfifo  u_rdfifo0(
    //sdram接口
    .wrclk      (clk_ref),                //写时钟
    .wrreq      (sdram_rd_ack0),          //写请求
    .data       (sdram_dout0),            //写数据
    
    //用户接口
    .rdclk      (clk_read),              //读时钟
    .rdreq      (rdf_rdreq0),             //读请求
    .q          (rdf_dout0),              //读数据
    
    .wrusedw    (rdf_use0),               //FIFO中的数据量
    .aclr       (~rst_n | rd_load_flag)   //异步清零信号   
    );    
endmodule 