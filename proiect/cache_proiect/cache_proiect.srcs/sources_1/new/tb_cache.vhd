library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_cache is
end tb_cache;

architecture sim of tb_cache is

    -- ------------------------------------------------------------------
    -- Signals
    -- ------------------------------------------------------------------
    signal i_clk             : std_logic := '0';
    signal i_rst             : std_logic := '0';
    
    -- CPU Signals
    signal i_address_cpu     : std_logic_vector(15 downto 0) := (others => '0');
    signal i_write_data_cpu  : std_logic_vector(7 downto 0)  := (others => '0');
    signal i_read            : std_logic := '0';
    signal i_write           : std_logic := '0';
    signal o_read_data_cpu   : std_logic_vector(7 downto 0);
    signal o_hit             : std_logic;
    
    -- Controller / Snooping Signals (UPDATED)
    signal i_address_cc      : std_logic_vector(15 downto 0) := (others => '0');
    signal i_data_request    : std_logic := '0';  -- Snoop Enable
    signal i_invalidate      : std_logic := '0';
    signal i_snoop_update_en : std_logic := '0';  -- NEW
    signal i_snoop_new_state : std_logic_vector(1 downto 0) := "00"; -- NEW
    signal o_snoop_hit       : std_logic;         -- NEW
    signal o_data_broadcast  : std_logic_vector(31 downto 0);
    signal o_mesi_cache      : std_logic_vector(1 downto 0);
    signal o_invalidate      : std_logic;
    
    -- Memory Interface Signals
    signal i_mem_ready       : std_logic := '0';
    signal i_mem_data        : std_logic_vector(31 downto 0) := (others => '0');
    signal i_mesi_cc         : std_logic_vector(1 downto 0) := "10";
    signal o_mem_request     : std_logic;
    signal o_mem_address     : std_logic_vector(15 downto 0);
    signal o_rwitm           : std_logic;
    signal o_data_out        : std_logic_vector(47 downto 0);

    -- Simulation Constants
    constant CLK_PERIOD : time := 10 ns;
    
    -- MESI State Constants for readability
    constant MESI_M : std_logic_vector(1 downto 0) := "00";
    constant MESI_E : std_logic_vector(1 downto 0) := "01";
    constant MESI_S : std_logic_vector(1 downto 0) := "10";
    constant MESI_I : std_logic_vector(1 downto 0) := "11";

