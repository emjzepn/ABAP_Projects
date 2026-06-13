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
*& Clase: ZCL_MM_FLEETIO_INIT_LOAD
*& Descripción: Clase principal para carga inicial de inventario
*&---------------------------------------------------------------------*
CLASS zcl_mm_fleetio_init_load DEFINITION FINAL.

  PUBLIC SECTION.

    "Constructor de la clase
    METHODS: constructor.

    "Método para leer archivo Excel
    METHODS: read_excel_file
      IMPORTING
        iv_file_path      TYPE rlgrap-filename
      EXPORTING
        et_excel_data     TYPE STANDARD TABLE
      RETURNING
        VALUE(rv_success) TYPE abap_bool
      RAISING
        cx_static_check.

    "Método para validar datos del Excel
    METHODS: validate_excel_data
      CHANGING
        ct_excel_data TYPE STANDARD TABLE
        ct_result_log TYPE STANDARD TABLE.

    "Método para procesar carga inicial
    METHODS: process_initial_load
      IMPORTING
        it_excel_data TYPE STANDARD TABLE
        iv_test_mode  TYPE xfeld
      CHANGING
        ct_result_log TYPE STANDARD TABLE.

    "Método para validar centro activo
    METHODS: validate_plant
      IMPORTING
        iv_plant        TYPE werks_d
      RETURNING
        VALUE(rv_valid) TYPE abap_bool.

    "Método para validar tipo de material permitido
    METHODS: validate_material_type
      IMPORTING
        iv_material     TYPE matnr
      RETURNING
        VALUE(rv_valid) TYPE abap_bool.

  PRIVATE SECTION.

    "Atributos privados
    DATA:
      i_active_plants TYPE STANDARD TABLE OF zta0117_flt_conf.

    DATA:
      r_allowed_mtart TYPE RANGE OF mtart.

    "Métodos privados
    METHODS: load_configuration.

    METHODS: get_material_base_unit
      IMPORTING
        iv_material         TYPE matnr
      RETURNING
        VALUE(rv_base_unit) TYPE meins.

    METHODS: post_goods_movement_561
      IMPORTING
        iw_excel_data     TYPE ty_excel_data
        iv_test_mode      TYPE xfeld
      EXPORTING
        ev_mat_doc        TYPE mblnr
        ev_message        TYPE string
      RETURNING
        VALUE(rv_success) TYPE abap_bool.

ENDCLASS.

*&---------------------------------------------------------------------*
*& Clase: ZCL_MM_FLEETIO_VALIDATOR
*& Descripción: Clase para validaciones específicas
*&---------------------------------------------------------------------*
CLASS zcl_mm_fleetio_validator DEFINITION FINAL.

  PUBLIC SECTION.

    "Validar existencia de material
    CLASS-METHODS: check_material_exists
      IMPORTING
        iv_material      TYPE matnr
      RETURNING
        VALUE(rv_exists) TYPE abap_bool.

    "Validar extensión de material a centro
    CLASS-METHODS: check_material_plant
      IMPORTING
        iv_material     TYPE matnr
        iv_plant        TYPE werks_d
      RETURNING
        VALUE(rv_valid) TYPE abap_bool.

    "Validar almacén
    CLASS-METHODS: check_storage_location
      IMPORTING
        iv_plant        TYPE werks_d
        iv_storage_loc  TYPE lgort_d
      RETURNING
        VALUE(rv_valid) TYPE abap_bool.

ENDCLASS.

*&---------------------------------------------------------------------*
*& Clase: ZCL_MM_FLEETIO_ALV_DISPLAY
*& Descripción: Clase para visualización ALV de resultados
*&---------------------------------------------------------------------*
CLASS zcl_mm_fleetio_alv_display DEFINITION FINAL.

  PUBLIC SECTION.

    "Método para construir catálogo de campos
    METHODS: build_fieldcatalog
      RETURNING
        VALUE(rt_fieldcat) TYPE lvc_t_fcat.

    "Método para mostrar ALV
    METHODS: display_alv.

