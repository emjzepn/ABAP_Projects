*-------------------------------------------------------------------------------*
*                   Fabrica de Software ABAP NEORIS                             *
*-------------------------------------------------------------------------------*
* Nombre del Programa : ZRE_CSDSLS_MONITOR_PROCESOS                             *
* Descripción         : Monitor de procesos INFRA                               *
* Funcional           : Dino Cordero                                            *
* Desarrollador       : Edgar Morales                                           *
* Diseñador Técnico   : Consultor ABAP Senior                                   *
* Fecha de Creación   : 11.11.2025                                              *
* ID del Componente   : DF-EXSD44                                               *
* Número de Req.      : EXSD44                                                  *
*-------------------------------------------------------------------------------*
*                          LOG DE MODIFICACIONES                                *
*-------------------------------------------------------------------------------*
* Descripción           :                                                       *
* Funcional             :                                                       *
* Desarrollador         :                                                       *
* Fecha de Modificación :                                                       *
* ID del Componente     :                                                       *
* Núm. de Requerimiento :                                                       *
*-------------------------------------------------------------------------------*
REPORT zre_csdsls_monitor_procesos
  NO STANDARD PAGE HEADING
  LINE-SIZE 200
  LINE-COUNT 60
  MESSAGE-ID zsd.

*-------------------------------------------------------------------------------*
* INCLUDES                                                                      *
*-------------------------------------------------------------------------------*
INCLUDE: zre_csdsls_monitor_procesos_a,  " Declaración de datos globales
         zre_csdsls_monitor_procesos_b.  " Definición de rutinas

*-------------------------------------------------------------------------------*
* START-OF-SELECTION                                                            *
*-------------------------------------------------------------------------------*
START-OF-SELECTION.

  TRY.
      CREATE OBJECT o_monitor.
      o_monitor->proceso( ).
    CATCH cx_root INTO DATA(lo_root) ##NEEDED.
      DATA(lv_error) = lo_root->get_text( ) ##NEEDED.
  ENDTRY.