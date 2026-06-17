class ZCXCL_BMMRMTBM_MB_DOC_FLEETIO definition
  public
  final
  create public .

public section.

  types:
    tt_flt_conf TYPE TABLE OF zta0117_flt_conf .
  types:
    tt_flt_bwar TYPE TABLE OF zta0117_flt_bwar .
  types:
    BEGIN OF ty_mkpf_json,
        mblnr TYPE string,
        mjahr TYPE string,
        budat TYPE string,
        cpudt TYPE string,
        cputm TYPE string,
        usnam TYPE string,
      END OF ty_mkpf_json .
  types:
    BEGIN OF ty_mseg_json,
        mblnr TYPE string,
        mjahr TYPE string,
        zeile TYPE string,
        aufnr TYPE string,
        bwart TYPE string,
        matnr TYPE string,
        werks TYPE string,
        lgort TYPE string,
        menge TYPE string,
        erfmg TYPE string,
        meins TYPE string,
        erfme TYPE string,
        shkzg TYPE string,
        rsnum TYPE string,
        rspos TYPE string,
        ebeln TYPE string,
        ebelp TYPE string,
        belnr TYPE string,
        buzei TYPE string,
        kzear TYPE string,
        equnr TYPE string,
        smbln TYPE string,
        smblp TYPE string,
        txz01 TYPE string,
      END OF ty_mseg_json .
  types:
    BEGIN OF ty_mara_json,
        matnr TYPE string,
        mtart TYPE string,
        matkl TYPE string,
        meins TYPE string,
      END OF ty_mara_json .
  types:
    BEGIN OF ty_makt_json,
        spras TYPE string,
        maktx TYPE string,
        maktg TYPE string,
      END OF ty_makt_json .
  types:
    BEGIN OF ty_mard_json,
        matnr TYPE string,
        werks TYPE string,
        lgort TYPE string,
        labst TYPE string,
      END OF ty_mard_json .
  types:
    BEGIN OF ty_derived_data_json,
        quantity         TYPE string,
        inventory_action TYPE string,
        signed_quantity  TYPE string,
        uom_published    TYPE string,
      END OF ty_derived_data_json .
  types:
    BEGIN OF ty_service_line_json,
        packno TYPE string,
        extrow TYPE string,
        introw TYPE string,
        srvpos TYPE string,
        ktext1 TYPE string,
        menge  TYPE string,
        meins  TYPE string,
        brtwr  TYPE string,
        netwr  TYPE string,
      END OF ty_service_line_json .
  types:
    tt_service_line_json TYPE STANDARD TABLE OF ty_service_line_json WITH EMPTY KEY .
  types:
    BEGIN OF ty_service_data_json,
        packno        TYPE string,
        waers         TYPE string,
        service_lines TYPE tt_service_line_json,
      END OF ty_service_data_json .
  types:
    BEGIN OF ty_payload_json,
        system_source  TYPE string,
        object_key     TYPE string,
        log_number     TYPE string,
        transaction_id TYPE string,
        event_type     TYPE string,
        system_target  TYPE string,
        mkpf           TYPE ty_mkpf_json,
        mseg           TYPE ty_mseg_json,
        mara           TYPE ty_mara_json,
        makt           TYPE ty_makt_json,
        mard           TYPE ty_mard_json,
        derived_data   TYPE ty_derived_data_json,
        service_data   TYPE ty_service_data_json,
      END OF ty_payload_json .
  types:
    BEGIN OF ty_token_response,
        access_token   TYPE string,
        expires_in     TYPE i,
        ext_expires_in TYPE i,
        token_type     TYPE string,
      END OF ty_token_response .

  data IT_ACTIVE_PLANTS type TT_FLT_CONF .
  data IT_ACTIVE_BWART type TT_FLT_BWAR .
  data:
    r_allowed_mtart TYPE RANGE OF mtart .

  methods LOAD_CONFIGURATION .
  type-pools ABAP .
  methods VALIDATE_DOCUMENT
    importing
      !IW_MKPF type MKPF
      !IW_MSEG type MSEG
    returning
      value(RV_VALID) type ABAP_BOOL .
  methods BUILD_JSON_PAYLOAD
    importing
      !IW_MKPF type MKPF
      !IW_MSEG type MSEG
    returning
      value(RV_JSON) type STRING .
  methods SEND_TO_FLEETIO
    importing
      !IV_JSON type STRING
    exporting
      !EV_SUCCESS type CHAR1
      !EV_RESPONSE type STRING
      !EV_ERROR_TEXT type STRING .
  methods WRITE_LOG
    importing
      !IV_LOG_NUMBER type ZTA0117_FLT_LOG_NUMBER
      !IW_MKPF type MKPF
      !IW_MSEG type MSEG
      !IV_JSON type STRING
      !IV_RESPONSE type STRING
      !IV_STATUS type CHAR5
      !IV_ERROR_TEXT type STRING .
  methods GET_TOKEN
    exporting
      !EV_SUCCESS type CHAR1
      !EV_TOKEN_RESPONSE type TY_TOKEN_RESPONSE
      !EV_ERROR_TEXT type STRING .
  methods SET_LOG_EXTE
    importing
      !IV_LOG_NUMBER type ZTA0117_FLT_LOG_NUMBER
      !IV_JSON type STRING .
  PROTECTED SECTION.
