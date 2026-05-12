--------------------------------------------------------------------------------
-- Institución : Instituto Politécnico Nacional (IPN) - UPIITA
-- Proyecto    : FSM de Inicialización para LCD 16x2
-- Archivo     : lcd_init_fsm.vhd
-- Descripción :
-- Este módulo implementa una Máquina de Estados Finitos (FSM) encargada
-- de ejecutar la secuencia completa de inicialización de un display LCD
-- compatible con el controlador HD44780 operando en modo de 4 bits.
--
-- El controlador HD44780 requiere una secuencia específica de comandos
-- y retardos temporales después del encendido para garantizar una
-- configuración correcta del display.
--
-- Funciones principales:
--
--   1. Espera inicial de estabilización tras power-up
--   2. Secuencia de "wake-up" del controlador LCD
--   3. Configuración del modo de 4 bits
--   4. Configuración de display y formato
--   5. Activación del display
--   6. Limpieza inicial de pantalla
--   7. Generación de pulsos Enable (LCD_E)
--   8. Garantía de tiempos Setup y Hold
--
-- Secuencia implementada:
--
--   1. Espera >15 ms
--   2. Envío 0x3 (3 veces)
--   3. Envío 0x2 (modo 4 bits)
--   4. Function Set (0x28)
--   5. Display ON/OFF (0x0C)
--   6. Clear Display (0x01)
--
-- Arquitectura temporal:
--
--   LOAD_BUS  -> Coloca datos en el bus
--   STABILIZE -> Garantiza Setup Time
--   PULSE_E   -> Genera pulso Enable
--   HOLD_DATA -> Garantiza Hold Time
--   DELAY     -> Espera interna del LCD
--
-- Dependencias:
--   - IEEE.STD_LOGIC_1164
--   - IEEE.NUMERIC_STD
--
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

--------------------------------------------------------------------------------
-- ENTITY
--------------------------------------------------------------------------------
entity lcd_init_fsm is
    generic (

        ------------------------------------------------------------------------
        -- Frecuencia del reloj principal del sistema
        ------------------------------------------------------------------------
        CLK_FREQ_HZ : integer := 50_000_000
    );

    port (

        ------------------------------------------------------------------------
        -- Entradas de control
        ------------------------------------------------------------------------
        clk : in std_logic; -- Reloj principal

        rst : in std_logic; -- Reset síncrono

        ------------------------------------------------------------------------
        -- Clock Enable de 1 microsegundo
        ------------------------------------------------------------------------
        ce_1us : in std_logic;

        ------------------------------------------------------------------------
        -- Interfaz física hacia el LCD
        ------------------------------------------------------------------------
        LCD_RS : out std_logic;

        LCD_E : out std_logic;

        LCD_D : out std_logic_vector(3 downto 0);

        ------------------------------------------------------------------------
        -- Señal de finalización de inicialización
        ------------------------------------------------------------------------
        init_done : out std_logic
    );
end entity;

