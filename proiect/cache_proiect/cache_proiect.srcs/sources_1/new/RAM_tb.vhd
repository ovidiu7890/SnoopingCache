library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity RAM_tb is
end RAM_tb;

architecture tb of RAM_tb is

    component RAM is
        Port (
            i_clk     : in  std_logic;
            i_address : in  std_logic_vector(15 downto 0);
            o_data    : out std_logic_vector(31 downto 0);
            i_data    : in  std_logic_vector(31 downto 0);
            i_read    : in  std_logic;
            i_write   : in  std_logic
        );
    end component;

    signal address : std_logic_vector(15 downto 0) := (others => '0');
    signal data_in : std_logic_vector(31 downto 0) := (others => '0');
    signal data_out : std_logic_vector(31 downto 0);
    signal read_sig : std_logic := '0';
    signal write_sig : std_logic := '0';
    signal clk: std_logic:= '0';
    constant CLK_PERIOD : time := 10 ns;
begin

    DUT: RAM
        port map (
            i_clk     => clk,
            i_address => address,
            o_data    => data_out,
            i_data    => data_in,
            i_read    => read_sig,
            i_write   => write_sig
        );
    clk_process : process
    begin
        while true loop
            clk <= '0';
            wait for CLK_PERIOD/2;
            clk <= '1';
            wait for CLK_PERIOD/2;
        end loop;
    end process;

    --tests
    stim_proc : process
    begin


        --write
        address <= x"0004";
        data_in <= x"12345678";
        write_sig <= '1';
        read_sig <= '0';
        wait for 10 ns;

        write_sig <= '0';

        --read
        read_sig <= '1';
        wait for 10 ns;


        --write
        address <= x"0008";
        data_in <= x"AABBCCDD";
        write_sig <= '1';
        read_sig <= '0';
        wait for 10 ns;

        write_sig <= '0';

        --write
        address <= x"000C";
        data_in <= x"DDBBFFAA";
        write_sig <= '1';
        wait for 10 ns;

        write_sig <= '0';

        --read
        address <= x"0008";
        read_sig <= '1';
        wait for 10 ns;


        --read
        address <= x"000C";
        wait for 10 ns;


        wait;

    end process;

end tb;