private section.
ENDCLASS.



CLASS ZCXCL_BMMRMTBM_MB_DOC_FLEETIO IMPLEMENTATION.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCXCL_BMMRMTBM_MB_DOC_FLEETIO->BUILD_JSON_PAYLOAD
* +-------------------------------------------------------------------------------------------------+
* | [--->] IW_MKPF                        TYPE        MKPF
* | [--->] IW_MSEG                        TYPE        MSEG
* | [<-()] RV_JSON                        TYPE        STRING
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD build_json_payload.

    TYPES:
      BEGIN OF lty_mara,
        matnr TYPE mara-matnr,
        meins TYPE mara-meins,
        mtart TYPE mara-mtart,
        matkl TYPE mara-matkl,
      END OF lty_mara,

      BEGIN OF lty_makt,
        matnr TYPE makt-matnr,
        spras TYPE makt-spras,
        maktx TYPE makt-maktx,
        maktg TYPE makt-maktg,
      END OF lty_makt,

      BEGIN OF lty_mard,
        matnr TYPE mard-matnr,
        werks TYPE mard-werks,
        lgort TYPE mard-lgort,
        labst TYPE mard-labst,
      END OF lty_mard,

      BEGIN OF lty_ekpo,
        ebeln  TYPE ekpo-ebeln,
        ebelp  TYPE ekpo-ebelp,
        txz01  TYPE ekpo-txz01,
        pstyp  TYPE ekpo-pstyp,
        packno TYPE ekpo-packno,
      END OF lty_ekpo,

      BEGIN OF lty_eslh,
        packno  TYPE eslh-packno,
        fpackno TYPE eslh-fpackno,
        hpackno TYPE eslh-hpackno,
        waers   TYPE eslh-waers,
      END OF lty_eslh,

      BEGIN OF lty_esll,
        packno     TYPE esll-packno,
        introw     TYPE esll-introw,
        extrow     TYPE esll-extrow,
        srvpos     TYPE esll-srvpos,
        sub_packno TYPE esll-sub_packno,
        ktext1     TYPE esll-ktext1,
        menge      TYPE esll-menge,
        meins      TYPE esll-meins,
        brtwr      TYPE esll-brtwr,
        netwr      TYPE esll-netwr,
      END OF lty_esll.

    DATA:
      lw_mara    TYPE lty_mara,
      lw_makt    TYPE lty_makt,
      lw_mard    TYPE lty_mard,
      lw_ekpo    TYPE lty_ekpo,
      lw_eslh    TYPE lty_eslh,
      lw_esll    TYPE lty_esll,
      lw_payload TYPE ty_payload_json.

    DATA:
      li_esll_pack    TYPE TABLE OF lty_esll,
      li_esll_subpack TYPE TABLE OF lty_esll.

    DATA:
      lw_svc_line TYPE ty_service_line_json.

    DATA:
      lv_quantity      TYPE menge_d,
      lv_inv_action    TYPE char8,
      lv_signed_qty    TYPE menge_d,
      lv_uom_published TYPE meins,
      lv_stock         TYPE labst,
      lv_object_key    TYPE char30.

    "Leer datos maestros de material
    SELECT SINGLE matnr meins mtart matkl
      FROM mara
      INTO lw_mara
      WHERE matnr = iw_mseg-matnr.

    "Leer descripción del material
    SELECT SINGLE matnr spras maktx maktg
      FROM makt
      INTO lw_makt
      WHERE matnr = iw_mseg-matnr
        AND spras = 'E'.

    "Leer stock actual del material en el centro/almacén
    SELECT SINGLE matnr werks lgort labst
      FROM mard
      INTO lw_mard
      WHERE matnr = iw_mseg-matnr
        AND werks = iw_mseg-werks
        AND lgort = iw_mseg-lgort.

    IF sy-subrc = 0.
      lv_stock = lw_mard-labst.
    ENDIF.

    "Leer texto del material
    SELECT SINGLE ebeln ebelp txz01 pstyp packno
      FROM ekpo
      INTO lw_ekpo
      WHERE ebeln = iw_mseg-ebeln
        AND ebelp = iw_mseg-ebelp.

    "Derivar cantidad y acción de inventario
    IF iw_mseg-menge IS NOT INITIAL.
      lv_quantity = abs( iw_mseg-menge ).
    ELSE.
      lv_quantity = abs( iw_mseg-erfmg ).
    ENDIF.

    IF iw_mseg-shkzg = 'S'.  "Debe = Incremento
      lv_inv_action = 'INCREASE'.
      lv_signed_qty = iw_mseg-menge.
    ELSEIF iw_mseg-shkzg = 'H'.  "Haber = Decremento
      lv_inv_action = 'DECREASE'.
      lv_signed_qty = iw_mseg-menge * -1.
    ENDIF.

    "Determinar unidad publicada
    IF iw_mseg-meins IS NOT INITIAL.
      lv_uom_published = iw_mseg-meins.
    ELSEIF iw_mseg-matnr IS NOT INITIAL.
      lv_uom_published = lw_mara-meins.
    ELSE.
      "Caso técnico: sin material y sin MEINS
      lv_uom_published = iw_mseg-erfme.
    ENDIF.

    "Construir object_key
    CONCATENATE iw_mseg-mblnr
                iw_mseg-mjahr
                iw_mseg-zeile
                INTO lv_object_key SEPARATED BY '-'.

    "Construir JSON con estructura
    lw_payload-system_source  = |{ sy-sysid }CLNT{ sy-mandt }|.
    lw_payload-object_key     = lv_object_key.
    lw_payload-log_number     = lv_object_key.
    lw_payload-transaction_id = lv_object_key.
    lw_payload-event_type     = 'EVENT'.
    lw_payload-system_target  = 'CONFLUENT'.

    "MKPF
    lw_payload-mkpf-mblnr = iw_mkpf-mblnr.
    lw_payload-mkpf-mjahr = iw_mkpf-mjahr.
    lw_payload-mkpf-budat = iw_mkpf-budat.
    lw_payload-mkpf-cpudt = iw_mkpf-cpudt.
    lw_payload-mkpf-cputm = iw_mkpf-cputm.
    lw_payload-mkpf-usnam = iw_mkpf-usnam.

    "MSEG
    lw_payload-mseg-mblnr = iw_mseg-mblnr.
    lw_payload-mseg-mjahr = iw_mseg-mjahr.
    lw_payload-mseg-zeile = iw_mseg-zeile.
    lw_payload-mseg-aufnr = iw_mseg-aufnr.
    lw_payload-mseg-bwart = iw_mseg-bwart.
    lw_payload-mseg-matnr = iw_mseg-matnr.
    lw_payload-mseg-werks = iw_mseg-werks.
    lw_payload-mseg-lgort = iw_mseg-lgort.
    lw_payload-mseg-menge = |{ iw_mseg-menge NUMBER = USER }|. CONDENSE lw_payload-mseg-menge NO-GAPS.
    lw_payload-mseg-erfmg = |{ iw_mseg-erfmg NUMBER = USER }|. CONDENSE lw_payload-mseg-erfmg NO-GAPS.
    lw_payload-mseg-meins = iw_mseg-meins.
    lw_payload-mseg-erfme = iw_mseg-erfme.
    lw_payload-mseg-shkzg = iw_mseg-shkzg.
    lw_payload-mseg-rsnum = iw_mseg-rsnum.
    lw_payload-mseg-rspos = iw_mseg-rspos.
    lw_payload-mseg-ebeln = iw_mseg-ebeln.
    lw_payload-mseg-ebelp = iw_mseg-ebelp.
    lw_payload-mseg-belnr = iw_mseg-belnr.
    lw_payload-mseg-buzei = iw_mseg-buzei.
    lw_payload-mseg-kzear = iw_mseg-kzear.
    lw_payload-mseg-equnr = iw_mseg-equnr.
    lw_payload-mseg-smbln = iw_mseg-smbln.
    lw_payload-mseg-smblp = iw_mseg-smblp.
    lw_payload-mseg-txz01 = lw_ekpo-txz01.

    "MARA
    lw_payload-mara-matnr = lw_mara-matnr.
    lw_payload-mara-mtart = lw_mara-mtart.
    lw_payload-mara-matkl = lw_mara-matkl.
    lw_payload-mara-meins = lw_mara-meins.

    "MAKT
    lw_payload-makt-spras = lw_makt-spras.
    lw_payload-makt-maktx = lw_makt-maktx.
    lw_payload-makt-maktg = lw_makt-maktg.

    "MARD
    lw_payload-mard-matnr = lw_mard-matnr.
    lw_payload-mard-werks = lw_mard-werks.
    lw_payload-mard-lgort = lw_mard-lgort.
    lw_payload-mard-labst = |{ lv_stock NUMBER = USER }|. CONDENSE lw_payload-mard-labst NO-GAPS.

    "derivedData
    lw_payload-derived_data-quantity         = |{ lv_quantity NUMBER = USER }|. CONDENSE lw_payload-derived_data-quantity NO-GAPS.
    lw_payload-derived_data-inventory_action = lv_inv_action.
    lw_payload-derived_data-signed_quantity  = |{ lv_signed_qty NUMBER = USER }|. CONDENSE lw_payload-derived_data-signed_quantity NO-GAPS.
    lw_payload-derived_data-uom_published    = lv_uom_published.

    "Derivar serviceData para posiciones de servicio ---
    IF iw_mseg-ebeln IS NOT INITIAL AND iw_mseg-ebelp IS NOT INITIAL.
      IF lw_ekpo-pstyp = '9'.
        lw_payload-service_data-packno = lw_ekpo-packno.

        "Leer ESLH para obtener moneda y paquetes de líneas
        SELECT SINGLE packno fpackno hpackno waers
          FROM eslh
          INTO lw_eslh
          WHERE ebeln = iw_mseg-ebeln
            AND ebelp = iw_mseg-ebelp.

        IF sy-subrc = 0.
          lw_payload-service_data-waers = lw_eslh-waers.

          "Leer líneas de servicio de ESLL
          SELECT packno introw extrow srvpos sub_packno ktext1
                 menge meins brtwr netwr
            FROM esll
            INTO TABLE li_esll_pack
            WHERE packno = lw_ekpo-packno.
          IF sy-subrc = 0.
            "Leer líneas de servicio de ESLL
            SELECT packno introw extrow srvpos sub_packno ktext1
                   menge meins brtwr netwr
              FROM esll
              INTO TABLE li_esll_subpack
              FOR ALL ENTRIES IN li_esll_pack
              WHERE packno = li_esll_pack-sub_packno.
          ENDIF.

          LOOP AT li_esll_subpack INTO lw_esll.
            CLEAR lw_svc_line.
            lw_svc_line-packno = lw_esll-packno.
            lw_svc_line-extrow = lw_esll-extrow.
            lw_svc_line-introw = lw_esll-introw.
            lw_svc_line-srvpos = lw_esll-srvpos.
            lw_svc_line-ktext1 = lw_esll-ktext1.
            lw_svc_line-menge  = |{ lw_esll-menge NUMBER = USER }|. CONDENSE lw_svc_line-menge NO-GAPS.
            lw_svc_line-meins  = lw_esll-meins.
            lw_svc_line-brtwr  = |{ lw_esll-brtwr NUMBER = USER }|. CONDENSE lw_svc_line-brtwr NO-GAPS.
            lw_svc_line-netwr  = |{ lw_esll-netwr NUMBER = USER }|. CONDENSE lw_svc_line-netwr NO-GAPS.
            APPEND lw_svc_line TO lw_payload-service_data-service_lines.
          ENDLOOP.
        ENDIF.
      ENDIF.
    ENDIF.

    "Serializar a JSON
    rv_json = /ui2/cl_json=>serialize(
      data          = lw_payload
      compress      = abap_true
      pretty_name   = /ui2/cl_json=>pretty_mode-camel_case
    ).

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCXCL_BMMRMTBM_MB_DOC_FLEETIO->GET_TOKEN
* +-------------------------------------------------------------------------------------------------+
* | [<---] EV_SUCCESS                     TYPE        CHAR1
* | [<---] EV_TOKEN_RESPONSE              TYPE        TY_TOKEN_RESPONSE
* | [<---] EV_ERROR_TEXT                  TYPE        STRING
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD get_token.

    TYPES:
      BEGIN OF lty_apim_cnt,
        api_name       TYPE zta01im_apim_cnt-api_name,
        active         TYPE zta01im_apim_cnt-active,
        path           TYPE zta01im_apim_cnt-path,
        authentication TYPE zta01im_apim_cnt-authentication,
      END OF lty_apim_cnt,

      BEGIN OF lty_apim_par,
        api_name            TYPE zta01im_apim_par-api_name,
        classification_apim TYPE zta01im_apim_par-classification_apim,
        api_operation       TYPE zta01im_apim_par-api_operation,
        no_para             TYPE zta01im_apim_par-no_para,
        entity              TYPE zta01im_apim_par-entity,
        is_header           TYPE zta01im_apim_par-is_header,
        is_constant         TYPE zta01im_apim_par-is_constant,
        name                TYPE zta01im_apim_par-name,
        sign                TYPE zta01im_apim_par-sign,
        value               TYPE zta01im_apim_par-value,
      END OF lty_apim_par.

    DATA:
      lw_apim_cnt TYPE lty_apim_cnt,
      lw_apim_par TYPE lty_apim_par.

    DATA:
      li_apim_par TYPE TABLE OF lty_apim_par.

    DATA:
      lv_url           TYPE string,
      lv_response      TYPE string,
      lv_bearer        TYPE string,
      lv_grant_type    TYPE string,
      lv_client_id     TYPE string,
      lv_client_secret TYPE string,
      lv_scope         TYPE string,
      lv_body          TYPE string,
      lv_code          TYPE i.

    DATA:
      lo_http_client TYPE REF TO if_http_client.


    "Control de parametros para APIs
    SELECT SINGLE api_name active path authentication
      FROM zta01im_apim_cnt
      INTO lw_apim_cnt
      WHERE api_name = 'Token'.

    "Obligatory Parameters for API
    SELECT api_name
           classification_apim
           api_operation
           no_para
           entity
           is_header
           is_constant
           name
           sign
           value
      FROM zta01im_apim_par
      INTO TABLE li_apim_par
      WHERE api_name = 'Token'
       AND classification_apim = 'PROCUREMENT'.

    IF lw_apim_cnt IS INITIAL.
      ev_success = abap_false.
      ev_error_text = 'Error falta configuración del servicio'.
      RETURN.
    ENDIF.

    TRY.
        lv_url = lw_apim_cnt-path.

        "Crear cliente HTTP para conexión a CEMEX Bridge
        cl_http_client=>create_by_url(
          EXPORTING
            url           = lv_url
            proxy_host    = ''
            proxy_service = ''
          IMPORTING
            client = lo_http_client
          EXCEPTIONS
            OTHERS = 1 ).

        IF sy-subrc <> 0.
          ev_success = abap_false.
          ev_error_text = 'Error al crear cliente HTTP'.
          RETURN.
        ENDIF.

        "Configurar método POST
        lo_http_client->request->set_method( if_http_request=>co_request_method_post ).

        "Establecer content-type por defecto para POST de formulario
        lo_http_client->request->set_header_field(
          name  = 'Content-Type'
          value = 'application/x-www-form-urlencoded' ).

        LOOP AT li_apim_par INTO lw_apim_par.

          IF lw_apim_par-name = 'grant'.
            lv_grant_type = lw_apim_par-value.
          ENDIF.

          IF lw_apim_par-name = 'client_id'.
            lv_client_id = lw_apim_par-value.
          ENDIF.

          IF lw_apim_par-name = 'client_secret'.
            lv_client_secret = lw_apim_par-value.
          ENDIF.

          IF lw_apim_par-name = 'scope'.
            lv_scope = lw_apim_par-value.
          ENDIF.

        ENDLOOP.

        lv_body = |grant_type={ lv_grant_type }|
              && |&client_id={ lv_client_id }|
              && |&client_secret={ lv_client_secret }|
              && |&scope={ lv_scope }|.

        "Asignar el body al request HTTP
        lo_http_client->request->set_cdata( lv_body ).

        "Enviar request
        lo_http_client->send(
          EXCEPTIONS
            http_communication_failure = 1
            http_invalid_state         = 2
            OTHERS                     = 3 ).

        IF sy-subrc <> 0.
          ev_success = abap_false.
          ev_error_text = 'Error al enviar request HTTP'.
          lo_http_client->close( ).
          RETURN.
        ENDIF.

        "Recibir response
        lo_http_client->receive(
          EXCEPTIONS
            http_communication_failure = 1
            http_invalid_state         = 2
            OTHERS                     = 3 ).

        IF sy-subrc <> 0.
          ev_success = abap_false.
          ev_error_text = 'Error al recibir response HTTP'.
          lo_http_client->close( ).
          RETURN.
        ENDIF.

        "Obtener código de respuesta
        lo_http_client->response->get_status( IMPORTING code = lv_code ).

        "Obtener body de respuesta
        DATA(lv_resp_json) = lo_http_client->response->get_cdata( ).

        "Evaluar éxito
        IF lv_code >= 200 AND lv_code < 300.
          ev_success = abap_true.
          "Deserializar JSON a la estructura de salida
          /ui2/cl_json=>deserialize(
            EXPORTING
              json             = lv_resp_json
              pretty_name      = /ui2/cl_json=>pretty_mode-camel_case
            CHANGING
              data             = ev_token_response ).
        ELSE.
          ev_success = abap_false.
          ev_error_text = lv_resp_json.
        ENDIF.

        "Cerrar conexión
        lo_http_client->close( ).

      CATCH cx_root INTO DATA(lx_root).
        ev_success = abap_false.
        ev_error_text = lx_root->get_text( ).
    ENDTRY.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCXCL_BMMRMTBM_MB_DOC_FLEETIO->LOAD_CONFIGURATION