ENDCLASS.

*&---------------------------------------------------------------------*
*& Include ZMM_INIT_STOCK_F01
*& Descripción: Implementación de métodos de las clases
*&---------------------------------------------------------------------*

*&---------------------------------------------------------------------*
*& Implementación: ZCL_MM_FLEETIO_INIT_LOAD
*&---------------------------------------------------------------------*
CLASS zcl_mm_fleetio_init_load IMPLEMENTATION.

  METHOD constructor.
    "Inicializar atributos y cargar configuración
    CALL METHOD me->load_configuration.
  ENDMETHOD.

  METHOD load_configuration.

    DATA:
      lw_tvarvc TYPE tvarvc,
      lw_range  LIKE LINE OF me->r_allowed_mtart.

    DATA:
      li_tvarvc TYPE STANDARD TABLE OF tvarvc.

    "Cargar tipos de material permitidos desde TVARVC
    SELECT *
      FROM tvarvc
      INTO TABLE li_tvarvc
      WHERE name = c_param_mtart
        AND type = 'S'.

    IF sy-subrc = 0.
      LOOP AT li_tvarvc INTO lw_tvarvc.
        lw_range-sign   = lw_tvarvc-sign.
        lw_range-option = lw_tvarvc-opti.
        lw_range-low    = lw_tvarvc-low.
        lw_range-high   = lw_tvarvc-high.
        APPEND lw_range TO me->r_allowed_mtart.
      ENDLOOP.
    ENDIF.

    "Cargar centros activos desde ZTASDCONF_FLEETIO
    SELECT *
      FROM zta0117_flt_conf
      INTO TABLE me->i_active_plants
      WHERE active = 'X'.

    IF sy-subrc NE 0.
      MESSAGE s908(fb) WITH 'No hay centros configurados'.
    ENDIF.

  ENDMETHOD.

  METHOD read_excel_file.

    DATA:
      li_data_tab TYPE STANDARD TABLE OF alsmex_tabline.

    DATA:
      lw_data_tab TYPE alsmex_tabline,
      lw_excel    TYPE ty_excel_data.

    DATA:
      lv_row      TYPE i VALUE 1.

    TRY.
        "Leer archivo Excel usando FM estándar
        CALL FUNCTION 'ALSM_EXCEL_TO_INTERNAL_TABLE'
          EXPORTING
            filename                = iv_file_path
            i_begin_col             = 1
            i_begin_row             = 2     "Saltar cabecera
            i_end_col               = 6
            i_end_row               = 65536
          TABLES
            intern                  = li_data_tab
          EXCEPTIONS
            inconsistent_parameters = 1
            upload_ole              = 2
            OTHERS                  = 3.

        IF sy-subrc <> 0.
          MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
            WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
        ENDIF.

        "Procesar datos del Excel
        SORT li_data_tab BY row col.

        LOOP AT li_data_tab INTO lw_data_tab.

          IF lv_row <> lw_data_tab-row.
            IF lw_excel IS NOT INITIAL.
              APPEND lw_excel TO et_excel_data.
              CLEAR lw_excel.
            ENDIF.
            lv_row = lw_data_tab-row.
          ENDIF.

          CASE lw_data_tab-col.
            WHEN 1. "Centro
              lw_excel-plant = lw_data_tab-value.
              CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
                EXPORTING
                  input  = lw_excel-plant
                IMPORTING
                  output = lw_excel-plant.

            WHEN 2. "Material
              lw_excel-material = lw_data_tab-value.
              CALL FUNCTION 'CONVERSION_EXIT_MATN1_INPUT'
                EXPORTING
                  input  = lw_excel-material
                IMPORTING
                  output = lw_excel-material.

            WHEN 3. "Almacén
              lw_excel-storage_loc = lw_data_tab-value.
              CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
                EXPORTING
                  input  = lw_excel-storage_loc
                IMPORTING
                  output = lw_excel-storage_loc.

            WHEN 4. "Cantidad
              REPLACE ALL OCCURRENCES OF ',' IN lw_data_tab-value WITH '.'.
              lw_excel-quantity = lw_data_tab-value.

            WHEN 5. "Unidad
              lw_excel-unit = lw_data_tab-value.

            WHEN 6. "Valor
              REPLACE ALL OCCURRENCES OF ',' IN lw_data_tab-value WITH '.'.
              lw_excel-value = lw_data_tab-value.

          ENDCASE.

        ENDLOOP.

        "Agregar última línea
        IF lw_excel IS NOT INITIAL.
          APPEND lw_excel TO et_excel_data.
        ENDIF.

        rv_success = abap_true.

      CATCH cx_static_check.
        rv_success = abap_false.
    ENDTRY.

  ENDMETHOD.

  METHOD validate_excel_data.

    DATA:
      lw_result    TYPE ty_result_log.

    DATA:
      lv_line_num  TYPE i VALUE 1,
      lv_base_unit TYPE meins,
      lv_valid     TYPE abap_bool.

    FIELD-SYMBOLS: <fs_excel> TYPE ty_excel_data.

    LOOP AT ct_excel_data ASSIGNING <fs_excel>.

      CLEAR lw_result.
      lw_result-line_num    = lv_line_num.
      lw_result-plant       = <fs_excel>-plant.
      lw_result-material    = <fs_excel>-material.
      lw_result-storage_loc = <fs_excel>-storage_loc.
      lw_result-quantity    = <fs_excel>-quantity.
      lw_result-unit        = <fs_excel>-unit.
      lw_result-value       = <fs_excel>-value.

      "Validar datos obligatorios
      IF <fs_excel>-plant IS INITIAL OR
         <fs_excel>-material IS INITIAL OR
         <fs_excel>-storage_loc IS INITIAL OR
         <fs_excel>-quantity IS INITIAL OR
         <fs_excel>-unit IS INITIAL OR
         <fs_excel>-value IS INITIAL.

        lw_result-status  = c_status_error.
        lw_result-icon    = c_icon_error.
        lw_result-message = text-e02. "Datos obligatorios incompletos
        APPEND lw_result TO ct_result_log.
        lv_line_num = lv_line_num + 1.
        CONTINUE.
      ENDIF.

      "Validar cantidad y valor mayores a cero
      IF <fs_excel>-quantity <= 0 OR <fs_excel>-value <= 0.
        lw_result-status  = c_status_error.
        lw_result-icon    = c_icon_error.
        lw_result-message = text-e03. "Cantidad o valor debe ser mayor a cero
        APPEND lw_result TO ct_result_log.
        lv_line_num = lv_line_num + 1.
        CONTINUE.
      ENDIF.

      "Validar centro activo
      lv_valid = me->validate_plant( iv_plant = <fs_excel>-plant ).
      IF lv_valid = abap_false.
        lw_result-status  = c_status_error.
        lw_result-icon    = c_icon_error.
        lw_result-message = text-e04. "Centro no configurado en ZTASDCONF_FLEETIO
        APPEND lw_result TO ct_result_log.
        lv_line_num = lv_line_num + 1.
        CONTINUE.
      ENDIF.

      "Validar existencia de material
      lv_valid = zcl_mm_fleetio_validator=>check_material_exists(
        iv_material = <fs_excel>-material ).
      IF lv_valid = abap_false.
        lw_result-status  = c_status_error.
        lw_result-icon    = c_icon_error.
        lw_result-message = text-e05. "Material no existe en SAP
        APPEND lw_result TO ct_result_log.
        lv_line_num = lv_line_num + 1.
        CONTINUE.
      ENDIF.

      "Validar tipo de material permitido
      lv_valid = me->validate_material_type( iv_material = <fs_excel>-material ).
      IF lv_valid = abap_false.
        lw_result-status  = c_status_error.
        lw_result-icon    = c_icon_error.
        lw_result-message = text-e06. "Tipo de material no permitido
        APPEND lw_result TO ct_result_log.
        lv_line_num = lv_line_num + 1.
        CONTINUE.
      ENDIF.

      "Validar extensión de material a centro
      lv_valid = zcl_mm_fleetio_validator=>check_material_plant(
        iv_material = <fs_excel>-material
        iv_plant    = <fs_excel>-plant ).
      IF lv_valid = abap_false.
        lw_result-status  = c_status_error.
        lw_result-icon    = c_icon_error.
        lw_result-message = text-e07. "Material no extendido al centro
        APPEND lw_result TO ct_result_log.
        lv_line_num = lv_line_num + 1.
        CONTINUE.
      ENDIF.

      "Validar almacén
      lv_valid = zcl_mm_fleetio_validator=>check_storage_location(
        iv_plant       = <fs_excel>-plant
        iv_storage_loc = <fs_excel>-storage_loc ).
      IF lv_valid = abap_false.
        lw_result-status  = c_status_error.
        lw_result-icon    = c_icon_error.
        lw_result-message = text-e08. "Almacén no válido para el centro
        APPEND lw_result TO ct_result_log.
        lv_line_num = lv_line_num + 1.
        CONTINUE.
      ENDIF.

      "Validar unidad de medida base
      lv_base_unit = me->get_material_base_unit( iv_material = <fs_excel>-material ).
      <fs_excel>-unit = lv_base_unit.

      "Si todas las validaciones son exitosas, marcar como válido
      lw_result-status  = c_status_ok.
      lw_result-icon    = c_icon_ok.
      lw_result-message = text-s01. "Registro válido para procesar
      APPEND lw_result TO ct_result_log.

      lv_line_num = lv_line_num + 1.

    ENDLOOP.

  ENDMETHOD.

  METHOD process_initial_load.

    DATA: lw_result   TYPE ty_result_log,
          lv_mat_doc  TYPE mblnr,
          lv_message  TYPE string,
          lv_success  TYPE abap_bool,
          lv_line_num TYPE i VALUE 1.

    FIELD-SYMBOLS: <fs_excel>  TYPE ty_excel_data,
                   <fs_result> TYPE ty_result_log.

    "Procesar solo registros validados como OK
    LOOP AT it_excel_data ASSIGNING <fs_excel>.

      "Buscar resultado de validación
      READ TABLE ct_result_log ASSIGNING <fs_result>
        WITH KEY ('LINE_NUM') = lv_line_num.

      IF sy-subrc = 0 AND <fs_result>-status = c_status_ok.

        "Llamar al método de contabilización del movimiento 561
        lv_success = me->post_goods_movement_561(
          EXPORTING
            iw_excel_data = <fs_excel>
            iv_test_mode  = iv_test_mode
          IMPORTING
            ev_mat_doc    = lv_mat_doc
            ev_message    = lv_message ).

        IF lv_success = abap_true.
          <fs_result>-status  = c_status_ok.
          <fs_result>-icon    = c_icon_ok.
          <fs_result>-mat_doc = lv_mat_doc.
          <fs_result>-message = lv_message.
        ELSE.
          <fs_result>-status  = c_status_error.
          <fs_result>-icon    = c_icon_error.
          <fs_result>-message = lv_message.
        ENDIF.

      ENDIF.

      lv_line_num = lv_line_num + 1.

    ENDLOOP.

  ENDMETHOD.

  METHOD validate_plant.

    DATA: ls_plant TYPE zta0117_flt_conf.

    rv_valid = abap_false.

    READ TABLE me->i_active_plants INTO ls_plant
      WITH KEY werks = iv_plant
               active = 'X'.

    IF sy-subrc = 0.
      rv_valid = abap_true.
    ENDIF.

  ENDMETHOD.

  METHOD validate_material_type.

    DATA: lv_mtart TYPE mtart.

    rv_valid = abap_false.

    "Obtener tipo de material
    SELECT SINGLE mtart
      FROM mara
      INTO lv_mtart
      WHERE matnr = iv_material.

    IF sy-subrc = 0.
      IF lv_mtart IN me->r_allowed_mtart.
        rv_valid = abap_true.
      ENDIF.
    ENDIF.

  ENDMETHOD.

  METHOD get_material_base_unit.

    "Obtiene unidad de medida
    SELECT SINGLE meins
      FROM mara
      INTO rv_base_unit
      WHERE matnr = iv_material.

  ENDMETHOD.

  METHOD post_goods_movement_561.

    DATA:
      lw_header TYPE bapi2017_gm_head_01,
      lw_code   TYPE bapi2017_gm_code,
      lw_item   TYPE bapi2017_gm_item_create,
      lw_return TYPE bapiret2.

    DATA:
      li_item   TYPE STANDARD TABLE OF bapi2017_gm_item_create,
      li_return TYPE STANDARD TABLE OF bapiret2.

    DATA:
      lv_mat_doc  TYPE bapi2017_gm_head_ret-mat_doc,
      lv_doc_year TYPE bapi2017_gm_head_ret-doc_year.

    "Construir cabecera del documento
    lw_header-pstng_date = sy-datum.  "Fecha de contabilización
    lw_header-doc_date   = sy-datum.  "Fecha del documento
    lw_header-ref_doc_no = 'INIT_LOAD'. "Referencia

    "Código de movimiento
    lw_code-gm_code = c_gm_code.  "05 = Other goods receipt

    "Construir posición del documento
    lw_item-material    = iw_excel_data-material.
    lw_item-plant       = iw_excel_data-plant.
    lw_item-stge_loc    = iw_excel_data-storage_loc.
    lw_item-move_type   = c_move_type.  "561
    lw_item-entry_qnt   = iw_excel_data-quantity.
    lw_item-entry_uom   = iw_excel_data-unit.
    lw_item-amount_lc   = iw_excel_data-value.  "Valor en moneda local
    APPEND lw_item TO li_item.

    "Llamar a BAPI para contabilizar movimiento
    CALL FUNCTION 'BAPI_GOODSMVT_CREATE'
      EXPORTING
        goodsmvt_header  = lw_header
        goodsmvt_code    = lw_code
        testrun          = iv_test_mode
      IMPORTING
        materialdocument = lv_mat_doc
        matdocumentyear  = lv_doc_year
      TABLES
        goodsmvt_item    = li_item
        return           = li_return.

    "Evaluar resultado
    READ TABLE li_return INTO lw_return WITH KEY type = 'E'.
    IF sy-subrc = 0.
      "Hubo error
      rv_success = abap_false.
      ev_message = lw_return-message.
    ELSE.
      "Éxito: hacer COMMIT si no es modo prueba
      IF iv_test_mode = abap_false.
        CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
          EXPORTING
            wait = 'X'.
      ENDIF.

      rv_success = abap_true.
      ev_mat_doc = lv_mat_doc.
      CONCATENATE 'Documento de material generado' lv_mat_doc INTO ev_message SEPARATED BY space.

    ENDIF.

  ENDMETHOD.

