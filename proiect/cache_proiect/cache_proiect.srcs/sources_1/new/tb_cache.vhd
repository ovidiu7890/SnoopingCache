library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_cache is
end tb_cache;

architecture Behavioral of tb_cache is

    -- Component Declaration
    component cache is
        Port ( 
            i_clk             : in std_logic;
            i_rst             : in std_logic;
            i_address_cpu     : in std_logic_vector(15 downto 0);
            i_write_data_cpu  : in std_logic_vector(7 downto 0);
            i_read            : in std_logic;
            i_write           : in std_logic;
            o_read_data_cpu   : out std_logic_vector(7 downto 0);
            o_hit             : out std_logic;
            
            i_address_cc      : in std_logic_vector(15 downto 0);
            i_data_request    : in std_logic;
            i_invalidate      : in std_logic; 
            
            i_snoop_update_en : in std_logic;
            i_snoop_new_state : in std_logic_vector(1 downto 0);
            o_snoop_hit       : out std_logic;

            i_mem_ready       : in std_logic;
            i_mem_data        : in std_logic_vector(31 downto 0);
            i_mesi_cc         : in std_logic_vector(1 downto 0);
            
            o_mem_request     : out std_logic;
            o_mem_address     : out std_logic_vector(15 downto 0);
            o_rwitm           : out std_logic;
            o_data_out        : out std_logic_vector(47 downto 0);
            o_writeback_en    : out std_logic;
            o_data_broadcast  : out std_logic_vector(31 downto 0);
            o_mesi_cache      : out std_logic_vector(1 downto 0);
            o_invalidate      : out std_logic
        );
    end component;

    -- Signals
    signal clk : std_logic := '0';
    signal rst : std_logic := '0';

    -- CPU Interface
    signal i_address_cpu     : std_logic_vector(15 downto 0) := (others => '0');
    signal i_write_data_cpu  : std_logic_vector(7 downto 0) := (others => '0');
    signal i_read, i_write   : std_logic := '0';
    signal o_read_data_cpu   : std_logic_vector(7 downto 0);
    signal o_hit             : std_logic;

    -- Snoop Interface
    signal i_address_cc      : std_logic_vector(15 downto 0) := (others => '0');
    signal i_data_request    : std_logic := '0';
    signal i_invalidate      : std_logic := '0';
    signal i_snoop_update_en : std_logic := '0';
    signal i_snoop_new_state : std_logic_vector(1 downto 0) := "11";
    signal o_snoop_hit       : std_logic;
    signal o_data_broadcast  : std_logic_vector(31 downto 0);
    signal o_mesi_cache      : std_logic_vector(1 downto 0);

    -- Memory Interface
    signal i_mem_ready       : std_logic := '0';
    signal i_mem_data        : std_logic_vector(31 downto 0) := (others => '0');
    signal i_mesi_cc         : std_logic_vector(1 downto 0) := "01"; -- Default E
    signal o_mem_request     : std_logic;
    signal o_mem_address     : std_logic_vector(15 downto 0);
    signal o_rwitm           : std_logic;
    signal o_data_out        : std_logic_vector(47 downto 0);
    signal o_writeback_en    : std_logic;
    signal o_invalidate_out  : std_logic;

    constant CLK_PERIOD : time := 10 ns;

