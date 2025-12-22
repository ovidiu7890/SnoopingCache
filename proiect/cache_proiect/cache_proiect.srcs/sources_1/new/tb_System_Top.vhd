library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_System_Top is
end tb_System_Top;

architecture sim of tb_System_Top is

    signal clk : std_logic := '0';
    signal rst : std_logic := '0';

    -- Signals for CPU 0, 1, 2
    signal cmd0_en, cmd0_rw : std_logic := '0';
    signal cmd0_addr : std_logic_vector(15 downto 0) := (others => '0');
    signal cmd0_data, sts0_data : std_logic_vector(7 downto 0) := (others => '0');
    signal sts0_done : std_logic;

    signal cmd1_en, cmd1_rw : std_logic := '0';
    signal cmd1_addr : std_logic_vector(15 downto 0) := (others => '0');
    signal cmd1_data, sts1_data : std_logic_vector(7 downto 0) := (others => '0');
    signal sts1_done : std_logic;

    signal cmd2_en, cmd2_rw : std_logic := '0';
    signal cmd2_addr : std_logic_vector(15 downto 0) := (others => '0');
    signal cmd2_data, sts2_data : std_logic_vector(7 downto 0) := (others => '0');
    signal sts2_done : std_logic;

    constant CLK_PERIOD : time := 10 ns;

begin

    DUT: entity work.top_module
        port map (
            clk => clk, rst => rst,
            cmd0_en => cmd0_en, cmd0_rw => cmd0_rw, cmd0_addr => cmd0_addr, cmd0_data => cmd0_data,
            sts0_done => sts0_done, sts0_data => sts0_data,
            cmd1_en => cmd1_en, cmd1_rw => cmd1_rw, cmd1_addr => cmd1_addr, cmd1_data => cmd1_data,
            sts1_done => sts1_done, sts1_data => sts1_data,
            cmd2_en => cmd2_en, cmd2_rw => cmd2_rw, cmd2_addr => cmd2_addr, cmd2_data => cmd2_data,
            sts2_done => sts2_done, sts2_data => sts2_data
        );

    clk_process : process begin
        while true loop clk <= '0'; wait for CLK_PERIOD/2; clk <= '1'; wait for CLK_PERIOD/2; end loop;
    end process;

    stim_proc : process
    begin
        -- =========================================================
        -- INITIAL RESET
        -- =========================================================
        rst <= '1'; wait for 50 ns; rst <= '0'; wait for 20 ns;

        -- =========================================================
        -- TEST 1: LOCAL READ MISS -> BECOMES EXCLUSIVE (E)
        -- "No other copy in caches -> Value read, marked E"
        -- =========================================================
--        report "TEST 1: CPU 0 Read Miss 0x1000 (Expect E)" severity note;
--        cmd0_addr <= x"1000"; cmd0_rw <= '0'; cmd0_en <= '1';
--        wait for CLK_PERIOD; cmd0_en <= '0';
--        wait until sts0_done = '1'; wait for 20 ns;

--        -- =========================================================
--        -- TEST 2: LOCAL READ MISS (Remote E) -> BECOMES SHARED (S)
--        -- "One cache has E copy -> Snooping puts value, Both set to S"
--        -- =========================================================
--        report "TEST 2: CPU 1 Read 0x1000 (Snoop CPU 0, Both -> S)" severity note;
--        cmd1_addr <= x"1000"; cmd1_rw <= '0'; cmd1_en <= '1';
--        wait for CLK_PERIOD; cmd1_en <= '0';
--        wait until sts1_done = '1'; wait for 20 ns;

--        -- =========================================================
--        -- TEST 3: LOCAL READ HIT (Shared)
--        -- "Line in S -> Simply return value, No state change"
--        -- =========================================================
--        report "TEST 3: CPU 0 Read Hit 0x1000 (Remains S)" severity note;
--        cmd0_addr <= x"1000"; cmd0_rw <= '0'; cmd0_en <= '1';
--        wait for CLK_PERIOD; cmd0_en <= '0';
--        wait until sts0_done = '1'; wait for 20 ns;

--        -- =========================================================
--        -- TEST 4: LOCAL WRITE HIT (Shared) -> BECOMES MODIFIED (M)
--        -- "Processor broadcasts invalidate -> Others S->I, Local S->M"
--        -- =========================================================
--        report "TEST 4: CPU 1 Write 0x1000 (Inv CPU 0, CPU 1 -> M)" severity note;
--        cmd1_addr <= x"1000"; cmd1_data <= x"AA"; cmd1_rw <= '1'; cmd1_en <= '1';
--        wait for CLK_PERIOD; cmd1_en <= '0';
--        wait until sts1_done = '1'; wait for 20 ns;

--        -- =========================================================
--        -- TEST 5: LOCAL READ MISS (Remote M) -> BECOMES SHARED (S)
--        -- "One cache has M -> M flushes to RAM, M->S, Local -> S"
--        -- =========================================================
--        report "TEST 5: CPU 0 Read 0x1000 (Flush CPU 1, Both -> S)" severity note;
--        cmd0_addr <= x"1000"; cmd0_rw <= '0'; cmd0_en <= '1';
--        wait for CLK_PERIOD; cmd0_en <= '0';
--        wait until sts0_done = '1'; 
        
