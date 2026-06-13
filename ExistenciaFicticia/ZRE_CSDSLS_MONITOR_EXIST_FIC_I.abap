*-------------------------------------------------------------------------------*
*                   Fabrica de Software ABAP NEORIS                             *
*-------------------------------------------------------------------------------*
* Nombre del Programa : ZRE_CSDSLS_MONITOR_EXIST_FIC_I                          *
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
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_0100  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_0100 INPUT.

  CASE sy-ucomm.
    WHEN 'BACK' OR 'EXIT' OR 'CANC'.
      LEAVE TO SCREEN 0.

    WHEN 'ACCEPT'.
      "Proceso de aceptación
      PERFORM f_process_aceptance.

    WHEN 'REJECT'.
      "Proceso de rechazo
      PERFORM f_process_reject.

    WHEN 'SHOW_LOG'.
      " Mostrar log de proceso
      PERFORM f_show_error_log.

  ENDCASE.

ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_0200  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_0200 INPUT.

  " El proceso regresa al programa de control principal
  " No es necesario hacer algun proceso extra por el popup
  CASE sy-ucomm.
    WHEN 'BACK' OR 'EXIT' OR 'CANC'.
      SET SCREEN 0. LEAVE SCREEN. " Cierra el popup y devuelve control

    WHEN 'CONTINUE'.
      SET SCREEN 0. LEAVE SCREEN. " Cierra el popup y devuelve control

    WHEN 'CANCEL'.
      SET SCREEN 0. LEAVE SCREEN. " Cierra el popup y devuelve control

  ENDCASE.

ENDMODULE.