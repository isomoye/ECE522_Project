-- ===================================================================================================
-- ===================================================================================================
-- Calculate distance. No need for square root -- just watch out for overflow

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.all;

library work;
use work.DataTypes_pkg.all;

entity CopyAssignmentArray is
	port(
		Clk           : in  std_logic;
		RESET         : in  std_logic;
		start         : in  std_logic;
		ready         : out std_logic;
		PNL_BRAM_addr : out std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
		PNL_BRAM_din  : out std_logic_vector(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);
		PNL_BRAM_dout : in  std_logic_vector(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);
		PNL_BRAM_we   : out std_logic_vector(0 to 0);
		Num_Vals      : in  std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
		SRC_BRAM_addr : in  std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
		TGT_BRAM_addr : in  std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0)
	);
end CopyAssignmentArray;

architecture beh of CopyAssignmentArray is
	type state_type is (idle, get_cluster_addr, get_cluster_val, store_val);
	signal state_reg, state_next : state_type;

	signal ready_reg, ready_next : std_logic;

	-- Address registers for the PNs and CalcAllDistgram portions of memory
	signal PN_addr_reg, PN_addr_next           : unsigned(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
	signal cluster_addr_reg, cluster_addr_next : unsigned(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);

	--   signal points_addr_reg, points_addr_next: unsigned(PNL_BRAM_ADDR_SIZE_NB-1 downto 0);

	-- for iterating through # of points and #cluster
	signal dist_count_reg, dist_count_next : unsigned(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
	-- signal cluster_val_reg, cluster_val_next:  unsigned(3 downto 0);

	-- For selecting between PN or CalcAllDist portion of memory during memory accesses
	signal do_PN_cluster_addr : std_logic;

	-- Stores the full 16-bit distance 
	signal cluster_val_reg, cluster_val_next   : unsigned(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);
	signal copy_cluster_reg, copy_cluster_next : unsigned(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);

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
			dist_count_reg   <= (others => '0');
			copy_cluster_reg <= (others => '0');
		elsif (Clk'event and Clk = '1') then
			state_reg        <= state_next;
			ready_reg        <= ready_next;
			PN_addr_reg      <= PN_addr_next;
			cluster_val_reg  <= cluster_val_next;
			cluster_addr_reg <= cluster_addr_next;
			dist_count_reg   <= dist_count_next;
			copy_cluster_reg <= copy_cluster_next;
		end if;
	end process;

	-- =============================================================================================
	-- Combo logic
	-- =============================================================================================

	process(state_reg, start, ready_reg, Num_Vals, PN_addr_reg, TGT_BRAM_addr, SRC_BRAM_addr, cluster_addr_reg, dist_count_reg, copy_cluster_reg, cluster_val_reg, PNL_BRAM_dout)
	begin
		state_next <= state_reg;
		ready_next <= ready_reg;

		PN_addr_next      <= PN_addr_reg;
		cluster_val_next  <= cluster_val_reg;
		cluster_addr_next <= cluster_addr_reg;
		copy_cluster_next <= copy_cluster_reg;
		dist_count_next   <= dist_count_reg;

		-- Default value is 0 -- used during memory initialization.
		--PNL_BRAM_din <= (others => '0');

		PNL_BRAM_we <= "0";

		do_PN_cluster_addr <= '0';

		case state_reg is

			-- =====================
			when idle =>
				ready_next <= '1';

				if (start = '1') then
					ready_next <= '0';

					-- Assert 'we' to zero out the first cell at 0.
					--PNL_BRAM_we <= "1";
					copy_cluster_next <= (others => '0');
					cluster_val_next  <= (others => '0');
					dist_count_next   <= (others => '0');
					PN_addr_next      <= (others => '0');
					cluster_addr_next <= (others => '0');
					state_next        <= get_cluster_addr;
				end if;

			when get_cluster_addr =>

				if (dist_count_reg >= (unsigned(Num_Vals) - 1)) then
					state_next <= idle;
				else
					--	points_addr_next <= to_unsigned(KMEANS_PN_BRAM_LOWER_LIMIT,PNL_BRAM_ADDR_SIZE_NB) 
					--	+ (dist_count_reg * dims_count);
					PN_addr_next <= unsigned(SRC_BRAM_addr) + dist_count_reg;
					state_next   <= get_cluster_val;
				end if;

			-- =====================
			-- get bram address of current centroid.
			when get_cluster_val =>
				cluster_val_next <= unsigned(PNL_BRAM_dout);
				state_next       <= store_val;
			-- get p1 value
			when store_val =>
				PNL_BRAM_din       <= std_logic_vector(cluster_val_reg);
				PNL_BRAM_we        <= "1";
				do_PN_cluster_addr <= '1';
				cluster_addr_next  <= unsigned(TGT_BRAM_addr) + dist_count_reg;
				dist_count_next    <= dist_count_reg + 1;
				state_next         <= get_cluster_addr;
		end case;
	end process;

	-- Using _reg here (not the look-ahead _next value).
	with do_PN_cluster_addr select PNL_BRAM_addr <=
		std_logic_vector(PN_addr_next) when '0',
		std_logic_vector(cluster_addr_next) when others;

	ready <= ready_reg;

end beh;

