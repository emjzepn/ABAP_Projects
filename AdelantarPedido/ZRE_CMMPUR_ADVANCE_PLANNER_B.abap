*-------------------------------------------------------------------------------*
*                   Fabrica de Software ABAP NEORIS                             *
*-------------------------------------------------------------------------------*
* Nombre del Programa : ZRE_CMMPUR_ADVANCE_PLANNER_B                            *
* Descripción         : Logica para adelanto de pedidos                         *
* Funcional           : Julio Carrasco                                          *
* Desarrollador       : Edgar Morales  - ABAP_01                                *
* Diseñador Técnico   : Edgar Morales                                           *
* Fecha de Creación   : 06.01.2026                                              *
* ID del Componente   : DF-DMM06                                                *
* Número de Req.      : DMM06                                                   *
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
*----------------------------------------------------------------------*
* Clase principal del planificador de adelantos
*----------------------------------------------------------------------*
CLASS cl_advance_planner DEFINITION FINAL.

  PUBLIC SECTION.
    " Métodos públicos
    METHODS:
      get_advance_planner
        EXPORTING
          ev_okparam             TYPE abap_bool
        RETURNING
          VALUE(ri_advance_plan) TYPE tt_advance_plan,

      get_day
        IMPORTING
          iv_date       TYPE dats
        RETURNING
          VALUE(rv_day) TYPE char1,

      calculate_next_exec_date
        IMPORTING
          iv_werks       TYPE werks_d
          iv_puwnr       TYPE t439c-puwnr
          iv_source      TYPE char1  "'M' = Cal. MRP, 'L' = Cal. Logístico
          iv_start_date  TYPE dats OPTIONAL  "Fecha base para iniciar búsqueda
        RETURNING
          VALUE(rv_date) TYPE dats.

  PRIVATE SECTION.
    " Atributos privados
    DATA:
      li_centro_data  TYPE tt_centro_data,
      li_advance_plan TYPE tt_advance_plan.

    " Métodos privados
    METHODS:
      validate_selection_exists
        RETURNING VALUE(rv_okparam) TYPE abap_bool,

      get_selection_data,

      validate_authorizations
        CHANGING
          ci_advance_plan TYPE tt_advance_plan,

      set_advance_data.

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
        puwnr       TYPE ztamm_except_mrp-puwnr,
        werks       TYPE ztamm_except_mrp-werks,
        tipo        TYPE ztamm_except_mrp-tipo,
        planum      TYPE ztamm_except_mrp-planum,
        advance     TYPE ztamm_except_mrp-advance,
        noexec      TYPE ztamm_except_mrp-noexec,
        noexec_pro  TYPE ztamm_except_mrp-noexec_pro,
        dateori     TYPE ztamm_except_mrp-dateori,
        dateadv     TYPE ztamm_except_mrp-dateadv,
        dateori_pro TYPE ztamm_except_mrp-dateadv_pro,
        dateadv_pro TYPE ztamm_except_mrp-dateadv_pro,
        reason      TYPE ztamm_except_mrp-reason,
        createby    TYPE ztamm_except_mrp-createby,
        createon    TYPE ztamm_except_mrp-createon,
        processed   TYPE ztamm_except_mrp-processed,
        day         TYPE char1,
      END OF lty_except_mrp,

      BEGIN OF lty_cal_log,
        werks    TYPE ztamm_cal_log-werks,
        tipo_cal TYPE ztamm_cal_log-tipo_cal,
        puwnr    TYPE ztamm_cal_log-agr_oper,
        active   TYPE ztamm_cal_log-estatus,
        period   TYPE ztamm_cal_log-period,
        moday    TYPE ztamm_cal_log-moday,
        tuday    TYPE ztamm_cal_log-tuday,
        weday    TYPE ztamm_cal_log-weday,
        thday    TYPE ztamm_cal_log-thday,
        frday    TYPE ztamm_cal_log-frday,
        saday    TYPE ztamm_cal_log-saday,
        suday    TYPE ztamm_cal_log-suday,
        uname    TYPE ztamm_cal_log-uname,
        udate    TYPE ztamm_cal_log-udate,
      END OF lty_cal_log.

    DATA:
      li_cal_mrp TYPE TABLE OF lty_cal_mrp,
      li_cal_log TYPE TABLE OF lty_cal_log.

ENDCLASS.

