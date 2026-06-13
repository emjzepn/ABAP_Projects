*-------------------------------------------------------------------------------*
*                   Fabrica de Software ABAP NEORIS                             *
*-------------------------------------------------------------------------------*
* Nombre del Programa : ZRE_CMMPUR_VIRTUAL_STOCK                                *
* Descripción         : Asignar material no colocado                            *
* Funcional           : Julio Carrasco                                          *
* Desarrollador       : Edgar Morales  - ABAP_01                                *
* Diseñador Técnico   : Edgar Morales                                           *
* Fecha de Creación   : 21.01.2026                                              *
* ID del Componente   : DF-EXMM03                                               *
* Número de Req.      : EXMM03                                                  *
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
* TABLES                                                                        *
*-------------------------------------------------------------------------------*

*-------------------------------------------------------------------------------*
* DECLARACIÓN DE TIPOS                                                          *
*-------------------------------------------------------------------------------*
TYPES:
  BEGIN OF ty_zmm_expro,
    idarchivo   TYPE ztamm_expro-idarchivo,
    consecutivo TYPE ztamm_expro-consecutivo,
    fecha       TYPE ztamm_expro-fecha,
    proveedor   TYPE ztamm_expro-proveedor,
    materialpro TYPE ztamm_expro-materialpro,
    materialsap TYPE ztamm_expro-materialsap,
    unimed      TYPE ztamm_expro-unimed,
    cantidad    TYPE ztamm_expro-cantidad,
    precio      TYPE ztamm_expro-precio,
    numoc       TYPE ztamm_expro-numoc,
    docentmerc  TYPE ztamm_expro-docentmerc,
  END OF ty_zmm_expro,

  BEGIN OF ty_asignacion,
    matnr          TYPE matnr,
    menge          TYPE menge_d,
    meins          TYPE meins,
    werks          TYPE werks_d,
    cantas         TYPE menge_d,
    banfn          TYPE banfn,
    bnfpo          TYPE bnfpo,
    lfdat          TYPE lfdat,
    ebeln          TYPE ebeln,
    mblnr          TYPE mblnr,
    aedat          TYPE aedat,
    transfer_order TYPE ebeln,
  END OF ty_asignacion.

TYPES:
  tt_zmm_expro  TYPE STANDARD TABLE OF ty_zmm_expro,
  tt_asignacion TYPE STANDARD TABLE OF ty_asignacion.

*-------------------------------------------------------------------------------*
* CONSTANTES                                                                    *
*-------------------------------------------------------------------------------*
CONSTANTS:
  c_centro_3030      TYPE werks_d VALUE '3030',
  c_activo           TYPE banpr VALUE '02', "Activo
  c_liberada         TYPE banpr VALUE '05', "Liberadad
  c_pstyp_traslado   TYPE pstyp VALUE '7',
  c_bwart_devolucion TYPE bwart VALUE '122',
  c_move_reas_incomp TYPE grund VALUE '002',
  c_doc_type_zubv    TYPE bsart VALUE 'ZUBV',
  c_gm_code_01       TYPE gm_code VALUE '01',
  c_proceso_po       TYPE char20 VALUE 'EXMM03PO',
  c_proceso_dev      TYPE char20 VALUE 'EXMM03DEV',
  c_werks_var        TYPE tvarv-name VALUE 'ZMM_VIRTSTOCK-WERKS',
  c_lgort_var        TYPE tvarv-name VALUE 'ZMM_VIRTSTOCK-LGORT',
  c_ekorg_var        TYPE tvarv-name VALUE 'ZMM_VIRTSTOCK-VKORG',
  c_eq               TYPE char2 VALUE 'EQ',
  c_a                TYPE char1 VALUE 'A',
  c_b                TYPE char1 VALUE 'B',
  c_d                TYPE char1 VALUE 'D',
  c_m                TYPE char1 VALUE 'M',
  c_i                TYPE char1 VALUE 'I',
  c_p                TYPE char1 VALUE 'P',
  c_x                TYPE char1 VALUE 'X',
  c_check_rule       TYPE prreg VALUE 'ZB',
  c_stge_loc         TYPE lgort_d VALUE 'MERV',
  c_sobsl            TYPE sobsl VALUE '40'.

*-------------------------------------------------------------------------------*
* ESTRUCTURAS                                                                   *
*-------------------------------------------------------------------------------*
DATA:
  w_zmm_expro TYPE ty_zmm_expro ##NEEDED.

*-------------------------------------------------------------------------------*
* TABLAS INTERNAS                                                               *
*-------------------------------------------------------------------------------*
DATA:
  i_zmm_expro    TYPE tt_zmm_expro ##NEEDED,
  i_asignaciones TYPE tt_asignacion ##NEEDED.

*-------------------------------------------------------------------------------*
* RANGOS                                                                        *
*-------------------------------------------------------------------------------*

*-------------------------------------------------------------------------------*
* FIELD-SYMBOLS                                                                 *
*-------------------------------------------------------------------------------*

*-------------------------------------------------------------------------------*
* VARIABLES GLOBALES                                                            *
*-------------------------------------------------------------------------------*
DATA:
  " Contadores: Assign Quantities
  v_assign_procesados TYPE i ##NEEDED,
  v_assign_exitosos   TYPE i ##NEEDED,
  v_assign_errores    TYPE i ##NEEDED,
  " Contadores: Stock Transfer Order
  v_sto_procesados    TYPE i ##NEEDED,
  v_sto_exitosos      TYPE i ##NEEDED,
  v_sto_errores       TYPE i ##NEEDED,
  " Contadores: Create Return
  v_return_procesados TYPE i ##NEEDED,
  v_return_exitosos   TYPE i ##NEEDED,
  v_return_errores    TYPE i ##NEEDED,
  " Cantidad devuelta
  v_return_quantity   TYPE menge_d ##NEEDED.

*-------------------------------------------------------------------------------*
* OBJETOS                                                                       *
*-------------------------------------------------------------------------------*

*-------------------------------------------------------------------------------*
* PARÁMETROS DE SELECCIÓN                                                       *
*-------------------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-t01.
PARAMETERS: p_edate TYPE sy-datum OBLIGATORY DEFAULT sy-datum,
            p_plant TYPE werks_d DEFAULT '3030' OBLIGATORY.
SELECTION-SCREEN END OF BLOCK b1.