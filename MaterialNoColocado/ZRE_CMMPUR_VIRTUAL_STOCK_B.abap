*-------------------------------------------------------------------------------*
*                   Fabrica de Software ABAP NEORIS                             *
*-------------------------------------------------------------------------------*
* Nombre del Programa : ZRE_CMMPUR_VIRTUAL_STOCK                                *
* Descripción         : Asignar material no colocado                            *
* Funcional           : Julio Carrasco                                          *
* Desarrollador       : Edgar Morales  - ABAP_01                                *
* Diseñador Técnico   : Edgar Morales                                           *
* Fecha de Creación   : 21.01.2026                                              *
* ID del Componente   : DF-EXMM03                                               *
* Número de Req.      : EXMM03                                                  *
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

CLASS cl_virtual_stock DEFINITION FINAL.

  PUBLIC SECTION.

    DATA:
      " Contadores: Assign Quantities
      lv_assign_procesados TYPE i,
      lv_assign_exitosos   TYPE i,
      lv_assign_errores    TYPE i,
      " Contadores: Stock Transfer Order
      lv_sto_procesados    TYPE i,
      lv_sto_exitosos      TYPE i,
      lv_sto_errores       TYPE i,
      " Contadores: Create Return
      lv_return_procesados TYPE i,
      lv_return_exitosos   TYPE i,
      lv_return_errores    TYPE i,
      " Cantidad devuelta
      lv_return_qty        TYPE menge_d.

    "Métodos públicos
    METHODS:
      constructor
        IMPORTING
          iv_plant TYPE werks_d,
      virtual_stock_process
        RETURNING VALUE(rv_error) TYPE abap_bool.

  PRIVATE SECTION.
    "Atributos privados

    TYPES:
      BEGIN OF lty_eban,
        banfn TYPE eban-banfn,
        bnfpo TYPE eban-bnfpo,
        loekz TYPE eban-loekz,
        matnr TYPE eban-matnr,
        werks TYPE eban-werks,
        reswk TYPE eban-reswk,
        menge TYPE eban-menge,
        meins TYPE eban-meins,
        lfdat TYPE eban-lfdat,
        pstyp TYPE eban-pstyp,
        bsmng TYPE eban-bsmng,
        banpr TYPE eban-banpr,
      END OF lty_eban,

      BEGIN OF lty_marc,
        matnr TYPE marc-matnr,
        werks TYPE marc-werks,
        ekgrp TYPE marc-ekgrp,
      END OF lty_marc,

      BEGIN OF lty_t460a,
        werks TYPE t460a-werks,
        sobsl TYPE t460a-sobsl,
        wrk02 TYPE t460a-wrk02,
      END OF lty_t460a,

      BEGIN OF lty_material_stock,
        supplying_plant TYPE reswk,
        material        TYPE matnr,
        unit            TYPE meins,
        com_qty         TYPE mng06,
        ava_qty         TYPE mng06,
      END OF lty_material_stock.

    DATA:
      lw_material_stock TYPE lty_material_stock,
      lw_eban           TYPE lty_eban,
      lw_marc           TYPE lty_marc,
      lw_t460a          TYPE lty_t460a.

    DATA:
      li_material_stock TYPE HASHED TABLE OF lty_material_stock WITH UNIQUE KEY supplying_plant material,
      li_eban           TYPE TABLE OF lty_eban,
      li_marc           TYPE TABLE OF lty_marc,
      li_t460a          TYPE TABLE OF lty_t460a.

    DATA:
      lr_plant TYPE RANGE OF werks_d.

    DATA:
      lv_plant TYPE werks_d,
      lv_lgort TYPE lgort_d,
      lv_ekorg TYPE ekorg.


    "Métodos privados
    METHODS:
      get_tvarv,
      get_materials
        RETURNING VALUE(rv_find_materials) TYPE abap_bool,
      get_elegible_plant
        RETURNING VALUE(rv_find_plant) TYPE abap_bool,
      get_purchase_requisition,
      get_material_stock
        CHANGING
          w_material_stock TYPE lty_material_stock,
      assign_quantities,
      check_authorization,
      create_stock_transfer_order,
      create_return,
      generate_process_log
        IMPORTING iv_process  TYPE char20
                  iv_document TYPE char10
                  iv_position TYPE numc5
                  iv_material TYPE matnr
                  iv_plant    TYPE werks_d
                  iv_quantity TYPE menge_d
                  iv_unimed   TYPE meins
                  iv_message  TYPE char255.

ENDCLASS.

