library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.Cache_Types.all; -- Include the package with the Array Type

entity tb_cache_controller is
end tb_cache_controller;

architecture sim of tb_cache_controller is

    -- ------------------------------------------------------------------
    -- Signals
    -- ------------------------------------------------------------------
    signal clk             : std_logic := '0';
    signal rst             : std_logic := '0';
    
    -- Bus Inputs
    signal i_bus_addr      : std_logic_vector(15 downto 0) := (others => '0');
    signal i_bus_cmd       : std_logic_vector(1 downto 0)  := "00";
    signal i_bus_source_id : integer range 0 to 2 := 0;
    
    -- Bus Outputs
    signal o_bus_abort     : std_logic;
    
    -- Cache Interface (Arrays)
    signal o_snoop_addr      : std_logic_vector(15 downto 0);
    signal o_snoop_check     : std_logic_vector(2 downto 0);
    signal i_snoop_hit       : std_logic_vector(2 downto 0) := (others => '0');
    signal i_snoop_mesi      : t_mesi_array := (others => "11"); -- Default Invalid
    
    signal o_snoop_update_en : std_logic_vector(2 downto 0);
    signal o_snoop_new_state : t_mesi_array;

    -- Constants for Simulation
    constant CLK_PERIOD : time := 10 ns;
    
    -- MESI Helpers
    constant MESI_M : std_logic_vector(1 downto 0) := "00";
    constant MESI_E : std_logic_vector(1 downto 0) := "01";
    constant MESI_S : std_logic_vector(1 downto 0) := "10";
    constant MESI_I : std_logic_vector(1 downto 0) := "11";

    constant CMD_NOP     : std_logic_vector(1 downto 0) := "00";
    constant CMD_BUS_RD  : std_logic_vector(1 downto 0) := "01";
    constant CMD_BUS_RDX : std_logic_vector(1 downto 0) := "10";

