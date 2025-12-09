library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_System_Top is
end tb_System_Top;

architecture sim of tb_System_Top is

    signal clk : std_logic := '0';
    signal rst : std_logic := '0';

    -- CPU 0 Control Signals
    signal cmd0_en   : std_logic := '0';
    signal cmd0_rw   : std_logic := '0'; -- 0:Read, 1:Write
    signal cmd0_addr : std_logic_vector(15 downto 0) := (others => '0');
    signal cmd0_data : std_logic_vector(7 downto 0)  := (others => '0');
    signal sts0_done : std_logic;
    signal sts0_data : std_logic_vector(7 downto 0);

    -- CPU 1 Control Signals
    signal cmd1_en   : std_logic := '0';
    signal cmd1_rw   : std_logic := '0';
    signal cmd1_addr : std_logic_vector(15 downto 0) := (others => '0');
    signal cmd1_data : std_logic_vector(7 downto 0)  := (others => '0');
    signal sts1_done : std_logic;
    signal sts1_data : std_logic_vector(7 downto 0);

    -- CPU 2 Control Signals
    signal cmd2_en   : std_logic := '0';
    signal cmd2_rw   : std_logic := '0';
    signal cmd2_addr : std_logic_vector(15 downto 0) := (others => '0');
    signal cmd2_data : std_logic_vector(7 downto 0)  := (others => '0');
    signal sts2_done : std_logic;
    signal sts2_data : std_logic_vector(7 downto 0);

    -- Simulation Constants
    constant CLK_PERIOD : time := 10 ns;

begin

    -- ------------------------------------------------------------------
    -- 1. Instantiate the Full System
    -- ------------------------------------------------------------------
    DUT: entity work.top_module
        port map (
            clk => clk,
            rst => rst,
            
            -- CPU 0
            cmd0_en => cmd0_en, cmd0_rw => cmd0_rw, 
            cmd0_addr => cmd0_addr, cmd0_data => cmd0_data,
            sts0_done => sts0_done, sts0_data => sts0_data,
            
            -- CPU 1
            cmd1_en => cmd1_en, cmd1_rw => cmd1_rw, 
            cmd1_addr => cmd1_addr, cmd1_data => cmd1_data,
            sts1_done => sts1_done, sts1_data => sts1_data,

            -- CPU 2
            cmd2_en => cmd2_en, cmd2_rw => cmd2_rw, 
            cmd2_addr => cmd2_addr, cmd2_data => cmd2_data,
            sts2_done => sts2_done, sts2_data => sts2_data
        );

    -- ------------------------------------------------------------------
    -- 2. Clock Generation
    -- ------------------------------------------------------------------
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
    -- 3. Main Test Sequence
    -- ------------------------------------------------------------------
    stim_proc : process
    begin
        -- === RESET SYSTEM ===
        rst <= '1';
        wait for 50 ns;
        rst <= '0';
        wait for 20 ns;

        -- =================================================================
        -- SCENARIO 1: CPU 0 Reads Address 0x1000 (Cold Miss)
        -- Expect: RAM access, Cache 0 loads line.
        -- =================================================================
        report "SCENARIO 1: CPU 0 Read Miss 0x1000" severity note;
        
        cmd0_addr <= x"1000";
        cmd0_rw   <= '0'; -- Read
        cmd0_en   <= '1';
        wait for CLK_PERIOD;
        cmd0_en   <= '0';

        -- Wait for transaction done
        wait until sts0_done = '1';
        wait for 20 ns;


        -- =================================================================
        -- SCENARIO 2: CPU 1 Reads Same Address 0x1000
        -- Expect: Coherence Check. Cache 0 is snooped. Both become SHARED.
        -- =================================================================
        report "SCENARIO 2: CPU 1 Read 0x1000 (Shared)" severity note;
        
        cmd1_addr <= x"1000";
        cmd1_rw   <= '0'; -- Read
        cmd1_en   <= '1';
        wait for CLK_PERIOD;
        cmd1_en   <= '0';

        wait until sts1_done = '1';
        wait for 20 ns;

        