* +-------------------------------------------------------------------------------------------------+
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD load_configuration.

    DATA:
      lt_tvarvc TYPE STANDARD TABLE OF tvarvc.

    DATA:
      lw_tvarvc TYPE tvarvc,
      lw_range  LIKE LINE OF r_allowed_mtart.

    "Cargar tipos de material permitidos desde TVARVC
    SELECT *
      FROM tvarvc
      INTO TABLE lt_tvarvc
      WHERE name = 'ZTASD_MTART_FLEETIO'
        AND type = 'S'.

    IF sy-subrc = 0.
      LOOP AT lt_tvarvc INTO lw_tvarvc.
        lw_range-sign   = lw_tvarvc-sign.
        lw_range-option = lw_tvarvc-opti.
        lw_range-low    = lw_tvarvc-low.
        lw_range-high   = lw_tvarvc-high.
        APPEND lw_range TO r_allowed_mtart.
      ENDLOOP.
    ENDIF.

    "Cargar centros activos
    SELECT *
      FROM zta0117_flt_conf
      INTO TABLE it_active_plants
      WHERE active = 'X'.

    "Cargar tipos de movimiento permitidos
    SELECT *
      FROM zta0117_flt_bwar
      INTO TABLE it_active_bwart
      WHERE active = 'X'.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCXCL_BMMRMTBM_MB_DOC_FLEETIO->SEND_TO_FLEETIO
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_JSON                        TYPE        STRING
* | [<---] EV_SUCCESS                     TYPE        CHAR1
* | [<---] EV_RESPONSE                    TYPE        STRING
* | [<---] EV_ERROR_TEXT                  TYPE        STRING
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD send_to_fleetio.

    TYPES:
      BEGIN OF lty_apim_cnt,
        api_name       TYPE zta01im_apim_cnt-api_name,
        active         TYPE zta01im_apim_cnt-active,
        path           TYPE zta01im_apim_cnt-path,
        authentication TYPE zta01im_apim_cnt-authentication,
      END OF lty_apim_cnt,

      BEGIN OF lty_apim_par,
        api_name            TYPE zta01im_apim_par-api_name,
        classification_apim TYPE zta01im_apim_par-classification_apim,
        api_operation       TYPE zta01im_apim_par-api_operation,
        no_para             TYPE zta01im_apim_par-no_para,
        entity              TYPE zta01im_apim_par-entity,
        is_header           TYPE zta01im_apim_par-is_header,
        is_constant         TYPE zta01im_apim_par-is_constant,
        name                TYPE zta01im_apim_par-name,
        sign                TYPE zta01im_apim_par-sign,
        value               TYPE zta01im_apim_par-value,
      END OF lty_apim_par.

    DATA:
      lw_apim_cnt       TYPE lty_apim_cnt,
      lw_apim_par       TYPE lty_apim_par,
      lw_token_response TYPE ty_token_response.

    DATA:
      li_apim_par TYPE TABLE OF lty_apim_par.

    DATA:
      lv_url           TYPE string,
      lv_response      TYPE string,
      lv_bearer        TYPE string,
      lv_content_type  TYPE string,
      lv_subscription  TYPE string,
      lv_authorization TYPE string,
      lv_value         TYPE string,
      lv_code          TYPE i.

    DATA:
      lo_http_client TYPE REF TO if_http_client.

    "Control de parametros para APIs
    SELECT SINGLE api_name
                  active
                  path
                  authentication
      FROM zta01im_apim_cnt
      INTO lw_apim_cnt
      WHERE api_name = 'IM'.

    "Obligatory Parameters for API
    SELECT api_name
           classification_apim
           api_operation
           no_para
           entity
           is_header
           is_constant
           name
           sign
           value
      FROM zta01im_apim_par
      INTO TABLE li_apim_par
      WHERE api_name = 'IM'.

    IF lw_apim_cnt IS INITIAL.
      ev_success = abap_false.
      ev_error_text = 'Error falta configuración del servicio'.
      RETURN.
    ENDIF.

    "Obtener token
    get_token(
      IMPORTING
        ev_success        = ev_success          " Single-Character Indicator
        ev_token_response = lw_token_response   " Response
        ev_error_text     = ev_error_text       " Error text
    ).

    IF ev_success = abap_true.

      TRY.
          lv_url = lw_apim_cnt-path.

          "Crear cliente HTTP para conexión a CEMEX Bridge
          cl_http_client=>create_by_url(
            EXPORTING
              url           = lv_url
              proxy_host    = ''
              proxy_service = ''
            IMPORTING
              client = lo_http_client
            EXCEPTIONS
              OTHERS = 1 ).

          IF sy-subrc <> 0.
            ev_success = abap_false.
            ev_error_text = 'Error al crear cliente HTTP'.
            RETURN.
          ENDIF.

          "Configurar método POST
          lo_http_client->request->set_method( if_http_request=>co_request_method_post ).

          LOOP AT li_apim_par INTO lw_apim_par.

            IF lw_apim_par-name = 'Content-type'.
              lv_content_type = lw_apim_par-value.
              lo_http_client->request->set_header_field( name = 'Content-type' value = lv_content_type ).
            ENDIF.

            IF lw_apim_par-name = 'Ocp-Apim-Subscription-Key'.
              lv_subscription = lw_apim_par-value.
              lo_http_client->request->set_header_field( name = 'Ocp-Apim-Subscription-Key' value = lv_subscription ).
            ENDIF.

          ENDLOOP.

          IF lw_token_response-access_token IS NOT INITIAL.
            lv_authorization = |Bearer { lw_token_response-access_token }|.
            lo_http_client->request->set_header_field( name = 'Authorization' value = lv_authorization ).
          ENDIF.

          "Establecer payload JSON
          lo_http_client->request->set_cdata( iv_json ).

          "Enviar request
          lo_http_client->send(
            EXCEPTIONS
              http_communication_failure = 1
              http_invalid_state         = 2
              OTHERS                     = 3 ).

          IF sy-subrc <> 0.
            ev_success = abap_false.
            ev_error_text = 'Error al enviar request HTTP'.
            lo_http_client->close( ).
            RETURN.
          ENDIF.

          "Recibir response
          lo_http_client->receive(
            EXCEPTIONS
              http_communication_failure = 1
              http_invalid_state         = 2
              OTHERS                     = 3 ).

          IF sy-subrc <> 0.
            ev_success = abap_false.
            ev_error_text = 'Error al recibir response HTTP'.
            lo_http_client->close( ).
            RETURN.
          ENDIF.

          "Obtener código de respuesta
          lo_http_client->response->get_status( IMPORTING code = lv_code ).

          "Obtener body de respuesta
          ev_response = lo_http_client->response->get_cdata( ).

          "Evaluar éxito
          IF lv_code >= 200 AND lv_code < 300.
            ev_success = abap_true.
          ELSE.
            ev_success = abap_false.
          ENDIF.

          "Cerrar conexión
          lo_http_client->close( ).

        CATCH cx_root INTO DATA(lx_root).
          ev_success = abap_false.
          ev_response = lx_root->get_text( ).
      ENDTRY.

    ENDIF.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCXCL_BMMRMTBM_MB_DOC_FLEETIO->SET_LOG_EXTE
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_LOG_NUMBER                  TYPE        ZTA0117_FLT_LOG_NUMBER
* | [--->] IV_JSON                        TYPE        STRING
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD set_log_exte.

    DATA:
       lw_log_exte TYPE zta01im_log_exte.

    DATA:
       li_log_exte TYPE TABLE OF zta01im_log_exte.

    DATA:
       v_xstring_json TYPE xstring.

    " Convertir string a xstring
    CALL FUNCTION 'SCMS_STRING_TO_XSTRING'
      EXPORTING
        text     = iv_json
        encoding = '4110'  "Código para UTF-8
      IMPORTING
        buffer   = v_xstring_json.

    lw_log_exte-mandt           = sy-mandt.
    lw_log_exte-lognumber       = iv_log_number.
    lw_log_exte-erdat           = sy-datum.
    lw_log_exte-ertim           = sy-timlo.
    lw_log_exte-ernam           = sy-uname.
    lw_log_exte-entity          = 'IM'.
    lw_log_exte-service_odata   = 'IM Fleetio'.
    lw_log_exte-event           = 'POST'.
    lw_log_exte-objkey          = iv_log_number.
    lw_log_exte-external_sys_id = 'CONFLUENT'.
    lw_log_exte-in_out          = 'O'.
    lw_log_exte-status          = 'O1'.
