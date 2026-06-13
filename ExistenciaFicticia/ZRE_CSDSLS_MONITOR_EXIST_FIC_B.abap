*-------------------------------------------------------------------------------*
*                   Fabrica de Software ABAP NEORIS                             *
*-------------------------------------------------------------------------------*
* Nombre del Programa : ZRE_CSDSLS_MONITOR_EXIST_FIC_B                          *
* Descripción         : Monitor de Existencia Ficticia para pedidos de venta    *
*                       con entregas parciales integrados con sistemas POS      *
* Funcional           : Dino Cordero                                            *
* Desarrollador       : Edgar Morales  - ABAP_01                                *
* Diseñador Técnico   : Edgar Morales                                           *
* Fecha de Creación   : 11.11.2025                                              *
* ID del Componente   : DF-EXSD44                                               *
* Número de Req.      : EXSD44                                                  *
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
* Clase principal para el procesamiento del monitor                             *
*-------------------------------------------------------------------------------*
CLASS cl_exsd_monitor_exist_fic DEFINITION FINAL.

  PUBLIC SECTION.

    METHODS:
      constructor,

      " Obtiene ordenes parciales
      get_parcial_salesorders
        RETURNING VALUE(rt_goods_assumtion) TYPE tt_goods_assumtion,

      " Valida autorizaciones
      validate_authorizations
        CHANGING iv_goods_assumtion TYPE tt_goods_assumtion,

      " Proceso de aceptación
      process_acceptance
        CHANGING  iv_parcial_orders TYPE ty_goods_assumtion
        RETURNING VALUE(rv_success) TYPE abap_bool,

      " Proceso de rechazo
      process_rejection
        CHANGING  iv_parcial_orders TYPE ty_goods_assumtion
        RETURNING VALUE(rv_success) TYPE abap_bool,

      " Revisar bloqueo de pedido
      check_lock_vbak
        IMPORTING iv_vbeln         TYPE vbak-vbeln
        RETURNING VALUE(rv_locked) TYPE abap_bool ##NEEDED,

      " Revisar bloqueo de entrega
      check_lock_likp
        IMPORTING iv_vbeln         TYPE likp-vbeln
        RETURNING VALUE(rv_locked) TYPE abap_bool ##NEEDED,

      " Revisar bloqueo de transporte
      check_lock_vttk
        IMPORTING iv_tknum         TYPE vttk-tknum
        RETURNING VALUE(rv_locked) TYPE abap_bool ##NEEDED,

      " Revisar bloqueo de factura
      check_lock_vbrk
        IMPORTING iv_vbeln         TYPE vbrk-vbeln
        RETURNING VALUE(rv_locked) TYPE abap_bool ##NEEDED,

      " Generar log de procesamiento
      generate_process_log
        IMPORTING iv_process  TYPE char30
                  iv_document TYPE vbeln_va
                  iv_status   TYPE char10
                  iv_message  TYPE char255.

  PRIVATE SECTION.

    TYPES:
      BEGIN OF lty_cash_orders,
        vbeln  TYPE vbak-vbeln,
        posnr  TYPE vbap-posnr,
        erdat  TYPE vbak-erdat,
        vkorg  TYPE vbak-vkorg,
        vtweg  TYPE vbak-vtweg,
        spart  TYPE vbak-spart,
        kunnr  TYPE vbak-kunnr,
        matnr  TYPE vbap-matnr,
        kwmeng TYPE vbap-kwmeng,
        meins  TYPE vbap-meins,
        werks  TYPE vbap-werks,
        zterm  TYPE vbkd-zterm,
      END OF lty_cash_orders,

      BEGIN OF lty_sales_docflow,
        vbelv     TYPE vbfa-vbelv,
        posnv     TYPE vbfa-posnv,
        vbeln     TYPE vbfa-vbeln,
        posnn     TYPE vbfa-posnn,
        vbtyp_n   TYPE vbfa-vbtyp_n,
        rfmng     TYPE vbfa-rfmng,
        rfmng_flo TYPE vbfa-rfmng_flo,
      END OF lty_sales_docflow,

      BEGIN OF lty_deliveries,
        vbeln TYPE likp-vbeln,
        posnr TYPE lips-posnr,
        erdat TYPE likp-erdat,
        vgbel TYPE lips-vgbel,
        vgpos TYPE lips-vgpos,
        matnr TYPE lips-matnr,
        lfimg TYPE lips-lfimg,
        meins TYPE lips-meins,
      END OF lty_deliveries,

      BEGIN OF lty_shipments,
        tknum TYPE vttp-tknum,
        tpnum TYPE vttp-tpnum,
      END OF lty_shipments,

      BEGIN OF lty_customers,
        kunnr TYPE kna1-kunnr,
        name1 TYPE kna1-name1,
      END OF lty_customers,

      BEGIN OF lty_products,
        matnr TYPE makt-matnr,
        maktx TYPE makt-maktx,
      END OF lty_products.

    DATA:
      li_goods_assumtion_temp TYPE TABLE OF ty_goods_assumtion,
      li_cash_orders          TYPE TABLE OF lty_cash_orders,
      li_sales_docflow        TYPE TABLE OF lty_sales_docflow,
      li_deliveries           TYPE TABLE OF lty_deliveries,
      li_shipments            TYPE TABLE OF lty_shipments,
      li_customers            TYPE TABLE OF lty_customers,
      li_products             TYPE TABLE OF lty_products.

    METHODS:

      " Obtener pedidos de contado
      get_cash_orders,

      " Obtener entregas relacionadas
      get_linked_deliveries,

      " Filtrar entregas parcialmente confirmadas
      filter_partial_deliveries,

      " Calcular diferencias
      calculate_differences,

      " Obtener histórico de ejecución
      get_historical_data,

      " Unir fuentes de información
      merge_data_sources,

      " Obtener datos de contabiliación de salida de mercancías (documento de material PGI)
      get_pgi
        CHANGING it_goods_assumtion TYPE tt_goods_assumtion,

      " Obtener datos de notas de crédito
      get_credit_memo
        CHANGING it_goods_assumtion TYPE tt_goods_assumtion,

      " Procesamiento de aceptación
      execute_acceptance_process
        CHANGING  iv_parcial_orders TYPE ty_goods_assumtion
        RETURNING VALUE(rv_success) TYPE abap_bool,

      " Anular shipment
      reverse_shipment
        IMPORTING iv_salesorder     TYPE vbeln
                  iv_delivery       TYPE vbeln_vl
        RETURNING VALUE(rv_success) TYPE abap_bool,

      " Anular entrega
      reverse_delivery
        IMPORTING iv_salesorder     TYPE vbeln
                  iv_delivery       TYPE vbeln_vl
        RETURNING VALUE(rv_success) TYPE abap_bool,

      " Asignar motivo de rechazo en pedido
      assign_reason_for_rejection
        IMPORTING iv_salesorder     TYPE vbeln_va
        EXPORTING ev_reason_rej     TYPE abgru
        RETURNING VALUE(rv_success) TYPE abap_bool,

      " Crear pedido de anticipo (ZANT)
      create_advance_order
        IMPORTING iv_vbeln_orig     TYPE vbeln_va
        EXPORTING ev_vbeln_new      TYPE vbeln_va
        RETURNING VALUE(rv_success) TYPE abap_bool,

      " Crear factura de anticipo (ZANT)
      create_advance_invoice
        IMPORTING iv_vbeln_orig     TYPE vbeln_va
                  iv_vbeln          TYPE vbeln_va
        EXPORTING ev_invoice        TYPE vbeln_vf
        RETURNING VALUE(rv_success) TYPE abap_bool,

      " Crear pedido de consumo (ZVM1)
      create_consumption_order
        IMPORTING iv_vbeln_orig        TYPE vbeln_va
                  iv_salesorder_ant    TYPE vbeln_va
                  iv_invoice_ant       TYPE vbeln_vf
        EXPORTING ev_consumption_order TYPE vbeln_va
        RETURNING VALUE(rv_success)    TYPE abap_bool,

      " Crear entrega de consumo (ZVM1)
      create_consumption_delivery
        IMPORTING iv_vbeln_orig     TYPE vbeln_va
                  iv_vbeln          TYPE vbeln_va
        EXPORTING ev_delivery       TYPE vbeln_vl
        RETURNING VALUE(rv_success) TYPE abap_bool,

      " Contabilizar salida de mercancías (PGI) (ZVM1)
      create_post_goods_issue
        IMPORTING iv_vbeln_orig     TYPE vbeln_va
                  iv_delivery       TYPE vbeln_vl
        EXPORTING ev_pgi            TYPE mblnr
        RETURNING VALUE(rv_success) TYPE abap_bool,

      " Crear transporte de consumo (ZVM1)
      create_consumption_transport
        IMPORTING iv_vbeln_orig     TYPE vbeln_va
                  iv_delivery       TYPE vbeln_vl
        EXPORTING ev_shipment       TYPE tknum
        RETURNING VALUE(rv_success) TYPE abap_bool,

      " Crear factura de consumo (ZVM1)
      create_consumption_invoice
        IMPORTING iv_vbeln_orig     TYPE vbeln_va
                  iv_vbeln          TYPE vbeln_va
        EXPORTING ev_invoice        TYPE vbeln_vf
        RETURNING VALUE(rv_success) TYPE abap_bool,

      " Obtener pedido Sol.NC Anticipo (ZNCA)
      get_order_advance_creditmemo
        IMPORTING iv_invoice_ant        TYPE vbeln_vl
        EXPORTING ev_creditmemo_request TYPE vbeln_va
        RETURNING VALUE(rv_success)     TYPE abap_bool,

      " Obtener factura Sol.NC Anticipo (ZNCA)
      get_invoice_advance_creditmemo
        IMPORTING iv_creditmemo_request TYPE vbeln_va
        EXPORTING ev_creditmemo_invoice TYPE vbeln_vf
        RETURNING VALUE(rv_success)     TYPE abap_bool,

      " Obtener pedido Sol.Bonificación (ZCRE)
      get_order_bonus_creditmemo
        IMPORTING iv_invoice_ant      TYPE vbeln_vl
        EXPORTING ev_creditmemo_bonus TYPE vbeln_va
        RETURNING VALUE(rv_success)   TYPE abap_bool,

      " Crear pedido Sol.Bonificación (ZCRE)
      get_invoice_bonus_creditmemo
        IMPORTING iv_creditmemo_bonus   TYPE vbeln_vf
        EXPORTING ev_creditmemo_invoice TYPE vbeln_vf
        RETURNING VALUE(rv_success)     TYPE abap_bool,

      handle_errors
        IMPORTING iv_salesorder   TYPE vbeln_va
                  iv_process      TYPE char30
                  iv_status       TYPE char10
                  it_return       TYPE bapiret2_t
        RETURNING VALUE(rv_error) TYPE abap_bool.

ENDCLASS.