--        -- =================================================================
--        -- SCENARIO 3: CPU 2 Writes to 0x1000 (Write Miss / Invalidate)
--        -- Expect: Bus RdX (Read for Ownership). 
--        --         Cache 0 and Cache 1 must INVALIDATE their copies.
--        --         Cache 2 becomes MODIFIED.
--        -- =================================================================
--        report "SCENARIO 3: CPU 2 Write 0x1000 (Invalidate 0 & 1)" severity note;
        
--        cmd2_addr <= x"1000";
--        cmd2_data <= x"FF"; -- Writing Data 0xFF
--        cmd2_rw   <= '1';   -- Write
--        cmd2_en   <= '1';
--        wait for CLK_PERIOD;
--        cmd2_en   <= '0';

--        wait until sts2_done = '1';
--        wait for 20 ns;


--        -- =================================================================
--        -- SCENARIO 4: CPU 0 Reads 0x1000 Again
--        -- Expect: Cache 0 is currently Invalid. It issues a Read.
--        --         Cache 2 has Modified data. Cache 2 snoops and intervenes.
--        -- =================================================================
--        report "SCENARIO 4: CPU 0 Re-Read 0x1000 (Snoop Modified)" severity note;
        
--        cmd0_addr <= x"1000";
--        cmd0_rw   <= '0';
--        cmd0_en   <= '1';
--        wait for CLK_PERIOD;
--        cmd0_en   <= '0';

--        wait until sts0_done = '1';
        
--        -- =================================================================
--        -- SCENARIO 5: WRITE-BACK ON RWITM (Modified -> Flush -> Invalid)
--        -- Target Address: 0x2000
--        -- =================================================================
        
--        -- STEP A: CPU 1 Reads 0x2000 (Allocates, Exclusive)
--        report "SCENARIO 5A: CPU 1 Reads 0x2000 (Exclusive)" severity note;
--        cmd1_addr <= x"2000";
--        cmd1_rw   <= '0'; -- Read
--        cmd1_en   <= '1';
--        wait for CLK_PERIOD;
--        cmd1_en   <= '0';
--        wait until sts1_done = '1';
--        wait for 20 ns;

--        -- STEP B: CPU 1 Writes to 0x2000 (Becomes Modified)
--        report "SCENARIO 5B: CPU 1 Writes 0xAA to 0x2000 (Transitions to Modified)" severity note;
--        cmd1_data <= x"AA";
--        cmd1_rw   <= '1'; -- Write
--        cmd1_en   <= '1';
--        wait for CLK_PERIOD;
--        cmd1_en   <= '0';
--        wait until sts1_done = '1';
--        wait for 20 ns;
        
--        -- STEP C: CPU 2 Tries to WRITE to 0x2000 (Trigger RWITM & Flush)
--        report "SCENARIO 5C: CPU 2 Writes 0xBB to 0x2000 (Trigger RWITM & Flush)" severity note;
--        cmd2_addr <= x"2000";
--        cmd2_data <= x"BB";
--        cmd2_rw   <= '1'; -- Write
--        cmd2_en   <= '1';
--        wait for CLK_PERIOD;
--        cmd2_en   <= '0';

--        wait until sts2_done = '1';
--        wait for 20 ns;

--        -- =================================================================
--        -- VERIFICATION: CPU 0 Reads 0x2000
--        -- =================================================================
--        report "SCENARIO 5D: CPU 0 Reads 0x2000 (Verify Final Data 0xBB)" severity note;
        
--        cmd0_addr <= x"2000";
--        cmd0_rw   <= '0';
--        cmd0_en   <= '1';
--        wait for CLK_PERIOD;
--        cmd0_en   <= '0';
        
--        wait until sts0_done = '1';
        
--        -- Check Logic (FIXED: Using integer conversion for print compatibility)
--        if sts0_data /= x"BB" then
--            report "ERROR: Data Mismatch! Expected 0xBB (187), got " & integer'image(to_integer(unsigned(sts0_data)))
--            severity error;
--        else
--            report "SUCCESS: Data Match (0xBB)" severity note;
--        end if;

        report "Test Sequence Completed Successfully." severity note;
        wait;
        
    end process;

end architecture sim;