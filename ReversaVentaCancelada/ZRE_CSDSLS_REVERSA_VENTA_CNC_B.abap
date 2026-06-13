*-------------------------------------------------------------------------------*
*                   Fabrica de Software ABAP NEORIS                             *
*-------------------------------------------------------------------------------*
* Nombre del Programa : ZRE_CSDSLS_REVERSA_VENTA_CNC_B                          *
* Descripción         : Proceso de Reversa de Venta por cancelación fiscal      *
*                       Automatiza la reversa de documentos de venta cuando el  *
*                       eDocument CFDI está en estatus CANCELADO                *
* Funcional           : Alejandra Barragán Lavara                               *
* Desarrollador       : Edgar Morales  - ABAP_01                                *
* Diseñador Técnico   : Edgar Morales                                           *
* Fecha de Creación   : 11.11.2025                                              *
* ID del Componente   : DF-EXSD43                                               *
* Número de Req.      : EXSD43                                                  *
*-------------------------------------------------------------------------------*
*                          LOG DE MODIFICACIONES                                *
*-------------------------------------------------------------------------------*
* Descripción          :                                                        *
* Funcional            :                                                        *
* Desarrollador        :                                                        *
* Fecha de Modificación:                                                        *
* ID del Componente    :                                                        *
* Núm. de Requerimiento:                                                        *
*-------------------------------------------------------------------------------*
*-------------------------------------------------------------------------------*
* CLASE PRINCIPAL PARA PROCESO DE REVERSA DE VENTA POR CANCELACIÓN FISCAL       *
*-------------------------------------------------------------------------------*
CLASS cl_sd_reversa_cfiscal DEFINITION FINAL.

  PUBLIC SECTION.

    TYPES:
      BEGIN OF lty_cancelled_invoices,
        vbeln_vf   TYPE vbrk-vbeln,
        fkart      TYPE vbrk-fkart,
        vkorg      TYPE vbrk-vkorg,
        fkdat      TYPE vbrk-fkdat,
        kunag      TYPE vbrk-kunag,
        fksto      TYPE vbrk-fksto,
        vbeln_va   TYPE vbak-vbeln,
        name1      TYPE kna1-name1,
        edoc_guid  TYPE edocument-edoc_guid,
        status_sat TYPE edocument-proc_status,
      END OF lty_cancelled_invoices.

    DATA:
      lw_cancelled_invoices TYPE lty_cancelled_invoices.

    " Métodos públicos
    METHODS:
      constructor,

      get_cancelled_invoices
        RETURNING
          VALUE(rt_reverse_orders) TYPE tt_reverse_orders,

      validate_authorizations
        CHANGING
          iv_reverse_orders TYPE tt_reverse_orders,

      execute_reverse
        CHANGING
          iv_reverse_orders TYPE ty_reverse_orders
        RETURNING
          VALUE(rv_success) TYPE abap_bool.

  PRIVATE SECTION.

    DATA:
      li_reverse_orders_temp TYPE TABLE OF ty_reverse_orders.

    " Métodos privados para cada paso de la cadena
    METHODS:

      get_invoices,

      get_historical_data,

      merge_data_sources,

      get_clearing_document
        IMPORTING
          iv_invoice      TYPE vbeln_vf
          iv_bukrs        TYPE bukrs
          iv_gjahr        TYPE gjahr
        RETURNING
          VALUE(rv_augbl) TYPE augbl,

      reset_cleared_items
        IMPORTING
          iv_invoice        TYPE vbeln_vf
        RETURNING
          VALUE(rv_success) TYPE abap_bool ##NEEDED,

      cancel_billing_document
        IMPORTING
          iv_invoice        TYPE vbrk-vbeln
          iv_test           TYPE abap_bool DEFAULT abap_true
        EXPORTING
          ev_invoice_can    TYPE vbrk-vbeln
        RETURNING
          VALUE(rv_success) TYPE abap_bool ##NEEDED,

      reverse_goods_movement
        IMPORTING
          iv_invoice        TYPE vbrk-vbeln
          iv_test           TYPE abap_bool DEFAULT abap_true
        RETURNING
          VALUE(rv_success) TYPE abap_bool ##NEEDED,

      change_shipment
        IMPORTING
          iv_invoice        TYPE vbrk-vbeln
          iv_test           TYPE abap_bool DEFAULT abap_true
        RETURNING
          VALUE(rv_success) TYPE abap_bool ##NEEDED,

      change_outbound_delivery
        IMPORTING
          iv_invoice        TYPE vbrk-vbeln
          iv_test           TYPE abap_bool DEFAULT abap_true
        RETURNING
          VALUE(rv_success) TYPE abap_bool ##NEEDED,

      change_sales_order
        IMPORTING
          iv_salesorder     TYPE vbak-vbeln
          iv_invoice        TYPE vbrk-vbeln
          iv_test           TYPE abap_bool DEFAULT abap_true
        RETURNING
          VALUE(rv_success) TYPE abap_bool ##NEEDED,

      check_lock_vbrk
        IMPORTING iv_vbeln         TYPE vbeln_vf
        RETURNING VALUE(rv_locked) TYPE abap_bool ##NEEDED,

      check_lock_vbak
        IMPORTING iv_vbeln         TYPE vbak-vbeln
        RETURNING VALUE(rv_locked) TYPE abap_bool ##NEEDED,

      check_lock_likp
        IMPORTING iv_vbeln         TYPE likp-vbeln
        RETURNING VALUE(rv_locked) TYPE abap_bool ##NEEDED,

      check_lock_vttk
        IMPORTING iv_tknum         TYPE vttk-tknum
        RETURNING VALUE(rv_locked) TYPE abap_bool ##NEEDED,

      generate_process_log
        IMPORTING iv_process  TYPE char30
                  iv_document TYPE vbeln_va
                  iv_status   TYPE char10
                  iv_message  TYPE char255.

ENDCLASS.