*-------------------------------------------------------------------------------*
* IMPLEMENTACIÓN DE LA CLASE                                                    *
*-------------------------------------------------------------------------------*
CLASS cl_exsd_monitor_exist_fic IMPLEMENTATION.

  METHOD constructor ##NEEDED.

  ENDMETHOD.

  METHOD get_parcial_salesorders.
    " Método principal para obtener pedidos con entregas parciales

    " 1 Seleccionar pedidos de contado
    get_cash_orders( ).

    " 2 Seleccionar entregas vinculadas
    get_linked_deliveries( ).

    " 3 Filtrar entregas parciales
    filter_partial_deliveries( ).

    " 4 Calcular diferencias
    calculate_differences( ).

    " 5 Obtiene historico
    get_historical_data(  ).

    " 6 Fusionar fuente de datos
    merge_data_sources(  ).

    " 7 Obtener PGI faltantes
    get_pgi(
      CHANGING
        it_goods_assumtion = li_goods_assumtion_temp
    ).

    " 8 Obtener NC faltantes
    get_credit_memo(
      CHANGING
        it_goods_assumtion = li_goods_assumtion_temp
    ).

    " Retornar tabla de pedidos parciales
    rt_goods_assumtion = li_goods_assumtion_temp.

  ENDMETHOD.

  METHOD get_cash_orders.

    DATA:
      li_cash_orders_c TYPE TABLE OF lty_cash_orders.

    " Seleccionar pedidos de venta de contado según criterios
    SELECT p~vbeln
           p~posnr
           k~erdat
           k~vkorg
           k~vtweg
           k~spart
           k~kunnr
           p~matnr
           p~kwmeng
           p~meins
           p~werks
           d~zterm
      FROM vbak AS k INNER JOIN vbap AS p
                                     ON k~vbeln = p~vbeln
                     INNER JOIN vbkd AS d
                                     ON p~vbeln = d~vbeln
      INTO TABLE li_cash_orders
      WHERE k~auart IN s_auart
        AND k~vkorg IN s_vkorg
        AND k~vtweg IN s_vtweg
        AND k~spart IN s_spart
        AND k~erdat IN s_erdat
        AND k~kunnr IN s_kunnr
        AND k~vbeln IN s_vbeln
        AND p~werks IN s_werks.                   "#EC CI_NO_TRANSFORM.
    IF sy-subrc = 0.

      li_cash_orders_c[] = li_cash_orders[].
      SORT li_cash_orders_c BY kunnr.
      DELETE ADJACENT DUPLICATES FROM li_cash_orders_c COMPARING kunnr.
      IF li_cash_orders_c[] IS NOT INITIAL.
        " Obtener datos de los clientes
        SELECT kunnr
               name1
          FROM kna1
          INTO TABLE li_customers
          FOR ALL ENTRIES IN li_cash_orders_c
          WHERE kunnr = li_cash_orders_c-kunnr.
        IF sy-subrc = 0.
          SORT li_customers BY kunnr.
        ENDIF.
      ENDIF.

      li_cash_orders_c[] = li_cash_orders[].
      SORT li_cash_orders_c BY matnr.
      DELETE ADJACENT DUPLICATES FROM li_cash_orders_c COMPARING matnr.
      IF li_cash_orders_c[] IS NOT INITIAL.
        " Obtener descripción del material
        SELECT matnr
               maktx
          FROM makt
          INTO TABLE li_products
          FOR ALL ENTRIES IN li_cash_orders_c
          WHERE matnr = li_cash_orders_c-matnr
            AND spras = sy-langu.
        IF sy-subrc = 0.
          SORT li_products BY matnr maktx.
        ENDIF.
      ENDIF.

    ENDIF.

  ENDMETHOD.

  METHOD get_linked_deliveries.

    DATA:
      li_cash_orders_c TYPE TABLE OF lty_cash_orders.

    IF li_cash_orders[] IS NOT INITIAL.

      li_cash_orders_c[] = li_cash_orders[].
      SORT li_cash_orders_c BY vbeln.
      DELETE ADJACENT DUPLICATES FROM li_cash_orders_c COMPARING vbeln.
      IF li_cash_orders_c[] IS NOT INITIAL.
        " Seleccionar entregas vinculadas a los pedidos
        SELECT vbelv
               posnv
               vbeln
               posnn
               vbtyp_n
               rfmng
               rfmng_flo
          FROM vbfa
          INTO TABLE li_sales_docflow
          FOR ALL ENTRIES IN li_cash_orders_c
          WHERE vbelv = li_cash_orders_c-vbeln
            AND vbtyp_n = c_vbtyp_delivery.        "#EC CI_NO_TRANSFORM
        IF sy-subrc = 0.
          SORT li_sales_docflow BY vbelv posnv.
        ENDIF.
      ENDIF.

    ENDIF.

  ENDMETHOD.

  METHOD filter_partial_deliveries.

    TYPES:
      BEGIN OF lty_likp,
        vbeln TYPE likp-vbeln,
        erdat TYPE likp-erdat,
      END OF lty_likp,

      BEGIN OF lty_lips,
        vbeln TYPE likp-vbeln,
        posnr TYPE lips-posnr,
        vgbel TYPE lips-vgbel,
        vgpos TYPE lips-vgpos,
        matnr TYPE lips-matnr,
        lfimg TYPE lips-lfimg,
        meins TYPE lips-meins,
      END OF lty_lips.

    DATA:
      lw_likp       TYPE lty_likp,
      lw_lips       TYPE lty_lips,
      lw_deliveries TYPE lty_deliveries.

    DATA:
      li_likp            TYPE TABLE OF lty_likp,
      li_lips            TYPE TABLE OF lty_lips,
      li_sales_docflow_c TYPE TABLE OF lty_sales_docflow.

    DATA:
      lv_index TYPE sy-tabix.

    IF li_sales_docflow[] IS NOT INITIAL.

      " Optimización: Para ir a LIPS, usamos li_sales_docflow_c ya filtrada,
      li_sales_docflow_c[] = li_sales_docflow[].
      SORT li_sales_docflow_c BY vbeln.
      DELETE ADJACENT DUPLICATES FROM li_sales_docflow_c COMPARING vbeln.
      IF li_sales_docflow_c[] IS NOT INITIAL.
        " Seleccionar cabeceras de entrega con estado parcial
        SELECT vbeln
               posnr
               vgbel
               vgpos
               matnr
               lfimg
               meins
           FROM lips
           INTO TABLE li_lips
           FOR ALL ENTRIES IN li_sales_docflow_c
           WHERE vbeln = li_sales_docflow_c-vbeln. "#EC CI_NO_TRANSFORM
        IF sy-subrc = 0.

          " Optimización: Para ir a LIKP, usamos li_lips ya filtrada,
          DATA(li_lips_c) = li_lips[].
          SORT li_lips_c BY vbeln.
          DELETE ADJACENT DUPLICATES FROM li_lips_c COMPARING vbeln.
          IF li_lips_c[] IS NOT INITIAL.
            " Obtener datos de cabecera de la entrega
            SELECT vbeln erdat
              FROM likp
              INTO TABLE li_likp
              FOR ALL ENTRIES IN li_lips_c
              WHERE vbeln = li_lips_c-vbeln.
            IF sy-subrc = 0.

              " Ordenar para Binary Search
              SORT li_likp BY vbeln.

              LOOP AT li_lips INTO lw_lips.

                " Movemos datos de posición
                MOVE-CORRESPONDING lw_lips TO lw_deliveries.

                " Leemos datos de cabecera
                READ TABLE li_likp INTO lw_likp
                                   WITH KEY vbeln = lw_lips-vbeln
                                   BINARY SEARCH.
                IF sy-subrc = 0.
                  lw_deliveries-erdat = lw_likp-erdat.
                ENDIF.

                APPEND lw_deliveries TO li_deliveries.
                CLEAR lw_deliveries.
              ENDLOOP.

            ENDIF.
          ENDIF.
        ENDIF.
      ENDIF.

      IF li_deliveries[] IS NOT INITIAL.
        " Seleccionar estado de posiciones con picking parcial
        " Se deberán considerar en este monitor
        " todas aquellas entregas en donde VBUk-KOSTK = ‘B’

        " Documento comercial: Status de posición
        SELECT vbeln,
               kostk
          FROM vbuk
          INTO TABLE @DATA(li_vbuk)
          FOR ALL ENTRIES IN @li_deliveries
          WHERE vbeln = @li_deliveries-vbeln
            AND kostk = @c_embalaje_parcial.       "#EC CI_NO_TRANSFORM
        IF sy-subrc = 0.
          " Ordenar para Binary Search
          SORT li_vbuk BY vbeln.

          LOOP AT li_deliveries INTO lw_deliveries.
            lv_index = sy-tabix.
            READ TABLE li_vbuk TRANSPORTING NO FIELDS
                               WITH KEY vbeln = lw_deliveries-vbeln
                               BINARY SEARCH.
            IF sy-subrc <> 0.
              DELETE li_deliveries INDEX lv_index.
            ENDIF.
          ENDLOOP.
        ELSE.
          CLEAR li_deliveries[].
        ENDIF.

        IF li_deliveries[] IS NOT INITIAL.

          " Optimización: Para ir a VBFA, usamos li_sales_docflow_c ya filtrada,
          DATA(li_deliveries_c) = li_deliveries[].
          SORT li_deliveries_c BY vbeln.
          DELETE ADJACENT DUPLICATES FROM li_deliveries_c COMPARING vbeln.
          IF li_deliveries_c[] IS NOT INITIAL.
            " Seleccionar transportes vinculados a las entregas
            SELECT vbelv
                   posnv
                   vbeln
                   posnn
                   vbtyp_n
                   rfmng
                   rfmng_flo
              FROM vbfa
              APPENDING TABLE li_sales_docflow
              FOR ALL ENTRIES IN li_deliveries_c
              WHERE vbelv = li_deliveries_c-vbeln
                AND vbtyp_n = c_vbtyp_picking.     "#EC CI_NO_TRANSFORM
            IF sy-subrc = 0.
              SORT li_sales_docflow BY vbelv posnv.
            ENDIF.
          ENDIF.

          " Optimización: Para ir a VBFA, usamos li_sales_docflow_c ya filtrada,
          li_deliveries_c = li_deliveries[].
          SORT li_deliveries_c BY vbeln.
          DELETE ADJACENT DUPLICATES FROM li_deliveries_c COMPARING vbeln.
          IF li_deliveries_c[] IS NOT INITIAL.
            " Seleccionar transportes vinculados a las entregas
            SELECT vbelv
                   posnv
                   vbeln
                   posnn
                   vbtyp_n
                   rfmng
                   rfmng_flo
              FROM vbfa
              APPENDING TABLE li_sales_docflow
              FOR ALL ENTRIES IN li_deliveries_c
              WHERE vbelv = li_deliveries_c-vbeln
                AND vbtyp_n = c_vbtyp_shipment.    "#EC CI_NO_TRANSFORM
            IF sy-subrc = 0.
              " Optimización: Para ir a VTTP, usamos li_sales_docflow_c ya filtrada,
              li_sales_docflow_c[] = li_sales_docflow[].
              SORT li_sales_docflow_c BY vbeln.
              DELETE ADJACENT DUPLICATES FROM li_sales_docflow_c COMPARING vbeln.
              IF li_sales_docflow_c[] IS NOT INITIAL.
                " Seleccionar transportes vinculados a las entregas
                SELECT tknum
                       tpnum
                  FROM vttp
                  INTO TABLE li_shipments
                  FOR ALL ENTRIES IN li_sales_docflow_c
                  WHERE tknum = li_sales_docflow_c-vbeln. "#EC CI_NO_TRANSFORM
                IF sy-subrc = 0.
                  SORT li_shipments BY tknum tpnum.
                ENDIF.
              ENDIF.
            ENDIF.
          ENDIF.
        ENDIF.
      ENDIF.
    ENDIF.

  ENDMETHOD.

  METHOD calculate_differences.
    "Como parte del proceso de pudieran encontrarse documentos con el flujo de documentos parciales
    "ya sea por la acción de rechazo que anula los documentos o por mismo proceso que pudiera estar
    "parcialmente creado en donde no se tenga el cumplimiento del proceso total finalizado,
    "es por ello que el desarrollo debe contemplar esos escenarios y solo asignar los documentos
    "que tenga su momento creados

    DATA:
      lw_sales_docflow TYPE lty_sales_docflow,
      lw_deliveries    TYPE lty_deliveries,
      lw_shipments     TYPE lty_shipments.

    DATA:
      lv_picking    TYPE vbfa-rfmng,
      lv_diferencia TYPE vbfa-rfmng.

    DATA(li_sales_docflow_d) = li_sales_docflow[].
    DELETE li_sales_docflow_d WHERE vbtyp_n <> c_vbtyp_delivery. " Entrega

    DATA(li_sales_docflow_p) = li_sales_docflow[].
    DELETE li_sales_docflow_p WHERE vbtyp_n <> c_vbtyp_picking. " Picking

    DATA(li_sales_docflow_t) = li_sales_docflow[].
    DELETE li_sales_docflow_t WHERE vbtyp_n <> c_vbtyp_shipment. " Transporte

    " Ordenar para Binary Search
    SORT li_sales_docflow_d BY vbelv posnv vbtyp_n.
    SORT li_sales_docflow_p BY vbelv posnv vbtyp_n.
    SORT li_sales_docflow_t BY vbelv vbtyp_n.
    SORT li_deliveries BY vbeln posnr.
    SORT li_shipments BY tknum tpnum.
    SORT li_customers BY kunnr.
    SORT li_products BY matnr.

    " Calcular diferencias entre cantidades pedidas y entregadas
    LOOP AT li_cash_orders INTO DATA(lw_cash_orders).

      CLEAR: lw_sales_docflow, lw_deliveries, lw_shipments, lv_picking, lv_diferencia.

      " Buscar flujo de documentos (entregas)
      READ TABLE li_sales_docflow_d INTO lw_sales_docflow
                                    WITH KEY vbelv = lw_cash_orders-vbeln
                                             posnv = lw_cash_orders-posnr
                                             vbtyp_n = c_vbtyp_delivery
                                    BINARY SEARCH.
      IF sy-subrc = 0.

        " Buscar entregas
        READ TABLE li_deliveries INTO lw_deliveries
                                 WITH KEY vbeln = lw_sales_docflow-vbeln
                                          posnr = lw_sales_docflow-posnn
                                 BINARY SEARCH.
        IF sy-subrc = 0.

          " Buscar flujo de documentos (picking)
          READ TABLE li_sales_docflow_p INTO lw_sales_docflow
                                        WITH KEY vbelv = lw_deliveries-vbeln
                                                 posnv = lw_deliveries-posnr
                                                 vbtyp_n = c_vbtyp_picking
                                        BINARY SEARCH.
          IF sy-subrc = 0.
            lv_picking = lw_sales_docflow-rfmng_flo.
          ENDIF.


          " Buscar flujo de documentos (transporte)
          READ TABLE li_sales_docflow_t INTO lw_sales_docflow
                                        WITH KEY vbelv = lw_deliveries-vbeln
                                                 vbtyp_n = c_vbtyp_shipment
                                        BINARY SEARCH.
          IF sy-subrc = 0.

            " Buscar transporte
            READ TABLE li_shipments INTO lw_shipments
                                    WITH KEY tknum = lw_sales_docflow-vbeln    ##WARN_OK
                                             tpnum = lw_sales_docflow-posnn
                                    BINARY SEARCH.
            IF sy-subrc <> 0.
              CLEAR lw_shipments.
            ENDIF.
          ENDIF.

          " Calcular diferencia
          lv_diferencia = lw_deliveries-lfimg - lv_picking.

          " Construir registro final
          w_parcial_orders-icon  = icon_light_out.
          w_parcial_orders-vbeln = lw_cash_orders-vbeln.
          w_parcial_orders-posnr = lw_cash_orders-posnr.
          w_parcial_orders-erdat = lw_cash_orders-erdat.
          w_parcial_orders-vkorg = lw_cash_orders-vkorg.
          w_parcial_orders-vtweg = lw_cash_orders-vtweg.
          w_parcial_orders-spart = lw_cash_orders-spart.
          w_parcial_orders-werks = lw_cash_orders-werks.
          w_parcial_orders-kunnr = lw_cash_orders-kunnr.
          w_parcial_orders-matnr = lw_cash_orders-matnr.
          w_parcial_orders-kwmeng = lw_cash_orders-kwmeng.
          w_parcial_orders-zterm = lw_cash_orders-zterm.
          w_parcial_orders-vbeln_vl = lw_deliveries-vbeln.
          w_parcial_orders-erdat_vl = lw_deliveries-erdat.
          w_parcial_orders-lfimg = lw_deliveries-lfimg.
          w_parcial_orders-rfmng = lv_picking.
          w_parcial_orders-meins = lw_cash_orders-meins.
          w_parcial_orders-difference = lv_diferencia.
          w_parcial_orders-tknum = lw_shipments-tknum.
          w_parcial_orders-tpnum = lw_shipments-tpnum.

          " Obtener nombre del cliente
          READ TABLE li_customers INTO DATA(lw_customers)
                                  WITH KEY kunnr = lw_cash_orders-kunnr
                                  BINARY SEARCH.
          IF sy-subrc = 0.
            w_parcial_orders-name1 = lw_customers-name1.
          ENDIF.

          " Obtener descripción del material
          READ TABLE li_products INTO DATA(lw_products)
                                 WITH KEY matnr = lw_cash_orders-matnr
                                 BINARY SEARCH.
          IF sy-subrc = 0.
            w_parcial_orders-maktx = lw_products-maktx.
          ENDIF.

          IF w_parcial_orders-zterm = c_cash_sales.
            w_parcial_orders-dtpaymt = TEXT-c01. "Contado
          ELSE.
            w_parcial_orders-dtpaymt = TEXT-c02. "Crédito
          ENDIF.

          APPEND w_parcial_orders TO li_goods_assumtion_temp.
          CLEAR w_parcial_orders.

        ENDIF.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.

  METHOD process_acceptance.

    " Ejecutar proceso de aceptación
    rv_success = execute_acceptance_process(
                    CHANGING
                       iv_parcial_orders = iv_parcial_orders
                 ).

  ENDMETHOD.

  METHOD get_historical_data.
    " Obtener datos históricos de la tabla ZEXSD_PARCIAL

    TYPES:
      BEGIN OF lty_exfic_mon,
        vbeln             TYPE ztasd_exfic_mon-vbeln,
        posnr             TYPE ztasd_exfic_mon-posnr,
        erdat             TYPE ztasd_exfic_mon-erdat,
        vkorg             TYPE ztasd_exfic_mon-vkorg,
        vtweg             TYPE ztasd_exfic_mon-vtweg,
        spart             TYPE ztasd_exfic_mon-spart,
        werks             TYPE ztasd_exfic_mon-werks,
        kunnr             TYPE ztasd_exfic_mon-kunnr,
        name1             TYPE ztasd_exfic_mon-name1,
        zterm             TYPE ztasd_exfic_mon-zterm,
        matnr             TYPE ztasd_exfic_mon-matnr,
        maktx             TYPE ztasd_exfic_mon-maktx,
        kwmeng            TYPE ztasd_exfic_mon-kwmeng,
        vbeln_vl          TYPE ztasd_exfic_mon-vbeln_vl,
        erdat_vl          TYPE ztasd_exfic_mon-erdat_vl,
        lfimg             TYPE ztasd_exfic_mon-lfimg,
        meins             TYPE ztasd_exfic_mon-meins,
        rfmng             TYPE ztasd_exfic_mon-rfmng,
        difference        TYPE ztasd_exfic_mon-difference,
        tknum             TYPE ztasd_exfic_mon-tknum,
        tpnum             TYPE ztasd_exfic_mon-tpnum,
        process           TYPE ztasd_exfic_mon-process,
        status            TYPE ztasd_exfic_mon-status,
        reason_rej        TYPE ztasd_exfic_mon-reason_rej,
        salesorder_ant    TYPE ztasd_exfic_mon-salesorder_ant,
        invoice_ant       TYPE ztasd_exfic_mon-invoice_ant,
        salesorder_cons   TYPE ztasd_exfic_mon-salesorder_cons,
        delivery_cons     TYPE ztasd_exfic_mon-delivery_cons,
        pgi_cons          TYPE ztasd_exfic_mon-pgi_cons,
        shipment_cons     TYPE ztasd_exfic_mon-shipment_cons,
        invoice_cons      TYPE ztasd_exfic_mon-invoice_cons,
        creditmemo_ant    TYPE ztasd_exfic_mon-creditmemo_ant,
        creditmemo_antinv TYPE ztasd_exfic_mon-creditmemo_antinv,
        creditmemo_bon    TYPE ztasd_exfic_mon-creditmemo_bon,
        creditmemo_boninv TYPE ztasd_exfic_mon-creditmemo_boninv,
        message           TYPE ztasd_exfic_mon-message,
      END OF lty_exfic_mon.

    DATA:
      lw_exfic_mon  TYPE lty_exfic_mon,
      lw_salesorder TYPE ty_goods_assumtion.

    DATA:
      li_exfic_mon  TYPE TABLE OF lty_exfic_mon.

    " Consultar tabla Z con filtros de selección
    SELECT vbeln
           posnr
           erdat
           vkorg
           vtweg
           spart
           werks
           kunnr
           name1
           zterm
           matnr
           maktx
           kwmeng
           vbeln_vl
           erdat_vl
           lfimg
           meins
           rfmng
           difference
           tknum
           tpnum
           process
           status
           reason_rej
           salesorder_ant
           invoice_ant
           salesorder_cons
           delivery_cons
           pgi_cons
           shipment_cons
           invoice_cons
           creditmemo_ant
           creditmemo_antinv
           creditmemo_bon
           creditmemo_boninv
           message
     FROM ztasd_exfic_mon
     INTO TABLE li_exfic_mon
     WHERE vbeln IN s_vbeln
       AND kunnr IN s_kunnr
       AND werks IN s_werks
       AND erdat IN s_erdat
       AND vkorg IN s_vkorg
       AND vtweg IN s_vtweg
       AND spart IN s_spart.
    IF sy-subrc = 0.
      SORT li_exfic_mon BY vbeln posnr.

      " Convertir formato de tabla Z a estructura de retorno
      LOOP AT li_exfic_mon INTO lw_exfic_mon.

        CLEAR lw_salesorder.
        lw_salesorder-icon              = icon_led_yellow.    " Icono histórico (diferente de actual)
        lw_salesorder-vbeln             = lw_exfic_mon-vbeln.
        lw_salesorder-posnr             = lw_exfic_mon-posnr.
        lw_salesorder-erdat             = lw_exfic_mon-erdat.
        lw_salesorder-vkorg             = lw_exfic_mon-vkorg.
        lw_salesorder-vtweg             = lw_exfic_mon-vtweg.
        lw_salesorder-spart             = lw_exfic_mon-spart.
        lw_salesorder-werks             = lw_exfic_mon-werks.
        lw_salesorder-kunnr             = lw_exfic_mon-kunnr.
        lw_salesorder-name1             = lw_exfic_mon-name1.
        lw_salesorder-matnr             = lw_exfic_mon-matnr.
        lw_salesorder-zterm             = lw_exfic_mon-zterm.
        lw_salesorder-maktx             = lw_exfic_mon-maktx.
        lw_salesorder-kwmeng            = lw_exfic_mon-kwmeng.
        lw_salesorder-vbeln_vl          = lw_exfic_mon-vbeln_vl.
        lw_salesorder-erdat_vl          = lw_exfic_mon-erdat_vl.
        lw_salesorder-lfimg             = lw_exfic_mon-lfimg.
        lw_salesorder-meins             = lw_exfic_mon-meins.
        lw_salesorder-rfmng             = lw_exfic_mon-rfmng.
        lw_salesorder-difference        = lw_exfic_mon-difference.
        lw_salesorder-tknum             = lw_exfic_mon-tknum.
        lw_salesorder-tpnum             = lw_exfic_mon-tpnum.
        lw_salesorder-process           = lw_exfic_mon-process.
        lw_salesorder-status            = lw_exfic_mon-status.
        lw_salesorder-reason_rej        = lw_exfic_mon-reason_rej.
        lw_salesorder-salesorder_ant    = lw_exfic_mon-salesorder_ant.
        lw_salesorder-invoice_ant       = lw_exfic_mon-invoice_ant.
        lw_salesorder-salesorder_cons   = lw_exfic_mon-salesorder_cons.
        lw_salesorder-delivery_cons     = lw_exfic_mon-delivery_cons.
        lw_salesorder-pgi_cons          = lw_exfic_mon-pgi_cons.
        lw_salesorder-shipment_cons     = lw_exfic_mon-shipment_cons.
        lw_salesorder-invoice_cons      = lw_exfic_mon-invoice_cons.
        lw_salesorder-creditmemo_ant    = lw_exfic_mon-creditmemo_ant.
        lw_salesorder-creditmemo_antinv = lw_exfic_mon-creditmemo_antinv.
        lw_salesorder-creditmemo_bon    = lw_exfic_mon-creditmemo_bon.
        lw_salesorder-creditmemo_boninv = lw_exfic_mon-creditmemo_boninv.
        lw_salesorder-message           = lw_exfic_mon-message.

        IF lw_salesorder-zterm = c_cash_sales.
          lw_salesorder-dtpaymt = TEXT-c01. "Contado
        ELSE.
          lw_salesorder-dtpaymt = TEXT-c02. "Crédito
        ENDIF.

        IF lw_salesorder-status = c_error.
          lw_salesorder-icon = icon_red_light.
        ELSE.
          lw_salesorder-icon = icon_green_light.
        ENDIF.

        APPEND lw_salesorder TO li_goods_assumtion_temp.
        CLEAR lw_salesorder.

      ENDLOOP.

    ENDIF.

  ENDMETHOD.

  METHOD merge_data_sources.
    " Combinar datos actuales e históricos eliminando duplicados

    SORT li_goods_assumtion_temp BY vbeln posnr icon.
    DELETE ADJACENT DUPLICATES FROM li_goods_assumtion_temp COMPARING vbeln posnr.

    "Valida autorizaciones
    validate_authorizations(
      CHANGING
        iv_goods_assumtion = li_goods_assumtion_temp
    ).

  ENDMETHOD.

  METHOD get_pgi.
    "Obtiene documentos de salida de mercancías (PGI) manuales o asíncronos

    DATA:
      lw_exfic_mon_upd TYPE ztasd_exfic_mon.

    DATA:
      li_exfic_mon_upd TYPE TABLE OF ztasd_exfic_mon.

    DATA:
      lv_update        TYPE abap_bool.

    IF it_goods_assumtion[] IS NOT INITIAL.
      "Consulta PGI del flujo de documento relacionado a la entrega de consumo
      SELECT vbelv, posnv, vbeln, posnn, vbtyp_n
        FROM vbfa
        INTO TABLE @DATA(li_pgi)
        FOR ALL ENTRIES IN @it_goods_assumtion
        WHERE vbelv = @it_goods_assumtion-delivery_cons
          AND vbtyp_n = 'R'.                       "#EC CI_NO_TRANSFORM
      IF sy-subrc = 0.
        SORT li_pgi BY vbelv posnv.
      ENDIF.
    ENDIF.

    LOOP AT it_goods_assumtion ASSIGNING FIELD-SYMBOL(<lfs_goods_assumtion>).
      lv_update = abap_false.

      IF <lfs_goods_assumtion>-pgi_cons IS INITIAL AND <lfs_goods_assumtion>-delivery_cons IS NOT INITIAL.
        READ TABLE li_pgi INTO DATA(lw_pgi)
                          WITH KEY vbelv = <lfs_goods_assumtion>-delivery_cons
                          BINARY SEARCH.
        IF sy-subrc = 0.
          <lfs_goods_assumtion>-pgi_cons = lw_pgi-vbeln.
          lv_update = abap_true.
        ENDIF.
      ENDIF.

      " Si se encontró nuevo PGI, actualizar tabla Z
      IF lv_update = abap_true.
        MOVE-CORRESPONDING <lfs_goods_assumtion> TO lw_exfic_mon_upd.
        lw_exfic_mon_upd-pgi_cons = <lfs_goods_assumtion>-pgi_cons.
        APPEND lw_exfic_mon_upd TO li_exfic_mon_upd.
      ENDIF.

    ENDLOOP.

    IF li_exfic_mon_upd[] IS NOT INITIAL.
      MODIFY ztasd_exfic_mon FROM TABLE li_exfic_mon_upd.
      COMMIT WORK AND WAIT.
    ENDIF.

  ENDMETHOD.

  METHOD get_credit_memo.
    "Obtiene documentos manuales

    DATA:
      lw_exfic_mon_upd TYPE ztasd_exfic_mon.

    DATA:
      li_exfic_mon_upd TYPE TABLE OF ztasd_exfic_mon.

    DATA:
      lv_update        TYPE abap_bool.

    IF it_goods_assumtion[] IS NOT INITIAL.
      "Consulta pedido del flujo de documento
      SELECT f~vbelv, f~posnv, f~vbeln, f~posnn, f~vbtyp_n
        FROM vbfa AS f INNER JOIN vbak AS k
          ON f~vbeln = k~vbeln
      INTO TABLE @DATA(li_creditmemo_order)
      FOR ALL ENTRIES IN @it_goods_assumtion
      WHERE f~vbelv = @it_goods_assumtion-invoice_ant
        AND f~vbtyp_n = 'K'
        AND k~auart = 'ZNCA'.                      "#EC CI_NO_TRANSFORM
      IF sy-subrc = 0.
        "Consulta pedido del flujo de documento
        SELECT vbelv, posnv, vbeln, posnn, vbtyp_n
          FROM vbfa
        INTO TABLE @DATA(li_creditmemo_order_invoice)
        FOR ALL ENTRIES IN @li_creditmemo_order
        WHERE vbelv = @li_creditmemo_order-vbeln
          AND vbtyp_n = 'O'.                       "#EC CI_NO_TRANSFORM
        IF sy-subrc = 0.
          SORT li_creditmemo_order BY vbelv posnv.
          SORT li_creditmemo_order_invoice BY vbelv posnv.
        ENDIF.
      ENDIF.
    ENDIF.

    IF it_goods_assumtion[] IS NOT INITIAL.
      "Consulta pedido del flujo de documento
      SELECT f~vbelv, f~posnv, f~vbeln, f~posnn, f~vbtyp_n
        FROM vbfa AS f INNER JOIN vbak AS k
          ON f~vbeln = k~vbeln
      INTO TABLE @DATA(li_creditmemo_bonus)
      FOR ALL ENTRIES IN @it_goods_assumtion
      WHERE f~vbelv = @it_goods_assumtion-invoice_ant
        AND f~vbtyp_n = 'K'
        AND k~auart = 'ZCRE'.                      "#EC CI_NO_TRANSFORM
      IF sy-subrc = 0.
        "Consulta pedido del flujo de documento
        SELECT vbelv, posnv, vbeln, posnn, vbtyp_n
          FROM vbfa
        INTO TABLE @DATA(li_creditmemo_bonus_invoice)
        FOR ALL ENTRIES IN @li_creditmemo_bonus
        WHERE vbelv = @li_creditmemo_bonus-vbeln
          AND vbtyp_n = 'O'.                       "#EC CI_NO_TRANSFORM
        IF sy-subrc = 0.
          SORT li_creditmemo_bonus BY vbelv posnv.
          SORT li_creditmemo_bonus_invoice BY vbelv posnv.
        ENDIF.
      ENDIF.
    ENDIF.

    LOOP AT it_goods_assumtion ASSIGNING FIELD-SYMBOL(<lfs_goods_assumtion>).
      lv_update = abap_false.

      IF <lfs_goods_assumtion>-creditmemo_ant IS INITIAL.
        READ TABLE li_creditmemo_order INTO DATA(lw_creditmemo_order)
                                       WITH KEY vbelv = <lfs_goods_assumtion>-invoice_ant
                                       BINARY SEARCH.
        IF sy-subrc = 0.
          <lfs_goods_assumtion>-creditmemo_ant = lw_creditmemo_order-vbeln.
          lv_update = abap_true.

          READ TABLE li_creditmemo_order_invoice INTO DATA(lw_creditmemo_order_invoice)
                                                 WITH KEY vbelv = <lfs_goods_assumtion>-creditmemo_ant
                                                 BINARY SEARCH.
          IF sy-subrc = 0.
            <lfs_goods_assumtion>-creditmemo_antinv = lw_creditmemo_order_invoice-vbeln.
          ENDIF.

        ENDIF.
      ENDIF.

      IF <lfs_goods_assumtion>-creditmemo_bon IS INITIAL.
        READ TABLE li_creditmemo_bonus INTO DATA(lw_creditmemo_bonus)
                                       WITH KEY vbelv = <lfs_goods_assumtion>-invoice_ant
                                       BINARY SEARCH.
        IF sy-subrc = 0.
          <lfs_goods_assumtion>-creditmemo_bon = lw_creditmemo_bonus-vbeln.
          lv_update = abap_true.

          READ TABLE li_creditmemo_bonus_invoice INTO DATA(lw_creditmemo_bonus_invoice)
                                                 WITH KEY vbelv = <lfs_goods_assumtion>-creditmemo_bon
                                                 BINARY SEARCH.
          IF sy-subrc = 0.
            <lfs_goods_assumtion>-creditmemo_boninv = lw_creditmemo_bonus_invoice-vbeln.
          ENDIF.
        ENDIF.
      ENDIF.

      " Si se encontraron nuevos documentos manuales, actualizar tabla Z
      IF lv_update = abap_true.
        MOVE-CORRESPONDING <lfs_goods_assumtion> TO lw_exfic_mon_upd.
        lw_exfic_mon_upd-creditmemo_ant    = <lfs_goods_assumtion>-creditmemo_ant.
        lw_exfic_mon_upd-creditmemo_antinv = <lfs_goods_assumtion>-creditmemo_antinv.
        lw_exfic_mon_upd-creditmemo_bon    = <lfs_goods_assumtion>-creditmemo_bon.
        lw_exfic_mon_upd-creditmemo_boninv = <lfs_goods_assumtion>-creditmemo_boninv.
        APPEND lw_exfic_mon_upd TO li_exfic_mon_upd.
      ENDIF.

    ENDLOOP.

    IF li_exfic_mon_upd[] IS NOT INITIAL.
      MODIFY ztasd_exfic_mon FROM TABLE li_exfic_mon_upd.
      COMMIT WORK AND WAIT.
    ENDIF.

  ENDMETHOD.

  METHOD process_rejection.
    " Procesar rechazo de parcialidad

    " Inicializar resultado
    rv_success = abap_false.

    TRY.

        " Sacar entrega del transporte
        IF reverse_shipment( EXPORTING
                               iv_salesorder = iv_parcial_orders-vbeln
                               iv_delivery = iv_parcial_orders-vbeln_vl ) = abap_false.
          iv_parcial_orders-message = TEXT-e08.
          iv_parcial_orders-status = c_error.
          iv_parcial_orders-icon = icon_red_light.
          RETURN.
        ENDIF.

        " Reversar entrega (borrar)
        IF reverse_delivery( EXPORTING
                               iv_salesorder = iv_parcial_orders-vbeln
                               iv_delivery = iv_parcial_orders-vbeln_vl ) = abap_false.
          iv_parcial_orders-message = TEXT-e09.
          iv_parcial_orders-status = c_error.
          iv_parcial_orders-icon = icon_red_light.
          RETURN.
        ENDIF.

        " Asignar motivo de rechazo
        IF assign_reason_for_rejection( EXPORTING
                                          iv_salesorder = iv_parcial_orders-vbeln
                                        IMPORTING
                                          ev_reason_rej = iv_parcial_orders-reason_rej ) = abap_false.

          iv_parcial_orders-message = TEXT-e10.
          iv_parcial_orders-status = c_error.
          iv_parcial_orders-icon = icon_red_light.
          RETURN.
        ENDIF.

        " Si llegamos aquí, todos los pasos fueron exitosos
        iv_parcial_orders-status = c_finised.
        iv_parcial_orders-icon = icon_green_light.
        CLEAR iv_parcial_orders-message. " Limpia el mensaje
        rv_success = abap_true.

      CATCH cx_sy_arithmetic_error
            cx_sy_conversion_error
            cx_sy_assign_cast_illegal_cast
            cx_sy_assign_cast_unknown_type
            cx_sy_move_cast_error INTO DATA(lo_exception) ##NEEDED.

        rv_success = abap_false.
    ENDTRY.

  ENDMETHOD.

  METHOD execute_acceptance_process.
    " Ejecutar proceso completo de aceptación

