library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
entity data_bus is
    Port (address: in std_logic_vector(15 downto 0);
          data_out: in std_logic_vector(31 downto 0);--data that is replaced in cache
          data_in: out std_logic_vector(31 downto 0);--data that is placed in the cache
          read_write_in: in std_logic;
          read_write_out: out std_logic;
          address_ram: out std_logic_vector(15 downto 0);
          data_out_ram: out std_logic_vector(31 downto 0);
          data_in_ram: in std_logic_vector(31 downto 0));
end data_bus;

architecture Behavioral of data_bus is

begin


end Behavioral;
