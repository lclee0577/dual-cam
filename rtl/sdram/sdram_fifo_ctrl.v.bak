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
    input      [ 9:0] wr_length,         //写SDRAM时的数据突发长度 
    input             wr_load,           //写端口复位: 复位写地址,清空写FIFO 
    input      [23:0] wr_min_addr,       //写SDRAM的起始地址
    input      [23:0] wr_max_addr,       //写SDRAM的结束地址
    
    input             clk0_write,        //写端口FIFO: 写时钟 
    input             wrf0_wrreq,        //写端口FIFO: 写请求 
    input      [15:0] wrf0_din,          //写端口FIFO: 写数据 

    input             clk1_write,        //写端口FIFO: 写时钟 
    input             wrf1_wrreq,        //写端口FIFO: 写请求 
    input      [15:0] wrf1_din,          //写端口FIFO: 写数据 
    
    //用户读端口                         
    input             clk_read,          //读端口FIFO: 读时钟
    input             rdf_rdreq,         //读端口FIFO: 读请求 
    output     [15:0] rdf_dout,          //读端口FIFO: 读数据
    input      [23:0] rd_min_addr,       //读SDRAM的起始地址
    input      [23:0] rd_max_addr,       //读SDRAM的结束地址
    input      [ 9:0] rd_length,         //从SDRAM中读数据时的突发长度 
    input             rd_load,           //读端口复位: 复位读地址,清空读FIFO
    input      [12:0] rd_h_pixel, 
    
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
localparam st_idle       = 4'd0;
localparam st_sdram_done = 4'd1;
localparam st_wr_sdram   = 4'd2;
localparam st_rd_sdram   = 4'd3;  
    
//reg define
reg  [3:0]  rw_state = st_idle;
reg         sdram_wr_flag = 1'b0;  
reg         sdram_rd_flag = 1'b0;
reg  [23:0] sdram_wr0_addr;
reg  [23:0] sdram_wr1_addr;

reg  [23:0] sdram_rd0_addr;
reg  [23:0] sdram_rd1_addr;

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
                                         
//wire define                            
wire       write_done_flag;              //sdram_wr_ack 下降沿标志位      
wire       read_done_flag;               //sdram_rd_ack 下降沿标志位      
wire       wr_load_flag;                //wr_load      上升沿标志位          
wire       rd_load_flag;                 //rd_load      上升沿标志位  

wire [10:0] wrf0_use;                     //写端口FIFO中的数据量
wire [10:0] wrf1_use;                     //写端口FIFO中的数据量
wire [10:0] rdf0_use;                      //读端口FIFO中的数据量
wire [10:0] rdf1_use;                      //读端口FIFO中的数据量
wire       wr0_fifo_rd_req;
wire       wr1_fifo_rd_req;
wire [15:0] sdram_din0;
wire [15:0] sdram_din1;

wire        rd0_req;
wire        rd1_req;
reg  [12:0] rd_cnt;
wire [15:0] rdf0_dout;
wire [15:0] rdf1_dout;


wire        sdram_rd0_ack;
wire        sdram_rd1_ack;

//*****************************************************
//**                    main code
//***************************************************** 

//检测下降沿
assign write_done_flag = wr_ack_r2   & ~wr_ack_r1;  
assign read_done_flag  = rd_ack_r2   & ~rd_ack_r1;

//检测上升沿
assign wr_load_flag   = ~wr_load_r2 & wr_load_r1;
assign rd_load_flag    = ~rd_load_r2 & rd_load_r1;