begin

    uut: cache port map (
        i_clk => clk, i_rst => rst,
        i_address_cpu => i_address_cpu, i_write_data_cpu => i_write_data_cpu,
        i_read => i_read, i_write => i_write, o_read_data_cpu => o_read_data_cpu, o_hit => o_hit,
        i_address_cc => i_address_cc, i_data_request => i_data_request, i_invalidate => i_invalidate,
        i_snoop_update_en => i_snoop_update_en, i_snoop_new_state => i_snoop_new_state, o_snoop_hit => o_snoop_hit,
        i_mem_ready => i_mem_ready, i_mem_data => i_mem_data, i_mesi_cc => i_mesi_cc,
        o_mem_request => o_mem_request, o_mem_address => o_mem_address, o_rwitm => o_rwitm,
        o_data_out => o_data_out, o_writeback_en => o_writeback_en,
        o_data_broadcast => o_data_broadcast, o_mesi_cache => o_mesi_cache, o_invalidate => o_invalidate_out
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
        rst <= '1';
        wait for 20 ns;
        rst <= '0';
        wait for 10 ns;

        -- =========================================================
        -- TEST 1: READ MISS -> FILL -> CHECK DATA (Atomic Update)
        -- =========================================================
        report "TEST 1: Read Miss & Fill (Checking Atomic Update)" severity note;
        
        i_address_cpu <= x"1000"; -- Address 0x1000
        i_read <= '1';
        wait for CLK_PERIOD; -- Request goes out
        
        -- Simulate RAM Latency
        wait for CLK_PERIOD; 
        
        -- RAM Responds with Data 0xAABBCCDD
        -- Address 1000 (ends in 00) should read MSB (AA)
        i_mem_data <= x"AABBCCDD";
        i_mem_ready <= '1';
        i_mesi_cc   <= "01"; -- Exclusive
        
        wait for CLK_PERIOD; 
        i_mem_ready <= '0';
        i_read <= '0'; -- Clear CPU Request
        
        -- The CPU output should match RAM data IMMEDIATELY
        assert o_read_data_cpu = x"AA" 
            report "TEST 1 FAILED: Stale Data! Expected 0xAA, got " & integer'image(to_integer(unsigned(o_read_data_cpu))) severity error;

        if o_read_data_cpu = x"AA" then report "TEST 1 PASSED" severity note; end if;
        wait for 20 ns;

        -- =========================================================
        -- TEST 2: WRITE HIT -> MODIFY DATA
        -- =========================================================
        report "TEST 2: Write Hit (Modifying Data)" severity note;
        
        i_address_cpu    <= x"1000";
        i_write_data_cpu <= x"99"; -- Overwrite AA with 99
        i_write          <= '1';
        
        wait for CLK_PERIOD;
        i_write <= '0';
        
        -- Verify internal state by reading back
        i_read <= '1';
        wait for CLK_PERIOD;
        i_read <= '0';
        
        assert o_read_data_cpu = x"99" 
            report "TEST 2 FAILED: Write did not update cache! Got " & integer'image(to_integer(unsigned(o_read_data_cpu))) severity error;
            
        if o_read_data_cpu = x"99" then report "TEST 2 PASSED" severity note; end if;
        wait for 20 ns;

        -- =========================================================
        -- TEST 3: SNOOP BROADCAST (The Critical Flush Test)
        -- =========================================================
        report "TEST 3: Snoop Broadcast (Verifying Flush Data)" severity note;
        
        -- Another core asks for 0x1000
        i_address_cc   <= x"1000";
        -- i_data_request is NOT set initially to verify the "Always On" broadcast fix
        
        wait for 1 ns; -- Combinatorial Delay
        
        -- CHECK: Does o_data_broadcast have 0x99BBCCDD? (Tag matched, so data should be there)
        -- Byte 0 (MSB) was modified to 99. The rest (BBCCDD) remain from RAM.
        if o_data_broadcast = x"99BBCCDD" then
            report "TEST 3 (Part A) PASSED: Broadcast Data valid immediately on address match." severity note;
        else
            report "TEST 3 (Part A) FAILED: Broadcast Data Invalid/Zero! Expected x99BBCCDD, got " & integer'image(to_integer(unsigned(o_data_broadcast(31 downto 24)))) severity error;
        end if;
        
        -- Now enable request to check Hit flag
        i_data_request <= '1';
        wait for 1 ns;
        assert o_snoop_hit = '1' report "TEST 3 (Part B) FAILED: No Snoop Hit reported" severity error;
        
        i_address_cc <= x"0000"; i_data_request <= '0'; -- Clear
        wait for 20 ns;

        -- =========================================================
        -- TEST 4: EVICTION (LRU)
        -- =========================================================
        report "TEST 4: Eviction (Filling Cache to force Writeback)" severity note;
        
        -- We already have 0x1000 in Index 0 (Modified).
        -- We need to fill lines 1 to 15 with dummy reads to push 0x1000 to the bottom.
        
        for k in 1 to 15 loop
            i_address_cpu <= std_logic_vector(to_unsigned(4096 + k*4, 16)); -- 0x1004, 1008...
            i_read <= '1';
            wait for CLK_PERIOD;
            
            i_mem_ready <= '1'; i_mem_data <= x"FFFFFFFF"; i_mesi_cc <= "01";
            wait for CLK_PERIOD;
            i_mem_ready <= '0';
        end loop;
        i_read <= '0';
        
        report "Cache Full. Requesting 17th line to force eviction of 0x1000..." severity note;
        
        -- Request one more (Line 17)
        i_address_cpu <= x"5000";
        i_read <= '1';
        wait for CLK_PERIOD; -- This cycle detects MISS + EVICT NEEDED
        
        -- The Cache should immediately assert o_writeback_en because the victim (0x1000) is Modified
        wait for 1 ns;
        
        assert o_writeback_en = '1' report "TEST 4 FAILED: Writeback not enabled!" severity error;
        
        -- Check the data being evicted. It should be the Modified line (Tag + 00 + Data)
        -- 0x1000 tag is 0x0400. M state is 00. Data is 99BBCCDD.
        -- Expected: 0x0400 & 00 & 99BBCCDD
        
        if o_data_out(31 downto 0) = x"99BBCCDD" then
            report "TEST 4 PASSED: Correct dirty line evicted." severity note;
        else
             report "TEST 4 FAILED: Evicted data wrong. Expected x99BBCCDD" severity error;
        end if;

        wait;
    end process;

end Behavioral;