*-------------------------------------------------------------------------------*
* IMPLEMENTACIÓN DE LA CLASE PRINCIPAL                                         *
*-------------------------------------------------------------------------------*
CLASS cl_sd_reversa_cfiscal IMPLEMENTATION.

  METHOD constructor.
    " Inicialización de variables de la clase
  ENDMETHOD ##NEEDED.

  METHOD get_cancelled_invoices.
    " Método principal para obtener facturas canceladas

    " 1 Seleccionar facturas
    get_invoices( ).

    " 2 Obtiene historico
    get_historical_data(  ).

    " 3 Fusionar fuente de datos
    merge_data_sources(  ).

    " Retornar tabla de pedidos parciales
    rt_reverse_orders = li_reverse_orders_temp.

  ENDMETHOD.

  METHOD get_invoices.

    TYPES:
      BEGIN OF lty_vbrk,
        vbeln TYPE vbrk-vbeln,
        fkart TYPE vbrk-fkart,
        vkorg TYPE vbrk-vkorg,
        fkdat TYPE vbrk-fkdat,
        kunag TYPE vbrk-kunag,
        fksto TYPE vbrk-fksto,
      END OF lty_vbrk,

      BEGIN OF lty_vbrk_e,
        vbeln TYPE edocument-source_key,
        fkart TYPE vbrk-fkart,
        vkorg TYPE vbrk-vkorg,
        fkdat TYPE vbrk-fkdat,
        kunag TYPE vbrk-kunag,
        fksto TYPE vbrk-fksto,
      END OF lty_vbrk_e,

      BEGIN OF lty_vbfa,
        vbeln   TYPE vbfa-vbeln,
        vbelv   TYPE vbfa-vbelv,
        vbtyp_v TYPE vbfa-vbtyp_v,
      END OF lty_vbfa,

      BEGIN OF lty_kna1,
        kunnr TYPE kna1-kunnr,
        name1 TYPE kna1-name1,
      END OF lty_kna1,

      BEGIN OF lty_edocument,
        edoc_guid   TYPE edocument-edoc_guid,
        source_key  TYPE edocument-source_key,
        proc_status TYPE edocument-proc_status,
      END OF lty_edocument.

    DATA:
      lw_vbrk      TYPE lty_vbrk,
      lw_vbfa      TYPE lty_vbfa,
      lw_kna1      TYPE lty_kna1,
      lw_edocument TYPE lty_edocument.

    DATA:
      li_vbrk               TYPE TABLE OF lty_vbrk,
      li_vbrk_c             TYPE TABLE OF lty_vbrk,
      li_vbrk_e             TYPE TABLE OF lty_vbrk_e,
      li_vbfa               TYPE TABLE OF lty_vbfa,
      li_kna1               TYPE TABLE OF lty_kna1,
      li_edocument          TYPE TABLE OF lty_edocument,
      li_cancelled_invoices TYPE TABLE OF lty_cancelled_invoices.

    " Obtiene factura
    SELECT vbeln
           fkart
           vkorg
           fkdat
           kunag
           fksto
     FROM vbrk
     INTO TABLE li_vbrk
      WHERE vbeln IN s_vbeln
        AND vkorg IN s_vkorg
        AND kunag IN s_kunag
        AND fkdat IN s_fkdat
        AND fksto = space. " Solo facturas no anuladas manualmente
    IF sy-subrc = 0.

      SORT li_vbrk BY vbeln.

      MOVE-CORRESPONDING li_vbrk[] TO li_vbrk_c[].
      SORT li_vbrk_c BY vbeln.
      DELETE ADJACENT DUPLICATES FROM li_vbrk_c COMPARING vbeln.

      IF li_vbrk_c[] IS NOT INITIAL.
        " Obtiene pedido
        SELECT vbeln
               vbelv
               vbtyp_v
        FROM vbfa
        INTO TABLE li_vbfa
        FOR ALL ENTRIES IN li_vbrk_c
         WHERE vbeln = li_vbrk_c-vbeln
           AND vbtyp_v = 'C'.                           "#EC CI_NOFIRST
        IF sy-subrc = 0.
          SORT li_vbfa BY vbeln.
        ENDIF.
      ENDIF.

      MOVE-CORRESPONDING li_vbrk[] TO li_vbrk_c[].
      SORT li_vbrk_c BY kunag.
      DELETE ADJACENT DUPLICATES FROM li_vbrk_c COMPARING kunag.

      IF li_vbrk_c[] IS NOT INITIAL.
        " Obtiene nombre del cliente
        SELECT kunnr
               name1
         FROM kna1
         INTO TABLE li_kna1
         FOR ALL ENTRIES IN li_vbrk_c
         WHERE kunnr = li_vbrk_c-kunag.
        IF sy-subrc = 0.
          SORT li_kna1 BY kunnr.
        ENDIF.
      ENDIF.

      MOVE-CORRESPONDING li_vbrk[] TO li_vbrk_e[].
      SORT li_vbrk_e BY kunag.
      DELETE ADJACENT DUPLICATES FROM li_vbrk_e COMPARING vbeln.

      IF li_vbrk_e[] IS NOT INITIAL.
        " Obtiene UUID de la factura
        SELECT edoc_guid
               source_key
               proc_status
          FROM edocument
          INTO TABLE li_edocument
          FOR ALL ENTRIES IN li_vbrk_e
          WHERE source_key = li_vbrk_e-vbeln
            AND proc_status = c_status_canc.            "#EC CI_NOFIRST
        IF sy-subrc = 0.
          SORT li_edocument BY source_key.
        ENDIF.
      ENDIF.

    ENDIF.

    LOOP AT li_edocument INTO lw_edocument.

      lw_cancelled_invoices-edoc_guid = lw_edocument-edoc_guid.
      lw_cancelled_invoices-status_sat = lw_edocument-proc_status.

      READ TABLE li_vbrk INTO lw_vbrk
                              WITH KEY vbeln = lw_edocument-source_key
                              BINARY SEARCH ##WARN_OK.

      IF sy-subrc = 0.
        lw_cancelled_invoices-vbeln_vf = lw_vbrk-vbeln.
        lw_cancelled_invoices-fkart = lw_vbrk-fkart.
        lw_cancelled_invoices-vkorg = lw_vbrk-vkorg.
        lw_cancelled_invoices-fkdat = lw_vbrk-fkdat.
        lw_cancelled_invoices-kunag = lw_vbrk-kunag.
        lw_cancelled_invoices-fksto = lw_vbrk-fksto.
      ENDIF.

      READ TABLE li_vbfa INTO lw_vbfa
                         WITH KEY vbeln = lw_vbrk-vbeln
                         BINARY SEARCH.
      IF sy-subrc = 0.
        lw_cancelled_invoices-vbeln_va = lw_vbfa-vbelv.
      ENDIF.

      READ TABLE li_kna1 INTO lw_kna1
                         WITH KEY kunnr = lw_vbrk-kunag
                         BINARY SEARCH.
      IF sy-subrc = 0.
        lw_cancelled_invoices-name1 = lw_kna1-name1.
      ENDIF.

      APPEND lw_cancelled_invoices TO li_cancelled_invoices.
      CLEAR lw_cancelled_invoices.

    ENDLOOP.

    LOOP AT li_cancelled_invoices INTO lw_cancelled_invoices.
      MOVE-CORRESPONDING lw_cancelled_invoices TO w_reverse_orders.
      w_reverse_orders-icon = icon_light_out.
      APPEND w_reverse_orders TO li_reverse_orders_temp.
      CLEAR w_reverse_orders.
    ENDLOOP.

  ENDMETHOD.

  METHOD get_historical_data.
    " Obtener datos históricos de la tabla ZTTSD_REVTA_CANC

    TYPES:
      BEGIN OF lty_revta_canc,
        edoc_guid    TYPE ztasd_revta_canc-edoc_guid,
        vbeln_vf     TYPE ztasd_revta_canc-vbeln_vf,
        status_sat   TYPE ztasd_revta_canc-status_sat,
        vkorg        TYPE ztasd_revta_canc-vkorg,
        kunag        TYPE ztasd_revta_canc-kunag,
        name1        TYPE ztasd_revta_canc-name1,
        fkart        TYPE ztasd_revta_canc-fkart,
        fkdat        TYPE ztasd_revta_canc-fkdat,
        vbeln_va     TYPE ztasd_revta_canc-vbeln_va,
        invoice_canc TYPE ztasd_revta_canc-invoice_canc,
        cancelled    TYPE ztasd_revta_canc-cancelled,
        message      TYPE ztasd_revta_canc-message,
      END OF lty_revta_canc.

    DATA:
      lw_revta_canc     TYPE lty_revta_canc,
      lw_reverse_orders TYPE ty_reverse_orders.

    DATA:
      li_revta_canc TYPE TABLE OF lty_revta_canc.

    " Consultar tabla Z con filtros de selección
    SELECT edoc_guid
           vbeln_vf
           status_sat
           vkorg
           kunag
           name1
           fkart
           fkdat
           vbeln_va
           invoice_canc
           cancelled
           message
      FROM ztasd_revta_canc
      INTO TABLE li_revta_canc
      WHERE vbeln_vf IN s_vbeln
        AND vkorg IN s_vkorg
        AND kunag IN s_kunag
        AND fkdat IN s_fkdat.                           "#EC CI_NOFIRST
    IF sy-subrc = 0.

      " Convertir formato de tabla Z a estructura de retorno
      LOOP AT li_revta_canc INTO lw_revta_canc.

        lw_reverse_orders-edoc_guid    = lw_revta_canc-edoc_guid.
        lw_reverse_orders-vbeln_vf     = lw_revta_canc-vbeln_vf.
        lw_reverse_orders-status_sat   = lw_revta_canc-status_sat.
        lw_reverse_orders-vkorg        = lw_revta_canc-vkorg.
        lw_reverse_orders-kunag        = lw_revta_canc-kunag.
        lw_reverse_orders-name1        = lw_revta_canc-name1.
        lw_reverse_orders-fkart        = lw_revta_canc-fkart.
        lw_reverse_orders-fkdat        = lw_revta_canc-fkdat.
        lw_reverse_orders-vbeln_va     = lw_revta_canc-vbeln_va.
        lw_reverse_orders-invoice_canc = lw_revta_canc-invoice_canc.
        lw_reverse_orders-cancelled    = lw_revta_canc-cancelled.
        lw_reverse_orders-message      = lw_revta_canc-message.

        IF lw_reverse_orders-cancelled IS NOT INITIAL.
          lw_reverse_orders-icon = icon_green_light.
        ELSE.
          lw_reverse_orders-icon = icon_red_light.
        ENDIF.

        APPEND lw_reverse_orders TO li_reverse_orders_temp.
        CLEAR lw_reverse_orders.

      ENDLOOP.

    ENDIF.

  ENDMETHOD.

  METHOD merge_data_sources.
    " Combinar datos actuales e históricos eliminando duplicados

    SORT li_reverse_orders_temp BY edoc_guid vbeln_vf.
    DELETE ADJACENT DUPLICATES FROM li_reverse_orders_temp COMPARING edoc_guid vbeln_vf.

    "Valida autorizaciones
    validate_authorizations(
      CHANGING
        iv_reverse_orders = li_reverse_orders_temp
    ).

  ENDMETHOD.

  METHOD validate_authorizations.

    " Validar autorización para organización de ventas
    LOOP AT iv_reverse_orders INTO w_reverse_orders.
      AUTHORITY-CHECK OBJECT 'V_VBRK_VKO'
                       ID 'VKORG' FIELD w_reverse_orders-vkorg
                       ID 'ACTVT' FIELD '02'.

      IF sy-subrc <> 0.
        DELETE iv_reverse_orders INDEX sy-tabix.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD execute_reverse.

    " Inicializar resultado
    rv_success = abap_false.

    TRY.
        " Estructura de control de flujo optimizada - Patrón Early Return
        " Cada paso solo se ejecuta si el anterior fue exitoso

        " Paso 1: Anular compensación
        IF reset_cleared_items( iv_invoice = iv_reverse_orders-vbeln_vf ) = abap_false.
          iv_reverse_orders-message = TEXT-010. "Error en anulación de compensación
          iv_reverse_orders-icon = icon_red_light.
          RETURN.
        ENDIF.

        " Paso 2: Cancelar factura SD
        IF cancel_billing_document( EXPORTING
                                      iv_invoice = iv_reverse_orders-vbeln_vf
                                    IMPORTING
                                      ev_invoice_can = iv_reverse_orders-invoice_canc ) = abap_false.
          iv_reverse_orders-message = TEXT-002. "Error en cancelación de factura
          iv_reverse_orders-icon = icon_red_light.
          RETURN.
        ENDIF.

        " Paso 3: Reversar salida de mercancías
        IF reverse_goods_movement( iv_invoice = iv_reverse_orders-vbeln_vf ) = abap_false.
          iv_reverse_orders-message = TEXT-003. "Error en reversión de salida de mercancías
          iv_reverse_orders-icon = icon_red_light.
          RETURN.
        ENDIF.

        " Paso 4: Actualizar embarque
        IF change_shipment( iv_invoice = iv_reverse_orders-vbeln_vf ) = abap_false.
          iv_reverse_orders-message = TEXT-004. "Error en actualización de embarque
          iv_reverse_orders-icon = icon_red_light.
          RETURN.
        ENDIF.

        " Paso 5: Eliminar entrega
        IF change_outbound_delivery( iv_invoice = iv_reverse_orders-vbeln_vf ) = abap_false.
          iv_reverse_orders-message = TEXT-005. "Error en eliminación de entrega
          iv_reverse_orders-icon = icon_red_light.
          RETURN.
        ENDIF.

        " Paso 6: Rechazar pedido de venta
        IF change_sales_order( iv_salesorder = iv_reverse_orders-vbeln_va
                               iv_invoice = iv_reverse_orders-vbeln_vf ) = abap_false.
          iv_reverse_orders-message = TEXT-006. "Error en rechazo de pedido de venta
          iv_reverse_orders-icon = icon_red_light.
          RETURN.
        ENDIF.

        "Si llegamos aquí, todos los pasos fueron exitosos
        iv_reverse_orders-cancelled = abap_true.
        iv_reverse_orders-icon = icon_green_light.
        rv_success = abap_true.

      CATCH cx_sy_arithmetic_error
        cx_sy_conversion_error
        cx_sy_assign_cast_illegal_cast
        cx_sy_assign_cast_unknown_type
        cx_sy_move_cast_error INTO DATA(lo_exception) ##NEEDED.

        rv_success = abap_false.

    ENDTRY.


  ENDMETHOD.

  METHOD reset_cleared_items.
    " Anular Compensación

    TYPES:
      BEGIN OF lty_vbrk,
        vbeln TYPE vbrk-vbeln,
        gjahr TYPE vbrk-gjahr,
        bukrs TYPE vbrk-bukrs,
      END OF lty_vbrk.

    DATA:
      lw_vbrk TYPE lty_vbrk.

    DATA:
      lv_augbl TYPE bsad-augbl,
      lv_bukrs TYPE vbrk-bukrs,
      lv_gjahr TYPE bsad-gjahr.

    " Verificar si factura está compensada
    SELECT vbeln gjahr bukrs
      UP TO 1 ROWS
      FROM vbrk
      INTO lw_vbrk
      WHERE vbeln = iv_invoice.
    ENDSELECT.
    IF sy-subrc = 0.
      " Verificamos bloqueo de la factura
      IF check_lock_vbrk( iv_vbeln = lw_vbrk-vbeln ) = abap_false.
        rv_success = abap_false.
        RETURN.
      ENDIF.

      lv_augbl = get_clearing_document(
                      iv_invoice = lw_vbrk-vbeln
                      iv_bukrs = lw_vbrk-bukrs
                      iv_gjahr = lw_vbrk-gjahr ).

      IF lv_augbl IS NOT INITIAL.

        " Ejecutar anulación de compensación
        CALL FUNCTION 'POSTING_INTERFACE_START'
          EXPORTING
            i_client   = sy-mandt
            i_function = 'C'
            i_mode     = 'N'
            i_update   = 'S'.

        CALL FUNCTION 'POSTING_INTERFACE_RESET_CLEAR'
          EXPORTING
            i_augbl = lv_augbl
            i_bukrs = lv_bukrs
            i_gjahr = lv_gjahr
            i_tcode = 'FBRA'.

        COMMIT WORK.

        rv_success = abap_true.
      ELSE.
        rv_success = abap_true.
      ENDIF.
    ENDIF.

  ENDMETHOD.

  METHOD get_clearing_document.

    " Obtiene documento de compensación
    SELECT augbl
      UP TO 1 ROWS
      FROM bsad
      INTO rv_augbl
      WHERE bukrs = iv_bukrs
        AND gjahr = iv_gjahr
        AND zuonr = iv_invoice ##WARN_OK.
    ENDSELECT.
    IF sy-subrc = 0.
      CLEAR rv_augbl.
    ENDIF.

  ENDMETHOD.

  METHOD cancel_billing_document.
    " Cancelación de Factura SD

    DATA:
      lw_document_data_in TYPE bapikomfk,
      lw_returnlog_out    TYPE bapireturn1.

    DATA:
      li_document_data_in TYPE TABLE OF bapikomfk,
      li_returnlog_out    TYPE TABLE OF bapireturn1.

    DATA:
      lv_message  TYPE char255,
      lv_messages TYPE char255.

    CLEAR ev_invoice_can.

    " Verificar si la factura ya está cancelada manualmente
    SELECT fksto
      UP TO 1 ROWS
      FROM vbrk
      INTO @DATA(lv_fksto)
      WHERE vbeln = @iv_invoice.
    ENDSELECT.
    IF sy-subrc = 0.
      " Verificamos bloqueo de la factura
      IF check_lock_vbrk( iv_vbeln = iv_invoice ) = abap_false.
        rv_success = abap_false.
        RETURN.
      ENDIF.
    ENDIF.

    IF lv_fksto = c_fksto_x.
      " Consulta documento de anulación
      SELECT vbeln
        UP TO 1 ROWS
        FROM vbrk
        INTO @DATA(lv_invoice_can)                      "#EC CI_NOFIELD
        WHERE sfakn = @iv_invoice.
      ENDSELECT.
      IF sy-subrc = 0.
        ev_invoice_can = lv_invoice_can.
      ENDIF.

      " Ya está cancelada, continuar con siguiente paso
      rv_success = abap_true.
      RETURN.
    ENDIF.

    lw_document_data_in-sd_doc = iv_invoice.     " Número de factura a cancelar
    APPEND lw_document_data_in TO li_document_data_in.

    " Cancelar factura usando BAPI
    CALL FUNCTION 'BAPI_BILLINGDOC_CANCEL'
      TABLES
        document_data_in = li_document_data_in
        returnlog_out    = li_returnlog_out.

    " Procesar resultados de la BAPI
    READ TABLE li_returnlog_out INTO lw_returnlog_out
                                WITH KEY type = 'E'.
    "No es necesario binary search se tratan de pocos registros
    IF sy-subrc <> 0.

      ev_invoice_can = sy-msgv1.
      " Commit
      CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
        EXPORTING
          wait = abap_true.

      rv_success = abap_true.

    ELSE.

      LOOP AT li_returnlog_out INTO lw_returnlog_out.
        MESSAGE ID lw_returnlog_out-id TYPE lw_returnlog_out-type
                                       NUMBER lw_returnlog_out-number
                                         WITH lw_returnlog_out-message_v1
                                              lw_returnlog_out-message_v2
                                              lw_returnlog_out-message_v3
                                              lw_returnlog_out-message_v4 INTO lv_message.

        lv_messages = |{ lv_message } / { lv_messages }|.
      ENDLOOP.

      " Log del proceso
      generate_process_log(
        iv_process = 'CANCELAR_FACTURA'
        iv_document = iv_invoice
        iv_status = 'ERROR'
        iv_message = lv_messages
      ).

    ENDIF.

  ENDMETHOD.

  METHOD reverse_goods_movement.
    " Reversa de Salida de Mercancías

    DATA:
      li_mesg TYPE TABLE OF mesg.

    DATA:
      lv_delivery         TYPE vbfa-vbelv ##NEEDED,
      lv_materialdocument TYPE mblnr ##NEEDED,
      lv_matdocumentyear  TYPE mjahr ##NEEDED,
      lv_matdoc_can       TYPE mblnr ##NEEDED,
      lv_matdocyear_can   TYPE mjahr ##NEEDED.

    " Obtener el número de Entrega desde el Flujo de Documentos (VBFA)
    SELECT vbelv
      UP TO 1 ROWS
      FROM vbfa
      INTO lv_delivery
      WHERE vbeln   = iv_invoice                   " Tu variable de entrada (Factura)
        AND vbtyp_n = 'M'                          " Tipo: Factura
        AND vbtyp_v = 'J'. "#EC CI_NOFIRST         " Tipo precedente: Entrega
    ENDSELECT.
    IF sy-subrc <> 0.
      rv_success = abap_true.
      RETURN.
    ENDIF.

    IF lv_delivery IS NOT INITIAL.
      " Verificamos bloqueo de la entrega
      IF check_lock_likp( iv_vbeln = lv_delivery ) = abap_false.
        rv_success = abap_false.
        RETURN.
      ENDIF.

      " Obtener el Documento de Material (MSEG) usando la Entrega
      SELECT mblnr mjahr
          UP TO 1 ROWS
          FROM mseg
          INTO (lv_materialdocument, lv_matdocumentyear)
          WHERE vbeln_im = lv_delivery. "#EC CI_NOFIELD. " Campo clave del índice M
      ENDSELECT.
      IF sy-subrc = 0.
        " Consulta si el documento se encuentra cancelado
        SELECT sjahr smbln
           UP TO 1 ROWS
            FROM mseg
            INTO (lv_matdocyear_can, lv_matdoc_can )
            WHERE sjahr = lv_matdocumentyear
              AND smbln = lv_materialdocument. "#EC CI_NOFIELD. " Campo clave del índice M
        ENDSELECT.
        IF sy-subrc = 0. "Si el documento esta cancelado termina el proceso
          rv_success = abap_true.
          RETURN.
        ENDIF.
      ELSE.
        " Si no encuentra entrega asignada termina el proceso
        rv_success = abap_false.
        RETURN.
      ENDIF.
    ENDIF.

    " Reversar movimiento de mercancías (Transaction VL09)
    CALL FUNCTION 'WS_REVERSE_GOODS_ISSUE'
      EXPORTING
        i_vbeln                   = lv_delivery
        i_budat                   = sy-datum
        i_tcode                   = 'VL09'
        i_vbtyp                   = 'J'
      TABLES
        t_mesg                    = li_mesg
      EXCEPTIONS
        error_reverse_goods_issue = 1
        OTHERS                    = 2.

    IF sy-subrc = 0.
      CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
        EXPORTING
          wait = 'X'.
    ENDIF.

    IF li_mesg[] IS NOT INITIAL.

      " Log del proceso
      generate_process_log(
        iv_process = 'REVERSA_SALIDA_MERCANCIA'
        iv_document = iv_invoice
        iv_status = 'ERROR'
        iv_message = |{ TEXT-003 } { lv_materialdocument }| "Error al reversar salida de mercancía
      ).

      rv_success = abap_false.
    ELSE.
      " Commit
      CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
        EXPORTING
          wait = abap_true.

      rv_success = abap_true.
    ENDIF.

  ENDMETHOD.

  METHOD change_shipment.
    "Actualización de Embarque

    DATA:
      lw_headerdata       TYPE bapishipmentheader,
      lw_headerdataaction TYPE bapishipmentheaderaction,
      lw_itemdata         TYPE bapishipmentitem,
      lw_itemdataaction   TYPE bapishipmentitemaction,
      lw_return           TYPE bapiret2 ##NEEDED.

    DATA:
      li_itemdata       TYPE TABLE OF bapishipmentitem,
      li_itemdataaction TYPE TABLE OF bapishipmentitemaction,
      li_return         TYPE TABLE OF bapiret2.

    DATA:
      lv_shipment TYPE vttk-tknum,
      lv_delivery TYPE likp-vbeln,
      lv_message  TYPE char255,
      lv_messages TYPE char255.

    " Obtener la Entrega desde el Flujo (VBFA)
    SELECT vbelv
      UP TO 1 ROWS
      FROM vbfa
      INTO lv_delivery
      WHERE vbeln   = iv_invoice
        AND vbtyp_n = 'M'                   " Factura
        AND vbtyp_v = 'J'.                   "#EC CI_NOFIRST  " Entrega
    ENDSELECT.
    IF sy-subrc = 0.
      " Obtener el Transporte (VTTP)
      SELECT tknum
        UP TO 1 ROWS
        FROM vttp
        INTO lv_shipment
        WHERE vbeln = lv_delivery.
      ENDSELECT.
    ENDIF.
    " Si no encuentra entrega asignada termina el proceso
    IF lv_delivery IS INITIAL OR lv_shipment IS INITIAL.
      rv_success = abap_true. " No hay embarque asociado
      RETURN.
    ENDIF.

    " Verificamos bloqueo de Transporte
    IF check_lock_vttk( iv_tknum = lv_shipment ) = abap_false.
      rv_success = abap_false.
      RETURN.
    ENDIF.

    " Preparar datos para BAPI
    lw_headerdata-shipment_num = lv_shipment.

    lw_itemdata-shipment_num = lv_shipment.
    lw_itemdata-delivery = lv_delivery.
    APPEND lw_itemdata TO li_itemdata.

    lw_itemdataaction-delivery = 'D'. " Delete
    APPEND lw_itemdataaction TO li_itemdataaction.

    " Ejecutar BAPI de cambio de embarque
    CALL FUNCTION 'BAPI_SHIPMENT_CHANGE'
      EXPORTING
        headerdata       = lw_headerdata
        headerdataaction = lw_headerdataaction
      TABLES
        itemdata         = li_itemdata
        itemdataaction   = li_itemdataaction
        return           = li_return.

    " Procesar resultados de la BAPI
    READ TABLE li_return INTO lw_return
                         WITH KEY type = 'E'.
    "No es necesario binary search se tratan de pocos registros
    IF sy-subrc <> 0.

      CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
        EXPORTING
          wait = abap_true.

      rv_success = abap_true.

    ELSE.

      LOOP AT li_return INTO lw_return.
        MESSAGE ID lw_return-id TYPE lw_return-type
                                NUMBER lw_return-number
                                WITH lw_return-message_v1
                                     lw_return-message_v2
                                     lw_return-message_v3
                                     lw_return-message_v4 INTO lv_message.

        lv_messages = |{ lv_message } / { lv_messages }|.
      ENDLOOP.

      generate_process_log(
        iv_process = 'ACTUALIZACIÓN DE EMBARQUE'
        iv_document = iv_invoice
        iv_status = 'ERROR'
        iv_message = lv_messages
      ).

      rv_success = abap_false.
    ENDIF.

  ENDMETHOD.

  METHOD change_outbound_delivery.
    " Eliminar Entrega

    DATA:
      lw_vbkok_wa  TYPE vbkok,
      lw_vbpok_tab TYPE vbpok.

    DATA:
      li_vbpok_tab TYPE TABLE OF vbpok.

    DATA:
      lv_delivery  TYPE likp-vbeln.


    " Obtener entrega asociada
    SELECT vbelv
      UP TO 1 ROWS
      FROM vbfa
      INTO lv_delivery
      WHERE vbeln = iv_invoice                          "#EC CI_NOFIRST
        AND vbtyp_n = 'M'
        AND vbtyp_v = 'J' ##WARN_OK.
    ENDSELECT.
    IF sy-subrc <> 0.
      rv_success = abap_true.
      RETURN.
    ENDIF.

    " Verificamos bloqueo de la entrega
    IF check_lock_likp( iv_vbeln = lv_delivery ) = abap_false.
      rv_success = abap_false.
      RETURN.
    ENDIF.

    " Preparar parámetros para eliminación
    lw_vbkok_wa-vbeln_vl = lv_delivery.
    lw_vbkok_wa-likp_del = abap_true.

    lw_vbpok_tab-vbeln_vl = lv_delivery.
    lw_vbpok_tab-lips_del = abap_true.
    APPEND lw_vbpok_tab TO li_vbpok_tab.

    " Eliminar entrega
    CALL FUNCTION 'WS_DELIVERY_UPDATE'
      EXPORTING
        vbkok_wa      = lw_vbkok_wa
        delivery      = lv_delivery
      TABLES
        vbpok_tab     = li_vbpok_tab
      EXCEPTIONS
        error_message = 1
        OTHERS        = 2.

    IF sy-subrc = 0.
      COMMIT WORK.
      rv_success = abap_true.
    ELSE.

      generate_process_log(
          iv_process = 'ELIMINAR_ENTREGA'
          iv_document = iv_invoice
          iv_status = 'ERROR'
          iv_message = |{ TEXT-005 } { lv_delivery }| "Error al eliminar la entrega
        ).

      rv_success = abap_false.
    ENDIF.

  ENDMETHOD.

  METHOD change_sales_order.
    " Rechazar Pedido de Venta

    DATA:
      lw_order_header_in  TYPE bapisdh1,
      lw_order_header_inx TYPE bapisdh1x,
      lw_order_item_in    TYPE bapisditm,
      lw_order_item_inx   TYPE bapisditmx,
      lw_return           TYPE bapiret2 ##NEEDED.

    DATA:
      li_order_items_in  TYPE TABLE OF bapisditm,
      li_order_items_inx TYPE TABLE OF bapisditmx,
      li_return          TYPE TABLE OF bapiret2.

    DATA:
      lv_salesorder TYPE vbak-vbeln,
      lv_abgru      TYPE tvarv-low,
      lv_message    TYPE char255,
      lv_messages   TYPE char255.

    " Obtener razón de rechazo de TVARV
    SELECT low
      UP TO 1 ROWS
      FROM tvarv
      INTO lv_abgru
      WHERE name = 'ZSD_EXSD_REVTA-MOTIVO_RECHAZO'
        AND type = 'P'.
    ENDSELECT.
    IF sy-subrc <> 0.
      lv_abgru = c_abgru_b7. " Valor por defecto
    ENDIF.

    " Verificamos bloqueo del pedido
    IF check_lock_vbak( iv_vbeln = iv_salesorder ) = abap_false.
      rv_success = abap_false.
      RETURN.
    ENDIF.

    " Configurar motivo de rechazo
    lw_order_header_inx-updateflag = c_u.

    " Configurar items del pedido
    SELECT vbeln, posnr
      FROM vbap
      INTO TABLE @DATA(li_items)
      WHERE vbeln = @iv_salesorder.
    IF sy-subrc = 0.

      lv_salesorder = iv_salesorder.

      LOOP AT li_items INTO DATA(lw_items).
        lw_order_item_in-itm_number = lw_items-posnr.
        lw_order_item_in-reason_rej = lv_abgru.
        APPEND lw_order_item_in TO li_order_items_in.

        lw_order_item_inx-itm_number = lw_items-posnr.
        lw_order_item_inx-updateflag = c_u.
        lw_order_item_inx-reason_rej = c_x.
        APPEND lw_order_item_inx TO li_order_items_inx.
      ENDLOOP.
    ENDIF.

    " Actualiza pedido de venta
    CALL FUNCTION 'BAPI_SALESORDER_CHANGE'
      EXPORTING
        salesdocument    = lv_salesorder
        order_header_in  = lw_order_header_in
        order_header_inx = lw_order_header_inx
      TABLES
        return           = li_return
        order_item_in    = li_order_items_in
        order_item_inx   = li_order_items_inx.

    READ TABLE li_return INTO lw_return
                         WITH KEY type = 'E'.
    "No es necesario binary search se tratan de pocos registros
    IF sy-subrc = 0.
      rv_success = abap_false.

      LOOP AT li_return INTO lw_return.
        MESSAGE ID lw_return-id TYPE lw_return-type
                                NUMBER lw_return-number
                                WITH lw_return-message_v1
                                     lw_return-message_v2
                                     lw_return-message_v3
                                     lw_return-message_v4 INTO lv_message.

        lv_messages = |{ lv_message } / { lv_messages }|.
      ENDLOOP.

      generate_process_log(
          iv_process = 'RECHAZAR_PEDIDO_VENTA'
          iv_document = iv_invoice
          iv_status = 'ERROR'
          iv_message = lv_messages "|{ TEXT-006 } { lv_salesorder }| "Error al rechazar pedido de venta
        ).

    ELSE.
      CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
        EXPORTING
          wait = abap_true.
      rv_success = abap_true.
    ENDIF.

  ENDMETHOD.

  METHOD check_lock_vbrk.

    DATA:
      lv_cont TYPE i.

    IF iv_vbeln IS NOT INITIAL.
      WHILE lv_cont < 5.
        " Bloquea factura
        CALL FUNCTION 'ENQUEUE_EVVBRKE'
          EXPORTING
            mode_vbrk      = 'E'
            vbeln          = iv_vbeln
          EXCEPTIONS
            foreign_lock   = 1
            system_failure = 2
            OTHERS         = 3.
        IF sy-subrc = 0.
          " desbloquea factura
          CALL FUNCTION 'DEQUEUE_EVVBRKE'
            EXPORTING
              mode_vbrk = 'E'
              vbeln     = iv_vbeln.
          rv_locked = abap_true.
          EXIT.
        ELSE.
          WAIT UP TO 1 SECONDS.
          lv_cont = lv_cont + 1.
          rv_locked = abap_false.
        ENDIF.
      ENDWHILE.
    ENDIF.

  ENDMETHOD.

  METHOD check_lock_vbak.

    DATA:
      lv_cont TYPE i.

    IF iv_vbeln IS NOT INITIAL.
      WHILE lv_cont < 5.
        " Bloquea pedido
        CALL FUNCTION 'ENQUEUE_EVVBAKE'
          EXPORTING
            mode_vbak      = 'E'
            vbeln          = iv_vbeln
          EXCEPTIONS
            foreign_lock   = 1
            system_failure = 2
            OTHERS         = 3.
        IF sy-subrc = 0.
          " desbloquea pedido
          CALL FUNCTION 'DEQUEUE_EVVBAKE'
            EXPORTING
              mode_vbak = 'E'
              vbeln     = iv_vbeln.
          rv_locked = abap_true.
          EXIT.
        ELSE.
          WAIT UP TO 1 SECONDS.
          lv_cont = lv_cont + 1.
          rv_locked = abap_false.
        ENDIF.
      ENDWHILE.
    ENDIF.

  ENDMETHOD.

  METHOD check_lock_likp.

    DATA:
      lv_cont TYPE i.

    IF iv_vbeln IS NOT INITIAL.
      WHILE lv_cont < 5.
        " Bloquea entrega
        CALL FUNCTION 'ENQUEUE_EVVBLKE'
          EXPORTING
            mode_likp      = 'E'
            vbeln          = iv_vbeln
          EXCEPTIONS
            foreign_lock   = 1
            system_failure = 2
            OTHERS         = 3.
        IF sy-subrc = 0.
          " desbloquea entrega
          CALL FUNCTION 'DEQUEUE_EVVBLKE'
            EXPORTING
              mode_likp = 'E'
              vbeln     = iv_vbeln.
          rv_locked = abap_true.
          EXIT.
        ELSE.
          WAIT UP TO 1 SECONDS.
          lv_cont = lv_cont + 1.
          rv_locked = abap_false.
        ENDIF.
      ENDWHILE.
    ENDIF.

  ENDMETHOD.

  METHOD check_lock_vttk.

    DATA:
      lv_cont TYPE i.

    IF iv_tknum IS NOT INITIAL.
      WHILE lv_cont < 5.
        " Bloquea transporte
        CALL FUNCTION 'ENQUEUE_EVVTTKE'
          EXPORTING
            mode_vttk      = 'E'
            tknum          = iv_tknum
          EXCEPTIONS
            foreign_lock   = 1
            system_failure = 2
            OTHERS         = 3.
        IF sy-subrc = 0.
          " desbloquea trnsporte
          CALL FUNCTION 'DEQUEUE_EVVTTKE'
            EXPORTING
              mode_vttk = 'E'
              tknum     = iv_tknum.
          rv_locked = abap_true.
          EXIT.
        ELSE.
          WAIT UP TO 1 SECONDS.
          lv_cont = lv_cont + 1.
          rv_locked = abap_false.
        ENDIF.
      ENDWHILE.
    ENDIF.

  ENDMETHOD.

  METHOD generate_process_log.
    " Generar log de proceso en tabla Z

    DATA:
      li_revta_log TYPE TABLE OF ztasd_revta_log.

    w_log-document = iv_document.
    w_log-process  = iv_process.
    w_log-status   = iv_status.
    w_log-euser    = sy-uname.
    w_log-edate    = sy-datum.
    w_log-etime    = sy-uzeit.
    w_log-message  = iv_message.
    APPEND w_log TO i_log.
    CLEAR w_log.

    " Guardar en tabla Z si está activo el log
    IF i_log[] IS NOT INITIAL.
      MOVE-CORRESPONDING i_log TO li_revta_log.
      MODIFY ztasd_revta_log FROM TABLE li_revta_log.
      COMMIT WORK.
    ENDIF.

  ENDMETHOD.

