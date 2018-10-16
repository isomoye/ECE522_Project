-- ===================================================================================================
-- ===================================================================================================
-- Calculate distance. No need for square root -- just watch out for overflow

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.all;

library work;
use work.DataTypes_pkg.all;

entity CheckIfAssignmentCountChanged is
	port(
		Clk               : in  std_logic;
		RESET             : in  std_logic;
		start             : in  std_logic;
		ready             : out std_logic;
		PNL_BRAM_addr     : out std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
		PNL_BRAM_din      : out std_logic_vector(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);
		PNL_BRAM_dout     : in  std_logic_vector(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);
		PNL_BRAM_we       : out std_logic_vector(0 to 0);
		Num_Vals          : in  std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
		SRC_BRAM_addr     : in  std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
		TGT_BRAM_addr     : in  std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
		Change_Count_dout : out std_logic_vector(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0)
	);
end CheckIfAssignmentCountChanged;

architecture beh of CheckIfAssignmentCountChanged is
	type state_type is (idle, get_p1_addr, get_p1_val, get_p2_addr, get_p2_val, change_count);
	signal state_reg, state_next : state_type;

	signal ready_reg, ready_next : std_logic;

	-- Address registers for the PNs and CalcAllDistgram portions of memory
	signal PN_addr_reg, PN_addr_next           : unsigned(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
	signal cluster_addr_reg, cluster_addr_next : unsigned(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);

	--   signal points_addr_reg, points_addr_next: unsigned(PNL_BRAM_ADDR_SIZE_NB-1 downto 0);

	-- for iterating through # of points and #cluster
	signal dist_count_reg, dist_count_next : unsigned(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);

	-- For selecting between PN or CalcAllDist portion of memory during memory accesses
	signal do_PN_cluster_addr : std_logic;

	-- Stores the full 16-bit distance
	signal cluster_val_reg, cluster_val_next   : unsigned(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);
	signal copy_cluster_reg, copy_cluster_next : unsigned(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);
	signal change_count_reg, change_count_next : unsigned(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);

begin

	-- =============================================================================================
	-- State and register logic
	-- =============================================================================================
	process(Clk, RESET)
	begin
		if (RESET = '1') then
			state_reg        <= idle;
			ready_reg        <= '1';
			PN_addr_reg      <= (others => '0');
			cluster_val_reg  <= (others => '0');
			cluster_addr_reg <= (others => '0');
			change_count_reg <= (others => '0');
			dist_count_reg   <= (others => '0');
			cluster_addr_reg <= (others => '0');
			copy_cluster_reg <= (others => '0');
		elsif (Clk'event and Clk = '1') then
			state_reg        <= state_next;
			ready_reg        <= ready_next;
			PN_addr_reg      <= PN_addr_next;
			cluster_val_reg  <= cluster_val_next;
			change_count_reg <= change_count_next;
			cluster_addr_reg <= cluster_addr_next;
			dist_count_reg   <= dist_count_next;
			copy_cluster_reg <= copy_cluster_next;
		end if;
	end process;

	-- =============================================================================================
	-- Combo logic
	-- =============================================================================================

	process(state_reg, start, ready_reg, PN_addr_reg, cluster_addr_reg, change_count_reg, dist_count_reg, copy_cluster_reg, cluster_val_reg, PNL_BRAM_dout, Num_Vals, SRC_BRAM_addr, TGT_BRAM_addr)
	begin
		state_next <= state_reg;
		ready_next <= ready_reg;

		PN_addr_next      <= PN_addr_reg;
		cluster_val_next  <= cluster_val_reg;
		cluster_addr_next <= cluster_addr_reg;
		copy_cluster_next <= copy_cluster_reg;
		dist_count_next   <= dist_count_reg;
		change_count_next <= change_count_reg;

		-- Default value is 0 -- used during memory initialization.
		PNL_BRAM_din <= (others => '0');

		PNL_BRAM_we <= "0";

		do_PN_cluster_addr <= '0';

		case state_reg is

			-- =====================
			when idle =>
				ready_next <= '1';

				if (start = '1') then
					ready_next <= '0';

					-- Allow CalcAllDist_addr to drive PNL_BRAM
					do_PN_cluster_addr <= '1';

					-- Assert 'we' to zero out the first cell at 0.
					--PNL_BRAM_we <= "1";
					copy_cluster_next <= (others => '0');
					dist_count_next   <= (others => '0');
					cluster_val_next  <= (others => '0');
					change_count_next <= (others => '0');
					PN_addr_next      <= to_unsigned(PN_BRAM_BASE, PNL_BRAM_ADDR_SIZE_NB);
					state_next        <= get_p1_addr;
				end if;

			when get_p1_addr =>

				if (dist_count_reg = unsigned(Num_Vals) - 1) then
					Change_Count_dout <= std_logic_vector(change_count_reg);
					state_next        <= idle;
				else
					PN_addr_next <= unsigned(SRC_BRAM_addr) + dist_count_reg;
					state_next   <= get_p1_val;
				end if;

			-- =====================
			-- get bram address of current centroid.
			when get_p1_val =>
				cluster_val_next <= unsigned(PNL_BRAM_dout);
				state_next       <= get_p2_addr;

			when get_p2_addr =>
				PN_addr_next <= unsigned(TGT_BRAM_addr) + dist_count_reg;
				state_next   <= get_p2_val;

			-- =====================
			-- get bram address of current centroid.
			when get_p2_val =>
				cluster_val_next <= unsigned(PNL_BRAM_dout);
				state_next       <= change_count;
			-- get p1 value
			when change_count =>

				if (cluster_addr_reg /= copy_cluster_reg) then
					change_count_next <= change_count_reg + 1;
				end if;
				dist_count_next <= dist_count_reg + 1;
				state_next      <= get_p1_addr;
		end case;
	end process;

	-- Using _reg here (not the look-ahead _next value).
	PNL_BRAM_addr <= std_logic_vector(PN_addr_next);

	ready <= ready_reg;

end beh;

