*-------------------------------------------------------------------------------*
*                   Fabrica de Software ABAP NEORIS                             *
*-------------------------------------------------------------------------------*
* Nombre del Programa : ZRE_CMMPUR_ACT_MRP                                      *
* Descripción         : Actualización masiva de datos MRP                       *
* Funcional           : Julio Carrasco                                          *
* Desarrollador       : Edgar Morales  - ABAP_01                                *
* Diseñador Técnico   : Edgar Morales                                           *
* Fecha de Creación   : 21.03.2026                                              *
* ID del Componente   : DF-DMM02                                                *
* Número de Req.      : DMM02                                                   *
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
*& DECLARACIÓN DE TIPOS
*&---------------------------------------------------------------------*
TYPES:
  "Estructura para datos de Excel
  BEGIN OF ty_excel,
    matnr    TYPE mara-matnr,        "Número de material
    werks    TYPE marc-werks,        "Centro
    dismm    TYPE marc-dismm,        "Característica planificación
    minbe    TYPE string,            "Punto de pedido
    disls    TYPE marc-disls,        "Tamaño lote planif
    bstmi    TYPE string,            "Tamaño lote mínimo
    bstma    TYPE string,            "Tamaño lote máximo
    mabst    TYPE string,            "Stock máximo
    bstrf    TYPE string,            "Valor redondeo
    sobsl    TYPE marc-sobsl,        "Clase aprov especial
    plifz    TYPE string,            "Plazo entrega
    webaz    TYPE string,            "Tiempo tratamiento EM
    fhori    TYPE marc-fhori,        "Clave horizonte
    eisbe    TYPE string,            "Stock seguridad
    eislo    TYPE string,            "Stock seguridad mínimo
    prmod    TYPE mpop-prmod,        "Modelo pronóstico
    vrbmt    TYPE marc-vrbmt,        "Material referencia consumo
    vrbwk    TYPE marc-vrbwk,        "Centro referencia consumo
    peran    TYPE string,            "Períodos pasado
    anzpr    TYPE string,            "Períodos pronóstico
    perio    TYPE string,            "Períodos estacionales
    maabc    TYPE marc-maabc,        "Indicador ABC
    maxlz    TYPE string,            "Tiempo máximo almacenaje