CLASS cl_advance_planner IMPLEMENTATION.

  METHOD get_advance_planner.

    " Validar que existan datos en la selección
    ev_okparam = validate_selection_exists( ).

    IF ev_okparam IS INITIAL.

      " Obtener datos según criterios de selección
      get_selection_data( ).

      "Valida autorizaciones
      validate_authorizations(
            CHANGING
               ci_advance_plan = li_advance_plan
      ).

      " Agrega información para adelanto de pedido
      set_advance_data( ).

      ri_advance_plan = li_advance_plan.

    ENDIF.

  ENDMETHOD.

  METHOD validate_selection_exists.
    " Validar existencia de agrupaciones en T439C

    " Validar Metro
    IF s_puwnr[] IS NOT INITIAL.
      SELECT puwnr
        UP TO 1 ROWS
        FROM t439c
        INTO @DATA(lv_puwnr)
        WHERE puwnr IN @s_puwnr ##NEEDED.
      ENDSELECT.
      IF sy-subrc <> 0.
        CLEAR lv_puwnr.
        MESSAGE s908(fb) WITH TEXT-002 DISPLAY LIKE 'E'. " Agrup. operativa no existente
        rv_okparam = abap_true.
        RETURN.
      ENDIF.
    ENDIF.

    " Validar Centro
    IF s_werks[] IS NOT INITIAL.
      SELECT werks
        UP TO 1 ROWS
        FROM t001w
        INTO @DATA(lv_werks)
        WHERE werks IN @s_werks ##NEEDED.
      ENDSELECT.
      IF sy-subrc <> 0.
        CLEAR lv_werks.
        MESSAGE s908(fb) WITH TEXT-003 DISPLAY LIKE 'E'. " Centro no existente
        rv_okparam = abap_true.
        RETURN.
      ENDIF.
    ENDIF.

  ENDMETHOD.

  METHOD get_selection_data.

    DATA:
      lw_cal_mrp      TYPE lty_cal_mrp,
      lw_except_mrp   TYPE lty_except_mrp,
      lw_centro_data  TYPE ty_centro_data,
      lw_advance_plan TYPE ty_advance_plan,
      lw_dd07v_a      TYPE dd07v.

    DATA:
      li_except_mrp     TYPE TABLE OF lty_except_mrp,
      li_dd07v_a        TYPE TABLE OF dd07v,
      li_dd07v_n        TYPE TABLE OF dd07v,
      li_keys_with_plan TYPE HASHED TABLE OF ty_advance_plan WITH UNIQUE KEY puwnr plwrk.

    DATA:
      lv_where     TYPE string,
      lv_cond_dias TYPE string,
      lv_first     TYPE abap_bool.

    CLEAR: li_centro_data[],
           li_cal_mrp[],
           li_cal_log[],
           li_except_mrp[],
           v_fabkl.

    " Seleccionar datos de T439C y T001W según criterios
    SELECT c~puwnr AS puwnr
           c~plwrk AS plwrk
           w~name1 AS name1
           w~fabkl AS fabkl
      FROM t439c AS c
      INNER JOIN t001w AS w
         ON c~plwrk = w~werks                          "#EC CI_BUFFJOIN
      INTO TABLE li_centro_data
      WHERE c~puwnr IN s_puwnr
        AND c~plwrk IN s_werks.
    IF sy-subrc = 0.

      lw_centro_data = li_centro_data[ 1 ].

      v_fabkl = lw_centro_data-fabkl.

      " Construir condición dinámica para días ANTES del SELECT
      IF s_day[] IS NOT INITIAL.

        " Obtenemos los valores fijos del dominio ZDOMM_DIA_MRP
        CALL FUNCTION 'DD_DOMA_GET'
          EXPORTING
            domain_name   = 'ZDOMM_DIA_MRP'
            langu         = sy-langu
            withtext      = 'X'
          TABLES
            dd07v_tab_a   = li_dd07v_a
            dd07v_tab_n   = li_dd07v_n
          EXCEPTIONS
            illegal_value = 1
            op_failure    = 2
            OTHERS        = 3.
        IF sy-subrc <> 0.
          RETURN. " Si no encuentra el dominio, salimos
        ENDIF.

        " Filtrar solo los días seleccionados
        DELETE li_dd07v_a WHERE domvalue_l NOT IN s_day.

        " Construir condición con OR entre días
        lv_first = abap_true.
        LOOP AT li_dd07v_a INTO lw_dd07v_a.
          " Agregar OR si no es el primer elemento
          IF lv_first = abap_false.
            lv_cond_dias = |{ lv_cond_dias } OR|.
          ENDIF.
          lv_first = abap_false.

          " Mapear valor del dominio al campo correspondiente
          CASE lw_dd07v_a-domvalue_l.
            WHEN '1'. lv_cond_dias = |{ lv_cond_dias } MODAY = 'X'|.
            WHEN '2'. lv_cond_dias = |{ lv_cond_dias } TUDAY = 'X'|.
            WHEN '3'. lv_cond_dias = |{ lv_cond_dias } WEDAY = 'X'|.
            WHEN '4'. lv_cond_dias = |{ lv_cond_dias } THDAY = 'X'|.
            WHEN '5'. lv_cond_dias = |{ lv_cond_dias } FRDAY = 'X'|.
            WHEN '6'. lv_cond_dias = |{ lv_cond_dias } SADAY = 'X'|.
            WHEN '7'. lv_cond_dias = |{ lv_cond_dias } SUDAY = 'X'|.
          ENDCASE.
        ENDLOOP.

        " Agregar paréntesis a la condición de días
        IF lv_cond_dias IS NOT INITIAL.
          lv_cond_dias = |( { lv_cond_dias } )|.
        ENDIF.

      ENDIF.

      " Construir WHERE completo
      lv_where = |WERKS IN S_WERKS AND TIPO IN S_TIPO AND PUWNR IN S_PUWNR|.
      IF lv_cond_dias IS NOT INITIAL.
        lv_where = |{ lv_where } AND { lv_cond_dias }|.
      ENDIF.

      " Obtener información de calendario por centro con WHERE dinámico
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

      REPLACE 'PUWNR' WITH 'AGR_OPER' INTO lv_where.
      REPLACE 'TIPO'  WITH 'TIPO_CAL' INTO lv_where.

      " Obtener información de Calendario Logístico
      SELECT werks
             tipo_cal
             agr_oper
             estatus
             period
             moday
             tuday
             weday
             thday
             frday
             saday
             suday
             uname
             udate
        FROM ztamm_cal_log
        INTO TABLE li_cal_log
        WHERE (lv_where).
      IF sy-subrc = 0.
        SORT li_cal_log BY werks puwnr.
      ENDIF.
    ENDIF.

    " Obtiene adelantos de planeados
    SELECT puwnr
           werks
           tipo
           planum
           advance
           noexec
           noexec_pro
           dateori
           dateadv
           dateori_pro
           dateadv_pro
           reason
           createby
           createon
           processed
      FROM ztamm_except_mrp
      INTO TABLE li_except_mrp ##TOO_MANY_ITAB_FIELDS
      WHERE puwnr IN s_puwnr
        AND werks IN s_werks
        AND tipo  IN s_tipo.
    IF sy-subrc = 0.
      LOOP AT li_except_mrp ASSIGNING FIELD-SYMBOL(<lfs_except_mrp>).
        IF <lfs_except_mrp>-dateadv IS NOT INITIAL.
          "Asigna el número de día del la semana de acuerdo a la fecha de adelanto
          <lfs_except_mrp>-day = get_day( iv_date = <lfs_except_mrp>-dateadv ).
        ENDIF.
      ENDLOOP.
      "Elimina los registros que no esten en el rango de seleccion de los días
      DELETE li_except_mrp WHERE day NOT IN s_day.

      " Elimina los registros procesados
      IF p_procd IS INITIAL.
        DELETE li_except_mrp WHERE processed = abap_true.
      ENDIF.
    ENDIF.

    SORT li_cal_mrp BY werks tipo puwnr.
    SORT li_except_mrp BY puwnr werks tipo planum.
    SORT li_centro_data BY puwnr plwrk.

    LOOP AT li_cal_mrp INTO lw_cal_mrp.

      READ TABLE li_centro_data INTO lw_centro_data
                                WITH KEY puwnr = lw_cal_mrp-puwnr
                                         plwrk = lw_cal_mrp-werks
                                BINARY SEARCH.
      IF sy-subrc = 0.
        lw_advance_plan-name1 = lw_centro_data-name1.
      ENDIF.

      lw_advance_plan-puwnr = lw_cal_mrp-puwnr.
      lw_advance_plan-plwrk = lw_cal_mrp-werks.
      lw_advance_plan-tipo  = lw_cal_mrp-tipo.

      " Calcular próxima fecha de ejecución si no tiene fecha original
      IF lw_advance_plan-dateori IS INITIAL.
        lw_advance_plan-dateori = calculate_next_exec_date(
                                    iv_werks  = lw_cal_mrp-werks
                                    iv_puwnr  = lw_cal_mrp-puwnr
                                    iv_source = 'M'
                                  ).
      ENDIF.

      IF lw_advance_plan-dateori_pro  IS INITIAL.
        " Calcular fecha original si aplica
        lw_advance_plan-dateori_pro = calculate_next_exec_date(
                                      iv_werks = lw_cal_mrp-werks
                                      iv_puwnr = lw_cal_mrp-puwnr
                                      iv_source = 'L' ).
      ENDIF.

      APPEND lw_advance_plan TO li_advance_plan.
      CLEAR lw_advance_plan.

    ENDLOOP.

    LOOP AT li_except_mrp INTO lw_except_mrp.

      READ TABLE li_centro_data INTO lw_centro_data
                                WITH KEY puwnr = lw_except_mrp-puwnr
                                         plwrk = lw_except_mrp-werks
                                BINARY SEARCH.
      IF sy-subrc = 0.
        lw_advance_plan-name1 = lw_centro_data-name1.
      ENDIF.

      lw_advance_plan-tipo      = lw_except_mrp-tipo.
      lw_advance_plan-puwnr     = lw_except_mrp-puwnr.
      lw_advance_plan-plwrk     = lw_except_mrp-werks.
      lw_advance_plan-planum    = lw_except_mrp-planum.
      lw_advance_plan-dateori   = lw_except_mrp-dateori.
      lw_advance_plan-advance   = lw_except_mrp-advance.
      lw_advance_plan-noexec    = lw_except_mrp-noexec.
      lw_advance_plan-reason    = lw_except_mrp-reason.
      lw_advance_plan-dateadv   = lw_except_mrp-dateadv.
      lw_advance_plan-dateori_pro = lw_except_mrp-dateori_pro.
      lw_advance_plan-dateadv_pro = lw_except_mrp-dateadv_pro.
      lw_advance_plan-createby  = lw_except_mrp-createby.
      lw_advance_plan-createon  = lw_except_mrp-createon.
      lw_advance_plan-processed = lw_except_mrp-processed.

      " Calcular próxima fecha de ejecución si no tiene fecha original
      IF lw_advance_plan-dateori IS INITIAL.
        lw_advance_plan-dateori = calculate_next_exec_date(
                                    iv_werks  = lw_except_mrp-werks
                                    iv_puwnr  = lw_except_mrp-puwnr
                                    iv_source = 'M'
                                  ).
      ENDIF.

      APPEND lw_advance_plan TO li_advance_plan.
      CLEAR lw_advance_plan.

    ENDLOOP.

