CLASS zcxcl_bmmrmtbm_prpo_fleetio DEFINITION
*&---------------------------------------------------------------------*
*& Clase: ZCXCL_BMMRMTBM_PRPO_FLEETIO
*& Descripción: Gestión completa de trazabilidad PR/PO y construcción
*&              JSON para interfaz Fleetio
*& Autor: Edgar Morales
*& Fecha: 01.06.2026
*& Requerimiento: SR - Fleetio PR/PO Outbound Response Interface
*& Especificación: PPC-FD-00-CX-O-EN-V2.0-FUD-Fleetio-PRPO-Outbound
*&---------------------------------------------------------------------*
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    "*====================================================================*
    "* DEFINICIÓN DE TIPOS PARA ESTRUCTURA JSON
    "*====================================================================*

    "Items de Purchase Order
    TYPES: BEGIN OF ty_po_item,
             zpmt_flt_prpo_po_action TYPE string,
             ekpo_ebeln              TYPE string,
             ekpo_ebelp              TYPE string,
             eban_banfn              TYPE string,
             eban_bnfpo              TYPE string,
             ekpo_matnr              TYPE string,
             ekpo_txz01              TYPE string,
             ekpo_werks              TYPE string,
             ekpo_lgort              TYPE string,
             ekpo_matkl              TYPE string,
             ekpo_menge              TYPE string,
             ekpo_meins              TYPE string,
             ekpo_bprme              TYPE string,
             ekpo_peinh              TYPE string,
             ekpo_netpr              TYPE string,
             ekpo_netwr              TYPE string,
             ekpo_loekz              TYPE string,
             ekpo_elikz              TYPE string,
           END OF ty_po_item.
    TYPES: tt_po_item TYPE STANDARD TABLE OF ty_po_item WITH DEFAULT KEY.

    "Estructura de Purchase Order
    TYPES: BEGIN OF ty_purchase_order,
             ekko_ebeln TYPE string,
             ekko_lifnr TYPE string,
             ekko_ekorg TYPE string,
             ekko_ekgrp TYPE string,
             ekko_waers TYPE string,
             lfa1_name1 TYPE string,
             items      TYPE tt_po_item,
           END OF ty_purchase_order.
    TYPES: tt_purchase_order TYPE STANDARD TABLE OF ty_purchase_order WITH DEFAULT KEY.

    "Estructura de Purchase Requisition
    TYPES: BEGIN OF ty_purchase_requisition,
             eban_banfn              TYPE string,
             eban_bnfpo              TYPE string,
             ebkn_aufnr              TYPE string,
             eban_werks              TYPE string,
             zpmt_flt_prpo_pr_action TYPE string,
             eban_matnr              TYPE string,
             eban_txz01              TYPE string,
             eban_menge              TYPE string,
             eban_meins              TYPE string,
             eban_matkl              TYPE string,
             eban_ekgrp              TYPE string,
             eban_ekorg              TYPE string,
             eban_preis              TYPE string,
             eban_peinh              TYPE string,
             eban_waers              TYPE string,
             eban_loekz              TYPE string,
             ebkn_sakto              TYPE string,
             ebkn_kokrs              TYPE string,
             eban_ebeln              TYPE string,
             eban_ebelp              TYPE string,
           END OF ty_purchase_requisition.
    TYPES: tt_purchase_requisition TYPE STANDARD TABLE OF ty_purchase_requisition WITH DEFAULT KEY.

    "Estructura completa de respuesta Fleetio
    TYPES: BEGIN OF ty_fleetio_response,
             zta0108_odatal_id          TYPE string,
             zta0108_odatal_type        TYPE string,
             zta0108_odatal_workorder   TYPE string,
             zta0108_odatal_external_id TYPE string,
             zta0108_odatal_origin_id   TYPE string,
             zta0108_odatal_message     TYPE string,
             zpmt_flt_prpo_status       TYPE string,
             zpmt_flt_prpo_code         TYPE string,
             zpmt_flt_prpo_message_text TYPE string,
             purchaserequisitions       TYPE tt_purchase_requisition,
             purchaseorders             TYPE tt_purchase_order,
           END OF ty_fleetio_response.

    "Estructura interna de trazabilidad
    TYPES: BEGIN OF ty_prpo_trace,
             fleetio_id     TYPE zde_flt_ordid,
             aufnr          TYPE aufnr,
             doc_type       TYPE zde_doctype,
             log_seq        TYPE zde_logseq,
             status         TYPE j_txt30,
             code           TYPE j_txt30,
             message_text   TYPE zde_bp_msg,
             banfn          TYPE banfn,
             bnfpo          TYPE bnfpo,
             ebeln          TYPE ebeln,
             ebelp          TYPE ebelp,
             lifnr          TYPE elifn,
             waers          TYPE waers,
             pr_werks       TYPE werks_d,
             pr_matnr       TYPE matnr,
             pr_txz01       TYPE txz01,
             pr_menge       TYPE bamng,
             pr_meins       TYPE bamei,
             pr_matkl       TYPE matkl,
             pr_ekgrp       TYPE ekgrp,
             pr_ekorg       TYPE ekorg,
             pr_preis       TYPE bapre,
             pr_peinh       TYPE epein,
             pr_waers       TYPE waers,
             eban_loekz     TYPE eloek,
             ebkn_sakto     TYPE saknr,
             ebkn_kokrs     TYPE kokrs,
             po_werks       TYPE werks_d,
             po_lgort       TYPE lgort_d,
             po_matnr       TYPE matnr,
             po_txz01       TYPE txz01,
             po_menge       TYPE bstmg,
             po_meins       TYPE bstme,
             po_matkl       TYPE matkl,
             po_bprme       TYPE bbprm,
             po_peinh       TYPE epein,
             netpr          TYPE bprei,
             netwr          TYPE bwert,
             ekpo_loekz     TYPE eloek,
             ekpo_elikz     TYPE elikz,
             po_ekorg       TYPE ekorg,
             po_ekgrp       TYPE ekgrp,
             out_status     TYPE j_txt30,
             out_message_id TYPE zde_msgid,
             out_error_text TYPE zde_msgtxt,
             retry_count    TYPE i,
             changed_on     TYPE syst_datum,
             changed_at     TYPE syst_uzeit,
             changed_by     TYPE uname,
           END OF ty_prpo_trace.

    "Tabla tipo de trazabilidad
    TYPES: tt_prpo_trace TYPE STANDARD TABLE OF ty_prpo_trace WITH DEFAULT KEY.

    "*====================================================================*
    "* CONSTANTES PÚBLICAS
    "*====================================================================*

    "Constantes para tipos de documento
    CONSTANTS: BEGIN OF c_doc_type,
                 pr TYPE char2 VALUE 'PR',
                 po TYPE char2 VALUE 'PO',
               END OF c_doc_type.

    "Constantes para status
    CONSTANTS: BEGIN OF c_status,
                 pr_created TYPE char15 VALUE 'PR_CREATED',
                 pr_updated TYPE char15 VALUE 'PR_UPDATED',
                 po_created TYPE char15 VALUE 'PO_CREATED',
                 po_updated TYPE char15 VALUE 'PO_UPDATED',
                 deleted    TYPE char15 VALUE 'DELETED',
                 completed  TYPE char15 VALUE 'COMPLETED',
                 success    TYPE char15 VALUE 'SUCCESS',
                 error      TYPE char15 VALUE 'ERROR',
               END OF c_status.

    "Constantes para códigos de proceso
    CONSTANTS: BEGIN OF c_code,
                 wo_created TYPE char30 VALUE 'WO_CREATED',
                 wo_error   TYPE char30 VALUE 'WO_ERROR',
                 pr_created TYPE char30 VALUE 'PR_CREATED',
                 pr_updated TYPE char30 VALUE 'PR_UPDATED',
                 po_created TYPE char30 VALUE 'PO_CREATED',
                 po_updated TYPE char30 VALUE 'PO_UPDATED',
               END OF c_code.

    "Constantes para outbound status
    CONSTANTS: BEGIN OF c_out_status,
                 pending TYPE char12 VALUE 'PENDING',
                 sent    TYPE char12 VALUE 'SENT',
                 error   TYPE char12 VALUE 'ERROR',
                 retry   TYPE char12 VALUE 'RETRY',
               END OF c_out_status.

    "Constantes para acciones de PR/PO
    CONSTANTS: BEGIN OF c_action,
                 pr_created TYPE string VALUE 'PR_CREATED',
                 pr_updated TYPE string VALUE 'PR_UPDATED',
                 po_created TYPE string VALUE 'PO_CREATED',
                 created    TYPE string VALUE 'CREATED',
                 updated    TYPE string VALUE 'UPDATED',
                 deleted    TYPE string VALUE 'DELETED',
                 completed  TYPE string VALUE 'COMPLETED',
               END OF c_action.

    "*====================================================================*
    "* MÉTODOS PÚBLICOS - GESTIÓN DE TRAZABILIDAD
    "*====================================================================*

    "Constructor
    METHODS constructor.

    METHODS register_pr_creation
      IMPORTING
        iv_banfn        TYPE banfn
        iv_bnfpo        TYPE bnfpo
        iv_aufnr        TYPE aufnr OPTIONAL
        iv_fleetio_id   TYPE zpmt_flt_prpo-fleetio_id OPTIONAL
      RETURNING
        VALUE(rs_trace) TYPE ty_prpo_trace.

    METHODS register_po_creation
      IMPORTING
        iv_ebeln        TYPE ebeln
        iv_ebelp        TYPE ebelp
        iv_banfn        TYPE banfn OPTIONAL
        iv_bnfpo        TYPE bnfpo OPTIONAL
      RETURNING
        VALUE(rs_trace) TYPE ty_prpo_trace.

    METHODS register_po_change
      IMPORTING
        iv_ebeln        TYPE ebeln
        iv_ebelp        TYPE ebelp
        iv_change_type  TYPE char20
      RETURNING
        VALUE(rs_trace) TYPE ty_prpo_trace.

    METHODS get_pending_records
      RETURNING
        VALUE(rt_traces) TYPE tt_prpo_trace.


    METHODS update_outbound_status
      IMPORTING
        iv_fleetio_id     TYPE zpmt_flt_prpo-fleetio_id
        iv_aufnr          TYPE aufnr
        iv_log_seq        TYPE zpmt_flt_prpo-log_seq
        iv_out_status     TYPE char20
        iv_message_id     TYPE char3 OPTIONAL
        iv_error_text     TYPE char40 OPTIONAL
      RETURNING
        VALUE(rv_success) TYPE abap_bool.

    "*====================================================================*
    "* MÉTODOS PÚBLICOS - CONSTRUCCIÓN JSON
    "*====================================================================*

    METHODS build_json_response
      IMPORTING
        iv_fleetio_id  TYPE zpmt_flt_prpo-fleetio_id
        iv_aufnr       TYPE aufnr
        it_traces      TYPE tt_prpo_trace OPTIONAL
      RETURNING
        VALUE(rv_json) TYPE string.

    METHODS get_traces_by_wo
      IMPORTING
        iv_fleetio_id    TYPE zpmt_flt_prpo-fleetio_id
        iv_aufnr         TYPE aufnr
      RETURNING
        VALUE(rt_traces) TYPE tt_prpo_trace.

  PROTECTED SECTION.

  PRIVATE SECTION.

    "*====================================================================*
    "* CONSTANTES PRIVADAS
    "*====================================================================*
    CONSTANTS:
      c_max_retry      TYPE numc3 VALUE '003',  "Máximo de reintentos
      c_origin_fleetio TYPE char20 VALUE 'Fleetio'.

    "*====================================================================*
    "* MÉTODOS PRIVADOS - GESTIÓN DE TRAZABILIDAD
    "*====================================================================*

    METHODS get_fleetio_correlation
      IMPORTING
        iv_aufnr             TYPE aufnr
      RETURNING
        VALUE(rv_fleetio_id) TYPE zpmt_flt_prpo-fleetio_id.

    METHODS is_plant_active
      IMPORTING
        iv_werks            TYPE werks_d
      RETURNING
        VALUE(rv_is_active) TYPE abap_bool.

    METHODS get_next_sequence
      IMPORTING
        iv_fleetio_id     TYPE zpmt_flt_prpo-fleetio_id
        iv_aufnr          TYPE aufnr
        iv_doc_type       TYPE zpmt_flt_prpo-doc_type
      RETURNING
        VALUE(rv_log_seq) TYPE zpmt_flt_prpo-log_seq.

    METHODS enrich_pr_data
      IMPORTING
        iv_banfn TYPE banfn
        iv_bnfpo TYPE bnfpo
      CHANGING
        cs_trace TYPE ty_prpo_trace.

    METHODS enrich_po_data
      IMPORTING
        iv_ebeln TYPE ebeln
        iv_ebelp TYPE ebelp
      CHANGING
        cs_trace TYPE ty_prpo_trace.

    "*====================================================================*
    "* MÉTODOS PRIVADOS - CONSTRUCCIÓN JSON
    "*====================================================================*

    METHODS build_pr_section
      CHANGING
        it_traces         TYPE tt_prpo_trace
      RETURNING
        VALUE(rt_pr_list) TYPE tt_purchase_requisition.

    METHODS build_po_section
      CHANGING
        it_traces         TYPE tt_prpo_trace
      RETURNING
        VALUE(rt_po_list) TYPE tt_purchase_order.

    METHODS get_wo_log_data
      IMPORTING
        iv_aufnr         TYPE aufnr
      RETURNING
        VALUE(rs_odatal) TYPE zta0108_odatal.

    METHODS convert_to_string
      IMPORTING
        iv_value         TYPE any
      RETURNING
        VALUE(rv_string) TYPE string.

    METHODS get_vendor_name
      IMPORTING
        iv_lifnr        TYPE lifnr
      RETURNING
        VALUE(rv_name1) TYPE string.

    METHODS convert_db_to_trace
      IMPORTING
        is_zpmt         TYPE zpmt_flt_prpo
      RETURNING
        VALUE(rs_trace) TYPE ty_prpo_trace.

    METHODS convert_trace_to_db
      IMPORTING
        is_trace       TYPE ty_prpo_trace
      RETURNING
        VALUE(rs_zpmt) TYPE zpmt_flt_prpo.

    METHODS write_application_log
      IMPORTING
        iv_msgty TYPE sy-msgty DEFAULT 'E'
        iv_msgno TYPE sy-msgno DEFAULT '001'
        iv_msgv1 TYPE sy-msgv1 OPTIONAL
        iv_msgv2 TYPE sy-msgv2 OPTIONAL
        iv_msgv3 TYPE sy-msgv3 OPTIONAL
        iv_msgv4 TYPE sy-msgv4 OPTIONAL.

