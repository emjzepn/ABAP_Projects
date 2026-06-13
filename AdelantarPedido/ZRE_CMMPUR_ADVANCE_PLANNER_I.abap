*-------------------------------------------------------------------------------*
*                   Fabrica de Software ABAP NEORIS                             *
*-------------------------------------------------------------------------------*
* Nombre del Programa : ZRE_CMMPUR_ADVANCE_PLANNER_I                            *
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
*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_0100  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE user_command_0100 INPUT.

  CASE sy-ucomm.
    WHEN 'BACK' OR 'EXIT' OR 'CANC'.
      " Liberar bloqueo de tabla antes de salir
      PERFORM f_dequeue_table.
      LEAVE TO SCREEN 0.

    WHEN 'SAVE'.
      " Guardar cambios en la tabla ztamm_except_mrp
      PERFORM f_save_data.

    WHEN 'MASS'.
      " Aplicar cambios masivos según parámetros de cabecera
      PERFORM f_mass_update.

    WHEN 'ADDPLAN'.
      " Agregar nuevo plan
      PERFORM f_add_plan.

  ENDCASE.

ENDMODULE.