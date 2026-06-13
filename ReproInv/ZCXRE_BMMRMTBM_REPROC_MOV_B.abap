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
*& Definición de la clase lcl_alv_controller
*&---------------------------------------------------------------------*
CLASS cl_alv_controller DEFINITION FINAL.
  PUBLIC SECTION.

    "--- Atributos ---
    DATA: mo_container TYPE REF TO cl_gui_custom_container,
          mo_alv_grid  TYPE REF TO cl_gui_alv_grid,
          mt_fieldcat  TYPE lvc_t_fcat,
          ms_layout    TYPE lvc_s_layo,
          ms_variant   TYPE disvariant.

    "--- Métodos de operación ---
    METHODS: get_inventory_log,
      initialize_alv,
      reprocess_movements.

    "--- Eventos del ALV ---
    METHODS: handle_toolbar
                  FOR EVENT toolbar OF cl_gui_alv_grid
      IMPORTING e_object e_interactive,
      handle_user_command
                    FOR EVENT user_command OF cl_gui_alv_grid
        IMPORTING e_ucomm.

  PRIVATE SECTION.
    METHODS: build_fieldcat.

ENDCLASS.

*&---------------------------------------------------------------------*
*& Implementación de la clase lcl_alv_controller
*&---------------------------------------------------------------------*
CLASS cl_alv_controller IMPLEMENTATION.

  METHOD get_inventory_log.

    "Leer documentos desde tabla de log
    SELECT *
      FROM zta0117_flt_invl
      INTO CORRESPONDING FIELDS OF TABLE it_log_data
      WHERE werks IN s_werks
        AND mblnr IN s_mblnr
        AND send_date IN s_budat
        AND status = 'ERROR'.
    IF sy-subrc = 0.
      SORT it_log_data BY log_number.

      "Asignar semáforo según status
      LOOP AT it_log_data INTO wa_log_data.
        IF wa_log_data-status = 'ERROR'.
          wa_log_data-traffic_light = '1'.  "Rojo
        ELSE.
          wa_log_data-traffic_light = '3'.  "Verde
        ENDIF.
        MODIFY it_log_data FROM wa_log_data.
      ENDLOOP.
    ENDIF.

  ENDMETHOD.

  METHOD initialize_alv.

    IF mo_alv_grid IS INITIAL.

      CREATE OBJECT mo_container
        EXPORTING
          container_name = 'CC_ALV'.

      CREATE OBJECT mo_alv_grid
        EXPORTING
          i_parent = mo_container.

      "Configurar field catalog
      me->build_fieldcat( ).

      "Configurar layout
      ms_layout-zebra      = abap_true.
      ms_layout-sel_mode   = 'A'.  "Selección múltiple con checkbox
      ms_layout-cwidth_opt = abap_true.
      ms_layout-excp_fname = 'TRAFFIC_LIGHT'.  "Campo de semáforo

      "Variante de display
      ms_variant-report = sy-repid.

      "Registrar eventos
      SET HANDLER me->handle_toolbar     FOR mo_alv_grid.
      SET HANDLER me->handle_user_command FOR mo_alv_grid.

      "Mostrar ALV
      mo_alv_grid->set_table_for_first_display(
        EXPORTING
          is_layout       = ms_layout
          i_save          = 'A'
          is_variant      = ms_variant
        CHANGING
          it_outtab       = it_log_data
          it_fieldcatalog = mt_fieldcat ).

    ELSE.
      mo_alv_grid->refresh_table_display( ).
    ENDIF.

  ENDMETHOD.

  METHOD build_fieldcat.

    DATA: ls_fcat TYPE lvc_s_fcat.

    CALL FUNCTION 'LVC_FIELDCATALOG_MERGE'
      EXPORTING
        i_structure_name = 'ZTA0117_FLT_INVL'
      CHANGING
        ct_fieldcat      = mt_fieldcat
      EXCEPTIONS
        OTHERS           = 1.

    "Eliminar campo STRING no soportado en estructura local
    DELETE mt_fieldcat WHERE fieldname = 'PAYLOAD_JSON'.

    "Insertar columna de semáforo como primera columna
    CLEAR ls_fcat.
    ls_fcat-fieldname = 'TRAFFIC_LIGHT'.
    ls_fcat-coltext   = 'Status'.
    ls_fcat-col_pos   = 0.
    ls_fcat-outputlen = 3.
    ls_fcat-just      = 'C'.
    INSERT ls_fcat INTO mt_fieldcat INDEX 1.

    "Ajustar columnas relevantes
    LOOP AT mt_fieldcat INTO ls_fcat.
      CASE ls_fcat-fieldname.
        WHEN 'LOG_NUMBER'.
          ls_fcat-coltext = 'Log No.'.
        WHEN 'STATUS'.
          ls_fcat-coltext = 'Estado'.
          ls_fcat-emphasize = 'C610'.
        WHEN 'ERROR_TEXT'.
          ls_fcat-coltext = 'Mensaje Error'.
          ls_fcat-outputlen = 40.
        WHEN 'MBLNR'.
          ls_fcat-coltext = 'Doc. Material'.
        WHEN 'WERKS'.
          ls_fcat-coltext = 'Centro'.
      ENDCASE.
      MODIFY mt_fieldcat FROM ls_fcat.
    ENDLOOP.

  ENDMETHOD.

  METHOD reprocess_movements.

    DATA:
      lw_mkpf TYPE mkpf,
      lw_mseg TYPE mseg,
      lw_row  TYPE lvc_s_row.

    DATA:
      li_rows TYPE lvc_t_row.

    DATA:
      lv_json      TYPE string,
      lv_success   TYPE abap_bool,
      lv_response  TYPE string,
      lv_count_ok  TYPE i,
      lv_count_err TYPE i.

    DATA:
      lo_badi_impl TYPE REF TO zcxcl_bmmrmtbm_mb_doc_fleetio.

    "Obtener registros seleccionados del ALV
    mo_alv_grid->get_selected_rows( IMPORTING et_index_rows = li_rows ).

    IF li_rows IS INITIAL.
      MESSAGE s908(fb) WITH 'Seleccione al menos un registro'.
      RETURN.
    ENDIF.

    CREATE OBJECT lo_badi_impl.

    lo_badi_impl->load_configuration( ).

    LOOP AT li_rows INTO lw_row.
      READ TABLE it_log_data INTO wa_log_data INDEX lw_row-index.
      CHECK sy-subrc = 0.

      "Header: Material Document
      SELECT SINGLE *
        FROM mkpf
        INTO lw_mkpf
        WHERE mblnr = wa_log_data-mblnr
          AND mjahr = wa_log_data-mjahr.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      "Document Segment: Material
      SELECT SINGLE *
        FROM mseg
        INTO lw_mseg
        WHERE mblnr = wa_log_data-mblnr
          AND mjahr = wa_log_data-mjahr
          AND zeile = wa_log_data-zeile.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      "Validar documento
      DATA(lv_valid) = lo_badi_impl->validate_document(
        iw_mkpf = lw_mkpf
        iw_mseg = lw_mseg ).

      IF lv_valid = abap_true.

        "Reconstruir JSON
        lv_json = lo_badi_impl->build_json_payload(
          iw_mkpf = lw_mkpf
          iw_mseg = lw_mseg ).

        "Reenviar a Fleetio
        lo_badi_impl->send_to_fleetio(
          EXPORTING
            iv_json     = lv_json
          IMPORTING
            ev_success  = lv_success
            ev_response = lv_response ).

        "Actualizar log
        IF lv_success = abap_true.
          UPDATE zta0117_flt_invl
            SET status = 'SENT'
                reprocess_flag = 'X'
                reprocess_date = sy-datum
                reprocess_time = sy-uzeit
                reprocess_by = sy-uname
                send_date = sy-datum
                send_time = sy-uzeit
                response_msg = lv_response
                error_text = ''
            WHERE log_number = wa_log_data-log_number.

          "Actualizar tabla interna para refrescar ALV
          wa_log_data-status         = 'SENT'.
          wa_log_data-reprocess_flag = 'X'.
          wa_log_data-reprocess_date = sy-datum.
          wa_log_data-reprocess_time = sy-uzeit.
          wa_log_data-reprocess_by   = sy-uname.
          wa_log_data-error_text     = ''.
          MODIFY it_log_data FROM wa_log_data INDEX lw_row-index.

          lv_count_ok = lv_count_ok + 1.
        ELSE.
          UPDATE zta0117_flt_invl
            SET reprocess_flag = 'X'
                reprocess_date = sy-datum
                reprocess_time = sy-uzeit
                reprocess_by = sy-uname
                error_text = lv_response
            WHERE log_number = wa_log_data-log_number.

          "Actualizar tabla interna para refrescar ALV
          wa_log_data-reprocess_flag = 'X'.
          wa_log_data-reprocess_date = sy-datum.
          wa_log_data-reprocess_time = sy-uzeit.
          wa_log_data-reprocess_by   = sy-uname.
          MODIFY it_log_data FROM wa_log_data INDEX lw_row-index.

          lv_count_err = lv_count_err + 1.
        ENDIF.

        COMMIT WORK.

      ENDIF.

    ENDLOOP.

    "Mostrar mensaje resumen
    MESSAGE s911(fb) WITH lv_count_ok lv_count_err.

    "Refrescar ALV para mostrar status actualizado
    mo_alv_grid->refresh_table_display( ).

  ENDMETHOD.

  METHOD handle_toolbar.

    DATA: lw_button TYPE stb_button.

    lw_button-function  = 'REPROC'.
    lw_button-icon      = icon_execute_object.
    lw_button-quickinfo = 'Reprocesar seleccionados'.
    lw_button-text      = 'Reprocesar'.
    lw_button-butn_type = 0.
    APPEND lw_button TO e_object->mt_toolbar.

  ENDMETHOD.

  METHOD handle_user_command.

    CASE e_ucomm.
      WHEN 'REPROC'.
        me->reprocess_movements( ).
    ENDCASE.

  ENDMETHOD.

ENDCLASS.