ENDCLASS.



CLASS ZCXCL_BMMRMTBM_PRPO_FLEETIO IMPLEMENTATION.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCXCL_BMMRMTBM_PRPO_FLEETIO->BUILD_JSON_RESPONSE
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_FLEETIO_ID                  TYPE        ZPMT_FLT_PRPO-FLEETIO_ID
* | [--->] IV_AUFNR                       TYPE        AUFNR
* | [--->] IT_TRACES                      TYPE        TT_PRPO_TRACE(optional)
* | [<-()] RV_JSON                        TYPE        STRING
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD build_json_response.

    DATA:
      lw_response TYPE ty_fleetio_response,
      lw_odatal   TYPE zta0108_odatal.

    DATA:
      lt_pr_traces TYPE tt_prpo_trace,
      lt_po_traces TYPE tt_prpo_trace,
      lt_traces    TYPE tt_prpo_trace.

    DATA:
      lv_status  TYPE string,
      lv_code    TYPE string,
      lv_message TYPE string.

    "Obtener datos del log de WO (WO-01)
    lw_odatal = get_wo_log_data( iv_aufnr ).

    "Si no se proporcionaron trazas, obtenerlas automáticamente
    IF it_traces IS INITIAL.
      lt_traces = get_traces_by_wo(
        iv_fleetio_id = iv_fleetio_id
        iv_aufnr      = iv_aufnr ).
    ELSE.
      lt_traces = it_traces.
    ENDIF.

    "Separar trazas por tipo de documento
    LOOP AT lt_traces ASSIGNING FIELD-SYMBOL(<ls_trace>).
      IF <ls_trace>-doc_type = c_doc_type-pr.
        APPEND <ls_trace> TO lt_pr_traces.
      ELSEIF <ls_trace>-doc_type = c_doc_type-po.
        APPEND <ls_trace> TO lt_po_traces.
      ENDIF.
    ENDLOOP.

    "Determinar status y código principal (WO-02)
    IF lw_odatal-type = 'E'.
      lv_status  = c_status-error.
      lv_code    = c_code-wo_error.
      lv_message = lw_odatal-message.
    ELSEIF lines( lt_po_traces ) > 0.
      "Hay PO, tomar el último status
      READ TABLE lt_po_traces INDEX lines( lt_po_traces ) ASSIGNING FIELD-SYMBOL(<ls_last_po>).
      IF sy-subrc = 0.
        lv_status  = <ls_last_po>-status.
        lv_code    = <ls_last_po>-code.
        lv_message = <ls_last_po>-message_text.
      ENDIF.
    ELSEIF lines( lt_pr_traces ) > 0.
      "Hay PR, tomar el último status
      READ TABLE lt_pr_traces INDEX lines( lt_pr_traces ) ASSIGNING FIELD-SYMBOL(<ls_last_pr>).
      IF sy-subrc = 0.
        lv_status  = <ls_last_pr>-status.
        lv_code    = <ls_last_pr>-code.
        lv_message = <ls_last_pr>-message_text.
      ENDIF.
    ELSE.
      "Solo WO
      lv_status  = c_status-success.
      lv_code    = c_code-wo_created.
      lv_message = lw_odatal-message.
    ENDIF.

    "Llenar estructura de respuesta - Datos de cabecera
    lw_response-zta0108_odatal_id          = convert_to_string( lw_odatal-id ).
    lw_response-zta0108_odatal_type        = convert_to_string( lw_odatal-type ).
    lw_response-zta0108_odatal_workorder   = convert_to_string( lw_odatal-workorder ).
    lw_response-zta0108_odatal_external_id = convert_to_string( lw_odatal-external_id ).
    lw_response-zta0108_odatal_origin_id   = convert_to_string( lw_odatal-origin_id ).
    lw_response-zta0108_odatal_message     = convert_to_string( lw_odatal-message ).
    lw_response-zpmt_flt_prpo_status       = lv_status.
    lw_response-zpmt_flt_prpo_code         = lv_code.
    lw_response-zpmt_flt_prpo_message_text = lv_message.

    "Construir secciones de PR y PO
    lw_response-purchaserequisitions = build_pr_section( CHANGING it_traces = lt_pr_traces ).
    lw_response-purchaseorders       = build_po_section( CHANGING it_traces = lt_po_traces ).

    "Serializar estructura a JSON usando /ui2/cl_json
    TRY.
        rv_json = /ui2/cl_json=>serialize(
          data             = lw_response
          compress         = abap_false        "JSON con formato legible
          pretty_name      = /ui2/cl_json=>pretty_mode-camel_case "camelCase
        ).

      CATCH cx_sy_move_cast_error INTO DATA(lx_cast).
