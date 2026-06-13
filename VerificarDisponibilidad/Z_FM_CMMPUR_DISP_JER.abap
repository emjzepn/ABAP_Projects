*-------------------------------------------------------------------------------*
*                   Fabrica de Software ABAP NEORIS                             *
*-------------------------------------------------------------------------------*
* Grupo de funciones  : ZFG_CMMPUR_DISP_JER                                     *
* Módulo de funciones : Z_FM_CMMPUR_DISP_JER                                    *
* Descripción         : Verificación de disponibilidad                          *
* Funcional           : Sarai Reyes                                             *
* Desarrollador       : Edgar Morales  - ABAP_01                                *
* Diseñador Técnico   : Edgar Morales                                           *
* Fecha de Creación   : 09.03.2026                                              *
* ID del Componente   : DF-EXMM53                                               *
* Número de Req.      : EXMM53                                                  *
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
FUNCTION z_fm_cmmpur_disp_jer.
*"----------------------------------------------------------------------
*"*"Interfase local
*"  IMPORTING
*"     VALUE(IV_WERKS) TYPE  WERKS_D
*"     VALUE(IV_MATNR) TYPE  MATNR
*"     VALUE(IV_MEINS) TYPE  MEINS
*"     VALUE(IV_MENGE) TYPE  MENGE_D
*"  EXPORTING
*"     VALUE(EV_STATUS) TYPE  CHAR4
*"     VALUE(EV_WERKS_S) TYPE  WERKS_D
*"     VALUE(EV_MESSAGE) TYPE  BAPI_MSG
*"----------------------------------------------------------------------


*&---------------------------------------------------------------------*
*& ESTRUCTURAS
*&---------------------------------------------------------------------*
  DATA:
    lw_wmdvsx TYPE bapiwmdvs.

*&---------------------------------------------------------------------*
*& TABLAS INTERNAS
*&---------------------------------------------------------------------*
  DATA:
    li_wmdvsx TYPE TABLE OF bapiwmdvs,
    li_wmdvex TYPE TABLE OF bapiwmdve.

*&---------------------------------------------------------------------*
*& VARIABLES
*&---------------------------------------------------------------------*
  DATA:
    lv_current_werks TYPE werks_d,
    lv_next_werks    TYPE werks_d,
    lv_cedis_config  TYPE werks_d,
    lv_lgort         TYPE lgort_d,
    lv_matnr_int     TYPE matnr,
    lv_available_in  TYPE char5,
    lv_error         TYPE abap_bool.

*&---------------------------------------------------------------------*
*& CONSTANTES
*&---------------------------------------------------------------------*
  CONSTANTS:
    "Constantes para Status de Disponibilidad
    lc_status_error   TYPE char1 VALUE 'E',     "Error en validación
    lc_status_sin     TYPE char1 VALUE 'X',     "Sin disponibilidad
    lc_status_nodo    TYPE char2 VALUE 'DN',    "Disponible Nodo (DN)
    lc_status_cedis_v TYPE char3 VALUE 'DCV',   "Disponible CEDIS MERV (DCV)
    lc_status_cedis_m TYPE char3 VALUE 'DCM',   "Disponible CEDIS MERC (DCM)
    lc_nodo           TYPE char4 VALUE 'NODO',  "Nodo

    "Constantes para Almacenes CEDIS
    lc_almacen_merv   TYPE lgort_d VALUE 'MERV',  "Almacén virtual CEDIS
    lc_almacen_merc   TYPE lgort_d VALUE 'MERC',  "Almacén físico CEDIS

    "Constantes de Configuración
    lc_sobsl_nodo     TYPE sobsl VALUE '40',      "Fuente de suministro Nodo
    lc_check_rule     TYPE char2 VALUE 'ZB'.      "Regla ATP customizada

*&---------------------------------------------------------------------*
*& FIELD-SYMBOLS
*&---------------------------------------------------------------------*
  FIELD-SYMBOLS:
    <lfs_wmdvex> TYPE bapiwmdve.

