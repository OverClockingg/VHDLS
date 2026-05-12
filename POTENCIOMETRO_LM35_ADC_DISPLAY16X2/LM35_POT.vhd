library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.lcd_pkg.all;

entity LM35_POT is
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
		  AUDIO_IN   : out std_logic;
        sw_arriba  : in  std_logic; -- Para modo Temperatura
        sw_abajo   : in  std_logic; -- Para modo Ángulo
        -- Reset maestro (puedes asignarlo a un switch o botón)
        rst        : in  std_logic;
		  pwr_ctrl_out : out std_logic
    );
end LM35_POT;

architecture Behavioral of LM35_POT is

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
	 signal ascii_cen : std_logic_vector(7 downto 0);
    signal ascii_dec : std_logic_vector(7 downto 0);
    signal ascii_uni : std_logic_vector(7 downto 0);
	 signal current_msg_id : std_logic_vector(3 downto 0);

begin

    LCD_RW <= '0'; -- Escritura permanente en el LCD
	 pwr_ctrl_out <= not rst;
	 ----------------------------------------------------------------------------
    -- LÓGICA DE SELECCIÓN DE MODO (El Cerebro del Top)
    ----------------------------------------------------------------------------
    process(sw_arriba, sw_abajo)
    begin
        if sw_arriba = '1' and sw_abajo = '0' then
            current_msg_id <= "0100"; -- MSG_TEMP
        elsif sw_arriba = '0' and sw_abajo = '1' then
            current_msg_id <= "0101"; -- MSG_POT
        else
            current_msg_id <= "1000"; -- MSG_STANDBY (Centro)
        end if;
    end process;

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
            -- Pasamos el estado de los switches para el cálculo interno
            sw_arriba      => sw_arriba,
            sw_abajo       => sw_abajo,
            wr             => wr,
            rd             => rd,
            clk_adc        => clk_adc,
            -- Salidas de 3 dígitos
            ascii_centenas => ascii_cen,
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
            cmd        => current_msg_id, 
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
    -- 6. TRIGGER PARA DFPLAYER MINI (Implementación Directa)
    ----------------------------------------------------------------------------
    process(clk_50MHz)
        -- Timer para un pulso de 200ms (50MHz * 0.2s)
        variable v_timer : integer range 0 to 10_000_000 := 0;
        variable v_active : std_logic := '0';
    begin
        if rising_edge(clk_50MHz) then
            if rst = '1' then
                v_timer := 0;
                v_active := '0';
                AUDIO_IN <= '0';
            else
                -- DISPARO: Se activa cada 500ms (cuando el ADC refresca)
                -- Solo dispara si NO estamos en Standby
                if ce_500ms = '1' and v_active = '0' and current_msg_id /= "1000" then
                    v_active := '1';
                    v_timer  := 0;
                end if;

                -- Generación del pulso
                if v_active = '1' then
                    AUDIO_IN <= '1'; -- Esto satura el transistor y manda el pin a GND
                    if v_timer < 10_000_000 then
                        v_timer := v_timer + 1;
                    else
                        v_active := '0'; -- Suelta el pin
                    end if;
                else
                    AUDIO_IN <= '0';
                    v_timer  := 0;
                end if;
            end if;
        end if;
    end process;
		  
		  
end Behavioral;