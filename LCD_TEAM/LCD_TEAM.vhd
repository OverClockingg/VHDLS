--------------------------------------------------------------------------------
-- Institución : Instituto Politécnico Nacional (IPN) - UPIITA
-- Proyecto    : Sistema de Control LCD 16x2
-- Archivo     : LCD_TEAM.vhd
-- Descripción :
-- Este módulo corresponde al nivel superior (Top Level) del sistema de
-- control para un display LCD 16x2 compatible con el controlador HD44780
-- operando en modo de 4 bits.
--
-- El módulo integra todos los bloques funcionales necesarios para:
--
--   1. Generar la base de tiempo del sistema
--   2. Inicializar correctamente el LCD
--   3. Gestionar mensajes de alto nivel
--   4. Controlar el protocolo físico de escritura
--   5. Multiplexar automáticamente el control del LCD
--
-- Arquitectura general:
--
--   +-------------------+
--   |   LCD_Timer       |
--   +-------------------+
--              |
--              v
--   +-------------------+
--   | lcd_init_fsm      |
--   +-------------------+
--              |
--              v
--   +-------------------+
--   | FSM_Mensajes      |
--   +-------------------+
--              |
--              v
--   +-------------------+
--   | FSM_LCD           |
--   +-------------------+
--              |
--              v
--           LCD 16x2
--
-- Funcionamiento:
--
-- Durante el arranque, el módulo lcd_init_fsm tiene control total de las
-- líneas físicas del LCD para ejecutar la secuencia de inicialización.
--
-- Una vez completada la inicialización:
--
--   - init_done se activa
--   - El control pasa automáticamente al driver FSM_LCD
--   - FSM_Mensajes administra el envío de mensajes
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
entity LCD_TEAM is
    port(

        ------------------------------------------------------------------------
        -- Entradas principales
        ------------------------------------------------------------------------
        clk : in std_logic; -- Reloj principal del sistema
        rst : in std_logic; -- Reset general

        ------------------------------------------------------------------------
        -- Interfaz física hacia el LCD
        ------------------------------------------------------------------------
        LCD_RS : out std_logic;                     -- Registro/Dato
        LCD_RW : out std_logic;                     -- Lectura/Escritura
        LCD_E  : out std_logic;                     -- Enable
        LCD_D  : out std_logic_vector(3 downto 0)  -- Bus de datos de 4 bits
    );
end LCD_TEAM;

--------------------------------------------------------------------------------
-- ARCHITECTURE
--------------------------------------------------------------------------------
architecture Behavioral of LCD_TEAM is

    ----------------------------------------------------------------------------
    -- SEÑALES DE CONTROL DE HARDWARE
    ----------------------------------------------------------------------------

    -- Pulso de habilitación cada 1 us generado por LCD_Timer
    signal ce_1us : std_logic;

    -- Señal que indica que la inicialización terminó correctamente
    signal init_done : std_logic;

    ----------------------------------------------------------------------------
    -- Señales provenientes del driver FSM_LCD
    ----------------------------------------------------------------------------
    signal drv_rs   : std_logic;
    signal drv_e    : std_logic;

    signal drv_d : std_logic_vector(3 downto 0);

    -- Señal busy del driver LCD
    signal drv_busy : std_logic;

    ----------------------------------------------------------------------------
    -- Señales de comunicación con FSM_Mensajes
    ----------------------------------------------------------------------------

    -- Identificador del mensaje seleccionado
    signal msg_id : std_logic_vector(3 downto 0);

    -- Pulso de inicio para FSM_LCD
    signal msg_start : std_logic;

    ----------------------------------------------------------------------------
    -- Señales provenientes del inicializador LCD
    ----------------------------------------------------------------------------
    signal init_rs : std_logic;
    signal init_e  : std_logic;

    signal init_d : std_logic_vector(3 downto 0);

    ----------------------------------------------------------------------------
    -- Señales auxiliares de flujo
    ----------------------------------------------------------------------------

    signal cmd_final : std_logic_vector(3 downto 0);

    signal secuencia_ok : std_logic;