CLASS cl_virtual_stock IMPLEMENTATION.

  METHOD constructor.

    " Asignar centro desde parámetro de pantalla
    lv_plant = iv_plant.

    "Obtener variables de configuración
    get_tvarv( ).

  ENDMETHOD.

  METHOD virtual_stock_process.

    CLEAR rv_error.

    TRY.

        "Obtiene materiales
        IF get_materials( ) = abap_true.

          "Selección de centros elegibles en base a día de surtido
          IF get_elegible_plant( ) = abap_true.

            "Seleccionar solicitudes de pedido
            get_purchase_requisition( ).

            "Asignar cantidades
            assign_quantities( ).

            "Revisar autorizaciones
            check_authorization( ).

            "Crear pedidos de traslado
            create_stock_transfer_order( ).

            "Crear devolución del sobrante
            create_return( ).

          ELSE.
            rv_error = abap_true.
          ENDIF.

        ELSE.
          rv_error = abap_true.
        ENDIF.

      CATCH cx_root INTO DATA(lo_exception) ##CATCH_ALL.
        MESSAGE e911(fb) WITH TEXT-004 lo_exception->get_text( ). "Error en procesamiento:

    ENDTRY.
  ENDMETHOD.

  METHOD get_tvarv.
    "Obtener configuración desde TVARV

    SELECT SINGLE low
      FROM tvarvc                                       "#EC CI_NOORDER
      INTO lv_plant
      WHERE name = c_werks_var
        AND type = c_p ##WARN_OK.
    IF sy-subrc <> 0.
      CLEAR lv_plant.
    ENDIF.

    SELECT SINGLE low
      FROM tvarvc                                       "#EC CI_NOORDER
      INTO lv_lgort
      WHERE name = c_lgort_var
        AND type = c_p ##WARN_OK.
    IF sy-subrc <> 0.
      CLEAR lv_lgort.
    ENDIF.

    SELECT SINGLE low
      FROM tvarvc                                       "#EC CI_NOORDER
      INTO lv_ekorg
      WHERE name = c_ekorg_var
        AND type = c_p ##WARN_OK.
    IF sy-subrc <> 0.
      CLEAR lv_ekorg.
    ENDIF.

  ENDMETHOD.

  METHOD get_materials.

    CLEAR rv_find_materials.

    "Obtiene Materiales externos proveedor
    SELECT idarchivo
           consecutivo
           fecha
           proveedor
           materialpro
           materialsap
           unimed
           cantidad
           precio
           numoc
           docentmerc
      FROM ztamm_expro                                  "#EC CI_NOFIRST
      INTO TABLE i_zmm_expro
      WHERE fecha = sy-datum.
    IF sy-subrc = 0.
      rv_find_materials = abap_true.
      SORT i_zmm_expro BY materialsap.
    ELSE.
      MESSAGE s908(fb) WITH TEXT-005. "No se encontraron materiales
    ENDIF.

  ENDMETHOD.

  METHOD get_elegible_plant.

    TYPES:
      BEGIN OF lty_cal_mrp,
        werks     TYPE ztamm_cal_mrp-werks,
        tipo      TYPE ztamm_cal_mrp-tipo,
        puwnr     TYPE ztamm_cal_mrp-puwnr,
        active    TYPE ztamm_cal_mrp-active,
        period    TYPE ztamm_cal_mrp-period,
        moday     TYPE ztamm_cal_mrp-moday,
        tuday     TYPE ztamm_cal_mrp-tuday,
        weday     TYPE ztamm_cal_mrp-weday,
        thday     TYPE ztamm_cal_mrp-thday,
        frday     TYPE ztamm_cal_mrp-frday,
        saday     TYPE ztamm_cal_mrp-saday,
        suday     TYPE ztamm_cal_mrp-suday,
        runtime   TYPE ztamm_cal_mrp-runtime,
        varid     TYPE ztamm_cal_mrp-varid,
        versl     TYPE ztamm_cal_mrp-versl,
        plmod     TYPE ztamm_cal_mrp-plmod,
        baner     TYPE ztamm_cal_mrp-baner,
        trmpl     TYPE ztamm_cal_mrp-trmpl,
        dispo     TYPE ztamm_cal_mrp-dispo,
        uname     TYPE ztamm_cal_mrp-uname,
        smtp_addr TYPE ztamm_cal_mrp-smtp_addr,
        lastrun   TYPE ztamm_cal_mrp-lastrun,
        pedadv    TYPE ztamm_cal_mrp-pedadv,
        remarks   TYPE ztamm_cal_mrp-remarks,
      END OF lty_cal_mrp,

      BEGIN OF lty_except_mrp,
        puwnr     TYPE ztamm_except_mrp-puwnr,
        werks     TYPE ztamm_except_mrp-werks,
        tipo      TYPE ztamm_except_mrp-tipo,
        planum    TYPE ztamm_except_mrp-planum,
        advance   TYPE ztamm_except_mrp-advance,
        noexec    TYPE ztamm_except_mrp-noexec,
        dateori   TYPE ztamm_except_mrp-dateori,
        dateadv   TYPE ztamm_except_mrp-dateadv,
        reason    TYPE ztamm_except_mrp-reason,
        createby  TYPE ztamm_except_mrp-createby,
        createon  TYPE ztamm_except_mrp-createon,
        processed TYPE ztamm_except_mrp-processed,
      END OF lty_except_mrp.

    DATA:
      lw_cal_mrp    TYPE lty_cal_mrp,
      lw_except_mrp TYPE lty_except_mrp.

    DATA:
      li_cal_mrp    TYPE TABLE OF lty_cal_mrp,
      li_except_mrp TYPE TABLE OF lty_except_mrp.

    DATA:
      lv_day     TYPE p,
      lv_where   TYPE string,
      lv_day_str TYPE string.

    CLEAR rv_find_plant.

    "Obtiene día de la semana
    CALL FUNCTION 'DAY_IN_WEEK'
      EXPORTING
        datum = p_edate
      IMPORTING
        wotnr = lv_day.

    "Crea consulta dinámica
    CASE lv_day.
      WHEN 1. lv_day_str = |MODAY = 'X'|.
      WHEN 2. lv_day_str = |TUDAY = 'X'|.
      WHEN 3. lv_day_str = |WEDAY = 'X'|.
      WHEN 4. lv_day_str = |THDAY = 'X'|.
      WHEN 5. lv_day_str = |FRDAY = 'X'|.
      WHEN 6. lv_day_str = |SADAY = 'X'|.
      WHEN 7. lv_day_str = |SUDAY = 'X'|.
    ENDCASE.

    " Construir WHERE completo
    lv_where = |TIPO = 'M'|.
    IF lv_day_str IS NOT INITIAL.
      lv_where = |{ lv_where } AND { lv_day_str }|.
    ENDIF.

    "Obtener información de calendario para la ejecución del día
    SELECT werks
           tipo
           puwnr
           active
           period
           moday
           tuday
           weday
           thday
           frday
           saday
           suday
           runtime
           varid
           versl
           plmod
           baner
           trmpl
           dispo
           uname
           smtp_addr
           lastrun
           pedadv
           remarks
     FROM ztamm_cal_mrp
     INTO TABLE li_cal_mrp
     WHERE (lv_where).
    IF sy-subrc = 0.
      SORT li_cal_mrp BY werks puwnr.
    ENDIF.

    "Obtiene Adelanto de Pedidos
    SELECT puwnr
           werks
           tipo
           planum
           advance
           noexec
           dateori
           dateadv
           reason
           createby
           createon
           processed
      FROM ztamm_except_mrp                             "#EC CI_NOFIELD
      INTO TABLE li_except_mrp
      WHERE tipo = c_m
        AND advance = c_a
        AND dateadv = sy-datum
        AND processed = space.
    IF sy-subrc = 0.
      SORT li_except_mrp
        BY puwnr werks.
    ENDIF.

    "Obtiene centros
    LOOP AT li_cal_mrp INTO lw_cal_mrp.

      READ TABLE li_except_mrp INTO lw_except_mrp
                               WITH KEY puwnr = lw_cal_mrp-puwnr
                                        werks = lw_cal_mrp-werks
                               BINARY SEARCH.
      IF sy-subrc = 0.
        "Construir rango de centros elegibles
        APPEND VALUE #( sign = c_i option = c_eq low = lw_except_mrp-werks ) TO lr_plant.
      ELSE.
        APPEND VALUE #( sign = c_i option = c_eq low = lw_cal_mrp-werks ) TO lr_plant.
      ENDIF.

    ENDLOOP.

    IF lr_plant[] IS NOT INITIAL.
      rv_find_plant = abap_true.
    ELSE.
      MESSAGE s908(fb) WITH TEXT-006. "No se encontraron plantas elegibles
    ENDIF.

  ENDMETHOD.

  METHOD get_purchase_requisition.

    DATA:
      lv_cantidad TYPE eban-menge.

    IF i_zmm_expro[] IS NOT INITIAL AND
       lr_plant[] IS NOT INITIAL.

      "Obtiene solicitudes de pedido
      SELECT banfn
             bnfpo
             loekz
             matnr
             werks
             reswk
             menge
             meins
             lfdat
             pstyp
             bsmng
             banpr
        FROM eban
        INTO TABLE li_eban
        FOR ALL ENTRIES IN i_zmm_expro
        WHERE matnr = i_zmm_expro-materialsap
          AND ( banpr = c_activo OR
                banpr = c_liberada )
          AND pstyp = c_pstyp_traslado
          AND loekz = space
          AND reswk = c_centro_3030
          AND werks IN lr_plant. "Solo centros elegibles
      IF sy-subrc = 0.
        "Ordenar por fecha de entrega (antigüedad)
        SORT li_eban BY lfdat ASCENDING.

        "Obtiene cantidad de material en centro
        LOOP AT li_eban INTO lw_eban.

          lv_cantidad = lw_eban-menge - lw_eban-bsmng.
          IF lv_cantidad <= 0.
            DELETE li_eban INDEX sy-tabix.
            CONTINUE.
          ENDIF.

          lw_material_stock-supplying_plant = lw_eban-reswk.
          lw_material_stock-material = lw_eban-matnr.
          lw_material_stock-unit = lw_eban-meins.

          "Determinar material no colocado
          get_material_stock( CHANGING
                                 w_material_stock = lw_material_stock ).

          INSERT lw_material_stock INTO TABLE li_material_stock.
          CLEAR lw_material_stock.

        ENDLOOP.
      ENDIF.

    ENDIF.

  ENDMETHOD.

  METHOD get_material_stock.

    DATA:
      lw_wmdvex TYPE bapiwmdve.

    DATA:
      li_wmdvsx TYPE TABLE OF bapiwmdvs,
      li_wmdvex TYPE TABLE OF bapiwmdve.

    "Obtiene material disponible
    CALL FUNCTION 'BAPI_MATERIAL_AVAILABILITY'
      EXPORTING
        plant      = w_material_stock-supplying_plant
        material   = w_material_stock-material
        unit       = w_material_stock-unit
        check_rule = c_check_rule
        stge_loc   = c_stge_loc
      TABLES
        wmdvsx     = li_wmdvsx
        wmdvex     = li_wmdvex.

    READ TABLE li_wmdvex INTO lw_wmdvex INDEX 1.
    IF sy-subrc = 0.
      w_material_stock-com_qty = lw_wmdvex-com_qty.
      w_material_stock-ava_qty = lw_wmdvex-com_qty.
    ENDIF.

  ENDMETHOD.

  METHOD assign_quantities.

    DATA:
      lw_asignacion TYPE ty_asignacion.

    DATA:
      lv_cantidad_requerida TYPE menge_d.

    SORT i_zmm_expro
      BY materialsap.

    LOOP AT li_eban INTO lw_eban.

      " Contador: procesados (cada material en stock)
      lv_assign_procesados = lv_assign_procesados + 1.

      READ TABLE li_material_stock ASSIGNING FIELD-SYMBOL(<lfs_material_stock>)
                                   WITH KEY material = lw_eban-matnr.

      IF sy-subrc = 0.

        lv_cantidad_requerida = lw_eban-menge - lw_eban-bsmng.

        IF <lfs_material_stock>-ava_qty >= lv_cantidad_requerida.
          "Asignación completa
          lw_asignacion-cantas = lv_cantidad_requerida.
          <lfs_material_stock>-ava_qty = <lfs_material_stock>-ava_qty - lv_cantidad_requerida.
        ELSEIF lw_material_stock-ava_qty > 0.
          "Asignación parcial (último pedido)
          lw_asignacion-cantas = <lfs_material_stock>-ava_qty.
          <lfs_material_stock>-ava_qty = 0.
        ELSE.
          "Sin stock disponible
          CONTINUE.
        ENDIF.

        "Completar datos de asignación
        lw_asignacion-matnr = lw_eban-matnr.
        lw_asignacion-menge = lw_eban-menge.
        lw_asignacion-meins = lw_eban-meins.
        lw_asignacion-werks = lw_eban-werks.
        lw_asignacion-banfn = lw_eban-banfn.
        lw_asignacion-bnfpo = lw_eban-bnfpo.
        lw_asignacion-lfdat = lw_eban-lfdat.

        "Obtener datos de OC/EM
        READ TABLE i_zmm_expro INTO w_zmm_expro
                               WITH KEY materialsap = lw_eban-matnr
                               BINARY SEARCH.
        IF sy-subrc = 0.
          lw_asignacion-ebeln = w_zmm_expro-numoc.
          lw_asignacion-mblnr = w_zmm_expro-docentmerc.
          lw_asignacion-aedat = w_zmm_expro-fecha.
        ENDIF.

        APPEND lw_asignacion TO i_asignaciones.

        " Contador: exitosos (asignación realizada)
        lv_assign_exitosos = lv_assign_exitosos + 1.

        IF <lfs_material_stock>-ava_qty = 0.
          EXIT. "No hay más stock para este material
        ENDIF.

      ENDIF.

    ENDLOOP.

    " Calcular errores de asignación (procesados sin éxito)
    lv_assign_errores = lv_assign_procesados - lv_assign_exitosos.
    IF lv_assign_errores < 0.
      lv_assign_errores = 0.
    ENDIF.

  ENDMETHOD.

  METHOD check_authorization.

    LOOP AT i_asignaciones INTO DATA(lw_asignaciones).

      " Validacíón de autorización a centro
      AUTHORITY-CHECK OBJECT 'M_MATE_WRK'
                          ID 'WERKS' FIELD lw_asignaciones-werks
                          ID 'ACTVT' FIELD '02'.
      IF sy-subrc <> 0.
        DELETE i_asignaciones INDEX sy-tabix.
        CONTINUE.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.

  METHOD create_stock_transfer_order.

    TYPES:
      BEGIN OF lty_banfn,
        banfn TYPE banfn,
      END OF lty_banfn.

    DATA:
      lw_poheader            TYPE bapimepoheader,
      lw_poheaderx           TYPE bapimepoheaderx,
      lw_poitem              TYPE bapimepoitem,
      lw_poitemx             TYPE bapimepoitemx,
      lw_poschedule          TYPE bapimeposchedule,
      lw_poschedulex         TYPE bapimeposchedulx,
      lw_extensionin         TYPE bapiparex,
      lw_bapi_te_mepoheader  TYPE bapi_te_mepoheader,
      lw_bapi_te_mepoheaderx TYPE bapi_te_mepoheaderx,
      lw_solicitudes_unicas  TYPE lty_banfn.

    DATA:
      li_poitem             TYPE TABLE OF bapimepoitem,
      li_poitemx            TYPE TABLE OF bapimepoitemx,
      li_poschedule         TYPE TABLE OF bapimeposchedule,
      li_poschedulex        TYPE TABLE OF bapimeposchedulx,
      li_extensionin        TYPE TABLE OF bapiparex,
      li_return             TYPE TABLE OF bapiret2,
      li_solicitudes_unicas TYPE HASHED TABLE OF lty_banfn WITH UNIQUE KEY banfn,
      li_asignaciones_c     TYPE TABLE OF ty_asignacion.

    CONSTANTS:
      lc_bapi_te_mepoheader  TYPE char18 VALUE 'BAPI_TE_MEPOHEADER',
      lc_bapi_te_mepoheaderx TYPE char19 VALUE 'BAPI_TE_MEPOHEADERX'.

    DATA:
      lv_ponumber      TYPE bapimepoheader-po_number,
      lv_grupo_compras TYPE ekgrp,
      lv_poitem        TYPE ebelp,
      lv_sched_line    TYPE etenr,
      lv_message       TYPE char255,
      lv_messages      TYPE char255.

    IF i_asignaciones[] IS NOT INITIAL.

      "Agrupar asignaciones por solicitud de pedido
      LOOP AT i_asignaciones INTO DATA(lw_asignaciones).

        " Validar que el registro no exista antes de insertar
        READ TABLE li_solicitudes_unicas
          WITH TABLE KEY banfn = lw_asignaciones-banfn
          TRANSPORTING NO FIELDS.
        " Tabla hashed no requiere binary search
        IF sy-subrc <> 0.
          " Solo insertar si no existe
          INSERT VALUE lty_banfn( banfn = lw_asignaciones-banfn )
                 INTO TABLE li_solicitudes_unicas.
        ENDIF.

      ENDLOOP.

      li_asignaciones_c = i_asignaciones[].
      SORT li_asignaciones_c
        BY matnr.
      DELETE ADJACENT DUPLICATES FROM li_asignaciones_c COMPARING matnr.
      IF li_asignaciones_c[] IS NOT INITIAL.
        " Obtener grupos de compras
        SELECT matnr werks ekgrp
          FROM marc
          INTO TABLE li_marc
          FOR ALL ENTRIES IN li_asignaciones_c
          WHERE matnr = li_asignaciones_c-matnr
            AND werks = lv_plant.
        IF sy-subrc = 0.
          SORT li_marc
            BY matnr werks.
        ENDIF.
      ENDIF.

      li_asignaciones_c = i_asignaciones[].
      SORT li_asignaciones_c
        BY werks.
      DELETE ADJACENT DUPLICATES FROM li_asignaciones_c COMPARING werks.
      IF li_asignaciones_c[] IS NOT INITIAL.
        "Obtener centro proveedor
        SELECT werks sobsl wrk02
          FROM t460a
          INTO TABLE li_t460a
          FOR ALL ENTRIES IN li_asignaciones_c
          WHERE werks = li_asignaciones_c-werks
            AND sobsl = c_sobsl.
        IF sy-subrc = 0.
          SORT li_t460a
            BY werks sobsl.
        ENDIF.
      ENDIF.

      SORT i_asignaciones
        BY banfn.

      "Crear un pedido por cada solicitud única
      LOOP AT li_solicitudes_unicas INTO lw_solicitudes_unicas.
        CLEAR: lw_poheader, lw_poheaderx, li_poitem,
               li_poitemx, li_poschedule, li_poschedulex, li_return,
               lv_ponumber.

        " Contador: procesados
        lv_sto_procesados = lv_sto_procesados + 1.

        "Obtener grupo de compras del primer material
        READ TABLE i_asignaciones INTO lw_asignaciones
                                  WITH KEY banfn = lw_solicitudes_unicas-banfn
                                  BINARY SEARCH.
        IF sy-subrc = 0.
          READ TABLE li_marc INTO lw_marc
                             WITH KEY matnr = lw_asignaciones-matnr
                                      werks = lv_plant
                             BINARY SEARCH.
          IF sy-subrc = 0.
            lv_grupo_compras = lw_marc-ekgrp.
          ENDIF.
        ENDIF.

        "Cabecera del pedido
        lw_poheader-doc_type = c_doc_type_zubv.
        lw_poheader-purch_org = lv_ekorg.
        lw_poheader-pur_group = lv_grupo_compras.

        "Obtener centro proveedor
        READ TABLE li_t460a INTO lw_t460a
                            WITH KEY werks = lw_asignaciones-werks
                                     sobsl = c_sobsl
                            BINARY SEARCH.
        IF sy-subrc = 0.
          lw_poheader-suppl_plnt = lw_t460a-wrk02.
        ENDIF.

        lw_poheaderx-doc_type = c_x.
        lw_poheaderx-purch_org = c_x.
        lw_poheaderx-pur_group = c_x.
        lw_poheaderx-suppl_plnt = c_x.

        LOOP AT i_asignaciones INTO lw_asignaciones.

          IF lw_asignaciones-banfn = lw_solicitudes_unicas-banfn AND
             lw_asignaciones-cantas > 0.

            CLEAR: lw_poitem, lw_poitemx,
                   lw_poschedule, lw_poschedulex.

            "Incrementar número de posición
            lv_poitem = lv_poitem + 10.
            lv_sched_line = lv_sched_line + 1.

            "Completar posición del pedido
            lw_poitem-po_item   = lv_poitem.
            lw_poitem-material  = lw_asignaciones-matnr.
            lw_poitem-plant     = lw_asignaciones-werks.
            lw_poitem-stge_loc  = lv_lgort.
            lw_poitem-quantity  = lw_asignaciones-cantas.
            lw_poitem-po_unit   = lw_asignaciones-meins.
            lw_poitem-preq_no   = lw_asignaciones-banfn.
            lw_poitem-preq_item = lw_asignaciones-bnfpo.
            lw_poitem-period_ind_expiration_date = c_d.

            lw_poitemx-po_item   = lv_poitem.
            lw_poitemx-po_itemx  = c_x.
            lw_poitemx-material  = c_x.
            lw_poitemx-plant     = c_x.
            lw_poitemx-stge_loc  = c_x.
            lw_poitemx-quantity  = c_x.
            lw_poitemx-po_unit   = c_x.
            lw_poitemx-preq_no   = c_x.
            lw_poitemx-preq_item = c_x.
            lw_poitemx-period_ind_expiration_date = c_x.

            APPEND lw_poitem TO li_poitem.
            APPEND lw_poitemx TO li_poitemx.

            lw_poschedule-po_item       = lv_poitem.
            lw_poschedule-sched_line    = lv_sched_line.
            lw_poschedule-delivery_date = sy-datum.
            lw_poschedule-quantity      = lw_asignaciones-cantas.
            lw_poschedule-preq_no       = lw_asignaciones-banfn.
            lw_poschedule-preq_item     = lw_asignaciones-bnfpo.

            lw_poschedulex-po_item       = lv_poitem.
            lw_poschedulex-sched_line    = lv_sched_line.
            lw_poschedulex-delivery_date = c_x.
            lw_poschedulex-quantity      = c_x.
            lw_poschedulex-preq_no       = c_x.
            lw_poschedulex-preq_item     = c_x.

            APPEND lw_poschedule TO li_poschedule.
            APPEND lw_poschedulex TO li_poschedulex.

          ENDIF.
        ENDLOOP.

        "Asigna campo adicional
        lw_bapi_te_mepoheader-zztipo_comp = '01'.
        lw_extensionin-structure  = lc_bapi_te_mepoheader.
        lw_extensionin-valuepart1 = lw_bapi_te_mepoheader-zztipo_comp.
        APPEND lw_extensionin TO li_extensionin.

        lw_bapi_te_mepoheaderx-zztipo_comp = 'X'.
        lw_extensionin-structure  = lc_bapi_te_mepoheaderx.
        lw_extensionin-valuepart1 = lw_bapi_te_mepoheaderx.
        APPEND lw_extensionin TO li_extensionin.

        IF lw_poheader IS NOT INITIAL AND
           li_poitem[] IS NOT INITIAL AND
           li_poschedule[] IS NOT INITIAL.

          "Crear pedido de traslado
          CALL FUNCTION 'BAPI_PO_CREATE1'
            EXPORTING
              poheader         = lw_poheader
              poheaderx        = lw_poheaderx
            IMPORTING
              exppurchaseorder = lv_ponumber
            TABLES
              poitem           = li_poitem
              poitemx          = li_poitemx
              poschedule       = li_poschedule
              poschedulex      = li_poschedulex
              extensionin      = li_extensionin
              return           = li_return.

          "Verificar errores
          READ TABLE li_return TRANSPORTING NO FIELDS
                               WITH KEY type = 'E'.
          "No requiere binary search ya que solo busca si ocurrio error
          IF sy-subrc = 0.
            "Registrar error
            LOOP AT li_return INTO DATA(lw_return).
              IF lw_return-type = 'E'.
                MESSAGE ID lw_return-id TYPE lw_return-type NUMBER lw_return-number
                                        WITH lw_return-message_v1 lw_return-message_v2
                                             lw_return-message_v3 lw_return-message_v4
                                        INTO lv_message.

                lv_messages = |{ lv_messages } / { lv_message }|.
              ENDIF.
            ENDLOOP.

            " Contador: errores
            lv_sto_errores = lv_sto_errores + 1.

            generate_process_log(
                iv_document  = lw_asignaciones-banfn
                iv_position  = lw_asignaciones-bnfpo
                iv_material  = lw_asignaciones-matnr
                iv_plant     = lw_asignaciones-werks
                iv_quantity  = lw_asignaciones-cantas
                iv_unimed    = lw_asignaciones-meins
                iv_process   = c_proceso_po
                iv_message   = lv_message ).

          ELSE.
            "Confirmar transacción
            CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
              EXPORTING
                wait = c_x.

            " Contador: exitosos
            lv_sto_exitosos = lv_sto_exitosos + 1.

            "Actualizar datos de asignación con número de pedido
            READ TABLE i_asignaciones INTO DATA(lw_asig_temp)
                                      WITH KEY banfn = lw_solicitudes_unicas-banfn
                                      BINARY SEARCH.
            IF sy-subrc = 0.
              lw_asig_temp-transfer_order = lv_ponumber.
              MODIFY i_asignaciones FROM lw_asig_temp INDEX sy-tabix.
            ENDIF.

          ENDIF.
        ENDIF.
      ENDLOOP.

    ENDIF.

  ENDMETHOD.

  METHOD create_return.

    TYPES:
      BEGIN OF lty_ekpo,
        ebeln TYPE ekpo-ebeln,
        ebelp TYPE ekpo-ebelp,
        matnr TYPE ekpo-matnr,
        meins TYPE ekpo-meins,
      END OF lty_ekpo.

    DATA:
      lw_goodsmvt_header TYPE bapi2017_gm_head_01,
      lw_goodsmvt_code   TYPE bapi2017_gm_code,
      lw_goodsmvt_item   TYPE bapi2017_gm_item_create,
      lw_return          TYPE bapiret2,
      lw_ekpo            TYPE lty_ekpo.

    DATA:
      li_goodsmvt_item TYPE TABLE OF bapi2017_gm_item_create,
      li_return        TYPE TABLE OF bapiret2,
      li_ekpo          TYPE TABLE OF lty_ekpo.

    DATA:
      lv_materialdocument TYPE mblnr ##NEEDED,
      lv_matdocumentyear  TYPE mjahr ##NEEDED,
      lv_test_run         TYPE xfeld,
      lv_total_asignado   TYPE menge_d,
      lv_sobrante         TYPE menge_d,
      lv_message          TYPE char255,
      lv_messages         TYPE char255.


    IF li_material_stock[] IS NOT INITIAL.

      IF i_zmm_expro[] IS NOT INITIAL.
        "Obtiene información de la orden de compra
        SELECT ebeln
               ebelp
               matnr
               meins
          FROM ekpo
          INTO TABLE li_ekpo
          FOR ALL ENTRIES IN i_zmm_expro
          WHERE ebeln = i_zmm_expro-numoc.
        IF sy-subrc = 0.
          SORT li_ekpo BY matnr.
        ENDIF.
      ENDIF.

      "Configurar cabecera del movimiento
      lw_goodsmvt_header-pstng_date = sy-datum.
      lw_goodsmvt_header-doc_date = sy-datum.
      lw_goodsmvt_header-header_txt = TEXT-001. "Devolución Mercancía Virtual.
      lw_goodsmvt_code-gm_code = c_gm_code_01.

      "Calcular sobrante no asignado por material
      LOOP AT li_material_stock INTO DATA(lw_material_stock).

        "Calcular total asignado para este material
        CLEAR: lv_total_asignado.
        LOOP AT i_asignaciones INTO DATA(lw_asignaciones).
          IF lw_asignaciones-matnr = lw_material_stock-material.
            lv_total_asignado = lv_total_asignado + lw_asignaciones-cantas.
          ENDIF.
        ENDLOOP.

        "Calcular sobrante
        lv_sobrante = lw_material_stock-com_qty - lv_total_asignado.

        IF lv_sobrante > 0.
          "Preparar posición de devolución
          CLEAR: lw_goodsmvt_item.

          lw_goodsmvt_item-plant     = lv_plant.
          lw_goodsmvt_item-stge_loc  = c_stge_loc.
          lw_goodsmvt_item-move_type = c_bwart_devolucion.
          lw_goodsmvt_item-entry_qnt = lv_sobrante.
          lw_goodsmvt_item-mvt_ind   = c_b.
          lw_goodsmvt_item-move_reas = c_move_reas_incomp.

          "Obtener datos de OC original
          READ TABLE li_ekpo INTO lw_ekpo
                             WITH KEY matnr = lw_material_stock-material
                             BINARY SEARCH.
          IF sy-subrc = 0.
            lw_goodsmvt_item-po_number = lw_ekpo-ebeln.
            lw_goodsmvt_item-po_item = lw_ekpo-ebelp.
          ENDIF.

          APPEND lw_goodsmvt_item TO li_goodsmvt_item.
        ENDIF.
      ENDLOOP.

      " Contador: procesados (una llamada al BAPI)
      IF li_goodsmvt_item[] IS NOT INITIAL.
        lv_return_procesados = lv_return_procesados + 1.
      ENDIF.

      REFRESH: li_return.

      CALL FUNCTION 'BAPI_GOODSMVT_CREATE'
        EXPORTING
          goodsmvt_header  = lw_goodsmvt_header
          goodsmvt_code    = lw_goodsmvt_code
          testrun          = lv_test_run
        IMPORTING
          materialdocument = lv_materialdocument
          matdocumentyear  = lv_matdocumentyear
        TABLES
          goodsmvt_item    = li_goodsmvt_item
          return           = li_return.

      "Verificar resultado final
      READ TABLE li_return TRANSPORTING NO FIELDS
                           WITH KEY type = 'E'.
      "No requiere binary search ya que solo busca si ocurrio error
      IF sy-subrc = 0.
        "Registrar errores finales
        LOOP AT li_return INTO lw_return.
          IF lw_return-type = 'E'.

            MESSAGE ID lw_return-id TYPE lw_return-type NUMBER lw_return-number
                                    WITH lw_return-message_v1 lw_return-message_v2
                                         lw_return-message_v3 lw_return-message_v4
                                    INTO lv_message.

            lv_messages = |{ lv_messages } / { lv_message }|.

          ENDIF.
        ENDLOOP.

        " Contador: errores
        lv_return_errores = lv_return_errores + 1.

        READ TABLE li_goodsmvt_item INTO lw_goodsmvt_item
                                    INDEX 1.
        IF sy-subrc = 0.
          generate_process_log(
               iv_document  = lw_goodsmvt_item-po_number
               iv_position  = lw_goodsmvt_item-po_item
               iv_material  = lw_goodsmvt_item-material
               iv_plant     = lw_goodsmvt_item-plant
               iv_quantity  = lw_goodsmvt_item-quantity
               iv_unimed    = lw_goodsmvt_item-entry_uom
               iv_process   = c_proceso_dev
               iv_message   = lv_message ).
        ENDIF.


      ELSE.
        "Confirmar transacción
        CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
          EXPORTING
            wait = c_x.

        " Contador: exitosos
        lv_return_exitosos = lv_return_exitosos + 1.
        lv_return_qty = lv_sobrante.
      ENDIF.

    ENDIF.

  ENDMETHOD.

  METHOD generate_process_log.

    DATA:
      lw_error TYPE ztamm_virtstock.

    lw_error-idproc   = iv_process.
    lw_error-rec_date = sy-datum.
    lw_error-rec_time = sy-timlo.
    lw_error-numdoc   = iv_document.
    lw_error-docitem  = iv_position.
    lw_error-material = iv_material.
    lw_error-plant    = iv_plant.
    lw_error-quantity = iv_quantity.
    lw_error-uom      = iv_unimed.
    lw_error-message  = iv_message.

    "Insertar en tabla de log de errores
    INSERT ztamm_virtstock FROM lw_error.
    IF sy-subrc = 0.
      COMMIT WORK.
    ENDIF.

  ENDMETHOD.

