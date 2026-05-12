--------------------------------------------------------------------------------
-- Institución : Instituto Politécnico Nacional (IPN) - UPIITA
-- Proyecto    : Driver LCD con Actualización Dinámica de Variables
-- Archivo     : FSM_LCD.vhd
-- Descripción :
-- Este módulo implementa un controlador de bajo nivel para un display
-- LCD 16x2 compatible con el controlador HD44780 operando en modo de
-- 4 bits.
--
-- La arquitectura está basada en una Máquina de Estados Finitos (FSM)
-- encargada de:
--
--   1. Limpiar pantalla
--   2. Posicionar cursor
--   3. Obtener caracteres desde lcd_pkg
--   4. Enviar datos/comandos al LCD
--   5. Respetar tiempos de protocolo HD44780
--   6. Administrar saltos automáticos de línea
--   7. Actualizar variables dinámicas sin parpadeo
--
-- El sistema soporta mensajes estáticos y mensajes dinámicos donde
-- ciertos caracteres son reemplazados en tiempo real por valores
-- provenientes de sensores o variables externas.
--
-- Características principales:
--
--   - Comunicación LCD en modo 4 bits
--   - Refresco inteligente sin Clear Display continuo
--   - Inserción dinámica de temperatura
--   - Inserción dinámica de ángulo
--   - Cambio automático de línea
--   - Señales de estado busy/done
--
-- Arquitectura general:
--
--          +----------------------+
--          |      FSM_LCD         |
--          +----------+-----------+
--                     |
--         +-----------+------------+
--         |                        |
--         v                        v
--   lcd_pkg                Variables ASCII
--                             dinámicas
--                     |
--                     v
--                 LCD 16x2
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
        -- Frecuencia del reloj principal
        ------------------------------------------------------------------------
        CLK_FREQ : integer := 50_000_000
    );

    port(

        ------------------------------------------------------------------------
        -- Entradas de control
        ------------------------------------------------------------------------
        clk : in std_logic;

        rst : in std_logic;

        ------------------------------------------------------------------------
        -- Pulso de inicio de escritura
        ------------------------------------------------------------------------
        start : in std_logic;

        ------------------------------------------------------------------------
        -- Identificador del mensaje a desplegar
        ------------------------------------------------------------------------
        msg_id : in std_logic_vector(3 downto 0);

        ------------------------------------------------------------------------
        -- Interfaz física LCD
        ------------------------------------------------------------------------
        LCD_RS : out std_logic;

        LCD_E : out std_logic;

        LCD_D : out std_logic_vector(3 downto 0);

        ------------------------------------------------------------------------
        -- Variables dinámicas ASCII
        ------------------------------------------------------------------------

        -- Centenas ASCII
        ascii_centenas : in std_logic_vector(7 downto 0);

        -- Decenas ASCII
        ascii_decenas : in std_logic_vector(7 downto 0);

        -- Unidades ASCII
        ascii_unidades : in std_logic_vector(7 downto 0);

        ------------------------------------------------------------------------
        -- Señales de estado
        ------------------------------------------------------------------------
        busy : out std_logic;

        done : out std_logic
    );
end FSM_LCD;

