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
		Clk                     : in  std_logic;
		RESET                   : in  std_logic;
		start                   : in  std_logic;
		ready                   : out std_logic;
		Kmeans_ERR              : out std_logic;
		PNL_BRAM_addr           : out std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
		PNL_BRAM_din            : out std_logic_vector(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);
		PNL_BRAM_dout           : in  std_logic_vector(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);
		PNL_BRAM_we             : out std_logic_vector(0 to 0);
		BRAM_select             : out Select_Enum;
		Num_Vals                : out std_logic_vector(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);
		Num_Clusters            : out std_logic_vector(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);
		Num_Dims                : out std_logic_vector(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);
		Copy_start              : out std_logic;
		Copy_ready              : in  std_logic;
		Copy_SRC_addr           : out std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
		Copy_TGT_addr           : out std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
		CalAllDistance_start    : out std_logic;
		CalAllDistance_ready    : in  std_logic;
		CalcCluster_start       : out std_logic;
		CalcCluster_ready       : in  std_logic;
		CalCTotal_start         : out std_logic;
		CalCTotal_ready         : in  std_logic;
		CalcTotal_CalcDist_dout : in  std_logic_vector(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);
		Check_assigns_start     : out std_logic;
		Check_assigns_ready     : in  std_logic;
		Check_SRC_addr          : out std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
		Check_TGT_addr          : out std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
		Find_Centroid_start     : out std_logic;
		Find_Centroid_ready     : in  std_logic;
		Calc_Distance_ready     : in  std_logic;
		Change_Count_dout       : in  std_logic_vector(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);
		calcDist_select         : out myEnum
	);
end Kmeans;

architecture beh of Kmeans is
	type state_type is (idle, get_prog_addr, get_prog_vals, wait_find_centroid, wait_copy, start_iteration, wait_calc_cluster, wait_total, fail_improve, wait_calcAll, wait_change_count);
	signal state_reg, state_next : state_type;

	signal ready_reg, ready_next : std_logic;

	signal Kmeans_ERR_reg, Kmeans_ERR_next : std_logic;

	signal Kmeans_select : Select_Enum;

	signal num_vals_reg, num_vals_next         : unsigned(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);
	signal num_clusters_reg, num_clusters_next : unsigned(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);
	signal num_dims_reg, num_dims_next         : unsigned(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);

	-- in case we want to read "out" values
	--signal PNL_BRAM_addr_out : std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
	--signal PNL_BRAM_din_out  : std_logic_vector(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);

	--signals for CalAllDistances module

	--signal for addressing number of values,cluster,dimensions
	signal Kmeans_addr_reg, Kmeans_addr_next : unsigned(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);

	-- registers for iterations, prev_totD and cur_todD.
	signal dist_count_reg, dist_count_next : unsigned(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);

	--signals for getting number of values, clusters, dimensions

	-- value holders for total distance calculation
	signal tot_D_reg, tot_D_next           : unsigned(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);
	signal prev_tot_D_reg, prev_tot_D_next : unsigned(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);

	-- signals for module control flow
	signal copy_select_reg, copy_select_next       : myEnum;
	signal CalcAll_select_reg, CalcAll_select_next : myEnum;
	signal Cluster_select_reg, Cluster_select_next : myEnum;
	--	signal calcDistance_select : std_logic_vector(1 downto 0);

