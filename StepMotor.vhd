----------------------------------------------------------------------------------
-- Institución: Instituto Politécnico Nacional (IPN) - UPIITA
-- Proyecto:    Control de Motor a Pasos Multimodal
-- Módulo:      StepMotor (Top-Level del Sistema Mecánico)
-- Descripción: Control de motor a pasos mediante encoder rotativo mecánico. 
--              Incluye gestión de sensores de límite, indicadores visuales y 
--              alarma sonora.
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity StepMotor is
  port(
    -- Entradas de Reloj y Control
    clk                 : in  std_logic; -- Reloj maestro de la FPGA (50 MHz)
	 -----------------------------------------------------------------------
	 ------------- ENTRADAS DEL ENCODER MECANICO
	 -----------------------------------------------------------------------
    clk_encoder_fisico  : in  std_logic; -- Canal A del Encoder
    dt_encoder_fisico   : in  std_logic; -- Canal B del Encoder
    stop1               : in  std_logic; -- Sensor de límite de carrera 1
    stop2               : in  std_logic; -- Sensor de límite de carrera 2
    rst                 : in  std_logic; -- Reset general del sistema
	 ------------------------------------------------------------------------
    -- Selector de sensor (00: Mecánico, 01: Velocidad, 10: Magnético)
	 -----------------------------------------------------------------------
    selector_Dip_Switch : in  std_logic_vector(1 downto 0);
	 -----------------------------------------------------------------------
    -- Salidas de Potencia y Visualización
	 ----------------------------------------------------------------------
    coil                : out std_logic_vector(3 downto 0); -- Secuencia para el Driver (ULN2003/L298N)
    leds_indicadores    : out std_logic_vector(3 downto 0); -- Monitor de pasos del encoder
    leds_direccion      : out std_logic_vector(1 downto 0); -- Indicador visual de sentido de giro
    beep                : out std_logic                     -- Salida para Buzzer pasivo/activo
  );
end StepMotor;

architecture Structural of StepMotor is

----------------------------------------------------------------------------------
-- Señales de Interconexión Interna (Bus de datos local)
----------------------------------------------------------------------------------
signal dir_signal     : std_logic;                    -- Dirección detectada en tiempo real por el encoder
signal paso_signal    : std_logic;                    -- Pulso de detección de movimiento del encoder
signal coil_signal    : std_logic_vector(3 downto 0); -- Estado actual de las fases del motor
signal tick_signal    : std_logic;                    -- Base de tiempo generada para la velocidad del motor
signal motor_enable   : std_logic := '0';             -- Registro de estado: '1' motor activo, '0' detenido
signal dir_registrada : std_logic := '0';             -- Memoria de la última dirección válida detectada
signal leds_interno   : std_logic_vector(3 downto 0); -- Señal interna para retroalimentación visual
-- Señales de bus para conectar sensores con el activador
signal paso_final     : std_logic;
signal dir_final      : std_logic;
signal rst_por_modo    : std_logic;

-- Señales Placeholder para futuros sensores (Evita errores de compilación)
signal paso_vel_dummy  : std_logic := '0';
signal dir_vel_dummy   : std_logic := '0';
signal paso_mag_dummy  : std_logic := '0';
signal dir_mag_dummy   : std_logic := '0';


begin



----------------------------------------------------------------------------------
-- Instancia: Selector Multiplexor (MUX)
-- Objetivo: Elegir la fuente de control y resetear la lógica en la transición.
----------------------------------------------------------------------------------
MUX_INST: entity work.Selector_Mux
port map(
    clk         => clk,
    sel         => selector_Dip_Switch,
    -- Entrada desde Encoder Mecánico
    paso_mec    => paso_signal,
    dir_mec     => dir_signal,
    -- Entradas Placeholder (Aquí conectarás tus otros módulos después)
    paso_vel    => paso_vel_dummy,
    dir_vel     => dir_vel_dummy,
    paso_mag    => paso_mag_dummy,
    dir_mag     => dir_mag_dummy,
    -- Salidas hacia el resto del sistema
    paso_out    => paso_final,
    dir_out     => dir_final,
    rst_cambio  => rst_por_modo
);



----------------------------------------------------------------------------------
-- Instancia: Divisor de Frecuencia (U_DIV)
-- Objetivo: Reducir los 50MHz a la frecuencia de paso requerida por el motor.
----------------------------------------------------------------------------------
U_DIV: entity work.Frecuencia_Bobinas
port map(
    clk           => clk,
    rst           => rst,
    tick_bobinas  => tick_signal
);

----------------------------------------------------------------------------------
-- Instancia: Decodificador de Encoder (ENC)
-- Objetivo: Interpretar las señales de cuadratura y aplicar filtrado (Debounce).
----------------------------------------------------------------------------------
ENC: entity work.FSMEncoder
generic map(
    USE_DEBOUNCE => true -- Activa el filtrado de ruido para encoders mecánicos
)
port map(
    clk        => clk,
    clk_enc    => clk_encoder_fisico,
    dt         => dt_encoder_fisico,
    paso       => paso_signal,
    direccion  => dir_signal,
    leds_shift => leds_interno
);

----------------------------------------------------------------------------------
-- Proceso: Lógica de Control Central
-- Descripción: Gestiona el estado del motor basándose en las entradas de los 
--              sensores y los comandos del usuario a través del encoder.
----------------------------------------------------------------------------------

UC: entity work.Activar_sistema
port map(
    clk            => clk,
    rst            => (rst or rst_por_modo),
    stop1          => stop1,
    stop2          => stop2,
    paso_bus       => paso_final, -- Conexión directa del encoder
    dir_bus        => dir_final,  -- Conexión directa del encoder
    
    motor_enable   => motor_enable,  -- Hacia la FSM del motor
    dir_registrada => dir_registrada -- Hacia la FSM y Audio
);

-------------------------------------------------------------
-- Instancia: Máquina de Estados del Motor (MOTOR)
-- Objetivo: Generar la secuencia de pasos (Full Step/Half Step) para las bobinas.
----------------------------------------------------------------------------------
MOTOR: entity work.FSM
port map(
    clk        => clk,
    tick_coils => tick_signal,
    direction  => dir_registrada,
    start      => motor_enable,
    rst        => rst,
    coil       => coil_signal
);

----------------------------------------------------------------------------------
-- Instancia: Subsistema de Audio (AUDIO)
-- Objetivo: Generar alertas sonoras diferenciadas por dirección al tocar límites.
----------------------------------------------------------------------------------
AUDIO: entity work.Control_Audio
port map(
    clk        => clk,
    rst        => rst,
    en_beep    => (stop1 or stop2), -- El audio solo se activa en colisión
    dir        => dir_registrada,   -- Cambia la frecuencia del beep según el lado
    buzzer_out => beep
);

----------------------------------------------------------------------------------
-- Bloque: Asignación Concurrente de Salidas
-- Descripción: Conecta las señales internas a los pines físicos de la FPGA.
----------------------------------------------------------------------------------
-- Indicadores de dirección: 

leds_direccion(0) <= (not dir_registrada) and motor_enable;
leds_direccion(1) <= dir_registrada and motor_enable;

-- Conexión directa a las fases del motor
coil             <= coil_signal;

-- Monitor de bits del encoder para depuración visual
leds_indicadores <= leds_interno;

end Structural;