begin

    -- ------------------------------------------------------------------
    -- Instantiate the DUT (Device Under Test)
    -- ------------------------------------------------------------------
    DUT: entity work.cache_controller
        port map (
            clk               => clk,
            rst               => rst,
            i_bus_addr        => i_bus_addr,
            i_bus_cmd         => i_bus_cmd,
            i_bus_source_id   => i_bus_source_id,
            o_bus_abort       => o_bus_abort,
            o_snoop_addr      => o_snoop_addr,
            o_snoop_check     => o_snoop_check,
            i_snoop_hit       => i_snoop_hit,
            i_snoop_mesi      => i_snoop_mesi,
            o_snoop_update_en => o_snoop_update_en,
            o_snoop_new_state => o_snoop_new_state
        );

    -- Clock Generation
    clk_process : process
    begin
        while true loop
            clk <= '0';
            wait for CLK_PERIOD/2;
            clk <= '1';
            wait for CLK_PERIOD/2;
        end loop;
    end process;

    -- ------------------------------------------------------------------
    -- Test Stimulus
    -- ------------------------------------------------------------------
    stim_proc : process
    begin
        -- RESET
        rst <= '1';
        wait for 2*CLK_PERIOD;
        rst <= '0';
        wait for CLK_PERIOD;
        
        -- =============================================================
        -- TEST 1: Bus Read by Cache 0 -> Cache 1 has Valid Copy (Exclusive)
        -- Expected: Cache 1 Downgrades E -> S
        -- =============================================================
        report "TEST 1: Cache 0 reads, Cache 1 hits (Exclusive)" severity note;
        
        i_bus_source_id <= 0;          -- Cache 0 initiates
        i_bus_cmd       <= CMD_BUS_RD; -- Read Request
        i_bus_addr      <= x"AAAA";
        
        -- Simulate Cache Responses (Cache 1 says "I have it in Exclusive")
        i_snoop_hit(0) <= '0'; 
        i_snoop_hit(1) <= '1'; i_snoop_mesi(1) <= MESI_E;
        i_snoop_hit(2) <= '0';
        
        wait for CLK_PERIOD;
        
        -- Check Logic
        -- o_snoop_check should be "110" (Check 1 and 2, but not 0)
        -- o_snoop_update_en(1) should be '1'
        -- o_snoop_new_state(1) should be "10" (Shared)
        
        assert o_snoop_update_en(1) = '1' report "Test 1 Failed: Cache 1 update not enabled" severity error;
        assert o_snoop_new_state(1) = MESI_S report "Test 1 Failed: Cache 1 did not go Shared" severity error;
        
        -- Clear
        i_bus_cmd <= CMD_NOP;
        i_snoop_hit <= "000";
        wait for CLK_PERIOD;

        
        -- =============================================================
        -- TEST 2: Bus Write (RDX) by Cache 1 -> Cache 2 has Shared Copy
        -- Expected: Cache 2 Invalidates (S -> I)
        -- =============================================================
        report "TEST 2: Cache 1 writes, Cache 2 hits (Shared)" severity note;
        
        i_bus_source_id <= 1;           -- Cache 1 initiates
        i_bus_cmd       <= CMD_BUS_RDX; -- Write Request
        i_bus_addr      <= x"BBBB";
        
        -- Simulate Cache Responses
        i_snoop_hit(0) <= '0';
        i_snoop_hit(1) <= '0'; -- Self hit doesn't matter here
        i_snoop_hit(2) <= '1'; i_snoop_mesi(2) <= MESI_S;
        
        wait for CLK_PERIOD;
        
        assert o_snoop_update_en(2) = '1'    report "Test 2 Failed: Cache 2 update not enabled" severity error;
        assert o_snoop_new_state(2) = MESI_I report "Test 2 Failed: Cache 2 did not go Invalid" severity error;
        
        i_bus_cmd <= CMD_NOP;
        i_snoop_hit <= "000";
        wait for CLK_PERIOD;


        -- =============================================================
        -- TEST 3: Bus Read by Cache 2 -> Cache 0 has Modified Copy
        -- Expected: Cache 0 Flushes (Abort) and Downgrades (M -> S)
        -- =============================================================
        report "TEST 3: Cache 2 reads, Cache 0 hits (Modified)" severity note;
        
        i_bus_source_id <= 2;
        i_bus_cmd       <= CMD_BUS_RD;
        i_bus_addr      <= x"CCCC";
        
        i_snoop_hit(0) <= '1'; i_snoop_mesi(0) <= MESI_M;
        i_snoop_hit(1) <= '0';
        
        wait for CLK_PERIOD;
        
        assert o_bus_abort = '1'             report "Test 3 Failed: Bus Abort (Flush) not asserted" severity error;
        assert o_snoop_update_en(0) = '1'    report "Test 3 Failed: Cache 0 update not enabled" severity error;
        assert o_snoop_new_state(0) = MESI_S report "Test 3 Failed: Cache 0 did not go Shared" severity error;

        i_bus_cmd <= CMD_NOP;
        i_snoop_hit <= "000";
        wait for CLK_PERIOD;
        
        
        -- =============================================================
        -- TEST 4: Snoop Filtering (Don't Snoop Self)
        -- Expected: o_snoop_check(0) should be '0' if source is 0
        -- =============================================================
        report "TEST 4: Snoop Filtering Check" severity note;
        
        i_bus_source_id <= 0;
        i_bus_cmd       <= CMD_BUS_RD;
        
        wait for CLK_PERIOD;
        
        -- "110" -> Check 2 and 1, do NOT check 0
        assert o_snoop_check(0) = '0' report "Test 4 Failed: Controller tried to snoop the requester" severity error;
        assert o_snoop_check(1) = '1' report "Test 4 Failed: Controller failed to snoop neighbor" severity error;
        
        report "Simulation Completed Successfully." severity note;
        wait;
        
    end process;

end architecture sim;