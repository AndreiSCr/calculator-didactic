// DESIGN SPECIFIC
`define ALU_BUS_WITH 		16
`define ALU_AMM_ADDR_WITH 	8
`define ALU_AMM_DATA_WITH	8   

/**

== Input packets ==

Header beat
+-----------------+--------------+---------------+------------------+
| reserved[15:12] | opcode[11:8] | reserved[7:6] | nof_operands[5:0]|
+-----------------+--------------+---------------+------------------+

Payload beat
+-----------------+----------+----------------------+
| reserved[15:10] | mod[9:8] | operands/address[7:0]|
+-----------------+----------+----------------------+

== Output packets ==

Header beat

+----------------+----------+-------------+
| reserved[15:5] | error[4] | opcode[3:0] |
+----------------+----------+-------------+

Payload beat

+-----------------+--------------+
| reserved[15:12] | result[11:0] |
+-----------------+--------------+

*/

module alu(

	 // Output interface
    output reg[`ALU_BUS_WITH - 1:0] 	data_out,
	 output reg 						  		valid_out,
	 output reg							  		cmd_out,

	 //Input interface
	 input [`ALU_BUS_WITH - 1:0] 			data_in,
	 input 							  			valid_in,
	 input 							  			cmd_in,
	 
	 // AMM interface
	 output reg 									 	amm_read,
	 output reg[`ALU_AMM_ADDR_WITH - 1:0] 		amm_address,
	 input [`ALU_AMM_DATA_WITH - 1:0] 			amm_readdata,
	 input 									 			amm_waitrequest,
	 input[1:0] 							 			amm_response,
	 
	 
	 //clock and reset interface
	 input clk,
	 input rst_n
	 
    );
	
	// TODO: Implement Not-so-simple ALU
`define idle 				'h1
`define read_head 		'h2
`define read_payload 	'h3
`define decode 			'h4
`define send 				'h5
`define send2 				'h6
`define error 				'h7
`define op_code 			'h8

	reg[`ALU_BUS_WITH - 1:0]date[63:0],head;
	reg[5:0] numar_val;
	reg[5:0] i=0;
	reg[3:0] operatie;
	reg[3:0] allow=1;
	reg[5:0] state;
	reg[5:0] next_state=`idle;
	reg[`ALU_BUS_WITH - 1:0] head_out,payload;
	reg[`ALU_BUS_WITH - 1:0] rez;
	reg[`ALU_BUS_WITH - 1:0] rez2;
	always@(posedge clk) begin
		
		state<=next_state;	
		
	end
	
	always @(*) begin
			
			if(allow) begin
			
				allow=0;
				case(state)
				
					`idle: begin 
						
						valid_out=0;
						cmd_out=0;
						i=0;
						next_state=`read_head;
												
					end
					
					`read_head: begin
						
						if(valid_in && cmd_in) begin
						
							numar_val=data_in[5:0];
							operatie=data_in[11:8];
							//$display("Head:%h,valoare:%h, Operatie:%h",data_in,numar_val,operatie);
							if(numar_val==0) begin
								
								//$display("Payload error");
								next_state=`error;
						
							end
							else begin
							
								next_state=`read_payload;
							
							end
							
						end
						
						
					end
					
					`read_payload: begin
					
						if(valid_in) begin
						
							if(i<=numar_val-1) begin
							
								date[i]=data_in;
								//$display("Read[%d]=%h",i,date[i]);
								i=i+1;
								
							end
							if(i==numar_val) begin
								
								next_state=`decode;
								i=0;
							
							end
							
						end
							
					end
					
					`error: begin
					
						//$display("Error:");
						head_out={1,operatie};
						payload='hbad;
						next_state=`send;
					
					end
					
					`decode: begin //Obtinere date din memorie
						
						
						if(date[i][8]=='b1) begin
		
							if(amm_waitrequest) begin
							
									amm_address=date[i][7:0];
									amm_read=1;
							
							end
							else begin
							
								if(amm_response) begin
								
									//$display("Memory error");
									next_state=`error;
									amm_read=0;
								
								end
								else begin
								
									date[i]=amm_readdata;
									//$display("Date[%d]=%b",i,date[i]);
									i=i+1;
									amm_read=0;
								
								end
							
							end
						
						end
						else begin

							//$display("Date[%d]=%b",i,date[i]);
							i=i+1;
						
						end
						if(i==numar_val) begin
						
							next_state=`op_code;
							i=0;
							rez=0;
						
						end
						
					end
					
					`op_code: begin //Realizare operatie
						
						//$display("Rezultat: %b",rez);
						case(operatie)
						
							0: begin

								rez=rez+date[i];
									
							end
							
							1: begin
								if(i==0)
								rez=date[i];
								else
								rez=rez&date[i];
							
							end
							
							2: begin
							
								rez=date[i]|rez;
								
							end
							
							3: begin
							
								rez=date[i]^rez;
								
							end
							
							4: begin
								
								if(i==0) begin
									
									rez=~date[i]-'hff00;
									
								end
								else begin
									
									next_state=`error;
								
								end
							
							end
							
							5: begin
								
								if(i==0) begin
									
									rez=date[i]+1;
									
								end
								else begin
									
									next_state=`error;
								
								end
							
							end
							
							6: begin
								
								if(i==0) begin
									
									rez=date[i]-1;
									
								end
								else begin
									
									next_state=`error;
								
								end
							
							end
							
							7: begin
								
								if(i==0) begin
									
									rez=(date[i]^(~0))+1-'hff00;
									
								end
								else begin
									
									next_state=`error;
								
								end
							
							end
							
							8: begin
								
								if(numar_val==2) begin
									
									rez=(date[0]>>date[1]);
									
								end
								else begin
									
									next_state=`error;
								
								end
							
							end
							
							9: begin
								
								if(numar_val==2) begin
									
									rez=(date[0]<<date[1]);
									rez={'h00,rez[7:0]};
									
								end
								else begin
									
									next_state=`error;
								
								end
							
							end
							
						
						endcase
						//$display("Rezultat: %b",rez);
						i=i+1;
						if(next_state!=`error)
						if(i>=numar_val) begin
									
									head_out=operatie;
									payload=rez;
									next_state=`send;
								
						end
					
					end
					
					`send: begin
					
						data_out=head_out;
						valid_out=1;
						cmd_out=1;
						//$display("Head:%h",data_out);				
						next_state=`send2;
					
					end
					
					`send2: begin
						
						data_out=payload;
						cmd_out=0;
						//$display("Payload:%b",data_out);	
						next_state=`idle;	
						
					end
					
				endcase
			
			end
			if(!clk) begin
			
				allow=1;
				
			end
	
	end
	
endmodule
