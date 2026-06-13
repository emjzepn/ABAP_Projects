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
*-------------------------------------------------------------------------------*
* CLASE PRINCIPAL PARA PROCESO DE ACTUALIZACIÓN DE MATERIAL                     *
*-------------------------------------------------------------------------------*
CLASS cl_act_mrp DEFINITION FINAL.

  PUBLIC SECTION.

    METHODS:
      constructor,

      read_file
        EXPORTING
          et_excel TYPE tt_excel,

      process_data
        EXPORTING
          et_updated_mrp TYPE tt_updated_mrp
        CHANGING
          it_datos       TYPE tt_excel,

      check_authority
        IMPORTING
          iv_werks   TYPE werks_d
        EXPORTING
          ev_valid   TYPE abap_bool
          ev_message TYPE string,

      update_material
        IMPORTING
          iw_dato    TYPE ty_excel
        EXPORTING
          ev_success TYPE abap_bool
          ev_message TYPE string.

  PRIVATE SECTION.

    METHODS:

      check_obligatory_fields
        IMPORTING
          iw_dato    TYPE ty_excel
        EXPORTING
          ev_valid   TYPE abap_bool
          ev_message TYPE string,

      fixed_fields
        CHANGING
          iw_dato        TYPE ty_excel
          iw_updated_mrp TYPE ty_updated_mrp,

      rule_nd
        CHANGING
          iw_dato        TYPE ty_excel
          iw_updated_mrp TYPE ty_updated_mrp,

      validate_file_structure
        IMPORTING
          iv_header  TYPE string
        EXPORTING
          ev_valid   TYPE abap_bool
          ev_message TYPE string.

ENDCLASS.

*-------------------------------------------------------------------------------*
* IMPLEMENTACIÓN DE LA CLASE PRINCIPAL                                         *
*-------------------------------------------------------------------------------*
CLASS cl_act_mrp IMPLEMENTATION.

  METHOD constructor ##NEEDED.
    " Inicialización de variables de la clase
  ENDMETHOD.

  METHOD read_file.
    "----------------------------------------------------------------------
    " Lee archivo Excel y convierte a tabla interna
    "----------------------------------------------------------------------

    DATA:
      lw_datos TYPE ty_datos,
      lw_excel TYPE ty_excel.

    DATA:
      li_raw_data TYPE STANDARD TABLE OF string.

    DATA:
      lv_filename TYPE string,
      lv_line     TYPE string.

    CLEAR et_excel.

    lv_filename = p_file.

    "Leer archivo
    TRY.
        cl_gui_frontend_services=>gui_upload(
          EXPORTING
            filename                = lv_filename
            filetype                = 'ASC'
            has_field_separator     = abap_true
            dat_mode                = space
          CHANGING
            data_tab                = li_raw_data
          EXCEPTIONS
            file_open_error         = 1
            file_read_error         = 2
            no_batch                = 3
            gui_refuse_filetransfer = 4
            invalid_type            = 5
            no_authority            = 6
            unknown_error           = 7
            bad_data_format         = 8
            header_not_allowed      = 9
            separator_not_allowed   = 10
            header_too_long         = 11
            unknown_dp_error        = 12
            access_denied           = 13
            dp_out_of_memory        = 14
            disk_full               = 15
            dp_timeout              = 16
            not_supported_by_gui    = 17
            error_no_gui            = 18
            OTHERS                  = 19
        ).
        IF sy-subrc <> 0.
          MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
                WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
        ENDIF.

      CATCH cx_root INTO DATA(lo_error) ##CATCH_ALL.
        MESSAGE lo_error->get_text( ) TYPE 'E'.

    ENDTRY.

    " ── Validar estructura del archivo ──
    READ TABLE li_raw_data INTO DATA(lv_header) INDEX 1.
    IF sy-subrc = 0.
      validate_file_structure(
        EXPORTING
          iv_header  = lv_header
        IMPORTING
          ev_valid   = DATA(lv_struct_valid)
          ev_message = DATA(lv_struct_msg) ).

      IF lv_struct_valid = abap_false.
        MESSAGE lv_struct_msg TYPE 'E'.
        RETURN.
      ENDIF.
    ELSE.
      MESSAGE 'El archivo está vacío o no contiene cabecera.' TYPE 'E'.
      RETURN.
    ENDIF.

    TRY.
        "Parsear datos (ignorar cabecera)
        LOOP AT li_raw_data INTO lv_line FROM 2.

          "Dividir línea por tabulador
          SPLIT lv_line AT c_sep_tab INTO
                lw_datos-matnr
                lw_datos-werks
                lw_datos-dismm
                lw_datos-minbe
                lw_datos-disls
                lw_datos-bstmi
                lw_datos-bstma
                lw_datos-mabst
                lw_datos-bstrf
                lw_datos-sobsl
                lw_datos-plifz
                lw_datos-webaz
                lw_datos-fhori
                lw_datos-eisbe
                lw_datos-eislo
                lw_datos-prmod
                lw_datos-vrbmt
                lw_datos-vrbwk
                lw_datos-peran
                lw_datos-anzpr
                lw_datos-perio
                lw_datos-maabc
                lw_datos-maxlz.

          MOVE-CORRESPONDING lw_datos TO lw_excel.

          "Convertir número de material con ceros a la izquierda
          lw_excel-matnr = |{ lw_excel-matnr ALPHA = IN }|.

          APPEND lw_excel TO et_excel.
          CLEAR: lw_datos, lw_excel.
        ENDLOOP.

        "Ordena la tabla con el contenido del archivo
        SORT et_excel BY matnr werks.

        "Validar que los datos del archivo no tenga registros duplicados.
        "Archivo con combinaciones de material y centro repetidas
        "Se deben de indicar aquellos registros que esten duplicados y no procesarlos
        LOOP AT et_excel ASSIGNING FIELD-SYMBOL(<lfs_excel_1>).
          DATA(lv_tabix) = sy-tabix.
          READ TABLE et_excel ASSIGNING FIELD-SYMBOL(<lfs_excel_2>) INDEX lv_tabix + 1.
          IF sy-subrc = 0.
            IF <lfs_excel_1>-matnr = <lfs_excel_2>-matnr AND
               <lfs_excel_1>-werks = <lfs_excel_2>-werks.
              <lfs_excel_1>-status = <lfs_excel_2>-status = 'ERROR'.
              <lfs_excel_1>-icon   = <lfs_excel_2>-icon = icon_led_red.
              <lfs_excel_1>-comments = <lfs_excel_2>-comments = 'Registro duplicado'.
            ENDIF.
          ENDIF.
        ENDLOOP.

      CATCH cx_root INTO DATA(lo_conv) ##CATCH_ALL.
        MESSAGE lo_conv->get_text( ) TYPE 'E'.  " o guarda el texto

    ENDTRY.

  ENDMETHOD.

  METHOD process_data.
    "----------------------------------------------------------------------
    " Procesa cada registro del archivo
    "----------------------------------------------------------------------

    DATA:
      lw_updated_mrp TYPE ty_updated_mrp.

    DATA:
      lv_total     TYPE i,
      lv_procesado TYPE i,
      lv_success   TYPE abap_bool,
      lv_message   TYPE string.

    FIELD-SYMBOLS:
      <lfs_result> TYPE ty_updated_mrp.