*    " Identificar registros con plan existente para eliminar duplicados vacíos
    DATA(li_advance_plan_c) = li_advance_plan[].
    DELETE li_advance_plan_c WHERE planum = '00000'. "No tiene plan asignado
    " Recolectar llaves que tienen plan asignado
    LOOP AT li_advance_plan_c INTO lw_advance_plan.
      INSERT lw_advance_plan INTO TABLE li_keys_with_plan.
    ENDLOOP.

    " Eliminar registros template (sin plan) si ya existe un plan para ese centro
    " Técnica optimizada: LOOP descendente con READ TABLE en tabla hash
    IF li_keys_with_plan IS NOT INITIAL.
      DATA(lv_lines) = lines( li_advance_plan ).
      DO lv_lines TIMES.
        DATA(lv_idx) = lv_lines - sy-index + 1.
        READ TABLE li_advance_plan INTO lw_advance_plan INDEX lv_idx.
        IF sy-subrc = 0 AND lw_advance_plan-planum IS INITIAL.
          READ TABLE li_keys_with_plan TRANSPORTING NO FIELDS
                                       WITH TABLE KEY puwnr = lw_advance_plan-puwnr
                                                      plwrk = lw_advance_plan-plwrk.
          "No requiere binary search se trata de tabla de tipo hashed.
          IF sy-subrc = 0.
            DELETE li_advance_plan INDEX lv_idx.
          ENDIF.
        ENDIF.
      ENDDO.
    ENDIF.

  ENDMETHOD.

  METHOD validate_authorizations.
    " Validar autorizaciones del usuario

    LOOP AT ci_advance_plan INTO DATA(lw_advance_plan).
      " Validacíón de autorización a centro
      AUTHORITY-CHECK OBJECT 'M_MATE_WRK'
                          ID 'WERKS' FIELD lw_advance_plan-plwrk
                          ID 'ACTVT' FIELD '03'.

      IF sy-subrc <> 0.
        DELETE ci_advance_plan INDEX sy-tabix.
        CONTINUE.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD set_advance_data.

    DATA:
      lw_celltab      TYPE lvc_s_styl.

    " Campos editables que se deben bloquear cuando PROCESSED = 'X'
    DATA:
      li_editable_fields TYPE TABLE OF lvc_fname,
      li_celltab         TYPE lvc_t_styl.

    DATA:
      lv_field TYPE lvc_fname.

    " Definir campos editables
    APPEND 'ADVANCE'  TO li_editable_fields.
    APPEND 'DATEADV'  TO li_editable_fields.
    APPEND 'NOEXEC'   TO li_editable_fields.
    APPEND 'REASON'   TO li_editable_fields.

    SORT li_centro_data BY puwnr plwrk.

    LOOP AT li_advance_plan ASSIGNING FIELD-SYMBOL(<lfs_advance_plan>).

      CLEAR: li_celltab.

      " Si el registro está procesado, bloquear campos editables
      IF <lfs_advance_plan>-processed = 'X'.
        SORT li_editable_fields.
        LOOP AT li_editable_fields INTO lv_field.
          CLEAR lw_celltab.
          lw_celltab-fieldname = lv_field.
          lw_celltab-style     = cl_gui_alv_grid=>mc_style_disabled.
          APPEND lw_celltab TO li_celltab.
        ENDLOOP.
        <lfs_advance_plan>-celltab = li_celltab.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.

  METHOD get_day.
    " Obtiene el día a partir de la fecha otorgada

    CALL FUNCTION 'DATE_COMPUTE_DAY'
      EXPORTING
        date = iv_date
      IMPORTING
        day  = rv_day.

  ENDMETHOD.

  METHOD calculate_next_exec_date.
    " Calcular la siguiente fecha de ejecución basada en el calendario
    " iv_source = 'M' → Calendario MRP (li_cal_mrp)
    " iv_source = 'L' → Calendario Logístico (li_cal_log)

    DATA:
      lv_date_chk TYPE dats,
      lv_day_week TYPE scal-indicator,
      lv_period   TYPE char1,
      lv_moday    TYPE char1,
      lv_tuday    TYPE char1,
      lv_weday    TYPE char1,
      lv_thday    TYPE char1,
      lv_frday    TYPE char1,
      lv_saday    TYPE char1,
      lv_suday    TYPE char1.

    "--- Obtener datos según la fuente ---
    CASE iv_source.
      WHEN 'M'.  "Calendario MRP
        READ TABLE li_cal_mrp INTO DATA(lw_cal_mrp)
                              WITH KEY werks = iv_werks
                                       puwnr = iv_puwnr
                              BINARY SEARCH.
        IF sy-subrc <> 0. RETURN. ENDIF.
        lv_period = lw_cal_mrp-period.
        lv_moday  = lw_cal_mrp-moday.
        lv_tuday  = lw_cal_mrp-tuday.
        lv_weday  = lw_cal_mrp-weday.
        lv_thday  = lw_cal_mrp-thday.
        lv_frday  = lw_cal_mrp-frday.
        lv_saday  = lw_cal_mrp-saday.
        lv_suday  = lw_cal_mrp-suday.

      WHEN 'L'.  "Calendario Logístico
        READ TABLE li_cal_log INTO DATA(lw_cal_log)
                              WITH KEY werks = iv_werks
                                       puwnr = iv_puwnr
                              BINARY SEARCH.
        IF sy-subrc <> 0. RETURN. ENDIF.
        lv_period = lw_cal_log-period.
        lv_moday  = lw_cal_log-moday.
        lv_tuday  = lw_cal_log-tuday.
        lv_weday  = lw_cal_log-weday.
        lv_thday  = lw_cal_log-thday.
        lv_frday  = lw_cal_log-frday.
        lv_saday  = lw_cal_log-saday.
        lv_suday  = lw_cal_log-suday.

      WHEN OTHERS.
        RETURN.
    ENDCASE.

    "--- Lógica común de cálculo ---
    " Si es semanal (S) o diario (D) determina la próxima fecha
    IF lv_period = 'S' OR lv_period = 'D'.

      " Usar fecha base proporcionada o sy-datum si no se especifica
      IF iv_start_date IS NOT INITIAL.
        lv_date_chk = iv_start_date.
      ELSE.
        lv_date_chk = sy-datum.
      ENDIF.

      DO 14 TIMES ##NUMBER_OK.
        lv_date_chk = lv_date_chk + 1.

        CALL FUNCTION 'DATE_COMPUTE_DAY'
          EXPORTING
            date = lv_date_chk
          IMPORTING
            day  = lv_day_week.

        CASE lv_day_week.
          WHEN 1. IF lv_moday = 'X'. rv_date = lv_date_chk. EXIT. ENDIF. " Lunes
          WHEN 2. IF lv_tuday = 'X'. rv_date = lv_date_chk. EXIT. ENDIF. " Martes
          WHEN 3. IF lv_weday = 'X'. rv_date = lv_date_chk. EXIT. ENDIF. " Miércoles
          WHEN 4. IF lv_thday = 'X'. rv_date = lv_date_chk. EXIT. ENDIF. " Jueves
          WHEN 5. IF lv_frday = 'X'. rv_date = lv_date_chk. EXIT. ENDIF. " Viernes
          WHEN 6. IF lv_saday = 'X'. rv_date = lv_date_chk. EXIT. ENDIF. " Sábado
          WHEN 7. IF lv_suday = 'X'. rv_date = lv_date_chk. EXIT. ENDIF. " Domingo
        ENDCASE.
      ENDDO.

    ENDIF.

  ENDMETHOD.
ENDCLASS.

*----------------------------------------------------------------------*
* Clase manejadora de eventos para ALV Grid
*----------------------------------------------------------------------*
CLASS cl_alv_advance_planner DEFINITION FINAL.
  PUBLIC SECTION.
    METHODS:

      constructor
        IMPORTING ir_data TYPE REF TO data,

      " Mostrar ALV
      display_alv,

      " Evento cuando cambian datos en el ALV
      handle_data_changed
                  FOR EVENT data_changed OF cl_gui_alv_grid
        IMPORTING er_data_changed e_onf4 e_onf4_before e_onf4_after e_ucomm ##NEEDED,

      " Evento cuando cambian datos finalizados
      handle_data_changed_finished
                  FOR EVENT data_changed_finished OF cl_gui_alv_grid
        IMPORTING e_modified et_good_cells ##NEEDED.

  PRIVATE SECTION.

    METHODS:

      " Construir catálogo
      build_fieldcat
        RETURNING VALUE(ri_fieldcat) TYPE lvc_t_fcat,

      " Construir layout
      build_layout
        RETURNING VALUE(rw_layout) TYPE lvc_s_layo.

ENDCLASS.