*        write_application_log(
*          iv_msgty = 'E'
*          iv_msgv1 = 'JSON Cast error'
*          iv_msgv2 = lx_cast->get_text( ) ).
        CLEAR rv_json.

      CATCH cx_root INTO DATA(lx_root).
*        write_application_log(
*          iv_msgty = 'E'
*          iv_msgv1 = 'JSON Serialize error'
*          iv_msgv2 = lx_root->get_text( ) ).
        CLEAR rv_json.
    ENDTRY.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCXCL_BMMRMTBM_PRPO_FLEETIO->BUILD_PO_SECTION
* +-------------------------------------------------------------------------------------------------+
* | [<-->] IT_TRACES                      TYPE        TT_PRPO_TRACE
* | [<-()] RT_PO_LIST                     TYPE        TT_PURCHASE_ORDER
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD build_po_section.

    DATA:
      lw_po      TYPE ty_purchase_order,
      lw_po_item TYPE ty_po_item.

    DATA:
      lv_po_action  TYPE string,
      lv_prev_ebeln TYPE string.

    CLEAR rt_po_list.

    "Ordenar trazas por EBELN para agrupar
    SORT it_traces BY ebeln ebelp.

    LOOP AT it_traces ASSIGNING FIELD-SYMBOL(<ls_trace>).

      "Si cambia el número de PO, agregar el PO anterior y crear uno nuevo
      IF <ls_trace>-ebeln <> lv_prev_ebeln AND lv_prev_ebeln IS NOT INITIAL.
        "Agregar PO anterior a tabla de retorno
        APPEND lw_po TO rt_po_list.
        CLEAR: lw_po.
      ENDIF.

      "Si es un nuevo PO o el primero, inicializar cabecera
      IF <ls_trace>-ebeln <> lv_prev_ebeln.
        lw_po-ekko_ebeln = <ls_trace>-ebeln.
        lw_po-ekko_lifnr = <ls_trace>-lifnr.
        lw_po-ekko_waers = <ls_trace>-waers.
        lw_po-ekko_ekorg = <ls_trace>-po_ekorg.
        lw_po-ekko_ekgrp = <ls_trace>-po_ekgrp.
*        lw_po-lfa1_name1 = get_vendor_name( <ls_trace>-lifnr ).

        CLEAR lw_po-items.
      ENDIF.

      "Determinar acción de PO (PO-04, PO-05, PO-06)
      CASE <ls_trace>-status.
        WHEN c_status-po_created.
          lv_po_action = c_action-created.
        WHEN c_status-po_updated.
          lv_po_action = c_action-updated.
        WHEN c_status-deleted.
          lv_po_action = c_action-deleted.
        WHEN c_status-completed.
          lv_po_action = c_action-completed.
        WHEN OTHERS.
          lv_po_action = c_action-updated.
      ENDCASE.

      "Construir item de PO (campos ya son STRING)
      CLEAR lw_po_item.
      lw_po_item-zpmt_flt_prpo_po_action = lv_po_action.
      lw_po_item-ekpo_ebeln              = <ls_trace>-ebeln.
      lw_po_item-ekpo_ebelp              = <ls_trace>-ebelp.
      lw_po_item-eban_banfn              = <ls_trace>-banfn.
      lw_po_item-eban_bnfpo              = <ls_trace>-bnfpo.
      lw_po_item-ekpo_matnr              = <ls_trace>-po_matnr.
      lw_po_item-ekpo_txz01              = <ls_trace>-po_txz01.
      lw_po_item-ekpo_werks              = <ls_trace>-po_werks.
      lw_po_item-ekpo_lgort              = <ls_trace>-po_lgort.
      lw_po_item-ekpo_matkl              = <ls_trace>-po_matkl.
      lw_po_item-ekpo_menge              = <ls_trace>-po_menge.
      lw_po_item-ekpo_meins              = <ls_trace>-po_meins.
      lw_po_item-ekpo_bprme              = <ls_trace>-po_bprme.
      lw_po_item-ekpo_peinh              = <ls_trace>-po_peinh.
      lw_po_item-ekpo_netpr              = <ls_trace>-netpr.
      lw_po_item-ekpo_netwr              = <ls_trace>-netwr.
      lw_po_item-ekpo_loekz              = <ls_trace>-ekpo_loekz.
      lw_po_item-ekpo_elikz              = <ls_trace>-ekpo_elikz.

      "Agregar item a la PO
      APPEND lw_po_item TO lw_po-items.

      lv_prev_ebeln = <ls_trace>-ebeln.

    ENDLOOP.

    "Agregar última PO si existe
    IF lw_po-ekko_ebeln IS NOT INITIAL.
      APPEND lw_po TO rt_po_list.
    ENDIF.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCXCL_BMMRMTBM_PRPO_FLEETIO->BUILD_PR_SECTION
* +-------------------------------------------------------------------------------------------------+
* | [<-->] IT_TRACES                      TYPE        TT_PRPO_TRACE
* | [<-()] RT_PR_LIST                     TYPE        TT_PURCHASE_REQUISITION
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD build_pr_section.

    DATA:
      lw_pr        TYPE ty_purchase_requisition.

    DATA:
      lv_pr_action TYPE string.

    CLEAR rt_pr_list.

    LOOP AT it_traces ASSIGNING FIELD-SYMBOL(<ls_trace>).

      CLEAR lw_pr.

      "Determinar acción de PR
      CASE <ls_trace>-status.
        WHEN c_status-pr_created.
          lv_pr_action = c_action-pr_created.
        WHEN c_status-pr_updated.
          lv_pr_action = c_action-pr_updated.
        WHEN c_status-po_created OR c_status-po_updated.
          lv_pr_action = c_action-po_created.
        WHEN c_status-deleted.
          lv_pr_action = c_action-deleted.
        WHEN OTHERS.
          lv_pr_action = c_action-pr_created.
      ENDCASE.

      "Llenar campos desde traza (ya son STRING)
      lw_pr-eban_banfn              = <ls_trace>-banfn.
      lw_pr-eban_bnfpo              = <ls_trace>-bnfpo.
      lw_pr-ebkn_aufnr              = <ls_trace>-aufnr.
      lw_pr-eban_werks              = <ls_trace>-pr_werks.
      lw_pr-zpmt_flt_prpo_pr_action = lv_pr_action.
      lw_pr-eban_matnr              = <ls_trace>-pr_matnr.
      lw_pr-eban_txz01              = <ls_trace>-pr_txz01.
      lw_pr-eban_menge              = <ls_trace>-pr_menge.
      lw_pr-eban_meins              = <ls_trace>-pr_meins.
      lw_pr-eban_matkl              = <ls_trace>-pr_matkl.
      lw_pr-eban_ekgrp              = <ls_trace>-pr_ekgrp.
      lw_pr-eban_ekorg              = <ls_trace>-pr_ekorg.
      lw_pr-eban_preis              = <ls_trace>-pr_preis.
      lw_pr-eban_peinh              = <ls_trace>-pr_peinh.
      lw_pr-eban_waers              = <ls_trace>-pr_waers.
      lw_pr-eban_loekz              = <ls_trace>-eban_loekz.
      lw_pr-ebkn_sakto              = <ls_trace>-ebkn_sakto.
      lw_pr-ebkn_kokrs              = <ls_trace>-ebkn_kokrs.
      lw_pr-eban_ebeln              = <ls_trace>-ebeln.
      lw_pr-eban_ebelp              = <ls_trace>-ebelp.

      "Agregar a tabla de retorno
      APPEND lw_pr TO rt_pr_list.

    ENDLOOP.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCXCL_BMMRMTBM_PRPO_FLEETIO->CONSTRUCTOR