*  Macro: asignación segura de campo numérico con soporte "&"
*  Si "&" → limpia destino. Si no → asigna normalmente.
    DEFINE map_num_safe.
      IF &1 = c_caracter_borrado.
        CLEAR &2.
      ELSE.
        IF &1 IS NOT INITIAL.
           &2 = &1.
        ENDIF.
      ENDIF.
    END-OF-DEFINITION.

    CLEAR et_updated_mrp.

    lv_total = lines( it_datos ).

    IF it_datos[] IS NOT INITIAL.
      "Obtiene materiales existentes
      SELECT marc~matnr, marc~werks, mara~pstat
        FROM marc INNER JOIN mara
            ON marc~matnr = mara~matnr
        INTO TABLE @DATA(li_materiales)
        FOR ALL ENTRIES IN @it_datos
        WHERE marc~matnr = @it_datos-matnr.
      IF sy-subrc = 0.
        SORT li_materiales BY matnr werks.
      ENDIF.

      "Procesar registros
      LOOP AT it_datos ASSIGNING FIELD-SYMBOL(<lfs_datos>).

        TRY.
            lv_procesado = sy-tabix.

            "Inicializar registro de resultado e insertar en tabla de salida
            CLEAR lw_updated_mrp.

            "Campos fijos
            fixed_fields(
              CHANGING
                iw_dato        = <lfs_datos>
                iw_updated_mrp = lw_updated_mrp
            ).

            "--- Campos numéricos con soporte "&" ---
            map_num_safe <lfs_datos>-matnr    lw_updated_mrp-matnr.
            map_num_safe <lfs_datos>-werks    lw_updated_mrp-werks.
            map_num_safe <lfs_datos>-dismm    lw_updated_mrp-dismm.
            map_num_safe <lfs_datos>-disls    lw_updated_mrp-disls.
            map_num_safe <lfs_datos>-minbe    lw_updated_mrp-minbe.
            map_num_safe <lfs_datos>-bstmi    lw_updated_mrp-bstmi.
            map_num_safe <lfs_datos>-bstma    lw_updated_mrp-bstma.
            map_num_safe <lfs_datos>-mabst    lw_updated_mrp-mabst.
            map_num_safe <lfs_datos>-bstrf    lw_updated_mrp-bstrf.
            map_num_safe <lfs_datos>-sobsl    lw_updated_mrp-sobsl.
            map_num_safe <lfs_datos>-plifz    lw_updated_mrp-plifz.
            map_num_safe <lfs_datos>-webaz    lw_updated_mrp-webaz.
            map_num_safe <lfs_datos>-fhori    lw_updated_mrp-fhori.
            map_num_safe <lfs_datos>-eisbe    lw_updated_mrp-eisbe.
            map_num_safe <lfs_datos>-eislo    lw_updated_mrp-eislo.
            map_num_safe <lfs_datos>-prmod    lw_updated_mrp-prmod.
            map_num_safe <lfs_datos>-vrbmt    lw_updated_mrp-vrbmt.
            map_num_safe <lfs_datos>-vrbwk    lw_updated_mrp-vrbwk.
            map_num_safe <lfs_datos>-peran    lw_updated_mrp-peran.
            map_num_safe <lfs_datos>-anzpr    lw_updated_mrp-anzpr.
            map_num_safe <lfs_datos>-perio    lw_updated_mrp-perio.
            map_num_safe <lfs_datos>-maabc    lw_updated_mrp-maabc.
            map_num_safe <lfs_datos>-maxlz    lw_updated_mrp-maxlz.
            map_num_safe <lfs_datos>-status   lw_updated_mrp-status.
            map_num_safe <lfs_datos>-icon     lw_updated_mrp-icon.
            map_num_safe <lfs_datos>-comments lw_updated_mrp-comments.

            "Valida regla ND
            rule_nd(
              CHANGING
                iw_dato        = <lfs_datos>
                iw_updated_mrp = lw_updated_mrp ).

            APPEND lw_updated_mrp TO et_updated_mrp ASSIGNING <lfs_result>.

            IF <lfs_datos>-status = 'ERROR'.
              CONTINUE.
            ENDIF.

            "Mostrar progreso
            cl_progress_indicator=>progress_indicate(
              EXPORTING
                i_text               = |{ TEXT-006 } { lv_procesado } { TEXT-007 } { lv_total }|
                i_processed          = lv_procesado
                i_total              = lv_total
                i_output_immediately = abap_true ).

            "Validar que el material exista
            READ TABLE li_materiales INTO DATA(lw_materiales)
                                     WITH KEY matnr = <lfs_datos>-matnr
                                     BINARY SEARCH.
            IF sy-subrc <> 0.
              <lfs_result>-status   = 'ERROR'.
              <lfs_result>-icon     = icon_led_red.
              <lfs_result>-comments = |{ TEXT-013 } { <lfs_datos>-matnr } { TEXT-014 }|.
              CONTINUE.
            ENDIF.

            "Validar que el material exista en el centro
            READ TABLE li_materiales INTO lw_materiales
                                     WITH KEY matnr = <lfs_datos>-matnr
                                              werks = <lfs_datos>-werks
                                     BINARY SEARCH.
            IF sy-subrc <> 0.
              <lfs_result>-status   = 'ERROR'.
              <lfs_result>-icon     = icon_led_red.
              <lfs_result>-comments = |{ TEXT-013 } { <lfs_datos>-matnr } { TEXT-015 } { <lfs_datos>-werks }|.
              CONTINUE.
            ENDIF.

            <lfs_datos>-pstat = lw_materiales-pstat.

            IF <lfs_datos>-pstat NS 'D'.
              <lfs_result>-status   = 'ERROR'.
              <lfs_result>-icon     = icon_led_red.
              <lfs_result>-comments = |{ TEXT-016 }|.
              CONTINUE.
            ENDIF.

            IF <lfs_datos>-pstat NS 'P'.
              <lfs_result>-status   = 'ERROR'.
              <lfs_result>-icon     = icon_led_red.
              <lfs_result>-comments = |{ TEXT-017 }|.
              CONTINUE.
            ENDIF.

            "Verificar autorización por centro
            check_authority( EXPORTING
                               iv_werks = <lfs_datos>-werks
                             IMPORTING
                               ev_valid = lv_success
                               ev_message = lv_message ).
            IF lv_success = abap_false.
              <lfs_result>-status   = 'ERROR'.
              <lfs_result>-icon     = icon_led_red.
              <lfs_result>-comments = lv_message.
              CONTINUE.
            ENDIF.

            "Validar campos obligatorios
            check_obligatory_fields(
              EXPORTING
                iw_dato    = <lfs_datos>
              IMPORTING
                ev_valid   = lv_success
                ev_message = lv_message ).

            IF lv_success = abap_false.
              <lfs_result>-status   = 'ERROR'.
              <lfs_result>-icon     = icon_led_red.
              <lfs_result>-comments = lv_message.
              CONTINUE.
            ENDIF.

            "Actualizar material mediante BAPI
            update_material(
              EXPORTING
                iw_dato    = <lfs_datos>
              IMPORTING
                ev_success = lv_success
                ev_message = lv_message ).

            IF lv_success = abap_true.
              <lfs_result>-status   = 'EXITOSO'.
              <lfs_result>-icon     = icon_led_green.
              <lfs_result>-comments = TEXT-008. "Material actualizado correctamente
            ELSE.
              <lfs_result>-status   = 'ERROR'.
              <lfs_result>-icon     = icon_led_red.
              <lfs_result>-comments = lv_message.
            ENDIF.

          CATCH cx_root INTO DATA(lo_root) ##CATCH_ALL.
            MESSAGE lo_root->get_text( ) TYPE 'E'.
        ENDTRY.

      ENDLOOP.

    ENDIF.

  ENDMETHOD.

  METHOD check_authority.
    "----------------------------------------------------------------------
    " Revisa autorización
    "----------------------------------------------------------------------

    DATA:
      lv_werks TYPE werks_d.

    CLEAR ev_message.

    ev_valid = abap_true.
    lv_werks = iv_werks.

    "Autorización para modificar materiales por centro
    AUTHORITY-CHECK OBJECT 'M_MATE_WRK'
      ID 'WERKS' FIELD lv_werks
      ID 'ACTVT' FIELD '02'.  "Modificar
    IF sy-subrc <> 0.
      ev_valid = abap_false.
      ev_message = |{ TEXT-009 } { lv_werks }|.
    ENDIF.

    "Autorización para status de actualización
    AUTHORITY-CHECK OBJECT 'M_MATE_STA'
             ID 'ACTVT' FIELD '02'
             ID 'STATM' FIELD 'D'. "Planificación de necesidades
    IF sy-subrc <> 0.
      ev_valid = abap_false.
      ev_message = |{ TEXT-010 } { iv_werks }|.
    ENDIF.

    "Autorización para status de actualización
    AUTHORITY-CHECK OBJECT 'M_MATE_STA'
             ID 'ACTVT' FIELD '02'
             ID 'STATM' FIELD 'P'.  "Pronóstico
    IF sy-subrc <> 0.
      ev_valid = abap_false.
      ev_message = |{ TEXT-011 } { iv_werks }|.
    ENDIF.

  ENDMETHOD.

  METHOD update_material.
