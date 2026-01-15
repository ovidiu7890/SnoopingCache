library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
-- Ensure this package is compiled in your library
use work.Cache_Types.all; 

entity tb_cache_controller is
end tb_cache_controller;

architecture Behavioral of tb_cache_controller is

    -- Component Declaration
    component cache_controller is
        Port (
            clk             : in std_logic;
            rst             : in std_logic;
            i_bus_addr      : in std_logic_vector(15 downto 0);
            i_bus_cmd       : in std_logic_vector(1 downto 0);
            i_bus_source_id : in integer range 0 to 2;
            o_bus_abort     : out std_logic;
            o_snoop_addr    : out std_logic_vector(15 downto 0);
            o_snoop_check   : out std_logic_vector(2 downto 0);
            i_snoop_hit     : in  std_logic_vector(2 downto 0);
            i_snoop_mesi    : in  t_mesi_array;
            o_snoop_update_en : out std_logic_vector(2 downto 0);
            o_snoop_new_state : out t_mesi_array;
            o_response_mesi   : out t_mesi_array 
        );
    end component;

    -- Signals
    signal clk : std_logic := '0';
    signal rst : std_logic := '0';
    
    -- Inputs
    signal i_bus_addr      : std_logic_vector(15 downto 0) := (others => '0');
    signal i_bus_cmd       : std_logic_vector(1 downto 0) := "00";
    signal i_bus_source_id : integer range 0 to 2 := 0;
    signal i_snoop_hit     : std_logic_vector(2 downto 0) := "000";
    signal i_snoop_mesi    : t_mesi_array := (others => "11"); -- Default Invalid

    -- Outputs
    signal o_bus_abort     : std_logic;
    signal o_snoop_addr    : std_logic_vector(15 downto 0);
    signal o_snoop_check   : std_logic_vector(2 downto 0);
    signal o_snoop_update_en : std_logic_vector(2 downto 0);
    signal o_snoop_new_state : t_mesi_array;
    signal o_response_mesi   : t_mesi_array;

    -- Constants
    constant CLK_PERIOD : time := 10 ns;
    
    -- MESI Constants for Checks
    constant MESI_M : std_logic_vector(1 downto 0) := "00";
    constant MESI_E : std_logic_vector(1 downto 0) := "01";
    constant MESI_S : std_logic_vector(1 downto 0) := "10";
    constant MESI_I : std_logic_vector(1 downto 0) := "11";
    
    constant CMD_BUS_RD  : std_logic_vector(1 downto 0) := "01";
    constant CMD_BUS_RDX : std_logic_vector(1 downto 0) := "10";