--------------------------------------------------------------------------------
-- ARCHITECTURE
--------------------------------------------------------------------------------
architecture RTL of FSM_LCD is

    ----------------------------------------------------------------------------
    -- DEFINICIÓN DE ESTADOS FSM
    ----------------------------------------------------------------------------
    --
    -- ST_IDLE:
    --   Espera solicitud de escritura
    --
    -- ST_CLEAR:
    --   Limpia completamente el LCD
    --
    -- ST_POS_TEMP:
    --   Reposiciona cursor para refresco dinámico
    --
    -- ST_FETCH:
    --   Obtiene siguiente carácter
    --
    -- ST_SETUP_H:
    --   Coloca nibble alto
    --
    -- ST_PULSE_H:
    --   Genera pulso Enable para nibble alto
    --
    -- ST_HOLD_H:
    --   Hold time nibble alto
    --
    -- ST_SETUP_L:
    --   Coloca nibble bajo
    --
    -- ST_PULSE_L:
    --   Genera pulso Enable para nibble bajo
    --
    -- ST_HOLD_L:
    --   Hold time nibble bajo
    --
    -- ST_WAIT:
    --   Espera interna del LCD
    --
    -- ST_NEXT:
    --   Control de flujo del mensaje
    --
    -- ST_DONE:
    --   Escritura finalizada
    ----------------------------------------------------------------------------
    type t_state is (
        ST_IDLE,
        ST_CLEAR,
        ST_POS_TEMP,
        ST_FETCH,
        ST_SETUP_H,
        ST_PULSE_H,
        ST_HOLD_H,
        ST_SETUP_L,
        ST_PULSE_L,
        ST_HOLD_L,
        ST_WAIT,
        ST_NEXT,
        ST_DONE
    );

    ----------------------------------------------------------------------------
    -- REGISTRO DE ESTADO
    ----------------------------------------------------------------------------
    signal state : t_state := ST_IDLE;

    ----------------------------------------------------------------------------
    -- REGISTROS INTERNOS
    ----------------------------------------------------------------------------

    ------------------------------------------------------------------------
    -- Byte actual a transmitir
    ------------------------------------------------------------------------
    signal r_data : std_logic_vector(7 downto 0) := (others => '0');

    ------------------------------------------------------------------------
    -- Índice actual del mensaje
    ------------------------------------------------------------------------
    signal r_index : integer range 0 to 31 := 0;

    ------------------------------------------------------------------------
    -- Longitud del mensaje actual
    ------------------------------------------------------------------------
    signal r_msg_len : integer range 0 to 32 := 0;

    ------------------------------------------------------------------------
    -- Registro RS interno
    ------------------------------------------------------------------------
    signal lcd_rs_reg : std_logic := '0';

    ------------------------------------------------------------------------
    -- Último mensaje mostrado
    ----------------------------------------------------------------------------
    -- Se utiliza para implementar refresco inteligente y evitar
    -- Clear Display innecesario.
    ----------------------------------------------------------------------------
    signal last_msg_id : std_logic_vector(3 downto 0) := "0000";

    ----------------------------------------------------------------------------
    -- CONSTANTES TEMPORALES
    ----------------------------------------------------------------------------

    ------------------------------------------------------------------------
    -- Ciclos equivalentes a 1 us
    ------------------------------------------------------------------------
    constant CYCLES_1US : integer :=
        CLK_FREQ / 1_000_000;

    ------------------------------------------------------------------------
    -- Retardo típico de instrucciones estándar (~40 us)
    ------------------------------------------------------------------------
    constant CYCLES_40US : integer :=
        CLK_FREQ / 25_000;

    ------------------------------------------------------------------------
    -- Retardo requerido por Clear Display (~2 ms)
    ------------------------------------------------------------------------
    constant CYCLES_2MS : integer :=
        CLK_FREQ / 500;

    ----------------------------------------------------------------------------
    -- TEMPORIZADORES
    ----------------------------------------------------------------------------

    ------------------------------------------------------------------------
    -- Contador general de retardos
    ------------------------------------------------------------------------
    signal timer : integer range 0 to CYCLES_2MS := 0;

    ------------------------------------------------------------------------
    -- Límite configurable de espera
    ------------------------------------------------------------------------
    signal wait_limit : integer range 0 to CYCLES_2MS := 0;

