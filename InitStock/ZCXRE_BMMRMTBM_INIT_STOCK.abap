*----------------------------------------------------------------------*
*                    NEORIS ABAP Software Factory                      *
*----------------------------------------------------------------------*
* Program name         : ZCXRE_BMMRMTBM_INIT_STOCK                     *
* Description          : Programa de carga inicial de inventario       *
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
REPORT zcxre_bmmrmtbm_init_stock
       MESSAGE-ID fb
       NO STANDARD PAGE HEADING.

*&---------------------------------------------------------------------*
*& INCLUDE - Declaración de componentes
*&---------------------------------------------------------------------*
INCLUDE: zcxre_bmmrmtbm_init_stock_a,     "Declaraciones globales
         zcxre_bmmrmtbm_init_stock_b,     "Implementación de métodos
         zcxre_bmmrmtbm_init_stock_o,     "Process Before Output
         zcxre_bmmrmtbm_init_stock_i.     "Process After Input

*&---------------------------------------------------------------------*
*& INITIALIZATION
*&---------------------------------------------------------------------*
INITIALIZATION.
  "Inicialización de parámetros por defecto
  PERFORM f_initialization.

*&---------------------------------------------------------------------*
*& AT SELECTION-SCREEN ON VALUE-REQUEST
*&---------------------------------------------------------------------*
AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_file.
  "Ayuda de búsqueda para selección de archivo Excel
  PERFORM f_file_help CHANGING p_file.

*&---------------------------------------------------------------------*
*& AT SELECTION-SCREEN
*&---------------------------------------------------------------------*
AT SELECTION-SCREEN.
  "Validaciones de pantalla de selección
  PERFORM f_validate_selection_screen.

*&---------------------------------------------------------------------*
*& START-OF-SELECTION
*&---------------------------------------------------------------------*
START-OF-SELECTION.
  "Proceso principal del programa
  PERFORM f_main_process.

*&---------------------------------------------------------------------*
*& END-OF-SELECTION
*&---------------------------------------------------------------------*
END-OF-SELECTION.
  "Mostrar resultados en ALV
  PERFORM f_display_results.