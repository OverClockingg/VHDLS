--------------------------------------------------------------------------------
-- Institución : Instituto Politécnico Nacional (IPN) - UPIITA
-- Proyecto    : Procesador de Datos ADC y Conversión ASCII
-- Archivo     : ADC_Processor.vhd
-- Descripción :
-- Este módulo implementa la lógica de control y procesamiento para un
-- convertidor analógico-digital (ADC) de 8 bits.
--
-- El sistema realiza:
--
--   1. Generación del reloj para el ADC
--   2. Control de señales WR y RD
--   3. Secuencia de adquisición mediante FSM
--   4. Captura de datos digitales del ADC
--   5. Conversión matemática según el modo seleccionado
--   6. Conversión final a caracteres ASCII
--
-- El módulo soporta dos modos de operación seleccionados mediante un
-- switch de tres posiciones:
--
--   - Modo LM35:
--       Conversión de temperatura
--
--   - Modo Potenciómetro:
--       Conversión proporcional de voltaje
--
--   - Posición central:
--       Salida forzada a cero
--
-- La salida final se entrega en formato ASCII de tres dígitos para
-- facilitar su visualización en sistemas LCD.
--
-- Arquitectura:
--
--   +-------------------+
--   | Generador clk_adc |
--   +-------------------+
--              |
--              v
--   +-------------------+
--   | FSM ADC Control   |
--   +-------------------+
--              |
--              v
--   +-------------------+
--   | Conversión Escala |
--   +-------------------+
--              |
--              v
--   +-------------------+
--   | Conversión ASCII  |
--   +-------------------+
--
-- Dependencias:
--   - IEEE.STD_LOGIC_1164
--   - IEEE.NUMERIC_STD
--
-- Autor       :
-- Fecha       :
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

--------------------------------------------------------------------------------
-- ENTITY
--------------------------------------------------------------------------------
entity ADC_Processor is
    port (

        ------------------------------------------------------------------------
        -- Entradas principales
        ------------------------------------------------------------------------
        clk : in std_logic; -- Reloj principal del sistema

        rst : in std_logic; -- Reset síncrono

        ------------------------------------------------------------------------
        -- Habilitación periódica de muestreo
        ------------------------------------------------------------------------
        -- Pulso generado externamente cada 500 ms
        ------------------------------------------------------------------------
        ce_500ms : in std_logic;

        ------------------------------------------------------------------------
        -- Datos provenientes del ADC
        ------------------------------------------------------------------------
        adc_data : in std_logic_vector(7 downto 0);

        ------------------------------------------------------------------------
        -- Señal de interrupción/conversión terminada del ADC
        ------------------------------------------------------------------------
        intr : in std_logic;

        ------------------------------------------------------------------------
        -- Entradas del selector de modo
        ------------------------------------------------------------------------

        -- Selección modo LM35
        sw_arriba : in std_logic;

        -- Selección modo Potenciómetro
        sw_abajo : in std_logic;

        ------------------------------------------------------------------------
        -- Señales de control hacia el ADC
        ------------------------------------------------------------------------

        -- Write Start Conversion
        wr : out std_logic;

        -- Read Enable
        rd : out std_logic;

        -- Clock del ADC
        clk_adc : out std_logic;

        ------------------------------------------------------------------------
        -- Salidas ASCII de 3 dígitos
        ------------------------------------------------------------------------
        ascii_centenas : out std_logic_vector(7 downto 0);

        ascii_decenas : out std_logic_vector(7 downto 0);

        ascii_unidades : out std_logic_vector(7 downto 0)
    );
end ADC_Processor;