CLASS cl_alv_advance_planner IMPLEMENTATION.

  METHOD constructor.
    o_data = ir_data.
  ENDMETHOD.

  METHOD display_alv.
    " Implementación de ALV con funcionalidades específicas

    DATA:
      lw_layout TYPE lvc_s_layo.

    DATA:
      li_fieldcat TYPE lvc_t_fcat,
      li_exclude  TYPE ui_functions.

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

    " Excluir botones de edición de filas del toolbar
    APPEND cl_gui_alv_grid=>mc_fc_loc_append_row    TO li_exclude.
    APPEND cl_gui_alv_grid=>mc_fc_loc_insert_row    TO li_exclude.
    APPEND cl_gui_alv_grid=>mc_fc_loc_delete_row    TO li_exclude.
    APPEND cl_gui_alv_grid=>mc_fc_loc_copy_row      TO li_exclude.
    APPEND cl_gui_alv_grid=>mc_fc_loc_cut           TO li_exclude.
    APPEND cl_gui_alv_grid=>mc_fc_loc_paste         TO li_exclude.
    APPEND cl_gui_alv_grid=>mc_fc_loc_paste_new_row TO li_exclude.
    APPEND cl_gui_alv_grid=>mc_fc_loc_undo          TO li_exclude.
    APPEND cl_gui_alv_grid=>mc_fc_loc_copy          TO li_exclude.
    APPEND cl_gui_alv_grid=>mc_fc_loc_move_row      TO li_exclude.
    APPEND cl_gui_alv_grid=>mc_fc_refresh           TO li_exclude.
    APPEND cl_gui_alv_grid=>mc_fc_check             TO li_exclude.

    TRY.
        CALL METHOD o_alv_grid->set_table_for_first_display
          EXPORTING
            is_layout            = lw_layout
            it_toolbar_excluding = li_exclude
          CHANGING
            it_outtab            = <lfs_data>
            it_fieldcatalog      = li_fieldcat.

        " Habilitar edición en el ALV
        CALL METHOD o_alv_grid->set_ready_for_input
          EXPORTING
            i_ready_for_input = 1.

        " Registrar eventos para capturar cambios
        SET HANDLER me->handle_data_changed FOR o_alv_grid.
        SET HANDLER me->handle_data_changed_finished FOR o_alv_grid.

        " Registrar el evento ENTER para aplicar cambios inmediatos
        CALL METHOD o_alv_grid->register_edit_event
          EXPORTING
            i_event_id = cl_gui_alv_grid=>mc_evt_enter.

        " Registrar el evento de cambio de celda
        CALL METHOD o_alv_grid->register_edit_event
          EXPORTING
            i_event_id = cl_gui_alv_grid=>mc_evt_modified.

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

    CLEAR: lw_fieldcat, ri_fieldcat[].

    " Campo: Metro
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'PUWNR'.
    lw_fieldcat-coltext   = 'Clasificación' ##NO_TEXT.
    lw_fieldcat-outputlen = 10.
    lw_fieldcat-key       = abap_true.
    APPEND lw_fieldcat TO ri_fieldcat.

    " Campo: Centro
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'PLWRK'.
    lw_fieldcat-coltext   = 'Centro' ##NO_TEXT.
    lw_fieldcat-outputlen = 6 ##NUMBER_OK.
    lw_fieldcat-key       = abap_true.
    APPEND lw_fieldcat TO ri_fieldcat.

    " Campo: Nombre Centro
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'NAME1'.
    lw_fieldcat-coltext   = 'Nombre Centro' ##NO_TEXT.
    lw_fieldcat-outputlen = 30 ##NUMBER_OK.
    lw_fieldcat-key       = abap_true.
    APPEND lw_fieldcat TO ri_fieldcat.

    " Campo: Tipo
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'TIPO'.
    lw_fieldcat-coltext   = 'Tipo'          ##NO_TEXT.
    lw_fieldcat-outputlen = 4 ##NUMBER_OK.
    lw_fieldcat-key       = abap_true.
    APPEND lw_fieldcat TO ri_fieldcat.

    " Campo: Número de Plan
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'PLANUM'.
    lw_fieldcat-coltext   = 'No. Plan' ##NO_TEXT.
    lw_fieldcat-outputlen = 8 ##NUMBER_OK.
    APPEND lw_fieldcat TO ri_fieldcat.

    " Campo: Adelantar (editable)
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'ADVANCE'.
    lw_fieldcat-coltext   = 'Adelantar' ##NO_TEXT.
    lw_fieldcat-outputlen = 10 ##NUMBER_OK.
    lw_fieldcat-checkbox  = abap_true.
    lw_fieldcat-edit      = abap_true.
    APPEND lw_fieldcat TO ri_fieldcat.

    " Campo: No Ejecutar (editable)
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'NOEXEC_PRO'.
    lw_fieldcat-coltext   = 'No Ejecutar Proceso' ##NO_TEXT.
    lw_fieldcat-outputlen = 12 ##NUMBER_OK.
    lw_fieldcat-checkbox  = abap_true.
    lw_fieldcat-edit      = abap_true.
    APPEND lw_fieldcat TO ri_fieldcat.

    " Campo: Fecha Original
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'DATEORI_PRO'.
    lw_fieldcat-coltext   = 'Fecha Original Proceso' ##NO_TEXT.
    lw_fieldcat-outputlen = 12 ##NUMBER_OK.
    APPEND lw_fieldcat TO ri_fieldcat.

    " Campo: Fecha Original
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'DATEADV_PRO'.
    lw_fieldcat-coltext   = 'Fecha Adelanto Proceso' ##NO_TEXT.
    lw_fieldcat-edit      = abap_true.
    lw_fieldcat-outputlen = 12 ##NUMBER_OK.
    APPEND lw_fieldcat TO ri_fieldcat.

    " Campo: No Ejecutar (editable)
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'NOEXEC'.
    lw_fieldcat-coltext   = 'No Ejecutar' ##NO_TEXT.
    lw_fieldcat-outputlen = 12 ##NUMBER_OK.
    lw_fieldcat-checkbox  = abap_true.
    lw_fieldcat-edit      = abap_true.
    APPEND lw_fieldcat TO ri_fieldcat.

    " Campo: Fecha Original
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'DATEORI'.
    lw_fieldcat-coltext   = 'Fecha Original MRP' ##NO_TEXT.
    lw_fieldcat-outputlen = 12 ##NUMBER_OK.
    APPEND lw_fieldcat TO ri_fieldcat.

    " Campo: Fecha Adelanto (editable)
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'DATEADV'.
    lw_fieldcat-coltext   = 'Fecha Adelanto MRP' ##NO_TEXT.
    lw_fieldcat-outputlen = 14 ##NUMBER_OK.
    lw_fieldcat-edit      = abap_true.
    APPEND lw_fieldcat TO ri_fieldcat.

    " Campo: Razón (editable)
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'REASON'.
    lw_fieldcat-coltext   = 'Motivo' ##NO_TEXT.
    lw_fieldcat-outputlen = 20 ##NUMBER_OK.
    lw_fieldcat-edit      = abap_true.
    APPEND lw_fieldcat TO ri_fieldcat.

    " Campo: Creado Por
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'CREATEBY'.
    lw_fieldcat-coltext   = 'Creado Por' ##NO_TEXT.
    lw_fieldcat-outputlen = 12 ##NUMBER_OK.
    APPEND lw_fieldcat TO ri_fieldcat.

    " Campo: Fecha de Creación
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'CREATEON'.
    lw_fieldcat-coltext   = 'Fecha Creación' ##NO_TEXT.
    lw_fieldcat-outputlen = 12 ##NUMBER_OK.
    APPEND lw_fieldcat TO ri_fieldcat.

    " Campo: Procesado
    CLEAR lw_fieldcat.
    lw_fieldcat-fieldname = 'PROCESSED'.
    lw_fieldcat-coltext   = 'Procesado' ##NO_TEXT.
    lw_fieldcat-outputlen = 10 ##NUMBER_OK.
    lw_fieldcat-checkbox  = abap_true.
    APPEND lw_fieldcat TO ri_fieldcat.

  ENDMETHOD.

  METHOD build_layout.
    " Configurar layout del ALV

    rw_layout-zebra      = c_x.        " Líneas alternadas
    rw_layout-sel_mode   = c_a.        " Selección múltiple
    rw_layout-stylefname = 'CELLTAB'.  " Campo con estilos de celda

  ENDMETHOD.

  METHOD handle_data_changed.
    " Procesar cambios en los datos del ALV

    DATA:
      lw_mod_cell  TYPE lvc_s_modi.

    DATA:
      lv_advance    TYPE char1,
      lv_noexec     TYPE char1,
      lv_noexec_pro TYPE char1,
      lv_dateori    TYPE dats,
      lv_dateadv    TYPE dats,
      lv_reason     TYPE char20,
      lv_processed  TYPE char1,
      lv_puwnr      TYPE t439c-puwnr,
      lv_plwrk      TYPE t439c-plwrk,
      lv_tipo       TYPE ztamm_except_mrp-tipo,
      lv_day        TYPE p,
      lv_error      TYPE flag,
      lv_row_id     TYPE i.

    DATA:
      lv_dateori_pro TYPE datum,
      lv_dateadv_pro TYPE datum.

    " Recorrer todas las celdas modificadas
    LOOP AT er_data_changed->mt_mod_cells INTO lw_mod_cell.

      CLEAR lv_error.

      lv_row_id = lw_mod_cell-row_id.

      " Verificar si el registro ya está procesado
      CALL METHOD er_data_changed->get_cell_value
        EXPORTING
          i_row_id    = lv_row_id
          i_fieldname = 'PROCESSED'
        IMPORTING
          e_value     = lv_processed.

      " Si está procesado, no permitir edición
      IF lv_processed = c_x.
        CALL METHOD er_data_changed->add_protocol_entry
          EXPORTING
            i_msgid     = 'FB'
            i_msgno     = '000'
            i_msgty     = 'E'
            i_msgv1     = TEXT-e01 "Registro ya procesado.
            i_msgv2     = TEXT-e02 "No se puede modificar.
            i_fieldname = lw_mod_cell-fieldname
            i_row_id    = lv_row_id.

        " Revertir el cambio (mantener valor original)
        CALL METHOD er_data_changed->modify_cell
          EXPORTING
            i_row_id    = lv_row_id
            i_fieldname = lw_mod_cell-fieldname
            i_value     = lw_mod_cell-value.
        CONTINUE.
      ENDIF.

      " Obtiene planta
      CALL METHOD er_data_changed->get_cell_value
        EXPORTING
          i_row_id    = lv_row_id
          i_fieldname = 'PUWNR'
        IMPORTING
          e_value     = lv_puwnr.

      " Obtiene centro
      CALL METHOD er_data_changed->get_cell_value
        EXPORTING
          i_row_id    = lv_row_id
          i_fieldname = 'PLWRK'
        IMPORTING
          e_value     = lv_plwrk.

      " Obtiene tipo
      CALL METHOD er_data_changed->get_cell_value
        EXPORTING
          i_row_id    = lv_row_id
          i_fieldname = 'TIPO'
        IMPORTING
          e_value     = lv_tipo.

      " Obtiene fecha original
      CALL METHOD er_data_changed->get_cell_value
        EXPORTING
          i_row_id    = lv_row_id
          i_fieldname = 'DATEORI'
        IMPORTING
          e_value     = lv_dateori.

      " Validaciones específicas por campo
      CASE lw_mod_cell-fieldname.

        WHEN 'DATEADV'.
          " Validar que la fecha de adelanto sea válida
          " Convertir fecha de formato de salida (DD.MM.YYYY) a interno (YYYYMMDD)
          CALL FUNCTION 'CONVERT_DATE_TO_INTERNAL'
            EXPORTING
              date_external            = lw_mod_cell-value
              accept_initial_date      = 'X'
            IMPORTING
              date_internal            = lv_dateadv
            EXCEPTIONS
              date_external_is_invalid = 1
              OTHERS                   = 2.
          IF sy-subrc <> 0.
            " Fecha con formato inválido
            CALL METHOD er_data_changed->add_protocol_entry
              EXPORTING
                i_msgid     = 'FB'
                i_msgno     = '000'
                i_msgty     = 'E'
                i_msgv1     = TEXT-e07 "Formato de fecha inválido
                i_msgv2     = space
                i_fieldname = 'DATEADV'
                i_row_id    = lv_row_id.
            CONTINUE.
          ENDIF.

          " La fecha no puede estar vacía si hay adelanto
          IF lv_dateadv IS NOT INITIAL.

            " Validar que la fecha de adelanto no sea mayor o igual a la fecha original
            IF lv_dateadv >= lv_dateori.
              CALL METHOD er_data_changed->add_protocol_entry
                EXPORTING
                  i_msgid     = 'FB'
                  i_msgno     = '000'
                  i_msgty     = 'E'
                  i_msgv1     = TEXT-e08 "Fecha de adelanto no puede
                  i_msgv2     = TEXT-e09 "ser mayor o igual a fecha original
                  i_fieldname = 'DATEADV'
                  i_row_id    = lv_row_id.
            ENDIF.

            IF lv_dateadv < sy-datum.
              CALL METHOD er_data_changed->add_protocol_entry
                EXPORTING
                  i_msgid     = 'FB'
                  i_msgno     = '000'
                  i_msgty     = 'E'
                  i_msgv1     = TEXT-e08 "Fecha de adelanto no puede
                  i_msgv2     = TEXT-e14 "estar en el pasado
                  i_fieldname = 'DATEADV'
                  i_row_id    = lv_row_id.
            ENDIF.

            " Valida que la fecha de avance no sea en día feriado (Sabado o Domingo)
            CALL FUNCTION 'DAY_IN_WEEK'
              EXPORTING
                datum = lv_dateadv
              IMPORTING
                wotnr = lv_day.

            IF lv_day = '6'    ##LITERAL    "Sábado
              OR lv_day = '7'  ##LITERAL.   "Domingo
              CALL METHOD er_data_changed->add_protocol_entry
                EXPORTING
                  i_msgid     = 'FB'
                  i_msgno     = '000'
                  i_msgty     = 'E'
                  i_msgv1     = TEXT-e08 "Fecha de adelanto no puede
                  i_msgv2     = TEXT-e12 "ser en día feriado
                  i_fieldname = 'DATEADV'
                  i_row_id    = lv_row_id.
            ENDIF.

            " Validar que la fecha no esté duplicada ni sea menor o igual a una ya registrada para el mismo grupo
            LOOP AT i_advance_plan ASSIGNING FIELD-SYMBOL(<lfs_check>).
              IF sy-tabix = lv_row_id.
                CONTINUE.
              ENDIF.
              IF <lfs_check>-puwnr = lv_puwnr AND <lfs_check>-plwrk = lv_plwrk AND <lfs_check>-tipo = lv_tipo.
                IF <lfs_check>-dateadv IS NOT INITIAL.
                  IF lv_dateadv = <lfs_check>-dateadv.
                    CALL METHOD er_data_changed->add_protocol_entry
                      EXPORTING
                        i_msgid     = 'FB'
                        i_msgno     = '000'
                        i_msgty     = 'E'
                        i_msgv1     = TEXT-e16 "Fecha ya registrada para esta
                        i_msgv2     = TEXT-e17 "clasificación, centro y tipo
                        i_fieldname = 'DATEADV'
                        i_row_id    = lv_row_id.
