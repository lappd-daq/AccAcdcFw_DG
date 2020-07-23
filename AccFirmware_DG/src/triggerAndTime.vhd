--------------------------------------------------
-- University of Chicago
-- LAPPD system firmware
--------------------------------------------------
-- module		: 	Hardware_trigger.vhd
-- author		: 	ejo
-- date			: 	10/2012
-- description	:  
--------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

use work.defs.all;

entity triggerAndTime is
port(
	sys_clock				:  in		std_logic;
	reset 					: 	in		std_logic;
	xEXT_TRIGGER			:	in		std_logic;
	xTRIG_CLK				: 	in		std_logic;
	xUSB_DONE				:  in		std_logic;
	xMODE						: 	in		std_logic;
	xTRIG_DELAY				:  in		std_logic_vector(6 downto 0);
	xSOFT_TRIG_IN			:  in		std_logic_vector(N-1 downto 0);
	xCC_READ_MODE     	:  in		std_logic_vector(2 downto 0);	
	xAUX_TRIG_0				:  in		std_logic;
	xAUX_TRIG_1				:  in		std_logic;
	xAUX_TRIG_2_DC			:	in		std_logic;
	xAUX_TRIG_3_DC			: 	in		std_logic;
	XACDC_WAITING			: 	in 	std_logic;
	xEVENT_AND_TIME_RESET:	in   	std_logic;
	xTRIG_FROM_FRONTEND	: 	in 	std_logic_vector(N-1 downto 0);		
	xTRIG_SOURCE      	: 	in 	std_logic_vector(2 downto 0);
	xSLAVE_DEV_HARD_RESET : in 	std_logic;
	xEXT_TRIG_VALID		: 	in 	std_logic;
	xSOFT_TRIG_BIN			: 	in 	std_logic_vector(2 downto 0);	
	xMASTERHI_SLAVELO		: 	in 	std_logic;
	xFROM_SYSTEM_TRIGGER : 	in 	std_logic;	
	xTRIG_OUT				:  out	std_logic_vector(N-1 downto 0);	
	xSYSTEM_CLOCK_COUNTER:	out	std_logic_vector(47 downto 0);
	xEVENT_COUNT			:	out	std_logic_vector(31 downto 0);
	xCLOCKED_TRIG_OUT		: 	out 	std_logic;
	xBIN_COUNT				:  out   std_logic_vector(15 downto 0);
	xAUX_TRIG_COUNTERS	:  out	std_logic_vector(15 downto 0));	
end triggerAndTime;
	
   
architecture Behavioral of triggerAndTime is
	type trig_count_state_type is (WAIT_FOR, TRIG);
	signal trigger_state	: trig_count_state_type;
	
	type AUX_TRIG_0_counter_STATE_type is (COUNT, HOLD);
	signal AUX_TRIG_0_counter_STATE : AUX_TRIG_0_counter_STATE_type;
	
	type AUX_TRIG_1_counter_STATE_type is (COUNT, HOLD);
	signal AUX_TRIG_1_counter_STATE : AUX_TRIG_1_counter_STATE_type;
	
	signal trigger_counter 			:	std_logic_vector(6 downto 0);
	signal LATCHED_TRIG				:	std_logic;

	signal FIRMWARE_RESET			:	std_logic;
	signal CLOCKED_TRIG				:	std_logic; 
	signal CLOCKED_TRIG_OUT			:	std_logic; 

	signal SYSTEM_CLOCK_COUNTER	:	std_logic_vector(47 downto 0);
	signal LATCHED_SYSTEM_CLOCK	:	std_logic_vector(47 downto 0);
	signal EVENT_COUNT				:	std_logic_vector(31 downto 0);	

	signal BIN_COUNT 					: 	std_logic_vector(1 downto 0);
	signal BIN_COUNT_SAVE 			: 	std_logic_vector(1 downto 0) := "00";
	signal SOFT_TRIG_OR 				: 	std_logic;
	signal SOFT_TRIG 					:	std_logic := '0';
	signal BIN_COUNT_START 			:	std_logic := '0';
	
	signal AUX_TRIG_0 				: 	std_logic;
	signal AUX_TRIG_0_counter 		: 	std_logic_vector(6 downto 0);
	signal AUX_TRIG_0_counter_latch: std_logic_vector(6 downto 0);
	
	signal AUX_TRIG_1 				: 	std_logic;
	signal AUX_TRIG_1_counter 		: 	std_logic_vector(6 downto 0);
	signal AUX_TRIG_1_counter_latch: std_logic_vector(6 downto 0);
	
	signal AUX_TRIG_2 				: 	std_logic;
	signal AUX_TRIG_3 				: 	std_logic;
	
	signal INTERNAL_TRIGGER 		: 	std_logic;
	signal USE_BEAM_ON				: 	std_logic;
	
	signal make_time_stamp 			: 	std_logic;
	signal check_bin		  			: 	std_logic_vector(1 downto 0);
	signal some_trig_to_count 		: 	std_logic;
	signal SOFT_TRIG_OUT				:  std_logic_vector(N-1 downto 0);

	signal systemTime_low: std_logic_vector(31 downto 0);
	signal systemTime_high: std_logic_vector(31 downto 0);