* +-------------------------------------------------------------------------------------------------+
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD constructor.
    "Inicialización de la clase si es necesario
  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCXCL_BMMRMTBM_PRPO_FLEETIO->CONVERT_DB_TO_TRACE
* +-------------------------------------------------------------------------------------------------+
* | [--->] IS_ZPMT                        TYPE        ZPMT_FLT_PRPO
* | [<-()] RS_TRACE                       TYPE        TY_PRPO_TRACE
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD convert_db_to_trace.

    "Convertir todos los campos de estructura DB a STRING
    rs_trace-fleetio_id     = convert_to_string( is_zpmt-fleetio_id ).
    rs_trace-aufnr          = convert_to_string( is_zpmt-aufnr ).
    rs_trace-doc_type       = convert_to_string( is_zpmt-doc_type ).
    rs_trace-log_seq        = convert_to_string( is_zpmt-log_seq ).
    rs_trace-status         = convert_to_string( is_zpmt-status ).
    rs_trace-code           = convert_to_string( is_zpmt-code ).
    rs_trace-message_text   = convert_to_string( is_zpmt-message_text ).
    rs_trace-banfn          = convert_to_string( is_zpmt-banfn ).
    rs_trace-bnfpo          = convert_to_string( is_zpmt-bnfpo ).
    rs_trace-ebeln          = convert_to_string( is_zpmt-ebeln ).
    rs_trace-ebelp          = convert_to_string( is_zpmt-ebelp ).
    rs_trace-lifnr          = convert_to_string( is_zpmt-lifnr ).
    rs_trace-waers          = convert_to_string( is_zpmt-waers ).
*    rs_trace-pr_werks       = convert_to_string( is_zpmt-pr_werks ).
    rs_trace-pr_matnr       = convert_to_string( is_zpmt-pr_matnr ).
    rs_trace-pr_txz01       = convert_to_string( is_zpmt-pr_txz01 ).
    rs_trace-pr_menge       = convert_to_string( is_zpmt-pr_menge ).
    rs_trace-pr_meins       = convert_to_string( is_zpmt-pr_meins ).
*    rs_trace-pr_matkl       = convert_to_string( is_zpmt-pr_matkl ).
*    rs_trace-pr_ekgrp       = convert_to_string( is_zpmt-pr_ekgrp ).
*    rs_trace-pr_ekorg       = convert_to_string( is_zpmt-pr_ekorg ).
*    rs_trace-pr_preis       = convert_to_string( is_zpmt-pr_preis ).
*    rs_trace-pr_peinh       = convert_to_string( is_zpmt-pr_peinh ).
*    rs_trace-pr_waers       = convert_to_string( is_zpmt-pr_waers ).
*    rs_trace-eban_loekz     = convert_to_string( is_zpmt-eban_loekz ).
*    rs_trace-ebkn_sakto     = convert_to_string( is_zpmt-ebkn_sakto ).
*    rs_trace-ebkn_kokrs     = convert_to_string( is_zpmt-ebkn_kokrs ).
*    rs_trace-po_werks       = convert_to_string( is_zpmt-po_werks ).
*    rs_trace-po_lgort       = convert_to_string( is_zpmt-po_lgort ).
*    rs_trace-po_matnr       = convert_to_string( is_zpmt-po_matnr ).
*    rs_trace-po_txz01       = convert_to_string( is_zpmt-po_txz01 ).
*    rs_trace-po_menge       = convert_to_string( is_zpmt-po_menge ).
*    rs_trace-po_meins       = convert_to_string( is_zpmt-po_meins ).
*    rs_trace-po_matkl       = convert_to_string( is_zpmt-po_matkl ).
*    rs_trace-po_bprme       = convert_to_string( is_zpmt-po_bprme ).
*    rs_trace-po_peinh       = convert_to_string( is_zpmt-po_peinh ).
*    rs_trace-netpr          = convert_to_string( is_zpmt-netpr ).
*    rs_trace-netwr          = convert_to_string( is_zpmt-netwr ).
*    rs_trace-ekpo_loekz     = convert_to_string( is_zpmt-ekpo_loekz ).
*    rs_trace-ekpo_elikz     = convert_to_string( is_zpmt-ekpo_elikz ).
*    rs_trace-po_ekorg       = convert_to_string( is_zpmt-po_ekorg ).
*    rs_trace-po_ekgrp       = convert_to_string( is_zpmt-po_ekgrp ).
*    rs_trace-out_status     = convert_to_string( is_zpmt-out_status ).
*    rs_trace-out_message_id = convert_to_string( is_zpmt-out_message_id ).
*    rs_trace-out_error_text = convert_to_string( is_zpmt-out_error_text ).
*    rs_trace-retry_count    = convert_to_string( is_zpmt-retry_count ).
*    rs_trace-changed_on     = convert_to_string( is_zpmt-changed_on ).
*    rs_trace-changed_at     = convert_to_string( is_zpmt-changed_at ).
*    rs_trace-changed_by     = convert_to_string( is_zpmt-changed_by ).

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCXCL_BMMRMTBM_PRPO_FLEETIO->CONVERT_TO_STRING
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_VALUE                       TYPE        ANY
* | [<-()] RV_STRING                      TYPE        STRING
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD convert_to_string.

    DATA: lv_temp TYPE string.

    "Si el valor está vacío, retornar string vacío
    IF iv_value IS INITIAL.
      rv_string = ''.
      RETURN.
    ENDIF.

    "Convertir a string
    lv_temp = iv_value.

    "Eliminar espacios en blanco iniciales y finales
    CONDENSE lv_temp NO-GAPS.
    rv_string = lv_temp.

    "Para valores numéricos, eliminar ceros iniciales si aplica
    IF iv_value CO '0123456789 .,-'.
      SHIFT rv_string LEFT DELETING LEADING '0'.
      IF rv_string IS INITIAL OR rv_string = '.'.
        rv_string = '0'.
      ENDIF.
    ENDIF.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCXCL_BMMRMTBM_PRPO_FLEETIO->CONVERT_TRACE_TO_DB
* +-------------------------------------------------------------------------------------------------+
* | [--->] IS_TRACE                       TYPE        TY_PRPO_TRACE
* | [<-()] RS_ZPMT                        TYPE        ZPMT_FLT_PRPO
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD convert_trace_to_db.

    "Convertir estructura STRING trace a tipos originales de DB
    rs_zpmt-mandt           = sy-mandt.
    rs_zpmt-fleetio_id      = is_trace-fleetio_id.
    rs_zpmt-aufnr           = is_trace-aufnr.
    rs_zpmt-doc_type        = is_trace-doc_type.
    rs_zpmt-log_seq         = is_trace-log_seq.
    rs_zpmt-status          = is_trace-status.
    rs_zpmt-code            = is_trace-code.
    rs_zpmt-message_text    = is_trace-message_text.
    rs_zpmt-banfn           = is_trace-banfn.
    rs_zpmt-bnfpo           = is_trace-bnfpo.
    rs_zpmt-ebeln           = is_trace-ebeln.
    rs_zpmt-ebelp           = is_trace-ebelp.
    rs_zpmt-lifnr           = is_trace-lifnr.
    rs_zpmt-waers           = is_trace-waers.
