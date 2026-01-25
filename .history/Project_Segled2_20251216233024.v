//---------------------------------------------------------------------------
//--	文件名		:	Project_Segled2.v
//--	描述		:	动态数码管显示,模12计数器，末状态由参数state_max决定。
//---------------------------------------------------------------------------
module Project_Segled2
(	
	//输入端口 
	CLK_50M,RST_N,
	//输出端口
	SEG_DATA,SEG_EN,
	
	FLAG1,FLAG2,FLAG3
);
	
//---------------------------------------------------------------------------
//--	外部端口声明
//---------------------------------------------------------------------------
input 				CLK_50M;			     	//时钟的端口,开发板用的50M晶振
input				RST_N;				      //复位的端口,低电平复位
output reg 	[ 7:0] 	SEG_EN;				//数码管使能端口
output reg 	[ 7:0] 	SEG_DATA;			//数码管数据端口(查看管脚分配文档或者原理图)
input             FLAG1;
input             FLAG2;
input             FLAG3;

//---------------------------------------------------------------------------
//--  按键消抖与单击脉冲（默认按键低电平按下，50MHz 时钟，约20ms消抖）
//---------------------------------------------------------------------------
parameter DB_CNT_MAX = 20'd1_000_000; // 20ms @50MHz

reg k1_sync0, k1_sync1, k1_level, k1_level_prev; reg [19:0] k1_cnt; reg inc_min_pulse;
reg k2_sync0, k2_sync1, k2_level, k2_level_prev; reg [19:0] k2_cnt; reg inc_hour_pulse;
reg k3_sync0, k3_sync1, k3_level, k3_level_prev; reg [19:0] k3_cnt; reg soft_rst_pulse;

// 两级同步
always @(posedge CLK_50M or negedge RST_N) begin
    if(!RST_N) begin
        k1_sync0 <= 1'b1; k1_sync1 <= 1'b1;
        k2_sync0 <= 1'b1; k2_sync1 <= 1'b1;
        k3_sync0 <= 1'b1; k3_sync1 <= 1'b1;
    end else begin
        k1_sync0 <= FLAG1; k1_sync1 <= k1_sync0;
        k2_sync0 <= FLAG2; k2_sync1 <= k2_sync0;
        k3_sync0 <= FLAG3; k3_sync1 <= k3_sync0;
    end
end

// 消抖 + 产生按下脉冲（高->低稳定翻转产生 1 个 CLK 周期脉冲）
always @(posedge CLK_50M or negedge RST_N) begin
    if(!RST_N) begin
        k1_cnt <= 20'd0; k1_level <= 1'b1; k1_level_prev <= 1'b1; inc_min_pulse <= 1'b0;
    end else begin
        inc_min_pulse <= 1'b0;
        if(k1_sync1 == k1_level) begin
            k1_cnt <= 20'd0;
        end else begin
            if(k1_cnt >= DB_CNT_MAX-1) begin
                k1_level_prev <= k1_level;
                k1_level <= k1_sync1;
                k1_cnt <= 20'd0;
                if(k1_level_prev==1'b1 && k1_sync1==1'b0) inc_min_pulse <= 1'b1; // 按下
            end else begin
                k1_cnt <= k1_cnt + 20'd1;
            end
        end
    end
end

always @(posedge CLK_50M or negedge RST_N) begin
    if(!RST_N) begin
        k2_cnt <= 20'd0; k2_level <= 1'b1; k2_level_prev <= 1'b1; inc_hour_pulse <= 1'b0;
    end else begin
        inc_hour_pulse <= 1'b0;
        if(k2_sync1 == k2_level) begin
            k2_cnt <= 20'd0;
        end else begin
            if(k2_cnt >= DB_CNT_MAX-1) begin
                k2_level_prev <= k2_level;
                k2_level <= k2_sync1;
                k2_cnt <= 20'd0;
                if(k2_level_prev==1'b1 && k2_sync1==1'b0) inc_hour_pulse <= 1'b1;
            end else begin
                k2_cnt <= k2_cnt + 20'd1;
            end
        end
    end
end

