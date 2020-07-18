`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/03/08 19:59:14
// Design Name: 
// Module Name: ft60x_top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module ft60x_top(
// system control
input                  Rstn_i,//fpga reset
output                 USBSS_EN,//power enable    
// FIFO interface     
input                  CLK_i,
inout [31:0]           DATA_io,
inout [3:0]            BE_io,
input                  RXF_N_i,   // ACK_N
input                  TXE_N_i,
output reg             OE_N_o,
output reg             WR_N_o,    // REQ_N
output                 SIWU_N_o,
output reg             RD_N_o,
output                 WAKEUP_o,
output [1:0]           GPIO_o,
//
output reg [2:0]            LED3bit//

);

assign USBSS_EN = 1'b1;    
assign WAKEUP_o = 1'b1;
assign GPIO_o   = 2'b00;    
assign SIWU_N_o = 1'b0;


wire rstn ;
assign rstn = Rstn_i;

wire [31:0] FIFO_Din;
reg [31:0] FIFO_Dout;
wire [3 :0] BE_RD;
wire [ 3:0] BE_WR;
wire FIFO_F,FIFO_V;
(*noprune*) reg [1:0] USB_S;
wire FIFO_WR, FIFO_RD;

//read or write flag
assign FIFO_Din =  (USB_S==2'd1) ? DATA_io   : 32'd0;//read data dir
assign DATA_io  =  (USB_S==2'd2) ? FIFO_Dout : 32'bz;// write data dir
assign BE_RD    =  (USB_S==2'd1) ? BE_io   : 4'd0;
assign BE_io    =  (USB_S==2'd2) ? BE_WR   : 4'bz;// write data dir
assign BE_WR    =  4'b1111;

// assign FIFO_Dout = {FIFO_Din[7:0],FIFO_Din[15:8]};
// assign FIFO_WR    = (!RD_N_o)&&(!RXF_N_i);
// assign FIFO_RD    = (!WR_N_o)&&(!TXE_N_i);

wire data_rd_valid,data_wr_valid;
assign data_rd_valid = (RD_N_o==1'b0)&&(RXF_N_i==1'b0);
assign data_wr_valid = (WR_N_o==1'b0)&&(TXE_N_i==1'b0);


localparam [1:0] USB_S_idle =  2'd0;
localparam [1:0] USB_S_read =  2'd1;
localparam [1:0] USB_S_writ =  2'd2;
// localparam [1:0] USB_S_idle =  2'd3;



reg [15:0] rd_cnt/*synthesis noprune*/;

reg [31:0] cmd_data[0:1];
always@(posedge CLK_i or negedge rstn) begin
    if(!rstn) begin
        cmd_data[0] = 32'b0;
        cmd_data[1] = 32'b0;
    end
    else begin
        if (data_rd_valid == 1'b1) begin
            cmd_data[0] <= FIFO_Din;
            cmd_data[1] <= cmd_data[0];
            rd_cnt <= rd_cnt + 1'b1;
        end
        else begin
            cmd_data[0] <= cmd_data[0];
            cmd_data[1] <= cmd_data[1];
            rd_cnt <= 32'b0 ;
        end
    end
end

// always@(posedge CLK_i or negedge rstn) begin
//     if (!rstn) begin
//         FIFO_Dout <= 32'b0;
//     end
//     else 
//         if (data_wr_valid == 1'b1) FIFO_Dout <= 32'h12345678;
//         else FIFO_Dout <= FIFO_Dout;

// end



reg [15:0] frame_header/*synthesis noprune*/;
reg [15:0] frame_end/*synthesis noprune*/;
reg [15:0] frame_data [0:1]/*synthesis noprune*/;

always@(posedge CLK_i or negedge rstn) begin
	if(!rstn) begin
		frame_header <= 16'h0;
		frame_data[1] <= 16'h0;
		frame_data[0] <= 16'h0;
		frame_end <= 16'h0;
	end
	else begin
		frame_header <= {cmd_data[1][7:0],cmd_data[1][15:8]};
		frame_data[1] <= {cmd_data[1][23:16],cmd_data[1][31:24]};//i2c地址
		frame_data[0] <= {cmd_data[0][7:0],cmd_data[0][15:8]};//i2c 数据
		frame_end <= {cmd_data[0][23:16],cmd_data[0][31:24]};
	end
end


always @(posedge CLK_i or negedge rstn) begin
    if(!rstn) begin
        LED3bit <= { 1'b0, USB_S[1:0]};
        LED3bit <= 3'b0;
    end
    else begin
        if ((frame_header == 16'hA56B)&&(frame_end==16'h7CD8)) begin
            FIFO_Dout <= { frame_data[1][7:0],frame_data[1][7:0],frame_data[1][7:0],frame_data[1][7:0]};
        end
        else
            FIFO_Dout <= FIFO_Dout;
        // LED3bit <= { 1'b0, USB_S[1:0]};
    end

end





always @(posedge CLK_i)begin
    if(!rstn)begin
        USB_S <= 2'd0;
        OE_N_o <= 1'b1;
        RD_N_o <= 1'b1; 
        WR_N_o <= 1'b1; 
    end 
    else begin
        case(USB_S)
        0:begin
            OE_N_o <= 1'b1;
            RD_N_o <= 1'b1; 
            WR_N_o <= 1'b1; 
            if((!RXF_N_i)) begin
                USB_S  <= 2'd1;
                OE_N_o <= 1'b0;   
            end
            else if(!TXE_N_i)begin
                USB_S  <= 2'd2;
            end
        end
        1:begin
            RD_N_o <= 1'b0;   
            if(RXF_N_i) begin
                USB_S  <= 2'd0;
                RD_N_o <= 1'b1;
                OE_N_o <= 1'b1;      
            end
        end
        2:begin
            WR_N_o <= 1'b0; 
            if(TXE_N_i) begin
                USB_S  <= 2'd0;
                WR_N_o <= 1'b1; 
             end
        end
        3:begin
            USB_S <= 2'd0;
        end
        endcase                 
    end
end





endmodule

