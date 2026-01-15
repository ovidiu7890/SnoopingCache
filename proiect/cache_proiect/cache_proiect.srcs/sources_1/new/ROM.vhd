library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ROM is
    Port (
        i_step        : in  integer range 0 to 31;
        o_cpu_id      : out integer range 0 to 2;
        o_addr        : out std_logic_vector(15 downto 0);
        o_rw          : out std_logic; -- 0: Read, 1: Write
        o_data_in     : out std_logic_vector(7 downto 0);
        o_expected    : out std_logic_vector(7 downto 0);
        o_check_en    : out std_logic -- 1: Check Result, 0: Ignore
    );
end ROM;

architecture Behavioral of ROM is
begin
    process(i_step)
        -- Helper variable to calculate addresses for the loop
        variable v_offset : integer;
    begin
        -- Default Outputs
        o_cpu_id   <= 0;
        o_addr     <= (others => '0');
        o_rw       <= '0';
        o_data_in  <= (others => '0');
        o_expected <= (others => '0');
        o_check_en <= '0';

        case i_step is
            when 0 => -- Cold Miss
                o_cpu_id <= 0; o_addr <= x"1000"; o_rw <= '0';

            when 1 => -- Snoop Share
                o_cpu_id <= 1; o_addr <= x"1000"; o_rw <= '0';

            when 2 => -- Upgrade to Modified
                o_cpu_id <= 1; o_addr <= x"1000"; o_rw <= '1'; o_data_in <= x"AA";

            when 3 => -- Snoop Flush Check
                o_cpu_id <= 0; o_addr <= x"1000"; o_rw <= '0'; o_expected <= x"AA"; o_check_en <= '1';

            when 4 => -- Write Invalidate
                o_cpu_id <= 2; o_addr <= x"1000"; o_rw <= '1'; o_data_in <= x"BB";

            when 5 => -- Verify Invalidation
                o_cpu_id <= 1; o_addr <= x"1000"; o_rw <= '0'; o_expected <= x"BB"; o_check_en <= '1';

            when 6 to 21 => 
                v_offset := i_step - 6; -- 0 to 15
                
                o_cpu_id  <= 0; 
                -- Generate Address: 0x3000 + (offset * 4)
                o_addr    <= std_logic_vector(to_unsigned(12288 + (v_offset * 4), 16)); 
                -- Generate Data: 0x10 + offset
                o_data_in <= std_logic_vector(to_unsigned(16 + v_offset, 8)); 
                o_rw      <= '1'; -- Write

            when 22 =>
                -- Cache is full. 0x3000 (from Step 6) is at the bottom.
                -- Writing to new address 0x4000 forces 0x3000 to RAM.
                o_cpu_id <= 0; o_addr <= x"4000"; o_rw <= '1'; o_data_in <= x"FF";

            when 23 =>
                -- CPU 2 reads 0x3000. It must come from RAM (0x10).
                o_cpu_id <= 2; o_addr <= x"3000"; o_rw <= '0'; 
                o_expected <= x"10"; o_check_en <= '1';

            when others =>
                null; 
        end case;
    end process;
end Behavioral;