always @(posedge CLK_50M or negedge RST_N) begin
    if(!RST_N) begin
        k3_cnt <= 20'd0; k3_level <= 1'b1; k3_level_prev <= 1'b1; soft_rst_pulse <= 1'b0;
    end else begin
        soft_rst_pulse <= 1'b0;
        if(k3_sync1 == k3_level) begin
            k3_cnt <= 20'd0;
        end else begin
            if(k3_cnt >= DB_CNT_MAX-1) begin
                k3_level_prev <= k3_level;
                k3_level <= k3_sync1;
                k3_cnt <= 20'd0;
                if(k3_level_prev==1'b1 && k3_sync1==1'b0) soft_rst_pulse <= 1'b1;
            end else begin
                k3_cnt <= k3_cnt + 20'd1;
            end
        end
    end
end

//---------------------------------------------------------------------------
//--	内部端口声明
//---------------------------------------------------------------------------
reg			[15:0]	time_cnt;			//用来控制数码管闪烁频率的定时计数器
reg			[15:0]	time_cnt_n;			//time_cnt的下一个状态
reg			[ 2:0]	led_cnt;				//用来控制数码管亮灭及显示数据的显示计数器
reg			[ 2:0]	led_cnt_n;			//led_cnt的下一个状态

reg         [27:0]  cnt_1s;
reg         [5:0]   cnt_s;            //max value 64
reg         [5:0]   cnt_m;         
reg         [5:0]   cnt_h;        
//reg         [3:0] cnt_12s; 
//reg         [7:0] cnt_12s_8bit;   

reg         [7:0]   seg0,seg1;         //seconds
reg         [7:0]   seg2,seg3;         //minutes
reg         [7:0]   seg4,seg5;         //hours
wire         [3:0]  ones_bit;
wire         [3:0]  tens_bit;

//二进制转bcd十进制
reg [5:0] s_ones;
reg [5:0] s_tens;
reg [5:0] m_ones;
reg [5:0] m_tens;
reg [5:0] h_ones;
reg [5:0] h_tens;
wire [5:0] s_ones_bit;
wire [5:0] s_tens_bit;
wire [5:0] m_ones_bit;
wire [5:0] m_tens_bit;
wire [5:0] h_ones_bit;
wire [5:0] h_tens_bit;
integer i;

//设置定时器的时间为1ms,计算方法为  (1*10^3)us / (1/50)us  50MHz为开发板晶振
parameter SET_TIME_1MS = 16'd50_000;		
parameter SET_TIME_1S = 'd50_000_000;

parameter SIXTY = 'd5;
parameter TWENTYFORE ='d5;

parameter state_max_yellow = 4'd0;		

parameter SEG_CODE_0 = 8'b1100_0000,
          SEG_CODE_1 = 8'b1111_1001,  
          SEG_CODE_2 = 8'b1010_0100,
          SEG_CODE_3 = 8'b1011_0000,
          SEG_CODE_4 = 8'b1001_1001,
          SEG_CODE_5 = 8'b1001_0010,
          SEG_CODE_6 = 8'b1000_0010,
          SEG_CODE_7 = 8'b1111_1000,
          SEG_CODE_8 = 8'b1000_0000,
          SEG_CODE_9 = 8'b1001_0000;
          


//---------------------------------------------------------------------------
//--	逻辑功能实现	
//---------------------------------------------------------------------------
//////////////倒计时的计数
/*
always @ (posedge CLK_50M or negedge RST_N)  
begin
	if(!RST_N)	
        cnt_1s <= 'd0;
    else if(cnt_1s == SET_TIME_1S - 1)
        cnt_1s <= 'd0;
    else
        cnt_1s <= cnt_1s + 28'b1;
end

always @ (posedge CLK_50M or negedge RST_N)  
begin
	if(!RST_N)	
        cnt_12s <= state_max_yellow;
    else if(cnt_12s == 'd0  && cnt_1s== SET_TIME_1S - 1)
        cnt_12s <= state_max_yellow;
    else if(cnt_1s== SET_TIME_1S - 1)
        cnt_12s <= cnt_12s - 4'd1;
    else
        cnt_12s <= cnt_12s ;    
end
*/
//---------------------------------------------------------------------------
//clk to secnond
always @ (posedge CLK_50M or negedge RST_N)  
begin
	if(!RST_N)	
        cnt_1s <= 28'd0;
    else if(cnt_1s == SET_TIME_1S - 1)
        cnt_1s <= 28'd0;
    else
        cnt_1s <= cnt_1s + 28'b1;