begin

    -- Instantiate DUT
    uut: cache_controller port map (
        clk => clk, rst => rst,
        i_bus_addr => i_bus_addr, i_bus_cmd => i_bus_cmd, i_bus_source_id => i_bus_source_id,
        o_bus_abort => o_bus_abort, o_snoop_addr => o_snoop_addr, o_snoop_check => o_snoop_check,
        i_snoop_hit => i_snoop_hit, i_snoop_mesi => i_snoop_mesi,
        o_snoop_update_en => o_snoop_update_en, o_snoop_new_state => o_snoop_new_state,
        o_response_mesi => o_response_mesi
    );

    -- Clock Process
    clk_process : process
    begin
        clk <= '0'; wait for CLK_PERIOD/2;
        clk <= '1'; wait for CLK_PERIOD/2;
    end process;

    -- Stimulus Process
    stim_proc: process
    begin
        -- 1. Reset
        rst <= '1';
        wait for 20 ns;
        rst <= '0';
        wait for 10 ns;

        report "------------------------------------------------" severity note;
        report "TEST 1: Standard Read Miss (No Sharers)" severity note;
        report "------------------------------------------------" severity note;
        -- CPU 0 Reads 0x1000. No one has it.
        i_bus_source_id <= 0;
        i_bus_addr      <= x"1000";
        i_bus_cmd       <= CMD_BUS_RD;
        i_snoop_hit     <= "000"; -- No hit
        i_snoop_mesi    <= ("11", "11", "11");
        
        wait for CLK_PERIOD;
        
        -- Check Response
        assert o_response_mesi(0) = MESI_E report "TEST 1 FAILED: Expected Exclusive (E)" severity error;
        assert o_bus_abort = '0' report "TEST 1 FAILED: Unexpected Abort" severity error;

        -- Reset Inputs
        i_bus_cmd <= "00"; wait for CLK_PERIOD;


        report "------------------------------------------------" severity note;
        report "TEST 2: Read Miss with Shared Copy" severity note;
        report "------------------------------------------------" severity note;
        -- CPU 0 Reads 0x2000. CPU 1 has it in Shared (S).
        i_bus_source_id <= 0;
        i_bus_addr      <= x"2000";
        i_bus_cmd       <= CMD_BUS_RD;
        i_snoop_hit     <= "010"; -- Hit on CPU 1
        i_snoop_mesi    <= (0 => "11", 1 => "10", 2 => "11"); -- CPU 1 is S
        
        wait for CLK_PERIOD;
        
        -- Check Response
        assert o_response_mesi(0) = MESI_S report "TEST 2 FAILED: Expected Shared (S)" severity error;
        assert o_bus_abort = '0' report "TEST 2 FAILED: Unexpected Abort" severity error;
        assert o_snoop_update_en(1) = '1' report "TEST 2 FAILED: Should update snoop state" severity error;
        
        -- Reset Inputs
        i_bus_cmd <= "00"; i_snoop_hit <= "000"; wait for CLK_PERIOD;


        report "------------------------------------------------" severity note;
        report "TEST 3: CRITICAL FLUSH TEST (Read Miss on Modified)" severity note;
        report "------------------------------------------------" severity note;
        -- CPU 0 Reads 0x3000. CPU 2 has it in Modified (M).
        -- We expect o_bus_abort to stay High for ~3 cycles (0, 1, 2)
        -- We expect o_snoop_update_en to be Low for cycles 0, 1 and High at 2.
        
        i_bus_source_id <= 0;
        i_bus_addr      <= x"3000";
        i_bus_cmd       <= CMD_BUS_RD;
        i_snoop_hit     <= "100"; -- Hit on CPU 2
        i_snoop_mesi    <= (0 => "11", 1 => "11", 2 => "00"); -- CPU 2 is M
        
        -- === CYCLE 0 (Start of Request) ===
        wait for 1 ns; -- Small delta to let combinatorial logic settle
        assert o_bus_abort = '1' report "TEST 3 (C0) FAILED: Abort not asserted immediately" severity error;
        assert o_snoop_update_en(2) = '0' report "TEST 3 (C0) FAILED: Update enabled too early!" severity error;
        
        wait for CLK_PERIOD - 1 ns; -- Finish Cycle 0

        -- === CYCLE 1 (Wait State 1) ===
        -- Counter should be 1 internaly. Abort must still be high. Update still low.
        wait for 1 ns;
        assert o_bus_abort = '1' report "TEST 3 (C1) FAILED: Abort dropped too early" severity error;
        assert o_snoop_update_en(2) = '0' report "TEST 3 (C1) FAILED: Update enabled too early!" severity error;
        
        wait for CLK_PERIOD - 1 ns;

        -- === CYCLE 2 (Wait State 2 / Action State) ===
        -- Counter should be 2. Abort still high (to hold write). Update goes High.
        wait for 1 ns;
        assert o_bus_abort = '1' report "TEST 3 (C2) FAILED: Abort dropped too early" severity error;
        
        -- THIS IS THE CRITICAL CHECK
        if o_snoop_update_en(2) = '1' then
            report "TEST 3 SUCCESS: Update enabled correctly after delay." severity note;
        else
            report "TEST 3 FAILED: Update Enable NOT asserted after 2 cycle delay" severity error;
        end if;
        
        assert o_snoop_new_state(2) = MESI_S report "TEST 3 FAILED: New state should be S" severity error;

        wait for CLK_PERIOD - 1 ns;
        
        -- End of Test
        i_bus_cmd <= "00"; i_snoop_hit <= "000";
        wait for CLK_PERIOD;
        assert o_bus_abort = '0' report "TEST 3 FAILED: Abort stuck high" severity error;

        report "------------------------------------------------" severity note;
        report "TEST 4: Write Miss (Invalidate)" severity note;
        report "------------------------------------------------" severity note;
        -- CPU 0 Writes 0x4000 (RDX). CPU 1 and 2 have Shared (S).
        i_bus_source_id <= 0;
        i_bus_addr      <= x"4000";
        i_bus_cmd       <= CMD_BUS_RDX;
        i_snoop_hit     <= "110"; -- Hit on 1 and 2
        i_snoop_mesi    <= (0 => "11", 1 => "10", 2 => "10");
        
        wait for CLK_PERIOD;
        
        assert o_snoop_update_en = "110" report "TEST 4 FAILED: Should invalidate both sharers" severity error;
        assert o_snoop_new_state(1) = MESI_I report "TEST 4 FAILED: State should be I" severity error;
        assert o_bus_abort = '0' report "TEST 4 FAILED: No abort needed for S->I" severity error;

        report "ALL TESTS COMPLETE";
        wait;
    end process;

end Behavioral;