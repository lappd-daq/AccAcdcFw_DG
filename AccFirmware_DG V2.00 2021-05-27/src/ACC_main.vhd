---------------------------------------------------------------------------------
-- Univ. of Chicago  
--    
--
-- PROJECT:      ANNIE 
-- FILE:         ACC_main.vhd
-- AUTHOR:       D. Greenshields
-- DATE:         Oct 2020
--
-- DESCRIPTION:  top-level firmware module for ACC
--
---------------------------------------------------------------------------------


library IEEE; 
use ieee.std_logic_1164.all;
USE ieee.numeric_std.ALL; 
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.defs.all;
use work.components.all;
use work.LibDG.all;



entity ACC_main is
	port(		
		clockIn			: in	clockSource_type;
		clockCtrl		: out	clockCtrl_type;
		systemIn			: in 	systemIn_type;	-- common lvds connetions 2x digital input (single RJ45 connector)
		systemOut		: out systemOut_type; -- common lvds connetions 1x digital output (single RJ45 connector)
		LVDS_In			: in	LVDS_inputArray_type;
		LVDS_Out			: out LVDS_outputArray_type;		
		led            : out	std_logic_vector(2 downto 0); -- red(2), yellow(1), green(0)				
		SMA				: inout	std_logic_vector(1 to 6);	
		USB_in			: in USB_in_type;
		USB_out			: out USB_out_type;
		USB_bus			: inout USB_bus_type;
		DIPswitch		: in   std_logic_vector (9 downto 0)		-- switch reads as a 10-bit binary number msb left (sw1), lsb right (sw10); switch open = logic 1		
	);
end ACC_main;
	
	
	
architecture vhdl of	ACC_main is


	signal	ledSetup				: ledSetup_array_type;
	signal	ledDrv				: 	std_logic_vector(2 downto 0);
	signal	clock					: 	clock_type;
	signal	reset					: 	reset_type;
	signal	usbTx					:	usbTx_type;
	signal	usbRx					:	usbRx_type;
	signal	uartTx				:	uartTx_type;
	signal	uartRx				:	uartRx_type;
	signal	trig					:	trigSetup_type;
   signal   usb_busWriteEnable: std_logic_vector(15 downto 0);
   signal   usb_busReadEnable: std_logic;   
   signal   rxBuffer_readReq: std_logic;
   signal   rxBuffer_resetReq: std_logic_vector(7 downto 0);
   signal   localInfo_readReq : std_logic;
   signal   localInfo_latchReq : std_logic;
   signal   trig_out : std_logic_vector(7 downto 0);
   signal   readChannel : natural range 0 to 15;
   signal   dataHandler_timeoutError: std_logic;
   signal   sync:       std_logic;
	signal	acdcBoardDetect: std_logic_vector(7 downto 0);
	signal	boardDetect_resetReq: std_logic;
	signal	ledFunction	: ledFunction_array;
	signal	ledTestFunction: ledTestFunction_array;
	signal	ledTest_onTime	: ledTest_onTime_array;
	signal	ledMux: std_logic_vector(63 downto 0);
	signal	resetRequest_clockChange: std_logic;
	signal	useExtRef: std_logic;
	signal	pps: std_logic;
	signal	hw_trig: std_logic;
	signal	pllLockDetect_z: std_logic;
	signal	pllLockFailCounter: natural;
	signal	test: std_logic_vector(1 downto 0);
	signal	beamgate_trig: std_logic;
	
	
	
	
	
	
	
begin


SMA(3) <= trig_out(1);





------------------------------------
--	LED INDICATOR SETTINGS
------------------------------------

-- led index (front panel):	
--
--	2 red
-- 1 yellow
-- 0 green


-- modes:
-- 
-- ledMode.flashing
-- ledMode.monostable
-- ledMode.direct
--
--
-- led setup: (input, mode, onTime[ms], period[ms])
--

