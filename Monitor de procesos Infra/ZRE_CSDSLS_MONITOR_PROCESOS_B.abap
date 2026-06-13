*-------------------------------------------------------------------------------*
*                   Fabrica de Software ABAP NEORIS                             *
*-------------------------------------------------------------------------------*
* Nombre del Programa : ZRE_CSDSLS_MONITOR_PROCESOS_B                           *
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

CLASS cl_monitor_procesos DEFINITION FINAL.

  PUBLIC SECTION.

    METHODS: proceso.

ENDCLASS.

CLASS cl_monitor_procesos IMPLEMENTATION.

  METHOD proceso.

    "Existencia ficticia
    IF p_exfic = abap_true.
      SUBMIT zre_csdsls_monitor_exist_fic
             VIA SELECTION-SCREEN
             AND RETURN.

      "Nota de crédito para anticipos
    ELSEIF p_advc = abap_true.
      SUBMIT zre_exsd_monitor_nc_anticipo
             VIA SELECTION-SCREEN
             AND RETURN.

      "Estatus de cancelaciones
    ELSEIF p_canc = abap_true.

      "Reporte Estatus Cancelación
    ELSEIF p_rscn = abap_true.

      "Reversa Venta por Cancelación
    ELSEIF p_rvcn = abap_true.
      SUBMIT zre_csdsls_reversa_venta_cnc
             VIA SELECTION-SCREEN
             AND RETURN.

    ENDIF.

  ENDMETHOD.

ENDCLASS.