ENDCLASS.

*&---------------------------------------------------------------------*
*& Implementación: ZCL_MM_FLEETIO_VALIDATOR
*&---------------------------------------------------------------------*
CLASS zcl_mm_fleetio_validator IMPLEMENTATION.

  METHOD check_material_exists.

    DATA:
      lv_matnr TYPE matnr.

    rv_exists = abap_false.

    "Consulta material
    SELECT SINGLE matnr
      FROM mara
      INTO lv_matnr
      WHERE matnr = iv_material.

    IF sy-subrc = 0.
      rv_exists = abap_true.
    ENDIF.

  ENDMETHOD.

  METHOD check_material_plant.

    DATA:
      lv_matnr TYPE matnr.

    rv_valid = abap_false.

    "Consulta material en planta
    SELECT SINGLE matnr
      FROM marc
      INTO lv_matnr
      WHERE matnr = iv_material
        AND werks = iv_plant.

    IF sy-subrc = 0.
      rv_valid = abap_true.
    ENDIF.

  ENDMETHOD.

  METHOD check_storage_location.

    DATA:
      lv_lgort TYPE lgort_d.

    rv_valid = abap_false.

    "Consulta almacén
    SELECT SINGLE lgort
      FROM t001l
      INTO lv_lgort
      WHERE werks = iv_plant
        AND lgort = iv_storage_loc.

    IF sy-subrc = 0.
      rv_valid = abap_true.
    ENDIF.

  ENDMETHOD.

