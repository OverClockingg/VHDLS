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

        busy     : out std_logic;
        done     : out std_logic
    );
end FSM_LCD;

architecture RTL of FSM_LCD is

    --------------------------------------------------------------------
    -- FSM STATES
    --------------------------------------------------------------------
    type t_state is (
        ST_IDLE,
        ST_CLEAR,
        ST_FETCH,
        ST_SETUP_H, ST_PULSE_H, ST_HOLD_H,
        ST_SETUP_L, ST_PULSE_L, ST_HOLD_L,
        ST_WAIT,
        ST_NEXT,
        ST_DONE
    );

    signal state : t_state := ST_IDLE;

    --------------------------------------------------------------------
    -- REGISTERS
    --------------------------------------------------------------------
    signal r_data      : std_logic_vector(7 downto 0) := (others => '0');
    signal r_index     : integer range 0 to 31 := 0;
    signal r_msg_len   : integer range 0 to 32 := 0;
    signal lcd_rs_reg  : std_logic := '0';
    signal after_clear : std_logic := '0';

    --------------------------------------------------------------------
    -- TIMING
    --------------------------------------------------------------------
    constant CYCLES_1US  : integer := CLK_FREQ / 1_000_000;
    constant CYCLES_40US : integer := CLK_FREQ / 25_000;
    constant CYCLES_2MS  : integer := CLK_FREQ / 500;

    signal timer      : integer range 0 to CYCLES_2MS := 0;
    signal wait_limit : integer range 0 to CYCLES_2MS := 0;

begin

    --------------------------------------------------------------------
    -- OUTPUT ASSIGN
    --------------------------------------------------------------------
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

            LCD_E <= '0';
            done  <= '0';

            case state is

            ----------------------------------------------------------------
            -- IDLE: Espera la señal de inicio
            ----------------------------------------------------------------
            when ST_IDLE =>
                busy <= '0';
                r_index <= 0;
                after_clear <= '0';
                if start = '1' then
                    busy <= '1';
                    r_msg_len <= get_msg_len(msg_id);
                    state <= ST_CLEAR;
                end if;

            ----------------------------------------------------------------
            -- CLEAR LCD: Limpia la pantalla antes de empezar
            ----------------------------------------------------------------
            when ST_CLEAR =>
                lcd_rs_reg <= '0'; -- Modo COMANDO
                r_data <= x"01";   -- Instrucción Clear Display
                wait_limit <= CYCLES_2MS;
                timer <= 0;
                state <= ST_SETUP_H;

            ----------------------------------------------------------------
            -- FETCH CHARACTER: Obtiene la siguiente letra del mensaje
            ----------------------------------------------------------------
            when ST_FETCH =>
                lcd_rs_reg <= '1'; -- Modo DATOS
                r_data <= get_lcd_char(msg_id, r_index);
                wait_limit <= CYCLES_40US;
                timer <= 0;
                state <= ST_SETUP_H;

            ----------------------------------------------------------------
            -- PROTOCOLO 4-BITS: Envío de Nibble Superior
            ----------------------------------------------------------------
            when ST_SETUP_H =>
                LCD_D <= r_data(7 downto 4);
                state <= ST_PULSE_H;

            when ST_PULSE_H =>
                LCD_D <= r_data(7 downto 4);
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

            ----------------------------------------------------------------
            -- PROTOCOLO 4-BITS: Envío de Nibble Inferior
            ----------------------------------------------------------------
            when ST_SETUP_L =>
                LCD_D <= r_data(3 downto 0);
                state <= ST_PULSE_L;

            when ST_PULSE_L =>
                LCD_D <= r_data(3 downto 0);
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

            ----------------------------------------------------------------
            -- WAIT: Tiempo de procesamiento del LCD
            ----------------------------------------------------------------
            when ST_WAIT =>
                if timer < wait_limit then
                    timer <= timer + 1;
                else
                    state <= ST_NEXT;
                end if;

            ----------------------------------------------------------------
            -- NEXT STEP: Gestión de flujo y salto de línea
            ----------------------------------------------------------------
            when ST_NEXT =>
                timer <= 0;

                -- 1. Transición después de limpiar pantalla
                if after_clear = '0' then
                    after_clear <= '1';
                    r_index <= 0;
                    state <= ST_FETCH;

                -- 2. Lógica de Salto de Renglón (IMPORTANTE)
                -- Si acabamos de escribir el carácter 16 (índice 15)
                elsif r_index = 15 then
                    r_index <= 16;      -- Apuntamos a la siguiente letra
                    lcd_rs_reg <= '0';  -- Cambiamos a modo COMANDO
                    r_data <= x"C0";    -- Comando para ir al segundo renglón
                    wait_limit <= CYCLES_40US;
                    state <= ST_SETUP_H;

                -- 3. Fin del mensaje
                elsif r_index >= r_msg_len - 1 then
                    state <= ST_DONE;

                -- 4. Incrementar índice normalmente
                else
                    r_index <= r_index + 1;
                    state <= ST_FETCH;
                end if;

            ----------------------------------------------------------------
            -- DONE: Indica que el mensaje se terminó de escribir
            ----------------------------------------------------------------
            when ST_DONE =>
                busy <= '0';
                done <= '1';
                state <= ST_IDLE;

            when others =>
                state <= ST_IDLE;

            end case;
        end if;
    end process;

end RTL;