Readme

BiRISC V Nexus – 32 bit Dual Issue RISC V CPU con extensiones OoO

biRISC V Nexus es una versión extendida del procesador biRISC V original, incorporando
mejoras orientadas al procesamiento en paralelo, incluyendo:

•	Soporte para ejecución Out of Order (OoO): Incorporación de un Register Alias Table (RAT), una lista de libres (Free List) y un archivo de registros físicos (PRF).
•	Integración de un Tournament Branch Predictor.
•	Testbenches mejorados y métricas de síntesis para FPGA.
•	Scripts y documentación para simulación, verificación y análisis de rendimiento.

Este repositorio está basado en el trabajo de ultraembedded, pero introduce modificaciones significativas en RTL, predictor de saltos, testbench y entorno de síntesis.


Estructura del Repositorio

•	src: Código RTL del procesador (Verilog) 
Módulos nuevos añadidos:
-	biriscv_freelist.v
-	biriscv_issue_ooo.v
-	biriscv_prf.v
-	biriscv_rat.v
-	biriscv_rename
-	biriscv_rob.v
Módulos modificados:
-	biriscv_divider.v
-	biriscv_exec.v
-	biriscv_Isu.v
-	biriscv_npc.v
-	biriscv_Isu.v
-	biriscv_multiplier.v
-	core.v

•	tb: Testbenches y entorno de verificación 
•	docs: Diagramas, documentación y especificaciones 
•	vivado_project: Reportes de síntesis y utilización (Artix-7) 
•	LICENSE: Licencia Apache 2.0
Características

•	Núcleo RISC V RV32IMZicsr.
•	Pipeline dual issue de 6–7 etapas.
•	Ejecución Out of Order experimental.
•	Predictor de saltos híbrido: Bimodal, Gshare, selector de torneo
•	BTB y RAS configurables.
•	Unidad de división fuera de pipeline.
•	Soporte para:
    - Modo usuario, supervisor y máquina.
   - MMU básica.
    - Caches o TCM.
    - Interfaces AXI.
•	Compatible con Verilator, Icarus y FPGA (Artix 7).
•	Reportes de síntesis incluidos (utilización).


Simulación

Requisitos:
•	Icarus Verilog o Verilator
•	Make (opcional)
•	GCC / Clang para modelos C++

Para ejecutar el testbench principal:

Bash:
cd tb/tb_core_icarus
make

Síntesis en FPGA (Vivado)
El directorio vivado_project/ contiene:
•	Reportes de utilización (LUTs, FFs, BRAMs)
•	Métricas de área 
Para sintetizar desde cero:
Bash
vivado -source synth.tcl


Parámetros Configurables
El procesador expone múltiples parámetros para experimentación:
•	Activación de MMU, MULDIV, dual issue
•	Tamaño del BTB, BHT y RAS
•	Opciones de bypass
•	Configuración de caches
•	Rango de direcciones cacheables
Consulta docs/configuration.md para una descripción detallada.
Integración
El núcleo puede integrarse en SoCs mediante:
•	Interfaces AXI
•	Memorias tightly coupled
•	Caches configurables
Documentación disponible en docs/integration.md.
Métricas de Rendimiento
-	Las métricas de rendimiento se obtuvieron con dos flujos distintos: simulación del procesador para desempeño funcional y síntesis en Vivado para costo de hardware
Localización: vivado_project/synth_1/reports/
Comparación de Arquitecturas:
Recurso	Antes	Después	Delta	Cambio relativo
Slice LUTs	11465	21180	+9715	+84.7%
Slice Registers	6719	15263	+8544	+127.2%
F7 Muxes	793	2285	+1492	+188.1%
F8 Muxes	105	822	+717	+682.9%
Recursos que no cambiaron:
Recurso	Before	After
Block RAM Tile	16	16
DSPs	4	4
I/O Bonded IOB	327	327
BUFGCTRL	1	1
Cambios primitivos más importantes:
Primitiva	Before	After	Delta
LUT6	6764	13126	+6362
FDCE	4406	10390	+5984
FDPE	1035	3595	+2560
LUT5	1892	3239	+1347
LUT4	1202	3079	+1877
LUT3	1876	2856	+980
MUXF7	793	2285	+1492
MUXF8	105	822	+717
CARRY4	608	610	+2
FDRE	1278	1278	0
RAMB36E1	16	16	0
DSP48E1	4	4	0

Documentación Adicional (Disponible en docs/)
•	Configuración del core
•	Integración en SoC
•	Boot de Linux
•	Características personalizadas