*                  ELSEIF lv_dateadv < <lfs_check>-dateadv.
*                    CALL METHOD er_data_changed->add_protocol_entry
*                      EXPORTING
*                        i_msgid     = 'FB'
*                        i_msgno     = '000'
*                        i_msgty     = 'E'
*                        i_msgv1     = TEXT-e18 "Fecha debe ser mayor a las
*                        i_msgv2     = TEXT-e19 "ya registradas para este plan
*                        i_fieldname = 'DATEADV'
*                        i_row_id    = lv_row_id.
                  ENDIF.
                ENDIF.
              ENDIF.
            ENDLOOP.

*            " Obtener valor de ADVANCE para validar coherencia
*            CALL METHOD er_data_changed->get_cell_value
*              EXPORTING
*                i_row_id    = lv_row_id
*                i_fieldname = 'ADVANCE'
*              IMPORTING
*                e_value     = lv_advance.
*
*            " Si pone fecha pero no marcó adelantar, marcar automáticamente
*            IF lv_advance <> c_x.
*              CALL METHOD er_data_changed->modify_cell
*                EXPORTING
*                  i_row_id    = lv_row_id
*                  i_fieldname = 'ADVANCE'
*                  i_value     = 'X'.
*            ENDIF.

          ENDIF.

        WHEN 'REASON'.
          " Validar que la razón no esté vacía si hay adelanto o no ejecución
          lv_reason = lw_mod_cell-value.

          " Obtener valores de ADVANCE y NOEXEC
          CALL METHOD er_data_changed->get_cell_value
            EXPORTING
              i_row_id    = lv_row_id
              i_fieldname = 'ADVANCE'
            IMPORTING
              e_value     = lv_advance.

          CALL METHOD er_data_changed->get_cell_value
            EXPORTING
              i_row_id    = lv_row_id
              i_fieldname = 'NOEXEC'
            IMPORTING
              e_value     = lv_noexec.

          CALL METHOD er_data_changed->get_cell_value
            EXPORTING
              i_row_id    = lv_row_id
              i_fieldname = 'DATEADV_PRO'
            IMPORTING
              e_value     = lv_dateadv_pro.

          CALL METHOD er_data_changed->get_cell_value
            EXPORTING
              i_row_id    = lv_row_id
              i_fieldname = 'NOEXEC_PRO'
            IMPORTING
              e_value     = lv_noexec_pro.

          " Si hay adelanto o no ejecución, la razón es obligatoria
          IF ( lv_advance = c_x OR lv_noexec = c_x OR lv_noexec_pro = c_x ) AND lv_reason IS INITIAL.
            CALL METHOD er_data_changed->add_protocol_entry
              EXPORTING
                i_msgid     = 'FB'
                i_msgno     = '000'
                i_msgty     = 'E'
                i_msgv1     = TEXT-e10 "Favor de indicar una
                i_msgv2     = TEXT-e11 "razón para el cambio'
                i_fieldname = 'REASON'
                i_row_id    = lv_row_id.
          ENDIF.

        WHEN 'DATEADV_PRO'.
          " La fecha no puede estar vacía si hay adelanto de proceso
          IF lw_mod_cell-value IS NOT INITIAL.

            CALL FUNCTION 'CONVERT_DATE_TO_INTERNAL'
              EXPORTING
                date_external            = lw_mod_cell-value
                accept_initial_date      = 'X'
              IMPORTING
                date_internal            = lv_dateadv_pro
              EXCEPTIONS
                date_external_is_invalid = 1
                OTHERS                   = 2.

            IF sy-subrc <> 0.
              CONTINUE. " Error en formato será gestionado si ALV nativo falla
            ENDIF.

            CALL METHOD er_data_changed->get_cell_value
              EXPORTING
                i_row_id    = lv_row_id
                i_fieldname = 'DATEORI_PRO'
              IMPORTING
                e_value     = lv_dateori_pro.

            " Validar que la fecha de adelanto de proceso no sea mayor o igual a la original del proceso
            IF lv_dateadv_pro >= lv_dateori_pro.
              CALL METHOD er_data_changed->add_protocol_entry
                EXPORTING
                  i_msgid     = 'FB'
                  i_msgno     = '000'
                  i_msgty     = 'E'
                  i_msgv1     = TEXT-e08 "Fecha de adelanto no puede
                  i_msgv2     = TEXT-e09 "ser mayor o igual a fecha original
                  i_fieldname = 'DATEADV_PRO'
                  i_row_id    = lv_row_id.
            ENDIF.

            " Validar que la fecha de proceso no sea en el pasado
            IF lv_dateadv_pro < sy-datum.
              CALL METHOD er_data_changed->add_protocol_entry
                EXPORTING
                  i_msgid     = 'FB'
                  i_msgno     = '000'
                  i_msgty     = 'E'
                  i_msgv1     = TEXT-e08 "Fecha de adelanto no puede
                  i_msgv2     = TEXT-e14 "estar en el pasado
                  i_fieldname = 'DATEADV_PRO'
                  i_row_id    = lv_row_id.
            ENDIF.

            " Valida fin de semana
            CALL FUNCTION 'DAY_IN_WEEK'
              EXPORTING
                datum = lv_dateadv_pro
              IMPORTING
                wotnr = lv_day.

            IF lv_day = '6'   ##LITERAL   "Sábado
              OR lv_day = '7' ##LITERAL.  "Domingo
              CALL METHOD er_data_changed->add_protocol_entry
                EXPORTING
                  i_msgid     = 'FB'
                  i_msgno     = '000'
                  i_msgty     = 'E'
                  i_msgv1     = TEXT-e08 "Fecha de adelanto no puede
                  i_msgv2     = TEXT-e12 "ser en día feriado
                  i_fieldname = 'DATEADV_PRO'
                  i_row_id    = lv_row_id.
            ENDIF.

            " Validar que la fecha de proceso no esté duplicada ni sea menor o igual a una ya registrada
            LOOP AT i_advance_plan ASSIGNING FIELD-SYMBOL(<lfs_check_pro>).
              IF sy-tabix = lv_row_id.
                CONTINUE.
              ENDIF.
              IF <lfs_check_pro>-puwnr = lv_puwnr AND <lfs_check_pro>-plwrk = lv_plwrk AND <lfs_check_pro>-tipo = lv_tipo.
                IF <lfs_check_pro>-dateadv_pro IS NOT INITIAL.
                  IF lv_dateadv_pro = <lfs_check_pro>-dateadv_pro.
                    CALL METHOD er_data_changed->add_protocol_entry
                      EXPORTING
                        i_msgid     = 'FB'
                        i_msgno     = '000'
                        i_msgty     = 'E'
                        i_msgv1     = TEXT-e16 "Fecha ya registrada para esta
                        i_msgv2     = TEXT-e17 "clasificación, centro y tipo
                        i_fieldname = 'DATEADV_PRO'
                        i_row_id    = lv_row_id.
                  ELSEIF lv_dateadv_pro < <lfs_check_pro>-dateadv_pro.
                    CALL METHOD er_data_changed->add_protocol_entry
                      EXPORTING
                        i_msgid     = 'FB'
                        i_msgno     = '000'
                        i_msgty     = 'E'
                        i_msgv1     = TEXT-e18 "Fecha debe ser mayor a las
                        i_msgv2     = TEXT-e19 "ya registradas para este plan
                        i_fieldname = 'DATEADV_PRO'
                        i_row_id    = lv_row_id.
                  ENDIF.
                ENDIF.
              ENDIF.
            ENDLOOP.
          ENDIF.

      ENDCASE.

      IF lv_error IS INITIAL.
        " Marcar registro como modificado en la tabla global
        READ TABLE i_advance_plan ASSIGNING FIELD-SYMBOL(<lfs_plan>) INDEX lv_row_id.
        IF sy-subrc = 0.
          <lfs_plan>-changed = c_x.
        ENDIF.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD handle_data_changed_finished.
    " Este método se ejecuta cuando el usuario termina de editar
    " Aquí se pueden realizar acciones finales como refrescar el grid

    IF e_modified = abap_true.
      " Los datos fueron modificados
      MESSAGE s908(fb) WITH TEXT-m01. "Datos modificados. Recuerde guardar los cambios.
    ENDIF.

  ENDMETHOD.