ENDCLASS.

*&---------------------------------------------------------------------*
*& Implementación: ZCL_MM_FLEETIO_ALV_DISPLAY
*&---------------------------------------------------------------------*
CLASS zcl_mm_fleetio_alv_display IMPLEMENTATION.

  METHOD build_fieldcatalog.

    DATA: lw_fieldcat TYPE lvc_s_fcat.

    "Campo: Número de línea
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'LINE_NUM'.
    lw_fieldcat-scrtext_s = 'Línea'.
    lw_fieldcat-scrtext_m = 'Núm Línea'.
    lw_fieldcat-scrtext_l = 'Número de Línea'.
    lw_fieldcat-col_pos   = 1.
    lw_fieldcat-outputlen = 10.
    APPEND lw_fieldcat TO rt_fieldcat.

    "Campo: Icono
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'ICON'.
    lw_fieldcat-scrtext_s = 'St'.
    lw_fieldcat-scrtext_m = 'Status'.
    lw_fieldcat-scrtext_l = 'Estado'.
    lw_fieldcat-col_pos   = 2.
    lw_fieldcat-icon      = 'X'.
    lw_fieldcat-outputlen = 4.
    APPEND lw_fieldcat TO rt_fieldcat.

    "Campo: Centro
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'PLANT'.
    lw_fieldcat-scrtext_s = 'Centro'.
    lw_fieldcat-scrtext_m = 'Centro'.
    lw_fieldcat-scrtext_l = 'Centro'.
    lw_fieldcat-col_pos   = 3.
    lw_fieldcat-outputlen = 4.
    APPEND lw_fieldcat TO rt_fieldcat.

    "Campo: Material
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'MATERIAL'.
    lw_fieldcat-scrtext_s = 'Material'.
    lw_fieldcat-scrtext_m = 'Material'.
    lw_fieldcat-scrtext_l = 'Material'.
    lw_fieldcat-col_pos   = 4.
    lw_fieldcat-outputlen = 18.
    APPEND lw_fieldcat TO rt_fieldcat.

    "Campo: Almacén
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'STORAGE_LOC'.
    lw_fieldcat-scrtext_s = 'Alm'.
    lw_fieldcat-scrtext_m = 'Almacén'.
    lw_fieldcat-scrtext_l = 'Almacén'.
    lw_fieldcat-col_pos   = 5.
    lw_fieldcat-outputlen = 4.
    APPEND lw_fieldcat TO rt_fieldcat.

    "Campo: Cantidad
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'QUANTITY'.
    lw_fieldcat-scrtext_s = 'Cant'.
    lw_fieldcat-scrtext_m = 'Cantidad'.
    lw_fieldcat-scrtext_l = 'Cantidad'.
    lw_fieldcat-col_pos   = 6.
    lw_fieldcat-outputlen = 13.
    APPEND lw_fieldcat TO rt_fieldcat.

    "Campo: Unidad
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'UNIT'.
    lw_fieldcat-scrtext_s = 'UM'.
    lw_fieldcat-scrtext_m = 'UM'.
    lw_fieldcat-scrtext_l = 'Unidad Medida'.
    lw_fieldcat-col_pos   = 7.
    lw_fieldcat-outputlen = 3.
    APPEND lw_fieldcat TO rt_fieldcat.

    "Campo: Valor
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'VALUE'.
    lw_fieldcat-scrtext_s = 'Valor'.
    lw_fieldcat-scrtext_m = 'Valor'.
    lw_fieldcat-scrtext_l = 'Valor'.
    lw_fieldcat-col_pos   = 8.
    lw_fieldcat-outputlen = 15.
    APPEND lw_fieldcat TO rt_fieldcat.

    "Campo: Documento material
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'MAT_DOC'.
    lw_fieldcat-scrtext_s = 'Doc Mat'.
    lw_fieldcat-scrtext_m = 'Doc Material'.
    lw_fieldcat-scrtext_l = 'Documento de Material'.
    lw_fieldcat-col_pos   = 9.
    lw_fieldcat-outputlen = 10.
    APPEND lw_fieldcat TO rt_fieldcat.

    "Campo: Mensaje
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'MESSAGE'.
    lw_fieldcat-scrtext_s = 'Mensaje'.
    lw_fieldcat-scrtext_m = 'Mensaje'.
    lw_fieldcat-scrtext_l = 'Mensaje de resultado'.
    lw_fieldcat-col_pos   = 10.
    lw_fieldcat-outputlen = 60.
    APPEND lw_fieldcat TO rt_fieldcat.

  ENDMETHOD.

  METHOD display_alv.

    DATA:
      lw_layout TYPE lvc_s_layo.

    DATA:
      li_fcat   TYPE lvc_t_fcat.

    DATA:
      lo_container TYPE REF TO cl_gui_custom_container,
      lo_alv_grid  TYPE REF TO cl_gui_alv_grid.

    "Construir catálogo de campos
    li_fcat = me->build_fieldcatalog( ).

    "Configurar layout