-- standard function
ledSetup(2,0) <= (input => usbTx.valid or usbRx.valid, mode => ledMode.monostable, onTime => 250, period => 0);
ledSetup(1,0) <= (input => useExtRef, mode => ledMode.monostable, onTime => 250, period => 0);
ledSetup(0,0) <= (input => acdcBoardDetect(0), mode => ledMode.monostable, onTime => 250, period => 0);

-- test function
LED_ON_OFF: for i in 0 to 2 generate
	ledSetup(i,1) <= (input => '1', mode => ledMode.direct, onTime => 0,	period => 0);
	ledSetup(i,2) <= (input => '0', mode => ledMode.direct, onTime => 0,	period => 0);
	ledSetup(i,3) <= (input => ledMux(ledTestFunction(i)), mode => ledMode.direct, onTime => 0,	period => 0)
		when (ledTest_onTime(i) <= 1) else (input => ledMux(ledTestFunction(i)), mode => ledMode.monostable, onTime => ledTest_onTime(i),	period => 0);
end generate;


-- led test signal multiplexer
------------------------------
ledMux(0) <= acdcBoardDetect(0);
ledMux(1) <= acdcBoardDetect(1);
ledMux(2) <= acdcBoardDetect(2);
ledMux(3) <= acdcBoardDetect(3);
ledMux(4) <= acdcBoardDetect(4);
ledMux(5) <= acdcBoardDetect(5);
ledMux(6) <= acdcBoardDetect(6);
ledMux(7) <= acdcBoardDetect(7);
ledMux(8) <= not uartRx.buffer_empty(0);
ledMux(9) <= not uartRx.buffer_empty(1);
ledMux(10) <= not uartRx.buffer_empty(2);
ledMux(11) <= not uartRx.buffer_empty(3);
ledMux(12) <= not uartRx.buffer_empty(4);
ledMux(13) <= not uartRx.buffer_empty(5);
ledMux(14) <= not uartRx.buffer_empty(6);
ledMux(15) <= not uartRx.buffer_empty(7);
ledMux(16) <= SMA(1);
ledMux(17) <= SMA(2);
ledMux(18) <= SMA(3);
ledMux(19) <= SMA(4);
ledMux(20) <= SMA(5);
ledMux(21) <= SMA(6);
ledMux(22) <= uartRx.valid(0);
ledMux(23) <= uartRx.valid(1);
ledMux(24) <= uartTx.enable(0);
ledMux(25) <= uartTx.enable(1);
ledMux(26) <= uartRx.bufferReset(0);
ledMux(27) <= uartRx.bufferReset(1);
ledMux(28) <= uartTx.valid;
ledMux(29) <= uartRx.error(0);
ledMux(30) <= uartRx.error(1);
ledMux(31) <= boardDetect_resetReq;
ledMux(32) <= localInfo_readReq;
ledMux(33) <= trig_out(0);
ledMux(34) <= trig.sw;
ledMux(35) <= rxBuffer_readReq;
ledMux(36) <= '0';
ledMux(37) <= LVDS_in(0)(0);
ledMux(38) <= LVDS_in(0)(1);
ledMux(39) <= LVDS_in(0)(2);
ledMux(40) <= LVDS_in(0)(3);
ledMux(41) <= usbRx.valid;
ledMux(42) <= usbTx.valid;
ledMux(43) <= useExtRef;
ledMux(44) <= resetRequest_clockChange;
ledMux(45) <= pps;







LED_driver_gen: for i in 0 to 2 generate
	LED_driver_map: LED_driver port map (
		clock	 	=> clock.timer,        
		setup		=> ledSetup(i, ledFunction(i)),
		output   => ledDrv(i));
	-- leds are inverse logic so invert the outputs
	led(i) <= not ledDrv(i);
end generate;






------------------------------------
--	TRIGGER
------------------------------------

