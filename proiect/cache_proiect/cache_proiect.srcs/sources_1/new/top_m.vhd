library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top_m is
    Port (
        clk : in std_logic;
        btnC : in std_logic; -- Step
        btnU : in std_logic; -- Reset
        led  : out std_logic_vector(15 downto 0)
    );
end top_m;

architecture Behavioral of top_m is

    -- Signals
    signal rst, step_btn : std_logic;
    signal step_pulsed   : std_logic;
    signal step_prev     : std_logic := '0';
    
    signal s_rom_step    : integer range 0 to 31 := 0;
    
    -- Instruction Signals
    signal s_cpu_id      : integer range 0 to 2;
    signal s_addr        : std_logic_vector(15 downto 0);
    signal s_rw          : std_logic;
    signal s_data_in     : std_logic_vector(7 downto 0);
    signal s_expected    : std_logic_vector(7 downto 0);
    signal s_check_en    : std_logic;
    
    -- System Connections
    signal cmd_en   : std_logic_vector(2 downto 0);
    signal cmd_rw   : std_logic_vector(2 downto 0);
    signal sts_done : std_logic_vector(2 downto 0);
    signal sts_data_0, sts_data_1, sts_data_2 : std_logic_vector(7 downto 0);
    
    -- State Machine
    type t_state is (IDLE, EXECUTE, WAIT_DONE, CHECK);
    signal r_state : t_state := IDLE;
    
    signal r_error_flag : std_logic := '0';
    signal r_last_read  : std_logic_vector(7 downto 0) := (others => '0');

begin

    -- 1. Debounce Inputs
    DB_Step: entity work.debouncer port map(clk, btnC, step_btn);
    DB_Rst:  entity work.debouncer port map(clk, btnU, rst);

    -- Edge Detector for Step Button
    process(clk) begin
        if rising_edge(clk) then
            step_prev <= step_btn;
            if step_btn = '1' and step_prev = '0' then step_pulsed <= '1'; else step_pulsed <= '0'; end if;
        end if;
    end process;

    -- 2. Instruction ROM
    ROM: entity work.ROM
    port map (
        i_step => s_rom_step, o_cpu_id => s_cpu_id, o_addr => s_addr, 
        o_rw => s_rw, o_data_in => s_data_in, o_expected => s_expected, o_check_en => s_check_en
    );

    -- 3. DUT Instance (Top Module)
    -- Mapping dynamic signals based on CPU ID is tricky in VHDL '93 without arrays in ports.
    -- We map them to internal signals and drive them in the process below.
    DUT: entity work.top_module
    port map (
        clk => clk, rst => rst,
        cmd0_en => cmd_en(0), cmd0_rw => cmd_rw(0), cmd0_addr => s_addr, cmd0_data => s_data_in, sts0_done => sts_done(0), sts0_data => sts_data_0,
        cmd1_en => cmd_en(1), cmd1_rw => cmd_rw(1), cmd1_addr => s_addr, cmd1_data => s_data_in, sts1_done => sts_done(1), sts1_data => sts_data_1,
        cmd2_en => cmd_en(2), cmd2_rw => cmd_rw(2), cmd2_addr => s_addr, cmd2_data => s_data_in, sts2_done => sts_done(2), sts2_data => sts_data_2
    );

    -- 4. Main Test Controller
    process(clk, rst)
    begin
        if rst = '1' then
            r_state <= IDLE;
            s_rom_step <= 0;
            cmd_en <= "000";
            r_error_flag <= '0';
            
        elsif rising_edge(clk) then
            case r_state is
                when IDLE =>
                    cmd_en <= "000";
                    if step_pulsed = '1' then
                        r_state <= EXECUTE;
                    end if;
                    
                when EXECUTE =>
                    -- Activate only the selected CPU
                    if s_cpu_id = 0 then cmd_en <= "001"; cmd_rw <= "00" & s_rw;
                    elsif s_cpu_id = 1 then cmd_en <= "010"; cmd_rw <= "0" & s_rw & "0";
                    else cmd_en <= "100"; cmd_rw <= s_rw & "00";
                    end if;
                    r_state <= WAIT_DONE;
                    
                when WAIT_DONE =>
                    cmd_en <= "000"; -- Pulse enable for 1 cycle is usually enough, or wait for handshake
                    
                    -- Check if the selected CPU is done
                    if (s_cpu_id = 0 and sts_done(0) = '1') or
                       (s_cpu_id = 1 and sts_done(1) = '1') or
                       (s_cpu_id = 2 and sts_done(2) = '1') then
                       
                        -- Capture Data
                        if s_cpu_id = 0 then r_last_read <= sts_data_0;
                        elsif s_cpu_id = 1 then r_last_read <= sts_data_1;
                        else r_last_read <= sts_data_2;
                        end if;
                        
                        r_state <= CHECK;
                    end if;
                    
                when CHECK =>
                    -- Verify result if Check Enabled
                    if s_check_en = '1' then
                        if r_last_read /= s_expected then
                            r_error_flag <= '1'; -- ERROR!
                        else
                            r_error_flag <= '0';
                        end if;
                    end if;
                    
                    -- Prepare for next step
                    if s_rom_step < 15 then
                        s_rom_step <= s_rom_step + 1;
                    end if;
                    r_state <= IDLE;
            end case;
        end if;
    end process;

    -- 5. LED Output Mappings
    led(4 downto 0)   <= std_logic_vector(to_unsigned(s_rom_step, 5)); -- Binary Counter of Step
    led(12 downto 5)  <= r_last_read; -- The Data we read
    led(15)           <= r_error_flag; -- RED LIGHT on Error

end Behavioral;