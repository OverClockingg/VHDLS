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
        -- Entradas del lado digital del Switch
        sw_arriba      : in  std_logic; 
        sw_abajo       : in  std_logic;
        
        wr             : out std_logic;
        rd             : out std_logic;
        clk_adc        : out std_logic;
        -- Salidas ASCII de 3 dígitos
        ascii_centenas : out std_logic_vector(7 downto 0);
        ascii_decenas  : out std_logic_vector(7 downto 0);
        ascii_unidades : out std_logic_vector(7 downto 0)
    );
end ADC_Processor;

architecture Behavioral of ADC_Processor is
    type state_t is (IDLE, START_CONV, WAIT_INTR, READ_DATA, CLEANUP);
    signal state : state_t;

    signal reg_adc      : std_logic_vector(7 downto 0) := (others => '0');
    signal valor_entero : integer range 0 to 270 := 0;
    signal delay_cnt    : integer range 0 to 1000 := 0;
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

    -- FSM de lectura del ADC
    process(clk, rst)
    begin
        if rst = '1' then
            state <= IDLE;
            wr <= '1'; rd <= '1';
            valor_entero <= 0;
        elsif rising_edge(clk) then
            wr <= '1'; rd <= '1';

            case state is
                when IDLE =>
                    if ce_500ms = '1' then
                        state <= START_CONV;
                        delay_cnt <= 0;
                    end if;

                when START_CONV =>
                    wr <= '0';
                    if delay_cnt < 50 then 
                        delay_cnt <= delay_cnt + 1;
                    else
                        wr <= '1';
                        delay_cnt <= 0;
                        state <= WAIT_INTR;
                    end if;

                when WAIT_INTR =>
                    if intr = '0' then 
                        state <= READ_DATA;
                        delay_cnt <= 0;
                    end if;

                when READ_DATA =>
                    rd <= '0';
                    if delay_cnt < 100 then
                        delay_cnt <= delay_cnt + 1;
                    else
                        reg_adc <= adc_data;
                        rd <= '1';
                        state <= CLEANUP;
                        delay_cnt <= 0;
                    end if;

                when CLEANUP =>
                    rd <= '1';
						  wr <= '1';
                    if intr = '1' or delay_cnt > 500 then
                        -- LÓGICA DE CONVERSIÓN SEGÚN EL SWITCH
                        if sw_arriba = '1' then
                            -- MODO LM35 (G=3): N * 65 / 100
                            valor_entero <= (to_integer(unsigned(reg_adc)) * 13) / 19;
                        elsif sw_abajo = '1' then
                            -- MODO POT (Vmax 4.594 -> Nmax 234): N * 15 / 13
                            valor_entero <= (to_integer(unsigned(reg_adc)) * 90) / 77;
                        else
                            -- POSICIÓN CENTRAL: Forzamos a cero
                            valor_entero <= 0;
                        end if;
                        state <= IDLE;
                    else
                        delay_cnt <= delay_cnt + 1;
                    end if;

                when others => state <= IDLE;
            end case;
        end if;
    end process;

    -- Descomposición ASCII de 3 dígitos
    ascii_centenas <= std_logic_vector(to_unsigned((valor_entero / 100) + 48, 8));
    ascii_decenas  <= std_logic_vector(to_unsigned(((valor_entero / 10) rem 10) + 48, 8));
    ascii_unidades <= std_logic_vector(to_unsigned((valor_entero rem 10) + 48, 8));

end Behavioral;