*    "----------------------------------------------------------------------
*    " Actualiza material mediante BAPI_MATERIAL_SAVEDATA
*    "----------------------------------------------------------------------

    DATA:
      lw_headdata            TYPE bapimathead,
      lw_plantdata           TYPE bapi_marc,
      lw_plantdatax          TYPE bapi_marcx,
      lw_forecastparameters  TYPE bapi_mpop,
      lw_forecastparametersx TYPE bapi_mpopx,
      lw_returnmessages      TYPE bapiret2,
      lw_extensionin         TYPE bapiparex,
      lw_extensioninx        TYPE bapiparexx.

    DATA:
      li_returnmessages TYPE STANDARD TABLE OF bapiret2,
      li_extensionin    TYPE STANDARD TABLE OF  bapiparex,
      li_extensioninx   TYPE STANDARD TABLE OF  bapiparexx.

    DATA:
      lv_str   TYPE string,
      lv_vrbdt TYPE vrbdt.

*   Macro para mapeo de campos con soporte de "&"
*   Campo alfanumérico: si "&" → limpiar + marcar. Si lleno → asignar + marcar. Si vacío → ignorar.
    DEFINE map_field_char.
      IF &1 = c_caracter_borrado.
        CLEAR &2. &3 = c_x.
      ELSEIF &1 IS NOT INITIAL.
        &2 = &1. &3 = c_x.
      ENDIF.
    END-OF-DEFINITION.
