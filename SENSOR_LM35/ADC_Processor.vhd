library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ADC_Processor is
    port (
        clk            : in  std_logic;
        rst            : in  std_logic;
        ce_500ms       : in  std_logic; 
        adc_data       : in  std_logic_vector(7 downto 0);
        intr           : in  std_logic;
        wr             : out std_logic;
        rd             : out std_logic;
        clk_adc        : out std_logic;
        ascii_decenas  : out std_logic_vector(7 downto 0);
        ascii_unidades : out std_logic_vector(7 downto 0)
    );
end ADC_Processor;

architecture Behavioral of ADC_Processor is
    -- FSM de 4 estados reales + 1 de recuperación
    type state_t is (IDLE, START_CONV, WAIT_INTR, READ_DATA, CLEANUP);
    signal state : state_t;

    signal reg_adc      : std_logic_vector(7 downto 0) := (others => '0');
    signal temp_entera  : integer range 0 to 99 := 0;
    signal delay_cnt    : integer range 0 to 1000 := 0; -- Contador más amplio
    signal r_clk_adc    : std_logic := '0';
    signal clk_div      : integer range 0 to 39 := 0;

begin
    -- Generador de clk_adc (Aprox 625KHz)
    process(clk) begin
        if rising_edge(clk) then
            if clk_div = 39 then clk_div <= 0; r_clk_adc <= not r_clk_adc;
            else clk_div <= clk_div + 1; end if;
        end if;
    end process;
    clk_adc <= r_clk_adc;

    -- FSM Robusta
    process(clk, rst)
    begin
        if rst = '1' then
            state <= IDLE;
            wr <= '1'; rd <= '1';
            temp_entera <= 0;
        elsif rising_edge(clk) then
            -- Forzado de seguridad: si no estamos en estados específicos, señales en '1'
            wr <= '1';
            rd <= '1';

            case state is
                when IDLE =>
                    if ce_500ms = '1' then
                        state <= START_CONV;
                        delay_cnt <= 0;
                    end if;

                when START_CONV =>
                    wr <= '0'; -- Pulso WR
                    if delay_cnt < 50 then -- 1us de pulso (Super seguro)
                        delay_cnt <= delay_cnt + 1;
                    else
                        wr <= '1'; -- Subimos WR explícitamente
                        delay_cnt <= 0;
                        state <= WAIT_INTR;
                    end if;

                when WAIT_INTR =>
                    -- Solo avanzamos si INTR baja
                    if intr = '0' then 
                        state <= READ_DATA;
                        delay_cnt <= 0;
                    end if;

                when READ_DATA =>
                    rd <= '0'; -- Bajamos RD para leer
                    if delay_cnt < 100 then -- Esperamos a que el bus sea válido
                        delay_cnt <= delay_cnt + 1;
                    else
                        reg_adc <= adc_data; -- Captura
                        rd <= '1'; -- ¡CRÍTICO! Subimos RD antes de salir
                        state <= CLEANUP;
                        delay_cnt <= 0;
                    end if;

                when CLEANUP =>
                    -- ESTADO VITAL: Esperamos a que INTR vuelva a subir a '1'
                    -- Si el ADC0804 no libera INTR, no salimos de aquí.
                    rd <= '1';
                    wr <= '1';
                    if intr = '1' or delay_cnt > 500 then 
                        -- Si subió INTR o pasó mucho tiempo (timeout), convertimos
                        temp_entera <= (to_integer(unsigned(reg_adc)) * 65) / 100;
                        state <= IDLE;
                    else
                        delay_cnt <= delay_cnt + 1;
                    end if;

                when others => state <= IDLE;
            end case;
        end if;
    end process;

    ascii_decenas  <= std_logic_vector(to_unsigned((temp_entera / 10) + 48, 8));
    ascii_unidades <= std_logic_vector(to_unsigned((temp_entera rem 10) + 48, 8));

end Behavioral;