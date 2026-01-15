library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity RAM_tb is
end RAM_tb;

architecture Behavioral of RAM_tb is

    -- Component Declaration for RAM
    component RAM is
        Port (
            i_clk     : in std_logic;
            i_address : in std_logic_vector(15 downto 0);
            i_data    : in std_logic_vector(31 downto 0);
            i_write   : in std_logic;
            i_read    : in std_logic;
            o_data    : out std_logic_vector(31 downto 0)
        );
    end component;

    -- Signals
    signal clk       : std_logic := '0';
    signal r_addr    : std_logic_vector(15 downto 0) := (others => '0');
    signal r_wdata   : std_logic_vector(31 downto 0) := (others => '0');
    signal r_write   : std_logic := '0';
    signal r_read    : std_logic := '0';
    signal w_rdata   : std_logic_vector(31 downto 0);

    -- Clock Period
    constant CLK_PERIOD : time := 10 ns;

begin

    -- Instantiate the Unit Under Test (UUT)
    uut: RAM port map (
        i_clk     => clk,
        i_address => r_addr,
        i_data    => r_wdata,
        i_write   => r_write,
        i_read    => r_read,
        o_data    => w_rdata
    );

    -- Clock Process
    clk_process : process
    begin
        clk <= '0'; wait for CLK_PERIOD/2;
        clk <= '1'; wait for CLK_PERIOD/2;
    end process;

    -- Test Stimulus
    stim_proc: process
    begin
        wait for 100 ns; -- Global Reset Wait
        
        report "==========================================================" severity note;
        report "STARTING RAM DIAGNOSTIC TEST" severity note;
        report "==========================================================" severity note;

        -- -----------------------------------------------------------
        -- TEST 1: ADDRESSING MODE CHECK (Byte vs Word)
        -- -----------------------------------------------------------
        report "TEST 1: Checking Addressing Mode..." severity note;
        
        -- Step A: Write to Address 0x0000 (Base)
        r_addr  <= x"0000";
        r_wdata <= x"AAAAAAAA"; -- Pattern A
        r_write <= '1';
        wait for CLK_PERIOD;
        r_write <= '0';
        
        -- Step B: Write to Address 0x0004 (Next 32-bit Word)
        r_addr  <= x"0004";
        r_wdata <= x"BBBBBBBB"; -- Pattern B
        r_write <= '1';
        wait for CLK_PERIOD;
        r_write <= '0';

        wait for 20 ns;

        -- Step C: Read Back 0x0000 (Should be A)
        r_addr <= x"0000"; r_read <= '1'; wait for CLK_PERIOD;
        if w_rdata = x"AAAAAAAA" then
            report "  [PASS] Read 0x0000 -> Got 0xAAAAAAAA (Correct)" severity note;
        else
            report "  [FAIL] Read 0x0000 -> Got " & integer'image(to_integer(unsigned(w_rdata))) severity error;
        end if;

        -- Step D: Read Back 0x0001 (The "Byte Offset" Check)
        -- IF your RAM is fixed (14 downto 2), this accesses Index 0 (Data A).
        -- IF your RAM is original (14 downto 0), this accesses Index 1 (Empty/Zero).
        r_addr <= x"0001"; r_read <= '1'; wait for CLK_PERIOD;
        
        if w_rdata = x"AAAAAAAA" then
            report "  [INFO] RAM IS WORD ALIGNED (Correct). Address 0x0001 returns Data at 0x0000." severity note;
        elsif w_rdata = x"00000000" then
            report "  [ERROR] RAM IS BYTE INDEXED (Incorrect). Address 0x0001 is treated as a different index than 0x0000." severity error;
            report "          FIX: Change RAM.vhd line to: mem(to_integer(unsigned(i_address(14 downto 2))))" severity failure;
        else
            report "  [INFO] Read 0x0001 -> Got unexpected data." severity note;
        end if;


        -- -----------------------------------------------------------
        -- TEST 2: SIMULATING THE "FLUSH" TIMING (The Race Condition)
        -- -----------------------------------------------------------
        report "TEST 2: Simulating Cache Flush Pulse..." severity note;
        
        -- In your system, Abort (Write) happens while Data is put on bus.
        -- We verify if a single-cycle write pulse captures the data correctly.
        
        r_addr  <= x"5000";
        r_wdata <= x"DEADBEEF";
        
        -- 1. Setup Data and Address
        wait for 10 ns; 
        
        -- 2. Pulse Write Enable for exactly 1 Clock Cycle
        r_write <= '1';
        wait for CLK_PERIOD; 
        r_write <= '0';
        
        -- 3. Clear Data Bus immediately (Simulating bus going to Z or 0)
        r_wdata <= x"00000000"; 
        
        wait for 20 ns;
        
        -- 4. Read Verification
        r_addr <= x"5000"; r_read <= '1'; wait for CLK_PERIOD;
        
        if w_rdata = x"DEADBEEF" then
             report "  [PASS] Flush Write Successful. RAM latched data correctly in 1 cycle." severity note;
        else
             report "  [FAIL] Flush Write Failed! Read " & integer'image(to_integer(unsigned(w_rdata))) & ". RAM missed the data window." severity error;
        end if;

        report "==========================================================" severity note;
        report "TEST COMPLETE" severity note;
        wait;
    end process;

end Behavioral;