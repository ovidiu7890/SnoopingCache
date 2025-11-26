library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package LRU_Types is

    constant C_DEPTH : integer := 16;

    -- Data type used in the cache (can be changed later)
    subtype T_DATA is std_logic_vector(7 downto 0);

    -- Cache line array type
    type T_CACHE_LINES is array (0 to C_DEPTH - 1) of T_DATA;

end package LRU_Types;