TRIG_MAP: trigger Port map(
		clock		=> clock.sys,
		reset		=> reset.global,
		trig	 	=> trig,
		pps		=> pps,
		hw_trig	=> SMA(6) xor trig.SMA_invert,
		beamGate_trig => beamgate_trig,
		trig_out	=> trig_out
		);

beamgate_trig <= systemIn.in1;		
systemOut.out0 <= beamgate_trig;
		
		
		
		
		
------------------------------------
--	RESET
------------------------------------

RESET_PROCESS : process(clock.sys)
-- perform a hardware reset by setting the ResetOut signal high for the time specified by ResetLength and then low again
-- any ResetRequest inputs will restart the process
variable t: natural := 0;		-- elaspsed time counter
variable r: std_logic;
begin
	if (rising_edge(clock.sys)) then 				
		if (reset.request = '1' or resetRequest_clockChange = '1') then t := 0; end if;   -- restart counter if new reset request					 										
		if (t >= 40000000) then r := '0'; else r := '1'; t := t + 1; end if;
		reset.global <= r;
	end if;
end process;


      


      
------------------------------------
--	CLOCKS
------------------------------------

clockCtrl.clockSourceSelect <= not useExtRef;		-- clock source multiplexer control





clockGen_map: ClockGenerator Port map(
		clockIn			=> clockIn,		-- clock sources into the fpga
		clock				=> clock			-- the generated clocks for use by the rest of the firmware
	);		

clockSelect_map: ClockSelect Port map(
		clock				=> clock,
		pps				=> pps,
		resetRequest	=> resetRequest_clockChange,
		useExtRef => useExtRef
		);


PLL_EDGE_DETECT: fallingEdgeDetect port map(clock.sys, clock.altpllLock, pllLockDetect_z);

PLL_LOCK_FAIL_COUNTER: process(clock.sys)
begin
	if (rising_edge(clock.sys)) then
		if (reset.global = '1') then
			pllLockFailCounter <= 0;
		elsif (pllLockDetect_z = '1' and pllLockFailCounter < 1000) then
			pllLockFailCounter <= pllLockFailCounter + 1;
		end if;
	end if;
end process;


	
	
	
      

------------------------------------
--	LVDS 
------------------------------------
-- There are 4 signals which are connected via an ethernet cable between ACC and ACDC using LVDS signalling:
--
-- Clock
-- Uart Tx
-- Uart Rx
-- trigger / gate
--

LVDS_GEN: process(trig_out, uartTx.serial, LVDS_In)
begin
	for i in N-1 downto 0 loop
-- out
		LVDS_Out(i)(0) <=	uartTx.serial(i);
		LVDS_Out(i)(1) <=	trig_out(i);
-- in
		uartRx.serial(i) <= LVDS_In(i)(0);
	end loop;
end process;


-- system lvds i/o
pps <= systemIn.in0;









------------------------------------
--	COMMAND HANDLER
------------------------------------
-- takes the command word and generates the appropriate control & setup signals
CMD_HANDLER_MAP: commandHandler port map (
		reset						=> reset.global,
		clock				      => clock.sys,      
      din		      	   => usbRx.data,
      din_valid				=> usbRx.valid,
		boardDetect_resetReq	=> boardDetect_resetReq,
      localInfo_readReq    => localInfo_readReq,
		rxBuffer_resetReq    => rxBuffer_resetReq,
		rxBuffer_readReq    	=> rxBuffer_readReq,
		globalResetReq       => reset.request,
      trig		            => trig,
      readChannel          => readChannel,
		ledFunction				=> ledFunction,		-- determines one of 4 led modes: 0 normal; 1 on; 2 off; 3 test
		ledTestFunction		=> ledTestFunction,	-- specifies the test signal number for when the led is in test mode
		ledTest_onTime			=> ledTest_onTime,
		extCmd.enable     	=> uartTx.enable,    -- an 8 bit field that selects the board(s) to which the command will be sent
		extCmd.data       	=> uartTx.word,
		extCmd.valid         => uartTx.valid);

  

