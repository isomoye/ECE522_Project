----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Professor Jim Plusquellic
-- 
-- Create Date:
-- Design Name: 
-- Module Name:    Kmeans - Behavioral 
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

-- Kmeans bins 

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.all;

library work;
use work.DataTypes_pkg.all;

entity Kmeans is
	port(
		Clk           : in  std_logic;
		RESET         : in  std_logic;
		start         : in  std_logic;
		ready         : out std_logic;
		Kmeans_ERR    : out std_logic;
		PNL_BRAM_addr : out std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
		PNL_BRAM_din  : out std_logic_vector(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);
		PNL_BRAM_dout : in  std_logic_vector(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);
		PNL_BRAM_we   : out std_logic_vector(0 to 0)
	);
end Kmeans;

architecture beh of Kmeans is
	type state_type is (idle, get_prog_addr, get_prog_vals, wait_find_centroid, wait_copy, start_iteration, wait_calc_cluster, wait_total, fail_improve, wait_calcAll, wait_change_count);
	signal state_reg, state_next : state_type;

	signal ready_reg, ready_next : std_logic;

	type Select_Enum is (kmeans, calcAll, calcDist, findCentroid, copy, calcCluster, calcTotal, checkAssigns);

	signal KMEANS_BRAM_select_reg, KMEANS_BRAM_select_next : Select_Enum;

	signal Kmeans_ERR_reg, Kmeans_ERR_next : std_logic;

	--calcDist_start
	--calcDist_ready
	--signals for CalAllDistances module
	signal CalAllDistance_start     : std_logic;
	signal CalAllDistance_ready     : std_logic;
	signal CalAllDistance_BRAM_addr : std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
	signal CalAllDistance_BRAM_din  : std_logic_vector(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);
	signal CalAllDistance_BRAM_we   : std_logic_vector(0 to 0);
	signal CalAll_Dist_start        : std_logic;
	signal CalAllDistance_P1_addr   : std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
	signal CalAllDistance_P2_addr   : std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);

	signal Check_assigns_start            : std_logic;
	signal Check_assigns_ready            : std_logic;
	signal Check_assigns_BRAM_addr        : std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
	signal Check_assigns_BRAM_din         : std_logic_vector(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);
	signal Check_assigns_BRAM_we          : std_logic_vector(0 to 0);
	signal Check_SRC_addr, Check_SRC_next : std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
	signal Check_TGT_addr, Check_TGT_next : std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
	signal Change_Count_dout              : std_logic_vector(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);

	signal Copy_start                   : std_logic;
	signal Copy_ready                   : std_logic;
	signal Copy_BRAM_addr               : std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
	signal Copy_BRAM_din                : std_logic_vector(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);
	signal Copy_BRAM_we                 : std_logic_vector(0 to 0);
	signal Copy_SRC_addr, Copy_SRC_next : std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
	signal Copy_TGT_addr, Copy_TGT_next : std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);

	signal CalcCluster_start     : std_logic;
	signal CalcCluster_ready     : std_logic;
	signal CalcCluster_BRAM_addr : std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
	signal CalcCluster_BRAM_din  : std_logic_vector(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);
	signal CalcCluster_BRAM_we   : std_logic_vector(0 to 0);
	-- Error flag is set to '1' if distribution is too narrow to be characterized with the specified bounds, or the integer portion of
	-- a PN value is outside the range of -1023 and 1024.

	signal Calc_Distance_start         : std_logic;
	signal Calc_Distance_ready         : std_logic;
	signal Calc_Distance_BRAM_addr     : std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
	signal Calc_Distance_P1_addr       : std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
	signal Calc_Distance_P2_addr       : std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
	signal Calc_Distance_CalcDist_dout : std_logic_vector(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);
	signal Calc_Distance_BRAM_din      : std_logic_vector(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);
	signal Calc_Distance_BRAM_we       : std_logic_vector(0 to 0);

	signal CalcTotal_start         : std_logic;
	signal CalcTotal_ready         : std_logic;
	signal CalcTotal_BRAM_addr     : std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
	signal CalcTotal_BRAM_din      : std_logic_vector(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);
	signal CalcTotal_BRAM_we       : std_logic_vector(0 to 0);
	signal CalcTotal_P1_addr       : std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
	signal CalcTotal_P2_addr       : std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
	signal CalcTotal_Dist_start    : std_logic;
	signal CalcTotal_CalcDist_dout : std_logic_vector(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);

	signal Find_Centroid_start     : std_logic;
	signal Find_Centroid_ready     : std_logic;
	signal Find_Centroid_BRAM_addr : std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
	signal Find_Centroid_BRAM_din  : std_logic_vector(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);
	signal Find_Centroid_BRAM_we   : std_logic_vector(0 to 0);

	signal Kmeans_BRAM_addr : std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
	--signal Kmeans_Centroid_BRAM_din  : std_logic_vector(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);
	--signal Kmeans_Centroid_BRAM_we   : std_logic_vector(0 to 0);

	-- registers for iterations, prev_totD and cur_todD.
	signal dist_count_reg, dist_count_next : unsigned(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);

	signal Num_Vals     : std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
	signal Num_Clusters : std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
	signal Num_Dims     : std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);

	signal tot_D_reg, tot_D_next           : unsigned(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);
	signal prev_tot_D_reg, prev_tot_D_next : unsigned(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);

	type myEnum is (a, b, c, d);
	signal copy_select_reg, copy_select_next       : myEnum;
	--	signal copy_select         : std_logic_vector(1 downto 0);
	signal CalcAll_select_reg, CalcAll_select_next : myEnum;
	signal Cluster_select_reg, Cluster_select_next : myEnum;
	signal calcDist_select                         : myEnum;
	--	signal calcDistance_select : std_logic_vector(1 downto 0);

