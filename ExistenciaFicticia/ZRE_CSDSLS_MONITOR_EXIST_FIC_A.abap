*-------------------------------------------------------------------------------*
*                   Fabrica de Software ABAP NEORIS                             *
*-------------------------------------------------------------------------------*
* Nombre del Programa : ZRE_CSDSLS_MONITOR_EXIST_FIC_A                          *
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
* DECLARACIÓN DE TABLAS                                                         *
*-------------------------------------------------------------------------------*
TABLES: vbak,      " Cabecera de documento de ventas
        vbap.      " Posiciones de documento de ventas

*-------------------------------------------------------------------------------*
* DECLARACIÓN DE TIPOS                                                          *
*-------------------------------------------------------------------------------*
TYPE-POOLS: slis, icon.

TYPES:
  BEGIN OF ty_goods_assumtion,
    icon              TYPE icon_d,         " Semáforo
    vbeln             TYPE vbak-vbeln,     " Número de pedido de venta
    posnr             TYPE vbap-posnr,     " Posición del pedido
    erdat             TYPE vbak-erdat,     " Fecha de creación
    vkorg             TYPE vbak-vkorg,     " Organización de ventas
    vtweg             TYPE vbak-vtweg,     " Canal de distribución
    spart             TYPE vbak-spart,     " Sector
    werks             TYPE vbap-werks,     " Centro
    kunnr             TYPE vbak-kunnr,     " Número de cliente
    name1             TYPE kna1-name1,     " Nombre del cliente
    zterm             TYPE vbkd-zterm,     " Clave de condiciones de pago
    dtpaymt           TYPE char10,         " Descripción termino de pago
    matnr             TYPE vbap-matnr,     " Material
    maktx             TYPE makt-maktx,     " Descripción del material
    kwmeng            TYPE vbap-kwmeng,    " Cantidad del pedido
    vbeln_vl          TYPE likp-vbeln,     " Número de entrega
    erdat_vl          TYPE likp-erdat,     " Fecha de entrega
    lfimg             TYPE lips-lfimg,     " Cantidad entregada
    meins             TYPE vbap-meins,     " Unidad de medida
    rfmng             TYPE vbfa-rfmng,     " Cantidad confirmada
    difference        TYPE vbap-kwmeng,    " Cantidad diferencia
    tknum             TYPE vttk-tknum,     " Nº transporte
    tpnum             TYPE vttp-tpnum,     " Posición transporte
    process           TYPE char10,         " Proceso - Aceptar / Rechazo
    status            TYPE char15,         " Estatus
    reason_rej        TYPE abgru_va,       " Razón de rechazo
    salesorder_ant    TYPE vbeln_va,       " Orden anticipo
    invoice_ant       TYPE vbrk-vbeln,     " Factura anticipo
    salesorder_cons   TYPE vbeln_va,       " Orden consumo
    delivery_cons     TYPE vbeln_vl,       " Entrega consumo
    pgi_cons          TYPE mseg-mblnr,     " EM Entrega salida mercancías
    shipment_cons     TYPE vttk-tknum,     " Transporte consumo
    invoice_cons      TYPE vbrk-vbeln,     " Factura consumo
    creditmemo_ant    TYPE vbeln_va,       " NC anticipo
    creditmemo_antinv TYPE vbeln_vf,       " NC anticipoinv
    creditmemo_bon    TYPE vbeln_va,       " NC Bon
    creditmemo_boninv TYPE vbeln_vf,       " NC Boninv
    message           TYPE bapi_msg,       " Mensajes
  END OF ty_goods_assumtion.

TYPES: tt_goods_assumtion TYPE STANDARD TABLE OF ty_goods_assumtion WITH DEFAULT KEY.

TYPES:
  BEGIN OF ty_log,
    icon     TYPE icon_d,         " Ícono de estado (semáforo)
    document TYPE vbeln_va,       " Documento procesado
    process  TYPE char20,         " Tipo de proceso
    status   TYPE char10,         " Estado del proceso
    euser    TYPE sy-uname,       " Usuario
    edate    TYPE dats,           " Fecha de ejecución
    etime    TYPE tims,           " Hora de ejecución
    message  TYPE char255,        " Mensaje detallado
  END OF ty_log.

