library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_System_Top is
end tb_System_Top;

architecture sim of tb_System_Top is
    constant AUTO_RUN : boolean := FALSE; 

    signal clk : std_logic := '0';
    signal rst : std_logic := '0';

    signal btn_next_test : std_logic := '0';

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

    procedure wait_for_step(signal trig : in std_logic; enable : boolean) is
    begin
        if not enable then
            wait until rising_edge(trig);
        else
            wait for 50 ns;
        end if;
    end procedure;

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
        -- INITIAL RESET
        rst <= '1'; wait for 50 ns; rst <= '0'; wait for 20 ns;
      
        -- TEST 1: LOCAL READ MISS -> BECOMES EXCLUSIVE (E)
        cmd0_addr <= x"1000"; cmd0_rw <= '0'; cmd0_en <= '1';
        wait for CLK_PERIOD; cmd0_en <= '0';
        wait until sts0_done = '1'; 
        
        wait_for_step(btn_next_test, AUTO_RUN); 

        -- TEST 2: LOCAL READ MISS (Remote E) -> BECOMES SHARED (S)
        cmd1_addr <= x"1000"; cmd1_rw <= '0'; cmd1_en <= '1';
        wait for CLK_PERIOD; cmd1_en <= '0';
        wait until sts1_done = '1'; 
        
        wait_for_step(btn_next_test, AUTO_RUN);

        -- TEST 3: LOCAL READ HIT (Shared)
        cmd0_addr <= x"1000"; cmd0_rw <= '0'; cmd0_en <= '1';
        wait for CLK_PERIOD; cmd0_en <= '0';
        wait until sts0_done = '1'; 
        
        wait_for_step(btn_next_test, AUTO_RUN);

        -- TEST 4: LOCAL WRITE HIT (Shared) -> BECOMES MODIFIED (M)
        cmd1_addr <= x"1000"; cmd1_data <= x"AA"; cmd1_rw <= '1'; cmd1_en <= '1';
        wait for CLK_PERIOD; cmd1_en <= '0';
        wait until sts1_done = '1'; 
        
        wait_for_step(btn_next_test, AUTO_RUN);
        
        -- TEST 5: LOCAL READ MISS (Remote M) -> BECOMES SHARED (S)
        cmd0_addr <= x"1000"; cmd0_rw <= '0'; cmd0_en <= '1';
        wait for CLK_PERIOD; cmd0_en <= '0';
        wait until sts0_done = '1'; 
        
        
        wait_for_step(btn_next_test, AUTO_RUN); 
        
        -- TEST 6: LOCAL WRITE HIT (Exclusive) -> BECOMES MODIFIED (M)
        -- Step A: CPU 2 Reads new address 0x2000 (Gets E)
        
        cmd2_addr <= x"2000"; cmd2_rw <= '0'; cmd2_en <= '1';
        wait for CLK_PERIOD; cmd2_en <= '0';
        wait until sts2_done = '1'; wait for 20 ns;

        -- Step B: CPU 2 Writes 0x2000 (Silent E->M)
        
        cmd2_addr <= x"2000"; cmd2_data <= x"BB"; cmd2_rw <= '1'; cmd2_en <= '1';
        wait for CLK_PERIOD; cmd2_en <= '0';
        wait until sts2_done = '1'; 
        
        wait_for_step(btn_next_test, AUTO_RUN);
        
        -- TEST 7: LOCAL WRITE MISS (Remote M) -> RWITM & FLUSH
        
        cmd0_addr <= x"2000"; cmd0_data <= x"CC"; cmd0_rw <= '1'; cmd0_en <= '1';
        wait for CLK_PERIOD; cmd0_en <= '0';
        wait until sts0_done = '1'; 
        
        wait_for_step(btn_next_test, AUTO_RUN); 
        
        -- TEST 8: VERIFY FINAL DATA IN RAM
        
        cmd1_addr <= x"2000"; cmd1_rw <= '0'; cmd1_en <= '1';
        wait for CLK_PERIOD; cmd1_en <= '0';
        wait until sts1_done = '1';
        
        wait_for_step(btn_next_test, AUTO_RUN); 
        
        -- TEST 9: RAM INTEGRITY & EVICTION
        
        
        -- Reset to clear state for Eviction test
        rst <= '1'; wait for 50 ns; rst <= '0'; wait for 20 ns;

        -- STEP A: Fill Cache 0 with 16 Modified Lines
        for i in 0 to 15 loop
            cmd0_addr <= std_logic_vector(to_unsigned(16 + i*4, 16)); -- 12288 is 0x3000
            cmd0_data <= std_logic_vector(to_unsigned(16 + i, 8));     -- Data 0x10 + i
            cmd0_rw   <= '1'; -- Write
            cmd0_en   <= '1';
            wait for CLK_PERIOD;
            cmd0_en   <= '0';
            wait until sts0_done = '1';
            wait for 20 ns; 
        end loop;

        report "Cache Full. Triggering Eviction..." severity note;
        wait_for_step(btn_next_test, AUTO_RUN);

        -- STEP B: Access a 17th Address (0x0050) to force Eviction of Index 0 (0x3000)
        report "TEST 9B: Write to 0x0050 (Forces Eviction of 0x0010/0x3000)" severity note;
        cmd0_addr <= x"0050";
        cmd0_data <= x"AA";
        cmd0_rw   <= '1';
        cmd0_en   <= '1';
        wait for CLK_PERIOD;
        cmd0_en   <= '0';
        
        wait until sts0_done = '1';
        
        -- STEP C: Verify RAM Update using CPU 1
        
        cmd1_addr <= std_logic_vector(to_unsigned(16, 16));
        cmd1_rw   <= '0'; 
        cmd1_en   <= '1';
        wait for CLK_PERIOD;
        cmd1_en   <= '0';
        wait until sts1_done = '1';

        
        wait;
    end process;

end architecture sim;