# Diagrama de Flujo: Inicio del Proceso WorkOrderPR

Este diagrama representa visualmente las dos fases descritas en el documento `inicio_proceso_workorderpr.md`.

```mermaid
flowchart TD
    %% Fase 1: Captura
    subgraph Fase1 ["1. Fase de Captura de Datos (Eventos en SAP)"]
        direction TB
        A("Usuario / Sistema (SAP)")
        
        A -->|"Crea Solicitud de Pedido (PR)"| B1("BAdI: ME_PROCESS_REQ_CUST")
        A -->|"Crea Pedido de Compra (PO)"| B2("BAdI: ME_PROCESS_PO_CUST")
        A -->|"Modifica Pedido (PO)"| B3("BAdI: ME_PROCESS_PO_CUST")
        
        B1 -->|"Llama método"| C1["register_pr_creation"]
        B2 -->|"Llama método"| C2["register_po_creation"]
        B3 -->|"Llama método"| C3["register_po_change"]
        
        C1 -->|"Extrae y guarda"| D[("Tabla ZPMT_FLT_PRPO (Status: PENDING)")]
        C2 -->|"Extrae y guarda"| D
        C3 -->|"Extrae y guarda"| D
    end

    %% Fase 2: Envío
    subgraph Fase2 ["2. Fase de Envío de Datos (Generación del JSON)"]
        direction TB
        E("Programa Ejecutable / Job de Fondo")
        
        E -->|"Despierta e inicia"| F["get_pending_records"]
        D -.->|"Busca status PENDING o RETRY"| F
        
        F -->|"Pasa fleetio_id y aufnr"| G["build_json_response"]
        
        G -->|"Envía JSON construido"| H("API Fleetio")
        
        H -->|"Retorna Éxito / Error"| I["update_outbound_status"]
        
        I -->|"Actualiza status final (SENT/ERROR)"| J[("Tabla ZPMT_FLT_PRPO")]
    end
    
    %% Relación entre BD
    D -.->|"Se actualiza el registro"| J
    
    %% Estilos para diferenciar fases
    style C1 fill:#d4edda,stroke:#28a745
    style C2 fill:#d4edda,stroke:#28a745
    style C3 fill:#d4edda,stroke:#28a745
    
    style F fill:#cce5ff,stroke:#007bff
    style G fill:#cce5ff,stroke:#007bff
    style I fill:#cce5ff,stroke:#007bff
```

### Descripción del Diagrama:
*   **Fase 1 (Verde):** Detalla cómo las BAdIs actúan como el gatillo inicial (trigger) para capturar los datos y depositarlos en la tabla transaccional con estatus `PENDING`.
*   **Fase 2 (Azul):** Ilustra cómo el programa de fondo toma el control a partir de `get_pending_records`, realiza el ensamblado del JSON y finalmente cierra el ciclo de vida del registro actualizando la tabla.