assign rd0_req = (rd_cnt < rd_h_pixel[12:1] && rdf_rdreq) ? 1'b1 : 1'b0;
assign rd1_req = (rd_cnt >= rd_h_pixel[12:1] && rdf_rdreq) ? 1'b1 : 1'b0;
assign wr0_fifo_rd_req = (sdram_wr_flag == 1'b0) ? sdram_wr_ack : 1'b0;
assign wr1_fifo_rd_req = sdram_wr_flag ? sdram_wr_ack : 1'b0;
assign sdram_din = (sdram_wr_flag == 1'b0) ? sdram_din0 : sdram_din1;
assign rdf_dout = (rd_cnt < rd_h_pixel[12:1] + 1'b1) ? rdf0_dout : rdf1_dout;

assign sdram_rd0_ack = (sdram_rd_flag == 1'b0) ? sdram_rd_ack : 1'b0;
assign sdram_rd1_ack = (sdram_rd_flag == 1'b1) ? sdram_rd_ack : 1'b0;


//读请求切换
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

//sdram写地址产生模块
always @(posedge clk_ref or negedge rst_n) begin
    if (!rst_n) begin
        sdram_wr0_addr <= 24'd0;
        sw_bank_en0 <= 1'b0;
        rw_bank_flag0 <= 1'b0;
    end
    else if(wr_load_flag) begin              //检测到写端口复位信号时，写地址复位
        sdram_wr0_addr <= wr_min_addr;   
        sw_bank_en0 <= 1'b0;
        rw_bank_flag0 <= 1'b0;
    end
    else if(write_done_flag && sdram_wr_flag == 1'b0) begin//若突发写SDRAM结束，更改写地址
                                             //若未到达写SDRAM的结束地址，则写地址累加                                  
        if(sdram_pingpang_en) begin          //SDRAM 读写乒乓使能
            if(sdram_wr0_addr[21:0] < wr_max_addr - wr_length)
                sdram_wr0_addr <= sdram_wr0_addr + wr_length;
            else begin                       //切换BANK
                rw_bank_flag0 <= ~rw_bank_flag0;   
                sw_bank_en0 <= 1'b1;          //拉高切换BANK使能信号
            end            
        end       
                                             //若突发写SDRAM结束，更改写地址
        else if(sdram_wr0_addr < wr_max_addr[23:1] - wr_length)
            sdram_wr0_addr <= sdram_wr0_addr + wr_length;
        else                                 //到达写SDRAM的结束地址，回到写起始地址
            sdram_wr0_addr <= wr_min_addr;
    end
    else if(sw_bank_en0) begin                //到达写SDRAM的结束地址，回到写起始地址
        sw_bank_en0 <= 1'b0;
        if(rw_bank_flag0 == 1'b0)             //切换BANK
            sdram_wr0_addr <= {2'b00,wr_min_addr[21:0]};
        else
            sdram_wr0_addr <= {2'b01,wr_min_addr[21:0]};     
    end
end

//sdram写地址产生模块
always @(posedge clk_ref or negedge rst_n) begin
    if (!rst_n) begin
        sdram_wr1_addr <= 24'd0;
        sw_bank_en1 <= 1'b0;
        rw_bank_flag1 <= 1'b0;
    end
    else if(wr_load_flag) begin              //检测到写端口复位信号时，写地址复位
        sdram_wr1_addr <= wr_max_addr[23:1];
        sw_bank_en1 <= 1'b0;
        rw_bank_flag1 <= 1'b0;
    end
    else if(write_done_flag && sdram_wr_flag) begin//若突发写SDRAM结束，更改写地址
                                             //若未到达写SDRAM的结束地址，则写地址累加                                 
        if(sdram_pingpang_en) begin          //SDRAM 读写乒乓使能
            if(sdram_wr1_addr[21:0] < wr_max_addr - wr_length)
                sdram_wr1_addr <= sdram_wr1_addr + wr_length;
            else begin                       //切换BANK
                rw_bank_flag1 <= ~rw_bank_flag1;   
                sw_bank_en1 <= 1'b1;          //拉高切换BANK使能信号
            end            
        end       
                                             //若突发写SDRAM结束，更改写地址
        else if(sdram_wr1_addr < wr_max_addr - wr_length)
            sdram_wr1_addr <= sdram_wr1_addr + wr_length;
        else                                 //到达写SDRAM的结束地址，回到写起始地址
            sdram_wr1_addr <= wr_max_addr[23:1];
    end
    else if(sw_bank_en1) begin                //到达写SDRAM的结束地址，回到写起始地址
        sw_bank_en1 <= 1'b0;
        if(rw_bank_flag1 == 1'b0)             //切换BANK
            sdram_wr1_addr <= {2'b10,wr_max_addr[22:1]};
        else
            sdram_wr1_addr <= {2'b11,wr_max_addr[22:1]};     
    end
end

//sdram读地址产生模块
always @(posedge clk_ref or negedge rst_n) begin
    if(!rst_n) begin
        sdram_rd0_addr <= 24'd0;
    end 
    else if(rd_load_flag)                    //检测到读端口复位信号时，读地址复位
        sdram_rd0_addr <= rd_min_addr;
    else if(read_done_flag && sdram_rd_flag == 1'b0) begin            //突发读SDRAM结束，更改读地址
                                             //若未到达读SDRAM的结束地址，则读地址累加                 
        if(sdram_pingpang_en) begin          //SDRAM 读写乒乓使能  
            if(sdram_rd0_addr[21:0] < rd_max_addr[23:1] - rd_length)
                sdram_rd0_addr <= sdram_rd0_addr + rd_length;
            else begin                       //到达读SDRAM的结束地址，回到读起始地址
                                             //读取没有在写数据的bank地址
                if(rw_bank_flag0 == 1'b0)     //根据rw_bank_flag的值切换读BANK地址
                    sdram_rd0_addr <= {2'b01,rd_min_addr[21:0]};
                else
                    sdram_rd0_addr <= {2'b00,rd_min_addr[21:0]};    
            end    
        end
                                             //若突发写SDRAM结束，更改写地址
        else if(sdram_rd0_addr < rd_max_addr[23:1] - rd_length)  
            sdram_rd0_addr <= sdram_rd0_addr + rd_length;
        else                                 //到达写SDRAM的结束地址，回到写起始地址
            sdram_rd0_addr <= rd_min_addr;
    end
end

//sdram读地址产生模块
always @(posedge clk_ref or negedge rst_n) begin
    if(!rst_n) begin
        sdram_rd1_addr <= 24'd0;
    end 
    else if(rd_load_flag)                    //检测到读端口复位信号时，读地址复位
        sdram_rd1_addr <= rd_max_addr[23:1];
    else if(read_done_flag && sdram_rd_flag) begin            //突发读SDRAM结束，更改读地址
                                             //若未到达读SDRAM的结束地址，则读地址累加                 
        if(sdram_pingpang_en) begin          //SDRAM 读写乒乓使能  
            if(sdram_rd1_addr[21:0] < rd_max_addr - rd_length)
                sdram_rd1_addr <= sdram_rd1_addr + rd_length;
            else begin                       //到达读SDRAM的结束地址，回到读起始地址
                                             //读取没有在写数据的bank地址
                if(rw_bank_flag1 == 1'b0)     //根据rw_bank_flag的值切换读BANK地址
                    sdram_rd1_addr <= {2'b11,rd_max_addr[22:1]};
                else
                    sdram_rd1_addr <= {2'b10,rd_max_addr[22:1]};    
            end    
        end
                                             //若突发写SDRAM结束，更改写地址
        else if(sdram_rd1_addr < rd_max_addr - rd_length)  
            sdram_rd1_addr <= sdram_rd1_addr + rd_length;
        else                                 //到达写SDRAM的结束地址，回到写起始地址
            sdram_rd1_addr <= rd_max_addr[23:1];
    end
end

//SDRAM读写流程控制
always@(posedge clk_ref or negedge rst_n) begin
    if(!rst_n) begin
        rw_state <= st_idle;
        sdram_wr_req <= 0;
        sdram_rd_req <= 0;
        sdram_wr_flag <= 1'b0;
        sdram_rd_flag <= 1'b0;
        sdram_wr_addr <= 24'd0;
        sdram_rd_addr <= 24'd0;
    end
    else begin
        case(rw_state)
            st_idle : begin
                if(sdram_init_done)
                    rw_state <= st_sdram_done;
            end
            st_sdram_done : begin
                if(wrf0_use >= wr_length) begin
                    sdram_wr_req <= 1'b1;
                    sdram_wr_addr <= sdram_wr0_addr;
                    sdram_wr_flag <= 1'b0;
                    rw_state <= st_wr_sdram;
                end
                else if(wrf1_use >= wr_length) begin
                    sdram_wr_req <= 1'b1;
                    sdram_wr_addr <= sdram_wr1_addr;
                    sdram_wr_flag <= 1'b1;
                    rw_state <= st_wr_sdram;
                end
                else if((rdf0_use < rd_length*2) && read_valid_r2) begin
                    sdram_rd_req <= 1;
                    sdram_rd_flag <= 1'b0;
                    sdram_rd_addr <= sdram_rd0_addr;
                    rw_state <= st_rd_sdram;
                end
                else if((rdf1_use < rd_length*2) && read_valid_r2) begin
                    sdram_rd_req <= 1;
                    sdram_rd_flag <= 1'b1;
                    sdram_rd_addr <= sdram_rd1_addr;
                    rw_state <= st_rd_sdram;
                end                
            end
            st_wr_sdram : begin
                if(write_done_flag) begin
                    sdram_wr_req <= 0;
                    rw_state <= st_sdram_done;
                end    
            end
            st_rd_sdram : begin
                if(read_done_flag) begin
                    sdram_rd_req <= 1'b0;
                    rw_state <= st_sdram_done;
                end
            end
            default : rw_state <= st_idle;
        endcase    
    end
end    

//例化写端口FIFO 0
wrfifo  u0_wrfifo(
    //用户接口
    .wrclk      (clk0_write),            //写时钟
    .wrreq      (wrf0_wrreq),            //写请求
    .data       (wrf0_din),              //写数据
    
    //sdram接口
    .rdclk      (clk_ref),               //读时钟
    .rdreq      (wr0_fifo_rd_req),          //读请求
    .q          (sdram_din0),             //读数据

    .rdusedw    (wrf0_use),              //FIFO中的数据量
    .aclr       (~rst_n | wr_load_flag) //异步清零信号
    );  

//例化写端口FIFO 1
wrfifo  u1_wrfifo(
    //用户接口
    .wrclk      (clk1_write),            //写时钟
    .wrreq      (wrf1_wrreq),            //写请求
    .data       (wrf1_din),              //写数据  
    
    //sdram接口
    .rdclk      (clk_ref),               //读时钟
    .rdreq      (wr1_fifo_rd_req),         //读请求
    .q          (sdram_din1),            //读数据

    .rdusedw    (wrf1_use),              //FIFO中的数据量
    .aclr       (~rst_n | wr_load_flag) //异步清零信号
    );      

//例化读端口FIFO
rdfifo  u0_rdfifo(
    //sdram接口
    .wrclk      (clk_ref),               //写时钟
    .wrreq      (sdram_rd0_ack),          //写请求
    .data       (sdram_dout),            //写数据
    
    //用户接口
    .rdclk      (clk_read),              //读时钟
    .rdreq      (rd0_req),             //读请求
    .q          (rdf0_dout),              //读数据

    .wrusedw    (rdf0_use),               //FIFO中的数据量
    .aclr       (~rst_n | rd_load_flag)  //异步清零信号   
    );

//例化读端口FIFO
rdfifo  u1_rdfifo(
    //sdram接口
    .wrclk      (clk_ref),               //写时钟
    .wrreq      (sdram_rd1_ack),          //写请求
    .data       (sdram_dout),            //写数据  sdram_dout
    
    //用户接口
    .rdclk      (clk_read),              //读时钟
    .rdreq      (rd1_req),             //读请求
    .q          (rdf1_dout),              //读数据

    .wrusedw    (rdf1_use),               //FIFO中的数据量
    .aclr       (~rst_n | rd_load_flag)  //异步清零信号   
    );
   
endmodule 