*&---------------------------------------------------------------------*
*& Inicio de proceso
*&---------------------------------------------------------------------*

  "Inicialización de variables de salida
  CLEAR:
    ev_status,
    ev_werks_s,
    ev_message.

  ev_status = lc_status_sin.
  lv_current_werks = iv_werks.

  "Convierte material a formato interno
  CALL FUNCTION 'CONVERSION_EXIT_MATN1_INPUT'
    EXPORTING
      input  = iv_matnr
    IMPORTING
      output = lv_matnr_int.

  "Valida parámetros
  PERFORM f_check_parameters
    USING  lv_matnr_int
           iv_werks
           iv_menge
           iv_meins
    CHANGING lv_error
             ev_message.

  IF lv_error = abap_true.
    ev_status = lc_status_sin.
    RETURN.
  ENDIF.

  "Obtiene cedis
  PERFORM f_get_cedis_tvarv
   CHANGING lv_cedis_config.

  WHILE lv_current_werks IS NOT INITIAL.

    "Valida autorización
    PERFORM f_check_authorization
      USING    lv_current_werks
      CHANGING lv_error
               ev_message.

    IF lv_error = abap_true.
      ev_status = lc_status_error.
      EXIT.
    ENDIF.

    DO 2 TIMES.
      CLEAR: lv_lgort, li_wmdvsx, li_wmdvex.

      IF lv_current_werks = lv_cedis_config.
        "En NODO: solo una iteración con MERC
        IF sy-index = 1.
          lv_lgort = lc_almacen_merc.
          lv_available_in = lc_nodo.
        ELSE.
          EXIT.  "Solo una iteración para Nodo
        ENDIF.
      ELSE.
        "En CEDIS: primera iteración MERV, segunda MERC
        IF sy-index = 1.
          lv_lgort = lc_almacen_merv.
          lv_available_in = lc_almacen_merv.
        ELSEIF sy-index = 2.
          lv_lgort = lc_almacen_merc.
          lv_available_in = lc_almacen_merc.
        ENDIF.
      ENDIF.

      lw_wmdvsx-req_date = sy-datum.
      lw_wmdvsx-req_qty  = iv_menge.
      APPEND lw_wmdvsx TO li_wmdvsx.

      "Obtiene material disponible
      CALL FUNCTION 'BAPI_MATERIAL_AVAILABILITY'
        EXPORTING
          plant      = lv_current_werks
          material   = lv_matnr_int
          unit       = iv_meins
          check_rule = lc_check_rule
          stge_loc   = lv_lgort
          stock_ind  = abap_true
        TABLES
          wmdvsx     = li_wmdvsx
          wmdvex     = li_wmdvex.

      "Verificar disponibilidad
      READ TABLE li_wmdvex ASSIGNING <lfs_wmdvex> INDEX 1.
      IF sy-subrc = 0 AND <lfs_wmdvex>-com_qty >= iv_menge.
        CASE lv_available_in.
          WHEN 'NODO'.
            ev_status = lc_status_nodo.       "DN
          WHEN 'MERV'.
            ev_status = lc_status_cedis_v.    "DCV
          WHEN 'MERC'.
            ev_status = lc_status_cedis_m.    "DCM
          WHEN OTHERS.
            ev_status = lc_status_sin.        "X
        ENDCASE.
        ev_werks_s = lv_current_werks.
        RETURN.
      ENDIF.
    ENDDO.

    IF lv_current_werks = lv_cedis_config.
      EXIT.
    ENDIF.

    "Clave de acopio especial
    SELECT SINGLE wrk02
      FROM t460a
      INTO lv_next_werks
      WHERE werks = lv_current_werks
        AND sobsl = lc_sobsl_nodo.
    IF sy-subrc <> 0 OR lv_next_werks IS INITIAL.
      EXIT.
    ELSE.
      lv_current_werks = lv_next_werks.
    ENDIF.

  ENDWHILE.

ENDFUNCTION.