*   Campo numérico: mismo patrón
    DEFINE map_field_num.
      lv_str = &1.
      IF lv_str = c_caracter_borrado.
        CLEAR &2.
        &3 = c_x.
      ELSEIF lv_str IS NOT INITIAL.
        TRY.
           &2 = &1.
           &3 = c_x.
          CATCH cx_root ##CATCH_ALL.
            ev_message = |{ TEXT-012 } { &4 }: { &1 }|.
            ev_success = abap_false. RETURN.
        ENDTRY.
      ENDIF.
    END-OF-DEFINITION.

    CLEAR: ev_success, ev_message.

    "--- HEADDATA ---
    lw_headdata-material      = iw_dato-matnr.
    lw_headdata-mrp_view      = c_x.
    lw_headdata-forecast_view = c_x.

    "--- PLANTDATA / PLANTDATAX ---
    lw_plantdata-plant  = iw_dato-werks.
    lw_plantdatax-plant = iw_dato-werks.

    "Campos que NO admiten "&" (solo asignar si llenos)
    IF iw_dato-dismm IS NOT INITIAL.
      lw_plantdata-mrp_type = iw_dato-dismm.
      lw_plantdatax-mrp_type = c_x.
    ENDIF.

    "Valores fijos
    lw_plantdata-proc_type  = iw_dato-beskz. lw_plantdatax-proc_type  = c_x.
    lw_plantdata-mrp_ctrler = iw_dato-dispo. lw_plantdatax-mrp_ctrler = c_x.
    lw_plantdata-sloc_exprc = iw_dato-lgfsb. lw_plantdatax-sloc_exprc = c_x.
    lw_plantdata-period_ind = iw_dato-perkz. lw_plantdatax-period_ind = c_x.

    "Campos alfanuméricos con soporte "&"
    map_field_char iw_dato-maabc   lw_plantdata-abc_id       lw_plantdatax-abc_id.
    map_field_char iw_dato-disls   lw_plantdata-lotsizekey   lw_plantdatax-lotsizekey.
    map_field_char iw_dato-sobsl   lw_plantdata-spproctype   lw_plantdatax-spproctype.
    map_field_char iw_dato-fhori   lw_plantdata-sm_key       lw_plantdatax-sm_key.

    IF iw_dato-vrbmt IS NOT INITIAL.

      lv_vrbdt = sy-datum + 15.
      map_field_char iw_dato-vrbmt  lw_plantdata-refmatcons   lw_plantdatax-refmatcons.
      map_field_char lv_vrbdt       lw_plantdata-d_to_ref_m   lw_plantdatax-d_to_ref_m.
      map_field_char 1              lw_plantdata-mult_ref_m   lw_plantdatax-mult_ref_m.

      lw_extensionin-structure = 'BAPI_TE_MARC'.
      lw_extensionin-valuepart1 = |{ iw_dato-werks }{ iw_dato-vrbwk }|.
      APPEND lw_extensionin TO li_extensionin.

      lw_extensioninx-structure = 'BAPI_TE_MARCX'.
      lw_extensioninx-valuepart1 = |{ iw_dato-werks }{ abap_true }|.
      APPEND lw_extensioninx TO li_extensioninx.

    ENDIF.

    "Campos numéricos con soporte "&"
    map_field_num iw_dato-minbe  lw_plantdata-reorder_pt     lw_plantdatax-reorder_pt     'MINBE'.
    map_field_num iw_dato-eisbe  lw_plantdata-safety_stk     lw_plantdatax-safety_stk     'EISBE'.
    map_field_num iw_dato-eislo  lw_plantdata-min_safety_stk lw_plantdatax-min_safety_stk 'EISLO'.
    map_field_num iw_dato-bstmi  lw_plantdata-minlotsize     lw_plantdatax-minlotsize     'BSTMI'.
    map_field_num iw_dato-bstma  lw_plantdata-maxlotsize     lw_plantdatax-maxlotsize     'BSTMA'.
    map_field_num iw_dato-bstrf  lw_plantdata-round_val      lw_plantdatax-round_val      'BSTRF'.
    map_field_num iw_dato-mabst  lw_plantdata-max_stock      lw_plantdatax-max_stock      'MABST'.
    map_field_num iw_dato-plifz  lw_plantdata-plnd_delry     lw_plantdatax-plnd_delry     'PLIFZ'.
    map_field_num iw_dato-webaz  lw_plantdata-gr_pr_time     lw_plantdatax-gr_pr_time     'WEBAZ'.
    map_field_num iw_dato-maxlz  lw_plantdata-stgeperiod     lw_plantdatax-stgeperiod     'MAXLZ'.

    "--- FORECASTPARAMETERS / FORECASTPARAMETERSX ---
    lw_forecastparameters-plant  = iw_dato-werks.
    lw_forecastparametersx-plant = iw_dato-werks.

    "PRMOD no admite "&"
    IF iw_dato-prmod <> c_caracter_borrado AND iw_dato-prmod IS NOT INITIAL.
      map_field_char iw_dato-prmod lw_forecastparameters-fore_model  lw_forecastparametersx-fore_model.
    ENDIF.

    "En escenario de creación
    IF p_crea = c_x.
      map_field_num iw_dato-peran  lw_forecastparameters-hist_vals   lw_forecastparametersx-hist_vals  'PERAN'.
      map_field_num iw_dato-anzpr  lw_forecastparameters-fore_pds    lw_forecastparametersx-fore_pds   'ANZPR'.
      map_field_num iw_dato-perio  lw_forecastparameters-season_pds  lw_forecastparametersx-season_pds 'PERIO'.
      map_field_char iw_dato-kzini lw_forecastparameters-initialize  lw_forecastparametersx-initialize.
    ENDIF.

    IF iw_dato-dismm = 'ND'.
      "Limpiar campos MRP
      CLEAR: lw_plantdata-mrp_ctrler,
             lw_plantdata-reorder_pt,
             lw_plantdata-safety_stk,
             lw_plantdata-minlotsize,
             lw_plantdata-maxlotsize,
             lw_plantdata-round_val,
             lw_plantdata-max_stock,
             lw_plantdata-plnd_delry,
             lw_plantdata-gr_pr_time,
             lw_plantdata-lotsizekey,
             lw_plantdata-spproctype,
             lw_plantdata-sloc_exprc,
             lw_plantdata-min_safety_stk,
             lw_plantdata-pl_ti_fnce,
             lw_plantdata-sm_key.
      "Los campos de pronóstico NO se limpian (PRMOD, PERAN, etc.)

      lw_plantdatax-mrp_type   = c_x.
      lw_plantdatax-mrp_ctrler = c_x.
      lw_plantdatax-plnd_delry = c_x.
      lw_plantdatax-gr_pr_time = c_x.
      lw_plantdatax-lotsizekey = c_x.
      lw_plantdatax-proc_type  = c_x.
      lw_plantdatax-spproctype = c_x.
      lw_plantdatax-reorder_pt = c_x.
      lw_plantdatax-safety_stk = c_x.
      lw_plantdatax-minlotsize = c_x.
      lw_plantdatax-maxlotsize = c_x.
      lw_plantdatax-round_val  = c_x.
      lw_plantdatax-max_stock  = c_x.
      lw_plantdatax-stgeperiod = c_x.
      lw_plantdatax-pl_ti_fnce = c_x.
      lw_plantdatax-sloc_exprc = c_x.
      lw_plantdatax-min_safety_stk = c_x.
      lw_plantdatax-sm_key = c_x.
    ENDIF.

    "Creación y modificación de datos maestros de materiales
    CALL FUNCTION 'BAPI_MATERIAL_SAVEDATA'
      EXPORTING
        headdata            = lw_headdata
        plantdata           = lw_plantdata
        plantdatax          = lw_plantdatax
        forecastparameters  = lw_forecastparameters
        forecastparametersx = lw_forecastparametersx
      TABLES
        returnmessages      = li_returnmessages
        extensionin         = li_extensionin
        extensioninx        = li_extensioninx.

    "--- Analizar updated_mrps ---
    DATA(lv_hay_error)  = abap_false.
    LOOP AT li_returnmessages INTO lw_returnmessages WHERE type CA 'EW'.
      lv_hay_error = abap_true.
      ev_message = |{ ev_message } { lw_returnmessages-message }|.
    ENDLOOP.

    IF lv_hay_error = abap_true.
      ev_success = abap_false.
      "Rollback explícito en caso de error
      CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
    ELSE.
      ev_success = abap_true.
      IF v_modo = c_modo_ejecucion.
        CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
          EXPORTING
            wait = abap_true.
      ELSE.
        "Simulación: rollback
        CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
      ENDIF.
    ENDIF.

  ENDMETHOD.

  METHOD check_obligatory_fields.
    "----------------------------------------------------------------------
    " Valida que los campos obligatorios estén presentes
    "----------------------------------------------------------------------

    ev_valid = abap_true.
    CLEAR ev_message.

    "Material y Centro son obligatorios
    IF iw_dato-matnr IS INITIAL.
      ev_valid   = abap_false.
      ev_message = TEXT-018. "Campo MATNR (Material) es obligatorio.
      RETURN.
    ENDIF.

    IF iw_dato-werks IS INITIAL.
      ev_valid   = abap_false.
      ev_message = TEXT-019. "Campo WERKS (Centro) es obligatorio.
      RETURN.
    ENDIF.

    "Característica de planificación (DISMM) obligatorio
    IF iw_dato-dismm IS INITIAL.
      ev_valid   = abap_false.
      ev_message = TEXT-020. "Campo DISMM (Característica Planificación) es obligatorio.
      RETURN.
    ENDIF.

    IF iw_dato-dismm <> 'ND'.
      "Tamaño lote planificación (DISLS) obligatorio
      IF iw_dato-disls IS INITIAL.
        ev_valid   = abap_false.
        ev_message = TEXT-021. "Campo DISLS (Tamaño lote Planif) es obligatorio.
        RETURN.
      ENDIF.
    ENDIF.

    "Validar que campos obligatorios no tengan "&"
    IF iw_dato-matnr = c_caracter_borrado OR
       iw_dato-werks = c_caracter_borrado OR
       iw_dato-dismm = c_caracter_borrado OR
       iw_dato-disls = c_caracter_borrado OR
       iw_dato-bstrf = c_caracter_borrado OR
       iw_dato-plifz = c_caracter_borrado OR
       iw_dato-prmod = c_caracter_borrado OR
       iw_dato-peran = c_caracter_borrado OR
       iw_dato-anzpr = c_caracter_borrado.
      ev_valid   = abap_false.
      ev_message = TEXT-022. "No se permite carácter "&" en campos obligatorios.
      RETURN.
    ENDIF.

  ENDMETHOD.

  METHOD fixed_fields.

    "Valores fijos
    iw_updated_mrp-dispo = iw_dato-dispo = 'MERC'.
    iw_updated_mrp-beskz = iw_dato-beskz = 'F'.
    iw_updated_mrp-lgfsb = iw_dato-lgfsb = 'MERC'.
    iw_updated_mrp-perkz = iw_dato-perkz = 'M'.

    IF p_crea = abap_true.
      iw_updated_mrp-kzini = iw_dato-kzini = 'X'.
    ENDIF.

  ENDMETHOD.

  METHOD rule_nd.
    "----------------------------------------------------------------------
    " Valida regla ND
    "----------------------------------------------------------------------

    IF iw_updated_mrp-dismm = 'ND'.
      "Limpiar campos MRP
      CLEAR: iw_dato-disls,
             iw_dato-minbe,
             iw_dato-bstmi,
             iw_dato-bstma,
             iw_dato-bstrf,
             iw_dato-mabst,
             iw_dato-sobsl,
             iw_dato-plifz,
             iw_dato-webaz,
             iw_dato-eisbe,
             iw_dato-eislo,
             iw_dato-fhori,
             iw_dato-dispo,
             iw_dato-beskz,
             iw_dato-lgfsb.

      CLEAR: iw_updated_mrp-disls,
             iw_updated_mrp-minbe,
             iw_updated_mrp-bstmi,
             iw_updated_mrp-bstma,
             iw_updated_mrp-bstrf,
             iw_updated_mrp-mabst,
             iw_updated_mrp-sobsl,
             iw_updated_mrp-plifz,
             iw_updated_mrp-webaz,
             iw_updated_mrp-eisbe,
             iw_updated_mrp-eislo,
             iw_updated_mrp-fhori,
             iw_updated_mrp-dispo,
             iw_updated_mrp-beskz,
             iw_updated_mrp-lgfsb.

    ENDIF.

  ENDMETHOD.

  METHOD validate_file_structure.
    "----------------------------------------------------------------------
    " Valida que la cabecera del archivo tenga la estructura esperada
    "----------------------------------------------------------------------

    DATA:
      li_header_cols    TYPE STANDARD TABLE OF string,
      li_expected_cols  TYPE STANDARD TABLE OF string,
      lv_col_count      TYPE i,
      lv_expected_count TYPE i,
      lv_index          TYPE i.

    CLEAR: ev_message.
    ev_valid = abap_true.

    " Definir columnas esperadas (en el orden exacto del layout)
    APPEND 'MARA-MATNR' TO li_expected_cols.
    APPEND 'MARC-WERKS' TO li_expected_cols.
    APPEND 'MARC-DISMM' TO li_expected_cols.
    APPEND 'MARC-MINBE' TO li_expected_cols.
    APPEND 'MARC-DISLS' TO li_expected_cols.
    APPEND 'MARC-BSTMI' TO li_expected_cols.
    APPEND 'MARC-BSTMA' TO li_expected_cols.
    APPEND 'MARC-MABST' TO li_expected_cols.
    APPEND 'MARC-BSTRF' TO li_expected_cols.
    APPEND 'MARC-SOBSL' TO li_expected_cols.
    APPEND 'MARC-PLIFZ' TO li_expected_cols.
    APPEND 'MARC-WEBAZ' TO li_expected_cols.
    APPEND 'MARC-FHORI' TO li_expected_cols.
    APPEND 'MARC-EISBE' TO li_expected_cols.
    APPEND 'MARC-EISLO' TO li_expected_cols.
    APPEND 'MPOP-PRMOD' TO li_expected_cols.
    APPEND 'MARC-VRBMT' TO li_expected_cols.
    APPEND 'MARC-VRBWK' TO li_expected_cols.
    APPEND 'MPOP-PERAN' TO li_expected_cols.
    APPEND 'MPOP-ANZPR' TO li_expected_cols.
    APPEND 'MPOP-PERIO' TO li_expected_cols.
    APPEND 'MARC-MAABC' TO li_expected_cols.
    APPEND 'MARC-MAXLZ' TO li_expected_cols.

    " Dividir la cabecera del archivo por el separador
    SPLIT iv_header AT c_sep_tab INTO TABLE li_header_cols.

    lv_col_count      = lines( li_header_cols ).
    lv_expected_count = lines( li_expected_cols ).

    " ── Validación 1: Número de columnas ──
    IF lv_col_count <> lv_expected_count.
      ev_valid = abap_false.
      ev_message = |El archivo tiene { lv_col_count } columnas, se esperan { lv_expected_count }.|.
      RETURN.
    ENDIF.

    " ── Validación 2: Nombre de cada columna ──
    lv_index = 0.
    LOOP AT li_expected_cols INTO DATA(lv_expected).
      lv_index = lv_index + 1.
      READ TABLE li_header_cols INTO DATA(lv_actual) INDEX lv_index.
      IF sy-subrc = 0.
        " Limpiar espacios y comparar en mayúsculas
        CONDENSE lv_actual NO-GAPS.
        TRANSLATE lv_actual TO UPPER CASE.
        CONDENSE lv_expected NO-GAPS.

        IF lv_actual <> lv_expected.
          ev_valid = abap_false.
          ev_message = |Columna { lv_index }: se esperaba "{ lv_expected }" pero se encontró "{ lv_actual }".|.
          RETURN.
        ENDIF.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