begin

    ----------------------------------------------------------------------------
    -- ASIGNACIÓN DE SALIDA RS
    ----------------------------------------------------------------------------
    LCD_RS <= lcd_rs_reg;

    ----------------------------------------------------------------------------
    -- PROCESO PRINCIPAL FSM
    ----------------------------------------------------------------------------
    process(clk, rst)
    begin

        ------------------------------------------------------------------------
        -- RESET ASÍNCRONO
        ------------------------------------------------------------------------
        if rst = '1' then

            state <= ST_IDLE;

            LCD_E <= '0';

            LCD_D <= (others => '0');

            lcd_rs_reg <= '0';

            busy <= '0';

            done <= '0';

            r_index <= 0;

            timer <= 0;

            last_msg_id <= (others => '0');

        ----------------------------------------------------------------------------
        -- FLANCO POSITIVO DE RELOJ
        ----------------------------------------------------------------------------
        elsif rising_edge(clk) then

            --------------------------------------------------------------------
            -- Valores por defecto
            --------------------------------------------------------------------
            LCD_E <= '0';

            done <= '0';

            --------------------------------------------------------------------
            -- MÁQUINA DE ESTADOS
            --------------------------------------------------------------------
            case state is

                ----------------------------------------------------------------
                -- ST_IDLE
                -- Espera solicitud de escritura
                ----------------------------------------------------------------
                when ST_IDLE =>

                    busy <= '0';

                    if start = '1' then

                        busy <= '1';

                        ----------------------------------------------------------------
                        -- REFRESCO INTELIGENTE
                        ----------------------------------------------------------------
                        -- Si el mensaje es el mismo:
                        --   solo reposiciona cursor
                        --
                        -- Si cambia:
                        --   limpia completamente LCD
                        ----------------------------------------------------------------
                        if msg_id = last_msg_id then

                            state <= ST_POS_TEMP;

                        else

                            state <= ST_CLEAR;
                        end if;

                        ----------------------------------------------------------------
                        -- Almacena último mensaje enviado
                        ----------------------------------------------------------------
                        last_msg_id <= msg_id;
                    end if;

                ----------------------------------------------------------------
                -- ST_CLEAR
                -- Limpieza completa del LCD
                ----------------------------------------------------------------
                when ST_CLEAR =>

                    lcd_rs_reg <= '0';

                    r_data <= x"01";

                    r_index <= 0;

                    r_msg_len <= get_msg_len(msg_id);

                    wait_limit <= CYCLES_2MS;

                    timer <= 0;

                    state <= ST_SETUP_H;

                ----------------------------------------------------------------
                -- ST_POS_TEMP
                -- Reposicionamiento inteligente del cursor
                ----------------------------------------------------------------
                when ST_POS_TEMP =>

                    lcd_rs_reg <= '0';

                    ----------------------------------------------------------------
                    -- Mensaje de temperatura
                    ----------------------------------------------------------------
                    if msg_id = "0100" then

                        --------------------------------------------------------
                        -- Cursor posición 12
                        --------------------------------------------------------
                        r_data <= x"8C";

                        r_index <= 12;

                    ----------------------------------------------------------------
                    -- Mensaje de ángulo/potenciómetro
                    ----------------------------------------------------------------
                    elsif msg_id = "0101" then

                        --------------------------------------------------------
                        -- Cursor posición 9
                        --------------------------------------------------------
                        r_data <= x"89";

                        r_index <= 9;

                    ----------------------------------------------------------------
                    -- Otros mensajes
                    ----------------------------------------------------------------
                    else

                        --------------------------------------------------------
                        -- Inicio línea 1
                        --------------------------------------------------------
                        r_data <= x"80";

                        r_index <= 0;
                    end if;

                    r_msg_len <= get_msg_len(msg_id);

                    wait_limit <= CYCLES_40US;

                    timer <= 0;

                    state <= ST_SETUP_H;

                ----------------------------------------------------------------
                -- ST_FETCH
                -- Obtiene siguiente carácter a transmitir
                ----------------------------------------------------------------
                when ST_FETCH =>

                    lcd_rs_reg <= '1';

                    ----------------------------------------------------------------
                    -- MENSAJE DINÁMICO DE TEMPERATURA
                    ----------------------------------------------------------------
                    if msg_id = "0100" then

                        case r_index is

                            when 12 =>

                                r_data <= ascii_decenas;

                            when 13 =>

                                r_data <= ascii_unidades;

                            when 14 =>

                                ------------------------------------------------
                                -- Símbolo °
                                ------------------------------------------------
                                r_data <= x"DF";

                            when 15 =>

                                ------------------------------------------------
                                -- Letra 'C'
                                ------------------------------------------------
                                r_data <= x"43";

                            when others =>

                                r_data <=
                                    get_lcd_char(msg_id, r_index);
                        end case;

                    ----------------------------------------------------------------
                    -- MENSAJE DINÁMICO DE ÁNGULO
                    ----------------------------------------------------------------
                    elsif msg_id = "0101" then

                        case r_index is

                            when 9 =>

                                r_data <= ascii_centenas;

                            when 10 =>

                                r_data <= ascii_decenas;

                            when 11 =>

                                r_data <= ascii_unidades;

                            when 12 =>

                                ------------------------------------------------
                                -- Símbolo °
                                ------------------------------------------------
                                r_data <= x"DF";

                            when others =>

                                r_data <=
                                    get_lcd_char(msg_id, r_index);
                        end case;

                    ----------------------------------------------------------------
                    -- MENSAJES ESTÁTICOS
                    ----------------------------------------------------------------
                    else

                        r_data <= get_lcd_char(msg_id, r_index);
                    end if;

                    wait_limit <= CYCLES_40US;

                    timer <= 0;

                    state <= ST_SETUP_H;

                ----------------------------------------------------------------
                -- ST_SETUP_H
                -- Coloca nibble alto
                ----------------------------------------------------------------
                when ST_SETUP_H =>

                    LCD_D <= r_data(7 downto 4);

                    state <= ST_PULSE_H;

                ----------------------------------------------------------------
                -- ST_PULSE_H
                -- Pulso Enable nibble alto
                ----------------------------------------------------------------
                when ST_PULSE_H =>

                    LCD_E <= '1';

                    if timer < CYCLES_1US then

                        timer <= timer + 1;

                    else

                        timer <= 0;

                        state <= ST_HOLD_H;
                    end if;

                ----------------------------------------------------------------
                -- ST_HOLD_H
                -- Hold time nibble alto
                ----------------------------------------------------------------
                when ST_HOLD_H =>

                    LCD_E <= '0';

                    state <= ST_SETUP_L;

                ----------------------------------------------------------------
                -- ST_SETUP_L
                -- Coloca nibble bajo
                ----------------------------------------------------------------
                when ST_SETUP_L =>

                    LCD_D <= r_data(3 downto 0);

                    state <= ST_PULSE_L;

                ----------------------------------------------------------------
                -- ST_PULSE_L
                -- Pulso Enable nibble bajo
                ----------------------------------------------------------------
                when ST_PULSE_L =>

                    LCD_E <= '1';

                    if timer < CYCLES_1US then

                        timer <= timer + 1;

                    else

                        timer <= 0;

                        state <= ST_HOLD_L;
                    end if;

                ----------------------------------------------------------------
                -- ST_HOLD_L
                -- Hold time nibble bajo
                ----------------------------------------------------------------
                when ST_HOLD_L =>

                    LCD_E <= '0';

                    timer <= 0;

                    state <= ST_WAIT;

                ----------------------------------------------------------------
                -- ST_WAIT
                -- Espera procesamiento interno LCD
                ----------------------------------------------------------------
                when ST_WAIT =>

                    if timer < wait_limit then

                        timer <= timer + 1;

                    else

                        state <= ST_NEXT;
                    end if;

                ----------------------------------------------------------------
                -- ST_NEXT
                -- Gestión de flujo del mensaje
                ----------------------------------------------------------------
                when ST_NEXT =>

                    timer <= 0;

                    ----------------------------------------------------------------
                    -- Si se acaba de enviar un comando
                    ----------------------------------------------------------------
                    if lcd_rs_reg = '0' then

                        state <= ST_FETCH;

                    ----------------------------------------------------------------
                    -- Cambio automático de línea
                    ----------------------------------------------------------------
                    elsif r_index = 15 and r_msg_len > 16 then

                        r_index <= 16;

                        lcd_rs_reg <= '0';

                        ----------------------------------------------------------------
                        -- Comando línea 2
                        ----------------------------------------------------------------
                        r_data <= x"C0";

                        wait_limit <= CYCLES_40US;

                        state <= ST_SETUP_H;

                    ----------------------------------------------------------------
                    -- Fin del mensaje
                    ----------------------------------------------------------------
                    elsif r_index >= r_msg_len - 1 then

                        state <= ST_DONE;

                    ----------------------------------------------------------------
                    -- Continuar siguiente carácter
                    ----------------------------------------------------------------
                    else

                        r_index <= r_index + 1;

                        state <= ST_FETCH;
                    end if;

                ----------------------------------------------------------------
                -- ST_DONE
                -- Escritura finalizada
                ----------------------------------------------------------------
                when ST_DONE =>

                    busy <= '0';

                    done <= '1';

                    state <= ST_IDLE;

                ----------------------------------------------------------------
                -- ESTADO NO DEFINIDO
                ----------------------------------------------------------------
                when others =>

                    state <= ST_IDLE;
            end case;
        end if;
    end process;

end RTL;
