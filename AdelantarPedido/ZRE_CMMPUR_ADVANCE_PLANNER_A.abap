*-------------------------------------------------------------------------------*
*                   Fabrica de Software ABAP NEORIS                             *
*-------------------------------------------------------------------------------*
* Nombre del Programa : ZRE_CMMPUR_ADVANCE_PLANNER_A                            *
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
*-------------------------------------------------------------------------------*
* DECLARACIÓN DE TABLAS                                                         *
*-------------------------------------------------------------------------------*
TABLES: t439c,                " Agrupaciones operativas
        ztamm_except_mrp,     " Adelanto de Pedidos
        zstmm_dia_semana_mrp. " Dia de la Semana

*-------------------------------------------------------------------------------*
* DECLARACIÓN DE TIPOS                                                          *
*-------------------------------------------------------------------------------*
TYPES:
  BEGIN OF ty_centro_data,
    puwnr   TYPE t439c-puwnr,                   "ID alcance planificación unidad MRP
    plwrk   TYPE t439c-plwrk,                   "Centro
    name1   TYPE t001w-name1,                   "Nombre
    fabkl   TYPE t001w-fabkl,                   "Pais
  END OF ty_centro_data,

  BEGIN OF ty_advance_plan,
    puwnr       TYPE t439c-puwnr,                   "ID alcance planificación unidad MRP
    plwrk       TYPE t439c-plwrk,                   "Centro
    name1       TYPE t001w-name1,                   "Nombre centro
    tipo        TYPE ztamm_except_mrp-tipo,         "Tipo
    planum      TYPE ztamm_except_mrp-planum,       "Número de plan
    dateori     TYPE ztamm_except_mrp-dateori,      "Fecha original de ejecución
    advance     TYPE ztamm_except_mrp-advance,      "Adelantar
    dateori_pro TYPE ztamm_except_mrp-dateori_pro,  "Fecha original de ejecución
    dateadv_pro TYPE ztamm_except_mrp-dateadv_pro,  "Adelantar
    noexec      TYPE ztamm_except_mrp-noexec,       "No ejecutar
    noexec_pro  TYPE ztamm_except_mrp-noexec_pro,   "No ejecutar proceso
    reason      TYPE ztamm_except_mrp-reason,       "Razón
    dateadv     TYPE ztamm_except_mrp-dateadv,      "Fecha de adelanto
    createby    TYPE ztamm_except_mrp-createby,     "Creado por
    createon    TYPE ztamm_except_mrp-createon,     "Creado el
    processed   TYPE ztamm_except_mrp-processed,    "Procesado
    celltab     TYPE lvc_t_styl,                    "Estilos de celda para edición
    changed     TYPE char1,                         "Indicador de modificación
  END OF ty_advance_plan.

TYPES: tt_centro_data TYPE STANDARD TABLE OF ty_centro_data.
TYPES: tt_advance_plan TYPE STANDARD TABLE OF ty_advance_plan WITH DEFAULT KEY.

*-------------------------------------------------------------------------------*
* CONSTANTES                                                                    *
*-------------------------------------------------------------------------------*
CONSTANTS:
  c_x TYPE char1 VALUE 'X',          " Constante X
  c_a TYPE char1 VALUE 'A'.          " Constante A

*-------------------------------------------------------------------------------*
* TABLAS INTERNAS                                                               *
*-------------------------------------------------------------------------------*
DATA:
  i_advance_plan TYPE TABLE OF ty_advance_plan ##NEEDED.

*-------------------------------------------------------------------------------*
* VARIABLES GLOBALES                                                            *
*-------------------------------------------------------------------------------*
DATA:
  v_advance     TYPE ztamm_except_mrp-advance,
  v_dateadv_pro TYPE ztamm_except_mrp-dateadv_pro,
  v_noexec      TYPE ztamm_except_mrp-noexec,
  v_noexec_pro  TYPE ztamm_except_mrp-noexec_pro,
  v_fabkl       TYPE scal-hcalid ##NEEDED,
  v_dateadv     TYPE ztamm_except_mrp-dateadv,
  v_reason      TYPE ztamm_except_mrp-reason,
  v_ok_code     TYPE sy-ucomm ##NEEDED,
  v_okparam     TYPE abap_bool ##NEEDED.

*-------------------------------------------------------------------------------*
* CLASES                                                                        *
*-------------------------------------------------------------------------------*
CLASS cl_advance_planner DEFINITION DEFERRED.

*-------------------------------------------------------------------------------*
* OBJETOS                                                                       *
*-------------------------------------------------------------------------------*
DATA:
  o_advance_planner TYPE REF TO cl_advance_planner ##NEEDED,
  o_alv_grid        TYPE REF TO cl_gui_alv_grid ##NEEDED,
  o_container       TYPE REF TO cl_gui_custom_container ##NEEDED,
  o_data            TYPE REF TO data ##NEEDED.

*-------------------------------------------------------------------------------*
* PARÁMETROS DE SELECCIÓN                                                       *
*-------------------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b01 WITH FRAME TITLE TEXT-t01.
SELECT-OPTIONS: s_puwnr  FOR t439c-puwnr,                             " Agrup. operativa
                s_werks  FOR t439c-plwrk,                             " Centro
                s_tipo   FOR ztamm_except_mrp-tipo,                   " Tipo
                s_day    FOR zstmm_dia_semana_mrp-dia.                " Día
SELECTION-SCREEN SKIP.
PARAMETERS:     p_procd  TYPE ztamm_except_mrp-processed AS CHECKBOX. "Procesados
SELECTION-SCREEN END OF BLOCK b01.