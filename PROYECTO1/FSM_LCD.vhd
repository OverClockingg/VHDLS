library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.lcd_pkg.all;

entity FSM_LCD is
    generic( 
        CLK_FREQ : integer := 50_000_000 
    );
    port(
        clk, rst : in std_logic;
        start    : in std_logic;
        msg_id   : in std_logic_vector(3 downto 0);
        offset   : in integer range 0 to 31;
        LCD_RS   : out std_logic;
        LCD_E    : out std_logic;
        LCD_D    : out std_logic_vector(3 downto 0);
        busy     : out std_logic;
        done     : out std_logic
    );
end FSM_LCD;

architecture RTL of FSM_LCD is

    type t_state is (
        ST_IDLE, ST_CLEAR, ST_FETCH,
        ST_SETUP_HIGH, ST_PULSE_HIGH, ST_HOLD_HIGH, 
        ST_SETUP_LOW,  ST_PULSE_LOW,  ST_HOLD_LOW,
        ST_WAIT, ST_NEXT, ST_DONE
    );

    signal state       : t_state := ST_IDLE;
    signal r_data      : std_logic_vector(7 downto 0) := (others => '0');
    signal r_index     : integer range 0 to 31 := 0;
    signal r_msg_id    : std_logic_vector(3 downto 0) := (others => '0'); 
    signal lcd_rs_reg  : std_logic := '0';
    signal after_clear : std_logic := '0';

    constant CYCLES_1US  : integer := CLK_FREQ / 1_000_000;
    constant CYCLES_40US : integer := CLK_FREQ / 25_000;
    constant CYCLES_2MS  : integer := CLK_FREQ / 500;

    signal timer      : integer range 0 to CYCLES_2MS := 0;
    signal wait_limit : integer range 0 to CYCLES_2MS := 0;

begin

    LCD_RS <= lcd_rs_reg;

    process(clk, rst)
    begin
        if rst = '1' then
            state       <= ST_IDLE;
            LCD_E       <= '0';
            LCD_D       <= (others => '0');
            lcd_rs_reg  <= '0';
            busy        <= '0';
            done        <= '0';
            r_index     <= 0;
            after_clear <= '0';
            timer       <= 0;

        elsif rising_edge(clk) then
            done <= '0';

            case state is

                when ST_IDLE =>
                    busy <= '0';
                    LCD_E <= '0';
                    r_index <= 0;
                    after_clear <= '0';
                    if start = '1' then
                        busy <= '1';
                        r_msg_id <= msg_id; 
                        state <= ST_CLEAR;
                    end if;

                when ST_CLEAR =>
                    lcd_rs_reg <= '0'; 
                    r_data <= x"80"; -- Dirección base renglón 1
                    wait_limit <= CYCLES_40US; 
                    state <= ST_SETUP_HIGH;

                when ST_FETCH =>
                    lcd_rs_reg <= '1'; 
                    r_data <= get_lcd_char(r_msg_id, (r_index + offset) mod 32);
                    wait_limit <= CYCLES_40US;
                    state <= ST_SETUP_HIGH;

                -- --- NIBBLE ALTO: DATA SETUP -> PULSE -> HOLD ---
                when ST_SETUP_HIGH =>
                    LCD_D <= r_data(7 downto 4);
                    LCD_E <= '0';
                    if timer < CYCLES_1US then
                        timer <= timer + 1;
                    else
                        timer <= 0;
                        state <= ST_PULSE_HIGH;
                    end if;

                when ST_PULSE_HIGH =>
                    LCD_E <= '1';
                    if timer < CYCLES_1US then
                        timer <= timer + 1;
                    else
                        timer <= 0;
                        state <= ST_HOLD_HIGH;
                    end if;

                when ST_HOLD_HIGH =>
                    LCD_E <= '0';
                    if timer < CYCLES_1US then
                        timer <= timer + 1;
                    else
                        timer <= 0;
                        state <= ST_SETUP_LOW;
                    end if;

                -- --- NIBBLE BAJO: DATA SETUP -> PULSE -> HOLD ---
                when ST_SETUP_LOW =>
                    LCD_D <= r_data(3 downto 0);
                    LCD_E <= '0';
                    if timer < CYCLES_1US then
                        timer <= timer + 1;
                    else
                        timer <= 0;
                        state <= ST_PULSE_LOW;
                    end if;

                when ST_PULSE_LOW =>
                    LCD_E <= '1';
                    if timer < CYCLES_1US then
                        timer <= timer + 1;
                    else
                        timer <= 0;
                        state <= ST_HOLD_LOW;
                    end if;

                when ST_HOLD_LOW =>
                    LCD_E <= '0';
                    if timer < CYCLES_1US then
                        timer <= timer + 1;
                    else
                        timer <= 0;
                        state <= ST_WAIT;
                    end if;

                when ST_WAIT =>
                    if timer < wait_limit then
                        timer <= timer + 1;
                    else
                        timer <= 0;
                        state <= ST_NEXT;
                    end if;

                when ST_NEXT =>
                    if after_clear = '0' then
                        after_clear <= '1';
                        lcd_rs_reg  <= '0'; 
                        if r_msg_id = "1110" then 
                            r_data <= x"C0"; -- Salto a Renglón 2
                        else 
                            r_data <= x"80"; -- Forzar Renglón 1
                        end if;
                        wait_limit <= CYCLES_40US;
                        state <= ST_SETUP_HIGH; 
                    elsif (r_index >= 15) then 
                        state <= ST_DONE;
                    else
                        r_index <= r_index + 1;
                        state   <= ST_FETCH;
                    end if;

                when ST_DONE =>
                    busy <= '0';
                    done <= '1';
                    state <= ST_IDLE;

                when others => state <= ST_IDLE;
            end case;
        end if;
    end process;
end RTL;