*    lw_layout-cwidth_opt = 'X'.  "Optimizar ancho de columnas
    lw_layout-zebra      = 'X'.  "Estilo cebra

    "Crear contenedor si no existe
    IF lo_container IS NOT BOUND.
      CREATE OBJECT lo_container
        EXPORTING
          container_name = 'CONTAINER_ALV'.  "Nombre del custom control
    ENDIF.

    "Crear instancia ALV si no existe
    IF lo_alv_grid IS NOT BOUND.
      CREATE OBJECT lo_alv_grid
        EXPORTING
          i_parent = lo_container.
    ENDIF.

    "Mostrar ALV
    CALL METHOD lo_alv_grid->set_table_for_first_display
      EXPORTING
        is_layout                     = lw_layout
      CHANGING
        it_outtab                     = it_result_log
        it_fieldcatalog               = li_fcat
      EXCEPTIONS
        invalid_parameter_combination = 1
        program_error                 = 2
        too_many_lines                = 3
        OTHERS                        = 4.

    IF sy-subrc <> 0.
      MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
        WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
    ENDIF.

    "Refrescar display
    CALL METHOD lo_alv_grid->refresh_table_display
      EXCEPTIONS
        finished = 1
        OTHERS   = 2.

  ENDMETHOD.

ENDCLASS.