--------------------------------------------------------------------------------
-- ARCHITECTURE
--------------------------------------------------------------------------------
architecture Behavioral of ADC_Processor is

    ----------------------------------------------------------------------------
    -- DEFINICIÓN DE ESTADOS DE LA FSM
    ----------------------------------------------------------------------------
    --
    -- IDLE:
    --   Espera nuevo ciclo de muestreo
    --
    -- START_CONV:
    --   Genera pulso WR para iniciar conversión ADC
    --
    -- WAIT_INTR:
    --   Espera finalización de conversión
    --
    -- READ_DATA:
    --   Lee el valor digital desde el ADC
    --
    -- CLEANUP:
    --   Procesa y convierte el valor leído
    ----------------------------------------------------------------------------
    type state_t is (
        IDLE,
        START_CONV,
        WAIT_INTR,
        READ_DATA,
        CLEANUP
    );

    ----------------------------------------------------------------------------
    -- REGISTRO DE ESTADO
    ----------------------------------------------------------------------------
    signal state : state_t;

    ----------------------------------------------------------------------------
    -- REGISTROS INTERNOS
    ----------------------------------------------------------------------------

    ------------------------------------------------------------------------
    -- Registro de captura del dato ADC
    ------------------------------------------------------------------------
    signal reg_adc : std_logic_vector(7 downto 0) := (others => '0');

    ------------------------------------------------------------------------
    -- Valor entero escalado final
    ------------------------------------------------------------------------
    signal valor_entero : integer range 0 to 270 := 0;

    ------------------------------------------------------------------------
    -- Contador auxiliar para retardos FSM
    ------------------------------------------------------------------------
    signal delay_cnt : integer range 0 to 1000 := 0;

    ----------------------------------------------------------------------------
    -- GENERADOR DE RELOJ PARA ADC
    ----------------------------------------------------------------------------

    ------------------------------------------------------------------------
    -- Registro interno del reloj ADC
    ------------------------------------------------------------------------
    signal r_clk_adc : std_logic := '0';

    ------------------------------------------------------------------------
    -- Divisor de frecuencia
    ------------------------------------------------------------------------
    signal clk_div : integer range 0 to 39 := 0;

