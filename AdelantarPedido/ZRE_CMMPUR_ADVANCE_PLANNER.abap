*-------------------------------------------------------------------------------*
*                   Fabrica de Software ABAP NEORIS                             *
*-------------------------------------------------------------------------------*
* Nombre del Programa : ZRE_CMMPUR_ADVANCE_PLANNER                              *
* Descripción         : Logica para adelanto de pedidos                         *
* Funcional           : Julio Carrasco                                          *
* Desarrollador       : Edgar Morales  - ABAP_01                                *
* Diseñador Técnico   : Edgar Morales                                           *
* Fecha de Creación   : 06.01.2026                                              *
* ID del Componente   : DF-DMM06                                                *
* Número de Req.      : DMM06                                                   *
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

REPORT zre_cmmpur_advance_planner
  NO STANDARD PAGE HEADING
  LINE-SIZE 200
  LINE-COUNT 60
  MESSAGE-ID fb.

*-------------------------------------------------------------------------------*
* INCLUDES                                                                      *
*-------------------------------------------------------------------------------*
INCLUDE: zre_cmmpur_advance_planner_a, " Declaración de datos globales
         zre_cmmpur_advance_planner_b, " Definición de rutinas
         zre_cmmpur_advance_planner_o, " Definición de rutinas
         zre_cmmpur_advance_planner_i. " Definición de rutinas

*-------------------------------------------------------------------------------*
* VALIDACIONES DE PANTALLA DE SELECCIÓN                                         *
*-------------------------------------------------------------------------------*
AT SELECTION-SCREEN.

  " Validar que se ingrese al menos un parámetro de búsqueda (exceptuando check de procesados)
  IF s_puwnr[] IS INITIAL AND
     s_werks[] IS INITIAL AND
     s_tipo[]  IS INITIAL AND
     s_day[]   IS INITIAL.
    MESSAGE e908(fb) WITH TEXT-004. "Debe ingresar al menos un parámetro de búsqueda
  ENDIF.

*-------------------------------------------------------------------------------*
* PROCESAMIENTO PRINCIPAL                                                       *
*-------------------------------------------------------------------------------*
START-OF-SELECTION.

  " Proceso principal del programa
  PERFORM f_main_process
          CHANGING v_okparam.

  IF v_okparam IS INITIAL.
    " Validar si se encontraron datos
    IF lines( i_advance_plan ) = 0.
      MESSAGE s908(fb) WITH TEXT-001. "No se encontraron pedidos con entregas parciales
    ELSE.
      " Mostrar datos en ALV
      PERFORM f_display_alv.
    ENDIF.
  ENDIF.