ENDCLASS.

CLASS cl_alv_mrp DEFINITION FINAL.

  PUBLIC SECTION.

    METHODS:
      constructor
        IMPORTING
          it_updated_mrp TYPE tt_updated_mrp,

      display_alv,

      hotspot_click  FOR EVENT hotspot_click OF cl_gui_alv_grid
        IMPORTING e_row_id e_column_id es_row_no ##NEEDED.

  PRIVATE SECTION.

    DATA:
      li_updated_mrp TYPE tt_updated_mrp.

    DATA:
      lo_alv       TYPE REF TO cl_gui_alv_grid ##NEEDED,
      lo_container TYPE REF TO cl_gui_custom_container ##NEEDED,
      lo_dock      TYPE REF TO cl_gui_docking_container ##NEEDED.

    METHODS:
      build_fieldcat RETURNING VALUE(rt_fieldcat) TYPE lvc_t_fcat,
      build_layout   RETURNING VALUE(rw_layout) TYPE lvc_s_layo.


ENDCLASS.

CLASS cl_alv_mrp IMPLEMENTATION.

  METHOD constructor.
    li_updated_mrp = it_updated_mrp.
  ENDMETHOD.

  METHOD display_alv.
    "----------------------------------------------------------------------
    " Muestra reporte ALV con updated_mrps
    "----------------------------------------------------------------------

    DATA:
      lw_layout TYPE lvc_s_layo.

    DATA:
      li_fieldcat TYPE lvc_t_fcat.

    IF lo_alv IS INITIAL.
      "Crear container si no existe
      CREATE OBJECT lo_container
        EXPORTING
          container_name = 'CONTAINER_ALV'.

      "Crear grid en el contenedor
      CREATE OBJECT lo_alv
        EXPORTING
          i_parent = lo_container.

      "Registrar handler de eventos para hotspot
      SET HANDLER hotspot_click FOR lo_alv.

      "Configurar layout
      lw_layout = build_layout( ).

      "Obtener catálogo
      li_fieldcat = build_fieldcat( ).

      "Mostrar ALV
      TRY.
          CALL METHOD lo_alv->set_table_for_first_display
            EXPORTING
              is_layout       = lw_layout
            CHANGING
              it_outtab       = li_updated_mrp
              it_fieldcatalog = li_fieldcat.

          " Llamar Dynpro que contiene el container
          CALL SCREEN 100.

        CATCH cx_root INTO DATA(lo_error) ##CATCH_ALL.
          DATA(lv_error) = lo_error->get_text(  ) ##NEEDED.

      ENDTRY.
    ELSE.
      lo_alv->refresh_table_display( ).
    ENDIF.

  ENDMETHOD.

  METHOD build_fieldcat.
    "----------------------------------------------------------------------
    " Construir catálogo de campos
    "----------------------------------------------------------------------
    CLEAR: rt_fieldcat[].

    CALL FUNCTION 'LVC_FIELDCATALOG_MERGE'
      EXPORTING
        i_structure_name       = 'ZSTMM_ACT_MRP_ALV'
      CHANGING
        ct_fieldcat            = rt_fieldcat
      EXCEPTIONS
        inconsistent_interface = 1
        program_error          = 2
        OTHERS                 = 3.
    IF sy-subrc <> 0.
      MESSAGE s908(fb) WITH TEXT-025. "Error al crear catálogo
    ENDIF.

    "Activar hotspot en el campo MATNR para navegación a MM03
    LOOP AT rt_fieldcat ASSIGNING FIELD-SYMBOL(<lfs_fcat>).
      IF <lfs_fcat>-fieldname = 'MATNR'.
        <lfs_fcat>-hotspot = abap_true.
        EXIT.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD build_layout.
    "----------------------------------------------------------------------
    " Construir layout
    "----------------------------------------------------------------------
    rw_layout-zebra = abap_true.
    rw_layout-cwidth_opt = abap_true.

  ENDMETHOD.

  METHOD hotspot_click.
    "----------------------------------------------------------------------
    " Hotspot click: Navegar a MM03 al hacer clic en MATNR
    "----------------------------------------------------------------------

    DATA:
      lv_matnr TYPE matnr.

    CHECK e_column_id-fieldname = 'MATNR'.

    "Obtener el número de material de la fila seleccionada
    READ TABLE li_updated_mrp INTO DATA(lw_line) INDEX e_row_id-index.
    IF sy-subrc = 0.
      lv_matnr = lw_line-matnr.

      "Pasar parámetro de material y llamar a MM03
      SET PARAMETER ID 'MAT' FIELD lv_matnr.
      CALL TRANSACTION 'MM03' AND SKIP FIRST SCREEN.     "#EC CI_CALLTA
    ENDIF.

  ENDMETHOD.