------------------------------------
--	DATA HANDLER
------------------------------------
-- manages the various sources of data & information 
-- and the transmission of this data over usb, 
-- according to request signals received
DATA_HANDLER_MAP: dataHandler port map (
		reset			=> reset.global,
		clock			=> clock.sys,
		pllLock		=> clock.altPllLock,
		trig			=> trig,
		readChannel    => readChannel,		
      ramReadEnable  => uartRx.ramReadEn,
      ramAddress     => uartRx.ramAddress,
      ramData        => uartRx.ramDataOut,
      rxDataLen		=> uartRx.dataLen,
		frame_received	=> uartRx.frame_received,
      bufferReadoutDone => uartRx.ramReadDone,  -- byte wide, one bit for each channel
		dout 		         => usbTx.data,
		dout_valid			=> usbTx.valid,
      txAck             => usbTx.dataAck,
      txReady           => usbTx.ready,
      txLockReq         => usbTx.lockReq,
      txLockAck         => usbTx.lockAck,
      rxBuffer_readReq	=> rxBuffer_readReq,
		localInfo_readRequest=> localInfo_readReq,    
      acdcBoardDetect     	=> acdcBoardDetect,
		pllLockFailCounter	=> pllLockFailCounter,
		useExtRef		=> useExtRef,
      timeoutError  			=> dataHandler_timeoutError);
 

 
	 
	 
	 
	 
------------------------------------
--	ACDC BOARD DETECT
------------------------------------
 -- ACC requests a short frame from all acdc channels
 -- whichever ones respond are flagged as present
 ACDC_Detect_process: process(clock.sys)
 begin
	if (rising_edge(clock.sys)) then
		for i in 0 to N-1 loop
			if (reset.global = '1' or boardDetect_resetReq = '1') then
				acdcBoardDetect(i) <= '0';
			elsif (uartRx.word(i) = ENDWORD and uartRx.valid(i) = '1') then
				acdcBoardDetect(i) <= '1';
			end if;
		end loop;
	end if;
end process;	
 
 
 
 
 
 
 

------------------------------------
--	UART COMMS
------------------------------------
-- serial comms with the acdc
uart_comms_8bit_gen	:	 for i in N-1 downto 0 generate
	uart_comms_8bit_map : uart_comms_8bit
	port map(
		reset					=> reset.global,	--global reset
		clock					=> clock,  
		txIn					=> uartTx.word,
		txIn_valid			=> uartTx.valid and uartTx.enable(i),	
		txOut					=> uartTx.serial(i),
		rxIn					=> uartRx.serial(i), 
		rxOut					=> uartRx.word(i),
		rxOut_valid			=> uartRx.valid(i),
		rxWordAlignReset 	=> uartRx.bufferReset(i),		-- reset rx so the next byte received is lower 8 bits of 16 bit word
		rxError				=> uartRx.error(i));
	end generate;
	
		
     

		
		

------------------------------------
--	UART RX BUFFER
------------------------------------
-- stores a burst of received data in ram
uart_rxBuffer_gen	:	 for i in N-1 downto 0 generate
	uart_rxBuffer_map : uart_rxBuffer
	port map (
		reset				=> uartRx.bufferReset(i),-- need to get this signal from data handler
		clock				=> clock.sys,	--system clock		 
		din				=> uartRx.word(i), --data in, 16 bits
		din_valid		=> uartRx.valid(i),	 
		read_enable		=> uartRx.ramReadEn(i), 	--enable reading from RAM block
		read_address	=> uartRx.ramAddress,--ram address
		buffer_empty 	=> uartRx.buffer_empty(i),
		frame_received	=> uartRx.frame_received(i),
		dataLen		   => uartRx.dataLen(i), -- length of data stored in ram
		dout				=> uartRx.ramDataOut(i)--data out
		);	
end generate;


