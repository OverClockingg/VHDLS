library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.lcd_pkg.all;

entity Temperatura_Display is
    port (
        clk_50MHz  : in  std_logic;
        -- Pines físicos hacia el ADC0804 (Nombres respetados del diagrama)
        adc_data   : in  std_logic_vector(7 downto 0);
        intr       : in  std_logic;
        wr         : out std_logic;
        rd         : out std_logic;
        clk_adc    : out std_logic;
        
        -- Pines físicos hacia el LCD 16x2
        LCD_RS     : out std_logic;
        LCD_RW     : out std_logic;
        LCD_E      : out std_logic;
        LCD_D      : out std_logic_vector(3 downto 0);
        
        -- Reset maestro (puedes asignarlo a un switch o botón)
        rst        : in  std_logic
    );
end Temperatura_Display;

architecture Behavioral of Temperatura_Display is

    -- Señales de interconexión interna
    signal ce_1us       : std_logic;
    signal ce_1ms       : std_logic;
	 signal ce_500ms     : std_logic;
    signal init_done    : std_logic;
    signal drv_busy     : std_logic;
    signal msg_start    : std_logic;
    signal msg_id       : std_logic_vector(3 downto 0);
    
    -- Señales para el multiplexado de hardware
    signal init_rs, init_e : std_logic;
    signal init_d          : std_logic_vector(3 downto 0);
    signal drv_rs, drv_e   : std_logic;
    signal drv_d           : std_logic_vector(3 downto 0);

    -- Señales de datos dinámicos del termómetro
    signal ascii_dec : std_logic_vector(7 downto 0);
    signal ascii_uni : std_logic_vector(7 downto 0);

begin

    LCD_RW <= '0'; -- Escritura permanente en el LCD

    ----------------------------------------------------------------------------
    -- MULTIPLEXOR DE CONTROL DE PINES (Init vs Driver)
    ----------------------------------------------------------------------------
    LCD_RS <= init_rs when init_done = '0' else drv_rs;
    LCD_E  <= init_e  when init_done = '0' else drv_e;
    LCD_D  <= init_d  when init_done = '0' else drv_d;

    ----------------------------------------------------------------------------
    -- 1. BASE DE TIEMPO (Timers)
    ----------------------------------------------------------------------------
    -- Generador de 1us para el Driver y la Inicialización
    u_timer_1us : entity work.LCD_Timer
        generic map ( CLK_FREQ_HZ => 50_000_000, RESOLUTION_US => 1 )
        port map ( clk => clk_50MHz, rst => rst, en => '1', ce_1us => ce_1us );

    -- Generador de 1ms para el control de refresco del termómetro
    u_timer_1ms : entity work.LCD_Timer
        generic map ( CLK_FREQ_HZ => 50_000_000, RESOLUTION_US => 1000 )
        port map ( clk => clk_50MHz, rst => rst, en => '1', ce_1us => ce_1ms );
		  
	 u_timer_500ms : entity work.LCD_Timer
        generic map ( CLK_FREQ_HZ => 50_000_000, RESOLUTION_US => 500000 )
        port map ( clk => clk_50MHz, rst => rst, en => '1', ce_1us => ce_500ms );
		  
	

    ----------------------------------------------------------------------------
    -- 2. INICIALIZACIÓN
    ----------------------------------------------------------------------------
    u_init : entity work.lcd_init_fsm
        generic map ( CLK_FREQ_HZ => 50_000_000 )
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
    -- 3. PROCESADOR ADC (LM35)
    ----------------------------------------------------------------------------
    u_adc_proc : entity work.ADC_Processor
        port map (
            clk            => clk_50MHz,
            rst            => rst,
            ce_500ms       => ce_500ms,
            adc_data       => adc_data,
            intr           => intr,
            wr             => wr,
            rd             => rd,
            clk_adc        => clk_adc,
            ascii_decenas  => ascii_dec,
            ascii_unidades => ascii_uni
        );

    ----------------------------------------------------------------------------
    -- 4. GESTOR DE MENSAJES (Handshake)
    ----------------------------------------------------------------------------
    u_msg_ctrl : entity work.FSM_Mensajes
        port map (
            clk        => clk_50MHz,
            rst        => rst,
            ce_refresh => ce_1ms,
            cmd        => "0100", -- ID 4: "TEMPERATURA: XX C"
            ready      => init_done,
            busy_drv   => drv_busy,
            start_drv  => msg_start,
            msg_id     => msg_id
        );

    ----------------------------------------------------------------------------
    -- 5. DRIVER DE BAJO NIVEL (Generador de señales LCD)
    ----------------------------------------------------------------------------
    u_driver : entity work.FSM_LCD
        generic map ( CLK_FREQ => 50_000_000 )
        port map (
            clk            => clk_50MHz,
            rst            => rst,
            start          => msg_start,
            msg_id         => msg_id,
            ascii_decenas  => ascii_dec, -- Dato dinámico inyectado
            ascii_unidades => ascii_uni, -- Dato dinámico inyectado
            LCD_RS         => drv_rs,
            LCD_E          => drv_e,
            LCD_D          => drv_d,
            busy           => drv_busy,
            done           => open
        );

end Behavioral;