----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Professor Jim Plusquellic
-- 
-- Create Date:
-- Design Name: 
-- Module Name:    Top - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------

-- ===================================================================================================
-- ===================================================================================================
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.all;

library work;
use work.DataTypes_pkg.all;

entity Top is
	port(
		Clk           : in  std_logic;
		PS_RESET_N    : in  std_logic;
		GPIO_Ins      : in  std_logic_vector(31 downto 0);
		GPIO_Outs     : out std_logic_vector(31 downto 0);
		PNL_BRAM_addr : out std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
		PNL_BRAM_din  : out std_logic_vector(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);
		PNL_BRAM_dout : in  std_logic_vector(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);
		PNL_BRAM_we   : out std_logic_vector(0 to 0);
		DEBUG_IN      : in  std_logic;
		DEBUG_OUT     : out std_logic
	);
end Top;

architecture beh of Top is

	-- GPIO INPUT BIT ASSIGNMENTS
	constant IN_CP_RESET       : integer := 31;
	constant IN_CP_START       : integer := 30;
	constant IN_CP_LM_ULM_DONE : integer := 25;
	constant IN_CP_HANDSHAKE   : integer := 24;

	-- GPIO OUTPUT BIT ASSIGNMENTS
	constant OUT_SM_READY     : integer := 31;
	constant Kmeans_ERR_BIT   : integer := 30;
	constant OUT_SM_HANDSHAKE : integer := 28;

	-- Signal declarations
	signal RESET : std_logic;

	signal LM_ULM_start, LM_ULM_ready      : std_logic;
	signal LM_ULM_stopped, LM_ULM_continue : std_logic;
	signal LM_ULM_done                     : std_logic;
	signal LM_ULM_base_address             : std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
	signal LM_ULM_upper_limit              : std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
	signal LM_ULM_load_unload              : std_logic;

	signal Kmeans_start : std_logic;
	signal Kmeans_ready : std_logic;
	signal Kmeans_ERR   : std_logic;
	--   signal Kmeans_dist_mean: std_logic_vector(PNL_BRAM_DBITS_WIDTH_NB-1 downto 0);
	--   signal Kmeans_dist_range: std_logic_vector(Kmeans_MAX_RANGE_NB-1 downto 0);

	signal Ctrl_start       : std_logic;
	signal Ctrl_ready       : std_logic;
	signal Ctrl_BRAM_select : std_logic;

	signal DataIn  : std_logic_vector(WORD_SIZE_NB - 1 downto 0);
	signal DataOut : std_logic_vector(WORD_SIZE_NB - 1 downto 0);

	-- Just in case we need to read these 'out' signals at some point
	signal PNL_BRAM_addr_out : std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
	signal PNL_BRAM_din_out  : std_logic_vector(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);

	-- BRAM signals from modules that will be multiplexed on the input ports of the memory (but are 'out' parameters in Top.vhd).
	signal LM_ULM_PNL_BRAM_addr : std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
	signal LM_ULM_PNL_BRAM_din  : std_logic_vector(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);
	signal LM_ULM_PNL_BRAM_we   : std_logic_vector(0 to 0);

	signal Kmeans_PNL_BRAM_addr : std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
	signal Kmeans_PNL_BRAM_din  : std_logic_vector(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);
	signal Kmeans_PNL_BRAM_we   : std_logic_vector(0 to 0);

	-- =======================================================================================================
begin

	-- Light up LED if LoadUnLoadMemMod is ready for a command
	DEBUG_OUT <= LM_ULM_ready;

	-- =====================
	-- INPUT control and status signals
	-- Software (C code) plus hardware global reset
	RESET <= GPIO_Ins(IN_CP_RESET) or not PS_RESET_N;

	-- Start signal from C program. 
	Ctrl_start <= GPIO_Ins(IN_CP_START);

	-- C program asserts if done reading or writing memory (or a portion of it)
	LM_ULM_done <= GPIO_Ins(IN_CP_LM_ULM_DONE);

	-- Handshake signal
	LM_ULM_continue <= GPIO_Ins(IN_CP_HANDSHAKE);

	-- Data from C program
	DataIn <= GPIO_Ins(WORD_SIZE_NB - 1 downto 0);

	-- =====================
	-- OUTPUT control and status signals
	-- Tell C program whether LoadUnLoadMemMod is ready 
	GPIO_Outs(OUT_SM_READY) <= Ctrl_ready;

	GPIO_Outs(Kmeans_ERR_BIT) <= Kmeans_ERR;

	-- Handshake signals
	GPIO_Outs(OUT_SM_HANDSHAKE) <= LM_ULM_stopped;

	-- Data to C program
	GPIO_Outs(WORD_SIZE_NB - 1 downto 0) <= DataOut;

	-- =====================

	-- Secure BRAM access control module
	LoadUnLoadMemMod : entity work.LoadUnLoadMem(beh)
		port map(Clk           => Clk, RESET => RESET, start => LM_ULM_start, ready => LM_ULM_ready, load_unload => LM_ULM_load_unload, stopped => LM_ULM_stopped,
		         continue      => LM_ULM_continue, done => LM_ULM_done, base_address => LM_ULM_base_address, upper_limit => LM_ULM_upper_limit,
		         CP_in_word    => DataIn, CP_out_word => DataOut,
		         PNL_BRAM_addr => LM_ULM_PNL_BRAM_addr, PNL_BRAM_din => LM_ULM_PNL_BRAM_din, PNL_BRAM_dout => PNL_BRAM_dout, PNL_BRAM_we => LM_ULM_PNL_BRAM_we);

	-- =====================
	KmeansMod : entity work.Kmeans(beh)
		port map(Clk           => Clk, RESET => RESET, start => Kmeans_start, ready => Kmeans_ready, Kmeans_ERR => Kmeans_ERR, PNL_BRAM_addr => Kmeans_PNL_BRAM_addr,
		         PNL_BRAM_din  => Kmeans_PNL_BRAM_din, PNL_BRAM_dout => PNL_BRAM_dout, PNL_BRAM_we => Kmeans_PNL_BRAM_we);

	-- =====================
	-- Master controller.
	ControllerMod : entity work.Controller(beh)
		port map(Clk                 => Clk, RESET => RESET, start => Ctrl_start, ready => Ctrl_ready, LM_ULM_start => LM_ULM_start, LM_ULM_ready => LM_ULM_ready,
		         LM_ULM_base_address => LM_ULM_base_address, LM_ULM_upper_limit => LM_ULM_upper_limit, LM_ULM_load_unload => LM_ULM_load_unload,
		         Kmeans_start        => Kmeans_start, Kmeans_ready => Kmeans_ready, BRAM_select => Ctrl_BRAM_select);

	-- =====================
	-- MEMORY CONTROL
	-- PNL_BRAM module select logic for addr, din and we.
	with Ctrl_BRAM_select select PNL_BRAM_addr_out <=
		LM_ULM_PNL_BRAM_addr when '0',
		Kmeans_PNL_BRAM_addr when others;

	with Ctrl_BRAM_select select PNL_BRAM_din_out <=
		LM_ULM_PNL_BRAM_din when '0',
		Kmeans_PNL_BRAM_din when others;

	with Ctrl_BRAM_select select PNL_BRAM_we <=
		LM_ULM_PNL_BRAM_we when '0',
		Kmeans_PNL_BRAM_we when others;

	PNL_BRAM_addr <= PNL_BRAM_addr_out;
	PNL_BRAM_din  <= PNL_BRAM_din_out;

end beh;

