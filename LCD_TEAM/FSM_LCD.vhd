--------------------------------------------------------------------------------
-- Institución : Instituto Politécnico Nacional (IPN) - UPIITA
-- Proyecto    : Controlador FSM para LCD 16x2 en modo 4 bits
-- Archivo     : FSM_LCD.vhd
-- Descripción :
-- Este módulo implementa una Máquina de Estados Finitos (FSM) encargada
-- de controlar un display LCD compatible con el controlador HD44780
-- utilizando interfaz de 4 bits.
--
-- La FSM realiza automáticamente:
--   1. Limpieza de pantalla (Clear Display)
--   2. Obtención de caracteres desde lcd_pkg
--   3. Envío de datos/comandos en formato de 4 bits
--   4. Generación de pulsos de habilitación (LCD_E)
--   5. Manejo de tiempos de espera requeridos por el LCD
--   6. Cambio automático al segundo renglón
--   7. Señalización de ocupado (busy) y finalización (done)
--
-- Funcionamiento general:
-- Cuando la señal "start" se activa, la FSM limpia primero la pantalla
-- y posteriormente transmite carácter por carácter el mensaje asociado
-- al identificador "msg_id".
--
-- El envío se realiza en dos etapas:
--   - Nibble superior
--   - Nibble inferior
--
-- Cada nibble es acompañado por un pulso en la señal LCD_E para cumplir
-- con el protocolo del controlador LCD.
--
-- Dependencias:
--   - IEEE.STD_LOGIC_1164
--   - IEEE.NUMERIC_STD
--   - work.lcd_pkg
--
-- Autor       :
-- Fecha       :
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.lcd_pkg.all;

--------------------------------------------------------------------------------
-- ENTITY
--------------------------------------------------------------------------------
entity FSM_LCD is
    generic(
        ------------------------------------------------------------------------
        -- Frecuencia del reloj del sistema.
        -- Se utiliza para calcular los retardos necesarios del LCD.
        ------------------------------------------------------------------------
        CLK_FREQ : integer := 50_000_000
    );

    port(
        ------------------------------------------------------------------------
        -- Entradas de control
        ------------------------------------------------------------------------
        clk     : in std_logic;                       -- Reloj principal
        rst     : in std_logic;                       -- Reset síncrono
        start   : in std_logic;                       -- Inicio de transmisión
        msg_id  : in std_logic_vector(3 downto 0);   -- Identificador de mensaje

        ------------------------------------------------------------------------
        -- Interfaz hacia el LCD
        ------------------------------------------------------------------------
        LCD_RS  : out std_logic;                      -- Selección COMANDO/DATO
        LCD_E   : out std_logic;                      -- Enable del LCD
        LCD_D   : out std_logic_vector(3 downto 0);  -- Bus de datos 4 bits

        ------------------------------------------------------------------------
        -- Señales de estado
        ------------------------------------------------------------------------
        busy    : out std_logic;                      -- FSM ocupada
        done    : out std_logic                       -- Escritura finalizada
    );
end FSM_LCD;