*-------------------------------------------------------------------------------*
* CONSTANTES                                                                    *
*-------------------------------------------------------------------------------*
CONSTANTS:
  c_cash_sales       TYPE vbrk-zterm   VALUE 'A000',   " Término de pago contado
  c_vbtyp_delivery   TYPE vbfa-vbtyp_n VALUE 'J',      " Tipo documento entrega
  c_vbtyp_picking    TYPE vbfa-vbtyp_n VALUE 'Q',      " Picking del documento de entrega
  c_vbtyp_shipment   TYPE vbfa-vbtyp_n VALUE '8',      " Tipo documento transporte
  c_embalaje_parcial TYPE vbuk-kostk   VALUE 'B',      " Estado embalaje parcial
  c_x                TYPE char1  VALUE 'X',            " Constante X
  c_d                TYPE char1  VALUE 'D',            " Constante D
  c_e                TYPE char1  VALUE 'E',            " Constante E
  c_i                TYPE char1  VALUE 'I',            " Constante I
  c_u                TYPE char1  VALUE 'U',            " Constante U
  c_eq               TYPE char2  VALUE 'EQ',           " Constante EQ
  c_bt               TYPE char2  VALUE 'BT',           " Constante BT
  c_finised          TYPE char10 VALUE 'FINALIZADO',   " Finalizado
  c_accept           TYPE char8  VALUE 'ACEPTADO',     " Comando aceptar
  c_reject           TYPE char9  VALUE 'RECHAZADO',    " Comando rechazar
  c_error            TYPE char5  VALUE 'ERROR'.        " Error

*-------------------------------------------------------------------------------*
* ESTRUCTURAS                                                                   *
*-------------------------------------------------------------------------------*
DATA:
  w_parcial_orders TYPE ty_goods_assumtion ##NEEDED,
  w_log            TYPE ty_log ##NEEDED.

*-------------------------------------------------------------------------------*
* TABLAS INTERNAS                                                               *
*-------------------------------------------------------------------------------*
DATA:
  i_parcial_orders TYPE TABLE OF ty_goods_assumtion ##NEEDED,
  i_log            TYPE TABLE OF ty_log ##NEEDED.

*-------------------------------------------------------------------------------*
* FIELD-SYMBOLS                                                                 *
*-------------------------------------------------------------------------------*
FIELD-SYMBOLS:
  <fs_log> TYPE ty_log ##NEEDED.

*-------------------------------------------------------------------------------*
* VARIABLES GLOBALES                                                            *
*-------------------------------------------------------------------------------*
DATA:
  v_okcode     TYPE sy-tcode,           " Código OK
  v_icon_name  TYPE iconname,
  v_text_line1 TYPE char255,
  v_text_line2 TYPE char255,
  v_text_line3 TYPE char255,
  v_last_day   TYPE sy-datum ##NEEDED.

*-------------------------------------------------------------------------------*
* OBJETOS                                                                       *
*-------------------------------------------------------------------------------*
DATA:
  o_alv_grid  TYPE REF TO cl_gui_alv_grid ##NEEDED,
  o_container TYPE REF TO cl_gui_custom_container ##NEEDED,
  o_data      TYPE REF TO data ##NEEDED.

*-------------------------------------------------------------------------------*
* PARÁMETROS DE SELECCIÓN                                                       *
*-------------------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b01 WITH FRAME TITLE TEXT-t01.
" Datos Documentos
SELECT-OPTIONS: s_auart FOR vbak-auart DEFAULT 'ZVM1',         " Clase doc.ventas
                s_vbeln FOR vbak-vbeln,                        " Documento
                s_kunnr FOR vbak-kunnr,                        " Cliente
                s_werks FOR vbap-werks,                        " Sucursal
                s_erdat FOR vbak-erdat.                        " Fecha de creación
SELECTION-SCREEN END OF BLOCK b01.

* Datos de organización
SELECTION-SCREEN BEGIN OF BLOCK b02 WITH FRAME TITLE TEXT-t02.
SELECT-OPTIONS: s_vkorg FOR vbak-vkorg OBLIGATORY DEFAULT 'IF00', "Organización de ventas
                s_vtweg FOR vbak-vtweg,                           "Canal de distribución
                s_spart FOR vbak-spart.                           "Sector
SELECTION-SCREEN END OF BLOCK b02.

* Opciones de procesamiento
SELECTION-SCREEN BEGIN OF BLOCK b03 WITH FRAME TITLE TEXT-t03.
PARAMETERS: p_accept TYPE char1 NO-DISPLAY, " Proceso de aceptación
            p_reject TYPE char1 NO-DISPLAY, " Proceso de rechazo
            p_batch  TYPE char1 NO-DISPLAY. " Proceso en fondo
SELECTION-SCREEN END OF BLOCK b03.

SELECTION-SCREEN BEGIN OF SCREEN 0210 AS SUBSCREEN.
SELECTION-SCREEN BEGIN OF BLOCK sb1.
PARAMETERS: p_sbatch AS CHECKBOX DEFAULT ' '.
SELECTION-SCREEN END OF BLOCK sb1.
SELECTION-SCREEN END OF SCREEN 0210.