ENDCLASS.

*-------------------------------------------------------------------------------*
* Clase para ALV                                                              *
*-------------------------------------------------------------------------------*
CLASS cl_alv_monitor_vc DEFINITION FINAL.

  PUBLIC SECTION.
    METHODS:
      constructor
        IMPORTING ir_data TYPE REF TO data,

      display_alv.

    METHODS:
      handle_hotspot_click
                  FOR EVENT hotspot_click OF cl_gui_alv_grid
        IMPORTING e_row_id e_column_id es_row_no ##NEEDED.

    METHODS:
      build_fieldcat
        RETURNING VALUE(rt_fieldcat) TYPE lvc_t_fcat,

      build_layout
        RETURNING VALUE(rs_layout) TYPE lvc_s_layo.

ENDCLASS.

CLASS cl_alv_monitor_vc IMPLEMENTATION.

  METHOD constructor.
    o_data = ir_data.
  ENDMETHOD.

  METHOD display_alv.
    " Implementación de ALV con funcionalidades específicas

    DATA:
      lw_layout TYPE lvc_s_layo.

    DATA:
      li_fieldcat TYPE lvc_t_fcat.

    FIELD-SYMBOLS:
      <lfs_data> TYPE STANDARD TABLE.


    " Construir fieldcat y layout
    li_fieldcat = build_fieldcat( ).
    lw_layout = build_layout( ).

    " Crear container si no existe
    IF o_container IS INITIAL.
      CREATE OBJECT o_container
        EXPORTING
          container_name = 'CONTAINER_ALV'.
    ENDIF.

    " Crear ALV Grid
    IF o_alv_grid IS INITIAL.
      CREATE OBJECT o_alv_grid
        EXPORTING
          i_parent = o_container.
    ENDIF.

    " Mostrar datos
    ASSIGN o_data->* TO <lfs_data>.

    " Registrar evento hotspot
    SET HANDLER me->handle_hotspot_click FOR o_alv_grid.

    TRY.
        CALL METHOD o_alv_grid->set_table_for_first_display
          EXPORTING
            is_layout       = lw_layout
          CHANGING
            it_outtab       = <lfs_data>
            it_fieldcatalog = li_fieldcat.

        " Llamar Dynpro que contiene el container
        CALL SCREEN 100.

      CATCH cx_root INTO DATA(lo_error) ##CATCH_ALL.
        DATA(lv_error) = lo_error->get_text(  ) ##NEEDED.

    ENDTRY.

  ENDMETHOD.

  METHOD build_fieldcat.
    " Construir catálogo de campos

    DATA:
      lw_fieldcat TYPE lvc_s_fcat.

    CLEAR: lw_fieldcat, rt_fieldcat[].

    " --- Columna del Semáforo (Icono) ---
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'ICON'.     " Nombre del campo en tu tabla interna
    lw_fieldcat-seltext   = 'Estado' ##NO_TEXT.   " Título de la columna
    lw_fieldcat-icon      = 'X'.        " Icono
    lw_fieldcat-key       = c_x.
    APPEND lw_fieldcat TO rt_fieldcat.

    " eDocument: GUID
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'EDOC_GUID'.
    lw_fieldcat-datatype = 'CHAR'.
    lw_fieldcat-outputlen = 32 ##NUMBER_OK.
    lw_fieldcat-coltext = 'EDOC_GUID' ##NO_TEXT.
    APPEND lw_fieldcat TO rt_fieldcat.

    " Número de Factura
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'VBELN_VF'.
    lw_fieldcat-datatype = 'CHAR'.
    lw_fieldcat-outputlen = 10 ##NUMBER_OK.
    lw_fieldcat-coltext = 'No. Factura' ##NO_TEXT.
    lw_fieldcat-key       = c_x.
    lw_fieldcat-hotspot   = c_x.
    APPEND lw_fieldcat TO rt_fieldcat.

    " Status SAT
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'STATUS_SAT'.
    lw_fieldcat-datatype = 'CHAR'.
    lw_fieldcat-outputlen = 20 ##NUMBER_OK.
    lw_fieldcat-coltext = 'Status SAT' ##NO_TEXT.
    APPEND lw_fieldcat TO rt_fieldcat.

    " Cliente
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'KUNAG'.
    lw_fieldcat-datatype = 'CHAR'.
    lw_fieldcat-outputlen = 10 ##NUMBER_OK.
    lw_fieldcat-coltext = 'Cliente' ##NO_TEXT.
    APPEND lw_fieldcat TO rt_fieldcat.

    " Nombre Cliente
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'NAME1'.
    lw_fieldcat-datatype = 'CHAR'.
    lw_fieldcat-outputlen = 35 ##NUMBER_OK.
    lw_fieldcat-coltext = 'Nombre Cliente' ##NO_TEXT.
    APPEND lw_fieldcat TO rt_fieldcat.

    " Tipo Factura
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'FKART'.
    lw_fieldcat-datatype = 'CHAR'.
    lw_fieldcat-outputlen = 4 ##NUMBER_OK.
    lw_fieldcat-coltext = 'Tipo Fact.' ##NO_TEXT.
    APPEND lw_fieldcat TO rt_fieldcat.

    " Pedido
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'VBELN_VA'.
    lw_fieldcat-datatype = 'CHAR'.
    lw_fieldcat-outputlen = 10 ##NUMBER_OK.
    lw_fieldcat-coltext = 'Pedido Venta' ##NO_TEXT.
    lw_fieldcat-hotspot   = c_x.
    APPEND lw_fieldcat TO rt_fieldcat.

    " Factura cancelada
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'INVOICE_CANC'.
    lw_fieldcat-datatype = 'CHAR'.
    lw_fieldcat-outputlen = 10 ##NUMBER_OK.
    lw_fieldcat-coltext = 'Fact. Anulada' ##NO_TEXT.
    APPEND lw_fieldcat TO rt_fieldcat.

    " Cancelado
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'CANCELLED'.
    lw_fieldcat-datatype = 'CHAR'.
    lw_fieldcat-outputlen = 1 ##NUMBER_OK.
    lw_fieldcat-coltext = 'Cancelado' ##NO_TEXT.
    APPEND lw_fieldcat TO rt_fieldcat.

    " Campo Mensaje
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'MESSAGE'.
    lw_fieldcat-datatype = 'CHAR'.
    lw_fieldcat-outputlen = 50 ##NUMBER_OK.
    lw_fieldcat-coltext = 'Mensaje' ##NO_TEXT.
    APPEND lw_fieldcat TO rt_fieldcat.

  ENDMETHOD.

  METHOD build_layout.

    " Configurar layout del ALV
    rs_layout-zebra = c_x.          " Líneas alternadas
    rs_layout-sel_mode = c_a.       " Selección múltiple

  ENDMETHOD.

  METHOD handle_hotspot_click.
    " Manejo del evento hotspot para navegar a las transacciones

    DATA:
      ls_line TYPE ty_reverse_orders.

    FIELD-SYMBOLS:
      <lt_data> TYPE STANDARD TABLE.

    ASSIGN o_data->* TO <lt_data>.

    " Leer la línea seleccionada
    READ TABLE <lt_data> INTO ls_line INDEX e_row_id-index.
    IF sy-subrc = 0.
      CASE e_column_id-fieldname.
        WHEN 'VBELN_VF'.
          " Navegar a la transacción VF03 (Factura)
          IF ls_line-vbeln_vf IS NOT INITIAL.
            SET PARAMETER ID 'VF' FIELD ls_line-vbeln_vf.
            CALL TRANSACTION 'VF03' AND SKIP FIRST SCREEN. "#EC CI_CALLTA
          ENDIF.

        WHEN 'VBELN_VA'.
          " Navegar a la transacción VA03 (Pedido)
          IF ls_line-vbeln_va IS NOT INITIAL.
            SET PARAMETER ID 'AUN' FIELD ls_line-vbeln_va.
            CALL TRANSACTION 'VA03' AND SKIP FIRST SCREEN. "#EC CI_CALLTA
          ENDIF.

      ENDCASE.
    ENDIF.

  ENDMETHOD.

