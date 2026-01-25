module top(
	Clk,
	Rst_n,
    
	SH_CP,
	ST_CP,
	DS,
	
	KEY1,
	KEY2,
	KEY3
);
	input Clk;	//50M
	input Rst_n;
	
	//PHY PIN
	output SH_CP;	//shift clock
	output ST_CP;	//latch data clock
	output DS;	   //shift serial data
	input KEY1;
	input KEY2;
	input KEY3;

	wire [7:0] SEG_EN;     //数码管位选（选择当前要显示的数码管）
	wire [7:0] SEG_DATA;   //数码管段选（当前要显示的内容）	



Project_Segled2 Project_Segled2_inst
(	

        .CLK_50M     (Clk)      ,				//时钟的端口,开发板用的50M晶振
        .RST_N       (Rst_n)    ,				//复位的端口,低电平复位
        .SEG_EN      (SEG_EN)   ,				//数码管使能端口
        .SEG_DATA    (SEG_DATA) ,			   //数码管数据端口(查看管脚分配文档或者原理图)
			  .FLAG1       (KEY1)    ,
			  .FLAG2       (KEY2)    ,
			  .FLAG3       (KEY3)     
);
	
	HC595_Driver HC595_Driver(
		.Clk(Clk),
		.Rst_n(Rst_n),
		.Data({SEG_DATA,SEG_EN}),
		.S_EN(1'b1),
		.SH_CP(SH_CP),
		.ST_CP(ST_CP),
		.DS(DS)
	);
endmodule