ENDCLASS.

*-------------------------------------------------------------------------------*
* FORM f_main_process                                                           *
*-------------------------------------------------------------------------------*
FORM f_main_process
     CHANGING c_v_okparam TYPE abap_bool.
  " Proceso principal del programa

  " Bloquear tabla para uso exclusivo
  PERFORM f_enqueue_table CHANGING c_v_okparam.
  IF c_v_okparam = abap_true.
    RETURN.
  ENDIF.

  " Crear instancia de la clase principal
  CREATE OBJECT o_advance_planner.

  " Obtener pedidos con entregas parciales
  i_advance_plan = o_advance_planner->get_advance_planner(
                   IMPORTING
                     ev_okparam = c_v_okparam
                 ).

ENDFORM.

*-------------------------------------------------------------------------------*
* FORM f_display_alv                                                            *
*-------------------------------------------------------------------------------*
FORM f_display_alv.
  " Mostrar datos en formato ALV

  DATA:
    lo_alv_advance_planner TYPE REF TO cl_alv_advance_planner,
    lo_data                TYPE REF TO data.

  " Crear referencia a los datos
  GET REFERENCE OF i_advance_plan INTO lo_data.

  " Crear instancia de ALV
  CREATE OBJECT lo_alv_advance_planner
    EXPORTING
      ir_data = lo_data.

  " Configurar fieldcat
  lo_alv_advance_planner->display_alv(  ).

ENDFORM.

