library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity FSM is
port(
    clk         : in std_logic;
    tick_coils  : in std_logic;
    direction   : in std_logic;
    start       : in std_logic;
    rst         : in std_logic;
    coil        : out std_logic_vector(3 downto 0)
);
end FSM;

architecture Behavioral of FSM is
    type state_type is (HOLD, S0, S1, S2, S3, S4, S5, S6, S7);
    signal state : state_type := HOLD;
    signal next_state : state_type := HOLD;
begin

    process(clk, rst)
    begin
        if rst = '1' then
            state <= HOLD;
        elsif rising_edge(clk) then
            if tick_coils = '1' then
                state <= next_state;
            end if;
        end if;
    end process;

    process(state, start, direction)
    begin
        if start = '0' then
            next_state <= HOLD;
        else
            case state is
                when HOLD =>
                    if direction = '0' then next_state <= S0;
                    else                   next_state <= S7;
                    end if;
                when S0 =>
                    if direction = '0' then next_state <= S1;
                    else                   next_state <= S7;
                    end if;
                when S1 =>
                    if direction = '0' then next_state <= S2;
                    else                   next_state <= S0;
                    end if;
                when S2 =>
                    if direction = '0' then next_state <= S3;
                    else                   next_state <= S1;
                    end if;
                when S3 =>
                    if direction = '0' then next_state <= S4;
                    else                   next_state <= S2;
                    end if;
                when S4 =>
                    if direction = '0' then next_state <= S5;
                    else                   next_state <= S3;
                    end if;
                when S5 =>
                    if direction = '0' then next_state <= S6;
                    else                   next_state <= S4;
                    end if;
                when S6 =>
                    if direction = '0' then next_state <= S7;
                    else                   next_state <= S5;
                    end if;
                when S7 =>
                    if direction = '0' then next_state <= S0;
                    else                   next_state <= S6;
                    end if;
                when others =>
                    next_state <= HOLD;
            end case;
        end if;
    end process;

    process(state)
    begin
        case state is
            when HOLD => coil <= "0000"; 
            when S0   => coil <= "1000";
            when S1   => coil <= "1100";
            when S2   => coil <= "0100";
            when S3   => coil <= "0110";
            when S4   => coil <= "0010";
            when S5   => coil <= "0011";
            when S6   => coil <= "0001";
            when S7   => coil <= "1001";
        end case;
    end process;
end Behavioral;