uart_rxBuffer_reset_gen: 
process(reset.global, rxBuffer_resetReq, uartRx.ramReadDone)
begin
	for i in N-1 downto 0 loop
		uartRx.bufferReset(i) <= reset.global or rxBuffer_resetReq(i) or uartRx.ramReadDone(i);
	end loop;
end process;
	
	
 
------------------------------------
--	USB TX 
------------------------------------
-- writes 16-bit words to the usb chip
-- transfers I/O signals to the sys clock for easier interfacing
--
-- note there is no 'done' signal as previously used (although there is a dataAck) because 
-- this module no longer handles the processing of a whole frame of data, 
-- it only takes in one word at a time
usbTx_gen: usbTx_driver
	port map (
			clock   		=> clock,
			reset    	=> reset.global,	   --reset signal to usb block
			txLockReq  	=> usbTx.lockReq,  
			txLockAck  	=> usbTx.lockAck,
			txLockAvailable => (not usbRx.busy) and (not usbRx.dataAvailable),--  tx can be locked when high; check flag as well as busy to ensure it doesn't get stuck in a loop where tx and rx both wait for each other  
			din	   	=> usbTx.data,  --data bus from firmware
			din_valid 	=> usbTx.valid,
			txReady   	=> usbTx.ready,
			txAck      	=> usbTx.dataAck,
         bufferReady => usb_in.CTL(2), -- usb flag c meaning the usb chip is ready to accept tx data  (note this flag is on usb clock)  	
         PKTEND      => usb_bus.PA(6),		--usb packet end flag
			SLWR     	=> usb_out.RDY(1),     --slave bus write signal to usb chip
         txBusy  		=> usbTx.busy,     --usb write-busy indicator (not a PHY pin)
			dout			=> usbTx.dataOut,
         timeoutError => usbTx.timeoutError);
        
        
usb_bus.PA(7) <= '0';		-- SLCS signal, the slave chip select (Permanently enabled)
		  
		  
		  
		  

------------------------------------
--	USB RX 
------------------------------------
-- reads 32-bit words from the usb port
-- processing is done with usb clock but output data is on system clock
usbRx_gen: usbRx_driver
	port map (
			clock			  => clock, 
			reset		     => reset.global, 	   --reset signal to usb block
			din  		     => usbRx.dataIn,  --usb data bus to PHY
         busReadEnable => usb_busReadEnable,
         enable        => not usbTx.busy, -- can't tx and rx at the same time as there is only one bus
         dataAvailable => usbRx.dataAvailable, -- FLAG A      (note this flag is on usb clock)
         SLOE          => usb_bus.PA(2),      -- slave bus output enable,   
         SLRD          => usb_out.RDY(0),		--usb slave bus read enable
         FIFOADR       => usb_bus.PA(5 downto 4),			
         busy 		     => usbRx.busy,	--usb read-busy indicator (not a PHY pin)
         dout          => usbRx.data,     -- 32bit data to the command handler
			dout_valid    => usbRx.valid,		--flag hi = packet read from PC is ready				
         timeoutError  => usbRx.timeoutError);

usbRx.dataAvailable <= usb_in.CTL(0);
       
         
------------------------------------
--	USB BUS DRIVER
------------------------------------
-- tristate control of the usb bus for reading and writing
usb_io_buffer	: iobuf
	port map(
		datain	=>	usbTx.dataOut,	-- tx data to the usb chip bus
		oe			=> usb_busWriteEnable,	-- low = read from bus, high = write to bus
		dataio	=> usb_bus.FD,	         -- the 16-bit wide bidirectional data bus of the Cypress chip
		dataout	=> usbRx.dataIn); -- data from the usb chip
      
usb_bus_oe: process(usb_busReadEnable)
begin
	for i in 15 downto 0 loop
		usb_busWriteEnable(i) <= not usb_busReadEnable;
	end loop;
end process;

         
      


		


			
         
 
 
end vhdl;