--------------------------------------------------------------------------------
-- ARCHITECTURE
--------------------------------------------------------------------------------
architecture RTL of FSM_LCD is

    ----------------------------------------------------------------------------
    -- DEFINICIÓN DE ESTADOS DE LA FSM
    ----------------------------------------------------------------------------
    type t_state is (

        ------------------------------------------------------------------------
        -- Estado de reposo
        ------------------------------------------------------------------------
        ST_IDLE,

        ------------------------------------------------------------------------
        -- Limpieza inicial del LCD
        ------------------------------------------------------------------------
        ST_CLEAR,

        ------------------------------------------------------------------------
        -- Obtención del siguiente carácter desde lcd_pkg
        ------------------------------------------------------------------------
        ST_FETCH,

        ------------------------------------------------------------------------
        -- Envío del nibble alto
        ------------------------------------------------------------------------
        ST_SETUP_H,
        ST_PULSE_H,
        ST_HOLD_H,

        ------------------------------------------------------------------------
        -- Envío del nibble bajo
        ------------------------------------------------------------------------
        ST_SETUP_L,
        ST_PULSE_L,
        ST_HOLD_L,

        ------------------------------------------------------------------------
        -- Espera de procesamiento interno del LCD
        ------------------------------------------------------------------------
        ST_WAIT,

        ------------------------------------------------------------------------
        -- Gestión del flujo de escritura
        ------------------------------------------------------------------------
        ST_NEXT,

        ------------------------------------------------------------------------
        -- Finalización de transmisión
        ------------------------------------------------------------------------
        ST_DONE
    );

    ----------------------------------------------------------------------------
    -- REGISTRO DE ESTADO
    ----------------------------------------------------------------------------
    signal state : t_state := ST_IDLE;

    ----------------------------------------------------------------------------
    -- REGISTROS INTERNOS
    ----------------------------------------------------------------------------

    -- Byte actual a transmitir al LCD
    signal r_data : std_logic_vector(7 downto 0) := (others => '0');

    -- Índice del carácter actual dentro del mensaje
    signal r_index : integer range 0 to 31 := 0;

    -- Longitud total del mensaje
    signal r_msg_len : integer range 0 to 32 := 0;

    -- Registro interno para LCD_RS
    signal lcd_rs_reg : std_logic := '0';

    -- Bandera utilizada para detectar la transición después del CLEAR
    signal after_clear : std_logic := '0';

    ----------------------------------------------------------------------------
    -- CONSTANTES DE TEMPORIZACIÓN
    ----------------------------------------------------------------------------

    -- Número de ciclos equivalentes a 1 us
    constant CYCLES_1US : integer := CLK_FREQ / 1_000_000;

    -- Tiempo típico de espera entre comandos/datos (~40 us)
    constant CYCLES_40US : integer := CLK_FREQ / 25_000;

    -- Tiempo requerido para Clear Display (~2 ms)
    constant CYCLES_2MS : integer := CLK_FREQ / 500;

    ----------------------------------------------------------------------------
    -- TEMPORIZADORES
    ----------------------------------------------------------------------------

    -- Contador principal de espera
    signal timer : integer range 0 to CYCLES_2MS := 0;

    -- Límite dinámico de espera
    signal wait_limit : integer range 0 to CYCLES_2MS := 0;

