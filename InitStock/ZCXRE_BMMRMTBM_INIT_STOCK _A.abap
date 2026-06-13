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

*&---------------------------------------------------------------------*
*& TABLAS
*&---------------------------------------------------------------------*

*&---------------------------------------------------------------------*
*& TIPOS DE DATOS
*&---------------------------------------------------------------------*

"Estructura para datos del archivo Excel
TYPES:
  BEGIN OF ty_excel_data,
    plant       TYPE werks_d,     "Centro
    material    TYPE matnr,       "Material
    storage_loc TYPE lgort_d,     "Almacén
    quantity    TYPE menge_d,     "Cantidad
    unit        TYPE meins,       "Unidad de medida
    value       TYPE bwert,       "Valor
  END OF ty_excel_data.

"Estructura para log de resultados
TYPES:
  BEGIN OF ty_result_log,
    line_num    TYPE numc10,      "Número de línea
    plant       TYPE werks_d,     "Centro
    material    TYPE matnr,       "Material
    storage_loc TYPE lgort_d,     "Almacén
    quantity    TYPE menge_d,     "Cantidad
    unit        TYPE meins,       "Unidad
    value       TYPE bwert,       "Valor
    status      TYPE char10,      "OK/ERROR
    mat_doc     TYPE mblnr,       "Doc material generado
    message     TYPE string,      "Mensaje
    icon        TYPE icon_d,      "Icono visual
  END OF ty_result_log.

"Estructura para BAPI header
TYPES: ty_bapi_header TYPE bapi2017_gm_head_01.

"Estructura para BAPI code
TYPES: ty_bapi_code TYPE bapi2017_gm_code.

"Estructura para BAPI item
TYPES: ty_bapi_item TYPE bapi2017_gm_item_create.

"Tabla interna de retorno BAPI
TYPES: ty_bapi_return TYPE STANDARD TABLE OF bapiret2
                      WITH NON-UNIQUE DEFAULT KEY.

*&---------------------------------------------------------------------*
*& CONSTANTES
*&---------------------------------------------------------------------*
CONSTANTS:
  c_gm_code      TYPE gm_code VALUE '05',     "Código GM
  c_move_type    TYPE bwart   VALUE '561',    "Tipo movimiento
  c_status_ok    TYPE char10  VALUE 'OK',      "Estado exitoso
  c_status_error TYPE char10  VALUE 'ERROR',   "Estado error
  c_icon_ok      TYPE icon_d  VALUE '@08@',    "Icono OK (verde)
  c_icon_error   TYPE icon_d  VALUE '@0A@',    "Icono error (rojo)
  c_param_mtart  TYPE rvari_vnam VALUE 'ZTASD_MTART_FLEETIO'.

*&---------------------------------------------------------------------*
*& VARIABLES GLOBALES
*&---------------------------------------------------------------------*
DATA:
  v_lines_total TYPE i,                "Total líneas procesadas
  v_lines_ok    TYPE i,                "Líneas exitosas
  v_lines_error TYPE i.                "Líneas con error

*&---------------------------------------------------------------------*
*& TABLAS INTERNAS
*&---------------------------------------------------------------------*
DATA:
  it_excel_data TYPE STANDARD TABLE OF ty_excel_data,
  it_result_log TYPE STANDARD TABLE OF ty_result_log.

*&---------------------------------------------------------------------*
*& WORK AREAS
*&---------------------------------------------------------------------*

*&---------------------------------------------------------------------*
*& FIELD-SYMBOLS
*&---------------------------------------------------------------------*
FIELD-SYMBOLS:
  <fs_excel>  TYPE ty_excel_data,
  <fs_result> TYPE ty_result_log.

*&---------------------------------------------------------------------*
*& PARAMETERS
*&---------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b01 WITH FRAME TITLE text-001.
PARAMETERS: p_file TYPE rlgrap-filename OBLIGATORY.  "Archivo Excel
SELECTION-SCREEN SKIP 1.
PARAMETERS: p_test TYPE xfeld AS CHECKBOX DEFAULT 'X'. "Modo prueba
SELECTION-SCREEN END OF BLOCK b01.

SELECTION-SCREEN BEGIN OF BLOCK b02 WITH FRAME TITLE text-002.
PARAMETERS: p_disp TYPE xfeld AS CHECKBOX DEFAULT 'X'. "Mostrar ALV
SELECTION-SCREEN END OF BLOCK b02.