*    rs_zpmt-pr_werks        = is_trace-pr_werks.
*    rs_zpmt-pr_matnr        = is_trace-pr_matnr.
*    rs_zpmt-pr_txz01        = is_trace-pr_txz01.
*    rs_zpmt-pr_menge        = is_trace-pr_menge.
*    rs_zpmt-pr_meins        = is_trace-pr_meins.
*    rs_zpmt-pr_matkl        = is_trace-pr_matkl.
*    rs_zpmt-pr_ekgrp        = is_trace-pr_ekgrp.
*    rs_zpmt-pr_ekorg        = is_trace-pr_ekorg.
*    rs_zpmt-pr_preis        = is_trace-pr_preis.
*    rs_zpmt-pr_peinh        = is_trace-pr_peinh.
*    rs_zpmt-pr_waers        = is_trace-pr_waers.
*    rs_zpmt-eban_loekz      = is_trace-eban_loekz.
*    rs_zpmt-ebkn_sakto      = is_trace-ebkn_sakto.
*    rs_zpmt-ebkn_kokrs      = is_trace-ebkn_kokrs.
*    rs_zpmt-po_werks        = is_trace-po_werks.
*    rs_zpmt-po_lgort        = is_trace-po_lgort.
*    rs_zpmt-po_matnr        = is_trace-po_matnr.
*    rs_zpmt-po_txz01        = is_trace-po_txz01.
*    rs_zpmt-po_menge        = is_trace-po_menge.
*    rs_zpmt-po_meins        = is_trace-po_meins.
*    rs_zpmt-po_matkl        = is_trace-po_matkl.
*    rs_zpmt-po_bprme        = is_trace-po_bprme.
*    rs_zpmt-po_peinh        = is_trace-po_peinh.
*    rs_zpmt-netpr           = is_trace-netpr.
*    rs_zpmt-netwr           = is_trace-netwr.
*    rs_zpmt-ekpo_loekz      = is_trace-ekpo_loekz.
*    rs_zpmt-ekpo_elikz      = is_trace-ekpo_elikz.
*    rs_zpmt-po_ekorg        = is_trace-po_ekorg.
*    rs_zpmt-po_ekgrp        = is_trace-po_ekgrp.
*    rs_zpmt-out_status      = is_trace-out_status.
*    rs_zpmt-out_message_id  = is_trace-out_message_id.
*    rs_zpmt-out_error_text  = is_trace-out_error_text.
*    rs_zpmt-retry_count     = is_trace-retry_count.
*    rs_zpmt-changed_on      = is_trace-changed_on.
*    rs_zpmt-changed_at      = is_trace-changed_at.
*    rs_zpmt-changed_by      = is_trace-changed_by.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCXCL_BMMRMTBM_PRPO_FLEETIO->ENRICH_PO_DATA
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_EBELN                       TYPE        EBELN
* | [--->] IV_EBELP                       TYPE        EBELP
* | [<-->] CS_TRACE                       TYPE        TY_PRPO_TRACE
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD enrich_po_data.

    DATA:
      lw_ekpo TYPE ekpo,
      lw_ekko TYPE ekko.

    "Leer datos detallados de PO - posición
    SELECT SINGLE *
      FROM ekpo
      INTO @lw_ekpo
      WHERE ebeln = @iv_ebeln
        AND ebelp = @iv_ebelp.

    IF sy-subrc = 0.
      cs_trace-po_werks   = convert_to_string( lw_ekpo-werks ).
      cs_trace-po_lgort   = convert_to_string( lw_ekpo-lgort ).
      cs_trace-po_matnr   = convert_to_string( lw_ekpo-matnr ).
      cs_trace-po_txz01   = convert_to_string( lw_ekpo-txz01 ).
      cs_trace-po_menge   = convert_to_string( lw_ekpo-menge ).
      cs_trace-po_meins   = convert_to_string( lw_ekpo-meins ).
      cs_trace-po_matkl   = convert_to_string( lw_ekpo-matkl ).
      cs_trace-po_bprme   = convert_to_string( lw_ekpo-bprme ).
      cs_trace-po_peinh   = convert_to_string( lw_ekpo-peinh ).
      cs_trace-netpr      = convert_to_string( lw_ekpo-netpr ).
      cs_trace-netwr      = convert_to_string( lw_ekpo-netwr ).
      cs_trace-ekpo_loekz = convert_to_string( lw_ekpo-loekz ).
      cs_trace-ekpo_elikz = convert_to_string( lw_ekpo-elikz ).

      "Si no se llenó antes, tomar del EKPO
      IF cs_trace-banfn IS INITIAL.
        cs_trace-banfn = convert_to_string( lw_ekpo-banfn ).
        cs_trace-bnfpo = convert_to_string( lw_ekpo-bnfpo ).
      ENDIF.
    ENDIF.

    "Leer cabecera de PO
    SELECT SINGLE *
      FROM ekko
      INTO @lw_ekko
      WHERE ebeln = @iv_ebeln.

    IF sy-subrc = 0.
      cs_trace-lifnr    = convert_to_string( lw_ekko-lifnr ).
      cs_trace-waers    = convert_to_string( lw_ekko-waers ).
      cs_trace-po_ekorg = convert_to_string( lw_ekko-ekorg ).
      cs_trace-po_ekgrp = convert_to_string( lw_ekko-ekgrp ).
    ENDIF.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCXCL_BMMRMTBM_PRPO_FLEETIO->ENRICH_PR_DATA
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_BANFN                       TYPE        BANFN
* | [--->] IV_BNFPO                       TYPE        BNFPO
* | [<-->] CS_TRACE                       TYPE        TY_PRPO_TRACE
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD enrich_pr_data.

    DATA:
      lw_eban TYPE eban,
      lw_ebkn TYPE ebkn.

    "Leer datos detallados de PR
    SELECT SINGLE *
      FROM eban
      INTO @lw_eban
      WHERE banfn = @iv_banfn
        AND bnfpo = @iv_bnfpo.

    IF sy-subrc = 0.
      cs_trace-pr_werks   = convert_to_string( lw_eban-werks ).
      cs_trace-pr_matnr   = convert_to_string( lw_eban-matnr ).
      cs_trace-pr_txz01   = convert_to_string( lw_eban-txz01 ).
      cs_trace-pr_menge   = convert_to_string( lw_eban-menge ).
      cs_trace-pr_meins   = convert_to_string( lw_eban-meins ).
      cs_trace-pr_matkl   = convert_to_string( lw_eban-matkl ).
      cs_trace-pr_ekgrp   = convert_to_string( lw_eban-ekgrp ).
      cs_trace-pr_ekorg   = convert_to_string( lw_eban-ekorg ).
      cs_trace-pr_preis   = convert_to_string( lw_eban-preis ).
      cs_trace-pr_peinh   = convert_to_string( lw_eban-peinh ).
      cs_trace-pr_waers   = convert_to_string( lw_eban-waers ).
      cs_trace-eban_loekz = convert_to_string( lw_eban-loekz ).
    ENDIF.

    "Leer imputación EBKN
    SELECT SINGLE *
      FROM ebkn
      INTO @lw_ebkn
      WHERE banfn = @iv_banfn
        AND bnfpo = @iv_bnfpo.

    IF sy-subrc = 0.
      cs_trace-ebkn_sakto = convert_to_string( lw_ebkn-sakto ).
      cs_trace-ebkn_kokrs = convert_to_string( lw_ebkn-kokrs ).
    ENDIF.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCXCL_BMMRMTBM_PRPO_FLEETIO->GET_FLEETIO_CORRELATION
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_AUFNR                       TYPE        AUFNR
* | [<-()] RV_FLEETIO_ID                  TYPE        ZPMT_FLT_PRPO-FLEETIO_ID
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD get_fleetio_correlation.

    DATA:
      lw_odatal TYPE zta0108_odatal.

    "Buscar correlación en tabla de log Fleetio (PR-03, PO-03)
    SELECT SINGLE *
      FROM zta0108_odatal
      INTO @lw_odatal
      WHERE workorder = @iv_aufnr
        AND origin_id = @c_origin_fleetio
        AND type IN ('S', 'E').

    IF sy-subrc = 0 AND lw_odatal-external_id IS NOT INITIAL.
      rv_fleetio_id = lw_odatal-external_id.
    ELSE.
      CLEAR rv_fleetio_id.
    ENDIF.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCXCL_BMMRMTBM_PRPO_FLEETIO->GET_NEXT_SEQUENCE
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_FLEETIO_ID                  TYPE        ZPMT_FLT_PRPO-FLEETIO_ID
* | [--->] IV_AUFNR                       TYPE        AUFNR
* | [--->] IV_DOC_TYPE                    TYPE        ZPMT_FLT_PRPO-DOC_TYPE
* | [<-()] RV_LOG_SEQ                     TYPE        ZPMT_FLT_PRPO-LOG_SEQ
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD get_next_sequence.

    DATA:
      lv_max_seq TYPE zpmt_flt_prpo-log_seq.

    "Obtener el secuencial máximo actual
    SELECT MAX( log_seq )
      FROM zpmt_flt_prpo
      INTO @lv_max_seq
      WHERE fleetio_id = @iv_fleetio_id
        AND aufnr      = @iv_aufnr
        AND doc_type   = @iv_doc_type.

    IF sy-subrc = 0 AND lv_max_seq IS NOT INITIAL.
      rv_log_seq = lv_max_seq + 1.
    ELSE.
      rv_log_seq = 1.
    ENDIF.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCXCL_BMMRMTBM_PRPO_FLEETIO->GET_PENDING_RECORDS
* +-------------------------------------------------------------------------------------------------+
* | [<-()] RT_TRACES                      TYPE        TT_PRPO_TRACE
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD get_pending_records.

    DATA:
       li_zpmt TYPE STANDARD TABLE OF zpmt_flt_prpo.

    "Seleccionar registros pendientes de envío
    SELECT *
      FROM zpmt_flt_prpo
      INTO TABLE @li_zpmt
      WHERE status IN ( @c_out_status-pending, @c_out_status-retry ).
