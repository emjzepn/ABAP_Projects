*-------------------------------------------------------------------------------*
*                   Fabrica de Software ABAP NEORIS                             *
*-------------------------------------------------------------------------------*
* Nombre del Programa : ZRE_CMMPUR_VIRTUAL_STOCK                                *
* Descripción         : Asignar material no colocado                            *
* Funcional           : Julio Carrasco                                          *
* Desarrollador       : Edgar Morales  - ABAP_01                                *
* Diseñador Técnico   : Edgar Morales                                           *
* Fecha de Creación   : 21.01.2026                                              *
* ID del Componente   : DF-EXMM03                                               *
* Número de Req.      : EXMM03                                                  *
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

REPORT zre_cmmpur_virtual_stock
  NO STANDARD PAGE HEADING
  LINE-SIZE 200
  LINE-COUNT 60
  MESSAGE-ID fb.

*-------------------------------------------------------------------------------*
* INCLUDES                                                                      *
*-------------------------------------------------------------------------------*
INCLUDE: zre_cmmpur_virtual_stock_a, " Declaración de datos globales
         zre_cmmpur_virtual_stock_b. " Definición de rutinas

*-------------------------------------------------------------------------------*
*  VALIDACIÓN DE PANTALLA                                                       *
*-------------------------------------------------------------------------------*
AT SELECTION-SCREEN.
  "Valida datos de pantalla
  PERFORM f_validate_selection.

*-------------------------------------------------------------------------------*
* PROCESAMIENTO PRINCIPAL                                                       *
*-------------------------------------------------------------------------------*
START-OF-SELECTION.
  " Proceso principal del programa
  PERFORM f_main_process.