*--------------------------------------------------------------------*
*   Primer proceso: Anticipo
*--------------------------------------------------------------------*

    " Crear pedido de anticipo
    IF iv_parcial_orders-salesorder_ant IS INITIAL.
      IF create_advance_order( EXPORTING
                                 iv_vbeln_orig = iv_parcial_orders-vbeln
                               IMPORTING
                                 ev_vbeln_new  = iv_parcial_orders-salesorder_ant ) = abap_false.
        iv_parcial_orders-message = TEXT-e01.
        iv_parcial_orders-status = c_error.
        iv_parcial_orders-icon = icon_red_light.
        RETURN.
      ENDIF.
    ENDIF.

    " Crear factura de anticipo
    IF iv_parcial_orders-invoice_ant IS INITIAL.
      IF create_advance_invoice( EXPORTING
                                   iv_vbeln_orig = iv_parcial_orders-vbeln
                                   iv_vbeln = iv_parcial_orders-salesorder_ant
                                 IMPORTING
                                   ev_invoice = iv_parcial_orders-invoice_ant ) = abap_false.
        iv_parcial_orders-message = TEXT-e03.
        iv_parcial_orders-status = c_error.
        iv_parcial_orders-icon = icon_red_light.
        RETURN.
      ENDIF.
    ENDIF.

*--------------------------------------------------------------------*
*   Segundo proceso: Consumo
*--------------------------------------------------------------------*

    " Crear el pedido de Consumo relacionado a la factura de Anticipo.
    IF iv_parcial_orders-salesorder_cons IS INITIAL.
      IF create_consumption_order( EXPORTING
                                     iv_vbeln_orig = iv_parcial_orders-vbeln
                                     iv_salesorder_ant = iv_parcial_orders-salesorder_ant
                                     iv_invoice_ant = iv_parcial_orders-invoice_ant
                                   IMPORTING
                                     ev_consumption_order = iv_parcial_orders-salesorder_cons ) = abap_false.
        iv_parcial_orders-message = TEXT-e04.
        iv_parcial_orders-status = c_error.
        iv_parcial_orders-icon = icon_red_light.
        RETURN.
      ENDIF.
    ENDIF.

    " Crear delivery de consumo
    IF iv_parcial_orders-delivery_cons IS INITIAL.
      IF create_consumption_delivery( EXPORTING
                                        iv_vbeln_orig = iv_parcial_orders-vbeln
                                        iv_vbeln = iv_parcial_orders-salesorder_cons
                                      IMPORTING
                                        ev_delivery = iv_parcial_orders-delivery_cons ) = abap_false.
        iv_parcial_orders-message = TEXT-e05.
        iv_parcial_orders-status = c_error.
        iv_parcial_orders-icon = icon_red_light.
        RETURN.
      ENDIF.
    ENDIF.

    " Post Goods Issue de la entrega de consumo
    IF iv_parcial_orders-pgi_cons IS INITIAL.
      IF create_post_goods_issue( EXPORTING
                             iv_vbeln_orig = iv_parcial_orders-vbeln
                             iv_delivery = iv_parcial_orders-delivery_cons
                           IMPORTING
                             ev_pgi = iv_parcial_orders-pgi_cons ) = abap_false.
        iv_parcial_orders-message = TEXT-e02. "'Error al contabilizar salida de mercancías (PGI)'.
        iv_parcial_orders-status = c_error.
        iv_parcial_orders-icon = icon_red_light.
        RETURN.
      ENDIF.
    ENDIF.

    " Crear transporte de consumo
    IF iv_parcial_orders-shipment_cons IS INITIAL.
      IF create_consumption_transport( EXPORTING
                                         iv_vbeln_orig = iv_parcial_orders-vbeln
                                         iv_delivery = iv_parcial_orders-delivery_cons
                                       IMPORTING
                                         ev_shipment = iv_parcial_orders-shipment_cons ) = abap_false.
        iv_parcial_orders-message = TEXT-e06.
        iv_parcial_orders-status = c_error.
        iv_parcial_orders-icon = icon_red_light.
        RETURN.
      ENDIF.
    ENDIF.

    " Crear factura de consumo
    IF iv_parcial_orders-invoice_cons IS INITIAL.
      IF create_consumption_invoice( EXPORTING
                                       iv_vbeln_orig = iv_parcial_orders-vbeln
                                       iv_vbeln = iv_parcial_orders-salesorder_cons
                                     IMPORTING
                                       ev_invoice = iv_parcial_orders-invoice_cons ) = abap_false.
        iv_parcial_orders-message = TEXT-e07.
        iv_parcial_orders-status = c_error.
        iv_parcial_orders-icon = icon_red_light.
        RETURN.
      ENDIF.
    ENDIF.

