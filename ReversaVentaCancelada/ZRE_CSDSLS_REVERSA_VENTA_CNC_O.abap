*-------------------------------------------------------------------------------*
*                   Fabrica de Software ABAP NEORIS                             *
*-------------------------------------------------------------------------------*
* Nombre del Programa : ZRE_CSDSLS_REVERSA_VENTA_CNC_O                          *
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
*&---------------------------------------------------------------------*
*&      Module  STATUS_0100  OUTPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE status_0100 OUTPUT.
  SET PF-STATUS 'ST_0100'.
  SET TITLEBAR 'T_0100'.
ENDMODULE.
*&---------------------------------------------------------------------*
*&      Module  STATUS_0200  OUTPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
MODULE status_0200 OUTPUT.
  SET PF-STATUS 'ST_0200'.
  SET TITLEBAR 'T_0200'.
ENDMODULE.