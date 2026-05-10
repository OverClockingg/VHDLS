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

        LCD_RS   : out std_logic;
        LCD_E    : out std_logic;
        LCD_D    : out std_logic_vector(3 downto 0);
        
        ascii_decenas  : in std_logic_vector(7 downto 0);
        ascii_unidades : in std_logic_vector(7 downto 0);
        
        busy     : out std_logic;
        done     : out std_logic
    );
end FSM_LCD;

architecture RTL of FSM_LCD is

    type t_state is (
        ST_IDLE,
        ST_CLEAR,    -- Agregado: Corrige el Error (10482)
        ST_POS_TEMP, -- Agregado: Para refresco inteligente sin parpadeo
        ST_FETCH,
        ST_SETUP_H, ST_PULSE_H, ST_HOLD_H,
        ST_SETUP_L, ST_PULSE_L, ST_HOLD_L,
        ST_WAIT,
        ST_NEXT,
        ST_DONE
    );

    signal state : t_state := ST_IDLE;

    signal r_data      : std_logic_vector(7 downto 0) := (others => '0');
    signal r_index     : integer range 0 to 31 := 0;
    signal r_msg_len   : integer range 0 to 32 := 0;
    signal lcd_rs_reg  : std_logic := '0';
    signal last_msg_id : std_logic_vector(3 downto 0) := "0000";

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
            timer       <= 0;
            last_msg_id <= (others => '0');

        elsif rising_edge(clk) then
            LCD_E <= '0';
            done  <= '0';

            case state is

                when ST_IDLE =>
                    busy <= '0';
                    if start = '1' then
                        busy <= '1';
                        -- LÓGICA DE REFRESCO: Si es el mismo ID, solo reposiciona el cursor
                        if msg_id = last_msg_id then
                            state <= ST_POS_TEMP;
                        else
                            state <= ST_CLEAR; -- Si cambia el mensaje, borra todo
                        end if;
                        last_msg_id <= msg_id;
                    end if;

                when ST_CLEAR =>
                    lcd_rs_reg <= '0';      -- Modo COMANDO
                    r_data     <= x"01";    -- Comando Clear Display
                    r_index    <= 0;
                    r_msg_len  <= get_msg_len(msg_id);
                    wait_limit <= CYCLES_2MS;
                    timer      <= 0;
                    state      <= ST_SETUP_H;

                when ST_POS_TEMP =>
                    lcd_rs_reg <= '0';      -- Modo COMANDO
                    if msg_id = "0100" then
                        r_data  <= x"8C";   -- Posición 12 (donde empiezan los números)
                        r_index <= 12;
                    else
                        r_data  <= x"80";   -- Inicio de línea 1 para otros mensajes
                        r_index <= 0;
                    end if;
                    r_msg_len  <= get_msg_len(msg_id);
                    wait_limit <= CYCLES_40US;
                    timer      <= 0;
                    state      <= ST_SETUP_H;

                when ST_FETCH =>
                    lcd_rs_reg <= '1'; -- Modo DATOS
                    -- Inyección dinámica de valores para el mensaje de Temperatura (ID 4)
                    if msg_id = "0100" then 
                        case r_index is
                            when 12 => r_data <= ascii_decenas;
                            when 13 => r_data <= ascii_unidades;
                            when 14 => r_data <= x"DF"; -- Símbolo de grado °
                            when 15 => r_data <= x"43"; -- 'C'
                            when others => r_data <= get_lcd_char(msg_id, r_index);
                        end case;
                    else
                        r_data <= get_lcd_char(msg_id, r_index);
                    end if;
                    wait_limit <= CYCLES_40US;
                    timer <= 0;
                    state <= ST_SETUP_H;

                when ST_SETUP_H =>
                    LCD_D <= r_data(7 downto 4);
                    state <= ST_PULSE_H;

                when ST_PULSE_H =>
                    LCD_E <= '1';
                    if timer < CYCLES_1US then
                        timer <= timer + 1;
                    else
                        timer <= 0;
                        state <= ST_HOLD_H;
                    end if;

                when ST_HOLD_H =>
                    LCD_E <= '0';
                    state <= ST_SETUP_L;

                when ST_SETUP_L =>
                    LCD_D <= r_data(3 downto 0);
                    state <= ST_PULSE_L;

                when ST_PULSE_L =>
                    LCD_E <= '1';
                    if timer < CYCLES_1US then
                        timer <= timer + 1;
                    else
                        timer <= 0;
                        state <= ST_HOLD_L;
                    end if;

                when ST_HOLD_L =>
                    LCD_E <= '0';
                    timer <= 0;
                    state <= ST_WAIT;

                when ST_WAIT =>
                    if timer < wait_limit then
                        timer <= timer + 1;
                    else
                        state <= ST_NEXT;
                    end if;

                when ST_NEXT =>
                    timer <= 0;
                    -- Si terminamos de enviar un COMANDO (RS=0), ahora vamos a los DATOS
                    if lcd_rs_reg = '0' then
                        state <= ST_FETCH;
                    -- Salto de línea automático si llegamos al final del primer renglón
                    elsif r_index = 15 and r_msg_len > 16 then
                        r_index <= 16;
                        lcd_rs_reg <= '0';
                        r_data <= x"C0"; -- Comando: Ir a línea 2
                        wait_limit <= CYCLES_40US;
                        state <= ST_SETUP_H;
                    -- Fin del mensaje actual
                    elsif r_index >= r_msg_len - 1 then
                        state <= ST_DONE;
                    else
                        r_index <= r_index + 1;
                        state <= ST_FETCH;
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