*----------------------------------------------------------------------*
*                    NEORIS ABAP Software Factory                      *
*----------------------------------------------------------------------*
* Program name         : ZCXRE_BMMRMTBM_REPROC_MOV                     *
* Description          : Reprocessing program for inventory movements  *
*                        sent to Fleetio                               *
* Functional           : Wilfrido Arroyo                               *
* Developer            : Edgar Morales   - E0HUGSANCHEZ                *
* Creation Date        : 01.06.2026                                    *
* ID Component         :                                               *
* Requirement Number   : SR-FLEETIO-001                                *
*----------------------------------------------------------------------*
*                      MODIFICATIONS LOG                               *
*----------------------------------------------------------------------*
* Description          : Detail briefly the objective of the change    *
* Functional           : Functional Designer Name.                     *
* Developer            : ABAP Developer Name and USER-ID.              *
* Modification date    : DD.MM.YYYY                                    *
* ID Component         :                                               *
* Requirement Number   : Example LN####                                *
*----------------------------------------------------------------------*
REPORT zcxre_bmmrmtbm_reproc_mov
       MESSAGE-ID fb
       NO STANDARD PAGE HEADING.

*&---------------------------------------------------------------------*
*& INCLUDE - Declaración de componentes
*&---------------------------------------------------------------------*
INCLUDE: zcxre_bmmrmtbm_reproc_mov_a,     "Declaraciones globales
         zcxre_bmmrmtbm_reproc_mov_b,     "Implementación de métodos
         zcxre_bmmrmtbm_reproc_mov_o,     "Proceso PBO
         zcxre_bmmrmtbm_reproc_mov_i.     "Proceso PAI

*&---------------------------------------------------------------------*
*& START-OF-SELECTION
*&---------------------------------------------------------------------*
START-OF-SELECTION.

  CREATE OBJECT o_controller.
  o_controller->get_inventory_log( ).

  IF it_log_data[] IS NOT INITIAL.
    CALL SCREEN 100.
  ELSE.
    MESSAGE s908(fb) WITH 'No hay documentos para reprocesar'.
  ENDIF.