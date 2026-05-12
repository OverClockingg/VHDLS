--------------------------------------------------------------------------------
-- Institución : Instituto Politécnico Nacional (IPN) - UPIITA
-- Proyecto    : Sistema Inteligente LCD + ADC0804 + LM35/Potenciómetro
-- Archivo     : LM35_POT.vhd
-- Descripción :
-- Este módulo corresponde al TOP LEVEL del sistema completo encargado de:
--
--   1. Inicializar un LCD 16x2
--   2. Leer datos desde un ADC0804
--   3. Procesar información proveniente de:
--        - Sensor LM35
--        - Potenciómetro
--   4. Convertir los datos a formato ASCII
--   5. Mostrar información dinámica en LCD
--   6. Generar disparos de audio mediante DFPlayer Mini
--   7. Administrar modos de operación mediante switches
--
-- El diseño integra múltiples módulos jerárquicos:
--
--   + LCD_Timer
--   + lcd_init_fsm
--   + ADC_Processor
--   + FSM_Mensajes
--   + FSM_LCD
--
-- Funcionalidades principales:
--
--   - Modo temperatura (LM35)
--   - Modo ángulo/potenciómetro
--   - Modo Standby
--   - Refresco automático del LCD
--   - Actualización dinámica sin parpadeo
--   - Generación de audio sincronizado
--   - Multiplexado automático de control LCD
--
-- Arquitectura general:
--
--                 +----------------+
--                 |   LM35_POT    |
--                 +--------+-------+
--                          |
--      +-------------------+-------------------+
--      |                   |                   |
--      v                   v                   v
--  ADC_Processor      FSM_Mensajes        lcd_init_fsm
--      |                   |                   |
--      +-------------------+-------------------+
--                          |
--                          v
--                      FSM_LCD
--                          |
--                          v
--                        LCD
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
entity LM35_POT is
    port (

        ------------------------------------------------------------------------
        -- Reloj principal del sistema
        ------------------------------------------------------------------------
        clk_50MHz : in std_logic;

        ------------------------------------------------------------------------
        -- Interfaz ADC0804
        ------------------------------------------------------------------------

        -- Bus de datos del ADC
        adc_data : in std_logic_vector(7 downto 0);

        -- Fin de conversión del ADC
        intr : in std_logic;

        -- Write ADC
        wr : out std_logic;

        -- Read ADC
        rd : out std_logic;

        -- Clock externo ADC
        clk_adc : out std_logic;

        ------------------------------------------------------------------------
        -- Interfaz LCD 16x2
        ------------------------------------------------------------------------

        LCD_RS : out std_logic;

        LCD_RW : out std_logic;

        LCD_E : out std_logic;

        LCD_D : out std_logic_vector(3 downto 0);

        ------------------------------------------------------------------------
        -- Salida de control hacia DFPlayer/transistor
        ------------------------------------------------------------------------
        AUDIO_IN : out std_logic;

        ------------------------------------------------------------------------
        -- Entradas de selección de modo
        ------------------------------------------------------------------------

        -- Modo temperatura
        sw_arriba : in std_logic;

        -- Modo ángulo/potenciómetro
        sw_abajo : in std_logic;

        ------------------------------------------------------------------------
        -- Reset maestro
        ------------------------------------------------------------------------
        rst : in std_logic;

        ------------------------------------------------------------------------
        -- Control auxiliar de alimentación
        ------------------------------------------------------------------------
        pwr_ctrl_out : out std_logic
    );
end LM35_POT;

--------------------------------------------------------------------------------
-- ARCHITECTURE
--------------------------------------------------------------------------------
architecture Behavioral of LM35_POT is

    ----------------------------------------------------------------------------
    -- SEÑALES DE TEMPORIZACIÓN
    ----------------------------------------------------------------------------

    ------------------------------------------------------------------------
    -- Clock Enable de 1 us
    ------------------------------------------------------------------------
    signal ce_1us : std_logic;

    ------------------------------------------------------------------------
    -- Clock Enable de 1 ms
    ------------------------------------------------------------------------
    signal ce_1ms : std_logic;

    ------------------------------------------------------------------------
    -- Clock Enable de 500 ms
    ------------------------------------------------------------------------
    signal ce_500ms : std_logic;

    ----------------------------------------------------------------------------
    -- CONTROL GENERAL DEL LCD
    ----------------------------------------------------------------------------

    ------------------------------------------------------------------------
    -- Bandera de inicialización completada
    ------------------------------------------------------------------------
    signal init_done : std_logic;

    ------------------------------------------------------------------------
    -- Señal busy del driver LCD
    ------------------------------------------------------------------------
    signal drv_busy : std_logic;

    ------------------------------------------------------------------------
    -- Pulso start para el driver
    ------------------------------------------------------------------------
    signal msg_start : std_logic;

    ------------------------------------------------------------------------
    -- Identificador del mensaje actual
    ------------------------------------------------------------------------
    signal msg_id : std_logic_vector(3 downto 0);

    ----------------------------------------------------------------------------
    -- MULTIPLEXADO DE CONTROL LCD
    ----------------------------------------------------------------------------

    ------------------------------------------------------------------------
    -- Señales provenientes del inicializador
    ------------------------------------------------------------------------
    signal init_rs, init_e : std_logic;

    signal init_d : std_logic_vector(3 downto 0);

    ------------------------------------------------------------------------
    -- Señales provenientes del driver principal
    ------------------------------------------------------------------------
    signal drv_rs, drv_e : std_logic;

    signal drv_d : std_logic_vector(3 downto 0);

    ----------------------------------------------------------------------------
    -- VARIABLES ASCII DINÁMICAS
    ----------------------------------------------------------------------------

    ------------------------------------------------------------------------
    -- Dígito centenas
    ------------------------------------------------------------------------
    signal ascii_cen : std_logic_vector(7 downto 0);

    ------------------------------------------------------------------------
    -- Dígito decenas
    ------------------------------------------------------------------------
    signal ascii_dec : std_logic_vector(7 downto 0);

    ------------------------------------------------------------------------
    -- Dígito unidades
    ------------------------------------------------------------------------
    signal ascii_uni : std_logic_vector(7 downto 0);

    ----------------------------------------------------------------------------
    -- MENSAJE ACTUAL DEL SISTEMA
    ----------------------------------------------------------------------------
    signal current_msg_id : std_logic_vector(3 downto 0);

