library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Encoder_Velocidad is
    port(
        clk        : in  std_logic;
        rst_fisico : in  std_logic; 
        rst_cambio : in  std_logic; 
        s_opt_A    : in  std_logic; 
        s_opt_B    : in  std_logic; 
        
        trigger    : out std_logic;
        dir_vel    : out std_logic; 
        leds_shift : out std_logic_vector(3 downto 0) 
    );
end Encoder_Velocidad;

architecture Behavioral of Encoder_Velocidad is

    signal A_d, B_d : std_logic := '1';
    signal activado : std_logic := '0';

    signal contador : integer range 0 to 5_000_000 := 0;

begin

process(clk)
begin
    if rising_edge(clk) then

        if rst_fisico = '1' or rst_cambio = '1' then
            trigger   <= '0';
            dir_vel   <= '0';
            activado  <= '0';
            A_d       <= '1';
            B_d       <= '1';
            contador  <= 0;

        else
            trigger <= '0';

            -- mantener pulso
            if contador > 0 then
                trigger <= '1';
                contador <= contador - 1;

            else
                -- detectar PRIMER cambio
                if activado = '0' then

                    -- sensor A activado (recuerda: activo en 0)
                    if (A_d = '1' and s_opt_A = '0') then
                        dir_vel   <= '1';
                        contador  <= 2_500_000; -- ~50ms
                        activado  <= '1';

                    -- sensor B activado
                    elsif (B_d = '1' and s_opt_B = '0') then
                        dir_vel   <= '0';
                        contador  <= 2_500_000;
                        activado  <= '1';
                    end if;

                end if;
            end if;

            -- actualizar históricos
            A_d <= s_opt_A;
            B_d <= s_opt_B;

        end if;
    end if;
end process;

leds_shift <= "1111";

end Behavioral;
