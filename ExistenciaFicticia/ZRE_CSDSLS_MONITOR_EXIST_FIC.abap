*-------------------------------------------------------------------------------*
*                   Fabrica de Software ABAP NEORIS                             *
*-------------------------------------------------------------------------------*
* Nombre del Programa : ZRE_EXSD_MONITOR_EXIST_FIC                              *
* Descripción         : Monitor de Existencia Ficticia para pedidos de venta    *
*                       con entregas parciales integrados con sistemas POS      *
* Funcional           : Dino Cordero                                            *
* Desarrollador       : Edgar Morales  - ABAP_01                                *
* Diseñador Técnico   : Edgar Morales                                           *
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

REPORT zre_csdsls_monitor_exist_fic
  NO STANDARD PAGE HEADING
  LINE-SIZE 200
  LINE-COUNT 60
  MESSAGE-ID fb.

*-------------------------------------------------------------------------------*
* INCLUDES                                                                      *
*-------------------------------------------------------------------------------*
INCLUDE: zre_csdsls_monitor_exist_fic_a, " Declaración de datos globales
         zre_csdsls_monitor_exist_fic_b, " Definición de rutinas
         zre_csdsls_monitor_exist_fic_o, " Definición de rutinas
         zre_csdsls_monitor_exist_fic_i. " Definición de rutinas

*-------------------------------------------------------------------------------*
* INICIALIZACIÓN DE VALORES POR DEFECTO                                        *
*-------------------------------------------------------------------------------*
INITIALIZATION.

  " Obtenemos el último día del mes
  CALL FUNCTION 'RP_LAST_DAY_OF_MONTHS'
    EXPORTING
      day_in            = sy-datum
    IMPORTING
      last_day_of_month = v_last_day
    EXCEPTIONS
      OTHERS            = 1.

  IF sy-subrc <> 0.
    v_last_day = sy-datum.
  ENDIF.

  APPEND VALUE #( sign   = c_i
                  option = c_bt
                  low    = sy-datum
                  high   = v_last_day ) TO s_erdat.

*-------------------------------------------------------------------------------*
* VALIDACIONES AT SELECTION-SCREEN                                              *
*-------------------------------------------------------------------------------*

AT SELECTION-SCREEN ON s_erdat.
  " Validar rango de fechas
  PERFORM f_validate_dates.

*-------------------------------------------------------------------------------*
* PROCESAMIENTO PRINCIPAL                                                       *
*-------------------------------------------------------------------------------*
START-OF-SELECTION.
  " Proceso principal del programa
  PERFORM f_main_process.

  " Ejecución en fondo (Procesamiento directo)
  IF p_batch = abap_true.

    "Proceso de aceptación
    IF p_accept = abap_true.
      PERFORM f_process_acceptance_batch.
    ENDIF.

    "Proceso de rechazo
    IF p_reject = abap_true.
      PERFORM f_process_rejection_batch.
    ENDIF.

  ELSE.

    " Validar si se encontraron datos
    IF lines( i_parcial_orders ) = 0.
      MESSAGE s908(fb) WITH TEXT-001. "No se encontraron pedidos con entregas parciales
    ELSE.
      " Mostrar datos en ALV
      PERFORM f_display_alv.
    ENDIF.
  ENDIF.