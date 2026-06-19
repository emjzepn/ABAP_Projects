# Inicio del Proceso: WorkOrderPR

Basado en el diseño y los métodos de la clase `ZCXCL_BMMRMTBM_PRPO_FLEETIO`, el proceso de integración de WorkOrderPR cuenta con **dos momentos principales de inicio**. Estos momentos dependen de si nos referimos a la captura de los eventos en SAP o al momento de enviar físicamente la información a Fleetio.

---

## 1. Fase de Captura de Datos (Eventos en SAP)

El proceso técnico comienza realmente cuando un usuario o el sistema crea o modifica una Solicitud de Pedido (PR) o un Pedido de Compra (PO) en SAP. Para iniciar la recolección de los datos (trazabilidad), se deben llamar a los siguientes métodos públicos (típicamente invocados desde una BAdI o User Exit estándar como `ME_PROCESS_REQ_CUST` o `ME_PROCESS_PO_CUST` al momento de guardar el documento):

### Métodos de Inicio:
*   **`register_pr_creation`**: Inicia el flujo cuando se crea una nueva Solicitud de Pedido (PR).
*   **`register_po_creation`**: Inicia el flujo alternativo cuando el PR se convierte en un Pedido de Compra (PO).
*   **`register_po_change`**: Inicia el flujo de actualización si el PO sufre cambios críticos (modificación de cantidad, indicador de borrado o marca de entrega completa).

**Comportamiento esperado:**
Estos métodos son el verdadero inicio técnico. Al ser invocados, extraen la información relevante del documento y la guardan en la tabla de trazabilidad (`ZPMT_FLT_PRPO`) con estatus de salida en pendiente (`PENDING`).

---

## 2. Fase de Envío de Datos (Generación del JSON)

Una vez que los eventos fueron capturados y registrados, debe existir un programa ejecutable (Reporte o Job de fondo) o una clase proxy que se encargue de recuperar esos datos, empaquetarlos en un JSON y enviarlos a la API de Fleetio.

### Método de Inicio:
*   **`get_pending_records`**: Este método es el **punto de partida del programa de envío**. Su función es buscar todos los registros en la tabla `ZPMT_FLT_PRPO` que están listos para ser procesados (aquellos con estatus `PENDING` o `RETRY`).

**Comportamiento esperado:**
Una vez que el programa obtiene los registros pendientes a través de este método, procede a llamar a **`build_json_response`** pasándole los parámetros correspondientes (`fleetio_id` y `aufnr`) para construir el JSON final que se enviará. Al terminar el envío, el ciclo se cierra llamando a **`update_outbound_status`** para actualizar el estatus en la base de datos (por ejemplo, a `SENT` o `ERROR`).

---

## Resumen

*   **¿Cómo se desencadena el registro original?** Mediante los métodos **`register_pr_creation`**, **`register_po_creation`** y **`register_po_change`**.
*   **¿Cómo inicia la interfaz que envía el JSON?** Llamando al método **`get_pending_records`**.