ENDCLASS.

*----------------------------------------------------------------------*
* FORM: validate selection
* Descripción: Validaciones de pantalla de selección
*----------------------------------------------------------------------*
FORM f_validate_selection.

  DATA:
    lv_weekday TYPE i.

  "Validar que la fecha no sea futura
  IF p_edate > sy-datum.
    MESSAGE e908(fb) WITH TEXT-002. "La fecha no puede ser futura
  ENDIF.

  "Obtiene día
  CALL FUNCTION 'DEV_GET_DAY_OF_WEEK'
    EXPORTING
      i_day     = sy-datum
    IMPORTING
      e_weekday = lv_weekday.

  "Validar día de la semana (solo lunes a viernes)
  IF lv_weekday NOT BETWEEN 1 AND 5.
    MESSAGE e908(fb) WITH TEXT-003. "El proceso solo ejecuta de lunes a viernes
  ENDIF.

ENDFORM.

*-------------------------------------------------------------------------------*
* FORM f_main_process                                                           *
* Proceso principal del programa                                                *
*-------------------------------------------------------------------------------*
FORM f_main_process.

  DATA:
    lo_virtual_stock TYPE REF TO cl_virtual_stock.

  "Crear instancia de la clase principal
  CREATE OBJECT lo_virtual_stock
    EXPORTING
      iv_plant = p_plant.

  IF lo_virtual_stock->virtual_stock_process( ) = abap_false.

    " Transferir contadores a variables globales: Asignación
    v_assign_procesados = lo_virtual_stock->lv_assign_procesados.
    v_assign_exitosos   = lo_virtual_stock->lv_assign_exitosos.
    v_assign_errores    = lo_virtual_stock->lv_assign_errores.

    " Transferir contadores: Pedido de traslado
    v_sto_procesados = lo_virtual_stock->lv_sto_procesados.
    v_sto_exitosos   = lo_virtual_stock->lv_sto_exitosos.
    v_sto_errores    = lo_virtual_stock->lv_sto_errores.

    " Transferir contadores: Devolución
    v_return_procesados = lo_virtual_stock->lv_return_procesados.
    v_return_exitosos   = lo_virtual_stock->lv_return_exitosos.
    v_return_errores    = lo_virtual_stock->lv_return_errores.

    " Cantidad devuelta
    v_return_quantity = lo_virtual_stock->lv_return_qty.

    " Muestra el resultado del proceso
    PERFORM f_show_results.

  ENDIF.