--        -- Verify Data Integrity (Should be 0xAA from Test 4)
--        assert sts0_data = x"AA" report "Error: Stale Data!" severity error;
--        wait for 20 ns;

--        -- =========================================================
--        -- TEST 6: LOCAL WRITE HIT (Exclusive) -> BECOMES MODIFIED (M)
--        -- "State E -> Update local, State E->M" (Silent Upgrade)
--        -- =========================================================
--        -- Step A: CPU 2 Reads new address 0x2000 (Gets E)
--        cmd2_addr <= x"2000"; cmd2_rw <= '0'; cmd2_en <= '1';
--        wait for CLK_PERIOD; cmd2_en <= '0';
--        wait until sts2_done = '1'; wait for 20 ns;

--        -- Step B: CPU 2 Writes 0x2000 (Silent E->M)
--        report "TEST 6: CPU 2 Write 0x2000 (E -> M Silent Upgrade)" severity note;
--        cmd2_addr <= x"2000"; cmd2_data <= x"BB"; cmd2_rw <= '1'; cmd2_en <= '1';
--        wait for CLK_PERIOD; cmd2_en <= '0';
--        wait until sts2_done = '1'; wait for 20 ns;

--        -- =========================================================
--        -- TEST 7: LOCAL WRITE MISS (Remote M) -> RWITM & FLUSH
--        -- "Another copy in M -> Source blocks, Writes back, Sets to I"
--        -- =========================================================
--        -- CPU 2 has 0x2000 in M (from Test 6). CPU 0 wants to Write.
--        report "TEST 7: CPU 0 Write 0x2000 (Flush CPU 2, CPU 2->I, CPU 0->M)" severity note;
--        cmd0_addr <= x"2000"; cmd0_data <= x"CC"; cmd0_rw <= '1'; cmd0_en <= '1';
--        wait for CLK_PERIOD; cmd0_en <= '0';
--        wait until sts0_done = '1'; wait for 20 ns;

--        -- =========================================================
--        -- TEST 8: VERIFY FINAL DATA IN RAM
--        -- =========================================================
--        -- CPU 0 should now have the latest data (0xCC) in M.
--        -- If we read from CPU 1, it should snoop CPU 0, flush 0xCC, and get 0xCC.
--        report "TEST 8: CPU 1 Read 0x2000 (Verify Data 0xCC)" severity note;
--        cmd1_addr <= x"2000"; cmd1_rw <= '0'; cmd1_en <= '1';
--        wait for CLK_PERIOD; cmd1_en <= '0';
--        wait until sts1_done = '1';

--        if sts1_data /= x"CC" then
--            report "ERROR: Data mismatch. Expected 0xCC" severity error;
--        else
--            report "SUCCESS: All MESI Transitions Verified." severity note;
--        end if;
        
        report "SCENARIO 6: Filling Cache 0 to trigger Eviction Write-Back" severity note;

        -- STEP A: Fill Cache 0 with 16 Modified Lines
        -- Addresses: 0x3000 to 0x300F
        -- Data:      0x10   to 0x1F
        for i in 0 to 15 loop
            cmd0_addr <= std_logic_vector(to_unsigned(12288 + i*4, 16)); -- 12288 is 0x3000
            cmd0_data <= std_logic_vector(to_unsigned(16 + i, 8));     -- Data 0x10 + i
            cmd0_rw   <= '1'; -- Write
            cmd0_en   <= '1';
            wait for CLK_PERIOD;
            cmd0_en   <= '0';
            wait until sts0_done = '1';
            wait for 10 ns; -- Small gap between transactions
        end loop;

        -- At this point:
        -- Cache 0 Index 0  (Newest) = 0x300F (Data 0x1F)
        -- ...
        -- Cache 0 Index 15 (Oldest) = 0x3000 (Data 0x10) -> THIS WILL BE EVICTED

        -- STEP B: Access a 17th Address to force Eviction
        report "SCENARIO 6B: Write to 0x4000 (Forces Eviction of 0x3000)" severity note;
        cmd0_addr <= x"4000";
        cmd0_data <= x"AA";
        cmd0_rw   <= '1';
        cmd0_en   <= '1';
        wait for CLK_PERIOD;
        cmd0_en   <= '0';
        
        -- This transaction takes longer because it does a WB then a Write
        wait until sts0_done = '1';
        wait for 20 ns;

        -- STEP C: Verify RAM Update using CPU 1
        -- CPU 1 reads the EVICTED address (0x3000). 
        -- It should get 0x10 (16) from RAM.
        report "SCENARIO 6C: CPU 1 Reads Evicted Address 0x3000" severity note;
        cmd1_addr <= x"3000";
        cmd1_rw   <= '0'; -- Read
        cmd1_en   <= '1';
        wait for CLK_PERIOD;
        cmd1_en   <= '0';
        
        wait until sts1_done = '1';

        if sts1_data /= x"10" then
             report "ERROR: Eviction Write-Back Failed! Expected 0x10, got " & integer'image(to_integer(unsigned(sts1_data))) severity error;
        else
             report "SUCCESS: Eviction Write-Back Verified. RAM has correct data." severity note;
        end if;

        wait;
    end process;

end architecture sim;