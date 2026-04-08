library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity FSMEncoder is
generic(
    USE_DEBOUNCE : boolean := true
);
port(
    clk        : in std_logic;
    clk_enc    : in std_logic;
    dt         : in std_logic;
    paso       : out std_logic;
    direccion  : out std_logic;
    leds_shift : out std_logic_vector(3 downto 0) 
);
end FSMEncoder;

architecture Behavioral of FSMEncoder is

-- señales del debounce
signal clk_filt, dt_filt : std_logic;

-- estados (actual y anterior)
signal prev_state : std_logic_vector(1 downto 0) := "00";

-- salida interna
signal paso_i : std_logic := '0';
signal dir_i  : std_logic := '0';

signal clk_sync, dt_sync : std_logic := '0';

-- Registro para el corrimiento de los LEDs
signal shift_reg : std_logic_vector(3 downto 0) := "0001"; -- Inicia con un LED encendido

begin

-------------------------------------------------
-- DEBOUNCE
-------------------------------------------------
GEN_DEB: if USE_DEBOUNCE generate
    DEB: entity work.DebounceEncoder
    port map(
        clk                => clk,
        clk_enc_fisico     => clk_enc,
        dt_enc_fisico      => dt,
        clk_clean_encoder  => clk_filt,
        dt_clean_encoder   => dt_filt
    );
end generate;

GEN_NODEB: if not USE_DEBOUNCE generate
    clk_filt <= clk_enc;
    dt_filt  <= dt;
end generate;

process(clk)
begin
    if rising_edge(clk) then
        clk_sync <= clk_filt;
        dt_sync  <= dt_filt;
    end if;
end process;

-------------------------------------------------
-- LÓGICA PRINCIPAL Y CORRIMIENTO
-------------------------------------------------
process(clk)
begin
    if rising_edge(clk) then
        paso_i <= '0';  -- Reset del pulso de paso

        -- 1. Detectar movimiento del encoder
        if (clk_sync & dt_sync) /= prev_state then
            case prev_state & (clk_sync & dt_sync) is
                -- SENTIDO HORARIO (dir_i = '0')
                when "0001" | "0111" | "1110" | "1000" =>
                    paso_i <= '1';
                    dir_i  <= '0';
                    -- Corrimiento a la derecha (circular)
                    shift_reg <= shift_reg(0) & shift_reg(3 downto 1);

                -- SENTIDO ANTIHORARIO (dir_i = '1')
                when "0010" | "1011" | "1101" | "0100" =>
                    paso_i <= '1';
                    dir_i  <= '1';
                    -- Corrimiento a la izquierda (circular)
                    shift_reg <= shift_reg(2 downto 0) & shift_reg(3);

                when others =>
                    null;
            end case;

            prev_state <= clk_sync & dt_sync;
        end if;
    end if;
end process;

-------------------------------------------------
-- SALIDAS
-------------------------------------------------
paso       <= paso_i;
direccion  <= dir_i;
leds_shift <= shift_reg; 

end Behavioral;