*--------------------------------------------------------------------*
*   Tercer proceso: Notas de crédito
*--------------------------------------------------------------------*

    " Obtener pedido Sol.NC Anticipo (ZNCA)
    " Nota de crédito se crea en automático al timbrar la factura
    IF iv_parcial_orders-creditmemo_ant IS INITIAL.
      get_order_advance_creditmemo( EXPORTING
                                      iv_invoice_ant = iv_parcial_orders-invoice_ant
                                    IMPORTING
                                      ev_creditmemo_request = iv_parcial_orders-creditmemo_ant ).

    ENDIF.

    " Obtener factura Sol.NC Anticipo (ZNCA)
    " Nota de crédito se crea en automático al timbrar la factura
    IF iv_parcial_orders-creditmemo_antinv IS INITIAL.
      get_invoice_advance_creditmemo( EXPORTING
                                        iv_creditmemo_request = iv_parcial_orders-creditmemo_ant
                                      IMPORTING
                                        ev_creditmemo_invoice = iv_parcial_orders-creditmemo_antinv ).
    ENDIF.

    " Obtener pedido Sol.Bonificación (ZCRE)
    IF iv_parcial_orders-creditmemo_bon IS INITIAL.
      get_order_bonus_creditmemo( EXPORTING
                                    iv_invoice_ant = iv_parcial_orders-invoice_ant
                                  IMPORTING
                                    ev_creditmemo_bonus = iv_parcial_orders-creditmemo_bon ).
    ENDIF.

    " Obtener factura Sol.Bonificación (ZCRE)
    IF iv_parcial_orders-creditmemo_boninv IS INITIAL.
      get_invoice_bonus_creditmemo( EXPORTING
                                      iv_creditmemo_bonus = iv_parcial_orders-creditmemo_bon
                                    IMPORTING
                                      ev_creditmemo_invoice = iv_parcial_orders-creditmemo_boninv ).  " Cantidad diferencia

    ENDIF.

    " Validar éxito de todas las operaciones
    IF iv_parcial_orders-salesorder_ant  IS NOT INITIAL AND
       iv_parcial_orders-invoice_ant     IS NOT INITIAL AND
       iv_parcial_orders-salesorder_cons IS NOT INITIAL AND
       iv_parcial_orders-delivery_cons   IS NOT INITIAL AND
       iv_parcial_orders-shipment_cons   IS NOT INITIAL AND
       iv_parcial_orders-invoice_cons    IS NOT INITIAL.

      iv_parcial_orders-status = c_finised.
      iv_parcial_orders-icon = icon_green_light.
      CLEAR iv_parcial_orders-message.
      rv_success = abap_true.  " Lógica de validación completa aquí
    ENDIF.

  ENDMETHOD.

  METHOD reverse_shipment.
    " Sacar la entrega del transporte

    DATA:
      lw_headerdata       TYPE bapishipmentheader,
      lw_headerdataaction TYPE bapishipmentheaderaction,
      lw_itemdata         TYPE bapishipmentitem,
      lw_itemdataaction   TYPE bapishipmentitemaction,
      lw_return           TYPE bapiret2 ##NEEDED.

    DATA:
      li_itemdataaction TYPE TABLE OF bapishipmentitemaction,
      li_itemdata       TYPE TABLE OF bapishipmentitem,
      li_return         TYPE TABLE OF bapiret2.

    DATA:
      lv_shipment TYPE tknum.

    " Obtener número de transporte
    SELECT tknum
      UP TO 1 ROWS
      FROM vttp              ##WARN_OK
      INTO lv_shipment
      WHERE vbeln = iv_delivery.
    ENDSELECT.
    IF sy-subrc <> 0.
      " No hay transporte asociado
      rv_success = abap_true.
      RETURN.
    ENDIF.
    " Si no encuentra entrega asignada termina el proceso
    IF iv_delivery IS INITIAL OR lv_shipment IS INITIAL.
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

    lw_headerdataaction-status_plan         = c_d. " Delete
    lw_headerdataaction-status_checkin      = c_d. " Delete
    lw_headerdataaction-status_load_start   = c_d. " Delete
    lw_headerdataaction-status_load_end     = c_d. " Delete
    lw_headerdataaction-status_compl        = c_d. " Delete
    lw_headerdataaction-status_shpmnt_start = c_d. " Delete
    lw_headerdataaction-status_shpmnt_end   = c_d. " Delete

    " Ejecutar BAPI de modificación de embarque ( Reversa estatus de ejecución )
    CALL FUNCTION 'BAPI_SHIPMENT_CHANGE'
      EXPORTING
        headerdata       = lw_headerdata
        headerdataaction = lw_headerdataaction
      TABLES
        itemdata         = li_itemdata
        itemdataaction   = li_itemdataaction
        return           = li_return.

    " Verificamos bloqueo de Transporte
    IF check_lock_vttk( iv_tknum = lv_shipment ) = abap_false.
      rv_success = abap_false.
      RETURN.
    ENDIF.

    "Limpia los datos de la primer ejecución de la BAPI
    CLEAR: lw_headerdata,
           lw_headerdataaction,
           li_itemdata[],
           li_itemdataaction[],
           li_return[].

    " Preparar datos para BAPI
    lw_headerdata-shipment_num = lv_shipment.

    lw_itemdata-delivery = iv_delivery.
    APPEND lw_itemdata TO li_itemdata.

    lw_itemdataaction-delivery = c_d. " Delete
    lw_itemdataaction-itenerary = c_d. " Delete
    APPEND lw_itemdataaction TO li_itemdataaction.

    " Ejecutar BAPI de modificación de embarque
    CALL FUNCTION 'BAPI_SHIPMENT_CHANGE'
      EXPORTING
        headerdata       = lw_headerdata
        headerdataaction = lw_headerdataaction
      TABLES
        itemdata         = li_itemdata
        itemdataaction   = li_itemdataaction
        return           = li_return.

    " Validar resultado
    rv_success = handle_errors( EXPORTING
                                  iv_salesorder = iv_salesorder
                                  iv_process = 'REVERSAR_DELIVERY'
                                  iv_status = 'ERROR'
                                  it_return = li_return ).

    IF rv_success = abap_true.
      " Commit de la transacción
      COMMIT WORK AND WAIT.
    ENDIF.

  ENDMETHOD.

  METHOD reverse_delivery.
    " Reversar entrega

    TYPES:
      BEGIN OF lty_lips,
        vbeln TYPE lips-vbeln,
        posnr TYPE lips-posnr,
      END OF lty_lips.

    DATA:
      lw_lips           TYPE lty_lips,
      lw_header_data    TYPE bapiobdlvhdrchg,
      lw_header_control TYPE bapiobdlvhdrctrlchg,
      lw_item_data      TYPE bapiobdlvitemchg,
      lw_item_control   TYPE bapiobdlvitemctrlchg.

    DATA:
      li_lips         TYPE TABLE OF lty_lips,
      li_item_data    TYPE TABLE OF bapiobdlvitemchg,
      li_item_control TYPE TABLE OF bapiobdlvitemctrlchg,
      li_return       TYPE TABLE OF bapiret2.

    " Obtener número de entrega
    SELECT vbeln
           posnr
      FROM lips
      INTO TABLE li_lips
      WHERE vbeln = iv_delivery.
    IF sy-subrc <> 0.
      " No hay transporte asociado
      rv_success = abap_true.
      RETURN.
    ENDIF.

    " Verificamos bloqueo de la entrega
    IF check_lock_likp( iv_vbeln = iv_delivery ) = abap_false.
      rv_success = abap_false.
      RETURN.
    ENDIF.

    " Configurar para borrado completo
    lw_header_data-deliv_numb = iv_delivery.
    lw_header_control-deliv_numb = iv_delivery.
    lw_header_control-dlv_del = c_x.

    LOOP AT li_lips INTO lw_lips.
      lw_item_data-deliv_numb = lw_lips-vbeln.
      lw_item_data-deliv_item = lw_lips-posnr.
      APPEND lw_item_data TO li_item_data.

      lw_item_control-deliv_numb = lw_lips-vbeln.
      lw_item_control-deliv_item = lw_lips-posnr.
      APPEND lw_item_control TO li_item_control.
    ENDLOOP.

    " Llamar BAPI para reversar
    CALL FUNCTION 'BAPI_OUTB_DELIVERY_CHANGE'
      EXPORTING
        header_data    = lw_header_data
        header_control = lw_header_control
        delivery       = iv_delivery
      TABLES
        item_data      = li_item_data
        item_control   = li_item_control
        return         = li_return.

    " Validar resultado
    rv_success = handle_errors( EXPORTING
                                  iv_salesorder = iv_salesorder
                                  iv_process = 'REVERSAR_DELIVERY'
                                  iv_status = 'ERROR'
                                  it_return = li_return ).

    IF rv_success = abap_true.
      " Commit de la transacción
      COMMIT WORK AND WAIT.
    ENDIF.

  ENDMETHOD.

  METHOD assign_reason_for_rejection.
    " Asignar motivo de rechazo

    DATA:
      lw_order_header_in  TYPE bapisdh1,
      lw_order_header_inx TYPE bapisdh1x,
      lw_order_item_in    TYPE bapisditm,
      lw_order_item_inx   TYPE bapisditmx.

    DATA:
      li_order_items_in  TYPE TABLE OF bapisditm,
      li_order_items_inx TYPE TABLE OF bapisditmx,
      li_return          TYPE TABLE OF bapiret2.

    DATA:
      lv_salesorder TYPE vbak-vbeln,
      lv_abgru      TYPE abgru.

    CLEAR: ev_reason_rej.

    "Obtiene motivo de rechazo
    SELECT SINGLE low                                   "#EC CI_NOORDER
      FROM tvarvc
      INTO lv_abgru
      WHERE name = 'ZSD_EXIST_FIC-MOTIVO_RECHAZO'
        AND type = 'P' ##WARN_OK.
    IF sy-subrc <> 0. "Falta parámetro en TVARV
      rv_success = abap_false.
      RETURN.
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

    " Validar resultado
    rv_success = handle_errors( EXPORTING
                                  iv_salesorder = iv_salesorder
                                  iv_process = 'RECHAZAR_PEDIDO'
                                  iv_status = 'ERROR'
                                  it_return = li_return ).

    IF rv_success = abap_true.
      " Commit de la transacción
      COMMIT WORK AND WAIT.

      ev_reason_rej = lv_abgru.

    ENDIF.

  ENDMETHOD.

  METHOD create_advance_order.
    " Crear pedido de anticipo
    " se deberá indicar Material de Servicio
    " con el precio del pedido previamente cancelado.
    " Todos los datos del cliente, destinatario, precio
    " se obtienen del pedido que se rechazó.

    DATA:
      lw_order_header_in     TYPE bapisdhd1,
      lw_order_header_inx    TYPE bapisdhd1x,
      lw_order_item_in       TYPE bapisditm,
      lw_order_item_inx      TYPE bapisditmx,
      lw_order_schedules_in  TYPE bapischdl,
      lw_order_schedules_inx TYPE bapischdlx,
      lw_conditions_in       TYPE bapicond,
      lw_conditions_inx      TYPE bapicondx,
      lw_order_partner       TYPE bapiparnr.

    DATA:
      li_order_items_in      TYPE TABLE OF bapisditm,
      li_order_items_inx     TYPE TABLE OF bapisditmx,
      li_order_partners      TYPE TABLE OF bapiparnr,
      li_order_schedules_in  TYPE TABLE OF bapischdl,
      li_order_schedules_inx TYPE TABLE OF bapischdlx,
      li_conditions_in       TYPE TABLE OF bapicond,
      li_conditions_inx      TYPE TABLE OF bapicondx,
      li_return              TYPE TABLE OF bapiret2.

    DATA:
      lv_material   TYPE matnr,
      lv_sales_unit TYPE meins.

    CLEAR: ev_vbeln_new.

    "Obtiene material
    SELECT SINGLE low                                   "#EC CI_NOORDER
      FROM tvarvc
      INTO lv_material
      WHERE name = 'ZSD_EXIST_FIC-MATERIAL_ANT'
        AND type = 'P' ##WARN_OK.
    IF sy-subrc <> 0. "Falta parámetro en TVARV
      rv_success = abap_false.
      RETURN.
    ENDIF.

    "Obtiene unidad de medida
    SELECT SINGLE low                                   "#EC CI_NOORDER
      FROM tvarvc
      INTO lv_sales_unit
      WHERE name = 'ZSD_EXIST_FIC-UOM_ANT'
        AND type = 'P' ##WARN_OK.
    IF sy-subrc <> 0. "Falta parámetro en TVARV
      rv_success = abap_false.
      RETURN.
    ENDIF.

    lv_material = |{ lv_material ALPHA = IN }|.

    " Consulta pedido cancelado
    SELECT p~vbeln, p~posnr, k~vkorg, k~vtweg, k~spart, k~kunnr,
           p~matnr, p~zmeng, p~meins, p~netwr, p~kwmeng, p~netpr,
           p~werks, p~waerk
      FROM vbak AS k INNER JOIN vbap AS p
          ON k~vbeln = p~vbeln
      INTO TABLE @DATA(li_salesorder_cancel)
      WHERE k~vbeln = @iv_vbeln_orig.
    IF sy-subrc <> 0.
      generate_process_log(
        iv_process = 'CREAR_ORDEN_ANTICIPO'
        iv_document = iv_vbeln_orig
        iv_status = 'ERROR'
        iv_message = |{ TEXT-003 } { iv_vbeln_orig } { TEXT-004 }| "Pedido original no encontrado
      ).
      RETURN.
    ENDIF.

    " Buscar datos del pedido cancelado
    READ TABLE li_salesorder_cancel INTO DATA(lw_salesorder_cancel)
                                    WITH KEY vbeln = iv_vbeln_orig.
    "No es necesario binary search se tratan de pocos registros
    IF  sy-subrc = 0.
      " Configurar cabecera del pedido de anticipo
      lw_order_header_in-doc_type = 'ZANT'.  "Tipo de pedido anticipo
      lw_order_header_in-sales_org = lw_salesorder_cancel-vkorg.
      lw_order_header_in-distr_chan = lw_salesorder_cancel-vtweg.
      lw_order_header_in-division = lw_salesorder_cancel-spart.
      lw_order_header_in-ord_reason = 'Z02'. "Producto incompleto
      lw_order_header_in-pymt_meth = '$'.
      lw_order_header_in-purch_no_c = |ANT-{ iv_vbeln_orig }|.

      lw_order_header_inx-updateflag = 'I'.
      lw_order_header_inx-doc_type   = 'X'.
      lw_order_header_inx-sales_org  = 'X'.
      lw_order_header_inx-distr_chan = 'X'.
      lw_order_header_inx-division   = 'X'.
      lw_order_header_inx-ord_reason = 'X'.
      lw_order_header_inx-pymt_meth  = 'X'.
      lw_order_header_inx-purch_no_c = 'X'.

      " Configurar partners
      lw_order_partner-partn_role = 'AG'.  " Solicitante
      lw_order_partner-partn_numb = lw_salesorder_cancel-kunnr.
      APPEND lw_order_partner TO li_order_partners.

      lw_order_partner-partn_role = 'WE'.  " Destinatario
      lw_order_partner-partn_numb = lw_salesorder_cancel-kunnr.
      APPEND lw_order_partner TO li_order_partners.
    ENDIF.

    " Configurar posición del anticipo
    lw_order_item_in-itm_number = '000010'.
    lw_order_item_in-material   = lv_material.
    lw_order_item_in-target_qty = 1.
    lw_order_item_in-sales_unit = lv_sales_unit.
    APPEND lw_order_item_in TO li_order_items_in.
    CLEAR: lw_order_item_in.

    lw_order_item_inx-updateflag = 'I'.
    lw_order_item_inx-itm_number = '000010'.
    lw_order_item_inx-material   = 'X'.
    lw_order_item_inx-target_qty = 'X'.
    lw_order_item_inx-sales_unit = 'X'.
    APPEND lw_order_item_inx TO li_order_items_inx.
    CLEAR lw_order_item_inx.

    lw_order_schedules_in-itm_number = '000010'.
    lw_order_schedules_in-sched_line = '0001'.
    lw_order_schedules_in-req_qty = 1.
    APPEND lw_order_schedules_in TO li_order_schedules_in.
    CLEAR: lw_order_schedules_in.

    lw_order_schedules_inx-updateflag = 'I'.
    lw_order_schedules_inx-itm_number = '000010'.
    lw_order_schedules_inx-sched_line = '0001'.
    lw_order_schedules_inx-req_qty = 'X'.
    APPEND lw_order_schedules_inx TO li_order_schedules_inx.
    CLEAR lw_order_schedules_inx.

    LOOP AT li_salesorder_cancel INTO lw_salesorder_cancel.

      "Agrega condiciones manuales
      lw_conditions_in-itm_number = '000010'.
      lw_conditions_in-cond_type = 'ZPM1'.
      lw_conditions_in-cond_value = lw_salesorder_cancel-netwr.
      lw_conditions_in-currency = lw_salesorder_cancel-waerk.
      COLLECT lw_conditions_in INTO li_conditions_in.
      CLEAR lw_conditions_in.

      lw_conditions_inx-updateflag = 'I'.
      lw_conditions_inx-itm_number = '000010'.
      lw_conditions_inx-cond_type = 'ZPM1'.
      lw_conditions_inx-cond_value = 'X'.
      lw_conditions_inx-currency = 'X'.
      COLLECT lw_conditions_inx INTO li_conditions_inx.
      CLEAR lw_conditions_inx.

    ENDLOOP.

    " Crear pedido de anticipo
    CALL FUNCTION 'BAPI_SALESORDER_CREATEFROMDAT2'
      EXPORTING
        order_header_in      = lw_order_header_in
        order_header_inx     = lw_order_header_inx
      IMPORTING
        salesdocument        = ev_vbeln_new
      TABLES
        return               = li_return
        order_items_in       = li_order_items_in
        order_items_inx      = li_order_items_inx
        order_partners       = li_order_partners
        order_schedules_in   = li_order_schedules_in
        order_schedules_inx  = li_order_schedules_inx
        order_conditions_in  = li_conditions_in
        order_conditions_inx = li_conditions_inx.

    " Validar resultado
    rv_success = handle_errors( EXPORTING
                                   iv_salesorder = iv_vbeln_orig
                                   iv_process = 'CREAR_ORDEN_ANTICIPO'
                                   iv_status = 'ERROR'
                                   it_return = li_return ).

    IF rv_success = abap_true.
      " Commit de la transacción
      COMMIT WORK AND WAIT.
    ENDIF.

  ENDMETHOD.

  METHOD create_advance_invoice.
    " Crear factura de anticipo

    DATA:
      lw_creatordatain TYPE bapicreatordata,
      lw_billingdatain TYPE bapivbrk,
      lw_success       TYPE bapivbrksuccess.

    DATA:
      li_billingdatain TYPE TABLE OF bapivbrk,
      li_return        TYPE TABLE OF bapiret2,
      li_success       TYPE TABLE OF bapivbrksuccess.

    DATA:
      lv_return TYPE sy-subrc.

    CLEAR: ev_invoice.

    " Configurar cabecera de la factura
    lw_creatordatain-created_by = sy-uname.
    lw_creatordatain-created_on = sy-datum.

    " Obtener posiciones del pedido de anticipo
    SELECT p~vbeln, p~posnr, k~vkorg, k~vtweg, k~spart, k~auart,
           k~waerk, p~matnr, p~werks, p~kwmeng, p~meins, p~netpr
      FROM vbak AS k INNER JOIN vbap AS p
         ON k~vbeln = p~vbeln
      INTO TABLE @DATA(li_pedido)
      WHERE k~vbeln = @iv_vbeln.
    IF sy-subrc <> 0.
      generate_process_log(
        iv_process = 'CREAR_FACTURA_ANTICIPO'
        iv_document = iv_vbeln_orig
        iv_status = 'ERROR'
        iv_message = |{ TEXT-006 } { iv_vbeln }{ TEXT-007 }| "Pedido no encontrado para crear factura
      ).
      RETURN.
    ENDIF.

    "Módulo de funciones Trigger WF
    CALL FUNCTION 'ZFM_SDWF_TRIGGER'
      EXPORTING
        i_vbeln   = iv_vbeln
        i_release = abap_true
      IMPORTING
        e_return  = lv_return.
    IF lv_return <> 0.
      generate_process_log(
        iv_process = 'CREAR_FACTURA_ANTICIPO'
        iv_document = iv_vbeln_orig
        iv_status = 'ERROR'
        iv_message = TEXT-027 "No se pudo liberar el pedido
      ).
      RETURN.
    ENDIF.

    "Documento comercial: Interlocutor
    SELECT parvw, kunnr
    FROM vbpa
    INTO TABLE @DATA(li_vbpa)
    WHERE vbeln = @iv_vbeln
      AND posnr = '000000'. " Solo interlocutores de cabecera
    IF sy-subrc = 0.
      " Buscamos el Solicitante (AG)
      READ TABLE li_vbpa INTO DATA(lw_vbpa)
                         WITH KEY parvw = 'AG'. " AG = Solicitante
      "No es necesario binary search se tratan de pocos registros
      IF sy-subrc = 0.
        DATA(lv_kunag) = lw_vbpa-kunnr.
      ENDIF.

      " Buscamos el Responsable de Pago (RG)
      READ TABLE li_vbpa INTO lw_vbpa
                         WITH KEY parvw = 'RG'. " RG = Resp. Pago
      "No es necesario binary search se tratan de pocos registros
      IF sy-subrc = 0.
        DATA(lv_kunrg) = lw_vbpa-kunnr.
      ELSE.
        " Si no hay RG específico, suele ser el mismo solicitante
        lv_kunrg = lv_kunag.
      ENDIF.
    ENDIF.

    " Configurar posiciones de la factura
    LOOP AT li_pedido INTO DATA(lw_pedido).
      lw_billingdatain-salesorg   = lw_pedido-vkorg.
      lw_billingdatain-distr_chan = lw_pedido-vtweg.
      lw_billingdatain-division   = lw_pedido-spart.
      lw_billingdatain-doc_type   = 'ZANT'.
      lw_billingdatain-bill_date  = sy-datum.
      lw_billingdatain-sold_to    = lv_kunag. " Solicitante
      lw_billingdatain-plant      = lw_pedido-werks.
      lw_billingdatain-payer      = lv_kunrg. " Responsable de pago
      lw_billingdatain-ref_doc    = lw_pedido-vbeln.
      lw_billingdatain-ref_item   = lw_pedido-posnr.
      lw_billingdatain-material   = lw_pedido-matnr.
      lw_billingdatain-req_qty    = lw_pedido-kwmeng.
      lw_billingdatain-ref_doc_ca = 'C'. "En base a pedido
      APPEND lw_billingdatain TO li_billingdatain.
      CLEAR lw_billingdatain.
    ENDLOOP.

    " Crear factura de anticipo
    CALL FUNCTION 'BAPI_BILLINGDOC_CREATEMULTIPLE'
      EXPORTING
        creatordatain = lw_creatordatain
      TABLES
        billingdatain = li_billingdatain
        return        = li_return
        success       = li_success.

    " Validar resultado
    rv_success = handle_errors( EXPORTING
                                  iv_salesorder = iv_vbeln_orig
                                  iv_process = 'CREAR_FACTURA_ANTICIPO'
                                  iv_status = 'ERROR'
                                  it_return = li_return ).

    READ TABLE li_success INTO lw_success INDEX 1.
    "No es necesario binary search se tratan de pocos registros
    IF sy-subrc = 0.
      ev_invoice = lw_success-bill_doc.
    ENDIF.

    IF rv_success = abap_true AND ev_invoice IS NOT INITIAL.
      " Commit de la transacción
      COMMIT WORK AND WAIT.
    ENDIF.

  ENDMETHOD.

  METHOD create_consumption_order.
    " Crear pedido de consumo relacionado al anticipo

    DATA:
      lw_order_header_in     TYPE bapisdhd1,
      lw_order_header_inx    TYPE bapisdhd1x,
      lw_order_item_in       TYPE bapisditm,
      lw_order_item_inx      TYPE bapisditmx,
      lw_order_schedules_in  TYPE bapischdl,
      lw_order_schedules_inx TYPE bapischdlx,
      lw_extensionin         TYPE bapiparex,
      lw_order_partner       TYPE bapiparnr,
      lw_bape_vbak           TYPE bape_vbak,
      lw_bape_vbakx          TYPE bape_vbakx.

    DATA:
      li_order_items_in      TYPE TABLE OF bapisditm,
      li_order_items_inx     TYPE TABLE OF bapisditmx,
      li_order_partners      TYPE TABLE OF bapiparnr,
      li_order_schedules_in  TYPE TABLE OF bapischdl,
      li_order_schedules_inx TYPE TABLE OF bapischdlx,
      li_extensionin         TYPE TABLE OF bapiparex,
      li_conditions_in       TYPE TABLE OF bapicond,
      li_return              TYPE TABLE OF bapiret2.

    CONSTANTS:
      lc_bape_vbak  TYPE char9  VALUE 'BAPE_VBAK',
      lc_bape_vbakx TYPE char10 VALUE 'BAPE_VBAKX'.

    CLEAR: ev_consumption_order.

    " Consulta pedido cancelado
    SELECT p~vbeln, p~posnr, k~vkorg, k~vtweg, k~spart, k~kunnr,
           p~matnr, p~zmeng, p~zieme, p~meins, p~netwr, p~kwmeng,
           p~netpr, p~werks
      FROM vbak AS k INNER JOIN vbap AS p
          ON k~vbeln = p~vbeln
      INTO TABLE @DATA(li_salesorder_cancel)
      WHERE k~vbeln = @iv_vbeln_orig.
    IF sy-subrc <> 0.
      generate_process_log(
        iv_process = 'CREAR_ORDER_CONSUMO'
        iv_document = iv_vbeln_orig
        iv_status = 'ERROR'
        iv_message = |{ TEXT-003 } { iv_salesorder_ant } { TEXT-004 }| "Pedido original no encontrado
      ).
      RETURN.
    ENDIF.

    "Monitor existencia ficticia
    SELECT vbeln, posnr, matnr, lfimg, meins, rfmng, difference
      FROM ztasd_exfic_mon
      INTO TABLE @DATA(li_exfic_mon)
      WHERE vbeln = @iv_vbeln_orig.
    IF sy-subrc = 0.
      SORT li_exfic_mon BY vbeln posnr.
    ENDIF.

    " Verificamos bloqueo de factura
    IF check_lock_vbrk( iv_vbeln = iv_invoice_ant ) = abap_false.
      rv_success = abap_false.
      RETURN.
    ENDIF.

    " Buscar datos del pedido cancelado
    READ TABLE li_salesorder_cancel INTO DATA(lw_salesorder_cancel)
                                    WITH KEY vbeln = iv_vbeln_orig.
    "No es necesario binary search se tratan de pocos registros
    IF sy-subrc = 0.
      " Configurar cabecera del pedido de anticipo
      lw_order_header_in-doc_type = 'ZVM1'.  " Tipo de pedido consumo
      lw_order_header_in-sales_org = lw_salesorder_cancel-vkorg.
      lw_order_header_in-distr_chan = lw_salesorder_cancel-vtweg.
      lw_order_header_in-division = lw_salesorder_cancel-spart.
      lw_order_header_in-purch_no_c = |CONS-{ iv_salesorder_ant }|.
      lw_order_header_in-ref_doc    = iv_invoice_ant.
      lw_order_header_in-refdoc_cat = 'M'.
      lw_order_header_in-dlv_block  = 'Z2'.
      lw_order_header_in-pymt_meth  = '$'.

      lw_order_header_inx-updateflag = 'I'.
      lw_order_header_inx-doc_type   = 'X'.
      lw_order_header_inx-sales_org  = 'X'.
      lw_order_header_inx-distr_chan = 'X'.
      lw_order_header_inx-division   = 'X'.
      lw_order_header_inx-purch_no_c = 'X'.
      lw_order_header_inx-ref_doc    = 'X'.
      lw_order_header_inx-refdoc_cat = 'X'.
      lw_order_header_inx-dlv_block  = 'X'.
      lw_order_header_inx-pymt_meth  = 'X'.

      " Configurar partners
      lw_order_partner-partn_role = 'AG'.  " Solicitante
      lw_order_partner-partn_numb = lw_salesorder_cancel-kunnr.
      APPEND lw_order_partner TO li_order_partners.

      lw_order_partner-partn_role = 'WE'.  " Destinatario
      lw_order_partner-partn_numb = lw_salesorder_cancel-kunnr.
      APPEND lw_order_partner TO li_order_partners.
    ENDIF.

    LOOP AT li_salesorder_cancel INTO lw_salesorder_cancel.

      READ TABLE li_exfic_mon INTO DATA(lw_exfic_mon)
                              WITH KEY vbeln = lw_salesorder_cancel-vbeln
                                       posnr = lw_salesorder_cancel-posnr
                              BINARY SEARCH.
      IF sy-subrc = 0.

        " Configurar posición del anticipo
        lw_order_item_in-itm_number = lw_salesorder_cancel-posnr.
        lw_order_item_in-material   = lw_salesorder_cancel-matnr.
        lw_order_item_in-plant      = lw_salesorder_cancel-werks.
        lw_order_item_in-store_loc  = 'MERC'.
        lw_order_item_in-target_qty = lw_exfic_mon-rfmng.
        lw_order_item_in-sales_unit = lw_salesorder_cancel-zieme.
        APPEND lw_order_item_in TO li_order_items_in.
        CLEAR: lw_order_item_in.

        lw_order_item_inx-updateflag = 'I'.
        lw_order_item_inx-itm_number = lw_salesorder_cancel-posnr.
        lw_order_item_inx-material   = 'X'.
        lw_order_item_inx-plant      = 'X'.
        lw_order_item_inx-store_loc  = 'X'.
        lw_order_item_inx-target_qty = 'X'.
        lw_order_item_inx-sales_unit = 'X'.
        APPEND lw_order_item_inx TO li_order_items_inx.
        CLEAR lw_order_item_inx.

        lw_order_schedules_in-itm_number = lw_salesorder_cancel-posnr.
        lw_order_schedules_in-sched_line = '0001'.
        lw_order_schedules_in-req_date   = sy-datum.
        lw_order_schedules_in-req_qty    = lw_exfic_mon-rfmng.
        lw_order_schedules_in-tp_date    = sy-datum.
        lw_order_schedules_in-ms_date    = sy-datum.
        lw_order_schedules_in-load_date  = sy-datum.
        lw_order_schedules_in-gi_date    = sy-datum.
        APPEND lw_order_schedules_in TO li_order_schedules_in.
        CLEAR: lw_order_schedules_in.

        lw_order_schedules_inx-updateflag = 'I'.
        lw_order_schedules_inx-itm_number = lw_salesorder_cancel-posnr.
        lw_order_schedules_inx-sched_line = '0001'.
        lw_order_schedules_inx-req_date   = 'X'.
        lw_order_schedules_inx-req_qty    = 'X'.
        lw_order_schedules_inx-tp_date    = 'X'.
        lw_order_schedules_inx-ms_date    = 'X'.
        lw_order_schedules_inx-load_date  = 'X'.
        lw_order_schedules_inx-gi_date    = 'X'.
        APPEND lw_order_schedules_inx TO li_order_schedules_inx.
        CLEAR lw_order_schedules_inx.

      ENDIF.

    ENDLOOP.

    lw_bape_vbak-zzanticipos  = iv_invoice_ant.
    lw_extensionin-structure  = lc_bape_vbak.
    lw_extensionin-valuepart1 = lw_bape_vbak ##ENH_OK.
    APPEND lw_extensionin TO li_extensionin.

    lw_bape_vbakx-zzanticipos = 'X'.
    lw_extensionin-structure  = lc_bape_vbakx.
    lw_extensionin-valuepart1 = lw_bape_vbakx ##ENH_OK.
    APPEND lw_extensionin TO li_extensionin.

    " Crear pedido de consumo relacionado al anticipo
    CALL FUNCTION 'BAPI_SALESORDER_CREATEFROMDAT2'
      EXPORTING
        order_header_in     = lw_order_header_in
        order_header_inx    = lw_order_header_inx
      IMPORTING
        salesdocument       = ev_consumption_order
      TABLES
        return              = li_return
        order_items_in      = li_order_items_in
        order_items_inx     = li_order_items_inx
        order_partners      = li_order_partners
        order_schedules_in  = li_order_schedules_in
        order_schedules_inx = li_order_schedules_inx
        order_conditions_in = li_conditions_in
        extensionin         = li_extensionin.

    " Validar resultado
    rv_success = handle_errors( EXPORTING
                                  iv_salesorder = iv_vbeln_orig
                                  iv_process = 'CREAR_ORDER_CONSUMO'
                                  iv_status = 'ERROR'
                                  it_return = li_return ).

    IF rv_success = abap_true AND ev_consumption_order IS NOT INITIAL.
      " Commit de la transacción
      COMMIT WORK AND WAIT.
    ENDIF.

  ENDMETHOD.

  METHOD create_consumption_delivery.
    " Crear delivery para pedido de anticipo

    DATA:
      lw_vbkok TYPE vbkok,
      lw_vbpok TYPE vbpok.

    DATA:
      li_vbpok TYPE STANDARD TABLE OF vbpok,
      li_prot  TYPE STANDARD TABLE OF prott.

    DATA:
      lv_lifsk    TYPE vbak-lifsk,
      lv_return   TYPE sy-subrc,
      lv_message  TYPE char255,
      lv_messages TYPE char255,
      lv_cont     TYPE i.

    CLEAR: ev_delivery.

    " Verificamos bloqueo del pedido
    IF check_lock_vbak( iv_vbeln = iv_vbeln ) = abap_false.
      rv_success = abap_false.
      RETURN.
    ENDIF.

    "Hace la consulta al pedido y se expera un maxímo de 5 intentos
    CLEAR lv_cont.
    WHILE lv_cont < 5 AND lv_lifsk IS INITIAL.
      " Consulta si el pedido tiene bloqueo de entrega
      SELECT SINGLE lifsk
        FROM vbak ##WARN_OK
        INTO lv_lifsk
        WHERE vbeln = iv_vbeln.
      IF sy-subrc = 0.
        IF lv_lifsk IS NOT INITIAL.
          "Desbloquea el peido para realizar la entrega
          CALL FUNCTION 'ZFM_SDWF_TRIGGER'
            EXPORTING
              i_vbeln   = iv_vbeln
              i_release = abap_true
            IMPORTING
              e_return  = lv_return.
          CLEAR lv_lifsk.
          WAIT UP TO 1 SECONDS.
          lv_cont = lv_cont + 1.
        ELSE.
          EXIT.
        ENDIF.
      ENDIF.
    ENDWHILE.

    IF lv_return <> 0.
      generate_process_log(
        iv_process = 'CREAR_ENTREGA_CONSUMO'
        iv_document = iv_vbeln_orig
        iv_status = 'ERROR'
        iv_message = TEXT-027 "No se pudo liberar el pedido
      ).
      RETURN.
    ENDIF.

    "Hace la consulta de la entrega y se expera un maxímo de 5 intentos
    "de un segundo a la vez
    CLEAR lv_cont.
    WHILE lv_cont < 5 AND ev_delivery IS INITIAL.
      " Obtiene información de la entrega creada
      SELECT SINGLE vbeln
        FROM vbfa ##WARN_OK
        INTO ev_delivery
        WHERE vbelv = iv_vbeln
          AND vbtyp_n = 'J'.                            "#EC CI_NOORDER
      IF sy-subrc <> 0.
        WAIT UP TO 1 SECONDS.
        lv_cont = lv_cont + 1.
      ELSE.
        EXIT.
      ENDIF.
    ENDWHILE.

    IF ev_delivery IS NOT INITIAL.

      " Verificamos bloqueo de la entrega
      IF check_lock_likp( iv_vbeln = ev_delivery ) = abap_false.
        rv_success = abap_false.
        RETURN.
      ENDIF.

      " Actualizar cantidad de picking en la entrega creada
      lw_vbkok-vbeln_vl = ev_delivery.

      "Doc.comercial: Entrega - Datos de posición
      SELECT vbeln, posnr, matnr, lfimg, meins, werks, lgort
        FROM lips
        INTO TABLE @DATA(li_lips)
        WHERE vbeln = @ev_delivery.

      LOOP AT li_lips INTO DATA(lw_lips).
        lw_vbpok-vbeln_vl = lw_lips-vbeln.
        lw_vbpok-posnr_vl = lw_lips-posnr.
        lw_vbpok-vbeln    = lw_lips-vbeln.
        lw_vbpok-posnn    = lw_lips-posnr.
        lw_vbpok-matnr    = lw_lips-matnr.
        lw_vbpok-meins    = lw_lips-meins.
        lw_vbpok-werks    = lw_lips-werks.
        lw_vbpok-lgort    = lw_lips-lgort.
        lw_vbpok-lfimg    = lw_lips-lfimg.
        lw_vbpok-pikmg    = lw_lips-lfimg.  " Asignar cantidad de picking
        APPEND lw_vbpok TO li_vbpok.
      ENDLOOP.

      " Actualiza entrega picking y contabilización de salida de mercancías
      CALL FUNCTION 'WS_DELIVERY_UPDATE'
        EXPORTING
          vbkok_wa       = lw_vbkok
          synchron       = c_x
          commit         = c_x
          update_picking = c_x
          delivery       = ev_delivery
        TABLES
          vbpok_tab      = li_vbpok
          prot           = li_prot.

      " Manejo de errores en caso de fallo en el picking
      READ TABLE li_prot TRANSPORTING NO FIELDS WITH KEY msgty = 'E'.
      IF sy-subrc <> 0.
        " Si falla el picking, la entrega existe pero no podrá procesarse luego
        rv_success = abap_true.

      ELSE.

        LOOP AT li_prot INTO DATA(lw_prot).

          IF lw_prot-msgty = 'E'.
            MESSAGE ID lw_prot-msgid TYPE lw_prot-msgty
                                     NUMBER lw_prot-msgno
                                     WITH lw_prot-msgv1
                                          lw_prot-msgv2
                                          lw_prot-msgv3
                                          lw_prot-msgv4
                                     INTO lv_message.

            lv_messages = |{ lv_messages }/{ lv_message }|.
          ENDIF.

        ENDLOOP.
        CLEAR lv_messages(1). CONDENSE lv_messages.

        generate_process_log(
          iv_process  = 'CREAR_ENTREGA_CONSUMO'
          iv_document = iv_vbeln_orig
          iv_status   = 'ERROR'
          iv_message  = lv_messages
      ).

        rv_success = abap_false.
      ENDIF.

    ELSE.

      generate_process_log(
        iv_process = 'CREAR_ENTREGA_CONSUMO'
        iv_document = iv_vbeln_orig
        iv_status = 'ERROR'
        iv_message = TEXT-027 "No se pudo liberar el pedido
      ).

    ENDIF.

  ENDMETHOD.

  METHOD create_post_goods_issue.
    " Contabilizar salida de mercancías (Post Goods Issue) para la entrega de consumo
    " Equivalente programático a VL02N Contabilizar salida de mercancías
    " Se usa WS_DELIVERY_UPDATE con el flag WABUC = 'X'

    DATA:
      lw_vbkok TYPE vbkok,
      lw_vbpok TYPE vbpok.

    DATA:
      li_vbpok TYPE STANDARD TABLE OF vbpok,
      li_prot  TYPE STANDARD TABLE OF prott.

    DATA:
      lv_message  TYPE char255,
      lv_messages TYPE char255,
      lv_cont     TYPE i.

    CLEAR: ev_pgi.

    " Obtener posiciones de la entrega desde LIPS
    SELECT vbeln, posnr, matnr, lfimg, meins, lgort, werks
      FROM lips
      INTO TABLE @DATA(li_lips)
      WHERE vbeln = @iv_delivery.
    IF sy-subrc <> 0.
      generate_process_log(
        iv_process  = 'POST_GOODS_ISSUE'
        iv_document = iv_vbeln_orig
        iv_status   = 'ERROR'
        iv_message  = |Entrega { iv_delivery } no tiene posiciones en LIPS|
      ).
      RETURN.
    ENDIF.

    " Configurar cabecera de control (VBKOK)
    lw_vbkok-vbeln_vl = iv_delivery.     " Número de entrega
    lw_vbkok-wabuc    = c_x.             " Flag: Contabilizar salida de mercancías

    " Configurar posiciones de control (VBPOK)
    LOOP AT li_lips INTO DATA(lw_lips).
      CLEAR lw_vbpok.
      lw_vbpok-vbeln_vl = lw_lips-vbeln. " Número de entrega
      lw_vbpok-posnr_vl = lw_lips-posnr. " Posición de entrega
      lw_vbpok-vbeln    = lw_lips-vbeln. " Número de entrega
      lw_vbpok-posnn    = lw_lips-posnr. " Posición de entrega
      lw_vbpok-matnr    = lw_lips-matnr. " Material
      lw_vbpok-lfimg    = lw_lips-lfimg. " Cantidad entregada
      lw_vbpok-meins    = lw_lips-meins. " Unidad de medida
      lw_vbpok-lgort    = lw_lips-lgort. " Almacén
      lw_vbpok-werks    = lw_lips-werks. " Centro
      APPEND lw_vbpok TO li_vbpok.
    ENDLOOP.

    " Ejecutar Post Goods Issue mediante WS_DELIVERY_UPDATE
    CALL FUNCTION 'WS_DELIVERY_UPDATE'
      EXPORTING
        vbkok_wa  = lw_vbkok
        synchron  = c_x        " Ejecución síncrona
        commit    = c_x        " Commit automático
        delivery  = iv_delivery
      TABLES
        vbpok_tab = li_vbpok
        prot      = li_prot.

    " Verificar errores en tabla de protocolo
    READ TABLE li_prot TRANSPORTING NO FIELDS WITH KEY msgty = 'E'.
    IF sy-subrc <> 0.

      rv_success = abap_true.

      WHILE lv_cont < 5 AND ev_pgi IS INITIAL.
        SELECT SINGLE vbeln
          FROM vbfa ##WARN_OK
          INTO @ev_pgi
          WHERE vbelv = @iv_delivery
            AND vbtyp_n = 'R'.                          "#EC CI_NOORDER
        IF sy-subrc <> 0.
          WAIT UP TO 1 SECONDS.
          lv_cont = lv_cont + 1.
        ENDIF.
      ENDWHILE.

    ELSE.

      LOOP AT li_prot INTO DATA(lw_prot).

        IF lw_prot-msgty = 'E'.
          MESSAGE ID lw_prot-msgid TYPE lw_prot-msgty
                                   NUMBER lw_prot-msgno
                                   WITH lw_prot-msgv1
                                        lw_prot-msgv2
                                        lw_prot-msgv3
                                        lw_prot-msgv4
                                   INTO lv_message.

          lv_messages = |{ lv_messages }/{ lv_message }|.
        ENDIF.

      ENDLOOP.
      CLEAR lv_messages(1). CONDENSE lv_messages.

      generate_process_log(
        iv_process  = 'CREAR_ENTREGA_CONSUMO'
        iv_document = iv_vbeln_orig
        iv_status   = 'ERROR'
        iv_message  = lv_messages
    ).
    ENDIF.

  ENDMETHOD.

  METHOD create_consumption_transport.
    " Crear transporte y asigna la entrega

    DATA:
      lw_headerdata TYPE bapishipmentheader,
      lw_itemdata   TYPE bapishipmentitem.

    DATA:
      li_itemdata TYPE TABLE OF bapishipmentitem,
      li_return   TYPE TABLE OF bapiret2.

    CLEAR: ev_shipment.

    " Configurar cabecera del transporte
    lw_headerdata-shipment_type = 'ZTU1'.  " Tipo de transporte
    lw_headerdata-trans_plan_pt = '3030'.

    " Obtener datos del delivery para configurar transporte
    SELECT kunnr, werks
      UP TO 1 ROWS
      FROM likp
      INTO @DATA(lw_delivery_data) ##NEEDED
      WHERE vbeln = @iv_delivery.
    ENDSELECT.
    IF sy-subrc <> 0.
      generate_process_log(
        iv_process = 'CREAR_TRANSPORTE_CONSUMO'
        iv_document = iv_vbeln_orig
        iv_status = 'ERROR'
        iv_message = |{ TEXT-002 } { iv_delivery } { TEXT-005 }|  "Entrega no encontrado para crear transporte
      ).
      RETURN.
    ENDIF.

    " Configurar delivery en el transporte
    lw_itemdata-delivery = iv_delivery.
    lw_itemdata-itenerary = '0010'.
    APPEND lw_itemdata TO li_itemdata.

    " Crear transporte y asigna la entrega
    CALL FUNCTION 'BAPI_SHIPMENT_CREATE'
      EXPORTING
        headerdata = lw_headerdata
      IMPORTING
        transport  = ev_shipment
      TABLES
        itemdata   = li_itemdata
        return     = li_return.

    " Validar resultado
    rv_success = handle_errors( EXPORTING
                                  iv_salesorder = iv_vbeln_orig
                                  iv_process = 'CREAR_TRANSPORTE_CONSUMO'
                                  iv_status = 'ERROR'
                                  it_return = li_return ).

    IF rv_success = abap_true AND ev_shipment IS NOT INITIAL.
      " Commit de la transacción
      COMMIT WORK AND WAIT.
    ENDIF.

  ENDMETHOD.

  METHOD create_consumption_invoice.
    " Crear factura de anticipo

    DATA:
      lw_creatordatain TYPE bapicreatordata,
      lw_billingdatain TYPE bapivbrk,
      lw_success       TYPE bapivbrksuccess.

    DATA:
      li_billingdatain TYPE TABLE OF bapivbrk,
      li_return        TYPE TABLE OF bapiret2,
      li_success       TYPE TABLE OF bapivbrksuccess.

    DATA:
      lv_return TYPE sy-subrc.

    CLEAR: ev_invoice.

    " Configurar cabecera de la factura
    lw_creatordatain-created_by = sy-uname.
    lw_creatordatain-created_on = sy-datum.

    " Obtener posiciones del pedido de anticipo
    SELECT p~vbeln, p~posnr, k~vkorg, k~vtweg, k~spart, k~auart,
           k~waerk, p~matnr, p~werks, p~kwmeng, p~meins, p~netpr
      FROM vbak AS k INNER JOIN vbap AS p
         ON k~vbeln = p~vbeln
      INTO TABLE @DATA(li_pedido)
      WHERE k~vbeln = @iv_vbeln.
    IF sy-subrc <> 0.
      generate_process_log(
        iv_process = 'CREATE_FACTURA_CONSUMO'
        iv_document = iv_vbeln_orig
        iv_status = 'ERROR'
        iv_message = |{ TEXT-006 } { iv_vbeln }{ TEXT-007 }| "Pedido no encontrado para crear factura
      ).
      RETURN.
    ENDIF.

    "Módulo de funciones Trigger WF
    CALL FUNCTION 'ZFM_SDWF_TRIGGER'
      EXPORTING
        i_vbeln   = iv_vbeln
        i_release = abap_true
      IMPORTING
        e_return  = lv_return.
    IF lv_return <> 0.
      generate_process_log(
        iv_process = 'CREATE_FACTURA_CONSUMO'
        iv_document = iv_vbeln_orig
        iv_status = 'ERROR'
        iv_message = TEXT-027 "No se pudo liberar el pedido
      ).
      RETURN.
    ENDIF.

    "Documento comercial: Interlocutor
    SELECT parvw, kunnr
    FROM vbpa
    INTO TABLE @DATA(li_vbpa)
    WHERE vbeln = @iv_vbeln
      AND posnr = '000000'. " Solo interlocutores de cabecera
    IF sy-subrc = 0.
      " Buscamos el Solicitante (AG)
      READ TABLE li_vbpa INTO DATA(lw_vbpa)
                         WITH KEY parvw = 'AG'. " AG = Solicitante
      "No es necesario binary search se tratan de pocos registros
      IF sy-subrc = 0.
        DATA(lv_kunag) = lw_vbpa-kunnr.
      ENDIF.

      " Buscamos el Responsable de Pago (RG)
      READ TABLE li_vbpa INTO lw_vbpa
                         WITH KEY parvw = 'RG'. " RG = Resp. Pago
      "No es necesario binary search se tratan de pocos registros
      IF sy-subrc = 0.
        DATA(lv_kunrg) = lw_vbpa-kunnr.
      ELSE.
        " Si no hay RG específico, suele ser el mismo solicitante
        lv_kunrg = lv_kunag.
      ENDIF.
    ENDIF.

    "Obtiene la entrega
    SELECT SINGLE vbeln
      FROM vbfa ##WARN_OK
      INTO @DATA(lv_delivery)
      WHERE vbelv = @iv_vbeln
        AND vbtyp_n = 'J'.                              "#EC CI_NOORDER

    " Configurar posiciones de la factura
    LOOP AT li_pedido INTO DATA(lw_pedido).
      lw_billingdatain-salesorg   = lw_pedido-vkorg.
      lw_billingdatain-distr_chan = lw_pedido-vtweg.
      lw_billingdatain-division   = lw_pedido-spart.
      lw_billingdatain-doc_type   = 'ZIF2'.
      lw_billingdatain-bill_date  = sy-datum.
      lw_billingdatain-sold_to    = lv_kunag.         " Solicitante
      lw_billingdatain-payer      = lv_kunrg.         " Responsable de pago
      lw_billingdatain-plant      = lw_pedido-werks.
      lw_billingdatain-ref_doc    = lv_delivery.
      lw_billingdatain-ref_item   = lw_pedido-posnr.
      lw_billingdatain-material   = lw_pedido-matnr.
      lw_billingdatain-req_qty    = lw_pedido-kwmeng.
      lw_billingdatain-ref_doc_ca = 'J'.              " En base a la entrega
      APPEND lw_billingdatain TO li_billingdatain.
      CLEAR lw_billingdatain.
    ENDLOOP.

    " Crear factura de anticipo
    CALL FUNCTION 'BAPI_BILLINGDOC_CREATEMULTIPLE'
      EXPORTING
        creatordatain = lw_creatordatain
      TABLES
        billingdatain = li_billingdatain
        return        = li_return
        success       = li_success.

    " Validar resultado
    rv_success = handle_errors( EXPORTING
                                  iv_salesorder = iv_vbeln_orig
                                  iv_process = 'CREATE_FACTURA_CONSUMO'
                                  iv_status = 'ERROR'
                                  it_return = li_return ).

    READ TABLE li_success INTO lw_success INDEX 1.
    "No es necesario binary search se tratan de pocos registros
    IF sy-subrc = 0.
      ev_invoice = lw_success-bill_doc.
    ENDIF.

    IF rv_success = abap_true AND ev_invoice IS NOT INITIAL.
      " Commit de la transacción
      COMMIT WORK AND WAIT.
    ENDIF.

  ENDMETHOD.

  METHOD get_order_advance_creditmemo.
    " Se crea sol. nota de crédito para cancelar el anticipo
    " con el valor de la factura emitida en el paso

    CLEAR: ev_creditmemo_request.

    "Consulta pedido del flujo de documento
    SELECT f~vbelv, f~posnv, f~vbeln, f~posnn, f~vbtyp_n
      FROM vbfa AS f INNER JOIN vbak AS k
        ON f~vbeln = k~vbeln
    INTO TABLE @DATA(li_vbfa)
    WHERE f~vbelv = @iv_invoice_ant
      AND f~vbtyp_n = 'K'
      AND k~auart = 'ZNCA'.                             "#EC CI_NOORDER
    IF sy-subrc = 0.
      READ TABLE li_vbfa INTO DATA(lw_vbfa) INDEX 1.    "#EC CI_NOORDER
      IF sy-subrc = 0.
        ev_creditmemo_request = lw_vbfa-vbeln.
        rv_success = abap_true.
      ENDIF.
    ENDIF.

  ENDMETHOD.

  METHOD get_invoice_advance_creditmemo.
    " Se Crea N/C de anticipo ZNCA Nota de crédito
    " se timbra relaciona a la Factura de Anticipo.

    CLEAR: ev_creditmemo_invoice.

    "Consulta pedido del flujo de documento
    SELECT vbelv, posnv, vbeln, posnn, vbtyp_n
      FROM vbfa
    INTO TABLE @DATA(li_vbfa)
    WHERE vbelv = @iv_creditmemo_request
      AND vbtyp_n = 'O'.                                "#EC CI_NOORDER
    IF sy-subrc = 0.
      READ TABLE li_vbfa INTO DATA(lw_vbfa) INDEX 1.    "#EC CI_NOORDER
      IF sy-subrc = 0.
        ev_creditmemo_invoice  = lw_vbfa-vbeln.
        rv_success = abap_true.
      ENDIF.
    ENDIF.

  ENDMETHOD.

  METHOD get_order_bonus_creditmemo.
    " Se crea sol. nota de crédito ZCRE para cancelar anticipo
    " con el valor de la diferencia entre lo consumido y el remanente.

    CLEAR: ev_creditmemo_bonus.

    "Consulta pedido del flujo de documento
    SELECT f~vbelv, f~posnv, f~vbeln, f~posnn, f~vbtyp_n
      FROM vbfa AS f INNER JOIN vbak AS k
        ON f~vbeln = k~vbeln
    INTO TABLE @DATA(li_vbfa)
    WHERE f~vbelv = @iv_invoice_ant
      AND f~vbtyp_n = 'K'
      AND k~auart = 'ZCRE'.                             "#EC CI_NOORDER
    IF sy-subrc = 0.
      READ TABLE li_vbfa INTO DATA(lw_vbfa) INDEX 1.    "#EC CI_NOORDER
      IF sy-subrc = 0.
        ev_creditmemo_bonus = lw_vbfa-vbeln.
        rv_success = abap_true.
      ENDIF.
    ENDIF.

  ENDMETHOD.

  METHOD get_invoice_bonus_creditmemo.
    " Crear nota de crédito de anticipo por diferencia de monto

    CLEAR: ev_creditmemo_invoice.

    "Consulta pedido del flujo de documento
    SELECT vbelv, posnv, vbeln, posnn, vbtyp_n
      FROM vbfa
    INTO TABLE @DATA(li_vbfa)
    WHERE vbelv = @iv_creditmemo_bonus
      AND vbtyp_n = 'O'.                                "#EC CI_NOORDER
    IF sy-subrc = 0.
      READ TABLE li_vbfa INTO DATA(lw_vbfa) INDEX 1.    "#EC CI_NOORDER
      IF sy-subrc = 0.
        ev_creditmemo_invoice  = lw_vbfa-vbeln.
        rv_success = abap_true.
      ENDIF.
    ENDIF.

  ENDMETHOD.

  METHOD handle_errors.
    " Manejo centralizado de errores de BAPIs

    DATA:
      lv_message  TYPE char255,
      lv_messages TYPE char255.

    rv_error = abap_true.

    LOOP AT it_return ASSIGNING FIELD-SYMBOL(<lfs_return>).
      IF <lfs_return>-type = c_e.
        MESSAGE ID <lfs_return>-id TYPE <lfs_return>-type
                                   NUMBER <lfs_return>-number
                                     WITH <lfs_return>-message_v1
                                          <lfs_return>-message_v2
                                          <lfs_return>-message_v3
                                          <lfs_return>-message_v4 INTO lv_message.

        lv_messages = |{ lv_messages }/{ lv_message }|.
      ENDIF.
    ENDLOOP.
    CLEAR lv_messages(1). CONDENSE lv_messages.

    IF lv_messages IS NOT INITIAL.

      " Log del error
      generate_process_log(
        iv_process = iv_process
        iv_document = iv_salesorder
        iv_status = iv_status
        iv_message = |{ lv_messages }|
      ).

      rv_error = abap_false.

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
          " Desbloquea factura
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

  METHOD generate_process_log.
    " Generar log de proceso en tabla Z

    DATA:
      li_exfic_log TYPE TABLE OF ztasd_exfic_log.

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
      MOVE-CORRESPONDING i_log TO li_exfic_log.
      MODIFY ztasd_exfic_log FROM TABLE li_exfic_log.
      COMMIT WORK.
    ENDIF.

  ENDMETHOD.

  METHOD validate_authorizations.
    " Validar autorizaciones del usuario

    LOOP AT iv_goods_assumtion INTO DATA(lw_goods_assumtion).

      " Validación de autorización a organización de ventas
      AUTHORITY-CHECK OBJECT 'V_VBAK_VKO'
                           ID 'VKORG' FIELD lw_goods_assumtion-vkorg
                           ID 'VTWEG' FIELD lw_goods_assumtion-vtweg
                           ID 'SPART' FIELD lw_goods_assumtion-spart
                           ID 'ACTVT' FIELD '03'.

      IF sy-subrc <> 0.
        DELETE iv_goods_assumtion INDEX sy-tabix.
        CONTINUE.
      ENDIF.

      " Validacíón de autorización a centro
      AUTHORITY-CHECK OBJECT 'M_MATE_WRK'
                          ID 'WERKS' FIELD lw_goods_assumtion-werks
                          ID 'ACTVT' FIELD '03'.

      IF sy-subrc <> 0.
        DELETE iv_goods_assumtion INDEX sy-tabix.
        CONTINUE.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.