begin

    ----------------------------------------------------------------------------
    -- ASIGNACIÓN DE SALIDAS
    ----------------------------------------------------------------------------
    LCD_RS <= lcd_rs_reg;

    ----------------------------------------------------------------------------
    -- PROCESO PRINCIPAL
    ----------------------------------------------------------------------------
    process(clk, rst)
    begin

        ------------------------------------------------------------------------
        -- RESET
        ------------------------------------------------------------------------
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

        ----------------------------------------------------------------------------
        -- FLANCO POSITIVO DE RELOJ
        ----------------------------------------------------------------------------
        elsif rising_edge(clk) then

            --------------------------------------------------------------------
            -- Valores por defecto en cada ciclo
            --------------------------------------------------------------------
            LCD_E <= '0';
            done  <= '0';

            --------------------------------------------------------------------
            -- MÁQUINA DE ESTADOS
            --------------------------------------------------------------------
            case state is

            --------------------------------------------------------------------
            -- ST_IDLE
            -- Espera la activación de "start"
            --------------------------------------------------------------------
            when ST_IDLE =>

                busy <= '0';

                r_index <= 0;

                after_clear <= '0';

                if start = '1' then

                    busy <= '1';

                    -- Obtiene la longitud del mensaje seleccionado
                    r_msg_len <= get_msg_len(msg_id);

                    -- Inicia con limpieza del LCD
                    state <= ST_CLEAR;
                end if;

            --------------------------------------------------------------------
            -- ST_CLEAR
            -- Envía el comando Clear Display (0x01)
            --------------------------------------------------------------------
            when ST_CLEAR =>

                lcd_rs_reg <= '0';  -- Modo COMANDO

                r_data <= x"01";    -- Clear Display

                wait_limit <= CYCLES_2MS;

                timer <= 0;

                state <= ST_SETUP_H;

            --------------------------------------------------------------------
            -- ST_FETCH
            -- Obtiene el siguiente carácter del mensaje
            --------------------------------------------------------------------
            when ST_FETCH =>

                lcd_rs_reg <= '1';  -- Modo DATOS

                r_data <= get_lcd_char(msg_id, r_index);

                wait_limit <= CYCLES_40US;

                timer <= 0;

                state <= ST_SETUP_H;

            --------------------------------------------------------------------
            -- ST_SETUP_H
            -- Coloca el nibble alto sobre el bus
            --------------------------------------------------------------------
            when ST_SETUP_H =>

                LCD_D <= r_data(7 downto 4);

                state <= ST_PULSE_H;

            --------------------------------------------------------------------
            -- ST_PULSE_H
            -- Genera el pulso Enable para el nibble alto
            --------------------------------------------------------------------
            when ST_PULSE_H =>

                LCD_D <= r_data(7 downto 4);

                LCD_E <= '1';

                if timer < CYCLES_1US then

                    timer <= timer + 1;

                else

                    timer <= 0;

                    state <= ST_HOLD_H;
                end if;

            --------------------------------------------------------------------
            -- ST_HOLD_H
            -- Finaliza transmisión del nibble alto
            --------------------------------------------------------------------
            when ST_HOLD_H =>

                LCD_E <= '0';

                state <= ST_SETUP_L;

            --------------------------------------------------------------------
            -- ST_SETUP_L
            -- Coloca el nibble bajo sobre el bus
            --------------------------------------------------------------------
            when ST_SETUP_L =>

                LCD_D <= r_data(3 downto 0);

                state <= ST_PULSE_L;

            --------------------------------------------------------------------
            -- ST_PULSE_L
            -- Genera el pulso Enable para el nibble bajo
            --------------------------------------------------------------------
            when ST_PULSE_L =>

                LCD_D <= r_data(3 downto 0);

                LCD_E <= '1';

                if timer < CYCLES_1US then

                    timer <= timer + 1;

                else

                    timer <= 0;

                    state <= ST_HOLD_L;
                end if;

            --------------------------------------------------------------------
            -- ST_HOLD_L
            -- Finaliza transmisión del nibble bajo
            --------------------------------------------------------------------
            when ST_HOLD_L =>

                LCD_E <= '0';

                timer <= 0;

                state <= ST_WAIT;

            --------------------------------------------------------------------
            -- ST_WAIT
            -- Espera el tiempo de procesamiento del LCD
            --------------------------------------------------------------------
            when ST_WAIT =>

                if timer < wait_limit then

                    timer <= timer + 1;

                else

                    state <= ST_NEXT;
                end if;

            --------------------------------------------------------------------
            -- ST_NEXT
            -- Gestiona el flujo de transmisión
            --------------------------------------------------------------------
            when ST_NEXT =>

                timer <= 0;

                ----------------------------------------------------------------
                -- Caso 1:
                -- Acabamos de terminar el comando CLEAR
                ----------------------------------------------------------------
                if after_clear = '0' then

                    after_clear <= '1';

                    r_index <= 0;

                    state <= ST_FETCH;

                ----------------------------------------------------------------
                -- Caso 2:
                -- Cambio automático al segundo renglón
                ----------------------------------------------------------------
                elsif r_index = 15 then

                    r_index <= 16;

                    lcd_rs_reg <= '0';   -- Modo COMANDO

                    r_data <= x"C0";     -- Dirección inicio línea 2

                    wait_limit <= CYCLES_40US;

                    state <= ST_SETUP_H;

                ----------------------------------------------------------------
                -- Caso 3:
                -- Fin del mensaje
                ----------------------------------------------------------------
                elsif r_index >= r_msg_len - 1 then

                    state <= ST_DONE;

                ----------------------------------------------------------------
                -- Caso 4:
                -- Continuar normalmente
                ----------------------------------------------------------------
                else

                    r_index <= r_index + 1;

                    state <= ST_FETCH;
                end if;

            --------------------------------------------------------------------
            -- ST_DONE
            -- Señaliza finalización de escritura
            --------------------------------------------------------------------
            when ST_DONE =>

                busy <= '0';

                done <= '1';

                state <= ST_IDLE;

            --------------------------------------------------------------------
            -- ESTADO NO DEFINIDO
            --------------------------------------------------------------------
            when others =>

                state <= ST_IDLE;

            end case;
        end if;
    end process;

end RTL;