*-------------------------------------------------------------------------------*
* FORM f_save_data - Guardar cambios en tabla ztamm_except_mrp                  *
*-------------------------------------------------------------------------------*
FORM f_save_data.

  " Estructura para control de consecutivos
  TYPES:
    BEGIN OF lty_max_plan,
      puwnr  TYPE t439c-puwnr,
      plwrk  TYPE t439c-plwrk,
      tipo   TYPE ztamm_except_mrp-tipo,
      planum TYPE ztamm_except_mrp-planum,
    END OF lty_max_plan,

    BEGIN OF lty_db_record,
      puwnr  TYPE ztamm_except_mrp-puwnr,
      werks  TYPE ztamm_except_mrp-werks,
      tipo   TYPE ztamm_except_mrp-tipo,
      planum TYPE ztamm_except_mrp-planum,
    END OF lty_db_record.

  DATA:
    lw_except_mrp TYPE ztamm_except_mrp,
    lw_max_plan   TYPE lty_max_plan,
    lw_db_record  TYPE lty_db_record.

  DATA:
    li_except_mrp TYPE TABLE OF ztamm_except_mrp,
    li_max_plan   TYPE HASHED TABLE OF lty_max_plan WITH UNIQUE KEY puwnr plwrk tipo,
    li_db_records TYPE TABLE OF lty_db_record,
    li_keys       TYPE TABLE OF lty_max_plan.

  DATA:
    lv_lines                     TYPE i,
    lv_error_empty               TYPE abap_bool,
    lv_error_reason              TYPE abap_bool,
    lv_error_day                 TYPE abap_bool,
    lv_error_day_past            TYPE abap_bool,
    lv_error_dateadv_dup         TYPE abap_bool,
    lv_error_dateadv_order       TYPE abap_bool,
    lv_error_dateadv_dateori     TYPE abap_bool,
    lv_error_day_past_pro        TYPE abap_bool,
    lv_error_dateadv_pro_dup     TYPE abap_bool,
    lv_error_dateadv_pro_order   TYPE abap_bool,
    lv_error_dateadv_dateori_pro TYPE abap_bool,
    lv_curr_tabix                TYPE sytabix,
    lv_day                       TYPE p.

  " Verificar que hay datos para guardar
  IF i_advance_plan[] IS INITIAL.
    MESSAGE s908(fb) WITH TEXT-m02. "No hay datos para guardar
    RETURN.
  ENDIF.

  " Recolectar todas las combinaciones puwnr/plwrk/tipo que necesitan consecutivo
  LOOP AT i_advance_plan ASSIGNING FIELD-SYMBOL(<lfs_pre>).
    IF <lfs_pre>-changed = c_x AND <lfs_pre>-planum IS INITIAL.
      APPEND VALUE #( puwnr = <lfs_pre>-puwnr
                      plwrk = <lfs_pre>-plwrk
                      tipo  = <lfs_pre>-tipo ) TO li_keys.
    ENDIF.
  ENDLOOP.

  " Eliminar duplicados
  SORT li_keys BY puwnr plwrk tipo.
  DELETE ADJACENT DUPLICATES FROM li_keys COMPARING puwnr plwrk tipo.
  IF li_keys IS NOT INITIAL.
    " Consultar Adelanto de Pedidos y calcular máximos de plan
    SELECT puwnr werks tipo planum
      FROM ztamm_except_mrp
      INTO TABLE li_db_records
      FOR ALL ENTRIES IN li_keys
      WHERE puwnr = li_keys-puwnr
        AND werks = li_keys-plwrk
        AND tipo  = li_keys-tipo.
    IF sy-subrc = 0.
      " Ordenar para agrupar por puwnr/werks/tipo/planum y obtener máximo
      SORT li_db_records BY puwnr werks tipo planum DESCENDING.
      " Calcular máximo por grupo
      LOOP AT li_db_records INTO lw_db_record.
        READ TABLE li_max_plan TRANSPORTING NO FIELDS
                               WITH TABLE KEY puwnr = lw_db_record-puwnr
                                              plwrk = lw_db_record-werks
                                              tipo  = lw_db_record-tipo.
        " No requiere binary search se trata de tabla de tipo hashed.
        IF sy-subrc <> 0.
          " Primer registro de este grupo = máximo (por orden descendente)
          lw_max_plan-puwnr  = lw_db_record-puwnr.
          lw_max_plan-plwrk  = lw_db_record-werks.
          lw_max_plan-tipo   = lw_db_record-tipo.
          lw_max_plan-planum = lw_db_record-planum.
          INSERT lw_max_plan INTO TABLE li_max_plan.
        ENDIF.
      ENDLOOP.
    ENDIF.
  ENDIF.

  " Validar y procesar solo registros modificados
  LOOP AT i_advance_plan ASSIGNING FIELD-SYMBOL(<lfs_except>).
    lv_curr_tabix = sy-tabix.

    " Saltar registros no modificados
    IF <lfs_except>-changed <> c_x.
      CONTINUE.
    ENDIF.

    " Valicación: Debe de estar marcado adelantar plan o no ejecutar ( No vacío )
    IF <lfs_except>-advance IS INITIAL AND
       <lfs_except>-noexec IS INITIAL AND
       <lfs_except>-noexec_pro IS INITIAL AND
       <lfs_except>-dateadv IS INITIAL AND
       <lfs_except>-dateadv_pro IS INITIAL.
      lv_error_empty = abap_true.
    ENDIF.

    " Valicación: Debe de estar marcado adelantar plan o no ejecutar ( No vacío )
    IF <lfs_except>-advance IS INITIAL AND
       <lfs_except>-noexec IS INITIAL AND
       <lfs_except>-noexec_pro IS INITIAL.
      lv_error_empty = abap_true.
    ENDIF.

    " Validación: Si tiene ADVANCE, NOEXEC, NOEXEC_PRO o DATEADV_PRO especificado, debe tener REASON
    IF ( <lfs_except>-advance = c_x OR
         <lfs_except>-noexec = c_x OR
         <lfs_except>-noexec_pro = c_x )
       AND <lfs_except>-reason IS INITIAL.
      lv_error_reason = abap_true.
    ENDIF.

    " Generación de consecutivo para PLANUM si está vacío
    IF <lfs_except>-planum IS INITIAL.
      " Verificar si ya tenemos el máximo para este grupo (desde tabla pre-cargada)
      READ TABLE li_max_plan INTO lw_max_plan
                             WITH TABLE KEY puwnr = <lfs_except>-puwnr
                                            plwrk = <lfs_except>-plwrk
                                            tipo  = <lfs_except>-tipo.
      IF sy-subrc <> 0.
        " No existe en BD, iniciar con valor vacío
        CLEAR lw_max_plan.
        lw_max_plan-puwnr = <lfs_except>-puwnr.
        lw_max_plan-plwrk = <lfs_except>-plwrk.
        lw_max_plan-tipo  = <lfs_except>-tipo.
        INSERT lw_max_plan INTO TABLE li_max_plan.
      ENDIF.

      " Incrementar consecutivo
      lw_max_plan-planum = lw_max_plan-planum + 1.

      " Asegurar formato correcto (ALPHA)
      lw_max_plan-planum = |{ lw_max_plan-planum ALPHA = IN }|.

      " Actualizar tabla hash y registro actual
      MODIFY TABLE li_max_plan FROM lw_max_plan.
      <lfs_except>-planum = lw_max_plan-planum.
    ENDIF.

    lw_except_mrp-puwnr       = <lfs_except>-puwnr.
    lw_except_mrp-werks       = <lfs_except>-plwrk.
    lw_except_mrp-tipo        = <lfs_except>-tipo.
    lw_except_mrp-planum      = <lfs_except>-planum.
    lw_except_mrp-dateori     = <lfs_except>-dateori.
    lw_except_mrp-advance     = <lfs_except>-advance.
    lw_except_mrp-dateori_pro = <lfs_except>-dateori_pro.
    lw_except_mrp-dateadv_pro = <lfs_except>-dateadv_pro.
    lw_except_mrp-noexec      = <lfs_except>-noexec.
    lw_except_mrp-reason      = <lfs_except>-reason.
    lw_except_mrp-dateadv     = <lfs_except>-dateadv.

    " Valida que la fecha de avance no sea en día feriado (Sabado o Domingo)
    IF lw_except_mrp-dateadv IS NOT INITIAL.
      CALL FUNCTION 'DAY_IN_WEEK'
        EXPORTING
          datum = lw_except_mrp-dateadv
        IMPORTING
          wotnr = lv_day.

      IF lv_day = '6'   ##LITERAL   "Sábado
        OR lv_day = '7' ##LITERAL.  "Domingo
        lv_error_day = abap_true.
      ENDIF.

      IF lw_except_mrp-dateadv < sy-datum.
        lv_error_day_past = abap_true.
      ENDIF.

      IF lw_except_mrp-dateadv >= lw_except_mrp-dateori.
        lv_error_dateadv_dateori = abap_true.
      ENDIF.

      " Validar que no exista registro duplicado o menor a otro de la misma agupación
      LOOP AT i_advance_plan ASSIGNING FIELD-SYMBOL(<lfs_check_db>).
        IF sy-tabix = lv_curr_tabix.
          CONTINUE.
        ENDIF.
        IF <lfs_check_db>-puwnr = lw_except_mrp-puwnr AND <lfs_check_db>-plwrk = lw_except_mrp-werks AND <lfs_check_db>-tipo = lw_except_mrp-tipo.
          IF <lfs_check_db>-dateadv IS NOT INITIAL.
            IF lw_except_mrp-dateadv = <lfs_check_db>-dateadv.
              lv_error_dateadv_dup = abap_true.
            ELSEIF ( lw_except_mrp-planum > <lfs_check_db>-planum ) AND ( lw_except_mrp-dateadv < <lfs_check_db>-dateadv ).
              lv_error_dateadv_order = abap_true.
            ENDIF.
          ENDIF.
        ENDIF.
      ENDLOOP.
    ENDIF.

    IF lw_except_mrp-dateadv_pro IS NOT INITIAL.
      CALL FUNCTION 'DAY_IN_WEEK'
        EXPORTING
          datum = lw_except_mrp-dateadv_pro
        IMPORTING
          wotnr = lv_day.

      IF lv_day = '6'    ##LITERAL    "Sábado
        OR lv_day = '7'  ##LITERAL.   "Domingo
        lv_error_day = abap_true.
      ENDIF.

      IF lw_except_mrp-dateadv_pro < sy-datum.
        lv_error_day_past_pro = abap_true.
      ENDIF.

      IF lw_except_mrp-dateadv_pro >= lw_except_mrp-dateori_pro.
        lv_error_dateadv_dateori_pro = abap_true.
      ENDIF.

      " Validar que no exista registro duplicado o menor a otro de la misma agupación
      LOOP AT i_advance_plan ASSIGNING FIELD-SYMBOL(<lfs_check_db_pro>).
        IF sy-tabix = lv_curr_tabix.
          CONTINUE.
        ENDIF.
        IF <lfs_check_db_pro>-puwnr = lw_except_mrp-puwnr AND <lfs_check_db_pro>-plwrk = lw_except_mrp-werks AND <lfs_check_db_pro>-tipo = lw_except_mrp-tipo.
          IF <lfs_check_db_pro>-dateadv_pro IS NOT INITIAL.
            IF lw_except_mrp-dateadv_pro = <lfs_check_db_pro>-dateadv_pro.
              lv_error_dateadv_pro_dup = abap_true.
            ELSEIF lw_except_mrp-dateadv_pro < <lfs_check_db_pro>-dateadv_pro.
              lv_error_dateadv_pro_order = abap_true.
            ENDIF.
          ENDIF.
        ENDIF.
      ENDLOOP.
    ENDIF.

    IF <lfs_except>-createby IS NOT INITIAL.
      lw_except_mrp-createby  = <lfs_except>-createby.
    ELSE.
      lw_except_mrp-createby  = sy-uname.
      <lfs_except>-createby   = sy-uname.
    ENDIF.

    IF <lfs_except>-createon IS NOT INITIAL.
      lw_except_mrp-createon  = <lfs_except>-createon.
    ELSE.
      lw_except_mrp-createon  = sy-datum.
      <lfs_except>-createon   = sy-datum.
    ENDIF.

    lw_except_mrp-processed = <lfs_except>-processed.
    APPEND lw_except_mrp TO li_except_mrp.
    CLEAR lw_except_mrp.

  ENDLOOP.

  " Si no hubo cambios
  IF li_except_mrp IS INITIAL.
    MESSAGE s908(fb) WITH TEXT-m02. "No hay datos para guardar
    RETURN.
  ENDIF.

  " Asigne información para el plan de adelanto
  IF lv_error_empty = abap_true.
    MESSAGE s908(fb) WITH TEXT-e15
      DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  " Fecha ya registrada para esta clasificación, centro y tipo
  IF lv_error_dateadv_dup = abap_true.
    MESSAGE s911(fb) WITH TEXT-e16 TEXT-e17
      DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  " Fecha debe ser mayor a las ya registradas para este plan
  IF lv_error_dateadv_order = abap_true.
    MESSAGE s911(fb) WITH TEXT-e18 TEXT-e19
      DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  " Favor de indicar una razón para el cambio
  IF lv_error_reason = abap_true.
    MESSAGE s911(fb) WITH TEXT-e10 TEXT-e11
      DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  " Fecha de adelanto no ser en día feriado
  IF lv_error_day = abap_true.
    MESSAGE s911(fb) WITH TEXT-e08 TEXT-e12
      DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  " Fecha de adelanto no puede estar en el pasado
  IF lv_error_day_past = abap_true.
    MESSAGE s911(fb) WITH TEXT-e08 TEXT-e14
      DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  " Fecha de adelanto no puede ser mayor o igual a fecha original
  IF lv_error_dateadv_dateori = abap_true.
    MESSAGE s911(fb) WITH TEXT-e08 TEXT-e09
      DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  " Fecha de adelanto PROCESO no puede estar en el pasado
  IF lv_error_day_past_pro = abap_true.
    MESSAGE s911(fb) WITH TEXT-e08 TEXT-e14
      DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  " Fecha de adelanto PROCESO no puede ser mayor o igual a fecha original
  IF lv_error_dateadv_dateori_pro = abap_true.
    MESSAGE s911(fb) WITH TEXT-e08 TEXT-e09
      DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  " Si hay errores por fecha PROCESO duplicada
  IF lv_error_dateadv_pro_dup = abap_true.
    MESSAGE s911(fb) WITH TEXT-e16 TEXT-e17
      DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  " Si hay errores por orden de fecha PROCESO
  IF lv_error_dateadv_pro_order = abap_true.
    MESSAGE s911(fb) WITH TEXT-e18 TEXT-e19
      DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  " Guardar en la tabla ztamm_except_mrp
  MODIFY ztamm_except_mrp FROM TABLE li_except_mrp.
  IF sy-subrc = 0.
    lv_lines = lines( li_except_mrp ).

    " Limpiar banderas de cambio
    MODIFY i_advance_plan FROM VALUE #( changed = space )
                          TRANSPORTING changed
                          WHERE changed = c_x.

    MESSAGE s911(fb) WITH lv_lines TEXT-m03. "registros guardados correctamente
    COMMIT WORK AND WAIT.
  ELSE.
    MESSAGE s908(fb) WITH TEXT-m04. "Error al guardar los datos
  ENDIF.

  " Refrescar el ALV
  IF o_alv_grid IS NOT INITIAL.
    CALL METHOD o_alv_grid->refresh_table_display.
  ENDIF.

ENDFORM.

*-------------------------------------------------------------------------------*
* FORM f_mass_update - Aplicar cambios masivos desde parámetros                 *
*-------------------------------------------------------------------------------*
FORM f_mass_update.

  DATA:
    lw_row TYPE lvc_s_row.

  DATA:
    li_rows TYPE lvc_t_row.

  DATA:
    lv_count TYPE i VALUE 0.

  " Validar que no se marquen ambas opciones simultáneamente
  IF v_advance = 'X' AND v_noexec = 'X'.
    MESSAGE w911(fb) WITH TEXT-e03 TEXT-e04. "No puede marcar Adelantar y No Ejecutar simultáneamente
    RETURN.
  ENDIF.

  " Validar que al menos un parámetro esté informado
  IF v_advance IS INITIAL AND v_noexec IS INITIAL
     AND v_dateadv IS INITIAL AND v_reason IS INITIAL
     AND v_dateadv_pro IS INITIAL.
    MESSAGE s908(fb) WITH TEXT-m05. "Ingrese al menos un valor para aplicar masivamente
    RETURN.
  ENDIF.

  "Obtiene lineas seleccionadas
  CALL METHOD o_alv_grid->get_selected_rows
    IMPORTING
      et_index_rows = li_rows.

