*-------------------------------------------------------------------------------*
*                   Fabrica de Software ABAP NEORIS                             *
*-------------------------------------------------------------------------------*
* Nombre del Programa : ZRE_CMMPUR_ACT_MRP                                      *
* Descripción         : Actualización masiva de datos MRP                       *
* Funcional           : Julio Carrasco                                          *
* Desarrollador       : Edgar Morales  - ABAP_01                                *
* Diseñador Técnico   : Edgar Morales                                           *
* Fecha de Creación   : 21.03.2026                                              *
* ID del Componente   : DF-DMM02                                                *
* Número de Req.      : DMM02                                                   *
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
REPORT zre_cmmpur_act_mrp
  NO STANDARD PAGE HEADING
  LINE-SIZE 200
  LINE-COUNT 60
  MESSAGE-ID zsd.

*-------------------------------------------------------------------------------*
* INCLUDES                                                                      *
*-------------------------------------------------------------------------------*
INCLUDE: zre_cmmpur_act_mrp_a, " Declaración de datos globales
         zre_cmmpur_act_mrp_b, " Definición de rutinas
         zre_cmmpur_act_mrp_o, " Definición de rutinas
         zre_cmmpur_act_mrp_i. " Definición de rutinas

*-------------------------------------------------------------------------------*
* EVENTO DE SELECTOR DE CAMPO DE PANTALLA                                       *
*-------------------------------------------------------------------------------*
AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_file.
  "Ayuda de búsqueda para selección de archivo
  PERFORM f_browse_file.

*-------------------------------------------------------------------------------*
* PROCESAMIENTO PRINCIPAL                                                       *
*-------------------------------------------------------------------------------*
START-OF-SELECTION.

  "Pop-up de confirmación para modo Real
  IF p_real = c_x.
    DATA: lv_answer TYPE char1 ##NEEDED.
    CALL FUNCTION 'POPUP_TO_CONFIRM'
      EXPORTING
        titlebar              = TEXT-001 "Confirmación de Ejecución Real
        text_question         = TEXT-002 "¿Desea ejecutar en modo REAL? Los cambios se grabarán en la base de datos.
        text_button_1         = TEXT-003 "Aceptar
        text_button_2         = TEXT-004 "Cancelar
        default_button        = '2'
        display_cancel_button = space
      IMPORTING
        answer                = lv_answer.

    IF lv_answer <> '1'.
      MESSAGE TEXT-005 TYPE 'S'. "Ejecución cancelada por el usuario
      RETURN.
    ENDIF.
  ENDIF.

  "Proceso principal
  PERFORM f_main_process.

*-------------------------------------------------------------------------------*
* PROCESAMIENTO FINAL                                                           *
*-------------------------------------------------------------------------------*
END-OF-SELECTION.
  "Presentación de resultados

  PERFORM f_show_results.