--------------------------------------------------------------------------------
-- ARCHITECTURE
--------------------------------------------------------------------------------
architecture RTL of lcd_init_fsm is

    ----------------------------------------------------------------------------
    -- CONSTANTES DE TEMPORIZACIÓN
    ----------------------------------------------------------------------------

    ------------------------------------------------------------------------
    -- Número de ciclos de reloj equivalentes a 1 us
    --
    -- Se utiliza para garantizar tiempos mínimos de setup y hold.
    ------------------------------------------------------------------------
    constant CYCLES_1US : integer :=
        (CLK_FREQ_HZ / 1_000_000);

    ----------------------------------------------------------------------------
    -- DEFINICIÓN DE ESTADOS DE LA FSM
    ----------------------------------------------------------------------------
    --
    -- POWER_UP:
    --   Espera inicial después del encendido (>15 ms)
    --
    -- LOAD_BUS:
    --   Coloca datos/comandos sobre el bus LCD_D
    --
    -- STABILIZE:
    --   Garantiza el Setup Time antes del pulso Enable
    --
    -- PULSE_E:
    --   Genera el pulso Enable (LCD_E = '1')
    --
    -- HOLD_DATA:
    --   Garantiza Hold Time después del pulso Enable
    --
    -- DELAY_STATE:
    --   Ejecuta retardos específicos entre comandos
    --
    -- DONE:
    --   Inicialización finalizada
    ----------------------------------------------------------------------------
    type state_type is (
        POWER_UP,
        LOAD_BUS,
        STABILIZE,
        PULSE_E,
        HOLD_DATA,
        DELAY_STATE,
        DONE
    );

    ----------------------------------------------------------------------------
    -- REGISTRO DE ESTADO
    ----------------------------------------------------------------------------
    signal state : state_type := POWER_UP;

    ----------------------------------------------------------------------------
    -- TEMPORIZADORES
    ----------------------------------------------------------------------------

    ------------------------------------------------------------------------
    -- Temporizador principal para retardos largos
    ------------------------------------------------------------------------
    signal timer : integer range 0 to 65535 := 0;

    ------------------------------------------------------------------------
    -- Temporizador utilizado para Setup/Hold del bus
    ------------------------------------------------------------------------
    signal bus_timer : integer range 0 to CYCLES_1US + 1 := 0;

    ----------------------------------------------------------------------------
    -- CONTADOR DE PASOS DE INICIALIZACIÓN
    ----------------------------------------------------------------------------
    -- Cada valor corresponde a un comando o nibble específico
    -- dentro de la secuencia HD44780.
    ----------------------------------------------------------------------------
    signal step : integer range 0 to 12 := 0;

