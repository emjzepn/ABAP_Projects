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
*& DECLARACIONES GLOBALES
*&---------------------------------------------------------------------*
TABLES: mkpf, mseg.

*&---------------------------------------------------------------------*
*& Datos globales
*&---------------------------------------------------------------------*

TYPES: BEGIN OF ty_log_data,
         mandt            TYPE mandt,
         log_number       TYPE zta0117_flt_invl-log_number,
         object_key       TYPE zta0117_flt_invl-object_key,
         mblnr            TYPE zta0117_flt_invl-mblnr,
         mjahr            TYPE zta0117_flt_invl-mjahr,
         zeile            TYPE zta0117_flt_invl-zeile,
         aufnr            TYPE zta0117_flt_invl-aufnr,
         werks            TYPE zta0117_flt_invl-werks,
         lgort            TYPE zta0117_flt_invl-lgort,
         matnr            TYPE zta0117_flt_invl-matnr,
         bwart            TYPE zta0117_flt_invl-bwart,
         menge            TYPE zta0117_flt_invl-menge,
         erfmg            TYPE zta0117_flt_invl-erfmg,
         meins            TYPE zta0117_flt_invl-meins,
         erfme            TYPE zta0117_flt_invl-erfme,
         shkzg            TYPE zta0117_flt_invl-shkzg,
         rsnum            TYPE zta0117_flt_invl-rsnum,
         rspos            TYPE zta0117_flt_invl-rspos,
         kzear            TYPE zta0117_flt_invl-kzear,
         sgtxt            TYPE zta0117_flt_invl-sgtxt,
         equnr            TYPE zta0117_flt_invl-equnr,
         belnr            TYPE zta0117_flt_invl-belnr,
         buzei            TYPE zta0117_flt_invl-buzei,
         ebeln            TYPE zta0117_flt_invl-ebeln,
         ebelp            TYPE zta0117_flt_invl-ebelp,
         smbln            TYPE zta0117_flt_invl-smbln,
         smblp            TYPE zta0117_flt_invl-smblp,
         quantity         TYPE zta0117_flt_invl-quantity,
         inventory_action TYPE zta0117_flt_invl-inventory_action,
         signed_quantity  TYPE zta0117_flt_invl-signed_quantity,
         uom_published    TYPE zta0117_flt_invl-uom_published,
         entry_date       TYPE zta0117_flt_invl-entry_date,
         entry_time       TYPE zta0117_flt_invl-entry_time,
         posted_by        TYPE zta0117_flt_invl-posted_by,
         send_date        TYPE zta0117_flt_invl-send_date,
         send_time        TYPE zta0117_flt_invl-send_time,
         sent_by          TYPE zta0117_flt_invl-sent_by,
         reprocess_flag   TYPE zta0117_flt_invl-reprocess_flag,
         reprocess_date   TYPE zta0117_flt_invl-reprocess_date,
         reprocess_time   TYPE zta0117_flt_invl-reprocess_time,
         reprocess_by     TYPE zta0117_flt_invl-reprocess_by,
         status           TYPE zta0117_flt_invl-status,
         response_msg     TYPE zta0117_flt_invl-response_msg,
         error_text       TYPE zta0117_flt_invl-error_text,
         traffic_light    TYPE c LENGTH 1,
       END OF ty_log_data.

DATA:
  wa_log_data TYPE ty_log_data.

DATA:
  it_log_data TYPE STANDARD TABLE OF ty_log_data.

CLASS cl_alv_controller DEFINITION DEFERRED.

DATA: o_controller TYPE REF TO cl_alv_controller.

*&---------------------------------------------------------------------*
*& PANTALLA DE SELECCIÓN
*&---------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b01 WITH FRAME TITLE text-001.
SELECT-OPTIONS: s_werks FOR mseg-werks OBLIGATORY,  "Centro
                s_mblnr FOR mkpf-mblnr,             "Documento material
                s_budat FOR mkpf-budat.             "Fecha contabilización
SELECTION-SCREEN END OF BLOCK b01.