*    lw_log_exte-objectclas      =
*    lw_log_exte-objectid        =
*    lw_log_exte-changenr        =
*    lw_log_exte-aedat_ackno     =
*    lw_log_exte-aetim_ackno     =
*    lw_log_exte-msg_ack         =
*    lw_log_exte-transid_event   =
    lw_log_exte-json_len = xstrlen( v_xstring_json ).
    lw_log_exte-json_msg = v_xstring_json.

    MODIFY zta01im_log_exte FROM lw_log_exte.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCXCL_BMMRMTBM_MB_DOC_FLEETIO->VALIDATE_DOCUMENT
* +-------------------------------------------------------------------------------------------------+
* | [--->] IW_MKPF                        TYPE        MKPF
* | [--->] IW_MSEG                        TYPE        MSEG
* | [<-()] RV_VALID                       TYPE        ABAP_BOOL
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD validate_document.

    DATA:
      lw_plant TYPE zta0117_flt_conf,
      lw_bwart TYPE zta0117_flt_bwar.

    DATA:
      lv_mtart TYPE mtart.

    rv_valid = abap_false.

    "Validar centro activo
    READ TABLE it_active_plants INTO lw_plant
      WITH KEY werks = iw_mseg-werks
               active = 'X'.

    IF sy-subrc <> 0.
      RETURN.  "Centro no configurado
    ENDIF.

    "Validar tipo de movimiento permitido
    READ TABLE it_active_bwart INTO lw_bwart
      WITH KEY bwart = iw_mseg-bwart
               active = 'X'.

    IF sy-subrc = 0.
      RETURN.  "Tipo de movimiento no configurado
    ENDIF.

    "Validar tipo de material permitido
    SELECT SINGLE mtart
      FROM mara
      INTO lv_mtart
      WHERE matnr = iw_mseg-matnr.

    IF sy-subrc = 0.
      IF lv_mtart NOT IN r_allowed_mtart.
        RETURN.  "Tipo de material no permitido
      ENDIF.
    ENDIF.

    "Validar scope funcional: solo stock de libre utilización
    "Se valida que SHKZG tenga valor (debe/haber)
    IF iw_mseg-shkzg IS INITIAL.
      RETURN.  "Movimiento fuera de scope
    ENDIF.

    "Si todas las validaciones pasaron
    rv_valid = abap_true.

  ENDMETHOD.


