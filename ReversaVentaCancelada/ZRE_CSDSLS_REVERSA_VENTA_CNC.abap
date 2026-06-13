*-------------------------------------------------------------------------------*
*                   Fabrica de Software ABAP NEORIS                             *
*-------------------------------------------------------------------------------*
* Nombre del Programa : ZRE_CSDSLS_REVERSA_VENTA_CNC                            *
* Descripción         : Proceso de Reversa de Venta por cancelación fiscal      *
*                       Automatiza la reversa de documentos de venta cuando el  *
*                       eDocument CFDI está en estatus CANCELADO                *
* Funcional           : Alejandra Barragán Lavara                               *
* Desarrollador       : Edgar Morales  - ABAP_01                                *
* Diseñador Técnico   : Edgar Morales                                           *
* Fecha de Creación   : 11.11.2025                                              *
* ID del Componente   : DF-EXSD43                                               *
* Número de Req.      : EXSD43                                                  *
*-------------------------------------------------------------------------------*
*                          LOG DE MODIFICACIONES                                *
*-------------------------------------------------------------------------------*
* Descripción          :                                                        *
* Funcional            :                                                        *
* Desarrollador        :                                                        *
* Fecha de Modificación:                                                        *
* ID del Componente    :                                                        *
* Núm. de Requerimiento:                                                        *
*-------------------------------------------------------------------------------*
REPORT zre_csdsls_reversa_venta_cnc
NO STANDARD PAGE HEADING
  LINE-SIZE 200
  LINE-COUNT 60
  MESSAGE-ID fb.

*-------------------------------------------------------------------------------*
* INCLUDES                                                                      *
*-------------------------------------------------------------------------------*
INCLUDE: zre_csdsls_reversa_venta_cnc_a, " Declaración de datos globales
         zre_csdsls_reversa_venta_cnc_b, " Definición de rutinas
         zre_csdsls_reversa_venta_cnc_o, " Definición de rutinas
         zre_csdsls_reversa_venta_cnc_i. " Definición de rutinas

*-------------------------------------------------------------------------------*
* PROCESAMIENTO PRINCIPAL                                                       *
*-------------------------------------------------------------------------------*
START-OF-SELECTION.
  " Proceso principal del programa
  PERFORM f_main_process.

  " Ejecución en fondo (Procesamiento directo)
  IF p_batch = abap_true.
    "Proceso de reversa
    PERFORM f_process_reverse_batch.

  ELSE.

    " Validar si se encontraron datos
    IF lines( i_reverse_orders ) = 0.
      MESSAGE s908(fb) WITH TEXT-001. "No se encontraron facturas a reversar.
    ELSE.
      " Mostrar datos en ALV
      PERFORM f_display_alv.
    ENDIF.
  ENDIF.