begin

    -- ------------------------------------------------------------------
    -- Instantiate the DUT
    -- ------------------------------------------------------------------
    DUT: entity work.cache
        port map (
            i_clk             => i_clk,
            i_rst             => i_rst,
            
            -- CPU
            i_address_cpu     => i_address_cpu,
            i_write_data_cpu  => i_write_data_cpu,
            i_read            => i_read,
            i_write           => i_write,
            o_read_data_cpu   => o_read_data_cpu,
            o_hit             => o_hit,
            
            -- Controller / Snoop
            i_address_cc      => i_address_cc,
            i_data_request    => i_data_request,
            i_invalidate      => i_invalidate,
            i_snoop_update_en => i_snoop_update_en, -- Connected
            i_snoop_new_state => i_snoop_new_state, -- Connected
            o_snoop_hit       => o_snoop_hit,       -- Connected
            
            o_data_broadcast  => o_data_broadcast,
            o_mesi_cache      => o_mesi_cache,
            o_invalidate      => o_invalidate,
            
            -- Memory
            i_mem_ready       => i_mem_ready,
            i_mem_data        => i_mem_data,
            i_mesi_cc         => i_mesi_cc,
            o_mem_request     => o_mem_request,
            o_mem_address     => o_mem_address,
            o_rwitm           => o_rwitm,
            o_data_out        => o_data_out
        );

    -- Clock Generation
    clk_process : process
    begin
        while true loop
            i_clk <= '0';
            wait for CLK_PERIOD/2;
            i_clk <= '1';
            wait for CLK_PERIOD/2;
        end loop;
    end process;

    -- ------------------------------------------------------------------
    -- Test Stimulus
    -- ------------------------------------------------------------------
    stim_proc : process
    begin
        -- Initial Reset
        i_rst <= '1';
        wait for 3*CLK_PERIOD;
        i_rst <= '0';
        wait for 2*CLK_PERIOD;
        
        -- =============================================================
        -- TEST 1: Read Miss (Allocating line at 0x1234)
        -- =============================================================
        report "TEST 1: CPU Read Miss 0x1234" severity note;
        i_address_cpu <= x"1234";
        i_read <= '1';
        wait for CLK_PERIOD;
        i_read <= '0';

        -- Wait for memory request
        if o_mem_request = '0' then
            wait until o_mem_request = '1';
        end if;
        wait for 2*CLK_PERIOD;

        -- Memory Response (Exclusive "01")
        i_mem_data  <= x"AABBCCDD";
        i_mesi_cc   <= MESI_E; 
        i_mem_ready <= '1';
        wait for CLK_PERIOD;
        i_mem_ready <= '0';
        wait for 3*CLK_PERIOD;

        
        -- =============================================================
        -- TEST 2: Write Miss (Allocating line at 0x5678)
        -- =============================================================
        report "TEST 2: CPU Write Miss 0x5678" severity note;
        i_address_cpu    <= x"5678";
        i_write_data_cpu <= x"FF";
        i_mesi_cc        <= MESI_S; -- Memory gives it as Shared initially
        i_write          <= '1';
        wait for CLK_PERIOD;
        i_write          <= '0';

        if o_mem_request = '0' then
            wait until o_mem_request = '1';
        end if;
        wait for 2*CLK_PERIOD;

        -- Memory Response
        i_mem_data  <= x"CCAABBDD";
        i_mem_ready <= '1';
        wait for CLK_PERIOD;
        i_mem_ready <= '0';
        wait for 3*CLK_PERIOD;

        
        -- =============================================================
        -- TEST 3: Read Hit (Read back 0x1234)
        -- =============================================================
        report "TEST 3: CPU Read Hit 0x1234" severity note;
        i_address_cpu <= x"1234";
        i_read <= '1';
        wait for CLK_PERIOD;
        i_read <= '0';
        wait for 3*CLK_PERIOD;
        
        
        -- =============================================================
        -- TEST 4: Write Hit (Modify 0x1234)
        -- =============================================================
        report "TEST 4: CPU Write Hit 0x1234 (Transition E -> M)" severity note;
        -- 0x1234 is currently Exclusive (from Test 1). Writing should make it Modified.
        i_address_cpu    <= x"1234";
        i_write_data_cpu <= x"BB";
        i_write          <= '1';
        wait for CLK_PERIOD;
        i_write          <= '0';
        wait for 3*CLK_PERIOD;
        
        
        -- =============================================================
        -- TEST 5: Snoop Hit (Controller checks 0x1234)
        -- =============================================================
        report "TEST 5: Controller Snoop Hit Check" severity note;
        -- Controller asks: "Do you have 0x1234?"
        i_address_cc   <= x"1234";
        i_data_request <= '1'; 
        wait for CLK_PERIOD;
        
        -- Verify o_snoop_hit is '1' here in waveform
        i_data_request <= '0'; 
        wait for 3*CLK_PERIOD;
        
        
        -- =============================================================
        -- TEST 6: Snoop Invalidate (Kill 0x5678)
        -- =============================================================
        report "TEST 6: Controller Invalidate 0x5678" severity note;
        -- Controller says: "Invalidate 0x5678" (Maybe another CPU wrote to it)
        i_address_cc   <= x"5678";
        i_data_request <= '1'; -- Must be high to find the line
        i_invalidate   <= '1'; 
        wait for CLK_PERIOD;
        
        i_invalidate   <= '0';
        i_data_request <= '0';
        wait for CLK_PERIOD;
        
        
        -- =============================================================
        -- TEST 7: Snoop State Update (Downgrade 0x1234 from M to S)
        -- =============================================================
        report "TEST 7: Controller State Update (M -> S)" severity note;
        -- 0x1234 is currently Modified (from Test 4).
        -- Scenario: Another CPU wants to READ. Controller tells us to go to SHARED.
        
        i_address_cc      <= x"1234";
        i_data_request    <= '1';      -- Find the line
        i_snoop_update_en <= '1';      -- Enable state change
        i_snoop_new_state <= MESI_S;   -- New State = Shared
        wait for CLK_PERIOD;
        
        i_snoop_update_en <= '0';
        i_data_request    <= '0';
        wait for CLK_PERIOD;
        
        -- Check Waveform: 0x1234 should now have MESI bits "10" (Shared)
        
        report "Simulation completed successfully." severity note;
        wait;
    end process;
    
end architecture sim;