ENDCLASS.

*-------------------------------------------------------------------------------*
* FORM f_main_process                                                           *
*-------------------------------------------------------------------------------*
FORM f_main_process.
  " Proceso principal del programa

  DATA: lo_monitor TYPE REF TO cl_sd_reversa_cfiscal.

  " Crear instancia de la clase principal
  CREATE OBJECT lo_monitor.

  " Obtener pedidos con entregas parciales
  i_reverse_orders = lo_monitor->get_cancelled_invoices( ).

ENDFORM.

*-------------------------------------------------------------------------------*
* FORM f_display_alv                                                            *
*-------------------------------------------------------------------------------*
FORM f_display_alv.
  " Mostrar datos en formato ALV

  DATA:
    lo_alv_monitor_vc TYPE REF TO cl_alv_monitor_vc,
    lo_data           TYPE REF TO data.

  " Crear referencia a los datos
  GET REFERENCE OF i_reverse_orders INTO lo_data.

  " Crear instancia de ALV
  CREATE OBJECT lo_alv_monitor_vc
    EXPORTING
      ir_data = lo_data.

  " Configurar fieldcat
  lo_alv_monitor_vc->display_alv(  ).

ENDFORM.

*-------------------------------------------------------------------------------*
* FORM f_revserse                                                               *
*-------------------------------------------------------------------------------*
FORM f_reverse.
  " Procesar rechazo de parcialidad

  DATA:
    lw_row        TYPE lvc_s_row,
    lw_revta_canc TYPE ztasd_revta_canc.

  DATA:
    li_rows       TYPE lvc_t_row,
    li_revta_canc TYPE TABLE OF ztasd_revta_canc.

  DATA:
    lr_vbeln TYPE RANGE OF vbrk-vbeln.

  DATA:
    lv_success       TYPE abap_bool,
    lv_error_count   TYPE i,
    lv_success_count TYPE i,
    lv_jobcount      TYPE tbtcjob-jobcount,
    lv_jobname       TYPE tbtcjob-jobname,
    lv_index         TYPE sy-tabix.

  DATA:
    lo_monitor TYPE REF TO cl_sd_reversa_cfiscal.


  " Crear instancia de la clase de procesamiento
  CREATE OBJECT lo_monitor.

  "Obtiene lineas seleccionadas
  CALL METHOD o_alv_grid->get_selected_rows
    IMPORTING
      et_index_rows = li_rows.


  " Configuración inicial de visualización
  v_icon_name = icon_message_question.
  v_text_line1 = TEXT-007.
  v_text_line2 = TEXT-008.
  v_text_line3 = TEXT-009.

  " Confirmar acción
  " Llamada al Popup Contenedor (Dynpro 0200)
  " Nota: La Dynpro 0200 contendrá el área para incrustar la screen 0210
  CALL SCREEN 200 STARTING AT 20 10
                  ENDING   AT 100 15.

  " Procesamiento de la respuesta
  IF v_okcode = 'CONTINUE'.
    IF p_sbatch = c_x.

      " Construir rango de documentos seleccionados
      LOOP AT li_rows INTO lw_row.
        READ TABLE i_reverse_orders INTO w_reverse_orders
                                    INDEX lw_row-index.
        "No es necesario binary search se tratan de pocos registros
        IF sy-subrc = 0.
          APPEND VALUE #( sign = c_i option = c_eq low = w_reverse_orders-vbeln_vf ) TO lr_vbeln.
        ENDIF.
      ENDLOOP.

      " --- Crear JOB de Fondo ---
      lv_jobname = |ZRE_REVTA_CANC{ sy-datum }_{ sy-uzeit }|.

      CALL FUNCTION 'JOB_OPEN'
        EXPORTING
          jobname          = lv_jobname
        IMPORTING
          jobcount         = lv_jobcount
        EXCEPTIONS
          cant_create_job  = 1
          invalid_job_data = 2
          jobname_missing  = 3
          OTHERS           = 4.

      IF sy-subrc <> 0.
        MESSAGE s908(fb) WITH TEXT-016. "Error al crear Job de fondo
        RETURN.
      ENDIF.

      " Submit del reporte con los filtros seleccionados y flag de ejecución
      SUBMIT zre_csdsls_reversa_venta_cnc
        WITH s_vbeln IN lr_vbeln
        WITH p_batch  = abap_true  " Activar modo ejecución
        VIA JOB lv_jobname NUMBER lv_jobcount
        AND RETURN.                                      "#EC CI_SUBMIT

      CALL FUNCTION 'JOB_CLOSE'
        EXPORTING
          jobcount             = lv_jobcount
          jobname              = lv_jobname
          strtimmed            = 'X' " Ejecución inmediata
        EXCEPTIONS
          cant_start_immediate = 1
          invalid_startdate    = 2
          jobname_missing      = 3
          job_close_failed     = 4
          job_nosteps          = 5
          job_notex            = 6
          lock_failed          = 7
          OTHERS               = 8.

      IF sy-subrc = 0.
        MESSAGE i911(fb) WITH TEXT-017 lv_jobname. "Proceso iniciado en fondo. Job:
      ELSE.
        MESSAGE s908(fb) WITH TEXT-018. "Error al cerrar/iniciar Job
      ENDIF.

    ELSE.

      " Procesar líneas seleccionadas
      LOOP AT li_rows INTO lw_row.

        READ TABLE i_reverse_orders INTO w_reverse_orders
                                    INDEX lw_row-index.
        "No es necesario binary search se tratan de pocos registros
        IF sy-subrc = 0.

          lv_index = sy-tabix.

          "Guarda información al inicio del proceso
          MOVE-CORRESPONDING w_reverse_orders TO lw_revta_canc.
          MODIFY ztasd_revta_canc FROM lw_revta_canc.
          COMMIT WORK AND WAIT.

          " Llamar método de rechazo
          lv_success = lo_monitor->execute_reverse(
                          CHANGING
                            iv_reverse_orders = w_reverse_orders
          ).

          " Actualizar status en tabla interna
          MODIFY i_reverse_orders FROM w_reverse_orders INDEX lv_index.
          MOVE-CORRESPONDING w_reverse_orders TO lw_revta_canc.
          APPEND lw_revta_canc TO li_revta_canc.
          CLEAR lw_revta_canc.

        ENDIF.

        IF lv_success = abap_true.
          lv_success_count = lv_success_count + 1.
        ELSE.
          lv_error_count = lv_error_count + 1.
        ENDIF.

      ENDLOOP.
      " Revisa que la tabla no est vacia para hacer la actualización
      IF li_revta_canc[] IS NOT INITIAL.
        MODIFY ztasd_revta_canc FROM TABLE li_revta_canc.
        COMMIT WORK AND WAIT.
      ENDIF.

    ENDIF.

  ENDIF.

  "Forzar la actualización del Grid
  CALL METHOD o_alv_grid->refresh_table_display.