end

//second realize
always @ (posedge CLK_50M or negedge RST_N)  
begin
	if(!RST_N)	
        cnt_s <= state_max_yellow;
    else if(cnt_s == SIXTY-1  && cnt_1s== SET_TIME_1S - 1)
        cnt_s <= 6'd0;
    else if(cnt_1s== SET_TIME_1S - 1)
        cnt_s <= cnt_s + 6'd1;
    else
        cnt_s <= cnt_s ;    
end

//minute realize
always @ (posedge CLK_50M or negedge RST_N)  
begin
	if(!RST_N)	
        cnt_m <= state_max_yellow;
    else if(cnt_m == SIXTY -1  && cnt_s== SIXTY -1 && cnt_1s== SET_TIME_1S - 1)
        cnt_m <= 6'd0;
    else if(cnt_s == SIXTY - 1&& cnt_1s== SET_TIME_1S - 1)
        cnt_m <= cnt_m + 6'd1;
    else
        cnt_m <= cnt_m ;    
end

//hour realize
always @ (posedge CLK_50M or negedge RST_N)  
begin
	if(!RST_N)	
        cnt_h <= state_max_yellow;
    else if(cnt_h == TWENTYFORE -1  && cnt_m == SIXTY - 1 && cnt_s== SIXTY -1 && cnt_1s== SET_TIME_1S - 1)
        cnt_h <= 6'd0;
    else if(cnt_m == SIXTY - 1 && cnt_s == SIXTY - 1 && cnt_1s== SET_TIME_1S - 1)
        cnt_h <= cnt_h + 6'd1;
    else
        cnt_h <= cnt_h ;    
end