*        AND retry_count <= @c_max_retry.

    IF sy-subrc = 0.
      SORT li_zpmt BY fleetio_id aufnr log_seq.
      LOOP AT li_zpmt ASSIGNING FIELD-SYMBOL(<ls_zpmt>).
        APPEND convert_db_to_trace( <ls_zpmt> ) TO rt_traces.
      ENDLOOP.
    ENDIF.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCXCL_BMMRMTBM_PRPO_FLEETIO->GET_TRACES_BY_WO
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_FLEETIO_ID                  TYPE        ZPMT_FLT_PRPO-FLEETIO_ID
* | [--->] IV_AUFNR                       TYPE        AUFNR
* | [<-()] RT_TRACES                      TYPE        TT_PRPO_TRACE
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD get_traces_by_wo.

    DATA:
      li_zpmt TYPE STANDARD TABLE OF zpmt_flt_prpo.

    "Seleccionar todos los registros de la WO
    SELECT *
      FROM zpmt_flt_prpo
      INTO TABLE @li_zpmt
      WHERE fleetio_id = @iv_fleetio_id
        AND aufnr      = @iv_aufnr
      ORDER BY doc_type, log_seq.

    IF sy-subrc = 0.
      LOOP AT li_zpmt ASSIGNING FIELD-SYMBOL(<ls_zpmt>).
        APPEND convert_db_to_trace( <ls_zpmt> ) TO rt_traces.
      ENDLOOP.
    ENDIF.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCXCL_BMMRMTBM_PRPO_FLEETIO->GET_VENDOR_NAME
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_LIFNR                       TYPE        LIFNR
* | [<-()] RV_NAME1                       TYPE        STRING
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD get_vendor_name.

    DATA:
      lw_lfa1 TYPE lfa1.

    "Leer nombre del proveedor
    SELECT SINGLE name1
      FROM lfa1
      INTO @lw_lfa1-name1
      WHERE lifnr = @iv_lifnr.

    IF sy-subrc = 0.
      rv_name1 = convert_to_string( lw_lfa1-name1 ).
    ELSE.
      rv_name1 = ''.
    ENDIF.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCXCL_BMMRMTBM_PRPO_FLEETIO->GET_WO_LOG_DATA
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_AUFNR                       TYPE        AUFNR
* | [<-()] RS_ODATAL                      TYPE        ZTA0108_ODATAL
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD get_wo_log_data.

    "Leer datos del log de Work Order (WO-01)
    SELECT SINGLE *
      FROM zta0108_odatal
      INTO @rs_odatal
      WHERE workorder = @iv_aufnr
        AND origin_id = @c_origin_fleetio.

    "Si no existe, inicializar valores por defecto
    IF sy-subrc <> 0.
      CLEAR rs_odatal.
      rs_odatal-id         = 'WO'.
      rs_odatal-type       = 'S'.
      rs_odatal-workorder  = iv_aufnr.
      rs_odatal-origin_id  = c_origin_fleetio.
      rs_odatal-message    = 'Work Order created successfully'.
    ENDIF.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCXCL_BMMRMTBM_PRPO_FLEETIO->IS_PLANT_ACTIVE
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_WERKS                       TYPE        WERKS_D
* | [<-()] RV_IS_ACTIVE                   TYPE        ABAP_BOOL
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD is_plant_active.

    DATA:
      lv_count TYPE i.

    "Verificar si la planta está activa en configuración (PR-02, ALL-01)
    SELECT COUNT(*)
      FROM zta0117_flt_conf
      INTO @lv_count
      WHERE werks = @iv_werks
        AND active = @abap_true.

    IF lv_count > 0.
      rv_is_active = abap_true.
    ELSE.
      rv_is_active = abap_false.
    ENDIF.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCXCL_BMMRMTBM_PRPO_FLEETIO->REGISTER_PO_CHANGE
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_EBELN                       TYPE        EBELN
* | [--->] IV_EBELP                       TYPE        EBELP
* | [--->] IV_CHANGE_TYPE                 TYPE        CHAR20
* | [<-()] RS_TRACE                       TYPE        TY_PRPO_TRACE
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD register_po_change.

    DATA:
      lw_ekpo TYPE ekpo,
      lw_ekkn TYPE ekkn,
      lw_zpmt TYPE zpmt_flt_prpo.

    DATA:
      lv_aufnr      TYPE aufnr,
      lv_fleetio_id TYPE zpmt_flt_prpo-fleetio_id,
      lv_werks      TYPE werks_d,
      lv_log_seq    TYPE zpmt_flt_prpo-log_seq,
      lv_status     TYPE zpmt_flt_prpo-status,
      lv_code       TYPE zpmt_flt_prpo-code,
      lv_message    TYPE zpmt_flt_prpo-message_text.

    "Validación de parámetros obligatorios
    IF iv_ebeln IS INITIAL OR iv_ebelp IS INITIAL.
      write_application_log(
        iv_msgty = 'E'
        iv_msgv1 = 'Missing parameters: EBELN or EBELP' ).
      RETURN.
    ENDIF.

    "Leer datos de la PO
    SELECT SINGLE *
      FROM ekpo
      INTO @lw_ekpo
      WHERE ebeln = @iv_ebeln
        AND ebelp = @iv_ebelp.

    IF sy-subrc <> 0.
*      write_application_log(
*        iv_msgty = 'E'
*        iv_msgv1 = 'PO not found'
*        iv_msgv2 = iv_ebeln
*        iv_msgv3 = iv_ebelp ).
      RETURN.
    ENDIF.

    lv_werks = lw_ekpo-werks.

    "Validar planta activa
    IF is_plant_active( lv_werks ) = abap_false.
      "Planta no activa, ignorar registro (ALL-01)
      RETURN.
    ENDIF.

    "Leer imputación (EKKN) para obtener AUFNR (PO-02)
    SELECT SINGLE *
      FROM ekkn
      INTO @lw_ekkn
      WHERE ebeln = @iv_ebeln
        AND ebelp = @iv_ebelp.

    IF sy-subrc = 0 AND lw_ekkn-aufnr IS NOT INITIAL.
      lv_aufnr = lw_ekkn-aufnr.
    ELSE.
      "No hay AUFNR, no procesar (PO-02, ALL-01)
      RETURN.
    ENDIF.

    "Obtener correlación Fleetio
    lv_fleetio_id = get_fleetio_correlation( lv_aufnr ).
    IF lv_fleetio_id IS INITIAL.
      "No hay correlación Fleetio, ignorar (ALL-01)
      RETURN.
    ENDIF.

    "Determinar tipo de cambio y status (PO-04, PO-05, PO-06)
    CASE iv_change_type.
      WHEN 'QUANTITY'.
        lv_status  = c_status-po_updated.
        lv_code    = c_code-po_updated.
        lv_message = 'PO item quantity updated in SAP.'.
      WHEN 'DELETED'.
        lv_status  = c_status-deleted.
        lv_code    = c_code-po_updated.
        lv_message = 'PO item deletion flag updated in SAP.'.
      WHEN 'COMPLETED'.
        lv_status  = c_status-completed.
        lv_code    = c_code-po_updated.
        lv_message = 'PO item completely delivered in SAP.'.
      WHEN OTHERS.
        lv_status  = c_status-po_updated.
        lv_code    = c_code-po_updated.
        lv_message = 'PO item updated in SAP.'.
    ENDCASE.

    "Obtener siguiente secuencial
    lv_log_seq = get_next_sequence(
      iv_fleetio_id = lv_fleetio_id
      iv_aufnr      = lv_aufnr
      iv_doc_type   = c_doc_type-po ).

    "Construir registro de trazabilidad
    CLEAR lw_zpmt.
    lw_zpmt-mandt        = sy-mandt.
    lw_zpmt-fleetio_id   = lv_fleetio_id.
    lw_zpmt-aufnr        = lv_aufnr.
    lw_zpmt-doc_type     = c_doc_type-po.
    lw_zpmt-log_seq      = lv_log_seq.
    lw_zpmt-status       = lv_status.
    lw_zpmt-code         = lv_code.
    lw_zpmt-message_text = lv_message.
    lw_zpmt-ebeln        = iv_ebeln.
    lw_zpmt-ebelp        = iv_ebelp.
    lw_zpmt-banfn        = lw_ekpo-banfn.
    lw_zpmt-bnfpo        = lw_ekpo-bnfpo.
*    lw_zpmt-out_status   = c_out_status-pending.
*    lw_zpmt-retry_count  = 0.
    lw_zpmt-changed_on   = sy-datum.
    lw_zpmt-changed_at   = sy-uzeit.