ENDFORM.
*----------------------------------------------------------------------*
* FORM: f_show_results
* Descripción: Mostrar estadísticas del proceso
*----------------------------------------------------------------------*
FORM f_show_results.

  " Encabezado
  WRITE: / TEXT-s01.                                  "Estadísticas del proceso:
  WRITE: / |{ TEXT-s02 } { p_edate }|.                "Fecha de proceso:
  WRITE: / |{ TEXT-s03 } { p_plant }|.                "Centro:
  SKIP.

  " Proceso: Assign Quantities
  WRITE: / TEXT-p01.                                  "Asignación
  WRITE: / TEXT-h01.                                  "procesados  exitosos  errores
  WRITE: / v_assign_procesados UNDER TEXT-h01,
           v_assign_exitosos,
           v_assign_errores.
  SKIP.

  " Proceso: Stock Transfer Order
  WRITE: / TEXT-p02.                                  "Pedido de traslado MERV
  WRITE: / TEXT-h01.                                  "procesados  exitosos  errores
  WRITE: / v_sto_procesados UNDER TEXT-h01,
           v_sto_exitosos,
           v_sto_errores.
  SKIP.

  " Proceso: Create Return
  WRITE: / TEXT-p03.                                  "Devolución
  WRITE: / TEXT-h01.                                  "procesados  exitosos  errores
  WRITE: / v_return_procesados UNDER TEXT-h01,
           v_return_exitosos,
           v_return_errores.
  SKIP.

  " Cantidad devuelta
  WRITE: / |{ TEXT-s07 } { v_return_quantity }|.      "Cantidad devuelta:

ENDFORM.