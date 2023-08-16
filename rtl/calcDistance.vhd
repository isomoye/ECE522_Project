-- ===================================================================================================
-- ===================================================================================================
-- Calculate distance. No need for square root -- just watch out for overflow

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.all;
use IEEE.fixed_pkg.all;

library work;
use work.DataTypes_pkg.all;

entity CalcDistance is
	port(
		Clk           : in  std_logic;
		RESET         : in  std_logic;
		start         : in  std_logic;
		ready         : out std_logic;
		PNL_BRAM_addr : out std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
		P1_addr       : in  std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
		P2_addr       : in  std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
		Num_dims      : in  std_logic_vector(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
		CalcDist_dout : out std_logic_vector(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);
		PNL_BRAM_din  : out std_logic_vector(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);
		PNL_BRAM_dout : in  std_logic_vector(PNL_BRAM_DBITS_WIDTH_NB - 1 downto 0);
		PNL_BRAM_we   : out std_logic_vector(0 to 0)
	);
end CalcDistance;

architecture beh of CalcDistance is
	type state_type is (idle, get_p1_addr, get_p1_val, get_p2_addr, get_p2_val, get_dist, get_sqr, sum_dist);
	signal state_reg, state_next : state_type;

	signal ready_reg, ready_next : std_logic;

	-- Address registers for the PNs and CalcAllDistgram portions of memory
	signal PN_addr_reg, PN_addr_next : unsigned(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);
	--   signal points_addr_reg, points_addr_next: unsigned(PNL_BRAM_ADDR_SIZE_NB-1 downto 0);

	-- for iterating through # of points and #cluster

	signal dims_count_reg, dims_count_next : unsigned(PNL_BRAM_ADDR_SIZE_NB - 1 downto 0);

	-- Stores the full 16-bit distance 
	signal distance_val_reg, distance_val_next : sfixed(PN_INTEGER_NB - 1 downto -PN_PRECISION_NB);
	signal dist_sqr_reg, dist_sqr_next         : sfixed(PN_INTEGER_NB - 1 downto -PN_PRECISION_NB);
	signal p1_val_reg, p1_val_next             : sfixed(PN_INTEGER_NB - 1 downto -PN_PRECISION_NB);
	signal p2_val_reg, p2_val_next             : sfixed(PN_INTEGER_NB - 1 downto -PN_PRECISION_NB);

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
			p1_val_reg       <= (others => '0');
			p2_val_reg       <= (others => '0');
			distance_val_reg <= (others => '0');
			dims_count_reg   <= (others => '0');
			dist_sqr_reg     <= (others => '0');
		elsif (Clk'event and Clk = '1') then
			state_reg        <= state_next;
			ready_reg        <= ready_next;
			PN_addr_reg      <= PN_addr_next;
			p1_val_reg       <= p1_val_next;
			p2_val_reg       <= p2_val_next;
			dims_count_reg   <= dims_count_next;
			distance_val_reg <= distance_val_next;
			dist_sqr_reg     <= dist_sqr_next;
		end if;
	end process;

	-- =============================================================================================
	-- Combo logic
	-- =============================================================================================
	process(state_reg, start, ready_reg, PN_addr_reg, p1_val_reg, p2_val_reg, dist_sqr_reg, dims_count_reg, Num_dims, P1_addr, P2_addr, distance_val_reg, PNL_BRAM_dout)
	begin
		state_next <= state_reg;
		ready_next <= ready_reg;

		PN_addr_next      <= PN_addr_reg;
		distance_val_next <= distance_val_reg;
		dist_sqr_next     <= dist_sqr_reg;
		p1_val_next       <= p1_val_reg;
		p2_val_next       <= p2_val_reg;
		dims_count_next   <= dims_count_reg;

		-- Default value is 0 -- used during memory initialization.
		PNL_BRAM_din <= (others => '0');
		PNL_BRAM_we  <= "0";

		case state_reg is

			-- =====================
			when idle =>
				ready_next <= '1';

				if (start = '1') then
					ready_next <= '0';

					-- Zero the register that will store distances
					distance_val_next <= (others => '0');
					dist_sqr_next     <= (others => '0');
					p1_val_next       <= (others => '0');
					p2_val_next       <= (others => '0');
					dims_count_next   <= (others => '0');
					PN_addr_next      <= to_unsigned(PN_BRAM_BASE, PNL_BRAM_ADDR_SIZE_NB);
					state_next        <= get_p1_addr;
				end if;

			--check exit condition and convert first address
			when get_p1_addr =>
				if (dims_count_reg >= unsigned(Num_dims) - 1) then
					dims_count_next <= (others => '0');
					CalcDist_dout   <= std_logic_vector(distance_val_reg);
					state_next      <= idle;
				else
					PN_addr_next <= unsigned(P1_addr) + dims_count_reg;
					state_next   <= get_p1_val;
				end if;

			-- get p1 value
			when get_p1_val =>
				p1_val_next <= sfixed(PNL_BRAM_dout);
				state_next  <= get_p2_addr;

			--convert second address
			when get_p2_addr =>
				PN_addr_next <= unsigned(P2_addr) + dims_count_reg;
				state_next   <= get_p2_val;

			--get second value
			when get_p2_val =>
				p2_val_next <= sfixed(PNL_BRAM_dout);
				state_next  <= get_dist;

			--start distance calculation
			when get_dist =>
				distance_val_next <= p1_val_reg - p2_val_reg, distance_val_reg;
				state_next        <= get_sqr;
			--square the value  separated the operations to avoid timing issues
			when get_sqr =>
				dist_sqr_next <= distance_val_reg * distance_val_reg;
				state_next    <= sum_dist;

			--sum distances
			when sum_dist =>
				distance_val_next <= distance_val_reg + dist_sqr_reg;
				dims_count_next   <= dims_count_reg + 1;
				state_next        <= get_p1_addr;

		end case;
	end process;

	-- Using _reg here (not the look-ahead _next value).
	PNL_BRAM_addr <= std_logic_vector(PN_addr_next);

	ready <= ready_reg;

end beh;