begin

	-- =============================================================================================
	-- State and register logic
	-- =============================================================================================
	process(Clk, RESET)
	begin
		if (RESET = '1') then
			state_reg          <= idle;
			ready_reg          <= '1';
			--KMEANS_BRAM_select <= b;
			tot_D_reg          <= (others => '0');
			prev_tot_D_reg     <= (others => '0');
			dist_count_reg     <= (others => '0');
			copy_select_reg    <= a;
			CalcAll_select_reg <= a;
			Cluster_select_reg <= a;
			Kmeans_addr_reg    <= (others => '0');
			num_vals_reg       <= (others => '0');
			num_clusters_reg   <= (others => '0');
			num_dims_reg       <= (others => '0');

		elsif (Clk'event and Clk = '1') then
			state_reg          <= state_next;
			ready_reg          <= ready_next;
			tot_D_reg          <= tot_D_next;
			dist_count_reg     <= dist_count_next;
			copy_select_reg    <= copy_select_next;
			CalcAll_select_reg <= CalcAll_select_next;
			Cluster_select_reg <= Cluster_select_next;
			prev_tot_D_reg     <= prev_tot_D_next;
			Kmeans_addr_reg    <= Kmeans_addr_next;
			num_vals_reg       <= num_vals_next;
			num_clusters_reg   <= num_clusters_next;
			num_dims_reg       <= num_dims_next;

		end if;
	end process;

	-- =============================================================================================
	-- Combo logic
	-- =============================================================================================
	process(state_reg, start, ready_reg, num_dims_reg, dist_count_next, num_clusters_reg, num_vals_reg, Kmeans_addr_reg, copy_select_reg, CalcAll_select_reg, Cluster_select_reg, prev_tot_D_reg, tot_D_reg, dist_count_reg, CalAllDistance_ready, Copy_ready, PNL_BRAM_dout, CalCTotal_ready, CalcCluster_ready, CalcTotal_CalcDist_dout, Calc_Distance_ready, Change_Count_dout, Check_assigns_ready, Find_Centroid_ready)
	begin
		state_next          <= state_reg;
		ready_next          <= ready_reg;
		dist_count_next     <= dist_count_reg;
		copy_select_next    <= copy_select_reg;
		Kmeans_addr_next    <= Kmeans_addr_reg;
		Cluster_select_next <= Cluster_select_reg;
		CalcAll_select_next <= CalcAll_select_reg;

		-- Default value is 0 -- used during memory initialization.
		--PNL_BRAM_din <= (others => '0');
		--PNL_BRAM_we  <= "0";
		Copy_SRC_addr  <= (others => '0');
		Copy_TGT_addr  <= (others => '0');
		Check_SRC_addr <= (others => '0');
		Check_TGT_addr <= (others => '0');
		CalAllDistance_start <= '0';
		CalcCluster_start    <= '0';
		--Calc_Distance_start  <= '0';
		CalCTotal_start      <= '0';
		Check_assigns_start  <= '0';
		Copy_start           <= '0';
		Find_Centroid_start  <= '0';
		PNL_BRAM_we          <= "0";
		PNL_BRAM_din         <= (others => '0');
		--KMEANS_BRAM_select          <= "00";

		tot_D_next        <= tot_D_reg;
		prev_tot_D_next   <= prev_tot_D_reg;
		num_vals_next     <= num_vals_reg;
		num_clusters_next <= num_clusters_reg;
		num_dims_next     <= num_dims_reg;
		Kmeans_select     <= lu_mod;
		calcDist_select   <= a;

		case state_reg is

			-- =====================
			when idle =>
				ready_next <= '1';

				if (start = '1') then
					ready_next          <= '0';
					state_next          <= get_prog_addr;
					copy_select_next    <= a;
					CalcAll_select_next <= a;
					Cluster_select_next <= a;
					dist_count_next     <= (others => '0');
					Kmeans_select       <= kmeans_drive;
					Kmeans_addr_next    <= to_unsigned(PN_BRAM_BASE, PNL_BRAM_ADDR_SIZE_NB);
					num_clusters_next   <= to_unsigned(DEFAULT_CLUSTERS, PNL_BRAM_DBITS_WIDTH_NB);
					num_vals_next       <= to_unsigned(DEFAULT_VALS, PNL_BRAM_DBITS_WIDTH_NB);
					num_dims_next       <= to_unsigned(DEFAULT_DIMS, PNL_BRAM_DBITS_WIDTH_NB);
					tot_D_next          <= (others => '0');
					calcDist_select     <= a;
					prev_tot_D_next     <= (others => '0');
				end if;

			-- start getting number of values for point,clusters,dims.
			when get_prog_addr =>
				Kmeans_select    <= kmeans_drive;
				--if at a point address: start and go to calcAll, give calcAll control of BRAM
				if (dist_count_reg = PROG_VALS) then
				
				dist_count_next <= (others => '0');
				Kmeans_select        <= calcAll;
				CalAllDistance_start <= '1';
				calcDist_select      <= a;
				state_next           <= wait_calcAll;
--
--								Copy_start    <= '1';
--								Copy_SRC_addr <= std_logic_vector(to_unsigned(PN_BRAM_BASE, PNL_BRAM_ADDR_SIZE_NB));
--								Copy_TGT_addr <= std_logic_vector(to_unsigned(FINAL_CLUSTER_BASE_ADDR, PNL_BRAM_ADDR_SIZE_NB));
--								Kmeans_select <= copy;
--								state_next    <= wait_copy; --wait_copy;
--								copy_select_next <= d;

				elsif (dist_count_reg = NUM_VALS_ADDR) then
					num_vals_next <= unsigned(PNL_BRAM_dout);
				elsif (dist_count_reg = NUM_CLUSTERS_ADDR) then
					num_clusters_next <= unsigned(PNL_BRAM_dout);
				elsif (dist_count_reg = NUM_DIMS_ADDR) then
					num_dims_next <= unsigned(PNL_BRAM_dout);
				end if;
				-- set the BRAM addr
				Kmeans_addr_next <= to_unsigned(PN_BRAM_BASE, PNL_BRAM_ADDR_SIZE_NB) + dist_count_next;
				dist_count_next  <= dist_count_reg + 1;

			-- checks value of count and sets BRAM output to the correct register
			when get_prog_vals =>
				Kmeans_select <= kmeans_drive;
				if (dist_count_reg = to_unsigned(NUM_VALS_ADDR, PNL_BRAM_ADDR_SIZE_NB)) then
					Num_Vals_next <= unsigned(PNL_BRAM_dout);
				elsif (dist_count_reg = to_unsigned(NUM_CLUSTERS_ADDR, PNL_BRAM_ADDR_SIZE_NB)) then
					Num_Clusters_next <= unsigned(PNL_BRAM_dout);
				elsif (dist_count_reg = to_unsigned(NUM_DIMS_ADDR, PNL_BRAM_ADDR_SIZE_NB)) then
					Num_Dims_next <= unsigned(PNL_BRAM_dout);
				end if;

				dist_count_next <= dist_count_reg + 1;
				state_next      <= get_prog_addr;
			-- wait for calcAll to finish, since calcDist is started within calcAll ,if calcDist is started give it control of BRAM
			-- else keep control of BRAM to calcAll
			when wait_calcAll =>
				Kmeans_select   <= calcAll;
				calcDist_select <= a;
				if (CalAllDistance_ready = '1') then
					Kmeans_select       <= findCentroid;
					Find_Centroid_start <= '1';
					state_next          <= wait_find_centroid;
				else
					if (Calc_Distance_ready = '0') then
						Kmeans_select <= calcDist;
					else
						Kmeans_select <= calcAll;
					end if;
				end if;

			-- wait for find centroid, if its outside the while loop then go to copy
			-- otherwise go to wait change count
			when wait_find_centroid =>
				Kmeans_select <= findCentroid;
				if (Find_Centroid_ready = '1') then
					case CalcAll_select_reg is
						when a =>
							Copy_start       <= '1';
							Copy_SRC_addr    <= std_logic_vector(to_unsigned(CLUSTER_BASE_ADDR, PNL_BRAM_ADDR_SIZE_NB));
							Copy_TGT_addr    <= std_logic_vector(to_unsigned(COPY_CLUSTER_BASE_ADDR, PNL_BRAM_ADDR_SIZE_NB));
							Kmeans_select    <= copy;
							copy_select_next <= a;
							state_next       <= wait_copy;
						--state_next       <= idle;
						when others =>
							Check_assigns_start <= '1';
							Check_SRC_addr      <= std_logic_vector(to_unsigned(CLUSTER_BASE_ADDR, PNL_BRAM_ADDR_SIZE_NB));
							Check_TGT_addr      <= std_logic_vector(to_unsigned(COPY_CLUSTER_BASE_ADDR, PNL_BRAM_ADDR_SIZE_NB));
							Kmeans_select       <= checkAssigns;
							state_next          <= wait_change_count;
					end case;
				end if;

			-- wait for copy to finish
			-- chose next stat based on copy select
			-- wait_copy is the exit control
			when wait_copy =>
				Kmeans_select <= copy;
				if (Copy_ready = '1') then
					--state_next <= idle;
					case copy_select_reg is
						when a =>
							state_next      <= start_iteration;
							dist_count_next <= (others => '0');
						--state_next <= idle;
						when b =>
							Kmeans_select       <= calcCluster;
							CalcCluster_start   <= '1';
							Cluster_select_next <= b;
							state_next          <= wait_calc_cluster;
						when c =>
							CalAllDistance_start <= '1';
							--CalcAll_select_next  <= b;
							state_next           <= wait_calcAll;
							calcDist_select      <= a;
							CalcAll_select_next <= b;
							Kmeans_select        <= calcAll;
						when others =>
							state_next <= idle;
					end case;
				end if;

			--starts the while loop, count until Max_iterations 
			when start_iteration =>
				if (dist_count_reg = MAX_ITERATIONS) then
					Copy_start       <= '1';
					Copy_SRC_addr    <= std_logic_vector(to_unsigned(CLUSTER_BASE_ADDR, PNL_BRAM_ADDR_SIZE_NB));
					Copy_TGT_addr    <= std_logic_vector(to_unsigned(FINAL_CLUSTER_BASE_ADDR, PNL_BRAM_ADDR_SIZE_NB));
					Kmeans_select    <= copy;
					copy_select_next <= d;
					state_next       <= wait_copy;
				else
					Kmeans_select     <= calcCluster;
					CalcCluster_start <= '1';
					state_next        <= wait_calc_cluster;
				end if;

			when wait_calc_cluster =>
				Kmeans_select <= calcCluster;
				if (CalcCluster_ready = '1') then
					--state_next <= wait_total;
					case Cluster_select_reg is
						when a =>
							Kmeans_select   <= calcTotal;
							CalcTotal_start <= '1';
							calcDist_select <= b;
							state_next      <= wait_total;
						--state_next      <= idle;
						when others =>
							Copy_start       <= '1';
							Copy_SRC_addr    <= std_logic_vector(to_unsigned(CLUSTER_BASE_ADDR, PNL_BRAM_ADDR_SIZE_NB));
							Copy_TGT_addr    <= std_logic_vector(to_unsigned(FINAL_CLUSTER_BASE_ADDR, PNL_BRAM_ADDR_SIZE_NB));
							Kmeans_select    <= copy;
							copy_select_next <= d;
							--Copy_Num_vals_in   <= Num_dims;
							state_next       <= wait_copy;
					end case;
				end if;

			when wait_total =>
				calcDist_select <= b;
				Kmeans_select   <= calcTotal;
				if (CalcTotal_ready = '1') then
					tot_D_next <= unsigned(CalcTotal_CalcDist_dout);
					state_next <= fail_improve;
				--state_next <= idle;
				else
					if (Calc_Distance_ready = '0') then
						Kmeans_select <= calcDist;
					else
						Kmeans_select <= calcTotal;
					end if;
				end if;

			-- check if we failed to improve
			when fail_improve =>

				if (dist_count_reg /= (dist_count_reg'range => '0') and tot_D_reg > prev_tot_D_reg) then
					Copy_start       <= '1';
					Copy_SRC_addr    <= std_logic_vector(to_unsigned(COPY_CLUSTER_BASE_ADDR, PNL_BRAM_ADDR_SIZE_NB));
					Copy_TGT_addr    <= std_logic_vector(to_unsigned(CLUSTER_BASE_ADDR, PNL_BRAM_ADDR_SIZE_NB));
					Kmeans_select    <= copy;
					copy_select_next <= b;
				else
					Copy_start       <= '1';
					Copy_SRC_addr    <= std_logic_vector(to_unsigned(CLUSTER_BASE_ADDR, PNL_BRAM_ADDR_SIZE_NB));
					Copy_TGT_addr    <= std_logic_vector(to_unsigned(COPY_CLUSTER_BASE_ADDR, PNL_BRAM_ADDR_SIZE_NB));
					Kmeans_select    <= copy;
					copy_select_next <= c;
				end if;
				state_next <= wait_copy;

			-- wait for change count module to finish
			when wait_change_count =>
				Kmeans_select <= checkAssigns;
				--state_next    <= idle;
				--				prev_tot_D_next <= tot_D_reg;
				--				state_next      <= start_iteration;
				--				dist_count_next <= dist_count_reg + 1;
				--state_next      <= start_iteration;
				if (Check_assigns_ready = '1') then
					if (Change_Count_dout = (Change_Count_dout'range => '0')) then
						Copy_start       <= '1';
						Copy_SRC_addr    <= std_logic_vector(to_unsigned(CLUSTER_BASE_ADDR, PNL_BRAM_ADDR_SIZE_NB));
						Copy_TGT_addr    <= std_logic_vector(to_unsigned(FINAL_CLUSTER_BASE_ADDR, PNL_BRAM_ADDR_SIZE_NB));
						Kmeans_select    <= copy;
						copy_select_next <= d;
						state_next       <= wait_copy;
					--state_next       <= wait_copy;
					else
						prev_tot_D_next <= tot_D_reg;
						--state_next      <= idle;
						dist_count_next <= dist_count_reg + 1;
						state_next      <= start_iteration;
					end if;
				end if;

		end case;
	end process;

	--PNL_BRAM_addr <= std_logic_vector(PN_addr_next);

	Kmeans_ERR <= Kmeans_ERR_reg;
	--
	--	with KMEANS_Kmeans_select_reg select PNL_BRAM_addr_out <=
	--		Kmeans_BRAM_addr when kmeans,
	--		CalAllDistance_BRAM_addr when calcAll,
	--		Calc_Distance_BRAM_addr 	when calcDist,
	--		Find_Centroid_BRAM_addr 	when findCentroid,
	--		Copy_BRAM_addr 				when copy,
	--		CalcCluster_BRAM_addr 		when calcCluster,
	--		CalcTotal_BRAM_addr 		when calcTotal,
	--		Check_assigns_BRAM_addr 	when checkAssigns;
	--
	--	with KMEANS_Kmeans_select_reg select PNL_BRAM_din_out <=
	--		Kmeans_BRAM_din when kmeans,
	--		CalAllDistance_BRAM_din when calcAll,      
	--		Calc_Distance_BRAM_din 		when calcDist,     
	--		Find_Centroid_BRAM_din 		when findCentroid, 
	--		Copy_BRAM_din 				when copy,         
	--		CalcCluster_BRAM_din 		when calcCluster,  
	--		CalcTotal_BRAM_din 			when calcTotal,    
	--		Check_assigns_BRAM_din  	when checkAssigns;
	--
	--	with KMEANS_Kmeans_select_reg select PNL_BRAM_we <=
	--		Kmeans_BRAM_we when kmeans,
	--		CalAllDistance_BRAM_we when calcAll,      
	--		Calc_Distance_BRAM_we	when calcDist,     
	--		Find_Centroid_BRAM_we 	when findCentroid, 
	--		Copy_BRAM_we 			when copy,         	
	--		CalcCluster_BRAM_we 	when calcCluster,  
	--		CalcTotal_BRAM_we 		when calcTotal,    
	--		Check_assigns_BRAM_we  	when checkAssigns;

	PNL_BRAM_addr <= std_logic_vector(Kmeans_addr_next);
	BRAM_select   <= Kmeans_select;
	ready         <= ready_reg;
	Num_Vals      <= std_logic_vector(num_vals_reg);
	Num_Clusters  <= std_logic_vector(num_clusters_reg);
	Num_Dims      <= std_logic_vector(num_dims_reg);

end beh;