* <SIGNATURE>---------------------------------------------------------------------------------------+
* | Instance Public Method ZCXCL_BMMRMTBM_MB_DOC_FLEETIO->WRITE_LOG
* +-------------------------------------------------------------------------------------------------+
* | [--->] IV_LOG_NUMBER                  TYPE        ZTA0117_FLT_LOG_NUMBER
* | [--->] IW_MKPF                        TYPE        MKPF
* | [--->] IW_MSEG                        TYPE        MSEG
* | [--->] IV_JSON                        TYPE        STRING
* | [--->] IV_RESPONSE                    TYPE        STRING
* | [--->] IV_STATUS                      TYPE        CHAR5
* | [--->] IV_ERROR_TEXT                  TYPE        STRING
* +--------------------------------------------------------------------------------------</SIGNATURE>
  METHOD write_log.

    DATA:
      lw_log TYPE zta0117_flt_invl.

    DATA:
      lv_quantity      TYPE menge_d,
      lv_inv_action    TYPE char8,
      lv_signed_qty    TYPE menge_d,
      lv_uom_published TYPE meins,
      lv_timestamp     TYPE timestamp.

    "Generar log number único
    GET TIME STAMP FIELD lv_timestamp.

    "Derivar datos adicionales
    IF iw_mseg-menge IS NOT INITIAL.
      lv_quantity = abs( iw_mseg-menge ).
    ELSE.
      lv_quantity = abs( iw_mseg-erfmg ).
    ENDIF.

    IF iw_mseg-shkzg = 'S'.
      lv_inv_action = 'INCREASE'.
      lv_signed_qty = iw_mseg-menge.
    ELSEIF iw_mseg-shkzg = 'H'.
      lv_inv_action = 'DECREASE'.
      lv_signed_qty = iw_mseg-menge * -1.
    ENDIF.

    IF iw_mseg-meins IS NOT INITIAL.
      lv_uom_published = iw_mseg-meins.
    ELSE.
      lv_uom_published = iw_mseg-erfme.
    ENDIF.

    "Construir registro de log
    lw_log-mandt            = sy-mandt.
    lw_log-log_number       = iv_log_number.
    lw_log-object_key       = iv_log_number.
    lw_log-mblnr            = iw_mseg-mblnr.
    lw_log-mjahr            = iw_mseg-mjahr.
    lw_log-zeile            = iw_mseg-zeile.
    lw_log-aufnr            = iw_mseg-aufnr.
    lw_log-werks            = iw_mseg-werks.
    lw_log-lgort            = iw_mseg-lgort.
    lw_log-matnr            = iw_mseg-matnr.
    lw_log-bwart            = iw_mseg-bwart.
    lw_log-menge            = iw_mseg-menge.
    lw_log-erfmg            = iw_mseg-erfmg.
    lw_log-meins            = iw_mseg-meins.
    lw_log-erfme            = iw_mseg-erfme.
    lw_log-shkzg            = iw_mseg-shkzg.
    lw_log-rsnum            = iw_mseg-rsnum.
    lw_log-rspos            = iw_mseg-rspos.
    lw_log-kzear            = iw_mseg-kzear.
    lw_log-sgtxt            = iw_mseg-sgtxt.
    lw_log-equnr            = iw_mseg-equnr.
    lw_log-belnr            = iw_mseg-belnr.
    lw_log-buzei            = iw_mseg-buzei.
    lw_log-ebeln            = iw_mseg-ebeln.
    lw_log-ebelp            = iw_mseg-ebelp.
    lw_log-smbln            = iw_mseg-smbln.
    lw_log-smblp            = iw_mseg-smblp.
    lw_log-quantity         = lv_quantity.
    lw_log-inventory_action = lv_inv_action.
    lw_log-signed_quantity  = lv_signed_qty.
    lw_log-uom_published    = lv_uom_published.
    lw_log-entry_date       = sy-datum.
    lw_log-entry_time       = sy-uzeit.
    lw_log-posted_by        = iw_mkpf-usnam.
    lw_log-send_date        = sy-datum.
    lw_log-send_time        = sy-uzeit.
    lw_log-sent_by          = sy-uname.
    lw_log-reprocess_flag   = ''.
    lw_log-status           = iv_status.
    lw_log-payload_json     = iv_json.
    lw_log-response_msg     = iv_response.
    lw_log-error_text       = iv_error_text.

    "Insertar en tabla de log
    INSERT zta0117_flt_invl FROM lw_log.

  ENDMETHOD.
ENDCLASS.