ENDFORM.

*-------------------------------------------------------------------------------*
* FORM SHOW_ERROR_LOG                                                           *
*-------------------------------------------------------------------------------*
FORM f_show_error_log.
  " Mostrar log de errores en ventana emergente

  TYPES:
    BEGIN OF lty_row_select,
      vbeln_vf TYPE vbrk-vbeln,
    END OF lty_row_select.

  DATA:
    lw_row_select TYPE lty_row_select,
    lw_row        TYPE lvc_s_row,
    lw_fieldcat   TYPE slis_fieldcat_alv.

  DATA:
    li_row_select TYPE TABLE OF lty_row_select,
    li_rows       TYPE lvc_t_row,
    li_fieldcat   TYPE slis_t_fieldcat_alv.

  DATA:
    lv_lines TYPE i.

  "Obtiene lineas seleccionadas
  CALL METHOD o_alv_grid->get_selected_rows
    IMPORTING
      et_index_rows = li_rows.

  " Procesar líneas seleccionadas
  LOOP AT li_rows INTO lw_row.

    READ TABLE i_reverse_orders INTO w_reverse_orders
                                INDEX lw_row-index.
    "No es necesario binary search se tratan de pocos registros
    IF sy-subrc = 0.
      lw_row_select-vbeln_vf = w_reverse_orders-vbeln_vf.
      APPEND lw_row_select TO li_row_select.
    ENDIF.

  ENDLOOP.

  IF li_row_select[] IS NOT INITIAL.

    "Consulta log
    SELECT document process status euser edate etime message
      FROM ztasd_revta_log
      INTO CORRESPONDING FIELDS OF TABLE i_log
      FOR ALL ENTRIES IN li_row_select
      WHERE document = li_row_select-vbeln_vf ##TOO_MANY_ITAB_FIELDS.
    IF sy-subrc = 0.
      " Asignar colores dinámicamente según el status
      LOOP AT i_log ASSIGNING <fs_log>.
        CASE <fs_log>-status.
          WHEN 'ERROR'.
            <fs_log>-icon = icon_led_red.    " Semáforo rojo
          WHEN 'SUCCESS'.
            <fs_log>-icon = icon_led_green.  " Semáforo verde
          WHEN OTHERS.
            <fs_log>-icon = icon_led_yellow. " Semáforo amarillo
        ENDCASE.
      ENDLOOP.
    ENDIF.
  ENDIF.

  " Verificar si hay registros en el log
  DESCRIBE TABLE i_log LINES lv_lines.

  IF lv_lines = 0.
    MESSAGE s908(fb) WITH TEXT-011. "No hay registros en el log de procesos
    RETURN.
  ENDIF.

  CLEAR lw_fieldcat.
  lw_fieldcat-fieldname = 'ICON'.
  lw_fieldcat-seltext_l = ''.
  lw_fieldcat-seltext_m = ''.
  lw_fieldcat-seltext_s = ''.
  lw_fieldcat-col_pos   = 1.
  lw_fieldcat-outputlen = 3 ##NUMBER_OK.
  lw_fieldcat-icon      = 'X'.
  APPEND lw_fieldcat TO li_fieldcat.

  CLEAR lw_fieldcat.
  lw_fieldcat-fieldname = 'DOCUMENT'.
  lw_fieldcat-seltext_l = 'Documento' ##NO_TEXT.
  lw_fieldcat-seltext_m = 'Documento' ##NO_TEXT.
  lw_fieldcat-seltext_s = 'Doc' ##NO_TEXT.
  lw_fieldcat-col_pos   = 2.
  lw_fieldcat-outputlen = 10 ##NUMBER_OK.
  APPEND lw_fieldcat TO li_fieldcat.

  CLEAR lw_fieldcat.
  lw_fieldcat-fieldname = 'PROCESS'.
  lw_fieldcat-seltext_l = 'Proceso' ##NO_TEXT.
  lw_fieldcat-seltext_m = 'Proceso' ##NO_TEXT.
  lw_fieldcat-seltext_s = 'Proceso' ##NO_TEXT.
  lw_fieldcat-col_pos   = 3.
  lw_fieldcat-outputlen = 20 ##NUMBER_OK.
  APPEND lw_fieldcat TO li_fieldcat.

  CLEAR lw_fieldcat.
  lw_fieldcat-fieldname = 'STATUS'.
  lw_fieldcat-seltext_l = 'Estado' ##NO_TEXT.
  lw_fieldcat-seltext_m = 'Estado' ##NO_TEXT.
  lw_fieldcat-seltext_s = 'Estado' ##NO_TEXT.
  lw_fieldcat-col_pos   = 4.
  lw_fieldcat-outputlen = 10 ##NUMBER_OK.
  APPEND lw_fieldcat TO li_fieldcat.

  CLEAR lw_fieldcat.
  lw_fieldcat-fieldname = 'EUSER'.
  lw_fieldcat-seltext_l = 'Usuario' ##NO_TEXT.
  lw_fieldcat-seltext_m = 'Usuario' ##NO_TEXT.
  lw_fieldcat-seltext_s = 'Usuario' ##NO_TEXT.
  lw_fieldcat-col_pos   = 5.
  lw_fieldcat-outputlen = 12 ##NUMBER_OK.
  APPEND lw_fieldcat TO li_fieldcat.

  CLEAR lw_fieldcat.
  lw_fieldcat-fieldname = 'EDATE'.
  lw_fieldcat-seltext_l = 'Usuario' ##NO_TEXT.
  lw_fieldcat-seltext_m = 'Usuario' ##NO_TEXT.
  lw_fieldcat-seltext_s = 'Usuario' ##NO_TEXT.
  lw_fieldcat-col_pos   = 6.
  lw_fieldcat-outputlen = 10 ##NUMBER_OK.
  APPEND lw_fieldcat TO li_fieldcat.

  CLEAR lw_fieldcat.
  lw_fieldcat-fieldname = 'ETIME'.
  lw_fieldcat-seltext_l = 'Usuario' ##NO_TEXT.
  lw_fieldcat-seltext_m = 'Usuario' ##NO_TEXT.
  lw_fieldcat-seltext_s = 'Usuario' ##NO_TEXT.
  lw_fieldcat-col_pos   = 7.
  lw_fieldcat-outputlen = 10 ##NUMBER_OK.
  APPEND lw_fieldcat TO li_fieldcat.

  CLEAR lw_fieldcat.
  lw_fieldcat-fieldname = 'MESSAGE'.
  lw_fieldcat-seltext_l = 'Mensaje' ##NO_TEXT.
  lw_fieldcat-seltext_m = 'Mensaje' ##NO_TEXT.
  lw_fieldcat-seltext_s = 'Mensaje' ##NO_TEXT.
  lw_fieldcat-col_pos   = 8.
  lw_fieldcat-outputlen = 80 ##NUMBER_OK.
  APPEND lw_fieldcat TO li_fieldcat.

  " Mostrar popup con el log
  CALL FUNCTION 'REUSE_ALV_POPUP_TO_SELECT'
    EXPORTING
      i_title               = TEXT-013 "Log de Procesos
      i_zebra               = 'X'
      i_screen_start_column = 10
      i_screen_start_line   = 5
      i_screen_end_column   = 150 ##NUMBER_OK
      i_screen_end_line     = 25 ##NUMBER_OK
      i_tabname             = 'I_LOG'
      it_fieldcat           = li_fieldcat
    TABLES
      t_outtab              = i_log
    EXCEPTIONS
      program_error         = 1
      OTHERS                = 2.

  IF sy-subrc <> 0.
    MESSAGE s908(fb) WITH TEXT-012. "Error al mostrar log de procesos
  ENDIF.