begin

FIRMWARE_RESET <= xUSB_DONE;

xSYSTEM_CLOCK_COUNTER 	<= LATCHED_SYSTEM_CLOCK;
xEVENT_COUNT 				<= EVENT_COUNT;

SOFT_TRIG_OR <= xSOFT_TRIG_IN(0) or xSOFT_TRIG_IN(1) or xSOFT_TRIG_IN(2) or xSOFT_TRIG_IN(3);
--xBIN_COUNT <= "00000000" & xMODE & BIN_COUNT_START & BIN_COUNT_SAVE(2 downto 0) & BIN_COUNT(2 downto 0);
xBIN_COUNT <= "00000000" & xMODE & BIN_COUNT_START & "0" & BIN_COUNT_SAVE(1 downto 0) & "0" & BIN_COUNT(1 downto 0);

xAUX_TRIG_COUNTERS <= AUX_TRIG_1_counter_latch & AUX_TRIG_0_counter_latch & AUX_TRIG_3 & AUX_TRIG_2;

CLOCKED_TRIG_OUT  <= (xFROM_SYSTEM_TRIGGER and (not xMASTERHI_SLAVELO)) or (CLOCKED_TRIG and xMASTERHI_SLAVELO);
xTRIG_OUT    		<= (SOFT_TRIG_OUT(7) or CLOCKED_TRIG_OUT) &
							(SOFT_TRIG_OUT(6) or CLOCKED_TRIG_OUT) &
							(SOFT_TRIG_OUT(5) or CLOCKED_TRIG_OUT) &
							(SOFT_TRIG_OUT(4) or CLOCKED_TRIG_OUT) &
							(SOFT_TRIG_OUT(3) or CLOCKED_TRIG_OUT) &
							(SOFT_TRIG_OUT(2) or CLOCKED_TRIG_OUT) &
							(SOFT_TRIG_OUT(1) or CLOCKED_TRIG_OUT) &
							(SOFT_TRIG_OUT(0) or CLOCKED_TRIG_OUT);
xCLOCKED_TRIG_OUT	<= CLOCKED_TRIG_OUT;  
--process(xMASTERHI_SLAVELO)
--begin
--	if	xMASTERHI_SLAVELO = '0' then
--		xCLOCKED_TRIG_OUT <= xFROM_SYSTEM_TRIGGER;
--	elsif xMASTERHI_SLAVELO = '1' then	
--		xCLOCKED_TRIG_OUT <= CLOCKED_TRIG;
--	end if;
--end process;

process(sys_clock, reset, xEVENT_AND_TIME_RESET, xTRIG_CLK)
begin	
	if reset = '1' or xEVENT_AND_TIME_RESET = '1'  then
		BIN_COUNT_START <= '0';
	elsif falling_edge(xTRIG_CLK) and xEVENT_AND_TIME_RESET = '0' then
		BIN_COUNT_START <= '1';
	end if;
end process;
--fine 'binning' counter cycle
process(reset, xTRIG_CLK, BIN_COUNT_START)
begin
	if BIN_COUNT_START = '0' then
		BIN_COUNT <= (others => '1');
	elsif rising_edge(xTRIG_CLK) and BIN_COUNT_START = '1' then
		BIN_COUNT <= BIN_COUNT + 1;
	elsif falling_edge(xTRIG_CLK) then
		check_bin <= BIN_COUNT;
	end if;
end process;




--driver for 48 bit system clock/timestamp mangement
process(sys_clock)
begin
	if (rising_edge(sys_clock)) then
      if (reset = '1' or xEVENT_AND_TIME_RESET = '1') then
         SYSTEM_CLOCK_COUNTER <= (others => '0');
      else
         SYSTEM_CLOCK_COUNTER <= SYSTEM_CLOCK_COUNTER + 1;
      end if;
	end if;
end process;



process(reset, xEVENT_AND_TIME_RESET, make_time_stamp)
begin
	if reset = '1' or xEVENT_AND_TIME_RESET = '1' then
		BIN_COUNT_SAVE       <= (others => '0');
	elsif rising_edge(make_time_stamp)then	
		BIN_COUNT_SAVE       <= BIN_COUNT;
	end if;