ENDCLASS.

*-------------------------------------------------------------------------------*
* Clase para ALV                                                                *
*-------------------------------------------------------------------------------*
CLASS cl_alv_monitor_ef DEFINITION FINAL.

  PUBLIC SECTION.
    METHODS:
      constructor
        IMPORTING ir_data TYPE REF TO data,

      display_alv.

    METHODS:
      build_fieldcat
        RETURNING VALUE(rt_fieldcat) TYPE lvc_t_fcat,

      build_layout
        RETURNING VALUE(rw_layout) TYPE lvc_s_layo,

      handle_hotspot_click
                  FOR EVENT hotspot_click OF cl_gui_alv_grid
        IMPORTING e_row_id e_column_id,

      expand_selection_by_order
        CHANGING ct_rows TYPE lvc_t_row.

ENDCLASS.

CLASS cl_alv_monitor_ef IMPLEMENTATION.

  METHOD constructor.
    o_data = ir_data.
  ENDMETHOD.

  METHOD display_alv.
    " Implementación de ALV con funcionalidades específicas

    DATA:
      lw_layout   TYPE lvc_s_layo.

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

    TRY.
        CALL METHOD o_alv_grid->set_table_for_first_display
          EXPORTING
            is_layout       = lw_layout
          CHANGING
            it_outtab       = <lfs_data>
            it_fieldcatalog = li_fieldcat.

        SET HANDLER handle_hotspot_click FOR o_alv_grid.

        " Llamar Dynpro que contiene el container
        CALL SCREEN 100.

      CATCH cx_root INTO DATA(lo_error)  ##CATCH_ALL.
        DATA(lv_error) = lo_error->get_text(  ) ##NEEDED.

    ENDTRY.

  ENDMETHOD.

  METHOD handle_hotspot_click.
    " Llamado visualizar documentos
    DATA:
      lw_parcial_order TYPE ty_goods_assumtion.

    READ TABLE i_parcial_orders INTO lw_parcial_order INDEX e_row_id-index.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    CASE e_column_id-fieldname.

      WHEN 'VBELN'.                              " Pedido de venta
        IF lw_parcial_order-vbeln IS NOT INITIAL.
          SET PARAMETER ID 'AUN' FIELD lw_parcial_order-vbeln.
          CALL TRANSACTION 'VA03' AND SKIP FIRST SCREEN. "#EC CI_CALLTA
        ENDIF.

      WHEN 'VBELN_VL'.                           " Entrega
        IF lw_parcial_order-vbeln_vl IS NOT INITIAL.
          SET PARAMETER ID 'VL' FIELD lw_parcial_order-vbeln_vl.
          CALL TRANSACTION 'VL03N' AND SKIP FIRST SCREEN. "#EC CI_CALLTA
        ENDIF.

      WHEN 'TKNUM'.                              " Transporte
        IF lw_parcial_order-tknum IS NOT INITIAL.
          SET PARAMETER ID 'TNR' FIELD lw_parcial_order-tknum.
          CALL TRANSACTION 'VT03N' AND SKIP FIRST SCREEN. "#EC CI_CALLTA
        ENDIF.

      WHEN 'SALESORDER_ANT'.                     " Orden anticipo
        IF lw_parcial_order-salesorder_ant IS NOT INITIAL.
          SET PARAMETER ID 'AUN' FIELD lw_parcial_order-salesorder_ant.
          CALL TRANSACTION 'VA03' AND SKIP FIRST SCREEN. "#EC CI_CALLTA
        ENDIF.

      WHEN 'INVOICE_ANT'.                        " Factura anticipo
        IF lw_parcial_order-invoice_ant IS NOT INITIAL.
          SET PARAMETER ID 'VF' FIELD lw_parcial_order-invoice_ant.
          CALL TRANSACTION 'VF03' AND SKIP FIRST SCREEN. "#EC CI_CALLTA
        ENDIF.

      WHEN 'SALESORDER_CONS'.                    " Orden consumo
        IF lw_parcial_order-salesorder_cons IS NOT INITIAL.
          SET PARAMETER ID 'AUN' FIELD lw_parcial_order-salesorder_cons.
          CALL TRANSACTION 'VA03' AND SKIP FIRST SCREEN. "#EC CI_CALLTA
        ENDIF.

      WHEN 'DELIVERY_CONS'.                      " Entrega consumo
        IF lw_parcial_order-delivery_cons IS NOT INITIAL.
          SET PARAMETER ID 'VL' FIELD lw_parcial_order-delivery_cons.
          CALL TRANSACTION 'VL03N' AND SKIP FIRST SCREEN. "#EC CI_CALLTA
        ENDIF.

      WHEN 'SHIPMENT_CONS'.                      " Transporte consumo
        IF lw_parcial_order-shipment_cons IS NOT INITIAL.
          SET PARAMETER ID 'TNR' FIELD lw_parcial_order-shipment_cons.
          CALL TRANSACTION 'VT03N' AND SKIP FIRST SCREEN. "#EC CI_CALLTA
        ENDIF.

      WHEN 'INVOICE_CONS'.                       " Factura consumo
        IF lw_parcial_order-invoice_cons IS NOT INITIAL.
          SET PARAMETER ID 'VF' FIELD lw_parcial_order-invoice_cons.
          CALL TRANSACTION 'VF03' AND SKIP FIRST SCREEN. "#EC CI_CALLTA
        ENDIF.

      WHEN 'CREDITMEMO_ANT'.                     " NC anticipo
        IF lw_parcial_order-creditmemo_ant IS NOT INITIAL.
          SET PARAMETER ID 'AUN' FIELD lw_parcial_order-creditmemo_ant.
          CALL TRANSACTION 'VA03' AND SKIP FIRST SCREEN. "#EC CI_CALLTA
        ENDIF.

      WHEN 'CREDITMEMO_ANTINV'.                  " NC anticipo factura
        IF lw_parcial_order-creditmemo_antinv IS NOT INITIAL.
          SET PARAMETER ID 'VF' FIELD lw_parcial_order-creditmemo_antinv.
          CALL TRANSACTION 'VF03' AND SKIP FIRST SCREEN. "#EC CI_CALLTA
        ENDIF.

      WHEN 'CREDITMEMO_BON'.                     " NC bonificación
        IF lw_parcial_order-creditmemo_bon IS NOT INITIAL.
          SET PARAMETER ID 'AUN' FIELD lw_parcial_order-creditmemo_bon.
          CALL TRANSACTION 'VA03' AND SKIP FIRST SCREEN. "#EC CI_CALLTA
        ENDIF.

      WHEN 'CREDITMEMO_BONINV'.                  " NC bonificación factura
        IF lw_parcial_order-creditmemo_boninv IS NOT INITIAL.
          SET PARAMETER ID 'VF' FIELD lw_parcial_order-creditmemo_boninv.
          CALL TRANSACTION 'VF03' AND SKIP FIRST SCREEN. "#EC CI_CALLTA
        ENDIF.

    ENDCASE.
  ENDMETHOD.

  METHOD expand_selection_by_order.