*&---------------------------------------------------------------------*
*& Form F_INITIALIZATION
*& Descripción: Inicialización de parámetros por defecto
*&---------------------------------------------------------------------*
FORM f_initialization.

  "Inicializar ruta de archivo por defecto
  p_file = 'C:\Temp\CargaInicial.xlsx'.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form F_FILE_HELP
*& Descripción: Ayuda F4 para selección de archivo Excel
*&---------------------------------------------------------------------*
FORM f_file_help CHANGING cv_file TYPE rlgrap-filename.

  DATA:
    li_file_table TYPE filetable.

  DATA:
    lv_rc     TYPE i,
    lv_action TYPE i.

  CALL METHOD cl_gui_frontend_services=>file_open_dialog
    EXPORTING
      window_title      = 'Seleccionar archivo Excel'
      default_extension = '*.xlsx'
      file_filter       = 'Archivos Excel (*.xlsx)|*.xlsx|Todos (*.*)|*.*'
      multiselection    = abap_false
    CHANGING
      file_table        = li_file_table
      rc                = lv_rc
      user_action       = lv_action
    EXCEPTIONS
      OTHERS            = 1.

  IF lv_action = cl_gui_frontend_services=>action_ok.
    READ TABLE li_file_table INTO cv_file INDEX 1.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form F_VALIDATE_SELECTION_SCREEN