begin

    ----------------------------------------------------------------------------
    -- CONFIGURACIÓN DEL LCD
    ----------------------------------------------------------------------------

    ------------------------------------------------------------------------
    -- LCD_RW se fija permanentemente en escritura
    -- El sistema nunca realiza lecturas desde el LCD
    ------------------------------------------------------------------------
    LCD_RW <= '0';

    ----------------------------------------------------------------------------
    -- MULTIPLEXADO DE PINES FÍSICOS
    ----------------------------------------------------------------------------
    -- Durante la inicialización:
    --   El control pertenece a lcd_init_fsm
    --
    -- Después de init_done:
    --   El control pasa automáticamente a FSM_LCD
    ----------------------------------------------------------------------------

    LCD_RS <= init_rs when init_done = '0' else drv_rs;

    LCD_E  <= init_e  when init_done = '0' else drv_e;

    LCD_D  <= init_d  when init_done = '0' else drv_d;

    ----------------------------------------------------------------------------
    -- 1. BASE DE TIEMPO
    ----------------------------------------------------------------------------
    -- Genera una señal de habilitación cada 1 us.
    -- Esta señal es utilizada por los módulos dependientes de temporización.
    ----------------------------------------------------------------------------
    u_timer : entity work.LCD_Timer
        generic map (
            CLK_FREQ_HZ => 50_000_000
        )
        port map (
            clk     => clk,
            rst     => rst,
            en      => '1',
            ce_1us  => ce_1us
        );

    ----------------------------------------------------------------------------
    -- 2. FSM DE INICIALIZACIÓN DEL LCD
    ----------------------------------------------------------------------------
    -- Ejecuta la secuencia obligatoria de arranque del controlador HD44780:
    --
    --   - Configuración modo 4 bits
    --   - Configuración de display
    --   - Encendido del cursor/display
    --   - Limpieza inicial
    --   - Entry mode
    ----------------------------------------------------------------------------
    u_init : entity work.lcd_init_fsm
        generic map (
            CLK_FREQ_HZ => 50_000_000
        )
        port map (
            clk       => clk,
            rst       => rst,
            ce_1us    => ce_1us,

            LCD_RS    => init_rs,
            LCD_E     => init_e,
            LCD_D     => init_d,

            init_done => init_done
        );

    ----------------------------------------------------------------------------
    -- 3. GESTOR DE MENSAJES
    ----------------------------------------------------------------------------
    -- Administra la lógica de envío de mensajes al driver LCD.
    --
    -- Funciones:
    --   - Detectar nuevos mensajes
    --   - Evitar retransmisiones
    --   - Coordinar la comunicación con FSM_LCD
    ----------------------------------------------------------------------------
    u_msg_ctrl : entity work.FSM_Mensajes
        port map (
            clk       => clk,
            rst       => rst,

            --------------------------------------------------------------------
            -- Mensaje fijo utilizado en este diseño
            --------------------------------------------------------------------
            cmd       => "1111",

            --------------------------------------------------------------------
            -- El gestor solo opera cuando el LCD ya fue inicializado
            --------------------------------------------------------------------
            ready     => init_done,

            --------------------------------------------------------------------
            -- Señal busy proveniente del driver LCD
            --------------------------------------------------------------------
            busy_drv  => drv_busy,

            --------------------------------------------------------------------
            -- Pulso de inicio hacia FSM_LCD
            --------------------------------------------------------------------
            start_drv => msg_start,

            --------------------------------------------------------------------
            -- ID estabilizado del mensaje
            --------------------------------------------------------------------
            msg_id    => msg_id
        );

    ----------------------------------------------------------------------------
    -- 4. DRIVER LCD DE BAJO NIVEL
    ----------------------------------------------------------------------------
    -- Este módulo implementa el protocolo físico de escritura hacia el LCD:
    --
    --   - Envío de comandos
    --   - Envío de caracteres
    --   - Generación de pulsos Enable
    --   - Manejo de tiempos internos del LCD
    --   - Control de renglones
    ----------------------------------------------------------------------------
    u_driver : entity work.FSM_LCD
        generic map (
            CLK_FREQ => 50_000_000
        )
        port map (

            --------------------------------------------------------------------
            -- Señales principales
            --------------------------------------------------------------------
            clk    => clk,
            rst    => rst,

            --------------------------------------------------------------------
            -- Control de inicio y mensaje
            --------------------------------------------------------------------
            start  => msg_start,
            msg_id => msg_id,

            --------------------------------------------------------------------
            -- Interfaz física hacia LCD
            --------------------------------------------------------------------
            LCD_RS => drv_rs,
            LCD_E  => drv_e,
            LCD_D  => drv_d,

            --------------------------------------------------------------------
            -- Señales de estado
            --------------------------------------------------------------------
            busy   => drv_busy,

            --------------------------------------------------------------------
            -- done no se utiliza en este nivel
            --------------------------------------------------------------------
            done   => open
        );

end Behavioral;