*----------------------------------------------------------------------*
* Selección atómica: Al seleccionar una posición de un pedido,
* automáticamente se seleccionan todas las posiciones del mismo pedido
*----------------------------------------------------------------------*

    DATA:
      lw_row           TYPE lvc_s_row,
      lw_row_new       TYPE lvc_s_row,
      lw_parcial_order TYPE ty_goods_assumtion.

    DATA:
      li_rows_expanded  TYPE lvc_t_row.

    TYPES:
      BEGIN OF lty_vbeln_unique,
        vbeln TYPE vbak-vbeln,
      END OF lty_vbeln_unique.

    DATA:
      li_vbeln TYPE TABLE OF lty_vbeln_unique,
      lw_vbeln TYPE lty_vbeln_unique.

    CHECK ct_rows IS NOT INITIAL.

    "Recopilar VBELNs únicos de las filas seleccionadas
    LOOP AT ct_rows INTO lw_row.
      READ TABLE i_parcial_orders INTO lw_parcial_order
                                   INDEX lw_row-index.
      IF sy-subrc = 0.
        lw_vbeln-vbeln = lw_parcial_order-vbeln.
        APPEND lw_vbeln TO li_vbeln.
      ENDIF.
    ENDLOOP.

    "Eliminar duplicados
    SORT li_vbeln BY vbeln.
    DELETE ADJACENT DUPLICATES FROM li_vbeln COMPARING vbeln.

    "Buscar todas las filas con los mismos pedidos
    LOOP AT i_parcial_orders INTO lw_parcial_order.
      DATA(lv_tabix) = sy-tabix.
      READ TABLE li_vbeln TRANSPORTING NO FIELDS
                          WITH KEY vbeln = lw_parcial_order-vbeln
                          BINARY SEARCH.
      IF sy-subrc = 0.
        lw_row_new-index = lv_tabix.
        APPEND lw_row_new TO li_rows_expanded.
      ENDIF.
    ENDLOOP.

    "Eliminar duplicados (por si ya estaban seleccionados)
    SORT li_rows_expanded BY index.
    DELETE ADJACENT DUPLICATES FROM li_rows_expanded COMPARING index.

    "Actualizar selección visual en el ALV
    IF o_alv_grid IS NOT INITIAL.
      CALL METHOD o_alv_grid->set_selected_rows
        EXPORTING
          it_index_rows = li_rows_expanded.
    ENDIF.

    "Retornar las filas expandidas
    ct_rows = li_rows_expanded.

  ENDMETHOD.

  METHOD build_fieldcat.
    " Construir catálogo de campos

    DATA: lw_fieldcat TYPE lvc_s_fcat.

    CLEAR: lw_fieldcat, rt_fieldcat[].

    " --- Columna del Semáforo (Icono) ---
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'ICON'.
    lw_fieldcat-seltext   = TEXT-c03.
    lw_fieldcat-icon      = 'X'.
    lw_fieldcat-coltext   = TEXT-c03.
    lw_fieldcat-key       = c_x.
    APPEND lw_fieldcat TO rt_fieldcat.

    " Número de pedido de venta (Campo Clave)
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'VBELN'.
    lw_fieldcat-ref_table = 'VBAK'.
    lw_fieldcat-ref_field = 'VBELN'.
    lw_fieldcat-key       = c_x.
    lw_fieldcat-hotspot   = c_x.
    APPEND lw_fieldcat TO rt_fieldcat.

    " Posición del pedido (Campo Clave)
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'POSNR'.
    lw_fieldcat-ref_table = 'VBAP'.
    lw_fieldcat-ref_field = 'POSNR'.
    lw_fieldcat-key       = c_x.
    APPEND lw_fieldcat TO rt_fieldcat.

    " Fecha de creación
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'ERDAT'.
    lw_fieldcat-ref_table = 'VBAK'.
    lw_fieldcat-ref_field = 'ERDAT'.
    APPEND lw_fieldcat TO rt_fieldcat.

    " Organización de ventas
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'VKORG'.
    lw_fieldcat-ref_table = 'VBAK'.
    lw_fieldcat-ref_field = 'VKORG'.
    APPEND lw_fieldcat TO rt_fieldcat.

    " Canal de distribución
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'VTWEG'.
    lw_fieldcat-ref_table = 'VBAK'.
    lw_fieldcat-ref_field = 'VTWEG'.
    APPEND lw_fieldcat TO rt_fieldcat.

    " Sector
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'SPART'.
    lw_fieldcat-ref_table = 'VBAK'.
    lw_fieldcat-ref_field = 'SPART'.
    APPEND lw_fieldcat TO rt_fieldcat.

    " Centro
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'WERKS'.
    lw_fieldcat-ref_table = 'VBAP'.
    lw_fieldcat-ref_field = 'WERKS'.
    APPEND lw_fieldcat TO rt_fieldcat.

    " Número de cliente
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'KUNNR'.
    lw_fieldcat-ref_table = 'VBAK'.
    lw_fieldcat-ref_field = 'KUNNR'.
    APPEND lw_fieldcat TO rt_fieldcat.

    " Nombre del cliente
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'NAME1'.
    lw_fieldcat-ref_table = 'KNA1'.
    lw_fieldcat-ref_field = 'NAME1'.
    APPEND lw_fieldcat TO rt_fieldcat.

    " Descripción termino de pago
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'DTPAYMT'.
    lw_fieldcat-seltext   = TEXT-c04.
    lw_fieldcat-coltext   = TEXT-c04.
    APPEND lw_fieldcat TO rt_fieldcat.

    " Material
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'MATNR'.
    lw_fieldcat-ref_table = 'VBAP'.
    lw_fieldcat-ref_field = 'MATNR'.
    APPEND lw_fieldcat TO rt_fieldcat.

    " Descripción del material
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'MAKTX'.
    lw_fieldcat-ref_table = 'MAKT'.
    lw_fieldcat-ref_field = 'MAKTX'.
    APPEND lw_fieldcat TO rt_fieldcat.

    " Cantidad del pedido (con referencia a unidad)
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'KWMENG'.
    lw_fieldcat-ref_table = 'VBAP'.
    lw_fieldcat-ref_field = 'KWMENG'.
    lw_fieldcat-qfieldname = 'MEINS'. " Campo de unidad
    lw_fieldcat-coltext   = TEXT-c05.
    APPEND lw_fieldcat TO rt_fieldcat.

    " Número de entrega
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'VBELN_VL'.
    lw_fieldcat-ref_table = 'LIKP'.  " Referencia al campo de entrega
    lw_fieldcat-ref_field = 'VBELN'.
    lw_fieldcat-coltext   = TEXT-c06.
    lw_fieldcat-hotspot   = c_x.
    APPEND lw_fieldcat TO rt_fieldcat.

    " Fecha de entrega
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'ERDAT_VL'.
    lw_fieldcat-ref_table = 'LIKP'.  " Referencia al campo de fecha
    lw_fieldcat-ref_field = 'ERDAT'.
    lw_fieldcat-coltext   = TEXT-c07.
    APPEND lw_fieldcat TO rt_fieldcat.

    " Cantidad a entregar (con referencia a unidad)
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'LFIMG'.
    lw_fieldcat-ref_table = 'LIPS'.
    lw_fieldcat-ref_field = 'LFIMG'.
    lw_fieldcat-qfieldname = 'MEINS'. " Campo de unidad
    lw_fieldcat-coltext   = TEXT-c08.
    APPEND lw_fieldcat TO rt_fieldcat.

    " Unidad de medida (Oculto, solo para referencia)
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'MEINS'.
    lw_fieldcat-ref_table = 'VBAP'.
    lw_fieldcat-ref_field = 'MEINS'.
    lw_fieldcat-tech      = c_x. " Marcar como campo técnico
    lw_fieldcat-no_out    = c_x. " No mostrar en el ALV
    APPEND lw_fieldcat TO rt_fieldcat.

    " Cantidad a entregar (con referencia a unidad)
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'RFMNG'.
    lw_fieldcat-ref_table = 'VBFA'.
    lw_fieldcat-ref_field = 'RFMNG'.
    lw_fieldcat-qfieldname = 'MEINS'. " Campo de unidad
    lw_fieldcat-coltext    = TEXT-c24.
    APPEND lw_fieldcat TO rt_fieldcat.

    " Cantidad diferencia (con referencia a unidad y formato)
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'DIFFERENCE'.
    lw_fieldcat-ref_table = 'VBAP'.   " Usamos VBAP-KWMENG para el formato
    lw_fieldcat-ref_field = 'KWMENG'. " (decimales, etc.)
    lw_fieldcat-qfieldname = 'MEINS'. " Campo de unidad
    lw_fieldcat-coltext   = TEXT-c09.
    APPEND lw_fieldcat TO rt_fieldcat.

    " Número de transporte
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'TKNUM'.
    lw_fieldcat-ref_table = 'VTTK'.
    lw_fieldcat-ref_field = 'TKNUM'.
    lw_fieldcat-hotspot   = c_x.
    APPEND lw_fieldcat TO rt_fieldcat.

    " Posición de transporte
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'TPNUM'.
    lw_fieldcat-ref_table = 'VTTP'.
    lw_fieldcat-ref_field = 'TPNUM'.
    APPEND lw_fieldcat TO rt_fieldcat.

    " Status
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'STATUS'.
    lw_fieldcat-coltext   = TEXT-c03.
    APPEND lw_fieldcat TO rt_fieldcat.

    " Orden anticipo
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'SALESORDER_ANT'.
    lw_fieldcat-coltext   = TEXT-c14.
    lw_fieldcat-hotspot   = c_x.
    APPEND lw_fieldcat TO rt_fieldcat.

    " Factura anticipo
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'INVOICE_ANT'.
    lw_fieldcat-coltext   = TEXT-c15.
    lw_fieldcat-hotspot   = c_x.
    APPEND lw_fieldcat TO rt_fieldcat.

    " Orden consumo
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'SALESORDER_CONS'.
    lw_fieldcat-coltext   = TEXT-c16.
    lw_fieldcat-hotspot   = c_x.
    APPEND lw_fieldcat TO rt_fieldcat.

    " Entrega consumo
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'DELIVERY_CONS'.
    lw_fieldcat-coltext   = TEXT-c17.
    lw_fieldcat-hotspot   = c_x.
    APPEND lw_fieldcat TO rt_fieldcat.

    " Transporte consumo
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'SHIPMENT_CONS'.
    lw_fieldcat-coltext   = TEXT-c18.
    lw_fieldcat-hotspot   = c_x.
    APPEND lw_fieldcat TO rt_fieldcat.

    " Factura consumo
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'INVOICE_CONS'.
    lw_fieldcat-coltext   = TEXT-c19.
    lw_fieldcat-hotspot   = c_x.
    APPEND lw_fieldcat TO rt_fieldcat.

    " NC anticipo
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'CREDITMEMO_ANT'.
    lw_fieldcat-coltext   = TEXT-c20.
    lw_fieldcat-hotspot   = c_x.
    APPEND lw_fieldcat TO rt_fieldcat.

    " NC anticipoinv
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'CREDITMEMO_ANTINV'.
    lw_fieldcat-coltext   = TEXT-c21.
    lw_fieldcat-hotspot   = c_x.
    APPEND lw_fieldcat TO rt_fieldcat.

    " NC Bon
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'CREDITMEMO_BON'.
    lw_fieldcat-coltext   = TEXT-c22.
    lw_fieldcat-hotspot   = c_x.
    APPEND lw_fieldcat TO rt_fieldcat.

    " NC Boninv
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'CREDITMEMO_BONINV'.
    lw_fieldcat-coltext   = TEXT-c23.
    lw_fieldcat-hotspot   = c_x.
    APPEND lw_fieldcat TO rt_fieldcat.

    " Mensaje
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'MESSAGE'.
    lw_fieldcat-coltext   = TEXT-c13.
    APPEND lw_fieldcat TO rt_fieldcat.


  ENDMETHOD.

  METHOD build_layout.

    " Configurar layout del ALV
    rw_layout-zebra = c_x.          " Líneas alternadas
    rw_layout-sel_mode = 'A'.       " Selección múltiple
    rw_layout-cwidth_opt = abap_true.

  ENDMETHOD.