begin

    ----------------------------------------------------------------------------
    -- LCD EN MODO ESCRITURA PERMANENTE
    ----------------------------------------------------------------------------
    LCD_RW <= '0';

    ----------------------------------------------------------------------------
    -- CONTROL AUXILIAR DE ENERGÍA
    ----------------------------------------------------------------------------
    pwr_ctrl_out <= not rst;

    ----------------------------------------------------------------------------
    -- PROCESO: SELECCIÓN DE MODO
    ----------------------------------------------------------------------------
    -- Determina el mensaje actual dependiendo del estado
    -- de los switches físicos.
    ----------------------------------------------------------------------------
    process(sw_arriba, sw_abajo)
    begin

        ------------------------------------------------------------------------
        -- MODO TEMPERATURA
        ------------------------------------------------------------------------
        if sw_arriba = '1' and sw_abajo = '0' then

            current_msg_id <= "0100";

        ------------------------------------------------------------------------
        -- MODO POTENCIÓMETRO / ÁNGULO
        ------------------------------------------------------------------------
        elsif sw_arriba = '0' and sw_abajo = '1' then

            current_msg_id <= "0101";

        ------------------------------------------------------------------------
        -- MODO STANDBY
        ------------------------------------------------------------------------
        else

            current_msg_id <= "1000";
        end if;
    end process;

    ----------------------------------------------------------------------------
    -- MULTIPLEXOR DE CONTROL LCD
    ----------------------------------------------------------------------------
    -- Durante init_done='0':
    --      El LCD es controlado por lcd_init_fsm
    --
    -- Durante init_done='1':
    --      El LCD es controlado por FSM_LCD
    ----------------------------------------------------------------------------
    LCD_RS <= init_rs when init_done = '0' else drv_rs;

    LCD_E <= init_e when init_done = '0' else drv_e;

    LCD_D <= init_d when init_done = '0' else drv_d;

    ----------------------------------------------------------------------------
    -- 1. BASE DE TIEMPO
    ----------------------------------------------------------------------------

    ----------------------------------------------------------------------------
    -- TIMER DE 1 us
    ----------------------------------------------------------------------------
    -- Utilizado por:
    --   + lcd_init_fsm
    --   + FSM_LCD
    ----------------------------------------------------------------------------
    u_timer_1us : entity work.LCD_Timer
        generic map (
            CLK_FREQ_HZ => 50_000_000,
            RESOLUTION_US => 1
        )
        port map (
            clk => clk_50MHz,
            rst => rst,
            en => '1',
            ce_1us => ce_1us
        );

    ----------------------------------------------------------------------------
    -- TIMER DE 1 ms
    ----------------------------------------------------------------------------
    -- Utilizado para refresco dinámico de mensajes.
    ----------------------------------------------------------------------------
    u_timer_1ms : entity work.LCD_Timer
        generic map (
            CLK_FREQ_HZ => 50_000_000,
            RESOLUTION_US => 1000
        )
        port map (
            clk => clk_50MHz,
            rst => rst,
            en => '1',
            ce_1us => ce_1ms
        );

    ----------------------------------------------------------------------------
    -- TIMER DE 500 ms
    ----------------------------------------------------------------------------
    -- Utilizado para:
    --   + Actualización ADC
    --   + Trigger de audio
    ----------------------------------------------------------------------------
    u_timer_500ms : entity work.LCD_Timer
        generic map (
            CLK_FREQ_HZ => 50_000_000,
            RESOLUTION_US => 500000
        )
        port map (
            clk => clk_50MHz,
            rst => rst,
            en => '1',
            ce_1us => ce_500ms
        );

    ----------------------------------------------------------------------------
    -- 2. FSM DE INICIALIZACIÓN LCD
    ----------------------------------------------------------------------------
    u_init : entity work.lcd_init_fsm
        generic map (
            CLK_FREQ_HZ => 50_000_000
        )
        port map (
            clk       => clk_50MHz,
            rst       => rst,
            ce_1us    => ce_1us,
            LCD_RS    => init_rs,
            LCD_E     => init_e,
            LCD_D     => init_d,
            init_done => init_done
        );

    ----------------------------------------------------------------------------
    -- 3. PROCESADOR ADC
    ----------------------------------------------------------------------------
    -- Responsable de:
    --   + Conversión ADC0804
    --   + Escalamiento matemático
    --   + Conversión ASCII
    ----------------------------------------------------------------------------
    u_adc_proc : entity work.ADC_Processor
        port map (
            clk            => clk_50MHz,
            rst            => rst,
            ce_500ms       => ce_500ms,
            adc_data       => adc_data,
            intr           => intr,

            sw_arriba      => sw_arriba,
            sw_abajo       => sw_abajo,

            wr             => wr,
            rd             => rd,
            clk_adc        => clk_adc,

            ascii_centenas => ascii_cen,
            ascii_decenas  => ascii_dec,
            ascii_unidades => ascii_uni
        );

    ----------------------------------------------------------------------------
    -- 4. GESTOR DE MENSAJES
    ----------------------------------------------------------------------------
    -- Implementa el Handshake entre:
    --   + Lógica de control
    --   + Driver LCD
    ----------------------------------------------------------------------------
    u_msg_ctrl : entity work.FSM_Mensajes
        port map (
            clk        => clk_50MHz,
            rst        => rst,
            ce_refresh => ce_1ms,
            cmd        => current_msg_id,
            ready      => init_done,
            busy_drv   => drv_busy,
            start_drv  => msg_start,
            msg_id     => msg_id
        );

    ----------------------------------------------------------------------------
    -- 5. DRIVER LCD
    ----------------------------------------------------------------------------
    -- Generador físico de señales hacia el LCD.
    ----------------------------------------------------------------------------
    u_driver : entity work.FSM_LCD
        generic map (
            CLK_FREQ => 50_000_000
        )
        port map (
            clk            => clk_50MHz,
            rst            => rst,
            start          => msg_start,
            msg_id         => msg_id,

            ascii_centenas => ascii_cen,
            ascii_decenas  => ascii_dec,
            ascii_unidades => ascii_uni,

            LCD_RS         => drv_rs,
            LCD_E          => drv_e,
            LCD_D          => drv_d,

            busy           => drv_busy,
            done           => open
        );

    ----------------------------------------------------------------------------
    -- 6. TRIGGER PARA DFPLAYER MINI
    ----------------------------------------------------------------------------
    -- Genera un pulso digital de aproximadamente 200 ms
    -- sincronizado con la actualización del ADC.
    --
    -- Funcionamiento:
    --
    --   + Se activa cada 500 ms
    --   + Solo funciona fuera de modo Standby
    --   + AUDIO_IN controla un transistor externo
    ----------------------------------------------------------------------------
    process(clk_50MHz)

        ------------------------------------------------------------------------
        -- Timer interno de duración del pulso
        ------------------------------------------------------------------------
        variable v_timer : integer range 0 to 10_000_000 := 0;

        ------------------------------------------------------------------------
        -- Estado interno del pulso
        ------------------------------------------------------------------------
        variable v_active : std_logic := '0';

    begin

        if rising_edge(clk_50MHz) then

            --------------------------------------------------------------------
            -- RESET
            --------------------------------------------------------------------
            if rst = '1' then

                v_timer := 0;

                v_active := '0';

                AUDIO_IN <= '0';

            else

                ----------------------------------------------------------------
                -- DISPARO DEL AUDIO
                ----------------------------------------------------------------
                if ce_500ms = '1'
                   and v_active = '0'
                   and current_msg_id /= "1000" then

                    v_active := '1';

                    v_timer := 0;
                end if;

                ----------------------------------------------------------------
                -- GENERACIÓN DEL PULSO
                ----------------------------------------------------------------
                if v_active = '1' then

                    ----------------------------------------------------------------
                    -- Activa transistor
                    ----------------------------------------------------------------
                    AUDIO_IN <= '1';

                    if v_timer < 10_000_000 then

                        v_timer := v_timer + 1;

                    else

                        ----------------------------------------------------------------
                        -- Fin del pulso
                        ----------------------------------------------------------------
                        v_active := '0';
                    end if;

                else

                    ----------------------------------------------------------------
                    -- Estado inactivo
                    ----------------------------------------------------------------
                    AUDIO_IN <= '0';

                    v_timer := 0;
                end if;
            end if;
        end if;
    end process;

end Behavioral;
