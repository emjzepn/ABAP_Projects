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

*&---------------------------------------------------------------------*
*& Module STATUS_0100 OUTPUT
*&---------------------------------------------------------------------*
MODULE status_0100 OUTPUT.
  SET PF-STATUS 'STATUS_0100'.
  SET TITLEBAR  'TITLE_0100'.
  o_controller->initialize_alv( ).
ENDMODULE.