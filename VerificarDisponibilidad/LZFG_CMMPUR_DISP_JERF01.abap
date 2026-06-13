*-------------------------------------------------------------------------------*
*                   Fabrica de Software ABAP NEORIS                             *
*-------------------------------------------------------------------------------*
* Grupo de funciones  : ZFG_CMMPUR_DISP_JER                                     *
* Módulo de funciones : Z_FM_CMMPUR_DISP_JER                                    *
* Descripción         : Verificación de disponibilidad                          *
* Funcional           : Sarai Reyes                                             *
* Desarrollador       : Edgar Morales  - ABAP_01                                *
* Diseñador Técnico   : Edgar Morales                                           *
* Fecha de Creación   : 09.03.2026                                              *
* ID del Componente   : DF-EXMM53                                               *
* Número de Req.      : EXMM53                                                  *
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
*&---------------------------------------------------------------------*
*& Form F_CHECK_AUTHORIZATION
*&---------------------------------------------------------------------*
*& Descripción: Valida autorización del usuario para centro
*&---------------------------------------------------------------------*
*& -->  PI_WERKS     Centro a validar
*& <--  PE_ERROR     Indicador de error
*& <--  PE_MENSAJE   Mensaje de error
*&---------------------------------------------------------------------*
FORM f_check_authorization
  USING    pi_werks    TYPE werks_d
  CHANGING pe_error    TYPE abap_bool
           pe_mensaje  TYPE bapi_msg.

  "Inicialización
  CLEAR:
    pe_error,
    pe_mensaje.

  "Validación de autorización para centro
  AUTHORITY-CHECK OBJECT 'M_MATE_WRK'
    ID 'ACTVT' FIELD '03'
    ID 'WERKS' FIELD pi_werks.

  IF sy-subrc <> 0.
    "Usuario no tiene autorización
    pe_error   = abap_true.
    pe_mensaje = TEXT-001. "'Usuario sin autorización para centro'.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form F_CHECK_PARAMETERS
*&---------------------------------------------------------------------*
*& Descripción: Valida parámetros obligatorios de entrada
*&---------------------------------------------------------------------*
*& -->  PI_MATNR     Material
*& -->  PI_WERKS     Centro
*& -->  PI_MENGE     Cantidad
*& -->  PI_MEINH     Unidad de medida
*& <--  PE_ERROR     Indicador de error
*& <--  PE_MENSAJE   Mensaje de error
*&---------------------------------------------------------------------*
FORM f_check_parameters
  USING    pi_matnr    TYPE matnr
           pi_werks    TYPE werks_d
           pi_menge    TYPE menge_d
           pi_meinh    TYPE meins
  CHANGING pe_error    TYPE abap_bool
           pe_mensaje  TYPE bapi_msg.

  "Inicialización
  CLEAR:
    pe_error,
    pe_mensaje.

  "Validar que parámetros obligatorios no estén vacíos
  IF pi_matnr IS INITIAL OR
     pi_werks IS INITIAL OR
     pi_menge IS INITIAL OR
     pi_meinh IS INITIAL.

    pe_error   = abap_true.
    pe_mensaje = text-002. "'Parámetros obligatorios no proporcionados'.
    RETURN.

  ENDIF.

  "Validar que material exista en maestro
  SELECT SINGLE matnr
    FROM mara
    INTO @DATA(lv_matnr_check) ##NEEDED
    WHERE matnr = @pi_matnr.

  IF sy-subrc <> 0.
    pe_error   = abap_true.
    pe_mensaje = text-003. "'Material no existe en maestro de materiales'.
    RETURN.
  ENDIF.

  "Validar que centro exista
  SELECT SINGLE werks
    FROM t001w
    INTO @DATA(lv_werks_check) ##NEEDED
    WHERE werks = @pi_werks.

  IF sy-subrc <> 0.
    pe_error   = abap_true.
    pe_mensaje = text-004. "'Centro no existe en sistema'.
    RETURN.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form F_GET_CEDIS_TVARV
*&---------------------------------------------------------------------*
*& Descripción: Obtiene centro CEDIS desde tabla TVARV
*&---------------------------------------------------------------------*
*& <--  PE_CEDIS     Centro CEDIS
*&---------------------------------------------------------------------*
FORM f_get_cedis_tvarv
  CHANGING pe_cedis TYPE werks_d.

  "Constante local
  DATA:
    lc_tvarv_name TYPE rvari_vnam VALUE 'CDYS',
    lc_parameter  TYPE char1 VALUE 'P'.         "Típo parámetro

  "Inicialización
  CLEAR pe_cedis.

  "Consultar TVARV
  SELECT SINGLE low
    FROM tvarv                 "#EC CI_NOORDER
    INTO @pe_cedis
    WHERE name = @lc_tvarv_name
      AND type = @lc_parameter ##WARN_OK.

  IF sy-subrc <> 0.
    "Si no se encuentra, usar valor por defecto (3030)
    pe_cedis = '3030'.
  ENDIF.

ENDFORM.