end process;

process(reset, xEVENT_AND_TIME_RESET, some_trig_to_count)
begin
	if reset = '1' or xEVENT_AND_TIME_RESET = '1' then
		LATCHED_SYSTEM_CLOCK <= (others => '0');
		EVENT_COUNT <= (others => '0');
	elsif rising_edge(some_trig_to_count) then	
		LATCHED_SYSTEM_CLOCK <= SYSTEM_CLOCK_COUNTER;	
		EVENT_COUNT <= EVENT_COUNT + 1;
	end if;
end process;
process(reset, xEVENT_AND_TIME_RESET, sys_clock)
begin
	if reset = '1' or xEVENT_AND_TIME_RESET = '1' then
		some_trig_to_count <= '0';
	elsif falling_edge(sys_clock) then	
		some_trig_to_count <= SOFT_TRIG or LATCHED_TRIG;
	end if;
end process;
--EXTERNAL TRIGGER REGISTER 
process(xTRIG_SOURCE, xEXT_TRIGGER)
begin
	case xTRIG_SOURCE(2 downto 1) is
		when "00" =>
			INTERNAL_TRIGGER <= xEXT_TRIGGER;
		when "01" => 
			INTERNAL_TRIGGER <= xEXT_TRIGGER;
		when "10" => 
			INTERNAL_TRIGGER <= xEXT_TRIGGER;		
		when "11" => 
			INTERNAL_TRIGGER <= xEXT_TRIGGER;
		when others=>
			INTERNAL_TRIGGER <= xEXT_TRIGGER;
	end case;
	
	case xTRIG_SOURCE(0) is
		when '0' =>
			USE_BEAM_ON <= '0';
		when '1' =>
			USE_BEAM_ON <= '1';
		when others=>
			USE_BEAM_ON <= '0';
		end case;
end process;
	
	
---This process latches the external trigger signal on its rising edge	
--Evan changed this 6/1/2019 to very simply look at the SMA external trigger
-- and if the USB commands have told us to have xext_trig_valid and "wait for sys"
--then it should send a trigger signal to the ACDCs. 
process(INTERNAL_TRIGGER, xEXT_TRIG_VALID, xACDC_WAITING)
begin  
	if xEXT_TRIG_VALID = '0' or xACDC_WAITING = '0' then
		---
		LATCHED_TRIG <= '0';
		
	elsif rising_edge(INTERNAL_TRIGGER) and xEXT_TRIG_VALID = '1' and xACDC_WAITING = '1' then
		---
		LATCHED_TRIG <= '1';
		---
	
	end if;
end process;
---This process registers the latched signal w.r.t. fast clock.		
process(reset, LATCHED_TRIG, FIRMWARE_RESET, xTRIG_CLK)
begin
	if reset = '1' or FIRMWARE_RESET = '1' or LATCHED_TRIG = '0' then
		CLOCKED_TRIG <= '0';
	elsif rising_edge(xTRIG_CLK) and (LATCHED_TRIG = '1') then	
		CLOCKED_TRIG <= '1';
	end if;
end process;

--SOFT_TRIG_OUT <= xSOFT_TRIG_IN;
--SOFTWARE TRIGGER REGISTER
process(check_bin, reset, SOFT_TRIG_OR, FIRMWARE_RESET, xTRIG_CLK, xSLAVE_DEV_HARD_RESET, xSOFT_TRIG_BIN)
begin
	if reset = '1' or FIRMWARE_RESET = '1' then
		SOFT_TRIG <= '0';
		SOFT_TRIG_OUT <= (others =>'0');
	elsif rising_edge(xTRIG_CLK) and (SOFT_TRIG_OR = '1') and xSOFT_TRIG_BIN(0) = '0' then	
		SOFT_TRIG <= '1';
		SOFT_TRIG_OUT <= xSOFT_TRIG_IN;
	elsif rising_edge(xTRIG_CLK) and (SOFT_TRIG_OR = '1') and xSOFT_TRIG_BIN(0) = '1' and 
	(xSOFT_TRIG_BIN(2 downto 1) = check_bin(1 downto 0)) then	
		SOFT_TRIG <= '1';
		SOFT_TRIG_OUT <= xSOFT_TRIG_IN;
	elsif rising_edge(xTRIG_CLK) and xSLAVE_DEV_HARD_RESET = '1' then
		SOFT_TRIG_OUT <= (others=>'1');
	end if;
end process;