*& Descripción: Validaciones de pantalla de selección
*&---------------------------------------------------------------------*
FORM f_validate_selection_screen.

  DATA:
    lv_result TYPE abap_bool,
    lv_file   TYPE string.

  "Validar que se haya seleccionado un archivo
  IF p_file IS INITIAL.
    MESSAGE s908(fb) WITH 'Debe seleccionar un archivo'.
  ELSE.
    lv_file = p_file.
  ENDIF.

  "Validar que el archivo exista
  CALL METHOD cl_gui_frontend_services=>file_exist
    EXPORTING
      file   = lv_file
    RECEIVING
      result = lv_result
    EXCEPTIONS
      OTHERS = 1.

  IF lv_result = abap_false.
    MESSAGE s908(fb) WITH 'El archivo no existe'.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form F_MAIN_PROCESS
*& Descripción: Proceso principal de carga inicial
*&---------------------------------------------------------------------*
FORM f_main_process.

  DATA:
    lv_success TYPE abap_bool.

  DATA:
    lo_init_load TYPE REF TO zcl_mm_fleetio_init_load.

  "Crear instancia de la clase principal
  CREATE OBJECT lo_init_load.

  "Leer archivo Excel
  TRY.
      lv_success = lo_init_load->read_excel_file(
        EXPORTING
          iv_file_path  = p_file
        IMPORTING
          et_excel_data = it_excel_data ).

      IF lv_success = abap_false.
        MESSAGE e908(fb) WITH 'Error al leer archivo Excel'.
        RETURN.
      ENDIF.

    CATCH cx_static_check.
      MESSAGE e908(fb) WITH 'Error al leer archivo Excel'.
      RETURN.
  ENDTRY.

  "Validar líneas que no estén vacías
  IF it_excel_data IS INITIAL.
    MESSAGE e908(fb) WITH 'El archivo no contiene datos'.
    RETURN.
  ENDIF.

  "Validar datos del Excel
  lo_init_load->validate_excel_data(
    CHANGING
      ct_excel_data = it_excel_data
      ct_result_log = it_result_log ).

  "Procesar carga inicial
  lo_init_load->process_initial_load(
    EXPORTING
      it_excel_data = it_excel_data
      iv_test_mode  = p_test
    CHANGING
      ct_result_log = it_result_log ).

  "Calcular estadísticas
  v_lines_total = lines( it_result_log ).
  LOOP AT it_result_log ASSIGNING FIELD-SYMBOL(<fs_res>).
    IF <fs_res>-status = c_status_ok AND <fs_res>-mat_doc IS NOT INITIAL.
      v_lines_ok = v_lines_ok + 1.
    ELSE.
      v_lines_error = v_lines_error + 1.
    ENDIF.
  ENDLOOP.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form F_DISPLAY_RESULTS
*& Descripción: Mostrar resultados en ALV
*&---------------------------------------------------------------------*
FORM f_display_results.

  DATA:
    lo_alv_display TYPE REF TO zcl_mm_fleetio_alv_display.

  IF p_disp = abap_true AND it_result_log IS NOT INITIAL.

    CREATE OBJECT lo_alv_display.

    "Mostrar reporte
    lo_alv_display->display_alv( ).

    "Crear contenedor personalizado
    CALL SCREEN 0100.

  ENDIF.

ENDFORM.