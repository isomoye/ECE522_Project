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
	signal Ctrl_BRAM_select : Select_Enum;

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

	signal CalAllDistance_start     : std_logic;
	signal CalAllDistance_ready     : std_logic;
	signal CalAllDistance_BRAM_addr : std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
	signal CalAllDistance_BRAM_din  : std_logic_vector(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);
	signal CalAllDistance_BRAM_we   : std_logic_vector(0 to 0);
	signal CalAll_Dist_start        : std_logic;
	signal CalAllDistance_P1_addr   : std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
	signal CalAllDistance_P2_addr   : std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);

	--signals for Distance calculator module
	signal Calc_Distance_start         : std_logic;
	signal Calc_Distance_ready         : std_logic;
	signal Calc_Distance_BRAM_addr     : std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
	signal Calc_Distance_P1_addr       : std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
	signal Calc_Distance_P2_addr       : std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
	signal Calc_Distance_CalcDist_dout : std_logic_vector(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);
	signal Calc_Distance_BRAM_din      : std_logic_vector(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);
	signal Calc_Distance_BRAM_we       : std_logic_vector(0 to 0);

	--signals for Check_assigns module
	signal Check_assigns_start     : std_logic;
	signal Check_assigns_ready     : std_logic;
	signal Check_assigns_BRAM_addr : std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
	signal Check_assigns_BRAM_din  : std_logic_vector(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);
	signal Check_assigns_BRAM_we   : std_logic_vector(0 to 0);
	signal Check_SRC_addr          : std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
	signal Check_TGT_addr          : std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
	signal Change_Count_dout       : std_logic_vector(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);

	--signals for cluster center calculator module
	signal CalcCluster_start     : std_logic;
	signal CalcCluster_ready     : std_logic;
	signal CalcCluster_BRAM_addr : std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
	signal CalcCluster_BRAM_din  : std_logic_vector(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);
	signal CalcCluster_BRAM_we   : std_logic_vector(0 to 0);

	-- signals for total distance calculator module
	signal CalcTotal_start         : std_logic;
	signal CalcTotal_ready         : std_logic;
	signal CalcTotal_BRAM_addr     : std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
	signal CalcTotal_BRAM_din      : std_logic_vector(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);
	signal CalcTotal_BRAM_we       : std_logic_vector(0 to 0);
	signal CalcTotal_P1_addr       : std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
	signal CalcTotal_P2_addr       : std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
	signal CalcTotal_Dist_start    : std_logic;
	signal CalcTotal_CalcDist_dout : std_logic_vector(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);

	-- signals for find_centroids module
	signal Find_Centroid_start     : std_logic;
	signal Find_Centroid_ready     : std_logic;
	signal Find_Centroid_BRAM_addr : std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
	signal Find_Centroid_BRAM_din  : std_logic_vector(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);
	signal Find_Centroid_BRAM_we   : std_logic_vector(0 to 0);

	--signals for copy module
	signal Copy_start     : std_logic;
	signal Copy_ready     : std_logic;
	signal Copy_BRAM_addr : std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
	signal Copy_BRAM_din  : std_logic_vector(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);
	signal Copy_BRAM_we   : std_logic_vector(0 to 0);
	signal Copy_SRC_addr  : std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
	signal Copy_TGT_addr  : std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);

	signal calcDist_select : myEnum;

	--signals for getting number of values, clusters, dimensions
	signal Num_Vals     : std_logic_vector(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);
	signal Num_Clusters : std_logic_vector(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);
	signal Num_Dims     : std_logic_vector(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);

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

	-- calc all distances module
	CalcAllDistanceMod : entity work.CalcAllDistance(beh)
		port map(
			Clk            => Clk,
			RESET          => RESET,
			start          => CalAllDistance_start,
			ready          => CalAllDistance_ready,
			PNL_BRAM_addr  => CalAllDistance_BRAM_addr,
			PNL_BRAM_din   => CalAllDistance_BRAM_din,
			PNL_BRAM_we    => CalAllDistance_BRAM_we,
			calcDist_start => CalAll_Dist_start,
			calcDist_ready => Calc_Distance_ready,
			P1_addr        => CalAllDistance_P1_addr,
			P2_addr        => CalAllDistance_P2_addr,
			CalcDist_dout  => Calc_Distance_CalcDist_dout,
			Num_Vals       => Num_Vals,
			Num_Clusters   => Num_Clusters,
			Num_dims       => Num_dims
		);
	--calc cluster centroids module
	CalcCentroidsMod : entity work.CalcClusterCentroids(beh)
		port map(
			Clk           => Clk,
			RESET         => RESET,
			start         => CalcCluster_start,
			ready         => CalcCluster_ready,
			PNL_BRAM_addr => CalcCluster_BRAM_addr,
			PNL_BRAM_din  => CalcCluster_BRAM_din,
			PNL_BRAM_dout => PNL_BRAM_dout,
			PNL_BRAM_we   => CalcCluster_BRAM_we,
			Num_Vals      => Num_Vals,
			Num_Clusters  => Num_Clusters,
			Num_Dims      => Num_Dims
		);

	--calc total distance module
	CalcTotalMod : entity work.CalcTotalDistance(beh)
		port map(
			Clk                    => Clk,
			RESET                  => RESET,
			start                  => CalCTotal_start,
			ready                  => CalCTotal_ready,
			PNL_BRAM_addr          => CalCTotal_BRAM_addr,
			PNL_BRAM_din           => CalCTotal_BRAM_din,
			PNL_BRAM_dout          => PNL_BRAM_dout,
			PNL_BRAM_we            => CalCTotal_BRAM_we,
			calcDist_start         => CalcTotal_Dist_start,
			calcDist_ready         => Calc_Distance_ready,
			P1_addr                => CalCTotal_P1_addr,
			P2_addr                => CalCTotal_P2_addr,
			CalcDist_dout          => Calc_Distance_CalcDist_dout,
			CalcTotalDistance_dout => CalcTotal_CalcDist_dout,
			Num_dims               => Num_dims,
			Num_Vals               => Num_Vals
		);

	--check count change module
	Check_assignsMod : entity work.CheckIfAssignmentCountChanged(beh)
		port map(
			Clk               => Clk,
			RESET             => RESET,
			start             => Check_assigns_start,
			ready             => Check_assigns_ready,
			PNL_BRAM_addr     => Check_assigns_BRAM_addr,
			PNL_BRAM_din      => Check_assigns_BRAM_din,
			PNL_BRAM_dout     => PNL_BRAM_dout,
			PNL_BRAM_we       => Check_assigns_BRAM_we,
			Num_Vals          => Num_Vals,
			SRC_BRAM_addr     => Check_SRC_addr,
			TGT_BRAM_addr     => Check_TGT_addr,
			Change_Count_dout => Change_Count_dout
		);

	-- find closest centroid module
	FindCentroidMod : entity work.FindClosestCentroid(beh)
		port map(
			Clk           => Clk,
			RESET         => RESET,
			start         => Find_Centroid_start,
			ready         => Find_Centroid_ready,
			PNL_BRAM_addr => Find_Centroid_BRAM_addr,
			PNL_BRAM_din  => Find_Centroid_BRAM_din,
			PNL_BRAM_dout => PNL_BRAM_dout,
			PNL_BRAM_we   => Find_Centroid_BRAM_we,
			Num_Vals      => Num_Vals,
			Num_Clusters  => Num_Clusters,
			Num_Dims      => Num_Dims
		);

	--calc distance module
	CalcDistMod : entity work.CalcDistance(beh)
		port map(
			Clk           => Clk,
			RESET         => RESET,
			start         => Calc_Distance_start,
			ready         => Calc_Distance_ready,
			PNL_BRAM_addr => Calc_Distance_BRAM_addr,
			P1_addr       => Calc_Distance_P1_addr,
			P2_addr       => Calc_Distance_P2_addr,
			Num_dims      => Num_dims,
			CalcDist_dout => Calc_Distance_CalcDist_dout,
			PNL_BRAM_din  => Calc_Distance_BRAM_din,
			PNL_BRAM_dout => PNL_BRAM_dout,
			PNL_BRAM_we   => Calc_Distance_BRAM_we
		);

	--copy values module
	CopyAssignMod : entity work.CopyAssignmentArray(beh)
		port map(
			Num_Vals      => Num_Vals,
			Clk           => Clk,
			RESET         => RESET,
			start         => Copy_start,
			ready         => Copy_ready,
			PNL_BRAM_addr => Copy_BRAM_addr,
			PNL_BRAM_din  => Copy_BRAM_din,
			PNL_BRAM_dout => PNL_BRAM_dout,
			PNL_BRAM_we   => Copy_BRAM_we,
			SRC_BRAM_addr => Copy_SRC_addr,
			TGT_BRAM_addr => Copy_TGT_addr
		);

	-- Secure BRAM access control module
	LoadUnLoadMemMod : entity work.LoadUnLoadMem(beh)
		port map(Clk           => Clk, RESET => RESET, start => LM_ULM_start, ready => LM_ULM_ready, load_unload => LM_ULM_load_unload, stopped => LM_ULM_stopped,
		         continue      => LM_ULM_continue, done => LM_ULM_done, base_address => LM_ULM_base_address, upper_limit => LM_ULM_upper_limit,
		         CP_in_word    => DataIn, CP_out_word => DataOut,
		         PNL_BRAM_addr => LM_ULM_PNL_BRAM_addr, PNL_BRAM_din => LM_ULM_PNL_BRAM_din, PNL_BRAM_dout => PNL_BRAM_dout, PNL_BRAM_we => LM_ULM_PNL_BRAM_we);

	-- =====================
	KmeansMod : entity work.Kmeans
		port map(
			Check_assigns_ready     => Check_assigns_ready,
			Clk                     => Clk,
			RESET                   => RESET,
			start                   => Kmeans_start,
			ready                   => Kmeans_ready,
			Kmeans_ERR              => Kmeans_ERR,
			PNL_BRAM_addr           => Kmeans_PNL_BRAM_addr,
			PNL_BRAM_din            => Kmeans_PNL_BRAM_din,
			PNL_BRAM_dout           => PNL_BRAM_dout,
			PNL_BRAM_we             => Kmeans_PNL_BRAM_we,
			BRAM_select             => Ctrl_BRAM_select,
			Num_Vals                => Num_Vals,
			Num_Clusters            => Num_Clusters,
			Num_Dims                => Num_Dims,
			Copy_start              => Copy_start,
			Copy_ready              => Copy_ready,
			Copy_SRC_addr           => Copy_SRC_addr,
			Copy_TGT_addr           => Copy_TGT_addr,
			CalAllDistance_start    => CalAllDistance_start,
			CalAllDistance_ready    => CalAllDistance_ready,
			CalcCluster_start       => CalcCluster_start,
			CalcCluster_ready       => CalcCluster_ready,
			CalCTotal_start         => CalcTotal_start,
			CalCTotal_ready         => CalcTotal_ready,
			CalcTotal_CalcDist_dout => CalcTotal_CalcDist_dout,
			Check_assigns_start     => Check_assigns_start,
			Check_SRC_addr          => Check_SRC_addr,
			Check_TGT_addr          => Check_TGT_addr,
			Find_Centroid_start     => Find_Centroid_start,
			Find_Centroid_ready     => Find_Centroid_ready,
			Calc_Distance_ready     => Calc_Distance_ready,
			Change_Count_dout       => Change_Count_dout,
			calcDist_select         => calcDist_select
		);
	-- =====================
	-- Master controller.
	ControllerMod : entity work.Controller(beh)
		port map(Clk                 => Clk, RESET => RESET, start => Ctrl_start, ready => Ctrl_ready, LM_ULM_start => LM_ULM_start, LM_ULM_ready => LM_ULM_ready,
		         LM_ULM_base_address => LM_ULM_base_address, LM_ULM_upper_limit => LM_ULM_upper_limit, LM_ULM_load_unload => LM_ULM_load_unload,
		         Kmeans_start        => Kmeans_start, Kmeans_ready => Kmeans_ready);

	-- =====================
	-- MEMORY CONTROL
	-- PNL_BRAM module select logic for addr, din and we.
	with Ctrl_BRAM_select select PNL_BRAM_addr_out <=
		Copy_BRAM_addr when copy,
		Kmeans_PNL_BRAM_addr when kmeans_drive,
		CalAllDistance_BRAM_addr when calcAll,
		Calc_Distance_BRAM_addr 	when calcDist,
		Find_Centroid_BRAM_addr 	when findCentroid,
		CalcCluster_BRAM_addr 		when calcCluster,
		CalcTotal_BRAM_addr 		when calcTotal,
		Check_assigns_BRAM_addr 	when checkAssigns,		
		LM_ULM_PNL_BRAM_addr when others;

	with Ctrl_BRAM_select select PNL_BRAM_din_out <=
		Copy_BRAM_din when copy,
		Kmeans_PNL_BRAM_din when kmeans_drive,
		CalAllDistance_BRAM_din when calcAll,      
		Calc_Distance_BRAM_din 		when calcDist,     
		Find_Centroid_BRAM_din 		when findCentroid, 
		CalcCluster_BRAM_din 		when calcCluster,  
		CalcTotal_BRAM_din 			when calcTotal,    
		Check_assigns_BRAM_din  	when checkAssigns,
		LM_ULM_PNL_BRAM_din when others;

	with Ctrl_BRAM_select select PNL_BRAM_we <=
		Copy_BRAM_we when copy,
		Kmeans_PNL_BRAM_we when kmeans_drive,
		CalAllDistance_BRAM_we when calcAll,      
		Calc_Distance_BRAM_we	when calcDist,     
		Find_Centroid_BRAM_we 	when findCentroid, 	
		CalcCluster_BRAM_we 	when calcCluster,  
		CalcTotal_BRAM_we 		when calcTotal,    
		Check_assigns_BRAM_we  	when checkAssigns,
		LM_ULM_PNL_BRAM_we when others;

	with calcDist_select select Calc_Distance_start <=
		CalAll_Dist_start when a,
		CalcTotal_Dist_start when others;

	with calcDist_select select Calc_Distance_P1_addr <=
		CalAllDistance_P1_addr when a,
		CalCTotal_P1_addr when others;

	with calcDist_select select Calc_Distance_P2_addr <=
		CalAllDistance_P2_addr when a,
		CalCTotal_P2_addr when others;

	PNL_BRAM_addr <= PNL_BRAM_addr_out;
	PNL_BRAM_din  <= PNL_BRAM_din_out;

end beh;