begin

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
			CalcDist_dout          => CalCTotal_CalcDist_dout,
			CalcTotalDistance_dout => CalcTotal_CalcDist_dout,
			Num_dims               => Num_dims,
			Num_Vals               => Num_Vals
		);

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

	CopyAssignMod : entity work.CopyAssignmentArray(beh)
		port map(
			Num_Vals      => Num_vals,
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
	-- =============================================================================================
	-- State and register logic
	-- =============================================================================================
	process(Clk, RESET)
	begin
		if (RESET = '1') then
			state_reg              <= idle;
			ready_reg              <= '1';
			--KMEANS_BRAM_select <= b;
			tot_D_reg              <= (others => '0');
			prev_tot_D_reg         <= (others => '0');
			dist_count_reg         <= (others => '0');
			copy_select_reg        <= a;
			CalcAll_select_reg     <= a;
			Cluster_select_reg     <= a;
			KMEANS_BRAM_select_reg <= kmeans;
			Copy_SRC_addr          <= (others => '0');
			Check_SRC_addr         <= (others => '0');

		elsif (Clk'event and Clk = '1') then
			state_reg              <= state_next;
			ready_reg              <= ready_next;
			tot_D_reg              <= tot_D_next;
			dist_count_reg         <= dist_count_next;
			copy_select_reg        <= copy_select_next;
			CalcAll_select_reg     <= CalcAll_select_next;
			Cluster_select_reg     <= Cluster_select_next;
			prev_tot_D_reg         <= prev_tot_D_next;
			KMEANS_BRAM_select_reg <= KMEANS_BRAM_select_next;
			Copy_SRC_addr          <= Copy_SRC_next;
			Check_SRC_addr         <= Check_SRC_next;

		end if;
	end process;

	-- =============================================================================================
	-- Combo logic
	-- =============================================================================================
	process(state_reg, start, ready_reg, Check_SRC_addr, Copy_SRC_addr, Change_Count_dout, KMEANS_BRAM_select_reg, copy_select_reg, CalcAll_select_reg, Cluster_select_reg, prev_tot_D_reg, Find_Centroid_ready, Calc_Distance_ready, CalcTotal_CalcDist_dout, tot_D_reg, dist_count_reg, Check_assigns_ready, CalcTotal_ready, CalcCluster_ready, CalAllDistance_ready, Copy_ready, PNL_BRAM_dout)
	begin
		state_next              <= state_reg;
		ready_next              <= ready_reg;
		dist_count_next         <= dist_count_reg;
		KMEANS_BRAM_select_next <= KMEANS_BRAM_select_reg;

		-- Default value is 0 -- used during memory initialization.
		PNL_BRAM_din <= (others => '0');
		PNL_BRAM_we  <= "0";

		CalAllDistance_start <= '0';
		CalcCluster_start    <= '0';
		Calc_Distance_start  <= '0';
		CalCTotal_start      <= '0';
		Check_assigns_start  <= '0';
		Copy_start           <= '0';
		Find_Centroid_start  <= '0';
		--KMEANS_BRAM_select          <= "00";

		tot_D_next      <= tot_D_reg;
		prev_tot_D_next <= prev_tot_D_reg;
		Copy_SRC_next   <= Copy_SRC_addr;
		Check_SRC_next  <= Check_SRC_addr;

		case state_reg is

			-- =====================
			when idle =>
				ready_next <= '1';

				if (start = '1') then
					ready_next              <= '0';
					state_next              <= get_prog_addr;
					copy_select_next        <= a;
					CalcAll_select_next     <= a;
					Cluster_select_next     <= a;
					dist_count_next         <= (others => '0');
					KMEANS_BRAM_select_next <= kmeans;
					Num_Clusters            <= (others => '0');
					Num_Vals                <= (others => '0');
					Num_Dims                <= (others => '0');
					tot_D_next              <= (others => '0');
					calcDist_select         <= a;
					prev_tot_D_next         <= (others => '0');
					Copy_SRC_next           <= (others => '0');
					Check_SRC_next          <= (others => '0');
				end if;

			when get_prog_addr =>
				if (dist_count_reg = to_unsigned(PROG_VALS, PNL_BRAM_ADDR_SIZE_NB - 1)) then
					dist_count_next         <= (others => '0');
					KMEANS_BRAM_select_next <= calcAll;
					CalAllDistance_start    <= '1';
					calcDist_select         <= a;
					state_next              <= wait_calcAll;

				else
					Kmeans_BRAM_addr <= std_logic_vector(to_unsigned(PN_BRAM_BASE, PNL_BRAM_ADDR_SIZE_NB) + dist_count_reg);
					state_next       <= get_prog_vals;
				end if;

			when get_prog_vals =>
				if (dist_count_reg = to_unsigned(NUM_VALS_ADDR, PNL_BRAM_ADDR_SIZE_NB)) then
					Num_Vals <= std_logic_vector(resize(unsigned(PNL_BRAM_dout), PNL_BRAM_ADDR_SIZE_NB));
				elsif (dist_count_reg = to_unsigned(NUM_CLUSTERS_ADDR, PNL_BRAM_ADDR_SIZE_NB)) then
					Num_Clusters <= std_logic_vector(resize(unsigned(PNL_BRAM_dout), PNL_BRAM_ADDR_SIZE_NB));
				elsif (dist_count_reg = to_unsigned(NUM_DIMS_ADDR, PNL_BRAM_ADDR_SIZE_NB)) then
					Num_Dims <= std_logic_vector(resize(unsigned(PNL_BRAM_dout), PNL_BRAM_ADDR_SIZE_NB));
				end if;

				dist_count_next <= dist_count_reg + 1;
				state_next      <= get_prog_addr;

			when wait_calcAll =>
				if (CalAllDistance_ready = '1') then
					KMEANS_BRAM_select_next <= findCentroid;
					Find_Centroid_start     <= '1';
					state_next              <= wait_find_centroid;
				else
					if (Calc_Distance_ready = '0') then
						KMEANS_BRAM_select_next <= calcDist;
					--	Top_Num_dims       <= CalAllDistance_Num_dims;
					else
						KMEANS_BRAM_select_next <= calcAll;
					end if;
				end if;

			when wait_find_centroid =>
				if (Find_Centroid_ready = '1') then
					case CalcAll_select_reg is
						when a =>
							Copy_start              <= '1';
							Copy_SRC_next           <= std_logic_vector(to_unsigned(PN_BRAM_BASE, PNL_BRAM_ADDR_SIZE_NB));
							Copy_TGT_next           <= std_logic_vector(to_unsigned(FINAL_CLUSTER_BASE_ADDR, PNL_BRAM_ADDR_SIZE_NB));
							KMEANS_BRAM_select_next <= copy;
							--Copy_Num_vals_in   <= std_logic_vector(Num_dims);
							state_next              <= wait_copy; --wait_copy;
						when others =>
							Check_assigns_start     <= '1';
							--Check_assigns_Num_Vals      <= std_logic_vector(Num_dims);
							Check_SRC_next          <= std_logic_vector(to_unsigned(CLUSTER_BASE_ADDR, PNL_BRAM_ADDR_SIZE_NB));
							Check_TGT_next          <= std_logic_vector(to_unsigned(COPY_CLUSTER_BASE_ADDR, PNL_BRAM_ADDR_SIZE_NB));
							KMEANS_BRAM_select_next <= checkAssigns;
							state_next              <= wait_change_count;
					end case;
				end if;

			when wait_copy =>
				if (Copy_ready = '1') then
					--state_next <= idle;
					case copy_select_reg is
						when a =>
							state_next <= start_iteration;
						when b =>
							KMEANS_BRAM_select_next <= calcCluster;
							CalcCluster_start       <= '1';
							Cluster_select_next     <= b;
							state_next              <= wait_calc_cluster;
						when c =>
							CalAllDistance_start    <= '1';
							CalcAll_select_next     <= b;
							state_next              <= wait_calcAll;
							calcDist_select         <= a;
							KMEANS_BRAM_select_next <= calcAll;
						when d =>
							state_next <= idle;
					end case;
				end if;

			--00 a 01b 10c 11d 
			when start_iteration =>
				if (dist_count_reg = to_unsigned(MAX_ITERATIONS, PNL_BRAM_ADDR_SIZE_NB)) then
					Copy_start              <= '1';
					Copy_SRC_next           <= std_logic_vector(to_unsigned(CLUSTER_BASE_ADDR, PNL_BRAM_ADDR_SIZE_NB));
					Copy_TGT_next           <= std_logic_vector(to_unsigned(FINAL_CLUSTER_BASE_ADDR, PNL_BRAM_ADDR_SIZE_NB));
					KMEANS_BRAM_select_next <= copy;
					copy_select_next        <= d;
					state_next              <= wait_copy;
				else
					KMEANS_BRAM_select_next <= calcCluster;
					CalcCluster_start       <= '1';
					state_next              <= wait_calc_cluster;
				end if;

			when wait_calc_cluster =>
				if (CalcCluster_ready = '1') then
					case Cluster_select_reg is
						when a =>
							KMEANS_BRAM_select_next <= calcTotal;
							CalcTotal_start         <= '1';
							calcDist_select         <= b;
							state_next              <= wait_total;
						when others =>
							Copy_start              <= '1';
							Copy_SRC_next           <= std_logic_vector(to_unsigned(PN_BRAM_BASE, PNL_BRAM_ADDR_SIZE_NB));
							Copy_TGT_next           <= std_logic_vector(to_unsigned(FINAL_CLUSTER_BASE_ADDR, PNL_BRAM_ADDR_SIZE_NB));
							KMEANS_BRAM_select_next <= copy;
							copy_select_next        <= d;
							--Copy_Num_vals_in   <= Num_dims;
							state_next              <= wait_copy;
					end case;
				end if;

			when wait_total =>
				if (CalcTotal_ready = '1') then
					tot_D_next <= unsigned(CalcTotal_CalcDist_dout);
					state_next <= fail_improve;
				else
					if (Calc_Distance_ready = '0') then
						KMEANS_BRAM_select_next <= calcDist;
					--	Top_Num_dims       <= CalAllDistance_Num_dims;
					else
						KMEANS_BRAM_select_next <= calcTotal;
					end if;
				end if;

			when fail_improve =>

				if (dist_count_reg /= (dist_count_reg'range => '0') and tot_D_reg > prev_tot_D_reg) then
					Copy_start              <= '1';
					Copy_SRC_next           <= std_logic_vector(to_unsigned(COPY_CLUSTER_BASE_ADDR, PNL_BRAM_ADDR_SIZE_NB));
					Copy_TGT_next           <= std_logic_vector(to_unsigned(CLUSTER_BASE_ADDR, PNL_BRAM_ADDR_SIZE_NB));
					KMEANS_BRAM_select_next <= copy;
					copy_select_next        <= b;
				else
					Copy_start              <= '1';
					Copy_SRC_next           <= std_logic_vector(to_unsigned(CLUSTER_BASE_ADDR, PNL_BRAM_ADDR_SIZE_NB));
					Copy_TGT_next           <= std_logic_vector(to_unsigned(COPY_CLUSTER_BASE_ADDR, PNL_BRAM_ADDR_SIZE_NB));
					KMEANS_BRAM_select_next <= copy;
					copy_select_next        <= c;
				end if;
				state_next <= wait_copy;

			when wait_change_count =>
				if (Check_assigns_ready = '1') then
					if (Change_Count_dout = (Change_Count_dout'range => '0')) then
						Copy_start              <= '1';
						Copy_SRC_next           <= std_logic_vector(to_unsigned(PN_BRAM_BASE, PNL_BRAM_ADDR_SIZE_NB));
						Copy_TGT_next           <= std_logic_vector(to_unsigned(FINAL_CLUSTER_BASE_ADDR, PNL_BRAM_ADDR_SIZE_NB));
						KMEANS_BRAM_select_next <= copy;
						copy_select_next        <= d;
						state_next              <= wait_copy;
					else
						prev_tot_D_next <= tot_D_reg;
						dist_count_next <= dist_count_reg + 1;
						state_next      <= start_iteration;
					end if;
				end if;

		end case;
	end process;

	--PNL_BRAM_addr <= std_logic_vector(PN_addr_next);

	Kmeans_ERR <= Kmeans_ERR_reg;

	with KMEANS_BRAM_select_reg select PNL_BRAM_addr <=
		Kmeans_BRAM_addr when kmeans,
		CalAllDistance_BRAM_addr when calcAll,
		Calc_Distance_BRAM_addr 	when calcDist,
		Find_Centroid_BRAM_addr 	when findCentroid,
		Copy_BRAM_addr 				when copy,
		CalcCluster_BRAM_addr 		when calcCluster,
		CalcTotal_BRAM_addr 		when calcTotal,
		Check_assigns_BRAM_addr 	when checkAssigns;

	with KMEANS_BRAM_select_reg select PNL_BRAM_din <=
		(others => '1') when kmeans,
		CalAllDistance_BRAM_din when calcAll,      
		Calc_Distance_BRAM_din 		when calcDist,     
		Find_Centroid_BRAM_din 		when findCentroid, 
		Copy_BRAM_din 				when copy,         
		CalcCluster_BRAM_din 		when calcCluster,  
		CalcTotal_BRAM_din 			when calcTotal,    
		Check_assigns_BRAM_din  	when checkAssigns;

	with KMEANS_BRAM_select_reg select PNL_BRAM_we <=
		(others => '0') when kmeans,
		CalAllDistance_BRAM_we when calcAll,      
		Calc_Distance_BRAM_we	when calcDist,     
		Find_Centroid_BRAM_we 	when findCentroid, 
		Copy_BRAM_we 			when copy,         	
		CalcCluster_BRAM_we 	when calcCluster,  
		CalcTotal_BRAM_we 		when calcTotal,    
		Check_assigns_BRAM_we  	when checkAssigns;

	with calcDist_select select Calc_Distance_start <=
		CalAll_Dist_start when a,
		CalcTotal_Dist_start when others;

	with calcDist_select select Calc_Distance_P1_addr <=
		CalAllDistance_P1_addr when a,
		CalCTotal_P1_addr when others;

	with calcDist_select select Calc_Distance_P2_addr <=
		CalAllDistance_P2_addr when a,
		CalCTotal_P2_addr when others;

	ready <= ready_reg;

end beh;