/////////////进制转换/////////////////////////////////////////////////
//todo
//second
always @(*) begin
 begin
	s_ones 		= 4'd0;
	s_tens 		= 4'd0;

 end
	
	for(i = 5; i >= 0; i = i - 1) begin
		if (s_ones >= 4'd5) 		s_ones = s_ones + 4'd3;
		if (s_tens >= 4'd5) 		s_tens = s_tens + 4'd3;

		s_tens	 = {s_tens[4:0],s_ones[5]};
		s_ones	 = {s_ones[4:0],cnt_s[i]};
	end

end

assign s_tens_bit = s_tens;
assign s_ones_bit = s_ones;

//minute
always @(*) begin
 begin
	m_ones 		= 4'd0;
	m_tens 		= 4'd0;

 end
	
	for(i = 5; i >= 0; i = i - 1) begin
		if (m_ones >= 4'd5) 		m_ones = m_ones + 4'd3;
		if (m_tens >= 4'd5) 		m_tens = m_tens + 4'd3;

		m_tens	 = {m_tens[4:0],m_ones[5]};
		m_ones	 = {m_ones[4:0],cnt_m[i]};
	end

end

assign m_tens_bit = m_tens;
assign m_ones_bit = m_ones;

//hours
always @(*) begin
 begin
	h_ones 		= 4'd0;
	h_tens 		= 4'd0;

 end
	
	for(i = 5; i >= 0; i = i - 1) begin
		if (h_ones >= 4'd5) 		h_ones = h_ones + 4'd3;
		if (h_tens >= 4'd5) 		h_tens = h_tens + 4'd3;

		h_tens	 = {h_tens[4:0],h_ones[5]};
		h_ones	 = {h_ones[4:0],cnt_h[i]};
	end

end

assign h_tens_bit = h_tens;
assign h_ones_bit = h_ones;
///////////////////////////////////////////////////////////////////////

///////////////////数码管段码值的给出//////////////////////////////////
//second realize
always @(*) begin
if(!RST_N) begin
    seg0 <= SEG_CODE_0;
end else
    case(s_ones_bit)
    'd0: seg0 <= SEG_CODE_0;
    'd1: seg0 <= SEG_CODE_1;
    'd2: seg0 <= SEG_CODE_2;
    'd3: seg0 <= SEG_CODE_3;
    'd4: seg0 <= SEG_CODE_4;
    'd5: seg0 <= SEG_CODE_5;
    'd6: seg0 <= SEG_CODE_6;
    'd7: seg0 <= SEG_CODE_7;
    'd8: seg0 <= SEG_CODE_8;
    'd9: seg0 <= SEG_CODE_9;
    default:seg0 <= SEG_CODE_0;
    endcase
end

always @(*) begin
if(!RST_N) begin
    seg1 <= SEG_CODE_0;
end else
    case(s_tens_bit)
    'd0: seg1 <= SEG_CODE_0;
    'd1: seg1 <= SEG_CODE_1;
    'd2: seg1 <= SEG_CODE_2;
    'd3: seg1 <= SEG_CODE_3;
    'd4: seg1 <= SEG_CODE_4;
    'd5: seg1 <= SEG_CODE_5;
    'd6: seg1 <= SEG_CODE_6;
    'd7: seg1 <= SEG_CODE_7;
    'd8: seg1 <= SEG_CODE_8;
    'd9: seg1 <= SEG_CODE_9;
    default:seg1 <= SEG_CODE_0;
    endcase
end
//minute realize
always @(*) begin
if(!RST_N) begin
    seg2 <= SEG_CODE_0;
end else
    case(m_ones_bit)
    'd0: seg2 <= SEG_CODE_0;
    'd1: seg2 <= SEG_CODE_1;
    'd2: seg2 <= SEG_CODE_2;
    'd3: seg2 <= SEG_CODE_3;
    'd4: seg2 <= SEG_CODE_4;
    'd5: seg2 <= SEG_CODE_5;
    'd6: seg2 <= SEG_CODE_6;
    'd7: seg2 <= SEG_CODE_7;
    'd8: seg2 <= SEG_CODE_8;
    'd9: seg2 <= SEG_CODE_9;
    default:seg2 <= SEG_CODE_0;
    endcase
end

always @(*) begin
if(!RST_N) begin
    seg3 <= SEG_CODE_0;
end else
    case(m_tens_bit)
    'd0: seg3 <= SEG_CODE_0;
    'd1: seg3 <= SEG_CODE_1;
    'd2: seg3 <= SEG_CODE_2;
    'd3: seg3 <= SEG_CODE_3;
    'd4: seg3 <= SEG_CODE_4;
    'd5: seg3 <= SEG_CODE_5;
    'd6: seg3 <= SEG_CODE_6;
    'd7: seg3 <= SEG_CODE_7;
    'd8: seg3 <= SEG_CODE_8;
    'd9: seg3 <= SEG_CODE_9;
    default:seg3 <= SEG_CODE_0;
    endcase
end
//hours realize
always @(*) begin
if(!RST_N) begin
    seg4 <= SEG_CODE_0;
end else
    case(h_ones_bit)
    'd0: seg4 <= SEG_CODE_0;
    'd1: seg4 <= SEG_CODE_1;
    'd2: seg4 <= SEG_CODE_2;
    'd3: seg4 <= SEG_CODE_3;
    'd4: seg4 <= SEG_CODE_4;
    'd5: seg4 <= SEG_CODE_5;
    'd6: seg4 <= SEG_CODE_6;
    'd7: seg4 <= SEG_CODE_7;
    'd8: seg4 <= SEG_CODE_8;
    'd9: seg4 <= SEG_CODE_9;
    default:seg4 <= SEG_CODE_0;
    endcase
end

always @(*) begin
if(!RST_N) begin
    seg5 <= SEG_CODE_0;
end else
    case(h_tens_bit)
    'd0: seg5 <= SEG_CODE_0;
    'd1: seg5 <= SEG_CODE_1;
    'd2: seg5 <= SEG_CODE_2;
    'd3: seg5 <= SEG_CODE_3;
    'd4: seg5 <= SEG_CODE_4;
    'd5: seg5 <= SEG_CODE_5;
    'd6: seg5 <= SEG_CODE_6;
    'd7: seg5 <= SEG_CODE_7;
    'd8: seg5 <= SEG_CODE_8;
    'd9: seg5 <= SEG_CODE_9;
    default:seg5 <= SEG_CODE_0;
    endcase
end
//////////////////////////////////////////////////////////////////////////////////

///////这里是数码管每隔1ms的计数///////////////////////////////////////////////////
//时序电路,用来给time_cnt寄存器赋值
always @ (posedge CLK_50M or negedge RST_N)  
begin
	if(!RST_N)									//判断复位
		time_cnt <= 16'h0;					//初始化time_cnt值
	else
		time_cnt <= time_cnt_n;				//用来给time_cnt赋值
end

//组合电路,实现1ms的定时计数器
always @ (*)  
begin
	if(time_cnt == SET_TIME_1MS)			//判断1ms时间
		time_cnt_n = 16'h0;					//如果到达1ms,定时计数器将会被清零
	else
		time_cnt_n = time_cnt + 16'd1;	//如果未到1ms,定时计数器将会继续累加
end
////////////////////////////////////////////////////////////////////////////////


////////////这里是数码管依次选通的计数//////////////////////////////////////////
//时序电路,用来给led_cnt寄存器赋值
always @ (posedge CLK_50M or negedge RST_N)  
begin
	if(!RST_N)									//判断复位
		led_cnt <= 3'h0;						//初始化led_cnt值
	else
		led_cnt <= led_cnt_n;				//用来给led_cnt赋值
end

//组合电路,判断时间，实现控制显示计数器累加
always @ (*)  
begin
	if(time_cnt == SET_TIME_1MS)			//判断1ms时间	
		led_cnt_n = led_cnt + 1'h1;		//如果到达1ms,计数器进行累加
	else
		led_cnt_n = led_cnt;					//如果未到1ms,计数器保持不变
end
//////////////////////////////////////////////////////////////////////////////

//组合电路,实现数码管的数字显示
always @ (*)
begin
	case (led_cnt)  
		3'b000 : SEG_DATA = seg0;	      //当计数器为0时,数码管将会显示 "0"
		3'b001 : SEG_DATA = seg1;	      //当计数器为1时,数码管将会显示 "0"
		3'b010 : SEG_DATA = seg2;	      //当计数器为2时,数码管将会显示 "0"
		3'b011 : SEG_DATA = seg3;	      //当计数器为3时,数码管将会显示 "0"
		3'b100 : SEG_DATA = seg4;	      //当计数器为4时,数码管将会显示 十位数
		3'b101 : SEG_DATA = seg5;	      //当计数器为5时,数码管将会显示 个位数
        3'b110 : SEG_DATA = SEG_CODE_0;
        3'b111 : SEG_DATA = SEG_CODE_0;
		default: SEG_DATA = SEG_CODE_0;	
	endcase 	
end

//组合电路,控制数码管亮灭
always @ (*)
begin
	case (led_cnt)  
		3'b000 : SEG_EN = 8'b0000_0001;		//当计数器为0时,数码管SEG1显示
		3'b001 : SEG_EN = 8'b0000_0010;		//当计数器为1时,数码管SEG2显示
		3'b010 : SEG_EN = 8'b0000_0100; 		//当计数器为2时,数码管SEG3显示
		3'b011 : SEG_EN = 8'b0000_1000;  	//当计数器为3时,数码管SEG4显示
		3'b100 : SEG_EN = 8'b0001_0000;		//当计数器为4时,数码管SEG5显示
		3'b101 : SEG_EN = 8'b0010_0000;  	//当计数器为5时,数码管SEG6显示
        3'b110 : SEG_EN = 8'b0100_0000;
        3'b111 : SEG_EN = 8'b1000_0000;
		default: SEG_EN = 8'b0000_0000;			
	endcase 	
end
endmodule
