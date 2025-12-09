library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

package Cache_Types is
    -- Define the array types here so everyone (Controller, Top, Testbench) can see them
    type t_mesi_array is array (0 to 2) of std_logic_vector(1 downto 0); 
    type t_addr_array is array(0 to 2) of std_logic_vector(15 downto 0);
    type t_data8_array is array(0 to 2) of std_logic_vector(7 downto 0);
    type t_data32_array is array(0 to 2) of std_logic_vector(31 downto 0);
    type t_bit_array is array(0 to 2) of std_logic;
    type t_evict_array is array(0 to 2) of std_logic_vector(47 downto 0);
end package Cache_Types;