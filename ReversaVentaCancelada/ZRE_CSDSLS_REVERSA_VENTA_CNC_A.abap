*-------------------------------------------------------------------------------*
*                   Fabrica de Software ABAP NEORIS                             *
*-------------------------------------------------------------------------------*
* Nombre del Programa : ZRE_CSDSLS_REVERSA_VENTA_CNC_A                          *
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
*-------------------------------------------------------------------------------*
* DECLARACIÓN DE TABLAS                                                         *
*-------------------------------------------------------------------------------*
TABLES: vbrk.           "Documento de facturación

*-------------------------------------------------------------------------------*
* DECLARACIÓN DE TIPOS                                                          *
*-------------------------------------------------------------------------------*
TYPE-POOLS: slis, icon.

*-------------------------------------------------------------------------------*
* DECLARACIÓN DE TIPOS                                                          *
*-------------------------------------------------------------------------------*
TYPES:
  BEGIN OF ty_reverse_orders,
    icon         TYPE icon_d,
    edoc_guid    TYPE edocument-edoc_guid,
    vbeln_vf     TYPE vbrk-vbeln,
    status_sat   TYPE char20,
    vkorg        TYPE vbrk-vkorg,
    kunag        TYPE vbrk-kunag,
    name1        TYPE kna1-name1,
    fkart        TYPE vbrk-fkart,
    fkdat        TYPE vbrk-fkdat,
    vbeln_va     TYPE vbak-vbeln,
    invoice_canc TYPE vbrk-vbeln,
    cancelled    TYPE char1,
    message      TYPE string,
  END OF ty_reverse_orders.

TYPES: tt_reverse_orders TYPE STANDARD TABLE OF ty_reverse_orders WITH DEFAULT KEY.

TYPES:
  BEGIN OF ty_log,
    icon     TYPE icon_d,         " Ícono de estado (semáforo)
    document TYPE vbeln_va,       " Documento procesado
    process  TYPE char20,         " Tipo de proceso
    status   TYPE char10,         " Estado del proceso
    euser    TYPE sy-uname,       " Usuario
    edate    TYPE dats,           " Fecha de ejecución
    etime    TYPE tims,           " Hora de ejecución
    message  TYPE char255,        " Mensaje detallado
  END OF ty_log.

*-------------------------------------------------------------------------------*
* CONSTANTES                                                                    *
*-------------------------------------------------------------------------------*
CONSTANTS:
  c_x           TYPE char1 VALUE 'X',          " Constante X
  c_a           TYPE char1 VALUE 'A',          " Constante A
  c_i           TYPE char1 VALUE 'I',          " Constante I
  c_u           TYPE char1 VALUE 'U',          " Constante U
  c_eq          TYPE char2 VALUE 'EQ',         " Constante EQ
  c_status_canc TYPE char20 VALUE 'CANCELLED',
  c_fksto_x     TYPE vbrk-fksto VALUE 'X',
  c_abgru_b7    TYPE vbap-abgru VALUE 'B7'.

*-------------------------------------------------------------------------------*
* ESTRUCTURAS                                                                   *
*-------------------------------------------------------------------------------*
DATA:
  w_reverse_orders TYPE ty_reverse_orders ##NEEDED,
  w_log            TYPE ty_log ##NEEDED.

*-------------------------------------------------------------------------------*
* TABLAS INTERNAS                                                               *
*-------------------------------------------------------------------------------*
DATA:
  i_reverse_orders TYPE TABLE OF ty_reverse_orders ##NEEDED,
  i_log            TYPE TABLE OF ty_log ##NEEDED.

*-------------------------------------------------------------------------------*
* RANGOS                                                                        *
*-------------------------------------------------------------------------------*
DATA:
  r_motivo TYPE RANGE OF char2 ##NEEDED.

*-------------------------------------------------------------------------------*
* FIELD-SYMBOLS                                                                 *
*-------------------------------------------------------------------------------*
FIELD-SYMBOLS:
  <fs_reverse_orders> TYPE ty_reverse_orders ##NEEDED,
  <fs_log>            TYPE ty_log ##NEEDED.

*-------------------------------------------------------------------------------*
* VARIABLES GLOBALES                                                            *
*-------------------------------------------------------------------------------*
DATA:
  v_okcode     TYPE sy-ucomm,
  v_icon_name  TYPE iconname,
  v_text_line1 TYPE char255,
  v_text_line2 TYPE char255,
  v_text_line3 TYPE char255.

*-------------------------------------------------------------------------------*
* OBJETOS                                                                       *
*-------------------------------------------------------------------------------*
DATA:
  o_alv_grid  TYPE REF TO cl_gui_alv_grid ##NEEDED,
  o_container TYPE REF TO cl_gui_custom_container ##NEEDED,
  o_data      TYPE REF TO data ##NEEDED.

*-------------------------------------------------------------------------------*
* PARÁMETROS DE SELECCIÓN                                                       *
*-------------------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-t01.
SELECT-OPTIONS: s_vkorg FOR vbrk-vkorg OBLIGATORY DEFAULT 'IF00',  "Organización de ventas
                s_vbeln FOR vbrk-vbeln,                            "Documento de facturación
                s_kunag FOR vbrk-kunag,                            "Cliente
                s_fkdat FOR vbrk-fkdat.                            "Fecha de facturación
SELECTION-SCREEN END OF BLOCK b1.

* Opciones de procesamiento
SELECTION-SCREEN BEGIN OF BLOCK b03 WITH FRAME TITLE TEXT-t03.
PARAMETERS: p_batch  TYPE char1 NO-DISPLAY. " Proceso en fondo
SELECTION-SCREEN END OF BLOCK b03.

SELECTION-SCREEN BEGIN OF SCREEN 0210 AS SUBSCREEN.
SELECTION-SCREEN BEGIN OF BLOCK sb1.
PARAMETERS: p_sbatch AS CHECKBOX DEFAULT ' '.
SELECTION-SCREEN END OF BLOCK sb1.
SELECTION-SCREEN END OF SCREEN 0210.