*--------------------------------------------------------------------*
* Validaciones por adelanto masivo
*--------------------------------------------------------------------*
  " Procesar líneas seleccionadas
  LOOP AT li_rows INTO lw_row.

    " Aplicar cambios a todos los registros (excepto los ya procesados)
    READ TABLE i_advance_plan INTO DATA(lw_advance_plan)
                              INDEX lw_row-index.

    "No es necesario binary search se tratan de pocos registros
    IF sy-subrc = 0.

      " Saltar registros ya procesados
      IF lw_advance_plan-processed = 'X'.
        CONTINUE.
      ENDIF.

      " Aplicar Fecha de Adelanto si está informada
      IF v_dateadv IS NOT INITIAL.
        lw_advance_plan-dateadv = v_dateadv.
      ENDIF.

      " Fecha de adelanto no puede ser mayor o igual a fecha original
      IF lw_advance_plan-dateadv >= lw_advance_plan-dateori.
        MESSAGE s000(fb) WITH TEXT-e08 TEXT-e09 lw_advance_plan-puwnr lw_advance_plan-plwrk
          DISPLAY LIKE 'E'.
        RETURN.
      ENDIF.

    ENDIF.

  ENDLOOP.
*--------------------------------------------------------------------*

  " Procesar líneas seleccionadas
  LOOP AT li_rows INTO lw_row.

    " Aplicar cambios a todos los registros (excepto los ya procesados)
    READ TABLE i_advance_plan ASSIGNING FIELD-SYMBOL(<lfs_row>)
                              INDEX lw_row-index.

    "No es necesario binary search se tratan de pocos registros
    IF sy-subrc = 0.

      " Saltar registros ya procesados
      IF <lfs_row>-processed = 'X'.
        CONTINUE.
      ENDIF.

      " Aplicar ADVANCE si está marcado
      IF v_advance = 'X'.
        <lfs_row>-advance = 'X'.
      ENDIF.

      " Aplicar NOEXEC si está marcado
      IF v_noexec = 'X'.
        <lfs_row>-noexec  = 'X'.
      ENDIF.

      " Aplicar NOEXEC_PRO si está marcado
      IF v_noexec_pro = 'X'.
        <lfs_row>-noexec_pro = 'X'.
      ENDIF.

      " Aplicar Fecha de Adelanto si está informada
      IF v_dateadv IS NOT INITIAL.
        <lfs_row>-dateadv = v_dateadv.
      ENDIF.

      " Aplicar Fecha de Adelanto Proceso si está informada
      IF v_dateadv_pro IS NOT INITIAL.
        <lfs_row>-dateadv_pro = v_dateadv_pro.
      ENDIF.

      " Aplicar Motivo si está informado
      IF v_reason IS NOT INITIAL.
        <lfs_row>-reason = v_reason.
      ENDIF.

      " Marcar como modificado
      <lfs_row>-changed = c_x.

      lv_count = lv_count + 1.

    ENDIF.

  ENDLOOP.

  " Refrescar el ALV para mostrar los cambios
  IF o_alv_grid IS NOT INITIAL.
    CALL METHOD o_alv_grid->refresh_table_display.
  ENDIF.

  " Mostrar mensaje de éxito
  MESSAGE s911(fb) WITH lv_count TEXT-m06. "registros actualizados. Recuerde guardar

ENDFORM.

*--------------------------------------------------------------------------------*
*  FORM f_add_plan - Agregar nuevo plan de adelanto de pedido                    *
*--------------------------------------------------------------------------------*
FORM f_add_plan.

  DATA:
    lw_row TYPE lvc_s_row.

  DATA:
    li_rows TYPE lvc_t_row.

  FIELD-SYMBOLS:
    <lfs_new_plan> TYPE ty_advance_plan.

  DATA:
    lv_count           TYPE i VALUE 0,
    lv_max_dateori     TYPE dats,
    lv_max_dateori_pro TYPE dats,
    lv_new_idx         TYPE i,
    lv_curr_idx        TYPE i.


  "Obtiene lineas seleccionadas
  CALL METHOD o_alv_grid->get_selected_rows
    IMPORTING
      et_index_rows = li_rows.

  " Procesar líneas seleccionadas
  LOOP AT li_rows INTO lw_row.

    " Aplicar cambios a todos los registros (excepto los ya procesados)
    READ TABLE i_advance_plan ASSIGNING FIELD-SYMBOL(<lfs_row>)
                              INDEX lw_row-index.
    "No es necesario binary search se tratan de pocos registros
    IF sy-subrc = 0.
      " Preparar nuevo registro como copia
      DATA(lw_new_row) = <lfs_row>.
      CLEAR: lw_new_row-planum,
             lw_new_row-dateori,
             lw_new_row-dateori_pro,
             lw_new_row-advance,
             lw_new_row-noexec,
             lw_new_row-noexec_pro,
             lw_new_row-dateadv,
             lw_new_row-dateadv_pro,
             lw_new_row-reason,
             lw_new_row-processed,
             lw_new_row-createby,
             lw_new_row-createon,
             lw_new_row-changed,
             lw_new_row-celltab.

      " Marcar como modificado/nuevo
      lw_new_row-changed = c_x.

      APPEND lw_new_row TO i_advance_plan.

      " Calcular fecha original MRP considerando planes previos
      READ TABLE i_advance_plan ASSIGNING <lfs_new_plan> INDEX lines( i_advance_plan ).
      IF sy-subrc = 0 AND <lfs_new_plan>-dateori IS INITIAL.
        " Buscar la mayor DATEORI existente para este PUWNR/PLWRK
        CLEAR lv_max_dateori.
        lv_new_idx = lines( i_advance_plan ).
        LOOP AT i_advance_plan ASSIGNING FIELD-SYMBOL(<lfs_prev>)
          WHERE puwnr = <lfs_new_plan>-puwnr
            AND plwrk = <lfs_new_plan>-plwrk.
          lv_curr_idx = sy-tabix.
          IF lv_curr_idx <> lv_new_idx
            AND <lfs_prev>-dateori > lv_max_dateori.
            lv_max_dateori = <lfs_prev>-dateori.
          ENDIF.
        ENDLOOP.
        " Calcular siguiente fecha de ejecución desde la última fecha original
        <lfs_new_plan>-dateori = o_advance_planner->calculate_next_exec_date(
                                      iv_werks      = <lfs_new_plan>-plwrk
                                      iv_puwnr      = <lfs_new_plan>-puwnr
                                      iv_source     = 'M'
                                      iv_start_date = lv_max_dateori
                                 ).
      ENDIF.

      " Calcular fecha original si aplica
      READ TABLE i_advance_plan ASSIGNING <lfs_new_plan> INDEX lines( i_advance_plan ).
      IF sy-subrc = 0 AND <lfs_new_plan>-dateori_pro IS INITIAL.
        " Buscar la mayor DATEORI existente para este PUWNR/PLWRK
        CLEAR lv_max_dateori_pro.
        lv_new_idx = lines( i_advance_plan ).
        LOOP AT i_advance_plan ASSIGNING FIELD-SYMBOL(<lfs_prev_pro>)
          WHERE puwnr = <lfs_new_plan>-puwnr
            AND plwrk = <lfs_new_plan>-plwrk.
          lv_curr_idx = sy-tabix.
          IF lv_curr_idx <> lv_new_idx
            AND <lfs_prev_pro>-dateori_pro > lv_max_dateori_pro.
            lv_max_dateori_pro = <lfs_prev_pro>-dateori_pro.
          ENDIF.
        ENDLOOP.
        <lfs_new_plan>-dateori_pro = o_advance_planner->calculate_next_exec_date(
                                      iv_werks = <lfs_new_plan>-plwrk
                                      iv_puwnr = <lfs_new_plan>-puwnr
                                      iv_source = 'L'
                                      iv_start_date = lv_max_dateori_pro
                                 ).
      ENDIF.

    ENDIF.

    lv_count = lv_count + 1.

  ENDLOOP.

  " Refrescar el ALV para mostrar los cambios
  IF o_alv_grid IS NOT INITIAL.
    CALL METHOD o_alv_grid->refresh_table_display.
  ENDIF.

  " Mostrar mensaje de éxito
  MESSAGE s911(fb) WITH lv_count TEXT-m06. "registros actualizados. Recuerde guardar

ENDFORM.

*-------------------------------------------------------------------------------*
* FORM f_enqueue_table - Bloquear tabla ZTAMM_EXCEPT_MRP                        *
*-------------------------------------------------------------------------------*
FORM f_enqueue_table
     CHANGING c_v_okparam TYPE abap_bool.

  " Solicitar bloqueo enqueue para objeto
  CALL FUNCTION 'ENQUEUE_EZLOMM_EXCEP_MRP'
    EXCEPTIONS
      foreign_lock   = 1
      system_failure = 2
      OTHERS         = 3.

  IF sy-subrc <> 0.
    " Otro usuario tiene el programa bloqueado
    MESSAGE s601(mc) WITH sy-msgv1 ##MG_MISSING.
    c_v_okparam = abap_true.
  ENDIF.

ENDFORM.

*-------------------------------------------------------------------------------*
* FORM f_dequeue_table - Liberar bloqueo de tabla ZTAMM_EXCEPT_MRP              *
*-------------------------------------------------------------------------------*
FORM f_dequeue_table.

  " Liberar bloqueo enqueue para objeto
  CALL FUNCTION 'DEQUEUE_EZLOMM_EXCEP_MRP'.

ENDFORM.