begin

    ----------------------------------------------------------------------------
    -- GENERADOR DE clk_adc
    ----------------------------------------------------------------------------
    -- Implementa un divisor de frecuencia para generar el reloj del ADC.
    --
    -- Con reloj principal de 50 MHz:
    --
    --   Toggle cada 40 ciclos
    --
    -- Frecuencia aproximada:
    --
    --   50 MHz / (2 * 40)
    --   ≈ 625 kHz
    ----------------------------------------------------------------------------
    process(clk)
    begin

        if rising_edge(clk) then

            if clk_div = 39 then

                clk_div <= 0;

                r_clk_adc <= not r_clk_adc;

            else

                clk_div <= clk_div + 1;
            end if;
        end if;
    end process;

    ----------------------------------------------------------------------------
    -- ASIGNACIÓN DE SALIDA DEL CLOCK ADC
    ----------------------------------------------------------------------------
    clk_adc <= r_clk_adc;

    ----------------------------------------------------------------------------
    -- FSM DE CONTROL Y LECTURA DEL ADC
    ----------------------------------------------------------------------------
    process(clk, rst)
    begin

        ------------------------------------------------------------------------
        -- RESET
        ------------------------------------------------------------------------
        if rst = '1' then

            state <= IDLE;

            wr <= '1';

            rd <= '1';

            valor_entero <= 0;

        ----------------------------------------------------------------------------
        -- FLANCO POSITIVO DE RELOJ
        ----------------------------------------------------------------------------
        elsif rising_edge(clk) then

            --------------------------------------------------------------------
            -- Valores por defecto
            --------------------------------------------------------------------
            wr <= '1';

            rd <= '1';

            --------------------------------------------------------------------
            -- MÁQUINA DE ESTADOS
            --------------------------------------------------------------------
            case state is

                ----------------------------------------------------------------
                -- IDLE
                -- Espera nuevo periodo de adquisición
                ----------------------------------------------------------------
                when IDLE =>

                    if ce_500ms = '1' then

                        state <= START_CONV;

                        delay_cnt <= 0;
                    end if;

                ----------------------------------------------------------------
                -- START_CONV
                -- Genera pulso WR para iniciar conversión ADC
                ----------------------------------------------------------------
                when START_CONV =>

                    wr <= '0';

                    if delay_cnt < 50 then

                        delay_cnt <= delay_cnt + 1;

                    else

                        wr <= '1';

                        delay_cnt <= 0;

                        state <= WAIT_INTR;
                    end if;

                ----------------------------------------------------------------
                -- WAIT_INTR
                -- Espera a que el ADC finalice la conversión
                ----------------------------------------------------------------
                when WAIT_INTR =>

                    ----------------------------------------------------------------
                    -- intr = '0' indica conversión terminada
                    ----------------------------------------------------------------
                    if intr = '0' then

                        state <= READ_DATA;

                        delay_cnt <= 0;
                    end if;

                ----------------------------------------------------------------
                -- READ_DATA
                -- Lee el dato digital proveniente del ADC
                ----------------------------------------------------------------
                when READ_DATA =>

                    rd <= '0';

                    if delay_cnt < 100 then

                        delay_cnt <= delay_cnt + 1;

                    else

                        ----------------------------------------------------------------
                        -- Captura del dato ADC
                        ----------------------------------------------------------------
                        reg_adc <= adc_data;

                        rd <= '1';

                        state <= CLEANUP;

                        delay_cnt <= 0;
                    end if;

                ----------------------------------------------------------------
                -- CLEANUP
                -- Conversión matemática y escalamiento
                ----------------------------------------------------------------
                when CLEANUP =>

                    rd <= '1';

                    wr <= '1';

                    if intr = '1' or delay_cnt > 500 then

                        ----------------------------------------------------------------
                        -- MODO LM35
                        ----------------------------------------------------------------
                        if sw_arriba = '1' then

                            --------------------------------------------------------
                            -- Conversión aproximada de temperatura
                            --
                            -- Fórmula:
                            --   N * 13 / 19
                            --------------------------------------------------------
                            valor_entero <=
                                (to_integer(unsigned(reg_adc)) * 13) / 19;

                        ----------------------------------------------------------------
                        -- MODO POTENCIÓMETRO
                        ----------------------------------------------------------------
                        elsif sw_abajo = '1' then

                            --------------------------------------------------------
                            -- Conversión proporcional de voltaje
                            --
                            -- Fórmula:
                            --   N * 90 / 77
                            --------------------------------------------------------
                            valor_entero <=
                                (to_integer(unsigned(reg_adc)) * 90) / 77;

                        ----------------------------------------------------------------
                        -- POSICIÓN CENTRAL
                        ----------------------------------------------------------------
                        else

                            --------------------------------------------------------
                            -- Fuerza salida a cero
                            --------------------------------------------------------
                            valor_entero <= 0;
                        end if;

                        ----------------------------------------------------------------
                        -- Reinicio FSM
                        ----------------------------------------------------------------
                        state <= IDLE;

                    else

                        delay_cnt <= delay_cnt + 1;
                    end if;

                ----------------------------------------------------------------
                -- ESTADO NO DEFINIDO
                ----------------------------------------------------------------
                when others =>

                    state <= IDLE;
            end case;
        end if;
    end process;

    ----------------------------------------------------------------------------
    -- CONVERSIÓN ASCII
    ----------------------------------------------------------------------------
    -- Convierte el valor entero procesado en tres caracteres ASCII:
    --
    --   centenas
    --   decenas
    --   unidades
    --
    -- Se suma 48 decimal para convertir:
    --
    --   0 -> '0'
    --   1 -> '1'
    --   ...
    --   9 -> '9'
    ----------------------------------------------------------------------------

    ----------------------------------------------------------------------------
    -- Centenas ASCII
    ----------------------------------------------------------------------------
    ascii_centenas <=
        std_logic_vector(
            to_unsigned((valor_entero / 100) + 48, 8)
        );

    ----------------------------------------------------------------------------
    -- Decenas ASCII
    ----------------------------------------------------------------------------
    ascii_decenas <=
        std_logic_vector(
            to_unsigned(((valor_entero / 10) rem 10) + 48, 8)
        );

    ----------------------------------------------------------------------------
    -- Unidades ASCII
    ----------------------------------------------------------------------------
    ascii_unidades <=
        std_logic_vector(
            to_unsigned((valor_entero rem 10) + 48, 8)
        );

end Behavioral;