*    lw_zpmt-changed_by   = sy-uname.

    "Convertir a estructura trace (string)
    rs_trace = convert_db_to_trace( lw_zpmt ).

    "Enriquecer con datos actuales de PO
    enrich_po_data(
      EXPORTING
        iv_ebeln = iv_ebeln
        iv_ebelp = iv_ebelp
      CHANGING
        cs_trace = rs_trace ).

    "Convertir trace de vuelta a estructura DB y guardar
    lw_zpmt = convert_trace_to_db( rs_trace ).
    INSERT zpmt_flt_prpo FROM lw_zpmt.

    IF sy-subrc <> 0.
      write_application_log(
        iv_msgty = 'E'
        iv_msgv1 = 'Database error INSERT ZPMT_FLT_PRPO CHANGE' ).
      RETURN.
    ENDIF.

    "Commit work si no está en update task
    IF sy-binpt = space.
      COMMIT WORK AND WAIT.
    ENDIF.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCXCL_BMMRMTBM_PRPO_FLEETIO->REGISTER_PO_CREATION
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_EBELN                       TYPE        EBELN
* | [--->] IV_EBELP                       TYPE        EBELP
* | [--->] IV_BANFN                       TYPE        BANFN(optional)
* | [--->] IV_BNFPO                       TYPE        BNFPO(optional)
* | [<-()] RS_TRACE                       TYPE        TY_PRPO_TRACE
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD register_po_creation.

    DATA:
      lw_ekpo    TYPE ekpo,
      lw_ekko    TYPE ekko,
      lw_ekkn    TYPE ekkn,
      lw_zpmt    TYPE zpmt_flt_prpo,
      lw_zpmt_pr TYPE zpmt_flt_prpo.

    DATA:
      lv_aufnr      TYPE aufnr,
      lv_fleetio_id TYPE zpmt_flt_prpo-fleetio_id,
      lv_werks      TYPE werks_d,
      lv_log_seq    TYPE zpmt_flt_prpo-log_seq,
      lv_banfn      TYPE banfn,
      lv_bnfpo      TYPE bnfpo.

    "Validación de parámetros obligatorios
    IF iv_ebeln IS INITIAL OR iv_ebelp IS INITIAL.
      write_application_log(
        iv_msgty = 'E'
        iv_msgv1 = 'Missing parameters: EBELN or EBELP' ).
      RETURN.
    ENDIF.

    "Leer datos de la PO
    SELECT SINGLE * FROM ekpo
      INTO @lw_ekpo
      WHERE ebeln = @iv_ebeln
        AND ebelp = @iv_ebelp.

    IF sy-subrc <> 0.
*      write_application_log(
*        iv_msgty = 'E'
*        iv_msgv1 = 'PO not found'
*        iv_msgv2 = iv_ebeln
*        iv_msgv3 = iv_ebelp ).
      RETURN.
    ENDIF.

    lv_werks = lw_ekpo-werks.

    "Validar planta activa
    IF is_plant_active( lv_werks ) = abap_false.
      "Planta no activa, ignorar registro (ALL-01)
      RETURN.
    ENDIF.

    "Leer cabecera PO
    SELECT SINGLE *
      FROM ekko
      INTO @lw_ekko
      WHERE ebeln = @iv_ebeln.

    "Leer imputación (EKKN) para obtener AUFNR (PO-02)
    SELECT SINGLE * FROM ekkn
      INTO @lw_ekkn
      WHERE ebeln = @iv_ebeln
        AND ebelp = @iv_ebelp.

    IF sy-subrc = 0 AND lw_ekkn-aufnr IS NOT INITIAL.
      lv_aufnr = lw_ekkn-aufnr.
    ELSE.
      "No hay AUFNR, no procesar (PO-02, ALL-01)
      RETURN.
    ENDIF.

    "Obtener correlación Fleetio
    lv_fleetio_id = get_fleetio_correlation( lv_aufnr ).
    IF lv_fleetio_id IS INITIAL.
      "No hay correlación Fleetio, ignorar (PO-03, ALL-01)
      RETURN.
    ENDIF.

    "Determinar BANFN/BNFPO desde parámetros o desde EKPO (PO-03)
    IF iv_banfn IS NOT INITIAL AND iv_bnfpo IS NOT INITIAL.
      lv_banfn = iv_banfn.
      lv_bnfpo = iv_bnfpo.
    ELSE.
      lv_banfn = lw_ekpo-banfn.
      lv_bnfpo = lw_ekpo-bnfpo.
    ENDIF.

    "Buscar y actualizar registro de PR relacionado si existe
    IF lv_banfn IS NOT INITIAL AND lv_bnfpo IS NOT INITIAL.
      SELECT SINGLE *
        FROM zpmt_flt_prpo
        INTO @lw_zpmt_pr
        WHERE fleetio_id = @lv_fleetio_id
          AND aufnr      = @lv_aufnr
          AND doc_type   = @c_doc_type-pr
          AND banfn      = @lv_banfn
          AND bnfpo      = @lv_bnfpo.

      IF sy-subrc = 0.
        "Actualizar registro de PR con datos de PO
        lw_zpmt_pr-ebeln        = iv_ebeln.
        lw_zpmt_pr-ebelp        = iv_ebelp.
        lw_zpmt_pr-status       = c_status-po_created.
        lw_zpmt_pr-code         = c_code-po_created.
        lw_zpmt_pr-message_text = 'Purchase Order created from PR.'.
*        lw_zpmt_pr-out_status   = co_out_status-pending.
        lw_zpmt_pr-changed_on   = sy-datum.
        lw_zpmt_pr-changed_at   = sy-uzeit.
*        lw_zpmt_pr-changed_by   = sy-uname.

        UPDATE zpmt_flt_prpo FROM lw_zpmt_pr.

        IF sy-subrc <> 0.
          write_application_log(
            iv_msgty = 'E'
            iv_msgv1 = 'Database error UPDATE ZPMT_FLT_PRPO PR' ).
        ENDIF.
      ENDIF.
    ENDIF.

    "Obtener siguiente secuencial para registro PO
    lv_log_seq = get_next_sequence(
      iv_fleetio_id = lv_fleetio_id
      iv_aufnr      = lv_aufnr
      iv_doc_type   = c_doc_type-po ).

    "Construir registro de trazabilidad PO
    CLEAR lw_zpmt.
    lw_zpmt-mandt        = sy-mandt.
    lw_zpmt-fleetio_id   = lv_fleetio_id.
    lw_zpmt-aufnr        = lv_aufnr.
    lw_zpmt-doc_type     = c_doc_type-po.
    lw_zpmt-log_seq      = lv_log_seq.
    lw_zpmt-status       = c_status-po_created.
    lw_zpmt-code         = c_code-po_created.
    lw_zpmt-message_text = 'Purchase Order created from PR.'.
    lw_zpmt-banfn        = lv_banfn.
    lw_zpmt-bnfpo        = lv_bnfpo.
    lw_zpmt-ebeln        = iv_ebeln.
    lw_zpmt-ebelp        = iv_ebelp.
    lw_zpmt-lifnr        = lw_ekko-lifnr.
    lw_zpmt-waers        = lw_ekko-waers.
*    lw_zpmt-out_status   = co_out_status-pending.
*    lw_zpmt-retry_count  = 0.
    lw_zpmt-changed_on   = sy-datum.
    lw_zpmt-changed_at   = sy-uzeit.
*    lw_zpmt-changed_by   = sy-uname.

    "Convertir a estructura trace (string)
    rs_trace = convert_db_to_trace( lw_zpmt ).

    "Enriquecer con datos completos de PO
    enrich_po_data(
      EXPORTING
        iv_ebeln = iv_ebeln
        iv_ebelp = iv_ebelp
      CHANGING
        cs_trace = rs_trace ).

    "Convertir trace de vuelta a estructura DB y guardar
    lw_zpmt = convert_trace_to_db( rs_trace ).
    INSERT zpmt_flt_prpo FROM lw_zpmt.

    IF sy-subrc <> 0.
      write_application_log(
        iv_msgty = 'E'
        iv_msgv1 = 'Database error INSERT ZPMT_FLT_PRPO PO' ).
      RETURN.
    ENDIF.

    "Commit work si no está en update task
    IF sy-binpt = space.
      COMMIT WORK AND WAIT.
    ENDIF.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCXCL_BMMRMTBM_PRPO_FLEETIO->REGISTER_PR_CREATION
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_BANFN                       TYPE        BANFN
* | [--->] IV_BNFPO                       TYPE        BNFPO
* | [--->] IV_AUFNR                       TYPE        AUFNR(optional)
* | [--->] IV_FLEETIO_ID                  TYPE        ZPMT_FLT_PRPO-FLEETIO_ID(optional)
* | [<-()] RS_TRACE                       TYPE        TY_PRPO_TRACE
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD register_pr_creation.

    DATA:
      lw_eban TYPE eban,
      lw_ebkn TYPE ebkn,
      lw_zpmt TYPE zpmt_flt_prpo.

    DATA:
      lv_aufnr      TYPE aufnr,
      lv_fleetio_id TYPE zpmt_flt_prpo-fleetio_id,
      lv_werks      TYPE werks_d,
      lv_log_seq    TYPE zpmt_flt_prpo-log_seq.

    "Validación de parámetros obligatorios
    IF iv_banfn IS INITIAL OR iv_bnfpo IS INITIAL.
      write_application_log(
        iv_msgty = 'E'
        iv_msgv1 = 'Missing parameters: BANFN or BNFPO' ).
      RETURN.
    ENDIF.

    "Leer datos de la PR
    SELECT SINGLE *
      FROM eban
      INTO @lw_eban
      WHERE banfn = @iv_banfn
        AND bnfpo = @iv_bnfpo.

    IF sy-subrc <> 0.
