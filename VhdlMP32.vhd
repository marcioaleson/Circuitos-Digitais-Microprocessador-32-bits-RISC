--****************************************** Header Section **************************************
--Project		:
--Names			:
--Group			:
--Data			:
--**************************************** End Header Section **********************************
--contact: ramonn76@gmail.com

library ieee;
LIBRARY lpm;

USE lpm.lpm_components.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
library altera_mf;
use altera_mf.altera_mf_components.all;

entity MP32 is
GENERIC ( data		:STRING := "data.mif";
		  instruc	:STRING := "instruction.mif");
port(
	clock, reset				: in std_logic;
	instruction_register_out	: out std_logic_vector(31 downto 0);
	output						: OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
	buffer_out					: OUT STD_LOGIC_VECTOR(31 DOWNTO 0));
end MP32;

architecture a of MP32 is
type STATE_TYPE is (reset_pc, fetch, decode, execute_add,execute_addi,execute_sub,execute_mult,execute_add,execute_div,execute_swr,execute_lwr,execute_and,execute_or,execute_xor,execute_beq,execute_bne,execute_copy,execute_lui,execute_jump,execute_jump_an_link,execute_jump_register);

TYPE gerreg IS ARRAY (31 DOWNTO 0) OF STD_LOGIC_VECTOR(31 DOWNTO 0);


SIGNAL geral_registers					: gerreg;							-- registers bank
SIGNAL state							:STATE_TYPE;						-- states
signal instruction_register 			: std_logic_vector(31 downto 0); 	
signal memory_buffer_register	 		: std_logic_vector(31 downto 0); 
SIGNAL memory_data_register				: std_logic_vector(31 downto 0);
SIGNAL memory_inst_data					: std_logic_vector(31 downto 0);
signal program_counter					: std_logic_vector(31 downto 0);
signal memory_address_register			: std_logic_vector(31 downto 0);
signal memory_write						: std_logic;
signal memory_inst_address				: std_logic_vector(31 downto 0);

begin
	
memory_instruction: altsyncram
	GENERIC MAP(
		operation_mode=>"SINGLE_PORT",
		width_a=>32,
		widthad_a=>10,
		lpm_type=>"altsyncram",
		outdata_reg_a=> "UNREGISTERED",
				--reads in mif file for initial progam and data values
		init_file => instruc,
		intended_device_family=>"Cyclone")
		
	PORT MAP(
			clock0=>clock,
			address_a=>memory_inst_address(9 downto 0),
			q_a=>memory_inst_data);
			
memory_datas: altsyncram
	GENERIC MAP(
		operation_mode=>"SINGLE_PORT",
		width_a=>32,
		widthad_a=>10,
		lpm_type=>"altsyncram",
		outdata_reg_a=> "UNREGISTERED",
				--reads in mif file for initial progam and data values
		init_file => data,
		intended_device_family=>"Cyclone")
		
	PORT MAP(wren_a=> memory_write,
			clock0=>clock,
			address_a=>memory_address_register(9 downto 0),
			data_a=> memory_buffer_register,
			q_a=>memory_data_register);
			
	-- signals for simulation		
	instruction_register_out <= instruction_register;
	output <= geral_registers(conv_integer(instruction_register(25 DOWNTO 21)));
	buffer_out <= memory_data_register;		
	
	
process (CLOCK,RESET)
	begin
	if reset='1' then
		state <= reset_pc;
	elsif clock'event and clock = '1' then
			--===============================================
							--STATE MACHINE
			--===============================================
		case state is
		    --===============================================
								--reset
			--===============================================
		when reset_pc =>
			program_counter		<="00000000000000000000000000000000";
			state				<=fetch;			
		
			--=============================================
								--fetch
			--=============================================
			
		when fetch=>
			instruction_register	<= memory_inst_data;
			program_counter			<= program_counter + 1;
			state					<=decode;			
			-----------------------------------------------
			--============================================
			--					--decode
			--============================================
			
		when decode=>
			case instruction_register(31 downto 26) is
				when "000000" =>
					state <= execute_add;
				when "000001" =>
					state <= execute_swr;
				when "000011" =>
					state <= execute_lui;
					
				when "111111" =>
					state <= execute_jump;
				when others =>
					state <= fetch;
			end case;
			------------------------------------------------------
			--====================================================
						-- instructions arithmetic
			--====================================================
		when execute_add =>
			
				geral_registers(conv_integer(instruction_register(25 DOWNTO 21))) <= geral_registers(conv_integer(instruction_register(20 DOWNTO 16))) + geral_registers(conv_integer(instruction_register(15 DOWNTO 11)));
			
			state  <= fetch;
		 -------------------------------------------------------- 
		 --======================================================
						-- instructions for accessing the memory
		 --======================================================
			
		when execute_swr =>
			state		<= fetch;
			
		---------------------------------------------------------
		--======================================================
						-- jump instructions
		 --======================================================
		when execute_jump =>
			program_counter		<=  program_counter + ("000000"&instruction_register(25 downto 0));
			state				<=  fetch;
			
		when execute_lui =>
			geral_registers(conv_integer(instruction_register(25 DOWNTO 21))) <= "00000000000"&instruction_register(20 downto 0);
			state <= fetch;
			
		when others =>
			state <= fetch;
		end case;
	end if;
	end process;

with state select
memory_inst_address <= 		"00000000000000000000000000000000"								when reset_pc,
							program_counter + ("000000"&instruction_register(25 downto 0))	when execute_jump,
							program_counter													when others;

with state select								
memory_address_register <= 	geral_registers(conv_integer(instruction_register(20 DOWNTO 16)))+("0000000000000000"&instruction_register(15 downto 0))	WHEN execute_swr,
							"00000000000000000000000000000000" 																							WHEN OTHERS;

WITH state SELECT
memory_buffer_register <=	geral_registers(conv_integer(instruction_register(25 DOWNTO 21)))		WHEN execute_swr,
							"00000000000000000000000000000000"										WHEN OTHERS;
with state select
		memory_write <=	'1'			when execute_swr,
						'0'			when others;
end a;