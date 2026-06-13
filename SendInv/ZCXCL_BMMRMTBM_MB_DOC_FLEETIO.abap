CLASS zcxcl_bmmrmtbm_mb_doc_fleetio DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    TYPES:
      tt_flt_conf TYPE TABLE OF zta0117_flt_conf .
    TYPES:
      tt_flt_bwar TYPE TABLE OF zta0117_flt_bwar .
    TYPES:
      BEGIN OF ty_mkpf_json,
        mblnr TYPE mkpf-mblnr,
        mjahr TYPE mkpf-mjahr,
        budat TYPE mkpf-budat,
        cpudt TYPE mkpf-cpudt,
        cputm TYPE mkpf-cputm,
        usnam TYPE mkpf-usnam,
      END OF ty_mkpf_json .
    TYPES:
      BEGIN OF ty_mseg_json,
        mblnr TYPE mseg-mblnr,
        mjahr TYPE mseg-mjahr,
        zeile TYPE mseg-zeile,
        aufnr TYPE mseg-aufnr,
        bwart TYPE mseg-bwart,
        matnr TYPE mseg-matnr,
        werks TYPE mseg-werks,
        lgort TYPE mseg-lgort,
        menge TYPE string,
        erfmg TYPE string,
        meins TYPE mseg-meins,
        erfme TYPE mseg-erfme,
        shkzg TYPE mseg-shkzg,
        rsnum TYPE mseg-rsnum,
        rspos TYPE mseg-rspos,
        ebeln TYPE mseg-ebeln,
        ebelp TYPE mseg-ebelp,
        belnr TYPE mseg-belnr,
        buzei TYPE mseg-buzei,
        kzear TYPE mseg-kzear,
        equnr TYPE mseg-equnr,
        smbln TYPE mseg-smbln,
        smblp TYPE mseg-smblp,
        txz01 TYPE ekpo-txz01,
      END OF ty_mseg_json .
    TYPES:
      BEGIN OF ty_mara_json,
        matnr TYPE mara-matnr,
        mtart TYPE mara-mtart,
        matkl TYPE mara-matkl,
        meins TYPE mara-meins,
      END OF ty_mara_json .
    TYPES:
      BEGIN OF ty_makt_json,
        spras TYPE makt-spras,
        maktx TYPE string,
        maktg TYPE string,
      END OF ty_makt_json .
    TYPES:
      BEGIN OF ty_mard_json,
        matnr TYPE mard-matnr,
        werks TYPE mard-werks,
        lgort TYPE mard-lgort,
        labst TYPE string,
      END OF ty_mard_json .
    TYPES:
      BEGIN OF ty_derived_data_json,
        quantity         TYPE string,
        inventory_action TYPE string,
        signed_quantity  TYPE string,
        uom_published    TYPE string,
      END OF ty_derived_data_json .
    TYPES:
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
      END OF ty_payload_json .
    TYPES:
      BEGIN OF ty_token_response,
        access_token   TYPE string,
        expires_in     TYPE i,
        ext_expires_in TYPE i,
        token_type     TYPE string,
      END OF ty_token_response .

    DATA it_active_plants TYPE tt_flt_conf .
    DATA it_active_bwart TYPE tt_flt_bwar .
    DATA:
      r_allowed_mtart TYPE RANGE OF mtart .

    METHODS load_configuration .
    TYPE-POOLS abap .
    METHODS validate_document
      IMPORTING
        !iw_mkpf        TYPE mkpf
        !iw_mseg        TYPE mseg
      RETURNING
        VALUE(rv_valid) TYPE abap_bool .
    METHODS build_json_payload
      IMPORTING
        !iw_mkpf       TYPE mkpf
        !iw_mseg       TYPE mseg
      RETURNING
        VALUE(rv_json) TYPE string .
    METHODS send_to_fleetio
      IMPORTING
        !iv_json       TYPE string
      EXPORTING
        !ev_success    TYPE char1
        !ev_response   TYPE string
        !ev_error_text TYPE string .
    METHODS write_log
      IMPORTING
        !iw_mkpf       TYPE mkpf
        !iw_mseg       TYPE mseg
        !iv_json       TYPE string
        !iv_response   TYPE string
        !iv_status     TYPE char5
        !iv_error_text TYPE string .
    METHODS get_token
      EXPORTING
        !ev_success        TYPE char1
        !ev_token_response TYPE ty_token_response
        !ev_error_text     TYPE string .
  PROTECTED SECTION.
  PRIVATE SECTION.

    DATA v_log_number TYPE char20 .
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
        ebeln TYPE ekpo-ebeln,
        ebelp TYPE ekpo-ebelp,
        txz01 TYPE ekpo-txz01,
      END OF lty_ekpo.

    DATA:
      lw_mara    TYPE lty_mara,
      lw_makt    TYPE lty_makt,
      lw_mard    TYPE lty_mard,
      lw_ekpo    TYPE lty_ekpo,
      lw_payload TYPE ty_payload_json.

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
    SELECT SINGLE ebeln ebelp txz01
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
    lw_payload-system_source  = 'TSUCLNT010'.
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
    CONCATENATE iw_mseg-mblnr
                iw_mseg-mjahr
                iw_mseg-zeile
                INTO v_log_number SEPARATED BY '-'.

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
    lw_log-log_number       = v_log_number.
    lw_log-object_key       = v_log_number.
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