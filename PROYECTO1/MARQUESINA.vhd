library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity MARQUESINA is
    generic (
        CLK_FREQ_HZ : integer := 50_000_000
    );
    port (
        clk   : in std_logic;
        rst   : in std_logic;
        start : in std_logic;
        df_trigger : out std_logic;
        LCD_RS : out std_logic;
        LCD_E  : out std_logic;
        LCD_D  : out std_logic_vector(3 downto 0);
		  pwr_ctrl_out : out std_logic
    );
end entity;

architecture RTL of MARQUESINA is

    -- ============================================================
    -- SEÑALES DE TEMPORIZACIÓN
    -- ============================================================
    signal ce_1us : std_logic;

    -- ============================================================
    -- INTERFAZ INIT FSM
    -- ============================================================
    signal init_done : std_logic;
    signal cmd_valid : std_logic;
    signal cmd_rs    : std_logic;
    signal cmd_data  : std_logic_vector(7 downto 0);

    -- ============================================================
    -- INTERFAZ MARQUESINA CTRL
    -- ============================================================
    signal marq_valid    : std_logic;
    signal marq_char     : std_logic_vector(7 downto 0);
    signal marq_line_sel : std_logic; -- 0=L1, 1=L2

    -- ============================================================
    -- SEÑALES DEL DRIVER (POST-MUX)
    -- ============================================================
    signal busy      : std_logic;
    signal mux_valid : std_logic;
    signal mux_rs    : std_logic;
    signal mux_data  : std_logic_vector(7 downto 0);

		-- Mensaje 1: "Me caigo y me levanto" (21 caracteres + 19 espacios)
	 signal LINEA1 : std_logic_vector(319 downto 0) := 
		 x"4D6520636169676F2079206D65206C6576616E746F" & -- "Me caigo y me levanto"
		 x"20202020202020202020202020202020202020";       -- Relleno hasta 40 chars

	-- Mensaje 2: "Julio Cortazar" (14 caracteres + 26 espacios)
	 signal LINEA2 : std_logic_vector(319 downto 0) := 
		 x"4A756C696F20436F7274617A6172" &               -- "Julio Cortazar"
		 x"2020202020202020202020202020202020202020202020202020"; -- Relleno hasta 40 chars

begin
    pwr_ctrl_out <= not rst;
    -- ============================================================
    -- GENERADOR DE TIEMPOS (LCD_Timer)[cite: 5]
    -- ============================================================
    U_TIMER : entity work.LCD_Timer
        generic map (
            CLK_FREQ_HZ => CLK_FREQ_HZ
        )
        port map (
            clk    => clk,
            rst    => rst,
            en     => '1',
            ce_1us => ce_1us
        );


 -- ============================================================
		-- LÓGICA DEL MULTIPLEXOR 
		-- ============================================================
		mux_valid <= cmd_valid when init_done = '0' else marq_valid;
		mux_data  <= cmd_data  when init_done = '0' else marq_char;

		-- RS debe ser dinámico siempre para permitir comandos de posición
		mux_rs    <= cmd_rs    when init_done = '0' else marq_line_sel;

    -- ============================================================
    -- MÓDULO DE INICIALIZACIÓN[cite: 4]
    -- ============================================================
    U_INIT : entity work.lcd_init_fsm
        generic map (
            CLK_FREQ_HZ => CLK_FREQ_HZ
        )
        port map (
            clk       => clk,
            rst       => rst,
            ce_1us    => ce_1us, -- Usa el pulso real de 1us[cite: 5]
            busy      => busy,
            cmd_valid => cmd_valid,
            cmd_rs    => cmd_rs,
            cmd_data  => cmd_data,
            init_done => init_done
        );

 
    U_MARQ : entity work.marquesina_ctrl
        port map (
            clk        => clk,
            rst        => rst,
            ce_1us     => ce_1us,
            start      => start,
            init_done  => init_done,
            busy       => busy,
            char_out   => marq_char,
            -- Se eliminó el puerto 'col' aquí porque ya no existe en la entidad
            line_sel   => marq_line_sel,
            valid      => marq_valid,
				df_trigger => df_trigger,
            LINEA1     => LINEA1, -- Asegúrate de que estas señales existan en tu architecture
            LINEA2     => LINEA2
        );

    -- ============================================================
    -- DRIVER FÍSICO LCD[cite: 4]
    -- ============================================================
    U_DRIVER : entity work.lcd_driver_4bit
        generic map (
            CLK_FREQ_HZ => CLK_FREQ_HZ
        )
        port map (
            clk     => clk,
            rst     => rst,
            valid   => mux_valid,
            char_in => mux_data,
            rs_in   => mux_rs,
            busy    => busy,
            LCD_RS  => LCD_RS,
            LCD_E   => LCD_E,
            LCD_D   => LCD_D
        );



end architecture;