ENDFORM.

*-------------------------------------------------------------------------------*
* FORM f_process_reverse_batch                                               *
*-------------------------------------------------------------------------------*
FORM f_process_reverse_batch.
  " Procesamiento masivo (Background)

  DATA:
    lw_revta_canc TYPE ztasd_revta_canc.

  DATA:
    li_revta_canc TYPE TABLE OF ztasd_revta_canc.

  DATA:
    lv_success TYPE abap_bool,
    lv_index   TYPE sy-tabix.

  DATA:
    lo_monitor TYPE REF TO cl_sd_reversa_cfiscal.

  CREATE OBJECT lo_monitor.

  "--- Inicio de Proceso de Existencia Ficticia (Batch) ---
  WRITE: / TEXT-019, sy-datum, sy-uzeit.
  SKIP.

  LOOP AT i_reverse_orders INTO w_reverse_orders.

    lv_index = sy-tabix.

    "Guarda información al inicio del proceso
    MOVE-CORRESPONDING w_reverse_orders TO lw_revta_canc.
    MODIFY ztasd_revta_canc FROM lw_revta_canc.
    COMMIT WORK AND WAIT.

    "Procesando Documento:
    WRITE: / TEXT-020, w_reverse_orders-vbeln_vf.

    lv_success = lo_monitor->execute_reverse(
                    CHANGING
                      iv_reverse_orders = w_reverse_orders
    ).

    " Actualizar status en tabla interna
    MODIFY i_reverse_orders FROM w_reverse_orders INDEX lv_index.
    MOVE-CORRESPONDING w_reverse_orders TO lw_revta_canc.
    APPEND lw_revta_canc TO li_revta_canc.
    CLEAR lw_revta_canc.

    IF lv_success = abap_true.
      WRITE: TEXT-021. " -> [OK] Procesado correctamente'
    ELSE.
      WRITE: TEXT-022. " -> [ERROR] Falló el procesamiento (Ver Log Z)
    ENDIF.

  ENDLOOP.

  " Revisa que la tabla no est vacia para hacer la actualización
  IF li_revta_canc[] IS NOT INITIAL.
    MODIFY ztasd_revta_canc FROM TABLE li_revta_canc.
    COMMIT WORK AND WAIT.
  ENDIF.

  SKIP.
  "--- Fin de Proceso ---
  WRITE: / TEXT-023, sy-datum, sy-uzeit.

ENDFORM.