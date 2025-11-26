library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_cache is
end tb_cache;

architecture sim of tb_cache is

    -- DUT signals
    signal i_clk            : std_logic := '0';
    signal i_rst            : std_logic := '0';
    signal i_address_cpu    : std_logic_vector(15 downto 0) := (others => '0');
    signal i_write_data_cpu : std_logic_vector(7 downto 0)  := (others => '0');
    signal i_read           : std_logic := '0';
    signal i_write          : std_logic := '0';
    signal i_rwitm          : std_logic := '0';
    signal i_invalidate     : std_logic := '0';
    signal i_address_cc     : std_logic_vector(15 downto 0):=(others => '0');
    signal i_mesi_cc        : std_logic_vector(1 downto 0) := "10";
    signal i_mem_ready      : std_logic := '0';
    signal i_mem_data       : std_logic_vector(31 downto 0) := (others => '0');
    signal i_data_request   : std_logic:= '0';
    signal o_invalidate     : std_logic ;
    signal o_data_out       : std_logic_vector(47 downto 0);
    signal o_data_broadcast : std_logic_vector(31 downto 0);
    signal o_write_back     : std_logic;
    signal o_mesi_cache     : std_logic_vector(1 downto 0);
    signal o_address_brd    : std_logic_vector(15 downto 0);
    signal o_read_data_cpu  : std_logic_vector(7 downto 0);
    signal o_mem_request    : std_logic;
    signal o_mem_address    : std_logic_vector(15 downto 0);
    signal o_hit            : std_logic;

    constant CLK_PERIOD : time := 10 ns;

begin

    ------------------------------------------------------------------
    -- Instantiate the DUT
    ------------------------------------------------------------------
    DUT: entity work.cache
        port map (
            i_clk           => i_clk,
            i_rst           => i_rst,
            i_address_cpu   => i_address_cpu,
            i_write_data_cpu=> i_write_data_cpu,
            i_read          => i_read,
            i_write         => i_write,
            i_address_cc    => i_address_cc,
            i_invalidate    => i_invalidate,
            i_mesi_cc       => i_mesi_cc,
            i_mem_ready     => i_mem_ready,
            i_mem_data      => i_mem_data,
            i_data_request  => i_data_request,
            o_rwitm         => i_rwitm,
            o_invalidate    => o_invalidate,
            o_data_broadcast=> o_data_broadcast,
            o_data_out      => o_data_out,
            o_mesi_cache    => o_mesi_cache,
            o_read_data_cpu => o_read_data_cpu,
            o_mem_request   => o_mem_request,
            o_mem_address   => o_mem_address,
            o_hit           => o_hit
        );

    clk_process : process
    begin
        while true loop
            i_clk <= '0';
            wait for CLK_PERIOD/2;
            i_clk <= '1';
            wait for CLK_PERIOD/2;
        end loop;
    end process;

    -- Tests
    stim_proc : process
    begin
        -- reset
        i_rst <= '1';
        wait for 3*CLK_PERIOD;
        i_rst <= '0';
        wait for 2*CLK_PERIOD;
        
        --1
        i_address_cpu <= x"1234";
        i_read <= '1';
        wait for CLK_PERIOD;
        i_read <= '0';

        -- Memory should respond after some delay
        wait until rising_edge(i_clk) and o_mem_request = '0';
        wait for 2*CLK_PERIOD;

        -- Memory sends data back
        i_mem_data  <= x"AABBCCDD";
        i_mesi_cc <= "00";
        i_mem_ready <= '1';
        wait for CLK_PERIOD;
        i_mem_ready <= '0';
        wait for 3*CLK_PERIOD;

        
        --2
        i_mesi_cc <= "10";
        i_address_cpu    <= x"5678";
        i_write_data_cpu <= x"FF";
        i_write          <= '1';
        wait for CLK_PERIOD;
        i_write          <= '0';

        wait until rising_edge(i_clk) and o_mem_request = '0';
        wait for 2*CLK_PERIOD;

        -- Memory responds
        i_mem_data  <= x"CCAABBDD";
        
        i_mem_ready <= '1';
        wait for CLK_PERIOD;
        i_mem_ready <= '0';
        wait for 3*CLK_PERIOD;

        
        --3
    
    
        i_address_cpu <= x"1234";
        i_read <= '1';
        wait for CLK_PERIOD;
        i_read <= '0';
        
        wait for 3*CLK_PERIOD;
        
        --4
        
        i_address_cpu    <= x"1234";
        i_write_data_cpu <= x"BB";
        i_write          <= '1';
        wait for CLK_PERIOD;
        i_write          <= '0';
        wait for CLK_PERIOD;
        
    
        wait for 3*CLK_PERIOD;
        
        --5
        
        i_address_cc    <= x"1234";
        
        i_data_request  <= '1'; 
        wait for CLK_PERIOD;
        i_data_request  <= '0'; 

        
        wait for 3*CLK_PERIOD;
        
        --6
        i_address_cc    <= x"1234";
        
        i_invalidate  <= '1'; 
        wait for CLK_PERIOD;
        i_invalidate  <= '0'; 

        wait for CLK_PERIOD;
        
        report "Simulation completed successfully." severity note;
        wait;
    end process;
    
end architecture sim;