begin

    ----------------------------------------------------------------------------
    -- PROCESO PRINCIPAL
    ----------------------------------------------------------------------------
    process(clk)
    begin

        ------------------------------------------------------------------------
        -- FLANCO POSITIVO DE RELOJ
        ------------------------------------------------------------------------
        if rising_edge(clk) then

            --------------------------------------------------------------------
            -- RESET SÍNCRONO
            --------------------------------------------------------------------
            if rst = '1' then

                state <= POWER_UP;

                timer <= 0;

                bus_timer <= 0;

                LCD_E <= '0';

                LCD_RS <= '0';

                LCD_D <= "0000";

                init_done <= '0';

                step <= 0;

            ----------------------------------------------------------------------------
            -- OPERACIÓN NORMAL
            ----------------------------------------------------------------------------
            else

                ----------------------------------------------------------------
                -- MÁQUINA DE ESTADOS
                ----------------------------------------------------------------
                case state is

                    ----------------------------------------------------------------
                    -- POWER_UP
                    -- Espera inicial requerida por el HD44780 (>15 ms)
                    ----------------------------------------------------------------
                    when POWER_UP =>

                        if ce_1us = '1' then

                            if timer < 15000 then

                                timer <= timer + 1;

                            else

                                timer <= 0;

                                state <= LOAD_BUS;
                            end if;
                        end if;

                    ----------------------------------------------------------------
                    -- LOAD_BUS
                    -- Coloca el comando/nibble sobre el bus de datos
                    ----------------------------------------------------------------
                    when LOAD_BUS =>

                        LCD_E <= '0';

                        case step is

                            --------------------------------------------------------
                            -- Secuencia Wake-Up (0x3 enviado 3 veces)
                            --------------------------------------------------------
                            when 0 | 1 | 2 =>

                                LCD_D <= "0011";

                                LCD_RS <= '0';

                            --------------------------------------------------------
                            -- Cambio a modo 4 bits (0x2)
                            --------------------------------------------------------
                            when 3 =>

                                LCD_D <= "0010";

                                LCD_RS <= '0';

                            --------------------------------------------------------
                            -- Function Set (0x28)
                            -- 2 líneas, matriz 5x8
                            --------------------------------------------------------
                            when 4 =>

                                LCD_D <= "0010"; -- Nibble alto

                                LCD_RS <= '0';

                            when 5 =>

                                LCD_D <= "1000"; -- Nibble bajo

                                LCD_RS <= '0';

                            --------------------------------------------------------
                            -- Display ON/OFF (0x0C)
                            -- Display ON, cursor OFF
                            --------------------------------------------------------
                            when 6 =>

                                LCD_D <= "0000";

                                LCD_RS <= '0';

                            when 7 =>

                                LCD_D <= "1100";

                                LCD_RS <= '0';

                            --------------------------------------------------------
                            -- Clear Display (0x01)
                            --------------------------------------------------------
                            when 8 =>

                                LCD_D <= "0000";

                                LCD_RS <= '0';

                            when 9 =>

                                LCD_D <= "0001";

                                LCD_RS <= '0';

                            --------------------------------------------------------
                            -- Valor por defecto
                            --------------------------------------------------------
                            when others =>

                                LCD_D <= "0000";

                                LCD_RS <= '0';
                        end case;

                        state <= STABILIZE;

                    ----------------------------------------------------------------
                    -- STABILIZE
                    -- Garantiza Setup Time antes de Enable
                    ----------------------------------------------------------------
                    when STABILIZE =>

                        bus_timer <= 0;

                        state <= PULSE_E;

                    ----------------------------------------------------------------
                    -- PULSE_E
                    -- Genera el pulso Enable del LCD
                    ----------------------------------------------------------------
                    when PULSE_E =>

                        LCD_E <= '1';

                        if bus_timer < CYCLES_1US - 1 then

                            bus_timer <= bus_timer + 1;

                        else

                            bus_timer <= 0;

                            state <= HOLD_DATA;
                        end if;

                    ----------------------------------------------------------------
                    -- HOLD_DATA
                    -- Garantiza Hold Time después de Enable
                    ----------------------------------------------------------------
                    when HOLD_DATA =>

                        LCD_E <= '0';

                        if bus_timer < CYCLES_1US - 1 then

                            bus_timer <= bus_timer + 1;

                        else

                            timer <= 0;

                            state <= DELAY_STATE;
                        end if;

                    ----------------------------------------------------------------
                    -- DELAY_STATE
                    -- Ejecuta retardos específicos entre comandos
                    ----------------------------------------------------------------
                    when DELAY_STATE =>

                        if ce_1us = '1' then

                            case step is

                                ----------------------------------------------------
                                -- Primer retardo crítico (~4.1 ms)
                                ----------------------------------------------------
                                when 0 =>

                                    if timer < 4100 then

                                        timer <= timer + 1;

                                    else

                                        state <= LOAD_BUS;

                                        step <= 1;
                                    end if;

                                ----------------------------------------------------
                                -- Segundo retardo crítico (~100 us)
                                ----------------------------------------------------
                                when 1 =>

                                    if timer < 100 then

                                        timer <= timer + 1;

                                    else

                                        state <= LOAD_BUS;

                                        step <= 2;
                                    end if;

                                ----------------------------------------------------
                                -- Clear Display requiere >1.5 ms
                                ----------------------------------------------------
                                when 8 | 9 =>

                                    if timer < 2000 then

                                        timer <= timer + 1;

                                    else

                                        state <= LOAD_BUS;

                                        step <= step + 1;
                                    end if;

                                ----------------------------------------------------
                                -- Fin de secuencia
                                ----------------------------------------------------
                                when 10 =>

                                    state <= DONE;

                                ----------------------------------------------------
                                -- Retardos estándar (~40 us)
                                ----------------------------------------------------
                                when others =>

                                    if timer < 40 then

                                        timer <= timer + 1;

                                    else

                                        state <= LOAD_BUS;

                                        step <= step + 1;
                                    end if;
                            end case;
                        end if;

                    ----------------------------------------------------------------
                    -- DONE
                    -- Inicialización completada
                    ----------------------------------------------------------------
                    when DONE =>

                        init_done <= '1';

                    ----------------------------------------------------------------
                    -- ESTADO NO DEFINIDO
                    ----------------------------------------------------------------
                    when others =>

                        state <= POWER_UP;
                end case;
            end if;
        end if;
    end process;

end architecture;