* Campos extra fuera del archivo de carga
    pstat    TYPE mara-pstat,        "Status de actualización
    icon     TYPE icon_d,            "Icon
    status   TYPE zdemm_status,      "Estatus
    comments TYPE zdemm_comments,    "Comentarios
  END OF ty_excel,

  BEGIN OF ty_datos,
    matnr TYPE string,        "Número de material
    werks TYPE string,        "Centro
    dismm TYPE string,        "Característica planificación
    minbe TYPE string,        "Punto de pedido
    disls TYPE string,        "Tamaño lote planif
    bstmi TYPE string,        "Tamaño lote mínimo
    bstma TYPE string,        "Tamaño lote máximo
    mabst TYPE string,        "Stock máximo
    bstrf TYPE string,        "Valor redondeo
    sobsl TYPE string,        "Clase aprov especial
    plifz TYPE string,        "Plazo entrega
    webaz TYPE string,        "Tiempo tratamiento EM
    fhori TYPE string,        "Clave horizonte
    eisbe TYPE string,        "Stock seguridad
    eislo TYPE string,        "Stock seguridad mínimo
    prmod TYPE string,        "Modelo pronóstico
    vrbmt TYPE string,        "Material referencia consumo
    vrbwk TYPE string,        "Centro referencia consumo
    peran TYPE string,        "Períodos pasado
    anzpr TYPE string,        "Períodos pronóstico
    perio TYPE string,        "Períodos estacionales
    maabc TYPE string,        "Indicador ABC
    maxlz TYPE string,        "Tiempo máximo almacenaje
  END OF ty_datos,

  "Estructura para resultados ALV
  BEGIN OF ty_updated_mrp,
    icon     TYPE icon_d,            "Icon
    status   TYPE zdemm_status,      "Estatus
    comments TYPE zdemm_comments,    "Comentarios
    matnr    TYPE mara-matnr,        "Número de material
    werks    TYPE marc-werks,        "Centro
    dismm    TYPE marc-dismm,        "Característica planificación
    minbe    TYPE marc-minbe,        "Punto de pedido
    dispo    TYPE marc-dispo,        "Planificador necesidades
    disls    TYPE marc-disls,        "Tamaño lote planif
    bstmi    TYPE marc-bstmi,        "Tamaño lote mínimo
    bstma    TYPE marc-bstma,        "Tamaño lote máximo
    mabst    TYPE marc-mabst,        "Stock máximo
    bstrf    TYPE marc-bstrf,        "Valor redondeo
    beskz    TYPE marc-beskz,        "Clase aprovisionamiento
    sobsl    TYPE marc-sobsl,        "Clase aprov especial
    lgfsb    TYPE marc-lgfsb,        "Almacén aprov externo
    plifz    TYPE marc-plifz,        "Plazo entrega
    webaz    TYPE marc-webaz,        "Tiempo tratamiento EM
    fhori    TYPE marc-fhori,        "Clave horizonte
    eisbe    TYPE marc-eisbe,        "Stock seguridad
    eislo    TYPE marc-eislo,        "Stock seguridad mínimo
    perkz    TYPE marc-perkz,        "Indicador de período
    prmod    TYPE mpop-prmod,        "Modelo pronóstico
    vrbmt    TYPE marc-vrbmt,        "Material referencia consumo
    vrbwk    TYPE marc-vrbwk,        "Centro referencia consumo
    peran    TYPE mpop-peran,        "Períodos pasado
    anzpr    TYPE mpop-anzpr,        "Períodos pronóstico
    perio    TYPE mpop-perio,        "Períodos estacionales
    kzini    TYPE mpop-kzini,        "Indicador inicialización
    maabc    TYPE marc-maabc,        "Indicador ABC
    maxlz    TYPE marc-maxlz,        "Tiempo máximo almacenaje
  END OF ty_updated_mrp,

  "Tipos tabla
  tt_excel       TYPE STANDARD TABLE OF ty_excel WITH DEFAULT KEY,
  tt_updated_mrp TYPE STANDARD TABLE OF ty_updated_mrp WITH DEFAULT KEY.

*&---------------------------------------------------------------------*
*& DECLARACIÓN DE CONSTANTES
*&---------------------------------------------------------------------*
CONSTANTS:
  c_caracter_borrado TYPE char1 VALUE '&',  "Carácter para borrado
  c_x                TYPE char1 VALUE 'X',  "Constante X
  c_modo_simulacion  TYPE char1 VALUE 'S',  "Modo simulación
  c_modo_ejecucion   TYPE char1 VALUE 'R',  "Modo real
  c_sep_tab          TYPE char1 VALUE ','.

*&---------------------------------------------------------------------*
*& DECLARACIÓN DE TABLAS INTERNAS
*&---------------------------------------------------------------------*
DATA:
  i_excel       TYPE tt_excel ##NEEDED,
  i_updated_mrp TYPE tt_updated_mrp ##NEEDED.

*&---------------------------------------------------------------------*
*& DECLARACIÓN DE VARIABLES GLOBALES
*&---------------------------------------------------------------------*
DATA:
  v_archivo TYPE string ##NEEDED,
  v_modo    TYPE char1 ##NEEDED.

*&---------------------------------------------------------------------*
*& PANTALLA DE SELECCIÓN
*&---------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-b01.
PARAMETERS:
  p_file TYPE rlgrap-filename OBLIGATORY.
SELECTION-SCREEN SKIP 1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE TEXT-b02.
PARAMETERS:
  p_crea RADIOBUTTON GROUP r1 DEFAULT 'X' USER-COMMAND modo ##NEEDED,
  p_modi RADIOBUTTON GROUP r1 ##NEEDED.
SELECTION-SCREEN END OF BLOCK b2.

SELECTION-SCREEN BEGIN OF BLOCK b3 WITH FRAME TITLE TEXT-b03.
PARAMETERS:
  p_simul RADIOBUTTON GROUP r2 DEFAULT 'X' USER-COMMAND modo ##NEEDED,
  p_real  RADIOBUTTON GROUP r2 ##NEEDED.
SELECTION-SCREEN END OF BLOCK b3.
SELECTION-SCREEN END OF BLOCK b1.