ENDCLASS.

*&---------------------------------------------------------------------*
*&      Form  F_BROWSE_FILE
*&---------------------------------------------------------------------*
*       Selección de archivo
*----------------------------------------------------------------------*
FORM f_browse_file .

  DATA:
    li_filetable TYPE filetable.

  DATA:
    lv_rc     TYPE i,
    lv_action TYPE i.

  TRY.
      cl_gui_frontend_services=>file_open_dialog(
        EXPORTING
          default_extension       = '*.csv'
          file_filter             = 'CSV Files (*.csv)|*.csv' ##NO_TEXT
          multiselection          = abap_false
        CHANGING
          file_table              = li_filetable
          rc                      = lv_rc
          user_action             = lv_action
        EXCEPTIONS
          file_open_dialog_failed = 1
          cntl_error              = 2
          error_no_gui            = 3
          not_supported_by_gui    = 4
          OTHERS                  = 5 ).

      IF sy-subrc = 0 AND lv_action = cl_gui_frontend_services=>action_ok.
        READ TABLE li_filetable INTO DATA(lw_file) INDEX 1.
        IF sy-subrc = 0.
          p_file = lw_file-filename.
        ENDIF.
      ENDIF.

    CATCH cx_root INTO DATA(lo_error) ##CATCH_ALL.
      MESSAGE lo_error->get_text( ) TYPE 'I'.
  ENDTRY.

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  F_MAIN_PROCESS
*&---------------------------------------------------------------------*
*       Proceso principal del programa
*----------------------------------------------------------------------*
FORM f_main_process .

  DATA:
    lo_act_mrp TYPE REF TO cl_act_mrp.

  "Determinar modo de ejecución
  IF p_simul = c_x.
    v_modo = c_modo_simulacion.
  ELSE.
    v_modo = c_modo_ejecucion.
  ENDIF.

  TRY.
      "Crear instancia de la clase principal
      CREATE OBJECT lo_act_mrp.

      "Leer archivo
      lo_act_mrp->read_file(
          IMPORTING
            et_excel = i_excel ).

      IF i_excel IS NOT INITIAL.

        "Procesar datos
        lo_act_mrp->process_data(
          IMPORTING
            et_updated_mrp = i_updated_mrp
          CHANGING
            it_datos       = i_excel ).

      ENDIF.

    CATCH cx_root INTO DATA(lo_root) ##CATCH_ALL.
      MESSAGE lo_root->get_text( ) TYPE 'E'.

  ENDTRY.

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  F_SHOW_RESULTS
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
FORM f_show_results .

  DATA:
    lo_alv_mrp TYPE REF TO cl_alv_mrp.

  IF i_updated_mrp IS INITIAL.
    MESSAGE s908(fb) WITH TEXT-024. "No hay resultados para mostrar
    RETURN.
  ENDIF.

  "Crear instancia de ALV
  TRY.
      CREATE OBJECT lo_alv_mrp
        EXPORTING
          it_updated_mrp = i_updated_mrp.

      "Mostrar ALV
      lo_alv_mrp->display_alv( ).

    CATCH cx_root INTO DATA(lo_exc) ##CATCH_ALL.
      MESSAGE lo_exc->get_text( ) TYPE 'E'.

  ENDTRY.

ENDFORM.