*      write_application_log(
*        iv_msgty = 'E'
*        iv_msgv1 = 'PR not found'
*        iv_msgv2 = iv_banfn
*        iv_msgv3 = iv_bnfpo ).
      RETURN.
    ENDIF.

    lv_werks = lw_eban-werks.

    "Validar planta activa (PR-02)
    IF is_plant_active( lv_werks ) = abap_false.
      "Planta no activa, ignorar registro sin error (ALL-01)
      RETURN.
    ENDIF.

    "Leer imputación (EBKN) para obtener AUFNR (PR-02)
    SELECT SINGLE *
      FROM ebkn
      INTO @lw_ebkn
      WHERE banfn = @iv_banfn
        AND bnfpo = @iv_bnfpo.

    IF sy-subrc = 0 AND lw_ebkn-aufnr IS NOT INITIAL.
      lv_aufnr = lw_ebkn-aufnr.
    ELSEIF iv_aufnr IS NOT INITIAL.
      lv_aufnr = iv_aufnr.
    ELSE.
      "No hay AUFNR, no procesar (PR-02, ALL-01)
      RETURN.
    ENDIF.

    "Obtener correlación Fleetio (PR-03)
    IF iv_fleetio_id IS NOT INITIAL.
      lv_fleetio_id = iv_fleetio_id.
    ELSE.
      lv_fleetio_id = get_fleetio_correlation( lv_aufnr ).
      IF lv_fleetio_id IS INITIAL.
        "No hay correlación Fleetio, ignorar (PR-03, ALL-01)
        RETURN.
      ENDIF.
    ENDIF.

    "Obtener siguiente secuencial
    lv_log_seq = get_next_sequence(
      iv_fleetio_id = lv_fleetio_id
      iv_aufnr      = lv_aufnr
      iv_doc_type   = c_doc_type-pr ).

    "Construir registro de trazabilidad en estructura DB
    CLEAR lw_zpmt.
    lw_zpmt-mandt        = sy-mandt.
    lw_zpmt-fleetio_id   = lv_fleetio_id.
    lw_zpmt-aufnr        = lv_aufnr.
    lw_zpmt-doc_type     = c_doc_type-pr.
    lw_zpmt-log_seq      = lv_log_seq.
    lw_zpmt-status       = c_status-pr_created.
    lw_zpmt-code         = c_code-pr_created.
    lw_zpmt-message_text = 'Purchase Requisition created for SAP Work Order.'.
    lw_zpmt-banfn        = iv_banfn.
    lw_zpmt-bnfpo        = iv_bnfpo.
*    lw_zpmt-out_status   = co_out_status-pending.
*    lw_zpmt-retry_count  = 0.
    lw_zpmt-changed_on   = sy-datum.
    lw_zpmt-changed_at   = sy-uzeit.
*    lw_zpmt-changed_by   = sy-uname.

    "Convertir a estructura trace (string)
    rs_trace = convert_db_to_trace( lw_zpmt ).

    "Enriquecer con datos completos de PR
    enrich_pr_data(
      EXPORTING
        iv_banfn = iv_banfn
        iv_bnfpo = iv_bnfpo
      CHANGING
        cs_trace = rs_trace ).

    "Convertir trace de vuelta a estructura DB y guardar
    lw_zpmt = convert_trace_to_db( rs_trace ).
    INSERT zpmt_flt_prpo FROM lw_zpmt.

    IF sy-subrc <> 0.
      write_application_log(
        iv_msgty = 'E'
        iv_msgv1 = 'Database error INSERT ZPMT_FLT_PRPO PR' ).
      RETURN.
    ENDIF.

    "Commit work si no está en update task
    IF sy-binpt = space.
      COMMIT WORK AND WAIT.
    ENDIF.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCXCL_BMMRMTBM_PRPO_FLEETIO->UPDATE_OUTBOUND_STATUS
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_FLEETIO_ID                  TYPE        ZPMT_FLT_PRPO-FLEETIO_ID
* | [--->] IV_AUFNR                       TYPE        AUFNR
* | [--->] IV_LOG_SEQ                     TYPE        ZPMT_FLT_PRPO-LOG_SEQ
* | [--->] IV_OUT_STATUS                  TYPE        CHAR20
* | [--->] IV_MESSAGE_ID                  TYPE        CHAR3(optional)
* | [--->] IV_ERROR_TEXT                  TYPE        CHAR40(optional)
* | [<-()] RV_SUCCESS                     TYPE        ABAP_BOOL
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD update_outbound_status.

    DATA:
      lw_zpmt TYPE zpmt_flt_prpo.

    "Leer registro actual
    SELECT SINGLE *
      FROM zpmt_flt_prpo
      INTO @lw_zpmt
      WHERE fleetio_id = @iv_fleetio_id
        AND aufnr      = @iv_aufnr
        AND log_seq    = @iv_log_seq.

    IF sy-subrc <> 0.
*      write_application_log(
*        iv_msgty = 'E'
*        iv_msgv1 = 'Record not found'
*        iv_msgv2 = iv_fleetio_id
*        iv_msgv3 = iv_aufnr ).
*      rv_success = abap_false.
      RETURN.
    ENDIF.

    "Actualizar status
*    lw_zpmt-out_status = iv_out_status.
    lw_zpmt-changed_on = sy-datum.
    lw_zpmt-changed_at = sy-uzeit.
*    lw_zpmt-changed_by = sy-uname.

    IF iv_message_id IS NOT INITIAL.
*      ls_zpmt-out_message_id = iv_message_id.
    ENDIF.

    IF iv_error_text IS NOT INITIAL.
*      lw_zpmt-out_error_text = iv_error_text.
    ENDIF.

    "Incrementar contador de reintentos si es error
    IF iv_out_status = c_out_status-error OR
       iv_out_status = c_out_status-retry.
*      lw_zpmt-retry_count = ls_zpmt-retry_count + 1.
    ENDIF.

    "Actualizar en base de datos
    UPDATE zpmt_flt_prpo FROM lw_zpmt.

    IF sy-subrc <> 0.
      write_application_log(
        iv_msgty = 'E'
        iv_msgv1 = 'Database error UPDATE STATUS' ).
      rv_success = abap_false.
      RETURN.
    ENDIF.

    "Commit work si no está en update task
    IF sy-binpt = space.
      COMMIT WORK AND WAIT.
    ENDIF.

    rv_success = abap_true.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Private Method ZCXCL_BMMRMTBM_PRPO_FLEETIO->WRITE_APPLICATION_LOG
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_MSGTY                       TYPE        SY-MSGTY (default ='E')
* | [--->] IV_MSGNO                       TYPE        SY-MSGNO (default ='001')
* | [--->] IV_MSGV1                       TYPE        SY-MSGV1(optional)
* | [--->] IV_MSGV2                       TYPE        SY-MSGV2(optional)
* | [--->] IV_MSGV3                       TYPE        SY-MSGV3(optional)
* | [--->] IV_MSGV4                       TYPE        SY-MSGV4(optional)
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD write_application_log.

    "Método auxiliar para escribir en log de aplicación
    "Puede implementarse usando BAL (Application Log) o simplemente
    "escribir a una tabla de log personalizada

*    DATA: ls_log TYPE zpmt_flt_log. "Tabla de log si existe
*
*    "Opción 1: Escribir mensaje a spool/log estándar
*    MESSAGE ID 'ZPMM_FLEETIO' TYPE iv_msgty NUMBER iv_msgno
*      WITH iv_msgv1 iv_msgv2 iv_msgv3 iv_msgv4.

    "Opción 2: Escribir a tabla de log personalizada (si existe)
    "ls_log-msgty = iv_msgty.
    "ls_log-msgno = iv_msgno.
    "ls_log-msgv1 = iv_msgv1.
    "ls_log-msgv2 = iv_msgv2.
    "ls_log-msgv3 = iv_msgv3.
    "ls_log-msgv4 = iv_msgv4.
    "ls_log-timestamp = sy-datum && sy-uzeit.
    "ls_log-user = sy-uname.
    "INSERT zpmt_flt_log FROM ls_log.

  ENDMETHOD.
ENDCLASS.