process(reset, FIRMWARE_RESET, xTRIG_CLK, xMODE, CLOCKED_TRIG, SOFT_TRIG)
begin
	if reset = '1' or FIRMWARE_RESET = '1' then
		--CLOCKED_TRIG <= '0';
		trigger_counter <= (others=>'0');
		make_time_stamp <= '0';
		trigger_state <= WAIT_FOR;
    
	elsif falling_edge(xTRIG_CLK) and (CLOCKED_TRIG = '1' or SOFT_TRIG = '1') then
	--add adjustable firmware delay
--		case trigger_state is
--			
--			when WAIT_FOR =>
--				if (trigger_counter = xTRIG_DELAY) then --or (trigger_counter = '111111111') then	
--				if CLOCKED_TRIG = '1' or SOFT_TRIG = '1'then
					make_time_stamp <= '1';
					--BIN_COUNT_SAVE <= BIN_COUNT;
					--CLOCKED_TRIG <= xMODE;
--					trigger_state <= TRIG;
	--			end if;
--				else
--					trigger_counter <= trigger_counter + 1;
--				end if;
--				
--			when TRIG =>
--				make_time_stamp <= '0';
				--CLOCKED_TRIG <= xMODE;				
--								
--		end case;
	end if;
end process;



process(sys_clock)
begin  
	if (rising_edge(sys_clock)) then
   
      if (reset = '1' or FIRMWARE_RESET = '1' or xMODE = '0') then
         AUX_TRIG_0_counter <= (others =>'0');
         AUX_TRIG_0_counter_STATE <= COUNT;
		
      elsif (LATCHED_TRIG = '1') then
         case AUX_TRIG_0_counter_STATE is 
			
            when COUNT => 
               AUX_TRIG_0_counter <= AUX_TRIG_0_counter + 1;
                  if AUX_TRIG_0_counter > 12 then
                     AUX_TRIG_0_counter_STATE <= HOLD;
                  end if;
			
            when HOLD =>
               AUX_TRIG_0_counter <= (others => '1');
				
         end case;
      end if;
	end if;
end process;
		
process(reset, xAUX_TRIG_0, LATCHED_TRIG, FIRMWARE_RESET, xMODE, AUX_TRIG_0_counter)
begin  
	if reset = '1' or FIRMWARE_RESET = '1' or xMODE = '0' then
		AUX_TRIG_0_counter_latch <= (others =>'0');
	elsif rising_edge(xAUX_TRIG_0) and LATCHED_TRIG = '1' and AUX_TRIG_0_counter < 9 then
		AUX_TRIG_0_counter_latch <= AUX_TRIG_0_counter + 1;
	end if;
end process;

process(sys_clock)
begin  
	if (rising_edge(sys_clock)) then
      if (reset = '1' or FIRMWARE_RESET = '1' or xMODE = '0') then
         AUX_TRIG_1_counter <= (others =>'0');
         AUX_TRIG_1_counter_STATE <= COUNT;
		
      elsif (LATCHED_TRIG = '1') then
         case AUX_TRIG_1_counter_STATE is 
			
            when COUNT => 
               AUX_TRIG_1_counter <= AUX_TRIG_1_counter + 1;
                  if AUX_TRIG_1_counter > 12 then
                     AUX_TRIG_1_counter_STATE <= HOLD;
                  end if;
			
            when HOLD =>
               AUX_TRIG_1_counter <= (others => '1');
               
         end case;
      end if;
	end if;
end process;
		
process(reset, xAUX_TRIG_1, LATCHED_TRIG, FIRMWARE_RESET, xMODE, AUX_TRIG_1_counter)
begin  
	if reset = '1' or FIRMWARE_RESET = '1' or xMODE = '0' then
		AUX_TRIG_1_counter_latch <= (others =>'0');
	elsif rising_edge(xAUX_TRIG_1) and LATCHED_TRIG = '1' and AUX_TRIG_1_counter < 9 then
		AUX_TRIG_1_counter_latch <= AUX_TRIG_1_counter + 1;
	end if;
end process;

process(reset, FIRMWARE_RESET, xMODE, LATCHED_TRIG)
begin
	if reset = '1' or FIRMWARE_RESET = '1' or xMODE = '0' then
		AUX_TRIG_2 <= '0';
	elsif rising_edge(LATCHED_TRIG) then
		AUX_TRIG_2 <= xAUX_TRIG_2_DC;
	end if;
end process;

process(reset, FIRMWARE_RESET, xMODE, LATCHED_TRIG)
begin
	if reset = '1' or FIRMWARE_RESET = '1' or xMODE = '0' then
		AUX_TRIG_3 <= '0';
	elsif rising_edge(LATCHED_TRIG) then
		AUX_TRIG_3 <= xAUX_TRIG_3_DC;
	end if;
end process;



end Behavioral;
					
				
				
		

						



