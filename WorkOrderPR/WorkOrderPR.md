# Functional Design for Developments and Configurations

**Project:** SAP-US Functional Specification - Fleetio PR/PO Outbound Response Interface

| Campo | Valor |
| --- | --- |
| ***Project:*** | SAP-US Functional Specification - Fleetio PR/PO Outbound Response Interface |
| ***Requirement ID:*** | SR |
| ***Date:*** | 16-06-2026 |
| ***Copyright:*** |  |
| ***Company:*** |  |
| ***Customer:*** |  |
| ***Priority:*** | HIGH |

---

## 1. Introduction

### 1.1 Created by:
John Doe

### 1.2 Email and telephone contact:
John Doe

### 1.3 Authorized by:
John Doe

### 1.4 Authorization date:
16-06-2026

### 1.5 Requested by:
Me

### 1.6 User Name:
Wilfrido Arroyo

### 1.7 Related Business Process:
PM / MM Purchasing

### 1.8 Application:
SAP ECC.

### 1.9 Module / Sub-module:
PM / MM

### 1.10 Application Version:
Optional - Specify the version of application where the requirement will be solved

---

## 2. Index

- Functional Design for Developments and Configurations
- 1 Introduction
  - 1.1 Created by
  - 1.2 Email and telephone contact
  - 1.3 Authorized by
  - 1.4 Authorization date
  - 1.5 Requested by
  - 1.6 User Name
  - 1.7 Related Business Process
  - 1.8 Application
  - 1.9 Module / Sub-module
  - 1.10 Application Version
- 2 Index
- 3 Modifications Log Book
- 4 General Definition
  - 4.1 Requirement description
  - 4.2 Geographical Impact
  - 4.3 Frequency and User Concurrency execution
  - 4.4 Data Volume
  - 4.5 Reason for the development or configuration (Business Value)
  - 4.6 Assumptions
  - 4.7 Acceptance criteria
  - 4.8 Comments
  - 4.9 Requirement Type
  - 4.10 Required components by
- 5 Additional Requirements
  - 5.1 Special Instructions
- 6 Glossary of Concepts
- 7 Change Controls

---

## 3. Modifications Log Book

| Version | Clarity ID or Folio ID | Date | Description | Author |
| --- | --- | --- | --- | --- |
| 1.7 |  | 16-06-2026 | Se separa la salida como log de WO y respuesta PR/PO. | John Doe |
|  |  |  |  |  |
|  |  |  |  |  |
|  |  |  |  |  |

---

## 4. General Definition

### 4.1 Requirement description:

Se requiere una interfaz de salida **SAP → Fleetio** para enviar el resultado de creación de la Work Order y la trazabilidad de compras asociada. La creación/modificación de la WO por JSON es un flujo inbound independiente.

El flujo enviará a Fleetio el `AUFNR` cuando la WO se cree correctamente. Si la BAPI falla, se enviará el mensaje registrado en `ZTA0108_ODATAL`. Después, cuando SAP genere la PR, la interfaz enviará los datos de requisición; cuando Compras genere la PO o cuando `EKPO-ELIKZ` quede en `X`, se reenviará el JSON con el avance correspondiente.

### 4.2 Geographical Impact

USA region

### 4.3 Frequency and User Concurrency execution:

Ejecución por evento: creación/error de WO, creación/modificación de PR, creación/modificación de PO, borrado de posición PO y actualización de entrega completa en `EKPO-ELIKZ`.

### 4.4 Data Volume:

| Concept | Definition |
| --- | --- |
| Work Orders | WOs Fleetio registradas en `ZTA0108_ODATAL`. |
| Purchase Requisitions | Una WO puede generar una o varias posiciones de PR. |
| Purchase Orders | Una PR puede convertirse en una o varias posiciones de PO. |
| Outbound Messages | Se envía respuesta por etapa: WO, PR, PO, modificación de cantidad, borrado o entrega completa de PO. |

### 4.5 Reason for the development or configuration (Business Value):

Dar a Fleetio visibilidad del resultado de la WO en SAP y del avance de compras sin seguimiento manual. Con esto Fleetio podrá conocer el `AUFNR`, la PR, la PO, los cambios de cantidad, el borrado de posiciones y la entrega completa de la posición.

### 4.6 Assumptions:

- La interfaz inbound de WO guarda el resultado de `BAPI_ALM_ORDER_MAINTAIN` en `ZTA0108_ODATAL`.
- La correlación Fleetio/SAP se toma de `ZTA0108_ODATAL` usando `EXTERNAL_ID`, `WORKORDER` y `ORIGIN_ID`.
- Solo se procesan documentos con `AUFNR` y planta activa en `ZTA0117_FLT_CONF`.
- Las BAdIs solo actualizan trazabilidad; el envío a Confluent/Fleetio lo realiza el Bridge/job fuera del update task.
- `EKPO-ELIKZ = X` indica posición de PO entregada completamente; `EKPO-LOEKZ` indica posición borrada y `EKPO-MENGE` refleja cambios de cantidad.

### 4.7 Acceptance criteria:

- **WO creada:** el JSON debe regresar `TYPE = S`, `WORKORDER = AUFNR` y el mensaje de éxito de `ZTA0108_ODATAL`.
- **WO con error:** el JSON debe regresar `TYPE = E` y el mensaje de error guardado en `ZTA0108_ODATAL`.
- **PR generada:** la posición debe registrarse en `ZPMT_FLT_PRPO` y enviarse con estatus `PR_CREATED` / `PR_UPDATED`.
- **PO generada:** la posición debe registrarse en `ZPMT_FLT_PRPO` y enviarse con `EBELN` / `EBELP`.
- **PO modificada:** si cambia `EKPO-MENGE`, `EKPO-NETPR` o `EKPO-NETWR`, se debe reenviar la posición con `Action = UPDATED`.
- **PO borrada:** si `EKPO-LOEKZ` se llena, se debe reenviar la posición con `Action = DELETED`.
- **PO modificada/borrada/entregada:** si cambia `EKPO-MENGE`, se llena `EKPO-LOEKZ` o `EKPO-ELIKZ = X`, se debe reenviar la PO con la acción correspondiente a nivel posición.
- Si falla el envío del Bridge, el registro debe quedar en `ERROR/RETRY` para reproceso.

### 4.8 Comments:

El alcance no incluye el detalle técnico de la interfaz inbound de WO.

### 4.9 Requirement Type

**SAP ECC Functional Specification**

**Fleetio ← SAP outbound log / PR / PO response through Bridge / Confluent channel**

| Element | Definition |
| --- | --- |
| SAP Object | PM Work Order / MM PR / MM PO. |
| Source System | SAP ECC. |
| Target System | Fleetio. |
| Outbound Channel | SAP → PR/PO Bridge → Confluent → Fleetio. |
| Main Triggers | `ZTA0108_ODATAL` log, `ME_REQ_POSTED`, `ME_PURCHDOC_POSTED` and EKPO changes: `MENGE`, `LOEKZ`, `ELIKZ`. |
| Monitoring / Persistence | `ZTA0108_ODATAL` para WO; `ZPMT_FLT_PRPO` para PR/PO y control outbound. |
| Plant Control | `ZTA0117_FLT_CONF` valida plantas/configuración habilitada. |
| Response Content | FleetioId, SAP Work Order, mensajes BAPI, PRs, POs, `EKPO_MENGE`, `EKPO_LOEKZ` and `EKPO_ELIKZ`. |
| Out of Scope | Inbound WO detail, confirmations, inventories and Goods Receipts detail. |

#### 1. Flujo funcional consolidado

| Step | Process Point | Functional Rule | Result |
| --- | --- | --- | --- |
| 1 | JSON entrada Fleetio → SAP | La interfaz inbound independiente ejecuta `BAPI_ALM_ORDER_MAINTAIN`. | `ZTA0108_ODATAL` guarda éxito o error. |
| 2 | WO Log Outbound | El Bridge lee `ZTA0108_ODATAL`. | Envía `AUFNR` si `TYPE = S` o mensaje BAPI si `TYPE = E`. |
| 3 | PR automática desde WO | SAP genera/modifica la PR y `ME_REQ_POSTED` valida `EBKN-AUFNR`, `WERKS` y correlación. | `ZPMT_FLT_PRPO` guarda `PR_CREATED` / `PR_UPDATED`. |
| 4 | PO por Compras | Compras convierte la PR a PO en ME21N / ME59N; `ME_PURCHDOC_POSTED` valida `AUFNR` y correlación. | `ZPMT_FLT_PRPO` guarda `PO_CREATED` / `PO_UPDATED`, `EBELN` y `EBELP`. |
| 5 | Cambios posteriores de PO | SAP actualiza `EKPO-MENGE`, `EKPO-LOEKZ` o `EKPO-ELIKZ`. | Se reenvía JSON con `Action = UPDATED`, `DELETED` o `COMPLETED` a nivel posición. |
| 6 | Bridge outbound | Lee pendientes, arma JSON y publica en Confluent. | Actualiza `SENT` o `ERROR/RETRY`. |

#### 2. Alcance funcional

| Concept | Rule |
| --- | --- |
| WO Log Response | Enviar a Fleetio el `AUFNR` o el error registrado en `ZTA0108_ODATAL`. |
| PR Capture | Capturar PR cuando la posición tenga `EBKN-AUFNR` y la WO exista en el log Fleetio. |
| PO Capture | Capturar PO cuando la imputación tenga `EKKN-AUFNR` y relación con la PR/WO Fleetio. |
| PO Update/Delete/Complete | Reenviar cuando cambie `EKPO-MENGE`, se llene `EKPO-LOEKZ` o `EKPO-ELIKZ = X`. |
| Traceability | Guardar PR/PO, cantidad, indicador de borrado, entrega completa y estatus outbound en `ZPMT_FLT_PRPO`. |

#### 3. Desarrollo ABAP

| Order | ABAP Object / Activity | Expected Detail |
| --- | --- | --- |
| 1 | WO Log Outbound | Leer `ZTA0108_ODATAL` y enviar `WO_CREATED` / `WO