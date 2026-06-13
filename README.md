# ABAP_Projects

> [!IMPORTANT]
> Los nombres de los programas ABAP comienzan con 4 letras (prefijo) y el resto es una cadena de 3 caracteres (sufijo).
>
> **Formato: `ZXXXYYYY`**
>
> Donde:
> - `Z` o `Y`: Identificador de objeto de cliente
> - `XXX`: Prefijo (Identificador del programa)
> - `YYYY`: Sufijo (Clave o ID del programa)

## Estructura de carpetas

Cada programa ABAP tiene una carpeta dedicada con la siguiente estructura:

```
NombrePrograma/
├── NombrePrograma.abap              # Código fuente principal (Implementation)
├── LZ..._I.abap                     # Interface Pool (Clases/Interfaces)
├── LZ..._O.abap                     # Object Pool (Clases)
├── LZ..._B.abap                     # Type Pool (Tipos de datos)
├── LZ..._A.abap                     # Attribute Pool (Atributos/Propiedades)
└── .gitignore                       # Archivos ignorados por Git
```

### Archivos especiales

#### 1. Interfaces y Clases (LZ..._I.abap, LZ..._O.abap)

En ABAP, es una práctica común separar la lógica en:
- **Interface Pool (`.I.abap`)**: Define interfaces, clases abstractas y la estructura de las clases.
- **Object Pool (`.O.abap`)**: Contiene las clases concretas que implementan las interfaces del pool.

#### 2. Atributos y Tipos (LZ..._A.abap, LZ..._B.abap)

- **Type Pool (`.B.abap`)**: Contiene tipos de datos globales, estructuras y tablas internas que se comparten entre programas.
- **Attribute Pool (`.A.abap`)**: Contiene atributos o propiedades globales del programa.

## Ejemplos de Programas

### 1. ZRE_CMMPUR_ACT_MRP

```
ActualizaMaterial/
├── ZRE_CMMPUR_ACT_MRP.abap           # Programa principal
├── LZFG_CMMPUR_ACT_MRP_I.abap        # Interfaces y Clases
├── LZFG_CMMPUR_ACT_MRP_O.abap        # Clases de implementación
├── LZFG_CMMPUR_ACT_MRP_A.abap        # Atributos
├── LZFG_CMMPUR_ACT_MRP_B.abap        # Tipos de datos
└── .gitignore
```

### 2. ZRE_CMMPUR_ADVANCE_PLANNER

```
AdelantarPedido/
├── ZRE_CMMPUR_ADVANCE_PLANNER.abap   # Programa principal
├── LZFG_CMMPUR_ADVANCE_PLANNER_I.abap
├── LZFG_CMMPUR_ADVANCE_PLANNER_O.abap
├── LZFG_CMMPUR_ADVANCE_PLANNER_A.abap
├── LZFG_CMMPUR_ADVANCE_PLANNER_B.abap
└── .gitignore
```

## Convenciones de Nomenclatura

### Prefijos
- `ZRE_`: Programas relacionados con "Requerimientos" (Requisitions)
- `ZCXRE_`: Programas relacionados con "Confirmaciones Externas" (Cross-System External Requirements)

### Estándares de implementación

#### Reportes (RE)
- **Interfaz**: `LZFG_..._I.abap`
- **Objeto**: `LZFG_..._O.abap`

#### Function Modules (FM)
- **Interfaz**: `Z_FM_..._I.abap`
- **Objeto**: `Z_FM_..._O.abap`

## Herramientas

Todos los programas están optimizados para ejecutarse con:
- **SAP GUI**
- **SAP Business Application Studio**
- **SAP Fiori Tools**