ENDCLASS.

*-------------------------------------------------------------------------------*
* FORM MAIN_PROCESS                                                             *
*-------------------------------------------------------------------------------*
FORM f_main_process.

  " Proceso principal del programa
  DATA: lo_monitor TYPE REF TO cl_exsd_monitor_exist_fic.

  " Crear instancia de la clase principal
  CREATE OBJECT lo_monitor.

  " Obtener pedidos con entregas parciales
  i_parcial_orders = lo_monitor->get_parcial_salesorders( ).

ENDFORM.

*-------------------------------------------------------------------------------*
* FORM DISPLAY_ALV                                                              *
*-------------------------------------------------------------------------------*
FORM f_display_alv.
  " Mostrar datos en formato ALV

  DATA: lo_alv_monitor_ef TYPE REF TO cl_alv_monitor_ef,
        lo_data           TYPE REF TO data.

  " Crear referencia a los datos
  GET REFERENCE OF i_parcial_orders INTO lo_data.

  " Crear instancia de ALV
  CREATE OBJECT lo_alv_monitor_ef
    EXPORTING
      ir_data = lo_data.

  " Configurar fieldcat
  lo_alv_monitor_ef->display_alv(  ).

ENDFORM.

*-------------------------------------------------------------------------------*
* FORM PROCESS_ACCEPTANCE                                                       *
*-------------------------------------------------------------------------------*
FORM f_process_aceptance.
  " Procesar aceptación de parcialidad

  DATA:
    lw_row       TYPE lvc_s_row,
    lw_exfic_mon TYPE ztasd_exfic_mon,
    lw_selected  TYPE ty_goods_assumtion,
    lw_driver    TYPE ty_goods_assumtion.

  DATA:
    li_rows            TYPE lvc_t_row,
    li_exfic_mon       TYPE TABLE OF ztasd_exfic_mon,
    li_selected_orders TYPE TABLE OF ty_goods_assumtion.

  DATA:
    lr_vbeln TYPE RANGE OF vbak-vbeln.

  DATA:
    lv_success       TYPE abap_bool,
    lv_error_count   TYPE i,
    lv_success_count TYPE i,
    lv_lines         TYPE i,
    lv_jobcount      TYPE tbtcjob-jobcount,
    lv_jobname       TYPE tbtcjob-jobname,
    lv_prev_vbeln    TYPE vbak-vbeln.

  DATA:
    lo_monitor    TYPE REF TO cl_exsd_monitor_exist_fic,
    lo_alv_expand TYPE REF TO cl_alv_monitor_ef.


  " Crear instancia de la clase de procesamiento
  CREATE OBJECT lo_monitor.

  " Obtiene lineas seleccionadas
  CALL METHOD o_alv_grid->get_selected_rows
    IMPORTING
      et_index_rows = li_rows.

  DESCRIBE TABLE li_rows LINES lv_lines.
  IF lv_lines = 0.
    MESSAGE s908(fb) WITH TEXT-018 DISPLAY LIKE 'E'. "Seleccione al menos un registro
    RETURN.
  ENDIF.

  CREATE OBJECT lo_alv_expand
    EXPORTING
      ir_data = o_data.

  " Expandir selección: seleccionar todas las posiciones del mismo pedido
  lo_alv_expand->expand_selection_by_order(
    CHANGING
      ct_rows = li_rows
  ).

  " Configuración inicial de visualización
  v_icon_name = icon_message_question.
  v_text_line1 = TEXT-008.
  v_text_line2 = TEXT-009.
  v_text_line3 = TEXT-010.

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
        READ TABLE i_parcial_orders INTO w_parcial_orders
                                    INDEX lw_row-index.
        "No es necesario binary search se tratan de pocos registros
        IF sy-subrc = 0.
          IF w_parcial_orders-zterm <> c_cash_sales. "Sólo considera pagos de contado
            CONTINUE.
          ENDIF.
          APPEND VALUE #( sign = c_i option = c_eq low = w_parcial_orders-vbeln ) TO lr_vbeln.
        ENDIF.
      ENDLOOP.

      SORT lr_vbeln BY low.
      DELETE ADJACENT DUPLICATES FROM lr_vbeln COMPARING low.

      " --- Crear JOB de Fondo ---
      lv_jobname = |ZRE_EXIST_FIC_{ sy-uname }_{ sy-datum }_{ sy-uzeit }|.

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
        MESSAGE s908(fb) WITH TEXT-019. "Error al crear Job de fondo
        RETURN.
      ENDIF.

      " Submit del reporte con los filtros seleccionados y flag de ejecución
      SUBMIT zre_csdsls_monitor_exist_fic
        WITH s_vbeln IN lr_vbeln
        WITH p_accept = abap_true
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
        MESSAGE i911(fb) WITH TEXT-020 lv_jobname. "Proceso iniciado en fondo. Job:
      ELSE.
        MESSAGE s908(fb) WITH TEXT-021. "Error al cerrar/iniciar Job
      ENDIF.

      LEAVE PROGRAM.

    ELSE.

*--------------------------------------------------------------------*
*     Procesamiento agrupado por pedido (atómico por VBELN)
*--------------------------------------------------------------------*

      " Recopilar posiciones seleccionadas en tabla intermedia
      LOOP AT li_rows INTO lw_row.
        READ TABLE i_parcial_orders INTO lw_selected
                                    INDEX lw_row-index.
        IF sy-subrc = 0.
          IF lw_selected-zterm <> c_cash_sales. "Sólo considera pagos de contado
            CONTINUE.
          ENDIF.
          lw_selected-process = c_accept.
          APPEND lw_selected TO li_selected_orders.
        ENDIF.
      ENDLOOP.

      " Ordenar por pedido para agrupar posiciones
      SORT li_selected_orders BY vbeln posnr.

      " Guardar estado inicial de todas las posiciones en tabla Z
      LOOP AT li_selected_orders INTO lw_selected.
        MOVE-CORRESPONDING lw_selected TO lw_exfic_mon.
        MODIFY ztasd_exfic_mon FROM lw_exfic_mon.
      ENDLOOP.
      COMMIT WORK AND WAIT.

      " Procesar agrupado por pedido
      CLEAR lv_prev_vbeln.

      LOOP AT li_selected_orders INTO lw_selected.

        "--------------------------------------------------------------"
        " Cambio de pedido: ejecutar rechazo + aceptación una sola vez
        "--------------------------------------------------------------"
        IF lw_selected-vbeln <> lv_prev_vbeln.
          lv_prev_vbeln = lw_selected-vbeln.

          " Tomar la primera posición como "driver" del pedido
          lw_driver = lw_selected.

          " Rechazo (reversa de transporte, entrega y motivo)
          IF lw_driver-reason_rej IS INITIAL.
            lv_success = lo_monitor->process_rejection(
              CHANGING
                iv_parcial_orders = lw_driver
            ).
          ELSE.
            lv_success = abap_true.
          ENDIF.

          " Aceptación (anticipo, consumo, notas de crédito)
          IF lv_success = abap_true.
            lv_success = lo_monitor->process_acceptance(
              CHANGING
                iv_parcial_orders = lw_driver
            ).
            lv_success_count = lv_success_count + 1.
          ELSE.
            lv_error_count = lv_error_count + 1.
          ENDIF.

        ENDIF.

        "--------------------------------------------------------------"
        " Propagar resultados del driver a TODAS las posiciones
        "--------------------------------------------------------------"
        lw_selected-status            = lw_driver-status.
        lw_selected-icon              = lw_driver-icon.
        lw_selected-message           = lw_driver-message.
        lw_selected-reason_rej        = lw_driver-reason_rej.
        lw_selected-salesorder_ant    = lw_driver-salesorder_ant.
        lw_selected-invoice_ant       = lw_driver-invoice_ant.
        lw_selected-salesorder_cons   = lw_driver-salesorder_cons.
        lw_selected-delivery_cons     = lw_driver-delivery_cons.
        lw_selected-pgi_cons          = lw_driver-pgi_cons.
        lw_selected-shipment_cons     = lw_driver-shipment_cons.
        lw_selected-invoice_cons      = lw_driver-invoice_cons.
        lw_selected-creditmemo_ant    = lw_driver-creditmemo_ant.
        lw_selected-creditmemo_antinv = lw_driver-creditmemo_antinv.
        lw_selected-creditmemo_bon    = lw_driver-creditmemo_bon.
        lw_selected-creditmemo_boninv = lw_driver-creditmemo_boninv.

        " Actualizar tabla principal i_parcial_orders
        READ TABLE i_parcial_orders TRANSPORTING NO FIELDS
          WITH KEY vbeln = lw_selected-vbeln
                   posnr = lw_selected-posnr.
        IF sy-subrc = 0.
          MODIFY i_parcial_orders FROM lw_selected INDEX sy-tabix.
        ENDIF.

        " Acumular para actualización masiva en tabla Z
        CLEAR lw_exfic_mon.
        MOVE-CORRESPONDING lw_selected TO lw_exfic_mon.
        APPEND lw_exfic_mon TO li_exfic_mon.

      ENDLOOP.
      " Revisa que la tabla no est vacia para hacer la actualización
      IF li_exfic_mon[] IS NOT INITIAL.
        MODIFY ztasd_exfic_mon FROM TABLE li_exfic_mon.
        COMMIT WORK AND WAIT.
      ENDIF.

    ENDIF.

  ENDIF.

  " Forzar la actualización del Grid
  CALL METHOD o_alv_grid->refresh_table_display.

ENDFORM.

*-------------------------------------------------------------------------------*
* FORM PROCESS_REJECT                                                           *
*-------------------------------------------------------------------------------*
FORM f_process_reject.
  " Procesar rechazo de parcialidad

  DATA:
    lw_row       TYPE lvc_s_row,
    lw_exfic_mon TYPE ztasd_exfic_mon,
    lw_selected  TYPE ty_goods_assumtion,
    lw_driver    TYPE ty_goods_assumtion.

  DATA:
    li_rows            TYPE lvc_t_row,
    li_exfic_mon       TYPE TABLE OF ztasd_exfic_mon,
    li_selected_orders TYPE TABLE OF ty_goods_assumtion.

  DATA:
    lr_vbeln TYPE RANGE OF vbak-vbeln.

  DATA:
    lv_success       TYPE abap_bool,
    lv_error_count   TYPE i,
    lv_success_count TYPE i,
    lv_lines         TYPE i,
    lv_jobcount      TYPE tbtcjob-jobcount,
    lv_jobname       TYPE tbtcjob-jobname,
    lv_prev_vbeln    TYPE vbak-vbeln.

  DATA:
    lo_monitor      TYPE REF TO cl_exsd_monitor_exist_fic,
    lo_alv_expand_r TYPE REF TO cl_alv_monitor_ef.


  " Crear instancia de la clase de procesamiento
  CREATE OBJECT lo_monitor.

  "Obtiene lineas seleccionadas
  CALL METHOD o_alv_grid->get_selected_rows
    IMPORTING
      et_index_rows = li_rows.

  DESCRIBE TABLE li_rows LINES lv_lines.
  IF lv_lines = 0.
    MESSAGE s908(fb) WITH TEXT-018 DISPLAY LIKE 'E'. "Seleccione al menos un registro
    RETURN.
  ENDIF.

  CREATE OBJECT lo_alv_expand_r
    EXPORTING
      ir_data = o_data.

  " Expandir selección: seleccionar todas las posiciones del mismo pedido
  lo_alv_expand_r->expand_selection_by_order(
    CHANGING
      ct_rows = li_rows
  ).

  " Configuración inicial de visualización
  v_icon_name = icon_message_question.
  v_text_line1 = TEXT-011.
  v_text_line2 = TEXT-012.
  v_text_line3 = TEXT-010.

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
        READ TABLE i_parcial_orders INTO w_parcial_orders
                                    INDEX lw_row-index.
        " No es necesario binary search se tratan de pocos registros
        IF sy-subrc = 0.

          IF w_parcial_orders-zterm <> c_cash_sales. "Sólo considera pagos de contado
            CONTINUE.
          ENDIF.

          APPEND VALUE #( sign = c_i option = c_eq low = w_parcial_orders-vbeln ) TO lr_vbeln.
        ENDIF.
      ENDLOOP.

      " --- Crear JOB de Fondo ---
      lv_jobname = |ZRE_EXIST_FIC_{ sy-uname }_{ sy-datum }_{ sy-uzeit }|.

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
        MESSAGE s908(fb) WITH TEXT-019. "Error al crear Job de fondo
        RETURN.
      ENDIF.

      " Submit del reporte con los filtros seleccionados y flag de ejecución
      SUBMIT zre_csdsls_monitor_exist_fic
        WITH s_vbeln IN lr_vbeln
        WITH p_reject = abap_true
        WITH p_batch  = abap_true  " Activar modo ejecución
        VIA JOB lv_jobname NUMBER lv_jobcount
        AND RETURN.                                     "#EC CI_SUBMIT.

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
        MESSAGE i911(fb) WITH TEXT-020 lv_jobname. "Proceso iniciado en fondo. Job:
      ELSE.
        MESSAGE s908(fb) WITH TEXT-021. "Error al cerrar/iniciar Job
      ENDIF.

      LEAVE PROGRAM.

    ELSE.

