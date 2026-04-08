library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity Selector_Mux is
    port(
        clk         : in  std_logic;
        sel         : in  std_logic_vector(1 downto 0);
        -- Entradas de los sensores
        paso_mec    : in  std_logic;
        dir_mec     : in  std_logic;
        paso_vel    : in  std_logic;
        dir_vel     : in  std_logic;
        paso_mag    : in  std_logic;
        dir_mag     : in  std_logic;
        -- Salidas hacia la UC
        paso_out    : out std_logic;
        dir_out     : out std_logic;
        rst_cambio  : out std_logic -- Pulso de reset al cambiar de modo
    );
end Selector_Mux;

architecture Behavioral of Selector_Mux is
    signal sel_ant : std_logic_vector(1 downto 0) := "00";
begin

    process(clk)
    begin
        if rising_edge(clk) then
            -- 1. Detector de cambio para el Reset automático
            sel_ant <= sel;
            if (sel /= sel_ant) then
                rst_cambio <= '1'; -- Genera un pulso de reset por un ciclo de reloj
            else
                rst_cambio <= '0';
            end if;

            -- 2. MUX Síncrono (Cero glitches a la salida)
            case sel is
                when "00" => 
                    paso_out <= paso_mec;
                    dir_out  <= dir_mec;
                when "01" =>
                    paso_out <= paso_vel;
                    dir_out  <= dir_vel;
                when "10" =>
                    paso_out <= paso_mag;
                    dir_out  <= dir_mag;
                when others =>
                    paso_out <= '0';
                    dir_out  <= '0';
            end case;
        end if;
    end process;

end Behavioral;