*--------------------------------------------------------------------*
*     Procesamiento agrupado por pedido (atómico por VBELN)
*--------------------------------------------------------------------*

      " Recopilar posiciones seleccionadas en tabla intermedia
      LOOP AT li_rows INTO lw_row.
        READ TABLE i_parcial_orders INTO lw_selected
                                     INDEX lw_row-index.
        IF sy-subrc = 0.
          IF lw_selected-zterm <> c_cash_sales. "Sólo considera pagos de contado
            CONTINUE.
          ENDIF.
          lw_selected-process = c_reject.
          APPEND lw_selected TO li_selected_orders.
        ENDIF.
      ENDLOOP.

      " Ordenar por pedido para agrupar posiciones
      SORT li_selected_orders BY vbeln posnr.

      "Guardar estado inicial de todas las posiciones en tabla Z
      LOOP AT li_selected_orders INTO lw_selected.
        MOVE-CORRESPONDING lw_selected TO lw_exfic_mon.
        MODIFY ztasd_exfic_mon FROM lw_exfic_mon.
      ENDLOOP.
      COMMIT WORK AND WAIT.

      " Procesar agrupado por pedido
      CLEAR lv_prev_vbeln.

      LOOP AT li_selected_orders INTO lw_selected.

        "--------------------------------------------------------------"
        " Cambio de pedido: ejecutar rechazo una sola vez
        "--------------------------------------------------------------"
        IF lw_selected-vbeln <> lv_prev_vbeln.
          lv_prev_vbeln = lw_selected-vbeln.

          " Tomar la primera posición como "driver" del pedido
          lw_driver = lw_selected.

          " Rechazo (reversa de transporte, entrega y motivo)
          IF lw_driver-reason_rej IS INITIAL.
            lv_success = lo_monitor->process_rejection(
              CHANGING
                iv_parcial_orders = lw_driver
            ).
          ELSE.
            lv_success = abap_true.
          ENDIF.

          IF lv_success = abap_true.
            lv_success_count = lv_success_count + 1.
          ELSE.
            lv_error_count = lv_error_count + 1.
          ENDIF.

        ENDIF.

        "--------------------------------------------------------------"
        " Propagar resultados del driver a TODAS las posiciones
        "--------------------------------------------------------------"
        lw_selected-status     = lw_driver-status.
        lw_selected-icon       = lw_driver-icon.
        lw_selected-message    = lw_driver-message.
        lw_selected-reason_rej = lw_driver-reason_rej.

        " Actualizar tabla principal i_parcial_orders
        READ TABLE i_parcial_orders TRANSPORTING NO FIELDS
          WITH KEY vbeln = lw_selected-vbeln
                   posnr = lw_selected-posnr.
        IF sy-subrc = 0.
          MODIFY i_parcial_orders FROM lw_selected INDEX sy-tabix.
        ENDIF.

        " Acumular para actualización masiva en tabla Z
        CLEAR lw_exfic_mon.
        MOVE-CORRESPONDING lw_selected TO lw_exfic_mon.
        APPEND lw_exfic_mon TO li_exfic_mon.

      ENDLOOP.
      " Revisa que la tabla no est vacia para hacer la actualización
      IF li_exfic_mon[] IS NOT INITIAL.
        MODIFY ztasd_exfic_mon FROM TABLE li_exfic_mon.
        COMMIT WORK AND WAIT.
      ENDIF.

    ENDIF.

  ENDIF.

  " Forzar la actualización del Grid
  CALL METHOD o_alv_grid->refresh_table_display.

ENDFORM.

*-------------------------------------------------------------------------------*
* FORM SHOW_ERROR_LOG                                                           *
*-------------------------------------------------------------------------------*
FORM f_show_error_log.
  " Mostrar log de errores en ventana emergente

  TYPES:
    BEGIN OF lty_row_select,
      vbeln TYPE vbak-vbeln,
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

  DATA:
    lo_alv_expand_l TYPE REF TO cl_alv_monitor_ef.

  "Obtiene lineas seleccionadas
  CALL METHOD o_alv_grid->get_selected_rows
    IMPORTING
      et_index_rows = li_rows.

  " Expandir selección: seleccionar todas las posiciones del mismo pedido
  CREATE OBJECT lo_alv_expand_l
    EXPORTING
      ir_data = o_data.

  lo_alv_expand_l->expand_selection_by_order(
    CHANGING
      ct_rows = li_rows
  ).

  " Procesar líneas seleccionadas
  LOOP AT li_rows INTO lw_row.

    READ TABLE i_parcial_orders INTO w_parcial_orders
                                INDEX lw_row-index.
    "No es necesario binary search se tratan de pocos registros
    IF sy-subrc = 0.
      lw_row_select-vbeln = w_parcial_orders-vbeln.
      APPEND lw_row_select TO li_row_select.
    ENDIF.

  ENDLOOP.

  IF li_row_select[] IS NOT INITIAL.

    "Consulta log
    SELECT document process status euser edate etime message
      FROM ztasd_exfic_log
      INTO CORRESPONDING FIELDS OF TABLE i_log ##TOO_MANY_ITAB_FIELDS
      FOR ALL ENTRIES IN li_row_select
      WHERE document = li_row_select-vbeln.
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
    MESSAGE TEXT-013 TYPE 'I' DISPLAY LIKE 'W'. "No hay registros en el log de procesos
    RETURN.
  ENDIF.

  CLEAR lw_fieldcat.
  lw_fieldcat-fieldname = 'ICON'.
  lw_fieldcat-seltext_l = ''.
  lw_fieldcat-seltext_m = ''.
  lw_fieldcat-seltext_s = ''.
  lw_fieldcat-col_pos   = 1.
  lw_fieldcat-outputlen = 3  ##NUMBER_OK.
  lw_fieldcat-icon      = 'X'.
  APPEND lw_fieldcat TO li_fieldcat.

  CLEAR lw_fieldcat.
  lw_fieldcat-fieldname = 'DOCUMENT'.
  lw_fieldcat-seltext_l = TEXT-c10.
  lw_fieldcat-seltext_m = TEXT-c10.
  lw_fieldcat-seltext_s = 'Doc'.
  lw_fieldcat-col_pos   = 2.
  lw_fieldcat-outputlen = 10  ##NUMBER_OK.
  APPEND lw_fieldcat TO li_fieldcat.

  CLEAR lw_fieldcat.
  lw_fieldcat-fieldname = 'PROCESS'.
  lw_fieldcat-seltext_l = TEXT-c11.
  lw_fieldcat-seltext_m = TEXT-c11.
  lw_fieldcat-seltext_s = TEXT-c11.
  lw_fieldcat-col_pos   = 3.
  lw_fieldcat-outputlen = 20  ##NUMBER_OK.
  APPEND lw_fieldcat TO li_fieldcat.

  CLEAR lw_fieldcat.
  lw_fieldcat-fieldname = 'STATUS'.
  lw_fieldcat-seltext_l = TEXT-c03.
  lw_fieldcat-seltext_m = TEXT-c03.
  lw_fieldcat-seltext_s = TEXT-c03.
  lw_fieldcat-col_pos   = 4.
  lw_fieldcat-outputlen = 10.
*  lw_fieldcat-emphasize = 'C500'.  " Resaltar con color
  APPEND lw_fieldcat TO li_fieldcat.

  CLEAR lw_fieldcat.
  lw_fieldcat-fieldname = 'EUSER'.
  lw_fieldcat-seltext_l = TEXT-c12.
  lw_fieldcat-seltext_m = TEXT-c12.
  lw_fieldcat-seltext_s = TEXT-c12.
  lw_fieldcat-col_pos   = 5.
  lw_fieldcat-outputlen = 12  ##NUMBER_OK.
  APPEND lw_fieldcat TO li_fieldcat.

  CLEAR lw_fieldcat.
  lw_fieldcat-fieldname = 'EDATE'.
  lw_fieldcat-seltext_l = TEXT-c12.
  lw_fieldcat-seltext_m = TEXT-c12.
  lw_fieldcat-seltext_s = TEXT-c12.
  lw_fieldcat-col_pos   = 6.
  lw_fieldcat-outputlen = 10  ##NUMBER_OK.
  APPEND lw_fieldcat TO li_fieldcat.

  CLEAR lw_fieldcat.
  lw_fieldcat-fieldname = 'ETIME'.
  lw_fieldcat-seltext_l = TEXT-c12.
  lw_fieldcat-seltext_m = TEXT-c12.
  lw_fieldcat-seltext_s = TEXT-c12.
  lw_fieldcat-col_pos   = 7.
  lw_fieldcat-outputlen = 10  ##NUMBER_OK.
  APPEND lw_fieldcat TO li_fieldcat.

  CLEAR lw_fieldcat.
  lw_fieldcat-fieldname = 'MESSAGE'.
  lw_fieldcat-seltext_l = TEXT-c13.
  lw_fieldcat-seltext_m = TEXT-c13.
  lw_fieldcat-seltext_s = TEXT-c13.
  lw_fieldcat-col_pos   = 8.
  lw_fieldcat-outputlen = 80  ##NUMBER_OK.
  APPEND lw_fieldcat TO li_fieldcat.

  " Mostrar popup con el log
  CALL FUNCTION 'REUSE_ALV_POPUP_TO_SELECT'
    EXPORTING
      i_title               = TEXT-014   "Log de Procesos
      i_zebra               = 'X'
      i_screen_start_column = 10
      i_screen_start_line   = 5
      i_screen_end_column   = 160 ##NUMBER_OK
      i_screen_end_line     = 10 ##NUMBER_OK
      i_tabname             = 'I_LOG'
      it_fieldcat           = li_fieldcat
    TABLES
      t_outtab              = i_log
    EXCEPTIONS
      program_error         = 1
      OTHERS                = 2.

  IF sy-subrc <> 0.
    MESSAGE s908 WITH TEXT-015. "Error al mostrar log de procesos
  ENDIF.

ENDFORM.

*-------------------------------------------------------------------------------*
* FORM VALIDAR_RANGO_FECHAS                                                   *
*-------------------------------------------------------------------------------*
FORM f_validate_dates.
  " Validar rango de fechas válido

  DATA: lv_dias TYPE i.

  " Validar que el rango no sea mayor a 90 días
  READ TABLE s_erdat ASSIGNING FIELD-SYMBOL(<lfs_erdat>) INDEX 1.
  "No es necesario binary search se tratan de pocos registros
  IF sy-subrc = 0.
    lv_dias = <lfs_erdat>-high - <lfs_erdat>-low.
    IF lv_dias > 90  ##NUMBER_OK.
      MESSAGE e908(fb) WITH TEXT-016. "El rango de fechas no puede ser mayor a 90 días
    ENDIF.

    " Validar que la fecha inicial no sea mayor a la final
    IF <lfs_erdat>-low > <lfs_erdat>-high.
      MESSAGE e908(fb) WITH TEXT-017. "Fecha inicial es mayor a la fecha final
    ENDIF.
  ENDIF.

ENDFORM.

*-------------------------------------------------------------------------------*
* FORM f_process_acceptance_batch                                               *
*-------------------------------------------------------------------------------*
FORM f_process_acceptance_batch.
  " Procesamiento masivo (Background)

  DATA:
    lv_success    TYPE abap_bool,
    lv_prev_vbeln TYPE vbak-vbeln.

  DATA:
    lw_exfic_mon TYPE ztasd_exfic_mon,
    lw_driver    TYPE ty_goods_assumtion,
    lw_selected  TYPE ty_goods_assumtion.

  DATA:
    li_exfic_mon       TYPE TABLE OF ztasd_exfic_mon,
    li_selected_orders TYPE TABLE OF ty_goods_assumtion.

  DATA:
    lo_monitor TYPE REF TO cl_exsd_monitor_exist_fic.

  CREATE OBJECT lo_monitor.

  "--- Inicio de Proceso de Existencia Ficticia (Batch) ---
  WRITE: / TEXT-022, sy-datum, sy-uzeit.
  SKIP.

  " Recopilar posiciones para procesar
  LOOP AT i_parcial_orders INTO lw_selected.
    IF lw_selected-zterm <> c_cash_sales. "Sólo considera pagos de contado
      CONTINUE.
    ENDIF.
    lw_selected-process = c_accept.
    APPEND lw_selected TO li_selected_orders.
  ENDLOOP.

  " Ordenar por pedido para agrupar posiciones
  SORT li_selected_orders BY vbeln posnr.

  " Guardar estado inicial de todas las posiciones en tabla Z
  LOOP AT li_selected_orders INTO lw_selected.
    MOVE-CORRESPONDING lw_selected TO lw_exfic_mon.
    MODIFY ztasd_exfic_mon FROM lw_exfic_mon.
  ENDLOOP.
  COMMIT WORK AND WAIT.

  " Procesar agrupado por pedido
  CLEAR lv_prev_vbeln.

  LOOP AT li_selected_orders INTO lw_selected.

    " Cambio de pedido: ejecutar rechazo + aceptación una sola vez
    IF lw_selected-vbeln <> lv_prev_vbeln.
      lv_prev_vbeln = lw_selected-vbeln.
      lw_driver = lw_selected.

      "Procesando Documento:
      WRITE: / TEXT-023, lw_driver-vbeln.

      " Rechazo (reversa de transporte, entrega y motivo)
      IF lw_driver-reason_rej IS INITIAL.
        lv_success = lo_monitor->process_rejection(
          CHANGING
            iv_parcial_orders = lw_driver
        ).
      ELSE.
        lv_success = abap_true.
      ENDIF.

      " Aceptación (anticipo, consumo, notas de crédito)
      IF lv_success = abap_true.
        lv_success = lo_monitor->process_acceptance(
          CHANGING
            iv_parcial_orders = lw_driver
        ).
      ENDIF.

      IF lv_success = abap_true.
        WRITE: TEXT-024. " -> [OK] Procesado correctamente
      ELSE.
        WRITE: TEXT-025. " -> [ERROR] Falló el procesamiento (Ver Log Z)
      ENDIF.

    ENDIF.

    " Propagar resultados del driver a TODAS las posiciones
    lw_selected-status            = lw_driver-status.
    lw_selected-icon              = lw_driver-icon.
    lw_selected-message           = lw_driver-message.
    lw_selected-reason_rej        = lw_driver-reason_rej.
    lw_selected-salesorder_ant    = lw_driver-salesorder_ant.
    lw_selected-invoice_ant       = lw_driver-invoice_ant.
    lw_selected-salesorder_cons   = lw_driver-salesorder_cons.
    lw_selected-delivery_cons     = lw_driver-delivery_cons.
    lw_selected-pgi_cons          = lw_driver-pgi_cons.
    lw_selected-shipment_cons     = lw_driver-shipment_cons.
    lw_selected-invoice_cons      = lw_driver-invoice_cons.
    lw_selected-creditmemo_ant    = lw_driver-creditmemo_ant.
    lw_selected-creditmemo_antinv = lw_driver-creditmemo_antinv.
    lw_selected-creditmemo_bon    = lw_driver-creditmemo_bon.
    lw_selected-creditmemo_boninv = lw_driver-creditmemo_boninv.

    " Actualizar tabla principal i_parcial_orders
    READ TABLE i_parcial_orders TRANSPORTING NO FIELDS
      WITH KEY vbeln = lw_selected-vbeln
               posnr = lw_selected-posnr.
    IF sy-subrc = 0.
      MODIFY i_parcial_orders FROM lw_selected INDEX sy-tabix.
    ENDIF.

    " Acumular para actualización masiva en tabla Z
    CLEAR lw_exfic_mon.
    MOVE-CORRESPONDING lw_selected TO lw_exfic_mon.
    APPEND lw_exfic_mon TO li_exfic_mon.

  ENDLOOP.

  IF li_exfic_mon[] IS NOT INITIAL.
    MODIFY ztasd_exfic_mon FROM TABLE li_exfic_mon.
    COMMIT WORK AND WAIT.
  ENDIF.

  SKIP.
  "--- Fin de Proceso ---
  WRITE: / TEXT-026, sy-datum, sy-uzeit.

ENDFORM.

*-------------------------------------------------------------------------------*
* FORM f_process_rejection_batch                                                *
*-------------------------------------------------------------------------------*
FORM f_process_rejection_batch.
  " Procesamiento masivo (Background)

  DATA:
    lv_success    TYPE abap_bool,
    lv_prev_vbeln TYPE vbak-vbeln.

  DATA:
    lw_exfic_mon TYPE ztasd_exfic_mon,
    lw_driver    TYPE ty_goods_assumtion,
    lw_selected  TYPE ty_goods_assumtion.

  DATA:
    li_exfic_mon       TYPE TABLE OF ztasd_exfic_mon,
    li_selected_orders TYPE TABLE OF ty_goods_assumtion.

  DATA:
    lo_monitor TYPE REF TO cl_exsd_monitor_exist_fic.

  CREATE OBJECT lo_monitor.

  "--- Inicio de Proceso de Existencia Ficticia (Batch) ---
  WRITE: / TEXT-022, sy-datum, sy-uzeit.
  SKIP.

  " Recopilar posiciones para procesar
  LOOP AT i_parcial_orders INTO lw_selected.
    IF lw_selected-zterm <> c_cash_sales. "Sólo considera pagos de contado
      CONTINUE.
    ENDIF.
    lw_selected-process = c_reject.
    APPEND lw_selected TO li_selected_orders.
  ENDLOOP.

  " Ordenar por pedido para agrupar posiciones
  SORT li_selected_orders BY vbeln posnr.

  " Guardar estado inicial de todas las posiciones en tabla Z
  LOOP AT li_selected_orders INTO lw_selected.
    MOVE-CORRESPONDING lw_selected TO lw_exfic_mon.
    MODIFY ztasd_exfic_mon FROM lw_exfic_mon.
  ENDLOOP.
  COMMIT WORK AND WAIT.

  " Procesar agrupado por pedido
  CLEAR lv_prev_vbeln.

  LOOP AT li_selected_orders INTO lw_selected.

    " Cambio de pedido: ejecutar rechazo una sola vez
    IF lw_selected-vbeln <> lv_prev_vbeln.
      lv_prev_vbeln = lw_selected-vbeln.
      lw_driver = lw_selected.

      "Procesando Documento:
      WRITE: / TEXT-023, lw_driver-vbeln.

      " Rechazo (reversa de transporte, entrega y motivo)
      IF lw_driver-reason_rej IS INITIAL.
        lv_success = lo_monitor->process_rejection(
          CHANGING
            iv_parcial_orders = lw_driver
        ).
      ELSE.
        lv_success = abap_true.
      ENDIF.

      IF lv_success = abap_true.
        WRITE: TEXT-024. " -> [OK] Procesado correctamente
      ELSE.
        WRITE: TEXT-025. " -> [ERROR] Falló el procesamiento (Ver Log Z)
      ENDIF.

    ENDIF.

    " Propagar resultados del driver a TODAS las posiciones
    lw_selected-status     = lw_driver-status.
    lw_selected-icon       = lw_driver-icon.
    lw_selected-message    = lw_driver-message.
    lw_selected-reason_rej = lw_driver-reason_rej.

    " Actualizar tabla principal i_parcial_orders
    READ TABLE i_parcial_orders TRANSPORTING NO FIELDS
      WITH KEY vbeln = lw_selected-vbeln
               posnr = lw_selected-posnr.
    IF sy-subrc = 0.
      MODIFY i_parcial_orders FROM lw_selected INDEX sy-tabix.
    ENDIF.

    " Acumular para actualización masiva en tabla Z
    CLEAR lw_exfic_mon.
    MOVE-CORRESPONDING lw_selected TO lw_exfic_mon.
    APPEND lw_exfic_mon TO li_exfic_mon.

  ENDLOOP.

  IF li_exfic_mon[] IS NOT INITIAL.
    MODIFY ztasd_exfic_mon FROM TABLE li_exfic_mon.
    COMMIT WORK AND WAIT.
  ENDIF.

  SKIP.
  "--- Fin de Proceso ---
  WRITE: / TEXT-026, sy-datum, sy-uzeit.

ENDFORM.